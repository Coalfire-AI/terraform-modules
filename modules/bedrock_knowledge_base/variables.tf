# Variables for Bedrock Knowledge Base Module

# =============================================================================
# Required Variables
# =============================================================================

variable "name" {
  description = "Name for the knowledge base (used as prefix for all resources)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.name)) && length(var.name) <= 63
    error_message = "Name must be alphanumeric with hyphens/underscores, max 63 characters"
  }
}

# =============================================================================
# IAM Configuration
# =============================================================================

variable "create_iam_role" {
  description = "Whether to create an IAM role for the knowledge base"
  type        = bool
  default     = true
}

variable "role_arn" {
  description = "ARN of existing IAM role (required if create_iam_role is false)"
  type        = string
  default     = null
}

# =============================================================================
# Knowledge Base Creation Control
# =============================================================================

variable "create_knowledge_base" {
  description = <<-EOT
    Whether to create the Bedrock Knowledge Base resource.
    Set to false during initial deployment when using OPENSEARCH_SERVERLESS to allow
    the vector index to be created externally before the Knowledge Base.

    Two-apply pattern for OpenSearch Serverless:
    1. First apply: Set create_knowledge_base = false to create the collection
    2. Create the vector index using opensearch provider (see opensearch_index_config output)
    3. Second apply: Set create_knowledge_base = true to create the Knowledge Base
  EOT
  type        = bool
  default     = true
}

# =============================================================================
# KMS Encryption Configuration
# =============================================================================

variable "create_kms_key" {
  description = "Whether to create a KMS key for encryption"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of existing KMS key (used if create_kms_key is false)"
  type        = string
  default     = null
}

variable "kms_key_deletion_window_days" {
  description = "Duration in days after which the KMS key is deleted after destruction"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window_days >= 7 && var.kms_key_deletion_window_days <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days"
  }
}

variable "kms_key_enable_rotation" {
  description = "Whether to enable automatic KMS key rotation"
  type        = bool
  default     = true
}

# =============================================================================
# Vector Store Type Selection
# =============================================================================

variable "vector_store_type" {
  description = <<-EOT
    Type of vector store to use for the knowledge base:
    - OPENSEARCH_SERVERLESS: Amazon OpenSearch Serverless (default) - Full-featured, no metadata limits, production-ready
    - S3_VECTORS: Amazon S3 Vectors - Pay-per-query, 2KB filterable metadata limit, cost-optimized

    Use OPENSEARCH_SERVERLESS for:
    - Production RAG applications requiring reliability and low latency
    - Complex metadata filtering without size limits
    - When using POST_CHUNKING Lambda that returns multiple chunks per input
    - Standard knowledge base deployments

    Use S3_VECTORS for:
    - Cost-sensitive deployments with low query volumes
    - Simple RAG applications with minimal metadata filtering
    - When metadata filtering needs are within 2KB limit
    - NOTE: Requires special extractors architecture for framework filtering
  EOT
  type        = string
  default     = "OPENSEARCH_SERVERLESS"

  validation {
    condition     = contains(["S3_VECTORS", "OPENSEARCH_SERVERLESS"], var.vector_store_type)
    error_message = "Vector store type must be S3_VECTORS or OPENSEARCH_SERVERLESS"
  }
}

# =============================================================================
# S3 Vector Store Configuration (used when vector_store_type = "S3_VECTORS")
# =============================================================================

variable "vector_bucket_name" {
  description = "Name for the S3 vector bucket (defaults to {name}-vectors)"
  type        = string
  default     = null
}

variable "vector_index_name" {
  description = "Name for the vector index (defaults to {name}-index)"
  type        = string
  default     = null
}

variable "vector_distance_metric" {
  description = "Distance metric for vector similarity search"
  type        = string
  default     = "cosine"

  validation {
    condition     = contains(["cosine", "euclidean", "dot_product"], var.vector_distance_metric)
    error_message = "Distance metric must be one of: cosine, euclidean, dot_product"
  }
}

# =============================================================================
# S3 Data Source Configuration
# =============================================================================

variable "create_data_source_bucket" {
  description = "Whether to create an S3 bucket for source documents"
  type        = bool
  default     = true
}

