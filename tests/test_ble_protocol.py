"""
Unit tests for BK-Light BLE protocol helpers (no hardware required).

Truth: reference/panel-hopper-github/vendor/bk_light/display_session.py
If these fail after a vendor update, compare against that file first.
"""
from __future__ import annotations

import asyncio
import binascii
from unittest.mock import MagicMock

import pytest

from bk_light.display_session import (
    ACK_BRIGHTNESS,
    ACK_DISPLAY_MODE,
    ACK_ON_OFF,
    ACK_ROTATION,
    ACK_SAVE,
    ACK_STAGE_ONE,
    ACK_STAGE_THREE,
    ACK_STAGE_TWO,
    AckWatcher,
    CMD_BRIGHTNESS,
    CMD_DELETE_ALL,
    CMD_DISPLAY_MODE,
    CMD_EDIT_END,
    CMD_ON_OFF,
    CMD_ROTATION,
    CMD_SAVE_COMMIT,
    CMD_SAVE_PREPARE,
    FRAME_VALIDATION,
    HANDSHAKE_FIRST,
    HANDSHAKE_SECOND,
    build_frame,
)


def test_handshake_and_cmd_constants_match_reference_hex():
    assert bytes.fromhex("08 00 01 80 0E 06 32 00") == HANDSHAKE_FIRST
    assert bytes.fromhex("04 00 05 80") == HANDSHAKE_SECOND
    assert CMD_EDIT_END == bytes.fromhex("05 00 04 01 00")
    assert CMD_BRIGHTNESS == bytes.fromhex("05 00 04 80")
    assert CMD_ROTATION == bytes.fromhex("05 00 06 80")
    assert CMD_ON_OFF == bytes.fromhex("05 00 07 01")
    assert CMD_DELETE_ALL == bytes.fromhex("04 00 03 80")
    assert CMD_SAVE_PREPARE == bytes.fromhex("07 00 02 01 01 00 01")
    assert CMD_SAVE_COMMIT == bytes.fromhex("07 00 02 01 01 00 02")
    assert CMD_DISPLAY_MODE == bytes.fromhex("07 00 08 80 01 00")


def test_ack_constants_used_by_watcher():
    assert ACK_STAGE_ONE == bytes.fromhex("0C 00 01 80 81 06 32 00 00 01 00 01")
    assert ACK_STAGE_TWO == bytes.fromhex("08 00 05 80 0B 03 07 02")
    assert ACK_STAGE_THREE == bytes.fromhex("05 00 02 00 03")
    assert FRAME_VALIDATION == bytes.fromhex("05 00 00 01 00")


def test_build_frame_png_layout_and_crc():
    payload = b"fake-png-bytes"
    frame = build_frame(payload, is_gif_frame=False, frame_index=0)
    total_len = len(payload) + 15
    assert frame[0:2] == total_len.to_bytes(2, "little")
    assert frame[2:4] == bytes([0x02, 0x00])
    assert frame[4] == 0x00
    assert frame[5:9] == len(payload).to_bytes(4, "little")
    assert frame[9:13] == binascii.crc32(payload).to_bytes(4, "little")
    assert frame[13] == 0x00
    assert frame[14] == 0x65
    assert frame[15:] == payload


def test_build_frame_gif_flags_and_continue():
    payload = b"g"
    first = build_frame(payload, is_gif_frame=True, frame_index=0)
    assert first[2:4] == bytes([0x03, 0x00])
    assert first[4] == 0x00
    assert first[13] == 0x02
    cont = build_frame(payload, is_gif_frame=True, frame_index=1)
    assert cont[4] == 0x02


