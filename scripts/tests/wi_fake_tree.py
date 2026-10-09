#!/usr/bin/env python3
"""Synthetic repo tree for tools/wire_asset.py and tools/fill_kit.py tests.

Builds a throwaway copy of the parts those tools touch (sprites.json, the C7
fixture, assets_manifest.json, provenance, docs, one bundled pack sheet, one
owned batch with MANIFEST.json, two atlas slices with SLICES.json) so the tools
run with --repo-root and never see the real tree. PNGs are drawn with PIL.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
import wire_asset as wa  # noqa: E402

PACK = "Pixel Crawler - Free Pack 2.1"       # spaces and a dot, like the real pack dir
UNBUNDLED_PACK = "Pixel Crawler - Hideout 1.0"
OWNED = "potential_assets/pixellab_test/L2_props/parcel_stack.png"
OWNED_DUP = "potential_assets/pixellab_test/L2_props/parcel_stack__alt1.png"
STRIP = "potential_assets/pixellab_test/L2_props/lantern_flicker.png"
BENCH = "potential_assets/pixellab_test/L2_props/wide_bench.png"
SLICE = f"potential_assets/{PACK}/_sliced/Furniture/Furniture__x16_y8_w16_h23.png"
PENDING_SLICE = f"potential_assets/{UNBUNDLED_PACK}/_sliced/Props/Props__x0_y0_w16_h16.png"
PIXELLAB_ID = "0a4384ab-702d-4998-8e26-8e15c4c97585"


def png_box(path: Path, w: int, h: int, box: tuple[int, int, int, int],
            color: tuple[int, int, int, int] = (150, 90, 40, 255)) -> Path:
    """Transparent canvas with one opaque box (inclusive corners, PIL semantics)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(img).rectangle(box, fill=color, outline=(20, 10, 5, 255))
    img.save(path)
    return path


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(root: Path) -> dict[str, str]:
    """relpath -> sha256 for every file; tests diff two of these."""
    return {p.relative_to(root).as_posix(): sha(p) for p in sorted(root.rglob("*")) if p.is_file()}


def changed(before: dict[str, str], after: dict[str, str]) -> set[str]:
    return {p for p in set(before) | set(after) if before.get(p) != after.get(p)}


