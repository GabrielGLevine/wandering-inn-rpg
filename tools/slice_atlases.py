#!/usr/bin/env python3
"""Slice static multi-sprite pack atlases into individual candidate sprites.

Spec: docs/superpowers/specs/2026-10-08-regional-kits-design.md section 4.1.
Row contract: docs/superpowers/plans/2026-10-08-regional-kits-phase0.md C8.

For every eligible sheet under potential_assets/ (Pixel Crawler prop atlases;
never animation strips, tilesets, shadows, lights, enemies, stations or promo
renders):
  1. find 8-connected alpha components (area >= MIN_AREA);
  2. split components on DOUBLE outline seams. #398: two flush crates and a
     barrel are ONE alpha component; the seam is two adjacent near-black
     columns (each sprite's own outline) whose flanks are not seam-dark. A
     single dark column is a shared edge and a dark mass is a sprite, never
     a seam; components taller than SEAM_MAX_H (trees) are never split;
  3. expand to the 16/32 px cell when the sheet is grid-laid and the cell
     holds no other piece (method grid16/grid32); else keep the trimmed box
     (component/seam). Manual --split regions are method override;
  4. write <pack>/_sliced/<stem>/<stem>__x{X}_y{Y}_w{W}_h{H}.png, SLICES.json
     and a numbered contact.png. Re-runs are idempotent and keep labels.
Byte-identical sheets slice once (first pack in sorted order); the other
paths land in duplicate_sheets. Every output stays untracked.

Usage:
  python3 tools/slice_atlases.py [--assets-root DIR] [--game-root DIR]
      [--only SUBSTRING] [--split <stem>:<x>,<y>,<w>,<h> ...] [--dry-run]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asset_candidates as ac  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = 1
MIN_AREA = 32      # px of alpha; the wired Rocks.png pebble is exactly 32
DARK = 48          # alpha-255 pixels with max(R,G,B) below this are outline
SEAM_FRAC = 0.9    # share of a piece's rows/cols a seam line must darken
FLANK_FRAC = 0.9   # the lines beside a seam must not be seam-dark themselves
                   # (a barrel's curved edge leaves its 2nd column ~75% dark)
SEAM_MAX_H = 64    # taller components are trees/structures: never seam-split
GRID_CLEAN = 0.8   # share of pieces that must sit alone in their cells
PACK_PREFIXES = ("Pixel Crawler",)
SKIP_DIRS = {"enemies", "social", "mockups", "weapons", "weapon", "tilesets", "stations"}
SKIP_NAME = re.compile(
    r"(-sheet\.png$|^shadows?\.png$|^shadown\.png$|^light\.png$|^tiles\.png$|^floor\.png$"
    r"|^walls?\.png$|^roofs?\.png$|^ground\.png$|^sand\.png$|^water\.png$|^interior_walls"
    r"|^wall_|^floors_|^water_|^dungeon_tiles)", re.I)
KINDS = ("crate", "barrel", "sack", "door", "window", "lamp", "table", "seat", "shelf", "bed",
         "plant", "rock", "debris", "tool", "sign", "wall_module", "container", "other")
LABEL_KEYS = ("targets", "verdict", "notes", "label_kind", "label_confidence")


# ------------------------------------------------------------- geometry

def components(alpha: bytes, w: int, h: int) -> tuple[list[int], list[list[int]]]:
    """8-connected components of alpha > 0. labels[y*w+x] is 0 or a 1-based
    id; boxes[id-1] = [x0, y0, x1, y1, area] with exclusive x1/y1."""
    labels = [0] * (w * h)
    boxes: list[list[int]] = []
    for start in range(w * h):
        if not alpha[start] or labels[start]:
            continue
        cid = len(boxes) + 1
        sx, sy = start % w, start // w
        box = [sx, sy, sx + 1, sy + 1, 0]
        labels[start] = cid
        todo = deque([start])
        while todo:
            i = todo.popleft()
            x, y = i % w, i // w
            if x < box[0]: box[0] = x
            if y < box[1]: box[1] = y
            if x + 1 > box[2]: box[2] = x + 1
            if y + 1 > box[3]: box[3] = y + 1
            box[4] += 1
            for ny in (y - 1, y, y + 1):
                if ny < 0 or ny >= h:
                    continue
                for nx in (x - 1, x, x + 1):
                    if nx < 0 or nx >= w:
                        continue
                    j = ny * w + nx
                    if alpha[j] and not labels[j]:
                        labels[j] = cid
                        todo.append(j)
        boxes.append(box)
    return labels, boxes


def _dark_profile(data: bytes, labels: list[int], cid: int, w: int, box: list[int],
                  axis: int) -> tuple[list[int], list[int]]:
    """Per column (axis 0) or row (axis 1) of box: how many of the piece's own
    pixels are present, and how many of those are outline-dark."""
    x0, y0, x1, y1 = box[:4]
    n = (x1 - x0) if axis == 0 else (y1 - y0)
    present, dark = [0] * n, [0] * n
    for y in range(y0, y1):
        for x in range(x0, x1):
            i = y * w + x
            if labels[i] != cid:
                continue
            k = (x - x0) if axis == 0 else (y - y0)
            present[k] += 1
            o = 4 * i
            if data[o + 3] == 255 and max(data[o], data[o + 1], data[o + 2]) < DARK:
                dark[k] += 1
    return present, dark


def seams(present: list[int], dark: list[int]) -> list[int]:
    """Offsets k such that a cut between k-1 and k separates a double outline:
    lines k-1 and k are dark over >= SEAM_FRAC of the piece and neither flank
    (k-2, k+1) is itself seam-dark, so a 3+ wide dark band never splits."""
    n = len(present)
    frac = [dark[k] / present[k] if present[k] else 0.0 for k in range(n)]
    out = []
    for k in range(1, n - 2):
        if (frac[k] >= SEAM_FRAC and frac[k + 1] >= SEAM_FRAC and present[k] >= 8
                and frac[k - 1] < FLANK_FRAC and frac[k + 2] < FLANK_FRAC):
            out.append(k + 1)
    return out


def trim(labels: list[int], cid: int, w: int, x0: int, y0: int, x1: int, y1: int) -> list[int]:
    bx0, by0, bx1, by1, area = x1, y1, x0, y0, 0
    for y in range(y0, y1):
        row = y * w
        for x in range(x0, x1):
            if labels[row + x] == cid:
                area += 1
                if x < bx0: bx0 = x
                if y < by0: by0 = y
                if x + 1 > bx1: bx1 = x + 1
                if y + 1 > by1: by1 = y + 1
    return [bx0, by0, bx1, by1, area]


def split_box(data: bytes, labels: list[int], cid: int, w: int,
              box: list[int]) -> list[tuple[list[int], str]]:
    cuts_x: list[int] = []
    cuts_y: list[int] = []
    if box[3] - box[1] <= SEAM_MAX_H:
        cuts_x = [box[0] + k for k in seams(*_dark_profile(data, labels, cid, w, box, 0))]
        cuts_y = [box[1] + k for k in seams(*_dark_profile(data, labels, cid, w, box, 1))]
    xs = [box[0]] + cuts_x + [box[2]]
    ys = [box[1]] + cuts_y + [box[3]]
    method = "seam" if cuts_x or cuts_y else "component"
    out = []
    for yi in range(len(ys) - 1):
        for xi in range(len(xs) - 1):
            t = trim(labels, cid, w, xs[xi], ys[yi], xs[xi + 1], ys[yi + 1])
            if t[4] >= MIN_AREA:
                out.append((t, method))
    return out


def cell_box(box: list[int], cell: int) -> list[int]:
    return [box[0] // cell * cell, box[1] // cell * cell,
            -(-box[2] // cell) * cell, -(-box[3] // cell) * cell]


def intersects(a: list[int], b: list[int]) -> bool:
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def sheet_grid(w: int, h: int, boxes: list[list[int]]) -> int | None:
    for cell in (16, 32):
        if w % cell or h % cell or not boxes:
            continue
        clean = sum(1 for b in boxes
                    if not any(o is not b and intersects(cell_box(b, cell), o) for o in boxes))
        if clean / len(boxes) >= GRID_CLEAN:
            return cell
    return None


def size_class(w: int, h: int) -> str:
    m = max(w, h)
    return "S" if m <= 16 else "M" if m <= 32 else "L" if m <= 64 else "XL"


def has_shadow(crop: Image.Image) -> bool:
    return any(0 < a < 255 for a in crop.getchannel("A").tobytes())


def _inter(a: list[int], b: list[int]) -> int:
    ix = max(0, min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0]))
    iy = max(0, min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1]))
    return ix * iy


def overlap_ratio(a: list[int], b: list[int]) -> float:
    """intersection / min(area) over [x, y, w, h] boxes: 1.0 on containment."""
    inter = _inter(a, b)
    return inter / min(a[2] * a[3], b[2] * b[3]) if inter else 0.0


def iou(a: list[int], b: list[int]) -> float:
    inter = _inter(a, b)
    return inter / (a[2] * a[3] + b[2] * b[3] - inter) if inter else 0.0
