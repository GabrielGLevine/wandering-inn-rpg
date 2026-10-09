#!/usr/bin/env python3
"""tools/asset_index.py must not index _sliced/ outputs (they are already
registry rows via tools/asset_candidates.py; indexing them double-counts)."""
import struct
import sys
import zlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
import asset_index as ai  # noqa: E402


def png(path: Path, w: int = 16, h: int = 16) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    chunk = b"IHDR" + ihdr
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", len(ihdr)) + chunk
                     + struct.pack(">I", zlib.crc32(chunk)))


def test_sliced_dirs_are_excluded(tmp_path):
    assets = tmp_path / "potential_assets"
    png(assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png", 800, 864)
    png(assets / "_sliced/Pixel Crawler - Free Pack/Furniture/Furniture__x0_y0_w16_h16.png")
    png(assets / "_sliced/Pixel Crawler - Free Pack/Furniture/contact.png", 64, 64)
    packs = ai.build(assets)
    assert [e["path"] for e in packs["Pixel Crawler - Free Pack"]] == [
        "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"]
