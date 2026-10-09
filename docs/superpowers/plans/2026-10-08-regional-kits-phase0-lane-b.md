# Regional Kits Phase 0 — Lane B (atlas slicing and labeling) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Slice every static multi-sprite Pixel Crawler prop atlas under untracked `potential_assets/` into individually indexed, vision-labeled candidate sprites that `tools/find_asset.py` returns and Lane C's `wire_asset` can consume (issue #607, Lane B).

**Architecture:** A new pure-PIL tool `tools/slice_atlases.py` finds 8-connected alpha components per sheet, splits fused components on double-outline seams (the #398 crate case), snaps clean components to the sheet's 16/32 px grid, and writes per-sheet `_sliced/<stem>/` PNGs plus a `SLICES.json` in the standard MANIFEST schema (contract C8) and a numbered `contact.png`. A second tool `tools/label_slices.py` exports paged numbered contact sheets for a controller-dispatched vision agent, imports its JSON answers into `SLICES.json`, and checks label agreement against the already-wired `data/sprites.json` regions. `tools/asset_candidates.py` learns to read `_sliced/` batches as tier `pack-bundle`, and `tools/asset_index.py` stops double-counting them.

**Tech Stack:** Python 3.12, Pillow only (CI installs `pytest Pillow`; no numpy/scipy), pytest in repo-root `scripts/tests/` (preflight runs `python3 -m pytest -q scripts/tests`).

**Spec:** `docs/superpowers/specs/2026-10-08-regional-kits-design.md` §4.1; contracts in `docs/superpowers/plans/2026-10-08-regional-kits-phase0.md` (C8 verbatim below).

## Global Constraints

- Branch `issue/607-lane-b` in worktree `/private/tmp/wi-607-b`, cut from `issue/607-kits-foundation` (itself from `main` at `7155db91`). At most two implementation workers run at once.
- Owned files only: NEW `tools/slice_atlases.py`, NEW `tools/label_slices.py`, MODIFY `tools/asset_candidates.py`, `tools/asset_index.py`, `tools/find_asset.py`; tests in repo-root `scripts/tests/`; regenerated `docs/asset-candidates.{json,md}` and `docs/asset-index.{json,md}` only in the final task.
- `potential_assets/` is gitignored and untracked; the worktree does not have it. Symlink it: `ln -s /Users/gabriel/wandering-inn-rpg/potential_assets /private/tmp/wi-607-b/potential_assets`. Never `git add` anything under it; `scripts/leak_check.sh` is authoritative.
- Never open pack PNGs into model context. Measure with PIL in Python; look only at the generated contact sheets, and only through the vision-labeling step.
- No player-visible change: no map JSON, `data/sprites.json`, `assets/` or `assets_manifest.json` edits in this lane.
- Comment ceilings: `python3 scripts/comment_census.py --check` must stay green; comments carry constraints and traps, not narrative.
- Evidence: preserve exit codes; never pipe a gate into `head`/`tail`.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

### Contract C8 (verbatim from the plan index)

- Each `_sliced/<sheet-stem>/SLICES.json` is `{"assets": [row, …]}`.
- A row: `{"path": "potential_assets/…/_sliced/<stem>/<stem>__x{X}_y{Y}_w{W}_h{H}.png", "kind": "prop", "targets": ["<kind-tag>", …], "verdict": "UNREVIEWED", "notes": "", "source_sheet": "potential_assets/…/<sheet>.png", "region": [X, Y, W, H], "sheet_sha256": "<hex>", "method": "grid16|grid32|seam|component|override", "has_shadow": false, "size_class": "S|M|L|XL", "label_confidence": 0.0}`
- Kind vocabulary (closed): `crate barrel sack door window lamp table seat shelf bed plant rock debris tool sign wall_module container other`.

Lane B adds (passthrough) keys beside the C8 ones: `label_kind`, `bundled`, `game_sheet`, `wired_ids`, `duplicate_sheets`. C8 keys are never renamed.

### Measured baseline (2026-10-08 PIL survey, main checkout)

| Rule | Effect |
|---|---|
| Packs: name starts with `Pixel Crawler` | 12 pack dirs, 191 non-strip non-enemy PNGs |
| Skip dirs `Enemies/ Social/ MockUps/ Weapons/ Weapon/ Tilesets/ TileSets/` (case-insensitive) | drops battlers, 4x promo renders, mockups, weapon sheets, terrain |
| Skip names `*-Sheet.png`, `Shadows.png/Shadown.png/Light.png`, `Tiles/Floor/Wall(s)/Roof(s)/Ground/Sand/Water.png`, `Interior_Walls*`, `Wall_*`, `Floors_*`, `Water_*`, `Dungeon_Tiles*` | leaves 85 files |
| Dedupe by sha256 (Free Pack == Free Pack 2.1; `Size_03-export.png` == `Size_03.png`) | 46 unique sheets, 1,203 alpha components ≥ 40 px² |
| Skip `Stations/` (Anvil/Bonfire/Furnace/Workbench/Cooking are stacked animation frames and structure variants, 13 unique sheets, ~100 components) | **33 unique sheets (29 duplicate files), 1,262 slices at the adopted MIN_AREA 32** (1,175 at 40; the brief's ~1,028 across 54 counted the Free Pack dupes). Running the extracted plan code end to end at MIN_AREA 32: component 285, grid16 868, seam 109, grid32 0; at 40 the size classes were S 506 / M 313 / L 168 / XL 188 with 35 baked shadows; 2 s for the whole pool |
| `MIN_AREA` | 40 → 1,175 slices but the wired `pebble` component is 32 px² and is lost; 32 → 1,262 (adopted); 24 → 1,364; 16 → 1,478 |
| grid16-clean share per sheet | ≥ 0.8 on 29/31 sheets (Furniture 62/72, Interior_Props 98/108, Fairy Props 82/84) |
| Double-outline seams (final rule: both lines ≥ 0.9 dark, flanks < 0.9, component height ≤ 64) | Furniture 18 cuts (the #398 trio splits exactly to `[720,73]`,`[736,73]`,`[752,74]`), Interior_Props 26, Graves 3, Fairy Props 0, Vegetation 0, Rocks 0; trees: Fairy `Tree.png` 4, Cemetery `Tree.png` 4 (1,235 / 166 with no flank guard; 30 / 8 with the flank guard but no height guard; a 0.5 flank threshold leaves the crate and barrel fused because the barrel's curved edge makes its second column 75% dark) |
| Semi-transparent pixels (baked shadow) | Desert Props 15/21, Sewer Props 11/56, Fairy Props 5/84; `Shadows.png` sheets are generic shadow blobs (Free Pack `Static/Shadows.png` is byte-identical to Cemetery `Props/Shadows.png`), not per-prop overlays |
| Bundled sheets (sha256 match under `wandering_inn_game/assets/`) | 15 of the 33 in-scope sheets |
| Wired regions on in-scope sheets | 44 of the 58 `region` animations (14 are on tiles sheets, `-Sheet.png` strips, Admurin or owned sheets, and `Building_Walls/Roofs`); raw components match only 22/44 at IoU ≥ 0.5, so the check uses containment (`overlap/min(area) ≥ 0.5`, ties by IoU) with seam-split and grid-expanded regions; the extracted plan code covers 43/44 at MIN_AREA 40 (pebble missing) and 44/44 at 32 |

## Review Focus

1. **A fused component whose seam is a single dark column** (one shared outline, not two): the splitter must leave it whole rather than cut one sprite's outline off. Pinned in Task 1 `test_single_dark_column_is_not_a_seam`.
2. **Re-running after labels landed**: a second `slice_atlases.py` run must not wipe `label_kind`/`targets`/`verdict`/`notes`, and a changed `--split` must drop orphan PNGs. Pinned in Task 3 `test_rerun_preserves_labels_and_removes_orphans`.
3. **Two sheets with the same stem in one pack with different content**: the second must not overwrite the first's `_sliced/<stem>/`. Pinned in Task 3 `test_stem_collision_gets_sha_suffix`.
4. **Vision answers with an unknown kind or a number outside the page**: `import` must refuse the whole answer file with a clear line and exit 2, never write a partial label. Pinned in Task 5 `test_import_rejects_bad_kind_and_bad_number`.
5. **A wired region on a sheet that was not sliced** (tiles sheets, strips): `check` must exclude it from the denominator and list it, not count it as a miss or crash. Pinned in Task 6 `test_check_excludes_unsliced_sheets`.

---

### Task 1: `tools/slice_atlases.py` core geometry (components, seams, grid, size, shadow)

**Files:**
- Create: `tools/slice_atlases.py`
- Test: `scripts/tests/test_slice_atlases.py`

**Interfaces:**
- Produces (used by Tasks 2, 3, 5, 6):
  - `components(alpha: bytes, w: int, h: int) -> tuple[list[int], list[list[int]]]` — `labels[y*w+x]` is 0 or a 1-based id; `boxes[id-1] = [x0, y0, x1, y1, area]` (x1/y1 exclusive).
  - `split_box(data: bytes, labels: list[int], cid: int, w: int, box: list[int]) -> list[tuple[list[int], str]]` — pieces `([x0,y0,x1,y1,area], "component"|"seam")`.
  - `seams(present: list[int], dark: list[int]) -> list[int]` — offsets k where a cut goes between k-1 and k.
  - `cell_box(box, cell) -> list[int]`, `intersects(a, b) -> bool`, `sheet_grid(w, h, boxes) -> int | None`.
  - `size_class(w: int, h: int) -> str`, `has_shadow(crop: Image.Image) -> bool`, `overlap_ratio(a, b) -> float` and `iou(a, b) -> float` (both over `[x, y, w, h]`).
  - Constants `KINDS`, `MIN_AREA = 32`, `DARK = 48`, `SEAM_FRAC = 0.9`, `FLANK_FRAC = 0.9`, `SEAM_MAX_H = 64`, `GRID_CLEAN = 0.8`.

- [ ] **Step 1: Write the failing tests**

Create `scripts/tests/test_slice_atlases.py`:

```python
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /private/tmp/wi-607-b && python3 -m pytest -q scripts/tests/test_slice_atlases.py`
Expected: `ModuleNotFoundError: No module named 'slice_atlases'` (collection error, exit 2).

- [ ] **Step 3: Write the core module**

Create `tools/slice_atlases.py`:

```python
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /private/tmp/wi-607-b && python3 -m pytest -q scripts/tests/test_slice_atlases.py`
Expected: `8 passed`.

- [ ] **Step 5: Commit**

```bash
cd /private/tmp/wi-607-b
git add tools/slice_atlases.py scripts/tests/test_slice_atlases.py
git commit -m "slice_atlases: component, double-outline seam and grid geometry (#607)

Pure-PIL 8-connected components, the #398 double-outline seam split with a
light-flank guard (dark trunks are not seams), 16/32 cell snapping, size
class, baked-shadow and containment-overlap helpers.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: sheet selection, dedupe, bundled and wired lookups

**Files:**
- Modify: `tools/slice_atlases.py` (append after `overlap_ratio`)
- Test: `scripts/tests/test_slice_atlases.py` (append)

**Interfaces:**
- Produces:
  - `eligible(rel: Path) -> bool` — `rel` is relative to the assets root.
  - `sha256(path: Path) -> str`.
  - `find_sheets(assets_root: Path, only: str = "") -> list[tuple[Path, list[str]]]` — `(sheet, duplicate_rel_paths)` one per unique sha, sorted by relative path; the primary is the shortest file name then first in part order; duplicates are the other relative paths (as posix strings prefixed `potential_assets/`).
  - `sheet_stem(sheet: Path) -> str` — the `_sliced/<stem>` name; `GENERIC_DIRS` parents keep the bare stem, others are prefixed (`Model_01_Size_02`).
  - `bundled_index(game_root: Path) -> dict[str, str]` — sha256 → `res://assets/...`.
  - `wired_regions(game_root: Path) -> dict[str, list[tuple[str, list[int]]]]` — `res://` sheet → `[(sprite_id, [x, y, w, h]), …]`.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/tests/test_slice_atlases.py`:

```python
def sprite_sheet(path: Path, boxes, size=(64, 32)) -> Image.Image:
    path.parent.mkdir(parents=True, exist_ok=True)
    im = Image.new("RGBA", size, CLEAR)
    for x, y, w, h in boxes:
        outlined_box(im, x, y, w, h)
    im.save(path)
    return im


def test_eligible_rules():
    ok = ["Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png",
          "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png",
          "Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png"]
    bad = ["Admurins_Freebies-2/x/Props.png",
           "Pixel Crawler - Cave/Pixel Crawler - Cave/Enemies/Fungus/Idle-Sheet.png",
           "Pixel Crawler - Cave/Pixel Crawler - Cave/Social/Props.png",
           "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png",
           "Pixel Crawler - Free Pack/Environment/Tilesets/Floors_Tiles.png",
           "Pixel Crawler - Free Pack/Environment/Props/Static/Shadows.png",
           "Pixel Crawler - Free Pack/Environment/Structures/Stations/Anvil/Anvil.png",
           "Pixel Crawler - Free Pack/Environment/Props/Static/Bonfire_01-Sheet.png",
           "Pixel Crawler - Free Pack/_sliced/Furniture/Furniture__x0_y0_w16_h16.png",
           "Pixel Crawler - Free Pack/MockUps/Tavern_01.png"]
    assert [sa.eligible(Path(p)) for p in ok] == [True] * 3
    assert [sa.eligible(Path(p)) for p in bad] == [False] * len(bad)


def test_find_sheets_dedupes_by_sha_and_records_duplicates(tmp_path):
    assets = tmp_path / "potential_assets"
    a = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    b = assets / "Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    c = assets / "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png"
    sprite_sheet(a, [(0, 0, 16, 16)])
    b.parent.mkdir(parents=True)
    b.write_bytes(a.read_bytes())
    sprite_sheet(c, [(0, 0, 16, 16), (32, 0, 16, 16)])
    trees = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03"
    sprite_sheet(trees / "Size_03-export.png", [(0, 0, 16, 16), (16, 0, 16, 16)])
    (trees / "Size_03.png").write_bytes((trees / "Size_03-export.png").read_bytes())
    found = sa.find_sheets(assets)
    assert [s.relative_to(assets).parts[0] for s, _ in found] == [
        "Pixel Crawler - Cave", "Pixel Crawler - Free Pack", "Pixel Crawler - Free Pack"]
    assert found[1][1] == ["potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"]
    assert found[0][1] == []
    assert found[2][0].name == "Size_03.png", "the shorter twin is primary"
    assert found[2][1] == ["potential_assets/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_03-export.png"]
    assert [s.name for s, _ in sa.find_sheets(assets, only="Cave")] == ["Props.png"]


def test_sheet_stem_prefixes_non_generic_parent():
    assert sa.sheet_stem(Path("P/Environment/Props/Static/Furniture.png")) == "Furniture"
    assert sa.sheet_stem(Path("P/Assets/Props.png")) == "Props"
    assert sa.sheet_stem(Path("P/Environment/Structures/Buildings/Props.png")) == "Props"
    assert sa.sheet_stem(Path("P/Environment/Props/Static/Trees/Model_01/Size_02.png")) == "Model_01_Size_02"


def test_bundled_index_and_wired_regions(tmp_path):
    game = tmp_path / "wandering_inn_game"
    sheet = game / "assets/props/free_pack/Furniture.png"
    sprite_sheet(sheet, [(0, 0, 16, 16)])
    (game / "data").mkdir()
    (game / "data/sprites.json").write_text(json.dumps({
        "_comment": "x",
        "crate": {"animations": {"idle": {"sheet": "res://assets/props/free_pack/Furniture.png",
                                          "region": [0, 0, 16, 16]}}},
        "walker": {"animations": {"idle": {"sheet": "res://assets/sprites/w/Idle-Sheet.png"}}}}))
    idx = sa.bundled_index(game)
    assert idx == {sa.sha256(sheet): "res://assets/props/free_pack/Furniture.png"}
    assert sa.wired_regions(game) == {"res://assets/props/free_pack/Furniture.png": [("crate", [0, 0, 16, 16])]}
    assert sa.wired_regions(tmp_path / "nowhere") == {}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /private/tmp/wi-607-b && python3 -m pytest -q scripts/tests/test_slice_atlases.py`
Expected: `4 failed, 8 passed` with `AttributeError: module 'slice_atlases' has no attribute 'eligible'` (and `find_sheets`, `sheet_stem`, `bundled_index`).

- [ ] **Step 3: Append the lookups**

Append to `tools/slice_atlases.py`:

```python
# ------------------------------------------------------------- lookups

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def eligible(rel: Path) -> bool:
    if not rel.parts or not rel.parts[0].startswith(PACK_PREFIXES):
        return False
    if "_sliced" in rel.parts or {p.lower() for p in rel.parts[1:-1]} & SKIP_DIRS:
        return False
    return rel.suffix.lower() == ".png" and not SKIP_NAME.search(rel.name)


GENERIC_DIRS = {"static", "assets", "props", "interior", "buildings", "environment", "structures"}


def sheet_stem(sheet: Path) -> str:
    """The _sliced/<stem> name. Trees/Model_01/Size_02.png and
    Trees/Model_02/Size_02.png share a stem in one pack, so a non-generic
    parent folder is prefixed: Model_01_Size_02."""
    parent = sheet.parent.name
    return sheet.stem if parent.lower() in GENERIC_DIRS else f"{parent}_{sheet.stem}"


def find_sheets(assets_root: Path, only: str = "") -> list[tuple[Path, list[str]]]:
    """One entry per unique sha256; the shortest file name, then the first
    path in part order, wins (Size_03.png over Size_03-export.png, Free Pack
    over Free Pack 2.1). The other paths are returned as duplicates."""
    by_sha: dict[str, tuple[Path, list[str]]] = {}
    for p in sorted(assets_root.rglob("*.png"), key=lambda p: (len(p.name), p.parts)):
        rel = p.relative_to(assets_root)
        if not eligible(rel) or (only and only not in str(rel)):
            continue
        h = sha256(p)
        if h in by_sha:
            by_sha[h][1].append((Path("potential_assets") / rel).as_posix())
        else:
            by_sha[h] = (p, [])
    return sorted(by_sha.values(), key=lambda e: str(e[0]))


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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /private/tmp/wi-607-b && python3 -m pytest -q scripts/tests/test_slice_atlases.py`
Expected: `12 passed`.

- [ ] **Step 5: Commit**

```bash
cd /private/tmp/wi-607-b
git add tools/slice_atlases.py scripts/tests/test_slice_atlases.py
git commit -m "slice_atlases: sheet eligibility, sha dedupe, bundled and wired lookups (#607)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `slice_sheet`, SLICES.json, contact sheet, overrides, idempotent CLI

**Files:**
- Modify: `tools/slice_atlases.py` (append after `wired_regions`)
- Test: `scripts/tests/test_slice_atlases.py` (append)

**Interfaces:**
- Produces:
  - `slice_sheet(sheet: Path, assets_root: Path, out_dir: Path, overrides: list[list[int]], bundled: dict[str, str], wired: dict, duplicates: list[str]) -> tuple[dict, list[Image.Image]]` — the SLICES.json document and the crops in row order.
  - `write_outputs(doc: dict, crops: list[Image.Image], out_dir: Path) -> None`.
  - `render_contact(crops: list[Image.Image], out: Path, scale: int, start: int = 1, cols: int = 8, max_px: int = 96) -> None` — numbered grid, reused by `label_slices.export`.
  - `out_dir_for(sheet: Path, assets_root: Path, sha: str) -> Path` — `<assets_root>/<pack>/_sliced/<stem>` or `<stem>-<sha[:8]>` on a stem collision with different content.
  - `main(argv: list[str] | None = None) -> int`.
  - SLICES.json top level: `{"schema": 1, "source": "pack", "tier": "pack-bundle", "family": "<pack_family>", "sheet": "potential_assets/…", "sheet_sha256": "<hex>", "grid": 16|32|null, "overrides": [[x,y,w,h], …], "check_notes": [], "assets": [C8 rows + label_kind/bundled/game_sheet/wired_ids/duplicate_sheets]}`.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/tests/test_slice_atlases.py`:

```python
def game_fixture(tmp_path, sheet_src: Path, wired=None):
    game = tmp_path / "wandering_inn_game"
    dst = game / "assets/props/free_pack" / sheet_src.name
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(sheet_src.read_bytes())
    (game / "data").mkdir(exist_ok=True)
    sprites = {"_comment": "x"}
    for sid, region in (wired or {}).items():
        sprites[sid] = {"animations": {"idle": {"sheet": "res://assets/props/free_pack/" + sheet_src.name,
                                                "region": region}}}
    (game / "data/sprites.json").write_text(json.dumps(sprites))
    return game


def test_slice_sheet_rows_follow_c8_and_record_bundled_and_wired(tmp_path):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    src.parent.mkdir(parents=True)
    packed_crates(src)
    game = game_fixture(tmp_path, src, {"crate": [16, 0, 16, 23]})
    out_dir = sa.out_dir_for(src, assets, sa.sha256(src))
    assert out_dir == assets / "Pixel Crawler - Free Pack/_sliced/Furniture"
    doc, crops = sa.slice_sheet(src, assets, out_dir, [], sa.bundled_index(game), sa.wired_regions(game), ["dupe"])
    rows = doc["assets"]
    assert [r["region"] for r in rows] == [[0, 0, 16, 23], [16, 0, 16, 23], [32, 1, 16, 22]]
    crate = rows[1]
    assert crate["path"] == "potential_assets/Pixel Crawler - Free Pack/_sliced/Furniture/Furniture__x16_y0_w16_h23.png"
    assert crate["source_sheet"] == "potential_assets/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    assert crate["sheet_sha256"] == sa.sha256(src) and crate["method"] == "seam"
    assert (crate["kind"], crate["verdict"], crate["notes"], crate["has_shadow"]) == ("prop", "UNREVIEWED", "", False)
    assert crate["size_class"] == "M" and crate["label_confidence"] == 0.0 and crate["label_kind"] == ""
    assert crate["bundled"] is True and crate["game_sheet"] == "res://assets/props/free_pack/Furniture.png"
    assert crate["wired_ids"] == ["crate"] and crate["targets"] == ["crate"]
    assert rows[0]["wired_ids"] == [] and rows[0]["targets"] == []
    assert crate["duplicate_sheets"] == ["dupe"]
    assert doc["grid"] is None and doc["tier"] == "pack-bundle" and doc["family"] == "PC16"
    assert crops[1].size == (16, 23)


def test_grid_sheet_expands_to_cells_and_marks_method(tmp_path):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Meat.png"
    sprite_sheet(src, [(3, 3, 10, 10), (19, 3, 10, 10), (35, 3, 10, 10), (3, 19, 10, 10)], size=(64, 32))
    doc, crops = sa.slice_sheet(src, assets, sa.out_dir_for(src, assets, "x"), [], {}, {}, [])
    assert doc["grid"] == 16
    assert [r["region"] for r in doc["assets"]] == [[0, 0, 16, 16], [16, 0, 16, 16], [32, 0, 16, 16], [0, 16, 16, 16]]
    assert {r["method"] for r in doc["assets"]} == {"grid16"} and {r["size_class"] for r in doc["assets"]} == {"S"}
    assert doc["assets"][0]["bundled"] is False and doc["assets"][0]["game_sheet"] == ""


def test_override_replaces_overlapping_auto_slice(tmp_path):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    src.parent.mkdir(parents=True)
    packed_crates(src)
    doc, _ = sa.slice_sheet(src, assets, sa.out_dir_for(src, assets, "x"), [[0, 0, 32, 23]], {}, {}, [])
    assert [(r["region"], r["method"]) for r in doc["assets"]] == [([0, 0, 32, 23], "override"), ([32, 1, 16, 22], "seam")]
    assert doc["overrides"] == [[0, 0, 32, 23]]


def test_shadow_flag_from_semi_alpha(tmp_path):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png"
    im = sprite_sheet(src, [(2, 2, 12, 12), (34, 2, 12, 12)], size=(64, 32))
    for x in range(34, 46):
        im.putpixel((x, 15), (0, 0, 0, 80))
    im.save(src)
    doc, _ = sa.slice_sheet(src, assets, sa.out_dir_for(src, assets, "x"), [], {}, {}, [])
    assert [r["has_shadow"] for r in doc["assets"]] == [False, True]


def run_cli(tmp_path, *extra):
    assets = tmp_path / "potential_assets"
    game = tmp_path / "wandering_inn_game"
    return sa.main(["--assets-root", str(assets), "--game-root", str(game), *extra])


def test_cli_is_idempotent_and_skips_strips_and_dupes(tmp_path, capsys):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    src.parent.mkdir(parents=True)
    packed_crates(src)
    dupe = assets / "Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    dupe.parent.mkdir(parents=True)
    dupe.write_bytes(src.read_bytes())
    sprite_sheet(assets / "Pixel Crawler - Cave/Pixel Crawler - Cave/Enemies/Fungus/Idle-Sheet.png", [(0, 0, 16, 16)])
    sprite_sheet(assets / "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png", [(0, 0, 16, 16)])
    game_fixture(tmp_path, src)
    assert run_cli(tmp_path) == 0
    out = assets / "Pixel Crawler - Free Pack/_sliced/Furniture"
    first = (out / "SLICES.json").read_text()
    names = sorted(p.name for p in out.iterdir())
    assert names == ["Furniture__x0_y0_w16_h23.png", "Furniture__x16_y0_w16_h23.png",
                     "Furniture__x32_y1_w16_h22.png", "SLICES.json", "contact.png"]
    assert not (assets / "Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/_sliced").exists()
    assert not list((assets / "Pixel Crawler - Cave").rglob("_sliced"))
    shas = {p.name: sa.sha256(p) for p in out.iterdir()}
    assert run_cli(tmp_path) == 0
    assert (out / "SLICES.json").read_text() == first
    assert {p.name: sa.sha256(p) for p in out.iterdir()} == shas
    doc = json.loads(first)
    assert doc["assets"][0]["duplicate_sheets"] == [
        "potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"]
    assert "sliced 1 sheets (1 duplicates skipped) -> 3 slices" in capsys.readouterr().out


def test_rerun_preserves_labels_and_removes_orphans(tmp_path):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    src.parent.mkdir(parents=True)
    packed_crates(src)
    assert run_cli(tmp_path) == 0
    sj = assets / "Pixel Crawler - Free Pack/_sliced/Furniture/SLICES.json"
    doc = json.loads(sj.read_text())
    doc["assets"][1].update({"label_kind": "crate", "label_confidence": 0.9, "targets": ["crate"],
                             "verdict": "READY", "notes": "hand-checked"})
    sj.write_text(json.dumps(doc))
    assert run_cli(tmp_path, "--split", "Furniture:0,0,16,23") == 0
    doc2 = json.loads(sj.read_text())
    crate = [r for r in doc2["assets"] if r["region"] == [16, 0, 16, 23]][0]
    assert (crate["label_kind"], crate["label_confidence"], crate["targets"], crate["verdict"], crate["notes"]) == \
        ("crate", 0.9, ["crate"], "READY", "hand-checked")
    assert [r["method"] for r in doc2["assets"]] == ["override", "seam", "seam"]
    assert run_cli(tmp_path, "--split", "Furniture:0,0,8,23") == 0
    names = sorted(p.name for p in sj.parent.glob("*.png"))
    assert "Furniture__x0_y0_w16_h23.png" not in names and "Furniture__x0_y0_w8_h23.png" in names


def test_stem_collision_gets_sha_suffix(tmp_path):
    # Two generic parents (Assets/, Props/) give the same stem with different content.
    assets = tmp_path / "potential_assets"
    a = assets / "Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png"
    b = assets / "Pixel Crawler - Cave/Pixel Crawler - Cave/Props/Props.png"
    sprite_sheet(a, [(0, 0, 16, 16)])
    sprite_sheet(b, [(0, 0, 16, 16), (32, 0, 16, 16)])
    assert run_cli(tmp_path) == 0
    dirs = sorted(p.name for p in (assets / "Pixel Crawler - Cave/_sliced").iterdir())
    assert dirs == ["Props", "Props-" + sa.sha256(b)[:8]]
    assert run_cli(tmp_path) == 0
    assert sorted(p.name for p in (assets / "Pixel Crawler - Cave/_sliced").iterdir()) == dirs


def test_dry_run_writes_nothing(tmp_path, capsys):
    assets = tmp_path / "potential_assets"
    src = assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"
    src.parent.mkdir(parents=True)
    packed_crates(src)
    assert run_cli(tmp_path, "--dry-run") == 0
    assert not (assets / "Pixel Crawler - Free Pack/_sliced").exists()
    assert "Furniture.png" in capsys.readouterr().out
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /private/tmp/wi-607-b && python3 -m pytest -q scripts/tests/test_slice_atlases.py`
Expected: `8 failed, 12 passed`, failures on `AttributeError: … 'out_dir_for'` / `'main'`.

- [ ] **Step 3: Append slicing, outputs and the CLI**

Append to `tools/slice_atlases.py`:

```python
# ------------------------------------------------------------- slicing

def _xywh(box: list[int]) -> list[int]:
    return [box[0], box[1], box[2] - box[0], box[3] - box[1]]


def out_dir_for(sheet: Path, assets_root: Path, sha: str) -> Path:
    stem = sheet_stem(sheet)
    base = assets_root / sheet.relative_to(assets_root).parts[0] / "_sliced" / stem
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


def slice_sheet(sheet: Path, assets_root: Path, out_dir: Path, overrides: list[list[int]],
                bundled: dict[str, str], wired: dict, duplicates: list[str]) -> tuple[dict, list[Image.Image]]:
    im = Image.open(sheet).convert("RGBA")
    w, h = im.size
    data = im.tobytes()
    labels, boxes = components(data[3::4], w, h)
    pieces: list[tuple[list[int], str]] = []
    for cid, box in enumerate(boxes, 1):
        if box[4] >= MIN_AREA:
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
            if not any(o is not box and intersects(e, o) for o, _ in pieces):
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
           "grid": cell, "overrides": overrides, "check_notes": [], "assets": rows}
    return doc, crops


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
    ap.add_argument("--dry-run", action="store_true")
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
    sheets = find_sheets(assets_root, args.only)
    dupes = sum(len(d) for _, d in sheets)
    total, methods = 0, {}
    for sheet, duplicates in sheets:
        sha = sha256(sheet)
        out_dir = out_dir_for(sheet, assets_root, sha)
        if args.dry_run:
            print(f"would slice {sheet.relative_to(assets_root)} -> {out_dir.relative_to(assets_root)}")
            continue
        doc, crops = slice_sheet(sheet, assets_root, out_dir, splits.get(sheet_stem(sheet), []), bundled, wired, duplicates)
        write_outputs(doc, crops, out_dir)
        total += len(doc["assets"])
        for r in doc["assets"]:
            methods[r["method"]] = methods.get(r["method"], 0) + 1
        print(f"{len(doc['assets']):4d} slices  grid={doc['grid']}  {sheet.relative_to(assets_root)}")
    print(f"sliced {len(sheets)} sheets ({dupes} duplicates skipped) -> {total} slices; "
          + ", ".join(f"{k} {v}" for k, v in sorted(methods.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /private/tmp/wi-607-b && python3 -m pytest -q scripts/tests/test_slice_atlases.py`
Expected: `20 passed`.

- [ ] **Step 5: Smoke the real tool on one sheet (untracked output)**

Run: `cd /private/tmp/wi-607-b && ls potential_assets >/dev/null && python3 tools/slice_atlases.py --only "Free Pack/Environment/Props/Static/Furniture.png"`
Expected (measured on the planner's extracted copy of this code): `  91 slices  grid=None  Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` (Furniture is not grid-clean once flush pieces are counted, so its regions stay trimmed), then `sliced 1 sheets (1 duplicates skipped) -> 91 slices; component 73, seam 18`. Then:

Run: `python3 -c "import json;d=json.load(open('potential_assets/Pixel Crawler - Free Pack/_sliced/Furniture/SLICES.json'));print([ (r['region'],r['method'],r['wired_ids']) for r in d['assets'] if 'crate' in r['wired_ids'] or 'barrel' in r['wired_ids'] or 'stool' in r['wired_ids']])"`
Expected: `([736, 73, 16, 23], 'seam', ['crate'])`, `([752, 74, 16, 22], 'seam', ['barrel'])` — the #398 fused trio split on its double outlines — and `([112, 514, 16, 14], 'component', ['stool'])` plus the larger table piece `[98, 466, 44, 62]` that also carries `stool` in `wired_ids` (its box spans the stool; `label_slices.best_slice` prefers the exact one). If the trio is NOT split, the seam constants drifted: do not loosen them, add `--split Furniture:736,73,16,23 --split Furniture:752,74,16,22` to the Task 7 run and record it in the PR.

- [ ] **Step 6: Commit**

```bash
cd /private/tmp/wi-607-b
git add tools/slice_atlases.py scripts/tests/test_slice_atlases.py
git commit -m "slice_atlases: SLICES.json per C8, contact sheet, overrides, idempotent CLI (#607)

Re-runs keep labels by (sha, region), drop orphan PNGs, honour recorded
--split overrides, and never write under a duplicate pack.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: registry and index integration (`asset_candidates.py`, `asset_index.py`, `find_asset.py`)

**Files:**
- Modify: `tools/asset_candidates.py:279-291` (`rows_from_manifest_json`), `:411` (`MANIFEST_NAMES`), `:424-435` (`find_batches`), `:438-464` (`read_batch`), `:482-512` (`finish_row`), `:564-590` (`build`)
- Modify: `tools/asset_index.py:52-70` (`build`)
- Modify: `tools/find_asset.py:115-130` (`fmt`)
- Test: `scripts/tests/test_asset_candidates.py` (append a class), `scripts/tests/test_asset_index.py` (new)

**Interfaces:**
- Consumes: SLICES.json documents from Task 3.
- Produces: registry rows with `tier: "pack-bundle"`, `source: "pack"`, `family: pack_family(<pack>)`, `batch: "<pack>/_sliced/<stem>"`, and passthrough of `ac.SLICE_KEYS = ("source_sheet", "region", "sheet_sha256", "method", "has_shadow", "size_class", "label_confidence", "label_kind", "bundled", "game_sheet", "wired_ids", "duplicate_sheets")`. `asset_index.build(assets: Path = ASSETS)` gains a parameter and skips `_sliced`.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/tests/test_asset_candidates.py` (before `if __name__ == "__main__":`):

```python
class TestSlicedBatches(Fixture):
    def slices(self):
        pack = self.assets / "Pixel Crawler - Free Pack"
        d = pack / "_sliced" / "Furniture"
        png(d / "Furniture__x736_y73_w16_h23.png", 16, 23)
        png(d / "Furniture__x0_y0_w32_h32.png", 32, 32)
        png(pack / "Environment" / "Props" / "Static" / "Furniture.png", 800, 864)
        rows = [
            {"path": "potential_assets/Pixel Crawler - Free Pack/_sliced/Furniture/Furniture__x736_y73_w16_h23.png",
             "kind": "prop", "targets": ["crate"], "verdict": "UNREVIEWED", "notes": "",
             "source_sheet": "potential_assets/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png",
             "region": [736, 73, 16, 23], "sheet_sha256": "ab" * 32, "method": "seam", "has_shadow": False,
             "size_class": "M", "label_confidence": 0.9, "label_kind": "crate", "bundled": True,
             "game_sheet": "res://assets/props/free_pack/Furniture.png", "wired_ids": ["crate"],
             "duplicate_sheets": []},
            {"path": "potential_assets/Pixel Crawler - Free Pack/_sliced/Furniture/Furniture__x0_y0_w32_h32.png",
             "kind": "prop", "targets": [], "verdict": "UNREVIEWED", "notes": "",
             "source_sheet": "potential_assets/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png",
             "region": [0, 0, 32, 32], "sheet_sha256": "ab" * 32, "method": "grid16", "has_shadow": False,
             "size_class": "M", "label_confidence": 0.0, "label_kind": "", "bundled": False, "game_sheet": "",
             "wired_ids": [], "duplicate_sheets": []}]
        (d / "SLICES.json").write_text(json.dumps({
            "schema": 1, "source": "pack", "tier": "pack-bundle", "family": "PC16",
            "sheet": rows[0]["source_sheet"], "sheet_sha256": "ab" * 32, "grid": 16,
            "overrides": [], "check_notes": [], "assets": rows}))
        return d

    def test_sliced_dir_is_a_pack_bundle_batch_with_passthrough(self):
        d = self.slices()
        reg = self.build()
        rows = self.rows(reg, "Pixel Crawler - Free Pack/_sliced/Furniture")
        crate = rows["Furniture__x736_y73_w16_h23.png"]
        self.assertEqual((crate["tier"], crate["source"], crate["family"], crate["kind"]),
                         ("pack-bundle", "pack", "PC16", "prop"))
        self.assertEqual(crate["region"], [736, 73, 16, 23])
        self.assertEqual(crate["method"], "seam")
        self.assertIs(crate["has_shadow"], False)
        self.assertIs(crate["bundled"], True)
        self.assertEqual(crate["game_sheet"], "res://assets/props/free_pack/Furniture.png")
        self.assertEqual(crate["label_confidence"], 0.9)
        self.assertEqual((crate["w"], crate["h"]), (16, 23))
        self.assertTrue(crate["manifest_ref"].endswith("_sliced/Furniture/SLICES.json"))
        other = rows["Furniture__x0_y0_w32_h32.png"]
        self.assertIs(other["bundled"], False)
        self.assertEqual(other["label_confidence"], 0.0)
        self.assertEqual(other["targets"], ["Furniture__x0_y0_w32_h32"], "unlabeled slices stay searchable by stem")
        batch = [b for b in reg["batches"] if b["batch"].endswith("_sliced/Furniture")][0]
        self.assertEqual((batch["origin"], batch["tier"], batch["rows"]), ("SLICES.json", "pack-bundle", 2))

    def test_write_manifests_never_touches_sliced_dirs(self):
        d = self.slices()
        self.build(write=True)
        self.assertNotIn("MANIFEST.json", ac.present(d))

    def test_find_asset_crate_returns_slice_with_region(self):
        self.slices()
        reg = self.build()
        hits = fa.search(reg["assets"], ["crate"], tier="pack")
        self.assertEqual([Path(r["path"]).name for _, r in hits], ["Furniture__x736_y73_w16_h23.png"])
        text = fa.fmt(hits[0][1])
        self.assertIn("region=736,73,16,23 of Furniture.png", text)
        self.assertIn("bundled=res://assets/props/free_pack/Furniture.png", text)
        pending = dict(hits[0][1], bundled=False, game_sheet="")
        self.assertIn("BUNDLE-PENDING", fa.fmt(pending))
```

Create `scripts/tests/test_asset_index.py`:

```python
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
    png(assets / "Pixel Crawler - Free Pack/_sliced/Furniture/Furniture__x0_y0_w16_h16.png")
    png(assets / "Pixel Crawler - Free Pack/_sliced/Furniture/contact.png", 64, 64)
    packs = ai.build(assets)
    assert [e["path"] for e in packs["Pixel Crawler - Free Pack"]] == [
        "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png"]
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /private/tmp/wi-607-b && python3 -m pytest -q scripts/tests/test_asset_candidates.py scripts/tests/test_asset_index.py`
Expected: 4 failures — `KeyError: 'Furniture__x736_y73_w16_h23.png'` (sliced dir not a batch), `TypeError: build() takes 0 positional arguments`.

- [ ] **Step 3: Implement the registry changes**

In `tools/asset_candidates.py`, after `MAX_NOTES = 200` (line 61) add:

```python
SLICE_KEYS = ("source_sheet", "region", "sheet_sha256", "method", "has_shadow", "size_class",
              "label_confidence", "label_kind", "bundled", "game_sheet", "wired_ids", "duplicate_sheets")
```

Replace `rows_from_manifest_json` (lines 279–291) with:

```python
def rows_from_manifest_json(batch_dir: Path, manifest: Path) -> list[dict]:
    data = json.loads(manifest.read_text(encoding="utf-8"))
    out = []
    for a in data.get("assets", []):
        row = {k: a.get(k, "") for k in ("path", "kind", "targets", "verdict", "pixellab_id",
                                          "prompt", "notes", "contact_sheet", "anchor_feet")}
        row["targets"] = list(row["targets"] or extract_targets("", row["path"]))
        row["verdict"] = row["verdict"] if row["verdict"] in VERDICT_RANK else normalize_verdict(row["verdict"])
        row["prompt"] = clip(row["prompt"], MAX_PROMPT)
        row["notes"] = clip(row["notes"], MAX_NOTES)
        row["manifest_ref"] = manifest.name
        out.append({k: v for k, v in row.items() if v not in ("", None, [])} | {"path": row["path"]}
                   | {k: a[k] for k in SLICE_KEYS if k in a})
    return out
```

Replace `MANIFEST_NAMES` (line 411) with:

```python
MANIFEST_NAMES = ("MANIFEST.json", "MANIFEST.md", "manifest.json")
SLICES_NAME = "SLICES.json"
```

Replace `find_batches` (lines 424–435) with:

```python
def find_batches(assets_root: Path) -> list[Path]:
    batches = []
    for top in sorted(assets_root.iterdir()):
        if not top.is_dir() or not re.match(r"(pixellab|codex)", top.name, re.I):
            continue
        lanes = [d for d in sorted(top.iterdir())
                 if d.is_dir() and present(d) & set(MANIFEST_NAMES)]
        if lanes and not present(top) & {"MANIFEST.json", "manifest.json"}:
            batches.extend(lanes)
        else:
            batches.append(top)
    # tools/slice_atlases.py output: <pack>/_sliced/<stem>/SLICES.json, tier pack-bundle
    for sliced in sorted(assets_root.glob("*/_sliced")):
        batches += [d for d in sorted(sliced.iterdir()) if d.is_dir() and SLICES_NAME in present(d)]
    return batches


def is_sliced(batch_rel: Path) -> bool:
    return "_sliced" in batch_rel.parts
```

In `read_batch` (line 441–447), after `names = present(batch_dir)` and inside the `try:`, insert as the first branch:

```python
        if SLICES_NAME in names:
            return SLICES_NAME, rows_from_manifest_json(batch_dir, batch_dir / SLICES_NAME)
```

In `finish_row` (line 506), change the passthrough loop to:

```python
    for k in ("pixellab_id", "prompt", "notes", "anchor_feet", "contact_sheet", *SLICE_KEYS):
        if row.get(k) not in (None, "", []):
            out[k] = row[k]
```

In `build` (lines 567–575), replace the classify line and the write guard:

```python
        for bdir in find_batches(assets_root):
            batch_rel = bdir.relative_to(assets_root)
            if is_sliced(batch_rel):
                source, tier, family = "pack", "pack-bundle", pack_family(batch_rel.parts[0])
            else:
                source, tier, family = classify_batch(batch_rel.parts[0])
            origin, rows = read_batch(bdir)
            rows = dedupe(rows)
            # never write MANIFEST.json beside a legacy manifest.json: on a
            # case-insensitive filesystem that clobbers it (see present()).
            if (write_manifests and origin not in ("MANIFEST.json", SLICES_NAME) and rows
                    and "manifest.json" not in present(bdir)):
                write_manifest_json(bdir, rows, source, tier, family, origin)
```

In `tools/asset_index.py`, replace `build` (lines 52–70) with:

```python
def build(assets: Path = ASSETS) -> dict:
    packs: dict[str, list[dict]] = {}
    for p in sorted(assets.rglob("*.png")):
        rel = p.relative_to(assets)
        pack = rel.parts[0]
        # _sliced/ holds tools/slice_atlases.py output, already registry rows
        if pack.endswith(".zip") or "_sliced" in rel.parts:
            continue
        size = png_size(p)
        if size is None:
            continue
        w, h = size
        packs.setdefault(pack, []).append({
            "path": str(rel),
            "w": w,
            "h": h,
            "frames": frame_guess(p.name, w, h),
            "bytes": p.stat().st_size,
        })
    return packs
```

In `tools/find_asset.py` `fmt` (line 124, after the `contact_sheet` branch) add:

```python
    if r.get("source_sheet"):
        region = ",".join(str(v) for v in r.get("region", []))
        extra.append(f"region={region} of {Path(r['source_sheet']).name}")
        extra.append(f"bundled={r['game_sheet']}" if r.get("game_sheet") else "BUNDLE-PENDING")
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /private/tmp/wi-607-b && python3 -m pytest -q scripts/tests/test_asset_candidates.py scripts/tests/test_asset_index.py scripts/tests/test_slice_atlases.py`
Expected: all pass (`… passed`, 0 failed).

- [ ] **Step 5: Commit**

```bash
cd /private/tmp/wi-607-b
git add tools/asset_candidates.py tools/asset_index.py tools/find_asset.py scripts/tests/test_asset_candidates.py scripts/tests/test_asset_index.py
git commit -m "asset registry: _sliced/ batches as pack-bundle rows, index excludes them (#607)

SLICES.json rows pass source_sheet/region/sheet_sha256/method/has_shadow/
size_class/label_* /bundled/game_sheet through; find_asset prints the
region and bundled sheet (or BUNDLE-PENDING) for wire_asset.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `tools/label_slices.py` — `export` (paged contact sheets + task file) and `import`

**Files:**
- Create: `tools/label_slices.py`
- Test: `scripts/tests/test_label_slices.py`

**Interfaces:**
- Consumes: `slice_atlases.render_contact`, `slice_atlases.KINDS`, SLICES.json documents.
- Produces:
  - `find_slices(assets_root: Path) -> list[Path]` — every `*/_sliced/*/SLICES.json`, sorted.
  - `export(assets_root: Path, page_size: int = 40) -> dict` — writes `<_sliced>/<stem>/pages/<stem>_p{NN}_2x.png` and `_1x.png`, and `<assets_root>/_sliced_task.json`; returns the task document `{"pages": [{"page": "<pack>/<stem>/p01", "png_2x": "...", "png_1x": "...", "slices_json": "...", "numbers": {"1": {"path": ..., "size_class": ..., "region": [...]}}}]}` (paths relative to the repo root, `potential_assets/…`).
  - `import_labels(assets_root: Path, answers_dir: Path) -> int` — reads `<answers_dir>/*.json` of shape `{"page": "<pack>/<stem>/p01", "labels": {"1": {"kind": "crate", "confidence": 0.9}, …}}`; returns 0, or 2 when any answer is invalid (nothing written).
  - `PROMPT_TEMPLATE: str` — the exact vision-agent prompt, formatted with `page`, `png_2x`, `png_1x`, `numbers`.
  - `main(argv) -> int` with sub-commands `export`, `import`, `check` (`check` is Task 6).

- [ ] **Step 1: Write the failing tests**

Create `scripts/tests/test_label_slices.py`:

```python
#!/usr/bin/env python3
"""tools/label_slices.py: export/import/check on synthetic slices.
Run: python3 -m pytest -q scripts/tests/test_label_slices.py"""
import json
import sys
from pathlib import Path

import pytest

pytest.importorskip("PIL")
from PIL import Image, ImageDraw  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
import label_slices as ls  # noqa: E402
import slice_atlases as sa  # noqa: E402

CLEAR = (0, 0, 0, 0)


def sheet_with_boxes(path: Path, n: int, size=None) -> Path:
    """n outlined 10x10 sprites on a 16px grid, left to right then down."""
    cols = 8
    size = size or (cols * 16, -(-n // cols) * 16)
    im = Image.new("RGBA", size, CLEAR)
    d = ImageDraw.Draw(im)
    for i in range(n):
        x, y = (i % cols) * 16 + 3, (i // cols) * 16 + 3
        d.rectangle((x, y, x + 9, y + 9), fill=(140, 90, 40, 255), outline=(0, 0, 0, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    return path


def sliced_fixture(tmp_path, n=45, wired=None):
    assets = tmp_path / "potential_assets"
    game = tmp_path / "wandering_inn_game"
    src = sheet_with_boxes(assets / "Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png", n)
    dst = game / "assets/props/free_pack/Furniture.png"
    dst.parent.mkdir(parents=True)
    dst.write_bytes(src.read_bytes())
    (game / "data").mkdir()
    sprites = {"_comment": "x"}
    for sid, (sheet, region) in (wired or {}).items():
        sprites[sid] = {"animations": {"idle": {"sheet": sheet, "region": region}}}
    (game / "data/sprites.json").write_text(json.dumps(sprites))
    assert sa.main(["--assets-root", str(assets), "--game-root", str(game)]) == 0
    return assets, game


def test_export_pages_numbered_and_capped_at_40(tmp_path):
    assets, _ = sliced_fixture(tmp_path, n=45)
    task = ls.export(assets)
    pages = task["pages"]
    assert [p["page"] for p in pages] == ["Pixel Crawler - Free Pack/Furniture/p01", "Pixel Crawler - Free Pack/Furniture/p02"]
    assert list(pages[0]["numbers"]) == [str(i) for i in range(1, 41)]
    assert list(pages[1]["numbers"]) == [str(i) for i in range(41, 46)]
    assert pages[0]["numbers"]["1"]["size_class"] == "S" and pages[0]["numbers"]["1"]["region"] == [0, 0, 16, 16]
    for p in pages:
        for key in ("png_2x", "png_1x", "slices_json"):
            assert (tmp_path / p[key]).exists(), key
    two = Image.open(tmp_path / pages[0]["png_2x"])
    one = Image.open(tmp_path / pages[0]["png_1x"])
    assert two.size[0] > one.size[0]
    assert json.loads((assets / "_sliced_task.json").read_text()) == task
    assert "{page}" not in ls.PROMPT_TEMPLATE.format(page="x", png_2x="a", png_1x="b", numbers="1-40")
    for kind in sa.KINDS:
        assert kind in ls.PROMPT_TEMPLATE


def write_answer(answers: Path, page: str, labels: dict) -> None:
    answers.mkdir(exist_ok=True)
    (answers / (page.replace("/", "__") + ".json")).write_text(json.dumps({"page": page, "labels": labels}))


def test_import_merges_labels_into_slices_json(tmp_path):
    assets, _ = sliced_fixture(tmp_path, n=3, wired={"crate": ("res://assets/props/free_pack/Furniture.png", [16, 0, 16, 16])})
    ls.export(assets)
    answers = tmp_path / "answers"
    write_answer(answers, "Pixel Crawler - Free Pack/Furniture/p01",
                 {"1": {"kind": "barrel", "confidence": 0.8}, "2": {"kind": "crate", "confidence": 0.95}})
    assert ls.import_labels(assets, answers) == 0
    rows = json.loads((assets / "Pixel Crawler - Free Pack/_sliced/Furniture/SLICES.json").read_text())["assets"]
    assert (rows[0]["label_kind"], rows[0]["label_confidence"], rows[0]["targets"]) == ("barrel", 0.8, ["barrel"])
    assert (rows[1]["label_kind"], rows[1]["targets"]) == ("crate", ["crate"]), "kind first, wired id kept"
    assert rows[1]["size_class"] == "S", "measured size class is never overwritten"
    assert (rows[2]["label_kind"], rows[2]["label_confidence"]) == ("", 0.0), "unanswered stays unlabeled"


def test_import_rejects_bad_kind_and_bad_number(tmp_path, capsys):
    assets, _ = sliced_fixture(tmp_path, n=3)
    ls.export(assets)
    answers = tmp_path / "answers"
    write_answer(answers, "Pixel Crawler - Free Pack/Furniture/p01",
                 {"1": {"kind": "chest", "confidence": 0.8}, "9": {"kind": "crate", "confidence": 1.0},
                  "2": {"kind": "crate", "confidence": 1.5}})
    assert ls.import_labels(assets, answers) == 2
    out = capsys.readouterr().out
    assert "unknown kind 'chest'" in out and "number 9" in out and "confidence 1.5" in out
    rows = json.loads((assets / "Pixel Crawler - Free Pack/_sliced/Furniture/SLICES.json").read_text())["assets"]
    assert all(r["label_kind"] == "" for r in rows), "an invalid answer file writes nothing"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /private/tmp/wi-607-b && python3 -m pytest -q scripts/tests/test_label_slices.py`
Expected: collection error `ModuleNotFoundError: No module named 'label_slices'`.

- [ ] **Step 3: Write export and import**

Create `tools/label_slices.py`:

```python
#!/usr/bin/env python3
"""Label the atlas slices from tools/slice_atlases.py with the closed kind
vocabulary, through a controller-dispatched vision agent.

  export  write numbered contact pages (1x and 2x, <= 40 slices each) under
          <pack>/_sliced/<stem>/pages/ and potential_assets/_sliced_task.json
  import  merge the agent's JSON answers (one file per page) into SLICES.json:
          label_kind, label_confidence, targets = [kind] + wired ids
  check   agreement of label_kind with the kind expected for every wired
          data/sprites.json region on a sliced sheet (WIRED_KINDS); misses are
          written into SLICES.json notes; exits 1 under --threshold (0.9)

The controller runs the agent: one prompt per page (PROMPT_TEMPLATE), the
answer saved as <answers_dir>/<page with / as __>.json. The agent never sees
the pack PNGs, only the contact pages. size_class is measured, never judged.

Usage:
  python3 tools/label_slices.py export [--assets-root DIR] [--page-size 40]
  python3 tools/label_slices.py import --answers DIR [--assets-root DIR]
  python3 tools/label_slices.py check [--assets-root DIR] [--game-root DIR] [--threshold 0.9]
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import slice_atlases as sa  # noqa: E402

ROOT = sa.ROOT
TASK_NAME = "_sliced_task.json"
CHECK_TAG = "check-miss:"

PROMPT_TEMPLATE = """You are labeling pixel-art prop sprites cut from a game asset atlas.
Read the two images of page {page}: {png_2x} (2x zoom) and {png_1x} (1x, gameplay scale).
Each sprite has a yellow number above it; the numbers on this page are {numbers}.

For EVERY number, choose exactly one kind from this closed list and nothing else:
crate barrel sack door window lamp table seat shelf bed plant rock debris tool sign wall_module container other

Guidance:
- crate = boxy wooden/metal box; barrel = round-bodied cask; sack = soft bag/pouch/bale;
  container = chest, urn, pot, basket, bucket or other vessel that is not a crate/barrel/sack;
- door, window, wall_module (wall/roof/fence/railing segment meant to tile with neighbours);
- lamp = any light source (lantern, candle, torch, sconce, brazier, campfire);
- table (also counters, desks, benches used as surfaces), seat (chair, stool, bench to sit on),
  shelf (bookcase, rack, cabinet), bed;
- plant = tree, bush, flower, grass, crop, mushroom, reeds; rock = stone, boulder, pebble, crystal;
- debris = rubble, bones, broken pieces, scattered litter; tool = tools, weapons racks, workshop items;
- sign = signboard, banner, flag, notice; other = anything that fits none of the above
  (food, statues, grates, scrolls, machines).
Do not invent a kind. Confidence is 0.0-1.0 for how sure you are of the kind.

Answer with ONLY this JSON (no prose), one entry per number:
{{"page": "{page}", "labels": {{"1": {{"kind": "crate", "confidence": 0.9}}, "2": {{"kind": "plant", "confidence": 0.7}}}}}}
"""


def find_slices(assets_root: Path) -> list[Path]:
    return sorted(assets_root.glob("*/_sliced/*/SLICES.json"))


def _rel(path: Path, assets_root: Path) -> str:
    return (Path("potential_assets") / path.relative_to(assets_root)).as_posix()


def export(assets_root: Path, page_size: int = 40) -> dict:
    pages = []
    for sj in find_slices(assets_root):
        doc = json.loads(sj.read_text(encoding="utf-8"))
        rows = doc["assets"]
        stem_dir = sj.parent
        pack = stem_dir.parent.parent.name
        crops = [Image.open(assets_root / Path(r["path"]).relative_to("potential_assets")).convert("RGBA")
                 for r in rows]
        for start in range(0, len(rows), page_size):
            n = start // page_size + 1
            chunk = rows[start:start + page_size]
            pngs = {}
            for scale in (1, 2):
                out = stem_dir / "pages" / f"{stem_dir.name}_p{n:02d}_{scale}x.png"
                sa.render_contact(crops[start:start + page_size], out, scale=scale, start=start + 1)
                pngs[scale] = _rel(out, assets_root)
            pages.append({
                "page": f"{pack}/{stem_dir.name}/p{n:02d}",
                "png_2x": pngs[2], "png_1x": pngs[1], "slices_json": _rel(sj, assets_root),
                "numbers": {str(start + i + 1): {"path": r["path"], "size_class": r["size_class"],
                                                 "region": r["region"]}
                            for i, r in enumerate(chunk)},
            })
    task = {"pages": pages}
    (assets_root / TASK_NAME).write_text(json.dumps(task, indent=1) + "\n", encoding="utf-8")
    print(f"exported {len(pages)} pages for {sum(len(p['numbers']) for p in pages)} slices -> {assets_root / TASK_NAME}")
    return task


def import_labels(assets_root: Path, answers_dir: Path) -> int:
    task_path = assets_root / TASK_NAME
    if not task_path.exists():
        print(f"no {TASK_NAME}; run export first")
        return 2
    pages = {p["page"]: p for p in json.loads(task_path.read_text(encoding="utf-8"))["pages"]}
    pending: dict[str, dict[str, tuple[str, float]]] = {}   # slices_json -> path -> (kind, conf)
    errors = []
    for ans in sorted(answers_dir.glob("*.json")):
        data = json.loads(ans.read_text(encoding="utf-8"))
        page = pages.get(data.get("page", ""))
        if page is None:
            errors.append(f"{ans.name}: unknown page {data.get('page')!r}")
            continue
        for num, lab in (data.get("labels") or {}).items():
            kind = (lab or {}).get("kind", "")
            conf = (lab or {}).get("confidence", 0.0)
            if num not in page["numbers"]:
                errors.append(f"{ans.name}: number {num} is not on page {page['page']}")
            elif kind not in sa.KINDS:
                errors.append(f"{ans.name}: unknown kind {kind!r} at number {num}")
            elif not isinstance(conf, (int, float)) or not 0.0 <= conf <= 1.0:
                errors.append(f"{ans.name}: confidence {conf!r} at number {num} is not in 0..1")
            else:
                pending.setdefault(page["slices_json"], {})[page["numbers"][num]["path"]] = (kind, float(conf))
    if errors:
        print("\n".join(errors))
        print(f"import refused: {len(errors)} invalid answers, nothing written")
        return 2
    labeled = 0
    for sj_rel, by_path in pending.items():
        sj = assets_root / Path(sj_rel).relative_to("potential_assets")
        doc = json.loads(sj.read_text(encoding="utf-8"))
        for row in doc["assets"]:
            if row["path"] in by_path:
                kind, conf = by_path[row["path"]]
                row["label_kind"], row["label_confidence"] = kind, conf
                row["targets"] = list(dict.fromkeys([kind] + list(row.get("wired_ids", []))))
                labeled += 1
        sj.write_text(json.dumps(doc, indent=1) + "\n", encoding="utf-8")
    print(f"imported {labeled} labels into {len(pending)} SLICES.json files")
    return 0
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /private/tmp/wi-607-b && python3 -m pytest -q scripts/tests/test_label_slices.py`
Expected: `3 passed`.

- [ ] **Step 5: Commit**

```bash
cd /private/tmp/wi-607-b
git add tools/label_slices.py scripts/tests/test_label_slices.py
git commit -m "label_slices: paged contact export, vision prompt and label import (#607)

Pages hold <= 40 numbered slices at 1x and 2x; import validates the closed
kind list, page numbers and confidence before writing anything.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `label_slices.py check` — agreement against wired regions

**Files:**
- Modify: `tools/label_slices.py` (append)
- Test: `scripts/tests/test_label_slices.py` (append)

**Interfaces:**
- Produces:
  - `WIRED_KINDS: dict[str, str]` — sprite id → expected kind for every `region` animation in `data/sprites.json` as of `7155db91`.
  - `best_slice(rows: list[dict], region: list[int]) -> tuple[dict | None, float]` — the row with the highest containment overlap (ties by IoU) and that overlap.
  - `check(assets_root: Path, game_root: Path, threshold: float = 0.9) -> int` — 0 when agreement ≥ threshold, else 1; prints a per-kind confusion table, the misses, and the wired regions excluded because their sheet was not sliced; rewrites each SLICES.json with `check-miss:` notes (per-row for mislabeled matches, `check_notes` for regions no slice covers), stripping older `check-miss:` notes first so re-runs are idempotent.
  - `main(argv) -> int`.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/tests/test_label_slices.py`:

```python
SHEET = "res://assets/props/free_pack/Furniture.png"


def labeled_fixture(tmp_path, labels: dict, wired: dict):
    assets, game = sliced_fixture(tmp_path, n=3, wired=wired)
    ls.export(assets)
    answers = tmp_path / "answers"
    write_answer(answers, "Pixel Crawler - Free Pack/Furniture/p01", labels)
    assert ls.import_labels(assets, answers) == 0
    return assets, game


def test_check_passes_at_full_agreement_and_strips_old_notes(tmp_path, capsys):
    assets, game = labeled_fixture(
        tmp_path, {"1": {"kind": "crate", "confidence": 0.9}, "2": {"kind": "barrel", "confidence": 0.9}},
        {"crate": (SHEET, [0, 0, 16, 16]), "barrel": (SHEET, [19, 3, 10, 10])})
    sj = assets / "Pixel Crawler - Free Pack/_sliced/Furniture/SLICES.json"
    doc = json.loads(sj.read_text())
    doc["assets"][0]["notes"] = "keep me check-miss: stale"
    sj.write_text(json.dumps(doc))
    assert ls.check(assets, game) == 0
    out = capsys.readouterr().out
    assert "agreement 2/2 = 100.0%" in out
    assert json.loads(sj.read_text())["assets"][0]["notes"] == "keep me"


def test_check_fails_under_threshold_and_writes_misses(tmp_path, capsys):
    assets, game = labeled_fixture(
        tmp_path, {"1": {"kind": "crate", "confidence": 0.9}, "2": {"kind": "plant", "confidence": 0.5}},
        {"crate": (SHEET, [0, 0, 16, 16]), "barrel": (SHEET, [16, 0, 16, 16]),
         "ghost": (SHEET, [100, 100, 8, 8])})
    ls.WIRED_KINDS["ghost"] = "other"
    try:
        assert ls.check(assets, game) == 1
    finally:
        del ls.WIRED_KINDS["ghost"]
    out = capsys.readouterr().out
    assert "agreement 1/3 = 33.3%" in out
    assert "barrel -> plant" in out and "ghost" in out
    doc = json.loads((assets / "Pixel Crawler - Free Pack/_sliced/Furniture/SLICES.json").read_text())
    assert doc["assets"][1]["notes"] == "check-miss: wired barrel expects barrel, got plant"
    assert doc["check_notes"] == ["check-miss: wired ghost expects other, got no overlapping slice"]
    assert doc["assets"][0]["notes"] == ""


def test_check_excludes_unsliced_sheets(tmp_path, capsys):
    assets, game = labeled_fixture(
        tmp_path, {"1": {"kind": "crate", "confidence": 0.9}},
        {"crate": (SHEET, [0, 0, 16, 16]),
         "library_desk": ("res://assets/tiles/library/Tiles.png", [160, 272, 48, 32]),
         "sconce": ("res://assets/props/free_pack/Bonfire_01-Sheet.png", [0, 0, 128, 32])})
    assert ls.check(assets, game) == 0
    out = capsys.readouterr().out
    assert "agreement 1/1 = 100.0%" in out
    assert "excluded 2 wired regions on unsliced sheets" in out and "library_desk" in out


def test_check_skips_ids_outside_wired_kinds(tmp_path, capsys):
    assets, game = labeled_fixture(tmp_path, {"1": {"kind": "crate", "confidence": 0.9}},
                                   {"crate": (SHEET, [0, 0, 16, 16]), "brand_new_id": (SHEET, [16, 0, 16, 16])})
    assert ls.check(assets, game) == 0
    assert "SKIP brand_new_id: not in WIRED_KINDS" in capsys.readouterr().out


def test_best_slice_prefers_exact_size_over_spanning_piece():
    rows = [{"region": [98, 466, 44, 62], "label_kind": "table"},
            {"region": [112, 514, 16, 14], "label_kind": "seat"},
            {"region": [736, 73, 32, 23], "label_kind": "crate"}]
    best, ratio = ls.best_slice(rows, [112, 514, 16, 14])
    assert (best["label_kind"], ratio) == ("seat", 1.0)
    best, ratio = ls.best_slice(rows, [752, 74, 16, 22])
    assert (best["label_kind"], ratio) == ("crate", 1.0), "a wired sub-region of a fused slice still matches"
    assert ls.best_slice([], [0, 0, 1, 1]) == (None, 0.0)


def test_main_dispatch(tmp_path):
    assets, game = sliced_fixture(tmp_path, n=2)
    assert ls.main(["export", "--assets-root", str(assets)]) == 0
    assert ls.main(["check", "--assets-root", str(assets), "--game-root", str(game)]) == 0, "no wired regions: vacuous pass"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /private/tmp/wi-607-b && python3 -m pytest -q scripts/tests/test_label_slices.py`
Expected: `6 failed, 3 passed` with `AttributeError: module 'label_slices' has no attribute 'check'` (and `best_slice`).

- [ ] **Step 3: Append the check and the CLI**

Append to `tools/label_slices.py`:

```python
# ------------------------------------------------------------------ check

# Expected kind for every data/sprites.json `region` animation at 7155db91.
# Ids on sheets the slicer skips (tiles, -Sheet strips, Admurin, owned) are
# excluded by check() at run time, so listing them here is harmless.
WIRED_KINDS = {
    "crate": "crate", "barrel": "barrel", "door": "door", "window_blue": "window",
    "unlit_lantern": "lamp", "sconce": "lamp", "campfire": "lamp",
    "table_brown": "table", "bar_counter": "table", "counter_left": "table", "counter_mid": "table",
    "counter_right": "table", "library_desk": "table", "stool": "seat",
    "shelf_bottles": "shelf", "library_shelf": "shelf", "bed": "bed",
    "plant_pot": "plant", "bush_green": "plant", "grass_tuft": "plant", "flower_purple": "plant",
    "flower_tiny": "plant", "pond_reeds": "plant", "tree_big": "plant", "tree_round": "plant",
    "tree_autumn_orange": "plant", "tree_autumn_red": "plant", "crop_row_orange": "plant",
    "crop_row_green": "plant", "crop_row_dark_green": "plant", "mushroom": "plant",
    "mushroom_purple_l": "plant", "mushroom_purple_m": "plant", "mushroom_purple_s": "plant",
    "hollow_mushroom_cluster": "plant", "hollow_canopy_tree": "plant", "hollow_small_tree": "plant",
    "hollow_bent_tree": "plant",
    "pebble": "rock", "boulder": "rock", "scree_spill": "rock", "hollow_glow_stone": "rock",
    "dungeon_rubble": "debris", "grill": "tool",
    "chest": "container", "chest_open": "container",
    "facade_plaster": "wall_module", "inn_roof": "wall_module", "pallass_rail_post": "wall_module",
    "dungeon_statue": "other", "pedestal": "other", "sewer_grate": "other", "dusty_scroll": "other",
    "food_bread": "other", "food_ham": "other", "food_basket": "other",
    "garden_fountain_basin": "other", "garden_fountain_statue": "other",
}


def _strip_check(note: str) -> str:
    idx = note.find(CHECK_TAG)
    return (note[:idx] if idx != -1 else note).strip()


def best_slice(rows: list[dict], region: list[int]) -> tuple[dict | None, float]:
    """The slice a wired region lands on: highest containment overlap, ties
    broken by IoU so an exact-size slice beats a larger piece whose box
    merely spans the region (Furniture's stool sits inside a table's box)."""
    if not rows:
        return None, 0.0
    best = max(rows, key=lambda r: (sa.overlap_ratio(region, r["region"]), sa.iou(region, r["region"])))
    return best, sa.overlap_ratio(region, best["region"])


def check(assets_root: Path, game_root: Path, threshold: float = 0.9) -> int:
    by_sheet: dict[str, tuple[Path, dict]] = {}
    for sj in find_slices(assets_root):
        doc = json.loads(sj.read_text(encoding="utf-8"))
        rows = doc.get("assets", [])
        if rows and rows[0].get("game_sheet"):
            by_sheet[rows[0]["game_sheet"]] = (sj, doc)
    wired = sa.wired_regions(game_root)
    total = hits = 0
    confusion: Counter = Counter()
    misses: list[str] = []
    excluded: list[str] = []
    for res, regs in sorted(wired.items()):
        if res not in by_sheet:
            excluded += [f"{sid} on {res}" for sid, _ in regs]
            continue
        sj, doc = by_sheet[res]
        for row in doc["assets"]:
            row["notes"] = _strip_check(row.get("notes", ""))
        doc["check_notes"] = []
        for sid, region in regs:
            expect = WIRED_KINDS.get(sid)
            if expect is None:
                print(f"SKIP {sid}: not in WIRED_KINDS")
                continue
            total += 1
            best, ratio = best_slice(doc["assets"], region)
            got = best.get("label_kind", "") if best and ratio >= 0.5 else ""
            confusion[(expect, got or "(none)")] += 1
            if got == expect:
                hits += 1
                continue
            msg = f"{CHECK_TAG} wired {sid} expects {expect}, got {got or 'no overlapping slice'}"
            misses.append(f"{sid}: {expect} -> {got or 'no overlapping slice'}  [{res}]")
            if ratio >= 0.5:
                best["notes"] = (best["notes"] + " " + msg).strip()
            else:
                doc["check_notes"].append(msg)
        sj.write_text(json.dumps(doc, indent=1) + "\n", encoding="utf-8")
    print("expected -> labeled : count")
    for (expect, got), n in sorted(confusion.items()):
        print(f"  {expect:12s} -> {got:12s} : {n}")
    for m in misses:
        print("MISS " + m)
    print(f"excluded {len(excluded)} wired regions on unsliced sheets" + (": " + ", ".join(excluded) if excluded else ""))
    rate = hits / total if total else 1.0
    print(f"agreement {hits}/{total} = {rate * 100:.1f}% (threshold {threshold * 100:.0f}%)")
    return 0 if rate >= threshold else 1


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("command", choices=("export", "import", "check"))
    ap.add_argument("--assets-root", type=Path, default=ROOT / "potential_assets")
    ap.add_argument("--game-root", type=Path, default=ROOT / "wandering_inn_game")
    ap.add_argument("--answers", type=Path, help="import: directory of per-page answer JSON files")
    ap.add_argument("--page-size", type=int, default=40)
    ap.add_argument("--threshold", type=float, default=0.9)
    args = ap.parse_args(argv)
    assets_root = args.assets_root.resolve()
    if args.command == "export":
        export(assets_root, args.page_size)
        return 0
    if args.command == "import":
        if not args.answers:
            ap.error("import needs --answers DIR")
        return import_labels(assets_root, args.answers)
    return check(assets_root, args.game_root, args.threshold)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /private/tmp/wi-607-b && python3 -m pytest -q scripts/tests/test_label_slices.py scripts/tests/test_slice_atlases.py scripts/tests/test_asset_candidates.py scripts/tests/test_asset_index.py`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
cd /private/tmp/wi-607-b
git add tools/label_slices.py scripts/tests/test_label_slices.py
git commit -m "label_slices: agreement check against wired sprites.json regions (#607)

Containment overlap (>= 0.5 of the smaller box) matches a wired region to
its slice; misses land in SLICES.json notes; unsliced sheets are excluded,
not failed.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: run on the real pool, label, check ≥ 90%, regenerate the docs, gates

**Files:**
- Regenerate: `docs/asset-candidates.json`, `docs/asset-candidates.md`, `docs/asset-index.json`, `docs/asset-index.md`
- Untracked outputs: `potential_assets/*/_sliced/**`, `potential_assets/_sliced_task.json`, answers under `/private/tmp/wi-607-b-labels/`

**Interfaces:**
- Consumes: every tool above.
- Produces: the Phase 0 Lane B exit evidence (slice count, agreement line, `find_asset.py crate` slice rows, green gates).

- [ ] **Step 1: Slice the real pool**

Run:
```bash
cd /private/tmp/wi-607-b
test -e potential_assets || ln -s /Users/gabriel/wandering-inn-rpg/potential_assets potential_assets
python3 tools/slice_atlases.py
```
Expected: 33 `  N slices  grid=…` lines (one per unique sheet; the Fairy Forest `Tree.png` is the slowest at ~1–2 s) and a final `sliced 33 sheets (29 duplicates skipped) -> 1262 slices; component …, grid16 …, seam …` (±20; the planner measured 1,262 with the extracted plan code). If the Furniture crate trio is fused (Task 3 Step 5), re-run with `--split Furniture:736,73,16,23 --split Furniture:752,74,16,22` and note the override in the PR.

- [ ] **Step 2: Export the labeling pages**

Run: `python3 tools/label_slices.py export`
Expected: `exported ~45 pages for ~1260 slices -> …/potential_assets/_sliced_task.json` (33 sheets, the big ones paged at 40).

- [ ] **Step 3: Dispatch the vision agent (controller step)**

The controller (not the implementer) runs one fresh vision-capable subagent per page, in batches of up to 5 concurrent pages. For each page `p` in `potential_assets/_sliced_task.json`, the prompt is `label_slices.PROMPT_TEMPLATE.format(page=p["page"], png_2x=<absolute path>, png_1x=<absolute path>, numbers="<first>-<last>")`; the agent may Read only those two PNGs. Save each answer verbatim as `/private/tmp/wi-607-b-labels/<page with / replaced by __>.json`. A helper prints every prompt:

```bash
python3 - <<'EOF'
import json, sys
sys.path.insert(0, "tools")
import label_slices as ls
task = json.load(open("potential_assets/_sliced_task.json"))
for p in task["pages"]:
    nums = list(p["numbers"])
    print("=== " + p["page"])
    print(ls.PROMPT_TEMPLATE.format(page=p["page"], png_2x="/private/tmp/wi-607-b/" + p["png_2x"],
                                    png_1x="/private/tmp/wi-607-b/" + p["png_1x"], numbers=f"{nums[0]}-{nums[-1]}"))
EOF
```

Budget: ~45 pages × ~2.5k tokens of image+answer ≈ 110k tokens (spec §4.1 planned ~100k).

- [ ] **Step 4: Import and check**

Run:
```bash
python3 tools/label_slices.py import --answers /private/tmp/wi-607-b-labels
python3 tools/label_slices.py check
```
Expected: `imported ~1260 labels into 33 SLICES.json files`, then the confusion table, `excluded 14 wired regions on unsliced sheets: …`, and `agreement N/44 = ≥90.0% (threshold 90%)` with exit 0 (so at most 4 misses). If it is under 90%: read the `MISS` lines; a wrong label on a correctly cut slice is re-asked for that page only (re-dispatch Step 3 for those pages, re-import); a miss of the form `no overlapping slice` is a cut problem — add a `--split` for that region, re-run Step 1 (labels survive), re-export only changes page numbering for that sheet, so re-label that sheet's pages. Record every override and re-ask in the PR body. Do not lower `--threshold`.

- [ ] **Step 5: Regenerate the registry and the index**

Run:
```bash
python3 tools/asset_candidates.py
python3 tools/asset_index.py --keep-notes
git status --short docs/
```
Expected: `~N rows from ~55 owned batches + sprites.json -> docs/asset-candidates.json` (≈1100 more rows than before), `indexed 1xxx PNGs across 61 packs` (same count as on main, because `_sliced/` is excluded), and only the four `docs/asset-*` files modified.

- [ ] **Step 6: Verify the query path**

Run: `python3 tools/find_asset.py crate --tier pack`
Expected: at least one row like
```
UNREVIEWED      pack-bundle      prop        16x23  potential_assets/Pixel Crawler - Free Pack/_sliced/Furniture/Furniture__x736_y73_w16_h23.png
                                                    targets=crate  potential_assets/Pixel Crawler - Free Pack/_sliced/Furniture/SLICES.json  region=736,73,16,23 of Furniture.png  bundled=res://assets/props/free_pack/Furniture.png
```
and the trailing `-- k of n matches` with n ≥ 1 (exit 0). Also run `python3 tools/find_asset.py crate` (no tier) and confirm shipped/owned rows still rank first.

- [ ] **Step 7: Gates**

Run, each on its own, preserving exit codes:
```bash
python3 -m pytest -q scripts/tests
scripts/leak_check.sh
python3 scripts/comment_census.py --check
git status --short
```
Expected: pytest `… passed` with 0 failed; `leak_check: clean (manifest paths, key files, potential_assets all untracked)`; comment census green; `git status` shows only the four `docs/asset-*` files (the `potential_assets` symlink is ignored).

- [ ] **Step 8: Commit and update HANDOFF**

```bash
cd /private/tmp/wi-607-b
git add docs/asset-candidates.json docs/asset-candidates.md docs/asset-index.json docs/asset-index.md
git commit -m "docs: asset registry with Pixel Crawler atlas slices (#607)

33 unique prop atlases sliced into ~1260 labeled pack-bundle candidates;
label agreement N/44 on the wired regions. potential_assets stays untracked.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Then add to `HANDOFF.md` (Lane B section; the controller merges it at composition): branch `issue/607-lane-b`, the slice and agreement counts, every `--split` override used, and the exact re-run order (`slice_atlases.py` → `label_slices.py export` → agent → `import` → `check` → `asset_candidates.py` → `asset_index.py --keep-notes`).

---

## Self-review

**Spec coverage (§4.1):** skip strips/tilesets (Task 2 `eligible`, measured); grid-first (Task 1 `sheet_grid`, Task 3 grid expansion); packed sheets split on outline seams not alpha (Task 1 `seams` + #398 test); `--split` overrides recorded per slice (Task 3); sha256 dedupe with Free Pack/2.1 (Task 2, Task 3 CLI test); `has_shadow` (Task 1/3); outputs as trimmed PNG + SLICES.json in MANIFEST schema + numbered contact sheet, stable key (sha, x, y, w, h) (Task 3); vision labeling with closed vocabulary, size class and confidence, ~55 wired regions as the accuracy check, labels in `targets` (Tasks 5–6, 7); `asset_candidates` `_sliced/` as `pack-bundle` via `pack_family`, `asset_index` exclusion, `find_asset` surfaces region + bundled sheet (Task 4); `bundled`/`game_sheet` for Lane C's `wire_asset` (Task 3). Phase 0 exit "≥90% kind agreement, every miss listed in SLICES.json notes" is Task 7 Step 4.

**Contract ambiguities resolved (recorded for the controller):**
1. C8 `targets` holds the label kind first, then wired sprite ids; the kind also lives in `label_kind` so the check never has to parse `targets`.
2. `size_class` is measured from the region (S ≤16, M ≤32, L ≤64, XL), never taken from the agent; the agent supplies kind + confidence only.
3. `has_shadow` means baked semi-transparent pixels in the slice; `Shadows.png` sheets are generic blob atlases (byte-identical across packs), not per-prop overlays, and are skipped.
4. `Stations/` and `Assets/Tiles.png`-style mixed sheets are skipped in v1 (animation frames / terrain); the 5 wired regions on tiles sheets and the 2 on `Building_Walls/Roofs` are excluded from the check denominator (44 remain).
5. Agreement matching uses containment overlap (`inter / min(area) ≥ 0.5`, largest slice on ties) because raw IoU matched only 22/44 wired regions (wired boxes are 16-cells around small sprites or sub-regions of fused components).
6. Dedupe keeps the first pack in sorted order (`Pixel Crawler - Free Pack`, not `2.1`, although the game syncs from 2.1); `duplicate_sheets` records the other path, and `game_sheet` comes from sha so it does not matter which copy was sliced.
7. Extra row keys beyond C8 (`label_kind`, `bundled`, `game_sheet`, `wired_ids`, `duplicate_sheets`) and top-level `grid`, `overrides`, `check_notes`, `sheet`, `sheet_sha256` are additive.
8. Other packs (Admurin, Cute Fantasy, Ninja, Pixel_16_interiors) are out of v1 scope: the catalog calls none of them a prop atlas with confirmed grid; `PACK_PREFIXES` is the single place to widen.
9. The worktree reaches `potential_assets/` through a gitignored symlink; no `--assets-root` plumbing is added to `asset_index.py` beyond the testable `build(assets)` parameter.
10. `_sliced/<stem>` uses the bare file stem unless the parent folder is non-generic (`Trees/Model_01/Size_02.png` → `Model_01_Size_02`), because three `Size_02.png` sheets share one pack; a residual collision still gets the `-<sha8>` suffix.
11. `MIN_AREA` is 32 px of alpha, not the brief's 40, because the wired `pebble` is a 32 px component and the spec's accuracy check needs every wired region to have a slice.
12. The check's 90% bar applies to the 44 wired regions on sliced sheets; `pallass_rail_post`, `library_*`, `garden_fountain_*`, `dungeon_*`, `chest*`, `sconce`, `campfire`, `grill`, `facade_plaster` and `inn_roof` are on skipped sheets and are reported as excluded.
13. Seam constants were tuned on the real sheets: `FLANK_FRAC` 0.5 left the #398 crate and barrel fused (the barrel's curved edge is 75% dark in its second column), 0.9 splits them; `SEAM_MAX_H` 64 stops the same rule from cutting trees (Fairy `Tree.png` 30 → 4 cuts).

**Placeholder scan:** none. **Type consistency:** `overlap_ratio` takes `[x, y, w, h]` everywhere (`region`, wired region, `_xywh(box)`); `components`/`split_box`/`cell_box` use `[x0, y0, x1, y1]`; `render_contact(crops, out, scale, start)` matches both callers; `SLICE_KEYS` in Task 4 equals the extra keys written in Task 3. **Review Focus:** each of the five lines is pinned by the named test in its owning task.
