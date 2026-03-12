# Lambda Function for Document Preprocessing

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

resource "aws_lambda_function" "preprocessing" {
  function_name = local.function_name
  description   = "Preprocesses documents using Docling for NIST metadata extraction"
  role          = var.create_iam_role ? aws_iam_role.lambda[0].arn : var.iam_role_arn

  package_type = "Image"
  image_uri    = local.resolved_image_uri

  architectures = local.architectures
  memory_size   = var.memory_size
  timeout       = var.timeout

  reserved_concurrent_executions = var.reserved_concurrent_executions != -1 ? var.reserved_concurrent_executions : null

  ephemeral_storage {
    size = var.ephemeral_storage_size
  }

  environment {
    variables = local.environment_variables
  }

  dynamic "dead_letter_config" {
    for_each = var.enable_dlq ? [1] : []
    content {
      target_arn = var.dlq_arn != null ? var.dlq_arn : aws_sqs_queue.dlq[0].arn
    }
  }

  dynamic "tracing_config" {
    for_each = var.enable_xray_tracing ? [1] : []
    content {
      mode = "Active"
    }
  }

  # Enhanced logging configuration for CloudWatch
  logging_config {
    log_format            = var.lambda_log_format
    application_log_level = var.lambda_log_format == "JSON" ? var.lambda_application_log_level : null
    system_log_level      = var.lambda_log_format == "JSON" ? var.lambda_system_log_level : null
    log_group             = aws_cloudwatch_log_group.lambda.name
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.cloudwatch_logs,
    aws_iam_role_policy.s3_source_read,
    aws_iam_role_policy.s3_output_write,
    aws_ecr_repository.lambda
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
# Lambda Permission for S3 Invocation
# =============================================================================

resource "aws_lambda_permission" "s3_invoke" {
  count = var.enable_s3_trigger ? 1 : 0

  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.preprocessing.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.source_bucket_arn

  source_account = data.aws_caller_identity.current.account_id
}

# =============================================================================
