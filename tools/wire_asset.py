#!/usr/bin/env python3
"""Wire one asset candidate into the game (regional kits spec §4.2, contract C9).

  python3 tools/wire_asset.py <candidate.png>… --id <sprite_id> [--id …] [--kind prop|setpiece]
        [--fallback <owned_sprite_id>] [--like <sprite_id>] [--fps N] [--dry-run]
        [--alias-of <existing_id> --reason "<text>"] [--no-regen] [--repo-root DIR]

One --id per candidate, in order. Exit codes: 0 wired or no change; 2 usage;
3 bundle pending; 4 refused (pc_* id, id already wired with different content,
bad --fallback, --alias-of naming no twin, non-canonical fixture); 5 probe
failure (empty alpha, bad strip); 6 duplicate art.

Duplicate art (#623): a new id whose art identity (wi_kits_lib.art_identity: a
region row's sheet and rect, merged with near-identical rects on that sheet at
IoU >= kl.NEAR_IOU; a frame sheet's sha256 and frame size; scale, tint and
fallback never count) is already registered is refused with exit 6 and
`DUPLICATE-ART`, naming the existing id. Reuse that id. A deliberate second id
needs --alias-of <that id> --reason "<why>" (one candidate per call), which
records "_alias_of" and "_alias_reason" on the entry; G2/G3 still count both ids
as one picture.

Owned PNG (potential_assets/pixellab_*/…, codex_*/…): copied unchanged to
assets/sprites/<id>/Idle-Sheet.png; a static sprites.json entry; a
'<id>/idle' pin in qa/fixtures/sprite_frame_counts.json; one provenance line in
assets/LICENSES/v019-owned-art-provenance.txt (source path, sha256, PixelLab
id from the batch MANIFEST.json when present). A sheet wider than tall is a
horizontal strip of height x height frames unless the MANIFEST row carries
"frame_size": [w, h].

Pack slice (…/_sliced/<stem>/<stem>__x_y_w_h.png beside SLICES.json): a
`region` entry on the ALREADY-BUNDLED game sheet, found by matching the row's
sheet_sha256 against every PNG under wandering_inn_game/assets/ (a row
"game_sheet" from the slicer short-circuits that). No file is copied, no
manifest row is added, provenance is the entry's own _comment (source sheet,
region, sheet sha). --fallback is required and must be a public, one-hop,
non-pc_ catalog entry. No bundled match: exit 3, print `BUNDLE-PENDING
<source_sheet>`, append one row to docs/art-bundle-pending.md.

Anchor: the alpha probe of the FIRST frame (scripts/sprite_alpha_probe.py's
rule): feet = lowest row with alpha >= 8, anchor [0.5, feet / frame_h].

Sibling rule for render_scale and shadow: --like <id> wins; else pack mode
takes the first catalog entry (file order) on the same game sheet that has a
region; owned mode takes the first non-directional entry under
res://assets/sprites/ with the same frame_size (pc_*, icon_*, owned_fallback_*
skipped); none -> DEFAULT_SCALE and shadow iff --kind prop.

Every write is planned in memory and proved first; --dry-run prints the exact
diff. Re-running a finished wiring prints "no change" and writes nothing.
sprites.json is spliced with scripts/splice_json.py's primitives, never
reserialized. docs/asset-candidates.* are regenerated through
tools/asset_candidates.py's build() (the same code `python3
tools/asset_candidates.py` runs) so --repo-root stays honoured.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
sys.path.insert(0, str(REPO_ROOT / "wandering_inn_game" / "scripts"))
import asset_candidates as ac  # noqa: E402
import splice_json  # noqa: E402
import wi_kits_lib as kl  # noqa: E402

EXIT_OK, EXIT_USAGE, EXIT_BUNDLE_PENDING, EXIT_REFUSED, EXIT_PROBE, EXIT_DUPLICATE = 0, 2, 3, 4, 5, 6
ALPHA_FLOOR = 8
ID_RE = re.compile(r"^[a-z0-9_]+$")
DEFAULT_SCALE = {"owned": 0.4, "pack": 1.0}
FIXTURE_COMMENT = ("Frame-count pins, '<sprite_id>/<anim>': frames. Generated once from "
                   "tests/test_sprite_registry.gd::_build_expected_counts (2026-10-08); "
                   "tools/wire_asset.py appends; the test fails on a missing key. "
                   "Canonical form: json.dumps(indent=1, sort_keys=True).")
BUNDLE_PENDING_HEADER = """# Art bundle pending (living)

