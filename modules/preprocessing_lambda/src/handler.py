"""
Document Preprocessing Lambda Handler
Processes documents using Docling for multi-framework metadata extraction.

This Lambda function:
1. Receives S3 event notifications for new documents
2. Downloads the document from S3
3. Uses Docling to parse and extract content
4. Extracts framework metadata (NIST SSDF, AWS WAF, etc.)
5. Outputs Markdown with structured metadata to processed/ prefix

Supported Frameworks:
- NIST 800-218 SSDF: Secure Software Development Framework (PO, PS, PW, RV)
- AWS Well-Architected Framework: Cloud architecture best practices
- Additional frameworks configurable via ENABLED_FRAMEWORKS env var
"""

import json
import logging
import os
import tempfile
from datetime import datetime, timezone
from typing import Any
from urllib.parse import unquote_plus

import boto3
from botocore.exceptions import ClientError

# Import shared extractors (copied to Lambda package at build time)
try:
    from extractors import build_document_metadata, extract_frameworks, get_enabled_frameworks
except ImportError:
    # Fallback for local development/testing
    import sys
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "bedrock_knowledge_base", "s3_vectors"))
    from extractors import build_document_metadata, extract_frameworks, get_enabled_frameworks

# Configure logging
log_level = os.environ.get("LOG_LEVEL", "INFO")
logging.basicConfig(level=getattr(logging, log_level))
logger = logging.getLogger(__name__)

# Environment variables
OUTPUT_BUCKET = os.environ.get("OUTPUT_BUCKET")
OUTPUT_PREFIX = os.environ.get("OUTPUT_PREFIX", "processed/")
EXTRACT_METADATA = os.environ.get("EXTRACT_METADATA", "true").lower() == "true"

# Metadata output mode:
# - "full": Include all references in frontmatter (for human readability, legacy mode)
# - "summary": Only include summary counts (recommended when using POST_CHUNKING Lambda)
# - "minimal": Only source info, no framework metadata (POST_CHUNKING handles everything)
METADATA_OUTPUT_MODE = os.environ.get("METADATA_OUTPUT_MODE", "summary")

# Pre-chunking configuration
# When enabled, documents are split into token-sized chunks BEFORE saving to S3
# This allows S3 Vectors to work with POST_CHUNKING (which only enriches metadata)
ENABLE_CHUNKING = os.environ.get("ENABLE_CHUNKING", "false").lower() == "true"

# Import chunking module at module level for better cold start performance
# (avoids per-invocation import overhead)
if ENABLE_CHUNKING:
    from chunking import (
        chunk_text,
        chunk_with_sections,
        get_chunking_config,
        ENABLE_SECTION_AWARE,
    )

# S3 client
s3_client = boto3.client("s3")


def generate_markdown_output(
    content: str,
    source_key: str,
    metadata: dict[str, Any] | None = None,
) -> str:
    """
    Generate Markdown output with YAML frontmatter metadata.

    The metadata output mode controls how much framework metadata is included:
    - "full": All references (can exceed S3 Vectors 2KB limit if many refs)
    - "summary": Only counts and framework codes (recommended with POST_CHUNKING)
    - "minimal": No framework metadata (POST_CHUNKING handles all metadata)

    Args:
        content: Converted document content in Markdown format
        source_key: Original S3 object key
        metadata: Optional framework metadata dictionary

    Returns:
        Markdown string with YAML frontmatter
    """
    lines = ["---"]
    lines.append(f'source: "{source_key}"')
    lines.append(f'processed_at: "{datetime.now(timezone.utc).isoformat()}"')
    lines.append(f'enabled_frameworks: {json.dumps(get_enabled_frameworks())}')

    if metadata and METADATA_OUTPUT_MODE != "minimal":
        lines.append(f"total_references: {metadata.get('total_references', 0)}")

        frameworks = metadata.get("frameworks_detected", [])
        if frameworks:
            lines.append(f"frameworks_detected: {json.dumps(frameworks)}")

        if metadata.get("primary_framework"):
            lines.append(f'primary_framework: "{metadata["primary_framework"]}"')

        if METADATA_OUTPUT_MODE == "full":
            # Full mode: Include all references (legacy, for human readability)
            # WARNING: This can exceed S3 Vectors 2KB filterable metadata limit
            references = metadata.get("references", {})
            if references:
                lines.append("references:")
                for fw_id, refs in references.items():
                    lines.append(f"  {fw_id}:")
                    for ref in refs:
                        lines.append(f"    - {ref}")

            categories = metadata.get("categories", {})
            if categories:
                lines.append("categories:")
                for fw_id, cats in categories.items():
                    lines.append(f"  {fw_id}:")
                    for cat, count in sorted(cats.items()):
                        lines.append(f"    {cat}: {count}")

        elif METADATA_OUTPUT_MODE == "summary":
            # Summary mode: Only framework summaries (stays under 2KB limit)
            # Recommended when using POST_CHUNKING Lambda for chunk-level metadata
            framework_summary = metadata.get("framework_summary", [])
            if framework_summary:
                lines.append("framework_summary:")
                for summary in framework_summary:
                    lines.append(f'  - "{summary}"')

    # Add note about metadata mode
    if METADATA_OUTPUT_MODE in ("summary", "minimal"):
        lines.append("# Note: Full framework metadata extracted at chunk-level by POST_CHUNKING Lambda")

    lines.append("---")
    lines.append("")
    lines.append(content)

    return "\n".join(lines)


