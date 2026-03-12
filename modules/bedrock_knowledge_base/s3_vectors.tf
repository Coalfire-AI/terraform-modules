# S3 Vector Bucket and Index for Bedrock Knowledge Base
# Only created when vector_store_type = "S3_VECTORS"

resource "aws_s3vectors_vector_bucket" "knowledge_base" {
  count = var.vector_store_type == "S3_VECTORS" ? 1 : 0

  vector_bucket_name = local.vector_bucket_name

  encryption_configuration {
    sse_type    = "aws:kms"
    kms_key_arn = local.kms_key_arn
  }

  tags = local.common_tags
}

resource "aws_s3vectors_index" "knowledge_base" {
  count = var.vector_store_type == "S3_VECTORS" ? 1 : 0

  index_name         = local.vector_index_name
  vector_bucket_name = aws_s3vectors_vector_bucket.knowledge_base[0].vector_bucket_name

  dimension       = var.embedding_dimensions
  distance_metric = var.vector_distance_metric
  data_type       = local.vector_data_type

  # CRITICAL: Configure metadata to avoid 2KB filterable limit error
  # Bedrock stores chunk text in AMAZON_BEDROCK_TEXT which exceeds 2KB.
  # By marking it as non-filterable, it moves to the 40KB storage tier.
  # See: modules/bedrock_knowledge_base/docs/s3-vectors-metadata-limitation.md
  metadata_configuration {
    non_filterable_metadata_keys = local.s3_vectors_non_filterable_keys
  }

  depends_on = [aws_s3vectors_vector_bucket.knowledge_base]
}