variable "data_source_bucket_arn" {
  description = "ARN of existing S3 bucket for source documents (required if create_data_source_bucket is false)"
  type        = string
  default     = null
}

variable "data_source_bucket_name" {
  description = "Name for the data source S3 bucket (defaults to {name}-documents)"
  type        = string
  default     = null
}

variable "data_source_inclusion_prefixes" {
  description = "List of S3 key prefixes to include in the data source"
  type        = list(string)
  default     = []
}

# =============================================================================
# Embedding Model Configuration
# =============================================================================

variable "embedding_model_id" {
  description = "Bedrock embedding model ID"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"

  validation {
    condition = contains([
      "amazon.titan-embed-text-v1",
      "amazon.titan-embed-text-v2:0",
      "amazon.titan-embed-image-v1",
      "cohere.embed-english-v3",
      "cohere.embed-multilingual-v3"
    ], var.embedding_model_id)
    error_message = "Invalid embedding model ID"
  }
}

variable "embedding_dimensions" {
  description = "Dimensions for the embedding vectors (must match model capability)"
  type        = number
  default     = 1024

  validation {
    condition     = contains([256, 384, 512, 1024, 1536], var.embedding_dimensions)
    error_message = "Embedding dimensions must be one of: 256, 384, 512, 1024, 1536"
  }
}

variable "embedding_data_type" {
  description = "Data type for embedding vectors"
  type        = string
  default     = "FLOAT32"

  validation {
    condition     = contains(["FLOAT32", "BINARY"], var.embedding_data_type)
    error_message = "Embedding data type must be FLOAT32 or BINARY"
  }
}

# =============================================================================
# Data Source Configuration
# =============================================================================

variable "data_deletion_policy" {
  description = <<-EOT
    Policy for vector deletion when data source is destroyed.
    - RETAIN: Keep ingested vectors when data source is deleted (safer default)
    - DELETE: Remove all ingested vectors when data source is deleted
  EOT
  type        = string
  default     = "RETAIN"

  validation {
    condition     = contains(["DELETE", "RETAIN"], var.data_deletion_policy)
    error_message = "Data deletion policy must be DELETE or RETAIN"
  }
}

# =============================================================================
# Chunking Configuration
# =============================================================================

variable "chunking_strategy" {
  description = "Strategy for chunking documents"
  type        = string
  default     = "FIXED_SIZE"

  validation {
    condition     = contains(["FIXED_SIZE", "NONE", "HIERARCHICAL", "SEMANTIC"], var.chunking_strategy)
    error_message = "Chunking strategy must be one of: FIXED_SIZE, NONE, HIERARCHICAL, SEMANTIC"
  }
}

variable "chunk_max_tokens" {
  description = "Maximum number of tokens per chunk (for FIXED_SIZE strategy)"
  type        = number
  default     = 300

  validation {
    condition     = var.chunk_max_tokens >= 1 && var.chunk_max_tokens <= 8192
    error_message = "Chunk max tokens must be between 1 and 8192"
  }
}

variable "chunk_overlap_percentage" {
  description = "Percentage of overlap between chunks (for FIXED_SIZE strategy)"
  type        = number
  default     = 10

  validation {
    condition     = var.chunk_overlap_percentage >= 0 && var.chunk_overlap_percentage <= 99
    error_message = "Chunk overlap percentage must be between 0 and 99"
  }
}

# =============================================================================
# Semantic Chunking Configuration (for SEMANTIC strategy)
# =============================================================================

variable "semantic_max_tokens" {
  description = "Maximum tokens per chunk for semantic chunking. Only used when chunking_strategy = SEMANTIC."
  type        = number
  default     = 512

  validation {
    condition     = var.semantic_max_tokens >= 1 && var.semantic_max_tokens <= 8192
    error_message = "Semantic max tokens must be between 1 and 8192"
  }
}

variable "semantic_buffer_size" {
  description = "Number of sentences to buffer for context (0-1). Higher values provide better semantic boundary detection. Only used when chunking_strategy = SEMANTIC."
  type        = number
  default     = 1

  validation {
    condition     = var.semantic_buffer_size >= 0 && var.semantic_buffer_size <= 1
    error_message = "Semantic buffer size must be between 0 and 1"
  }
}

