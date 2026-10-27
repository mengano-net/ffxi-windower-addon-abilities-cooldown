#!/usr/bin/env python3
"""Generate the PNG textures the addon draws with.

Windower tints a texture by multiplying it with the image's color, so the
textures are greyscale and the addon paints the real color (from
profiles.lua) on top at run time.

Standard library only (no PIL). Usage:
    python3 scripts/make-textures.py
Writes into abilities_cooldown/textures/.
"""
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "abilities_cooldown" / "textures"


def write_png(path, width, height, pixel):
    """pixel(x, y) -> (r, g, b, a), each 0-255."""
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type: none
        for x in range(width):
            raw.extend(pixel(x, y))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)  # 8-bit RGBA
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


# Bottom brightness as a share of the top. The README preview's background
# runs #2a3a4f -> #121a24, about 45%; the panel uses the same falloff.
PANEL_BOTTOM = 0.45


def panel(x, y, height=64):
    """Vertical gradient, full brightness at the top to PANEL_BOTTOM at the
    bottom. Tinted with colors.background, that is the top color."""
    t = y / (height - 1)
    v = int(round(255 * (1 - (1 - PANEL_BOTTOM) * t)))
    return (v, v, v, 255)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    write_png(OUT / "panel.png", 8, 64, panel)
    print(OUT / "panel.png")


if __name__ == "__main__":
    main()