def process_document(bucket: str, key: str) -> tuple[str, dict[str, Any] | None]:
    """
    Download and process a document using Docling.

    Args:
        bucket: S3 bucket name
        key: S3 object key

    Returns:
        Tuple of (markdown_content, framework_metadata)
    """
    # Import Docling here to ensure it's loaded after cold start
    try:
        from docling.document_converter import DocumentConverter, PdfFormatOption
        from docling.datamodel.pipeline_options import PdfPipelineOptions
        from docling.datamodel.base_models import InputFormat
    except ImportError as e:
        logger.error(f"Failed to import Docling: {e}")
        raise RuntimeError("Docling library not available") from e

    # Create temp file for download
    suffix = os.path.splitext(key)[1] or ".pdf"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp_file:
        tmp_path = tmp_file.name

    try:
        # Download from S3
        logger.info(f"Downloading s3://{bucket}/{key}")
        s3_client.download_file(bucket, key, tmp_path)

        # Convert document using Docling with OCR disabled
        # Most policy/guidance PDFs are text-based, so OCR is not needed
        logger.info("Converting document with Docling (OCR disabled)")
        pipeline_options = PdfPipelineOptions(do_ocr=False)
        converter = DocumentConverter(
            format_options={
                InputFormat.PDF: PdfFormatOption(pipeline_options=pipeline_options)
            }
        )
        result = converter.convert(tmp_path)

        # Export to Markdown
        markdown_content = result.document.export_to_markdown()

        # Extract framework metadata if enabled
        framework_metadata = None
        if EXTRACT_METADATA:
            logger.info("Extracting framework metadata", extra={"frameworks": get_enabled_frameworks()})
            framework_metadata = build_document_metadata(
                content=markdown_content,
                source_key=key,
                output_mode=METADATA_OUTPUT_MODE,
            )
            logger.info(
                "Framework extraction complete",
                extra={
                    "total_references": framework_metadata.get("total_references", 0),
                    "frameworks_detected": framework_metadata.get("frameworks_detected", []),
                }
            )

        return markdown_content, framework_metadata

    finally:
        # Clean up temp file
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def save_output(
    content: str,
    source_bucket: str,
    source_key: str,
    metadata: dict[str, Any] | None,
) -> str:
    """
    Save processed output to S3.

    Args:
        content: Markdown content to save
        source_bucket: Original source bucket
        source_key: Original source key
        metadata: Framework metadata to include

    Returns:
        Output S3 key
    """
    # Generate output key
    # raw/documents/file.pdf -> processed/documents/file.md
    base_key = source_key
    if base_key.startswith("raw/"):
        base_key = base_key[4:]

    # Change extension to .md
    base_name = os.path.splitext(base_key)[0]
    output_key = f"{OUTPUT_PREFIX}{base_name}.md"

    # Generate full Markdown with frontmatter
    full_content = generate_markdown_output(content, source_key, metadata)

    # Determine output bucket
    output_bucket = OUTPUT_BUCKET or source_bucket

    # Upload to S3
    logger.info(f"Saving output to s3://{output_bucket}/{output_key}")
    s3_client.put_object(
        Bucket=output_bucket,
        Key=output_key,
        Body=full_content.encode("utf-8"),
        ContentType="text/markdown",
        Metadata={
            "source-bucket": source_bucket,
            "source-key": source_key,
            "processor": "docling-preprocessing-lambda",
            "enabled-frameworks": ",".join(get_enabled_frameworks()),
        },
    )

    return output_key


