#!/usr/bin/env python3
"""Dialogue voice pass gate: freeze structure, detect prose tells.

snapshot: store per-file skeleton (text values masked) + facts (digits,
proper nouns, [Bracket] terms per text field).
check: current skeleton must deep-equal baseline; digits must survive
(numerals or number-words); tell regexes on new prose.
Hard fail -> exit 1. Proper-noun misses are warnings (W4 judges them).
"""
import argparse, json, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
DIALOGUE = REPO / "wandering_inn_game" / "data" / "dialogue"
PROSE_KEYS = {"text"}          # verified by corpus key inventory 2026-08-03
MASK = "§"
NUMBER_WORDS = set("""zero one two three four five six seven eight nine ten
eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen
twenty thirty forty fifty sixty seventy eighty ninety hundred thousand dozen
half quarter first second third fourth fifth sixth seventh eighth ninth tenth
twice thrice single pair both couple""".split())
CAPS_WHITELIST = {"OK"}        # extend deliberately, never to pass a file

RE_CAPS = re.compile(r"\b[A-Z]{3,}\b")
RE_ELLIPSIS = re.compile(r"\.\.\.|…")
RE_WHOLE = re.compile(r"\bthe (?:whole of|entire)\b", re.I)
RE_ANTITHESIS = re.compile(r",\s*not\b")
RE_DIGITS = re.compile(r"\d+")
RE_BRACKET = re.compile(r"\[[^\]]+\]")

MAPS = REPO / "wandering_inn_game" / "data" / "maps"
# GH#388: map prose lives in talk_pool (list[str]) and talk_pool_stages
# ([{lines: [str,...], line: str, ...}]). ORDER AND SIZE ARE CONTRACT --
# talk_pool_stages is last-match-wins, so a reorder is a behavior change,
# not a reword; the skeleton freeze below covers both because list
# positions are part of the skeleton.
MAP_TALK_KEYS = {"talk_pool"}
MAP_STAGE_KEYS = {"talk_pool_stages"}


def walk_map_texts(obj, path="$", in_talk=False):
    """Yield (json_path, value) for every map talk line; recurse the rest.
    talk_banks values are PROSE (measured once, where they are written);
    "@<bank>" refs inside pools are STRUCTURE -- the skeleton freeze keeps
    their identity and order, so a swapped ref is a structural diff, never
    an invisible masked slot."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f"{path}.{k}"
            if k in ("talk_banks", "banks") and isinstance(v, dict):
                # "banks" = maps/_shared_talk.json top-level key (cross-map bank file)
                for name, lines in v.items():
                    if isinstance(lines, list):
                        for i, line in enumerate(lines):
                            if isinstance(line, str):
                                yield f"{p}.{name}[{i}]", line
                continue
            if k in MAP_TALK_KEYS and isinstance(v, list):
                for i, line in enumerate(v):
                    if isinstance(line, str) and not line.startswith("@"):
                        yield f"{p}[{i}]", line
            elif k in MAP_STAGE_KEYS and isinstance(v, list):
                for i, stage in enumerate(v):
                    if isinstance(stage, dict):
                        if isinstance(stage.get("line"), str):
                            yield f"{p}[{i}].line", stage["line"]
                        for j, line in enumerate(stage.get("lines", [])):
                            if isinstance(line, str) and not line.startswith("@"):
                                yield f"{p}[{i}].lines[{j}]", line
            else:
                yield from walk_map_texts(v, p)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from walk_map_texts(v, f"{path}[{i}]")


def map_skeleton(obj, in_talk=False):
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            if k in ("talk_banks", "banks") and isinstance(v, dict):
                out[k] = {name: ([MASK if isinstance(x, str) else map_skeleton(x) for x in lines]
                                 if isinstance(lines, list) else map_skeleton(lines))
                          for name, lines in v.items()}
                continue
            if k in MAP_TALK_KEYS and isinstance(v, list):
                out[k] = [(x if isinstance(x, str) and x.startswith("@")
                           else (MASK if isinstance(x, str) else map_skeleton(x))) for x in v]
            elif k in MAP_STAGE_KEYS and isinstance(v, list):
                st_out = []
                for stage in v:
                    if isinstance(stage, dict):
                        st = {sk: (MASK if sk == "line" and isinstance(sv, str)
                                   else ([(x if isinstance(x, str) and x.startswith("@")
                                           else (MASK if isinstance(x, str) else map_skeleton(x))) for x in sv]
                                         if sk == "lines" and isinstance(sv, list)
                                         else map_skeleton(sv)))
                              for sk, sv in stage.items()}
                        st_out.append(st)
                    else:
                        st_out.append(map_skeleton(stage))
                out[k] = st_out
            else:
                out[k] = map_skeleton(v)
        return out
    if isinstance(obj, list):
        return [map_skeleton(v) for v in obj]
    return obj


def map_speaker_for(data, path):
    """The owning entity's id -- constraint cards apply per speaker."""
    m = re.match(r"\$\.entities\[(\d+)\]", path)
    if m:
        ents = data.get("entities", [])
        i = int(m.group(1))
        if i < len(ents) and isinstance(ents[i], dict):
            return str(ents[i].get("id", "map"))
    return "map"


