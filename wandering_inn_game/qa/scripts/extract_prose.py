#!/usr/bin/env python3
"""extract_prose.py -- GH#397 Phase 0/2 measurement layer for prose naturalization.

WHAT THIS IS
    A read-only inventory + sampling + classification tool over every
    player-facing prose string in the game. It NEVER writes into
    wandering_inn_game/data/. Phase 2/3 rewrite lanes execute against its
    output; Phase 5 re-reads its blind sets and holdout.

RELATIONSHIP TO dialogue_voice_gate.py
    Dialogue traversal is IMPORTED from dialogue_voice_gate.py (walk_texts,
    speaker_for) so the two tools can never disagree about what a dialogue
    prose string is. Map traversal is NEW and DISJOINT BY CONSTRUCTION from
    that gate's `--maps` walker:

      dialogue_voice_gate.walk_map_texts  ->  talk_pool / talk_pool_stages /
          talk_banks / banks   (GH#388 scope, closed, gated)
      extract_prose.walk_map_prose        ->  everything else player-facing
          (GH#397 scope, this issue)

    self-test asserts the two yield non-overlapping (file, json_path) sets
    over the real corpus. If that assertion ever fails, one walker has grown
    into the other's register and the counts in both issues are wrong.

MAP PROSE FIELD LIST (the contract; derived by full key census of
data/maps/**/*.json 2026-08-05, not guessed)

  INCLUDED -- string-valued keys:
    observe                    338   object/entity examine text
    toast                      205   generic interaction resolution
    locked_toast                61   gate refusal (skill/item absent)
    skill_hint_toast            48   "this wants a Skill" nudge
    once_per_waking_toast       20   already-done-today no-op
    friendly_line               19   NPC warm-reaction line
    open_toast                  14   container open resolution
    gate_closed_toast           14   gate-closed variant
    taken_toast                  8   item/companion acquired
    item_hint_toast              7   "this wants an item" nudge
    copy                         5   readable in-world document (board rumors)
    victory_toast                3   post-combat resolution
    sleep_toast                  3   sleep resolution
    unsteady_toast               2   footing refusal
    second_visit_toast           2   revisit variant
    kindle_toast                 2   [Firefly] outcome
    anchor_toast                 1   [Rope Work] outcome
    tame_refusal_toast           1   tame refusal
    light_toast                  1   [Light] outcome
    clean_toast                  1   [Basic Cleaning] outcome
    repair_toast                 1   [Basic Repair] outcome
    burn_toast                   1   [Firefly] outcome
    text                        72   $.arrival_toasts[].text (map arrival) and
                                     $.entities[].dialogue[].text (ambient NPC speech)
  INCLUDED -- list-of-string keys:
    interior_flavor          1 + 17  "nothing there" no-op flavour (str or list)

  Generalized rule: key == "toast" or key.endswith("_toast") is the whole
  toast family, so a future map that adds e.g. `douse_toast` is picked up
  automatically. TOAST_KEYS_SEEN pins what exists today; `field-census`
  reports any string key not in the include or exclude list, so field drift
  surfaces as a report rather than as silently missing prose.

  EXCLUDED, and why:
    talk_pool, talk_pool_stages (+ its `lines`/`line`), talk_banks, banks
        GH#388's closed register. Already gated by dialogue_voice_gate --maps.
        Verified: `lines` occurs ONLY under talk_pool_stages.
    display_name (431)
        Player-facing but a NAME, not prose. Renaming props is out of scope
        (pins, quest text and QA scripts reference these strings by value).
    keys beginning "_" (_comment, _pick, _light_comment, ...)  (~400)
        Author notes. Never rendered.
    id, kind, sprite, sheet, facing, conversation, speaker, to_map, arena,
    biome, preset, cells, rect, npc, item, counter, state_counter, echo_of,
    companion, companion_id, requires_skill, requires_item, remove_item,
    requires_weapon_family, accomplishment, on_*_accomplishment,
    banks_accomplishment, on_victory, contains, roster, enemies, allies,
    phase, pool, tint/cell/grid numerics
        Structure, ids, and mechanics.

DIALOGUE PROSE FIELD LIST
    Whatever dialogue_voice_gate.walk_texts yields: `text` at node level,
    `options[].text`, `text_variants[].text`, plus file-local `text_banks`
    values and _shared_lines.json `banks` values. "@ref" strings are
    STRUCTURE and are skipped there (and therefore here).

DETERMINISM
    * files walked in sorted() order; strings emitted in document order
    * inventory JSONL sorted by id; json.dumps(sort_keys=True)
    * every shuffle uses random.Random(SEED) with SEED pinned below and
      restated in the artifact headers
    Re-running any subcommand on the same tree is byte-identical.

USAGE
    python3 qa/scripts/extract_prose.py self-test
    python3 qa/scripts/extract_prose.py field-census
    python3 qa/scripts/extract_prose.py inventory --out DIR/inventory.jsonl
    python3 qa/scripts/extract_prose.py blind      --inventory F --outdir DIR
    python3 qa/scripts/extract_prose.py holdout    --inventory F --outdir DIR
    python3 qa/scripts/extract_prose.py classify   --inventory F --outdir DIR
    python3 qa/scripts/extract_prose.py heatmap    --inventory F --out FILE
    python3 qa/scripts/extract_prose.py all        --outdir DIR
"""
import argparse, collections, importlib.util, json, random, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
GAME = REPO / "wandering_inn_game"
MAPS = GAME / "data" / "maps"

# ---- the ONE seed. Restated in every artifact header. ------------------------
SEED = 397
BLIND_SAMPLE_N = 120          # >= 100 required by the issue; 120 for headroom
BLIND_MIN_WORDS = 6           # a review row needs enough text to judge
HOLDOUT_FRACTION = 0.10

