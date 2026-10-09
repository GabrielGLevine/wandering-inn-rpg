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
  4. write _sliced/<pack>/<stem>/<stem>__x{X}_y{Y}_w{W}_h{H}.png, SLICES.json
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

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "wandering_inn_game" / "scripts"))
import wi_kits_lib as kl  # noqa: E402

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
KINDS = kl.KINDS  # the closed vocabulary, shared with data_lint's _common kind rule
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
