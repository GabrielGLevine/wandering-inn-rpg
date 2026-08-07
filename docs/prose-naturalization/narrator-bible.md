# Narrator / object-prose bible — GH#397 Phase 1 · **RULED**

**Status: RULED.** Every rule the draft marked `[ADJUDICATE]` has been decided
by the controller and is marked **RULED** here with its ruling. The ruling
record is `bible-adjudication.md`, kept beside this file; §11 is the index. No
rule in this document is a new hard gate — the inherited bans ship **advisory**
in maps mode this pass and are promoted at issue close only if the pass ends
with zero legitimate exceptions, which is the same manual-first rollout the
dialogue gate had.

**Scope:** the player-facing prose of `data/maps/**/*.json` — **847 strings,
19,041 words**: `observe`, the toast family (including the 48 `on_skill_use.toast`
strings), embedded `text` (arrival + ambient), `friendly_line`,
`interior_flavor`, `copy`. Exact field list and every exclusion: the
`qa/scripts/extract_prose.py` header. All counts in this document are generated
into `inventory-summary.md`; if a number here and a number there disagree, the
generated one is right and this file needs an edit.

**Out of scope this pass:** `riverfarm/*` (controller ruling — the region is
excluded, and `riverfarm_*` dialogue graphs are dropped from the Phase 3
shortlist for the same reason). It is still measured, and its `witch_hut`
saturation case is still the worked teaching example in §2, because the lesson
generalises even where the file does not get touched.

**Canon guard** (inherited, non-negotiable): Book 17 spoiler bar, the game
advertises Vol 7. Write **"Magical Door"**, never the Vol-9 name. Never change
facts, names, numbers, directions, prices, item names, skill names or quest
instructions — reword them, keep them findable in the same field.

**The two lists that outrank everything below.** `protected-keeps.json` (12
peaks and models) and `holdout.json` (229 strings) are **untouchable**. A
protected keep is never rewritten *even where it trips a rule in this document*
— see §10 guard 2, which is a ruling, not a courtesy. Run
`extract_prose.py verify-untouched` before and after any lane's work; it exits
1 if a byte moved.

---

## Round 2 amendments — 2026-08-07, **RULED** (user accepted controller rec; CHOICE-LOG 2026-08-07)

The Phase-5 blind read (`phase5/phase5-reconciliation.md`) found the
mechanical tells dead but ONE rhetorical engine alive. These amendments
govern the round-2 re-authorship of `round2-worklist.jsonl` (188 rows,
mechanically frozen) and OVERRIDE the sections they name. Everything
else in this bible stands.

