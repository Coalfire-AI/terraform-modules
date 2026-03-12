"""Universal Framework Extractor.

A single extractor that runs all registered framework patterns against text
and produces standardized metadata for Bedrock Knowledge Base ingestion.

Architecture:
- FRAMEWORK_REGISTRY: Populated dynamically via register_framework()
- extract_frameworks(): Runs all patterns, returns unified result
- build_chunk_metadata(): Formats for POST_CHUNKING Lambda (S3 Vectors compliant)
- build_document_metadata(): Formats for document-level preprocessing

Metadata Strategy (S3 Vectors compliant):
- Filterable (~200-400 bytes): frameworks, primary_framework, document_type,
  primary_category, primary_category_name, reference_count
- Non-filterable (6 keys max): x_references, x_categories, x_source_section,
  x_framework_details, x_source_uri, x_enhancements
"""

import json
import os
import re
from typing import Any

# =============================================================================
# FRAMEWORK REGISTRY
# =============================================================================
# Populated dynamically by framework modules via register_framework()
# Each framework defines:
#   - name: Human-readable name
#   - reference_pattern: Regex pattern string or compiled pattern
#   - enhancement_pattern: Optional regex for sub-references (e.g., NIST enhancements)
#   - categories: Mapping of category codes to names
#   - category_extractor: Function to extract category from a reference
# =============================================================================

FRAMEWORK_REGISTRY: dict[str, dict[str, Any]] = {}


def register_framework(framework_id: str, config: dict[str, Any]) -> None:
    """
    Register a framework configuration.

    Args:
        framework_id: Unique identifier (e.g., "NIST-800-218-SSDF", "AWS-WAF")
        config: Framework configuration dict containing:
            - name: Human-readable name
            - description: Brief description
            - reference_pattern: Regex pattern (string or compiled)
            - categories: Dict of category_code -> category_name
            - category_extractor: Function(ref) -> category_code
            - enhancement_pattern: Optional regex for enhancements
            - reference_normalizer: Optional function to normalize refs
    """
    # Compile pattern if passed as string
    if isinstance(config.get("reference_pattern"), str):
        config["reference_pattern"] = re.compile(config["reference_pattern"])
    if isinstance(config.get("enhancement_pattern"), str):
        config["enhancement_pattern"] = re.compile(config["enhancement_pattern"])

    FRAMEWORK_REGISTRY[framework_id] = config


def get_registered_frameworks() -> list[str]:
    """Return list of all registered framework IDs."""
    return list(FRAMEWORK_REGISTRY.keys())


# Environment variable to enable/disable specific frameworks
# Defaults to all registered frameworks if not specified
_DEFAULT_FRAMEWORKS = os.environ.get("ENABLED_FRAMEWORKS", "")


def get_enabled_frameworks() -> list[str]:
    """Return list of currently enabled framework IDs."""
    if _DEFAULT_FRAMEWORKS:
        return [f.strip() for f in _DEFAULT_FRAMEWORKS.split(",") if f.strip() in FRAMEWORK_REGISTRY]
    # Default: all registered frameworks
    return list(FRAMEWORK_REGISTRY.keys())


# =============================================================================
# EXTRACTION FUNCTIONS
# =============================================================================


