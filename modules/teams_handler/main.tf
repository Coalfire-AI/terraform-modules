# Teams Handler Module - Main Resources
#
# Deploys a Lambda function with API Gateway to handle Microsoft Teams Bot Framework
# messages and Adaptive Card interactions for the handler workflow.

locals {
  function_name = "${var.deployment_name}-teams-handler"
  table_name    = "${var.deployment_name}-assessments"

  common_tags = merge(var.tags, {
    ManagedBy  = "terraform"
    Module     = "teams_handler"
    Deployment = var.deployment_name
  })
}

# -----------------------------------------------------------------------------
# API Gateway - HTTP API for Teams Bot Framework webhooks
# -----------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "teams_handler" {
  name          = "${var.deployment_name}-teams-handler"
  protocol_type = "HTTP"
  description   = "API Gateway for Microsoft Teams Bot Framework webhooks"

  cors_configuration {
    allow_origins = ["https://smba.trafficmanager.net", "https://*.botframework.com"]
    allow_methods = ["POST"]
    allow_headers = ["Content-Type", "Authorization"]
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.teams_handler.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.deployment_name}-teams-handler"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.teams_handler.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.teams_handler.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "teams_messages" {
  api_id    = aws_apigatewayv2_api.teams_handler.id
  route_key = "POST /teams/messages"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "teams_handler" {
  function_name = local.function_name
  role          = aws_iam_role.teams_handler.arn
  description   = "Teams handler for Bot Framework messages and Adaptive Cards"

  package_type  = "Image"
  image_uri     = var.container_uri
  architectures = ["arm64"] # Match CI/CD build platform

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      ASSESSMENT_TABLE_NAME    = aws_dynamodb_table.assessments.name
      PRIMARY_ORCHESTRATOR_ARN = var.primary_orchestrator_arn
      SSM_PARAMETER_PREFIX     = var.ssm_parameter_prefix
      DEPLOYMENT_NAME          = var.deployment_name
      LOG_LEVEL                = "INFO"
    }
  }

  # VPC configuration (optional)
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.teams_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.teams_handler.execution_arn}/*/*"
}

# -----------------------------------------------------------------------------
# DynamoDB Table for Assessment Mappings
# -----------------------------------------------------------------------------

resource "aws_dynamodb_table" "assessments" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "assessment_id"
    type = "S"
  }

  global_secondary_index {
    name            = "assessment-index"
    hash_key        = "assessment_id"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = local.common_tags
}
