#!/usr/bin/env python3
"""Verify committed Android/iOS icon artwork without third-party libraries."""

from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "launcher"
SOURCES = {
    "pebble_icon.png": 2,                   # 8-bit RGB, no alpha (iOS)
    "pebble_adaptive_foreground.png": 6,    # 8-bit RGBA (Android)
    "pebble_monochrome.png": 6,             # 8-bit RGBA (themed icons)
}

for filename, expected_colour_type in SOURCES.items():
    path = ART / filename
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{filename}: invalid PNG signature"
    assert data[12:16] == b"IHDR", f"{filename}: missing PNG header"
    width, height = struct.unpack(">II", data[16:24])
    bit_depth, colour_type = data[24], data[25]
    assert (width, height) == (1024, 1024), f"{filename}: expected 1024px square"
    assert bit_depth == 8 and colour_type == expected_colour_type, (
        f"{filename}: unexpected colour format ({bit_depth}, {colour_type})"
    )
    print(f"{filename}: {width}×{height}, PNG color type {colour_type}, {len(data)} bytes")

print("Pebble launcher artwork checks passed.")
