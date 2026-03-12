# Dead Letter Queue for Failed Processing

# =============================================================================
# SQS Dead Letter Queue
# =============================================================================

resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq && var.dlq_arn == null ? 1 : 0

  name = "${var.name}-preprocessing-dlq"

  message_retention_seconds  = 1209600 # 14 days
  visibility_timeout_seconds = 300     # Match Lambda timeout

  # Enable server-side encryption
  sqs_managed_sse_enabled = var.kms_key_arn == null

  tags = local.common_tags
}

# =============================================================================
# SQS Queue Policy
# =============================================================================

resource "aws_sqs_queue_policy" "dlq" {
  count = var.enable_dlq && var.dlq_arn == null ? 1 : 0

  queue_url = aws_sqs_queue.dlq[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.dlq[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_lambda_function.preprocessing.arn
          }
        }
      }
    ]
  })
}

# =============================================================================
# CloudWatch Alarm for DLQ Messages
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  count = var.enable_dlq && var.dlq_arn == null ? 1 : 0

  alarm_name          = "${var.name}-preprocessing-dlq-alarm"
  alarm_description   = "Alert when messages are sent to preprocessing DLQ"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq[0].name
  }

  tags = local.common_tags
}