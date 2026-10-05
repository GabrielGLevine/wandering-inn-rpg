#!/usr/bin/env python3
"""Build the use-case-keyed asset candidates registry.

`docs/asset-index.*` answers "what files does pack X contain" and
`docs/asset-catalog.md` answers "which pack fits". Neither knows about the
GENERATED batches (PixelLab/Codex) or what is already wired, so finding "the
best owned crate" meant grepping ~20 differently shaped manifests. This tool
folds every source into one registry keyed by what an asset is FOR:

  - owned batches under potential_assets/ (pixellab_*, codex_*, and nested
    lanes such as pixellab_harvest_2026-10/L2_props/), read from
      1. MANIFEST.json  (the standard schema below; preferred),
      2. MANIFEST.md    (markdown tables with a file/path column),
      3. manifest.json  (2026-07 legacy {"jobs": {...}} shape),
      4. the file listing (UNREVIEWED; PixelLab rig dirs collapse to one row);
  - every data/sprites.json record (verdict SHIPPED), tiered by whether its
    sheets are bundle-only in assets_manifest.json.

Third-party pack files are NOT duplicated here: tools/find_asset.py searches
docs/asset-index.json for those at query time.

Outputs (text only, safe to commit; the PNGs stay gitignored):
  docs/asset-candidates.json  machine-readable registry
  docs/asset-candidates.md    counts by kind/tier/batch + how to query

Standard MANIFEST.json (write one for every NEW generation batch):
  {"schema": 1, "source": "pixellab", "tier": "owned-public",
   "family": "PIXELLAB-AI", "assets": [
     {"path": "crate.png",            # relative to the batch dir; a dir = rig
      "kind": "prop",                 # see KINDS
      "targets": ["crate"],           # game ids / use tags this serves
      "verdict": "READY",             # see VERDICTS
      "pixellab_id": "...", "prompt": "...", "notes": "...",
      "anchor_feet": 47,              # optional, rigs: lowest opaque row
      "contact_sheet": "sheets/a.png"}]}

Usage:
  python3 tools/asset_candidates.py                    # rebuild registry
  python3 tools/asset_candidates.py --write-manifests  # also convert legacy
                                                       # batches to MANIFEST.json
  python3 tools/asset_candidates.py --assets-root DIR  # e.g. from a worktree
"""
from __future__ import annotations

import argparse
import json
import os
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = 1
KINDS = ("icon", "prop", "setpiece", "rig", "tileset", "ui", "keyart", "image", "audio", "other")
VERDICTS = ("SHIPPED", "READY", "USABLE-WITH-FIX", "ALT", "UNREVIEWED", "SUPERSEDED", "REJECTED")
VERDICT_RANK = {v: i for i, v in enumerate(VERDICTS)}
IMAGE_EXT = {".png", ".gif", ".webp", ".jpg", ".jpeg"}
AUDIO_EXT = {".ogg", ".wav", ".mp3"}
MAX_PROMPT = 160
MAX_NOTES = 200

# Header-cell substrings -> registry field (first match wins, checked in order).
HEADER_FIELDS = (
    ("path", ("file", "path")),
    ("pixellab_id", ("pixellab id", "object id")),
    ("targets", ("target", "use", "need")),
    ("prompt", ("prompt",)),
    ("verdict", ("verdict", "pick")),
    ("notes", ("notes", "why")),
)


# ---------------------------------------------------------------- helpers

def png_size(path: Path) -> tuple[int, int] | None:
    try:
        with path.open("rb") as f:
            head = f.read(24)
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", head[16:24])


def clip(text: str | None, n: int) -> str:
    text = re.sub(r"\s+", " ", (text or "")).strip()
    return text if len(text) <= n else text[: n - 1] + "…"


