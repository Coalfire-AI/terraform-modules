# Chunk Metadata Transformer Module

Terraform module for deploying a POST_CHUNKING Lambda transformation for AWS Bedrock Knowledge Base. This Lambda enriches each chunk with NIST control metadata while staying under S3 Vectors' 2KB filterable metadata limit.

## Problem Solved

When ingesting NIST compliance documents into Bedrock Knowledge Base with S3 Vectors storage, document-level metadata containing all control IDs (300+ for SP 800-53) exceeds the **2KB filterable metadata hard limit**.

This module implements a **two-tier metadata strategy**:
- **Filterable metadata** (~200-400 bytes): Indexed, searchable fields
- **Non-filterable metadata** (~1-2KB): Stored but not indexed, for context

## Architecture

```
Document Upload → Bedrock KB (SEMANTIC chunking) → POST_CHUNKING Lambda → S3 Vectors
                                                            ↓
                                                   Per-chunk metadata extraction
                                                            ↓
                                            ┌─────────────────────────────────┐
                                            │ Filterable (~200-400 bytes)     │
                                            │ - primary_family: "AC"          │
                                            │ - document_type: "policy"       │
                                            │ - compliance_framework: "NIST"  │
                                            │ - control_count: 3              │
                                            ├─────────────────────────────────┤
                                            │ Non-Filterable (x_ prefix)      │
                                            │ - x_chunk_control_ids: [...]    │
                                            │ - x_source_section: "3.2 AC-2"  │
                                            │ - x_enhancements: [...]         │
                                            └─────────────────────────────────┘
```

## Usage

### Basic Usage

```hcl
module "chunk_transformer" {
  source = "./modules/chunk_metadata_transformer"

  name = "nist-kb"

  intermediate_storage_bucket_arn = module.knowledge_base.data_source_bucket_arn
  intermediate_storage_prefix     = "intermediate/"

  tags = {
    Environment = "production"
    Project     = "compliance-kb"
  }
}

module "knowledge_base" {
  source = "./modules/bedrock_knowledge_base"

  name = "nist-kb"

  # Enable semantic chunking (recommended for S3 Vectors)
  chunking_strategy = "SEMANTIC"

  # Enable POST_CHUNKING transformation
  enable_custom_transformation    = true
  transformation_lambda_arn       = module.chunk_transformer.lambda_function_arn
  transformation_step             = "POST_CHUNKING"
  intermediate_storage_bucket_arn = module.knowledge_base.data_source_bucket_arn
  intermediate_storage_prefix     = "intermediate/"
}
```

### With Preprocessing Pipeline

```hcl
module "preprocessing" {
  source = "./modules/preprocessing_lambda"

  name              = "nist-kb"
  source_bucket_arn = module.knowledge_base.data_source_bucket_arn
  source_bucket_name = module.knowledge_base.data_source_bucket_name

  raw_documents_prefix       = "raw/"
  processed_documents_prefix = "processed/"
}

module "chunk_transformer" {
  source = "./modules/chunk_metadata_transformer"

  name = "nist-kb"

  intermediate_storage_bucket_arn = module.knowledge_base.data_source_bucket_arn
  intermediate_storage_prefix     = "intermediate/"

  compliance_framework   = "NIST-800-218-SSDF"
  default_document_type = "policy"
}

module "knowledge_base" {
  source = "./modules/bedrock_knowledge_base"

  name = "nist-kb"

  # Use preprocessed documents
  enable_preprocessing       = true
  processed_documents_prefix = "processed/"

  # Semantic chunking preserves context
  chunking_strategy = "SEMANTIC"
  semantic_max_tokens = 512

  # POST_CHUNKING adds per-chunk metadata
  enable_custom_transformation    = true
  transformation_lambda_arn       = module.chunk_transformer.lambda_function_arn
  transformation_step             = "POST_CHUNKING"
  intermediate_storage_bucket_arn = module.knowledge_base.data_source_bucket_arn
}
```

## Metadata Extracted

### Filterable Metadata (Indexed)

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `compliance_framework` | string | Compliance framework ID | `"NIST-800-218-SSDF"` |
| `document_type` | string | Document classification | `"policy"`, `"procedure"` |
| `primary_family` | string | Most referenced control family | `"AC"` |
| `primary_family_name` | string | Family full name | `"Access Control"` |
| `control_count` | number | Controls in this chunk | `3` |

### Non-Filterable Metadata (Stored, not indexed)

| Field | Type | Description |
|-------|------|-------------|
| `x_chunk_control_ids` | array | Control IDs in this chunk |
| `x_family_distribution` | object | Control counts by family |
| `x_source_section` | string | Section header if detected |
| `x_enhancements` | array | Control enhancements found |
| `x_source_uri` | string | Source document S3 URI |

## NIST Control Detection