Pack slices that `tools/wire_asset.py` refused to wire because their source
sheet is not under `wandering_inn_game/assets/` (exit 3, `BUNDLE-PENDING
<source_sheet>`). Pack art may only be wired as a `region` row on an
already-bundled sheet; a new sheet needs a manifest row and a private bundle
release (`wi-shipping`), which Phase 0 does not allow, so the request waits here.

Insertion: tail — append rows; delete a row in the commit that wires its
candidate. One row per candidate path.

Columns: date · source_sheet (pack path under `potential_assets/`) · candidate
(the slice PNG) · sprite_id (the id the wiring asked for) · region ([x, y, w, h]
on the source sheet).

| date | source_sheet | candidate | sprite_id | region |
|---|---|---|---|---|
"""


class Refused(Exception):
    exit_code = EXIT_REFUSED


class ProbeError(Exception):
    exit_code = EXIT_PROBE


class DuplicateArt(Exception):
    exit_code = EXIT_DUPLICATE


class BundlePending(Exception):
    exit_code = EXIT_BUNDLE_PENDING

    def __init__(self, source_sheet: str, region: list[int]):
        super().__init__(f"BUNDLE-PENDING {source_sheet}")
        self.source_sheet = source_sheet
        self.region = region


@dataclass
class Paths:
    repo_root: Path

    def __post_init__(self) -> None:
        self.repo_root = Path(self.repo_root).resolve()

    @property
    def game(self) -> Path:
        return self.repo_root / "wandering_inn_game"

    @property
    def sprites(self) -> Path:
        return self.game / "data" / "sprites.json"

    @property
    def fixture(self) -> Path:
        return self.game / "qa" / "fixtures" / "sprite_frame_counts.json"

    @property
    def provenance(self) -> Path:
        return self.game / "assets" / "LICENSES" / "v019-owned-art-provenance.txt"

    @property
    def manifest(self) -> Path:
        return self.game / "assets_manifest.json"

    @property
    def assets(self) -> Path:
        return self.game / "assets"

    @property
    def docs(self) -> Path:
        return self.repo_root / "docs"

    @property
    def bundle_pending(self) -> Path:
        return self.docs / "art-bundle-pending.md"

    @property
    def potential(self) -> Path:
        return self.repo_root / "potential_assets"


@dataclass
class TextEdit:
    path: Path
    before: str
    after: str


@dataclass
class Copy:
    src: Path
    dst: Path
    sha: str


@dataclass
class WirePlan:
    sprite_id: str
    entry: dict
    frames: int
    edits: list[TextEdit] = field(default_factory=list)
    copies: list[Copy] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)

    def is_noop(self) -> bool:
        return (all(e.before == e.after for e in self.edits)
                and all(c.dst.is_file() and sha256_file(c.dst) == c.sha for c in self.copies))


# ------------------------------------------------------------------ helpers

def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def probe(png: Path, frame_w: int | None = None) -> dict:
    """Alpha probe of the FIRST frame: bbox, feet row and anchor."""
    with Image.open(png) as raw:
        img = raw.convert("RGBA")
    w, h = img.size
    first = img.crop((0, 0, frame_w or w, h))
    box = first.getchannel("A").point(lambda v: 255 if v >= ALPHA_FLOOR else 0).getbbox()
    if box is None:
        raise ProbeError(f"{png}: first frame is fully transparent")
    x0, y0, x1, y1 = box
    return {"w": w, "h": h, "bbox": [x0, y0, x1, y1], "feet": y1, "anchor": [0.5, round(y1 / h, 4)]}


def frame_geometry(w: int, h: int, manifest_frame: list | None) -> tuple[int, int, int]:
    """(frame_w, frame_h, count): square = one frame; wider = strip of h x h frames."""
    if manifest_frame:
        fw, fh = int(manifest_frame[0]), int(manifest_frame[1])
        if fh != h or fw <= 0 or w % fw:
            raise ProbeError(f"manifest frame_size {manifest_frame} does not tile a {w}x{h} sheet")
        return fw, fh, w // fw
    if w == h:
        return w, h, 1
    if w % h == 0:
        return h, h, w // h
    raise ProbeError(f"{w}x{h} is neither square nor a strip of {h}x{h} frames; "
                     f"add \"frame_size\": [w, h] to the MANIFEST.json row")


def manifest_row(candidate: Path, paths: Paths) -> dict:
    """The candidate's row in the nearest MANIFEST.json above it (asset_candidates schema)."""
    for d in (candidate.parent, *candidate.parent.parents):
        if paths.potential not in d.parents:
            break
        if "MANIFEST.json" in ac.present(d):
            rel = candidate.relative_to(d).as_posix()
            rows = json.loads((d / "MANIFEST.json").read_text(encoding="utf-8")).get("assets", [])
            return next((r for r in rows if r.get("path") == rel), {})
    return {}


