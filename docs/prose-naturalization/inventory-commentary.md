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