1. **Riverfarm is IN scope.** Its round-1 exclusion reason (the pending
   #396 redesign) shipped 2026-08-06. The witch_hut saturation lesson
   in §2 now applies to its own file.
2. **§2 rule 1 override — ZERO inference by default.** A scenic or
   functional string states what is physically there. Every inference
   (what happened here, what someone meant, what a thing is for, what
   it "wants") now requires either a landmark-registry entry or the
   file's ONE pre-declared inference allowance — declared in the lane's
   row plan BEFORE writing, never discovered in the draft. Rule 5's
   soft target is superseded: zero-inference is no longer a floor
   fraction, it is the default state.
   **Skill-receipt carve-out (RULED at l3 review, 2026-08-07,
   mirroring amendment 4's):** `on_skill_use`/`skill_uses` toast
   fields report what the Skill READS — including the non-visible
   (history, keying, containment, species) — bounded by the canon
   guard; they spend no allowance. The Skill perceiving the
   imperceptible is the field's job, not narrator overreach. This
   retroactively covers the allowances l5/l6 declared on
   detect-magic-class receipts (harmless over-declarations).
3. **Named ban — the descriptor triad.** Two concrete details + one
   interpretive clause. The SHAPE is banned in scenic and functional
   regardless of content quality; a third concrete detail is fine, an
   interpretive turn is not (see 2).
4. **Named ban — the affordance formula.** "Good for X", "built to X",
   "waiting to X", "enough to X", "what it wants is X" and kin. State
   the object; the player infers the use. (Skill-outcome toasts state
   the RESULT of the use — they are not affordance prose and are
   unaffected.)
5. **Per-file button ceiling: ONE.** At most one button-family closer
   per map file — short deflation coda, relative-clause commentary
   (", which..."), triple cadence, gnomic epigram, persistence coda
   ("...and it will hold tomorrow"), personified verdict. The ceiling
   forces ending-shape diversity; "fact-stop" endings (the sentence
   just ends when the information does) are the unlimited default.
6. **The round-1 repair templates are ALSO banned.** One-word deflation
   codas ("Probably.", "For now."), inserted self-corrections, and
   stripped-twin deletion scars read as an editing signature. Round 2
   is FRESH AUTHORSHIP: re-write from the field's job; after the first
   read, the old sentence may not be consulted. A lane caught trimming
   instead of re-authoring is a fix-wave finding.
7. **Enforcement is advisory-first** (same rollout as every prose
   gate): bans 3–5 ship as `data_lint --advisories` arms in the Task-1
   commit; promotion to hard arms happens at issue close only if the
   pass ends with zero legitimate exceptions.

## 0. Why this is a separate document from the dialogue bible

`docs/dialogue-voice-bible.md` governs **spoken** prose and is authoritative
there. It cannot simply be applied to map fields, and the reason is
structural rather than stylistic:

| | dialogue bible | this bible |
|---|---|---|
| what a rule is scoped to | a **speaker** (tier T0–T4) | a **register** (what the string's job is) |
| how scarcity is allocated | **per NPC lifetime** — "≤1 antithesis per NPC, corpus ≤30" | **per site** — per map file, per quest chain |
| how many voices exist | 56 distinct speakers | **one narrator** |

That last row is the whole problem. The dialogue bible's central mechanism —
budget a scarce move per speaker, so no two characters share it — **has no
analogue here.** Map prose has one voice, so a per-speaker allowance would be
one corpus-wide allowance, and a single narrator who is permitted one epigram
per *speaker* is permitted an epigram everywhere.

So the scarcity in this document is **spatial**: budgeted per map file and per
quest chain (§5). Where this bible and the dialogue bible conflict *inside a
map field*, this one wins; the dialogue bible still governs `talk_pool` and
`talk_pool_stages`, which GH#388 closed and which this pass does not touch.

**RULED — registers replace tiers for map prose.** The dialogue tier system
does not extend here; the argument above is ratified. Nothing in a Phase 2
brief should assign a map string a tier.

**One inherited finding you must know.** CAPS emphasis, mid-line ellipsis and
"the whole of / the entire" are hard-banned at **zero** in dialogue and
enforced by `dialogue_voice_gate.py`. That gate does not walk these fields at
all, and all three shapes are still alive here: **23 CAPS (9 of them bare
emphasis), 6 ellipses, 2 "the whole of"** — including the exact construction
the issue quotes from `riverfarm_village.json` ("That is the whole of
Riverfarm's vocabulary for gratitude"). The corpus is gated in one register and
unguarded in the other. Rules in §8.

---

## 1. FUNCTIONAL — 272 strings (32%)

**Definition.** Prose whose job is to inform: an interaction result, a hint, a
gate refusal, a skill outcome, an already-done no-op, a wayfinding note, a
readable document. The player may be relying on it to know what to do next.

**Fields that are always functional:** `skill_hint_toast`, `item_hint_toast`,
`locked_toast`, `gate_closed_toast`, `once_per_waking_toast`, `taken_toast`,
`interior_flavor`, `unsteady_toast`, `tame_refusal_toast`, `copy`, the six
skill-verb outcome toasts (7 strings), **everything under `on_skill_use`
(48 strings, all spelled `toast`)**, and any resolution toast that does not
bank progress (a lift ride, a guest cot, `"Your own bed."`).

> **`on_skill_use.toast` is functional by PATH, not by key name.** It is the
> receipt for a Skill the player chose to spend, which is the same job the
> `kindle_toast` / `light_toast` / `repair_toast` family does under a nicer
> key. Keying the register on the key name undercounted skill-outcome prose by
> 48 of 55 strings — the single largest classification error the review found.
> The sibling block `skill_uses` ("a per-skill map of `on_skill_use` arms",
> `field_skills.gd:138`) was **not** in the ruling's scope and is still
> classified by entity/field; it is flagged in `inventory-summary.md` §4 as a
> follow-up, not silently folded in.

### Rules

1. **Plain, fast, and finished when the information is delivered.** No
   thematic closer, ever. This register has no landmark allowance and cannot
   petition for one.
   - **§1.1 does not bind an in-world document's own voice** (RULED, liscor
     petition 3; recorded here at #397 integration, 2026-08-06). A `copy`
     string is not authorial narration — it is a physical document the player is
     **reading, quoted**. The closer ban exists to stop the NARRATOR telling the
     reader what to think; a letter's own sign-off, or an in-world speaker's
     aside quoted inside it, is that document's voice and is the content.
     §1.4 already excepts `copy` from the sentence ceiling and §8 already
     permits its heading capitals ("whose capitals are the document by
     definition") — this is the same carve-out finished, on the same grounds.
   - Exemplar: `liscor/guild.json · board_rumors[1].copy` (protected keep) —
     the hat-letter, whose closing remark is attributed to the Guildmistress's
     clerk, not to the narrator. Its wax, its handwriting and its drawing of a
     hat are the Invrisil chain's only in-world hook.
   - The carve-out is **`copy` only**, and only for the document's own voice.
     Narration *around* a document (the `observe` that describes the board it
     is pinned to) is ordinary functional/scenic prose and rule 1 binds it.
2. **The instruction is the payload.** If a player needs the string to act,
   ornament competes with it. A hint may be atmospheric in its *first* clause
   and must be unambiguous in its last.
3. **No inferred history.** Nothing here discloses a microhistory. See §6.
4. **Length ceiling: 2 sentences. RULED — adopted, `copy` excepted (3–5).**
   The ceiling counts **sentences, not clauses**: a one-sentence hint whose
   first clause is atmospheric already satisfies rule 2 and is not a violation.
   Loosen only by petition **with the string in hand** — no blanket
   relaxations.

### Corpus examples — this is the sound

Every exemplar here is at or under the ceiling, deliberately: an exemplar list
that shows a 3-sentence line while the rule says 2 teaches the exception.

- `dungeon/trapped_halls.json · skill_hint_toast` — "Hauling at it idly will
  not do it. Setting your shoulder to it properly might." *Two sentences, the
  Skill implied, nothing decorative.*
- `floodplains/floodplains.json · skill_hint_toast` — "From up here the
  floodplains pretend to be a map. Good eyes could read it." *One image, then
  the instruction. The image serves the hint instead of competing.*
- `liscor/barracks.json · item_hint_toast` — "Nothing to shoot with. A bow in
  hand would do it." *The whole job in nine words.*
- `inn/inn.json · item_hint_toast` — "The kettle wants yarrow before it gives
  anything back." *One sentence. Names the item, states the gate, stops.*

*(The `pallass_market.json` PERMIT-plate refusal used to sit here. It moved to
§8, where it is the diegetic-CAPS exemplar, because it is a grandfathered
3-sentence gate refusal and belongs in the section that explains why it is
allowed rather than the section that sets the ceiling.)*

### Corpus examples — this is what Phase 2 fixes

- `dungeon/trapped_halls.json · locked_toast` — "The stone here looks like all
  the other stone. It is not." *A gate refusal built as a two-beat reversal.
  The player learns nothing actionable from the second sentence.*
- `dungeon/trapped_halls.json · skill_hint_toast` — "The floor ahead looks
  exactly like the floor behind you. Somehow, that is the part that bothers
  you." *A hint that ends on the narrator's feeling instead of the hint.*
- `dungeon/trapped_halls.json · gate_closed_toast` — "…you are not walking
  into it yet — not with the halls still armed, not without the Horns at your
  back." *A gate message in a rhetorical doublet. The two conditions are real
  information and should be stated as two conditions.*

---

## 2. SCENIC — 406 strings (48%), the bulk register

**Definition.** Environmental description with no quest payload and no person
in it. The largest register by far, and therefore **the one that sets the
reader's sense of the default voice.** If scenic prose has rhetorical
architecture, the whole world reads authored.

**RULED — the definition has to admit its own biggest exception.** 278 of the
406 scenic strings (**68%**) are tagged **`quest-prop`**: they hang on an
entity that banks an accomplishment. *(The draft said 298 of these props moved
out of character-bearing into scenic; the review corrected it to **281**, and
281 is exactly right for the pre-fix classification. Re-scoping skill-outcome
by path then moved 3 of the 281 to functional, so the live figure is 278. The
generated tables in `inventory-summary.md` are the authority.)* They are scenic because banking makes a
prop *quest-load-bearing*, not *character-revealing* — but "no quest payload"
is false of them at the mechanical level, and Phase 2 must know it:

> **On a `quest-prop` string, the STYLE may change and the FACT PAYLOAD may
> not.** Quest gating, pins and QA scripts read these strings' facts —
> counts, names, directions, item names, which thing is where, what state
> something is in. Reword freely; preserve every fact, in the same field,
> findable. A `quest-prop` rewrite that reads better and drops the number is a
> regression, not a style win. The tag is in every
> `inventory-classified/<region>.json` row; there is no excuse for not knowing
> which strings these are.

### Rules

1. **One or two concrete observations. At most ONE inference.** An inference
   is any claim about something not visible: what happened here, what someone
   meant, what a thing is for.
2. **No thematic closer.** The last sentence may not restate the earlier ones
   at a higher level of abstraction. (Diagnostic, from the rubric: *would it
   fit on a poster?*)
3. **The reader assembles the meaning.** Withholding the conclusion is the
   register's main technique, not a failure of it.
4. **Anonymous agents are rationed** — §6.
5. **Not every prop needs prose worth reading. RULED — SOFT TARGET, NEVER A
   GATE.** In a file with ≥8 scenic strings, ≥⅓ should carry zero inference.
   Phase 4 reports the figure; **no lane is scored on it.** Pair it with §10:
   zero-inference strings must not all converge on one rhythm, or the target
   has bought a monoculture with the inference it saved.

### Corpus examples — this is the sound

- `pallass/pallass_den_shop.json · observe` — "A bench cut down to knee
  height, three sets of claw-marks along the front edge at three different
  heights." *Two observations, zero inference. The reader supplies the
  hatchlings, and the line is better for not saying so. Protected as a MODEL.*
- `dungeon/trapped_halls.json · observe` — "The floor is simply gone here, one
  span of it, edge to edge. Dropped stone comes back as a sound and not much
  of one." *Ends on measurement-by-ear. Informative, atmospheric, no thesis.*
- `floodplains/floodplains.json · observe` — "Three boulders sit too evenly
  spaced for the hillside's own tumble, and one of them, you'd swear, just
  shifted." *One inference (too even to be natural), earned by the visible
  spacing, and it ends on motion rather than conclusion.*

### Corpus examples — this is what Phase 2 fixes

- `riverfarm/witch_hut.json` — **the saturation case, and the one to study**
  (the file itself is out of scope this pass; the lesson is not). Five props,
  and three of their toasts run the same inferred microhistory: the jars
  ("Whoever kept this house left it ready and never came back for it"), the
  drying rack ("Somebody kept this place stocked for a house they intended to
  come back to"), the hearth ("It has been cold for years"). The hearth's is
  **protected** — banked ash genuinely implies an intention to return, and the
  issue names it as earned. The other two are the same inference with the
  evidence swapped, and they *retroactively cheapen the hearth* by revealing it
  as the file's template. **Rule: one inferred microhistory per map file (§6).**
- `pallass/pallass_den_shop.json · toast` — "Eleven names carried. One of them
  has been carried for two years and has no repayment column at all. In
  Pallass, that is a document nobody filed." *Named in the issue. The first
  two sentences are excellent and specific; the third tells the reader what to
  think about them.*
- `dungeon/trapped_halls.json · observe` — "It is not a statue. Statues are
  not built facing the door they guard." *Named in the issue. See §7 — this
  one is a genuinely hard case, because the negation carries real gameplay
  warning.*

---

## 3. CHARACTER-BEARING — 160 strings (19%)

**Definition.** Prose that reveals a person: an NPC's `observe`, their
`friendly_line`, ambient `entities[].dialogue[].text`, or prose about a space
that is unmistakably somebody's.

### Rules

1. **Concrete evidence first. Interpretation optional, and never mandatory.**
   The physical detail must be able to stand alone. If the interpretive
   sentence were deleted, the line should still characterise.
2. **One interpretive move per string, maximum.** Not one per sentence.
3. **The narrator does not out-perform the character. RULED — KEEP, as a
   read-only principle.** If the sharpest observation about an NPC is the
   narrator's rather than theirs, the NPC has been described instead of met.
   No tooling test exists and none is wanted: this rule binds the Phase 5 cold
   read and reviewer judgement, **not** Phase 2 mechanics. Do not build a
   metric for it.
4. **Motif restraint.** A character's semantic field (Olesm/chess-and-counting,
   Pisces/scholarship, Hedault/appraisal, Coyle/inventory,
   Wilovan/hats-and-manners, Zevara/files-and-shifts, Pallass/standards) may
   appear. It may not be *demonstrated* in every string that touches them.
   Map prose is where motif saturation is cheapest to commit and hardest to
   notice, because no one is speaking.
5. **`friendly_line` is a reaction, not a summary.** It fires when the player
   has been decent. It should show the NPC's guard moving, not narrate that it
   moved.

### Corpus examples — this is the sound

- `floodplains/floodplains.json · observe` (Relc) — "A Drake built like a
  barracks door, spear worn smooth from use, standing at ease the way only
  dangerous people stand. He watches the road and everyone on it. Including
  you, now." *Three physical facts; the closing turn is a shift of attention,
  not a verdict.*
- `floodplains/rags_camp.json · observe` (goblin sentry) — "…sharpening
  something that is already sharp. It has not looked directly at you once."
  *Ends on an absence. Nothing is interpreted and everything is conveyed.*
- `dungeon/trapped_halls.json · observe` (Pisces) — "He has not sat down since
  you got here. One hand hovers a finger's width off the stone… his lips move
  without sound." *Pure behaviour. His scholarship is visible without the word
  being used — this is rule 4 satisfied.*

### Corpus example — this is what Phase 2 fixes

- `dungeon/trapped_halls.json` (the `[Observe]` skill-use toast) — "Behind you,
  Pisces says nothing, which from him is applause." *Named in the issue. Two
  tells at once: the `which from X is Y` shape (12 instances corpus-wide) and
  the narrator supplying the interpretation the player should have made.
  "Behind you, Pisces says nothing" already does the work. Note this string is
  character-bearing, so it is **not** in the demotion queue — the queue only
  covers functional/scenic register mismatch. It is on the hand-named work list
  instead (`issue_named_work` in the region file), which is how a
  character-bearing fix gets tracked at all.*

---

## 4. LANDMARK — 9 strings (1%), the scarce register

**Definition.** The register where an epigram, a reversal, an inferred
history, or a thematic closer may be worth its cost. Reserved for **quest and
act payoffs**: the beat a chain has been travelling toward.

**Currently spent** on 9 strings across **8 beats** in 7 of 30 map files — the
Anchor (`dungeon/seal_vault.json`), the seal opening
(`dungeon/trapped_halls.json`), the plinth/Door retrieval
(`ruin/ruin_surface.json`, 2 strings = 1 beat), **two distinct** Invrisil quest
payoffs (`invrisil/mercantile_alleys.json`), the rift seam, the sewer grate,
the fissure descent.

**Every one of the nine has a ruled disposition in `landmark-registry.json`:
7 KEEP-AS-IS, 2 RESTAGE.** RESTAGE means *keep the beat and keep the
correction; lose the CAPS and the staging, and nothing else* — it applies to
`seal_vault`'s "Not a prisoner. An ANCHOR —" and `ruin_surface`'s "not
treasure. A DOOR —". **Lanes get zero discretion beyond the disposition.**
A landmark string is not an invitation to rewrite.

### Rules

1. **Landmark register is earned by the CHAIN, not by the prop.** A prop does
   not promote itself into this register by being interesting. If the player
   has not been working toward this moment, it is scenic. A scenic string may
   still be a protected **peak** without changing register — the garden
   war-memorial plinth is exactly that case, and it is in
   `protected-keeps.json`, not here.
2. **A banked accomplishment is necessary but not sufficient.** State change
   is not a beat. Four strings that bank progress were hand-demoted for
   exactly this (see `classification-overrides.json`): rubble clearing while
   setting a discovery flag is traversal.
3. **What is permitted here and nowhere else:** a thematic closer; a reversal;
   an inferred history; an epigram. **One of them, once, per landmark
   string** — the permission is not cumulative.
4. **The evidence still comes first.** `ruin/ruin_surface.json`'s variant
   ("Beneath where the door lay, still seated in its groove: the anchor stone.
   The Horns left nothing else behind.") is a landmark that spends its
   allowance on an *absence*. It is stronger than its sibling, which spends it
   on "not treasure. A DOOR —", and that is why one is KEEP-AS-IS and the
   other is RESTAGE.
5. **`victory_toast` is landmark-eligible. RULED.** Post-combat is a moment the
   player has worked for, so rule 1 applies to it unchanged. It is also the
   most template-prone surface in the game, so **any landmark `victory_toast`
   requires an explicit petition and can never be self-granted.** The Relc
   demotion to character-bearing stands.

### Diagnostic for the hardest call

The two `ruin/ruin_surface.json · open_toast` strings are the **same beat**
rendered twice (a base toast and a variant). Both are landmark. That is
correct, and it is why §5's budget counts **beats, not strings**.

---

## 5. THE SCARCITY BUDGET (the mechanism)

Numbers derived from the inventory, not chosen for feel. Today: **9 landmark
strings / 8 beats / 30 map files / 847 strings.**

| unit | allowance | today |
|---|---|---|
| a map **file** | **≤1 landmark beat** | 6 files at 1 beat |
| a file that is the payoff site of **two distinct chains** | ≤2 beats | `mercantile_alleys` (2 separate quest payoffs) — the only case |
| a **quest chain**, across every map it touches | **≤3 beats** | Act V (seal + anchor) = 2, one in reserve |
| the **corpus** | **≤12 beats** | **8 spent, 4 held in reserve by the controller** |
| a file whose register mix is majority **functional** | **0** | satisfied |

Counting rules:

1. **Variants of one beat count once.** A base toast plus its
   `open_toast_variants` renderings of the same moment are one beat. Otherwise
   the budget is defeated by authoring the same payoff twice.
2. **A file with no quest payoff gets zero, and may not petition.** 23 of 30
   map files are in this position today and are correct.
3. **Reserve is allocated by the controller on petition**, in the dialogue
   bible's idiom (§5d there: 22 grants, 8 held back). A Phase 2 lane that
   believes a beat deserves promotion writes the petition; it does not
   self-grant.
4. **Spending is a swap, never an addition.** A newly promoted beat must be
   paid for by demoting one — the corpus ceiling is the point.

**RULED — the ceiling is 12 beats: 8 spent, 4 reserve.** The draft's
arithmetic was wrong (it said 7 spent / 5 reserve, missing that
`mercantile_alleys` carries two *distinct* beats rather than two renderings of
one). The ceiling of 12 stands: it keeps landmark at ~1.5% of map prose, so a
player meets one roughly every four maps, and the demotion queue cannot be
absorbed by promotion instead of rewriting. The worry that a ceiling set from
the current state ratifies the current state is answered by the reserve — a
chain that genuinely wants more petitions, and spending is a swap.

---

## 6. Anonymous-agent inference (`someone` / `somebody` / `whoever` / `whatever`)

**The measured problem.** 267 of 847 map strings (**32%**) contain an
anonymous agent, against 184 of 1,445 (13%) in dialogue. And it inverts with
population:

| region | rate | who is actually there |
|---|--:|---|
| garden | 58% | nobody |
| dungeon | 49% | nobody |
| ruin | 47% | nobody |
| sewers | 44% | nobody |
| **floodplains** | **33%** | **populated — and the highest-rate populated region** |
| invrisil | 30% | populated |
| pallass · riverfarm · inn · liscor | 26% each | populated |

**Where there is no one to observe, the narrator supplies someone.** That is
tell family 3 at its clearest, and it is a measurable, region-targeted finding
rather than a taste claim. Note floodplains explicitly: it is populated (Relc,
Rags' camp, the pup) and behaves like an empty region, which makes it the
populated lane most likely to miss its target by assuming the problem is
somewhere else.

### Rules

1. **The inference must be about an ACTION the evidence shows, never about a
   MOTIVE or a FEELING.**
   - Permitted: `riverfarm/riverfarm_mill.json · toast` — "Somebody has cut a
     notch for every flood since before the village had a headman, and built
     the shelf a hand above the worst of them." *The notches are there; the
     height is measurable.*
   - Forbidden: `garden/garden_sanctuary.json · observe` — "Someone carved joy
     here, and meant it to last." *Named in the issue. Neither the joy nor the
     intent is visible; only a dancer's pose is.*
2. **An anonymous agent may not close a string.** If the last sentence
   introduces `someone`/`somebody`/`whoever`, the inference has become the
   point. Cut it or move it earlier.
   - **CONSEQUENCE-ANON is a PERMITTED CLASS** (RULED 2026-08-05, pallass
     petition item 3; amended into §6 at #397 integration, 2026-08-06). A
     **hypothetical future consequence-bearer is not an inferred absent
     agent**: nothing is claimed about anybody who was here, so there is no
     microhistory and no invented motive. It states a cost, which is
     information the player acts on.
     - Permitted: `pallass/pallass_forge_hall.json · locked_toast` — "Heat,
       metal, and a gauge you cannot read. Guessing here costs somebody a
       week." *`somebody` is whoever would pay for the mistake, not somebody
       who did something. The counter still scores `anon_agent 1` here; the
       counter is wrong, and this class is how the bible says so.*
     - Still forbidden, for contrast: the same word pointing BACKWARD at an
       agent the evidence does not show — "Somebody wanted this hidden."
       *That is rule 1's motive claim, and closing on it is this rule.*
3. **One inferred microhistory per map FILE.** This is the `witch_hut` rule
   (§2). A house may have one absent owner, not three.
4. **Targets. RULED — advisory, never a gate.**

   | population | target | why |
   |---|--:|---|
   | corpus | **≤12%** (~100 strings, from 267) | parity with dialogue's 13%; criterion 6 requires map prose to end no worse than dialogue |
   | **unpeopled** — garden, dungeon, ruin, sewers | **≤15%** (from 44–58%) | the deepest cuts, because **the emptiness is the content** and inferring inhabitants spends it |
   | **populated** — everything else, and **floodplains especially** at 33% | **≤10%** | there are real people here to observe instead |

   The absent-builder counter-case — "a ruin's only available
   characterisation *is* its absent builders" — is honoured by rule 1 (actions
   the evidence shows), **not** by a looser number.

---

## 7. Negation / correction, at the distribution level

**Measured:** 29 instances in map prose (3%), 11 in dialogue (1%), and 7 map
strings stack two or more shapes in a single string. The issue's instruction is
to reduce this **at the distribution level** and keep it where it is
voice-distinctive.

**The complication this bible has to solve:** "keep where voice-distinctive"
is a dialogue rule, and map prose has one voice. Nothing here can be
distinctive *of a speaker*. So the keep criterion is re-derived as
**function**, not voice — **RULED, ratified verbatim, including all four
worked examples:**

> A negation/correction survives when it corrects a **wrong assumption the
> scene actively invites**, and the correction is information the player needs.
> It dies when it merely reframes for effect.

- `dungeon/trapped_halls.json · observe` — "It is not a statue. Statues are
  not built facing the door they guard." **Partial keep.** The scene has just
  shown the player a statue-shaped thing among real statues; "it is not a
  statue" is a *threat warning*, and the player acts on it. The second
  sentence is the reframe-for-effect and is what should go. Rewriting this to
  lose the warning would be a facts regression, not a style win.
- `dungeon/seal_vault.json · open_toast` — "Not a prisoner. An ANCHOR —"
  **Keep the correction, lose the staging.** The player has spent the chain
  believing the ward imprisons something; overturning that is the payoff, and
  this is a landmark string entitled to a reversal (§4). The CAPS goes (§8).
  Recorded as **RESTAGE** in `landmark-registry.json`.
- `ruin/ruin_surface.json · open_toast` — "Below the pedestal: not treasure. A
  DOOR —" **Keep, restaged.** Same argument; the player's expectation of
  treasure is real and the scene set it up. CAPS goes. Also **RESTAGE**.
- `hedault_enchanting.json` (dialogue, cited by the issue) — **deferred to
  Phase 3**, not this bible's jurisdiction. Noted so the parallel is visible;
  the graph is in the heatmap table.

### Rules

1. **Zero in functional register.** A gate refusal never corrects an
   assumption stylishly ("The stone here looks like all the other stone. It is
   not.").
2. **Corpus ceiling for map prose: 8, from 29. RULED — adopt 8.** The
   dialogue bible's comparable ceiling is 30 across 56 speakers; 8 across one
   narrator is the proportional read.
3. **At most one per map file**, and never twice on the same prop. The 7
   strings that stack ≥2 shapes are the first work: `liscor/street.json`'s
   sewer-grate `observe` runs **four** in four sentences.
4. **The `X is not the same as Y` and `not P. A Q.` shapes are the mechanical
   ones** and go first; a negation embedded mid-sentence is far less visible
   and is not the priority.

### The other shared shapes

12 instances of `which from X is Y` / `the way X does` / `the X is the X`
(vs 1 in dialogue). **Target: zero.** These are pure geometry with no
information payload, and unlike negation none of them warns the player about
anything. "Pisces says nothing, which from him is applause" and "the count is
the point and the rope is only the rope" are the exemplars.

---

## 8. The inherited bans, now applied here

These are enforced at **zero** in dialogue and are **unenforced** in map
prose. They are the cheapest wins in the pass. **All three ship ADVISORY in
maps mode this pass** (RULED: no new hard gates), and are promoted to hard at
issue close only if the pass ends with zero legitimate exceptions.

| shape | map instances | rule |
|---|--:|---|
| mid-line ellipsis / leading-ellipsis stage beat | 6 | **0.** Same as dialogue. Includes `runners_guild.json · text` "…five more minutes." and one ambient `text` that is *only* "…". |
| "the whole of / the entire" | 2 | **0.** Both are closers, and one is an issue-named button. |
| CAPS as **emphasis** | 9 | **0.** |
| CAPS as **diegetic lettering** | 14 | **PERMITTED.** |

**RULED — permit diegetic lettering, ban emphasis at zero, with a mechanical
proxy.** Diegetic CAPS must be **attributed to a physical written surface named
in the same string** — a sign, a plate, a board, a card, "in smaller writing
than the rest" — or be the heading of a `copy` document, whose capitals are the
document by definition. Phase 4 reports **lettering-context CAPS and bare CAPS
as two separate classes**; the bare list is the work queue; **judgement stays
the final arbiter** and the proxy is a smoke detector like every other regex in
this pass.

The proxy currently splits the 23 instances **14 lettering / 9 bare**. The
lettering side is `COYLE AND SONS` on a hanging board, `PERMIT AND STAMP
REQUIRED` on a stencilled plate, `THE WANDERING INN — NO KILLING GOBLINS` on a
hand-painted board, `WORKING SPACE, BY THE HOUR, NO CREDIT` on a hand-lettered
card, `WATCH NOTICE` / `TRAVELER'S NOTE` heading the Guild board's `copy`
documents, `THE DELIVERY BOARD`. The bare side is the work: `ANCHOR`, `DOOR`,
`CLICKS`, `POURING`, `HAND`, `SLEEP`, `RECOVERS`, `WITH`, `HELD`. A naive port
of the dialogue gate's `\b[A-Z]{3,}\b` rule would fail all 14 correct strings,
which is exactly why the gate was not ported.

**The diegetic-CAPS exemplar** — and a grandfathered exception worth naming:

- `pallass/pallass_market.json · locked_toast` — "The brass gate is locked. A
  stencilled plate: PERMIT AND STAMP REQUIRED. The clerk's window is open."
  *Three facts, one of them the answer. The CAPS is what is physically
  stencilled on the plate, and the plate is named in the same sentence — the
  proxy and the judgement agree.* **It is also three sentences in a register
  whose ceiling is two (§1.4).** It is grandfathered: the middle sentence is a
  quoted physical object rather than authorial prose, and cutting it would cost
  the player the actual requirement. It is a **worked exception, not a
  precedent** — a lane that wants a third sentence petitions with the string in
  hand.

---

## 9. Ending-shape variety (acceptance criterion 9)

The issue names six shapes. All six occur in the corpus already; the problem
is proportion, not vocabulary.

| shape | corpus example |
|---|---|
| **fact** | `dungeon/seal_vault.json · toast` — "Nobody came back to make the ninety-third." |
| **motion** | `dungeon/trapped_halls.json · taken_toast` — "The bones rise and fall into step behind you." |
| **interruption** | `inn/inn.json · text` — "Innkeeper! Anyone?" |
| **unresolved detail** | `invrisil/invrisil_boulevard.json · text` — "Browsing, or selling?" (a real question, unanswered) |
| **instruction** | `dungeon/trapped_halls.json · gate_closed_toast` — "Leave it that way." |
| **silence / absence** | `floodplains/rags_camp.json · observe` — "It has not looked directly at you once." |

### Rules

1. **Score every string's ending shape** during Phase 2, not only the ones
   being rewritten. The rubric requires it per row for the same reason.
2. **Within one map file, no single ending shape may exceed 40% of its
   scenic + functional strings. RULED — adopt 40%, advisory, and compute the
   current per-file distribution BEFORE any lane treats it as binding.** If
   most currently-good files violate 40%, loosen to 50% rather than force
   churn. The number exists to catch a lane building one rhythm, not to make
   good files churn.
3. **Within a region, at least 4 of the 6 shapes must appear.**
4. **Two adjacent props may not share an ending shape. RULED — "adjacent"
   means ENTITY-LIST ORDER**, which is cheap and deterministic and is what the
   computed check uses. Grid proximity stays a **cold-read lens** where a map
   has obvious prop clusters; it is not the mechanical definition.

---

## 10. THE ANTI-TEMPLATE WARNING

**This is the most likely way Phase 2 fails, and it will pass every metric in
this document while failing.**

The issue says it plainly: *"Do not replace the current templates with a
single new 'plain fact + physical action' template."* Every rule above pushes
in one direction — less inference, no closers, concrete detail, plain
functional prose. Applied mechanically by ten region lanes working in
parallel, the result is a **new monoculture**, and uniform plainness is itself
a machine signature. A reviewer reading the revised corpus cold would score it
*differently* but not *lower*.

### What the failure looks like

Take `riverfarm/witch_hut.json`, whose five props today share one inferred
microhistory. The lazy fix produces:

> - The jars: "A row of stoppered jars along the top shelf. Every stopper is
>   waxed. Dust has settled on the shoulders of each one."
> - The rack: "A rack of bundled stems along the wall. The bundles are tied
>   with twine. The stems have gone brittle."
> - The hearth: "Cold ash banked against the back of the hearth. The banking
>   has held its shape. Nothing has disturbed it."
> - The shutter: "One shutter, latched. Daylight comes through the slats. The
>   latch is on the inside."

Every string obeys every rule. Zero inference, zero closers, concrete nouns,
plain register. And it is **worse than what we have**: four strings, one
rhythm — noun phrase, flat declarative, flat declarative. The narrator has
stopped being uniform*ly clever* and become uniform*ly flat*. The banked-ash
line, which the issue protects as genuinely earned, has been destroyed to
satisfy a rule that was written to protect it.

The tell to watch for: **if you can read a file's strings aloud in sequence
and hear one metre, it does not matter that no sentence breaks a rule.**

### Guards

1. **Not every string changes.** The work queue is **64 demotion candidates**
   out of 847, plus the inherited-ban instances (9 bare CAPS, 6 ellipses, 2
   "whole of"), the anonymous-agent reduction, and the hand-named work list.
   **The default action on a scenic string is leave it alone.** A region lane
   that rewrote most of its strings has misread the assignment.
2. **A PROTECTED KEEP OUTRANKS EVERY RULE IN THIS DOCUMENT. RULED.** A string
   in `protected-keeps.json` is **never rewritten, even where it trips a rule
   here**, and **it consumes the relevant budget**: the `witch_hut` banked-ash
   line *is* that file's one inferred microhistory (§6.3), so the rest of the
   file has none left to spend — the keep does not sit outside the budget, it
   occupies it. Same for the garden war-memorial plinth: it is the garden's
   protected peak, at scenic register, and the garden's remaining strings
   inherit a tighter allowance because of it, not a looser one. The keeps are
   also **calibration**: they carry MODEL entries precisely so lanes have
   in-corpus examples of the target sound. Read them before your first
   rewrite; that reading is mandatory, not suggested.
3. **Vary the shape of the FIX, not just the fix.** The dialogue bible's §4
   replacement mandate names three moves (put a thing in the line / hands keep
   working / leave the ledger open) and warns that using move 3 everywhere
   builds a new template. The same warning applies with more force here,
   because there is no per-speaker variety to hide behind.
4. **Sentence-length variance. RULED — computed in Phase 4, report-only to the
   controller and reviewer.** Per-file sentence-length standard deviation is
   **not** published in Phase-2 lane briefs and has **no target number**. An
   unseen metric cannot be gamed; a published one becomes the work. A file
   whose strings all land in 12–18 words has been templated even if each is
   individually fine, and that is a finding for the cold read, not a number for
   a lane to hit.
5. **The gate is the cold read.** Criterion 9 requires final review samples to
   show preserved peaks, newly literal functional prose, *and multiple distinct
   ending shapes, with no replacement template dominating.* No count in this
   document can establish that.

### Gaming the counters (read this before you open a region file)

Every regex in `extract_prose.py` is a **smoke detector. The cold read is the
gate.** Two consequences, both binding:

**The anon-agent and negation rules bind SEMANTICALLY, not lexically.** Any
unnamed inferred agent counts as an anonymous agent — "the hand that cut
these", "whoever it was", "a previous tenant", "the last person through here"
— whether or not the word `someone` appears. Any correction geometry counts as
a negation-correction — "not P, Q", "P? No. Q.", "it looks like P; it is not" —
whether or not the regex fires. **Deleting the word `someone` while keeping the
inference is not a fix; it is a fix that beats the counter.** A lane whose
anon-agent number fell without its prose changing has done nothing, and Phase 5
reads prose, not counters.

Concrete proof that the counters are blind: eleven map strings turn on a place
keeping a schedule the player is not on — "Pallass sweeps on schedule",
"Pallass hires carts on a schedule too", "Pallass does not run two shifts at
once", "the alley keeps its own inventory schedule", "the warren restocks on
its own schedule", "The heat in here keeps a schedule, and you are not on it".
**Four of them score closer 0, anon 0, neg 0.** They are invisible to every
trigger in the tooling and they are unmistakably one template. Nothing in the
generated work queue will ever hand them to you.

**Phase-2 lanes may PETITION to protect additional earned peaks they find.**
The controller adjudicates. `protected-keeps.json` is not exhaustive and was
never claimed to be — the garden war-memorial plinth was added by ruling
*after* the review found the tooling could not see it (closer 0, anon 0,
neg 0). **Flattening an unlisted peak because "it wasn't in keeps" is a
misread of this document**, and it is the specific misread that would let this
pass destroy the thing it is protecting. When you find a line that is doing
real work and no counter flagged it: petition, and leave it alone until the
answer comes.

---

## 11. Ruling register (formerly the open `[ADJUDICATE]` list)

Every question the draft raised, with the controller's ruling. Full record:
`bible-adjudication.md`.

| § | question | **RULING** |
|---|---|---|
| 1.4 | functional length ceiling of 2 sentences (`copy` excepted) | **ADOPTED.** Counts sentences, not clauses. Loosen only by petition with the string in hand. |
| 2.5 | quantify "some scenery may be forgettable" as a zero-inference quota? | **SOFT TARGET, NEVER A GATE.** ≥⅓ zero-inference in files with ≥8 scenic strings; Phase 4 reports, no lane is scored. Pair with §10. |
| 3.3 | "narrator does not out-perform the character" — untestable by tooling | **KEEP as a read-only principle.** Binds the Phase-5 read and reviewer judgement, not Phase-2 mechanics. |
| 5 (ceiling) | landmark corpus ceiling of 12 beats | **ADOPTED 12.** Arithmetic corrected: **8 spent, 4 reserve**, allocated by petition; spending is a swap. |
| 5 (`victory_toast`) | landmark-eligible at all? | **ELIGIBLE.** Relc demotion stands; §4 rule 1 applies unchanged; any landmark `victory_toast` needs an explicit petition. |
| 6.4 | anon-agent target ≤12%; stricter in unpeopled regions? | **ADOPTED.** Corpus ≤12% advisory; unpeopled ≤15%; populated ≤10%, floodplains named. Absent-builder case honoured by rule 1, not by a looser number. |
| 7.2 | negation/correction map ceiling of 8 (from 29) | **ADOPTED 8.** Keep-criterion-as-function ratified verbatim, all four worked examples; hedault deferred to Phase 3. |
| 8 | CAPS: permit diegetic lettering, ban emphasis — mechanically separable? | **PERMIT lettering, BAN emphasis (0).** Proxy adopted: capitals attributed to a named written surface (or a `copy` heading). Two classes reported separately; the bare list is the queue; judgement is the arbiter. |
| 9.2 | 40% single-ending-shape cap per file | **ADOPTED 40%, advisory** — but Phase 4 computes the current per-file distribution first; loosen to 50% rather than force churn. |
| 9.4 | definition of "adjacent" | **ENTITY-LIST ORDER** for the computed check. Grid proximity stays a cold-read lens. |
| 10.4 | per-file sentence-length variance as an advisory metric | **ADOPTED, report-only to controller/reviewer.** Not in lane briefs, no target number — an unseen metric can't be gamed. |
| §0 | should the dialogue tier system extend to map prose? | **NO. Registers replace tiers**; §0's argument ratified. |
| — | does any of this become a hard gate? | **NO NEW HARD GATES THIS PASS.** Inherited bans ship advisory in maps mode; promote at issue close only if the pass ends with zero legitimate exceptions. |

**Also binding Phase-2 doctrine** (from the ruling record):

- One inferred microhistory per map file — the `witch_hut` rule.
- Guard 10.1: the default action on a scenic string is **leave it alone**.
- `protected-keeps.json` is **mandatory calibration reading** before a lane's
  first rewrite, and a keep outranks any rule it trips (guard 10.2).