def load_catalog(paths: Paths) -> tuple[str, dict]:
    text = paths.sprites.read_text(encoding="utf-8")
    return text, json.loads(text)


def bundle_paths(paths: Paths) -> set[str]:
    if not paths.manifest.is_file():
        raise Refused(f"{paths.manifest}: missing; cannot tell which sheets are bundle-only")
    data = json.loads(paths.manifest.read_text(encoding="utf-8"))
    return {a["path"] for a in data.get("assets", []) if a.get("bundle")}


def sheets_of(entry: dict) -> list[str]:
    out = []
    for anim in (entry.get("animations") or {}).values():
        if isinstance(anim, dict):
            out += [str(v).replace("res://", "") for k, v in anim.items() if k.startswith("sheet")]
    return out


def check_fallback(fallback: str, catalog: dict, bundle: set[str]) -> None:
    target = catalog.get(fallback)
    if not isinstance(target, dict):
        raise Refused(f"--fallback {fallback}: not in sprites.json")
    if fallback.startswith("pc_"):
        raise Refused(f"--fallback {fallback}: pc_* rigs are player-only")
    if "fallback_sprite" in target:
        raise Refused(f"--fallback {fallback}: has its own fallback_sprite (targets are one hop)")
    private = [s for s in sheets_of(target) if s in bundle]
    if private:
        raise Refused(f"--fallback {fallback}: not public, bundle-only sheets {private}")


def sibling(catalog: dict, mode: str, like: str | None, sheet_res: str,
            frame_size: tuple[int, int]) -> tuple[str, dict] | None:
    if like:
        if not isinstance(catalog.get(like), dict):
            raise Refused(f"--like {like}: not in sprites.json")
        return like, catalog[like]
    for sid, entry in catalog.items():
        if not isinstance(entry, dict) or sid.startswith(("pc_", "icon_", "owned_fallback_", "_")):
            continue
        idle = (entry.get("animations") or {}).get("idle") or {}
        if mode == "pack":
            if idle.get("sheet") == sheet_res and "region" in idle:
                return sid, entry
        elif (not entry.get("directional")
              and str(idle.get("sheet", "")).startswith("res://assets/sprites/")
              and [int(v) for v in idle.get("frame_size", [0, 0])] == list(frame_size)):
            return sid, entry
    return None


def art_twins(sprite_id: str, entry: dict, catalog: dict, sheets: kl.SheetHasher) -> tuple[tuple, list[str]]:
    """(the entry's art identity, every OTHER catalog id drawing that art), by the predicate
    data_lint uses: equal frame-sheet keys, or region rows of one near-identical component
    (kl.merge_near_regions). Frame sheets are hashed only for same-type, same-size entries."""
    ident = kl.art_identity(sprite_id, entry, sheets)
    others = {}
    for sid, other in catalog.items():
        if sid == sprite_id or sid.startswith("_") or not isinstance(other, dict):
            continue
        cheap = kl.art_identity(sid, other, lambda _path: None)
        if cheap[0] != ident[0] or (ident[0] == "S" and cheap[2] != ident[2]):
            continue
        if ident[0] == "R" and cheap[1] != ident[1]:
            continue
        others[sid] = cheap if ident[0] == "R" else kl.art_identity(sid, other, sheets)
    if ident[0] != "R":
        return ident, [sid for sid, k in others.items() if k == ident]
    canon = kl.merge_near_regions(list(others.values()) + [ident])
    return canon[ident], [sid for sid, k in others.items() if canon[k] == canon[ident]]