def save_chunks(
    content: str,
    source_bucket: str,
    source_key: str,
    metadata: dict[str, Any] | None,
) -> list[str]:
    """
    Chunk content and save each chunk as a separate file to S3.

    Uses the chunking module to split content into token-sized chunks
    with overlap for optimal RAG retrieval. Each chunk is saved to:
    processed/{doc-name}/chunk-001.md, chunk-002.md, etc.

    When ENABLE_SECTION_AWARE is true (default), uses section-aware chunking
    that preserves document structure (Executive Summary, Introduction, etc.)
    and adds section metadata for improved retrieval.

    Args:
        content: Markdown content to chunk and save
        source_bucket: Original source bucket
        source_key: Original source key
        metadata: Framework metadata to include in each chunk

    Returns:
        List of output S3 keys for all chunks
    """
    # Note: chunking functions imported at module level when ENABLE_CHUNKING is true

    # Generate base output path
    # raw/documents/file.pdf -> processed/documents/file/
    base_key = source_key
    if base_key.startswith("raw/"):
        base_key = base_key[4:]

    # Remove extension for directory name
    base_name = os.path.splitext(base_key)[0]
    output_dir = f"{OUTPUT_PREFIX}{base_name}/"

    # Determine output bucket
    output_bucket = OUTPUT_BUCKET or source_bucket

    # Chunk the content - use section-aware chunking if enabled
    chunking_config = get_chunking_config()
    if ENABLE_SECTION_AWARE:
        logger.info("Using section-aware chunking for document structure preservation")
        chunks = chunk_with_sections(content)
    else:
        chunks = chunk_text(content)

    total_chunks = len(chunks)

    if total_chunks == 0:
        logger.warning(f"No chunks generated for {source_key}")
        return []

    logger.info(
        f"Chunking document into {total_chunks} chunks",
        extra={
            "config": chunking_config,
            "section_aware": ENABLE_SECTION_AWARE,
        }
    )

    output_keys = []

    for chunk in chunks:
        chunk_index = chunk["index"]
        chunk_content = chunk["content"]

        # Generate chunk key with zero-padded index
        chunk_key = f"{output_dir}chunk-{chunk_index + 1:03d}.md"

        # Create chunk-specific metadata
        chunk_metadata = {
            "chunk_index": str(chunk_index),
            "total_chunks": str(total_chunks),
            "parent_document": source_key,
            "token_count": str(chunk.get("token_count", 0)),
        }

        # Add section metadata if using section-aware chunking
        section_metadata = {}
        if ENABLE_SECTION_AWARE:
            section_metadata = {
                "section_type": chunk.get("section_type", "body"),
                "section_title": chunk.get("section_title", ""),
                "section_order": chunk.get("section_order", 0),
                "chunk_index_in_section": chunk.get("chunk_index_in_section", 0),
                "total_chunks_in_section": chunk.get("total_chunks_in_section", 1),
            }
            chunk_metadata.update({k: str(v) for k, v in section_metadata.items()})

        # Merge with document-level metadata
        if metadata:
            chunk_metadata.update({
                "primary_framework": metadata.get("primary_framework", ""),
                "frameworks_detected": ",".join(metadata.get("frameworks_detected", [])),
                "total_references": str(metadata.get("total_references", 0)),
            })

        # Generate markdown with frontmatter for this chunk
        chunk_full_content = generate_chunk_markdown(
            chunk_content,
            source_key,
            chunk_index,
            total_chunks,
            metadata,
            section_metadata if ENABLE_SECTION_AWARE else None,
        )

        # Upload chunk to S3
        logger.debug(f"Saving chunk {chunk_index + 1}/{total_chunks} to s3://{output_bucket}/{chunk_key}")

        # Build S3 object metadata
        s3_metadata = {
            "source-bucket": source_bucket,
            "source-key": source_key,
            "chunk-index": str(chunk_index),
            "total-chunks": str(total_chunks),
            "processor": "docling-preprocessing-lambda",
        }
        # Add section info to S3 metadata (for debugging/traceability)
        if ENABLE_SECTION_AWARE and section_metadata.get("section_type"):
            s3_metadata["section-type"] = section_metadata["section_type"]

        s3_client.put_object(
            Bucket=output_bucket,
            Key=chunk_key,
            Body=chunk_full_content.encode("utf-8"),
            ContentType="text/markdown",
            Metadata=s3_metadata,
        )

        output_keys.append(chunk_key)

    # Log section distribution
    if ENABLE_SECTION_AWARE:
        section_counts = {}
        for chunk in chunks:
            st = chunk.get("section_type", "body")
            section_counts[st] = section_counts.get(st, 0) + 1
        logger.info(f"Section distribution: {section_counts}")

    logger.info(f"Saved {len(output_keys)} chunks to s3://{output_bucket}/{output_dir}")
    return output_keys


