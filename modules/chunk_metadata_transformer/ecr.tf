# ECR Repository for Chunk Metadata Transformer Lambda

# =============================================================================
# ECR Repository
# =============================================================================

resource "aws_ecr_repository" "lambda" {
  count = var.create_ecr_repository ? 1 : 0

  name                 = local.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # Enable encryption with AWS managed key
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

# =============================================================================
# ECR Lifecycle Policy
# =============================================================================

resource "aws_ecr_lifecycle_policy" "lambda" {
  count = var.create_ecr_repository ? 1 : 0

  repository = aws_ecr_repository.lambda[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}