def normalize_verdict(raw: str | None) -> str:
    s = (raw or "").upper()
    for key, verdict in (("REJECT", "REJECTED"), ("SUPERSEDED", "SUPERSEDED"),
                         ("USABLE", "USABLE-WITH-FIX"), ("READY", "READY"),
                         ("SHIPPED", "SHIPPED"), ("WIRED", "SHIPPED")):
        if key in s:
            return verdict
    if re.search(r"\bALT\b", s):
        return "ALT"
    if re.search(r"\*\*V\d\*\*|\bPICK(ED)?\b", s):
        return "READY"
    return "UNREVIEWED"


UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")


def stem_target(path: str) -> str:
    parts = [p for p in Path(path.rstrip("/")).parts if not UUID_RE.fullmatch(p)]
    stem = parts[-1] if parts else ""
    stem = Path(stem).stem if "." in stem else stem
    stem = re.sub(r"(__alt\d*|_alt\d*|_v\d+|_\d+px|_(?:16|24|32|48|64|96|128|256)"
                  r"|__after|__before|_after|_before)+$", "", stem)
    return stem


def extract_targets(cell: str, path: str) -> list[str]:
    # Only the FIRST backticked id is the target: later ones are context
    # ("`camp_carry_yoke` borrows bundle `crate`"), and stay searchable in notes.
    found = [t.strip() for t in re.findall(r"`([^`]+)`", cell or "")]
    found = [t for t in found if re.fullmatch(r"[a-z0-9_]+", t)][:1]
    stem = stem_target(path)
    if stem and stem not in found:
        found.append(stem)
    return list(dict.fromkeys(found))


def infer_kind(batch: str, path: str, hint: str = "") -> str:
    p = f"{batch}/{path} {hint}".lower()
    ext = Path(path).suffix.lower()
    if ext in AUDIO_EXT:
        return "audio"
    rules = (
        ("icon", ("icon", "/skills", "/items/", "/classes/", "/status/", "l1_icons")),
        ("tileset", ("/tiles/", "tileset", "wang")),
        ("ui", ("/ui/", "ui_", "chrome", "9slice", "nine_slice", "button", "panel")),
        ("keyart", ("title_", "act_card", "act1", "act2", "act3", "act4", "act5",
                    "emblem", "capsule", "key_art", "keyart", "backdrop")),
        ("setpiece", ("set_piece", "setpiece")),
        ("rig", ("rig", "walks/", "l3a_", "l3b_", "/rotations", "/animations")),
    )
    for kind, needles in rules:
        if any(n in p for n in needles):
            return kind
    if path.endswith("/"):
        return "rig"
    if ext in IMAGE_EXT:
        return "prop"
    return "other"


PACK_FAMILIES = (  # docs/asset-catalog.md sec. 1 style families, by pack-name prefix
    ("Pixel Crawler", "PC16"), ("Pixel_16_interiors", "PC16-ADJACENT?"),
    ("goblin", "CUSTOM-HD"), ("Bat_Fur", "CUSTOM-HD"), ("Small_Bat", "CUSTOM-HD"),
    ("topdown_floor_tiles", "CUSTOM-HD"), ("Admurin", "ADMURIN"), ("Tiny Swords", "TS-CARTOON"),
    ("Ninja Adventure", "NINJA16"), ("Cute_Fantasy", "CUTE16"), ("Relc", "PIXELLAB-AI"),
)


def pack_family(pack: str) -> str:
    return next((fam for prefix, fam in PACK_FAMILIES if pack.startswith(prefix)), "")


def classify_batch(name: str) -> tuple[str, str, str]:
    """(source, tier, family) for an owned batch dir name."""
    low = name.lower()
    if low.startswith("codex"):
        # gpt-image outputs: user-owned, public redistribution not yet verified
        return "codex", "owned-unverified", "CODEX-HD"
    return "pixellab", "owned-public", "PIXELLAB-AI"


# ------------------------------------------------------------ md tables

