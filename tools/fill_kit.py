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
import shlex
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

EXIT_OK, EXIT_USAGE, EXIT_UNRESOLVED = 0, 2, 5
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


def entry_rendered_h(entry: dict, paths: wa.Paths | None = None) -> float:
    """Rendered gameplay height. Owned entries measure the alpha bbox, as query() does for
    candidates: frame height would class a wired member L and hide its M siblings."""
    idle = (entry.get("animations") or {}).get("idle") or {}
    scale = float(entry.get("render_scale", 1.0))
    if idle.get("region"):
        return float(idle["region"][3]) * scale
    sheet = paths.game / str(idle.get("sheet", "")).replace("res://", "") if paths else None
    if sheet is not None and sheet.is_file():
        try:
            _x0, y0, _x1, y1 = wa.probe(sheet, idle["frame_size"][0])["bbox"]
            return float(y1 - y0) * scale
        except wa.ProbeError:
            pass
    return float(idle["frame_size"][1]) * scale


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


def pool_signatures(catalog: dict, pool: list[str], paths: wa.Paths) -> tuple[set[str], set[tuple]]:
    """(sha256 of owned members' sheets, (sheet, region) of pack members) for the role's pool."""
    shas: set[str] = set()
    regions: set[tuple] = set()
    for sid in pool:
        entry = catalog.get(sid)
        if not isinstance(entry, dict):
            continue
        idle = (entry.get("animations") or {}).get("idle") or {}
        sheet = str(idle.get("sheet", "")).replace("res://", "")
        if idle.get("region"):
            regions.add((sheet, tuple(int(v) for v in idle["region"])))
        elif (paths.game / sheet).is_file():
            shas.add(wa.sha256_file(paths.game / sheet))
    return shas, regions


def not_yet_wired(cands: list[Candidate], shas: set[str], regions: set[tuple]) -> list[Candidate]:
    return [c for c in cands if c.sha not in shas
            and (c.mode != "pack" or (c.sheet, tuple(c.region)) not in regions)]


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
    if args.select and isinstance(((kits.get(args.region) or {}).get("roles") or {}).get(args.role), str):
        raise wa.Refused(f"{args.region}.roles.{args.role} is a fixed sprite; convert it by hand before pooling")
    pool = role_pool_ids(kits, args.region, args.role)
    members = {size_class(entry_rendered_h(catalog[i], paths)) for i in pool if isinstance(catalog.get(i), dict)}
    like = next((i for i in pool if isinstance(catalog.get(i), dict)), None)
    scale = float(catalog[like].get("render_scale", wa.DEFAULT_SCALE["owned"])) if like else wa.DEFAULT_SCALE["owned"]
    shas, regions = pool_signatures(catalog, pool, paths)
    cands = number(not_yet_wired(compatible(query(paths, args.kind, scale), members, args.size), shas, regions)[: args.limit])
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
    import wi_kits_lib as kl  # code from this repo, data from --repo-root

    kits = kl.load_kits(paths.game)
    unresolved = 0
    maps_dir = paths.game / "data" / "maps" / region
    if not maps_dir.is_dir():
        raise wa.Refused(f"no maps under {maps_dir}")
    for mp in sorted(maps_dir.glob("*.json")):
        if mp.name.startswith("_"):
            continue
        m = json.loads(mp.read_text(encoding="utf-8"))
        errors: list = []
        resolved = kl.resolve_map(m, mp.stem, kl.map_region(mp), kits, errors)
        unresolved += len(errors)
        for err in errors:
            print(f"unresolved: {err}", file=sys.stderr)
        for layer in ("decor", "entities"):
            for row in resolved.get(layer, []):
                if row.get("sprite_role") == role:
                    print(f"{mp.stem} {layer} {row.get('cell')} {row['sprite']}")
    return EXIT_UNRESOLVED if unresolved else EXIT_OK




# ----------------------------------------------------- surgical kits.json

def _string_end(text: str, i: int) -> int:
    j = i + 1
    while True:
        c = text[j]
        if c == "\\":
            j += 2
            continue
        if c == '"':
            return j + 1
        j += 1