def walk_texts(obj, path="$"):
    """Yield (json_path, value) for every PROSE_KEYS string; recurse rest.
    Dialogue banks (2026-08-05): "@<name>" refs are STRUCTURE (frozen by the
    skeleton, so a swapped ref is a structural diff); bank values -- both
    file-local `text_banks` and _shared_lines.json `banks` -- are PROSE,
    measured once, where they are written."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f"{path}.{k}"
            if k in ("text_banks", "banks") and isinstance(v, dict):
                for name, line in v.items():
                    if isinstance(line, str):
                        yield f"{p}.{name}", line
                continue
            if k in PROSE_KEYS and isinstance(v, str):
                if not v.startswith("@"):
                    yield p, v
            else:
                yield from walk_texts(v, p)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from walk_texts(v, f"{path}[{i}]")

def skeleton(obj):
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            if k in ("text_banks", "banks") and isinstance(v, dict):
                out[k] = {name: (MASK if isinstance(line, str) else skeleton(line))
                          for name, line in v.items()}
            elif k in PROSE_KEYS and isinstance(v, str):
                out[k] = v if v.startswith("@") else MASK
            else:
                out[k] = skeleton(v)
        return out
    if isinstance(obj, list):
        return [skeleton(v) for v in obj]
    return obj

def propnouns(text):
    out = set()
    for m in re.finditer(r"\b[A-Z][a-z]{2,}\b", text):
        i = m.start()
        prev = text[:i].rstrip()
        if prev and prev[-1] not in ".!?\"'—:":   # not sentence-initial
            out.add(m.group())
    return out

def facts(text):
    return {"digits": sorted(set(RE_DIGITS.findall(text))),
            "propnouns": sorted(propnouns(text)),
            "brackets": sorted(set(RE_BRACKET.findall(text)))}

def speaker_for(data, path):
    """Nearest 'speaker' above a text path; fall back to file-level narrator."""
    m = re.match(r"\$\.nodes\.([^.\[]+)", path)
    if m:
        node = data.get("nodes", {}).get(m.group(1), {})
        if isinstance(node, dict) and isinstance(node.get("speaker"), str):
            return node["speaker"]
    return "narrator"

def snapshot_file(f, outdir, maps_mode=False):
    data = json.loads(f.read_text())
    sk = map_skeleton(data) if maps_mode else skeleton(data)
    walker = walk_map_texts if maps_mode else walk_texts
    base = {"skeleton": sk,
            "facts": {p: facts(t) for p, t in walker(data)}}
    (outdir / f.name).write_text(json.dumps(base, indent=1, sort_keys=True))

def check_file(f, basedir, maps_mode=False):
    hard, warn, anti = [], [], []
    data = json.loads(f.read_text())
    base = json.loads((basedir / f.name).read_text())
    sk = map_skeleton(data) if maps_mode else skeleton(data)
    if sk != base["skeleton"]:
        hard.append("structure differs from baseline (non-text change, "
                    "node add/drop, or reordered text_variants)")
    texts = dict((walk_map_texts if maps_mode else walk_texts)(data))
    for path, old in base["facts"].items():
        new = texts.get(path)
        if new is None:
            continue  # structure mismatch already reported
        low = new.lower()
        for d in old["digits"]:
            if d not in new and not (NUMBER_WORDS & set(re.findall(r"[a-z]+", low))):
                hard.append(f"{path}: digit {d} lost, no number-word present")
        missing = [p for p in old["propnouns"] if p not in new]
        if missing:
            warn.append(f"{path}: proper nouns missing: {', '.join(missing)}")
        for b in old["brackets"]:
            if b not in new:
                hard.append(f"{path}: bracket term {b} lost")
    for path, t in texts.items():
        caps = [c for c in RE_CAPS.findall(t) if c not in CAPS_WHITELIST]
        if caps:
            hard.append(f"{path}: CAPS {caps}")
        if RE_ELLIPSIS.search(t):
            hard.append(f"{path}: ellipsis")
        if RE_WHOLE.search(t):
            hard.append(f"{path}: 'the whole of/entire'")
        for m in RE_ANTITHESIS.finditer(t):
            anti.append({"speaker": (map_speaker_for if maps_mode else speaker_for)(data, path), "node": path,
                         "quote": t[max(0, m.start()-40):m.end()+40]})
    return hard, warn, anti

def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("self-test")
    sp = sub.add_parser("snapshot")
    sp.add_argument("--out", required=True)
    sp.add_argument("--maps", action="store_true", help="GH#388: map talk_pool mode")
    sp.add_argument("files", nargs="*")
    cp = sub.add_parser("check")
    cp.add_argument("--baseline", required=True)
    cp.add_argument("--final", action="store_true")
    cp.add_argument("--maps", action="store_true", help="GH#388: map talk_pool mode")
    cp.add_argument("--report")
    cp.add_argument("files", nargs="*")
    a = ap.parse_args()

    if a.cmd == "self-test":
        return self_test()

    maps_mode = bool(getattr(a, "maps", False))
    if maps_mode:
        files = ([Path(f) for f in a.files]
                 or sorted(MAPS.glob("**/*.json")))
    else:
        files = ([Path(f) if "/" in f else DIALOGUE / f for f in a.files]
                 or sorted(DIALOGUE.glob("*.json")))
    if a.cmd == "snapshot":
        out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
        for f in files:
            snapshot_file(f, out, maps_mode)
        print(f"snapshot: {len(files)} files -> {out}")
        return 0

    report, total_anti, per_speaker, fail = {}, 0, {}, False
    for f in files:
        hard, warn, anti = check_file(f, Path(a.baseline), maps_mode)
        report[f.name] = {"status": "FAIL" if hard else "PASS",
                          "hard": hard, "warn": warn, "antithesis": anti}
        total_anti += len(anti)
        for x in anti:
            per_speaker.setdefault(x["speaker"], []).append(f.name)
        fail |= bool(hard)
        tag = "FAIL" if hard else ("pass" if not warn else "pass*")
        print(f"{tag:5} {f.name}  hard={len(hard)} warn={len(warn)} anti={len(anti)}")
        for h in hard:
            print(f"      ! {h}")
    if a.final:
        if total_anti > 30:
            print(f"FINAL: antithesis corpus budget blown: {total_anti} > 30"); fail = True
        for s, fs in sorted(per_speaker.items()):
            if len(fs) > 1 and s != "narrator":
                print(f"FINAL: speaker '{s}' antithesis x{len(fs)}: {fs}"); fail = True
    if a.report:
        Path(a.report).write_text(json.dumps(
            {"files": report, "antithesis_total": total_anti}, indent=1))
    print(f"{'FAIL' if fail else 'CLEAN'}: {len(files)} files, anti={total_anti}")
    return 1 if fail else 0

def self_test():
    import tempfile
    old = {"start": "a", "nodes": {"a": {"speaker": "Zevara",
           "text": "Bring 3 crates to Liscor by dusk. The [Innkeeper] knows.",
           "options": [{"text": "Fine, not my problem.", "goto": "b"}],
           "text_variants": [{"requires": {"phase": ["night"]}, "text": "Go."}]}}}
    cases = [  # (mutator, expect_hard)
        (lambda d: d["nodes"]["a"].__setitem__(
            "text", "Three crates. Liscor. Before dusk — the [Innkeeper] knows."), False),
        (lambda d: d["nodes"]["a"]["text_variants"].append(
            {"requires": {"phase": ["dawn"]}, "text": "x"}), True),   # structure
        (lambda d: d["nodes"]["a"].__setitem__(
            "text", "Bring 3 crates to Liscor by DUSK. The [Innkeeper] knows."), True),
        (lambda d: d["nodes"]["a"].__setitem__(
            "text", "Bring 3 crates... to Liscor by dusk. The [Innkeeper] knows."), True),
        (lambda d: d["nodes"]["a"].__setitem__(
            "text", "Crates to Liscor by dusk. The [Innkeeper] knows."), True),  # digit lost
        (lambda d: d["nodes"]["a"].__setitem__(
            "text", "Bring 3 crates to Liscor by dusk. That is the entire job. The [Innkeeper] knows."), True),
        (lambda d: d["nodes"]["a"].__setitem__(
            "text", "Bring 3 crates to Liscor by dusk. Rules, not favors. The [Innkeeper] knows."), False),  # anti = warn-count only
    ]
    failures = 0
    with tempfile.TemporaryDirectory() as td:
        td = Path(td); (td / "b").mkdir(); (td / "d").mkdir()
        f = td / "d" / "t.json"
        f.write_text(json.dumps(old)); snapshot_file(f, td / "b")
        for i, (mut, expect) in enumerate(cases):
            data = json.loads(json.dumps(old)); mut(data); f.write_text(json.dumps(data))
            hard, warn, anti = check_file(f, td / "b")
            ok = bool(hard) == expect
            print(f"case {i}: {'ok' if ok else 'WRONG'} hard={hard}")
            failures += 0 if ok else 1
    print("self-test:", "PASS" if not failures else f"{failures} FAILURES")
    return 1 if failures else 0

if __name__ == "__main__":
    sys.exit(main())