def refuse_duplicate_art(sprite_id: str, entry: dict, catalog: dict, args: argparse.Namespace, paths: Paths,
                         new_sheets: dict | None = None) -> dict:
    """#623: the entry to write, or DuplicateArt when its art is registered under another id.
    --alias-of <twin> --reason lets it through and records both on the entry. A re-run of an
    id already in the catalog is left to sprites_with (no change, or exit 4)."""
    alias = getattr(args, "alias_of", None)
    if alias is None and sprite_id in catalog:
        return entry
    ident, twins = art_twins(sprite_id, entry, catalog, kl.SheetHasher(paths.game, new_sheets))
    if not twins:
        if alias:
            raise Refused(f"{sprite_id}: --alias-of {alias}, but no registered id draws this art "
                          f"({kl.identity_label(ident)}); drop --alias-of")
        return entry
    if alias not in twins:
        raise DuplicateArt(f"DUPLICATE-ART {sprite_id}: {kl.identity_label(ident)} is already registered as "
                           f"{', '.join(twins)}. Use that id, or pass --alias-of {twins[0]} --reason \"<why a "
                           f"second id>\" to wire a deliberate alias")
    out = {k: v for k, v in entry.items() if k == "_comment"}
    out["_alias_of"] = alias
    out["_alias_reason"] = args.reason
    out.update({k: v for k, v in entry.items() if k != "_comment"})
    return out


def build_entry(mode: str, sheet_res: str, frame: tuple[int, int], region: list[int] | None,
                anchor: list[float], sib: tuple[str, dict] | None, kind: str,
                fallback: str | None, fps: int, comment: str) -> dict:
    entry: dict = {}
    if comment:
        entry["_comment"] = comment
    entry["render_scale"] = sib[1].get("render_scale", DEFAULT_SCALE[mode]) if sib else DEFAULT_SCALE[mode]
    entry["anchor"] = anchor
    shadow = sib[1].get("shadow", False) if sib else (kind == "prop")
    if shadow:
        entry["shadow"] = True
    anim: dict = {"sheet": sheet_res, "frame_size": [frame[0], frame[1]]}
    if region:
        anim["region"] = list(region)
    anim["fps"] = fps
    entry["animations"] = {"idle": anim}
    if fallback:
        entry["fallback_sprite"] = fallback
    return entry


def logical_candidate(candidate: Path, paths: Paths) -> Path:
    """Map a path under the REAL potential_assets back to its repo-relative logical form.

    potential_assets is a symlink in a worktree, so a resolved path never sits under
    repo_root; every candidate/slice comparison goes through here."""
    real_root = paths.potential.resolve()
    resolved = candidate.resolve()
    if real_root in resolved.parents:
        return paths.potential / resolved.relative_to(real_root)
    return candidate


def is_slice(candidate: Path) -> bool:
    return "_sliced" in candidate.parts and (candidate.parent / "SLICES.json").is_file()


def slice_row(candidate: Path, paths: Paths) -> dict:
    """The C8 row for this slice in its SLICES.json (path matched repo-relative)."""
    candidate = logical_candidate(candidate, paths)
    rel = candidate.relative_to(paths.repo_root).as_posix()
    rows = json.loads((candidate.parent / "SLICES.json").read_text(encoding="utf-8")).get("assets", [])
    row = next((r for r in rows if r.get("path") == rel), None)
    if row is None:
        raise Refused(f"{rel}: no row in {candidate.parent / 'SLICES.json'}")
    for key in ("region", "sheet_sha256", "source_sheet"):
        if key not in row:
            raise Refused(f"{rel}: SLICES.json row lacks {key}")
    return row


_SHEET_INDEX: dict[Path, dict[str, str]] = {}
_SHEET_SIG: dict[Path, tuple[int, int]] = {}


def _assets_signature(assets: Path) -> tuple[int, int]:
    """(png count, newest mtime_ns): cheap stat-only change detector for the assets tree."""
    count, newest = 0, 0
    for p in assets.rglob("*.png"):
        count += 1
        newest = max(newest, p.stat().st_mtime_ns)
    return count, newest


