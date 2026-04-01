#!/usr/bin/env python3
"""
Send PNG or GIF to a BK-Light panel via Bleak (BleDisplaySession).

Source of truth: reference/panel-hopper-github/vendor/bk_light/display_session.py

Environment:
  BK_LIGHT_ADDRESS  — default MAC/UUID if --address omitted (Windows: AA:BB:...)

Examples:
  python send_to_panel.py --address AA:BB:CC:DD:EE:FF image.png
  python send_to_panel.py animation.gif
  python send_to_panel.py --brightness 80 --address ...
"""
from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path

_TOOLS_DIR = Path(__file__).resolve().parent
if str(_TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(_TOOLS_DIR))

# Repo-local: must run before importing bk_light
from vendor_path import ensure_bk_light_on_path

ensure_bk_light_on_path()

from bk_light.display_session import BleDisplaySession  # noqa: E402


def _load_file(path: Path) -> bytes:
    return path.read_bytes()


async def _run(args: argparse.Namespace) -> int:
    address = args.address or os.getenv("BK_LIGHT_ADDRESS")
    if not address:
        print("Error: set --address or BK_LIGHT_ADDRESS", file=sys.stderr)
        return 2

    session = BleDisplaySession(
        address=address,
        log_notifications=args.verbose,
        scan_timeout=args.scan_timeout,
    )

    async with session:
        if args.brightness is not None:
            ok = await session.set_panel_brightness(args.brightness)
            print(f"brightness {args.brightness}: {'OK' if ok else 'timeout/no ACK'}")

        path = Path(args.file)
        if not path.is_file():
            print(f"Error: not a file: {path}", file=sys.stderr)
            return 2

        data = _load_file(path)
        lower = path.suffix.lower()

        if lower == ".gif":
            gif_delay = args.delay if args.delay is not None else 0.05
            print(f"Sending GIF ({len(data)} bytes)...")
            ok = await session.send_gif(data, delay=gif_delay)
        else:
            png_delay = args.delay if args.delay is not None else 0.2
            print(f"Sending PNG ({len(data)} bytes)...")
            await session.send_png(data, delay=png_delay, stop_animation=not args.no_stop_anim)
            ok = True

        print("Done." if ok else "Completed with errors (see log).")
        return 0 if ok else 1


def main() -> None:
    parser = argparse.ArgumentParser(description="Send PNG/GIF to BK-Light LED panel (Bleak).")
    parser.add_argument("file", type=str, help="PNG or GIF file path")
    parser.add_argument(
        "--address", "-a", type=str, default=None, help="Panel BLE address (or BK_LIGHT_ADDRESS)"
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=None,
        help="Override delay (s). Default matches BleDisplaySession: 0.2 for PNG, 0.05 for GIF",
    )
    parser.add_argument(
        "--no-stop-anim",
        action="store_true",
        help="Do not send static display mode before PNG (default stops animation first)",
    )
    parser.add_argument("--brightness", type=int, default=None, help="Optional 0–100 before send")
    parser.add_argument("--scan-timeout", type=float, default=10.0, help="BLE scan timeout (s)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Log BLE notifications")
    args = parser.parse_args()

    try:
        code = asyncio.run(_run(args))
    except KeyboardInterrupt:
        code = 130
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        code = 1
    raise SystemExit(code)


if __name__ == "__main__":
    main()
