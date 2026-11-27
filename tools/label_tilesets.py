#!/usr/bin/env python3
"""Label every registered tileset with closed-vocabulary material words,
through a controller-dispatched vision agent (#624). The tileset sibling of
tools/label_slices.py: tilesets carried no material words, so a pool read
asking for brick or plank never found them.

  export  one page per kind-tileset row of docs/asset-candidates.json: the
          sheet at 2x (1x when 2x would pass MAX_PAGE_PX) on mid-grey with a
          16px grid, the tile part of a mixed sheet outlined in yellow, and
          TASK.json in --out listing every page with its filled prompt
  import  merge the agent's JSON answers (one file per page, any name) into
          potential_assets/_sliced/TILESET_LABELS.json; the next
          tools/asset_candidates.py run copies them into material_labels,
          which tools/find_asset.py matches like targets

The agent sees only the exported pages, never the pack folders. An answer
naming a material outside MATERIALS, or a confidence outside 0..1, refuses
the whole import and writes nothing.

Usage:
  python3 tools/label_tilesets.py export [--registry FILE] [--assets-root DIR] [--out DIR]
  python3 tools/label_tilesets.py import --answers DIR [--task FILE] [--assets-root DIR]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asset_candidates as ac  # noqa: E402

ROOT = ac.ROOT
MATERIALS = ("brick", "sandstone", "marble", "limestone", "cobble", "flagstone", "plank", "parquet",
             "carpet", "plaster", "timber", "stone", "dirt", "grass", "sand", "water", "roof_tile",
             "shingle", "metal", "other")
MAX_PAGE_PX = 2048
GRID = 16
TASK_NAME = "TASK.json"
DEFAULT_OUT = ROOT / "potential_assets" / "_sliced" / "_tileset_labels"

PROMPT_TEMPLATE = """You are labeling the surface materials of a pixel-art tileset from a top-down game asset pack.
Read the image {png}: {sheet} ({w}x{h} px) at {scale}x zoom on a grey background. Thin dark lines mark the 16px tile grid.{regions_note}

Name every surface material its tiles depict, choosing ONLY from this closed list:
{vocab}

Guidance:
- brick = fired clay bricks laid in courses; sandstone = warm tan or yellow cut stone; marble = polished pale
  stone with veining; limestone = pale cream or grey dressed block; cobble = rounded set stones;
  flagstone = large flat paving slabs; stone = rough rock or grey masonry that fits none of those;
- plank = wooden floor boards; parquet = patterned wood floor; timber = beams, log or half-timbered walls;
  carpet = rugs and woven floor coverings; plaster = smooth rendered wall;
- dirt, grass, sand, water = natural ground and water; roof_tile = clay or slate roof tiles;
  shingle = wooden roof shingles; metal = metal plates, grates and pipes;
- other = a material none of these fit (lava, ice, crystal, hedge, ...).
List each material once, most prominent first, and skip materials that cover only a few pixels.
Confidence is 0.0-1.0 for how sure you are the material is there.

