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

def walk_texts(obj, path="$"):
    """Yield (json_path, value) for every PROSE_KEYS string; recurse rest."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f"{path}.{k}"
            if k in PROSE_KEYS and isinstance(v, str):
                yield p, v
            else:
                yield from walk_texts(v, p)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from walk_texts(v, f"{path}[{i}]")

def skeleton(obj):
    if isinstance(obj, dict):
        return {k: (MASK if k in PROSE_KEYS and isinstance(v, str) else skeleton(v))
                for k, v in obj.items()}
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

def snapshot_file(f, outdir):
    data = json.loads(f.read_text())
    base = {"skeleton": skeleton(data),
            "facts": {p: facts(t) for p, t in walk_texts(data)}}
    (outdir / f.name).write_text(json.dumps(base, indent=1, sort_keys=True))

def check_file(f, basedir):
    hard, warn, anti = [], [], []
    data = json.loads(f.read_text())
    base = json.loads((basedir / f.name).read_text())
    if skeleton(data) != base["skeleton"]:
        hard.append("structure differs from baseline (non-text change, "
                    "node add/drop, or reordered text_variants)")
    texts = dict(walk_texts(data))
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
            anti.append({"speaker": speaker_for(data, path), "node": path,
                         "quote": t[max(0, m.start()-40):m.end()+40]})
    return hard, warn, anti

def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("self-test")
    sp = sub.add_parser("snapshot")
    sp.add_argument("--out", required=True)
    sp.add_argument("files", nargs="*")
    cp = sub.add_parser("check")
    cp.add_argument("--baseline", required=True)
    cp.add_argument("--final", action="store_true")
    cp.add_argument("--report")
    cp.add_argument("files", nargs="*")
    a = ap.parse_args()

    if a.cmd == "self-test":
        return self_test()

    files = ([Path(f) if "/" in f else DIALOGUE / f for f in a.files]
             or sorted(DIALOGUE.glob("*.json")))
    if a.cmd == "snapshot":
        out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
        for f in files:
            snapshot_file(f, out)
        print(f"snapshot: {len(files)} files -> {out}")
        return 0

    report, total_anti, per_speaker, fail = {}, 0, {}, False
    for f in files:
        hard, warn, anti = check_file(f, Path(a.baseline))
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
