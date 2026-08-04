# Dialogue Voice Pass Implementation Plan

**Status:** DONE (2026-08-04 — shipped via voice-pass branch; Fable terminal adjudication SHIP, 205/205 sweep, playtest clean)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the prose of all 71 dialogue files so a trained reader no longer flags the corpus as model-written, with zero structural or factual change.

**Architecture:** A scripted gate freezes everything except `text` values. A Fable agent authors a voice bible + per-cluster constraint cards; Opus agents rewrite in sibling-blind speaker clusters; scripted + cold-reader detection loops failures; Fable adjudicates a sample at close. Orchestration runs in the main session via the Agent tool.

**Tech Stack:** Python 3 (stdlib only) for the gate; Agent tool (`model: "fable"` for W1/W6, default Opus for rewrites/detection); repo skills `wi-usage-guard`, `wi-verifying-changes`, `wi-machine-playtest`.

**Spec:** `docs/superpowers/specs/2026-08-03-dialogue-voice-pass-design.md` (approved 2026-08-03)

## Global Constraints

- Prose lives ONLY in `text` string values (verified by key inventory: 1,482 `text` fields; next-largest string keys are structural). `toast` values (7) are FROZEN — effect surface, not dialogue.
- Byte-identical after rewrite: node keys, `start`, `requires`, **`text_variants` array order** (last-match-wins is load-bearing), `goto` targets, effects (`item`, `quest`, `skill`, `start_combat`, …), `speaker`, `_comment*`. Node count frozen per file.
- Every proper noun, number, item, direction, and instruction in old text survives findable in the same node's new text (numbers may become words).
- Ban budgets: antithesis ≤1/NPC lifetime and ≤30 corpus; buttons ≤1 per conversation graph, never on hub/shop/bark/repeat nodes; sentiment-then-deflect ≤2 corpus; CAPS 0; mid-line and leading ellipsis 0; "the whole of / the entire" 0; prose triads 0 (structure triads fine); theme-naming 0; bureaucracy gag ×1; "apparent object isn't the real one" ≤2 of 4; combat-bark shapes all distinct.
- Replacement mandate: a deleted button is replaced by a concrete physical detail, an action beat, or a plainly unfinished fact — never mere truncation.
- Canon: Book 17 spoiler bar, Vol 7 advertised; "Magical Door", never "[Door of Portals]".
- Wave discipline: `wi-usage-guard` before every dispatch round; judgment calls → CHOICE-LOG, never user-gates mid-wave; no two agents touch one file in a wave.
- All commits from repo root `/Users/gabriel/wandering-inn-rpg`; commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Critique file + gate script + baseline

**Files:**
- Create: `docs/dialogue-voice/critique-2026-08-03.md` (the 11-tell critique, verbatim from the 2026-08-03 conversation — the orchestrating session holds it; it is the W4 rubric source)
- Create: `wandering_inn_game/qa/scripts/dialogue_voice_gate.py`
- Create: `docs/dialogue-voice/baseline/*.json` (generated)

**Interfaces:**
- Produces CLI consumed by Tasks 4–7:
  - `python3 wandering_inn_game/qa/scripts/dialogue_voice_gate.py self-test`
  - `... snapshot --out docs/dialogue-voice/baseline [FILE...]` (default: all corpus files)
  - `... check --baseline docs/dialogue-voice/baseline [--final] [--report PATH] [FILE...]` — exit 0 clean / 1 hard-fail. `--final` additionally enforces corpus antithesis budget (≤30 total, ≤1 per speaker).
- Report JSON shape consumed by W4 aggregator: `{"files": {"<name>": {"status": "PASS|FAIL", "hard": [..], "warn": [..], "antithesis": [{"speaker": s, "node": n, "quote": q}]}}, "antithesis_total": N}`

- [ ] **Step 1: Write the critique file** — `docs/dialogue-voice/critique-2026-08-03.md`, verbatim paste of the user-supplied critique (Percentage / Characteristic tells 1–11 / Worst specific lines / Cheapest fixes tables), prefixed with a one-line provenance header: `> External critique received 2026-08-03; rubric for the dialogue voice pass.`

