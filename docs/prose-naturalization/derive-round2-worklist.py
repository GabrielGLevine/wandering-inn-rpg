#!/usr/bin/env python3
"""derive-round2-worklist.py -- GH#397 round 2, Task 0.

Freezes docs/prose-naturalization/round2-worklist.jsonl MECHANICALLY,
per the plan (docs/superpowers/plans/2026-08-07-prose-round2-397.md):
never by lane judgment.

Row sources (union, provenance recorded per row):
  reader   -- Phase-5 reader-1 maps-set (B) rows scoring >=55, mapped
              back to corpus ids via sample-key.json. Reader family
              tags ride along.
  census   -- pattern matchers over the CURRENT maps corpus (fresh
              inventory generated to a scratch dir; the frozen Phase-0
              inventory.jsonl is NEVER regenerated in place):
                BUTTON     extract_prose.closer_score(text) >= BUTTON_MIN
                TRIAD      2-4 sentences, final sentence interpretive,
                           earlier sentences concrete
                AFFORD     the affordance formula ("good for", "built
                           to", "waiting to", ...)
                SIMILE     simile-by-type ("like a <noun>", "as X as")
                OBJECT     interpretive marker inside a scenic or
                           functional register string (the
                           over-interpreted-kettle class)
  dup      -- the two corpus duplications the Phase-5 read recorded
              (the talk-only dupe gate cannot see them).

Exclusions (applied AFTER the union; each counted in the report):
  protected-keeps.json + protected-keeps-extra.json, holdout.json ids,
  landmark-registry.json entries with disposition KEEP-AS-IS, and
  dialogue-corpus rows (round 2 is maps-only by user ruling).

Validation: census matchers are scored against reader-1's own family
tags on the mapped B sample (precision/recall for BUTTON, the one
family both instruments claim to measure). Run with --report to see
the numbers without writing the worklist. The matcher constants below
were tuned ONCE against that report; tuning again after freeze is a
work-list edit and needs a CHOICE-LOG entry.
"""

import argparse
import ast
import hashlib
import importlib.util
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs" / "prose-naturalization"
EXTRACT = ROOT / "wandering_inn_game" / "qa" / "scripts" / "extract_prose.py"
OUT = DOCS / "round2-worklist.jsonl"

BUTTON_MIN = 2          # closer_score threshold; tuned vs reader tags
READER_SCORE_MIN = 55   # reader-1 rows at/above this enter the list

RELTURN = re.compile(
    r",\s*which\b|\bpretending\b|\bassumes?\b|\bdoesn't \w+ for it\b|"
    r"\bwhich is itself\b|\blets you see\b", re.I)
GNOMIC = re.compile(
    r"^(nothing|everything|every \w+|no \w+|any \w+) |"
    r"\b(hates|loves|learns|forgives|remembers|refuses|means it)\b", re.I)
TRIPLE = re.compile(r"^[^,.;]{3,45},\s*[^,.;]{3,45},\s*(and|then|the)\b", re.I)
PERSONIFY = re.compile(
    r"\b(finds? \w+ (acceptable|wanting)|keeping polite|has its own|"
    r"its own weather|stops? (smelling|pretending)|settl(es|ed) there)\b", re.I)
PERSIST = re.compile(
    r",\s*and (?:it|he|she|they|the \w+) (?:will|has(?: not)?|have(?: not)?|"
    r"is still|are still|keeps?|stays?|has been \w+ing)\b"
    r"|\band (?:it |he |she |they )?(?:will|would) \w+ tomorrow\b"
    r"|\bhas been \w+ing (?:at that )?for a (?:very )?long time\b"
    r"|\bnot \w+ since\b|\byou decide(?: not)? to\b", re.I)
THEWAY = re.compile(r"\bthe way \w+ \w+ \w+", re.I)
KEEPSGOING = re.compile(
    r"\bkeeps? (?:going|its|the|watch|coming|count)\b", re.I)