variable "semantic_breakpoint_threshold" {
  description = "Percentile threshold (50-99) for semantic breakpoints. Higher = fewer, larger chunks. Values below 50 create overly granular chunks. Only used when chunking_strategy = SEMANTIC."
  type        = number
  default     = 95

  validation {
    condition     = var.semantic_breakpoint_threshold >= 50 && var.semantic_breakpoint_threshold <= 99
    error_message = "Semantic breakpoint threshold must be between 50 and 99. Values below 50 are not recommended as they create overly granular chunks."
  }
}

# =============================================================================
# Hierarchical Chunking Configuration (for HIERARCHICAL strategy)
# =============================================================================

variable "hierarchical_parent_max_tokens" {
  description = "Maximum tokens for parent chunks. Only used when chunking_strategy = HIERARCHICAL."
  type        = number
  default     = 1500

  validation {
    condition     = var.hierarchical_parent_max_tokens >= 1 && var.hierarchical_parent_max_tokens <= 8192
    error_message = "Hierarchical parent max tokens must be between 1 and 8192"
  }
}

variable "hierarchical_child_max_tokens" {
  description = "Maximum tokens for child chunks. Must be less than parent. Only used when chunking_strategy = HIERARCHICAL."
  type        = number
  default     = 300

  validation {
    condition     = var.hierarchical_child_max_tokens >= 1 && var.hierarchical_child_max_tokens <= 8192
    error_message = "Hierarchical child max tokens must be between 1 and 8192"
  }
}

variable "hierarchical_overlap_tokens" {
  description = "Number of overlap tokens between hierarchical chunks. Only used when chunking_strategy = HIERARCHICAL."
  type        = number
  default     = 60

  validation {
    condition     = var.hierarchical_overlap_tokens >= 1 && var.hierarchical_overlap_tokens <= 1024
    error_message = "Hierarchical overlap tokens must be between 1 and 1024"
  }
}

# =============================================================================
# Custom Transformation Configuration (Bedrock-native Lambda invocation)
# =============================================================================

variable "enable_custom_transformation" {
  description = "Whether to enable custom Lambda transformation during Bedrock ingestion. This is different from preprocessing - it runs as part of Bedrock's ingestion pipeline."
  type        = bool
  default     = false
}

variable "transformation_lambda_arn" {
  description = "ARN of Lambda function for custom transformation (required if enable_custom_transformation is true)"
  type        = string
  default     = null

  validation {
    condition     = var.transformation_lambda_arn == null || can(regex("^arn:aws:lambda:", var.transformation_lambda_arn))
    error_message = "transformation_lambda_arn must be a valid Lambda ARN"
  }
}

variable "transformation_step" {
  description = "When to apply transformation: POST_CHUNKING (after chunking) or PRE_CHUNKING (before chunking)"
  type        = string
  default     = "POST_CHUNKING"

  validation {
    condition     = contains(["POST_CHUNKING", "PRE_CHUNKING"], var.transformation_step)
    error_message = "Transformation step must be POST_CHUNKING or PRE_CHUNKING"
  }
}

variable "intermediate_storage_bucket_arn" {
  description = "ARN of S3 bucket for intermediate transformation storage. If not provided, uses the data source bucket."
  type        = string
  default     = null

  validation {
    condition     = var.intermediate_storage_bucket_arn == null || can(regex("^arn:aws:s3:::", var.intermediate_storage_bucket_arn))
    error_message = "intermediate_storage_bucket_arn must be a valid S3 bucket ARN"
  }
}

variable "intermediate_storage_prefix" {
  description = "S3 prefix for intermediate transformation storage"
  type        = string
  default     = "intermediate/"

  validation {
    condition     = can(regex("^[a-zA-Z0-9!_.*'()/-]*$", var.intermediate_storage_prefix))
    error_message = "Intermediate storage prefix must be a valid S3 key prefix"
  }
}

# =============================================================================
# Parsing Configuration (Foundation Model parsing for complex documents)
# =============================================================================
# Foundation Model parsing uses multimodal AI to extract text, tables, and figures
# from complex PDFs. Cost: ~$0.003/page. Recommended for:
# - Documents with tables (AWS Well-Architected, compliance frameworks)
# - Technical specifications with diagrams
# - Forms and structured documents
# =============================================================================

