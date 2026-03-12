# Bedrock Knowledge Base Terraform Module

This module provides a standardized way to create and manage AWS Bedrock Knowledge Bases with configurable vector store backends.

## Features

- Creates Bedrock Knowledge Base with **OpenSearch Serverless** (default) or S3 Vectors storage
- KMS encryption for all data at rest (vector bucket, data source bucket)
- Automatic IAM role creation with least-privilege permissions
- S3 data source with configurable chunking strategies (FIXED_SIZE, SEMANTIC, HIERARCHICAL, NONE)
- Support for Titan Text Embeddings V2 (default) and other embedding models
- **Preprocessing pipeline support** - Read from preprocessed documents via external Lambda
- **Custom transformation** - Bedrock-native Lambda invocation during ingestion
- **Foundation model parsing** - Use Claude or other models for complex document parsing
- **Multi-framework metadata extraction** - Universal extractor for NIST 800-218 SSDF, AWS Well-Architected, and more
- Flexible configuration with sensible defaults

## Framework Support

The module includes a universal framework extractor that automatically detects and extracts metadata from multiple compliance frameworks and cloud guidance documents.

### Vector Store Requirements

| Vector Store | Extractors Required? | Notes |
|--------------|---------------------|-------|
| **S3 Vectors** | **Yes** (for framework filtering) | 2KB metadata limit requires pre-chunking pipeline |
| **OpenSearch Serverless** | No (optional) | Semantic search sufficient for most use cases |

> **Important**: If using S3 Vectors and you need framework filtering capabilities, you MUST use the pre-chunking pipeline with `chunking_strategy = "NONE"`. See [docs/extractors-guide.md](docs/extractors-guide.md) for detailed guidance.

### Supported Frameworks

| Framework | Pattern Examples | Categories |
|-----------|-----------------|------------|
| **NIST 800-218 SSDF** | PO.1, PS.2, PW.3.1, RV.1 | 4 practice groups (PO, PS, PW, RV) |
| **AWS Well-Architected** | SEC-01, REL-02, PERF-03 | 6 pillars (Security, Reliability, etc.) |

### How It Works

The universal extractor runs all enabled framework patterns against document chunks:

1. **Document Upload** → S3 triggers preprocessing Lambda
2. **Preprocessing** → Docling converts PDF to Markdown with document-level metadata
3. **Ingestion** → Bedrock KB chunks the document
4. **POST_CHUNKING** → Transformer Lambda extracts per-chunk framework references
5. **Vectorization** → Chunks stored in S3 Vectors with filterable metadata

### Metadata Schema (S3 Vectors Compliant)

Standardized fields work across all frameworks:

**Filterable** (indexed, <2KB):
- `frameworks` - JSON array of detected frameworks
- `primary_framework` - Framework with most references
- `primary_category` - Most referenced category code (AC, SEC, etc.)
- `document_type` - policy, standard, guideline, etc.
- `reference_count` - Total references in chunk

**Non-filterable** (stored, max 10 keys):
- `x_references` - All control/pillar IDs in chunk
- `x_categories` - Category distribution per framework
- `x_source_section` - Section header from document
- `x_framework_details` - Framework-specific metadata

### Query Examples

```python
# Get NIST Access Control guidance
filter = {"equals": {"key": "primary_category", "value": "AC"}}

# Get AWS Security pillar content
filter = {"equals": {"key": "primary_framework", "value": "AWS-WAF"}}

# Find cross-framework documents
filter = {"stringContains": {"key": "frameworks", "value": "NIST-800-218-SSDF"}}
```

## Architecture

### Basic Architecture (OpenSearch Serverless - Default)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Bedrock Knowledge Base                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │  S3 Data Source │───▶│ Titan Embed V2  │                    │
│  │    (Documents)  │    │ (Embedding Model)│                    │
│  └─────────────────┘    └────────┬────────┘                    │
│          │                       │                              │
│          │                       ▼                              │
│          │              ┌─────────────────┐                    │
│          │              │   OpenSearch    │                    │
│          │              │   Serverless    │                    │
│          │              │  (Vector Store) │                    │
│          │              └─────────────────┘                    │
│          │                       │                              │
│          └───────────────────────┘                              │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │    KMS Key      │    │    IAM Role     │                    │
│  │  (Encryption)   │    │  (Permissions)  │                    │
│  └─────────────────┘    └─────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

### With Preprocessing Pipeline

```
┌─────────────┐     ┌───────────────┐     ┌──────────────────┐     ┌─────────────┐
│  PDF Upload │────▶│  S3 (raw/)    │────▶│  Lambda          │────▶│ S3          │
│             │     │               │     │  (Docling/etc)   │     │ (processed/)│
└─────────────┘     └───────────────┘     └──────────────────┘     └──────┬──────┘
                                                                          │
                    ┌─────────────────────────────────────────────────────┘
                    ▼
            ┌─────────────────┐     ┌─────────────────┐
            │  Bedrock KB     │────▶│   OpenSearch    │
            │  (SEMANTIC)     │     │   Serverless    │
            └─────────────────┘     └─────────────────┘
```

## Usage

### Basic Usage

```hcl
module "knowledge_base" {
  source = "../../modules/bedrock_knowledge_base"

  name        = "my-knowledge-base"
  description = "Knowledge base for product documentation"
}
```

### With Custom Configuration

