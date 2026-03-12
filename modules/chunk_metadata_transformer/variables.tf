# Variables for Chunk Metadata Transformer Module
# POST_CHUNKING Lambda for Bedrock Knowledge Base

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

# =============================================================================
# S3 Configuration for Intermediate Storage
# =============================================================================

variable "intermediate_storage_bucket_arn" {
  description = "ARN of S3 bucket for Bedrock intermediate transformation storage"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:s3:::", var.intermediate_storage_bucket_arn))
    error_message = "Intermediate storage bucket ARN must be a valid S3 bucket ARN"
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

variable "kms_key_arn" {
  description = "ARN of KMS key used to encrypt intermediate storage bucket. Required if bucket uses KMS encryption."
  type        = string
  default     = null
}

# =============================================================================
# Lambda Configuration
# =============================================================================

variable "function_name" {
  description = "Name for the Lambda function. Defaults to {name}-chunk-transformer"
  type        = string
  default     = null
}

variable "memory_size" {
  description = "Memory allocation for Lambda in MB. 256-512MB is sufficient for metadata extraction"
  type        = number
  default     = 512

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 3008
    error_message = "Memory size must be between 128 MB and 3008 MB"
  }
}

variable "timeout" {
  description = "Lambda timeout in seconds. POST_CHUNKING typically completes quickly"
  type        = number
  default     = 60

  validation {
    condition     = var.timeout >= 3 && var.timeout <= 900
    error_message = "Timeout must be between 3 and 900 seconds"
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
  description = "Use ARM64 Graviton2 architecture for cost savings"
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

# =============================================================================
# NIST Metadata Configuration
# =============================================================================

variable "compliance_framework" {
  description = "Compliance framework identifier for metadata (NIST-800-218-SSDF, NIST-800-53, or AWS-WAF)"
  type        = string
  default     = "NIST-800-218-SSDF"
}

variable "default_document_type" {
  description = "Default document type when inference fails"
  type        = string
  default     = "policy"

  validation {
    condition     = contains(["policy", "procedure", "standard", "guideline", "ssp", "poam", "assessment", "ato", "other"], var.default_document_type)
    error_message = "Default document type must be a valid document classification"
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
  description = "Name for the ECR repository. Defaults to {name}-chunk-transformer"
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

variable "image_uri" {
  description = <<-EOT
    Container image URI from ECR (REQUIRED).

    Local Docker builds are not supported. You must provide a pre-built container
    image from CI/CD (e.g., GitHub Actions). See the workflow template at:
    .github/workflows/examples/lambda-images-build.yml.example

    Format: <account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>
    Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/chunk-metadata-transformer:sha-abc1234
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
  description = "Name for the IAM role. Defaults to {name}-chunk-transformer-role"
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

variable "lambda_log_format" {
  description = "Log format for Lambda function (Text or JSON)"
  type        = string
  default     = "JSON"

  validation {
    condition     = contains(["Text", "JSON"], var.lambda_log_format)
    error_message = "Lambda log format must be Text or JSON"
  }
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
