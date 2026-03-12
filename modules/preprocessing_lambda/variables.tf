# Variables for Preprocessing Lambda Module
# NIST Document Ingestion Pipeline

# =============================================================================
# Required Variables
# =============================================================================

variable "name" {
  description = "Name prefix for all resources created by this module"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.name)) && length(var.name) <= 50
    error_message = "Name must be alphanumeric with hyphens/underscores, max 50 characters"
  }
}

variable "source_bucket_name" {
  description = "Name of the S3 bucket containing raw documents to process"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.source_bucket_name))
    error_message = "Source bucket name must be a valid S3 bucket name"
  }
}

variable "source_bucket_arn" {
  description = "ARN of the S3 bucket containing raw documents"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:s3:::", var.source_bucket_arn))
    error_message = "Source bucket ARN must be a valid S3 bucket ARN"
  }
}

# =============================================================================
# Optional: Output Configuration
# =============================================================================

variable "output_bucket_name" {
  description = "Name of the S3 bucket for processed documents. If null, uses source_bucket_name"
  type        = string
  default     = null
}

variable "output_bucket_arn" {
  description = "ARN of the S3 bucket for processed documents. If null, uses source_bucket_arn"
  type        = string
  default     = null

  validation {
    condition     = var.output_bucket_arn == null || can(regex("^arn:aws:s3:::", var.output_bucket_arn))
    error_message = "Output bucket ARN must be a valid S3 bucket ARN"
  }
}

# =============================================================================
# S3 Prefix Configuration
# =============================================================================

variable "raw_documents_prefix" {
  description = "S3 prefix for raw document uploads (triggers Lambda)"
  type        = string
  default     = "raw/"

  validation {
    condition     = can(regex("^[a-zA-Z0-9!_.*'()/-]*$", var.raw_documents_prefix))
    error_message = "Raw documents prefix must be a valid S3 key prefix"
  }
}

variable "processed_documents_prefix" {
  description = "S3 prefix for processed document output (Markdown files)"
  type        = string
  default     = "processed/"

  validation {
    condition     = can(regex("^[a-zA-Z0-9!_.*'()/-]*$", var.processed_documents_prefix))
    error_message = "Processed documents prefix must be a valid S3 key prefix"
  }
}

# =============================================================================
# Lambda Configuration
# =============================================================================

variable "function_name" {
  description = "Name for the Lambda function. Defaults to {name}-preprocessing"
  type        = string
  default     = null
}

variable "memory_size" {
  description = "Memory allocation for Lambda in MB. Docling recommends 1-2GB minimum"
  type        = number
  default     = 2048

  validation {
    condition     = var.memory_size >= 512 && var.memory_size <= 10240
    error_message = "Memory size must be between 512 MB and 10240 MB"
  }
}

variable "timeout" {
  description = "Lambda timeout in seconds. Large documents may need 5+ minutes"
  type        = number
  default     = 300

  validation {
    condition     = var.timeout >= 30 && var.timeout <= 900
    error_message = "Timeout must be between 30 and 900 seconds"
  }
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions for Lambda. -1 for no limit"
  type        = number
  default     = -1

  validation {
    condition     = var.reserved_concurrent_executions >= -1 && var.reserved_concurrent_executions <= 1000
    error_message = "Reserved concurrent executions must be -1 (unlimited) or between 0 and 1000"
  }
}

variable "use_graviton" {
  description = "Use ARM64 Graviton2 architecture for 20-30% cost savings"
  type        = bool
  default     = true
}

variable "log_level" {
  description = "Log level for Lambda function"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "Log level must be DEBUG, INFO, WARNING, ERROR, or CRITICAL"
  }
}

variable "ephemeral_storage_size" {
  description = "Ephemeral storage (/tmp) size in MB. Large documents may need more than default 512MB"
  type        = number
  default     = 1024

  validation {
    condition     = var.ephemeral_storage_size >= 512 && var.ephemeral_storage_size <= 10240
    error_message = "Ephemeral storage size must be between 512 MB and 10240 MB"
  }
}

