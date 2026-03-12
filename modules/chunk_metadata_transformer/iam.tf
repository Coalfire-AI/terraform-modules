# IAM Resources for Chunk Metadata Transformer Lambda

# =============================================================================
# IAM Role for Lambda
# =============================================================================

resource "aws_iam_role" "lambda" {
  count = var.create_iam_role ? 1 : 0

  name = local.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# =============================================================================
# CloudWatch Logs Policy
# =============================================================================

resource "aws_iam_role_policy" "cloudwatch_logs" {
  count = var.create_iam_role ? 1 : 0

  name = "${local.function_name}-cloudwatch-logs"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.lambda.arn,
          "${aws_cloudwatch_log_group.lambda.arn}:*"
        ]
      }
    ]
  })
}

# =============================================================================
# S3 Intermediate Storage Policy
# =============================================================================
# Bedrock writes chunked content to intermediate storage before Lambda processes it
# Lambda needs read access to get chunks and write access to store transformed results

resource "aws_iam_role_policy" "s3_intermediate" {
  count = var.create_iam_role ? 1 : 0

  name = "${local.function_name}-s3-intermediate"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadIntermediateContent"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          var.intermediate_storage_bucket_arn,
          "${var.intermediate_storage_bucket_arn}/${var.intermediate_storage_prefix}*"
        ]
      },
      {
        Sid    = "WriteTransformedContent"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.intermediate_storage_bucket_arn}/${var.intermediate_storage_prefix}*"
        ]
      }
    ]
  })
}

# =============================================================================
# KMS Access Policy (for encrypted intermediate storage)
# =============================================================================

resource "aws_iam_role_policy" "kms_access" {
  count = var.create_iam_role && var.kms_key_arn != null ? 1 : 0

  name = "${local.function_name}-kms-access"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSDecryptEncrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# =============================================================================
# VPC Access Policy (if needed for future VPC deployment)
# =============================================================================

# Uncomment if Lambda needs VPC access
# resource "aws_iam_role_policy_attachment" "vpc_access" {
#   count = var.create_iam_role && var.vpc_config != null ? 1 : 0
#
#   role       = aws_iam_role.lambda[0].name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
# }