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


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    default_root = ROOT / "potential_assets"
    ex = sub.add_parser("export")
    ex.add_argument("--assets-root", type=Path, default=default_root)
    ex.add_argument("--page-size", type=int, default=40)
    im = sub.add_parser("import")
    im.add_argument("--assets-root", type=Path, default=default_root)
    im.add_argument("--answers", type=Path, required=True)
    args = ap.parse_args(argv)
    if args.cmd == "export":
        export(args.assets_root, args.page_size)
        return 0
    return import_labels(args.assets_root, args.answers)


if __name__ == "__main__":
    sys.exit(main())