INTERPRETIVE = re.compile(
    r"\b(as if|as though|meant (?:to|for)|some(?:one|body)(?:'s)?|"
    r"wants?|remember(?:s|ed)?|knows|forgot(?:ten)?|cared?|care taken|"
    r"habit|patien(?:ce|t)|argu(?:es|ment)|apolog\w*|promise[sd]?|"
    r"refus(?:es|al)|insist(?:s|ence)?|deliberate(?:ly)?|on purpose|"
    r"pride|stubborn\w*|waiting for some|decided|choos[ei]\w*|chose)\b",
    re.I,
)
AFFORDANCE = re.compile(
    r"\b(good for|enough to|built (?:to|for)|made (?:to|for)|"
    r"meant (?:to|for)|ready (?:to|for)|waiting (?:to|for)|"
    r"would do for|could \w+ if)\b",
    re.I,
)
SIMILE = re.compile(r"\blike an? \w+|\bas \w+ as\b", re.I)

DUP_TEXTS = [
    "Low fence rail, bordering the tilled rows.",
    "The bones rise and fall into step behind you.",
]


def load_extract():
    spec = importlib.util.spec_from_file_location("extract_prose", EXTRACT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def fresh_inventory(tmpdir):
    out = Path(tmpdir) / "inventory-current.jsonl"
    subprocess.run(
        [sys.executable, str(EXTRACT), "inventory", "--out", str(out)],
        check=True, cwd=ROOT, capture_output=True,
    )
    return [json.loads(l) for l in out.read_text().splitlines()]


def reader_b_rows():
    """Parse the B = [...] literal out of the phase-5 score sheet."""
    src = (DOCS / "phase5" / "reader1-scores.py").read_text()
    tree = ast.parse(src)
    for node in tree.body:
        if (isinstance(node, ast.Assign)
                and node.targets[0].id == "B"):
            return ast.literal_eval(node.value)
    raise SystemExit("no B list in reader1-scores.py")


def registers():
    reg = {}
    for f in sorted((DOCS / "inventory-classified").glob("*.json")):
        for row in json.load(open(f))["strings"]:
            reg[row["id"]] = row["register"]
    return reg


def is_button(mod, text):
    """Reader-1-shaped BUTTON smoke. Tuned ONCE against reader-1's own
    family tags on the mapped B sample: precision 0.74, recall 0.63,
    6/33 false positives on the <=35-no-BUTTON control. The remaining
    misses are regex-resistant rhetoric (reversal statements, implied
    agency) — the reader source covers those on sampled rows; census
    coverage of unsampled rows is a floor, not a census of truth."""
    ss = mod.sentences(text)
    if not ss:
        return False
    fs, prior = ss[-1], len(ss) > 1
    wc = lambda s: len(s.split())
    return bool(
        (prior and wc(fs) <= 4)
        or RELTURN.search(fs)
        or (TRIPLE.search(fs) and wc(fs) >= 8)
        or (GNOMIC.search(fs) and wc(fs) >= 5)
        or PERSONIFY.search(fs)
        or PERSIST.search(fs)
        or THEWAY.search(fs)
        or (prior and wc(fs) <= 8 and KEEPSGOING.search(fs))
        or (prior and INTERPRETIVE.search(fs)
            and not INTERPRETIVE.search(" ".join(ss[:-1])))
        or mod.closer_score(text) >= BUTTON_MIN
    )


def census_families(mod, text, register):
    fams = []
    ss = mod.sentences(text)
    if is_button(mod, text):
        fams.append("BUTTON")
    if 2 <= len(ss) <= 4:
        head, tail = " ".join(ss[:-1]), ss[-1]
        if INTERPRETIVE.search(tail) and not INTERPRETIVE.search(head):
            fams.append("TRIAD")
    if AFFORDANCE.search(text):
        fams.append("AFFORD")
    if SIMILE.search(text):
        fams.append("SIMILE")
    if register in ("scenic", "functional") and INTERPRETIVE.search(text):
        fams.append("OBJECT")
    return fams


def census_enters(fams, register):
    """A census hit enters the worklist only when the row is likely part
    of the RESIDUAL ENGINE, not merely brushed by one pattern: two or
    more independent families, or a BUTTON landing on scenery/functional
    prose (the over-polished-kettle class the reconciliation names).
    Single-family hits elsewhere are the narrator being allowed one
    move — the per-file ceilings in the bible handle those, not
    re-authorship."""
    return (len(fams) >= 2
            or ("BUTTON" in fams and register in ("scenic", "functional"))
            or "DUP" in fams)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", action="store_true",
                    help="print validation + counts, write nothing")
    args = ap.parse_args()

    mod = load_extract()
    with tempfile.TemporaryDirectory() as td:
        current = fresh_inventory(td)
    maps = {r["id"]: r for r in current if r["id"].startswith("map:")}
    reg = registers()

    keeps = set(json.load(open(DOCS / "protected-keeps.json"))["keeps"])
    keeps |= set(json.load(open(DOCS / "protected-keeps-extra.json")))
    hold = set(json.load(open(DOCS / "holdout.json"))["ids"])
    lm_keep = {
        f"map:{Path(e['file']).relative_to('wandering_inn_game/data/maps')}"
        f":{e['field_path']}"
        for e in json.load(open(DOCS / "landmark-registry.json"))["strings"]
        if e["disposition"] == "KEEP-AS-IS"
    }

    key = json.load(open(DOCS / "sample-key.json"))["maps"]
    b_scores = reader_b_rows()

    picked = {}  # id -> row

    def add(sid, source, fams, score=None):
        if sid not in maps:
            return "missing"
        if sid in keeps or sid in hold or sid in lm_keep:
            return "excluded"
        row = picked.setdefault(sid, {
            "id": sid,
            "file": maps[sid]["file"],
            "field_path": maps[sid]["field_path"],
            "register": reg.get(sid, "NEW-UNCLASSIFIED"),
            "text_sha1": hashlib.sha1(
                maps[sid]["text"].encode()).hexdigest()[:12],
            "families": [], "sources": [], "reader_score": None,
        })
        row["families"] = sorted(set(row["families"]) | set(fams))
        if source not in row["sources"]:
            row["sources"].append(source)
        if score is not None:
            row["reader_score"] = score
        return "added"

    # -- reader source + validation bookkeeping
    stats = {"excluded": 0, "missing": 0}
    reader_button, census_button = set(), set()
    for n, score, fams, _shape, _keep in b_scores:
        sid = key[str(n)][len("map:"):] if False else key[str(n)]
        sid = sid  # ids in the key already carry the map: prefix
        if sid in maps:
            cf = census_families(mod, maps[sid]["text"], reg.get(sid, ""))
            if "BUTTON" in fams.split():
                reader_button.add(sid)
            if "BUTTON" in cf:
                census_button.add(sid)
        if score >= READER_SCORE_MIN:
            r = add(sid, "reader", fams.split(), score)
            if r in stats:
                stats[r] += 1

    # -- census source over the whole current maps corpus
    census_gated_out = 0
    for sid, row in maps.items():
        fams = census_families(mod, row["text"], reg.get(sid, ""))
        if fams and census_enters(fams, reg.get(sid, "")):
            r = add(sid, "census", fams)
            if r in stats:
                stats[r] += 1
        elif fams:
            census_gated_out += 1

    # -- recorded duplications
    for dup in DUP_TEXTS:
        for sid, row in maps.items():
            if row["text"].strip() == dup:
                add(sid, "dup", ["DUP"])

    rows = sorted(picked.values(), key=lambda r: r["id"])

    # -- validation report
    tp = len(reader_button & census_button)
    prec = tp / len(census_button) if census_button else 0.0
    rec = tp / len(reader_button) if reader_button else 0.0
    by_src = {}
    for r in rows:
        for s in r["sources"]:
            by_src[s] = by_src.get(s, 0) + 1
    print(f"worklist rows: {len(rows)}  (expected ~220, stop-and-rescope >320)")
    print(f"by source: {by_src}   excluded: {stats['excluded']}  "
          f"key-ids missing from current corpus: {stats['missing']}  "
          f"census single-family gated out: {census_gated_out}")
    fam_counts = {}
    for r in rows:
        for f in r["families"]:
            fam_counts[f] = fam_counts.get(f, 0) + 1
    print(f"by family: {dict(sorted(fam_counts.items()))}")
    print(f"BUTTON matcher vs reader-1 tags on mapped B sample: "
          f"precision={prec:.2f} recall={rec:.2f} "
          f"(reader n={len(reader_button)}, census n={len(census_button)})")
    new_rows = [r for r in rows if r["register"] == "NEW-UNCLASSIFIED"]
    print(f"NEW-UNCLASSIFIED (post-freeze strings, e.g. #398): {len(new_rows)}")

    if args.report:
        return
    if len(rows) > 320:
        raise SystemExit("STOP: worklist >320 rows — re-scope with the user "
                         "(plan Task 0). Nothing written.")
    with open(OUT, "w") as f:
        for r in rows:
            f.write(json.dumps(r, sort_keys=True) + "\n")
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