# ---- import the gate's dialogue walkers (never edit that file) ---------------
_spec = importlib.util.spec_from_file_location(
    "dialogue_voice_gate", Path(__file__).resolve().parent / "dialogue_voice_gate.py")
GATE = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(GATE)

# ---- map prose field contract ------------------------------------------------
MAP_PROSE_KEYS = {"observe", "friendly_line", "interior_flavor", "copy", "text"}
TOAST_KEYS_SEEN = {
    "toast", "locked_toast", "skill_hint_toast", "once_per_waking_toast",
    "open_toast", "gate_closed_toast", "taken_toast", "item_hint_toast",
    "victory_toast", "sleep_toast", "unsteady_toast", "second_visit_toast",
    "kindle_toast", "anchor_toast", "tame_refusal_toast", "light_toast",
    "clean_toast", "repair_toast", "burn_toast",
}
SKIP_SUBTREES = {"talk_pool", "talk_pool_stages", "talk_banks", "banks"}
KNOWN_NON_PROSE = {
    "display_name", "id", "kind", "sprite", "sheet", "facing", "conversation",
    "speaker", "to_map", "arena", "biome", "preset", "cells", "rect", "npc",
    "item", "counter", "state_counter", "echo_of", "companion", "companion_id",
    "requires_skill", "requires_item", "remove_item", "requires_weapon_family",
    "accomplishment", "on_interact_accomplishment", "on_enter_accomplishment",
    "on_open_accomplishment", "banks_accomplishment", "on_victory",
    # structural list-of-string keys
    "contains", "roster", "enemies", "allies", "phase", "pool",
}
ACC_KEYS = ("on_interact_accomplishment", "on_open_accomplishment",
            "on_enter_accomplishment", "accomplishment", "banks_accomplishment",
            "on_victory")


def is_toast_key(k):
    return k == "toast" or k.endswith("_toast")


def is_prose_key(k):
    return k in MAP_PROSE_KEYS or is_toast_key(k)


def _accs(d):
    out = []
    for k in ACC_KEYS:
        v = d.get(k)
        if isinstance(v, str):
            out.append(v)
        elif isinstance(v, list):
            out += [x for x in v if isinstance(x, str)]
    return sorted(set(out))


def _entity_ctx(d):
    return {
        "entity_id": d.get("id"),
        "entity_kind": d.get("kind"),
        "display_name": d.get("display_name"),
        "requires_skill": d.get("requires_skill"),
        "conversation": d.get("conversation"),
        "banks": _accs(d),
    }


EMPTY_CTX = {"entity_id": None, "entity_kind": None, "display_name": None,
             "requires_skill": None, "conversation": None, "banks": []}


def walk_map_prose(obj, path="$", ctx=None, owner=None):
    """Yield (json_path, value, ctx, field) for every player-facing map prose
    string. Disjoint from GATE.walk_map_texts by construction (SKIP_SUBTREES).

    An entity dict (`id` + `kind`) establishes context for everything under it,
    so ambient `entities[].dialogue[].text` carries its speaker's entity.

    `owner` carries the OUTERMOST prose key down through containers, because a
    prose field is not always a bare string. Shapes that actually occur:
        "observe": "..."                                str
        "interior_flavor": ["...", "..."]               list[str]
        "sleep_toast": [{"requires": {...},             list[dict] -- conditional
                         "text": "..."}, ...]              variants, 7 strings
    A non-prose key RESETS owner to None, so structural strings inside a
    variant dict (`requires.phase: ["dusk"]`) are never mistaken for prose.
    The 7 sleep_toast-variant strings are exactly why the walker recurses
    instead of assuming str|list[str]; self-test's census cross-check is what
    caught them."""
    if ctx is None:
        ctx = EMPTY_CTX
    if isinstance(obj, dict):
        if "id" in obj and "kind" in obj:
            ctx = _entity_ctx(obj)
        for k, v in obj.items():
            if k in SKIP_SUBTREES or k.startswith("_"):
                continue
            p = f"{path}.{k}"
            own = (owner or k) if is_prose_key(k) else None
            if isinstance(v, str):
                if own:
                    yield p, v, ctx, own
            else:
                yield from walk_map_prose(v, p, ctx, own)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            p = f"{path}[{i}]"
            if isinstance(v, str):
                if owner:
                    yield p, v, ctx, owner
            else:
                yield from walk_map_prose(v, p, ctx, owner)


# ---- tell-family heuristics (SMOKE DETECTORS, never verdicts) ----------------
# Every regex below is advisory. The issue is explicit that most of this is
# perceptual; these exist to RANK work, not to grade prose.
RE_SENT = re.compile(r"[^.!?]+[.!?]*")
RE_ANON = re.compile(r"\b(someone|somebody|whoever|whatever|something|nobody|anyone)\b", re.I)
RE_WHICH_FROM = re.compile(r"\bwhich\s+(?:from|for|in)\s+\w+\s+(?:is|was|counts|passes)\b", re.I)
RE_THE_WAY_X = re.compile(r"\bthe way (?:a|an|the|you|one|\w+)\s+\w+\s+(?:does|do|is|are|was)\b", re.I)
RE_NOUN_REPEAT = re.compile(r"\bthe (\w{3,}) is (?:only |just |still )?the \1\b", re.I)
RE_NEG_CORRECTION = [
    re.compile(r",\s*not\b", re.I),                                   # gate's own
    re.compile(r"\bnot\s+(?:a|an|the)\s+[\w'-]+\s*[.!]", re.I),       # "Not a prisoner."
    re.compile(r"\b(?:is|was|are|were)\s+not\s+[^.;!?]{1,60}[;.]\s*(?:it|that|this|they)\s+(?:is|was|are)\b", re.I),
    re.compile(r"\bnot\s+(?:the\s+)?same\s+(?:as|thing)\b", re.I),
    re.compile(r"\b(?:isn't|wasn't|aren't|weren't)\s+[^.;!?]{1,50}[.;]\s*[A-Z]", re.I),
]
RE_COPULAR_THESIS = re.compile(
    r"\b(?:is|was|are|were)\s+(?:the|not|only|all|nobody|never|what|how|why)\b", re.I)
