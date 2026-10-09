#!/usr/bin/env python3
"""tools/slice_atlases.py: synthetic atlases only (CI has no potential_assets/).
Run: python3 -m pytest -q scripts/tests/test_slice_atlases.py"""
import json
import sys
from pathlib import Path

import pytest

PIL = pytest.importorskip("PIL")
from PIL import Image, ImageDraw  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
import slice_atlases as sa  # noqa: E402

BLACK = (0, 0, 0, 255)
BROWN = (140, 90, 40, 255)
CLEAR = (0, 0, 0, 0)


def outlined_box(im, x, y, w, h, fill=BROWN):
    """A sprite with a 1px near-black outline and a light fill."""
    d = ImageDraw.Draw(im)
    d.rectangle((x, y, x + w - 1, y + h - 1), fill=fill, outline=BLACK)


def packed_crates(path: Path) -> Image.Image:
    """The #398 sheet: two 16x23 crates flush at x0-31 (double outline at x15/x16)
    and a barrel flush at x32-47 (double outline at x31/x32): ONE alpha component.
    65x33 is deliberately not a 16/32 multiple, so no grid expansion applies and
    the trimmed seam pieces are what the tests see."""
    im = Image.new("RGBA", (65, 33), CLEAR)
    outlined_box(im, 0, 0, 16, 23)
    outlined_box(im, 16, 0, 16, 23)
    outlined_box(im, 32, 1, 16, 22, fill=(90, 70, 50, 255))
    im.save(path)
    return im


def rgba(im):
    data = im.tobytes()
    return data, data[3::4], im.size[0], im.size[1]


def test_components_are_8_connected_with_exclusive_boxes():
    im = Image.new("RGBA", (8, 8), CLEAR)
    im.putpixel((1, 1), BROWN)
    im.putpixel((2, 2), BROWN)   # diagonal neighbour joins
    im.putpixel((6, 6), BROWN)   # separate
    data, alpha, w, h = rgba(im)
    labels, boxes = sa.components(alpha, w, h)
    assert boxes == [[1, 1, 3, 3, 2], [6, 6, 7, 7, 1]]
    assert labels[1 * w + 1] == labels[2 * w + 2] == 1 and labels[6 * w + 6] == 2


def test_double_outline_seam_splits_fused_crates(tmp_path):
    im = packed_crates(tmp_path / "Furniture.png")
    data, alpha, w, h = rgba(im)
    labels, boxes = sa.components(alpha, w, h)
    assert len(boxes) == 1, "flush sprites fuse into one alpha component"
    pieces = sa.split_box(data, labels, 1, w, boxes[0])
    assert [(p[0][:4], p[1]) for p in pieces] == [
        ([0, 0, 16, 23], "seam"), ([16, 0, 32, 23], "seam"), ([32, 1, 48, 23], "seam")]


def test_single_dark_column_is_not_a_seam():
    # One shared outline column between two fills: cutting it would strip an edge.
    present = [23] * 20
    dark = [23, 0, 0, 0, 0, 0, 0, 0, 0, 23, 0, 0, 0, 0, 0, 0, 0, 0, 0, 23]
    assert sa.seams(present, dark) == []


def test_solid_dark_mass_is_not_a_seam():
    # A black 24-wide block: every column is dark, no light flanks, no cut.
    assert sa.seams([24] * 24, [24] * 24) == []
    # A 3-wide dark band is a drawn stripe, not two outlines.
    band = [0] * 20
    band[9] = band[10] = band[11] = 20
    assert sa.seams([20] * 20, band) == []
    # Double dark columns WITH lighter flanks cut once, between k=9 and k=10,
    # even when a flank is 75% dark (a barrel's curved second column).
    dark = [0] * 20
    dark[9] = dark[10] = 20
    dark[11] = 15
    assert sa.seams([20] * 20, dark) == [10]


def test_tall_components_are_never_seam_split():
    # Two flush 16x65 "tree trunks" share a double outline but exceed SEAM_MAX_H.
    im = Image.new("RGBA", (33, 66), CLEAR)
    outlined_box(im, 0, 0, 16, 65)
    outlined_box(im, 16, 0, 16, 65)
    data, alpha, w, h = rgba(im)
    labels, boxes = sa.components(alpha, w, h)
    assert sa.split_box(data, labels, 1, w, boxes[0]) == [([0, 0, 32, 65, boxes[0][4]], "component")]


def test_grid_detection_and_cell_expansion():
    boxes = [[3, 3, 13, 13, 100], [19, 3, 29, 13, 100], [35, 3, 45, 13, 100], [3, 19, 13, 29, 100]]
    assert sa.sheet_grid(64, 32, boxes) == 16
    assert sa.cell_box(boxes[1], 16) == [16, 0, 32, 16]
    assert sa.sheet_grid(65, 33, boxes) is None, "sheet dims must be cell multiples"
    straddle = [[3, 3, 20, 13, 100], [19, 3, 29, 13, 100], [35, 3, 45, 13, 100], [3, 19, 13, 29, 100]]
    assert sa.sheet_grid(64, 32, straddle) is None, "2 of 4 clean is under GRID_CLEAN"
    assert sa.intersects([0, 0, 16, 16], [15, 15, 20, 20]) and not sa.intersects([0, 0, 16, 16], [16, 0, 20, 20])


def test_size_class_shadow_and_overlap():
    assert [sa.size_class(16, 9), sa.size_class(17, 9), sa.size_class(64, 1), sa.size_class(65, 1)] == ["S", "M", "L", "XL"]
    im = Image.new("RGBA", (8, 8), CLEAR)
    outlined_box(im, 1, 1, 6, 5)
    assert sa.has_shadow(im) is False
    im.putpixel((3, 7), (0, 0, 0, 90))
    assert sa.has_shadow(im) is True
    assert sa.overlap_ratio([736, 73, 16, 23], [720, 73, 48, 23]) == 1.0, "containment counts as full"
    assert sa.overlap_ratio([0, 0, 16, 16], [8, 0, 16, 16]) == 0.5
    assert sa.overlap_ratio([0, 0, 16, 16], [16, 0, 16, 16]) == 0.0
    assert sa.iou([736, 73, 16, 23], [720, 73, 48, 23]) == pytest.approx(1 / 3)
    assert sa.iou([0, 0, 16, 16], [0, 0, 16, 16]) == 1.0
    assert set(sa.KINDS) == {"crate", "barrel", "sack", "door", "window", "lamp", "table", "seat",
                             "shelf", "bed", "plant", "rock", "debris", "tool", "sign",
                             "wall_module", "container", "other"}
