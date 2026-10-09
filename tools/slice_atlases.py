#!/usr/bin/env python3
"""Slice static multi-sprite pack atlases into individual candidate sprites.

Spec: docs/superpowers/specs/2026-10-08-regional-kits-design.md section 4.1.
Row contract: docs/superpowers/plans/2026-10-08-regional-kits-phase0.md C8.

Every PNG of a Pixel Crawler or goblin-camp pack (PACK_PREFIXES) is decided
by its content, never its name (#624: name skips hid Forge/Hideout/Library
Tiles.png, Light.png and the furnace Bricks sheets). Path skips remain only
for what is not environment art: Social/ and MockUps/ promo renders and
source-reference renders, Weapons/ held-weapon sheets, and frame-regular
`-Sheet` animation strips under Entities/Enemies/Characters. A frames/ PNG
equal to a grid cell of a larger sheet is that atlas's frame export.
A sheet without one alpha-255 pixel in OPAQUE_MIN is a translucent overlay
(shadows, smoke). The rest get a layout from their 16px cell census:

  tile block  a component with >= BLOCK_CELLS fully opaque 16px cells whose
              boundary lies >= BLOCK_ALIGN on 16px cell edges, on a sheet
              where >= SHEET_FULL of the non-empty cells are fully opaque.
              Once a sheet has one, smaller grid blocks (>= PART_CELLS cells,
              >= PART_ALIGN aligned) join its tile part.
  props       no tile block: slice every island (the pre-#624 behaviour,
              byte-identical output for every sheet sliced before it);
  tileset     tile blocks and no other island: nothing is sliced;
  mixed       both: slice the islands, record the blocks as tile_regions.

Measured over every Pixel Crawler sheet on 2026-10-09 (`--measure` prints
the census): the tile blocks of Tiles/Walls/Ground/Water sheets hold 34-339
full cells at 48-100% alignment, on sheets with 31-100% full cells. Tree
canopies hold up to 52 full cells at 15-33% alignment. The one prop atlas
with a grid-aligned block (Interior_Props_01: 45 cells, 54%) has only 17%
full cells, which SHEET_FULL keeps out.

For each props/mixed sheet:
  1. find 8-connected alpha components (area >= MIN_AREA);
  2. split components on DOUBLE outline seams. #398: two flush crates and a
     barrel are ONE alpha component; the seam is two adjacent near-black
     columns (each sprite's own outline) whose flanks are not seam-dark. A
     single dark column is a shared edge and a dark mass is a sprite, never
     a seam; components taller than SEAM_MAX_H (trees) are never split;
  3. expand to the 16/32 px cell when the sheet is grid-laid and the cell
     holds no other piece or tile-block pixel (method grid16/grid32); else
     keep the trimmed box (component/seam). Manual --split regions are
     method override;
  4. write _sliced/<pack>/<stem>/<stem>__x{X}_y{Y}_w{W}_h{H}.png, SLICES.json
     and a numbered contact.png. Re-runs are idempotent and keep labels.
Per pack, _sliced/<pack>/TILESETS.json lists every tileset and mixed sheet
plus every sheet with tileset directory or name evidence
(asset_candidates.tileset_evidence), and _sliced/<pack>/SKIPPED.json lists
every PNG not sliced with its reason. Byte-identical sheets slice once (first
pack in sorted order); the other paths land in duplicate_sheets. Every output
stays untracked.

Usage:
  python3 tools/slice_atlases.py [--assets-root DIR] [--game-root DIR]
      [--only SUBSTRING] [--split <stem>:<x>,<y>,<w>,<h> ...] [--dry-run]
      [--measure]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import deque
from pathlib import Path
from typing import NamedTuple

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
CELL = 16          # census cell: the PC16 tile unit
OPAQUE_MIN = 0.01  # alpha-255 share below this is a translucent overlay (Shadows 0%)
SHEET_FULL = 0.25  # tile part needs this share of non-empty cells fully opaque
BLOCK_CELLS = 32   # a tile block holds this many fully opaque cells...
BLOCK_ALIGN = 0.35  # ...with this share of its boundary on cell edges
PART_CELLS = 8     # once a sheet has a block, smaller grid blocks join the
PART_ALIGN = 0.5   # tile part at these looser limits
# The PC16 packs plus the CUSTOM-HD goblin-camp environment packs. Other
# families are registered by folder evidence (asset_candidates) or ruled in
# docs/asset-coverage-exclusions.json.
PACK_PREFIXES = ("Pixel Crawler", "goblin-huts-pack", "goblin_watchtower")
PROMO_DIRS = {"social", "mockups"}
PROMO_WORDS = {"reference", "mockup", "preview", "thumbnail", "cover"}
WEAPON_DIRS = {"weapons", "weapon"}
ENTITY_DIRS = {"entities", "enemies", "enemy", "characters", "mobs", "npc's", "npcs"}
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


# ------------------------------------------------------------- layout

def cell_census(alpha: bytes, labels: list[int], w: int, h: int) -> tuple[int, int, dict[int, int]]:
    """(non-empty CELL cells, fully opaque cells, component id -> its full
    cells). A full cell is 8-connected, so it always belongs to one component."""
    full_row = b"\xff" * CELL
    empty_row = bytes(CELL)
    nonempty = full = 0
    per: dict[int, int] = {}
    for cy in range(0, h, CELL):
        for cx in range(0, w, CELL):
            cw, ch = min(CELL, w - cx), min(CELL, h - cy)
            rows = [alpha[(cy + y) * w + cx:(cy + y) * w + cx + cw] for y in range(ch)]
            if all(r == empty_row[:cw] for r in rows):
                continue
            nonempty += 1
            if cw == ch == CELL and all(r == full_row for r in rows):
                full += 1
                cid = labels[cy * w + cx]
                per[cid] = per.get(cid, 0) + 1
    return nonempty, full, per


def edge_alignment(labels: list[int], cid: int, w: int, h: int, box: list[int]) -> float:
    """Share of the component's boundary pixels (a 4-neighbour outside it)
    that sit on a CELL edge: ~0.25 by chance for an organic outline, near 1.0
    for tiles laid on the grid."""
    on = bnd = 0
    last = CELL - 1
    for y in range(box[1], box[3]):
        row = y * w
        for x in range(box[0], box[2]):
            if labels[row + x] != cid:
                continue
            if (x == 0 or y == 0 or x == w - 1 or y == h - 1 or labels[row + x - 1] != cid
                    or labels[row + x + 1] != cid or labels[row - w + x] != cid
                    or labels[row + w + x] != cid):
                bnd += 1
                if x % CELL in (0, last) or y % CELL in (0, last):
                    on += 1
    return on / bnd if bnd else 0.0


def sheet_layout(alpha: bytes, labels: list[int], boxes: list[list[int]], w: int,
                 h: int) -> tuple[str, set[int], dict]:
    """(props | tileset | mixed, tile-block component ids, census metrics)."""
    nonempty, full, per = cell_census(alpha, labels, w, h)
    share = full / nonempty if nonempty else 0.0
    islands = [cid for cid, b in enumerate(boxes, 1) if b[4] >= MIN_AREA]
    align: dict[int, float] = {}

    def aligned(cid: int, cells: int, limit: float) -> bool:
        if per.get(cid, 0) < cells:
            return False
        if cid not in align:
            align[cid] = edge_alignment(labels, cid, w, h, boxes[cid - 1])
        return align[cid] >= limit

    blocks: set[int] = set()
    if share >= SHEET_FULL:
        blocks = {cid for cid in islands if aligned(cid, BLOCK_CELLS, BLOCK_ALIGN)}
        if blocks:
            blocks |= {cid for cid in islands if aligned(cid, PART_CELLS, PART_ALIGN)}
    rest = len(islands) - len(blocks)
    layout = "props" if not blocks else "mixed" if rest else "tileset"
    metrics = {"full_share": round(share, 3), "full_cells": full, "nonempty_cells": nonempty,
               "islands": len(islands), "blocks": len(blocks),
               "block_cells": sorted((per.get(c, 0) for c in blocks), reverse=True),
               "max_align": round(max(align.values()), 2) if align else 0.0}
    return layout, blocks, metrics


# ------------------------------------------------------------- lookups

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


SKIP_REASONS = {
    "promo_render": "promo or reference render (Social/, MockUps/, source-reference.png)",
    "frame_export": "per-frame export of an atlas cell; counted through the atlas SLICES.json",
    "weapon_sheet": "Weapons/ held-weapon sheet for character rigs",
    "animation_strip": "frame-regular -Sheet animation strip under Entities/Enemies/Characters",
    "duplicate": "byte-identical duplicate of another sheet",
    "empty": "no visible pixel",
    "translucent_overlay": "under OPAQUE_MIN alpha-255 pixels: a shadow or smoke overlay",
    "flat_overlay": "every visible pixel one colour: a shadow silhouette overlay",
    "tileset": "dense 16px tile grid with no islands: registered as kind tileset (TILESETS.json)",
    "no_islands": f"no island of {MIN_AREA}+ px to slice",
}


def _pa(rel: Path) -> str:
    return (Path("potential_assets") / rel).as_posix()


def in_scope(rel: Path) -> bool:
    return (bool(rel.parts) and rel.parts[0].startswith(PACK_PREFIXES) and "_sliced" not in rel.parts
            and rel.suffix.lower() == ".png")


def path_skip(rel: Path) -> str:
    """SKIP_REASONS key for a PNG that is not environment art by its folder
    (or, for reference renders, its file name: an opaque concept render reads
    as one tile block), or ''."""
    dirs = {p.lower() for p in rel.parts[1:-1]}
    stem_words = set(re.split(r"[^a-z0-9]+", Path(rel.name).stem.lower()))
    if dirs & PROMO_DIRS or stem_words & PROMO_WORDS:
        return "promo_render"
    if dirs & WEAPON_DIRS:
        return "weapon_sheet"
    return ""


def animation_strip(rel: Path, size: tuple[int, int] | None = None) -> bool:
    """A `-Sheet` PNG under an entity folder whose frames tile it: one side
    divides the other, or both sit on the 16px frame grid (Orc Death 576x80
    is nine 64x80 frames). Station and prop `-Sheet` strips are environment
    art and go through content classification."""
    if not rel.name.lower().endswith("-sheet.png") or not {p.lower() for p in rel.parts[1:-1]} & ENTITY_DIRS:
        return False
    if size is None:
        return True
    w, h = size
    return w > 0 and h > 0 and (w % h == 0 or h % w == 0 or (w % CELL == 0 and h % CELL == 0))


def eligible(rel: Path, size: tuple[int, int] | None = None) -> bool:
    """A Pixel Crawler PNG whose fate its content decides."""
    return in_scope(rel) and not path_skip(rel) and not animation_strip(rel, size)


GENERIC_DIRS = {"static", "assets", "props", "interior", "buildings", "environment", "structures", "frames"}


def sheet_stem(sheet: Path) -> str:
    """The _sliced/<stem> name. Trees/Model_01/Size_02.png and
    Trees/Model_02/Size_02.png share a stem in one pack, so a non-generic
    parent folder is prefixed: Model_01_Size_02."""
    parent = sheet.parent.name
    return sheet.stem if parent.lower() in GENERIC_DIRS else f"{parent}_{sheet.stem}"


def _cell_match(atlas: Path, frame: Path, fsize: tuple[int, int]) -> list[int] | None:
    """[x, y, w, h] of the atlas grid cell whose pixels equal the frame's."""
    want = Image.open(frame).convert("RGBA").tobytes()
    im = Image.open(atlas).convert("RGBA")
    fw, fh = fsize
    for y in range(0, im.size[1], fh):
        for x in range(0, im.size[0], fw):
            if im.crop((x, y, x + fw, y + fh)).tobytes() == want:
                return [x, y, fw, fh]
    return None