ABSTRACT_CLOSER_NOUNS = set("""point whole price rent cost kind thing things word words
answer question difference reason matter truth sort applause courtesy vocabulary
document habit purpose mercy kindness gratitude luck honesty pride shame respect
politeness manners standard standards rule rules order faith trust promise
proof evidence meaning story history memory""".split())
IMPERATIVE_STARTS = set("""go take bring put set come look listen wait stop keep leave
find ask tell give hold mind step move try use pull push open close read carry
follow watch stay turn drop pick""".split())


def sentences(text):
    return [s.strip() for s in RE_SENT.findall(text) if s.strip()]


def wc(s):
    return len(s.split())


def closer_score(text):
    """0-5 smoke score that a passage lands a polished button.
    >=2 == flagged. Deliberately crude; documented as such in the rubric."""
    ss = sentences(text)
    if not ss:
        return 0
    fs, prior = ss[-1], " ".join(ss[:-1])
    score = 0
    if RE_COPULAR_THESIS.search(fs):
        score += 2
    if RE_NOUN_REPEAT.search(fs) or RE_WHICH_FROM.search(fs) or RE_THE_WAY_X.search(fs):
        score += 2
    if any(p.search(fs) for p in RE_NEG_CORRECTION):
        score += 1
    toks = {w.strip(".,;:!?\"'").lower() for w in fs.split()}
    if toks & ABSTRACT_CLOSER_NOUNS:
        score += 1
    first = fs.split()[0].strip(".,;:!?\"'").lower() if fs.split() else ""
    if prior and wc(fs) <= 10 and wc(prior) >= 12 and first not in IMPERATIVE_STARTS:
        score += 1
    return min(score, 5)


def tells(text):
    """Per-string advisory tell flags, by the issue's six families."""
    ss = sentences(text)
    fs = ss[-1] if ss else ""
    return {
        "neg_correction": sum(len(p.findall(text)) for p in RE_NEG_CORRECTION),
        "anon_agent": len(RE_ANON.findall(text)),
        "which_from": len(RE_WHICH_FROM.findall(text)),
        "the_way_x": len(RE_THE_WAY_X.findall(text)),
        "noun_repeat_wit": len(RE_NOUN_REPEAT.findall(text)),
        "caps": [c for c in GATE.RE_CAPS.findall(text) if c not in GATE.CAPS_WHITELIST],
        "closer_score": closer_score(text),
        "sentences": len(ss),
        "final_sentence_words": wc(fs),
    }


# ---- inventory ---------------------------------------------------------------
def build_inventory():
    rows = []
    for f in sorted(GATE.DIALOGUE.glob("*.json")):
        data = json.loads(f.read_text())
        for path, text in GATE.walk_texts(data):
            rows.append({
                "id": f"dlg:{f.name}:{path}",
                "corpus": "dialogue",
                "file": f"wandering_inn_game/data/dialogue/{f.name}",
                "region": "dialogue",
                "graph": f.stem,
                "field_path": path,
                "field": path.rsplit(".", 1)[-1].split("[")[0],
                "speaker": GATE.speaker_for(data, path),
                "entity": None,
                "is_player_option": ".options[" in path,
                "text": text,
                "word_count": wc(text),
                "tells": tells(text),
            })
    for f in sorted(MAPS.glob("**/*.json")):
        rel = f.relative_to(MAPS).as_posix()
        region = rel.split("/")[0] if "/" in rel else "_root"
        data = json.loads(f.read_text())
        for path, text, ctx, field in walk_map_prose(data):
            rows.append({
                "id": f"map:{rel}:{path}",
                "corpus": "maps",
                "file": f"wandering_inn_game/data/maps/{rel}",
                "region": region,
                "graph": f.stem,
                "field_path": path,
                "field": field,
                "speaker": None,
                "entity": ctx,
                "is_player_option": False,
                "text": text,
                "word_count": wc(text),
                "tells": tells(text),
            })
    rows.sort(key=lambda r: r["id"])
    return rows


def load_inventory(p):
    return [json.loads(l) for l in Path(p).read_text().splitlines() if l.strip()]


def write_inventory(rows, out):
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("".join(
        json.dumps(r, sort_keys=True, ensure_ascii=False) + "\n" for r in rows))


# ---- register classification -------------------------------------------------
# Four registers from the issue's Phase 1. The heuristic assigns a PROPOSAL
# plus a one-word rationale tag; docs/prose-naturalization/classification-
# overrides.json records hand-audit corrections as data so the result stays
# reproducible. Landmark is the scarce register and is hand-audited in full.

# Cast roster, DERIVED from data/dialogue/**.speaker so it can't go stale:
# every capitalised token of a speaker label that isn't a title/role word.
# Used only to spot map prose that characterises a named cast member --
# tell family 4 (motif saturation) lives there.
TITLE_WORDS = set("""a an the and of by in with who came lady ring box forge tier
clerk smith former headman lift attendant hunter scribe hour man rented table den
shop keeper master house factor tallyman sergeant woman carriage goblin warband
hungry patron peddler villager watch regulars stray corusdeer boulder shapes
training dummies miscalibrated golem golems calibration rig small dark something
stone market local razorbeak nest creeping thicket team""".split())