def parse_md_tables(text: str) -> list[tuple[list[str], list[tuple[int, list[str]]]]]:
    """Return [(header_cells, [(line_no, cells), ...]), ...] for every table."""
    tables = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        nxt = lines[i + 1] if i + 1 < len(lines) else ""
        if line.lstrip().startswith("|") and re.fullmatch(r"\s*\|[\s:|-]+\|?\s*", nxt):
            header = split_row(line)
            rows = []
            j = i + 2
            while j < len(lines) and lines[j].lstrip().startswith("|"):
                rows.append((j + 1, split_row(lines[j])))
                j += 1
            tables.append((header, rows))
            i = j
        else:
            i += 1
    return tables


def split_row(line: str) -> list[str]:
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    # split on pipes not escaped and not inside backticks
    cells, buf, tick = [], [], False
    for ch_i, ch in enumerate(s):
        if ch == "`":
            tick = not tick
        if ch == "|" and not tick and (ch_i == 0 or s[ch_i - 1] != "\\"):
            cells.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
    cells.append("".join(buf).strip())
    return cells


def map_header(header: list[str]) -> dict[str, int]:
    mapping: dict[str, int] = {}
    for idx, cell in enumerate(header):
        low = cell.lower()
        for field, needles in HEADER_FIELDS:
            if field in mapping:
                continue
            if any(n in low for n in needles):
                mapping[field] = idx
                break
    return mapping


def clean_path_cell(cell: str) -> str:
    cell = cell.replace("`", "").strip()
    cell = re.split(r"\s+\(|\s+—\s+|\s+batch\s+\d", cell, maxsplit=1)[0].strip()
    return cell


def rows_from_markdown(batch_dir: Path, manifest: Path) -> list[dict]:
    text = manifest.read_text(encoding="utf-8", errors="replace")
    out: list[dict] = []
    for header, rows in parse_md_tables(text):
        cols = map_header(header)
        if "path" not in cols:
            continue
        for line_no, cells in rows:
            def cell(field: str) -> str:
                idx = cols.get(field)
                return cells[idx] if idx is not None and idx < len(cells) else ""
            raw_path = clean_path_cell(cell("path"))
            if not raw_path or not re.search(r"[./]", raw_path):
                continue
            for rel in expand_path(batch_dir, raw_path):
                pid = re.search(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}|\b[0-9a-f]{8}\b",
                                cell("pixellab_id"))
                out.append({
                    "path": rel,
                    "targets": extract_targets(cell("targets"), rel),
                    "verdict": normalize_verdict(cell("verdict")),
                    "pixellab_id": pid.group(0) if pid else "",
                    "prompt": clip(cell("prompt"), MAX_PROMPT),
                    "notes": clip(" ".join(x for x in (cell("targets"), cell("notes")) if x), MAX_NOTES),
                    "manifest_ref": f"{manifest.name}:{line_no}",
                })
    return out


def expand_path(batch_dir: Path, raw: str) -> list[str]:
    if "*" in raw:
        base = raw.split(" ")[0]
        hits = sorted(p for p in batch_dir.glob(base) if p.is_file())
        return [str(p.relative_to(batch_dir)) for p in hits]
    rel = raw.split(" ")[0] if not (batch_dir / raw).exists() else raw
    if (batch_dir / rel).is_dir() and not rel.endswith("/"):
        rel += "/"
    return [rel]


# ------------------------------------------------------- other readers

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
        out.append({k: v for k, v in row.items() if v not in ("", None, [])} | {"path": row["path"]})
    return out


def legacy_json_overlays(manifest: Path) -> list[dict]:
    """2026-07 shapes: {"jobs": {name: {file, params}}} or
    {"generations": [{name, params, result: {files}}]} -> overlays keyed by stem."""
    data = json.loads(manifest.read_text(encoding="utf-8"))
    entries = []
    if isinstance(data.get("jobs"), dict):
        entries = [dict(v, name=k) for k, v in data["jobs"].items() if isinstance(v, dict)]
    elif isinstance(data.get("generations"), list):
        entries = [g for g in data["generations"] if isinstance(g, dict)]
    out = []
    for e in entries:
        params = e.get("params") or {}
        prompt = (params.get("description") or params.get("upper_description")
                  or e.get("description") or "")
        files = [e.get("file")] if e.get("file") else (e.get("result") or {}).get("files") or []
        stems = {stem_target(Path(str(f).split(" (")[0]).name) for f in files if f}
        stems.add(e.get("name") or "")
        for stem in filter(None, stems):
            out.append({"stem": stem, "targets": [e.get("name")] if e.get("name") else [],
                        "prompt": clip(prompt, MAX_PROMPT),
                        "notes": clip(e.get("notes") or e.get("why"), MAX_NOTES),
                        "verdict": normalize_verdict(str(e.get("verdict") or e.get("pick") or "")),
                        "manifest_ref": manifest.name})
    return out


