"""
Ensure `bk_light` imports resolve to reference/panel-hopper-github/vendor/bk_light.
"""
from __future__ import annotations

import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent
_VENDOR = _ROOT / "reference" / "panel-hopper-github" / "vendor"
if _VENDOR.is_dir():
    p = str(_VENDOR)
    if p not in sys.path:
        sys.path.insert(0, p)