def generate_chunk_markdown(
    content: str,
    source_key: str,
    chunk_index: int,
    total_chunks: int,
    metadata: dict[str, Any] | None = None,
    section_metadata: dict[str, Any] | None = None,
) -> str:
    """
    Generate Markdown output for a single chunk with YAML frontmatter.

    Includes chunk-specific metadata (index, total) plus document-level
    metadata for filtering in Bedrock Knowledge Base.

    Args:
        content: Chunk text content
        source_key: Original document S3 key
        chunk_index: Zero-based chunk index
        total_chunks: Total number of chunks in document
        metadata: Optional document-level framework metadata
        section_metadata: Optional section-aware chunking metadata containing:
            - section_type: Normalized section type (executive_summary, body, etc.)
            - section_title: Original section heading text
            - section_order: Order of section in document (0-based)
            - chunk_index_in_section: Position of this chunk within section
            - total_chunks_in_section: Total chunks from this section

    Returns:
        Markdown string with YAML frontmatter
    """
    lines = ["---"]
    lines.append(f'source: "{source_key}"')
    lines.append(f"chunk_index: {chunk_index}")
    lines.append(f"total_chunks: {total_chunks}")
    lines.append(f'processed_at: "{datetime.now(timezone.utc).isoformat()}"')

    # Include section-aware metadata for structure preservation
    if section_metadata:
        section_type = section_metadata.get("section_type", "body")
        lines.append(f'section_type: "{section_type}"')
        
        section_title = section_metadata.get("section_title", "")
        if section_title:
            # Escape quotes in section title for YAML safety
            safe_title = section_title.replace('"', '\\"')
            lines.append(f'section_title: "{safe_title}"')
        
        lines.append(f"section_order: {section_metadata.get('section_order', 0)}")
        lines.append(f"chunk_in_section: {section_metadata.get('chunk_index_in_section', 0)}")
        lines.append(f"section_chunk_total: {section_metadata.get('total_chunks_in_section', 1)}")

    if metadata:
        if metadata.get("primary_framework"):
            lines.append(f'primary_framework: "{metadata["primary_framework"]}"')

        frameworks = metadata.get("frameworks_detected", [])
        if frameworks:
            lines.append(f"frameworks_detected: {json.dumps(frameworks)}")

        lines.append(f"total_references: {metadata.get('total_references', 0)}")

        # Include framework summary for filtering (stays under 2KB)
        framework_summary = metadata.get("framework_summary", [])
        if framework_summary:
            lines.append("framework_summary:")
            for summary in framework_summary[:5]:  # Limit to first 5
                lines.append(f'  - "{summary}"')

    lines.append("---")
    lines.append("")
    lines.append(content)

    return "\n".join(lines)


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """
    Lambda handler for S3 event processing.

    Args:
        event: S3 event notification
        context: Lambda context object

    Returns:
        Processing result with status and details
    """
    logger.info(f"Received event: {json.dumps(event)}")
    logger.info(f"Enabled frameworks: {get_enabled_frameworks()}")
    logger.info(f"Chunking enabled: {ENABLE_CHUNKING}")

    results = []
    errors = []

    # Process each S3 record
    records = event.get("Records", [])
    if not records:
        logger.warning("No records in event")
        return {"statusCode": 200, "body": "No records to process"}

    for record in records:
        try:
            # Extract S3 info
            s3_info = record.get("s3", {})
            bucket = s3_info.get("bucket", {}).get("name")
            key = unquote_plus(s3_info.get("object", {}).get("key", ""))

            if not bucket or not key:
                logger.error(f"Missing bucket or key in record: {record}")
                errors.append({"error": "Missing bucket or key", "record": str(record)})
                continue

            logger.info(f"Processing s3://{bucket}/{key}")

            # Process the document
            content, metadata = process_document(bucket, key)

            # Save output - use chunking if enabled
            if ENABLE_CHUNKING:
                output_keys = save_chunks(content, bucket, key, metadata)
                results.append({
                    "source": f"s3://{bucket}/{key}",
                    "output": f"s3://{OUTPUT_BUCKET or bucket}/{output_keys[0] if output_keys else 'none'}",
                    "chunks_created": len(output_keys),
                    "references_found": metadata.get("total_references", 0) if metadata else 0,
                    "frameworks_detected": metadata.get("frameworks_detected", []) if metadata else [],
                })
            else:
                output_key = save_output(content, bucket, key, metadata)
                results.append({
                    "source": f"s3://{bucket}/{key}",
                    "output": f"s3://{OUTPUT_BUCKET or bucket}/{output_key}",
                    "references_found": metadata.get("total_references", 0) if metadata else 0,
                    "frameworks_detected": metadata.get("frameworks_detected", []) if metadata else [],
                })

        except ClientError as e:
            error_msg = f"S3 error processing {key}: {e}"
            logger.error(error_msg)
            errors.append({"source": key, "error": str(e)})

        except Exception as e:
            error_msg = f"Error processing {key}: {e}"
            logger.exception(error_msg)
            errors.append({"source": key, "error": str(e)})

    # Return results
    response = {
        "statusCode": 200 if not errors else 207,  # 207 Multi-Status for partial success
        "processed": len(results),
        "errors": len(errors),
        "results": results,
    }

    if errors:
        response["error_details"] = errors

    logger.info(f"Processing complete: {len(results)} succeeded, {len(errors)} failed")
    return response


