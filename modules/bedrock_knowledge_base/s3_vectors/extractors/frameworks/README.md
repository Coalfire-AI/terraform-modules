# Adding New Framework Extractors

This directory contains framework definitions that are auto-discovered and registered when the extractors module is imported.

## When Are Extractors Needed?

| Vector Store | Extractors Required? | Reason |
|--------------|---------------------|--------|
| **S3 Vectors** | **Yes** (for framework filtering) | 2KB metadata limit requires explicit tagging |
| **OpenSearch Serverless** | **No** (optional) | Semantic search handles most use cases |

For detailed guidance on vector store requirements, see [../../docs/extractors-guide.md](../../docs/extractors-guide.md).

## Quick Start

1. Create a new file: `my_framework.py`
2. Register your framework:

```python
from ..universal import register_framework

register_framework("MY-FRAMEWORK-ID", {
    "name": "My Framework Name",
    "description": "Brief description",
    "reference_pattern": r"\b(MF-\d+)\b",
    "categories": {
        "MF": "My Category",
    },
    "category_extractor": lambda ref: ref[:2],
})
```

3. Test it works:
```bash
cd modules/bedrock_knowledge_base/s3_vectors
python3 -c "from extractors import get_registered_frameworks; print(get_registered_frameworks())"
```

## Configuration Reference

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | `str` | Human-readable framework name |
| `description` | `str` | Brief description of the framework |
| `reference_pattern` | `re.Pattern` or `str` | Regex to match references in text |
| `categories` | `dict[str, str]` | Map of category codes to names |
| `category_extractor` | `Callable[[str], str]` | Function to extract category from reference |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `enhancement_pattern` | `re.Pattern` or `str` | Regex for sub-references (e.g., NIST enhancements) |
| `reference_normalizer` | `Callable[..., str]` | Normalize reference format (for multi-group patterns) |
| `practices` | `dict[str, str]` | Additional metadata (practice descriptions, etc.) |

## Pattern Design

### Simple Pattern (Single Group)

For frameworks like NIST 800-218 SSDF where references are self-contained:

```python
# Matches: PO.1, PS.2, PW.3.1, RV.1
"reference_pattern": re.compile(r"\b((?:PO|PS|PW|RV)\.\d+(?:\.\d+)?)\b")
```

The first capture group becomes the reference ID.

### Multi-Group Pattern with Normalizer

For frameworks where you need to combine parts:

```python
# Matches: SEC01, SEC-01, sec01
"reference_pattern": re.compile(r"\b(SEC|REL|PERF)[-]?(\d{1,2})\b", re.IGNORECASE),
"reference_normalizer": lambda pillar, num: f"{pillar.upper()}-{num.zfill(2)}",
```

The normalizer receives all capture groups and returns the canonical reference.

### Enhancement Pattern

For frameworks with hierarchical references (parent + enhancement):

```python
# Matches: AC-2(1), AU-12(3)
"enhancement_pattern": re.compile(r"\b([A-Z]{2}-\d+)\((\d+)\)\b")
```

Group 1 = parent reference, Group 2 = enhancement number.

## Category Extractor

The category extractor derives the category code from a reference:

```python
# Extract first 2 characters: "AC-1" -> "AC"
"category_extractor": lambda ref: ref[:2] if len(ref) >= 2 else None

# Split on dot: "PO.1.2" -> "PO"
"category_extractor": lambda ref: ref.split(".")[0] if "." in ref else None

# Extract first 3-4 chars: "SEC-01" -> "SEC"
"category_extractor": lambda ref: ref[:3].upper() if len(ref) >= 3 else ref.upper()
```

The extracted code must exist in `categories` dict or the reference is ignored.

## Complete Examples

### Example 1: CIS Benchmarks

```python
# cis_benchmarks.py
"""CIS Benchmarks - Security Configuration Standards."""

import re
from ..universal import register_framework

register_framework("CIS", {
    "name": "CIS Benchmarks",
    "description": "Center for Internet Security configuration standards",
    # Matches: 1.1, 2.3.4, 5.1.2.3
    "reference_pattern": re.compile(r"\b(\d+(?:\.\d+){1,3})\b"),
    "enhancement_pattern": None,
    "categories": {
        "1": "Initial Setup",
        "2": "Services",
        "3": "Network Configuration",
        "4": "Logging and Auditing",
        "5": "Access, Authentication and Authorization",
        "6": "System Maintenance",
    },
    "category_extractor": lambda ref: ref.split(".")[0],
})
```