variable "additional_environment_variables" {
  description = "Additional environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

# =============================================================================
# NIST Metadata Extraction
# =============================================================================

variable "extract_nist_metadata" {
  description = "Enable extraction of NIST control IDs and metadata from documents"
  type        = bool
  default     = true
}

variable "enabled_frameworks" {
  description = <<-EOT
    Comma-separated list of compliance frameworks to extract metadata for.
    Available frameworks: NIST-800-218-SSDF, AWS-WAF
    The universal extractor supports multiple frameworks simultaneously.
  EOT
  type        = string
  default     = "NIST-800-218-SSDF,AWS-WAF"

  validation {
    condition = alltrue([
      for framework in split(",", var.enabled_frameworks) : contains([
        "NIST-800-218-SSDF", "AWS-WAF"
      ], trimspace(framework))
    ])
    error_message = "Enabled frameworks must be a comma-separated list of: NIST-800-218-SSDF, AWS-WAF"
  }
}

variable "metadata_output_mode" {
  description = <<-EOT
    Controls how much NIST metadata is included in the Markdown frontmatter:
    - "full": Include all control_ids (legacy mode, for human readability)
              WARNING: Can exceed S3 Vectors 2KB filterable metadata limit
    - "summary": Only counts and family codes (recommended with POST_CHUNKING Lambda)
    - "minimal": No NIST metadata in frontmatter (POST_CHUNKING handles everything)

    When using the chunk_metadata_transformer module for POST_CHUNKING, use "summary" or "minimal".
  EOT
  type        = string
  default     = "summary"

  validation {
    condition     = contains(["full", "summary", "minimal"], var.metadata_output_mode)
    error_message = "Metadata output mode must be 'full', 'summary', or 'minimal'"
  }
}

# =============================================================================
# ECR Configuration
# =============================================================================

variable "create_ecr_repository" {
  description = "Whether to create an ECR repository for the Lambda container image"
  type        = bool
  default     = true
}

variable "ecr_repository_name" {
  description = "Name for the ECR repository. Defaults to {name}-preprocessing"
  type        = string
  default     = null
}

variable "ecr_repository_arn" {
  description = "ARN of existing ECR repository (required if create_ecr_repository is false)"
  type        = string
  default     = null

  validation {
    condition     = var.ecr_repository_arn == null || can(regex("^arn:aws:ecr:", var.ecr_repository_arn))
    error_message = "ECR repository ARN must be a valid ECR ARN"
  }
}

variable "ecr_scan_on_push" {
  description = "Enable image scanning on push to ECR"
  type        = bool
  default     = true
}

variable "ecr_image_tag_mutability" {
  description = "Image tag mutability setting for ECR"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "ECR image tag mutability must be MUTABLE or IMMUTABLE"
  }
}

variable "image_uri" {
  description = <<-EOT
    Container image URI from ECR (REQUIRED).

    Local Docker builds are not supported. You must provide a pre-built container
    image from CI/CD (e.g., GitHub Actions). See the workflow template at:
    .github/workflows/examples/lambda-images-build.yml.example

    Format: <account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>
    Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/preprocessing-lambda:sha-abc1234
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.image_uri == null || can(regex("^\\d+\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/[a-z0-9._/-]+:[a-zA-Z0-9._-]+$", var.image_uri))
    error_message = "Image URI must be a valid ECR image URI: <account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>"
  }
}

# =============================================================================
# IAM Configuration
# =============================================================================

variable "create_iam_role" {
  description = "Whether to create an IAM role for the Lambda function"
  type        = bool
  default     = true
}

variable "iam_role_name" {
  description = "Name for the IAM role. Defaults to {name}-preprocessing-role"
  type        = string
  default     = null
}

variable "iam_role_arn" {
  description = "ARN of existing IAM role (required if create_iam_role is false)"
  type        = string
  default     = null

  validation {
    condition     = var.iam_role_arn == null || can(regex("^arn:aws:iam::", var.iam_role_arn))
    error_message = "IAM role ARN must be a valid IAM role ARN"
  }
}

variable "additional_iam_policies" {
  description = "List of additional IAM policy ARNs to attach to the Lambda role"
  type        = list(string)
  default     = []
}

# =============================================================================
# KMS Configuration
# =============================================================================

variable "enable_kms" {
  description = "Whether to enable KMS encryption. Set to true when kms_key_arn will be provided (even if computed at apply time)"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encrypting processed documents. Required when enable_kms is true"
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "KMS key ARN must be a valid KMS key ARN"
  }
}

# =============================================================================
# S3 Event Trigger Configuration
# =============================================================================

variable "enable_s3_trigger" {
  description = "Enable S3 event trigger for automatic processing"
  type        = bool
  default     = true
}

variable "s3_trigger_events" {
  description = "S3 event types to trigger Lambda"
  type        = list(string)
  default     = ["s3:ObjectCreated:Put", "s3:ObjectCreated:CompleteMultipartUpload"]

  validation {
    condition = alltrue([
      for event in var.s3_trigger_events : can(regex("^s3:", event))
    ])
    error_message = "S3 trigger events must be valid S3 event types"
  }
}

variable "s3_trigger_filter_suffix" {
  description = "File suffix filter for S3 trigger (e.g., .pdf). Empty string for no suffix filter"
  type        = string
  default     = ""
}

# =============================================================================
# Dead Letter Queue Configuration
# =============================================================================

variable "enable_dlq" {
  description = "Enable Dead Letter Queue for failed invocations"
  type        = bool
  default     = true
}