def bundled_sheet_for(sha: str, paths: Paths) -> str | None:
    """'assets/...' path (game-root relative) of the PNG under assets/ hashing to sha, else None.

    The SHA index is rebuilt after a miss only when the assets tree changed since the last build.
    """
    def build() -> dict[str, str]:
        index: dict[str, str] = {}
        for p in sorted(paths.assets.rglob("*.png")):
            index.setdefault(sha256_file(p), p.relative_to(paths.game).as_posix())
        _SHEET_INDEX[paths.assets] = index
        _SHEET_SIG[paths.assets] = _assets_signature(paths.assets)
        return index

    index = _SHEET_INDEX.get(paths.assets)
    if index is None:
        index = build()
    if sha not in index and _assets_signature(paths.assets) != _SHEET_SIG.get(paths.assets):
        index = build()
    return index.get(sha)


def hinted_sheet(hint: object, sha: str, paths: Paths) -> str | None:
    """The slicer's game_sheet hint ('res://assets/...' or 'assets/...'), trusted only inside assets/
    and only when its bytes hash to sha."""
    if not isinstance(hint, str) or not hint:
        return None
    path = (paths.game / hint.removeprefix("res://")).resolve()
    if paths.assets.resolve() not in path.parents or not path.is_file() or sha256_file(path) != sha:
        return None
    return path.relative_to(paths.game.resolve()).as_posix()


def plan_slice(candidate: Path, sprite_id: str, args: argparse.Namespace, paths: Paths,
               text: str, catalog: dict) -> WirePlan:
    row = slice_row(candidate, paths)
    x, y, w, h = (int(v) for v in row["region"])
    if not args.fallback:
        raise Refused(f"{sprite_id}: pack art needs --fallback <owned public sprite_id>")
    rel_sheet = (hinted_sheet(row.get("game_sheet"), row["sheet_sha256"], paths)
                 or bundled_sheet_for(row["sheet_sha256"], paths))
    if rel_sheet is None:
        raise BundlePending(row["source_sheet"], [x, y, w, h])
    pr = probe(candidate)
    if (pr["w"], pr["h"]) != (w, h):
        raise ProbeError(f"{candidate.name}: slice PNG is {pr['w']}x{pr['h']} but region says {w}x{h}")
    sheet_res = f"res://{rel_sheet}"
    sib = sibling(catalog, "pack", args.like, sheet_res, (w, h))
    comment = (f"slice of {row['source_sheet']} region {[x, y, w, h]} sheet sha256 "
               f"{row['sheet_sha256'][:12]}; wired by tools/wire_asset.py")
    entry = build_entry("pack", sheet_res, (w, h), [x, y, w, h], pr["anchor"], sib, args.kind,
                        args.fallback, args.fps or 1, comment)
    entry = refuse_duplicate_art(sprite_id, entry, catalog, args, paths)
    plan = WirePlan(sprite_id, entry, 1)
    plan.notes.append(f"pack: bundled sheet {rel_sheet}; sibling {sib[0] if sib else '(none; defaults)'}; "
                      f"probe bbox {pr['bbox']} feet {pr['feet']}/{h} anchor {pr['anchor']}")
    plan.edits.append(TextEdit(paths.sprites, text, sprites_with(text, catalog, sprite_id, entry)))
    ftext = read_text(paths.fixture)
    plan.edits.append(TextEdit(paths.fixture, ftext, fixture_with(ftext, f"{sprite_id}/idle", 1)))
    return plan


# ------------------------------------------------------------ text edits

def splice_top_level(text: str, key: str, value: dict) -> str:
    """splice_json.py's dict-mode append, in memory, with the same proofs."""
    open_idx, close_idx = splice_json.scan_container_span(text, "{", "}", 0)
    indent = splice_json.last_sibling_indent(text, open_idx, close_idx)
    body = '"%s": %s' % (key, splice_json.reindent(json.dumps(value, ensure_ascii=False), indent))
    tail = close_idx
    while tail > 0 and text[tail - 1] in " \t\n":
        tail -= 1
    out = text[:tail] + ",\n" + indent + body + text[tail:]
    before, after = json.loads(text), json.loads(out)
    if key not in after or len(after) != len(before) + 1 or after[key] != value:
        raise Refused(f"sprites.json splice proof failed for {key}")
    if not (out.startswith(text[:tail]) and out.endswith(text[close_idx:])):
        raise Refused("sprites.json splice changed bytes outside the insertion")
    return out