- [ ] **Step 2: Write the gate script**

```python
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
```

- [ ] **Step 3: Run self-test, expect all 7 cases ok**

Run: `python3 wandering_inn_game/qa/scripts/dialogue_voice_gate.py self-test`
Expected: `self-test: PASS`. Fix the script (not the cases) until it does.

- [ ] **Step 4: Snapshot baseline + no-op check**

Run: `python3 wandering_inn_game/qa/scripts/dialogue_voice_gate.py snapshot --out docs/dialogue-voice/baseline`
Then: `python3 wandering_inn_game/qa/scripts/dialogue_voice_gate.py check --baseline docs/dialogue-voice/baseline`
Expected: `snapshot: 71 files`. The check then FAILS overall — correct: tell detectors fire on the old prose (that is the debt this pass pays; measured 2026-08-03: 48 CAPS, 48 ellipsis, 13 whole/entire, anti=41). Gate-bug test is narrower: the untouched corpus must produce ZERO structure/digit/bracket hard fails (verify: pipe check output through `grep '!' | grep -vE "CAPS|ellipsis|whole of"` — must be empty). If any appear, the gate is buggy; fix before proceeding.

- [ ] **Step 5: Commit**

```bash
git add docs/dialogue-voice/ wandering_inn_game/qa/scripts/dialogue_voice_gate.py
git commit -m "Voice pass Task 1: critique file, gate script, frozen baseline"
```

---

### Task 2: Provisional cluster manifest

**Files:**
- Create: `docs/dialogue-voice/clusters.json`

**Interfaces:**
- Produces manifest consumed by W1 (Fable finalizes it), W2 (dispatch batches), W4 aggregator. Schema:

```json
{"clusters": [{"id": "pisces", "tier": "T3", "files": ["pisces_inn.json", "pisces_magic.json", "pisces_seal.json"], "notes": "same speaker; voice coherence wanted"}],
 "rules": ["same-speaker files always share a cluster",
           "same-tier different-speaker files never share a cluster",
           "each bark file lands in a different cluster"],
 "changelog": []}
```

- [ ] **Step 1: Write the manifest** with these provisional clusters (Fable may move files; moves append to `changelog`):

| id | tier | files |
|---|---|---|
| rags | T0 | rags_inn, rags_meeting, goblin_parley |
| ksmvr | T0 | ksmvr_intro, ksmvr_plates |
| drayman+bark | T0 | drayman_dispute, crab_nest |
| pell+bark | T0 | recruit_pell, corusdeer_range |
| riverfarm-villager | T1 | riverfarm_villager |
| riverfarm-hunter+bark | T1 | riverfarm_hunter, riverfarm_thicket_patch |
| riverfarm-headman | T1 | riverfarm_headman |
| peddler+bark | T1 | peddler_stall, razorbeak_nest |
| relc | T2 | relc_intro, relc_inn, relc_descent |
| selys | T2 | selys_inn, selys_delivery |
| krshia | T2 | krshia_crate, krshia_inn |
| tallyman+bark | T2 | riverfarm_tallyman, kingslayer_den |
| forge-smith | T2 | pallass_forge_smith, pallass_forge_clerk |
| den-keeper+witch | T2+T3 | pallass_den_keeper, riverfarm_witch |
| lift+klbkch | T2+T4 | pallass_lift_attendant, klbkch_inn |
| market-pallass | T2+T4 | pallass_market_clerk, pallass_market_local, market_watchgolems |
| renn+bark | T2 | renn_hammer, gallery_vermin_nest |
| octavia+golem | T2+T4 | octavia, forge_calibration_golem |
| vess+golem | T2+T4 | vess_counter, forge_temper_golem |
| dresk+watch | T2 | dresk_recruit, watch_crate |
| erin | T3 | erin_errand, patron_serving |
| lyonette+ledger | T3 | lyonette_tip, room_ledger, door_mounting, dummies_note |
| zevara | T3 | zevara_intro, zevara_inn |
| olesm | T3 | olesm_intro, olesm_inn |
| pisces | T3 | pisces_inn, pisces_magic, pisces_seal |
| hedault+bark | T3 | hedault_enchanting, boulevard_duel_ring |
| ceria | T3 | ceria_intro, ceria_dig_camp |
| yvlon+xif | T3+T4 | yvlon_intro, xif |
| grimalkin | T3 | grimalkin_inn, pallass_grimalkin |
| wilovan | T3 | invrisil_wilovan, wilovan_inn |
| invrisil-fixer | T3 | invrisil_fixer, invrisil_hired_scribe |
| invrisil-steward | T3 | invrisil_house_steward, invrisil_rest_factor |
| invrisil-prince | T3 | invrisil_merchant_prince, invrisil_stationer_client |
| invrisil-broker | T3 | invrisil_seal_broker |

