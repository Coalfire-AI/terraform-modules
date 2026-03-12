# Variables for Slack Handler Module

variable "deployment_name" {
  description = "Name of the deployment (used for resource naming)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

variable "container_uri" {
  description = "ECR image URI for the Slack handler Lambda"
  type        = string
}

variable "primary_orchestrator_arn" {
  description = "ARN of the primary orchestrator agent runtime"
  type        = string
}

variable "object_store_bucket_arn" {
  description = "ARN of the S3 bucket containing docs, templates, inputs, and outputs. Required for /tra docs and /tra templates commands."
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for parameter decryption"
  type        = string
  default     = null
}

variable "ssm_parameter_prefix" {
  description = "SSM parameter prefix for handler configuration (e.g., '/my-org')"
  type        = string
}

variable "vpc_config" {
  description = "Optional VPC configuration for Lambda"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 256
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "provisioned_concurrency" {
  description = "Number of provisioned concurrency instances (0 to disable). Eliminates cold starts but costs ~$37/year per instance at 256MB."
  type        = number
  default     = 0 # Default to 0, as provisioned concurrency is not a viable option for initial deploys since SSM parameter values will be default SETME and the handler will fail to start, blocking successful apply.
}
