# Prose inventory + register classification — GH#397 Phase 0/2 prep

**GENERATED** by `qa/scripts/extract_prose.py all --outdir docs/prose-naturalization` — seed 397, python 3.12.3, deterministic (a re-run on the same tree is byte-identical). Do not hand-edit.

**Acceptance criterion 3**, first half: *all player-facing map prose is inventoried and classified*. The rewrites themselves are Phase 2's.

> Hand-written analysis is NOT in this file's generated sections. It is appended verbatim at the end from `inventory-commentary.md` and is frozen commentary with its own source SHA.

---

## 1. Corpus size

| corpus | strings | words | issue's blind audit |
|---|--:|--:|---|
| dialogue (`data/dialogue/*.json`) | 1,445 | 24,753 | 1,482 / ~24.5k |
| map prose (`data/maps/**/*.json`) | 847 | 19,041 | 825 / ~18.5k |
| **total** | **2,292** | **43,794** | — |

String counts differ from the issue's by boundary convention: `@ref` strings are structure and are skipped, and this inventory ADDS the 7 `options[].effects[].toast` strings the Phase 0 pass missed (rendered at `wi_game.gd:1408-1412`). `self-test` gates both corpora against the issue's ballparks and runs a key census on BOTH sides, so a wrong field list fails loudly.

### Dialogue field census

| field | strings |
|---|--:|
| `effects[].toast` | 7 |
| `text` | 1416 |
| `text_bank` | 22 |
| **total** | **1445** |

Unknown dialogue string keys: **0** (none). Excluded as structure: `goto`×534, `speaker`×392, `accomplishment`×280, `_author-private`×132, `item`×77, `start`×71, `text (@ref = structure)`×66, `remove_item`×30.

## 2. Register distribution (map prose)

**`register` is the TARGET register** — what the string's job in the game says it should sound like, not a description of how it currently reads. The gap between the two is the work.

| region | strings | functional | scenic | character-bearing | landmark | queue |
|---|--:|--:|--:|--:|--:|--:|
| pallass | 149 | 51 | 82 | 16 | 0 | **15** |
| riverfarm | 134 | 43 | 82 | 9 | 0 | **7** |
| invrisil | 125 | 29 | 52 | 42 | 2 | **9** |
| liscor | 97 | 27 | 32 | 37 | 1 | **4** |
| floodplains | 89 | 33 | 50 | 5 | 1 | **9** |
| inn | 89 | 40 | 16 | 33 | 0 | **1** |
| dungeon | 61 | 24 | 27 | 8 | 2 | **9** |
| sewers | 48 | 19 | 26 | 2 | 1 | **2** |
| ruin | 43 | 5 | 28 | 8 | 2 | **6** |
| garden | 12 | 1 | 11 | 0 | 0 | **2** |
| **total** | **847** | **272** (32%) | **406** (48%) | **160** (19%) | **9** (1%) | **64** |

### Field → register

| field | n | registers |
|---|--:|---|
| `observe` | 340 | character-bearing 64 · functional 14 · scenic 262 |
| `toast` | 203 | character-bearing 13 · functional 48 · scenic 142 |
| `text` | 65 | character-bearing 63 · scenic 2 |
| `locked_toast` | 61 | functional 61 |
| `skill_hint_toast` | 48 | functional 48 |
| `once_per_waking_toast` | 20 | functional 20 |
| `friendly_line` | 19 | character-bearing 19 |
| `interior_flavor` | 18 | functional 18 |
| `open_toast` | 14 | functional 7 · landmark 7 |
| `gate_closed_toast` | 14 | functional 14 |
| `sleep_toast` | 10 | functional 10 |
| `taken_toast` | 8 | functional 8 |
| `item_hint_toast` | 7 | functional 7 |
| `copy` | 5 | functional 5 |
| `victory_toast` | 3 | character-bearing 1 · landmark 2 |
| `unsteady_toast` | 2 | functional 2 |
| `second_visit_toast` | 2 | functional 2 |
| `kindle_toast` | 2 | functional 2 |
| `anchor_toast` | 1 | functional 1 |
| `tame_refusal_toast` | 1 | functional 1 |
| `light_toast` | 1 | functional 1 |
| `clean_toast` | 1 | functional 1 |
| `repair_toast` | 1 | functional 1 |
| `burn_toast` | 1 | functional 1 |