(34 clusters, 71 files. The four invrisil-pair clusters technically pair same-tier different speakers — acceptable ONLY there because the register gap inside each pair is wide (fixer/scribe, steward/factor, prince/client); Fable may re-split in W1 if convergence risk looks real. All 6 narrator bark files sit in 6 different clusters.)

- [ ] **Step 2: Validate manifest** — every corpus file appears exactly once:

Run: `python3 -c "import json;m=json.load(open('docs/dialogue-voice/clusters.json'));fs=[f for c in m['clusters'] for f in c['files']];import glob,os;corpus={os.path.basename(p) for p in glob.glob('wandering_inn_game/data/dialogue/*.json')};assert sorted(fs)==sorted(corpus) and len(fs)==len(set(fs)),(set(corpus)^set(fs));print('manifest OK:',len(m['clusters']),'clusters',len(fs),'files')"`
Expected: `manifest OK: 34 clusters 71 files`

- [ ] **Step 3: Commit**

```bash
git add docs/dialogue-voice/clusters.json
git commit -m "Voice pass Task 2: provisional speaker-cluster manifest"
```

---

### Task 3: W1 — Fable bible + constraint cards

**Files:**
- Create: `docs/dialogue-voice-bible.md` (Fable-authored)
- Create: `docs/dialogue-voice-cards/<cluster-id>.md` — one per cluster (Fable-authored)
- Modify: `docs/dialogue-voice/clusters.json` (Fable finalizes; changelog records moves)

**Interfaces:**
- Consumes: spec, critique file (Task 1), manifest (Task 2).
- Produces: bible + cards consumed verbatim by every W2/W5 agent. Card format (contract): sections `## <file.json>` each containing `**BANNED:**`, `**FORCED:**`, `**CANON-VOICE:**`, `**SAMPLE:**` (one before/after pair from that actual file).

- [ ] **Step 1: Usage-guard check** — invoke Skill `wi-usage-guard`; proceed per its verdict.

- [ ] **Step 2: Dispatch Fable agent** (Agent tool, `subagent_type: "general-purpose"`, `model: "fable"`, `run_in_background: false`) with this prompt:

> Architecture task: author the voice bible and constraint cards for the Wandering Inn RPG dialogue de-AI pass. You are the adjudicating voice; Opus agents will execute your cards blind to each other.
>
> Read, in order: `docs/superpowers/specs/2026-08-03-dialogue-voice-pass-design.md`, `docs/dialogue-voice/critique-2026-08-03.md`, `docs/dialogue-voice/clusters.json`, and skim 8–10 dialogue files of your choice across tiers from `wandering_inn_game/data/dialogue/` to calibrate.
>
> Deliverables:
> 1. `docs/dialogue-voice-bible.md` — operationalized ban list with corpus budgets (copy from spec §Ban list); tier definitions T0–T4 each with TWO worked before/after pairs taken from real corpus lines; the replacement mandate with three named replacement moves (concrete physical detail / action beat / unfinished fact) each demonstrated; per-tier sentence-stat targets (avg words, subordinate-clause policy, punctuation policy); an allocation table for the scarce budgets — WHICH file keeps the one bureaucracy gag, WHICH ≤2 quests keep the not-the-real-object reveal, WHICH ≤2 nodes keep sentiment-then-deflect, and the ≤30 antithesis allocation by speaker.
> 2. `docs/dialogue-voice-cards/<cluster-id>.md` for every cluster in the manifest — per file: BANNED (tells this file currently exhibits, named with a quoted instance), FORCED (register moves this file must add, e.g. "1 dropped agreement, 1 self-repeat, avg sentence <9 words"), CANON-VOICE (2–3 lines on the character per The Wandering Inn canon), SAMPLE (one full before/after node rewrite from this actual file demonstrating the bar).
> 3. Finalize `docs/dialogue-voice/clusters.json` — move files between tiers/clusters if warranted; every move appended to `changelog` with one-line reason. Keep the three `rules` invariant.
>
> Canon guard: Book 17 spoiler bar, game advertises Vol 7; write "Magical Door", never "[Door of Portals]". Do not change any dialogue file. Return: list of files written, changelog summary, and the allocation table inline.