def cast_roster():
    names = set()
    for f in sorted(GATE.DIALOGUE.glob("*.json")):
        for n in json.loads(f.read_text()).get("nodes", {}).values():
            if isinstance(n, dict) and isinstance(n.get("speaker"), str):
                for tok in re.findall(r"[A-Za-z']+", n["speaker"]):
                    if len(tok) >= 4 and tok.lower() not in TITLE_WORDS and tok[0].isupper():
                        names.add(tok)
    return frozenset(names)


CAST = None  # lazily filled; frozenset of cast surnames/given names


def names_cast(text):
    global CAST
    if CAST is None:
        CAST = cast_roster()
    return sorted(n for n in CAST if re.search(rf"\b{re.escape(n)}\b", text))


FUNCTIONAL_FIELDS = {
    "skill_hint_toast", "item_hint_toast", "locked_toast", "gate_closed_toast",
    "once_per_waking_toast", "unsteady_toast", "tame_refusal_toast",
    "interior_flavor", "taken_toast",
}
SKILL_OUTCOME_FIELDS = {"kindle_toast", "anchor_toast", "light_toast",
                        "clean_toast", "repair_toast", "burn_toast"}
LANDMARK_CANDIDATE_FIELDS = {"victory_toast", "sleep_toast", "second_visit_toast"}


def classify_row(r, overrides):
    """-> (register, rationale_tag). Overrides win and are recorded by id."""
    if r["id"] in overrides:
        o = overrides[r["id"]]
        return o["register"], o.get("tag", "audited")
    f, ctx = r["field"], r["entity"] or EMPTY_CTX
    if f in FUNCTIONAL_FIELDS:
        return "functional", "gate" if "locked" in f or "hint" in f else "noop"
    if f in SKILL_OUTCOME_FIELDS:
        return "functional", "skill-outcome"
    if f == "friendly_line":
        return "character-bearing", "npc-reaction"
    if f == "text":
        if ".dialogue[" in r["field_path"]:
            return "character-bearing", "ambient-speech"
        return "scenic", "arrival"
    if f == "copy":
        return "functional", "document"
    if ctx["entity_kind"] == "npc":
        return "character-bearing", "npc-space"
    if ctx["entity_kind"] == "door":
        return "functional", "wayfinding"
    # LANDMARK is the scarce register, so the rule demands EVIDENCE: a
    # resolution field that actually banks progress (a quest/discovery beat),
    # not merely any open/sleep toast. Hand-audit 2026-08-05 found the
    # field-only rule swept in lift rides, guest cots and "Your own bed." --
    # traversal and rest resolutions, which are functional.
    if f in LANDMARK_CANDIDATE_FIELDS or f == "open_toast":
        if ctx["banks"]:
            return "landmark", "payoff"
        return "functional", "traversal"
    # Prose that characterises a NAMED cast member is character-bearing even on
    # a prop -- that is where motif saturation (tell 4) actually lives.
    if names_cast(r["text"]):
        return "character-bearing", "names-cast"
    # Banking an accomplishment makes a prop QUEST-LOAD-BEARING, not
    # character-revealing. Keep it scenic but tag it, because Phase 2 must
    # preserve its facts with extra care (quest gating reads them).
    if ctx["banks"]:
        return "scenic", "quest-prop"
    return "scenic", "prop"


def load_overrides(outdir):
    p = Path(outdir) / "classification-overrides.json"
    if not p.exists():
        return {}
    d = json.loads(p.read_text())
    return {k: v for k, v in d.items() if not k.startswith("_")}


# ---- blind sets --------------------------------------------------------------
def blind_pool(rows, corpus):
    return [r for r in rows
            if r["corpus"] == corpus and r["word_count"] >= BLIND_MIN_WORDS]


def make_blind(rows, corpus):
    pool = blind_pool(rows, corpus)
    rng = random.Random(SEED)
    picked = rng.sample(sorted(pool, key=lambda r: r["id"]),
                        min(BLIND_SAMPLE_N, len(pool)))
    rng.shuffle(picked)
    return picked


BLIND_HEADER = """# BLIND REVIEW VIEW -- {corpus}
# GH#397 Phase 0. {n} strings, shuffled with random.Random({seed}).
# Metadata deliberately stripped: no filenames, no speakers, no schema keys,
# no region. Row numbers are the ONLY handle; sample-key.json maps them back.
# Read each row cold. Score per review-rubric.md. Do not seek context.
# ---------------------------------------------------------------------------

"""


def write_blind(picked, corpus, outdir):
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    body = BLIND_HEADER.format(corpus=corpus, n=len(picked), seed=SEED)
    for i, r in enumerate(picked, 1):
        # single-line normalization keeps the review view uniform; the
        # inventory holds the byte-exact original.
        t = " ".join(r["text"].split())
        body += f"{i:3}. {t}\n\n"
    (outdir / f"sample-{corpus}-blind.txt").write_text(body)
    return {str(i): r["id"] for i, r in enumerate(picked, 1)}


# ---- protected keeps + holdout ----------------------------------------------
# Seeded from the issue's own counterevidence list, resolved from file:line to
# inventory id at build time so a reformat can never silently re-point them.
ISSUE_KEEPS = [
    ("wandering_inn_game/data/dialogue/relc_descent.json", 6,
     "issue-counterevidence: Relc's deep-tunnel joke, voice-distinctive"),
    ("wandering_inn_game/data/dialogue/erin_errand.json", 309,
     "issue-counterevidence: 'being smug at pigeons'"),
    ("wandering_inn_game/data/dialogue/drayman_dispute.json", 17,
     "issue-counterevidence: axle-pin reasoning unfolds messily"),
    ("wandering_inn_game/data/dialogue/rags_meeting.json", 415,
     "issue-counterevidence: Rags miscounts and self-corrects"),
    ("wandering_inn_game/data/maps/riverfarm/witch_hut.json", 240,
     "issue-counterevidence: banked ash earns its reversal from evidence"),
]


