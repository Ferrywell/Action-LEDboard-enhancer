"""
Resolve path to `reference/panel-hopper-github/vendor` so `bk_light` imports work.
"""
from __future__ import annotations

import sys
from pathlib import Path


def ensure_bk_light_on_path() -> Path:
    """
    Insert Panel Hopper vendor root on sys.path and return that directory.

    Layout: <repo>/tools/ble/vendor_path.py -> vendor is three levels up + reference/...
    """
    here = Path(__file__).resolve().parent
    repo_root = here.parent.parent
    vendor_parent = repo_root / "reference" / "panel-hopper-github" / "vendor"
    if not vendor_parent.is_dir():
        raise FileNotFoundError(
            f"Expected vendor directory at {vendor_parent}. "
            "Clone or update reference/panel-hopper-github (see docs/reference/SOURCES.md)."
        )
    p = str(vendor_parent)
    if p not in sys.path:
        sys.path.insert(0, p)
    return vendor_parent
