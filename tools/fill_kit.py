#!/usr/bin/env python3
"""Fill a kit role from the asset pool (regional kits spec §4.2 steps 1-3, 6-7; C9).

  python3 tools/fill_kit.py <region> <role> --need N [--kind <tag>] [--size S|M|L|XL]
        [--contact-sheet out.png] [--select 1,3,…] [--ids a,b,…] [--pick cell|map|door]
        [--module] [--fallback <owned_id>] [--lacked "text"] [--base <sprite_id>]
        [--limit N] [--preview] [--repo-root DIR]

Pool first. Candidates come from docs/asset-candidates.json: owned PixelLab
rows (tier owned-public) and lane B's atlas slices (tier pack-bundle, rows
under _sliced/ beside SLICES.json). Filters: kind prop|setpiece, verdict !=
REJECTED, --kind words must match targets/path/prompt/notes
(find_asset.score), slices must resolve to a bundled sheet (else printed as
skip), byte-identical files collapse by sha256, size class must match the
role's existing pool (or --size). Survivors are numbered; --contact-sheet
renders them at gameplay scale (2x on top, 1x below) beside the region's
material swatches from data/kits.json.

--select wires the numbered picks through tools/wire_asset.py (ids
<region>_<role>_<n> unless --ids), appends them to data/kits.json
<region>.roles.<role>.pool with a surgical splice (a new role gets --pick,
default cell, and --module), and on a shortfall (selected < --need) writes one
open row to docs/art-generation-list.md. --preview prints the picks every map
of the region resolves to, through scripts/wi_kits_lib.resolve_map (lane A).
Step 4 of the spec, the pool art-direction read, happens between the contact
sheet and --select and is a Fable read, not code. This tool never calls
PixelLab.

Size classes are rendered gameplay height: S <= 12px, M <= 24, L <= 48, XL
above. Owned candidates use bbox height x the pool's first member's
render_scale (DEFAULT_SCALE when the pool is empty); slices use region height.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
sys.path.insert(0, str(REPO_ROOT / "wandering_inn_game" / "scripts"))
import asset_candidates as ac  # noqa: E402
import find_asset as fa  # noqa: E402
import splice_json  # noqa: E402
import wire_asset as wa  # noqa: E402

EXIT_OK, EXIT_USAGE = 0, 2
SIZE_CLASSES = ("S", "M", "L", "XL")
CELL = 72        # contact-sheet cell edge, px
SWATCH_H = 52    # material swatch strip height (32px tile + label)
GENERATION_LIST_HEADER = """# Art generation list (living)

Rows are PixelLab generation requests the asset pool could not fill. Nothing
here is generated until the user approves a batch (regional kits spec §4.3,
Phase 3). `tools/fill_kit.py` appends a row when a role's selection falls short
of `--need`; `what the pool lacked` is the `--lacked` text the selecting agent
wrote after the pool read.

Insertion: tail — append rows at the end; one open row per (region, role) is
updated in place; a row closes by setting status to `done <sprite ids>` in the
batch PR, never by deletion.

Columns: region · role · have (ids already in the pool) · need (target pool
size) · what the pool lacked · base sprite (existing sprite id to derive
PixelLab object-state variants from) · status (`open` | `done <ids>` | `dropped`).

