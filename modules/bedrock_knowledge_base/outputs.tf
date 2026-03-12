# Outputs for Bedrock Knowledge Base Module

# =============================================================================
# Knowledge Base Outputs
# =============================================================================

output "knowledge_base_id" {
  description = "The unique identifier of the knowledge base (null if create_knowledge_base = false)"
  value       = var.create_knowledge_base ? aws_bedrockagent_knowledge_base.this[0].id : null
}

output "knowledge_base_arn" {
  description = "The ARN of the knowledge base (null if create_knowledge_base = false)"
  value       = var.create_knowledge_base ? aws_bedrockagent_knowledge_base.this[0].arn : null
}

output "knowledge_base_name" {
  description = "The name of the knowledge base"
  value       = var.name
}

output "knowledge_base_created" {
  description = "Whether the knowledge base was created (use for conditional logic in calling modules)"
  value       = var.create_knowledge_base
}

# =============================================================================
# Data Source Outputs
# =============================================================================

output "data_source_id" {
  description = "The unique identifier of the data source (null if create_knowledge_base = false)"
  value       = var.create_knowledge_base ? aws_bedrockagent_data_source.s3[0].data_source_id : null
}

output "data_source_bucket_arn" {
  description = "The ARN of the S3 bucket used as data source"
  value       = local.data_source_bucket_arn
}

output "data_source_bucket_name" {
  description = "The name of the S3 bucket used as data source"
  value = var.create_data_source_bucket ? aws_s3_bucket.data_source[0].id : (
    # Extract bucket name from ARN format: arn:aws:s3:::bucket-name
    var.data_source_bucket_arn != null ? replace(var.data_source_bucket_arn, "/^arn:aws:s3:::/", "") : null
  )
}

# =============================================================================
# Vector Store Type Output
# =============================================================================

output "vector_store_type" {
  description = "The type of vector store being used (S3_VECTORS or OPENSEARCH_SERVERLESS)"
  value       = var.vector_store_type
}

# =============================================================================
# S3 Vectors Outputs (only populated when vector_store_type = "S3_VECTORS")
# =============================================================================

output "vector_bucket_arn" {
  description = "The ARN of the S3 vector bucket (null if using OpenSearch Serverless)"
  value       = var.vector_store_type == "S3_VECTORS" ? aws_s3vectors_vector_bucket.knowledge_base[0].vector_bucket_arn : null
}

output "vector_bucket_name" {
  description = "The name of the S3 vector bucket (null if using OpenSearch Serverless)"
  value       = var.vector_store_type == "S3_VECTORS" ? aws_s3vectors_vector_bucket.knowledge_base[0].vector_bucket_name : null
}

output "vector_index_arn" {
  description = "The ARN of the S3 vector index (null if using OpenSearch Serverless)"
  value       = var.vector_store_type == "S3_VECTORS" ? aws_s3vectors_index.knowledge_base[0].index_arn : null
}

output "vector_index_name" {
  description = "The name of the vector index (applies to both S3 Vectors and OpenSearch)"
  value       = var.vector_store_type == "S3_VECTORS" ? aws_s3vectors_index.knowledge_base[0].index_name : local.opensearch_index_name
}

# =============================================================================
# OpenSearch Serverless Outputs (only populated when vector_store_type = "OPENSEARCH_SERVERLESS")
# =============================================================================

output "opensearch_collection_arn" {
  description = "The ARN of the OpenSearch Serverless collection (null if using S3 Vectors)"
  value       = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? aws_opensearchserverless_collection.knowledge_base[0].arn : null
}

output "opensearch_collection_id" {
  description = "The ID of the OpenSearch Serverless collection (null if using S3 Vectors)"
  value       = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? aws_opensearchserverless_collection.knowledge_base[0].id : null
}

output "opensearch_collection_endpoint" {
  description = "The endpoint URL of the OpenSearch Serverless collection (null if using S3 Vectors)"
  value       = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? aws_opensearchserverless_collection.knowledge_base[0].collection_endpoint : null
}

output "opensearch_dashboard_endpoint" {
  description = "The dashboard endpoint URL of the OpenSearch Serverless collection (null if using S3 Vectors)"
  value       = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? aws_opensearchserverless_collection.knowledge_base[0].dashboard_endpoint : null
}

output "opensearch_collection_name" {
  description = "The name of the OpenSearch Serverless collection (null if using S3 Vectors)"
  value       = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? local.opensearch_collection_name : null
}

output "opensearch_index_name" {
  description = "The name of the OpenSearch vector index (null if using S3 Vectors)"
  value       = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? local.opensearch_index_name : null
}

