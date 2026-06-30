# terraform-modules

Reusable Terraform modules for deploying AWS AI agent infrastructure, including Bedrock AgentCore runtimes, Knowledge Bases, document preprocessing pipelines, and human-in-the-loop (HITL) handler platforms.

## Modules

| Module | Description |
|--------|-------------|
| [tra_infra](modules/tra_infra/) | Orchestrator: deploys agents, HITL handlers, IAM, observability, and support access |
| [bedrock_knowledge_base](modules/bedrock_knowledge_base/) | Bedrock Knowledge Base with OpenSearch Serverless or S3 Vectors |
| [preprocessing_lambda](modules/preprocessing_lambda/) | Document preprocessing pipeline (PDF/DOCX parsing with Docling) |
| [chunk_metadata_transformer](modules/chunk_metadata_transformer/) | POST_CHUNKING metadata enrichment Lambda for S3 Vectors |
| [agentcore_agent](modules/agentcore_agent/) | Bedrock AgentCore agent runtime with optional ECR repository |
| [slack_handler](modules/slack_handler/) | Slack slash command HITL handler (API Gateway + Lambda + DynamoDB) |
| [log_retention_enforcer](modules/log_retention_enforcer/) | Auto-sets retention on AgentCore CloudWatch log groups |

## Usage

Each module can be used independently. See the individual module READMEs for usage examples and configuration details.

```hcl
module "example" {
  source = "git::ssh://git@github.com/Coalfire-AI/terraform-modules.git//modules/<module_name>?ref=v1.0.0"
}
```

## Requirements

- Terraform >= 1.0
- AWS Provider >= 6.0 (for AgentCore support)

## Versioning

This repository uses semantic versioning (`vMAJOR.MINOR.PATCH`) with GitHub releases. Pin to a specific version tag for stable deployments:

```hcl
source = "git::ssh://git@github.com/Coalfire-AI/terraform-modules.git//modules/tra_infra?ref=v2.1.0"
```

See [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md) for details.

## Development Setup

### Prerequisites

Install the required tools:

```bash
brew install pre-commit terraform-docs tflint
```

If on Linux, use your package manager to install these tools.

### Pre-commit Hooks

```bash
pre-commit install
```

Hooks run automatically on `git commit` and enforce:

- **terraform_fmt** — auto-formats `.tf` files
- **terraform_validate** — runs `terraform validate` on each module
- **terraform_docs** — regenerates README input/output tables from `<!-- BEGIN_TF_DOCS -->` markers
- **terraform_tflint** — lints for deprecated syntax, missing descriptions, and naming conventions

If hooks modify files (fmt or docs), re-stage the changes and commit again:

```bash
git add -u && git commit
```