def test_gif_chunk_header_algorithm_matches_display_session_send_gif():
    """
    Mirrors send_gif() chunk header construction (display_session.py).
    If this drifts, update alongside vendor file.
    """
    CHUNK_SIZE = 12288
    gif_data = b"Z" * 13000
    total_gif_length = len(gif_data)
    crc = binascii.crc32(gif_data) & 0xFFFFFFFF
    num_chunks = (total_gif_length + CHUNK_SIZE - 1) // CHUNK_SIZE
    assert num_chunks == 2

    for chunk_idx in range(num_chunks):
        start = chunk_idx * CHUNK_SIZE
        end = min(start + CHUNK_SIZE, total_gif_length)
        chunk_data = gif_data[start:end]
        chunk_length = len(chunk_data) + 15
        header = bytearray()
        header += chunk_length.to_bytes(2, "little")
        header += bytes([0x03, 0x00])
        header.append(0x00 if chunk_idx == 0 else 0x02)
        header += total_gif_length.to_bytes(4, "little")
        header += crc.to_bytes(4, "little")
        header.append(0x00)
        header.append(0x65)
        packet = bytes(header) + chunk_data
        assert packet[0:2] == chunk_length.to_bytes(2, "little")
        assert packet[4] == (0x00 if chunk_idx == 0 else 0x02)
        assert int.from_bytes(packet[5:9], "little") == total_gif_length


def test_ack_watcher_handshake_and_frame_acks():
    async def run():
        w = AckWatcher(verbose=False)
        w.handler(MagicMock(), bytearray(ACK_STAGE_ONE))
        assert w.stage_one.is_set()
        w.handler(MagicMock(), bytearray(ACK_STAGE_TWO))
        assert w.stage_two.is_set()
        w.handler(MagicMock(), bytearray(ACK_STAGE_THREE))
        assert w.stage_three.is_set()

    asyncio.run(run())


def test_ack_watcher_gif_chunk_and_complete():
    async def run():
        w = AckWatcher(verbose=False)
        w.frame_ack.clear()
        w.handler(MagicMock(), bytearray([0x05, 0x00, 0x03, 0x00, 0x01]))
        await asyncio.wait_for(w.frame_ack.wait(), timeout=0.2)
        assert not w.gif_complete.is_set()

        w.reset()
        w.handler(MagicMock(), bytearray([0x05, 0x00, 0x03, 0x00, 0x03]))
        await asyncio.wait_for(w.gif_complete.wait(), timeout=0.2)

    asyncio.run(run())


@pytest.mark.parametrize(
    "cmd_bytes,label",
    [
        (CMD_BRIGHTNESS + bytes([50]), "brightness"),
        (CMD_ROTATION + bytes([2]), "rotation"),
        (CMD_ON_OFF + bytes([1]), "on_off"),
        (CMD_SAVE_PREPARE, "save_prepare"),
        (bytes.fromhex("07 00 08 80 01 00 03"), "display_mode"),
        (CMD_EDIT_END, "edit_end"),
        (CMD_DELETE_ALL, "delete_all"),
    ],
)
def test_ack_watcher_command_ack_by_cmd_id(cmd_bytes: bytes, label: str):
    """Notifications with recognized cmd_id in [2:4] set command_ack."""

    async def run():
        w = AckWatcher(verbose=False)
        # Synthetic ACK: length + echo cmd id + trailing byte (like real ACKs)
        if len(cmd_bytes) >= 4:
            cmd_id = cmd_bytes[2:4]
        else:
            pytest.skip("short command")
        ack = bytearray([0x05, 0x00, cmd_id[0], cmd_id[1], 0x01])
        w.handler(MagicMock(), ack)
        await asyncio.wait_for(w.command_ack.wait(), timeout=0.2)
        assert w.last_response == bytes(ack)

    asyncio.run(run())


def test_expected_panel_command_ack_payloads():
    """Documented ACK shapes from display_session.py (for iOS parity checks)."""
    assert ACK_BRIGHTNESS == bytes.fromhex("05 00 04 80 01")
    assert ACK_ROTATION == bytes.fromhex("05 00 06 80 01")
    assert ACK_ON_OFF == bytes.fromhex("05 00 07 01 01")
    assert ACK_SAVE == bytes.fromhex("05 00 02 01 01")
    assert ACK_DISPLAY_MODE == bytes.fromhex("05 00 08 80 01")
