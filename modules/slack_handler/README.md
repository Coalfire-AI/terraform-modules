# Slack Handler

Deploys a Slack slash command and interactive component handler for the human-in-the-loop (HITL) assessment workflow. Users interact with agents via Slack slash commands, and assessment results are delivered back via interactive messages with approval/rejection buttons.

## Features

- API Gateway HTTP API with Slack-specific CORS configuration
- Lambda function (ARM64 container image) for handling slash commands and interactive components
- DynamoDB table for assessment state tracking with configurable TTL
- Optional provisioned concurrency to eliminate cold starts
- SSM Parameter Store integration for Slack credentials (injected at deploy time for faster cold starts)
- Least-privilege IAM with scoped access to agent invocation, DynamoDB, and SSM

## Architecture

```
Slack App --> API Gateway (POST /slack/events) --> Lambda --> Bedrock AgentCore
                                                     |
                                                     +--> DynamoDB (assessment state)
                                                     +--> SSM Parameters (credentials)
```

## Usage

```hcl
module "slack_handler" {
  source = "git::https://github.com/Coalfire-AI/terraform-modules.git//modules/slack_handler?ref=v2.1.0"

  deployment_name          = "my-deployment"
  aws_region               = "us-west-2"
  container_uri            = "123456789012.dkr.ecr.us-west-2.amazonaws.com/slack-handler:v1.0.0"
  primary_orchestrator_arn = module.tra_infra.agents["primary_orchestrator"].agent_runtime_arn
  ssm_parameter_prefix     = "/my-org"

  tags = {
    Environment = "production"
  }
}
```

> **Note:** This module is typically deployed via the [`tra_infra`](../tra_infra/) orchestrator module rather than standalone.

## Prerequisites

Before deploying, create the following SSM parameters:

| Parameter Path | Type | Description |
|---------------|------|-------------|
| `{ssm_parameter_prefix}/{deployment_name}/slack-token` | SecureString | Slack Bot OAuth token |
| `{ssm_parameter_prefix}/{deployment_name}/slack-signing-secret` | SecureString | Slack app signing secret |
| `{ssm_parameter_prefix}/{deployment_name}/handler-channel` | String | Slack channel ID for slash commands |

## Outputs

After deployment, configure your Slack app's **Event Subscriptions** and **Interactivity** URLs to the `slack_events_url` output.

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
| [aws_apigatewayv2_api.slack_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_apigatewayv2_integration.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_integration.lambda_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.slack_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_cloudwatch_log_group.api_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.assessments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_role.slack_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.ecr_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.kms_decrypt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.lambda_self_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.s3_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.s3_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.slack_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_alias.live](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_alias) | resource |
| [aws_lambda_function.slack_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.api_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_provisioned_concurrency_config.slack_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_provisioned_concurrency_config) | resource |
| [aws_ssm_parameter.handler_channel](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.slack_bot_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.slack_signing_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for deployment | `string` | n/a | yes |
| <a name="input_container_uri"></a> [container\_uri](#input\_container\_uri) | ECR image URI for the Slack handler Lambda | `string` | n/a | yes |
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment (used for resource naming) | `string` | n/a | yes |
| <a name="input_primary_orchestrator_arn"></a> [primary\_orchestrator\_arn](#input\_primary\_orchestrator\_arn) | ARN of the primary orchestrator agent runtime | `string` | n/a | yes |
| <a name="input_ssm_parameter_prefix"></a> [ssm\_parameter\_prefix](#input\_ssm\_parameter\_prefix) | SSM parameter prefix for handler configuration (e.g., '/my-org') | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of the KMS key for parameter decryption | `string` | `null` | no |
| <a name="input_lambda_memory_size"></a> [lambda\_memory\_size](#input\_lambda\_memory\_size) | Lambda memory size in MB | `number` | `256` | no |
| <a name="input_lambda_timeout"></a> [lambda\_timeout](#input\_lambda\_timeout) | Lambda timeout in seconds | `number` | `30` | no |
| <a name="input_object_store_bucket_arn"></a> [object\_store\_bucket\_arn](#input\_object\_store\_bucket\_arn) | ARN of the S3 bucket containing docs, templates, inputs, and outputs. Required for /tra docs and /tra templates commands. | `string` | `null` | no |
| <a name="input_provisioned_concurrency"></a> [provisioned\_concurrency](#input\_provisioned\_concurrency) | Number of provisioned concurrency instances (0 to disable). Eliminates cold starts but costs ~$37/year per instance at 256MB. | `number` | `0` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | Optional VPC configuration for Lambda | <pre>object({<br/>    subnet_ids         = list(string)<br/>    security_group_ids = list(string)<br/>  })</pre> | `null` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_endpoint"></a> [api\_endpoint](#output\_api\_endpoint) | API Gateway endpoint URL for Slack webhooks |
| <a name="output_api_gateway_id"></a> [api\_gateway\_id](#output\_api\_gateway\_id) | API Gateway ID |
| <a name="output_cloudwatch_log_group_api"></a> [cloudwatch\_log\_group\_api](#output\_cloudwatch\_log\_group\_api) | CloudWatch log group for API Gateway |
| <a name="output_cloudwatch_log_group_lambda"></a> [cloudwatch\_log\_group\_lambda](#output\_cloudwatch\_log\_group\_lambda) | CloudWatch log group for Lambda |
| <a name="output_dynamodb_table_arn"></a> [dynamodb\_table\_arn](#output\_dynamodb\_table\_arn) | DynamoDB table ARN for assessment mappings |
| <a name="output_dynamodb_table_name"></a> [dynamodb\_table\_name](#output\_dynamodb\_table\_name) | DynamoDB table name for assessment mappings |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | Slack handler Lambda function ARN |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Slack handler Lambda function name |
| <a name="output_lambda_role_arn"></a> [lambda\_role\_arn](#output\_lambda\_role\_arn) | IAM role ARN for the Lambda function |
| <a name="output_slack_events_url"></a> [slack\_events\_url](#output\_slack\_events\_url) | Full URL for Slack events endpoint (configure in Slack app) |
<!-- END_TF_DOCS -->
