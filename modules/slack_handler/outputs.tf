# Slack Handler Module - Outputs

output "api_endpoint" {
  description = "API Gateway endpoint URL for Slack webhooks"
  value       = aws_apigatewayv2_api.slack_handler.api_endpoint
}

output "slack_events_url" {
  description = "Full URL for Slack events endpoint (configure in Slack app)"
  value       = "${aws_apigatewayv2_api.slack_handler.api_endpoint}/slack/events"
}

output "lambda_function_name" {
  description = "Slack handler Lambda function name"
  value       = aws_lambda_function.slack_handler.function_name
}

output "lambda_function_arn" {
  description = "Slack handler Lambda function ARN"
  value       = aws_lambda_function.slack_handler.arn
}

output "lambda_role_arn" {
  description = "IAM role ARN for the Lambda function"
  value       = aws_iam_role.slack_handler.arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for assessment mappings"
  value       = aws_dynamodb_table.assessments.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN for assessment mappings"
  value       = aws_dynamodb_table.assessments.arn
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.slack_handler.id
}

output "cloudwatch_log_group_lambda" {
  description = "CloudWatch log group for Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "cloudwatch_log_group_api" {
  description = "CloudWatch log group for API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway.name
}