- [ ] **Step 3: Review Fable output** — orchestrator checks: every cluster has a card file; every card has all four sections per file; allocation table names concrete files for every scarce budget; manifest still validates (re-run Task 2 Step 2 command). Gaps → one follow-up SendMessage to the same agent, not a fresh dispatch.

- [ ] **Step 4: Commit**

```bash
git add docs/dialogue-voice-bible.md docs/dialogue-voice-cards/ docs/dialogue-voice/clusters.json
git commit -m "Voice pass Task 3 (W1): Fable voice bible, 34 constraint cards, final manifest"
```

---

### Task 4: W2 — clustered rewrite rounds

**Files:**
- Modify: `wandering_inn_game/data/dialogue/*.json` (prose only, per cluster ownership)

**Interfaces:**
- Consumes: bible, cards, manifest, gate CLI.
- Produces: rewritten corpus, one commit per round tagged `W2 round N`.

- [ ] **Step 1: Usage-guard** — invoke Skill `wi-usage-guard` before EACH round.

- [ ] **Step 2: Dispatch round** — ≤8 cluster agents per round (Agent tool, default model, parallel, background). One agent per cluster; agent prompt template (fill `<cluster-id>`, `<files>`):

> You are rewriting dialogue prose for the Wandering Inn RPG voice pass. Assume zero prior context.
>
> Read, in order: `docs/dialogue-voice-bible.md`; your card `docs/dialogue-voice-cards/<cluster-id>.md`; the Global Constraints section of `docs/superpowers/plans/2026-08-03-dialogue-voice-pass.md`.
>
> You own exactly these files — touch nothing else, and do not read any other dialogue file: <files, absolute paths under wandering_inn_game/data/dialogue/>.
>
> Per file, in order:
> 1. Read it. Write a fact list to your scratch: per node — proper nouns, numbers, items, directions, player instructions, [Bracket] terms.
> 2. Rewrite ONLY `text` string values (node text, `text_variants[].text`, option text). NEVER touch node keys, `start`, `requires`, `text_variants` order, `goto`, effects, `speaker`, `_comment*`, `toast`. No nodes or options added or removed. Preserve JSON formatting style of the file.
> 3. Apply your card's BANNED and FORCED lists and the bible's tier rules. Replacement mandate: where you delete a button/epigram, replace it with a concrete physical detail, an action beat, or a plainly unfinished fact — never mere truncation. Hub/shop/repeat/bark nodes end flat.
> 4. Verify every fact from step 1 survives in the same node.
> 5. Run `python3 wandering_inn_game/qa/scripts/dialogue_voice_gate.py check --baseline docs/dialogue-voice/baseline <your file names>` and fix until zero hard fails and zero unexplained proper-noun warnings.
>
> Antithesis: your card says whether any speaker of yours holds an allocation; if not, target zero `", not"` constructions.
> Return raw data, not a narrative: per file — node count touched, gate output line, your 3 highest-risk before/after pairs, and any card rule you could not satisfy with the exact reason. Do not restate the bible.

- [ ] **Step 3: Per-round gate + review** — after the round's agents report:

Run: `python3 wandering_inn_game/qa/scripts/dialogue_voice_gate.py check --baseline docs/dialogue-voice/baseline <all files of the round>`
Expected: zero hard fails. Orchestrator skims each agent's 3 risk pairs for flatness (replacement mandate violated → send the pair back to the same agent via SendMessage with the bible's replacement moves named). Judgment calls → CHOICE-LOG.

