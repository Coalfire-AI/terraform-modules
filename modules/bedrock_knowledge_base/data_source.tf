# Data Source Connector for Bedrock Knowledge Base
# Only created when the Knowledge Base itself is created

resource "aws_bedrockagent_data_source" "s3" {
  count = var.create_knowledge_base ? 1 : 0

  name              = "${var.name}-s3-source"
  knowledge_base_id = aws_bedrockagent_knowledge_base.this[0].id
  description       = "S3 data source for ${var.name} knowledge base"

  data_deletion_policy = var.data_deletion_policy

  data_source_configuration {
    type = "S3"

    s3_configuration {
      bucket_arn         = local.data_source_bucket_arn
      inclusion_prefixes = local.effective_inclusion_prefixes
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = var.chunking_strategy

      # FIXED_SIZE chunking configuration
      dynamic "fixed_size_chunking_configuration" {
        for_each = var.chunking_strategy == "FIXED_SIZE" ? [1] : []
        content {
          max_tokens         = var.chunk_max_tokens
          overlap_percentage = var.chunk_overlap_percentage
        }
      }

      # SEMANTIC chunking configuration
      # Best for NIST docs - preserves semantic context boundaries
      dynamic "semantic_chunking_configuration" {
        for_each = var.chunking_strategy == "SEMANTIC" ? [1] : []
        content {
          max_token                       = var.semantic_max_tokens
          buffer_size                     = var.semantic_buffer_size
          breakpoint_percentile_threshold = var.semantic_breakpoint_threshold
        }
      }

      # HIERARCHICAL chunking configuration
      # Creates parent/child chunk relationships for better context retrieval
      dynamic "hierarchical_chunking_configuration" {
        for_each = var.chunking_strategy == "HIERARCHICAL" ? [1] : []
        content {
          level_configuration {
            max_tokens = var.hierarchical_parent_max_tokens
          }
          level_configuration {
            max_tokens = var.hierarchical_child_max_tokens
          }
          overlap_tokens = var.hierarchical_overlap_tokens
        }
      }
    }

    # Custom transformation configuration (Bedrock-native Lambda invocation)
    # Enables custom processing during ingestion via Lambda function
    dynamic "custom_transformation_configuration" {
      for_each = var.enable_custom_transformation ? [1] : []
      content {
        intermediate_storage {
          s3_location {
            uri = local.intermediate_storage_uri
          }
        }

        transformation {
          transformation_function {
            transformation_lambda_configuration {
              lambda_arn = var.transformation_lambda_arn
            }
          }
          step_to_apply = var.transformation_step
        }
      }
    }

    # Parsing configuration (Foundation Model parsing)
    # Enables multimodal parsing of complex documents with tables and figures
    # Uses Claude or Nova models for superior extraction accuracy
    dynamic "parsing_configuration" {
      for_each = var.parsing_strategy == "BEDROCK_FOUNDATION_MODEL" ? [1] : []
      content {
        parsing_strategy = "BEDROCK_FOUNDATION_MODEL"

        bedrock_foundation_model_configuration {
          model_arn = local.parsing_model_arn

          dynamic "parsing_prompt" {
            for_each = var.parsing_prompt_override != null ? [1] : []
            content {
              parsing_prompt_string = var.parsing_prompt_override
            }
          }
        }
      }
    }
  }

  # Server-side encryption for the data source
  dynamic "server_side_encryption_configuration" {
    for_each = local.kms_key_arn != null ? [1] : []
    content {
      kms_key_arn = local.kms_key_arn
    }
  }

  depends_on = [
    aws_bedrockagent_knowledge_base.this[0],
    aws_s3_bucket_policy.data_source
  ]

  lifecycle {
    precondition {
      condition     = var.chunking_strategy != "HIERARCHICAL" || var.hierarchical_parent_max_tokens > var.hierarchical_child_max_tokens
      error_message = "When using HIERARCHICAL chunking, hierarchical_parent_max_tokens (${var.hierarchical_parent_max_tokens}) must be greater than hierarchical_child_max_tokens (${var.hierarchical_child_max_tokens})."
    }

    precondition {
      condition     = !var.enable_custom_transformation || var.transformation_lambda_arn != null
      error_message = "When enable_custom_transformation is true, transformation_lambda_arn must be provided."
    }

    precondition {
      condition     = var.parsing_strategy != "BEDROCK_FOUNDATION_MODEL" || local.parsing_model_arn != null
      error_message = "When parsing_strategy is BEDROCK_FOUNDATION_MODEL, either parsing_model_id or parsing_model_arn must be provided."
    }

    # Cross-region validation: if user provides a full parsing_model_arn, verify it matches deployment region
    precondition {
      condition     = var.parsing_model_arn == null || can(regex("^arn:aws:bedrock:${data.aws_region.current.id}:", var.parsing_model_arn))
      error_message = "parsing_model_arn region must match deployment region (${data.aws_region.current.id}). Either use parsing_model_id (auto-constructs ARN) or provide ARN in the same region."
    }
  }
}