def keyed_table_overlays(manifest: Path) -> list[dict]:
    """MANIFEST.md tables WITHOUT a path column but with a pick/verdict column
    (e.g. `| Icon | prompt | PICK | Why |` with **v1**): the first column names
    the target; files whose stem carries `_v<N>` of the pick become READY."""
    out = []
    text = manifest.read_text(encoding="utf-8", errors="replace")
    for header, rows in parse_md_tables(text):
        cols = map_header(header)
        if "path" in cols or "verdict" not in cols:
            continue
        for line_no, cells in rows:
            if not cells or not cells[0]:
                continue
            target = re.split(r"[\s(]", cells[0].replace("`", "").strip())[0]
            if not re.fullmatch(r"[a-z0-9_]+", target):
                continue
            vcell = cells[cols["verdict"]] if cols["verdict"] < len(cells) else ""
            pick = re.search(r"\bv(\d+)\b", vcell, re.I)
            pcol = cols.get("prompt")
            out.append({"stem": target, "targets": [target], "pick": pick.group(1) if pick else None,
                        "verdict": normalize_verdict(vcell),
                        "prompt": clip(cells[pcol] if pcol is not None and pcol < len(cells) else "", MAX_PROMPT),
                        "notes": clip(cells[cols["notes"]] if "notes" in cols and cols["notes"] < len(cells) else "", MAX_NOTES),
                        "manifest_ref": f"{manifest.name}:{line_no}"})
    return out


def apply_overlays(rows: list[dict], overlays: list[dict]) -> int:
    hits = 0
    for row in rows:
        stem = Path(row["path"].rstrip("/")).name
        stem = Path(stem).stem if "." in stem else stem
        for ov in overlays:
            if not re.search(rf"(^|_){re.escape(ov['stem'])}(_|$)", stem):
                continue
            hits += 1
            row["targets"] = list(dict.fromkeys(ov["targets"] + row.get("targets", [])))
            for k in ("prompt", "notes", "manifest_ref"):
                if ov.get(k):
                    row[k] = ov[k]
            if ov.get("pick"):
                row["verdict"] = "READY" if re.search(rf"_v{ov['pick']}(_|$)", stem) else "ALT"
            elif ov.get("verdict") and ov["verdict"] != "UNREVIEWED":
                row["verdict"] = ov["verdict"]
            break
    return hits


FRAME_RE = re.compile(r"(^|[_-])(south|north|east|west|down|up|side|idle|walk|run|attack|"
                      r"slice|hit|death|cast|frame|sheet)([_.-]|$)|[_-]\d{1,3}$", re.I)
SIZE_SUFFIX = re.compile(r"[_-](16|24|32|48|64|96|128|256)$")
SKIP_NAME = re.compile(r"(^contact|^\._|_4x|preview|^palette_)", re.I)


