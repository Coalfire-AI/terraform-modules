# TRA Infrastructure

Orchestrator module that composes the full Technical Risk Assessment (TRA) agent infrastructure. Deploys Bedrock AgentCore agents, a human-in-the-loop (HITL) handler platform (Slack or Teams), log retention enforcement, and optional Coalfire support access.

## Architecture

```
tra_infra
 ├── agentcore_agent (for_each var.agents)    # Bedrock AgentCore runtimes
 ├── log_retention_enforcer                    # CloudWatch log retention
 ├── slack_handler (if handler_platform=slack) # Slack HITL handler
 ├── teams_handler (if handler_platform=teams) # Teams HITL handler
 └── support-access.tf (if enabled)            # Coalfire support read-only role
```

## Features

- Deploy multiple AgentCore agents from a single `agents` map with per-agent IAM roles
- Agent-to-agent invocation permissions via `can_invoke` (least-privilege)
- Mutually exclusive handler platform selection (Slack, Teams, or none)
- Automatic CloudWatch log retention enforcement for AgentCore-created log groups
- Optional cross-account Knowledge Base access
- Optional Coalfire vendor support read-only IAM role
- Shared S3 bucket access with configurable read/write path prefixes

## Usage

```hcl
module "tra_infra" {
  source = "git::ssh://git@github.com/Coalfire-AI/terraform-modules.git//modules/tra_infra?ref=v2.1.0"

  deployment_name = "tra-prod"

  agents = {
    primary_orchestrator = {
      image_uri   = "123456789012.dkr.ecr.us-west-2.amazonaws.com/orchestrator:v1.0.0"
      can_invoke  = ["evidence_collector"]
    }
    evidence_collector = {
      image_uri = "123456789012.dkr.ecr.us-west-2.amazonaws.com/evidence-collector:v1.0.0"
      environment_variables = {
        PYTHONPATH = "/app"
      }
    }
  }

  # Slack HITL handler
  handler_platform = "slack"
  handler_config = {
    container_uri        = "123456789012.dkr.ecr.us-west-2.amazonaws.com/slack-handler:v1.0.0"
    ssm_parameter_prefix = "/my-org"
  }

  # Shared S3 bucket
  s3_bucket_arn = aws_s3_bucket.agents.arn

  # Encryption
  kms_key_arn = aws_kms_key.agents.arn

  tags = {
    Environment = "production"
    Project     = "TRA"
  }
}
```

## Support Access

