# Teams Handler

Deploys a Microsoft Teams Bot Framework message handler for the human-in-the-loop (HITL) assessment workflow. Users interact with agents via Teams messages, and assessment results are delivered back via Adaptive Cards with approval/rejection actions.

## Features

- API Gateway HTTP API with Teams Bot Framework CORS configuration
- Lambda function (ARM64 container image) for handling Bot Framework messages and Adaptive Cards
- DynamoDB table for assessment state tracking with configurable TTL
- SSM Parameter Store integration for Teams/Azure Bot credentials
- Least-privilege IAM with scoped access to agent invocation, DynamoDB, and SSM

## Architecture

```
Teams Bot Framework --> API Gateway (POST /teams/messages) --> Lambda --> Bedrock AgentCore
                                                                 |
                                                                 +--> DynamoDB (assessment state)
                                                                 +--> SSM Parameters (credentials)
```

## Usage

```hcl
module "teams_handler" {
  source = "git::https://github.com/Coalfire-AI/terraform-modules.git//modules/teams_handler?ref=v2.1.0"

  deployment_name          = "my-deployment"
  aws_region               = "us-west-2"
  container_uri            = "123456789012.dkr.ecr.us-west-2.amazonaws.com/teams-handler:v1.0.0"
  primary_orchestrator_arn = module.tra_infra.agents["primary_orchestrator"].agent_runtime_arn
  ssm_parameter_prefix     = "/my-org"

  tags = {
    Environment = "production"
  }
}
```

> **Note:** This module is typically deployed via the [`tra_infra`](../tra_infra/) orchestrator module rather than standalone.

## Prerequisites

Before deploying, create the required SSM parameters for your Azure Bot registration credentials under `{ssm_parameter_prefix}/{deployment_name}/`.

## Outputs

After deployment, configure your Azure Bot's **Messaging Endpoint** to the `teams_messages_url` output.

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
| [aws_apigatewayv2_api.teams_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_apigatewayv2_integration.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.teams_messages](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_cloudwatch_log_group.api_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.assessments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_role.teams_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.ecr_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.kms_decrypt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.teams_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.teams_handler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.api_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for deployment | `string` | n/a | yes |
| <a name="input_container_uri"></a> [container\_uri](#input\_container\_uri) | ECR image URI for the Teams handler Lambda | `string` | n/a | yes |
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment (used for resource naming) | `string` | n/a | yes |
| <a name="input_primary_orchestrator_arn"></a> [primary\_orchestrator\_arn](#input\_primary\_orchestrator\_arn) | ARN of the primary orchestrator agent runtime | `string` | n/a | yes |
| <a name="input_ssm_parameter_prefix"></a> [ssm\_parameter\_prefix](#input\_ssm\_parameter\_prefix) | SSM parameter prefix for handler configuration (e.g., '/my-org') | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of the KMS key for parameter decryption | `string` | `null` | no |
| <a name="input_lambda_memory_size"></a> [lambda\_memory\_size](#input\_lambda\_memory\_size) | Lambda memory size in MB | `number` | `256` | no |
| <a name="input_lambda_timeout"></a> [lambda\_timeout](#input\_lambda\_timeout) | Lambda timeout in seconds | `number` | `30` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | Optional VPC configuration for Lambda | <pre>object({<br/>    subnet_ids         = list(string)<br/>    security_group_ids = list(string)<br/>  })</pre> | `null` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_endpoint"></a> [api\_endpoint](#output\_api\_endpoint) | API Gateway endpoint URL for Teams Bot Framework webhooks |
| <a name="output_api_gateway_id"></a> [api\_gateway\_id](#output\_api\_gateway\_id) | API Gateway ID |
| <a name="output_cloudwatch_log_group_api"></a> [cloudwatch\_log\_group\_api](#output\_cloudwatch\_log\_group\_api) | CloudWatch log group for API Gateway |
| <a name="output_cloudwatch_log_group_lambda"></a> [cloudwatch\_log\_group\_lambda](#output\_cloudwatch\_log\_group\_lambda) | CloudWatch log group for Lambda |
| <a name="output_dynamodb_table_arn"></a> [dynamodb\_table\_arn](#output\_dynamodb\_table\_arn) | DynamoDB table ARN for assessment mappings |
| <a name="output_dynamodb_table_name"></a> [dynamodb\_table\_name](#output\_dynamodb\_table\_name) | DynamoDB table name for assessment mappings |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | Teams handler Lambda function ARN |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Teams handler Lambda function name |
| <a name="output_lambda_role_arn"></a> [lambda\_role\_arn](#output\_lambda\_role\_arn) | IAM role ARN for the Lambda function |
| <a name="output_teams_messages_url"></a> [teams\_messages\_url](#output\_teams\_messages\_url) | Full URL for Teams messages endpoint (configure in Azure Bot) |
<!-- END_TF_DOCS -->