`toast` splits by PATH, not by key name: 48 of them sit under `on_skill_use` and are functional/skill-outcome — the receipt for a Skill the player spent. Only 0 of those carry a non-functional override.

## 3. Tell-family counts

| tell | map prose (n=847) | dialogue (n=1445) |
|---|--:|--:|
| anonymous-agent inference (`someone`/`somebody`/`whoever`/…) | 267 | 184 |
| ≥2 anonymous agents in one string | 22 | 29 |
| button smoke ≥2/5 | 68 | 35 |
| negation/correction (any) | 29 | 11 |
| ≥2 negation shapes in one string | 7 | 0 |
| `which from X is Y` / `the way X does` / `the X is the X` | 12 | 1 |
| CAPS (all) | 23 | 0 |
| CAPS in lettering context (§8 PERMITTED) | 14 | 0 |
| CAPS bare — the §8 work queue | 9 | 0 |
| mid-line ellipsis | 6 | 0 |
| "the whole of / the entire" | 2 | 0 |

The last five rows are the headline: CAPS, ellipsis and "the whole of" are hard-banned at zero in dialogue and enforced by `dialogue_voice_gate.py`, which **does not walk map prose at all**. The CAPS split uses the controller's §8 mechanical proxy (capitals attributed to a named written surface are lettering; the rest are emphasis) and is ADVISORY — the bare list is the work queue, judgement is the arbiter.

### Anonymous-agent inference by region

| region | strings with an anonymous agent |
|---|--:|
| garden | 7/12 (58%) |
| dungeon | 30/61 (49%) |
| ruin | 20/43 (47%) |
| sewers | 21/48 (44%) |
| floodplains | 29/89 (33%) |
| invrisil | 38/125 (30%) |
| pallass | 39/149 (26%) |
| riverfarm | 35/134 (26%) |
| inn | 23/89 (26%) |
| liscor | 25/97 (26%) |

## 4. The Phase 2 work queue

A functional or scenic string is a **demotion candidate** when ANY of: `closer_score ≥ 2`, `neg_correction ≥ 2`, `anon_agent ≥ 2` — excluding protected keeps and holdout, which are untouchable. One trigger was not enough: the garden's "Someone carved joy here" scores closer 1, and `liscor/street.json`'s grate `observe` stacks four negation shapes at closer 1. Both are named in the issue.

| trigger | candidates |
|---|--:|
| `closer_score` | 47 |
| `neg_correction` | 4 |
| `anon_agent` | 17 |
| **queue total** (a string may trip more than one) | **64** |
| — of those, scenic | 50 |
| — of those, functional | 14 |

**5 strings are named by hand** — by the issue, or by the controller's fix ruling — and are RESERVED out of the holdout so a random draw can never make named work untouchable. They are flagged `issue_named_work` in the region files:

- `map:dungeon/trapped_halls.json:$.entities[8].skill_uses.observe.variants[0].toast` — issue-named: the `which from X is Y` shape plus the narrator supplying the interpretation the player should have made
- `map:dungeon/trapped_halls.json:$.entities[9].observe` — issue-named: partial keep — the threat warning stays, the reframe-for-effect second sentence is the work (bible §7)
- `map:garden/garden_sanctuary.json:$.entities[0].observe` — issue-named: forbidden inference — neither the joy nor the intent is visible, only a dancer's pose (bible §6 rule 1)
- `map:liscor/street.json:$.entities[12].observe` — controller-named: four negation-correction shapes stacked in one scenic string at closer 1 — the shape the counter-only queue could not see
- `map:pallass/pallass_den_shop.json:$.entities[6].toast` — issue-named button: two excellent specific sentences, then a third that tells the reader what to think about them