The `grant_coalfire_support_access` variable creates an IAM role (`cf-support-readonly`) that Coalfire support staff can assume for troubleshooting. This role has read-only access to agent-related CloudWatch logs, metrics, S3 objects, SSM parameters, and Bedrock AgentCore resources. It is disabled by default.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_agent"></a> [agent](#module\_agent) | ../agentcore_agent | n/a |
| <a name="module_log_retention_enforcer"></a> [log\_retention\_enforcer](#module\_log\_retention\_enforcer) | ../log_retention_enforcer | n/a |
| <a name="module_slack_handler"></a> [slack\_handler](#module\_slack\_handler) | ../slack_handler | n/a |
| <a name="module_teams_handler"></a> [teams\_handler](#module\_teams\_handler) | ../teams_handler | n/a |

### Resources

| Name | Type |
|------|------|
| [aws_iam_role.agent_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.coalfire_support](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.agent_additional_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agent_bedrock_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agent_cloudwatch_logs_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agent_ecr_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agent_invocation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agent_kb_cross_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agent_parameter_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agent_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.agent_xray_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.coalfire_support](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.orchestrator_dynamodb_lock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.agent_additional_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.agent_invocation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.agent_parameter_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.agent_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.agentcore_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.bedrock_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cloudwatch_logs_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.coalfire_support_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.coalfire_support_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecr_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.kb_cross_account_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.orchestrator_dynamodb_lock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.xray_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment (used for resource naming) | `string` | n/a | yes |
| <a name="input_agentcore_log_retention_days"></a> [agentcore\_log\_retention\_days](#input\_agentcore\_log\_retention\_days) | Retention period in days for AgentCore CloudWatch log groups | `number` | `14` | no |
| <a name="input_agents"></a> [agents](#input\_agents) | Map of agents to deploy. Key is the agent name. | <pre>map(object({<br/>    # Container image - full ECR URI with tag (e.g., 123456789012.dkr.ecr.us-west-2.amazonaws.com/agent:v1.0.0)<br/>    image_uri = string<br/><br/>    # Optional overrides (derived from agent name if not provided)<br/>    description = optional(string)<br/><br/>    # Network configuration<br/>    network_mode = optional(string, "PUBLIC")<br/>    vpc_config = optional(object({<br/>      security_groups = list(string)<br/>      subnets         = list(string)<br/>    }))<br/><br/>    # Protocol and environment<br/>    server_protocol       = optional(string)<br/>    environment_variables = optional(map(string), {})<br/><br/>    # Tags<br/>    tags = optional(map(string), {})<br/><br/>    # Endpoints<br/>    endpoints = optional(map(object({<br/>      name                  = string<br/>      description           = optional(string)<br/>      agent_runtime_version = optional(string)<br/>      tags                  = optional(map(string), {})<br/>    })), {})<br/><br/>    # S3 bucket ARNs this agent needs access to (in addition to shared bucket)<br/>    s3_bucket_arns = optional(list(string))<br/><br/>    # SSM parameter ARNs this agent needs access to<br/>    parameter_arns = optional(list(string), [])<br/><br/>    # Agent invocation permissions - list of agent names this agent can invoke<br/>    # Enables least-privilege agent-to-agent communication<br/>    can_invoke = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_coalfire_support_role_arn"></a> [coalfire\_support\_role\_arn](#input\_coalfire\_support\_role\_arn) | ARN of the Coalfire support role that can assume the customer support role. Required when grant\_coalfire\_support\_access is true. | `string` | `null` | no |
| <a name="input_ecr_repository_arns"></a> [ecr\_repository\_arns](#input\_ecr\_repository\_arns) | List of ECR repository ARNs that agents can pull from. If empty, allows all ECR repos. | `list(string)` | `[]` | no |
| <a name="input_grant_coalfire_support_access"></a> [grant\_coalfire\_support\_access](#input\_grant\_coalfire\_support\_access) | Enable Coalfire support staff role for troubleshooting access to agent infrastructure | `bool` | `false` | no |
| <a name="input_handler_config"></a> [handler\_config](#input\_handler\_config) | Configuration for the handler Lambda. Required when handler\_platform is 'slack' or 'teams'. | <pre>object({<br/>    # Container image for the handler Lambda (Slack or Teams)<br/>    container_uri = string<br/><br/>    # Name of the primary orchestrator agent (must exist in var.agents)<br/>    primary_orchestrator_name = optional(string, "primary_orchestrator")<br/><br/>    # SSM parameter prefix for platform credentials (e.g., "/my-org")<br/>    ssm_parameter_prefix = string<br/><br/>    # Optional VPC configuration<br/>    vpc_config = optional(object({<br/>      subnet_ids         = list(string)<br/>      security_group_ids = list(string)<br/>    }))<br/><br/>    # Lambda configuration<br/>    lambda_timeout     = optional(number, 30)<br/>    lambda_memory_size = optional(number, 256)<br/><br/>    # Provisioned concurrency to eliminate cold starts (0 = disabled)<br/>    # Costs ~$37/year per instance at 256MB<br/>    provisioned_concurrency = optional(number, 0) # Default to 0, as provisioned concurrency is not a viable option for initial deploys since SSM parameter values will be default SETME and the handler will fail to start, blocking successful apply.<br/><br/>  })</pre> | `null` | no |
| <a name="input_handler_platform"></a> [handler\_platform](#input\_handler\_platform) | Handler platform to deploy: 'slack', 'teams', or 'none' to disable. Only one platform can be active per deployment. | `string` | `"none"` | no |
| <a name="input_kb_cross_account_role_arn"></a> [kb\_cross\_account\_role\_arn](#input\_kb\_cross\_account\_role\_arn) | ARN of the cross-account role for Knowledge Base access in the build account. When provided, agents will be granted permission to assume this role for KB queries. | `string` | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of the KMS key used for encrypting SSM parameters and S3 objects | `string` | `null` | no |
| <a name="input_s3_bucket_arn"></a> [s3\_bucket\_arn](#input\_s3\_bucket\_arn) | ARN of the shared S3 bucket for agent config, docs, inputs, and outputs | `string` | `null` | no |
| <a name="input_s3_bucket_paths"></a> [s3\_bucket\_paths](#input\_s3\_bucket\_paths) | S3 path prefixes for agent access control | <pre>object({<br/>    read_paths  = optional(list(string), ["config/*", "docs/*", "inputs/*"])<br/>    write_paths = optional(list(string), ["outputs/*"])<br/>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_agent_execution_roles"></a> [agent\_execution\_roles](#output\_agent\_execution\_roles) | Map of agent names to their execution role ARNs |
| <a name="output_agent_identities"></a> [agent\_identities](#output\_agent\_identities) | Map of agent names to their full identities: {deployment\_name}-{region}-{agent\_name} |
| <a name="output_agents"></a> [agents](#output\_agents) | Map of deployed agents with their runtime details |
| <a name="output_cf_support_readonly_role_arn"></a> [cf\_support\_readonly\_role\_arn](#output\_cf\_support\_readonly\_role\_arn) | ARN of the cf-support-readonly role for Coalfire support access (null if support access is not enabled) |
| <a name="output_cf_support_readonly_role_name"></a> [cf\_support\_readonly\_role\_name](#output\_cf\_support\_readonly\_role\_name) | Name of the cf-support-readonly role (null if support access is not enabled) |
| <a name="output_handler_details"></a> [handler\_details](#output\_handler\_details) | Handler details (null if handler\_platform is 'none') |
| <a name="output_handler_platform"></a> [handler\_platform](#output\_handler\_platform) | The configured handler platform ('slack', 'teams', or 'none') |
| <a name="output_log_retention_enforcer"></a> [log\_retention\_enforcer](#output\_log\_retention\_enforcer) | Log retention enforcer details |
<!-- END_TF_DOCS -->
