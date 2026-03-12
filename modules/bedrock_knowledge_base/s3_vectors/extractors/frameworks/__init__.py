"""Framework definitions for the Universal Extractor.

This package auto-loads all framework modules on import, registering
them with the FRAMEWORK_REGISTRY.

To add a new framework:
1. Create a new file in this directory (e.g., my_framework.py)
2. Import register_framework and call it with your config
3. The framework will be automatically available

Example:
    # my_framework.py
    from ..universal import register_framework

    register_framework("MY-FRAMEWORK", {
        "name": "My Framework",
        "description": "Description of the framework",
        "reference_pattern": r"\\b(MF-\\d+)\\b",
        "categories": {"MF": "My Category"},
        "category_extractor": lambda ref: ref[:2],
    })
"""

import importlib
import pkgutil
from pathlib import Path

# Auto-discover and import all framework modules in this package
_package_dir = Path(__file__).parent

for _finder, _name, _ispkg in pkgutil.iter_modules([str(_package_dir)]):
    if not _name.startswith("_"):
        importlib.import_module(f".{_name}", __package__)