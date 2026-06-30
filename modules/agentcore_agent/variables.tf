# Variables for AgentCore Agent Module

variable "agent_runtime_name" {
  description = "Full runtime name for the agent (e.g., 'auditron_browser_automation_v1')"
  type        = string
}

variable "agent_display_name" {
  description = "Display name for tags (e.g., 'BrowserAutomation', 'CommandGenerator')"
  type        = string
}

variable "role_arn" {
  description = "ARN of the IAM role that the agent runtime assumes"
  type        = string
}

variable "container_uri" {
  description = "Full container image URI with tag (e.g., 123456789012.dkr.ecr.us-west-2.amazonaws.com/agent:v1.0.0)"
  type        = string
}

variable "network_mode" {
  description = "Network mode for the agent runtime (PUBLIC, VPC, SANDBOX)"
  type        = string
  default     = "PUBLIC"

  validation {
    condition     = contains(["PUBLIC", "VPC", "SANDBOX"], var.network_mode)
    error_message = "network_mode must be one of: PUBLIC, VPC, SANDBOX"
  }
}

variable "vpc_config" {
  description = "VPC configuration for the agent runtime (required if network_mode is VPC)"
  type = object({
    security_groups = list(string)
    subnets         = list(string)
  })
  default = null
}

variable "server_protocol" {
  description = "Server protocol for the agent runtime (HTTP, MCP, A2A)"
  type        = string
  default     = null

  validation {
    condition     = var.server_protocol == null || contains(["HTTP", "MCP", "A2A"], var.server_protocol)
    error_message = "server_protocol must be one of: HTTP, MCP, A2A, or null"
  }
}

variable "environment_variables" {
  description = "Map of environment variables to pass to the container"
  type        = map(string)
  default     = {}
}

variable "description" {
  description = "Description of the agent runtime"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to the agent runtime"
  type        = map(string)
  default     = {}
}

variable "endpoints" {
  description = "Map of endpoints to create for this agent runtime. Each endpoint acts as a version/environment."
  type = map(object({
    name                  = string
    description           = optional(string)
    agent_runtime_version = optional(string)
    tags                  = optional(map(string), {})
  }))
  default = {}
}

variable "authorizer_configuration" {
  description = <<-EOT
    Optional inbound CUSTOM_JWT authorizer. When set, AgentCore validates the
    request's bearer JWT (issuer/audience/clients) against discovery_url before
    it reaches the container. Leave null for SigV4 (IAM) inbound auth.
  EOT
  type = object({
    discovery_url    = string
    allowed_audience = optional(list(string))
    allowed_clients  = optional(list(string))
    allowed_scopes   = optional(list(string))
  })
  default = null

  validation {
    # The provider requires an OIDC discovery document URL.
    condition     = var.authorizer_configuration == null ? true : endswith(var.authorizer_configuration.discovery_url, ".well-known/openid-configuration")
    error_message = "authorizer_configuration.discovery_url must end with '.well-known/openid-configuration'."
  }
}

variable "request_header_allowlist" {
  description = "Inbound request headers AgentCore forwards to the container (e.g. [\"Authorization\"] so the runtime can re-verify the bearer). Empty = forward none."
  type        = list(string)
  default     = []
}