```hcl
module "knowledge_base" {
  source = "../../modules/bedrock_knowledge_base"

  name        = "product-docs-kb"
  description = "Knowledge base for product documentation"

  # Embedding configuration
  embedding_model_id   = "amazon.titan-embed-text-v2:0"
  embedding_dimensions = 1024

  # Chunking configuration
  chunking_strategy        = "FIXED_SIZE"
  chunk_max_tokens         = 500
  chunk_overlap_percentage = 15

  # Data source configuration
  data_source_inclusion_patterns = ["*.pdf", "*.md", "*.txt"]

  tags = {
    Environment = "production"
    Team        = "ai-platform"
  }
}
```

### With Existing IAM Role and KMS Key

```hcl
module "knowledge_base" {
  source = "../../modules/bedrock_knowledge_base"

  name = "existing-infra-kb"

  # Use existing IAM role
  create_iam_role = false
  role_arn        = aws_iam_role.existing_role.arn

  # Use existing KMS key
  create_kms_key = false
  kms_key_arn    = aws_kms_key.existing_key.arn

  # Use existing S3 bucket for documents
  create_data_source_bucket = false
  data_source_bucket_arn    = aws_s3_bucket.existing_bucket.arn
}
```

### With Semantic Chunking (Recommended for Compliance/Policy Documents)

```hcl
module "knowledge_base" {
  source = "../../modules/bedrock_knowledge_base"

  name = "compliance-guidance-kb"

  # Use semantic chunking for better context preservation
  chunking_strategy              = "SEMANTIC"
  semantic_max_tokens            = 512
  semantic_buffer_size           = 1
  semantic_breakpoint_threshold  = 95

  # Enable multi-framework extraction (NIST 800-218 SSDF + AWS Well-Architected)
  enabled_frameworks = ["NIST-800-218-SSDF", "AWS-WAF"]

  # Cohere multilingual embeddings for international content
  embedding_model_id   = "cohere.embed-multilingual-v3"
  embedding_dimensions = 1024
}
```

### Multi-Framework Configuration

```hcl
module "knowledge_base" {
  source = "../../modules/bedrock_knowledge_base"

  name = "security-guidance-kb"

  # Enable specific frameworks
  enabled_frameworks   = ["NIST-800-218-SSDF", "AWS-WAF"]
  default_document_type = "guidance"
  metadata_output_mode  = "summary"  # Recommended for POST_CHUNKING

  # Preprocessing with framework extraction
  enable_preprocessing        = true
  raw_documents_prefix       = "raw/"
  processed_documents_prefix = "processed/"

  # POST_CHUNKING transformation for per-chunk metadata
  enable_custom_transformation = true
  transformation_lambda_arn    = aws_lambda_function.chunk_transformer.arn
  transformation_step          = "POST_CHUNKING"

  # Semantic chunking for complex documents
  chunking_strategy             = "SEMANTIC"
  semantic_max_tokens           = 512
  semantic_breakpoint_threshold = 95
}
```

### With Hierarchical Chunking

```hcl
module "knowledge_base" {
  source = "../../modules/bedrock_knowledge_base"

  name = "structured-docs-kb"

  # Hierarchical chunking for parent-child relationships
  chunking_strategy             = "HIERARCHICAL"
  hierarchical_parent_max_tokens = 1500
  hierarchical_child_max_tokens  = 300
  hierarchical_overlap_tokens    = 60
}
```

### With Preprocessing Pipeline (External Lambda)

```hcl
module "knowledge_base" {
  source = "../../modules/bedrock_knowledge_base"

  name = "preprocessed-kb"

  # Enable preprocessing - reads from processed/ instead of raw/
  enable_preprocessing        = true
  raw_documents_prefix       = "raw/"
  processed_documents_prefix = "processed/"

  # Use semantic chunking for preprocessed markdown
  chunking_strategy = "SEMANTIC"
}
```

### With Custom Transformation (Bedrock-Native Lambda)

```hcl
module "knowledge_base" {
  source = "../../modules/bedrock_knowledge_base"

  name = "transformed-kb"

  # Enable Bedrock-native Lambda transformation during ingestion
  enable_custom_transformation = true
  transformation_lambda_arn    = aws_lambda_function.transformer.arn
  transformation_step          = "POST_CHUNKING"  # or "PRE_CHUNKING"

  # Optional: use separate bucket for intermediate storage
  # intermediate_storage_bucket_arn = aws_s3_bucket.intermediate.arn
  intermediate_storage_prefix = "intermediate/"
}
```

### Multi-Environment Setup (Dev/Staging/Prod)

For teams needing version-controlled documents with environment promotion:

```hcl
module "knowledge_base" {
  source = "../../modules/bedrock_knowledge_base"

  name        = "${var.project_name}-kb-${local.environment}"
  environment = local.environment  # dev, staging, or prod

  # Environment-specific configuration
  chunking_strategy      = local.env_config[local.environment].chunking_strategy
  enable_preprocessing   = local.env_config[local.environment].enable_preprocessing
  parsing_strategy       = local.env_config[local.environment].parsing_strategy
}

# Creates IAM role for GitHub Actions CI/CD
resource "aws_iam_role" "github_actions" {
  # OIDC trust for GitHub Actions
}
```

This pattern provides:
- **Git LFS** for binary document version control (PDF, DOCX)
- **Branch-based environments**: `feature/*` → dev, `staging` → staging, `main` → prod
- **GitHub Actions CI/CD** with OIDC authentication
- **Automatic ingestion** on document changes