def sprites_with(text: str, catalog: dict, sprite_id: str, entry: dict) -> str:
    existing = catalog.get(sprite_id)
    if existing is not None:
        if existing == entry:
            return text
        raise Refused(f"{sprite_id}: already in sprites.json with different content:\n"
                      f"  have {json.dumps(existing, sort_keys=True)}\n  want {json.dumps(entry, sort_keys=True)}")
    return splice_top_level(text, sprite_id, entry)


def fixture_with(text: str, key: str, frames: int) -> str:
    data = json.loads(text) if text else {"_comment": FIXTURE_COMMENT, "counts": {}}
    counts = data.get("counts")
    if not isinstance(counts, dict):
        raise Refused("sprite_frame_counts.json needs a top-level counts dict (C7)")
    for k, v in counts.items():
        if type(v) is not int:
            raise Refused(f"sprite_frame_counts.json: pin {k} = {v!r} is not an int")
    if text and json.dumps(data, indent=1, sort_keys=True) + "\n" != text:
        raise Refused("sprite_frame_counts.json is not canonical (json.dumps indent=1 sort_keys=True); "
                      "regenerate it before wiring")
    if key in counts and counts[key] != frames:
        raise Refused(f"fixture pin {key} = {counts[key]} already; candidate has {frames} frames")
    counts[key] = frames
    data["counts"] = dict(sorted(counts.items()))
    data.setdefault("_comment", FIXTURE_COMMENT)
    return json.dumps(data, indent=1, sort_keys=True) + "\n"


def provenance_line(sprite_id: str, candidate_rel: str, sha: str, row: dict, pr: dict,
                    frame: tuple[int, int], count: int) -> str:
    gen = f" owned PixelLab generation {row['pixellab_id']};" if row.get("pixellab_id") else ""
    return (f"{sprite_id}/Idle-Sheet.png:{gen} source {candidate_rel}; copied unchanged; "
            f"canvas {pr['w']}x{pr['h']}; frames {count} of {frame[0]}x{frame[1]}; "
            f"alpha {tuple(pr['bbox'])}; feet anchor [0.5, {pr['anchor'][1]}]; sha256 {sha}; "
            f"wired by tools/wire_asset.py.\n")


def provenance_with(text: str, line: str) -> str:
    if line in text:
        return text
    prefix = line.split(":", 1)[0] + ":"
    if any(l.startswith(prefix) for l in text.splitlines()):
        raise Refused(f"provenance already lists {prefix} with different content")
    return text.rstrip("\n") + "\n\n" + line


def bundle_pending_with(text: str, source_sheet: str, candidate_rel: str, sprite_id: str,
                        region: list[int]) -> str:
    if not text:
        text = BUNDLE_PENDING_HEADER
    if any(f"| `{candidate_rel}` |" in l for l in text.splitlines()):
        return text
    row = f"| {date.today().isoformat()} | `{source_sheet}` | `{candidate_rel}` | {sprite_id} | {region} |\n"
    return text.rstrip("\n") + "\n" + row


# ------------------------------------------------------------------ plans

