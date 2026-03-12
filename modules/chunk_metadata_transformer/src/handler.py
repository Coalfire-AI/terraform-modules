"""
Chunk Metadata Transformer Lambda Handler
POST_CHUNKING transformation for Bedrock Knowledge Base ingestion.

This Lambda function performs METADATA ENRICHMENT ONLY:
- Receives pre-chunked content from Bedrock KB (either via Bedrock's chunking
  strategies or via pre-chunking in the preprocessing Lambda)
- Extracts framework references (NIST, AWS Well-Architected, etc.)
- Adds filterable metadata for S3 Vectors
- Returns enriched chunks (1:1 - no expansion)

IMPORTANT: This Lambda does NOT perform chunking. Chunking is handled by:
1. Bedrock's built-in chunking strategies (SEMANTIC, FIXED_SIZE, etc.)
2. The preprocessing Lambda (when ENABLE_CHUNKING=true with NONE strategy)

Input/Output Format (POST_CHUNKING):
- Input: { inputFiles: [{ contentBatches: [{ key: "s3-key" }] }] }
- Output: { outputFiles: [{ contentBatches: [{ key: "s3-key" }] }] }
- Chunk files in S3: { fileContents: [{ contentBody, contentType, contentMetadata }] }

Metadata Strategy (S3 Vectors 2KB limit compliant):
- Filterable (~200-400 bytes): frameworks, primary_framework, document_type,
  primary_category, reference_count, chunk_index
- Source URI for traceability
- Excludes large Bedrock internal metadata (x-amz-bedrock-kb-*)
"""

import json
import logging
import os
import uuid
from typing import Any

import boto3

# Import shared extractors (copied to Lambda package at build time)
try:
    from extractors import build_chunk_metadata, get_enabled_frameworks
except ImportError:
    # Fallback for local development/testing
    import sys
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "bedrock_knowledge_base", "s3_vectors"))
    from extractors import build_chunk_metadata, get_enabled_frameworks

# Configure logging
log_level = os.environ.get("LOG_LEVEL", "INFO")
logging.basicConfig(level=getattr(logging, log_level))
logger = logging.getLogger(__name__)

# Initialize S3 client
s3_client = boto3.client("s3")