variable "parsing_strategy" {
  description = "Document parsing strategy: DEFAULT (free, basic text extraction) or BEDROCK_FOUNDATION_MODEL (~$0.003/page, multimodal parsing for complex docs with tables/figures)"
  type        = string
  default     = "DEFAULT"

  validation {
    condition     = contains(["DEFAULT", "BEDROCK_FOUNDATION_MODEL"], var.parsing_strategy)
    error_message = "Parsing strategy must be DEFAULT or BEDROCK_FOUNDATION_MODEL"
  }
}

variable "parsing_model_id" {
  description = <<-EOT
    Bedrock model ID for document parsing (used when parsing_strategy is BEDROCK_FOUNDATION_MODEL).
    ARN is auto-constructed for the deployment region.

    IMPORTANT: Parsing requires models with DIRECT regional availability (not cross-region inference).
    Claude 4/4.5 models currently only support cross-region inference and may not work for parsing.

    Recommended models with wide regional availability:
    - anthropic.claude-3-5-sonnet-20241022-v2:0 (recommended)
    - anthropic.claude-3-haiku-20240307-v1:0 (faster, lower cost)
    - amazon.nova-pro-v1:0, amazon.nova-lite-v1:0 (cost-effective)

    See: https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base-supported.html
  EOT
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"

  validation {
    condition = var.parsing_model_id == null || contains([
      # Claude 3 vision models (widely available)
      "anthropic.claude-3-haiku-20240307-v1:0",
      "anthropic.claude-3-sonnet-20240229-v1:0",
      # Claude 3.5 vision models (widely available)
      "anthropic.claude-3-5-haiku-20241022-v1:0",
      "anthropic.claude-3-5-sonnet-20240620-v1:0",
      "anthropic.claude-3-5-sonnet-20241022-v2:0",
      # Claude 3.7 vision models (limited regions)
      "anthropic.claude-3-7-sonnet-20250219-v1:0",
      # Claude 4 vision models (cross-region only - limited parsing support)
      "anthropic.claude-opus-4-20250514-v1:0",
      "anthropic.claude-sonnet-4-20250514-v1:0",
      "anthropic.claude-sonnet-4-5-20250929-v1:0",
      # Amazon Nova vision models (widely available)
      "amazon.nova-pro-v1:0",
      "amazon.nova-lite-v1:0",
      # Meta Llama 4 vision models (us-east-1, us-west-2)
      "meta.llama4-scout-17b-instruct-v1:0",
      "meta.llama4-maverick-17b-instruct-v1:0"
    ], var.parsing_model_id)
    error_message = "Invalid parsing model ID. Only vision/multimodal models are supported for parsing: Claude 3/3.5/3.7/4, Nova Pro/Lite, or Llama 4 Scout/Maverick."
  }
}

variable "parsing_model_arn" {
  description = "Full ARN of foundation model for parsing. If provided, overrides parsing_model_id. Use for cross-region models or custom deployments. Example: arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
  type        = string
  default     = null

  validation {
    condition     = var.parsing_model_arn == null || can(regex("^arn:aws:bedrock:", var.parsing_model_arn))
    error_message = "parsing_model_arn must be a valid Bedrock model ARN"
  }
}

variable "parsing_prompt_override" {
  description = "Custom prompt for foundation model parsing. Use to tailor extraction for specific document types (e.g., compliance frameworks, technical specs). Leave null for default behavior."
  type        = string
  default     = null
}

# =============================================================================
# Preprocessing Pipeline Configuration (External Lambda preprocessing)
# =============================================================================

variable "enable_preprocessing" {
  description = "Whether to read from preprocessed documents (vs raw uploads). When true, data source reads from processed_documents_prefix instead of raw_documents_prefix."
  type        = bool
  default     = false
}

variable "raw_documents_prefix" {
  description = "S3 prefix for raw document uploads (source PDFs, etc.)"
  type        = string
  default     = "raw/"

  validation {
    condition     = can(regex("^[a-zA-Z0-9!_.*'()/-]*$", var.raw_documents_prefix))
    error_message = "Raw documents prefix must be a valid S3 key prefix"
  }
}