| region | role | have (ids) | need | what the pool lacked | base sprite | status |
|---|---|---|---|---|---|---|
"""


def size_class(rendered_h: float) -> str:
    if rendered_h <= 12:
        return "S"
    if rendered_h <= 24:
        return "M"
    if rendered_h <= 48:
        return "L"
    return "XL"


@dataclass
class Candidate:
    n: int
    row: dict
    path: Path
    mode: str                 # "owned" | "pack"
    sha: str
    scale: float              # render_scale the wired entry would get
    frame_w: int              # first-frame width (strip frame for owned, region w for pack)
    rendered_h: float
    size_class: str
    sheet: str | None         # bundled game sheet, pack only
    region: list[int] | None  # [x, y, w, h], pack only


def kits_path(paths: wa.Paths) -> Path:
    return paths.game / "data" / "kits.json"


def load_kits_text(paths: wa.Paths) -> tuple[str, dict]:
    p = kits_path(paths)
    if not p.is_file():
        raise wa.Refused(f"{p} missing (lane A ships it with _common)")
    text = p.read_text(encoding="utf-8")
    return text, json.loads(text)


def role_pool_ids(kits: dict, region: str, role: str) -> list[str]:
    spec = ((kits.get(region) or {}).get("roles") or {}).get(role)
    if spec is None:
        return []
    if isinstance(spec, str):
        return [spec]
    return [p[0] if isinstance(p, list) else p for p in spec.get("pool", [])]


def entry_rendered_h(entry: dict) -> float:
    idle = (entry.get("animations") or {}).get("idle") or {}
    h = idle["region"][3] if idle.get("region") else idle["frame_size"][1]
    return float(h) * float(entry.get("render_scale", 1.0))


def query(paths: wa.Paths, kind: str | None, scale: float) -> list[Candidate]:
    reg = paths.docs / "asset-candidates.json"
    if not reg.is_file():
        raise wa.Refused("docs/asset-candidates.json missing; run python3 tools/asset_candidates.py")
    rows = json.loads(reg.read_text(encoding="utf-8"))["assets"]
    terms = sorted(fa.words(kind)) if kind else []
    out: list[Candidate] = []
    seen: set[str] = set()
    for row in rows:
        if row.get("kind") not in ("prop", "setpiece") or row.get("verdict") == "REJECTED":
            continue
        if row.get("tier") not in ("owned-public", "pack-bundle"):
            continue
        if terms and not fa.score(row, terms, "_".join(terms)):
            continue
        path = (paths.repo_root / row["path"]).resolve()
        if not path.is_file():
            continue
        sha = wa.sha256_file(path)
        if sha in seen:
            continue
        if wa.is_slice(path):
            srow = wa.slice_row(path, paths)
            sheet = (wa.hinted_sheet(srow.get("game_sheet") or row.get("game_sheet"), srow["sheet_sha256"], paths)
                     or wa.bundled_sheet_for(srow["sheet_sha256"], paths))
            if sheet is None:
                print(f"skip (bundle-pending {srow['source_sheet']}): {row['path']}")
                continue
            region = [int(v) for v in srow["region"]]
            cand = Candidate(0, row, path, "pack", sha, 1.0, region[2], float(region[3]),
                             size_class(region[3]), sheet, region)
        elif row.get("tier") == "pack-bundle":
            continue  # a pack file that is not a slice: never wired loose
        else:
            try:
                with Image.open(path) as img:
                    w, h = img.size
                fw, _fh, _n = wa.frame_geometry(w, h, wa.manifest_row(path, paths).get("frame_size"))
                pr = wa.probe(path, fw)
            except wa.ProbeError as exc:
                print(f"skip (probe: {exc}): {row['path']}")
                continue
            rendered = (pr["bbox"][3] - pr["bbox"][1]) * scale
            cand = Candidate(0, row, path, "owned", sha, scale, fw, rendered, size_class(rendered), None, None)
        seen.add(sha)
        out.append(cand)
    out.sort(key=lambda c: (ac.VERDICT_RANK.get(c.row.get("verdict"), 99),
                            fa.TIER_RANK.get(c.row.get("tier"), 99), c.row["path"]))
    return out


def compatible(cands: list[Candidate], member_classes: set[str], want: str | None) -> list[Candidate]:
    allowed = {want} if want else member_classes
    if not allowed:
        return list(cands)
    return [c for c in cands if c.size_class in allowed]


def number(cands: list[Candidate]) -> list[Candidate]:
    for i, c in enumerate(cands, 1):
        c.n = i
    return cands


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("region")
    ap.add_argument("role")
    ap.add_argument("--need", type=int, default=4)
    ap.add_argument("--kind", help="kind tag / use words, e.g. crate")
    ap.add_argument("--size", choices=SIZE_CLASSES)
    ap.add_argument("--contact-sheet", type=Path)
    ap.add_argument("--select", help="comma-separated numbers from the listing")
    ap.add_argument("--ids", help="comma-separated sprite ids for --select (default <region>_<role>_<n>)")
    ap.add_argument("--pick", choices=("cell", "map", "door"), default="cell")
    ap.add_argument("--module", action="store_true")
    ap.add_argument("--fallback", help="owned public sprite id for pack picks")
    ap.add_argument("--lacked", default="", help="what the pool lacked (generation-list column)")
    ap.add_argument("--base", help="base sprite for PixelLab object-state variants")
    ap.add_argument("--limit", type=int, default=48)
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    args = ap.parse_args(argv)
    paths = wa.Paths(args.repo_root)
    try:
        if args.preview:
            return preview(paths, args.region, args.role)
        return fill(args, paths)
    except (wa.Refused, wa.ProbeError) as exc:
        print(str(exc))
        return exc.exit_code


def fill(args: argparse.Namespace, paths: wa.Paths) -> int:
    _text, catalog = wa.load_catalog(paths)
    ktext, kits = load_kits_text(paths)
    pool = role_pool_ids(kits, args.region, args.role)
    members = {size_class(entry_rendered_h(catalog[i])) for i in pool if isinstance(catalog.get(i), dict)}
    like = next((i for i in pool if isinstance(catalog.get(i), dict)), None)
    scale = float(catalog[like].get("render_scale", wa.DEFAULT_SCALE["owned"])) if like else wa.DEFAULT_SCALE["owned"]
    cands = number(compatible(query(paths, args.kind, scale), members, args.size)[: args.limit])
    for c in cands:
        print(f"#{c.n:<3} {c.size_class:<2} {c.mode:<5} {c.row.get('verdict', ''):<15} {c.row['path']}")
    print(f"-- {len(cands)} candidates for {args.region}/{args.role} (have {len(pool)}, need {args.need})")
    if args.contact_sheet:
        render_contact_sheet(cands, material_swatches(kits, args.region, paths), args.contact_sheet)
        print(f"contact sheet: {args.contact_sheet}")
    if not args.select:
        return EXIT_OK
    return select(args, paths, cands, ktext, catalog, pool, like)


def preview(paths: wa.Paths, region: str, role: str) -> int:
    raise wa.Refused("preview lands with lane A's wi_kits_lib (Task 12)")


def select(args, paths, cands, ktext, catalog, pool, like) -> int:
    raise wa.Refused("--select lands in Task 11")


def render_contact_sheet(cands, materials, out: Path) -> None:
    raise wa.Refused("--contact-sheet lands in Task 10")


def material_swatches(kits: dict, region: str, paths: wa.Paths) -> list:
    raise wa.Refused("--contact-sheet lands in Task 10")


if __name__ == "__main__":
    sys.exit(main())