📚 **Full guide:** [docs/kb-document-source-management.md](docs/kb-document-source-management.md)

### With Foundation Model Parsing (Recommended for Complex Documents)

Foundation Model parsing uses multimodal AI (Claude/Nova) to accurately extract text, tables, and figures from complex PDFs. This is essential for documents like AWS Well-Architected Framework, NIST compliance frameworks, or technical specifications with diagrams.

**Cost:** ~$0.003/page | **Accuracy:** 95%+ for tables vs 60% with DEFAULT

```hcl
module "knowledge_base" {
  source = "../../modules/bedrock_knowledge_base"

  name = "complex-docs-kb"

  # Use Claude for parsing complex documents (tables, images, etc.)
  # ARN is auto-constructed from model ID + deployment region
  parsing_strategy = "BEDROCK_FOUNDATION_MODEL"
  parsing_model_id = "anthropic.claude-3-sonnet-20240229-v1:0"  # Recommended for accuracy

  # Alternative cost-effective options:
  # parsing_model_id = "anthropic.claude-3-haiku-20240307-v1:0"  # Faster, cheaper
  # parsing_model_id = "amazon.nova-pro-v1:0"                    # AWS native option
  # parsing_model_id = "amazon.nova-lite-v1:0"                   # Most cost-effective

  # Optional: custom parsing prompt for specific document types
  parsing_prompt_override = "Extract all text from this document. Preserve table structure as markdown tables. For diagrams, describe the content and relationships shown."
}
```

**Supported Parsing Models:**