- [ ] **Step 4: Commit round**

```bash
git add wandering_inn_game/data/dialogue/
git commit -m "Voice pass Task 4 (W2) round N: clusters <ids>"
```

- [ ] **Step 5: Repeat Steps 1–4** until all 34 clusters are through (~5 rounds).

---

### Task 5: W3 — full-corpus final gate

**Files:**
- Create: `docs/dialogue-voice/report-w3.json` (generated)

- [ ] **Step 1: Run final gate**

Run: `python3 wandering_inn_game/qa/scripts/dialogue_voice_gate.py check --baseline docs/dialogue-voice/baseline --final --report docs/dialogue-voice/report-w3.json`
Expected: `CLEAN: 71 files`, antithesis ≤30, no speaker over 1. Any FAIL → fix via the owning cluster's agent (SendMessage) before proceeding; re-run until clean.

- [ ] **Step 2: Commit**

```bash
git add docs/dialogue-voice/report-w3.json wandering_inn_game/data/dialogue/
git commit -m "Voice pass Task 5 (W3): full-corpus gate clean"
```

---

### Task 6: W4 — cold-reader detection

**Files:**
- Create: `docs/dialogue-voice/report-w4.json` (orchestrator-assembled from agent JSON)

**Interfaces:**
- Produces per-file verdicts consumed by Task 7: `[{"file": n, "verdict": "PASS|FAIL", "tell_hits": [{"tell": 1-11, "node": id, "quote": s}], "notes": s}]` plus one aggregator verdict object `{"budget_tells": {"2": ok, "3": ok, "9": ok, "10": ok, "11": ok}, "violations": [...]}`.

- [ ] **Step 1: Usage-guard**, then dispatch per-file cold readers in batches of ≤10 (Agent tool, default model, background). Prompt per file — the agent gets ONLY this (no bible, no cards, no spec):

> You are an adversarial manuscript detector. Read `wandering_inn_game/data/dialogue/<file>` and `docs/dialogue-voice/critique-2026-08-03.md` (the rubric). Nothing else — do not open any other file.
>
> Question: would a trained reader flag this file's prose as model-written, per the rubric's 11 tells? Judge the `text` values only.
>
> Return ONLY this JSON: `{"file": "<file>", "verdict": "PASS"|"FAIL", "tell_hits": [{"tell": <1-11>, "node": "<node key>", "quote": "<exact line>"}], "notes": "<one paragraph>"}`. FAIL means ≥2 distinct strong tells or one egregious instance. Be hostile: a merely-competent line is not a tell; a line you could screenshot for the critique's Worst Lines table is.

- [ ] **Step 2: Dispatch aggregator** (one agent, after all cold readers return) for corpus-budget tells:

> Corpus-budget audit for the Wandering Inn dialogue voice pass. Read `docs/dialogue-voice/critique-2026-08-03.md` tells 2, 3, 9, 10, 11 and `docs/dialogue-voice/report-w3.json`. Then check across ALL of `wandering_inn_game/data/dialogue/` (grep first, read matches): (a) button/epigram closers — flag any conversation graph with >1, any hub/shop/bark node landing one; (b) sentiment-then-deflect shape — count corpus instances, >2 is a violation, quote each; (c) recursive-bureaucracy gag — must appear in exactly 1 file; (d) "apparent object isn't the real one" quest reveals — ≤2 across riverfarm_tallyman, pallass_forge_smith, invrisil_stationer_client, pisces_seal; (e) the six narrator bark files (crab_nest, corusdeer_range, razorbeak_nest, kingslayer_den, gallery_vermin_nest, boulevard_duel_ring) — quote each file's dominant bark shape and fail any two that share the sensory-sentence + dry-understatement template.
> Return ONLY JSON: `{"budget_tells": {"2": true|false, "3": ..., "9": ..., "10": ..., "11": ...}, "violations": [{"tell": n, "files": [...], "quote": "..."}]}` (true = within budget).

- [ ] **Step 3: Assemble + commit** — orchestrator writes both result sets to `docs/dialogue-voice/report-w4.json`:

```bash
git add docs/dialogue-voice/report-w4.json
git commit -m "Voice pass Task 6 (W4): cold-reader verdicts + budget audit"
```

