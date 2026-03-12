# Local Values for Chunk Metadata Transformer Module

locals {
  # Resource naming
  function_name       = coalesce(var.function_name, "${var.name}-chunk-transformer")
  ecr_repository_name = coalesce(var.ecr_repository_name, "${var.name}-chunk-transformer")
  iam_role_name       = coalesce(var.iam_role_name, "${var.name}-chunk-transformer-role")

  # Architecture
  architectures = var.use_graviton ? ["arm64"] : ["x86_64"]

  # Resolved image URI for Lambda function
  # image_uri is required - local Docker builds are not supported
  # See .github/workflows/examples/lambda-images-build.yml.example for CI/CD workflow
  resolved_image_uri = var.image_uri

  # Environment variables for Lambda
  environment_variables = {
    LOG_LEVEL             = var.log_level
    COMPLIANCE_FRAMEWORK  = var.compliance_framework
    DEFAULT_DOCUMENT_TYPE = var.default_document_type
  }

  # Common tags for all resources
  common_tags = merge(
    {
      Module    = "chunk_metadata_transformer"
      ManagedBy = "terraform"
      Purpose   = "POST_CHUNKING transformation for Bedrock KB"
    },
    var.tags
  )
}

# Data sources
data "aws_caller_identity" "current" {}