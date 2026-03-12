# Log Retention Enforcer Module
#
# Automatically sets retention policies on CloudWatch log groups created by
# AgentCore runtimes. Uses EventBridge to detect CreateLogGroup events and
# triggers a Lambda to set the retention policy.

locals {
  function_name = "${var.deployment_name}-log-retention-enforcer"

  common_tags = merge(var.tags, {
    ManagedBy  = "terraform"
    Module     = "log_retention_enforcer"
    Deployment = var.deployment_name
  })

  # Inline Python code for the Lambda function
  lambda_code = <<-PYTHON
import json
import boto3
import os

logs_client = boto3.client('logs')

def handler(event, context):
    """
    Handle CreateLogGroup events from EventBridge and set retention policy.
    """
    retention_days = int(os.environ.get('RETENTION_DAYS', '14'))
    log_group_prefix = os.environ.get('LOG_GROUP_PREFIX', '/aws/bedrock-agentcore/runtimes/')

    # Extract log group name from the CloudTrail event
    detail = event.get('detail', {})
    request_params = detail.get('requestParameters', {})
    log_group_name = request_params.get('logGroupName', '')

    if not log_group_name:
        print(f"No logGroupName in event: {json.dumps(event)}")
        return {'statusCode': 400, 'body': 'No logGroupName found'}

    # Only process log groups matching our prefix
    if not log_group_name.startswith(log_group_prefix):
        print(f"Skipping log group {log_group_name} - does not match prefix {log_group_prefix}")
        return {'statusCode': 200, 'body': 'Skipped - prefix mismatch'}

    try:
        logs_client.put_retention_policy(
            logGroupName=log_group_name,
            retentionInDays=retention_days
        )
        print(f"Set retention policy of {retention_days} days on {log_group_name}")
        return {'statusCode': 200, 'body': f'Set retention on {log_group_name}'}
    except logs_client.exceptions.ResourceNotFoundException:
        print(f"Log group {log_group_name} not found (may have been deleted)")
        return {'statusCode': 404, 'body': 'Log group not found'}
    except Exception as e:
        print(f"Error setting retention on {log_group_name}: {e}")
        raise
PYTHON
}

# -----------------------------------------------------------------------------
# Lambda Function Code Package
# -----------------------------------------------------------------------------

data "archive_file" "lambda_code" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = local.lambda_code
    filename = "lambda_function.py"
  }
}

# -----------------------------------------------------------------------------
# IAM Role for Lambda
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_permissions" {
  # CloudWatch Logs - write own logs
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }

  # CloudWatch Logs - set retention on AgentCore log groups
  statement {
    effect    = "Allow"
    actions   = ["logs:PutRetentionPolicy"]
    resources = ["arn:aws:logs:*:*:log-group:${var.log_group_prefix}*"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "lambda" {
  name   = "lambda-permissions"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "enforcer" {
  function_name    = local.function_name
  role             = aws_iam_role.lambda.arn
  description      = "Sets retention policy on AgentCore CloudWatch log groups"
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_code.output_path
  source_code_hash = data.archive_file.lambda_code.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      RETENTION_DAYS   = tostring(var.retention_days)
      LOG_GROUP_PREFIX = var.log_group_prefix
    }
  }

  tags = local.common_tags

  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.retention_days

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# EventBridge Rule - Trigger on CreateLogGroup via CloudTrail
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "create_log_group" {
  name        = "${var.deployment_name}-agentcore-log-group-created"
  description = "Triggers when AgentCore creates a new CloudWatch log group"

  event_pattern = jsonencode({
    source      = ["aws.logs"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["logs.amazonaws.com"]
      eventName   = ["CreateLogGroup"]
      requestParameters = {
        logGroupName = [{
          prefix = var.log_group_prefix
        }]
      }
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.create_log_group.name
  target_id = "log-retention-enforcer"
  arn       = aws_lambda_function.enforcer.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.enforcer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.create_log_group.arn
}
