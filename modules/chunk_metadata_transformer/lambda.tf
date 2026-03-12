# Lambda Function for Chunk Metadata Transformation

# =============================================================================
# CloudWatch Log Group
# =============================================================================

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = local.common_tags
}

# =============================================================================
# Lambda Function
# =============================================================================

resource "aws_lambda_function" "transformer" {
  function_name = local.function_name
  description   = "POST_CHUNKING transformation for Bedrock KB - extracts per-chunk NIST metadata"
  role          = var.create_iam_role ? aws_iam_role.lambda[0].arn : var.iam_role_arn

  package_type = "Image"
  image_uri    = local.resolved_image_uri

  architectures = local.architectures
  memory_size   = var.memory_size
  timeout       = var.timeout

  reserved_concurrent_executions = var.reserved_concurrent_executions != -1 ? var.reserved_concurrent_executions : null

  environment {
    variables = local.environment_variables
  }

  # Enhanced logging configuration
  logging_config {
    log_format = var.lambda_log_format
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.cloudwatch_logs,
    aws_iam_role_policy.s3_intermediate
  ]

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = var.image_uri != null
      error_message = "image_uri is required. Since local Docker builds are not supported, you must provide a pre-built container image from CI/CD (e.g., GitHub Actions). See .github/workflows/examples/lambda-images-build.yml.example for a workflow template."
    }
  }
}

# =============================================================================
# Lambda Permission for Bedrock Invocation
# =============================================================================

resource "aws_lambda_permission" "bedrock_invoke" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transformer.function_name
  principal     = "bedrock.amazonaws.com"

  source_account = data.aws_caller_identity.current.account_id
}