### Example 2: SOC 2 Trust Services Criteria

```python
# soc2.py
"""SOC 2 Trust Services Criteria."""

import re
from ..universal import register_framework

register_framework("SOC2", {
    "name": "SOC 2",
    "description": "Service Organization Control 2 Trust Services Criteria",
    # Matches: CC1.1, CC6.3, A1.2, C1.1, PI1.1
    "reference_pattern": re.compile(r"\b(CC|A|C|PI|P)\d+\.\d+\b"),
    "enhancement_pattern": None,
    "categories": {
        "CC": "Common Criteria",
        "A": "Availability",
        "C": "Confidentiality",
        "PI": "Processing Integrity",
        "P": "Privacy",
    },
    "category_extractor": lambda ref: "".join(c for c in ref if c.isalpha()),
})
```

### Example 3: ISO 27001 Controls

```python
# iso_27001.py
"""ISO/IEC 27001 Information Security Controls."""

import re
from ..universal import register_framework

register_framework("ISO-27001", {
    "name": "ISO/IEC 27001",
    "description": "Information security management controls",
    # Matches: A.5.1, A.12.3.1, 5.1, 12.3.1
    "reference_pattern": re.compile(r"\b(A\.)?(\d{1,2}(?:\.\d{1,2}){1,2})\b"),
    "enhancement_pattern": None,
    "categories": {
        "5": "Information Security Policies",
        "6": "Organization of Information Security",
        "7": "Human Resource Security",
        "8": "Asset Management",
        "9": "Access Control",
        "10": "Cryptography",
        "11": "Physical and Environmental Security",
        "12": "Operations Security",
        "13": "Communications Security",
        "14": "System Acquisition, Development and Maintenance",
        "15": "Supplier Relationships",
        "16": "Information Security Incident Management",
        "17": "Business Continuity Management",
        "18": "Compliance",
    },
    "category_extractor": lambda ref: ref.lstrip("A.").split(".")[0],
    "reference_normalizer": lambda prefix, num: f"A.{num}" if prefix else f"A.{num}",
})
```

## Testing Your Framework

### 1. Unit Test

```python
# test_my_framework.py
from extractors import extract_frameworks

def test_my_framework():
    text = """
    This document references MF-1 and MF-23.
    Also see MF-100 for details.
    """

    result = extract_frameworks(text, frameworks=["MY-FRAMEWORK"])

    assert "MY-FRAMEWORK" in result["frameworks"]
    assert set(result["references"]["MY-FRAMEWORK"]) == {"MF-1", "MF-23", "MF-100"}
    assert result["categories"]["MY-FRAMEWORK"]["MF"] == 3
```

### 2. Interactive Test

```bash
cd modules/bedrock_knowledge_base/s3_vectors
python3 << 'EOF'
from extractors import extract_frameworks, get_registered_frameworks

# Verify registration
print("Registered:", get_registered_frameworks())

# Test extraction
text = "See control MF-1 and MF-2 for requirements."
result = extract_frameworks(text)
print("Result:", result)
EOF
```

### 3. Integration Test

After adding a framework, run the full test suite:

```bash
cd /path/to/terraform-modules
python3 -m pytest tests/ -v -k "extractor"
```

## Environment Variables

Control which frameworks are enabled at runtime:

```bash
# Enable specific frameworks only
export ENABLED_FRAMEWORKS="NIST-800-218-SSDF,MY-FRAMEWORK"

# Default: all registered frameworks are enabled
```

## Troubleshooting

### Framework not detected

1. Check file is in `frameworks/` directory
2. Ensure filename doesn't start with `_`
3. Verify no import errors: `python3 -c "from extractors.frameworks import my_framework"`

### References not matching

1. Test pattern in isolation: `re.findall(pattern, text)`
2. Check category extractor returns valid category code
3. Verify category code exists in `categories` dict

### Category counts wrong

1. Check for overlapping patterns between frameworks
2. Verify `category_extractor` handles edge cases
3. Test with explicit framework list: `extract_frameworks(text, frameworks=["MY-FRAMEWORK"])`