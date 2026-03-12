# AgentCore Agent Deployments
# Calls the agentcore_agent submodule for each agent defined in var.agents

module "agent" {
  source   = "../agentcore_agent"
  for_each = var.agents

  # Derive runtime and display names from agent key and deployment name
  # Runtime name must match: ^[a-zA-Z][a-zA-Z0-9_]{0,47}$ (no hyphens, max 48 chars)
  agent_runtime_name = local.agent_runtime_names[each.key]
  agent_display_name = replace(title(replace(each.key, "_", " ")), " ", "")

  description = coalesce(
    each.value.description,
    "Bedrock AgentCore runtime for ${each.key} agent in ${var.deployment_name} deployment"
  )

  # Per-agent execution role with all required permissions (ECR, Bedrock, SSM, S3)
  role_arn = aws_iam_role.agent_execution[each.key].arn

  # Container configuration - pass full image URI directly
  container_uri = each.value.image_uri

  # Network configuration
  network_mode = each.value.network_mode
  vpc_config   = each.value.vpc_config

  # Protocol configuration
  server_protocol = each.value.server_protocol

  # Environment variables
  environment_variables = each.value.environment_variables

  # Endpoints
  endpoints = each.value.endpoints

  # Tags
  tags = merge(
    {
      Deployment = var.deployment_name
      System     = "TRA"
    },
    var.tags,
    each.value.tags
  )
}