output "opensearch_index_mapping" {
  description = "The JSON mapping configuration for creating the OpenSearch vector index. Use with opensearch provider or OpenSearch Dashboards. (null if using S3 Vectors)"
  value       = local.opensearch_index_mapping
}

output "opensearch_index_config" {
  description = "Complete configuration for creating the OpenSearch vector index. Includes endpoint, index name, role ARN, and field names. (null if using S3 Vectors)"
  value = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? {
    collection_endpoint = try(aws_opensearchserverless_collection.knowledge_base[0].collection_endpoint, null)
    index_name          = local.opensearch_index_name
    role_arn            = local.role_arn
    vector_field_name   = var.opensearch_vector_field_name
    text_field_name     = var.opensearch_text_field_name
    metadata_field_name = var.opensearch_metadata_field_name
    vector_dimensions   = var.embedding_dimensions
    distance_metric     = var.vector_distance_metric
    index_mapping       = local.opensearch_index_mapping
  } : null
}

# =============================================================================
# IAM Outputs
# =============================================================================

output "iam_role_arn" {
  description = "The ARN of the IAM role used by the knowledge base"
  value       = local.role_arn
}

output "iam_role_name" {
  description = "The name of the IAM role used by the knowledge base"
  value       = var.create_iam_role ? aws_iam_role.knowledge_base[0].name : null
}

# =============================================================================
# KMS Outputs
# =============================================================================

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = local.kms_key_arn
}

output "kms_key_id" {
  description = "The ID of the KMS key used for encryption"
  value       = var.create_kms_key ? aws_kms_key.knowledge_base[0].key_id : null
}

output "kms_key_alias" {
  description = "The alias of the KMS key"
  value       = var.create_kms_key ? aws_kms_alias.knowledge_base[0].name : null
}

# =============================================================================
# Embedding Model Outputs
# =============================================================================

output "embedding_model_arn" {
  description = "The ARN of the embedding model used"
  value       = local.embedding_model_arn
}

output "embedding_dimensions" {
  description = "The number of dimensions in the embedding vectors"
  value       = var.embedding_dimensions
}

# =============================================================================
# Configuration Outputs
# =============================================================================

output "chunking_strategy" {
  description = "The chunking strategy used for document processing"
  value       = var.chunking_strategy
}

output "parsing_strategy" {
  description = "The parsing strategy used for document processing (DEFAULT or BEDROCK_FOUNDATION_MODEL)"
  value       = var.parsing_strategy
}

output "parsing_model_arn" {
  description = "The ARN of the foundation model used for document parsing (null if using DEFAULT strategy)"
  value       = local.parsing_model_arn
}

output "parsing_model_id" {
  description = "The model ID used for document parsing"
  value       = var.parsing_strategy == "BEDROCK_FOUNDATION_MODEL" ? var.parsing_model_id : null
}

# =============================================================================
# Feature Flag Outputs
# =============================================================================

output "preprocessing_enabled" {
  description = "Whether preprocessing pipeline is enabled (reads from processed/ prefix)"
  value       = var.enable_preprocessing
}

output "custom_transformation_enabled" {
  description = "Whether Bedrock-native custom Lambda transformation is enabled"
  value       = var.enable_custom_transformation
}

# =============================================================================
# S3 URI Outputs
# =============================================================================

output "raw_documents_s3_uri" {
  description = "S3 URI for raw document uploads"
  value       = var.create_data_source_bucket ? "s3://${aws_s3_bucket.data_source[0].id}/${var.raw_documents_prefix}" : null
}

output "processed_documents_s3_uri" {
  description = "S3 URI for preprocessed documents (output from preprocessing Lambda)"
  value       = var.create_data_source_bucket ? "s3://${aws_s3_bucket.data_source[0].id}/${var.processed_documents_prefix}" : null
}

output "effective_inclusion_prefixes" {
  description = "The S3 prefixes that the data source is configured to read from"
  value       = local.effective_inclusion_prefixes
}

output "intermediate_storage_uri" {
  description = "S3 URI for intermediate transformation storage (when custom transformation is enabled)"
  value       = local.intermediate_storage_uri
}

# =============================================================================
# Logging Outputs
# =============================================================================

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for knowledge base logs"
  value       = var.enable_logging ? aws_cloudwatch_log_group.knowledge_base[0].name : null
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group for knowledge base logs"
  value       = var.enable_logging ? aws_cloudwatch_log_group.knowledge_base[0].arn : null
}

output "logging_enabled" {
  description = "Whether CloudWatch logging is enabled for the knowledge base"
  value       = var.enable_logging
}