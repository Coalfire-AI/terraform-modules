# Outputs for Log Retention Enforcer Module

output "lambda_function_arn" {
  description = "ARN of the log retention enforcer Lambda function"
  value       = aws_lambda_function.enforcer.arn
}

output "lambda_function_name" {
  description = "Name of the log retention enforcer Lambda function"
  value       = aws_lambda_function.enforcer.function_name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.create_log_group.arn
}

output "log_group_prefix" {
  description = "The log group prefix being monitored"
  value       = var.log_group_prefix
}

output "retention_days" {
  description = "The retention period being enforced"
  value       = var.retention_days
}