def _build_chunk_metadata_safe(
    chunk_text_content: str,
    source_uri: str,
    existing_metadata: dict,
    chunk_index: int = 0,
    total_chunks: int = 1,
) -> dict[str, Any]:
    """
    Build S3 Vectors compliant metadata for a chunk.

    IMPORTANT: Bedrock adds its own internal metadata AFTER the Lambda runs.
    To stay under S3 Vectors 2KB limit, we ONLY return our enriched fields
    and do NOT preserve existing metadata (Bedrock handles that separately).

    Section metadata from preprocessing Lambda is passed through for filtering.

    Args:
        chunk_text_content: The chunk text
        source_uri: Source document URI
        existing_metadata: May contain section metadata from preprocessing Lambda
        chunk_index: Index of this chunk (0-based)
        total_chunks: Total number of chunks from this document

    Returns:
        Dictionary of metadata safe for S3 Vectors (~300-500 bytes)
    """
    # Build enriched metadata using universal extractor
    enriched = build_chunk_metadata(
        chunk_text=chunk_text_content,
        source_uri=source_uri,
        existing_metadata={},  # Don't pass existing - we control all output
    )

    # Start with empty metadata - we control exactly what goes in
    # Two-tier strategy for S3 Vectors:
    # - Filterable: Small fields indexed for filtering (counts toward 2KB limit)
    # - Non-filterable: Larger fields stored but not indexed (bypasses limit)
    # Note: For OpenSearch Serverless, all fields can be indexed (no limit)
    chunk_metadata = {}

    # Add filterable metadata (indexed by S3 Vectors, preserve native types)
    for key, value in enriched["filterable"].items():
        if isinstance(value, (list, dict)):
            chunk_metadata[key] = json.dumps(value)
        elif isinstance(value, (int, float, bool)):
            chunk_metadata[key] = value  # Preserve native types for numeric filtering
        else:
            chunk_metadata[key] = str(value)

    # Add non-filterable metadata (stored but not indexed by S3 Vectors)
    # These fields are larger and would exceed the 2KB filterable limit
    # For OpenSearch Serverless, these can also be indexed
    for key, value in enriched.get("non_filterable", {}).items():
        if isinstance(value, (list, dict)):
            chunk_metadata[key] = json.dumps(value)
        elif isinstance(value, (int, float, bool)):
            chunk_metadata[key] = value
        else:
            chunk_metadata[key] = str(value)

    # Add chunk position metadata (integers for numeric filtering)
    chunk_metadata["chunk_index"] = chunk_index
    chunk_metadata["total_chunks"] = total_chunks

    # Pass through section metadata from preprocessing Lambda
    # These fields enable section-based filtering in S3 Vectors
    section_fields = [
        "section_type",
        "section_title",
        "section_order",
        "chunk_in_section",
        "section_chunk_total",
    ]
    for field in section_fields:
        if field in existing_metadata and existing_metadata[field]:
            chunk_metadata[field] = str(existing_metadata[field])

    # Add source URI for traceability
    if source_uri:
        chunk_metadata["source_uri"] = source_uri

    return chunk_metadata


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """
    Lambda handler for POST_CHUNKING metadata enrichment.

    This handler performs 1:1 transformation - each input chunk receives
    enriched metadata but is NOT split into multiple chunks.

    Args:
        event: Bedrock KB transformation event containing:
            - version: API version (e.g., "1.0")
            - knowledgeBaseId: KB identifier
            - dataSourceId: Data source identifier
            - ingestionJobId: Current ingestion job
            - bucketName: Intermediate storage bucket
            - priorTask: Previous processing step (e.g., "CHUNKING", "PARSING")
            - inputFiles: List of files with S3 contentBatches references

    Returns:
        Response with outputFiles containing S3 references to enriched chunks
    """
    prior_task = event.get("priorTask", "unknown")

    logger.info(
        "Received POST_CHUNKING transformation event",
        extra={
            "knowledge_base_id": event.get("knowledgeBaseId"),
            "data_source_id": event.get("dataSourceId"),
            "ingestion_job_id": event.get("ingestionJobId"),
            "bucket_name": event.get("bucketName"),
            "prior_task": prior_task,
            "file_count": len(event.get("inputFiles", [])),
            "enabled_frameworks": get_enabled_frameworks(),
        }
    )
    logger.debug(f"Full event: {json.dumps(event, default=str)}")

    bucket_name = event.get("bucketName")
    input_files = event.get("inputFiles", [])

    if not bucket_name:
        logger.error("No bucketName in event")
        raise ValueError("bucketName is required in the event")

    if not input_files:
        logger.warning("No input files in event")
        return {"outputFiles": []}

    output_files = []
    total_input_chunks = 0
    total_output_chunks = 0
    frameworks_found: dict[str, int] = {}

    for file_record in input_files:
        original_location = file_record.get("originalFileLocation", {})
        file_metadata = file_record.get("fileMetadata", {})
        content_batches = file_record.get("contentBatches", [])

        source_uri = original_location.get("s3_location", {}).get("uri", "unknown")
        logger.info(f"Processing file: {source_uri} with {len(content_batches)} content batches")

        output_content_batches = []

        for batch in content_batches:
            input_key = batch.get("key")
            if not input_key:
                logger.warning("Content batch missing key, skipping")
                continue

            # Download chunk file from S3
            try:
                logger.debug(f"Downloading s3://{bucket_name}/{input_key}")
                response = s3_client.get_object(Bucket=bucket_name, Key=input_key)
                chunk_file_content = response["Body"].read().decode("utf-8")
                chunk_data = json.loads(chunk_file_content)
            except Exception as e:
                logger.error(f"Failed to download/parse {input_key}: {e}")
                # Pass through original reference on error
                output_content_batches.append(batch)
                continue

            # Process each chunk - metadata enrichment only (1:1)
            file_contents = chunk_data.get("fileContents", [])
            enriched_file_contents = []

            for item in file_contents:
                total_input_chunks += 1
                content_body = item.get("contentBody", "")
                content_type = item.get("contentType", "TEXT")
                existing_metadata = item.get("contentMetadata", {})

                if not content_body:
                    logger.debug(f"Chunk {total_input_chunks} has no content body, passing through")
                    enriched_file_contents.append(item)
                    total_output_chunks += 1
                    continue

                # Build enriched metadata for this chunk
                chunk_metadata = _build_chunk_metadata_safe(
                    chunk_text_content=content_body,
                    source_uri=source_uri,
                    existing_metadata=existing_metadata,
                    chunk_index=existing_metadata.get("chunk_index", 0),
                    total_chunks=existing_metadata.get("total_chunks", 1),
                )

                enriched_file_contents.append({
                    "contentBody": content_body,
                    "contentType": content_type,
                    "contentMetadata": chunk_metadata,
                })
                total_output_chunks += 1

                # Track frameworks
                _track_frameworks(chunk_metadata, frameworks_found)

                # Log sample metadata for first chunk
                if total_output_chunks == 1:
                    logger.info(f"Sample enriched metadata: {json.dumps(chunk_metadata, indent=2)}")

            # Write enriched chunks back to S3
            # Handle both .json and .JSON extensions (Bedrock uses uppercase .JSON)
            unique_suffix = f"-enriched-{uuid.uuid4().hex[:8]}.json"
            if input_key.lower().endswith(".json"):
                output_key = input_key[:-5] + unique_suffix  # Remove last 5 chars (.json or .JSON)
            else:
                output_key = input_key + unique_suffix
            enriched_chunk_data = {"fileContents": enriched_file_contents}

            try:
                logger.debug(f"Writing {len(enriched_file_contents)} chunks to s3://{bucket_name}/{output_key}")
                s3_client.put_object(
                    Bucket=bucket_name,
                    Key=output_key,
                    Body=json.dumps(enriched_chunk_data).encode("utf-8"),
                    ContentType="application/json",
                )
                output_content_batches.append({"key": output_key})
            except Exception as e:
                logger.error(f"Failed to write enriched chunks to {output_key}: {e}")
                # Fall back to original on write failure
                output_content_batches.append(batch)

        # Build output file record
        output_files.append({
            "originalFileLocation": original_location,
            "fileMetadata": file_metadata,
            "contentBatches": output_content_batches,
        })

    logger.info(
        "Transformation complete",
        extra={
            "total_input_chunks": total_input_chunks,
            "total_output_chunks": total_output_chunks,
            "frameworks_found": frameworks_found,
            "output_files": len(output_files),
        }
    )

    return {"outputFiles": output_files}