def _children(text: str, open_idx: int, close_idx: int):
    i = open_idx + 1
    while i < close_idx:
        if text[i] in " \t\r\n,":
            i += 1
            continue
        key_end = _string_end(text, i)
        key = json.loads(text[i:key_end])
        j = text.index(":", key_end) + 1
        while text[j] in " \t\r\n":
            j += 1
        if text[j] in "{[":
            _, vc = splice_json.scan_container_span(text, text[j], "}" if text[j] == "{" else "]", j)
            val_end = vc + 1
        elif text[j] == '"':
            val_end = _string_end(text, j)
        else:
            val_end = re.compile(r"[^,\s\]}]+").match(text, j).end()
        yield key, i, j, val_end
        i = val_end


def _span(text: str, path: list[str]) -> tuple[int, int]:
    o, c = splice_json.scan_container_span(text, "{", "}", 0)
    for key in path:
        for k, _ki, vi, _ve in _children(text, o, c):
            if k == key:
                if text[vi] not in "{[":
                    raise wa.Refused(f"kits.json: {'.'.join(path)} is not a container")
                o, c = splice_json.scan_container_span(text, text[vi], "}" if text[vi] == "{" else "]", vi)
                break
        else:
            raise wa.Refused(f"kits.json: missing key {'.'.join(path)}")
    return o, c


def _item_starts(text: str, o: int, c: int) -> list[int]:
    """Start index of every direct child of the container span (array items or object keys)."""
    if text[o] == "{":
        return [ki for _k, ki, _vi, _ve in _children(text, o, c)]
    out, i = [], o + 1
    while i < c:
        if text[i] in " \t\r\n,":
            i += 1
            continue
        out.append(i)
        if text[i] in "{[":
            _, vc = splice_json.scan_container_span(text, text[i], "}" if text[i] == "{" else "]", i)
            i = vc + 1
        elif text[i] == '"':
            i = _string_end(text, i)
        else:
            i = re.compile(r"[^,\s\]}]+").match(text, i).end()
    return out


def _insert(text: str, o: int, c: int, body_json: str, key: str | None) -> str:
    """Splice one member in. last_sibling_indent returns the whole line prefix, which is
    not whitespace for inline containers, so layout is decided here instead."""
    inline_body = ('"%s": %s' % (key, body_json)) if key is not None else body_json
    if "\n" not in text[o:c]:
        if text[o + 1:c].strip():
            tail = c
            while text[tail - 1] in " \t":
                tail -= 1
            return text[:tail] + ", " + inline_body + text[tail:]
        return text[:o + 1] + inline_body + text[c:]
    if text[o + 1:c].strip():
        last = _item_starts(text, o, c)[-1]
        prefix = text[text.rfind("\n", 0, last) + 1:last]
        tail = c
        while text[tail - 1] in " \t\r\n":
            tail -= 1
        if prefix.strip():
            return text[:tail] + ", " + inline_body + text[tail:]
        body = splice_json.reindent(body_json, prefix)
        if key is not None:
            body = '"%s": %s' % (key, body)
        return text[:tail] + ",\n" + prefix + body + text[tail:]
    line_start = text.rfind("\n", 0, o) + 1
    base = re.match(r"[ \t]*", text[line_start:o]).group(0)
    indent = base + ("\t" if "\t" in base or text.startswith("{\n\t") else " ")
    body = splice_json.reindent(body_json, indent)
    if key is not None:
        body = '"%s": %s' % (key, body)
    return text[:o + 1] + "\n" + indent + body + "\n" + base + text[c:]


def _prove(before: str, after: str, path: list[str]) -> None:
    try:
        node = json.loads(after)
        for key in path:
            node = node[key]
    except (json.JSONDecodeError, KeyError, TypeError) as exc:
        raise wa.Refused(f"kits.json splice produced invalid JSON at {'.'.join(path)}: {exc}") from exc
    pre = 0
    while pre < min(len(before), len(after)) and before[pre] == after[pre]:
        pre += 1
    suf = 0
    while suf < min(len(before), len(after)) - pre and before[-1 - suf] == after[-1 - suf]:
        suf += 1
    if pre + suf < len(before):
        raise wa.Refused("kits.json splice changed bytes outside the insertion")


def add_key(text: str, path: list[str], key: str, value) -> str:
    o, c = _span(text, path)
    if text[o] != "{":
        raise wa.Refused(f"kits.json: {'.'.join(path) or '<root>'} is not an object")
    out = _insert(text, o, c, json.dumps(value, ensure_ascii=False), key)
    _prove(text, out, path + [key])
    return out


