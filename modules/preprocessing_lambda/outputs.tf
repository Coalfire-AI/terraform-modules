# Outputs for Preprocessing Lambda Module

# =============================================================================
# Lambda Function Outputs
# =============================================================================

output "function_name" {
  description = "Name of the preprocessing Lambda function"
  value       = aws_lambda_function.preprocessing.function_name
}

output "function_arn" {
  description = "ARN of the preprocessing Lambda function"
  value       = aws_lambda_function.preprocessing.arn
}

output "function_invoke_arn" {
  description = "Invoke ARN of the preprocessing Lambda function"
  value       = aws_lambda_function.preprocessing.invoke_arn
}

output "function_version" {
  description = "Latest published version of the Lambda function"
  value       = aws_lambda_function.preprocessing.version
}

output "function_qualified_arn" {
  description = "Qualified ARN of the Lambda function (includes version)"
  value       = aws_lambda_function.preprocessing.qualified_arn
}

# =============================================================================
# IAM Outputs
# =============================================================================

output "role_arn" {
  description = "ARN of the IAM role for the Lambda function"
  value       = var.create_iam_role ? aws_iam_role.lambda[0].arn : var.iam_role_arn
}

output "role_name" {
  description = "Name of the IAM role for the Lambda function"
  value       = var.create_iam_role ? aws_iam_role.lambda[0].name : null
}

# =============================================================================
# ECR Outputs
# =============================================================================

output "ecr_repository_arn" {
  description = "ARN of the ECR repository for Lambda container images"
  value       = var.create_ecr_repository ? aws_ecr_repository.lambda[0].arn : var.ecr_repository_arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for Lambda container images"
  value       = var.create_ecr_repository ? aws_ecr_repository.lambda[0].repository_url : null
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = var.create_ecr_repository ? aws_ecr_repository.lambda[0].name : null
}

# =============================================================================
# CloudWatch Outputs
# =============================================================================

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for Lambda logs"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda.arn
}

# =============================================================================
# DLQ Outputs
# =============================================================================

output "dlq_arn" {
  description = "ARN of the Dead Letter Queue (if created)"
  value       = var.enable_dlq && var.dlq_arn == null ? aws_sqs_queue.dlq[0].arn : var.dlq_arn
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue (if created)"
  value       = var.enable_dlq && var.dlq_arn == null ? aws_sqs_queue.dlq[0].url : null
}

output "dlq_alarm_arn" {
  description = "ARN of the CloudWatch alarm for DLQ messages"
  value       = var.enable_dlq && var.dlq_arn == null ? aws_cloudwatch_metric_alarm.dlq_messages[0].arn : null
}

# =============================================================================
# S3 Configuration Outputs
# =============================================================================

output "raw_documents_prefix" {
  description = "S3 prefix for raw document uploads"
  value       = local.raw_prefix
}

output "processed_documents_prefix" {
  description = "S3 prefix for processed document output"
  value       = local.processed_prefix
}

output "s3_trigger_enabled" {
  description = "Whether S3 trigger is enabled"
  value       = var.enable_s3_trigger
}

# =============================================================================
# Configuration Outputs
# =============================================================================

output "architecture" {
  description = "Lambda function architecture (arm64 or x86_64)"
  value       = local.architectures[0]
}

output "memory_size" {
  description = "Lambda function memory size in MB"
  value       = var.memory_size
}

output "timeout" {
  description = "Lambda function timeout in seconds"
  value       = var.timeout
}

output "extract_nist_metadata" {
  description = "Whether NIST metadata extraction is enabled"
  value       = var.extract_nist_metadata
}

output "xray_tracing_enabled" {
  description = "Whether X-Ray tracing is enabled for the Lambda function"
  value       = var.enable_xray_tracing
}

output "log_format" {
  description = "Log format configured for the Lambda function (Text or JSON)"
  value       = var.lambda_log_format
}
