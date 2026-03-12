# Teams Handler Module - Outputs

output "api_endpoint" {
  description = "API Gateway endpoint URL for Teams Bot Framework webhooks"
  value       = aws_apigatewayv2_api.teams_handler.api_endpoint
}

output "teams_messages_url" {
  description = "Full URL for Teams messages endpoint (configure in Azure Bot)"
  value       = "${aws_apigatewayv2_api.teams_handler.api_endpoint}/teams/messages"
}

output "lambda_function_name" {
  description = "Teams handler Lambda function name"
  value       = aws_lambda_function.teams_handler.function_name
}

output "lambda_function_arn" {
  description = "Teams handler Lambda function ARN"
  value       = aws_lambda_function.teams_handler.arn
}

output "lambda_role_arn" {
  description = "IAM role ARN for the Lambda function"
  value       = aws_iam_role.teams_handler.arn
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
  value       = aws_apigatewayv2_api.teams_handler.id
}

output "cloudwatch_log_group_lambda" {
  description = "CloudWatch log group for Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "cloudwatch_log_group_api" {
  description = "CloudWatch log group for API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway.name
}