variable "dlq_arn" {
  description = "ARN of existing SQS queue for DLQ. If null and enable_dlq is true, creates a new queue"
  type        = string
  default     = null

  validation {
    condition     = var.dlq_arn == null || can(regex("^arn:aws:sqs:", var.dlq_arn))
    error_message = "DLQ ARN must be a valid SQS queue ARN"
  }
}

# =============================================================================
# CloudWatch Configuration
# =============================================================================

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cloudwatch_log_retention_days)
    error_message = "CloudWatch log retention must be a valid retention period"
  }
}

variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray tracing for the Lambda function"
  type        = bool
  default     = false
}

variable "lambda_log_format" {
  description = "Log format for Lambda function (Text or JSON). JSON enables structured logging with log levels."
  type        = string
  default     = "JSON"

  validation {
    condition     = contains(["Text", "JSON"], var.lambda_log_format)
    error_message = "Lambda log format must be Text or JSON"
  }
}

variable "lambda_application_log_level" {
  description = "Application log level for Lambda (only applies when lambda_log_format is JSON)"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL"], var.lambda_application_log_level)
    error_message = "Lambda application log level must be TRACE, DEBUG, INFO, WARN, ERROR, or FATAL"
  }
}

variable "lambda_system_log_level" {
  description = "System log level for Lambda runtime (only applies when lambda_log_format is JSON)"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARN"], var.lambda_system_log_level)
    error_message = "Lambda system log level must be DEBUG, INFO, or WARN"
  }
}

# =============================================================================
# Tags
# =============================================================================

# =============================================================================
# Chunking Configuration
# =============================================================================

variable "enable_chunking" {
  description = <<-EOT
    Enable pre-chunking in the preprocessing Lambda.
    
    When true, documents are chunked before being stored in S3, which is REQUIRED
    when using Bedrock KB with S3 Vectors (set data source chunking_strategy = "NONE").
    
    When false, documents are stored as-is and Bedrock KB handles chunking.
  EOT
  type        = bool
  default     = false
}

variable "chunk_size_tokens" {
  description = <<-EOT
    Target chunk size in tokens (using tiktoken cl100k_base encoding).
    
    For S3 Vectors with Bedrock KB, recommended values:
    - 256-512 for fine-grained retrieval
    - 512-1024 for balanced retrieval
    - 1024+ for broader context
    
    Note: Actual chunks may be smaller at paragraph/section boundaries.
  EOT
  type        = number
  default     = 512

  validation {
    condition     = var.chunk_size_tokens >= 64 && var.chunk_size_tokens <= 4096
    error_message = "Chunk size must be between 64 and 4096 tokens"
  }
}

variable "chunk_overlap_tokens" {
  description = <<-EOT
    Number of overlapping tokens between consecutive chunks.
    
    Overlap helps preserve context across chunk boundaries for better
    semantic search results. Recommended: 10-20% of chunk_size_tokens.
    
    With section-aware chunking, overlap does NOT cross section boundaries.
  EOT
  type        = number
  default     = 64

  validation {
    condition     = var.chunk_overlap_tokens >= 0 && var.chunk_overlap_tokens <= 512
    error_message = "Chunk overlap must be between 0 and 512 tokens"
  }
}

variable "enable_section_aware_chunking" {
  description = <<-EOT
    Enable section-aware chunking to preserve document structure.
    
    When true (default), the chunker:
    - Detects section headings (Executive Summary, Introduction, etc.)
    - Preserves important sections intact when possible
    - Adds section_type metadata to each chunk for filtering
    - Prevents overlap from crossing section boundaries
    - Excludes Table of Contents from content chunks
    
    This is critical for compliance documents (SSDF, NIST, etc.) where
    executive summaries and introductions should be retrievable as units.
  EOT
  type        = bool
  default     = true
}

variable "section_max_tokens" {
  description = <<-EOT
    Maximum tokens for a section before it gets split.
    
    Sections smaller than this are kept intact as single chunks (if possible).
    Larger sections are split using virtual preservation (same section_type).
    
    Recommended: 1024-2048 tokens for important sections like Executive Summary.
  EOT
  type        = number
  default     = 1024

  validation {
    condition     = var.section_max_tokens >= 256 && var.section_max_tokens <= 8192
    error_message = "Section max tokens must be between 256 and 8192"
  }
}

variable "sections_to_preserve" {
  description = <<-EOT
    Comma-separated list of section types to prioritize for preservation.
    
    These sections will be kept intact as single chunks when under section_max_tokens.
    The section names are normalized (lowercase, underscores for spaces).
    
    Default preserves document overview sections critical for RAG retrieval:
    "executive_summary,abstract,introduction,purpose,scope"
  EOT
  type        = string
  default     = "executive_summary,abstract,introduction,purpose,scope"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
