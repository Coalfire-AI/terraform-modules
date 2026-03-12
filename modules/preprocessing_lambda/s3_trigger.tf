# S3 Event Trigger for Lambda Preprocessing

# =============================================================================
# S3 Bucket Notification
# =============================================================================

resource "aws_s3_bucket_notification" "source_bucket" {
  count = var.enable_s3_trigger ? 1 : 0

  bucket = var.source_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.preprocessing.arn
    events              = var.s3_trigger_events

    filter_prefix = local.raw_prefix
    filter_suffix = var.s3_trigger_filter_suffix != "" ? var.s3_trigger_filter_suffix : null
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}