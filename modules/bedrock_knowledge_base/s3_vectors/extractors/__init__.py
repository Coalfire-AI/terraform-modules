"""Universal Framework Extractor for Bedrock Knowledge Base.

This module provides a single extractor that detects and extracts metadata
from multiple compliance frameworks and cloud guidance documents.

Supported Frameworks (auto-loaded from frameworks/):
- NIST 800-218 SSDF: Secure Software Development Framework (PO.1, PW.3, etc.)
- AWS Well-Architected Framework: Cloud architecture best practices (SEC-01, REL-02, etc.)

Additional frameworks can be added by creating new modules in the frameworks/ directory.

Usage:
    from extractors import extract_frameworks, build_chunk_metadata

    # Extract all framework references from text
    result = extract_frameworks(text)

    # Build standardized metadata for KB ingestion
    metadata = build_chunk_metadata(text, source_uri)
"""

# Import core functions first
from .universal import (
    FRAMEWORK_REGISTRY,
    build_chunk_metadata,
    build_document_metadata,
    extract_frameworks,
    get_enabled_frameworks,
    get_registered_frameworks,
    register_framework,
)

# Import frameworks package to trigger auto-registration
from . import frameworks  # noqa: F401

__all__ = [
    "FRAMEWORK_REGISTRY",
    "register_framework",
    "get_registered_frameworks",
    "extract_frameworks",
    "build_chunk_metadata",
    "build_document_metadata",
    "get_enabled_frameworks",
]