# ECR Repository for Lambda Container Image

# =============================================================================
# ECR Repository
# =============================================================================

resource "aws_ecr_repository" "lambda" {
  count = var.create_ecr_repository ? 1 : 0

  name                 = local.ecr_repository_name
  image_tag_mutability = var.ecr_image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.ecr_scan_on_push
  }

  encryption_configuration {
    encryption_type = var.kms_key_arn != null ? "KMS" : "AES256"
    kms_key         = var.kms_key_arn
  }

  tags = local.common_tags
}

# =============================================================================
# ECR Lifecycle Policy (keep last 10 images)
# =============================================================================

resource "aws_ecr_lifecycle_policy" "lambda" {
  count = var.create_ecr_repository ? 1 : 0

  repository = aws_ecr_repository.lambda[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# =============================================================================
# ECR Repository Policy (allow Lambda service to pull)
# =============================================================================

resource "aws_ecr_repository_policy" "lambda" {
  count = var.create_ecr_repository ? 1 : 0

  repository = aws_ecr_repository.lambda[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaECRImageRetrievalPolicy"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Condition = {
          StringLike = {
            "aws:sourceArn" = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:${local.function_name}"
          }
        }
      }
    ]
  })
}