variable "processed_documents_prefix" {
  description = "S3 prefix for preprocessed documents (output from preprocessing Lambda)"
  type        = string
  default     = "processed/"

  validation {
    condition     = can(regex("^[a-zA-Z0-9!_.*'()/-]*$", var.processed_documents_prefix))
    error_message = "Processed documents prefix must be a valid S3 key prefix"
  }
}

# =============================================================================
# Knowledge Base Configuration
# =============================================================================

variable "description" {
  description = "Description of the knowledge base"
  type        = string
  default     = null
}

# =============================================================================
# Logging Configuration
# =============================================================================

variable "enable_logging" {
  description = "Enable CloudWatch logging for knowledge base data ingestion jobs"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "CloudWatch log retention must be a valid retention period"
  }
}

# =============================================================================
# Framework Extraction Configuration
# =============================================================================
# The universal extractor supports multiple compliance frameworks and cloud
# guidance documents. Enable/disable frameworks as needed for your use case.
#
# Supported Frameworks:
# - NIST-800-218-SSDF: Secure Software Development Framework (PO.1, PS.2, etc.)
# - AWS-WAF: Well-Architected Framework pillars (SEC-01, REL-02, etc.)
# - Additional frameworks can be added to the extractor registry
# =============================================================================

# =============================================================================
# S3 Vectors Metadata Configuration
# =============================================================================
# S3 Vectors has specific metadata constraints:
# - Filterable metadata: 2KB limit (HARD), used for query filtering
# - Non-filterable metadata: Must be defined at index creation, stored but not queryable
# - Total metadata: 40KB limit
# - Max non-filterable keys: 10
#
# Best practice: Use chunk_metadata_transformer module for POST_CHUNKING
# metadata enrichment to stay under these limits.
# =============================================================================

variable "s3_vectors_metadata_fields" {
  description = <<-EOT
    Metadata field definitions for S3 Vectors index. Fields can be filterable (indexed, queryable)
    or non-filterable (stored but not indexed). Non-filterable fields MUST be defined at index
    creation time and cannot be added later.

    Standardized metadata fields (framework-agnostic):
    - Filterable: frameworks, primary_framework, document_type, primary_category,
      primary_category_name, reference_count
    - Non-filterable: x_references, x_categories, x_source_section, x_framework_details,
      x_source_uri, x_enhancements

    Note: Non-filterable fields are prefixed with 'x_' by the chunk_metadata_transformer.
  EOT
  type = object({
    filterable_fields = optional(list(object({
      name = string
      type = string # STRING, NUMBER, BOOLEAN
    })), [])
    non_filterable_fields = optional(list(object({
      name = string
      type = string # STRING, NUMBER, BOOLEAN, STRING_LIST
    })), [])
  })
  default = {
    # Filterable: indexed and queryable (<2KB total)
    filterable_fields = [
      { name = "frameworks", type = "STRING" },            # JSON array of detected frameworks
      { name = "primary_framework", type = "STRING" },     # Framework with most references
      { name = "document_type", type = "STRING" },         # policy, standard, guideline, etc.
      { name = "primary_category", type = "STRING" },      # Primary category code (AC, SEC, etc.)
      { name = "primary_category_name", type = "STRING" }, # Human-readable category name
      { name = "reference_count", type = "NUMBER" },       # Total references in chunk
    ]
    # Non-filterable: stored but not indexed (max 10 fields)
    non_filterable_fields = [
      { name = "x_references", type = "STRING" },        # JSON array of all reference IDs
      { name = "x_categories", type = "STRING" },        # JSON dict of category distributions
      { name = "x_source_section", type = "STRING" },    # Section header from document
      { name = "x_framework_details", type = "STRING" }, # Framework-specific metadata
      { name = "x_source_uri", type = "STRING" },        # S3 URI of source document
      { name = "x_enhancements", type = "STRING" },      # Enhancement details (NIST-specific)
    ]
  }

  validation {
    condition     = length(var.s3_vectors_metadata_fields.non_filterable_fields) <= 10
    error_message = "S3 Vectors supports a maximum of 10 non-filterable metadata fields."
  }

  validation {
    condition = alltrue([
      for field in var.s3_vectors_metadata_fields.filterable_fields :
      contains(["STRING", "NUMBER", "BOOLEAN"], field.type)
    ])
    error_message = "Filterable field types must be STRING, NUMBER, or BOOLEAN."
  }

  validation {
    condition = alltrue([
      for field in var.s3_vectors_metadata_fields.non_filterable_fields :
      contains(["STRING", "NUMBER", "BOOLEAN", "STRING_LIST"], field.type)
    ])
    error_message = "Non-filterable field types must be STRING, NUMBER, BOOLEAN, or STRING_LIST."
  }
}

