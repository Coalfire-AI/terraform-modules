# Log Retention Enforcer
# Automatically sets retention policies on CloudWatch log groups created by AgentCore

module "log_retention_enforcer" {
  source = "../log_retention_enforcer"

  deployment_name  = var.deployment_name
  log_group_prefix = "/aws/bedrock-agentcore/runtimes/"
  retention_days   = var.agentcore_log_retention_days

  tags = merge(
    {
      Deployment = var.deployment_name
      System     = "TRA"
      Component  = "LogRetentionEnforcer"
    },
    var.tags
  )
}