**UNRULED SIBLING, flagged for the controller:** 9 map strings sit under `skill_uses`, which `field_skills.gd:138` documents as *"a per-skill map of `on_skill_use` arms"* — the multi-Skill spelling of the same block. The fix ruling scoped skill-outcome to `on_skill_use` (48 strings) and this pass implements exactly that scope, so these are still classified by entity/field like any other prose (character-bearing 3, scenic 6). If the register is meant to follow the engine's semantics rather than the block's name, this is the follow-up.

## 5. Landmark scarcity, measured

**9 landmark strings across 847 (1%), in 7 of 30 map files.**

| file | landmark strings | dispositions |
|---|--:|---|
| `dungeon/seal_vault.json` | 1 | RESTAGE 1 |
| `dungeon/trapped_halls.json` | 1 | KEEP-AS-IS 1 |
| `floodplains/floodplains.json` | 1 | KEEP-AS-IS 1 |
| `invrisil/mercantile_alleys.json` | 2 | KEEP-AS-IS 2 |
| `liscor/street.json` | 1 | KEEP-AS-IS 1 |
| `ruin/ruin_surface.json` | 2 | KEEP-AS-IS 1 · RESTAGE 1 |
| `sewers/sewers.json` | 1 | KEEP-AS-IS 1 |

Per-string rulings: `landmark-registry.json`. Lanes get zero discretion beyond the disposition recorded there.

## 6. Dialogue residual work (Phase 3 targeting)

72 graphs ranked in `dialogue-graph-heatmap.md`. Shortlist (riverfarm_* excluded from this pass by controller ruling): `krshia_crate`, `pisces_seal`, `forge_temper_golem`, `rags_inn`, `ceria_dig_camp`, `ksmvr_plates`, `krshia_inn`, `zevara_intro`, `pisces_magic`, `invrisil_stationer_client`.

## 7. Artifacts

| file | what it is |
|---|---|
| `inventory.jsonl` | 2,292 rows, one per string: id, file, field_path, speaker/entity, text, word_count, advisory tell flags. Sorted by id. THE BASELINE `verify-untouched` diffs against. |
| `inventory-classified/<region>.json` | Phase 2 work order: every map string with register, rationale tag, demotion triggers, holdout/protected flags, and its text. |
| `classification-overrides.json` | hand-audit corrections as data, each with a `why`. HAND-AUTHORED INPUT. |
| `protected-keeps-extra.json` | lane-added peaks/models. HAND-AUTHORED INPUT. |
| `protected-keeps.json` | 12 peaks/models, each pinned to {file, field_path, exact_text}. UNTOUCHABLE. |
| `holdout.json` | 229 ids (10%), drawn from the same ≥6-word pool as the blind sets, disjoint from both and from the keeps. UNTOUCHABLE. |
| `sample-dialogue-blind.txt · sample-maps-blind.txt` | 120 metadata-stripped rows each, seed 397. |
| `sample-holdout-blind.txt` | the Phase 5 instrument: the holdout in the same blind format, so the exit read is one procedure over two views. |
| `sample-key.json` | row → inventory id. Committed separately so a reviewer can be handed only the `.txt` files. |
| `landmark-registry.json` | all 9 landmark strings with a per-string disposition (KEEP-AS-IS / RESTAGE). |
| `review-rubric.md` | the 0–100 blind-read instrument. |
| `dialogue-graph-heatmap.md` | Phase 3 targeting by graph-level evidence. |
| `narrator-bible.md` | Phase 1, RULED. |
| `bible-adjudication.md` | the controller's rulings on the draft's 13 [ADJUDICATE] items. The ruling record. |
| `inventory-commentary.md` | hand-written frozen commentary, appended below. |