def _track_frameworks(chunk_metadata: dict[str, Any], frameworks_found: dict[str, int]) -> None:
    """Track detected frameworks for logging."""
    detected = chunk_metadata.get("frameworks")
    if detected:
        try:
            fw_list = json.loads(detected) if isinstance(detected, str) else detected
            for fw in fw_list:
                frameworks_found[fw] = frameworks_found.get(fw, 0) + 1
        except (json.JSONDecodeError, TypeError):
            # Ignore malformed framework data - not critical for processing
            pass


# For local testing
if __name__ == "__main__":
    # Test metadata enrichment on a sample chunk
    test_chunk = """
## AC-1 Access Control Policy and Procedures

Organizations must develop, document, and disseminate an access control policy that:
- Addresses purpose, scope, roles, responsibilities
- Establishes management commitment
- Coordinates among organizational entities
- Complies with applicable laws and regulations

Related controls: AC-2, AC-3, AC-4, AC-5, AC-6

### Implementation Guidance

AWS Well-Architected SEC-01 recommends implementing identity federation with
AWS IAM Identity Center. This aligns with NIST AC-1 requirements for
centralized access control policy management.
"""

    test_event = {
        "version": "1.0",
        "knowledgeBaseId": "TEST-KB-ID",
        "dataSourceId": "TEST-DS-ID",
        "ingestionJobId": "TEST-JOB-ID",
        "bucketName": "test-intermediate-bucket",
        "priorTask": "CHUNKING",
        "inputFiles": [
            {
                "originalFileLocation": {
                    "type": "S3",
                    "s3_location": {
                        "uri": "s3://test-bucket/processed/security-policy/chunk-001.md"
                    }
                },
                "fileMetadata": {
                    "document_type": "policy"
                },
                "contentBatches": [
                    {"key": "intermediate/docs/batch-001.json"}
                ]
            }
        ]
    }

    # The content file format (pre-chunked)
    content_file = {
        "fileContents": [
            {
                "contentBody": test_chunk,
                "contentType": "TEXT",
                "contentMetadata": {
                    "chunk_index": "0",
                    "total_chunks": "5"
                }
            }
        ]
    }

    print("=" * 60)
    print("LOCAL TEST - Metadata Enrichment Only")
    print("=" * 60)
    print(f"\nEnabled frameworks: {get_enabled_frameworks()}")
    print(f"\nInput event structure:")
    print(json.dumps(test_event, indent=2))
    print(f"\nContent file (pre-chunked):")
    print(f"  - fileContents count: {len(content_file['fileContents'])}")
    print(f"  - Content length: {len(test_chunk)} chars")
    print("\nNote: Full test requires S3 mocking or actual AWS access")

    # Test metadata extraction locally
    print("\n" + "=" * 60)
    print("Testing metadata extraction locally")
    print("=" * 60)
    metadata = _build_chunk_metadata_safe(
        chunk_text_content=test_chunk,
        source_uri="s3://test-bucket/processed/security-policy/chunk-001.md",
        existing_metadata={"chunk_index": "0", "total_chunks": "5"},
        chunk_index=0,
        total_chunks=5,
    )
    print(f"\nExtracted metadata:")
    print(json.dumps(metadata, indent=2))
    print(f"\nMetadata size: {len(json.dumps(metadata).encode('utf-8'))} bytes")