def rows_from_files(batch_dir: Path) -> list[dict]:
    """Fallback: one UNREVIEWED row per image. A dir holding a PixelLab
    `rotations/` export, or 8+ images that are mostly animation frames
    (direction/anim words or a trailing frame index), collapses to ONE rig row."""
    images = [p for p in sorted(batch_dir.rglob("*"))
              if p.is_file() and p.suffix.lower() in IMAGE_EXT | AUDIO_EXT
              and not SKIP_NAME.search(p.stem)
              and not {"sheets", "mockups", "__pycache__"} & set(p.relative_to(batch_dir).parts)]
    rig_dirs = {d.parent for d in batch_dir.rglob("rotations") if d.is_dir()}
    by_dir: dict[Path, list[Path]] = {}
    for p in images:
        by_dir.setdefault(p.parent, []).append(p)
    for d, files in by_dir.items():
        framey = [f for f in files if FRAME_RE.search(f.stem) and not SIZE_SUFFIX.search(f.stem)]
        need = 0.8 if d == batch_dir else 0.6   # a batch root of frames IS one rig
        if len(files) >= 8 and len(framey) >= need * len(files):
            rig_dirs.add(d)
    # keep only the outermost collapsed dirs
    rig_dirs = {d for d in rig_dirs if not any(o in d.parents for o in rig_dirs)}
    out = []
    for d in sorted(rig_dirs):
        rel = ("" if d == batch_dir else str(d.relative_to(batch_dir)) + "/") or "./"
        n = sum(1 for p in images if d in p.parents)
        targets = extract_targets("", rel) if d != batch_dir else [batch_dir.name]
        out.append({"path": rel, "targets": targets, "verdict": "UNREVIEWED",
                    "kind": "rig", "notes": f"{n} frames/sheets", "manifest_ref": "(file listing)"})
    for p in images:
        if any(r in p.parents for r in rig_dirs):
            continue
        rel = str(p.relative_to(batch_dir))
        out.append({"path": rel, "targets": extract_targets("", rel), "verdict": "UNREVIEWED",
                    "manifest_ref": "(file listing)"})
    return out


# ------------------------------------------------------------ batches

MANIFEST_NAMES = ("MANIFEST.json", "MANIFEST.md", "manifest.json")


def present(d: Path) -> set[str]:
    """EXACT file names in d. Path.exists() is case-insensitive on macOS, where
    MANIFEST.json and the legacy manifest.json are the SAME file — trusting it
    once overwrote three legacy manifests (restored from potential-assets-v2)."""
    try:
        return set(os.listdir(d))
    except OSError:
        return set()


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
    return batches


def read_batch(batch_dir: Path) -> tuple[str, list[dict]]:
    """MANIFEST.json wins; else MANIFEST.md path tables; else the file
    listing overlaid with whatever legacy manifest data matches by stem."""
    mj, md, lj = (batch_dir / n for n in MANIFEST_NAMES)
    names = present(batch_dir)
    try:
        if mj.name in names:
            rows = rows_from_manifest_json(batch_dir, mj)
            if rows:
                return mj.name, rows
        if md.name in names:
            rows = rows_from_markdown(batch_dir, md)
            if rows:
                return md.name, rows
        rows = rows_from_files(batch_dir)
        origin = ["(file listing)"]
        overlays = []
        if lj.name in names:
            overlays += legacy_json_overlays(lj)
        if md.name in names:
            overlays += keyed_table_overlays(md)
        if overlays and apply_overlays(rows, overlays):
            origin.append("+ " + " + ".join(n for n, p in ((lj.name, lj), (md.name, md)) if n in names))
        return " ".join(origin), rows
    except (json.JSONDecodeError, OSError) as exc:
        print(f"WARN {batch_dir}: {exc}", file=sys.stderr)
        return "(file listing)", rows_from_files(batch_dir)


def dedupe(rows: list[dict]) -> list[dict]:
    """One row per path, keeping the best verdict and merging targets."""
    best: dict[str, dict] = {}
    for r in rows:
        cur = best.get(r["path"])
        if cur is None:
            best[r["path"]] = dict(r)
            continue
        merged = list(dict.fromkeys(cur.get("targets", []) + r.get("targets", [])))
        if VERDICT_RANK.get(r["verdict"], 99) < VERDICT_RANK.get(cur["verdict"], 99):
            best[r["path"]] = dict(r)
        best[r["path"]]["targets"] = merged
    return list(best.values())


