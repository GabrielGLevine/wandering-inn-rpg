#!/usr/bin/env python3
"""Compose the Steam capsule-art set from an existing windowed-QA screenshot.

Issue #19 (desktop presets + SteamPipe CI + store assets). Source material is
whatever the QA pipeline already produces (qa/run_qa.sh <script> windowed) —
no new art, no hand-drawn assets. This script center-crops one screenshot to
each capsule's exact aspect ratio, darkens the lower band for legibility, and
letters the title only (no tagline/subtitle art per the brief: "title text
only, keep it clean"). Re-run whenever screenshots/01_inn.png is refreshed
(new content, new licensed-asset overlay wave) — the four capsule PNGs are
committed derivatives, never hand-edited directly.

Usage: python3 docs/steam/make_capsules.py
Requires: Pillow (already a repo dependency for asset-pipeline tooling).
"""
from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "screenshots", "01_inn.png")
OUT_DIR = os.path.join(HERE, "capsules")

TITLE = "The Wandering Inn RPG"

# (filename, width, height) — the four EXACT sizes required by the brief.
SIZES = [
    ("capsule_small_231x87.png", 231, 87),
    ("capsule_main_460x215.png", 460, 215),
    ("capsule_library_616x353.png", 616, 353),
    ("capsule_hero_1232x706.png", 1232, 706),
]

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
]


def _font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def _center_crop(im: Image.Image, target_w: int, target_h: int) -> Image.Image:
    """Largest centered crop matching the target aspect ratio, then resize."""
    src_w, src_h = im.size
    target_ratio = target_w / target_h
    src_ratio = src_w / src_h
    if src_ratio > target_ratio:
        # source is wider than target — crop width (left/right)
        crop_h = src_h
        crop_w = int(round(crop_h * target_ratio))
    else:
        # source is taller/narrower than target — crop height (top/bottom)
        crop_w = src_w
        crop_h = int(round(crop_w / target_ratio))
    left = (src_w - crop_w) // 2
    top = (src_h - crop_h) // 2
    cropped = im.crop((left, top, left + crop_w, top + crop_h))
    return cropped.resize((target_w, target_h), Image.LANCZOS)


def _lettered(im: Image.Image, width: int, height: int) -> Image.Image:
    im = im.convert("RGB")
    overlay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Darken the lower band so the title reads clean over busy scenery —
    # scales with capsule height so the tiny 87px capsule doesn't lose the
    # whole image to the gradient.
    band_h = max(int(height * 0.42), 22)
    for y in range(band_h):
        alpha = int(190 * (y / band_h))
        draw.line([(0, height - band_h + y), (width, height - band_h + y)], fill=(10, 8, 14, alpha))
    draw.rectangle([0, height - 2, width, height], fill=(10, 8, 14, 190))

    composed = Image.alpha_composite(im.convert("RGBA"), overlay)

    # Fit the title within ~92% of the capsule width, scaling the font down
    # for the tiny capsule sizes rather than truncating the title text.
    draw2 = ImageDraw.Draw(composed)
    max_w = int(width * 0.92)
    size = max(int(height * 0.30), 10)
    font = _font(size)
    while size > 8:
        font = _font(size)
        bbox = draw2.textbbox((0, 0), TITLE, font=font)
        text_w = bbox[2] - bbox[0]
        if text_w <= max_w:
            break
        size -= 1
    bbox = draw2.textbbox((0, 0), TITLE, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = (width - text_w) // 2 - bbox[0]
    y = height - band_h + (band_h - text_h) // 2 - bbox[1] - int(height * 0.02)
    # Thin dark outline for legibility at small sizes, then the fill.
    outline = max(1, size // 18)
    for dx in range(-outline, outline + 1):
        for dy in range(-outline, outline + 1):
            if dx or dy:
                draw2.text((x + dx, y + dy), TITLE, font=font, fill=(10, 8, 14, 255))
    draw2.text((x, y), TITLE, font=font, fill=(240, 224, 190, 255))

    return composed.convert("RGB")


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    src = Image.open(SOURCE)
    for filename, w, h in SIZES:
        cropped = _center_crop(src, w, h)
        final = _lettered(cropped, w, h)
        assert final.size == (w, h), f"{filename}: got {final.size}, want {(w, h)}"
        out_path = os.path.join(OUT_DIR, filename)
        final.save(out_path, "PNG")
        print(f"wrote {out_path} ({w}x{h})")


if __name__ == "__main__":
    main()