# =============================================================================
# OpenSearch Serverless Configuration (used when vector_store_type = "OPENSEARCH_SERVERLESS")
# =============================================================================

variable "opensearch_collection_name" {
  description = "Name for the OpenSearch Serverless collection (defaults to {name}-collection)"
  type        = string
  default     = null

  validation {
    condition     = var.opensearch_collection_name == null || can(regex("^[a-z][a-z0-9-]{2,31}$", var.opensearch_collection_name))
    error_message = "Collection name must be 3-32 characters, start with lowercase letter, contain only lowercase letters, numbers, and hyphens"
  }
}

variable "opensearch_index_name" {
  description = "Name for the vector index in OpenSearch (defaults to bedrock-knowledge-base-default-index)"
  type        = string
  default     = "bedrock-knowledge-base-default-index"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-_]*$", var.opensearch_index_name))
    error_message = "Index name must start with lowercase letter and contain only lowercase letters, numbers, hyphens, and underscores"
  }
}

variable "opensearch_standby_replicas" {
  description = "Whether to use standby replicas for the collection (ENABLED or DISABLED). ENABLED provides higher availability but increases cost."
  type        = string
  default     = "ENABLED"

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.opensearch_standby_replicas)
    error_message = "Standby replicas must be ENABLED or DISABLED"
  }
}

variable "opensearch_use_aws_owned_key" {
  description = "Whether to use AWS owned KMS key for encryption. Set to false to use customer managed KMS key."
  type        = bool
  default     = true
}

variable "opensearch_allow_public_access" {
  description = <<-EOT
    Whether to allow public network access to the OpenSearch collection.
    When false, AWS service private access is enabled for Bedrock (bedrock.amazonaws.com),
    allowing the Knowledge Base to access the private collection securely.
    See: https://repost.aws/knowledge-center/bedrock-knowledge-base-private-network-policy
  EOT
  type        = bool
  default     = false
}

variable "opensearch_vector_field_name" {
  description = "Name of the vector field in OpenSearch index"
  type        = string
  default     = "bedrock-knowledge-base-default-vector"
}

variable "opensearch_text_field_name" {
  description = "Name of the text field in OpenSearch index (stores chunked text)"
  type        = string
  default     = "AMAZON_BEDROCK_TEXT_CHUNK"
}

variable "opensearch_metadata_field_name" {
  description = "Name of the metadata field in OpenSearch index"
  type        = string
  default     = "AMAZON_BEDROCK_METADATA"
}

variable "opensearch_collection_wait_duration" {
  description = "Duration to wait for OpenSearch collection to become active (e.g., '3m' for 3 minutes)"
  type        = string
  default     = "3m"

  validation {
    condition     = can(regex("^[0-9]+[smh]$", var.opensearch_collection_wait_duration))
    error_message = "Wait duration must be a valid duration string (e.g., '3m', '180s', '1h')"
  }
}

variable "opensearch_additional_data_access_principals" {
  description = <<-EOT
    Additional IAM principal ARNs to grant data access to the OpenSearch collection.
    Use this to grant access to Terraform deployment roles or other external services
    that need to create indexes or access data in the collection.

    IMPORTANT: Use IAM role ARNs (arn:aws:iam::...:role/...), not STS assumed-role
    session ARNs (arn:aws:sts::...:assumed-role/...), as OpenSearch Serverless
    validates the underlying IAM principal.

    Example: ["arn:aws:iam::123456789012:role/terraform-deployment-role"]
  EOT
  type        = list(string)
  default     = []
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