---

### Task 7: W5 — failure loop

**Files:**
- Modify: failing dialogue files; `docs/dialogue-voice/report-w4.json` (updated verdicts)

- [ ] **Step 1: For each W4 FAIL file** — dispatch a FRESH rewrite agent (not the original cluster agent) with the Task 4 Step 2 prompt PLUS, appended: "A cold reader failed this file. Their verdict: <tell_hits + notes verbatim>. Fix exactly what they quote; change nothing that passed." Same for aggregator violations (route to the file's cluster card owner-agent prompt).

- [ ] **Step 2: Re-gate + re-detect** — run the Task 5 Step 1 command for touched files; re-dispatch a cold reader (Task 6 Step 1 prompt) per re-touched file. Max 2 loops per file; a file still failing after 2 goes on the Fable adjudication docket (Task 8) with its history.

- [ ] **Step 3: Commit**

```bash
git add wandering_inn_game/data/dialogue/ docs/dialogue-voice/report-w4.json
git commit -m "Voice pass Task 7 (W5): failure-loop rewrites, all files PASS or docketed"
```

---

### Task 8: W6 — Fable adjudication + QA close

**Files:**
- Create: `docs/dialogue-voice/adjudication.md` (Fable-authored)
- Modify: CHOICE-LOG (per repo convention), `HANDOFF.md`

- [ ] **Step 1: Usage-guard**, then dispatch Fable (Agent tool, `model: "fable"`) :

> Close adjudication for the dialogue voice pass. Read `docs/dialogue-voice/critique-2026-08-03.md`, `docs/dialogue-voice/report-w4.json`, and these files in full: any W5 docket files, plus a 10-file sample you pick spanning all tiers (include at least: one riverfarm T1, rags_inn T0, pisces_magic T3, one invrisil T3, one bark file). Bar: would the original critic still write "~100% model-written"? Write `docs/dialogue-voice/adjudication.md`: per sample file — verdict + the single worst surviving line; overall verdict SHIP / FIX-FIRST with a numbered fix list if FIX-FIRST. Do not edit dialogue files.

- [ ] **Step 2: Execute Fable's fix list** (if FIX-FIRST) via W5 mechanics (Task 7), re-run Task 5 gate, then one Fable SendMessage re-check. SHIP required to proceed.

- [ ] **Step 3: QA sweep** — invoke Skill `wi-verifying-changes`; run the gates it prescribes for a data-only player-facing change (at minimum the `run_qa.sh` sweep). Expected: green, zero new warnings.

- [ ] **Step 4: Machine playtest** — invoke Skill `wi-machine-playtest` (dialogue = player-facing surface; variants must fire, long lines must fit panels — rewrites changed text lengths). Any layout overflow → trim the specific line via owning cluster rules, re-gate that file.

- [ ] **Step 5: Close bookkeeping** — CHOICE-LOG entries for every judgment call logged during waves; HANDOFF.md updated (pass shipped, artifacts index, gate script location, how to re-run detection on future dialogue).

- [ ] **Step 6: Close commit**

```bash
git add -A
git commit -m "Voice pass Task 8 (W6): Fable adjudication SHIP, QA green, playtest clean"
```

---

## Self-review notes

- Spec coverage: preservation contract → Task 1 gate + per-agent rules; tiers → manifest + bible; all 11 ban rules → gate regexes (1,4,5,6) + aggregator (2,3,9,10,11) + cards (7,8); replacement mandate → W2 prompt + orchestrator risk-pair review; waves W1–W6 → Tasks 3–8; verification list → Tasks 5,6,8. Risks table: flatness → risk-pair review + Fable close; re-uniforming → sibling-blind prompts + aggregator (e); fact loss → agent checklist + gate digits/brackets hard + propnoun warns; token weight → usage-guard steps + round batching; T0 drift → T0 cards say strip-only, W4 cold read covers.
- No placeholders: gate script is complete and self-testing; all agent prompts verbatim; manifest enumerated.
- Type consistency: gate CLI flags and report JSON shape identical across Tasks 1/4/5/6/7; card section contract identical in Tasks 3/4.
