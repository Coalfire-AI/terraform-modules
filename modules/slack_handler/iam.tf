# Slack Handler Module - IAM Resources

# -----------------------------------------------------------------------------
# Lambda Execution Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "slack_handler" {
  name = "${var.deployment_name}-slack-handler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

# Basic Lambda execution (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.slack_handler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC access (if VPC config provided)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.slack_handler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom policy for Slack handler
resource "aws_iam_role_policy" "slack_handler" {
  name = "slack-handler-policy"
  role = aws_iam_role.slack_handler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # DynamoDB access for assessment mappings
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          aws_dynamodb_table.assessments.arn,
          "${aws_dynamodb_table.assessments.arn}/index/*"
        ]
      },

      # AgentCore invocation for primary_orchestrator
      # Includes both runtime ARN and endpoint ARN pattern (matching agent IAM policies)
      {
        Sid    = "AgentCoreInvoke"
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:InvokeAgentRuntime",
          "bedrock-agentcore:InvokeAgentRuntimeWithWebSocketStream"
        ]
        Resource = [
          var.primary_orchestrator_arn,
          "${var.primary_orchestrator_arn}/runtime-endpoint/*"
        ]
      },

      # SSM Parameter access for Slack credentials
      {
        Sid    = "SSMParameterAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter${var.ssm_parameter_prefix}/${var.deployment_name}/slack-*"
        ]
      }
    ]
  })
}

# KMS policy for S3 operations (only created if KMS key is provided)
# Decrypt: needed for reading S3 objects (docs, templates, outputs, inputs)
# GenerateDataKey: needed for writing S3 objects (file uploads to inputs/)
resource "aws_iam_role_policy" "kms_decrypt" {
  count = var.kms_key_arn != null ? 1 : 0
  name  = "slack-handler-kms-policy"
  role  = aws_iam_role.slack_handler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "KMSDecryptAndEncrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [var.kms_key_arn]
      }
    ]
  })
}

# S3 read access for documentation, templates, assessment outputs, and inputs (only created if bucket is provided)
# Enables /tra docs, /tra templates, /tra assessments, /tra completed, and /tra initiate (artifact check) commands
resource "aws_iam_role_policy" "s3_read" {
  count = var.object_store_bucket_arn != null ? 1 : 0
  name  = "slack-handler-s3-read-policy"
  role  = aws_iam_role.slack_handler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [var.object_store_bucket_arn]
        Condition = {
          StringLike = {
            "s3:prefix" = ["docs/*", "config/templates/*", "outputs/*", "inputs/*"]
          }
        }
      },
      {
        Sid    = "S3GetObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "${var.object_store_bucket_arn}/docs/*",
          "${var.object_store_bucket_arn}/config/templates/*",
          "${var.object_store_bucket_arn}/outputs/*",
          "${var.object_store_bucket_arn}/inputs/*"
        ]
      }
    ]
  })
}

# S3 write access for file uploads (only created if bucket is provided)
# Enables /tra upload command to store files in assessment input folders
resource "aws_iam_role_policy" "s3_write" {
  count = var.object_store_bucket_arn != null ? 1 : 0
  name  = "slack-handler-s3-write-policy"
  role  = aws_iam_role.slack_handler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3PutInputs"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = [
          "${var.object_store_bucket_arn}/inputs/*"
        ]
      }
    ]
  })
}

# Lambda self-invoke for Slack Bolt lazy listeners
# Required so that long-running handlers (e.g., file upload) can ack() immediately
# and then re-invoke the Lambda asynchronously for the heavy I/O work.
resource "aws_iam_role_policy" "lambda_self_invoke" {
  name = "slack-handler-self-invoke-policy"
  role = aws_iam_role.slack_handler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LambdaSelfInvoke"
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = [aws_lambda_function.slack_handler.arn]
      }
    ]
  })
}

# ECR access policy for cross-account container image pull
# Required when Lambda pulls container images from ECR in another account
resource "aws_iam_role_policy" "ecr_access" {
  name = "slack-handler-ecr-policy"
  role = aws_iam_role.slack_handler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRGetAuthorizationToken"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      },
      {
        Sid    = "ECRPullImage"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        # Allow pulling from any ECR repository - repository policies control actual access
        Resource = ["*"]
      }
    ]
  })
}
