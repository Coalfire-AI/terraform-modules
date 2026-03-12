# Log Retention Enforcer

Automatically sets retention policies on CloudWatch log groups created by Bedrock AgentCore runtimes. AgentCore creates log groups dynamically at runtime without configurable retention, defaulting to indefinite retention. This module uses EventBridge to detect `CreateLogGroup` CloudTrail events and triggers a Lambda to set the desired retention policy.

## Features

- Listens for `CreateLogGroup` events via EventBridge (CloudTrail integration required)
- Filters by configurable log group prefix (defaults to `/aws/bedrock-agentcore/runtimes/`)
- Sets retention policy via Lambda (inline Python, no external dependencies)
- Lightweight: 128MB memory, Python 3.12 runtime

## Usage

```hcl
module "log_retention_enforcer" {
  source = "git::https://github.com/Coalfire-AI/terraform-modules.git//modules/log_retention_enforcer?ref=v2.1.0"

  deployment_name  = "my-deployment"
  log_group_prefix = "/aws/bedrock-agentcore/runtimes/"
  retention_days   = 14

  tags = {
    Environment = "production"
  }
}
```

> **Note:** This module is typically deployed via the [`tra_infra`](../tra_infra/) orchestrator module rather than standalone.

## Prerequisites

- CloudTrail must be enabled in the account for EventBridge to receive `CreateLogGroup` API events.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.create_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.enforcer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [archive_file.lambda_code](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_iam_policy_document.lambda_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment (used for resource naming) | `string` | n/a | yes |
| <a name="input_log_group_prefix"></a> [log\_group\_prefix](#input\_log\_group\_prefix) | Prefix for log groups to monitor (e.g., '/aws/bedrock-agentcore/runtimes/') | `string` | `"/aws/bedrock-agentcore/runtimes/"` | no |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Number of days to retain logs | `number` | `14` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_eventbridge_rule_arn"></a> [eventbridge\_rule\_arn](#output\_eventbridge\_rule\_arn) | ARN of the EventBridge rule |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | ARN of the log retention enforcer Lambda function |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Name of the log retention enforcer Lambda function |
| <a name="output_log_group_prefix"></a> [log\_group\_prefix](#output\_log\_group\_prefix) | The log group prefix being monitored |
| <a name="output_retention_days"></a> [retention\_days](#output\_retention\_days) | The retention period being enforced |
<!-- END_TF_DOCS -->
