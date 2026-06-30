# AgentCore Agent Module - Main Resources 

# AgentCore Agent Runtime
resource "aws_bedrockagentcore_agent_runtime" "agent" {
  agent_runtime_name = var.agent_runtime_name
  role_arn           = var.role_arn
  description        = var.description

  agent_runtime_artifact {
    container_configuration {
      container_uri = var.container_uri
    }
  }

  network_configuration {
    network_mode = var.network_mode

    # Only include vpc_config if network_mode is VPC
    dynamic "network_mode_config" {
      for_each = var.network_mode == "VPC" && var.vpc_config != null ? [var.vpc_config] : []
      content {
        security_groups = network_mode_config.value.security_groups
        subnets         = network_mode_config.value.subnets
      }
    }
  }

  # Optional protocol configuration
  dynamic "protocol_configuration" {
    for_each = var.server_protocol != null ? [var.server_protocol] : []
    content {
      server_protocol = protocol_configuration.value
    }
  }

  # Optional inbound CUSTOM_JWT authorizer (else SigV4/IAM inbound).
  dynamic "authorizer_configuration" {
    for_each = var.authorizer_configuration != null ? [var.authorizer_configuration] : []
    content {
      custom_jwt_authorizer {
        discovery_url    = authorizer_configuration.value.discovery_url
        allowed_audience = authorizer_configuration.value.allowed_audience
        allowed_clients  = authorizer_configuration.value.allowed_clients
        allowed_scopes   = authorizer_configuration.value.allowed_scopes
      }
    }
  }

  # Optional allowlist of inbound headers forwarded to the container.
  dynamic "request_header_configuration" {
    for_each = length(var.request_header_allowlist) > 0 ? [1] : []
    content {
      request_header_allowlist = var.request_header_allowlist
    }
  }

  # Environment variables (only included if not empty)
  environment_variables = length(var.environment_variables) > 0 ? var.environment_variables : null

  tags = merge(
    {
      ManagedBy = "Terraform"
      Agent     = var.agent_display_name
    },
    var.tags
  )
}

# AgentCore Agent Runtime Endpoints
# Multiple endpoints can be created per runtime to act as versions/environments
resource "aws_bedrockagentcore_agent_runtime_endpoint" "endpoint" {
  for_each = var.endpoints

  name                  = each.value.name
  agent_runtime_id      = aws_bedrockagentcore_agent_runtime.agent.agent_runtime_id
  description           = each.value.description
  agent_runtime_version = each.value.agent_runtime_version

  tags = merge(
    {
      ManagedBy = "Terraform"
      Agent     = var.agent_display_name
    },
    each.value.tags,
    var.tags
  )
}
