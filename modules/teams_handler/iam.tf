# Teams Handler Module - IAM Resources

# -----------------------------------------------------------------------------
# Lambda Execution Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "teams_handler" {
  name = "${var.deployment_name}-teams-handler"

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
  role       = aws_iam_role.teams_handler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC access (if VPC config provided)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.teams_handler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom policy for Teams handler
resource "aws_iam_role_policy" "teams_handler" {
  name = "teams-handler-policy"
  role = aws_iam_role.teams_handler.id

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
      {
        Sid    = "AgentCoreInvoke"
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:InvokeAgentRuntime",
          "bedrock-agentcore:InvokeAgentRuntimeWithWebSocketStream"
        ]
        Resource = var.primary_orchestrator_arn
      },

      # SSM Parameter access for Teams credentials
      {
        Sid    = "SSMParameterAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter${var.ssm_parameter_prefix}/${var.deployment_name}/teams-*"
        ]
      }
    ]
  })
}

# KMS decrypt policy (only created if KMS key is provided)
resource "aws_iam_role_policy" "kms_decrypt" {
  count = var.kms_key_arn != null ? 1 : 0
  name  = "teams-handler-kms-policy"
  role  = aws_iam_role.teams_handler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "KMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [var.kms_key_arn]
      }
    ]
  })
}

# ECR access policy for cross-account container image pull
# Required when Lambda pulls container images from ECR in another account
resource "aws_iam_role_policy" "ecr_access" {
  name = "teams-handler-ecr-policy"
  role = aws_iam_role.teams_handler.id

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
