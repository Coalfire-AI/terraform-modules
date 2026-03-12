"""AWS Well-Architected Framework.

The AWS Well-Architected Framework provides best practices for building
secure, high-performing, resilient, and efficient cloud infrastructure.

Reference format: XXX-NN or XXXNN
Examples: SEC-01, REL02, PERF-03, COST04, OPS-05, SUS06
"""

import re
from ..universal import register_framework

register_framework("AWS-WAF", {
    "name": "AWS Well-Architected Framework",
    "description": "Best practices for cloud architecture across six pillars",
    # Matches: SEC01, REL02, PERF03, COST04, OPS05, SUS06
    # Also: SEC-01, REL-02 (with hyphen)
    "reference_pattern": re.compile(r"\b(SEC|REL|PERF|COST|OPS|SUS)[-]?(\d{1,2})\b", re.IGNORECASE),
    "enhancement_pattern": None,  # AWS WAF doesn't have enhancements
    "categories": {
        "SEC": "Security",
        "REL": "Reliability",
        "PERF": "Performance Efficiency",
        "COST": "Cost Optimization",
        "OPS": "Operational Excellence",
        "SUS": "Sustainability",
    },
    "category_extractor": lambda ref: ref[:3].upper() if len(ref) >= 3 else ref.upper(),
    # Normalize reference format
    "reference_normalizer": lambda pillar, num: f"{pillar.upper()}-{num.zfill(2)}",
})