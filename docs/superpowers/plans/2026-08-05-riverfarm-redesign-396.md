# Riverfarm Redesign Implementation Plan (issue #396)

> Status: **ACTIVE** — queued, not started: do not implement until the active code session lands (see Global Constraints).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Riverfarm's Hunter with "A Shepherd", replace his quest with
`a_winter_of_teeth`, drop the briar-fight ally (solo re-gate), and wrap the
[Hedge Witch] grant in a new Eloise quest `the_makings`.

**Architecture:** Pure content surgery on `data/*.json` + one new sprite +
sim/QA re-gates. No engine changes. All shipped ids frozen; retirement =
gating producers, never deleting counters or quest defs. Spec:
`docs/superpowers/specs/2026-08-05-riverfarm-shepherd-and-witch-quests-design.md`.

**Tech Stack:** Godot 4.7 headless (QA + unit gates), `data_lint.py`
pre-gate, PixelLab MCP (sprite), declarative QA scripts.

## Global Constraints

- **DO NOT START until the currently-active session's work lands on main.**
  Then branch fresh off main (`issue/396-riverfarm-redesign`) and cherry-pick
  the two spec/plan doc commits if #388's branch hasn't merged.
- Shipped-ids freeze: never rename/re-semanticize `hunter_will_come`,
  `survived_wolf_night`, `heard_thicket_keeps`, `thicket_answered`,
  `witch_lessons`, `witch_craft_used`, `tended_beasts`, `soothed_a_beast`,
  any `fought_*`. `shipped_ids.json` is generated — do not hand-edit; regen
  happens at release cut only.
- Frozen internal ids kept with legacy `_comment`s: `riverfarm_hunter`
  (entity, combatant, dialogue file), `hunters_lamb_pen`.
- Every `data/*.json` edit: `python3 wandering_inn_game/scripts/data_lint.py`
  FIRST, then the Godot gates (lint is never a substitute).
- Zero-warning bar: grep every run for `SCRIPT ERROR|Parse Error|WARNING`.
- A failed QA `assert` HANGS: wrap runs
  `perl -e 'alarm 45; exec @ARGV' /usr/local/bin/godot ...`.
- New copy: T1 rural voice (avg ≤8 words/sentence, no subordinate clauses).
  Copy below is DRAFT-FINAL: ship it as written; the voice-card recut
  (Task 11) is the only pass allowed to amend it, one adjudicated pass.
- Naming: **"A Shepherd"** (indefinite; commoner pattern). Never "The
  Shepherd", never "Hunter" in any player-visible string in Riverfarm.
- `ward_scrap_read` must never bank `detected_wardwork` (standing rule).
- New accomplishment counters this plan mints: `heard_winter_teeth`,
  `fold_rebuilt`, `pack_traced`, `winter_answered`, `heard_the_makings`,
  `makings_brought`, `craft_tended`.
