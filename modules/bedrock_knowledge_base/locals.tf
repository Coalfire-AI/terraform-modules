# Locals for Bedrock Knowledge Base Module

locals {
  # Resource naming
  vector_bucket_name      = coalesce(var.vector_bucket_name, "${var.name}-vectors")
  vector_index_name       = coalesce(var.vector_index_name, "${var.name}-index")
  data_source_bucket_name = coalesce(var.data_source_bucket_name, "${var.name}-documents")
  iam_role_name           = "AWS_Bedrock_Exec_KB_${var.name}"

  # Embedding model ARN construction
  embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.id}::foundation-model/${var.embedding_model_id}"

  # Parsing model ARN construction (for Foundation Model parsing)
  # Only set when parsing_strategy = BEDROCK_FOUNDATION_MODEL
  # Priority: 1) User-provided full ARN, 2) Auto-construct from parsing_model_id
  parsing_model_arn = var.parsing_strategy == "BEDROCK_FOUNDATION_MODEL" ? coalesce(
    var.parsing_model_arn,
    "arn:aws:bedrock:${data.aws_region.current.id}::foundation-model/${var.parsing_model_id}"
  ) : null

  # Vector data type mapping (Terraform uses lowercase)
  vector_data_type = lower(var.embedding_data_type)

  # S3 Vectors non-filterable metadata keys
  # CRITICAL: AMAZON_BEDROCK_TEXT and AMAZON_BEDROCK_METADATA MUST be non-filterable
  # to avoid the 2KB filterable metadata limit error during ingestion.
  # Bedrock stores chunk text in these fields which typically exceeds 2KB.
  # User-defined non-filterable fields are appended after the required Bedrock fields.
  s3_vectors_non_filterable_keys = distinct(concat(
    ["AMAZON_BEDROCK_TEXT", "AMAZON_BEDROCK_METADATA"],
    [for field in var.s3_vectors_metadata_fields.non_filterable_fields : field.name]
  ))

  # KMS key to use
  kms_key_arn = var.create_kms_key ? aws_kms_key.knowledge_base[0].arn : var.kms_key_arn

  # IAM role to use
  role_arn = var.create_iam_role ? aws_iam_role.knowledge_base[0].arn : var.role_arn

  # Data source bucket ARN
  data_source_bucket_arn = var.create_data_source_bucket ? aws_s3_bucket.data_source[0].arn : var.data_source_bucket_arn

  # Effective inclusion prefixes for the data source
  # Priority: 1) User-specified prefixes 2) Auto-prefix based on enable_preprocessing
  # When preprocessing enabled: read from processed/ prefix (output of Lambda)
  # When preprocessing disabled: read from raw/ prefix (source documents)
  effective_inclusion_prefixes = coalesce(
    length(var.data_source_inclusion_prefixes) > 0 ? var.data_source_inclusion_prefixes : null,
    var.enable_preprocessing ? [var.processed_documents_prefix] : [var.raw_documents_prefix]
  )

  # Custom transformation: intermediate storage bucket ARN (use provided or fall back to data source bucket)
  intermediate_storage_bucket_arn = coalesce(
    var.intermediate_storage_bucket_arn,
    local.data_source_bucket_arn
  )

  # Custom transformation: S3 URI for intermediate storage
  # Extract bucket name from the resolved intermediate storage ARN
  intermediate_storage_bucket_name = var.enable_custom_transformation ? regex("arn:aws:s3:::(.+)", local.intermediate_storage_bucket_arn)[0] : null

  intermediate_storage_uri = var.enable_custom_transformation ? "s3://${local.intermediate_storage_bucket_name}/${var.intermediate_storage_prefix}" : null

  # OpenSearch Serverless configuration
  opensearch_collection_name = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? coalesce(
    var.opensearch_collection_name,
    lower(replace(var.name, "_", "-"))
  ) : null

  opensearch_index_name = var.opensearch_index_name

  # Map Terraform distance metric to OpenSearch space type
  opensearch_space_type = {
    "cosine"      = "cosinesimil"
    "euclidean"   = "l2"
    "dot_product" = "innerproduct"
  }[var.vector_distance_metric]

  # Common tags
  common_tags = merge(
    {
      ManagedBy       = "Terraform"
      KnowledgeBase   = var.name
      VectorStoreType = var.vector_store_type
    },
    var.tags
  )
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}