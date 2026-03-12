# IAM Role and Policies for Preprocessing Lambda

# =============================================================================
# Lambda Execution Role
# =============================================================================

resource "aws_iam_role" "lambda" {
  count = var.create_iam_role ? 1 : 0

  name = local.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
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

  name = "${var.name}-cloudwatch-logs"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.function_name}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.function_name}:*"
        ]
      }
    ]
  })
}

# =============================================================================
# S3 Read Policy (Source Bucket)
# =============================================================================

resource "aws_iam_role_policy" "s3_source_read" {
  count = var.create_iam_role ? 1 : 0

  name = "${var.name}-s3-source-read"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ListSourceBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = var.source_bucket_arn
        Condition = {
          StringLike = {
            "s3:prefix" = "${local.raw_prefix}*"
          }
        }
      },
      {
        Sid    = "S3GetSourceObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${var.source_bucket_arn}/${local.raw_prefix}*"
      }
    ]
  })
}

# =============================================================================
# S3 Write Policy (Output Bucket)
# =============================================================================

resource "aws_iam_role_policy" "s3_output_write" {
  count = var.create_iam_role ? 1 : 0

  name = "${var.name}-s3-output-write"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3PutProcessedObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${coalesce(var.output_bucket_arn, var.source_bucket_arn)}/${local.processed_prefix}*"
      }
    ]
  })
}

# =============================================================================
# KMS Policy (if KMS key provided)
# =============================================================================

resource "aws_iam_role_policy" "kms_access" {
  count = var.create_iam_role && var.enable_kms ? 1 : 0

  name = "${var.name}-kms-access"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSDecryptEncrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# =============================================================================
# DLQ Policy (if DLQ enabled)
# =============================================================================

resource "aws_iam_role_policy" "dlq_access" {
  count = var.create_iam_role && var.enable_dlq ? 1 : 0

  name = "${var.name}-dlq-access"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQSSendMessage"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = var.dlq_arn != null ? var.dlq_arn : aws_sqs_queue.dlq[0].arn
      }
    ]
  })
}

# =============================================================================
# X-Ray Tracing Policy (if enabled)
# =============================================================================

resource "aws_iam_role_policy" "xray_tracing" {
  count = var.create_iam_role && var.enable_xray_tracing ? 1 : 0

  name = "${var.name}-xray-tracing"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "XRayTracing"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# ECR Pull Policy (for container images)
# =============================================================================

resource "aws_iam_role_policy" "ecr_pull" {
  count = var.create_iam_role ? 1 : 0

  name = "${var.name}-ecr-pull"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRGetAuthToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPullImage"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = var.create_ecr_repository ? aws_ecr_repository.lambda[0].arn : var.ecr_repository_arn
      }
    ]
  })
}

# =============================================================================
# Additional Policy Attachments
# =============================================================================

resource "aws_iam_role_policy_attachment" "additional" {
  count = var.create_iam_role ? length(var.additional_iam_policies) : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = var.additional_iam_policies[count.index]
}