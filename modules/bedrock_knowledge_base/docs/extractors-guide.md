# When to Use Framework Extractors

This guide explains when framework extractors and transformation Lambdas are required vs optional, based on your vector store choice.

## Quick Decision Matrix

| Vector Store | Extractors Required? | Transformation Lambda? | Why |
|--------------|---------------------|------------------------|-----|
| **S3 Vectors** | Yes (for filtering) | Yes | 2KB metadata limit |
| **OpenSearch Serverless** | No | No | No limits, semantic search sufficient |

## S3 Vectors: Extractors Required

### The Problem

S3 Vectors enforces a **2KB limit on filterable metadata**. When you need to:
- Filter by compliance framework (NIST, AWS WAF)
- Query by document type or category
- Support structured regulatory queries

You must carefully manage what metadata gets indexed.

### The Solution: Pre-Chunking Pipeline

```
Raw Doc → preprocessing_lambda (chunks) → S3 → Bedrock KB (NONE) → POST_CHUNKING (metadata) → S3 Vectors
```

**Required components:**
1. `preprocessing_lambda` - Pre-chunks documents with section awareness
2. `chunk_metadata_transformer` - Extracts framework references per chunk
3. `chunking_strategy = "NONE"` - Bedrock passes through pre-chunked content

**Why pre-chunking?**
- Bedrock's chunking creates 1:N chunks from each document
- POST_CHUNKING Lambda can't create new chunks (only modify)
- Without pre-chunking, metadata multiplication exceeds 2KB limit

### Configuration

```hcl
module "knowledge_base" {
  source = "github.com/Coalfire-AI/terraform-modules//modules/bedrock_knowledge_base"

  vector_store_type = "S3_VECTORS"  # Default
  chunking_strategy = "NONE"        # Required for pre-chunking

  # Enable POST_CHUNKING transformation
  enable_custom_transformation = true
  transformation_lambda_arn    = module.chunk_transformer.function_arn
  transformation_step          = "POST_CHUNKING"
}

module "preprocessing_lambda" {
  source = "github.com/Coalfire-AI/terraform-modules//modules/preprocessing_lambda"
  # ...
}

module "chunk_transformer" {
  source = "github.com/Coalfire-AI/terraform-modules//modules/chunk_metadata_transformer"
  # ...
}
```

---

## OpenSearch Serverless: Extractors Optional

### Why Extractors Aren't Needed

OpenSearch Serverless has:
- **No metadata size limits**
- **Full-text search** on all content
- **Semantic search** finds relevant content without explicit tagging

For most use cases, Bedrock's built-in chunking + semantic search handles retrieval without framework-specific metadata.

### Configuration

```hcl
module "knowledge_base" {
  source = "github.com/Coalfire-AI/terraform-modules//modules/bedrock_knowledge_base"

  vector_store_type = "OPENSEARCH_SERVERLESS"
  chunking_strategy = "SEMANTIC"  # or FIXED_SIZE, HIERARCHICAL

  # These are NOT needed:
  # enable_custom_transformation = false  (default)
  # transformation_lambda_arn = null      (default)
}

# No preprocessing_lambda needed
# No chunk_metadata_transformer needed
```

### When You MIGHT Want Extractors with OpenSearch

| Use Case | Need Extractors? | Reason |
|----------|-----------------|--------|
| General RAG chatbot | No | Semantic search sufficient |
| Compliance documentation | Maybe | Heavy filtering requirements |
| Regulatory audit responses | Maybe | Precise control citations |
| Simple policy Q&A | No | Natural language queries work |
| Multi-framework comparison | Yes | Need explicit framework tags |

If you need **precise filtering** by framework code (e.g., "show only NIST AC controls"), you may still benefit from extractors. But for most use cases, semantic search handles it.

---

## Architecture Comparison

### S3 Vectors (with extractors)

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────────────┐
│  PDF Upload │────▶│  preprocessing  │────▶│  S3 (processed/)    │
│             │     │  Lambda         │     │  (pre-chunked)      │
└─────────────┘     │  - Docling      │     └──────────┬──────────┘
                    │  - Chunking     │                │
                    │  - Section-aware│                ▼
                    └─────────────────┘     ┌─────────────────────┐
                                            │  Bedrock KB         │
                                            │  chunking = NONE    │
                                            └──────────┬──────────┘
                                                       │
                                                       ▼
                                            ┌─────────────────────┐
                                            │  POST_CHUNKING      │
                                            │  Lambda             │
                                            │  - Extract refs     │
                                            │  - Add metadata     │
                                            └──────────┬──────────┘
                                                       │
                                                       ▼
                                            ┌─────────────────────┐
                                            │  S3 Vectors         │
                                            │  (<2KB metadata)    │
                                            └─────────────────────┘
```

### OpenSearch Serverless (no extractors)

```
┌─────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│  PDF Upload │────▶│  S3 (documents/)    │────▶│  Bedrock KB         │
│             │     │                     │     │  chunking = SEMANTIC│
└─────────────┘     └─────────────────────┘     └──────────┬──────────┘
                                                           │
                                                           ▼
                                                ┌─────────────────────┐
                                                │  OpenSearch         │
                                                │  Serverless         │
                                                │  (no metadata limit)│
                                                └─────────────────────┘
```

---

## Cost Comparison

| Approach | Components | Compute Cost | Use Case |
|----------|------------|--------------|----------|
| **S3 Vectors + Extractors** | 2 Lambdas + S3 | Pay-per-query | Cost-sensitive with filtering |
| **OpenSearch (no extractors)** | OpenSearch only | Hourly OCU | High-throughput, simple setup |

---

## Migration Path

### Moving from S3 Vectors to OpenSearch

If you started with S3 Vectors + extractors and want to simplify:

1. Change `vector_store_type = "OPENSEARCH_SERVERLESS"`
2. Remove `enable_custom_transformation = true`
3. Change `chunking_strategy` from `NONE` to `SEMANTIC`
4. Re-ingest documents

The extractors and Lambda modules can remain in the codebase but won't be used.

### Moving from OpenSearch to S3 Vectors

If you need framework filtering capabilities:

1. Deploy `preprocessing_lambda` and `chunk_metadata_transformer`
2. Change `vector_store_type = "S3_VECTORS"`
3. Set `chunking_strategy = "NONE"`
4. Enable `enable_custom_transformation = true`
5. Re-ingest documents with preprocessing

---

## Summary

| Question | Answer |
|----------|--------|
| Using OpenSearch? | Skip extractors - semantic search handles it |
| Using S3 Vectors? | Need extractors if you want framework filtering |
| Need precise control citations? | Use extractors regardless of vector store |
| Just want Q&A chatbot? | OpenSearch without extractors is simplest |