def plan_owned(candidate: Path, sprite_id: str, args: argparse.Namespace, paths: Paths,
               text: str, catalog: dict) -> WirePlan:
    row = manifest_row(candidate, paths)
    with Image.open(candidate) as img:
        w, h = img.size
    fw, fh, count = frame_geometry(w, h, row.get("frame_size"))
    pr = probe(candidate, fw)
    sha = sha256_file(candidate)
    sheet_res = f"res://assets/sprites/{sprite_id}/Idle-Sheet.png"
    sib = sibling(catalog, "owned", args.like, sheet_res, (fw, fh))
    fps = args.fps or (1 if count == 1 else 6)
    entry = build_entry("owned", sheet_res, (fw, fh), None, pr["anchor"], sib, args.kind,
                        args.fallback, fps, "")
    entry = refuse_duplicate_art(sprite_id, entry, catalog, args, paths,
                                 {sheet_res.removeprefix("res://"): sha})
    plan = WirePlan(sprite_id, entry, count)
    plan.notes.append(f"owned: {count} frame(s) of {fw}x{fh}; sibling {sib[0] if sib else '(none; defaults)'}; "
                      f"probe bbox {pr['bbox']} feet {pr['feet']}/{fh} anchor {pr['anchor']}")
    plan.copies.append(Copy(candidate, paths.assets / "sprites" / sprite_id / "Idle-Sheet.png", sha))
    plan.edits.append(TextEdit(paths.sprites, text, sprites_with(text, catalog, sprite_id, entry)))
    ftext = read_text(paths.fixture)
    plan.edits.append(TextEdit(paths.fixture, ftext, fixture_with(ftext, f"{sprite_id}/idle", count)))
    ptext = read_text(paths.provenance)
    rel = candidate.relative_to(paths.repo_root).as_posix()
    line = provenance_line(sprite_id, rel, sha, row, pr, (fw, fh), count)
    plan.edits.append(TextEdit(paths.provenance, ptext, provenance_with(ptext, line)))
    return plan


def render_diff(plan: WirePlan, paths: Paths) -> str:
    lines: list[str] = []
    for c in plan.copies:
        state = "exists, identical" if c.dst.is_file() and sha256_file(c.dst) == c.sha else "new file"
        lines.append(f"COPY {c.src.relative_to(paths.repo_root).as_posix()} -> "
                     f"{c.dst.relative_to(paths.repo_root).as_posix()} sha256 {c.sha[:12]} ({state})\n")
    for e in plan.edits:
        if e.before == e.after:
            continue
        rel = e.path.relative_to(paths.repo_root).as_posix()
        for d in difflib.unified_diff(e.before.splitlines(True), e.after.splitlines(True),
                                      f"a/{rel}", f"b/{rel}"):
            lines.append(d if d.endswith("\n") else d + "\n")
    return "".join(lines)


def apply_plan(plan: WirePlan) -> None:
    for c in plan.copies:
        if not (c.dst.is_file() and sha256_file(c.dst) == c.sha):
            c.dst.parent.mkdir(parents=True, exist_ok=True)
            c.dst.write_bytes(c.src.read_bytes())
    for e in plan.edits:
        if e.before != e.after:
            e.path.parent.mkdir(parents=True, exist_ok=True)
            e.path.write_text(e.after, encoding="utf-8")


def regenerate_candidates(paths: Paths) -> None:
    reg = ac.build(paths.potential, paths.repo_root)
    paths.docs.mkdir(parents=True, exist_ok=True)
    (paths.docs / "asset-candidates.json").write_text(ac.dump_registry(reg), encoding="utf-8")
    (paths.docs / "asset-candidates.md").write_text(ac.summary_md(reg), encoding="utf-8")


# ------------------------------------------------------------------- main

def check_owned_batch(candidate: Path, paths: Paths, args: argparse.Namespace) -> None:
    """Only owned batches (the registry's ^(pixellab|codex) rule) may take the owned path."""
    batch = candidate.relative_to(paths.potential).parts[0]
    if not re.match(r"(pixellab|codex)", batch, re.I):
        raise Refused(f"{candidate.name}: batch '{batch}' is not an owned batch (pixellab_*/codex_*); "
                      "pack art must come in as a _sliced slice with --fallback")
    tier = ac.classify_batch(batch)[1]
    if tier == "owned-unverified" and not args.allow_unverified:
        raise Refused(f"{candidate.name}: batch '{batch}' is {tier} (public redistribution unverified); "
                      "pass --allow-unverified to wire it anyway")