def finish_row(row: dict, batch_dir: Path, assets_root: Path, repo_root: Path,
               source: str, tier: str, family: str) -> dict:
    rel = row["path"]
    full = batch_dir / rel
    batch_rel = batch_dir.relative_to(assets_root)
    out = {
        "path": str(Path("potential_assets") / batch_rel / rel) + ("/" if rel.endswith("/") else ""),
        "batch": str(batch_rel),
        "kind": row.get("kind") or infer_kind(str(batch_rel), rel, " ".join(row.get("targets", []))),
        "targets": row.get("targets", []),
        "verdict": row.get("verdict", "UNREVIEWED"),
        "tier": tier,
        "family": family,
        "source": source,
        "exists": full.exists(),
    }
    size = None
    if full.is_file():
        size = png_size(full)
    elif full.is_dir():
        south = next(iter(sorted(full.rglob("rotations/south.png"))), None)
        size = png_size(south) if south else None
    if size:
        out["w"], out["h"] = size
    for k in ("pixellab_id", "prompt", "notes", "anchor_feet", "contact_sheet"):
        if row.get(k) not in (None, "", []):
            out[k] = row[k]
    ref = row.get("manifest_ref", "")
    if ref and not ref.startswith("("):
        out["manifest_ref"] = str(Path("potential_assets") / batch_rel / ref)
    return out


# ------------------------------------------------------------- shipped

def shipped_rows(repo_root: Path) -> list[dict]:
    game = repo_root / "wandering_inn_game"
    sprites_path = game / "data" / "sprites.json"
    if not sprites_path.exists():
        return []
    sprites = json.loads(sprites_path.read_text(encoding="utf-8"))
    bundle = set()
    am = game / "assets_manifest.json"
    if am.exists():
        bundle = {a["path"] for a in json.loads(am.read_text(encoding="utf-8")).get("assets", [])
                  if a.get("bundle")}
    out = []
    for sid, rec in sorted(sprites.items()):
        if sid.startswith("_") or not isinstance(rec, dict):
            continue
        sheets = []
        for anim in (rec.get("animations") or {}).values():
            if isinstance(anim, dict):
                sheets += [v for k, v in anim.items() if k.startswith("sheet") and isinstance(v, str)]
        sheets = [s.replace("res://", "") for s in dict.fromkeys(sheets)]
        if not sheets:
            continue
        is_bundle = any(s in bundle for s in sheets)
        first = sheets[0]
        size = png_size(game / first)
        row = {
            "path": f"wandering_inn_game/{first}",
            "batch": "data/sprites.json",
            "kind": "icon" if sid.startswith("icon_") else ("rig" if rec.get("directional") else "prop"),
            "targets": [sid],
            "verdict": "SHIPPED",
            "tier": "shipped-bundle" if is_bundle else "shipped-public",
            "family": "",
            "source": "sprites.json",
            "exists": (game / first).exists(),
            "sprite_id": sid,
        }
        if size:
            row["w"], row["h"] = size
        if len(sheets) > 1:
            row["notes"] = f"{len(sheets)} sheets"
        out.append(row)
    return out


# --------------------------------------------------------------- build

def build(assets_root: Path, repo_root: Path, write_manifests: bool = False) -> dict:
    assets, batches = [], []
    if assets_root.is_dir():
        for bdir in find_batches(assets_root):
            source, tier, family = classify_batch(bdir.relative_to(assets_root).parts[0])
            origin, rows = read_batch(bdir)
            rows = dedupe(rows)
            # never write MANIFEST.json beside a legacy manifest.json: on a
            # case-insensitive filesystem that clobbers it (see present()).
            if (write_manifests and origin != "MANIFEST.json" and rows
                    and "manifest.json" not in present(bdir)):
                write_manifest_json(bdir, rows, source, tier, family, origin)
            done = [finish_row(r, bdir, assets_root, repo_root, source, tier, family) for r in rows]
            assets += done
            batches.append({"batch": str(bdir.relative_to(assets_root)), "origin": origin,
                            "rows": len(done), "tier": tier, "source": source})
    else:
        print(f"WARN no assets root at {assets_root}; registry holds shipped sprites only",
              file=sys.stderr)
    assets += shipped_rows(repo_root)
    assets.sort(key=lambda a: (a["kind"], a["targets"][0] if a["targets"] else "",
                               VERDICT_RANK.get(a["verdict"], 99), a["path"]))
    return {"schema": SCHEMA,
            "generated_by": "tools/asset_candidates.py",
            "query_with": "python3 tools/find_asset.py <terms> [--kind K] [--tier T]",
            "batches": batches,
            "assets": assets}


