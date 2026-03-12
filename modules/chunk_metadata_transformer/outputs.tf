# Outputs for Chunk Metadata Transformer Module

# =============================================================================
# Lambda Function Outputs
# =============================================================================

output "lambda_function_arn" {
  description = "ARN of the chunk metadata transformer Lambda function"
  value       = aws_lambda_function.transformer.arn
}

output "lambda_function_name" {
  description = "Name of the chunk metadata transformer Lambda function"
  value       = aws_lambda_function.transformer.function_name
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Lambda function (for API Gateway/Bedrock integration)"
  value       = aws_lambda_function.transformer.invoke_arn
}

output "lambda_function_qualified_arn" {
  description = "Qualified ARN of the Lambda function (includes version)"
  value       = aws_lambda_function.transformer.qualified_arn
}

# =============================================================================
# IAM Role Outputs
# =============================================================================

output "iam_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = var.create_iam_role ? aws_iam_role.lambda[0].arn : var.iam_role_arn
}

output "iam_role_name" {
  description = "Name of the Lambda IAM role"
  value       = var.create_iam_role ? aws_iam_role.lambda[0].name : null
}

# =============================================================================
# ECR Repository Outputs
# =============================================================================

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = var.create_ecr_repository ? aws_ecr_repository.lambda[0].repository_url : null
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = var.create_ecr_repository ? aws_ecr_repository.lambda[0].arn : var.ecr_repository_arn
}

# =============================================================================
# CloudWatch Outputs
# =============================================================================

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.arn
}

# =============================================================================
# Integration Outputs (for Bedrock Knowledge Base module)
# =============================================================================

output "transformation_lambda_arn" {
  description = "Lambda ARN formatted for Bedrock KB transformation_lambda_arn variable"
  value       = aws_lambda_function.transformer.arn
}

output "bedrock_integration" {
  description = "Configuration block for Bedrock Knowledge Base integration"
  value = {
    enable_custom_transformation    = true
    transformation_lambda_arn       = aws_lambda_function.transformer.arn
    transformation_step             = "POST_CHUNKING"
    intermediate_storage_bucket_arn = var.intermediate_storage_bucket_arn
    intermediate_storage_prefix     = var.intermediate_storage_prefix
  }
}