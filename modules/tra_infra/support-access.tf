# Coalfire Support Access Role
# Creates an IAM role in customer accounts that Coalfire support staff can assume
# for troubleshooting agent infrastructure. This role has read-only access to
# agent-related resources.

###############################################################################
# TRUST POLICY - Allows Coalfire support role to assume this role
###############################################################################

data "aws_iam_policy_document" "coalfire_support_assume_role" {
  count = var.grant_coalfire_support_access ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [var.coalfire_support_role_arn]
    }
  }
}

###############################################################################
# SUPPORT ACCESS ROLE
###############################################################################

resource "aws_iam_role" "coalfire_support" {
  count = var.grant_coalfire_support_access ? 1 : 0

  name               = "cf-support-readonly"
  description        = "Coalfire support read-only access role for troubleshooting ${var.deployment_name} agent infrastructure"
  assume_role_policy = data.aws_iam_policy_document.coalfire_support_assume_role[0].json

  tags = merge(
    var.tags,
    {
      Name       = "cf-support-readonly"
      Deployment = var.deployment_name
      Purpose    = "Coalfire support read-only access"
      ManagedBy  = "Terraform"
    }
  )
}

###############################################################################
# SUPPORT ACCESS POLICY - Read-only access to agent infrastructure
###############################################################################

data "aws_iam_policy_document" "coalfire_support_policy" {
  count = var.grant_coalfire_support_access ? 1 : 0

  # CloudWatch Logs - List log groups (requires broad resource for listing)
  statement {
    sid    = "CloudWatchLogsDescribe"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeQueries"
    ]
    resources = ["*"]
  }

  # CloudWatch Logs - Read access to specific agent log groups
  statement {
    sid    = "CloudWatchLogsRead"
    effect = "Allow"
    actions = [
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:StartQuery",
      "logs:GetQueryResults",
      "logs:StopQuery"
    ]
    resources = [
      "arn:aws:logs:${local.region}:${local.aws_account_id}:log-group:/aws/bedrock-agentcore/*",
      "arn:aws:logs:${local.region}:${local.aws_account_id}:log-group:/aws/bedrock-agentcore/*:*",
      "arn:aws:logs:${local.region}:${local.aws_account_id}:log-group:/aws/lambda/*-slack-handler*",
      "arn:aws:logs:${local.region}:${local.aws_account_id}:log-group:/aws/lambda/*-slack-handler*:*",
      "arn:aws:logs:${local.region}:${local.aws_account_id}:log-group:/aws/lambda/*-teams-handler*",
      "arn:aws:logs:${local.region}:${local.aws_account_id}:log-group:/aws/lambda/*-teams-handler*:*"
    ]
  }

  # CloudWatch Metrics - Read access to metrics
  statement {
    sid    = "CloudWatchMetricsRead"
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetDashboard",
      "cloudwatch:ListDashboards",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DescribeAlarmHistory"
    ]
    resources = ["*"]
  }

  # S3 - Read access to agents bucket
  dynamic "statement" {
    for_each = var.s3_bucket_arn != null ? [1] : []
    content {
      sid    = "S3ListBucket"
      effect = "Allow"
      actions = [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ]
      resources = [var.s3_bucket_arn]
    }
  }

  dynamic "statement" {
    for_each = var.s3_bucket_arn != null ? [1] : []
    content {
      sid       = "S3ReadObjects"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["${var.s3_bucket_arn}/*"]
    }
  }

  # SSM Parameters - Read access to agent parameters
  statement {
    sid    = "SSMParameterRead"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:DescribeParameters"
    ]
    resources = [
      "arn:aws:ssm:${local.region}:${local.aws_account_id}:parameter${var.handler_config != null ? var.handler_config.ssm_parameter_prefix : ""}/${var.deployment_name}/*"
    ]
  }

  # KMS - Decrypt access for SSM and S3
  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      sid    = "KMSDecrypt"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      resources = [var.kms_key_arn]
    }
  }

  # Bedrock AgentCore - Read access to agent resources
  statement {
    sid    = "BedrockAgentCoreRead"
    effect = "Allow"
    actions = [
      "bedrock-agentcore:GetAgentRuntime",
      "bedrock-agentcore:GetAgentRuntimeEndpoint",
      "bedrock-agentcore:ListAgentRuntimes",
      "bedrock-agentcore:ListAgentRuntimeEndpoints",
      "bedrock-agentcore:GetMemory",
      "bedrock-agentcore:ListMemories"
    ]
    resources = ["*"]
  }

  # X-Ray - Read access to traces
  statement {
    sid    = "XRayRead"
    effect = "Allow"
    actions = [
      "xray:GetTraceSummaries",
      "xray:BatchGetTraces",
      "xray:GetServiceGraph",
      "xray:GetTraceGraph"
    ]
    resources = ["*"]
  }

  # Lambda - List functions (requires broad resource for listing)
  statement {
    sid    = "LambdaList"
    effect = "Allow"
    actions = [
      "lambda:ListFunctions"
    ]
    resources = ["*"]
  }

  # Lambda - Read access to specific handler functions
  statement {
    sid    = "LambdaRead"
    effect = "Allow"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration"
    ]
    resources = [
      "arn:aws:lambda:${local.region}:${local.aws_account_id}:function:*-slack-handler*",
      "arn:aws:lambda:${local.region}:${local.aws_account_id}:function:*-teams-handler*"
    ]
  }

  # DynamoDB - Read access to handler tables
  statement {
    sid    = "DynamoDBRead"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan"
    ]
    resources = [
      "arn:aws:dynamodb:${local.region}:${local.aws_account_id}:table/*-slack-assessments",
      "arn:aws:dynamodb:${local.region}:${local.aws_account_id}:table/*-teams-assessments"
    ]
  }

  # IAM - Read access to view agent execution roles
  statement {
    sid    = "IAMRead"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies"
    ]
    resources = [
      "arn:aws:iam::${local.aws_account_id}:role/${var.deployment_name}-*"
    ]
  }
}

resource "aws_iam_role_policy" "coalfire_support" {
  count = var.grant_coalfire_support_access ? 1 : 0

  name   = "coalfire-support-read-only"
  role   = aws_iam_role.coalfire_support[0].id
  policy = data.aws_iam_policy_document.coalfire_support_policy[0].json
}
