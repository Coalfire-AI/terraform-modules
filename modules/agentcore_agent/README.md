# AgentCore Agent Terraform Module

This module provides a standardized way to create and manage AWS Bedrock AgentCore agent runtimes with their associated ECR repositories.

## Features

- Creates AgentCore agent runtime resources
- Optionally creates and manages ECR repositories
- Supports custom environment variables
- Flexible network configuration (PUBLIC, VPC, SANDBOX)
- Configurable protocol settings (HTTP, MCP, A2A)
- Consistent tagging strategy

## Usage

### Basic Usage

```hcl
module "browser_automation_agent" {
  source = "../../modules/agentcore_agent"

  agent_runtime_name = "auditron_browser_automation_v1"
  agent_display_name = "BrowserAutomation"

  role_arn      = aws_iam_role.bedrock_agentcore.arn
  container_uri = "123456789012.dkr.ecr.us-west-2.amazonaws.com/browser-automation:latest"

  network_mode = "PUBLIC"
}
```

### With Environment Variables

```hcl
module "evidence_collector_agent" {
  source = "../../modules/agentcore_agent"

  agent_runtime_name = "auditron_evidence_collector_v1"
  agent_display_name = "EvidenceCollector"

  role_arn      = aws_iam_role.bedrock_agentcore.arn
  container_uri = "123456789012.dkr.ecr.us-west-2.amazonaws.com/evidence-collector:latest"

  environment_variables = {
    BYPASS_TOOL_CONSENT        = "true"
    PYTHONPATH                 = "/app"
    STRANDS_SHELL_MAX_PARALLEL = "10"
    STRANDS_SHELL_TIMEOUT      = "300"
  }

  network_mode = "PUBLIC"
}
```

### With VPC Configuration

```hcl
module "vpc_agent" {
  source = "../../modules/agentcore_agent"

  agent_runtime_name = "auditron_vpc_agent_v1"
  agent_display_name = "VpcAgent"

  role_arn      = aws_iam_role.bedrock_agentcore.arn
  container_uri = "123456789012.dkr.ecr.us-west-2.amazonaws.com/vpc-agent:latest"

  network_mode = "VPC"
  vpc_config = {
    security_groups = [aws_security_group.agent.id]
    subnets         = aws_subnet.private[*].id
  }
}
```

### With Custom Protocol

```hcl
module "mcp_agent" {
  source = "../../modules/agentcore_agent"

  agent_runtime_name = "auditron_mcp_agent_v1"
  agent_display_name = "McpAgent"

  role_arn      = aws_iam_role.bedrock_agentcore.arn
  container_uri = "123456789012.dkr.ecr.us-west-2.amazonaws.com/mcp-agent:latest"

  server_protocol = "MCP"
  network_mode    = "PUBLIC"

  description = "Agent runtime with MCP protocol support"
}
```

### With Endpoints

```hcl
module "multi_env_agent" {
  source = "../../modules/agentcore_agent"

  agent_runtime_name = "auditron_multi_env_v1"
  agent_display_name = "MultiEnvAgent"

  role_arn      = aws_iam_role.bedrock_agentcore.arn
  container_uri = "123456789012.dkr.ecr.us-west-2.amazonaws.com/multi-env:latest"

  network_mode = "PUBLIC"

  endpoints = {
    dev = {
      name        = "dev"
      description = "Development endpoint"
    }
    prod = {
      name        = "prod"
      description = "Production endpoint"
    }
  }
}
```

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

No modules.

### Resources

| Name | Type |
|------|------|
| [aws_bedrockagentcore_agent_runtime.agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_agent_runtime) | resource |
| [aws_bedrockagentcore_agent_runtime_endpoint.endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_agent_runtime_endpoint) | resource |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_display_name"></a> [agent\_display\_name](#input\_agent\_display\_name) | Display name for tags (e.g., 'BrowserAutomation', 'CommandGenerator') | `string` | n/a | yes |
| <a name="input_agent_runtime_name"></a> [agent\_runtime\_name](#input\_agent\_runtime\_name) | Full runtime name for the agent (e.g., 'auditron\_browser\_automation\_v1') | `string` | n/a | yes |
| <a name="input_container_uri"></a> [container\_uri](#input\_container\_uri) | Full container image URI with tag (e.g., 123456789012.dkr.ecr.us-west-2.amazonaws.com/agent:v1.0.0) | `string` | n/a | yes |
| <a name="input_role_arn"></a> [role\_arn](#input\_role\_arn) | ARN of the IAM role that the agent runtime assumes | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Description of the agent runtime | `string` | `null` | no |
| <a name="input_endpoints"></a> [endpoints](#input\_endpoints) | Map of endpoints to create for this agent runtime. Each endpoint acts as a version/environment. | <pre>map(object({<br/>    name                  = string<br/>    description           = optional(string)<br/>    agent_runtime_version = optional(string)<br/>    tags                  = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Map of environment variables to pass to the container | `map(string)` | `{}` | no |
| <a name="input_network_mode"></a> [network\_mode](#input\_network\_mode) | Network mode for the agent runtime (PUBLIC, VPC, SANDBOX) | `string` | `"PUBLIC"` | no |
| <a name="input_server_protocol"></a> [server\_protocol](#input\_server\_protocol) | Server protocol for the agent runtime (HTTP, MCP, A2A) | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to the agent runtime | `map(string)` | `{}` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | VPC configuration for the agent runtime (required if network\_mode is VPC) | <pre>object({<br/>    security_groups = list(string)<br/>    subnets         = list(string)<br/>  })</pre> | `null` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_agent_runtime_arn"></a> [agent\_runtime\_arn](#output\_agent\_runtime\_arn) | The ARN of the agent runtime |
| <a name="output_agent_runtime_id"></a> [agent\_runtime\_id](#output\_agent\_runtime\_id) | The unique identifier of the agent runtime |
| <a name="output_agent_runtime_name"></a> [agent\_runtime\_name](#output\_agent\_runtime\_name) | The name of the agent runtime |
| <a name="output_agent_runtime_version"></a> [agent\_runtime\_version](#output\_agent\_runtime\_version) | The version of the agent runtime |
| <a name="output_container_uri"></a> [container\_uri](#output\_container\_uri) | The full container URI used by the agent runtime |
| <a name="output_endpoints"></a> [endpoints](#output\_endpoints) | Map of endpoint details for this agent runtime |
| <a name="output_workload_identity_arn"></a> [workload\_identity\_arn](#output\_workload\_identity\_arn) | The ARN of the workload identity associated with the agent runtime |
<!-- END_TF_DOCS -->

## Common Patterns

### Standard Auditron Agent

Most Auditron agents follow this pattern:

```hcl
module "agent" {
  source = "../../modules/agentcore_agent"

  agent_runtime_name = "auditron_<snake_case_name>_v1"
  agent_display_name = "<PascalCaseName>"

  role_arn      = aws_iam_role.bedrock_agentcore.arn
  container_uri = "${aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/<repo>:latest"

  network_mode = "PUBLIC"
}
```

### Importing Existing Resources

To import an existing agent runtime into this module:

```bash
terraform import 'module.agent_name.aws_bedrockagentcore_agent_runtime.agent' <agent_runtime_id>
```

## Notes

- The `agent_runtime_version` is managed by AWS and will update automatically when the agent runtime is modified
- Environment variables with empty values are not supported by AWS and will cause errors
- VPC configuration is only applied when `network_mode = "VPC"`
- Protocol configuration is optional and only added when `server_protocol` is specified