def frame_exports(assets_root: Path, sheets: dict[Path, list[str]]) -> dict[Path, dict[str, list[int]]]:
    """atlas -> {frame path: cell} for every PNG under a frames/ folder whose
    pixels equal one grid cell of a larger sheet in the same pack (the
    CUSTOM-HD packs ship frames/hut_01.png beside the hut atlas). Such a frame
    is not sliced again: it counts through its atlas. Its byte-identical
    copies map to the same cell."""
    sizes = {p: ac.png_size(p) for p in sheets}
    out: dict[Path, dict[str, list[int]]] = {}
    for f in sorted(sheets):
        rel = f.relative_to(assets_root)
        fs = sizes[f]
        if "frames" not in {p.lower() for p in rel.parts[1:-1]} or not fs:
            continue
        for a in sorted(sheets):
            asz = sizes[a]
            if (a == f or a not in sheets or not asz or a.relative_to(assets_root).parts[0] != rel.parts[0]
                    or asz == fs or asz[0] % fs[0] or asz[1] % fs[1]):
                continue
            cell = _cell_match(a, f, fs)
            if cell:
                out.setdefault(a, {}).update({p: cell for p in [_pa(rel), *sheets[f]]})
                break
    return out


def scan(assets_root: Path, only: str = "") -> tuple[list[tuple[Path, list[str]]], list[dict],
                                                     dict[Path, dict[str, list[int]]]]:
    """(sheets, skipped, frame exports). Sheets: one entry per unique sha256
    among the eligible PNGs; the shortest file name, then the first path in
    part order, wins (Size_03.png over Size_03-export.png, Free Pack over
    Free Pack 2.1), and the other paths are its duplicates. Skipped: a
    SKIPPED.json row for every path skip, duplicate and frame export."""
    files = [p for top in sorted(assets_root.iterdir()) if top.is_dir() and top.name.startswith(PACK_PREFIXES)
             for p in top.rglob("*") if p.suffix.lower() == ".png" and p.is_file()]
    by_sha: dict[str, tuple[Path, list[str]]] = {}
    skipped: list[dict] = []
    for p in sorted(files, key=lambda p: (len(p.name), p.parts)):
        rel = p.relative_to(assets_root)
        if not in_scope(rel) or (only and only not in str(rel)):
            continue
        reason = path_skip(rel) or ("animation_strip" if animation_strip(rel, ac.png_size(p)) else "")
        if reason:
            skipped.append({"path": _pa(rel), "reason": reason})
            continue
        h = sha256(p)
        if h in by_sha:
            by_sha[h][1].append(_pa(rel))
            skipped.append({"path": _pa(rel), "reason": "duplicate",
                            "detail": _pa(by_sha[h][0].relative_to(assets_root))})
        else:
            by_sha[h] = (p, [])
    sheets = dict(by_sha.values())
    exports = frame_exports(assets_root, sheets)
    for atlas, frames in exports.items():
        for path in frames:
            src = assets_root / Path(path).relative_to("potential_assets")
            sheets.pop(src, None)
            skipped[:] = [s for s in skipped if s["path"] != path]
            skipped.append({"path": path, "reason": "frame_export",
                            "detail": _pa(atlas.relative_to(assets_root))})
    return sorted(sheets.items(), key=lambda e: str(e[0])), skipped, exports


