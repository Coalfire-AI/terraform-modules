"""NIST SP 800-218 Secure Software Development Framework (SSDF).

The SSDF defines a set of practices for secure software development
organized into four groups: Prepare, Protect, Produce, and Respond.

Reference format: XX.N or XX.N.N for tasks
Examples: PO.1, PS.2, PW.3.1, RV.1.2
"""

import re
from ..universal import register_framework

register_framework("NIST-800-218-SSDF", {
    "name": "NIST SP 800-218 SSDF",
    "description": "Secure Software Development Framework v1.1",
    # Matches practices: PO.1, PS.2, PW.3, RV.1, etc.
    # Matches tasks: PO.1.1, PS.3.2, PW.1.2, RV.1.1, etc.
    "reference_pattern": re.compile(r"\b((?:PO|PS|PW|RV)\.\d+(?:\.\d+)?)\b"),
    "enhancement_pattern": None,  # SSDF uses tasks, not enhancements
    "categories": {
        "PO": "Prepare the Organization",
        "PS": "Protect the Software",
        "PW": "Produce Well-Secured Software",
        "RV": "Respond to Vulnerabilities",
    },
    # Practice descriptions for detailed metadata
    "practices": {
        # PO - Prepare the Organization
        "PO.1": "Define Security Requirements for Software Development",
        "PO.2": "Implement Roles and Responsibilities",
        "PO.3": "Implement Supporting Toolchains",
        "PO.4": "Define and Use Criteria for Software Security Checks",
        "PO.5": "Implement and Maintain Secure Environments for Software Development",
        # PS - Protect the Software
        "PS.1": "Protect All Forms of Code from Unauthorized Access",
        "PS.2": "Provide a Mechanism for Verifying Software Release Integrity",
        "PS.3": "Archive and Protect Each Software Release",
        # PW - Produce Well-Secured Software
        "PW.1": "Design Software to Meet Security Requirements and Mitigate Security Risks",
        "PW.2": "Review the Software Design to Verify Compliance with Security Requirements",
        "PW.3": "Reuse Existing, Well-Secured Software When Feasible",
        "PW.4": "Use a Standard, Secure Coding Practices Checklist",
        "PW.5": "Use Code Analysis to Detect Potential Security Vulnerabilities",
        "PW.6": "Use Testing to Detect Potential Security Vulnerabilities",
        "PW.7": "Configure the Software to Have Secure Settings by Default",
        "PW.8": "Review and/or Analyze Human-Readable Code",
        "PW.9": "Test Executable Code to Identify Vulnerabilities",
        # RV - Respond to Vulnerabilities
        "RV.1": "Identify and Confirm Vulnerabilities on an Ongoing Basis",
        "RV.2": "Assess, Prioritize, and Remediate Vulnerabilities",
        "RV.3": "Analyze Vulnerabilities to Identify Their Root Causes",
    },
    "category_extractor": lambda ref: ref.split(".")[0] if "." in ref else None,
})