def append_item(text: str, path: list[str], value) -> str:
    o, c = _span(text, path)
    if text[o] != "[":
        raise wa.Refused(f"kits.json: {'.'.join(path)} is not an array")
    out = _insert(text, o, c, json.dumps(value, ensure_ascii=False), None)
    _prove(text, out, path)
    return out


def kits_with_pool(text: str, region: str, role: str, ids: list[str], pick: str, module: bool) -> str:
    data = json.loads(text)
    if region not in data:
        text = add_key(text, [], region, {"materials": {}, "roles": {}, "cast": []})
        data = json.loads(text)
    if "roles" not in data[region]:
        text = add_key(text, [region], "roles", {})
        data = json.loads(text)
    spec = data[region]["roles"].get(role)
    if spec is None:
        obj: dict = {"pick": pick}
        if module:
            obj["module"] = True
        obj["pool"] = list(ids)
        return add_key(text, [region, "roles"], role, obj)
    if isinstance(spec, str):
        raise wa.Refused(f"{region}.roles.{role} is a fixed sprite '{spec}'; convert it by hand before pooling")
    have = role_pool_ids(data, region, role)
    for sid in ids:
        if sid not in have:
            text = append_item(text, [region, "roles", role, "pool"], sid)
            have.append(sid)
    return text


# ------------------------------------------------------------- selection

def next_ids(region: str, role: str, n: int, catalog: dict, pool: list[str]) -> list[str]:
    out, k = [], len(pool) + 1
    while len(out) < n:
        sid = f"{region}_{role}_{k}"
        if sid not in catalog and sid not in pool:
            out.append(sid)
        k += 1
    return out


def _cell(value: str) -> str:
    return re.sub(r"[\r\n]+", " ", str(value)).replace("|", "/").strip()


def _open_row(lines: list[str], region: str, role: str) -> int | None:
    for i, line in enumerate(lines):
        cells = [c.strip() for c in line.strip().strip("|").split("|")] if line.startswith("|") else []
        if len(cells) == 7 and cells[0] == region and cells[1] == role and cells[6] == "open":
            return i
    return None


def generation_list_with(text: str, region: str, role: str, have: list[str], need: int,
                         lacked: str, base: str) -> str:
    if not text:
        text = GENERATION_LIST_HEADER
    row = (f"| {_cell(region)} | {_cell(role)} | {_cell(', '.join(have)) or '-'} | {need} | "
           f"{_cell(lacked) or '-'} | {_cell(base) or '-'} | open |")
    lines = text.rstrip("\n").split("\n")
    i = _open_row(lines, region, role)
    if i is not None:
        lines[i] = row
        return "\n".join(lines) + "\n"
    return "\n".join(lines + [row]) + "\n"


def generation_list_closed(text: str, region: str, role: str, have: list[str]) -> str:
    """Close the open (region, role) row as `done <ids>`; rows are never deleted."""
    lines = text.rstrip("\n").split("\n")
    i = _open_row(lines, region, role)
    if i is None:
        return text
    cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
    cells[2] = _cell(", ".join(have))
    cells[6] = "done " + _cell(", ".join(have))
    lines[i] = "| " + " | ".join(cells) + " |"
    return "\n".join(lines) + "\n"


def matching_entry(c: Candidate, catalog: dict, paths: wa.Paths, region: str, role: str,
                   explicit: str | None) -> str | None:
    """An already-wired entry holding this candidate's art, so a re-run after a partial
    failure reuses it. Only this role's auto ids (or the explicit id) qualify: shipped
    entries such as `crate` share pack regions and must not become pool members."""
    auto = re.compile(rf"^{re.escape(region)}_{re.escape(role)}_\d+$")
    for sid, entry in catalog.items():
        if not isinstance(entry, dict) or not (sid == explicit if explicit else auto.match(sid)):
            continue
        idle = (entry.get("animations") or {}).get("idle") or {}
        sheet = str(idle.get("sheet", "")).replace("res://", "")
        if c.mode == "pack":
            if sheet == c.sheet and idle.get("region") and [int(v) for v in idle["region"]] == c.region:
                return sid
        elif not idle.get("region") and (paths.game / sheet).is_file() and wa.sha256_file(paths.game / sheet) == c.sha:
            return sid
    return None