---

<!-- appended verbatim from inventory-commentary.md by extract_prose.py; not generated -->

# Frozen commentary — method, judgement, and how far to trust the numbers

**Status: HAND-WRITTEN, FROZEN.** Not generated. `extract_prose.py all` appends
this file verbatim to the end of `inventory-summary.md`; everything above the
separator there is generated and authoritative for counts.

**Source SHA:** written against the inventory at `df9c7ae0` (GH#397 Phase 0/1),
revised once in the fix wave that added the dialogue effect-toasts, re-scoped
skill-outcome by path, and widened the work-queue trigger.

**This file deliberately restates no counts.** That is the whole lesson of the
fix wave's I5 finding: the first version of `inventory-summary.md` hand-typed
its tables, so every regeneration silently invalidated the prose around them.
Numbers live in the generated sections. Judgement lives here.

---

## 1. What is mechanical and reproducible

Register is assigned by a documented heuristic in `extract_prose.py:classify_row`:

1. recorded hand-audit override (`classification-overrides.json`), then
2. **path** — anything inside an `on_skill_use` block is the receipt for a
   Skill the player spent, and is functional/skill-outcome whatever its key is
   called, then
3. **field type** — a `skill_hint_toast` is functional because its job is to
   inform, then
4. **entity kind** — an `npc`'s `observe` is character-bearing, a `door`'s is
   wayfinding, then
5. **evidence** — a resolution field that *banks quest progress* is landmark;
   one that does not is traversal.

Every string carries a one-word rationale tag naming which rule fired, so a
lane can audit the proposal instead of trusting it.

## 2. What is hand-audited

- **The landmark tier in full, every row**, because it sets the scarcity
  budget. That audit changed the rule: the first version keyed landmark on
  field alone and swept in lift rides, guest cots and `"Your own bed."` —
  traversal and rest resolutions that are plainly functional. Landmark now
  requires a banked accomplishment, and the remaining corrections are recorded
  in `classification-overrides.json` with reasons. Every landmark string now
  also carries a ruled **disposition** in `landmark-registry.json`; lanes get
  no discretion beyond it.
- **Functional / scenic / character-bearing by tag group, not row by row.** A
  sample of each tag was read and the rule corrected where the sample was
  wrong. The largest such correction moved "banks an accomplishment" props out
  of character-bearing and into scenic: banking makes a prop
  *quest-load-bearing*, not *character-revealing*. Those rows keep the
  `quest-prop` tag, because their **fact payload** is what quest gating reads
  and Phase 2 may restyle it but may not disturb it.
- **A stratified re-probe after the fix wave.** 20 rows, 5 per register, seed
  documented in `extract_prose.py:PROBE_SEED`, reproducible with
  `extract_prose.py classify-probe`. Result is recorded in §4 below.

## 3. What is not settled

Individual scenic-vs-character-bearing calls on `observe`/`toast` are the
softest edge, and the corpus has not been adjudicated row by row. Phase 2
region lanes are expected to re-judge and **must record the change in
`classification-overrides.json`** rather than edit silently — `self-test` fails
on an override whose id does not bind, so a stale correction cannot become a
quiet no-op.

Two known soft spots, named so nobody rediscovers them as bugs:

- **`skill_uses`.** `field_skills.gd` documents it as "a per-skill map of
  `on_skill_use` arms" — the same register under a different block name. The
  fix ruling scoped skill-outcome to `on_skill_use`, so these rows are still
  classified by entity/field. Flagged in the generated §4 as the follow-up.
- **`names_cast` promotion.** Prose that names a cast member is promoted to
  character-bearing even on a prop, because that is where motif saturation
  hides. It is the right default and it will occasionally promote a string
  that is really scenery with a name in it.

## 4. The stratified classification re-probe (fix-wave, post-change)

Command, reproducible:

```
python3 qa/scripts/extract_prose.py classify-probe          # seed 3971, 20 rows
```

Read cold against the four register definitions in `narrator-bible.md` §§1–4.
A **disagreement** means: I would have filed this row in a different register,
not merely that I would have written the line differently.

**Result: 1 disagreement in 20.**

- The disagreement is `map:floodplains/rags_camp.json:$.entities[2].toast` —
  "Every hide is stretched to the same tension. Whoever runs this rack does not
  let anyone else near it." Filed `scenic / quest-prop`; I would file it
  **character-bearing**. The first sentence is scenery, but the second is a
  character claim about a person, and the only reason the heuristic does not
  see it is that the person is anonymous (`names_cast` finds nobody). This is
  the softest edge §3 names, and it is a *file it differently* disagreement
  rather than a *the rule is wrong* one — but it is worth knowing that
  anonymous-agent characterisation is the exact seam where scenic and
  character-bearing blur, since that is also the tell family the pass is
  reducing.
- The 5 functional rows and the 5 landmark rows agreed unanimously, which is
  the important half: those two registers carry the pass's hard rules (no
  closers at all in one, the scarcity budget in the other), so a heuristic that
  misfiled them would poison the work order. The five landmark rows drawn were
  all four ruled beats plus the ruin variant, and every one matched its
  disposition in `landmark-registry.json`.
