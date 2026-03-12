# Bedrock Knowledge Base Resource
# Supports both S3_VECTORS and OPENSEARCH_SERVERLESS storage types
#
# For OPENSEARCH_SERVERLESS: Set create_knowledge_base = false on first apply
# to create the collection, then create the vector index externally,
# then set create_knowledge_base = true on second apply.

resource "aws_bedrockagent_knowledge_base" "this" {
  count = var.create_knowledge_base ? 1 : 0

  name        = var.name
  description = var.description
  role_arn    = local.role_arn

  knowledge_base_configuration {
    type = "VECTOR"

    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn

      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = var.embedding_dimensions
          embedding_data_type = var.embedding_data_type
        }
      }
    }
  }

  # Dynamic storage configuration based on vector_store_type
  storage_configuration {
    type = var.vector_store_type

    # S3 Vectors configuration (when vector_store_type = "S3_VECTORS")
    dynamic "s3_vectors_configuration" {
      for_each = var.vector_store_type == "S3_VECTORS" ? [1] : []
      content {
        index_arn = aws_s3vectors_index.knowledge_base[0].index_arn
      }
    }

    # OpenSearch Serverless configuration (when vector_store_type = "OPENSEARCH_SERVERLESS")
    dynamic "opensearch_serverless_configuration" {
      for_each = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? [1] : []
      content {
        collection_arn    = aws_opensearchserverless_collection.knowledge_base[0].arn
        vector_index_name = local.opensearch_index_name

        field_mapping {
          vector_field   = var.opensearch_vector_field_name
          text_field     = var.opensearch_text_field_name
          metadata_field = var.opensearch_metadata_field_name
        }
      }
    }
  }

  tags = local.common_tags

  depends_on = [
    # Common dependencies
    aws_iam_role_policy.bedrock_model_access,
    aws_iam_role_policy.s3_data_source_access,
    aws_iam_role_policy.kms_access,
    # S3 Vectors dependencies
    aws_iam_role_policy.s3_vectors_access,
    aws_s3vectors_index.knowledge_base,
    # OpenSearch Serverless dependencies
    # Note: The vector index must be created externally BEFORE the Knowledge Base
    # can be created. Use the opensearch_index_config output to create the index
    # with the opensearch provider, then re-apply to create the Knowledge Base.
    aws_iam_role_policy.opensearch_serverless_access,
    time_sleep.wait_for_collection
  ]
}