def text_at_line(repo_rel, lineno):
    """The JSON string value on a 1-indexed line of a pretty-printed data file."""
    lines = (REPO / repo_rel).read_text().splitlines()
    if not 1 <= lineno <= len(lines):
        return None
    m = re.search(r':\s*"(.*)"\s*,?\s*$', lines[lineno - 1])
    if not m:
        m = re.search(r'^\s*"(.*)"\s*,?\s*$', lines[lineno - 1])
    if not m:
        return None
    try:
        return json.loads('"' + m.group(1) + '"')
    except Exception:
        return None


def resolve_issue_keeps(rows):
    by_file = collections.defaultdict(list)
    for r in rows:
        by_file[r["file"]].append(r)
    out, unresolved = {}, []
    for path, line, why in ISSUE_KEEPS:
        t = text_at_line(path, line)
        hit = None
        if t is not None:
            for r in by_file.get(path, []):
                if r["text"] == t:
                    hit = r
                    break
        if hit:
            out[hit["id"]] = {"reason": why, "source": f"{path}:{line}"}
        else:
            unresolved.append(f"{path}:{line}")
    return out, unresolved


def make_holdout(rows, protected_ids, blind_ids):
    """~10% of the inventory, disjoint from protected keeps AND from the blind
    sets (Phase 5 re-reads the revised blind sample against an UNTOUCHED
    holdout -- overlap would destroy that comparison)."""
    pool = sorted(r["id"] for r in rows
                  if r["id"] not in protected_ids and r["id"] not in blind_ids)
    rng = random.Random(SEED + 1)
    # 10% OF THE WHOLE INVENTORY, drawn from the eligible pool -- so the
    # holdout is a true tenth of the corpus, not a tenth of what's left over.
    n = min(round(len(rows) * HOLDOUT_FRACTION), len(pool))
    return sorted(rng.sample(pool, n))


# ---- subcommands -------------------------------------------------------------
def cmd_field_census():
    """Report every string/list-of-string key in maps, bucketed. Drift guard."""
    inc, exc, unknown = collections.Counter(), collections.Counter(), collections.Counter()

    def walk(o):
        if isinstance(o, dict):
            for k, v in o.items():
                if k in SKIP_SUBTREES:
                    continue
                if isinstance(v, str) or (isinstance(v, list) and v and
                                          all(isinstance(x, str) for x in v)):
                    n = 1 if isinstance(v, str) else len(v)
                    if k.startswith("_"):
                        exc[k] += n
                    elif is_prose_key(k):
                        inc[k] += n
                    elif k in KNOWN_NON_PROSE:
                        exc[k] += n
                    else:
                        unknown[k] += n
                if not isinstance(v, str):
                    walk(v)
        elif isinstance(o, list):
            for x in o:
                walk(x)

    for f in sorted(MAPS.glob("**/*.json")):
        walk(json.loads(f.read_text()))
    print("INCLUDED prose keys:")
    for k, c in sorted(inc.items()):
        star = "" if (k in MAP_PROSE_KEYS or k in TOAST_KEYS_SEEN) else "  <-- NEW TOAST KEY"
        print(f"  {c:5}  {k}{star}")
    print(f"  TOTAL {sum(inc.values())}")
    print("\nUNKNOWN keys (neither prose nor known-structural -- TRIAGE THESE):")
    for k, c in sorted(unknown.items()):
        print(f"  {c:5}  {k}")
    if not unknown:
        print("  (none)")
    return 1 if unknown else 0