- All commands run from repo root.
- **Schema-drift check at start:** this plan's dialogue/map JSON drafts were
  authored before the talk-line/dialogue-line BANK sweeps landed on this
  branch (`27a01604`, `8ee2e704` — "write a line once, reference it
  everywhere"). Before Task 2/3/9, diff one current dialogue file against
  the drafts' inline-text shape; if lines now live in banks, adapt the
  drafts mechanically (same copy, bank-referenced) — copy and gating are
  the contract, field shape is not.

## Lane map (from spec; `quests.json` is integrator-owned)

- Lane 0: Task 1 (sprite) — fully parallel.
- Lane 1: Tasks 2–5, 7, 8 (shepherd + winter quest + its QA).
- Lane 2: Task 6 (ally removal + sim re-gate).
- Lane 3: Tasks 9–10 (Eloise quest + QA).
- Tasks 4 and 9 both write `quests.json` → run them in one lane or hand
  patches to the controller; never two lanes writing it live.
- Tasks 11–12 (voice/docs, close) run after all lanes land.

---

### Task 1: Sprite `a_shepherd`

**Files:**
- Create: `wandering_inn_game/assets/sprites/a_shepherd/` (6 sheets)
- Modify: `wandering_inn_game/data/sprites.json` (new block after `a_hunter`)
- Modify: `wandering_inn_game/tests/test_sprite_registry.gd` (expected rows)
- Modify: `wandering_inn_game/assets_manifest.json`, `ATTRIBUTION.md`

**Interfaces:**
- Produces: sprite key `"a_shepherd"` consumed by Task 2 (map) and Task 3's
  combatant note. Sheet contract identical to `a_hunter`:
  `Idle_{Down,Side,Up}-Sheet.png` + `Run_{Down,Side,Up}-Sheet.png`.

- [ ] **Step 1:** Read `data/sprites.json` `a_hunter` block (line ~2696) and
  `tests/test_sprite_registry.gd`'s `a_hunter` rows; note frame counts,
  fps, anchor fields — the new block mirrors every field.
- [ ] **Step 2:** Generate via PixelLab (wi-art-and-sprites flow, max
  fidelity). Character prompt: *"Middle-aged human shepherd, sturdy, brimmed
  felt hat, long wooden crook in hand, plain wool cloak over work clothes,
  muted earth tones. No bow, no quiver, no game bag."* Distinct-silhouette
  check against Former Headman / A Villager / a_hunter before accepting:
  crook + hat must read at gameplay zoom.
- [ ] **Step 3:** Export/place the 6 sheets under
  `assets/sprites/a_shepherd/` matching `a_hunter` filenames exactly.
- [ ] **Step 4:** Add `"a_shepherd"` block to `sprites.json` — copy the
  `a_hunter` block verbatim, swap every `a_hunter` path segment to
  `a_shepherd`. Add matching expected-frame-count rows to
  `test_sprite_registry.gd` (copy `a_hunter` rows, rename key).
- [ ] **Step 5:** Gates:
  ```bash
  python3 wandering_inn_game/scripts/data_lint.py
  /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sprite_registry.gd 2>&1 | grep -E "SCRIPT ERROR|Parse Error|WARNING|FAIL" ; echo exit=$?
  ```
  Expected: lint clean; suite pass, grep finds nothing.
- [ ] **Step 6:** `assets_manifest.json` + `ATTRIBUTION.md` entries
  (PixelLab outputs: user-owned + redistributable). Windowed read comes in
  Task 2 (sprite must be on the map first).
- [ ] **Step 7:** Commit: `feat(#396): a_shepherd sprite + registry rows`

### Task 2: Village map — character surface + route props

**Files:**
- Modify: `wandering_inn_game/data/maps/riverfarm/riverfarm_village.json`

**Interfaces:**
- Consumes: sprite key `a_shepherd` (Task 1).
- Produces: props `winter_fold_hurdles` (banks `fold_rebuilt`) and
  `wolf_sign_trail` (banks `pack_traced`) consumed by Task 4's quest beats
  and Task 7's QA; gate counter `heard_winter_teeth` produced by Task 3.

- [ ] **Step 1:** Entity `riverfarm_hunter` edits:
  - `display_name` → `"A Shepherd"`; `sprite` → `"a_shepherd"`.
  - `observe` → `"Tar-marked hands, a crook worn smooth, wolf sign on his boots. The flock is penned. He is still watching the treeline."`
  - `dialogue` preview stays `"Hollow's not safe alone."` but speaker →
    `"A Shepherd"`.
  - Replace `_comment` with: `"legacy id -- character is A Shepherd (2026-08-05 redesign, spec 2026-08-05-riverfarm-shepherd-and-witch-quests-design.md). Id frozen: shipped counters + save entity keys."`
  - `talk_pool` →
    ```json
    [
     "Hollow's quieter than it should be. Doesn't sit right.",
     "Lost two lambs to something with thorns for teeth. Wasn't a wolf.",
     "Know that treeline better than the headman does. He'd rather not.",
     "Wolf sign's thicker toward the hollow, week by week. The pack's ground moved. Mine didn't.",
     "The witch? Her business is hers and I keep to mine. Sheep is my trade, all of it."
    ]
    ```
  - `talk_pool_stages`: keep all four stage ids. `thread_hollow` line →
    `"The hollow's west past the fields. Nobody walks you there. Nobody local, anyway."` (unchanged — now true). `thread_neutral` lines = the new
    base pool verbatim (it duplicates base by design). `thicket_answered` and
    `lambs_tended` stage lines survive unchanged (already flock-voiced).
    Add a fifth stage:
    ```json
    {
     "id": "riverfarm_shepherd_winter_answered",
     "requires_accomplishment": { "winter_answered": 1 },
     "lines": [
      "Watch fires stay lit till thaw. Cheap, next to lambs.",
      "Pack's fed elsewhere or it's thinner. Either way it's off my fields.",
      "First snow came and the count held. The count held."
     ]
    }
    ```
    (Last-satisfied-wins: place after `lambs_tended`.)
- [ ] **Step 2:** Entity `hunters_lamb_pen`: `display_name` → `"A Lamb Pen"`;
  `observe` → `"Hurdle fencing the shepherd threw up after the thicket business. Two ewe lambs inside it, and a third that will not put weight on a foreleg."`;
  add legacy `_comment` (same wording as Step 1). Everything else untouched
  (#330 contract).
- [ ] **Step 3:** Add two route props (clear cells near pen/field edge; pick
  unblocked cells per wi-adding-a-scene and verify with lint):
  ```json
  {
   "_comment": "#396 a_winter_of_teeth WORK route. Quest-gated; once. fold_rebuilt is the route counter.",
   "id": "winter_fold_hurdles",
   "kind": "prop",
   "cell": [15, 12],
   "display_name": "Stacked Hurdles",
   "sprite": "riverfarm_fence_ew",
   "present_when": { "requires": { "heard_winter_teeth": 1 } },
   "observe": "Hazel hurdles, cut and stacked. Enough to double the fold, if someone puts the day in.",
   "on_interact_accomplishment": "fold_rebuilt",
   "toast": "You put the day in. Double hurdles, drained ground, a gate that hangs true. The fold holds a wolf out now, not just sheep in."
  },
  {
   "_comment": "#396 a_winter_of_teeth TRACK route. Quest-gated; once. pack_traced is the route counter. Copy reveals the displacement and points at the old line.",
   "id": "wolf_sign_trail",
   "kind": "prop",
   "cell": [4, 13],
   "display_name": "Wolf Sign",
   "sprite": "trail_gap",
   "present_when": { "requires": { "heard_winter_teeth": 1 } },
   "observe": "Prints in the field margin. Too many, too bold, all one direction.",
   "on_interact_accomplishment": "pack_traced",
   "toast": "You walk the sign back. The pack came off the north ground by the old line -- something denned in it and they gave way. They didn't choose these fields. They were pushed."
  }
  ```
  Verify prop field shapes against the pen entity (same idiom) and
  wi-adding-a-scene; adjust cells if lint flags blocking/overlap.
- [ ] **Step 4:** Gates:
  ```bash
  python3 wandering_inn_game/scripts/data_lint.py
  wandering_inn_game/qa/run_qa.sh load_gate headless
  bash wandering_inn_game/qa/ci_sweep.sh --touching wandering_inn_game/data/maps/riverfarm/riverfarm_village.json
  ```
  Expected: existing riverfarm scripts FAIL on pinned "The Hunter"
  speakers — that's Tasks 7–8's work; record which scripts failed, confirm
  failures are pin-only (speaker/text payloads), nothing structural.
- [ ] **Step 5:** Windowed read (sprite + pen + props on screen), read the
  PNG yourself:
  ```bash
  wandering_inn_game/qa/run_qa.sh riverfarm_fight windowed --seed=<pinned>
  ```
- [ ] **Step 6:** Commit: `feat(#396): A Shepherd surface + winter route props (village map)`

### Task 3: Dialogue — `riverfarm_hunter.json` rewrite

**Files:**
- Modify: `wandering_inn_game/data/dialogue/riverfarm_hunter.json`
- Modify: `wandering_inn_game/data/combatants.json` (`riverfarm_hunter` block)

**Interfaces:**
- Consumes: nothing new.
- Produces: `heard_winter_teeth` (offer), `hunter_will_come` (watch ask —
  frozen counter, semantics preserved), `winter_answered` (report rows).
  Node ids consumed by Task 7 QA: `winter_brief`, `watch_agreed`,
  `winter_reported_watch`, `winter_reported_fold`, `winter_reported_traced`.

- [ ] **Step 1:** `combatants.json` `riverfarm_hunter`: `display_name` →
  `"A Shepherd"`, `sprite` → `"a_shepherd"`, `_comment` → legacy note (Task
  2 wording). Stats/die/ai/skills untouched.
- [ ] **Step 2:** Dialogue file. All `speaker` fields → `"A Shepherd"`
  (every node, legacy ones included — the NPC is the same person on legacy
  saves). Hub changes:
  - Hub base `text` → `"Wolf sign's thicker every week. Three lambs gone since spring. The pack's off its own ground and eating mine."`
  - Hub `text_variants` → replace both with:
    ```json
    [
     { "requires": { "accomplishment": { "hunter_will_come": 1 } }, "text": "Dark soon. Field edge, when you're ready. I'll be there." },
     { "requires": { "accomplishment": { "survived_wolf_night": 1 } }, "text": "You stood a watch before I ever asked. Word went round the fields." },
     { "requires": { "accomplishment": { "winter_answered": 1 } }, "text": "Count's holding. Fires stay lit till thaw anyway." }
    ]
    ```
    (Later-listed variant wins on overlap — verify variant precedence in
    dialogue.gd; order so `winter_answered` beats the others.)
  - DELETE the old offer row (`"The deer stopped at the treeline. Why?"`).
    Keep untouched: the three thicket report rows, the R2 re-entry row, and
    their `_comment`s (legacy saves; all gate on `heard_thicket_keeps`).
  - REPLACE the come-along row (`"[Ask him to come with you.]"`) with the
    watch ask, same position (cursor-pin rule: canonical indices hold):
    ```json
    { "text": "[Offer to stand the night watch with him.]", "requires": { "accomplishment": { "heard_winter_teeth": 1 } }, "hide_when": { "accomplishment": { "hunter_will_come": 1 } }, "goto": "watch_agreed" }
    ```
  - APPEND LAST (cursor-pin rule), the winter offer + report rows:
    ```json
    { "text": "The wolves. Say what you need.", "hide_when": { "accomplishment": { "heard_winter_teeth": 1 } }, "effects": [ { "quest": "a_winter_of_teeth" }, { "accomplishment": "heard_winter_teeth" } ], "goto": "winter_brief" },
    { "text": "We stood the night. The pack's thinner for it.", "requires": { "accomplishment": { "heard_winter_teeth": 1, "survived_wolf_night": 1 } }, "hide_when": { "accomplishment": { "winter_answered": 1 } }, "effects": [ { "accomplishment": "winter_answered" } ], "goto": "winter_reported_watch" },
    { "text": "The fold's rebuilt. Double hurdles, drained ground.", "requires": { "accomplishment": { "heard_winter_teeth": 1, "fold_rebuilt": 1 } }, "hide_when": { "accomplishment": { "winter_answered": 1 } }, "effects": [ { "accomplishment": "winter_answered" } ], "goto": "winter_reported_fold" },
    { "text": "Your wolves were pushed. Something holds their old ground.", "requires": { "accomplishment": { "heard_winter_teeth": 1, "pack_traced": 1 } }, "hide_when": { "accomplishment": { "winter_answered": 1 } }, "effects": [ { "accomplishment": "winter_answered" } ], "goto": "winter_reported_traced" }
    ```
    Carry a `_comment` on the report cluster mirroring the old one: all
    three report rows gate on `heard_winter_teeth` beside their route
    counter so no ungated producer can leak `winter_answered`.
- [ ] **Step 3:** New nodes (add; keep all legacy `thicket_*` nodes intact):
  ```json
  "winter_brief": {
   "speaker": "A Shepherd",
   "text": "Three ways I see it. Stand the watch with me and thin them. Rebuild the fold so they stop mattering. Or walk the sign and learn why they came. Wolves don't move ground for nothing.",
   "options": [
    { "text": "Where do I start?", "goto": "winter_topic" },
    { "text": "I'll see to it.", "end": true }
   ]
  },
  "winter_topic": {
   "speaker": "A Shepherd",
   "text": "Hurdles are cut and stacked by the pen. Sign runs the west margin, plain as a road. And the watch is mine, every night. Company's welcome.",
   "options": [
    { "text": "Back up a step.", "goto": "winter_brief" },
    { "text": "Noted.", "end": true }
   ]
  },
  "watch_agreed": {
   "speaker": "A Shepherd",
   "text": "Field edge, after dark. Bring your own bandages. I've got enough of my own to worry about.",
   "options": [
    { "text": "Deal.", "effects": [ { "accomplishment": "hunter_will_come" } ], "end": true }
   ]
  },
  "winter_reported_watch": {
   "speaker": "A Shepherd",
   "text": "So we did. One night bought is one night. I'll take it. The fires stay lit regardless.",
   "options": [ { "text": "One night's a start.", "end": true } ]
  },
  "winter_reported_fold": {
   "speaker": "A Shepherd",
   "text": "Walked it this morning. Gate hangs true. A wolf tests a fence once and remembers. My father built the old fold. He'd have said nothing and checked it twice.",
   "options": [ { "text": "Sleep well.", "end": true } ]
  },
  "winter_reported_traced": {
   "speaker": "A Shepherd",
   "text": "Pushed. Off their own ground, by the old line. So it was never my fields they wanted. Wolves and me both, working round something neither of us can see.",
   "options": [ { "text": "Neither of you chose it.", "end": true } ]
  }
  ```
  `_comment` on `watch_agreed`: `"banks hunter_will_come (FROZEN id, legacy name): semantics preserved -- this NPC fields as ally at river_wolf_pack. end+effects ordering note carried from legacy agreed node."` Keep legacy
  `agreed` node (unreachable for new saves once the ask row is replaced;
  legacy saves' banked state doesn't need it — delete `agreed` ONLY if
  data_lint flags orphans; otherwise leave with a legacy comment.)
- [ ] **Step 4:** Gates:
  ```bash
  python3 wandering_inn_game/scripts/data_lint.py   # catches dangling gotos
  wandering_inn_game/qa/run_qa.sh load_gate headless
  ```
- [ ] **Step 5:** Commit: `feat(#396): shepherd dialogue -- winter offer/routes/report, thicket offer retired`

### Task 4: `quests.json` + `leads.json` (integrator-owned file)

**Files:**
- Modify: `wandering_inn_game/data/quests.json`
- Modify: `wandering_inn_game/data/leads.json`

**Interfaces:**
- Consumes: counters from Tasks 2–3.
- Produces: quest id `a_winter_of_teeth` (Task 3's offer row references it).

- [ ] **Step 1:** Add after `what_the_thicket_keeps`:
  ```json
  {
   "_comment": "#396. Replaces what_the_thicket_keeps for NEW saves (offer retired in riverfarm_hunter.json; legacy def below stays completable forever -- shipped counters). FIGHT route counter is survived_wolf_night (FROZEN, semantics identical, encounter on_victory untouched); pre-bank cohort handled by hub text_variant + normal offer row, so accept->resolve reads intentional. Report rows carry heard_winter_teeth beside their route counter.",
   "id": "a_winter_of_teeth",
   "title": "A Winter of Teeth",
   "region": "Riverfarm",
   "beats": [
    { "id": "resolve", "description": "Wolf sign thickens toward the hollow and the shepherd is losing lambs. Stand the night watch at the field edge, rebuild the fold from the stacked hurdles, or walk the wolf sign and learn what pushed the pack.", "complete_when_any": { "survived_wolf_night": 1, "fold_rebuilt": 1, "pack_traced": 1 } },
    { "id": "report", "description": "Tell the shepherd how the winter gets survived, at the lamb pen.", "complete_when": { "winter_answered": 1 } }
   ],
   "_resolution_order": "WEAKEST CLAIM FIRST (resolved_path is last-match-wins), all three co-bank. Ladder: traced > fold > watch. One night's wolves buy a night; hurdles buy a winter; knowing why they push is the answer.",
   "resolution_paths": [
    { "accomplishment": "survived_wolf_night", "text": "You stood the night watch and the pack paid for the field." },
    { "accomplishment": "fold_rebuilt", "text": "You rebuilt the fold, and the wolves stopped mattering." },
    { "accomplishment": "pack_traced", "text": "You walked the sign back and found the pack was pushed -- their old ground is held by something on the line." }
   ]
  }
  ```
- [ ] **Step 2:** `what_the_thicket_keeps` `_comment` gains:
  `"RETIRED FOR NEW SAVES 2026-08-05 (#396): offer row deleted in riverfarm_hunter.json; def stays forever for legacy saves mid-quest (shipped counters). Successor: a_winter_of_teeth."`
- [ ] **Step 3:** `leads.json`: delete the `lead_thicket` row. Add:
  ```json
  { "id": "lead_winter", "hide_when": { "heard_winter_teeth": 1 }, "lead_text": "A shepherd at Riverfarm watches the treeline more than his own flock.", "place": "The lamb pen, Riverfarm" }
  ```
  (No `requires` — untied, ruling 3. Match surrounding rows' field shape.)
- [ ] **Step 4:** Gates: `data_lint.py` + `load_gate` + run one untouched
  quest script as harness regression:
  ```bash
  wandering_inn_game/qa/run_qa.sh floodplains_price_help headless --seed=<pinned>
  ```
- [ ] **Step 5:** Commit: `feat(#396): a_winter_of_teeth quest + lead; thicket retired for new saves`

### Task 5: Wolf-night QA smoke of the new flow (manual-level check)

**Files:** none created — verification checkpoint before QA authoring.

- [ ] **Step 1:** Headless spot-run the full new-save flow with a throwaway
  QA sketch or manual driver: talk (offer) → hurdle prop (work route) →
  report row → quest complete. Confirm toasts fire once each, no
  back-to-back New-quest/Quest-complete, `winter_answered` banks.
- [ ] **Step 2:** Pre-bank cohort: fixture with `survived_wolf_night: 1`,
  fresh otherwise → hub shows the "stood a watch before I ever asked"
  variant; offer row → accept; resolve completes on accept; report row
  visible in SAME hub; picking it completes. Two player actions, two
  toasts — reads intentional. If it reads glitchy in Task 12's machine
  playtest, fallback (spec'd): mint `watch_stood`, bank via a post-fight
  dialogue row, swap the beat counter. Do NOT preemptively build fallback.
- [ ] **Step 3:** No commit (checkpoint only; findings feed Task 7).

### Task 6: Ally removal + briar solo re-gate

**Files:**
- Modify: `wandering_inn_game/data/maps/riverfarm/witch_hollow.json`
- Modify: `wandering_inn_game/tests/sim_combat_batch.gd`
- Modify (only if retune fires): `wandering_inn_game/data/combatants.json`

**Interfaces:**
- Consumes: nothing from other tasks (parallel-safe lane).
- Produces: solo-gated briar cells; Task 8 reshapes `riverfarm_fight.json`
  against this.

- [ ] **Step 1:** `witch_hollow.json`: remove `allies` + `ally_requires`
  from `briar_collectors` AND `briar_collectors_deep`. Replace both
  `_comment`s: `"#396: ally removed (user ruling 2026-08-05) -- nobody local walks you to the hollow. Solo sim gates in sim_combat_batch.gd. hunter_will_come still fields the shepherd at river_wolf_pack (village) only."`
  Do NOT touch `river_wolf_pack` in the village map.
- [ ] **Step 2:** Measure BEFORE gating — run the harness, record win rates
  and round medians for `briar_collectors_w10_solo`,
  `briar_collectors_deep_w10_solo`, and add temporary
  `t3_warrior10`-build solo cells for both fights (copy the `_hunter` cell
  rows, `"solo": true`, drop `win_lo/win_hi` for the measurement run):
  ```bash
  /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd 2>&1 | tee /tmp/396-sim-baseline.txt
  ```
- [ ] **Step 3:** Gate + prune:
  - Delete all `_hunter` briar cells (list at `sim_combat_batch.gd:203-230`:
    `briar_collectors{,_deep}_{w10,t3_spellsword9,t3_warrior9,t3_warrior10}_hunter`)
    and the stale name in the header list (line ~35).
  - Gate `briar_collectors_t3_warrior10_solo` at `0.55–0.95` (the thicket
    solo precedent) and `briar_collectors_deep_t3_warrior10_solo` from
    measurement (±0.07 envelope around measured, `check_rounds: true`).
  - **Retune rule (spec):** if deep solo measured `< 0.50` at `t3_warrior10`
    or `< 0.20` at `warrior5_mage5`, step `briar_collector_deep_a/_b` down
    (con first, then weapon_die) and re-measure until `t3_warrior10` solo
    lands ≥ 0.55 — `blight_lifted` rides this fight; the anchor's fight
    route must stay viable solo. If retune fires: combat-data seed check —
    re-run every combat QA script at its pinned seed (table in
    `wandering_inn_game/AGENTS.md`).
- [ ] **Step 4:** Gates: full harness green + zero warnings; if combatants
  changed, seed-check sweep from Step 3.
- [ ] **Step 5:** Commit: `feat(#396): briar fights solo -- ally removed, sims re-gated` (+ `retune:` trailer if it fired)

### Task 7: QA — `a_winter_of_teeth` scripts + fixtures

**Files:**
- Create: `wandering_inn_game/qa/scripts/winter_teeth_talk.json`,
  `winter_teeth_work.json`, `winter_teeth_fight.json`
- Create: `wandering_inn_game/qa/fixtures/winter_teeth_start.json`,
  `winter_teeth_prebank_start.json`
- Modify: `wandering_inn_game/qa/manifest.json`

**Interfaces:**
- Consumes: node ids from Task 3, props from Task 2, quest from Task 4.

- [ ] **Step 1:** Author per wi-writing-qa-scripts (read it first; follow
  the thicket_keeps_* scripts as the closest idiom — same offer/route/report
  shape). Coverage contract:
  - `winter_teeth_talk`: fresh fixture → hub → offer row (assert quest
    started + `heard_winter_teeth`) → `winter_brief`/`winter_topic` walk →
    report blocked (no route counter) → hurdle prop → report row → assert
    `winter_answered` + quest complete + resolution text.
  - `winter_teeth_work`: fold route in isolation — prop present only after
    offer (assert absent before), once-semantics, toast payload pinned.
  - `winter_teeth_fight`: watch ask (assert `hunter_will_come` banks AFTER
    dialogue_ended — carry the legacy `agreed`-node ordering note), night
    phase, `river_wolf_pack` with shepherd fielded as ally, victory banks
    `survived_wolf_night`, report row completes. Plus a pre-bank leg on
    `winter_teeth_prebank_start` (Task 5 Step 2 shape) asserting the
    variant text + same-hub report.
  - TRACK route riding inside `winter_teeth_talk` or a fourth script if
    cleaner: `wolf_sign_trail` interact banks `pack_traced`, its report row
    text pinned.
- [ ] **Step 2:** Derive seeds per wi-writing-qa-scripts; add manifest rows.
- [ ] **Step 3:** Run each headless at pinned seed, zero warnings; then one
  untouched script (harness regression):
  ```bash
  wandering_inn_game/qa/run_qa.sh winter_teeth_talk headless --seed=<derived>
  wandering_inn_game/qa/run_qa.sh crate_fight headless --seed=<pinned>
  ```
- [ ] **Step 4:** Commit: `test(#396): winter_teeth QA trio + fixtures`

### Task 8: QA — legacy thicket re-anchor + riverfarm_fight reshape

**Files:**
- Modify: `wandering_inn_game/qa/scripts/thicket_keeps_talk.json`,
  `thicket_keeps_skill.json`, `thicket_keeps_fight.json`,
  `riverfarm_fight.json`
- Create: `wandering_inn_game/qa/fixtures/thicket_legacy_start.json`

**Interfaces:**
- Consumes: Task 2/3 surface (speaker "A Shepherd"), Task 6 solo briars.

- [ ] **Step 1:** New fixture `thicket_legacy_start.json`: copy
  `thicket_talk_start.json`, pre-bank `heard_thicket_keeps: 1` (+ whatever
  route state each script's leg needs) — models a legacy save mid-quest.
- [ ] **Step 2:** Re-anchor the three `thicket_keeps_*` scripts on the
  legacy fixture; re-pin their 4 `"The Hunter"` speaker payloads →
  `"A Shepherd"`; adjust the talk script's hub option-index comments (offer
  row deleted, watch-ask row replaced — recount indices, the file's own
  `_comment` discipline). These scripts now PROVE the retirement contract:
  legacy saves complete the retired quest.
- [ ] **Step 3:** `riverfarm_fight.json`: come-along leg re-pins to the
  watch-ask copy (`[Offer to stand the night watch with him.]`,
  `watch_agreed` text, speaker payload); briar legs drop ally assertions
  (fights run solo — expect longer fights, seed re-derivation likely);
  wolf-night leg keeps ally assertions. 1 speaker payload re-pin.
- [ ] **Step 4:** Run all four at pinned/re-derived seeds, zero warnings.
- [ ] **Step 5:** Commit: `test(#396): legacy-thicket re-anchor + riverfarm_fight reshape`

### Task 9: Eloise craft quest — `the_makings`

**Files:**
- Modify: `wandering_inn_game/data/dialogue/riverfarm_witch.json`
- Modify: `wandering_inn_game/data/quests.json` (integrator-owned — coordinate with Task 4)
- Modify: `wandering_inn_game/data/maps/riverfarm/witch_hollow.json`
  (`hollow_offering_pot`), `riverfarm_village.json` (tend prop)

**Interfaces:**
- Consumes: nothing from Lane 1 (offer gate is the existing
  `blight_lifted` + `hide_when drove_off_collectors` row).
- Produces: quest `the_makings`; counters `heard_the_makings`,
  `makings_brought`, `craft_tended`; `witch_lessons` unchanged as terminal.

- [ ] **Step 1:** `riverfarm_witch.json`. The hub row `"The way you work —
  the craft. Could a person learn it?"` keeps its gate + position and
  becomes the quest starter: `goto` → `makings_brief`,
  add `"effects": [ { "quest": "the_makings" }, { "accomplishment": "heard_the_makings" } ]`
  and `"hide_when": { "accomplishment": { "heard_the_makings": 1 } }`
  (starter is one-shot). APPEND a re-entry row `"About the makings."` with
  `requires {heard_the_makings: 1}` + `hide_when {witch_lessons: 1}` +
  `goto makings_brief` (tallyman shape, appended last — cursor-pin rule).
  New nodes:
  ```json
  "makings_brief": {
   "speaker": "Eloise",
   "text": "Craft isn't told, child. It's done. Three things, then. Fill the pot by my stones with what the hollow gives you. Tend something that can't thank you for it. Then come sit my kettle, and we'll see what you felt while you worked.",
   "options": [
    { "text": "That's all? Chores?", "goto": "makings_chores" },
    { "text": "I'll start with the pot.", "end": true }
   ]
  },
  "makings_chores": {
   "speaker": "Eloise",
   "text": "Every witch you'll ever fear got that way doing chores with her whole heart in them. The chore is the least of it. What you carry while you do it is the craft.",
   "options": [ { "text": "Then I'll carry it well.", "end": true } ]
  },
  "makings_kettle": {
   "speaker": "Eloise",
   "text": "Pot filled. A lamb standing sound that wasn't. And you, back at my table with your hands smelling of both. Sit. The kettle's been waiting on you, not the water.",
   "options": [
    { "text": "[Sit, and take the lesson.]", "goto": "witch_lesson" }
   ]
  }
  ```
  The existing `witch_lesson` node keeps its text; its teach option
  (`"Then teach me the first of it."` → banks `witch_lessons`) gains
  `"requires": { "accomplishment": { "makings_brought": 1, "craft_tended": 1 } }`.
  Add a hub row (appended last) surfacing the closer:
  `{ "text": "The makings are done.", "requires": { "accomplishment": { "makings_brought": 1, "craft_tended": 1 } }, "hide_when": { "accomplishment": { "witch_lessons": 1 } }, "goto": "makings_kettle" }`.
  `_comment` the cluster: `witch_lessons` stays the ONLY bank point
  (frozen counter, now quest-terminal; legacy saves with it banked see
  nothing new — existing bank-option `hide_when` already covers them).
- [ ] **Step 2:** `witch_hollow.json` `hollow_offering_pot` becomes the
  gather surface (currently inert):
  ```json
  "present_when" stays as-is (if any);
  add: "observe": "A waiting pot by the standing stones. Eloise's, for what the hollow gives.",
  "on_interact_accomplishment": "makings_brought",
  "interact_when": { "requires": { "heard_the_makings": 1 } },
  "toast": "You work the hollow's margin til the pot is full. Rosehips, dead-nettle, a knot of wool off the briars. Nothing rare. Everything looked at properly."
  ```
  (If the prop schema lacks `interact_when`, gate with a variant or a
  `requires`-shaped field per the anchor-stone's `portal_menu_when`
  precedent — data_lint's vacuous-gate check + wi-adding-a-scene rule on
  which gate shapes are legal for interact rows. Same idiom question as
  Task 2 Step 3; resolve once, apply to both.)
- [ ] **Step 3:** Village map: add tend prop by the pen (separate row, same
  prop-idiom; `tended_beasts`/#330 untouched):
  ```json
  {
   "_comment": "#396 the_makings TEND beat. Separate prop beside hunters_lamb_pen -- never touches the #330 counters.",
   "id": "makings_tend_lamb",
   "kind": "prop",
   "cell": [17, 11],
   "display_name": "The Limping Lamb",
   "sprite": "riverfarm_fence_ew",
   "present_when": { "requires": { "heard_the_makings": 1 } },
   "observe": "The third lamb, the one that would not bear weight. Someone has to sit with it long enough to matter.",
   "on_interact_accomplishment": "craft_tended",
   "toast": "You sit with it past the point that's useful and into the point that counts. It sleeps. You notice you were humming."
  }
  ```
- [ ] **Step 4:** `quests.json` (coordinate with Task 4's owner):
  ```json
  {
   "_comment": "#396. Wraps the [Hedge Witch] grant in a quest (user ruling 2026-08-05). Offer gate = the ratified peaceful-OR path, unchanged. witch_lessons (FROZEN) stays the terminal bank inside witch_lesson's teach option, now requiring both beat counters. Sequential beats.",
   "id": "the_makings",
   "title": "The Makings",
   "region": "Riverfarm",
   "beats": [
    { "id": "gather", "description": "Fill the pot by Eloise's standing stones with what the hollow gives.", "complete_when": { "makings_brought": 1 } },
    { "id": "tend", "description": "Tend something that can't thank you for it, at the lamb pen.", "complete_when": { "craft_tended": 1 } },
    { "id": "lesson", "description": "Sit Eloise's kettle and take the first lesson.", "complete_when": { "witch_lessons": 1 } }
   ]
  }
  ```
  (No `resolution_paths` — single path; match whatever the schema requires
  for linear quests by checking an existing linear quest def first; if all
  quests carry `resolution_paths`, add the single-entry form.)
- [ ] **Step 5:** Gates: `data_lint.py`, `load_gate`, selective sweep
  touching both maps + witch dialogue; run existing witch-flow scripts
  (`crate_fight` etc. per manifest) at pinned seeds — the hub gained only
  appended rows + one goto change, pinned option indices must hold.
- [ ] **Step 6:** Commit: `feat(#396): the_makings -- Eloise craft quest wraps Hedge Witch grant`

### Task 10: QA — `the_makings` script

**Files:**
- Create: `wandering_inn_game/qa/scripts/makings_loop.json`
- Create: `wandering_inn_game/qa/fixtures/makings_start.json`
- Modify: `wandering_inn_game/qa/manifest.json`

- [ ] **Step 1:** Fixture: peaceful-path save (`blight_lifted: 1`,
  `mediated_the_debt`-shaped, `drove_off_collectors: 0`,
  `witch_lessons: 0`) standing at Eloise.
- [ ] **Step 2:** Script: offer row visible → accept (assert quest +
  `heard_the_makings`) → teach option ABSENT in `witch_lesson` (beat gate
  holds) → pot interact (assert `makings_brought`, beat 1) → tend prop
  (assert `craft_tended`, beat 2) → "The makings are done." → kettle node →
  teach option present → bank `witch_lessons` → sleep → assert
  `hedge_witch` granted (the class's `gained_by`, unchanged). Negative leg:
  fixture variant with `drove_off_collectors: 1` asserts the offer row
  never renders.
- [ ] **Step 3:** Derive seed, manifest row, run headless zero-warning +
  one untouched script.
- [ ] **Step 4:** Commit: `test(#396): the_makings QA loop`

### Task 11: Voice cards, baselines, logs

**Files:**
- Create: `docs/dialogue-voice-cards/riverfarm-shepherd+bark.md`
- Modify: `docs/dialogue-voice-cards/riverfarm-hunter+bark.md` (superseded header)
- Regenerate: `docs/dialogue-voice/baseline/riverfarm_hunter.json`,
  `docs/dialogue-voice/baseline/riverfarm_witch.json`,
  `docs/dialogue-voice/baseline-maps/riverfarm_village.json`,
  `witch_hollow.json`
- Modify: `docs/CHOICE-LOG.md`, `docs/VISUAL-LOG.md`

- [ ] **Step 1:** New card: T1 rural stats carried over; CANON-VOICE →
  "Riverfarm shepherd, flock loss on his mind before mystery; respect in
  work terms." PEAK assignment: `winter_reported_traced` ("Wolves and me
  both, working round something neither of us can see.") — the file's one
  landed moment; nothing else gets a button. Note "Fences before deer."
  survives only in legacy `thicket_*` nodes and keeps its pin THERE.
  Run this card as the one adjudicated voice pass over all Task 2/3/9 draft
  copy; amend copy + re-pin any QA text payloads it moves (pin-sync rule).
- [ ] **Step 2:** Regenerate baselines with the voice-pass tooling
  (procedure in `docs/superpowers/plans/2026-08-03-dialogue-voice-pass.md`).
- [ ] **Step 3:** CHOICE-LOG entries (one line each): quest replacement over
  reskin; briar ally removal + solo gates; `hunter_will_come` reuse with
  preserved semantics; edge cohort losing the un-accepted thicket offer;
  pre-bank offer-variant decision. VISUAL-LOG: `a_shepherd` eye-gate row.
- [ ] **Step 4:** Commit: `docs(#396): shepherd voice card, baselines, choice/visual logs`

### Task 12: Close — full bar + machine playtest + states

- [ ] **Step 1:** Full gates: `data_lint.py`; ALL unit suites (count
  `tests/test_*.gd`, run each, grep `SCRIPT ERROR|Parse Error|WARNING`);
  full canonical QA sweep; balance harness green.
- [ ] **Step 2:** wi-machine-playtest pass (windowed, player eyes): shepherd
  in village, wolf-night watch, both new quests end-to-end, Eloise beats.
  Explicit check: pre-bank cohort flow (Task 5 Step 2) — if it reads
  glitchy, fire the spec'd `watch_stood` fallback and loop Tasks 3/4/7.
- [ ] **Step 3:** Playtest states (playtest-states pattern), shipped in
  `qa/playtest_saves/`: (1) fresh at shepherd, (2) watch agreed + night,
  (3) `the_makings` mid-beat-2. README with load lines.
- [ ] **Step 4:** Update HANDOFF; PR per wi-running-the-machine gates;
  closes #396.

---

## Self-review notes (done at plan time)

- Spec coverage: A→Tasks 1–3; B→2–5,7,8; C→6,8; D→9–10; voice/docs→11;
  acceptance criteria→12 (criteria 1–7 map to Task 12 steps + Task 8's
  legacy proof + Task 6's gates).
- Deliberate deviations from bite-size TDD shape: content tasks gate on
  data_lint + QA scripts rather than unit-test-first (project idiom: QA
  scripts ARE the tests; wi-writing-qa-scripts governs).
- Two schema unknowns are flagged inline with resolution instructions
  rather than guessed silently: interact-gate shape on props (Tasks 2/9,
  resolve once against wi-adding-a-scene + data_lint), linear-quest
  `resolution_paths` requirement (Task 9 Step 4, check an existing linear
  def).