def find_sheets(assets_root: Path, only: str = "") -> list[tuple[Path, list[str]]]:
    return scan(assets_root, only)[0]


def bundled_index(game_root: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    assets = game_root / "assets"
    if not assets.is_dir():
        return out
    for p in sorted(assets.rglob("*.png")):
        out.setdefault(sha256(p), "res://" + p.relative_to(game_root).as_posix())
    return out


def wired_regions(game_root: Path) -> dict[str, list[tuple[str, list[int]]]]:
    path = game_root / "data" / "sprites.json"
    if not path.exists():
        return {}
    out: dict[str, list[tuple[str, list[int]]]] = {}
    for sid, rec in json.loads(path.read_text(encoding="utf-8")).items():
        if sid.startswith("_") or not isinstance(rec, dict):
            continue
        for anim in (rec.get("animations") or {}).values():
            if isinstance(anim, dict) and anim.get("region") and isinstance(anim.get("sheet"), str):
                out.setdefault(anim["sheet"], []).append((sid, [int(v) for v in anim["region"]]))
    return out


# ------------------------------------------------------------- slicing

def _xywh(box: list[int]) -> list[int]:
    return [box[0], box[1], box[2] - box[0], box[3] - box[1]]


def out_dir_for(sheet: Path, assets_root: Path, sha: str) -> Path:
    stem = sheet_stem(sheet)
    base = assets_root / "_sliced" / sheet.relative_to(assets_root).parts[0] / stem
    existing = base / "SLICES.json"
    if existing.exists():
        try:
            if json.loads(existing.read_text(encoding="utf-8")).get("sheet_sha256") != sha:
                return base.with_name(f"{stem}-{sha[:8]}")
        except (json.JSONDecodeError, OSError):
            pass
    return base


def _carry_labels(out_dir: Path) -> tuple[dict[tuple, dict], list[list[int]]]:
    """Labels and overrides from a previous run, keyed by (sha, region)."""
    sj = out_dir / "SLICES.json"
    if not sj.exists():
        return {}, []
    try:
        old = json.loads(sj.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}, []
    keep = {(r.get("sheet_sha256"), tuple(r.get("region", []))): {k: r[k] for k in LABEL_KEYS if k in r}
            for r in old.get("assets", [])}
    return keep, [list(o) for o in old.get("overrides", [])]


class Analysis(NamedTuple):
    im: Image.Image
    data: bytes
    labels: list[int]
    boxes: list[list[int]]
    layout: str
    blocks: set[int]
    metrics: dict


def analyze(sheet: Path) -> Analysis:
    im = Image.open(sheet).convert("RGBA")
    w, h = im.size
    data = im.tobytes()
    alpha = data[3::4]
    labels, boxes = components(alpha, w, h)
    layout, blocks, metrics = sheet_layout(alpha, labels, boxes, w, h)
    return Analysis(im, data, labels, boxes, layout, blocks, metrics)


def opaque_skip(im: Image.Image) -> str:
    """SKIP_REASONS key for an empty, translucent or single-colour sheet, or ''."""
    alpha = im.getchannel("A").tobytes()
    visible = len(alpha) - alpha.count(0)
    if not visible:
        return "empty"
    if alpha.count(255) < OPAQUE_MIN * visible:
        return "translucent_overlay"
    colors = im.getcolors(4)
    if colors is not None and len([c for _, c in colors if c[3]]) == 1:
        return "flat_overlay"
    return ""


def _holds_block(labels: list[int], blocks: set[int], w: int, box: list[int]) -> bool:
    if not blocks:
        return False
    for y in range(box[1], box[3]):
        row = y * w
        if any(labels[row + x] in blocks for x in range(box[0], box[2])):
            return True
    return False


def slice_sheet(sheet: Path, assets_root: Path, out_dir: Path, overrides: list[list[int]],
                bundled: dict[str, str], wired: dict, duplicates: list[str],
                analysis: Analysis | None = None,
                exports: dict[str, list[int]] | None = None) -> tuple[dict, list[Image.Image]]:
    """C8 rows for every island outside the tile blocks. A props sheet has
    no blocks, so its rows and doc keys are exactly the pre-#624 output."""
    a = analysis or analyze(sheet)
    im, data, labels, boxes = a.im, a.data, a.labels, a.boxes
    w, h = im.size
    pieces: list[tuple[list[int], str]] = []
    for cid, box in enumerate(boxes, 1):
        if box[4] >= MIN_AREA and cid not in a.blocks:
            pieces += split_box(data, labels, cid, w, box)
    carried, old_overrides = _carry_labels(out_dir)
    overrides = [list(o) for o in dict.fromkeys(tuple(o) for o in old_overrides + overrides)]
    for ov in overrides:
        pieces = [p for p in pieces if overlap_ratio(_xywh(p[0]), ov) < 0.5]
        pieces.append(([ov[0], ov[1], ov[0] + ov[2], ov[1] + ov[3], ov[2] * ov[3]], "override"))
    cell = sheet_grid(w, h, [p[0] for p in pieces])
    sha = sha256(sheet)
    rel = sheet.relative_to(assets_root)
    game_sheet = bundled.get(sha, "")
    wired_here = wired.get(game_sheet, []) if game_sheet else []
    stem = sheet_stem(sheet)
    rows, crops = [], []
    for box, method in sorted(pieces, key=lambda p: (p[0][1], p[0][0])):
        x0, y0, x1, y1 = box[:4]
        if cell and method != "override":
            e = cell_box(box, cell)
            if (not any(o is not box and intersects(e, o) for o, _ in pieces)
                    and not _holds_block(labels, a.blocks, w, e)):
                x0, y0, x1, y1 = e
                method = f"grid{cell}"
        region = [x0, y0, x1 - x0, y1 - y0]
        crop = im.crop((x0, y0, x1, y1))
        wired_ids = [sid for sid, r in wired_here if overlap_ratio(region, r) >= 0.5]
        row = {
            "path": (Path("potential_assets") / out_dir.relative_to(assets_root)
                     / f"{stem}__x{x0}_y{y0}_w{region[2]}_h{region[3]}.png").as_posix(),
            "kind": "prop", "targets": list(wired_ids), "verdict": "UNREVIEWED", "notes": "",
            "source_sheet": (Path("potential_assets") / rel).as_posix(),
            "region": region, "sheet_sha256": sha, "method": method,
            "has_shadow": has_shadow(crop), "size_class": size_class(region[2], region[3]),
            "label_confidence": 0.0, "label_kind": "",
            "bundled": bool(game_sheet), "game_sheet": game_sheet,
            "wired_ids": wired_ids, "duplicate_sheets": list(duplicates),
        }
        row.update(carried.get((sha, tuple(region)), {}))
        rows.append(row)
        crops.append(crop)
    doc = {"schema": SCHEMA, "source": "pack", "tier": "pack-bundle",
           "family": ac.pack_family(rel.parts[0]),
           "sheet": (Path("potential_assets") / rel).as_posix(), "sheet_sha256": sha,
           "grid": cell}
    if a.blocks:
        # absent on props sheets, so their SLICES.json stays byte-identical
        doc["layout"] = "mixed" if rows else "tileset"
        doc["tile_regions"] = tile_regions(a)
    if exports:
        doc["frame_exports"] = dict(sorted(exports.items()))
    doc.update({"overrides": overrides, "check_notes": [], "assets": rows})
    return doc, crops


def tile_regions(a: Analysis) -> list[list[int]]:
    return sorted((_xywh(a.boxes[c - 1]) for c in a.blocks), key=lambda r: (r[1], r[0]))


def render_contact(crops: list[Image.Image], out: Path, scale: int, start: int = 1,
                   cols: int = 8, max_px: int = 96) -> None:
    """Numbered grid on mid-grey so dark outlines and pale shadows both read.
    Slices above max_px are shrunk to it first (trees); the number is the
    1-based index into the SLICES.json rows."""
    shown = []
    for c in crops:
        m = max(c.size)
        if m > max_px:
            c = c.resize((max(1, c.size[0] * max_px // m), max(1, c.size[1] * max_px // m)), Image.BOX)
        shown.append(c.resize((c.size[0] * scale, c.size[1] * scale), Image.NEAREST))
    cw = max((s.size[0] for s in shown), default=16) + 8
    ch = max((s.size[1] for s in shown), default=16) + 18
    rows = -(-len(shown) // cols) if shown else 1
    page = Image.new("RGBA", (cols * cw, rows * ch), (107, 107, 107, 255))
    draw = ImageDraw.Draw(page)
    for i, s in enumerate(shown):
        x, y = (i % cols) * cw, (i // cols) * ch
        page.alpha_composite(s, (x + 4, y + 14))
        label = str(start + i)
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            draw.text((x + 3 + dx, y + 1 + dy), label, fill=(0, 0, 0, 255))
        draw.text((x + 3, y + 1), label, fill=(255, 255, 0, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    page.save(out)


def write_outputs(doc: dict, crops: list[Image.Image], out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    keep = {Path(r["path"]).name for r in doc["assets"]}
    for stale in out_dir.glob("*.png"):
        if stale.name != "contact.png" and stale.name not in keep:
            stale.unlink()
    for row, crop in zip(doc["assets"], crops):
        crop.save(out_dir / Path(row["path"]).name)
    (out_dir / "SLICES.json").write_text(json.dumps(doc, indent=1) + "\n", encoding="utf-8")
    render_contact(crops, out_dir / "contact.png", scale=2)


def parse_split(spec: str) -> tuple[str, list[int]]:
    stem, _, nums = spec.partition(":")
    parts = [int(v) for v in nums.split(",")]
    if not stem or len(parts) != 4 or parts[2] <= 0 or parts[3] <= 0:
        raise argparse.ArgumentTypeError(f"--split wants <stem>:<x>,<y>,<w>,<h>, got {spec!r}")
    return stem, parts


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--assets-root", type=Path, default=ROOT / "potential_assets")
    ap.add_argument("--game-root", type=Path, default=ROOT / "wandering_inn_game")
    ap.add_argument("--only", default="", help="only sheets whose relative path contains this")
    ap.add_argument("--split", type=parse_split, action="append", default=[],
                    help="manual region <stem>:<x>,<y>,<w>,<h> where <stem> is the _sliced/ dir "
                         "name (Furniture, Model_01_Size_02); recorded as method override")
    ap.add_argument("--dry-run", action="store_true", help="classify and report; write nothing")
    ap.add_argument("--measure", action="store_true",
                    help="print each sheet's layout and cell census; write nothing")
    args = ap.parse_args(argv)
    assets_root = args.assets_root.resolve()
    if not assets_root.is_dir():
        print(f"no assets root at {assets_root}", file=sys.stderr)
        return 2
    splits: dict[str, list[list[int]]] = {}
    for stem, region in args.split:
        splits.setdefault(stem, []).append(region)
    bundled = bundled_index(args.game_root)
    wired = wired_regions(args.game_root)
    sheets, skipped, exports = scan(assets_root, args.only)
    dupes = sum(len(d) for _, d in sheets)
    tilesets: list[dict] = []
    total, n_sliced, methods = 0, 0, {}
    for sheet, duplicates in sheets:
        rel = sheet.relative_to(assets_root)
        a = analyze(sheet)
        skip = opaque_skip(a.im)
        if args.measure:
            print(f"{skip or a.layout:19s} {json.dumps(a.metrics)}  {rel}")
            continue
        if skip:
            skipped.append({"path": _pa(rel), "reason": skip})
            continue
        stem = sheet_stem(sheet)
        sha = sha256(sheet)
        out_dir = out_dir_for(sheet, assets_root, sha)
        doc, crops = (({"assets": []}, []) if a.layout == "tileset" and not splits.get(stem)
                      else slice_sheet(sheet, assets_root, out_dir, splits.get(stem, []), bundled, wired,
                                       duplicates, a, exports.get(sheet)))
        rows = doc["assets"]
        evidence = (["content"] if a.blocks else []) + (["directory"] if ac.tileset_evidence(rel) else [])
        if evidence:
            tilesets.append({
                "sheet": _pa(rel), "sheet_sha256": sha, "w": a.im.size[0], "h": a.im.size[1],
                "layout": doc.get("layout", a.layout if not rows else "props"), "evidence": evidence,
                "grid": CELL, "tile_regions": tile_regions(a), "slices": len(rows),
                "full_share": a.metrics["full_share"], "islands": a.metrics["islands"],
                "family": ac.pack_family(rel.parts[0]), "duplicate_sheets": list(duplicates)})
        if not rows:
            skipped.append({"path": _pa(rel), "reason": "tileset" if a.blocks else "no_islands"})
            print(f"   0 slices  {a.layout:8s} {rel}")
            continue
        n_sliced += 1
        total += len(rows)
        for r in rows:
            methods[r["method"]] = methods.get(r["method"], 0) + 1
        print(f"{len(rows):4d} slices  {doc.get('layout', 'props'):8s} grid={doc['grid']}  {rel}")
        if not args.dry_run:
            write_outputs(doc, crops, out_dir)
    if args.measure:
        return 0
    print(f"sliced {n_sliced} sheets ({dupes} duplicates skipped) -> {total} slices; "
          + ", ".join(f"{k} {v}" for k, v in sorted(methods.items())))
    reasons: dict[str, int] = {}
    for s in skipped:
        reasons[s["reason"]] = reasons.get(s["reason"], 0) + 1
    print(f"tilesets {len(tilesets)} ({sum(1 for t in tilesets if t['layout'] == 'mixed')} mixed); "
          f"skipped {len(skipped)}: " + ", ".join(f"{k} {v}" for k, v in sorted(reasons.items())))
    if not args.dry_run:
        write_pack_lists(assets_root, sheets, skipped, tilesets)
    return 0


def write_pack_lists(assets_root: Path, sheets: list[tuple[Path, list[str]]], skipped: list[dict],
                     tilesets: list[dict]) -> None:
    """_sliced/<pack>/SKIPPED.json and TILESETS.json. Rows for paths this run
    decided are replaced; rows for paths an --only run never saw are kept."""
    decided = {_pa(s.relative_to(assets_root)) for s, _ in sheets} | {s["path"] for s in skipped}
    packs = {Path(p).parts[1] for p in decided}
    for pack in sorted(packs):
        base = assets_root / "_sliced" / pack
        for name, key, ident, new in (("SKIPPED.json", "files", "path", skipped),
                                      ("TILESETS.json", "sheets", "sheet", tilesets)):
            path = base / name
            old = []
            if path.exists():
                try:
                    old = json.loads(path.read_text(encoding="utf-8")).get(key, [])
                except (json.JSONDecodeError, OSError):
                    old = []
            mine = [r for r in new if Path(r[ident]).parts[1] == pack]
            rows = sorted([r for r in old if r.get(ident) not in decided] + mine, key=lambda r: r[ident])
            if not rows and not path.exists():
                continue
            base.mkdir(parents=True, exist_ok=True)
            for r in rows:
                if key == "files":
                    r.setdefault("why", SKIP_REASONS.get(r["reason"], ""))
            path.write_text(json.dumps({"schema": SCHEMA, "pack": pack, key: rows}, indent=1) + "\n",
                            encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
