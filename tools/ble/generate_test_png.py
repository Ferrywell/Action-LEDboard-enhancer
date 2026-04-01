#!/usr/bin/env python3
"""
Write a 32×32 PNG test pattern (quadrant colors) for panel bring-up.

Does not connect to BLE — use with send_to_panel.py.
"""
from __future__ import annotations

import argparse
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw


def build_quadrant_png() -> bytes:
    img = Image.new("RGB", (32, 32), (0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, 15, 15], fill=(255, 0, 0))
    draw.rectangle([16, 0, 31, 15], fill=(0, 255, 0))
    draw.rectangle([0, 16, 15, 31], fill=(0, 0, 255))
    draw.rectangle([16, 16, 31, 31], fill=(255, 255, 0))
    buf = BytesIO()
    img.save(buf, format="PNG", optimize=False)
    return buf.getvalue()


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("test_pattern_32x32.png"),
        help="Output PNG path",
    )
    args = p.parse_args()
    args.output.write_bytes(build_quadrant_png())
    print(f"Wrote {args.output} ({args.output.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
