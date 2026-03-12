# IAM Roles and Policies for AgentCore Runtimes

# =============================================================================
# ASSUME ROLE POLICY - Shared trust policy for Bedrock AgentCore service
# =============================================================================

data "aws_iam_policy_document" "agentcore_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.aws_account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock-agentcore:${local.region}:${local.aws_account_id}:*"]
    }
  }
}

# =============================================================================
# PER-AGENT EXECUTION ROLES - Each agent gets its own IAM role
# =============================================================================

# Build agent identity names
locals {
  # IAM role names: {deployment_name}-{region}-{agent_name} (hyphens allowed)
  agent_identities = {
    for agent_name, config in var.agents :
    agent_name => "${var.deployment_name}-${local.region}-${agent_name}"
  }

  # AgentCore runtime names must match: ^[a-zA-Z][a-zA-Z0-9_]{0,47}$
  # Use underscores, no hyphens, max 48 chars
  agent_runtime_names = {
    for agent_name, config in var.agents :
    agent_name => substr(replace("${var.deployment_name}_${agent_name}", "-", "_"), 0, 48)
  }

  # Agents with S3 bucket access requirements
  agents_with_s3 = {
    for name, config in var.agents : name => config
    if config.s3_bucket_arns != null && length(config.s3_bucket_arns) > 0
  }

  # Agents with parameter access requirements
  agents_with_parameters = {
    for name, config in var.agents : name => config
    if length(config.parameter_arns) > 0
  }

  # Agents with agent invocation requirements
  agents_with_invocation = {
    for name, config in var.agents : name => config
    if length(coalesce(config.can_invoke, [])) > 0
  }

  # S3 read paths (with defaults)
  s3_read_paths = length(try(var.s3_bucket_paths.read_paths, [])) > 0 ? var.s3_bucket_paths.read_paths : ["config/*", "docs/*", "inputs/*", "test/*"]

  # S3 write paths (with defaults)
  s3_write_paths = length(try(var.s3_bucket_paths.write_paths, [])) > 0 ? var.s3_bucket_paths.write_paths : ["outputs/*"]
}

# Create IAM execution role for each agent
resource "aws_iam_role" "agent_execution" {
  for_each = var.agents

  name               = local.agent_identities[each.key]
  description        = "Bedrock AgentCore execution role for ${each.key} agent in ${var.deployment_name} deployment"
  assume_role_policy = data.aws_iam_policy_document.agentcore_assume_role.json

  tags = merge(
    var.tags,
    {
      Name       = local.agent_identities[each.key]
      AgentName  = each.key
      Deployment = var.deployment_name
      ManagedBy  = "Terraform"
      service    = "tra-agent"
    }
  )
}

# =============================================================================
# ECR ACCESS POLICY - Required for all agents to pull container images
# =============================================================================

data "aws_iam_policy_document" "ecr_access" {
  statement {
    sid    = "ECRAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = length(var.ecr_repository_arns) > 0 ? var.ecr_repository_arns : ["*"]
  }
}

resource "aws_iam_role_policy" "agent_ecr_access" {
  for_each = var.agents

  name   = "ecr-access"
  role   = aws_iam_role.agent_execution[each.key].id
  policy = data.aws_iam_policy_document.ecr_access.json
}

# =============================================================================
# BEDROCK ACCESS POLICY - Required for agents to invoke models
# =============================================================================

