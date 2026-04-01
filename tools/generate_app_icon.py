"""
Generate 1024x1024 iOS App Icon (RGB, no alpha) for Action LEDboard.
Run from repo root: python tools/generate_app_icon.py
Requires: pip install Pillow
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "ios" / "ActionLEDboard" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"
SIZE = 1024
CELL = 32  # 32x32 logical LED grid
DOT_R = 11
BG = (14, 16, 22)
OFF = (35, 38, 48)
ON = (255, 153, 0)
GLOW = (255, 190, 80)
DIM = (90, 55, 15)


def cell_color(x: int, y: int) -> tuple[int, int, int]:
    """Border + soft 'display' cross; rest dim."""
    if x == 0 or x == 31 or y == 0 or y == 31:
        return ON
    if x in (15, 16) or y in (15, 16):
        return GLOW if abs(x - 15) <= 2 or abs(y - 15) <= 2 else DIM
    if 8 <= x <= 23 and 8 <= y <= 23:
        return ON if (x + y) % 3 == 0 else OFF
    return OFF


def main() -> None:
    img = Image.new("RGB", (SIZE, SIZE), BG)
    draw = ImageDraw.Draw(img)
    for y in range(32):
        for x in range(32):
            cx = x * CELL + CELL // 2
            cy = y * CELL + CELL // 2
            color = cell_color(x, y)
            r = DOT_R if color != OFF else 8
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="PNG", optimize=True)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
