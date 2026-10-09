#!/usr/bin/env python3
"""Asset intake coverage: every PNG under potential_assets/ is sliced,
registered or explicitly excluded (#624).

The regional-kit pool reads see only what the intake made searchable: slices
in _sliced/<pack>/<stem>/SLICES.json and rows in docs/asset-candidates.json.
A sheet that neither the slicer nor the registry covered stayed invisible
(Forge/Hideout/Library Tiles.png, Desert Ground.png, the furnace bricks).
This tool puts every PNG in exactly one class, first match wins:

  sliced(n)         a SLICES.json names it as `sheet` or in `duplicate_sheets`
                    and holds n >= 1 slices (a mixed sheet's tile part is also
                    a registered tileset; it still counts here)
  tileset           a docs/asset-candidates.json row of kind tileset (path or
                    duplicate_sheets)
  rig_or_animation  a registry rig row (file, or a file under a rig dir row),
                    or a path under a character/creature/animation/VFX dir
                    (RIG_WORDS, FX_WORDS)
  ui_or_icon        a registry icon/ui row, or a path under a UI/icon/item dir
                    (UI_WORDS)
  audio             a registry audio row, or a path under an audio pack dir
                    (AUDIO_WORDS)
  owned_wired       any other registry row: the owned PixelLab/Codex batches
                    the harvest registered (MANIFEST rows)
  excluded(reason)  a glob in docs/asset-coverage-exclusions.json; an entry
                    may carry "class" to record a rig/ui/audio file the path
                    words cannot see (goblin rigs), else it is `excluded`
  UNCLASSIFIED      none of the above: the intake never looked at it

Directory words match whole words of a directory name ("Npc's" -> npc,
"UI Elements" -> ui), never the file name, so an environment sheet is never
waved through by its name.

Outputs docs/asset-coverage.md (per-pack table, exclusion use, UNCLASSIFIED
list). --check writes nothing and exits 1 when any PNG is UNCLASSIFIED; it
exits 0 with a SKIP note when potential_assets/ is absent (CI).

Usage:
  python3 tools/asset_coverage.py [--assets-root DIR] [--registry FILE]
      [--exclusions FILE] [--out FILE] [--check]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLASSES = ("sliced", "tileset", "rig_or_animation", "ui_or_icon", "audio", "owned_wired",
           "excluded", "UNCLASSIFIED")
OVERRIDE_CLASSES = ("excluded", "rig_or_animation", "ui_or_icon", "audio")
SKIP_TOP = {"_sliced", "license-notes"}
RIG_WORDS = {"entities", "entity", "enemies", "enemy", "characters", "character", "characteranimated",
             "mobs", "mob", "npc", "npcs", "actor", "actors", "monster", "monsters", "boss", "bosses",
             "animal", "animals", "units", "unit", "factions", "troops", "player", "rotations",
             "animations", "rig", "rigs"}
FX_WORDS = {"fx", "vfx", "effects", "effect", "particle", "particles", "projectile", "projectiles"}
UI_WORDS = {"ui", "gui", "hud", "icon", "icons", "items", "item", "font", "fonts", "emote", "emotes",
            "cursor", "cursors"}
AUDIO_WORDS = {"music", "sfx", "audio", "sound", "sounds"}
KIND_CLASS = {"tileset": "tileset", "rig": "rig_or_animation", "icon": "ui_or_icon",
              "ui": "ui_or_icon", "audio": "audio"}


# ------------------------------------------------------------------ inputs

def list_pngs(assets_root: Path) -> list[str]:
    """potential_assets-relative posix paths of every PNG outside SKIP_TOP."""
    out = []
    for p in assets_root.rglob("*"):
        if p.suffix.lower() != ".png" or not p.is_file():
            continue
        rel = p.relative_to(assets_root)
        if rel.parts[0] in SKIP_TOP:
            continue
        out.append(rel.as_posix())
    return sorted(out)


def _strip(path: str) -> str:
    return path[len("potential_assets/"):] if path.startswith("potential_assets/") else path


def sliced_index(assets_root: Path) -> dict[str, int]:
    """sheet (and duplicate) path -> slice count, from every SLICES.json."""
    out: dict[str, int] = {}
    for sj in sorted(assets_root.glob("_sliced/*/*/SLICES.json")):
        try:
            doc = json.loads(sj.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        rows = doc.get("assets", [])
        if not rows or not doc.get("sheet"):
            continue
        dupes = {d for r in rows for d in r.get("duplicate_sheets", [])}
        for path in {doc["sheet"], *dupes}:
            out[_strip(path)] = out.get(_strip(path), 0) + len(rows)
    return out


def registry_index(registry: Path) -> tuple[dict[str, str], list[tuple[str, str]]]:
    """(file path -> registry kind, [(rig dir prefix, kind)]) for potential_assets rows."""
    files: dict[str, str] = {}
    dirs: list[tuple[str, str]] = []
    if not registry.exists():
        return files, dirs
    for row in json.loads(registry.read_text(encoding="utf-8")).get("assets", []):
        path = row.get("path", "")
        if not path.startswith("potential_assets/"):
            continue
        kind = row.get("kind", "")
        if path.endswith("/"):
            dirs.append((_strip(path), kind))
            continue
        files.setdefault(_strip(path), kind)
        for dup in row.get("duplicate_sheets", []):
            files.setdefault(_strip(dup), kind)
    dirs.sort(key=lambda d: -len(d[0]))
    return files, dirs


def glob_regex(glob: str) -> re.Pattern:
    """potential_assets-relative glob: `**/` spans zero or more directories,
    `**` at the end spans anything, `*` and `?` stay inside one segment."""
    out, i = [], 0
    while i < len(glob):
        if glob.startswith("**/", i):
            out.append("(?:[^/]*/)*")
            i += 3
        elif glob.startswith("**", i):
            out.append(".*")
            i += 2
        elif glob[i] == "*":
            out.append("[^/]*")
            i += 1
        elif glob[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(glob[i]))
            i += 1
    return re.compile("".join(out) + r"\Z")


def load_exclusions(path: Path) -> list[dict]:
    if not path.exists():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    out = []
    for e in data.get("exclusions", []):
        cls = e.get("class", "excluded")
        if not e.get("glob") or not e.get("reason") or cls not in OVERRIDE_CLASSES:
            raise ValueError(f"{path}: every exclusion needs glob + reason and class in "
                             f"{OVERRIDE_CLASSES}: {e}")
        out.append({"glob": e["glob"], "reason": e["reason"], "class": cls,
                    "re": glob_regex(e["glob"])})
    return out


# ------------------------------------------------------------- classifying

def dir_words(rel: str) -> set[str]:
    return {w for part in rel.split("/")[:-1] for w in re.split(r"[^a-z0-9]+", part.lower()) if w}


def classify(rel: str, sliced: dict[str, int], reg_files: dict[str, str],
             reg_dirs: list[tuple[str, str]], exclusions: list[dict]) -> tuple[str, str]:
    """(class, detail) for one potential_assets-relative path."""
    if sliced.get(rel, 0) > 0:
        return "sliced", str(sliced[rel])
    kind = reg_files.get(rel)
    if kind is None:
        kind = next((k for d, k in reg_dirs if rel.startswith(d)), None)
    if kind is not None:
        return KIND_CLASS.get(kind, "owned_wired"), kind
    words = dir_words(rel)
    if words & (RIG_WORDS | FX_WORDS):
        return "rig_or_animation", "path"
    if words & UI_WORDS:
        return "ui_or_icon", "path"
    if words & AUDIO_WORDS:
        return "audio", "path"
    for e in exclusions:
        if e["re"].match(rel):
            return e["class"], e["glob"]
    return "UNCLASSIFIED", ""


def pack_of(rel: str) -> str:
    parts = rel.split("/")
    return parts[0] if len(parts) > 1 else "(root)"


def run(assets_root: Path, registry: Path, exclusions_path: Path) -> dict:
    exclusions = load_exclusions(exclusions_path)
    sliced = sliced_index(assets_root)
    reg_files, reg_dirs = registry_index(registry)
    per_pack: dict[str, Counter] = {}
    slices_per_pack: Counter = Counter()
    glob_use: Counter = Counter()
    unclassified: list[str] = []
    for rel in list_pngs(assets_root):
        cls, detail = classify(rel, sliced, reg_files, reg_dirs, exclusions)
        pack = pack_of(rel)
        per_pack.setdefault(pack, Counter())[cls] += 1
        if cls == "sliced":
            slices_per_pack[pack] += int(detail)
        if detail and any(e["glob"] == detail for e in exclusions):
            glob_use[detail] += 1
        if cls == "UNCLASSIFIED":
            unclassified.append(rel)
    return {"per_pack": per_pack, "slices": slices_per_pack, "exclusions": exclusions,
            "glob_use": glob_use, "unclassified": unclassified}


# ----------------------------------------------------------------- output

def render_md(res: dict) -> str:
    cols = ("sliced", "tileset", "rig_or_animation", "ui_or_icon", "audio", "owned_wired",
            "excluded", "UNCLASSIFIED")
    total = Counter()
    for c in res["per_pack"].values():
        total.update(c)
    lines = [
        "# Asset intake coverage (generated — do not edit)",
        "",
        "Regenerate with `python3 tools/asset_coverage.py`. The gate is",
        "`python3 tools/asset_coverage.py --check` (run by `scripts/preflight.sh`):",
        "0 UNCLASSIFIED before any pool read. Every PNG under `potential_assets/`",
        "(except `_sliced/` and `license-notes/`) sits in exactly one class; the",
        "rules are in the `tools/asset_coverage.py` docstring and explicit",
        "exclusions in `docs/asset-coverage-exclusions.json`.",
        "",
        f"**{sum(total.values())} PNGs: " + ", ".join(f"{total[c]} {c}" for c in cols if total[c]) + ".**",
        "",
        "## Per pack",
        "",
        "`sliced` counts source sheets, with their slices in brackets. `rig/anim`",
        "is rig_or_animation and `owned` is owned_wired.",
        "",
        "| pack | PNGs | sliced [slices] | tileset | rig/anim | ui/icon | audio | owned | excluded | UNCLASSIFIED |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for pack in sorted(res["per_pack"], key=str.lower):
        c = res["per_pack"][pack]
        sl = f"{c['sliced']} [{res['slices'][pack]}]" if c["sliced"] else ""
        cells = [str(c[k]) if c[k] else "" for k in cols[1:]]
        lines.append(f"| {pack} | {sum(c.values())} | {sl} | " + " | ".join(cells) + " |")
    lines += ["", "## Exclusions in use", "",
              "| glob | class | PNGs | reason |", "|---|---|---|---|"]
    for e in res["exclusions"]:
        lines.append(f"| `{e['glob']}` | {e['class']} | {res['glob_use'][e['glob']]} | {e['reason']} |")
    lines += ["", f"## UNCLASSIFIED ({len(res['unclassified'])})", ""]
    lines += [f"- `{p}`" for p in res["unclassified"]] or ["None."]
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--assets-root", type=Path, default=ROOT / "potential_assets")
    ap.add_argument("--registry", type=Path, default=ROOT / "docs" / "asset-candidates.json")
    ap.add_argument("--exclusions", type=Path, default=ROOT / "docs" / "asset-coverage-exclusions.json")
    ap.add_argument("--out", type=Path, default=ROOT / "docs" / "asset-coverage.md")
    ap.add_argument("--check", action="store_true", help="write nothing; exit 1 on any UNCLASSIFIED")
    args = ap.parse_args(argv)
    if not args.assets_root.is_dir():
        print(f"SKIP asset coverage: no {args.assets_root} (CI has no potential_assets/)")
        return 0
    res = run(args.assets_root, args.registry, args.exclusions)
    unused = [e["glob"] for e in res["exclusions"] if not res["glob_use"][e["glob"]]]
    for g in unused:
        print(f"WARN exclusion glob matches nothing: {g}")
    n = sum(sum(c.values()) for c in res["per_pack"].values())
    bad = res["unclassified"]
    if args.check:
        for p in bad[:40]:
            print(f"UNCLASSIFIED {p}")
        if len(bad) > 40:
            print(f"... and {len(bad) - 40} more (python3 tools/asset_coverage.py writes them all)")
        print(f"asset coverage: {n} PNGs, {len(bad)} UNCLASSIFIED")
        return 1 if bad else 0
    args.out.write_text(render_md(res), encoding="utf-8")
    print(f"asset coverage: {n} PNGs, {len(bad)} UNCLASSIFIED -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
