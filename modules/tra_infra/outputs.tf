# Outputs for TRA Infrastructure Module

output "agent_execution_roles" {
  description = "Map of agent names to their execution role ARNs"
  value = {
    for agent_name, role in aws_iam_role.agent_execution :
    agent_name => role.arn
  }
}

output "agent_identities" {
  description = "Map of agent names to their full identities: {deployment_name}-{region}-{agent_name}"
  value       = local.agent_identities
}

output "agents" {
  description = "Map of deployed agents with their runtime details"
  value = {
    for name, agent in module.agent : name => {
      agent_runtime_id      = agent.agent_runtime_id
      agent_runtime_arn     = agent.agent_runtime_arn
      agent_runtime_name    = agent.agent_runtime_name
      agent_runtime_version = agent.agent_runtime_version
      workload_identity_arn = agent.workload_identity_arn
      endpoints             = agent.endpoints
    }
  }
}

###############################################################################
# Handler Platform Outputs
###############################################################################

output "handler_platform" {
  description = "The configured handler platform ('slack', 'teams', or 'none')"
  value       = var.handler_platform
}

output "handler_details" {
  description = "Handler details (null if handler_platform is 'none')"
  value = var.handler_platform == "slack" ? {
    platform             = "slack"
    api_endpoint         = module.slack_handler[0].api_endpoint
    webhook_url          = module.slack_handler[0].slack_events_url
    lambda_function_name = module.slack_handler[0].lambda_function_name
    lambda_function_arn  = module.slack_handler[0].lambda_function_arn
    dynamodb_table_name  = module.slack_handler[0].dynamodb_table_name
    dynamodb_table_arn   = module.slack_handler[0].dynamodb_table_arn
    cloudwatch_log_group = module.slack_handler[0].cloudwatch_log_group_lambda
    } : var.handler_platform == "teams" ? {
    platform             = "teams"
    api_endpoint         = module.teams_handler[0].api_endpoint
    webhook_url          = module.teams_handler[0].teams_messages_url
    lambda_function_name = module.teams_handler[0].lambda_function_name
    lambda_function_arn  = module.teams_handler[0].lambda_function_arn
    dynamodb_table_name  = module.teams_handler[0].dynamodb_table_name
    dynamodb_table_arn   = module.teams_handler[0].dynamodb_table_arn
    cloudwatch_log_group = module.teams_handler[0].cloudwatch_log_group_lambda
  } : null
}

###############################################################################
# Log Retention Enforcer Outputs
###############################################################################

output "log_retention_enforcer" {
  description = "Log retention enforcer details"
  value = {
    lambda_function_name = module.log_retention_enforcer.lambda_function_name
    lambda_function_arn  = module.log_retention_enforcer.lambda_function_arn
    eventbridge_rule_arn = module.log_retention_enforcer.eventbridge_rule_arn
    log_group_prefix     = module.log_retention_enforcer.log_group_prefix
    retention_days       = module.log_retention_enforcer.retention_days
  }
}

###############################################################################
# Coalfire Support Access Outputs
###############################################################################

output "cf_support_readonly_role_arn" {
  description = "ARN of the cf-support-readonly role for Coalfire support access (null if support access is not enabled)"
  value       = var.grant_coalfire_support_access ? aws_iam_role.coalfire_support[0].arn : null
}

output "cf_support_readonly_role_name" {
  description = "Name of the cf-support-readonly role (null if support access is not enabled)"
  value       = var.grant_coalfire_support_access ? aws_iam_role.coalfire_support[0].name : null
}