def extract_frameworks(text: str, frameworks: list[str] | None = None) -> dict[str, Any]:
    """
    Extract all framework references from text.

    Runs all enabled framework patterns against the text and returns
    a unified result with all detected references.

    Args:
        text: Document or chunk text content
        frameworks: Optional list of framework IDs to use (defaults to ENABLED_FRAMEWORKS)

    Returns:
        Dictionary containing:
        - frameworks: List of framework IDs detected
        - primary_framework: Framework with most references
        - references: Dict of framework_id -> list of references
        - categories: Dict of framework_id -> {category_code: count}
        - enhancements: Dict of framework_id -> list of enhancement details
        - total_references: Total count across all frameworks
    """
    frameworks_to_check = frameworks or get_enabled_frameworks()

    result = {
        "frameworks": [],
        "primary_framework": None,
        "references": {},
        "categories": {},
        "enhancements": {},
        "total_references": 0,
    }

    framework_ref_counts: dict[str, int] = {}

    for framework_id in frameworks_to_check:
        if framework_id not in FRAMEWORK_REGISTRY:
            continue

        config = FRAMEWORK_REGISTRY[framework_id]
        refs = set()
        categories: dict[str, int] = {}
        enhancements = []

        # Extract main references
        ref_pattern = config["reference_pattern"]
        for match in ref_pattern.finditer(text):
            # Handle patterns with multiple groups (like AWS-WAF with pillar + number)
            if len(match.groups()) > 1 and "reference_normalizer" in config:
                ref = config["reference_normalizer"](*match.groups())
            else:
                ref = match.group(1) if match.lastindex else match.group(0)

            # Validate category exists
            category_extractor = config.get("category_extractor", lambda x: x[:2])
            category_code = category_extractor(ref)

            if category_code and category_code in config["categories"]:
                refs.add(ref)
                categories[category_code] = categories.get(category_code, 0) + 1

        # Extract enhancements if pattern exists
        enhancement_pattern = config.get("enhancement_pattern")
        if enhancement_pattern:
            for match in enhancement_pattern.finditer(text):
                parent = match.group(1)
                enhancement_num = match.group(2)
                category_code = config.get("category_extractor", lambda x: x[:2])(parent)

                if category_code and category_code in config["categories"]:
                    enhancements.append({
                        "parent": parent,
                        "enhancement": int(enhancement_num),
                        "full_id": f"{parent}({enhancement_num})",
                    })
                    refs.add(parent)  # Also track parent control
                    categories[category_code] = categories.get(category_code, 0) + 1

        # Store results if any references found
        if refs:
            result["frameworks"].append(framework_id)
            result["references"][framework_id] = sorted(refs)
            result["categories"][framework_id] = categories
            framework_ref_counts[framework_id] = len(refs)

            if enhancements:
                result["enhancements"][framework_id] = sorted(
                    enhancements, key=lambda x: (x["parent"], x["enhancement"])
                )

    # Determine primary framework (most references)
    if framework_ref_counts:
        result["primary_framework"] = max(framework_ref_counts, key=framework_ref_counts.get)
        result["total_references"] = sum(framework_ref_counts.values())

    return result


def _extract_section_header(text: str) -> str | None:
    """
    Extract section header from text.

    Looks for common patterns:
    - Markdown headers: "## Section Name"
    - Numbered sections: "3.1.2 Section Name"
    - Control headers: "AC-1 ACCESS CONTROL POLICY"
    - AWS WAF style: "SEC-01: Identity and Access Management"
    """
    # Markdown header
    md_match = re.search(r"^#+\s+(.+?)$", text, re.MULTILINE)
    if md_match:
        return md_match.group(1).strip()[:100]

    # Numbered section
    numbered_match = re.search(r"^(\d+(?:\.\d+)*)\s+(.+?)$", text, re.MULTILINE)
    if numbered_match:
        return f"{numbered_match.group(1)} {numbered_match.group(2)}".strip()[:100]

    # NIST-style control header
    nist_header = re.search(r"^([A-Z]{2}-\d+)\s+([A-Z][A-Z\s]+)$", text, re.MULTILINE)
    if nist_header:
        return f"{nist_header.group(1)} {nist_header.group(2)}".strip()[:100]

    # AWS WAF style header
    waf_header = re.search(r"^(SEC|REL|PERF|COST|OPS|SUS)[-]?\d+[:\s]+(.+?)$", text, re.MULTILINE | re.IGNORECASE)
    if waf_header:
        return waf_header.group(0).strip()[:100]

    return None


def _infer_document_type(source_uri: str, text: str) -> str:
    """Infer document type from source URI or content."""
    source_lower = (source_uri or "").lower()
    text_lower = text.lower()[:500]

    type_keywords = [
        ("policy", "policy"),
        ("procedure", "procedure"),
        ("standard", "standard"),
        ("guideline", "guideline"),
        ("ssp", "ssp"),
        ("system security plan", "ssp"),
        ("poam", "poam"),
        ("plan of action", "poam"),
        ("assessment", "assessment"),
        ("ato", "ato"),
        ("authority to operate", "ato"),
        ("whitepaper", "whitepaper"),
        ("best practice", "best_practice"),
        ("well-architected", "well_architected"),
        ("benchmark", "benchmark"),
    ]

    for keyword, doc_type in type_keywords:
        if keyword in source_lower or keyword in text_lower:
            return doc_type

    return os.environ.get("DEFAULT_DOCUMENT_TYPE", "guidance")


# =============================================================================
# METADATA BUILDERS
# =============================================================================