The Lambda extracts:
- **Base controls**: AC-1, AU-12, SI-7, etc.
- **Enhancements**: AC-2(1), SI-7(15), etc.
- **All 20 NIST 800-53 families**: AC, AT, AU, CA, CM, CP, IA, IR, MA, MP, PE, PL, PM, PS, PT, RA, SA, SC, SI, SR

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecr_lifecycle_policy.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_iam_role.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cloudwatch_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.kms_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.s3_intermediate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.transformer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.bedrock_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_intermediate_storage_bucket_arn"></a> [intermediate\_storage\_bucket\_arn](#input\_intermediate\_storage\_bucket\_arn) | ARN of S3 bucket for Bedrock intermediate transformation storage | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources created by this module | `string` | n/a | yes |
| <a name="input_cloudwatch_log_retention_days"></a> [cloudwatch\_log\_retention\_days](#input\_cloudwatch\_log\_retention\_days) | Number of days to retain CloudWatch logs | `number` | `30` | no |
| <a name="input_compliance_framework"></a> [compliance\_framework](#input\_compliance\_framework) | Compliance framework identifier for metadata (NIST-800-218-SSDF, NIST-800-53, or AWS-WAF) | `string` | `"NIST-800-218-SSDF"` | no |
| <a name="input_create_ecr_repository"></a> [create\_ecr\_repository](#input\_create\_ecr\_repository) | Whether to create an ECR repository for the Lambda container image | `bool` | `true` | no |
| <a name="input_create_iam_role"></a> [create\_iam\_role](#input\_create\_iam\_role) | Whether to create an IAM role for the Lambda function | `bool` | `true` | no |
| <a name="input_default_document_type"></a> [default\_document\_type](#input\_default\_document\_type) | Default document type when inference fails | `string` | `"policy"` | no |
| <a name="input_ecr_repository_arn"></a> [ecr\_repository\_arn](#input\_ecr\_repository\_arn) | ARN of existing ECR repository (required if create\_ecr\_repository is false) | `string` | `null` | no |
| <a name="input_ecr_repository_name"></a> [ecr\_repository\_name](#input\_ecr\_repository\_name) | Name for the ECR repository. Defaults to {name}-chunk-transformer | `string` | `null` | no |
| <a name="input_function_name"></a> [function\_name](#input\_function\_name) | Name for the Lambda function. Defaults to {name}-chunk-transformer | `string` | `null` | no |
| <a name="input_iam_role_arn"></a> [iam\_role\_arn](#input\_iam\_role\_arn) | ARN of existing IAM role (required if create\_iam\_role is false) | `string` | `null` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Name for the IAM role. Defaults to {name}-chunk-transformer-role | `string` | `null` | no |
| <a name="input_image_uri"></a> [image\_uri](#input\_image\_uri) | Container image URI from ECR (REQUIRED).<br/><br/>Local Docker builds are not supported. You must provide a pre-built container<br/>image from CI/CD (e.g., GitHub Actions). See the workflow template at:<br/>.github/workflows/examples/lambda-images-build.yml.example<br/><br/>Format: <account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag><br/>Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/chunk-metadata-transformer:sha-abc1234 | `string` | `null` | no |
| <a name="input_intermediate_storage_prefix"></a> [intermediate\_storage\_prefix](#input\_intermediate\_storage\_prefix) | S3 prefix for intermediate transformation storage | `string` | `"intermediate/"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of KMS key used to encrypt intermediate storage bucket. Required if bucket uses KMS encryption. | `string` | `null` | no |
| <a name="input_lambda_log_format"></a> [lambda\_log\_format](#input\_lambda\_log\_format) | Log format for Lambda function (Text or JSON) | `string` | `"JSON"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda function | `string` | `"INFO"` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Memory allocation for Lambda in MB. 256-512MB is sufficient for metadata extraction | `number` | `512` | no |
| <a name="input_reserved_concurrent_executions"></a> [reserved\_concurrent\_executions](#input\_reserved\_concurrent\_executions) | Reserved concurrent executions for Lambda. -1 for no limit | `number` | `-1` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Lambda timeout in seconds. POST\_CHUNKING typically completes quickly | `number` | `60` | no |
| <a name="input_use_graviton"></a> [use\_graviton](#input\_use\_graviton) | Use ARM64 Graviton2 architecture for cost savings | `bool` | `true` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_bedrock_integration"></a> [bedrock\_integration](#output\_bedrock\_integration) | Configuration block for Bedrock Knowledge Base integration |
| <a name="output_cloudwatch_log_group_arn"></a> [cloudwatch\_log\_group\_arn](#output\_cloudwatch\_log\_group\_arn) | ARN of the CloudWatch log group |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Name of the CloudWatch log group |
| <a name="output_ecr_repository_arn"></a> [ecr\_repository\_arn](#output\_ecr\_repository\_arn) | ARN of the ECR repository |
| <a name="output_ecr_repository_url"></a> [ecr\_repository\_url](#output\_ecr\_repository\_url) | URL of the ECR repository |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | ARN of the Lambda IAM role |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | Name of the Lambda IAM role |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | ARN of the chunk metadata transformer Lambda function |
| <a name="output_lambda_function_invoke_arn"></a> [lambda\_function\_invoke\_arn](#output\_lambda\_function\_invoke\_arn) | Invoke ARN of the Lambda function (for API Gateway/Bedrock integration) |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Name of the chunk metadata transformer Lambda function |
| <a name="output_lambda_function_qualified_arn"></a> [lambda\_function\_qualified\_arn](#output\_lambda\_function\_qualified\_arn) | Qualified ARN of the Lambda function (includes version) |
| <a name="output_transformation_lambda_arn"></a> [transformation\_lambda\_arn](#output\_transformation\_lambda\_arn) | Lambda ARN formatted for Bedrock KB transformation\_lambda\_arn variable |
<!-- END_TF_DOCS -->

## S3 Vectors Constraints

| Constraint | Limit | How This Module Handles It |
|------------|-------|---------------------------|
| Filterable metadata | 2,048 bytes | Only 5-6 small fields (~200-400 bytes) |
| Non-filterable keys | 10 max | 5 non-filterable fields with `x_` prefix |
| Total metadata | 40KB | Well under limit per chunk |

## Important Notes

1. **Non-filterable metadata keys must be defined at S3 Vectors index creation time**
2. **Use SEMANTIC chunking** - AWS warns against HIERARCHICAL for S3 Vectors metadata
3. **The `x_` prefix distinguishes non-filterable from filterable metadata**

## License

Apache 2.0
