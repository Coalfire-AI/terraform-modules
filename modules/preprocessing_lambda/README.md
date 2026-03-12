# Preprocessing Lambda Module

Terraform module for deploying a document preprocessing Lambda function that uses [Docling](https://github.com/DS4SD/docling) to parse PDF/DOCX files and extract NIST control metadata.

## Architecture

![NIST Document Ingestion Pipeline](https://mermaid.ink/svg/pako:eNqNk29P2zAQxt_vU5yMNhUJ1tJWFaAJifwpoCalTUo1ydoLJ7mkFmmcOQ6lUj48ipOidBqIvHFs_-658-NznIpduGFSwcr4BgBQlEEiWb6BMk8FiyixRFhuMVPwpBfIH43V3xPtkacCZd_fFwq35LSzBefnNxVpQmBhTfvWo_mbVOCPPEr80TVItutDLjHmr60kZpEej8vIJeZShFgUPEsoWXSn4LBtELFOSf7IazL7I7Bf6qpXkicJSlKBQ0nDw7TMQsVF9iuQ_ZveredOxmCKTDGeoTztyDmN2ILJAkkFlnYj1Zl5IJnca4UVC1IE-1VJpmXhavgdphcdHavRaRFSwZyS-YO_AhcVi5hiWqcuQYoUHqziDKZsy1OORUdl3qg8llovFbhMPkdil2lTF42prTUY_WNte5afdfiU8RQjcLEoWIJFfSxnSYmFLAIHlUIJyxJL_PRWAoykCJ8pMZofmGVil2KUIBiswKMbWTRlW0wx8EUpw9rKmUHJhzEzo71E272drx5MMDdl9syzhFRg3s8o0XM4dGbXI_N-1nq9DTCCHVcbWHHFMlgPSQW2a1ByMRiOzyO-hTWGSshuuO0eUish6zrXtkl7dTcd2NPPbPlbotxTsqwHmKZi15Fetq8F9G73sSyblB4qyfEF4QfcYYaSqcaod25tm21xfMtTJrnag49Mhptj7mCfd3sHHha5yHT3erRHDlNtjG463YYmV6zu3A-Op_Yp6qcV8zS9Ponjq6vB4CwUqZDXJ4PB4IhafIFyvsDMjBa6DMdxHB-gOI47UG1JQ43iy8lw_H_KcpbvCSfBJOhQb8c_dDc)

## Features

- **Docling Integration**: Uses IBM's Docling library for high-quality PDF/DOCX parsing
- **Table Extraction**: 92% F1 score on table structure recognition
- **NIST Metadata Extraction**: Automatically extracts control IDs, enhancements, and families
- **ARM64 Graviton2**: 20-30% cost savings with ARM64 architecture
- **Container Image**: Pre-built container with all dependencies
- **S3 Event Trigger**: Automatic processing on document upload
- **Dead Letter Queue**: Handles failed processing gracefully
- **Markdown Output**: Clean output format with YAML frontmatter

## Usage

### Basic Usage

```hcl
module "preprocessing_lambda" {
  source = "path/to/modules/preprocessing_lambda"

  name               = "my-preprocessor"
  source_bucket_name = "my-documents-bucket"
  source_bucket_arn  = "arn:aws:s3:::my-documents-bucket"

  tags = {
    Environment = "production"
  }
}
```

### With Bedrock Knowledge Base Integration

```hcl
module "knowledge_base" {
  source = "path/to/modules/bedrock_knowledge_base"

  name                       = "nist-kb"
  enable_preprocessing       = true
  raw_documents_prefix       = "raw/"
  processed_documents_prefix = "processed/"
  chunking_strategy          = "SEMANTIC"
}

module "preprocessing_lambda" {
  source = "path/to/modules/preprocessing_lambda"

  name               = "nist-kb"
  source_bucket_name = module.knowledge_base.data_source_bucket_name
  source_bucket_arn  = module.knowledge_base.data_source_bucket_arn
  output_bucket_name = module.knowledge_base.data_source_bucket_name
  output_bucket_arn  = module.knowledge_base.data_source_bucket_arn

  raw_documents_prefix       = "raw/"
  processed_documents_prefix = "processed/"

  enable_s3_trigger        = true
  s3_trigger_filter_suffix = ".pdf"
  extract_nist_metadata    = true
}
```

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0.0 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.dlq_messages](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_ecr_lifecycle_policy.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecr_repository_policy.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository_policy) | resource |
| [aws_iam_role.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cloudwatch_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.dlq_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ecr_pull](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.kms_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.s3_output_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.s3_source_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.xray_tracing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.preprocessing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.s3_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_s3_bucket_notification.source_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_sqs_queue.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources created by this module | `string` | n/a | yes |
| <a name="input_source_bucket_arn"></a> [source\_bucket\_arn](#input\_source\_bucket\_arn) | ARN of the S3 bucket containing raw documents | `string` | n/a | yes |
| <a name="input_source_bucket_name"></a> [source\_bucket\_name](#input\_source\_bucket\_name) | Name of the S3 bucket containing raw documents to process | `string` | n/a | yes |
| <a name="input_additional_environment_variables"></a> [additional\_environment\_variables](#input\_additional\_environment\_variables) | Additional environment variables for the Lambda function | `map(string)` | `{}` | no |
| <a name="input_additional_iam_policies"></a> [additional\_iam\_policies](#input\_additional\_iam\_policies) | List of additional IAM policy ARNs to attach to the Lambda role | `list(string)` | `[]` | no |
| <a name="input_chunk_overlap_tokens"></a> [chunk\_overlap\_tokens](#input\_chunk\_overlap\_tokens) | Number of overlapping tokens between consecutive chunks.<br/><br/>Overlap helps preserve context across chunk boundaries for better<br/>semantic search results. Recommended: 10-20% of chunk\_size\_tokens.<br/><br/>With section-aware chunking, overlap does NOT cross section boundaries. | `number` | `64` | no |
| <a name="input_chunk_size_tokens"></a> [chunk\_size\_tokens](#input\_chunk\_size\_tokens) | Target chunk size in tokens (using tiktoken cl100k\_base encoding).<br/><br/>For S3 Vectors with Bedrock KB, recommended values:<br/>- 256-512 for fine-grained retrieval<br/>- 512-1024 for balanced retrieval<br/>- 1024+ for broader context<br/><br/>Note: Actual chunks may be smaller at paragraph/section boundaries. | `number` | `512` | no |
| <a name="input_cloudwatch_log_retention_days"></a> [cloudwatch\_log\_retention\_days](#input\_cloudwatch\_log\_retention\_days) | Number of days to retain CloudWatch logs | `number` | `30` | no |
| <a name="input_create_ecr_repository"></a> [create\_ecr\_repository](#input\_create\_ecr\_repository) | Whether to create an ECR repository for the Lambda container image | `bool` | `true` | no |
| <a name="input_create_iam_role"></a> [create\_iam\_role](#input\_create\_iam\_role) | Whether to create an IAM role for the Lambda function | `bool` | `true` | no |
| <a name="input_dlq_arn"></a> [dlq\_arn](#input\_dlq\_arn) | ARN of existing SQS queue for DLQ. If null and enable\_dlq is true, creates a new queue | `string` | `null` | no |
| <a name="input_ecr_image_tag_mutability"></a> [ecr\_image\_tag\_mutability](#input\_ecr\_image\_tag\_mutability) | Image tag mutability setting for ECR | `string` | `"MUTABLE"` | no |
| <a name="input_ecr_repository_arn"></a> [ecr\_repository\_arn](#input\_ecr\_repository\_arn) | ARN of existing ECR repository (required if create\_ecr\_repository is false) | `string` | `null` | no |
| <a name="input_ecr_repository_name"></a> [ecr\_repository\_name](#input\_ecr\_repository\_name) | Name for the ECR repository. Defaults to {name}-preprocessing | `string` | `null` | no |
| <a name="input_ecr_scan_on_push"></a> [ecr\_scan\_on\_push](#input\_ecr\_scan\_on\_push) | Enable image scanning on push to ECR | `bool` | `true` | no |
| <a name="input_enable_chunking"></a> [enable\_chunking](#input\_enable\_chunking) | Enable pre-chunking in the preprocessing Lambda.<br/><br/>When true, documents are chunked before being stored in S3, which is REQUIRED<br/>when using Bedrock KB with S3 Vectors (set data source chunking\_strategy = "NONE").<br/><br/>When false, documents are stored as-is and Bedrock KB handles chunking. | `bool` | `false` | no |
| <a name="input_enable_dlq"></a> [enable\_dlq](#input\_enable\_dlq) | Enable Dead Letter Queue for failed invocations | `bool` | `true` | no |
| <a name="input_enable_kms"></a> [enable\_kms](#input\_enable\_kms) | Whether to enable KMS encryption. Set to true when kms\_key\_arn will be provided (even if computed at apply time) | `bool` | `false` | no |
| <a name="input_enable_s3_trigger"></a> [enable\_s3\_trigger](#input\_enable\_s3\_trigger) | Enable S3 event trigger for automatic processing | `bool` | `true` | no |
| <a name="input_enable_section_aware_chunking"></a> [enable\_section\_aware\_chunking](#input\_enable\_section\_aware\_chunking) | Enable section-aware chunking to preserve document structure.<br/><br/>When true (default), the chunker:<br/>- Detects section headings (Executive Summary, Introduction, etc.)<br/>- Preserves important sections intact when possible<br/>- Adds section\_type metadata to each chunk for filtering<br/>- Prevents overlap from crossing section boundaries<br/>- Excludes Table of Contents from content chunks<br/><br/>This is critical for compliance documents (SSDF, NIST, etc.) where<br/>executive summaries and introductions should be retrievable as units. | `bool` | `true` | no |
| <a name="input_enable_xray_tracing"></a> [enable\_xray\_tracing](#input\_enable\_xray\_tracing) | Enable AWS X-Ray tracing for the Lambda function | `bool` | `false` | no |
| <a name="input_enabled_frameworks"></a> [enabled\_frameworks](#input\_enabled\_frameworks) | Comma-separated list of compliance frameworks to extract metadata for.<br/>Available frameworks: NIST-800-218-SSDF, AWS-WAF<br/>The universal extractor supports multiple frameworks simultaneously. | `string` | `"NIST-800-218-SSDF,AWS-WAF"` | no |
| <a name="input_ephemeral_storage_size"></a> [ephemeral\_storage\_size](#input\_ephemeral\_storage\_size) | Ephemeral storage (/tmp) size in MB. Large documents may need more than default 512MB | `number` | `1024` | no |
| <a name="input_extract_nist_metadata"></a> [extract\_nist\_metadata](#input\_extract\_nist\_metadata) | Enable extraction of NIST control IDs and metadata from documents | `bool` | `true` | no |
| <a name="input_function_name"></a> [function\_name](#input\_function\_name) | Name for the Lambda function. Defaults to {name}-preprocessing | `string` | `null` | no |
| <a name="input_iam_role_arn"></a> [iam\_role\_arn](#input\_iam\_role\_arn) | ARN of existing IAM role (required if create\_iam\_role is false) | `string` | `null` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Name for the IAM role. Defaults to {name}-preprocessing-role | `string` | `null` | no |
| <a name="input_image_uri"></a> [image\_uri](#input\_image\_uri) | Container image URI from ECR (REQUIRED).<br/><br/>Local Docker builds are not supported. You must provide a pre-built container<br/>image from CI/CD (e.g., GitHub Actions). See the workflow template at:<br/>.github/workflows/examples/lambda-images-build.yml.example<br/><br/>Format: <account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag><br/>Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/preprocessing-lambda:sha-abc1234 | `string` | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of KMS key for encrypting processed documents. Required when enable\_kms is true | `string` | `null` | no |
| <a name="input_lambda_application_log_level"></a> [lambda\_application\_log\_level](#input\_lambda\_application\_log\_level) | Application log level for Lambda (only applies when lambda\_log\_format is JSON) | `string` | `"INFO"` | no |
| <a name="input_lambda_log_format"></a> [lambda\_log\_format](#input\_lambda\_log\_format) | Log format for Lambda function (Text or JSON). JSON enables structured logging with log levels. | `string` | `"JSON"` | no |
| <a name="input_lambda_system_log_level"></a> [lambda\_system\_log\_level](#input\_lambda\_system\_log\_level) | System log level for Lambda runtime (only applies when lambda\_log\_format is JSON) | `string` | `"INFO"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda function | `string` | `"INFO"` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Memory allocation for Lambda in MB. Docling recommends 1-2GB minimum | `number` | `2048` | no |
| <a name="input_metadata_output_mode"></a> [metadata\_output\_mode](#input\_metadata\_output\_mode) | Controls how much NIST metadata is included in the Markdown frontmatter:<br/>- "full": Include all control\_ids (legacy mode, for human readability)<br/>          WARNING: Can exceed S3 Vectors 2KB filterable metadata limit<br/>- "summary": Only counts and family codes (recommended with POST\_CHUNKING Lambda)<br/>- "minimal": No NIST metadata in frontmatter (POST\_CHUNKING handles everything)<br/><br/>When using the chunk\_metadata\_transformer module for POST\_CHUNKING, use "summary" or "minimal". | `string` | `"summary"` | no |
| <a name="input_output_bucket_arn"></a> [output\_bucket\_arn](#input\_output\_bucket\_arn) | ARN of the S3 bucket for processed documents. If null, uses source\_bucket\_arn | `string` | `null` | no |
| <a name="input_output_bucket_name"></a> [output\_bucket\_name](#input\_output\_bucket\_name) | Name of the S3 bucket for processed documents. If null, uses source\_bucket\_name | `string` | `null` | no |
| <a name="input_processed_documents_prefix"></a> [processed\_documents\_prefix](#input\_processed\_documents\_prefix) | S3 prefix for processed document output (Markdown files) | `string` | `"processed/"` | no |
| <a name="input_raw_documents_prefix"></a> [raw\_documents\_prefix](#input\_raw\_documents\_prefix) | S3 prefix for raw document uploads (triggers Lambda) | `string` | `"raw/"` | no |
| <a name="input_reserved_concurrent_executions"></a> [reserved\_concurrent\_executions](#input\_reserved\_concurrent\_executions) | Reserved concurrent executions for Lambda. -1 for no limit | `number` | `-1` | no |
| <a name="input_s3_trigger_events"></a> [s3\_trigger\_events](#input\_s3\_trigger\_events) | S3 event types to trigger Lambda | `list(string)` | <pre>[<br/>  "s3:ObjectCreated:Put",<br/>  "s3:ObjectCreated:CompleteMultipartUpload"<br/>]</pre> | no |
| <a name="input_s3_trigger_filter_suffix"></a> [s3\_trigger\_filter\_suffix](#input\_s3\_trigger\_filter\_suffix) | File suffix filter for S3 trigger (e.g., .pdf). Empty string for no suffix filter | `string` | `""` | no |
| <a name="input_section_max_tokens"></a> [section\_max\_tokens](#input\_section\_max\_tokens) | Maximum tokens for a section before it gets split.<br/><br/>Sections smaller than this are kept intact as single chunks (if possible).<br/>Larger sections are split using virtual preservation (same section\_type).<br/><br/>Recommended: 1024-2048 tokens for important sections like Executive Summary. | `number` | `1024` | no |
| <a name="input_sections_to_preserve"></a> [sections\_to\_preserve](#input\_sections\_to\_preserve) | Comma-separated list of section types to prioritize for preservation.<br/><br/>These sections will be kept intact as single chunks when under section\_max\_tokens.<br/>The section names are normalized (lowercase, underscores for spaces).<br/><br/>Default preserves document overview sections critical for RAG retrieval:<br/>"executive\_summary,abstract,introduction,purpose,scope" | `string` | `"executive_summary,abstract,introduction,purpose,scope"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Lambda timeout in seconds. Large documents may need 5+ minutes | `number` | `300` | no |
| <a name="input_use_graviton"></a> [use\_graviton](#input\_use\_graviton) | Use ARM64 Graviton2 architecture for 20-30% cost savings | `bool` | `true` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_architecture"></a> [architecture](#output\_architecture) | Lambda function architecture (arm64 or x86\_64) |
| <a name="output_dlq_alarm_arn"></a> [dlq\_alarm\_arn](#output\_dlq\_alarm\_arn) | ARN of the CloudWatch alarm for DLQ messages |
| <a name="output_dlq_arn"></a> [dlq\_arn](#output\_dlq\_arn) | ARN of the Dead Letter Queue (if created) |
| <a name="output_dlq_url"></a> [dlq\_url](#output\_dlq\_url) | URL of the Dead Letter Queue (if created) |
| <a name="output_ecr_repository_arn"></a> [ecr\_repository\_arn](#output\_ecr\_repository\_arn) | ARN of the ECR repository for Lambda container images |
| <a name="output_ecr_repository_name"></a> [ecr\_repository\_name](#output\_ecr\_repository\_name) | Name of the ECR repository |
| <a name="output_ecr_repository_url"></a> [ecr\_repository\_url](#output\_ecr\_repository\_url) | URL of the ECR repository for Lambda container images |
| <a name="output_extract_nist_metadata"></a> [extract\_nist\_metadata](#output\_extract\_nist\_metadata) | Whether NIST metadata extraction is enabled |
| <a name="output_function_arn"></a> [function\_arn](#output\_function\_arn) | ARN of the preprocessing Lambda function |
| <a name="output_function_invoke_arn"></a> [function\_invoke\_arn](#output\_function\_invoke\_arn) | Invoke ARN of the preprocessing Lambda function |
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | Name of the preprocessing Lambda function |
| <a name="output_function_qualified_arn"></a> [function\_qualified\_arn](#output\_function\_qualified\_arn) | Qualified ARN of the Lambda function (includes version) |
| <a name="output_function_version"></a> [function\_version](#output\_function\_version) | Latest published version of the Lambda function |
| <a name="output_log_format"></a> [log\_format](#output\_log\_format) | Log format configured for the Lambda function (Text or JSON) |
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | ARN of the CloudWatch Log Group |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Name of the CloudWatch Log Group for Lambda logs |
| <a name="output_memory_size"></a> [memory\_size](#output\_memory\_size) | Lambda function memory size in MB |
| <a name="output_processed_documents_prefix"></a> [processed\_documents\_prefix](#output\_processed\_documents\_prefix) | S3 prefix for processed document output |
| <a name="output_raw_documents_prefix"></a> [raw\_documents\_prefix](#output\_raw\_documents\_prefix) | S3 prefix for raw document uploads |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the IAM role for the Lambda function |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the IAM role for the Lambda function |
| <a name="output_s3_trigger_enabled"></a> [s3\_trigger\_enabled](#output\_s3\_trigger\_enabled) | Whether S3 trigger is enabled |
| <a name="output_timeout"></a> [timeout](#output\_timeout) | Lambda function timeout in seconds |
| <a name="output_xray_tracing_enabled"></a> [xray\_tracing\_enabled](#output\_xray\_tracing\_enabled) | Whether X-Ray tracing is enabled for the Lambda function |
<!-- END_TF_DOCS -->

## Building the Container Image

The Lambda function uses a container image. To build and push:

```bash
# Navigate to the docker directory
cd modules/preprocessing_lambda/docker

# Build the image (ARM64 for Graviton)
docker buildx build --platform linux/arm64 -t preprocessing-lambda:latest .

# Tag and push to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-west-2.amazonaws.com
docker tag preprocessing-lambda:latest <ecr-url>:latest
docker push <ecr-url>:latest
```

## NIST Metadata Extraction

The Lambda function extracts the following NIST metadata from documents:

- **Control IDs**: Patterns like `AC-1`, `SC-7`, `AU-2`
- **Control Enhancements**: Patterns like `AC-2(1)`, `SC-7(4)`
- **Control Families**: AC, AT, AU, CA, CM, CP, IA, IR, MA, MP, PE, PL, PM, PS, PT, RA, SA, SC, SI, SR

Extracted metadata is stored in YAML frontmatter:

```markdown
---
source_file: document.pdf
processed_at: 2026-01-06T12:00:00Z
nist_controls:
  - AC-1
  - AC-2
  - SC-7
nist_enhancements:
  - AC-2(1)
  - SC-7(4)
nist_families:
  - AC
  - SC
---

# Document Content

...
```

## Error Handling

Failed processing is handled via:

1. **Dead Letter Queue**: Failed messages are sent to SQS DLQ
2. **CloudWatch Alarm**: Alerts when messages appear in DLQ
3. **CloudWatch Logs**: Full processing logs retained for 30 days (configurable)

## Cost Estimates

| Component | Per 10,000 Pages |
|-----------|------------------|
| Lambda (2GB, 300s max) | ~$15.00 |
| S3 Storage | ~$0.05 |
| ECR Storage | ~$0.10 |
| **Total** | ~$15.15 |

ARM64 Graviton2 provides 20-30% cost savings over x86_64.

## License

Apache 2.0