# For local testing
if __name__ == "__main__":
    # Test the metadata extraction without Docling
    test_content = """
# Secure Software Development Guide

## Prepare the Organization (SSDF PO Practice Group)

This section covers organizational preparation per NIST 800-218 SSDF PO.1 through PO.5.

### PO.1 Define Security Requirements

Organizations must:
- Define security requirements per PO.1.1 security requirements
- Implement security training per PO.2.1 training requirements
- Establish secure development per PO.3.1 development processes

### AWS Well-Architected Security Pillar

Following SEC-01 (Securely operate your workload) and SEC-02 (Manage identities)
ensures proper security controls.

Related controls:
- SEC-03: Manage permissions
- SEC-04: Detect and investigate security events

## Produce Well-Secured Software (SSDF PW Practice Group)

Per SSDF PW.1 and PW.2, implement secure coding practices.
AWS guidance in OPS-01 recommends CloudWatch and CloudTrail.
    """

    print("Testing extract_frameworks:")
    print("=" * 60)
    result = extract_frameworks(test_content)
    print(json.dumps(result, indent=2))

    print("\n\nTesting build_document_metadata (summary mode):")
    print("=" * 60)
    doc_meta = build_document_metadata(test_content, "raw/test-doc.pdf", "summary")
    print(json.dumps(doc_meta, indent=2))

    print("\n\nTesting generate_markdown_output:")
    print("=" * 60)
    output = generate_markdown_output("# Test Content", "raw/test-doc.pdf", doc_meta)
    print(output[:500] + "...")