def cmd_all(outdir):
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    rows = build_inventory()
    write_inventory(rows, outdir / "inventory.jsonl")

    # blind sets + key
    key = {"_seed": SEED, "_min_words": BLIND_MIN_WORDS,
           "_note": "row number -> inventory id; committed separately from the "
                    ".txt views so a reviewer can be handed the .txt files alone"}
    for corpus in ("dialogue", "maps"):
        key[corpus] = write_blind(make_blind(rows, corpus), corpus, outdir)
    (outdir / "sample-key.json").write_text(
        json.dumps(key, indent=1, sort_keys=True, ensure_ascii=False) + "\n")

    # protected keeps
    keeps, unresolved = resolve_issue_keeps(rows)
    extra = json.loads((outdir / "protected-keeps-extra.json").read_text()) \
        if (outdir / "protected-keeps-extra.json").exists() else {}
    for k, v in extra.items():
        if k.startswith("_"):
            continue
        if k in keeps:
            # The issue's own entry stays authoritative; the lane's note is
            # ADDED, not dropped. A collision is a signal, not a conflict: the
            # lane independently reached a line the issue already protects.
            keeps[k]["also"] = v
        else:
            keeps[k] = v
    (outdir / "protected-keeps.json").write_text(json.dumps(
        {"_seed": SEED,
         "_note": "Peaks. Phase 2/3 must not flatten these. Seeded from the "
                  "issue's counterevidence list (resolved file:line -> id) plus "
                  "lane-added earned lines in protected-keeps-extra.json.",
         "_unresolved": unresolved,
         "keeps": keeps}, indent=1, sort_keys=True, ensure_ascii=False) + "\n")

    # holdout
    blind_ids = {i for c in ("dialogue", "maps") for i in key[c].values()}
    hold = make_holdout(rows, set(keeps), blind_ids)
    hold_set = set(hold)
    (outdir / "holdout.json").write_text(json.dumps(
        {"_seed": SEED + 1, "_fraction": HOLDOUT_FRACTION,
         "_note": "UNTOUCHABLE by Phase 2/3. Disjoint from protected-keeps.json "
                  "and from both blind samples, so Phase 5 can read revised "
                  "sample vs untouched holdout.",
         "_count": len(hold), "ids": hold}, indent=1, sort_keys=True,
        ensure_ascii=False) + "\n")

    # classification, per region
    overrides = load_overrides(outdir)
    cdir = outdir / "inventory-classified"
    cdir.mkdir(exist_ok=True)
    per_region = collections.defaultdict(list)
    counts = collections.defaultdict(collections.Counter)
    for r in rows:
        if r["corpus"] != "maps":
            continue
        reg, tag = classify_row(r, overrides)
        t = r["tells"]
        # THE PHASE 2 WORK QUEUE. `register` is the TARGET register. A
        # functional/scenic string carrying a button (closer smoke >=2) is a
        # string currently PERFORMING landmark register without earning it --
        # that mismatch, not the register itself, is what Phase 2 rewrites.
        demote = (reg in ("functional", "scenic") and t["closer_score"] >= 2
                  and r["id"] not in keeps and r["id"] not in hold_set)
        per_region[r["region"]].append({
            "id": r["id"], "file": r["file"], "field_path": r["field_path"],
            "field": r["field"], "register": reg, "tag": tag,
            "entity_id": (r["entity"] or {}).get("entity_id"),
            "display_name": (r["entity"] or {}).get("display_name"),
            "word_count": r["word_count"],
            "closer_score": t["closer_score"],
            "anon_agent": t["anon_agent"],
            "neg_correction": t["neg_correction"],
            "demotion_candidate": demote,
            "holdout": r["id"] in hold_set,
            "protected": r["id"] in keeps,
            "text": r["text"],
        })
        counts[r["region"]][reg] += 1
        if demote:
            counts[r["region"]]["_demotion_candidates"] += 1
    for region, items in sorted(per_region.items()):
        (cdir / f"{region}.json").write_text(json.dumps(
            {"_region": region, "_count": len(items),
             "_registers": {k: v for k, v in sorted(counts[region].items())
                            if not k.startswith("_")},
             "_demotion_candidates": counts[region]["_demotion_candidates"],
             "_note": "GH#397 Phase 2 work order. register/tag are a reproducible "
                      "heuristic proposal plus recorded hand-audit overrides "
                      "(classification-overrides.json). Region lanes may "
                      "re-judge any string, but must log the change.",
             "strings": items}, indent=1, sort_keys=True, ensure_ascii=False) + "\n")

    print(f"inventory: {len(rows)} strings -> {outdir/'inventory.jsonl'}")
    d = [r for r in rows if r["corpus"] == "dialogue"]
    m = [r for r in rows if r["corpus"] == "maps"]
    print(f"  dialogue {len(d):5} strings / {sum(r['word_count'] for r in d):6} words")
    print(f"  maps     {len(m):5} strings / {sum(r['word_count'] for r in m):6} words")
    print(f"blind: {len(key['dialogue'])} dialogue + {len(key['maps'])} maps rows")
    print(f"protected-keeps: {len(keeps)} (unresolved: {unresolved or 'none'})")
    print(f"holdout: {len(hold)} ids ({HOLDOUT_FRACTION:.0%})")
    print(f"classified: {sum(len(v) for v in per_region.values())} map strings "
          f"across {len(per_region)} regions")
    return 0


def cmd_heatmap(rows, out):
    """Per-dialogue-file closer density + shared-geometry indicators, ranked,
    so Phase 3 picks its top-N graphs by evidence instead of by vibe."""
    SHAPES = ("neg_correction", "which_from", "the_way_x", "noun_repeat_wit")
    per = collections.defaultdict(lambda: {
        "nodes": 0, "opts": 0, "flagged": 0, "words": 0,
        "shapes": collections.Counter(), "speakers": set(), "worst": []})
    for r in rows:
        if r["corpus"] != "dialogue":
            continue
        g = per[r["graph"]]
        t = r["tells"]
        if r["is_player_option"]:
            g["opts"] += 1
        else:
            g["nodes"] += 1
        g["words"] += r["word_count"]
        g["speakers"].add(r["speaker"])
        for s in SHAPES:
            g["shapes"][s] += t[s]
        if not r["is_player_option"] and t["closer_score"] >= 2:
            g["flagged"] += 1
            g["worst"].append((t["closer_score"], r["field_path"], r["text"]))
    # shared geometry: how many OTHER graphs use each shape this graph uses
    shape_graphs = {s: {g for g, v in per.items() if v["shapes"][s]} for s in SHAPES}
    # Volume-shrunk density. A 1-node graph with 1 flagged node has raw
    # density 100% and is not a graph worth a pass; SHRINK pulls small-n rows
    # toward 0 (Laplace-style, denominator + SHRINK_K) so the ranking surfaces
    # graphs with enough evidence to judge. Raw density stays in the table.
    SHRINK_K = 6
    ranked = []
    for g, v in per.items():
        dens = v["flagged"] / v["nodes"] if v["nodes"] else 0.0
        adj = v["flagged"] / (v["nodes"] + SHRINK_K)
        shared = sum(len(shape_graphs[s]) - 1 for s in SHAPES if v["shapes"][s])
        ranked.append({
            "graph": g, "nodes": v["nodes"], "opts": v["opts"], "words": v["words"],
            "flagged": v["flagged"], "density": dens, "adj_density": adj,
            "shapes": dict(v["shapes"]), "shared_geometry": shared,
            "speakers": sorted(x for x in v["speakers"] if x),
            "score": round(adj * 100 + shared * 0.5 + sum(v["shapes"].values()), 2),
            "worst": sorted(v["worst"], reverse=True)[:2],
        })
    ranked.sort(key=lambda x: (-x["score"], x["graph"]))
    L = []
    L.append("# Dialogue graph heatmap — GH#397 Phase 3 targeting\n")
    L.append("**Generated** by `qa/scripts/extract_prose.py heatmap` "
             f"(seed {SEED}, deterministic). Do not hand-edit.\n")
    L.append("Acceptance criterion 4: residual dialogue work is targeted by "
             "graph-level evidence, not a mandatory second rewrite of every "
             "file. This is that evidence.\n")
    L.append("**How to read it.** `closer density` = share of narrator/NPC "
             "`text` strings (player options excluded) whose final sentence "
             "trips the button smoke score (>=2 of 5; see review-rubric.md §4). "
             "`shared geom` = for every rhetorical shape this graph uses, how "
             "many OTHER graphs use the same shape — the issue's actual "
             "complaint is distributional, so a shape is only damning when "
             "it is common. `score` = density*100 + shared*0.5 + raw shape "
             "hits. **These are smoke detectors. A high row is a graph worth "
             "READING, never a graph proven bad**; a low row is not a "
             "clearance.\n")
    L.append(f"Corpus: {len(per)} graphs, "
             f"{sum(v['nodes'] for v in per.values())} narrator/NPC strings, "
             f"{sum(v['opts'] for v in per.values())} player options.\n")
    L.append("`density` is raw; `adj` is the volume-shrunk density the ranking "
             f"actually uses (flagged / (nodes + {SHRINK_K})), so a 1-node graph "
             "cannot top the list on a single hit.\n")
    L.append("| # | graph | nodes | flagged | density | adj | shared geom | shape hits | score |")
    L.append("|--:|---|--:|--:|--:|--:|--:|---|--:|")
    for i, x in enumerate(ranked, 1):
        sh = ", ".join(f"{k.replace('_',' ')} {v}" for k, v in sorted(x["shapes"].items()) if v) or "—"
        L.append(f"| {i} | `{x['graph']}` | {x['nodes']} | {x['flagged']} | "
                 f"{x['density']:.0%} | {x['adj_density']:.0%} | "
                 f"{x['shared_geometry']} | {sh} | {x['score']:.1f} |")
    L.append("\n## Top 10 by score — the Phase 3 shortlist\n")
    for i, x in enumerate(ranked[:10], 1):
        L.append(f"### {i}. `{x['graph']}` — density {x['density']:.0%} "
                 f"({x['flagged']}/{x['nodes']}), shared geom {x['shared_geometry']}, "
                 f"score {x['score']:.1f}")
        L.append(f"Speakers: {', '.join(x['speakers']) or 'narrator'}. "
                 f"{x['words']} words.\n")
        for sc, fp, t in x["worst"]:
            L.append(f"- smoke {sc}/5 · `{fp}`\n  > {' '.join(t.split())}")
        L.append("")
    Path(out).write_text("\n".join(L) + "\n")
    return ranked