data "aws_iam_policy_document" "bedrock_access" {
  statement {
    sid    = "BedrockModelInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    # Modern models are gated behind cross region inference profiles. In practice, this generally means us-east-1, us-east-2 and us-west-2.
    # See https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-support.html for details.
    # Foundation model access must be allowed for these regions, and inference-profile access must be allowed for the deployed region.
    resources = [
      "arn:aws:bedrock:us-east-1::foundation-model/*",
      "arn:aws:bedrock:us-east-2::foundation-model/*",
      "arn:aws:bedrock:us-west-2::foundation-model/*",
      "arn:aws:bedrock:${local.region}:${local.aws_account_id}:inference-profile/*"
    ]
  }

  statement {
    sid    = "BedrockKnowledgeBaseRetrieve"
    effect = "Allow"
    actions = [
      "bedrock:Retrieve"
    ]
    # Wildcard required: KB ID is configured at runtime via SSM, and agents may need
    # cross-account/cross-region KB access. Actual access control is enforced by
    # KB resource policies - this permission just allows the Retrieve API call.
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "agent_bedrock_access" {
  for_each = var.agents

  name   = "bedrock-access"
  role   = aws_iam_role.agent_execution[each.key].id
  policy = data.aws_iam_policy_document.bedrock_access.json
}

# =============================================================================
# SSM PARAMETER ACCESS POLICY - For agents that need parameter store access
# =============================================================================

data "aws_iam_policy_document" "agent_parameter_access" {
  for_each = local.agents_with_parameters

  dynamic "statement" {
    for_each = length(each.value.parameter_arns) > 0 ? [1] : []
    content {
      sid    = "SSMParameterAccess"
      effect = "Allow"
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      resources = each.value.parameter_arns
    }
  }

  # KMS access for parameter decryption (if KMS key is configured)
  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      sid    = "KMSDecryptParameters"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      resources = [var.kms_key_arn]
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["ssm.${local.region}.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_role_policy" "agent_parameter_access" {
  for_each = local.agents_with_parameters

  name   = "parameter-access"
  role   = aws_iam_role.agent_execution[each.key].id
  policy = data.aws_iam_policy_document.agent_parameter_access[each.key].json
}

# =============================================================================
# X-RAY ACCESS POLICY - Required for all agents to send trace data
# =============================================================================

data "aws_iam_policy_document" "xray_access" {
  for_each = var.agents

  statement {
    sid    = "XRayTracing"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "agent_xray_access" {
  for_each = var.agents

  name   = "xray-access"
  role   = aws_iam_role.agent_execution[each.key].id
  policy = data.aws_iam_policy_document.xray_access[each.key].json
}

# =============================================================================
# S3 ACCESS POLICY - For shared bucket access (all agents)
# =============================================================================

data "aws_iam_policy_document" "agent_s3_access" {
  for_each = var.s3_bucket_arn != null ? var.agents : {}

  # ListBucket with prefix condition for listing objects, and unconditional for HeadBucket
  # Using StringLikeIfExists allows HeadBucket (which doesn't pass a prefix) while still
  # restricting ListObjects to specific prefixes
  statement {
    sid       = "S3ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.s3_bucket_arn]
    condition {
      test     = "StringLikeIfExists"
      variable = "s3:prefix"
      values   = concat(local.s3_read_paths, local.s3_write_paths)
    }
  }

  # Read access for config, docs, inputs (object-level operations)
  statement {
    sid       = "S3ReadConfigDocsInputs"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = [for path in local.s3_read_paths : "${var.s3_bucket_arn}/${path}"]
  }

  # Read/Write access for outputs (object-level operations)
  statement {
    sid    = "S3ReadWriteOutputs"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [for path in local.s3_write_paths : "${var.s3_bucket_arn}/${path}"]
  }

  # KMS access for S3 object encryption/decryption (if KMS key is configured)
  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      sid    = "KMSDecryptEncryptS3Objects"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ]
      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_role_policy" "agent_s3_access" {
  for_each = var.s3_bucket_arn != null ? var.agents : {}

  name   = "s3-access"
  role   = aws_iam_role.agent_execution[each.key].id
  policy = data.aws_iam_policy_document.agent_s3_access[each.key].json
}

# =============================================================================
# CLOUDWATCH LOGS ACCESS POLICY - Required for all agents to write logs
# =============================================================================

data "aws_iam_policy_document" "cloudwatch_logs_access" {
  for_each = var.agents

  # Allow describing log groups (global permission)
  statement {
    sid       = "DescribeLogGroups"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  # Allow creating log group for this specific agent runtime
  statement {
    sid    = "CreateLogGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup"
    ]
    resources = [
      "arn:aws:logs:${local.region}:${local.aws_account_id}:log-group:/aws/bedrock-agentcore/runtimes/${local.agent_runtime_names[each.key]}*"
    ]
  }

  # Allow creating log streams and putting log events for this agent runtime
  statement {
    sid    = "CreateLogStreamAndPutLogEvents"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${local.region}:${local.aws_account_id}:log-group:/aws/bedrock-agentcore/runtimes/${local.agent_runtime_names[each.key]}*:*"
    ]
  }

  # Allow describing log streams for this agent runtime
  statement {
    sid    = "DescribeLogStreams"
    effect = "Allow"
    actions = [
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${local.region}:${local.aws_account_id}:log-group:/aws/bedrock-agentcore/runtimes/${local.agent_runtime_names[each.key]}*"
    ]
  }
}

resource "aws_iam_role_policy" "agent_cloudwatch_logs_access" {
  for_each = var.agents

  name   = "cloudwatch-logs-access"
  role   = aws_iam_role.agent_execution[each.key].id
  policy = data.aws_iam_policy_document.cloudwatch_logs_access[each.key].json
}

# =============================================================================
# ADDITIONAL S3 BUCKET ACCESS - For agents needing access to extra S3 buckets
# =============================================================================

data "aws_iam_policy_document" "agent_additional_s3" {
  for_each = local.agents_with_s3

  statement {
    sid    = "AdditionalS3BucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = flatten([
      for bucket_arn in each.value.s3_bucket_arns : [
        bucket_arn,
        "${bucket_arn}/*"
      ]
    ])
  }
}

resource "aws_iam_role_policy" "agent_additional_s3" {
  for_each = local.agents_with_s3

  name   = "additional-s3-access"
  role   = aws_iam_role.agent_execution[each.key].id
  policy = data.aws_iam_policy_document.agent_additional_s3[each.key].json
}

# =============================================================================
# AGENT INVOCATION POLICY - For agents that need to invoke other agents
# Enables least-privilege agent-to-agent communication within the deployment
# =============================================================================

data "aws_iam_policy_document" "agent_invocation" {
  for_each = local.agents_with_invocation

  statement {
    sid    = "InvokeAgentRuntimes"
    effect = "Allow"
    actions = [
      "bedrock-agentcore:InvokeAgentRuntime",
      "bedrock-agentcore:InvokeAgentRuntimeWithWebSocketStream"
    ]
    # Grant access to both the runtime and all its endpoints for each target agent
    resources = flatten([
      for target_name in each.value.can_invoke : [
        # Runtime ARN
        module.agent[target_name].agent_runtime_arn,
        # All endpoints under this runtime (wildcard pattern)
        "${module.agent[target_name].agent_runtime_arn}/runtime-endpoint/*"
      ]
      if contains(keys(var.agents), target_name)
    ])
  }
}

resource "aws_iam_role_policy" "agent_invocation" {
  for_each = local.agents_with_invocation

  name   = "agent-invocation"
  role   = aws_iam_role.agent_execution[each.key].id
  policy = data.aws_iam_policy_document.agent_invocation[each.key].json
}

# =============================================================================
# CROSS-ACCOUNT KB ACCESS POLICY - For agents that need to query KB in build account
# Allows agents to assume the cross-account role for Knowledge Base queries
# =============================================================================

data "aws_iam_policy_document" "kb_cross_account_assume" {
  count = var.kb_cross_account_role_arn != null ? 1 : 0

  statement {
    sid       = "AssumeKBCrossAccountRole"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [var.kb_cross_account_role_arn]
  }
}

resource "aws_iam_role_policy" "agent_kb_cross_account" {
  for_each = var.kb_cross_account_role_arn != null ? var.agents : {}

  name   = "kb-cross-account-access"
  role   = aws_iam_role.agent_execution[each.key].id
  policy = data.aws_iam_policy_document.kb_cross_account_assume[0].json
}

# =============================================================================
# DYNAMODB LOCK ACCESS POLICY - For orchestrator execution lock
# Enables the primary orchestrator to acquire/release distributed locks in the
# assessments DynamoDB table to prevent concurrent execution for the same assessment.
# =============================================================================

data "aws_iam_policy_document" "orchestrator_dynamodb_lock" {
  # Only check var.handler_platform (not local.assessment_table_arn) to avoid count depending on module outputs
  count = var.handler_platform != "none" ? 1 : 0

  statement {
    sid    = "DynamoDBLockOperations"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ]
    resources = [
      local.assessment_table_arn,
      "${local.assessment_table_arn}/index/*"
    ]
  }
}

resource "aws_iam_role_policy" "orchestrator_dynamodb_lock" {
  count = var.handler_platform != "none" ? 1 : 0

  name   = "dynamodb-lock-access"
  role   = aws_iam_role.agent_execution[var.handler_config.primary_orchestrator_name].id
  policy = data.aws_iam_policy_document.orchestrator_dynamodb_lock[0].json
}