def make_tree(root: Path) -> Path:
    game = root / "wandering_inn_game"
    png_box(game / "assets" / "sprites" / "crate_owned" / "Idle-Sheet.png", 64, 64, (20, 30, 43, 59))
    sheet = png_box(game / "assets" / "props" / "free_pack" / "Furniture.png", 128, 64, (16, 8, 31, 30))
    sprites = {
        "pc_human_m": {"directional": True, "render_scale": 0.62, "animations": {"idle": {
            "sheet_down": "res://assets/sprites/pc_human_m/Idle_Down-Sheet.png",
            "sheet_side": "res://assets/sprites/pc_human_m/Idle_Side-Sheet.png",
            "sheet_up": "res://assets/sprites/pc_human_m/Idle_Up-Sheet.png",
            "frame_size": [104, 104], "fps": 6}}},
        "crate_owned": {"render_scale": 0.4, "anchor": [0.5, 0.9375], "shadow": True, "animations": {
            "idle": {"sheet": "res://assets/sprites/crate_owned/Idle-Sheet.png",
                     "frame_size": [64, 64], "fps": 1}}},
        "crate": {"fallback_sprite": "crate_owned", "render_scale": 1.0, "anchor": [0.5, 1.0], "animations": {
            "idle": {"sheet": "res://assets/props/free_pack/Furniture.png", "frame_size": [16, 23],
                     "region": [16, 8, 16, 23], "fps": 1}}},
    }
    (game / "data").mkdir(parents=True)
    (game / "data" / "sprites.json").write_text(json.dumps(sprites, indent=1) + "\n", encoding="utf-8")
    fixture = {"_comment": wa.FIXTURE_COMMENT,
               "counts": {"crate/idle": 1, "crate_owned/idle": 1, "pc_human_m/idle": 4}}
    (game / "qa" / "fixtures").mkdir(parents=True)
    (game / "qa" / "fixtures" / "sprite_frame_counts.json").write_text(
        json.dumps(fixture, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    manifest = {"_comment": "fake", "assets": [{"path": "assets/props/free_pack/Furniture.png",
                "source_pack": PACK, "verdict": "FORBIDDEN", "bundle": True, "fallback": "placeholder"}]}
    (game / "assets_manifest.json").write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")
    (game / "assets" / "LICENSES").mkdir(parents=True)
    (game / "assets" / "LICENSES" / "v019-owned-art-provenance.txt").write_text(
        "OWNED ART — fake tree\n=====================\n\nassets/sprites/crate_owned/Idle-Sheet.png\n"
        "    fake owned sibling.\n", encoding="utf-8")
    (root / "docs").mkdir()
    (root / "docs" / "art-bundle-pending.md").write_text(wa.BUNDLE_PENDING_HEADER, encoding="utf-8")
    # owned batch: a 64x64 static, its byte-identical duplicate, a 192x64 three-frame
    # strip, and a 96x32 strip whose MANIFEST row pins frame_size [48, 32]
    batch = root / "potential_assets" / "pixellab_test" / "L2_props"
    png_box(batch / "parcel_stack.png", 64, 64, (18, 24, 45, 59))
    (batch / "parcel_stack__alt1.png").write_bytes((batch / "parcel_stack.png").read_bytes())
    png_box(batch / "lantern_flicker.png", 192, 64, (24, 10, 40, 60))
    png_box(batch / "wide_bench.png", 96, 32, (4, 6, 90, 30))
    (batch / "MANIFEST.json").write_text(json.dumps({
        "schema": 1, "source": "pixellab", "tier": "owned-public", "family": "PIXELLAB-AI", "assets": [
            {"path": "parcel_stack.png", "kind": "prop", "targets": ["parcel_stack", "crate"],
             "verdict": "READY", "pixellab_id": PIXELLAB_ID, "prompt": "stacked parcels"},
            {"path": "parcel_stack__alt1.png", "kind": "prop", "targets": ["parcel_stack", "crate"],
             "verdict": "ALT", "pixellab_id": PIXELLAB_ID},
            {"path": "lantern_flicker.png", "kind": "prop", "targets": ["lamp"], "verdict": "READY",
             "pixellab_id": "11111111-2222-4333-8444-555555555555"},
            {"path": "wide_bench.png", "kind": "prop", "targets": ["seat", "crate"], "verdict": "REJECTED",
             "frame_size": [48, 32]},
        ]}, indent=1) + "\n", encoding="utf-8")
    # pack slices: one cut from the bundled sheet, one from a sheet absent under assets/
    sliced = root / "potential_assets" / PACK / "_sliced" / "Furniture"
    sliced.mkdir(parents=True)
    with Image.open(sheet) as im:
        im.crop((16, 8, 32, 31)).save(sliced / "Furniture__x16_y8_w16_h23.png")
    (sliced / "SLICES.json").write_text(json.dumps({"assets": [{
        "path": SLICE, "kind": "prop", "targets": ["crate"], "verdict": "UNREVIEWED", "notes": "",
        "source_sheet": f"potential_assets/{PACK}/Furniture.png", "region": [16, 8, 16, 23],
        "sheet_sha256": sha(sheet), "method": "grid16", "has_shadow": False, "size_class": "M",
        "label_confidence": 0.9}]}, indent=1) + "\n", encoding="utf-8")
    pending = root / "potential_assets" / UNBUNDLED_PACK / "_sliced" / "Props"
    png_box(pending / "Props__x0_y0_w16_h16.png", 16, 16, (1, 1, 14, 14))
    (pending / "SLICES.json").write_text(json.dumps({"assets": [{
        "path": PENDING_SLICE, "kind": "prop", "targets": ["crate"], "verdict": "UNREVIEWED", "notes": "",
        "source_sheet": f"potential_assets/{UNBUNDLED_PACK}/Props.png", "region": [0, 0, 16, 16],
        "sheet_sha256": "f" * 64, "method": "grid16", "has_shadow": False, "size_class": "M",
        "label_confidence": 0.5}]}, indent=1) + "\n", encoding="utf-8")
    return root