def write_manifest_json(bdir: Path, rows: list[dict], source: str, tier: str,
                        family: str, origin: str) -> None:
    keep = ("path", "kind", "targets", "verdict", "pixellab_id", "prompt", "notes",
            "anchor_feet", "contact_sheet")
    data = {"schema": SCHEMA, "source": source, "tier": tier, "family": family,
            "converted_from": origin,
            "assets": [{k: r[k] for k in keep if r.get(k) not in (None, "", [])} for r in rows]}
    (bdir / "MANIFEST.json").write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")


def summary_md(reg: dict) -> str:
    from collections import Counter
    assets = reg["assets"]
    by_kind_tier = Counter((a["kind"], a["tier"]) for a in assets)
    kinds = sorted({k for k, _ in by_kind_tier})
    tiers = sorted({t for _, t in by_kind_tier})
    lines = [
        "# Asset candidates registry (generated — do not edit)",
        "",
        "Regenerate: `python3 tools/asset_candidates.py` (after any new generation",
        "batch or sprites.json change). Query, don't scroll:",
        "",
        "```",
        "python3 tools/find_asset.py crate                    # best candidates for a use",
        "python3 tools/find_asset.py renn --kind rig",
        "python3 tools/find_asset.py flame bolt --kind icon --tier owned",
        "python3 tools/find_asset.py barrel --tier public --json",
        "```",
        "",
        "Verdict order: " + " > ".join(VERDICTS) + ". Tiers: `owned-public` (PixelLab, ",
        "redistributable), `owned-unverified` (Codex gpt-image, bundle-tier until",
        "verified), `shipped-public` / `shipped-bundle` (wired in data/sprites.json),",
        "`pack-bundle` (third-party, searched from docs/asset-index.json at query time).",
        "",
        "## Rows by kind and tier",
        "",
        "| kind | " + " | ".join(tiers) + " |",
        "|---|" + "---|" * len(tiers),
    ]
    for k in kinds:
        lines.append(f"| {k} | " + " | ".join(str(by_kind_tier.get((k, t), "")) for t in tiers) + " |")
    lines += ["", "## Owned batches", "", "| batch | read from | rows |", "|---|---|---|"]
    for b in reg["batches"]:
        lines.append(f"| {b['batch']} | {b['origin']} | {b['rows']} |")
    lines.append("")
    return "\n".join(lines)


def dump_registry(reg: dict) -> str:
    """Valid JSON with ONE asset per line, so a rebuild diffs row by row."""
    head = {k: v for k, v in reg.items() if k != "assets"}
    lines = [json.dumps(head, ensure_ascii=False)[:-1] + ', "assets": [']
    rows = [json.dumps(a, ensure_ascii=False, separators=(",", ":")) for a in reg["assets"]]
    lines.append(",\n".join(rows))
    lines.append("]}")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--assets-root", type=Path, default=ROOT / "potential_assets")
    ap.add_argument("--out-dir", type=Path, default=ROOT / "docs")
    ap.add_argument("--write-manifests", action="store_true",
                    help="convert legacy batches to the standard MANIFEST.json")
    args = ap.parse_args(argv)
    reg = build(args.assets_root.resolve(), ROOT, args.write_manifests)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "asset-candidates.json").write_text(dump_registry(reg), encoding="utf-8")
    (args.out_dir / "asset-candidates.md").write_text(summary_md(reg), encoding="utf-8")
    print(f"{len(reg['assets'])} rows from {len(reg['batches'])} owned batches + sprites.json "
          f"-> {args.out_dir}/asset-candidates.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
