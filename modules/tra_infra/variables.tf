# Variables for TRA Infrastructure Module

variable "deployment_name" {
  description = "Name of the deployment (used for resource naming)"
  type        = string
}

variable "grant_coalfire_support_access" {
  description = "Enable Coalfire support staff role for troubleshooting access to agent infrastructure"
  type        = bool
  default     = false
}

variable "coalfire_support_role_arn" {
  description = "ARN of the Coalfire support role that can assume the customer support role. Required when grant_coalfire_support_access is true."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs that agents can pull from. If empty, allows all ECR repos."
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting SSM parameters and S3 objects"
  type        = string
  default     = null
}

variable "s3_bucket_arn" {
  description = "ARN of the shared S3 bucket for agent config, docs, inputs, and outputs"
  type        = string
  default     = null
}

variable "s3_bucket_paths" {
  description = "S3 path prefixes for agent access control"
  type = object({
    read_paths  = optional(list(string), ["config/*", "docs/*", "inputs/*"])
    write_paths = optional(list(string), ["outputs/*"])
  })
  default = {}
}

###############################################################################
# Observability Configuration
###############################################################################

variable "agentcore_log_retention_days" {
  description = "Retention period in days for AgentCore CloudWatch log groups"
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.agentcore_log_retention_days)
    error_message = "agentcore_log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

###############################################################################
# Agent Configuration
###############################################################################

variable "agents" {
  description = "Map of agents to deploy. Key is the agent name."
  type = map(object({
    # Container image - full ECR URI with tag (e.g., 123456789012.dkr.ecr.us-west-2.amazonaws.com/agent:v1.0.0)
    image_uri = string

    # Optional overrides (derived from agent name if not provided)
    description = optional(string)

    # Network configuration
    network_mode = optional(string, "PUBLIC")
    vpc_config = optional(object({
      security_groups = list(string)
      subnets         = list(string)
    }))

    # Protocol and environment
    server_protocol       = optional(string)
    environment_variables = optional(map(string), {})

    # Tags
    tags = optional(map(string), {})

    # Endpoints
    endpoints = optional(map(object({
      name                  = string
      description           = optional(string)
      agent_runtime_version = optional(string)
      tags                  = optional(map(string), {})
    })), {})

    # S3 bucket ARNs this agent needs access to (in addition to shared bucket)
    s3_bucket_arns = optional(list(string))

    # SSM parameter ARNs this agent needs access to
    parameter_arns = optional(list(string), [])

    # Agent invocation permissions - list of agent names this agent can invoke
    # Enables least-privilege agent-to-agent communication
    can_invoke = optional(list(string), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for agent_name, config in var.agents :
      alltrue([
        for target in coalesce(config.can_invoke, []) :
        contains(keys(var.agents), target)
      ])
    ])
    error_message = "All agents listed in 'can_invoke' must be defined in the agents map."
  }
}

###############################################################################
# Handler Platform Configuration
# Supports Slack OR Teams (mutually exclusive per deployment)
###############################################################################

variable "handler_platform" {
  description = "Handler platform to deploy: 'slack', 'teams', or 'none' to disable. Only one platform can be active per deployment."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["slack", "teams", "none"], var.handler_platform)
    error_message = "handler_platform must be 'slack', 'teams', or 'none'."
  }
}

variable "handler_config" {
  description = "Configuration for the handler Lambda. Required when handler_platform is 'slack' or 'teams'."
  type = object({
    # Container image for the handler Lambda (Slack or Teams)
    container_uri = string

    # Name of the primary orchestrator agent (must exist in var.agents)
    primary_orchestrator_name = optional(string, "primary_orchestrator")

    # SSM parameter prefix for platform credentials (e.g., "/my-org")
    ssm_parameter_prefix = string

    # Optional VPC configuration
    vpc_config = optional(object({
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))

    # Lambda configuration
    lambda_timeout     = optional(number, 30)
    lambda_memory_size = optional(number, 256)

    # Provisioned concurrency to eliminate cold starts (0 = disabled)
    # Costs ~$37/year per instance at 256MB
    provisioned_concurrency = optional(number, 0) # Default to 0, as provisioned concurrency is not a viable option for initial deploys since SSM parameter values will be default SETME and the handler will fail to start, blocking successful apply.

  })
  default = null
}

# Validation: config required when platform is enabled
check "handler_config_required" {
  assert {
    condition     = var.handler_platform == "none" || var.handler_config != null
    error_message = "handler_config is required when handler_platform is 'slack' or 'teams'."
  }
}

# Validation: coalfire_support_role_arn required when support access is enabled
check "coalfire_support_role_arn_required" {
  assert {
    condition     = !var.grant_coalfire_support_access || var.coalfire_support_role_arn != null
    error_message = "coalfire_support_role_arn is required when grant_coalfire_support_access is true."
  }
}

###############################################################################
# Cross-Account Knowledge Base Access
###############################################################################

variable "kb_cross_account_role_arn" {
  description = "ARN of the cross-account role for Knowledge Base access in the build account. When provided, agents will be granted permission to assume this role for KB queries."
  type        = string
  default     = null
}