def build_chunk_metadata(
    chunk_text: str,
    source_uri: str | None = None,
    existing_metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """
    Build two-tier metadata for a chunk (POST_CHUNKING Lambda).

    Produces S3 Vectors compliant metadata:
    - Filterable: <2KB, indexed for queries
    - Non-filterable: Stored but not indexed (6 keys max)

    Args:
        chunk_text: The text content of the chunk
        source_uri: S3 URI of the source document
        existing_metadata: Any existing metadata to preserve

    Returns:
        Dictionary with 'filterable' and 'non_filterable' keys
    """
    existing_metadata = existing_metadata or {}

    # Extract framework data
    framework_data = extract_frameworks(chunk_text)

    # Extract section header
    section_header = _extract_section_header(chunk_text)

    # Infer document type
    document_type = _infer_document_type(source_uri or "", chunk_text)

    # Build filterable metadata (~200-400 bytes)
    filterable: dict[str, Any] = {
        "document_type": document_type,
        "reference_count": framework_data["total_references"],
    }

    # Add frameworks list (JSON encoded for S3 Vectors)
    if framework_data["frameworks"]:
        filterable["frameworks"] = json.dumps(framework_data["frameworks"])
        filterable["primary_framework"] = framework_data["primary_framework"]

        # Add primary category from primary framework
        primary_fw = framework_data["primary_framework"]
        if primary_fw and framework_data["categories"].get(primary_fw):
            categories = framework_data["categories"][primary_fw]
            primary_category = max(categories, key=categories.get)
            filterable["primary_category"] = primary_category

            # Add human-readable category name
            fw_config = FRAMEWORK_REGISTRY.get(primary_fw, {})
            category_names = fw_config.get("categories", {})
            if primary_category in category_names:
                filterable["primary_category_name"] = category_names[primary_category]

    # Preserve existing filterable metadata
    for key in ["source_bucket", "source_key", "processed_at"]:
        if key in existing_metadata:
            filterable[key] = existing_metadata[key]

    # Build non-filterable metadata (6 keys max)
    non_filterable: dict[str, Any] = {}

    # x_references: All references across all frameworks
    all_refs = []
    for fw_refs in framework_data["references"].values():
        all_refs.extend(fw_refs)
    if all_refs:
        non_filterable["x_references"] = sorted(set(all_refs))

    # x_categories: Category distribution per framework
    if framework_data["categories"]:
        non_filterable["x_categories"] = framework_data["categories"]

    # x_source_section: Section header if found
    if section_header:
        non_filterable["x_source_section"] = section_header

    # x_framework_details: Framework-specific metadata
    framework_details = {}
    for fw_id in framework_data["frameworks"]:
        fw_config = FRAMEWORK_REGISTRY.get(fw_id, {})
        framework_details[fw_id] = {
            "name": fw_config.get("name", fw_id),
            "ref_count": len(framework_data["references"].get(fw_id, [])),
        }
    if framework_details:
        non_filterable["x_framework_details"] = framework_details

    # x_source_uri: Source document URI
    if source_uri:
        non_filterable["x_source_uri"] = source_uri

    # x_enhancements: Enhancement details (NIST-specific, etc.)
    if framework_data["enhancements"]:
        all_enhancements = []
        for fw_enhancements in framework_data["enhancements"].values():
            all_enhancements.extend([e["full_id"] for e in fw_enhancements])
        if all_enhancements:
            non_filterable["x_enhancements"] = all_enhancements

    return {
        "filterable": filterable,
        "non_filterable": non_filterable,
    }


def build_document_metadata(
    content: str,
    source_key: str,
    output_mode: str = "summary",
) -> dict[str, Any]:
    """
    Build document-level metadata for preprocessing Lambda.

    Args:
        content: Full document content (Markdown)
        source_key: Original S3 object key
        output_mode: "full", "summary", or "minimal"
            - full: Include all references in frontmatter (legacy)
            - summary: Only counts and primary info (recommended)
            - minimal: Only source info (POST_CHUNKING handles metadata)

    Returns:
        Dictionary with document-level metadata for YAML frontmatter
    """
    metadata = {
        "source": source_key,
    }

    if output_mode == "minimal":
        return metadata

    # Extract framework data
    framework_data = extract_frameworks(content)

    metadata["total_references"] = framework_data["total_references"]
    metadata["frameworks_detected"] = framework_data["frameworks"]

    if framework_data["primary_framework"]:
        metadata["primary_framework"] = framework_data["primary_framework"]

    if output_mode == "summary":
        # Compact summary per framework
        summaries = []
        for fw_id in framework_data["frameworks"]:
            categories = framework_data["categories"].get(fw_id, {})
            summary = f"{fw_id}: " + ", ".join(
                f"{cat}:{count}" for cat, count in sorted(categories.items())
            )
            summaries.append(summary)
        if summaries:
            metadata["framework_summary"] = summaries

    elif output_mode == "full":
        # Full reference lists (can exceed S3 Vectors 2KB limit)
        metadata["references"] = framework_data["references"]
        metadata["categories"] = framework_data["categories"]
        if framework_data["enhancements"]:
            metadata["enhancements"] = framework_data["enhancements"]

    return metadata