# Variables for Teams Handler Module

variable "deployment_name" {
  description = "Name of the deployment (used for resource naming)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

variable "container_uri" {
  description = "ECR image URI for the Teams handler Lambda"
  type        = string
}

variable "primary_orchestrator_arn" {
  description = "ARN of the primary orchestrator agent runtime"
  type        = string
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