Answer with ONLY this JSON (no prose):
{{"page": "{page}", "materials": {{"stone": 0.9, "plank": 0.6}}}}
"""


def tileset_rows(registry: Path) -> list[dict]:
    rows = json.loads(registry.read_text(encoding="utf-8")).get("assets", [])
    return [r for r in rows if r.get("kind") == "tileset" and r.get("path", "").startswith("potential_assets/")
            and not r["path"].endswith("/")]


def render_page(sheet: Image.Image, regions: list[list[int]], scale: int) -> Image.Image:
    w, h = sheet.size
    page = Image.new("RGBA", (w * scale, h * scale), (107, 107, 107, 255))
    page.alpha_composite(sheet.resize((w * scale, h * scale), Image.NEAREST))
    grid = Image.new("RGBA", page.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(grid)
    for x in range(0, w + 1, GRID):
        d.line([(x * scale, 0), (x * scale, h * scale)], fill=(0, 0, 0, 70))
    for y in range(0, h + 1, GRID):
        d.line([(0, y * scale), (w * scale, y * scale)], fill=(0, 0, 0, 70))
    for rx, ry, rw, rh in regions:
        d.rectangle([rx * scale, ry * scale, (rx + rw) * scale - 1, (ry + rh) * scale - 1],
                    outline=(255, 220, 0, 255), width=2)
    page.alpha_composite(grid)
    return page


def slug(path: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", path[len("potential_assets/"):]).strip("_")


def export(registry: Path, assets_root: Path, out: Path) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    pages = []
    for i, row in enumerate(sorted(tileset_rows(registry), key=lambda r: r["path"]), 1):
        src = assets_root / Path(row["path"]).relative_to("potential_assets")
        if not src.is_file():
            print(f"WARN missing {row['path']}")
            continue
        sheet = Image.open(src).convert("RGBA")
        w, h = sheet.size
        scale = 2 if max(w, h) * 2 <= MAX_PAGE_PX else 1
        regions = row.get("tile_regions", []) if row.get("layout") == "mixed" else []
        png = out / f"{i:03d}_{slug(row['path'])}.png"
        render_page(sheet, regions, scale).save(png)
        note = (" Yellow boxes outline the tile part; the loose sprites outside them are props, ignore those."
                if regions else "")
        pages.append({
            "page": row["path"], "png": str(png), "sheet": row["path"],
            "sheet_sha256": row.get("sheet_sha256", ""), "scale": scale, "w": w, "h": h,
            "tile_regions": regions,
            "prompt": PROMPT_TEMPLATE.format(png=png, sheet=row["path"], w=w, h=h, scale=scale,
                                             regions_note=note, vocab=" ".join(MATERIALS),
                                             page=row["path"]),
        })
    task = {"materials": list(MATERIALS), "answer_dir_note": "one JSON answer per page, any file name",
            "pages": pages}
    (out / TASK_NAME).write_text(json.dumps(task, indent=1) + "\n", encoding="utf-8")
    print(f"exported {len(pages)} tileset pages -> {out / TASK_NAME}")
    return task


def import_labels(assets_root: Path, answers_dir: Path, task_path: Path) -> int:
    if not task_path.exists():
        print(f"no {task_path}; run export first")
        return 2
    pages = {p["page"]: p for p in json.loads(task_path.read_text(encoding="utf-8"))["pages"]}
    pending: dict[str, dict] = {}
    errors = []
    for ans in sorted(answers_dir.glob("*.json")):
        try:
            data = json.loads(ans.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{ans.name}: not JSON ({exc})")
            continue
        page = pages.get(data.get("page", ""))
        mats = data.get("materials")
        if page is None:
            errors.append(f"{ans.name}: unknown page {data.get('page')!r}")
            continue
        if not isinstance(mats, dict) or not mats:
            errors.append(f"{ans.name}: no materials")
            continue
        for m, conf in mats.items():
            if m not in MATERIALS:
                errors.append(f"{ans.name}: unknown material {m!r}")
            elif not isinstance(conf, (int, float)) or not 0.0 <= conf <= 1.0:
                errors.append(f"{ans.name}: confidence {conf!r} for {m} is not in 0..1")
        order = sorted(mats, key=lambda m: (-float(mats[m]) if isinstance(mats[m], (int, float)) else 0,
                                            MATERIALS.index(m) if m in MATERIALS else 99))
        pending[page["sheet"]] = {"material_labels": order,
                                  "material_confidence": {m: mats[m] for m in order},
                                  "sheet_sha256": page.get("sheet_sha256", "")}
    if errors:
        print("\n".join(errors))
        print(f"import refused: {len(errors)} invalid answers, nothing written")
        return 2
    path = assets_root / "_sliced" / ac.LABELS_NAME
    labels = ac.tileset_labels(assets_root)
    labels.update(pending)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"schema": 1, "labels": dict(sorted(labels.items()))}, indent=1) + "\n",
                    encoding="utf-8")
    print(f"imported material labels for {len(pending)} tilesets -> {path}; "
          "run python3 tools/asset_candidates.py to carry them into the registry")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    ex = sub.add_parser("export")
    ex.add_argument("--registry", type=Path, default=ROOT / "docs" / "asset-candidates.json")
    ex.add_argument("--assets-root", type=Path, default=ROOT / "potential_assets")
    ex.add_argument("--out", type=Path, default=DEFAULT_OUT)
    im = sub.add_parser("import")
    im.add_argument("--answers", type=Path, required=True)
    im.add_argument("--task", type=Path, default=DEFAULT_OUT / TASK_NAME)
    im.add_argument("--assets-root", type=Path, default=ROOT / "potential_assets")
    args = ap.parse_args(argv)
    if args.cmd == "export":
        export(args.registry, args.assets_root, args.out)
        return 0
    return import_labels(args.assets_root, args.answers, args.task)


if __name__ == "__main__":
    sys.exit(main())
