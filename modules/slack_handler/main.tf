# Slack Handler Module - Main Resources
#
# Deploys a Lambda function with API Gateway to handle Slack slash commands
# and interactive components for the handler workflow.

locals {
  function_name = "${var.deployment_name}-slack-handler"
  table_name    = "${var.deployment_name}-assessments"

  # Extract bucket name from ARN (arn:aws:s3:::bucket-name) to construct S3 URI
  object_store_bucket_name = var.object_store_bucket_arn != null ? split(":", var.object_store_bucket_arn)[5] : null
  object_store_bucket_uri  = local.object_store_bucket_name != null ? "s3://${local.object_store_bucket_name}" : null

  # Slack command name - uses deployment_name to allow multiple deployments in same workspace
  # Examples: /tra-dev, /tra-test, /tra-prod (whatever the customer named their deployment)
  slack_command_name = "/${var.deployment_name}"

  common_tags = merge(var.tags, {
    ManagedBy  = "terraform"
    Module     = "slack_handler"
    Deployment = var.deployment_name
  })
}

# -----------------------------------------------------------------------------
# SSM Parameter Data Sources for Slack Credentials
# Reads credentials at deploy time to inject as environment variables.
# This eliminates SSM calls during Lambda cold start, reducing init time.
# -----------------------------------------------------------------------------

data "aws_ssm_parameter" "slack_bot_token" {
  name            = "${var.ssm_parameter_prefix}/${var.deployment_name}/slack-token"
  with_decryption = true
}

data "aws_ssm_parameter" "slack_signing_secret" {
  name            = "${var.ssm_parameter_prefix}/${var.deployment_name}/slack-signing-secret"
  with_decryption = true
}

data "aws_ssm_parameter" "handler_channel" {
  name = "${var.ssm_parameter_prefix}/${var.deployment_name}/handler-channel"
}

# -----------------------------------------------------------------------------
# API Gateway - HTTP API for Slack webhooks
# -----------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "slack_handler" {
  name          = "${var.deployment_name}-slack-handler"
  protocol_type = "HTTP"
  description   = "API Gateway for Slack handler webhooks"

  cors_configuration {
    allow_origins = ["https://api.slack.com"]
    allow_methods = ["POST"]
    allow_headers = ["Content-Type", "X-Slack-Signature", "X-Slack-Request-Timestamp"]
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.slack_handler.id
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
  name              = "/aws/apigateway/${var.deployment_name}-slack-handler"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.slack_handler.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.slack_handler.invoke_arn
  payload_format_version = "2.0"
}

# Integration pointing to alias (used when provisioned concurrency is enabled)
resource "aws_apigatewayv2_integration" "lambda_alias" {
  count                  = var.provisioned_concurrency > 0 ? 1 : 0
  api_id                 = aws_apigatewayv2_api.slack_handler.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_alias.live[0].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "slack_events" {
  api_id    = aws_apigatewayv2_api.slack_handler.id
  route_key = "POST /slack/events"
  target    = var.provisioned_concurrency > 0 ? "integrations/${aws_apigatewayv2_integration.lambda_alias[0].id}" : "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "slack_handler" {
  function_name = local.function_name
  role          = aws_iam_role.slack_handler.arn
  description   = "Slack handler for slash commands and interactive buttons"

  package_type  = "Image"
  image_uri     = var.container_uri
  architectures = ["arm64"]                       # Match CI/CD build platform
  publish       = var.provisioned_concurrency > 0 # Publish versions when using provisioned concurrency

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = merge(
      {
        ASSESSMENT_TABLE_NAME    = aws_dynamodb_table.assessments.name
        PRIMARY_ORCHESTRATOR_ARN = var.primary_orchestrator_arn
        SSM_PARAMETER_PREFIX     = var.ssm_parameter_prefix
        DEPLOYMENT_NAME          = var.deployment_name
        LOG_LEVEL                = "INFO"
        # Slack credentials injected at deploy time to eliminate SSM calls during cold start
        SLACK_BOT_TOKEN      = data.aws_ssm_parameter.slack_bot_token.value
        SLACK_SIGNING_SECRET = data.aws_ssm_parameter.slack_signing_secret.value
      },
      # Object store bucket URI for docs and templates commands
      local.object_store_bucket_uri != null ? { OBJECT_STORE_BUCKET_URI = local.object_store_bucket_uri } : {},
      # Slack command name - must match the command registered in the Slack app manifest
      { SLACK_COMMAND_NAME = local.slack_command_name },
      # Allowed channel for slash commands - commands are denied outside this channel (fail closed)
      { SLACK_ALLOWED_CHANNEL = data.aws_ssm_parameter.handler_channel.value }
    )
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

# -----------------------------------------------------------------------------
# Lambda Alias and Provisioned Concurrency (optional)
# Eliminates cold starts by keeping instances warm. Enabled when
# provisioned_concurrency > 0.
# -----------------------------------------------------------------------------

resource "aws_lambda_alias" "live" {
  count            = var.provisioned_concurrency > 0 ? 1 : 0
  name             = "live"
  description      = "Live alias with provisioned concurrency"
  function_name    = aws_lambda_function.slack_handler.function_name
  function_version = aws_lambda_function.slack_handler.version

  lifecycle {
    # Alias must be updated when function code changes
    create_before_destroy = true
  }
}

resource "aws_lambda_provisioned_concurrency_config" "slack_handler" {
  count                             = var.provisioned_concurrency > 0 ? 1 : 0
  function_name                     = aws_lambda_function.slack_handler.function_name
  qualifier                         = aws_lambda_alias.live[0].name
  provisioned_concurrent_executions = var.provisioned_concurrency
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.provisioned_concurrency > 0 ? aws_lambda_alias.live[0].arn : aws_lambda_function.slack_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.slack_handler.execution_arn}/*/*"
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