def warn_fallback_set(catalog: dict, pool: list[str]) -> None:
    public: set[str] = set()
    for sid in pool:
        entry = catalog.get(sid) or {}
        idle = (entry.get("animations") or {}).get("idle") or {}
        public.add(entry.get("fallback_sprite") if idle.get("region") else sid)
    public.discard(None)
    if len(public) < 2:
        print(f"warning: public fallback set {sorted(public)} has < 2 distinct owned sprites; lane A lint will refuse this pool")


def select(args: argparse.Namespace, paths: wa.Paths, cands: list[Candidate], ktext: str,
           catalog: dict, pool: list[str], like: str | None) -> int:
    try:
        picks = [int(s) for s in args.select.split(",") if s.strip()]
    except ValueError:
        print(f"fill_kit: --select wants numbers from the listing, got {args.select!r}")
        return EXIT_USAGE
    known = {c.n: c for c in cands}
    if not picks or len(set(picks)) != len(picks) or any(n not in known for n in picks):
        print(f"fill_kit: --select {args.select} is not a set of listed numbers 1..{len(cands)}")
        return EXIT_USAGE
    explicit = args.ids.split(",") if args.ids else None
    if explicit is not None and (len(explicit) != len(picks) or any(not wa.ID_RE.match(i) for i in explicit)):
        print(f"fill_kit: --ids needs {len(picks)} valid id(s)")
        return EXIT_USAGE
    chosen = [known[n] for n in picks]
    reused = [matching_entry(c, catalog, paths, args.region, args.role, explicit[k] if explicit else None)
              for k, c in enumerate(chosen)]
    if explicit:
        ids = explicit
    else:
        fresh = iter(next_ids(args.region, args.role, reused.count(None), catalog,
                              pool + [r for r in reused if r]))
        ids = [r or next(fresh) for r in reused]
    if any(c.mode == "pack" for c, r in zip(chosen, reused) if r is None) and not args.fallback:
        raise wa.Refused("a pack pick needs --fallback <owned public sprite_id> (public builds must not lose the pool)")
    # kits.json must be editable before any wire_asset call mutates anything
    kits_with_pool(ktext, args.region, args.role, ids, args.pick, args.module)
    wired: list[str] = []
    for c, sid, hit in zip(chosen, ids, reused):
        if hit is None:
            argv = [str(c.path), "--id", sid, "--repo-root", str(paths.repo_root), "--no-regen"]
            if c.mode == "pack":
                argv += ["--fallback", args.fallback]
            if like:
                argv += ["--like", like]
            rc = wa.main(argv)
            if rc != 0:
                raise wa.Refused(f"wire_asset exit {rc} for #{c.n} ({c.path.name}); pool not updated. "
                                 f"Already wired, not yet pooled: {wired or 'none'}. "
                                 f"Re-run (wired picks are reused): {rerun_command(args)}")
        wired.append(sid)
    wa.regenerate_candidates(paths)
    new_text = kits_with_pool(ktext, args.region, args.role, wired, args.pick, args.module)
    if new_text != ktext:
        kits_path(paths).write_text(new_text, encoding="utf-8")
    have = role_pool_ids(json.loads(new_text), args.region, args.role)
    warn_fallback_set(wa.load_catalog(paths)[1], have)
    print(f"pool {args.region}/{args.role}: {have}")
    gl = paths.docs / "art-generation-list.md"
    if len(have) < args.need:
        gl.write_text(generation_list_with(wa.read_text(gl), args.region, args.role, have, args.need,
                                           args.lacked, args.base or (have[0] if have else "")), encoding="utf-8")
        print(f"shortfall: pool {len(have)} < need {args.need}; open row in docs/art-generation-list.md")
    elif gl.is_file():
        closed = generation_list_closed(wa.read_text(gl), args.region, args.role, have)
        if closed != wa.read_text(gl):
            gl.write_text(closed, encoding="utf-8")
            print("pool filled: generation-list row closed")
    return EXIT_OK