| Model ID | Cost | Best For |
|----------|------|----------|
| `anthropic.claude-3-sonnet-20240229-v1:0` | ~$0.003/page | Complex documents, highest accuracy |
| `anthropic.claude-3-5-sonnet-20241022-v2:0` | ~$0.003/page | Latest Claude, best reasoning |
| `anthropic.claude-3-haiku-20240307-v1:0` | ~$0.001/page | Fast processing, good accuracy |
| `amazon.nova-pro-v1:0` | ~$0.002/page | AWS native, good balance |
| `amazon.nova-lite-v1:0` | ~$0.0008/page | Most cost-effective |

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.24.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.24.0 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.9 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [aws_bedrockagent_data_source.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagent_data_source) | resource |
| [aws_bedrockagent_knowledge_base.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagent_knowledge_base) | resource |
| [aws_cloudwatch_log_delivery.knowledge_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery_destination.knowledge_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_destination) | resource |
| [aws_cloudwatch_log_delivery_source.knowledge_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_source) | resource |
| [aws_cloudwatch_log_group.knowledge_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.knowledge_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.bedrock_model_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.intermediate_storage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.kms_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.lambda_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.opensearch_serverless_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.parsing_model_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.s3_data_source_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.s3_vectors_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.knowledge_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.knowledge_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_opensearchserverless_access_policy.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_access_policy) | resource |
| [aws_opensearchserverless_collection.knowledge_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_collection) | resource |
| [aws_opensearchserverless_security_policy.encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_security_policy) | resource |
| [aws_opensearchserverless_security_policy.network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_security_policy) | resource |
| [aws_s3_bucket.data_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.data_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.data_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.data_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.data_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3vectors_index.knowledge_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3vectors_index) | resource |
| [aws_s3vectors_vector_bucket.knowledge_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3vectors_vector_bucket) | resource |
| [time_sleep.wait_for_collection](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Name for the knowledge base (used as prefix for all resources) | `string` | n/a | yes |
| <a name="input_chunk_max_tokens"></a> [chunk\_max\_tokens](#input\_chunk\_max\_tokens) | Maximum number of tokens per chunk (for FIXED\_SIZE strategy) | `number` | `300` | no |
| <a name="input_chunk_overlap_percentage"></a> [chunk\_overlap\_percentage](#input\_chunk\_overlap\_percentage) | Percentage of overlap between chunks (for FIXED\_SIZE strategy) | `number` | `10` | no |
| <a name="input_chunking_strategy"></a> [chunking\_strategy](#input\_chunking\_strategy) | Strategy for chunking documents | `string` | `"FIXED_SIZE"` | no |
| <a name="input_create_data_source_bucket"></a> [create\_data\_source\_bucket](#input\_create\_data\_source\_bucket) | Whether to create an S3 bucket for source documents | `bool` | `true` | no |
| <a name="input_create_iam_role"></a> [create\_iam\_role](#input\_create\_iam\_role) | Whether to create an IAM role for the knowledge base | `bool` | `true` | no |
| <a name="input_create_kms_key"></a> [create\_kms\_key](#input\_create\_kms\_key) | Whether to create a KMS key for encryption | `bool` | `true` | no |
| <a name="input_create_knowledge_base"></a> [create\_knowledge\_base](#input\_create\_knowledge\_base) | Whether to create the Bedrock Knowledge Base resource.<br/>Set to false during initial deployment when using OPENSEARCH\_SERVERLESS to allow<br/>the vector index to be created externally before the Knowledge Base.<br/><br/>Two-apply pattern for OpenSearch Serverless:<br/>1. First apply: Set create\_knowledge\_base = false to create the collection<br/>2. Create the vector index using opensearch provider (see opensearch\_index\_config output)<br/>3. Second apply: Set create\_knowledge\_base = true to create the Knowledge Base | `bool` | `true` | no |
| <a name="input_data_deletion_policy"></a> [data\_deletion\_policy](#input\_data\_deletion\_policy) | Policy for vector deletion when data source is destroyed.<br/>- RETAIN: Keep ingested vectors when data source is deleted (safer default)<br/>- DELETE: Remove all ingested vectors when data source is deleted | `string` | `"RETAIN"` | no |
| <a name="input_data_source_bucket_arn"></a> [data\_source\_bucket\_arn](#input\_data\_source\_bucket\_arn) | ARN of existing S3 bucket for source documents (required if create\_data\_source\_bucket is false) | `string` | `null` | no |
| <a name="input_data_source_bucket_name"></a> [data\_source\_bucket\_name](#input\_data\_source\_bucket\_name) | Name for the data source S3 bucket (defaults to {name}-documents) | `string` | `null` | no |
| <a name="input_data_source_inclusion_prefixes"></a> [data\_source\_inclusion\_prefixes](#input\_data\_source\_inclusion\_prefixes) | List of S3 key prefixes to include in the data source | `list(string)` | `[]` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the knowledge base | `string` | `null` | no |
| <a name="input_embedding_data_type"></a> [embedding\_data\_type](#input\_embedding\_data\_type) | Data type for embedding vectors | `string` | `"FLOAT32"` | no |
| <a name="input_embedding_dimensions"></a> [embedding\_dimensions](#input\_embedding\_dimensions) | Dimensions for the embedding vectors (must match model capability) | `number` | `1024` | no |
| <a name="input_embedding_model_id"></a> [embedding\_model\_id](#input\_embedding\_model\_id) | Bedrock embedding model ID | `string` | `"amazon.titan-embed-text-v2:0"` | no |
| <a name="input_enable_custom_transformation"></a> [enable\_custom\_transformation](#input\_enable\_custom\_transformation) | Whether to enable custom Lambda transformation during Bedrock ingestion. This is different from preprocessing - it runs as part of Bedrock's ingestion pipeline. | `bool` | `false` | no |
| <a name="input_enable_logging"></a> [enable\_logging](#input\_enable\_logging) | Enable CloudWatch logging for knowledge base data ingestion jobs | `bool` | `true` | no |
| <a name="input_enable_preprocessing"></a> [enable\_preprocessing](#input\_enable\_preprocessing) | Whether to read from preprocessed documents (vs raw uploads). When true, data source reads from processed\_documents\_prefix instead of raw\_documents\_prefix. | `bool` | `false` | no |
| <a name="input_hierarchical_child_max_tokens"></a> [hierarchical\_child\_max\_tokens](#input\_hierarchical\_child\_max\_tokens) | Maximum tokens for child chunks. Must be less than parent. Only used when chunking\_strategy = HIERARCHICAL. | `number` | `300` | no |
| <a name="input_hierarchical_overlap_tokens"></a> [hierarchical\_overlap\_tokens](#input\_hierarchical\_overlap\_tokens) | Number of overlap tokens between hierarchical chunks. Only used when chunking\_strategy = HIERARCHICAL. | `number` | `60` | no |
| <a name="input_hierarchical_parent_max_tokens"></a> [hierarchical\_parent\_max\_tokens](#input\_hierarchical\_parent\_max\_tokens) | Maximum tokens for parent chunks. Only used when chunking\_strategy = HIERARCHICAL. | `number` | `1500` | no |
| <a name="input_intermediate_storage_bucket_arn"></a> [intermediate\_storage\_bucket\_arn](#input\_intermediate\_storage\_bucket\_arn) | ARN of S3 bucket for intermediate transformation storage. If not provided, uses the data source bucket. | `string` | `null` | no |
| <a name="input_intermediate_storage_prefix"></a> [intermediate\_storage\_prefix](#input\_intermediate\_storage\_prefix) | S3 prefix for intermediate transformation storage | `string` | `"intermediate/"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of existing KMS key (used if create\_kms\_key is false) | `string` | `null` | no |
| <a name="input_kms_key_deletion_window_days"></a> [kms\_key\_deletion\_window\_days](#input\_kms\_key\_deletion\_window\_days) | Duration in days after which the KMS key is deleted after destruction | `number` | `30` | no |
| <a name="input_kms_key_enable_rotation"></a> [kms\_key\_enable\_rotation](#input\_kms\_key\_enable\_rotation) | Whether to enable automatic KMS key rotation | `bool` | `true` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain CloudWatch logs | `number` | `30` | no |
| <a name="input_opensearch_additional_data_access_principals"></a> [opensearch\_additional\_data\_access\_principals](#input\_opensearch\_additional\_data\_access\_principals) | Additional IAM principal ARNs to grant data access to the OpenSearch collection.<br/>Use this to grant access to Terraform deployment roles or other external services<br/>that need to create indexes or access data in the collection.<br/><br/>IMPORTANT: Use IAM role ARNs (arn:aws:iam::...:role/...), not STS assumed-role<br/>session ARNs (arn:aws:sts::...:assumed-role/...), as OpenSearch Serverless<br/>validates the underlying IAM principal.<br/><br/>Example: ["arn:aws:iam::123456789012:role/terraform-deployment-role"] | `list(string)` | `[]` | no |
| <a name="input_opensearch_allow_public_access"></a> [opensearch\_allow\_public\_access](#input\_opensearch\_allow\_public\_access) | Whether to allow public network access to the OpenSearch collection.<br/>When false, AWS service private access is enabled for Bedrock (bedrock.amazonaws.com),<br/>allowing the Knowledge Base to access the private collection securely.<br/>See: https://repost.aws/knowledge-center/bedrock-knowledge-base-private-network-policy | `bool` | `false` | no |
| <a name="input_opensearch_collection_name"></a> [opensearch\_collection\_name](#input\_opensearch\_collection\_name) | Name for the OpenSearch Serverless collection (defaults to {name}-collection) | `string` | `null` | no |
| <a name="input_opensearch_collection_wait_duration"></a> [opensearch\_collection\_wait\_duration](#input\_opensearch\_collection\_wait\_duration) | Duration to wait for OpenSearch collection to become active (e.g., '3m' for 3 minutes) | `string` | `"3m"` | no |
| <a name="input_opensearch_index_name"></a> [opensearch\_index\_name](#input\_opensearch\_index\_name) | Name for the vector index in OpenSearch (defaults to bedrock-knowledge-base-default-index) | `string` | `"bedrock-knowledge-base-default-index"` | no |
| <a name="input_opensearch_metadata_field_name"></a> [opensearch\_metadata\_field\_name](#input\_opensearch\_metadata\_field\_name) | Name of the metadata field in OpenSearch index | `string` | `"AMAZON_BEDROCK_METADATA"` | no |
| <a name="input_opensearch_standby_replicas"></a> [opensearch\_standby\_replicas](#input\_opensearch\_standby\_replicas) | Whether to use standby replicas for the collection (ENABLED or DISABLED). ENABLED provides higher availability but increases cost. | `string` | `"ENABLED"` | no |
| <a name="input_opensearch_text_field_name"></a> [opensearch\_text\_field\_name](#input\_opensearch\_text\_field\_name) | Name of the text field in OpenSearch index (stores chunked text) | `string` | `"AMAZON_BEDROCK_TEXT_CHUNK"` | no |
| <a name="input_opensearch_use_aws_owned_key"></a> [opensearch\_use\_aws\_owned\_key](#input\_opensearch\_use\_aws\_owned\_key) | Whether to use AWS owned KMS key for encryption. Set to false to use customer managed KMS key. | `bool` | `true` | no |
| <a name="input_opensearch_vector_field_name"></a> [opensearch\_vector\_field\_name](#input\_opensearch\_vector\_field\_name) | Name of the vector field in OpenSearch index | `string` | `"bedrock-knowledge-base-default-vector"` | no |
| <a name="input_parsing_model_arn"></a> [parsing\_model\_arn](#input\_parsing\_model\_arn) | Full ARN of foundation model for parsing. If provided, overrides parsing\_model\_id. Use for cross-region models or custom deployments. Example: arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0 | `string` | `null` | no |
| <a name="input_parsing_model_id"></a> [parsing\_model\_id](#input\_parsing\_model\_id) | Bedrock model ID for document parsing (used when parsing\_strategy is BEDROCK\_FOUNDATION\_MODEL).<br/>ARN is auto-constructed for the deployment region.<br/><br/>IMPORTANT: Parsing requires models with DIRECT regional availability (not cross-region inference).<br/>Claude 4/4.5 models currently only support cross-region inference and may not work for parsing.<br/><br/>Recommended models with wide regional availability:<br/>- anthropic.claude-3-5-sonnet-20241022-v2:0 (recommended)<br/>- anthropic.claude-3-haiku-20240307-v1:0 (faster, lower cost)<br/>- amazon.nova-pro-v1:0, amazon.nova-lite-v1:0 (cost-effective)<br/><br/>See: https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base-supported.html | `string` | `"anthropic.claude-3-5-sonnet-20241022-v2:0"` | no |
| <a name="input_parsing_prompt_override"></a> [parsing\_prompt\_override](#input\_parsing\_prompt\_override) | Custom prompt for foundation model parsing. Use to tailor extraction for specific document types (e.g., compliance frameworks, technical specs). Leave null for default behavior. | `string` | `null` | no |
| <a name="input_parsing_strategy"></a> [parsing\_strategy](#input\_parsing\_strategy) | Document parsing strategy: DEFAULT (free, basic text extraction) or BEDROCK\_FOUNDATION\_MODEL (~$0.003/page, multimodal parsing for complex docs with tables/figures) | `string` | `"DEFAULT"` | no |
| <a name="input_processed_documents_prefix"></a> [processed\_documents\_prefix](#input\_processed\_documents\_prefix) | S3 prefix for preprocessed documents (output from preprocessing Lambda) | `string` | `"processed/"` | no |
| <a name="input_raw_documents_prefix"></a> [raw\_documents\_prefix](#input\_raw\_documents\_prefix) | S3 prefix for raw document uploads (source PDFs, etc.) | `string` | `"raw/"` | no |
| <a name="input_role_arn"></a> [role\_arn](#input\_role\_arn) | ARN of existing IAM role (required if create\_iam\_role is false) | `string` | `null` | no |
| <a name="input_s3_vectors_metadata_fields"></a> [s3\_vectors\_metadata\_fields](#input\_s3\_vectors\_metadata\_fields) | Metadata field definitions for S3 Vectors index. Fields can be filterable (indexed, queryable)<br/>or non-filterable (stored but not indexed). Non-filterable fields MUST be defined at index<br/>creation time and cannot be added later.<br/><br/>Standardized metadata fields (framework-agnostic):<br/>- Filterable: frameworks, primary\_framework, document\_type, primary\_category,<br/>  primary\_category\_name, reference\_count<br/>- Non-filterable: x\_references, x\_categories, x\_source\_section, x\_framework\_details,<br/>  x\_source\_uri, x\_enhancements<br/><br/>Note: Non-filterable fields are prefixed with 'x\_' by the chunk\_metadata\_transformer. | <pre>object({<br/>    filterable_fields = optional(list(object({<br/>      name = string<br/>      type = string # STRING, NUMBER, BOOLEAN<br/>    })), [])<br/>    non_filterable_fields = optional(list(object({<br/>      name = string<br/>      type = string # STRING, NUMBER, BOOLEAN, STRING_LIST<br/>    })), [])<br/>  })</pre> | <pre>{<br/>  "filterable_fields": [<br/>    {<br/>      "name": "frameworks",<br/>      "type": "STRING"<br/>    },<br/>    {<br/>      "name": "primary_framework",<br/>      "type": "STRING"<br/>    },<br/>    {<br/>      "name": "document_type",<br/>      "type": "STRING"<br/>    },<br/>    {<br/>      "name": "primary_category",<br/>      "type": "STRING"<br/>    },<br/>    {<br/>      "name": "primary_category_name",<br/>      "type": "STRING"<br/>    },<br/>    {<br/>      "name": "reference_count",<br/>      "type": "NUMBER"<br/>    }<br/>  ],<br/>  "non_filterable_fields": [<br/>    {<br/>      "name": "x_references",<br/>      "type": "STRING"<br/>    },<br/>    {<br/>      "name": "x_categories",<br/>      "type": "STRING"<br/>    },<br/>    {<br/>      "name": "x_source_section",<br/>      "type": "STRING"<br/>    },<br/>    {<br/>      "name": "x_framework_details",<br/>      "type": "STRING"<br/>    },<br/>    {<br/>      "name": "x_source_uri",<br/>      "type": "STRING"<br/>    },<br/>    {<br/>      "name": "x_enhancements",<br/>      "type": "STRING"<br/>    }<br/>  ]<br/>}</pre> | no |
| <a name="input_semantic_breakpoint_threshold"></a> [semantic\_breakpoint\_threshold](#input\_semantic\_breakpoint\_threshold) | Percentile threshold (50-99) for semantic breakpoints. Higher = fewer, larger chunks. Values below 50 create overly granular chunks. Only used when chunking\_strategy = SEMANTIC. | `number` | `95` | no |
| <a name="input_semantic_buffer_size"></a> [semantic\_buffer\_size](#input\_semantic\_buffer\_size) | Number of sentences to buffer for context (0-1). Higher values provide better semantic boundary detection. Only used when chunking\_strategy = SEMANTIC. | `number` | `1` | no |
| <a name="input_semantic_max_tokens"></a> [semantic\_max\_tokens](#input\_semantic\_max\_tokens) | Maximum tokens per chunk for semantic chunking. Only used when chunking\_strategy = SEMANTIC. | `number` | `512` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_transformation_lambda_arn"></a> [transformation\_lambda\_arn](#input\_transformation\_lambda\_arn) | ARN of Lambda function for custom transformation (required if enable\_custom\_transformation is true) | `string` | `null` | no |
| <a name="input_transformation_step"></a> [transformation\_step](#input\_transformation\_step) | When to apply transformation: POST\_CHUNKING (after chunking) or PRE\_CHUNKING (before chunking) | `string` | `"POST_CHUNKING"` | no |
| <a name="input_vector_bucket_name"></a> [vector\_bucket\_name](#input\_vector\_bucket\_name) | Name for the S3 vector bucket (defaults to {name}-vectors) | `string` | `null` | no |
| <a name="input_vector_distance_metric"></a> [vector\_distance\_metric](#input\_vector\_distance\_metric) | Distance metric for vector similarity search | `string` | `"cosine"` | no |
| <a name="input_vector_index_name"></a> [vector\_index\_name](#input\_vector\_index\_name) | Name for the vector index (defaults to {name}-index) | `string` | `null` | no |
| <a name="input_vector_store_type"></a> [vector\_store\_type](#input\_vector\_store\_type) | Type of vector store to use for the knowledge base:<br/>- OPENSEARCH\_SERVERLESS: Amazon OpenSearch Serverless (default) - Full-featured, no metadata limits, production-ready<br/>- S3\_VECTORS: Amazon S3 Vectors - Pay-per-query, 2KB filterable metadata limit, cost-optimized<br/><br/>Use OPENSEARCH\_SERVERLESS for:<br/>- Production RAG applications requiring reliability and low latency<br/>- Complex metadata filtering without size limits<br/>- When using POST\_CHUNKING Lambda that returns multiple chunks per input<br/>- Standard knowledge base deployments<br/><br/>Use S3\_VECTORS for:<br/>- Cost-sensitive deployments with low query volumes<br/>- Simple RAG applications with minimal metadata filtering<br/>- When metadata filtering needs are within 2KB limit<br/>- NOTE: Requires special extractors architecture for framework filtering | `string` | `"OPENSEARCH_SERVERLESS"` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_chunking_strategy"></a> [chunking\_strategy](#output\_chunking\_strategy) | The chunking strategy used for document processing |
| <a name="output_custom_transformation_enabled"></a> [custom\_transformation\_enabled](#output\_custom\_transformation\_enabled) | Whether Bedrock-native custom Lambda transformation is enabled |
| <a name="output_data_source_bucket_arn"></a> [data\_source\_bucket\_arn](#output\_data\_source\_bucket\_arn) | The ARN of the S3 bucket used as data source |
| <a name="output_data_source_bucket_name"></a> [data\_source\_bucket\_name](#output\_data\_source\_bucket\_name) | The name of the S3 bucket used as data source |
| <a name="output_data_source_id"></a> [data\_source\_id](#output\_data\_source\_id) | The unique identifier of the data source (null if create\_knowledge\_base = false) |
| <a name="output_effective_inclusion_prefixes"></a> [effective\_inclusion\_prefixes](#output\_effective\_inclusion\_prefixes) | The S3 prefixes that the data source is configured to read from |
| <a name="output_embedding_dimensions"></a> [embedding\_dimensions](#output\_embedding\_dimensions) | The number of dimensions in the embedding vectors |
| <a name="output_embedding_model_arn"></a> [embedding\_model\_arn](#output\_embedding\_model\_arn) | The ARN of the embedding model used |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | The ARN of the IAM role used by the knowledge base |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | The name of the IAM role used by the knowledge base |
| <a name="output_intermediate_storage_uri"></a> [intermediate\_storage\_uri](#output\_intermediate\_storage\_uri) | S3 URI for intermediate transformation storage (when custom transformation is enabled) |
| <a name="output_kms_key_alias"></a> [kms\_key\_alias](#output\_kms\_key\_alias) | The alias of the KMS key |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | The ARN of the KMS key used for encryption |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | The ID of the KMS key used for encryption |
| <a name="output_knowledge_base_arn"></a> [knowledge\_base\_arn](#output\_knowledge\_base\_arn) | The ARN of the knowledge base (null if create\_knowledge\_base = false) |
| <a name="output_knowledge_base_created"></a> [knowledge\_base\_created](#output\_knowledge\_base\_created) | Whether the knowledge base was created (use for conditional logic in calling modules) |
| <a name="output_knowledge_base_id"></a> [knowledge\_base\_id](#output\_knowledge\_base\_id) | The unique identifier of the knowledge base (null if create\_knowledge\_base = false) |
| <a name="output_knowledge_base_name"></a> [knowledge\_base\_name](#output\_knowledge\_base\_name) | The name of the knowledge base |
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | ARN of the CloudWatch Log Group for knowledge base logs |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Name of the CloudWatch Log Group for knowledge base logs |
| <a name="output_logging_enabled"></a> [logging\_enabled](#output\_logging\_enabled) | Whether CloudWatch logging is enabled for the knowledge base |
| <a name="output_opensearch_collection_arn"></a> [opensearch\_collection\_arn](#output\_opensearch\_collection\_arn) | The ARN of the OpenSearch Serverless collection (null if using S3 Vectors) |
| <a name="output_opensearch_collection_endpoint"></a> [opensearch\_collection\_endpoint](#output\_opensearch\_collection\_endpoint) | The endpoint URL of the OpenSearch Serverless collection (null if using S3 Vectors) |
| <a name="output_opensearch_collection_id"></a> [opensearch\_collection\_id](#output\_opensearch\_collection\_id) | The ID of the OpenSearch Serverless collection (null if using S3 Vectors) |
| <a name="output_opensearch_collection_name"></a> [opensearch\_collection\_name](#output\_opensearch\_collection\_name) | The name of the OpenSearch Serverless collection (null if using S3 Vectors) |
| <a name="output_opensearch_dashboard_endpoint"></a> [opensearch\_dashboard\_endpoint](#output\_opensearch\_dashboard\_endpoint) | The dashboard endpoint URL of the OpenSearch Serverless collection (null if using S3 Vectors) |
| <a name="output_opensearch_index_config"></a> [opensearch\_index\_config](#output\_opensearch\_index\_config) | Complete configuration for creating the OpenSearch vector index. Includes endpoint, index name, role ARN, and field names. (null if using S3 Vectors) |
| <a name="output_opensearch_index_mapping"></a> [opensearch\_index\_mapping](#output\_opensearch\_index\_mapping) | The JSON mapping configuration for creating the OpenSearch vector index. Use with opensearch provider or OpenSearch Dashboards. (null if using S3 Vectors) |
| <a name="output_opensearch_index_name"></a> [opensearch\_index\_name](#output\_opensearch\_index\_name) | The name of the OpenSearch vector index (null if using S3 Vectors) |
| <a name="output_parsing_model_arn"></a> [parsing\_model\_arn](#output\_parsing\_model\_arn) | The ARN of the foundation model used for document parsing (null if using DEFAULT strategy) |
| <a name="output_parsing_model_id"></a> [parsing\_model\_id](#output\_parsing\_model\_id) | The model ID used for document parsing |
| <a name="output_parsing_strategy"></a> [parsing\_strategy](#output\_parsing\_strategy) | The parsing strategy used for document processing (DEFAULT or BEDROCK\_FOUNDATION\_MODEL) |
| <a name="output_preprocessing_enabled"></a> [preprocessing\_enabled](#output\_preprocessing\_enabled) | Whether preprocessing pipeline is enabled (reads from processed/ prefix) |
| <a name="output_processed_documents_s3_uri"></a> [processed\_documents\_s3\_uri](#output\_processed\_documents\_s3\_uri) | S3 URI for preprocessed documents (output from preprocessing Lambda) |
| <a name="output_raw_documents_s3_uri"></a> [raw\_documents\_s3\_uri](#output\_raw\_documents\_s3\_uri) | S3 URI for raw document uploads |
| <a name="output_vector_bucket_arn"></a> [vector\_bucket\_arn](#output\_vector\_bucket\_arn) | The ARN of the S3 vector bucket (null if using OpenSearch Serverless) |
| <a name="output_vector_bucket_name"></a> [vector\_bucket\_name](#output\_vector\_bucket\_name) | The name of the S3 vector bucket (null if using OpenSearch Serverless) |
| <a name="output_vector_index_arn"></a> [vector\_index\_arn](#output\_vector\_index\_arn) | The ARN of the S3 vector index (null if using OpenSearch Serverless) |
| <a name="output_vector_index_name"></a> [vector\_index\_name](#output\_vector\_index\_name) | The name of the vector index (applies to both S3 Vectors and OpenSearch) |
| <a name="output_vector_store_type"></a> [vector\_store\_type](#output\_vector\_store\_type) | The type of vector store being used (S3\_VECTORS or OPENSEARCH\_SERVERLESS) |
<!-- END_TF_DOCS -->

## Embedding Models

| Model ID | Dimensions | Description |
|----------|------------|-------------|
| `amazon.titan-embed-text-v2:0` | 256, 512, 1024 | Latest AWS model (default) |
| `amazon.titan-embed-text-v1` | 1536 | Original Titan embeddings |
| `amazon.titan-embed-image-v1` | 1024, 384, 256 | Multimodal (text + images) |
| `cohere.embed-english-v3` | 1024 | English-optimized |
| `cohere.embed-multilingual-v3` | 1024 | 100+ languages |

## Chunking Strategies

| Strategy | Description | Use Case |
|----------|-------------|----------|
| `FIXED_SIZE` | Fixed token count with overlap | General purpose (default) |
| `SEMANTIC` | AI-based semantic boundaries | Complex documents |
| `HIERARCHICAL` | Parent-child chunk relationships | Structured content |
| `NONE` | No chunking | Pre-chunked data |

## Syncing Data

After creating the knowledge base, upload documents to the data source S3 bucket and trigger a sync:

```bash
# Upload documents
aws s3 cp ./documents/ s3://<data-source-bucket-name>/ --recursive

# Start ingestion job
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id <knowledge-base-id> \
  --data-source-id <data-source-id>
```

## Regional Availability

### OpenSearch Serverless (Default)

OpenSearch Serverless is available in all AWS regions that support Amazon Bedrock. See the [AWS Regional Services List](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/) for current availability.

### S3 Vectors (Alternative)

S3 Vectors has limited regional availability. If using `vector_store_type = "S3_VECTORS"`, ensure your region is supported:

| Region Code | Region Name |
|-------------|-------------|
| us-east-1 | US East (N. Virginia) |
| us-east-2 | US East (Ohio) |
| us-west-2 | US West (Oregon) |
| eu-central-1 | Europe (Frankfurt) |
| eu-west-1 | Europe (Ireland) |
| eu-west-2 | Europe (London) |
| eu-west-3 | Europe (Paris) |
| eu-north-1 | Europe (Stockholm) |
| ap-south-1 | Asia Pacific (Mumbai) |
| ap-southeast-1 | Asia Pacific (Singapore) |
| ap-southeast-2 | Asia Pacific (Sydney) |
| ap-northeast-1 | Asia Pacific (Tokyo) |
| ap-northeast-2 | Asia Pacific (Seoul) |
| ca-central-1 | Canada (Central) |

## Preprocessing vs Custom Transformation

This module supports two complementary approaches for document processing:

| Feature | Preprocessing Pipeline | Custom Transformation |
|---------|----------------------|----------------------|
| **How it works** | External Lambda processes docs before upload | Bedrock invokes Lambda during ingestion |
| **Trigger** | S3 event on raw/ prefix | Part of ingestion job |
| **Best for** | Complex preprocessing (Docling, table extraction) | Post-chunking enrichment |
| **Variables** | `enable_preprocessing`, prefix vars | `enable_custom_transformation`, Lambda ARN |

**Use preprocessing** when you need heavy document processing (e.g., Docling for PDFs with tables).
**Use custom transformation** when you need to modify chunks after Bedrock's chunking step.
**Use both** for maximum flexibility.

## Notes

- **OpenSearch Serverless is the default** vector store - full-featured, production-ready, no metadata limits
- S3 Vectors is available as a cost-optimized alternative for low-volume use cases (has 2KB metadata limit)
- The IAM role must have a trust relationship allowing `bedrock.amazonaws.com` to assume it (AWS console creates roles with `AmazonBedrockExecutionRoleForKnowledgeBase_` prefix)
- KMS key rotation is enabled by default for security best practices
- Vector bucket and data source bucket are separate for security isolation
- When using HIERARCHICAL chunking, parent max tokens must be greater than child max tokens
- When using BEDROCK_FOUNDATION_MODEL parsing, expect ~$0.003/page cost
- For NIST/policy documents, SEMANTIC chunking is recommended for better context preservation

