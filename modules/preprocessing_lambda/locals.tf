# Local Values for Preprocessing Lambda Module

locals {
  # Naming
  function_name = var.function_name != null ? var.function_name : "${var.name}-preprocessing"

  # ECR Repository
  ecr_repository_name = var.ecr_repository_name != null ? var.ecr_repository_name : "${var.name}-preprocessing"

  # IAM
  iam_role_name = var.iam_role_name != null ? var.iam_role_name : "${var.name}-preprocessing-role"

  # Resolved image URI for Lambda function
  # image_uri is required - local Docker builds are not supported
  # See .github/workflows/examples/lambda-images-build.yml.example for CI/CD workflow
  resolved_image_uri = var.image_uri

  # S3 Prefixes (ensure trailing slash)
  raw_prefix       = endswith(var.raw_documents_prefix, "/") ? var.raw_documents_prefix : "${var.raw_documents_prefix}/"
  processed_prefix = endswith(var.processed_documents_prefix, "/") ? var.processed_documents_prefix : "${var.processed_documents_prefix}/"

  # Architecture mapping for Lambda
  architectures = var.use_graviton ? ["arm64"] : ["x86_64"]

  # Environment variables for Lambda
  # Uses universal extractor which supports multiple frameworks
  environment_variables = merge(
    {
      OUTPUT_BUCKET        = var.output_bucket_name != null ? var.output_bucket_name : var.source_bucket_name
      OUTPUT_PREFIX        = local.processed_prefix
      EXTRACT_METADATA     = tostring(var.extract_nist_metadata)
      ENABLED_FRAMEWORKS   = var.enabled_frameworks
      METADATA_OUTPUT_MODE = var.metadata_output_mode
      LOG_LEVEL            = var.log_level

      # Chunking configuration
      ENABLE_CHUNKING      = tostring(var.enable_chunking)
      CHUNK_SIZE_TOKENS    = tostring(var.chunk_size_tokens)
      OVERLAP_TOKENS       = tostring(var.chunk_overlap_tokens)
      ENABLE_SECTION_AWARE = tostring(var.enable_section_aware_chunking)
      SECTION_MAX_TOKENS   = tostring(var.section_max_tokens)
      SECTIONS_TO_PRESERVE = var.sections_to_preserve
    },
    var.additional_environment_variables
  )

  # Common tags
  common_tags = merge(
    {
      Module    = "preprocessing-lambda"
      ManagedBy = "terraform"
    },
    var.tags
  )
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}