# ---- self-test ---------------------------------------------------------------
def self_test():
    fails = []

    def check(name, ok, detail=""):
        print(f"  {'ok  ' if ok else 'FAIL'} {name}{'  ' + detail if detail else ''}")
        if not ok:
            fails.append(name)

    # 1. the two map walkers must never overlap
    overlap = []
    for f in sorted(MAPS.glob("**/*.json")):
        d = json.loads(f.read_text())
        a = {p for p, _ in GATE.walk_map_texts(d)}
        b = {p for p, _, _, _ in walk_map_prose(d)}
        if a & b:
            overlap.append((f.name, sorted(a & b)[:3]))
    check("map walkers disjoint (GH#388 talk vs GH#397 prose)", not overlap,
          str(overlap[:2]))

    # 2. ballpark reconciliation with the issue's audit
    rows = build_inventory()
    d = [r for r in rows if r["corpus"] == "dialogue"]
    m = [r for r in rows if r["corpus"] == "maps"]
    dw, mw = sum(r["word_count"] for r in d), sum(r["word_count"] for r in m)
    check("dialogue strings within 5% of issue's 1482",
          abs(len(d) - 1482) / 1482 < 0.05, f"{len(d)}")
    check("dialogue words within 5% of issue's 24.5k",
          abs(dw - 24500) / 24500 < 0.05, f"{dw}")
    check("map strings within 5% of issue's 825",
          abs(len(m) - 825) / 825 < 0.05, f"{len(m)}")
    check("map words within 8% of issue's 18.5k",
          abs(mw - 18500) / 18500 < 0.08, f"{mw}")

    # 3. round-trip: every inventory text is findable verbatim in its file
    #    (as the JSON-escaped form -- \" and \n live escaped on disk)
    #    Either escaping form counts: most files carry literal em-dashes, but
    #    rags_meeting.json writes its own as —.
    src, bad = {}, []
    for r in rows:
        t = src.setdefault(r["file"], (REPO / r["file"]).read_text())
        if (json.dumps(r["text"], ensure_ascii=False)[1:-1] not in t
                and json.dumps(r["text"])[1:-1] not in t):
            bad.append(r["id"])
    check("every string round-trips into its source file", not bad, str(bad[:3]))

    # 3b. CENSUS CROSS-CHECK: the walker must find every prose-keyed string the
    #     independent key census counts. This is the leg that caught the 7
    #     sleep_toast conditional-variant strings; keep it.
    #     Independent PATH-BASED rule (no owner-threading, so it cannot share
    #     the walker's bugs): a string is prose iff some key on its path is a
    #     prose key, no key on its path is author-private ("_") or a GH#388
    #     talk subtree, and its own immediate key is not known structure.
    def census(o, keys=(), path="$"):
        if isinstance(o, dict):
            for k, v in o.items():
                yield from census(v, keys + (k,), f"{path}.{k}")
        elif isinstance(o, list):
            for i, v in enumerate(o):
                yield from census(v, keys, f"{path}[{i}]")
        elif isinstance(o, str) and keys:
            if any(k.startswith("_") or k in SKIP_SUBTREES for k in keys):
                return
            if any(is_prose_key(k) for k in keys) and keys[-1] not in KNOWN_NON_PROSE:
                yield path

    missed, extra = [], []
    for f in sorted(MAPS.glob("**/*.json")):
        d = json.loads(f.read_text())
        cpaths = set(census(d))
        wpaths = {p for p, _, _, _ in walk_map_prose(d)}
        missed += [f"{f.name}{p}" for p in sorted(cpaths - wpaths)]
        extra += [f"{f.name}{p}" for p in sorted(wpaths - cpaths)]
    check("walker finds every census-identified prose string", not missed, str(missed[:3]))
    check("walker claims nothing the census rejects", not extra, str(extra[:3]))

    # 4. ids unique
    ids = [r["id"] for r in rows]
    check("inventory ids unique", len(ids) == len(set(ids)),
          f"{len(ids)-len(set(ids))} dupes")

    # 5. determinism: two builds identical
    check("build_inventory deterministic",
          json.dumps(rows, sort_keys=True) ==
          json.dumps(build_inventory(), sort_keys=True))

    # 6. blind sampling deterministic + disjoint from holdout
    b1 = [r["id"] for r in make_blind(rows, "maps")]
    b2 = [r["id"] for r in make_blind(rows, "maps")]
    check("blind sample deterministic under fixed seed", b1 == b2)
    keeps, unres = resolve_issue_keeps(rows)
    check("all 5 issue counterevidence keeps resolve to ids", not unres, str(unres))
    blind_ids = set(b1) | {r["id"] for r in make_blind(rows, "dialogue")}
    hold = set(make_holdout(rows, set(keeps), blind_ids))
    check("holdout disjoint from blind sets", not (hold & blind_ids))
    check("holdout disjoint from protected keeps", not (hold & set(keeps)))
    check("holdout is ~10%", abs(len(hold) / len(rows) - 0.10) < 0.01,
          f"{len(hold)}/{len(rows)}")

    # 7. tell heuristics fire on the issue's own named examples
    check("neg_correction fires on 'Not a prisoner. An ANCHOR'",
          tells("Not a prisoner. An ANCHOR — a twin to the stone.")["neg_correction"] > 0)
    check("closer flags 'In Pallass, that is a document nobody filed.'",
          closer_score("Eleven names carried. One of them has been carried for two "
                       "years and has no repayment column at all. In Pallass, that "
                       "is a document nobody filed.") >= 2)
    check("closer does NOT flag a plain functional line",
          closer_score("A rack of bundled stems, dried long past any use.") < 2)
    check("anon_agent fires on 'Someone carved joy here'",
          tells("Someone carved joy here, and meant it to last.")["anon_agent"] > 0)

    # 8. every classified register is one of the four
    ov = load_overrides(REPO / "docs" / "prose-naturalization")
    regs = {classify_row(r, ov)[0] for r in rows if r["corpus"] == "maps"}
    check("registers are exactly the four named",
          regs <= {"functional", "scenic", "character-bearing", "landmark"}, str(regs))

    # 8b. every hand-audit override must BIND to a real inventory id. Without
    #     this leg a mistyped id is a silent no-op (it was, once).
    allids = {r["id"] for r in rows}
    stale = sorted(set(ov) - allids)
    check("every classification override binds to an inventory id", not stale, str(stale))
    check("every override names a register and a why",
          all(o.get("register") and o.get("why") for o in ov.values()))

    # 8c. same guard for lane-added protected keeps
    xp = REPO / "docs" / "prose-naturalization" / "protected-keeps-extra.json"
    if xp.exists():
        extra = {k: v for k, v in json.loads(xp.read_text()).items()
                 if not k.startswith("_")}
        bad_x = sorted(set(extra) - allids)
        check("every lane-added protected keep binds to an inventory id",
              not bad_x, str(bad_x))
        check("every lane-added keep names a kind and a reason",
              all(o.get("kind") and o.get("reason") for o in extra.values()))

    print("self-test:", "PASS" if not fails else f"{len(fails)} FAILURES: {fails}")
    return 1 if fails else 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("self-test")
    sub.add_parser("field-census")
    p = sub.add_parser("inventory"); p.add_argument("--out", required=True)
    p = sub.add_parser("blind"); p.add_argument("--inventory", required=True); p.add_argument("--outdir", required=True)
    p = sub.add_parser("holdout"); p.add_argument("--inventory", required=True); p.add_argument("--outdir", required=True)
    p = sub.add_parser("classify"); p.add_argument("--inventory", required=True); p.add_argument("--outdir", required=True)
    p = sub.add_parser("heatmap"); p.add_argument("--inventory"); p.add_argument("--out", required=True)
    p = sub.add_parser("all"); p.add_argument("--outdir", required=True)
    a = ap.parse_args()

    if a.cmd == "self-test":
        return self_test()
    if a.cmd == "field-census":
        return cmd_field_census()
    if a.cmd == "inventory":
        rows = build_inventory(); write_inventory(rows, a.out)
        print(f"inventory: {len(rows)} strings -> {a.out}"); return 0
    if a.cmd == "heatmap":
        rows = load_inventory(a.inventory) if a.inventory else build_inventory()
        r = cmd_heatmap(rows, a.out)
        print(f"heatmap: {len(r)} graphs -> {a.out}")
        for x in r[:10]:
            print(f"  {x['score']:6.1f}  {x['graph']:34} density={x['density']:.0%} "
                  f"flagged={x['flagged']}/{x['nodes']} shared={x['shared_geometry']}")
        return 0
    if a.cmd == "all":
        return cmd_all(a.outdir)
    # blind / holdout / classify are folded into `all` (they share derived state);
    # run `all` and take the artifact you need.
    print(f"'{a.cmd}' is produced by `all` (shared derived state); run: "
          f"extract_prose.py all --outdir docs/prose-naturalization", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