def wire_one(candidate: Path, sprite_id: str, args: argparse.Namespace, paths: Paths) -> bool:
    """Returns True when files changed. Raises Refused/ProbeError/BundlePending."""
    candidate = (candidate if candidate.is_absolute() else paths.repo_root / candidate).resolve()
    if not ID_RE.match(sprite_id):
        raise Refused(f"{sprite_id}: ids are [a-z0-9_]+")
    if sprite_id.startswith("pc_"):
        raise Refused(f"{sprite_id}: pc_* ids are the player's own skin; give it an NPC/prop id")
    if not candidate.is_file():
        raise Refused(f"{candidate}: no such file")
    if paths.potential.resolve() not in candidate.parents:   # potential_assets is a symlink in a worktree
        raise Refused(f"{candidate}: candidates live under potential_assets/")
    candidate = logical_candidate(candidate, paths)   # repo-relative logical path from here on
    text, catalog = load_catalog(paths)
    if args.fallback:
        check_fallback(args.fallback, catalog, bundle_paths(paths))
    if is_slice(candidate):
        try:
            plan = plan_slice(candidate, sprite_id, args, paths, text, catalog)
        except BundlePending as exc:
            if not args.dry_run:
                rel = candidate.relative_to(paths.repo_root).as_posix()
                doc = read_text(paths.bundle_pending)
                new = bundle_pending_with(doc, exc.source_sheet, rel, sprite_id, exc.region)
                if new != doc:
                    paths.bundle_pending.parent.mkdir(parents=True, exist_ok=True)
                    paths.bundle_pending.write_text(new, encoding="utf-8")
            raise
    else:
        check_owned_batch(candidate, paths, args)
        plan = plan_owned(candidate, sprite_id, args, paths, text, catalog)
    for n in plan.notes:
        print(f"{sprite_id}: {n}")
    if plan.is_noop():
        print(f"{sprite_id}: no change (already wired identically)")
        return False
    for c in plan.copies:
        if c.dst.is_file() and sha256_file(c.dst) != c.sha:
            raise Refused(f"{c.dst.relative_to(paths.repo_root)} exists with different bytes")
    diff = render_diff(plan, paths)
    if args.dry_run:
        print(diff, end="")
        print(f"{sprite_id}: DRY-RUN, nothing written (docs/asset-candidates.* would be regenerated)")
        return False
    apply_plan(plan)
    print(f"{sprite_id}: wired, {plan.frames} frame(s). Next: /usr/local/bin/godot --headless --path "
          f"wandering_inn_game --import, then commit the .import sidecar")
    return True


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("candidates", nargs="+", type=Path)
    ap.add_argument("--id", action="append", default=[], help="sprite id; repeat once per candidate")
    ap.add_argument("--kind", choices=("prop", "setpiece"), default="prop")
    ap.add_argument("--fallback", help="owned public sprite id (required for pack slices)")
    ap.add_argument("--like", help="copy render_scale/shadow from this catalog entry")
    ap.add_argument("--fps", type=int, help="default 1 for one frame, 6 for strips")
    ap.add_argument("--allow-unverified", action="store_true",
                    help="permit owned-unverified (codex_*) batches on the owned path")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--alias-of", help="existing id drawing the same art; wires a deliberate second id (#623)")
    ap.add_argument("--reason", help="why the alias exists (required with --alias-of; recorded on the entry)")
    ap.add_argument("--no-regen", action="store_true", help="skip docs/asset-candidates.* rebuild")
    ap.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    args = ap.parse_args(argv)
    if len(args.id) != len(args.candidates):
        print(f"wire_asset: {len(args.candidates)} candidate(s) need exactly {len(args.candidates)} --id value(s)",
              file=sys.stderr)
        return EXIT_USAGE
    if (args.alias_of is None) != (args.reason is None) or (args.reason is not None and not args.reason.strip()):
        print("wire_asset: --alias-of and a non-empty --reason go together", file=sys.stderr)
        return EXIT_USAGE
    if args.alias_of is not None and len(args.candidates) != 1:
        print("wire_asset: --alias-of takes exactly one candidate", file=sys.stderr)
        return EXIT_USAGE
    paths = Paths(args.repo_root)
    rc, any_change = EXIT_OK, False
    for candidate, sprite_id in zip(args.candidates, args.id):
        try:
            any_change = wire_one(candidate, sprite_id, args, paths) or any_change
        except (Refused, ProbeError, BundlePending, DuplicateArt) as exc:
            print(str(exc))
            rc = max(rc, exc.exit_code)
    if any_change and not args.no_regen:
        regenerate_candidates(paths)
        print("docs/asset-candidates.* regenerated")
    return rc


if __name__ == "__main__":
    sys.exit(main())
