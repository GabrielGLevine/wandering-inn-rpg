#!/usr/bin/env python3
"""Rank the best asset candidates for a use case — the step-0 asset query.

Searches docs/asset-candidates.json (owned PixelLab/Codex batches + every
wired data/sprites.json id; built by tools/asset_candidates.py) and, unless
--no-packs, the third-party pack files in docs/asset-index.json. Never opens
an image: it ranks on targets, paths, prompts and verdicts, then prints the
paths (and contact sheets / manifest lines) worth a controller look.

Ranking: exact target match > target-word or material-label match >
path-word match > prompt/notes match (a tileset's material_labels, e.g.
`brick --kind tileset`, score like its targets); ties break on verdict (SHIPPED > READY > USABLE-WITH-FIX >
ALT > UNREVIEWED) then tier (shipped-public > owned-public > shipped-bundle >
owned-unverified > pack-bundle). Every query word must match somewhere.

Examples:
  python3 tools/find_asset.py crate
  python3 tools/find_asset.py renn --kind rig
  python3 tools/find_asset.py flame bolt --kind icon --tier owned
  python3 tools/find_asset.py barrel --tier public --json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asset_candidates as ac  # noqa: E402

ROOT = ac.ROOT
TIER_RANK = {t: i for i, t in enumerate(
    ("shipped-public", "owned-public", "shipped-bundle", "owned-unverified", "pack-bundle"))}
STOP = {"a", "an", "the", "of", "and", "with", "for", "to", "in", "on", "top", "down",
        "rpg", "sprite", "pixel", "art", "bit", "16", "hard", "black", "outline"}


def words(text: str) -> set[str]:
    return {w for w in re.split(r"[^a-z0-9]+", (text or "").lower()) if w and w not in STOP}


def pack_rows(index_path: Path) -> list[dict]:
    if not index_path.exists():
        return []
    data = json.loads(index_path.read_text(encoding="utf-8"))
    out = []
    for pack, files in data.items():
        if not isinstance(files, list):
            continue
        fam = ac.pack_family(pack)
        for f in files:
            path = f.get("path", "")
            row = {"path": f"potential_assets/{path}", "batch": pack,
                   "kind": ac.infer_kind(pack, path), "targets": [ac.stem_target(path).lower()],
                   "verdict": "UNREVIEWED", "tier": "pack-bundle", "family": fam,
                   "source": "pack"}
            if f.get("w"):
                row["w"], row["h"] = f["w"], f.get("h")
            if f.get("frames"):
                row["notes"] = f"{f['frames']} frames"
            out.append(row)
    return out


def score(row: dict, terms: list[str], joined: str) -> int:
    targets = [t.lower() for t in row.get("targets", [])]
    named = targets + [m.lower() for m in row.get("material_labels") or []]
    t_words = set().union(*(words(t) for t in named)) if named else set()
    p_words = words(row.get("path", ""))
    x_words = words(row.get("prompt", "")) | words(row.get("notes", ""))
    s = 0
    for t in terms:
        if t in t_words:
            s += 10
        elif t in p_words:
            s += 5
        elif t in x_words:
            s += 1
        else:
            return 0  # every word must match somewhere
    bare = {re.sub(r"^(icon|pc)_", "", t) for t in targets} | set(targets)
    if joined in bare or (row.get("sprite_id") == joined):
        s += 100
    return s


def tier_ok(tier: str, want: str | None) -> bool:
    if not want:
        return True
    return want in tier.split("-") or tier.startswith(want) or tier == want


def search(rows: list[dict], query: list[str], kind: str | None = None, tier: str | None = None,
           family: str | None = None, include_rejected: bool = False) -> list[tuple[int, dict]]:
    terms = sorted(set().union(*(words(q) for q in query))) if query else []
    joined = "_".join(w for q in query for w in re.split(r"[^a-z0-9]+", q.lower()) if w)
    hits = []
    for r in rows:
        if kind and r.get("kind") != kind:
            continue
        if not tier_ok(r.get("tier", ""), tier):
            continue
        if family and r.get("family", "").upper() != family.upper():
            continue
        if not include_rejected and r.get("verdict") in ("REJECTED", "SUPERSEDED"):
            continue
        sc = score(r, terms, joined) if terms else 1
        if sc:
            hits.append((sc, r))
    hits.sort(key=lambda h: (-h[0], ac.VERDICT_RANK.get(h[1].get("verdict"), 99),
                             TIER_RANK.get(h[1].get("tier"), 99), h[1].get("path", "")))
    return hits


def fmt(r: dict) -> str:
    size = f"{r['w']}x{r['h']}" if r.get("w") else "-"
    extra = []
    if r.get("sprite_id"):
        extra.append(f"sprite_id={r['sprite_id']}")
    elif r.get("targets"):
        extra.append("targets=" + ",".join(r["targets"][:3]))
    if r.get("manifest_ref"):
        extra.append(r["manifest_ref"])
    if r.get("contact_sheet"):
        extra.append(f"sheet={r['contact_sheet']}")
    if r.get("material_labels"):
        extra.append("materials=" + ",".join(r["material_labels"]))
    if r.get("layout"):
        extra.append(f"layout={r['layout']}")
    if r.get("source_sheet"):
        region = ",".join(str(v) for v in r.get("region", []))
        extra.append(f"region={region} of {Path(r['source_sheet']).name}")
        extra.append(f"bundled={r['game_sheet']}" if r.get("game_sheet") else "BUNDLE-PENDING")
    line = f"{r.get('verdict', ''):<15} {r.get('tier', ''):<16} {r.get('kind', ''):<8} {size:>9}  {r['path']}"
    out = line + ("\n" + " " * 52 + "  ".join(extra) if extra else "")
    if r.get("notes"):
        out += "\n" + " " * 52 + ac.clip(r["notes"], 110)
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("query", nargs="*", help="use-case words, e.g. 'crate' or 'flame bolt'")
    ap.add_argument("--kind", choices=ac.KINDS)
    ap.add_argument("--tier", help="owned | public | shipped | pack | bundle | unverified, or a full tier")
    ap.add_argument("--family", help="style family, e.g. PC16, PIXELLAB-AI")
    ap.add_argument("--limit", type=int, default=12)
    ap.add_argument("--include-rejected", action="store_true")
    ap.add_argument("--no-packs", action="store_true", help="skip third-party pack files")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--registry", type=Path, default=ROOT / "docs" / "asset-candidates.json")
    ap.add_argument("--pack-index", type=Path, default=ROOT / "docs" / "asset-index.json")
    args = ap.parse_args(argv)
    if not args.registry.exists():
        print(f"no registry at {args.registry}; run python3 tools/asset_candidates.py", file=sys.stderr)
        return 2
    rows = json.loads(args.registry.read_text(encoding="utf-8"))["assets"]
    if not args.no_packs:
        # a registered sheet (pack tilesets) outranks its bare index row
        known = {r["path"] for r in rows} | {d for r in rows for d in r.get("duplicate_sheets") or []}
        rows += [r for r in pack_rows(args.pack_index) if r["path"] not in known]
    hits = search(rows, args.query, args.kind, args.tier, args.family, args.include_rejected)
    shown = [r for _, r in hits[: args.limit]]
    if args.json:
        print(json.dumps(shown, indent=1))
    else:
        for r in shown:
            print(fmt(r))
        print(f"-- {len(shown)} of {len(hits)} matches")
    return 0 if hits else 1


if __name__ == "__main__":
    sys.exit(main())