def rerun_command(args: argparse.Namespace) -> str:
    parts = ["python3", "tools/fill_kit.py", args.region, args.role, "--need", str(args.need)]
    for flag, val in (("--kind", args.kind), ("--size", args.size), ("--select", args.select), ("--ids", args.ids),
                      ("--pick", args.pick), ("--fallback", args.fallback), ("--lacked", args.lacked or None),
                      ("--base", args.base), ("--repo-root", args.repo_root)):
        if val:
            parts += [flag, str(val)]
    if args.module:
        parts.append("--module")
    return " ".join(shlex.quote(x) for x in parts)


def candidate_image(c: Candidate) -> Image.Image:
    with Image.open(c.path) as raw:
        img = raw.convert("RGBA")
    if c.mode == "pack":
        return img
    pr = wa.probe(c.path, c.frame_w)
    x0, y0, x1, y1 = pr["bbox"]
    crop = img.crop((x0, y0, x1, y1))
    size = (max(1, round((x1 - x0) * c.scale)), max(1, round((y1 - y0) * c.scale)))
    return crop.resize(size, Image.NEAREST)


def material_swatches(kits: dict, region: str, paths: wa.Paths) -> list[tuple[str, Image.Image | None]]:
    mats = dict((kits.get("_common") or {}).get("materials") or {})
    mats.update((kits.get(region) or {}).get("materials") or {})
    out = []
    for name, m in mats.items():
        sheet = paths.game / str(m.get("sheet", "")).replace("res://", "")
        coords = m.get("coords") or m.get("face")
        tile = None
        if sheet.is_file() and coords:
            px = int(m.get("tile_px", 16))
            cx, cy = int(coords[0]), int(coords[1])
            with Image.open(sheet) as im:
                tile = im.convert("RGBA").crop((cx * px, cy * px, cx * px + px, cy * px + px))
        out.append((name, tile))
    return out


def render_contact_sheet(cands: list[Candidate], materials: list[tuple[str, Image.Image | None]],
                         out: Path) -> None:
    cols = 8
    bg = (40, 40, 44, 255)
    ones = [candidate_image(c) for c in cands]
    cw = max([CELL] + [im.width + 24 for im in ones])   # 1x is never shrunk; the cell grows instead
    cap = 2 * CELL                                      # only the 2x render may be reduced
    twos, factors = [], []
    for im in ones:
        two = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        two.thumbnail((min(cap, cw), cap), Image.NEAREST)
        twos.append(two)
        factors.append(two.width / im.width)
    swatch_rows = max(1, (len(materials) + cols - 1) // cols)
    swatch_h = swatch_rows * SWATCH_H
    cand_rows = [list(range(r, min(r + cols, len(cands)))) for r in range(0, max(1, len(cands)), cols)]
    heights = [(max([CELL] + [twos[k].height for k in row]), max([24] + [ones[k].height for k in row]))
               for row in cand_rows]
    total_h = swatch_h + sum(a + b + 4 for a, b in heights)
    sheet = Image.new("RGBA", (cols * cw, total_h), bg)
    draw = ImageDraw.Draw(sheet)
    for i, (name, tile) in enumerate(materials):
        x, y = 4 + (i % cols) * CELL, (i // cols) * SWATCH_H + 4
        if tile is not None:
            sheet.alpha_composite(tile.resize((32, 32), Image.NEAREST), (x, y))
        else:
            draw.rectangle((x, y, x + 31, y + 31), outline=(200, 80, 80, 255))
        draw.text((x, y + 34), name[:10], fill=(220, 220, 220, 255))
    y0 = swatch_h
    for row, (a, b) in zip(cand_rows, heights):
        for col, k in enumerate(row):
            c, cx = cands[k], col * cw
            sheet.alpha_composite(twos[k], (cx + (cw - twos[k].width) // 2, y0 + a - twos[k].height))
            if factors[k] != 2:
                draw.text((cx + 2, y0 + 2), f"{factors[k]:g}x", fill=(255, 160, 80, 255))
            sheet.alpha_composite(ones[k], (cx + 2, y0 + a + 2))
            draw.text((cx + cw - 20, y0 + a + 2), str(c.n), fill=(255, 230, 120, 255))
            draw.text((cx + cw - 20, y0 + a + 14), c.size_class, fill=(180, 220, 180, 255))
        y0 += a + b + 4
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)


if __name__ == "__main__":
    sys.exit(main())
