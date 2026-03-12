# Data source to get current AWS region and account
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  region         = data.aws_region.current.region

  # Handler/Assessment DynamoDB table (for execution lock access by orchestrator)
  # Resolves to the appropriate handler's table based on platform, or null if handler is disabled
  assessment_table_arn = var.handler_platform == "slack" ? module.slack_handler[0].dynamodb_table_arn : (
    var.handler_platform == "teams" ? module.teams_handler[0].dynamodb_table_arn : null
  )
}