- One row is worth flagging as *right register, still work*:
  `dungeon/trapped_halls.json:$.entities[8].variants[2].toast` is correctly
  character-bearing (Pisces' voice is the content), and it also carries an "It
  is not a lock" correction. Correct register is not a clearance.
- `on_skill_use` rows now read as unambiguously functional, which the pre-fix
  classification got wrong 48 times over by keying on the key name.

## 5. What the numbers say about the problem (judgement, not counts)

Three findings from the generated tables are worth stating in words, because
they are what the pass is actually for:

**Anonymous-agent inference inverts with population.** The regions with nobody
in them — garden, dungeon, ruin, sewers — infer the most invisible people, at
roughly twice the rate of the populated ones. Where there is no one to observe,
the narrator supplies someone. That is tell family 3 at its clearest and it is
a measurable, region-targeted finding rather than a taste claim. The bible's
per-region targets (§6.4) are built on it, and the populated-region cap names
floodplains explicitly because floodplains is the populated region that
behaves like an empty one.

**The corpus is gated in one register and unguarded in the other.** CAPS,
mid-line ellipsis and "the whole of / the entire" are hard-banned at zero in
dialogue and enforced by `dialogue_voice_gate.py` — which does not walk map
prose at all. Every one of those banned shapes is still alive in map fields.
These are the cheapest wins in the pass and they are cheap precisely because
nobody chose them; they are an enforcement gap, not a style.

**Pallass is over-authored relative to its payoffs.** It carries the largest
share of the work queue on zero landmark strings — the most buttons per beat of
any region, matching the issue's "standards, forms, measurements, queues"
motif note. `inn`, `liscor`, `sewers` and `garden` are close to clean, and the
default action on a clean region is to leave it alone.

**The 9 landmark strings are not the problem.** The corpus already spends
landmark register about once per payoff site. The problem is the queue spending
it a second time where nothing was earned — and, per the fix wave, the several
earned peaks that no counter can see at all (`landmark-registry.json` and the
`PEAK` entries in `protected-keeps.json` are the ledger of both).

## 6. The failure mode this whole apparatus exists to prevent

Uniform plainness. Every rule in the bible pushes one direction — less
inference, no closers, concrete detail — and ten region lanes applying them
mechanically produce a new monoculture that passes every metric here while
failing the only test that matters. `narrator-bible.md` §10 is the guard; the
rubric's §1 "not a plainness reward" is the instrument; this file's job is to
say plainly that **a lane which rewrote most of its region has misread the
assignment.**
