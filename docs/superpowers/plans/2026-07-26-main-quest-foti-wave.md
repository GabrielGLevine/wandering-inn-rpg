# Main Quest Line + Friends of the Inn Wave — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kill the "post-game" framing, backport the Horns door-retrieval quest, thread an ordered Riverfarm→Invrisil→Pallass Main Quest to an Act V finale, and ship Friends of the Inn PR2 plus four new quest-gated inn guests (#269 extended).

**Architecture:** Data-first Godot 4.7 (`wandering_inn_game/`): quests/acts/dialogue/maps are JSON, sim logic in `src/core/*.gd`, UI in `src/ui/*.gd`. Two lanes — Lane A (main quest: quests.json, acts.json, ruin/inn/portal data, save.gd, sleep_beat/sleep_veil) and Lane B (FoTI: inn guest rows, `<npc>_inn.json` conversations, wi_inn_guests.gd). **inn.json is single-writer: Phase 2 merges before any Lane B phase merges.**

**Tech Stack:** Godot 4.7 headless for tests; declarative QA scripts in `wandering_inn_game/qa/scripts/`; canonical fixtures with pinned rng_state.

**Specs:** docs/design/2026-07-26-main-quest-line-spec.md (authority for Phases 1–2, 6–9); docs/design/2026-07-20-door-continuation-spec.md as amended by its §7 (Phase 7); docs/design/2026-07-20-foti-pr2-spec.md (Phases 3–4, mechanism authority for Phase 5).

## Global Constraints

- Test runner: `/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/<file>.gd` from repo root. Failed `assert` HANGS headless runs — alarm-wrap: `perl -e 'alarm 120; exec @ARGV' -- <command>`.
- Before claiming any change works: load `wi-verifying-changes`. Writing/altering QA scripts: load `wi-writing-qa-scripts`. Dialogue/quest edits: load `wi-adding-dialogue-and-quests`. Map edits: load `wi-adding-a-scene`. Encounters/balance: load `wi-adding-an-encounter`.
- Spoiler rule (binding, spec §3): "The Dig" title and `join_dig`/`breach` beat copy NEVER mention a door. Door named only from `haul` onward.
- No fetch-list copy (spec §4): spine/journal text points at reach, never itemizes objects.
- "the Magical Door" only — never a Vol-9 name, never "second door". Book-17 bar on all new material; oblique-Thresk where the wiki is silent.
- The door prop never speaks. Pisces is the voice.
- New counters ride plain accomplishments; freeze list (spec §9) names them at first write. STRUCTURAL_LITERALS in `scripts/generate_shipped_ids.py` + `tests/test_shipped_ids.gd` are updated at RELEASE tag time, not per-PR.
- FoTI roster is APPEND-ONLY: `[selys, krshia, olesm, pisces, relc, zevara, klbkch, rags, wilovan, grimalkin]` final order. Every guest entity on the inn carries an IDENTICAL `{roster, seats}` (co-located validator, test_content ~line 426).
- Guest conversation contract (FoTI spec): fresh 3-node `<npc>_inn.json` (greet / one off-duty topic / served), attached only to the guest row, no talk_pool; serve option on greet AND topic nodes: `requires {once_per_waking: "serve:<entity_id>", item: "hot_meal"}`, effects `[{bank_first_use...}, {accomplishment: "served_customer"}, {gold: 2}, {remove_item: "hot_meal"}]`.
- Guest rows are REGISTER-PURE: no home mechanics ride the inn row.
- Canonical pins are re-derived from a real run's events.jsonl, never assumed.
- Commits end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- One branch per phase off `main` (`wave/mq1-acts`, `wave/mq2-dig`, `wave/foti-2a`, `wave/foti-2b`, `wave/foti-ext`, `wave/mq3-spine`, `wave/mq4-act5`, `wave/mq5-finale`, `wave/mq6-bands`); PR per phase; merge order: mq2 before foti-* (inn.json ownership), mq3 before mq4.
- Model allocation (user directive 2026-07-26): implementation/review subagents run Opus 5 (`model: "opus"`); Fable (controller) keeps architecture, adjudication, spec/gate judgment, and the hardest verify stages. Codex Sol lane per `wi-delegating-to-codex` unchanged.

---

## Phase 1 — Acts/gating reframe (PR `wave/mq1-acts`)

### Task 1.1: Act III advances on the seal alone

**Files:**
- Modify: `wandering_inn_game/data/acts.json:30`
- Test: `wandering_inn_game/tests/test_acts.gd`

**Interfaces:**
- Produces: act_iv reachable at `raskghar_sealed` alone. Phase 2/6/7 rely on this.

- [ ] **Step 1: Read test_acts.gd; find any pin asserting act_iii's advance_when includes door_awakened.** Note assertion lines.
- [ ] **Step 2: Edit acts.json act_iii:**

```json
"advance_when": { "accomplishments": { "raskghar_sealed": 1 } },
```

Also update act_iii's `_comment`-free beats: keep `the_stirring`; keep `seal_holds` (post_game still banks, Task 1.2). Update the file-top `_comment` sentence "Act IV advance_when is defined but unreachable until Act V exists." → "Act IV advance_when is defined but unreachable until Act V exists (Phase 7 of the 2026-07-26 wave fills it)."

- [ ] **Step 3: Update any test_acts.gd pins found in Step 1 to the new gate (act_iv entered when raskghar_sealed>=1, door_awakened NOT required).** Add an explicit regression assert:

```gdscript
# act_iv must not require door_awakened (2026-07-26 main-quest reframe)
var gates: Dictionary = _act_gate("act_iii")
assert(not (gates.get("accomplishments", {}) as Dictionary).has("door_awakened"))
```

(Adapt helper name to the file's existing idiom — read it first.)

- [ ] **Step 4: Run:** `perl -e 'alarm 120; exec @ARGV' -- /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_acts.gd` — expect PASS.
- [ ] **Step 5: Commit** `feat(acts): act IV opens on the seal alone (main-quest reframe PR1)`.

### Task 1.2: post_game banks at the seal, not the epilogue

**Files:**
- Modify: `wandering_inn_game/src/core/sleep_beat.gd:128-153` (the sleep pass)
- Test: `wandering_inn_game/tests/test_sleep_beat.gd` (create assert case in existing file if present; else extend test_acts.gd's sim-level case)

**Interfaces:**
- Produces: `post_game` guaranteed banked by first sleep after `raskghar_sealed`, independent of the epilogue playing. Epilogue's own `_bank_post_game` (sleep_veil.gd:316) stays until Phase 8 retires it — both banks are idempotent.

- [ ] **Step 1: Write failing test** — sim-level: record `raskghar_sealed`, run one sleep pass, assert `post_game >= 1` without any epilogue event. Follow the existing sleep-pass test idiom in the file (read it first; the `_count`/`_record_accomplishment` closures are injected).
- [ ] **Step 2: Run it** — expect FAIL (post_game only banks via epilogue today).
- [ ] **Step 3: Implement** in sleep_beat.gd's sleep pass, after the `_maybe_fire_tremor_pointer()` block:

```gdscript
	# 2026-07-26 reframe: post_game means "Liscor counts you among its own",
	# banked silently at the first sleep after the seal -- the epilogue no
	# longer owns it (and is retired entirely in the finale phase).
	if _count("raskghar_sealed") >= 1 and _count("post_game") < 1:
		_record_accomplishment.call("post_game", 1)
```

No toast, no `anything_happened` — silent by design.

- [ ] **Step 4: Run the test** — expect PASS. Also run `res://tests/test_sim_core.gd`.
- [ ] **Step 5: Copy pass:** in `data/maps/liscor/guild.json:360` and `data/dialogue/olesm_intro.json` (stipend surface near line 180), reword any dev `_comment`/player copy implying "post-game"/"the story is over" to mid-story framing ("after the seal", "now that the Watch trusts you"). Grep: `grep -rn "post.game\|postgame" wandering_inn_game/data/ --include="*.json"` and fix player-facing/comment text (ids untouched).
- [ ] **Step 6: Run** `res://tests/test_content.gd` + `res://tests/test_dialogue.gd` — expect PASS.
- [ ] **Step 7: Commit** `feat(sim): bank post_game at the seal sleep; mid-story copy pass`.

---

## Phase 2 — "The Dig" + door reshape + day-one Liscor link (PR `wave/mq2-dig`)

New counters (spec §9): `horns_dig_started`, `horns_dig_joined`, `pedestal_breached`, `door_retrieved`, `door_mounted`.

### Task 2.1: quests.json — add `horns_dig`, reshape `door_that_goes_elsewhere`

**Files:**
- Modify: `wandering_inn_game/data/quests.json` (door_that_goes_elsewhere block, currently beats consult/recover_stone/buy_catalyst/attune; insert horns_dig before it)
- Test: `wandering_inn_game/tests/test_content.gd` (quest schema arm), `res://tests/test_quests.gd` if present

**Interfaces:**
- Produces: quest ids `horns_dig`, reshaped `door_that_goes_elsewhere`; beat counters as below. Tasks 2.2–2.6 bank them.

- [ ] **Step 1: Insert new quest** (before door_that_goes_elsewhere):

```json
{
	"_comment": "2026-07-26 main-quest spec 3: the backport. SPOILER RULE: title + join_dig/breach copy never mention a door; the reveal is the haul beat. Beats are ORDER-GATED by their counters' own gating (camp gates on horns_dig_joined, pedestal on camp, haul on pedestal) -- do not accept the catalyst-style cosmetic skip here.",
	"id": "horns_dig",
	"title": "The Dig",
	"region": "Liscor",
	"beats": [
		{ "id": "join_dig", "description": "Ceria's expedition hit something sealed under the ruin east past the gate road, and they're short-handed. Find the Horns' camp at the ruin.", "complete_when": { "horns_dig_joined": 1 } },
		{ "id": "breach", "description": "Get the Horns through the sealed pedestal level -- fight what guards it, walk the plates, or read the wardwork.", "complete_when": { "pedestal_breached": 1 } },
		{ "id": "haul", "description": "Help the Horns carry what the pedestal held back to the Wandering Inn, and see it mounted.", "complete_when": { "door_mounted": 1 } }
	]
},
```

(Note: haul's journal copy says "what the pedestal held" — still no door word until the on-screen reveal; the beat completes at mounting.)

- [ ] **Step 2: Reshape door_that_goes_elsewhere** — delete the `recover_stone` beat; replace `_comment` and re-copy remaining beats:

```json
{
	"_comment": "2026-07-26 reshape (main-quest spec 2.5): the door works to Liscor from mounting (horns_dig haul); this chain is the first FAR attunement. door_awakened re-semantics to 'reaches beyond Liscor'; its payoff is the Riverfarm rumor surface. Auto-starts at door_mounted via the mounting conversation (no start option). Old cosmetic-skip note is moot: 3 beats, catalyst still ungated on consult by design.",
	"id": "door_that_goes_elsewhere",
	"title": "The Door That Goes Elsewhere",
	"beats": [
		{ "id": "consult", "description": "The Magical Door manages the hop to Liscor but strains at anything farther. Fight what leaks through in the cellar, ask Pisces by the Guild steps, or read the wardwork yourself.", "complete_when": { "door_understood": 1 } },
		{ "id": "buy_catalyst", "description": "Buy the attunement catalyst from Krshia's stall on Market Street in Liscor.", "complete_when": { "bought_catalyst": 1 } },
		{ "id": "attune", "description": "Bring Krshia's catalyst to Pisces, by the Guild steps on Market Street, and see how far the Door can reach.", "complete_when": { "door_awakened": 1 } }
	],
	"resolution_paths": [ ...keep the existing array verbatim... ]
}
```

Keep whatever `resolution_paths` the block currently carries verbatim (read before editing).

- [ ] **Step 3: Run** `res://tests/test_content.gd` — expect PASS (schema + counter-reference lint). If the structural data lint (`scripts/tests/test_data_lint.py` via `python3 -m pytest scripts/tests/test_data_lint.py -q`) checks quest counters, run it too.
- [ ] **Step 4: Commit** `feat(quests): add The Dig; reshape door chain to far-attunement (no dead door)`.

### Task 2.2: Ceria's dig invitation + camp conversation

**Files:**
- Modify: `wandering_inn_game/data/dialogue/ceria_intro.json`
- Modify: `wandering_inn_game/data/dialogue/erin_errand.json` (~line 190-210: the "Something wrong with the pantry door?" hub option)
- Test: `res://tests/test_dialogue.gd`, `res://tests/test_content.gd`

**Interfaces:**
- Consumes: quest id `horns_dig` (Task 2.1).
- Produces: banks `horns_dig_started` (start), `horns_dig_joined` (camp node, Task 2.3 map hooks this conversation).

- [ ] **Step 1: Add to ceria_intro.json hub `options`** (after the existing "Go on." option):

```json
{ "text": "Heard your team's digging east of the gate road.", "requires": { "accomplishment": { "seal_kept_reported": 1 } }, "hide_when": { "accomplishment": { "horns_dig_started": 1 } }, "effects": [ { "quest": "horns_dig" }, { "accomplishment": "horns_dig_started" } ], "goto": "dig_pitch" },
```

Add nodes:

```json
"dig_pitch": {
	"speaker": "Ceria",
	"text": "Word travels. Yes -- there's a ruin out past the floodplains, and under it a level nobody's opened since before Liscor had walls. We hit the seal three days ago. Yvlon can't cut it, Pisces won't shut up about it, and we are exactly one pair of hands short.",
	"options": [
		{ "text": "I'm in. Where's the camp?", "goto": "dig_directions" },
		{ "text": "What's down there?", "goto": "dig_unknown" }
	]
},
"dig_unknown": {
	"speaker": "Ceria",
	"text": "If I knew, I wouldn't need a dig. Whatever it is, someone sealed it on purpose and did a very good job. That usually means valuable, dangerous, or both.",
	"options": [ { "text": "I'm in. Where's the camp?", "goto": "dig_directions" } ]
},
"dig_directions": {
	"speaker": "Ceria",
	"text": "East past the gate road, across the floodplains -- follow the survey stakes. Ask for me at the camp. And bring your own rope.",
	"options": [ { "text": "See you there.", "end": true } ]
}
```

SPOILER CHECK: none of these lines mention a door. "bring your own rope" reuses Ceria's shipped pool line as its pre-echo (door-continuation spec noted it).

- [ ] **Step 2: Retire Erin's old start option.** In erin_errand.json find the hub option with effect `{"quest": "door_that_goes_elsewhere"}` (~line 202). Replace the whole option with a pointer (no quest effect, no accomplishment):

```json
{ "text": "Anything odd around the inn lately?", "requires": { "accomplishment": { "seal_kept_reported": 1 } }, "hide_when": { "accomplishment": { "horns_dig_started": 1 } }, "goto": "ceria_nudge" },
```

Add node:

```json
"ceria_nudge": {
	"speaker": "Erin",
	"text": "Odd? Besides Ceria's whole team leaving at dawn with shovels? She's been going on about some ruin east of here. If you're bored, she was muttering about being short-handed.",
	"options": [ { "text": "Maybe I'll ask her.", "end": true } ]
}
```

The `door_chain_started` accomplishment effect from the old option is GONE — nothing banks it for new saves (cellar leak re-gates in Task 2.4; migration in Task 2.6).

- [ ] **Step 3: Run** `res://tests/test_dialogue.gd` + `res://tests/test_content.gd` — expect PASS. test_content walks every option/effect; a typo'd quest id fails here.
- [ ] **Step 4: Commit** `feat(dialogue): Ceria's dig invitation; Erin nudges instead of starting the chain`.

### Task 2.3: Ruin dig-state — camp, breach, reveal

**Files:**
- Modify: `wandering_inn_game/data/maps/ruin/ruin_surface.json` (pedestal at :139, socket :176, guardian :194, visual_states :167-173)
- Test: the map-validator arm of `res://tests/test_content.gd`, plus `python3 -m pytest scripts/tests/test_data_lint.py -q`

**Interfaces:**
- Consumes: `horns_dig_joined` gating; existing counters `pedestal_unsealed`, `rune_sequence_done`.
- Produces: banks `horns_dig_joined` (camp talk), `pedestal_breached` (pedestal after existing breach mechanics), `door_retrieved` + `recovered_anchor_stone` (reveal interact). Task 2.4 consumes `door_retrieved`.

- [ ] **Step 1: Load `wi-adding-a-scene`. Read the full ruin_surface.json first.** The shipped breach mechanics (rune sequence + guardian + `pedestal_unsealed`) are REUSED as-is — this task re-skins presence, not puzzles.
- [ ] **Step 2: Add the Horns' camp** — a `kind:npc` entity `ceria_dig_camp` near the ruin entrance (pick a free cell per the map's blocked/decor sets; validator enforces), `present_when: {"requires": {"horns_dig_started": 1}, "absent": {"door_retrieved": 1}}`, conversation `ceria_dig_camp` (new nodes appended to ceria_intro.json):

```json
"camp_hub": {
	"speaker": "Ceria",
	"text": "You made it. Camp rules: nobody touches anything shiny, nobody wanders past the survey stakes alone. The sealed level's below the pedestal court. We found the site off an old expedition ledger -- half the pages were about what they DIDN'T bring out.",
	"text_variants": [
		{ "requires": { "accomplishment": { "door_retrieved": 1 } }, "text": "Still can't believe we carried that thing across the floodplains. Erin's already put a tablecloth on it. A TABLECLOTH." }
	],
	"options": [
		{ "text": "Let's open it up.", "hide_when": { "accomplishment": { "horns_dig_joined": 1 } }, "effects": [ { "accomplishment": "horns_dig_joined" } ], "end": true },
		{ "text": "Just passing through.", "end": true }
	]
}
```

(The `door_retrieved` text_variant is the past-tense arm migrated saves see — spec §8.)

- [ ] **Step 3: Breach banking.** On the existing pedestal-unseal completion surface (whatever node/effect banks or requires `pedestal_unsealed` + `rune_sequence_done` — read the map), add a co-located effect banking `pedestal_breached` gated `{"horns_dig_joined": 1}`. If the unseal is prop-interact based, add `banks_accomplishment: "pedestal_breached"` to the same interact with `requires` on both existing counters + `horns_dig_joined`, matching the map's existing bank idiom.
- [ ] **Step 4: The reveal.** Change `anchor_stone_pedestal` (:139) post-unseal interact: when `pedestal_unsealed` + `horns_dig_joined` met and `door_retrieved < 1`, the interact toast (map idiom: `toast`/`observe` + `banks_accomplishment`) becomes:

```
"Below the pedestal: not treasure. A DOOR -- unhung, unmarked, utterly ordinary except that four adventurers go silent around it at once. Ceria, finally: 'That's wardwork. Old, fed wardwork. We're taking it home.' The anchor stone comes up with it."
```

banking `door_retrieved` and `recovered_anchor_stone` (both, one interact — reuse the map's multi-bank idiom if present; else two stacked bank entries per the validator's rules). Add a `visual_states` entry hiding the pedestal's sealed sprite once `door_retrieved >= 1`.

- [ ] **Step 5: Run** map validators + `res://tests/test_content.gd` + data lint — expect PASS (blocking/reachability included).
- [ ] **Step 6: Commit** `feat(ruin): the dig camp, the breach, and what the pedestal held`.

### Task 2.4: Mounting scene + day-one Liscor link + leak re-gate

**Files:**
- Modify: `wandering_inn_game/data/maps/inn/inn.json` (pantry door prop; rift_vermin_leak :1078-1114)
- Modify: `wandering_inn_game/data/dialogue/pisces_magic.json` (mounting node)
- Modify: `wandering_inn_game/data/portals.json` (:rows liscor_street, the_wandering_inn)
- Test: `res://tests/test_content.gd`, `res://tests/test_dialogue.gd`, portal QA canonical (Step 5)

**Interfaces:**
- Consumes: `door_retrieved` (Task 2.3).
- Produces: `door_mounted` banked; `door_that_goes_elsewhere` auto-started; portal rows live at `door_mounted`.

- [ ] **Step 1: Pantry mounting interact.** Find the inn's pantry-door prop entity (grep `pantry` in inn.json). Add an interact arm gated `{"requires": {"door_retrieved": 1}, "absent": {"door_mounted": 1}}` that opens a new pisces_magic.json node `door_mounting`:

```json
"door_mounting": {
	"speaker": "Pisces",
	"text": "Mounted, hinged, and -- observe -- already holding a hop to Liscor's gate district without so much as a rune of encouragement. It works. Now let us see how far it can go.",
	"options": [
		{ "text": "How far CAN it go?", "goto": "door_mounting_far" },
		{ "text": "One thing at a time.", "effects": [ { "accomplishment": "door_mounted" }, { "quest": "door_that_goes_elsewhere" } ], "end": true }
	]
},
"door_mounting_far": {
	"speaker": "Pisces",
	"text": "Farther than Liscor. The wardwork wants distance the way a bowstring wants release -- but push it unattuned and things will leak through that we did not invite. Properly? We attune it. Krshia stocks catalysts; I stock expertise.",
	"options": [ { "text": "Then let's start.", "effects": [ { "accomplishment": "door_mounted" }, { "quest": "door_that_goes_elsewhere" } ], "end": true } ]
}
```

Both exits bank + start — the quest auto-start IS this conversation (spec §2.5). Add pantry `visual_states` mounted-door state on `door_mounted >= 1`.

- [ ] **Step 2: Re-gate the leak.** inn.json:1109 `encounter_when` changes `{"door_chain_started": 1}` → `{"door_mounted": 1, ...}` preserving any other keys; update the :1078 `_comment` and the :1114 observe variant copy to strain fiction ("what leaks through when it strains").
- [ ] **Step 3: portals.json:** rows `liscor_street` and `the_wandering_inn`: `"requires_accomplishment": "door_awakened"` → `"door_mounted"`. Region rows untouched.
- [ ] **Step 4: Run** `res://tests/test_content.gd` + `res://tests/test_dialogue.gd`.
- [ ] **Step 5: QA canonicals.** Load `wi-writing-qa-scripts`. Re-derive `qa/scripts/portal_menu.json` pins (row visibility timing changed for the two Liscor rows) and any door_chain_* fixture that banked `door_chain_started` (now unbanked — swap fixture counter to `door_mounted` per the new flow; re-derive rng via `tests/_derive_rng_state.gd`). Run the affected QA scripts headless; expect green.
- [ ] **Step 6: Commit** `feat(inn): mounting scene, day-one Liscor link, leak re-gated to the mounted door`.

### Task 2.5: seal_kept start re-gate

**Files:**
- Modify: `wandering_inn_game/data/dialogue/olesm_intro.json:177-196`
- Test: `res://tests/test_dialogue.gd`

- [ ] **Step 1:** The "That Watch notice — the gallery survey. I'll take it." option keeps `requires {"accomplishment": {"post_game": 1}}` — post_game now banks at the seal sleep (Task 1.2), so this is already mid-story. Only change: the node's surrounding copy if it references the story being over (read the hub node; reword if needed). No id changes.
- [ ] **Step 2: Run** `res://tests/test_dialogue.gd`; **commit** `chore(dialogue): seal_kept survey copy reads mid-story` (skip commit if no text changed).

### Task 2.6: Save backfill

**Files:**
- Modify: `wandering_inn_game/src/core/save.gd` (after :320, the GH#167 block)
- Test: `res://tests/test_save.gd` (extend; read its fixture idiom first)

**Interfaces:**
- Consumes: counters from 2.1–2.4.

- [ ] **Step 1: Write failing test:** load a fixture save with `door_awakened: 1` (and `door_chain_started: 1`) but none of the new counters; assert after load: `horns_dig_started/joined`, `pedestal_breached`, `door_retrieved`, `door_mounted` all >= 1 and `started_quests` has `horns_dig`.
- [ ] **Step 2: Run** — expect FAIL.
- [ ] **Step 3: Implement** after the GH#167 block:

```gdscript
	# 2026-07-26 main-quest spec 8 backfill: the door chain re-fictioned
	# behind a retrieval quest (horns_dig) that old saves never played.
	# Any old door-chain progress implies the dig happened; bank it whole
	# so no journal points at a door that was never retrieved.
	var acc: Dictionary = s.get("accomplishments", {}) as Dictionary
	var old_chain := int(acc.get("door_understood", 0)) >= 1 \
			or int(acc.get("recovered_anchor_stone", 0)) >= 1 \
			or int(acc.get("bought_catalyst", 0)) >= 1 \
			or int(acc.get("door_awakened", 0)) >= 1 \
			or game.started_quests.has("door_that_goes_elsewhere")
	if old_chain and int(acc.get("horns_dig_started", 0)) < 1:
		for cid: String in ["horns_dig_started", "horns_dig_joined", "pedestal_breached", "door_retrieved", "door_mounted"]:
			game.record_accomplishment(cid)
		if not game.started_quests.has("horns_dig"):
			game.started_quests.append("horns_dig")
```

(Match the surrounding block's actual accessor names — read lines 290–325 first; if accomplishments restore later in the function, place this after that restore.)

- [ ] **Step 4: Run** — expect PASS. Run full `res://tests/test_save.gd`.
- [ ] **Step 5: Commit** `feat(save): backfill The Dig for pre-restructure door-chain saves`.

### Task 2.7: Phase QA gate

- [ ] **Step 1:** Load `wi-verifying-changes`; run its chosen gate set for a data+sim wave (minimum: test_content, test_dialogue, test_quests/test_acts, test_save, affected QA scripts).
- [ ] **Step 2:** Load `wi-machine-playtest` — windowed pass over: Ceria invite → camp → breach → reveal → mounting → Liscor hop. Drain findings to VISUAL-LOG.md.
- [ ] **Step 3:** PR per `wi-shipping` conventions; merge before any FoTI phase merges.

---

## Phase 3 — FoTI PR2a: Olesm + Pisces (PR `wave/foti-2a`)

Execute docs/design/2026-07-20-foti-pr2-spec.md exactly — it is task-grade already. Summary of its own binding details (do NOT re-derive; the spec file is the authority):

- [ ] **Task 3.1:** Add Olesm + Pisces "Inn register" voice blocks to docs/design/character-profiles.md (spec's Voice section, required BEFORE dialogue).
- [ ] **Task 3.2:** `olesm_inn.json`, `pisces_inn.json` — 3-node contract each (Global Constraints), register-pure topics per the spec's voice blocks.
- [ ] **Task 3.3:** inn.json: `olesm_inn_guest` (3,5), `pisces_inn_guest` (6,5); roster becomes `[selys,krshia,olesm,pisces]` in ALL FOUR guest entities (co-located validator).
- [ ] **Task 3.4:** Canonical re-derive per the spec's window math: boot seats olesm+pisces at t=10 (pool 4, start 2); sleep leg t=11 proves live rotation. Re-derive from events.jsonl.
- [ ] **Task 3.5:** Run test_inn_guests + test_content + inn QA scripts; screenshot-verify seats; commit + PR.

## Phase 4 — FoTI PR2b: Relc + Zevara (PR `wave/foti-2b`)

- [ ] **Task 4.1:** Voice blocks (Relc, Zevara) per spec.
- [ ] **Task 4.2:** `relc_inn.json`, `zevara_inn.json` (3-node contract).
- [ ] **Task 4.3:** inn.json rows `relc_inn_guest` (2,5), `zevara_inn_guest` (3,6); roster `[selys,krshia,olesm,pisces,relc,zevara]` in ALL SIX entities. Screenshot-verify no crowding (spec flagged).
- [ ] **Task 4.4:** Keep `inn_guests_start` fixture; RE-PIN its t=10 expectation (pool 5 with zevara unmet → start 0 → selys+krshia, per spec NOTE). Add `inn_guests_full_start` fixture (all six met, t=10 → relc+zevara). Derive from real runs.
- [ ] **Task 4.5:** Tests + QA + screenshots; commit + PR.

## Phase 5 — FoTI extension: Klbkch, Rags, Wilovan, Grimalkin (PR `wave/foti-ext`)

User ruling 2026-07-26: four more guests. Rags, Wilovan, Grimalkin appear only after their quests COMPLETE (not first-met): Rags = `rags_meeting_settled` (chieftains_price terminal), Wilovan = `brothers_job_done` (a_gentlemans_disagreement terminal), Grimalkin = `elevator_pass_stamped` (forge_tier_permit terminal). Klbkch has no quest — met-gate only (`chatted_with_klbkch`, already shipped/frozen).

New counters: `chatted_with_rags`, `chatted_with_grimalkin` (wilovan + klbkch met-counters already frozen: shipped_ids :339/:356).

### Task 5.1: Pool gating mechanism

**Files:**
- Modify: `wandering_inn_game/src/core/wi_inn_guests.gd` (read whole file first — `active_guests` windows met members)
- Test: `wandering_inn_game/tests/test_inn_guests.gd`

**Interfaces:**
- Produces: `GUEST_POOL_GATES: Dictionary` — npc → extra accomplishment required for pool membership. Guest rows in 5.3 ALSO carry the same counter in `present_when.requires` (belt + braces; requires AND guest compose per wi_game.gd:820-846).

- [ ] **Step 1: Write failing test:** roster of 10, all `chatted_with_*` banked, `rags_meeting_settled` NOT banked → assert rags never appears in `active_guests` output across times_slept 0..19; bank it → assert rags rotates in. Mirror the file's existing rotation-test idiom.
- [ ] **Step 2: Run** — expect FAIL.
- [ ] **Step 3: Implement** in wi_inn_guests.gd:

```gdscript
## Quest-completion gates on pool membership (2026-07-26 FoTI extension):
## a rostered npc joins the met-pool only when chatted AND its gate (if
## any) is banked -- otherwise the window would seat an entity whose
## present_when.requires hides it (a ghost-empty seat all waking).
const GUEST_POOL_GATES := {
	"rags": "rags_meeting_settled",
	"wilovan": "brothers_job_done",
	"grimalkin": "elevator_pass_stamped",
}
```

and in the met-pool filter add: `if GUEST_POOL_GATES.has(npc) and sim.accomplishment_count(GUEST_POOL_GATES[npc]) < 1: continue` (adapt to the function's actual accessor — read it).

- [ ] **Step 4: Run** — expect PASS.
- [ ] **Step 5: Commit** `feat(inn-guests): quest-completion pool gates`.

### Task 5.2: Met-counters for Rags + Grimalkin

**Files:**
- Modify: `wandering_inn_game/data/dialogue/rags_meeting.json`, `wandering_inn_game/data/dialogue/pallass_grimalkin.json`
- Test: `res://tests/test_dialogue.gd`

- [ ] **Step 1:** On each file's greet/hub first-contact surface, add the repo's `bank_first_use`-style first-chat bank (mirror how `chatted_with_wilovan` banks in invrisil_wilovan.json — read it, copy the idiom) banking `chatted_with_rags` / `chatted_with_grimalkin`.
- [ ] **Step 2:** Run test_dialogue + test_content; **commit** `feat(dialogue): met-counters for Rags and Grimalkin`.

### Task 5.3: Four voice blocks, four conversations, four guest rows

**Files:**
- Modify: `docs/design/character-profiles.md`; Create: `data/dialogue/klbkch_inn.json`, `rags_inn.json`, `wilovan_inn.json`, `grimalkin_inn.json`; Modify: `data/maps/inn/inn.json` (4 rows + roster in ALL TEN entities)
- Test: test_inn_guests, test_content, test_dialogue

- [ ] **Step 1: Voice blocks** (Inn register, off-duty, register-pure — one per NPC):
  - Klbkch: courteous, precise, faintly wrong-footed by leisure; asks what "resting" is supposed to accomplish; never Hive business.
  - Rags: chieftain slumming it; proud, hungry, counts exits; grudging respect for Erin's tables; never war planning.
  - Wilovan: hat-tipping gentleman-rogue courtesy; everything oblique; never names the trade.
  - Grimalkin: off-duty means a LIGHTER workout; assesses patrons' squat depth; never permit-office business.
- [ ] **Step 2: Conversations** — 3-node contract each (greet / one topic / served), serve options per Global Constraints with entity ids `klbkch_inn_guest`, `rags_inn_guest`, `wilovan_inn_guest`, `grimalkin_inn_guest`. Write real lines in each voice; Book-17 bar (Rags pre-Vol-5 characterization only; Klbkch never names Hive projects).
- [ ] **Step 3: inn.json rows** — four `kind:npc` entities at four NEW free cells (derive from the map's blocked/decor sets at edit time; spec Phase-2b already spent (2,5)/(3,6) — screenshot-verify). Each: `present_when: {"requires": {<gate>: 1}, "guest": {"npc": "<npc>", "roster": [all ten], "seats": 2}}` where gate = the Task 5.1 counter for rags/wilovan/grimalkin and OMITTED for klbkch (met-gate only, the guest arm handles it). Update roster to all-ten in ALL TEN guest entities (validator).
- [ ] **Step 4: Fixtures:** extend `inn_guests_full_start` to bank the four new met-counters + three quest terminals; re-derive window pins (pool 10, start = 10%10 = 0). Add a gate-proof leg: same fixture minus `rags_meeting_settled` → rags absent across a full rotation cycle.
- [ ] **Step 5:** Run test_inn_guests + test_content + test_dialogue + inn QA scripts; windowed screenshots (wi-machine-playtest) for seat crowding; **commit + PR.**

---

## Phase 6 — Pilgrimage spine `where_the_door_reaches` (PR `wave/mq3-spine`)

New counters: `spine_started`, `lattice_witch_lore`, `lattice_hedault_reading`, `lattice_forge_rune`.
COPY DISCIPLINE (binding, spec §4): reach not objects; discovery in-region; Pisces foreshadows/contextualizes, never assigns.

### Task 6.1: Spine quest + Pisces bookends

**Files:**
- Modify: `data/quests.json`, `data/dialogue/pisces_magic.json`
- Test: test_content, test_dialogue

- [ ] **Step 1: quests.json** append:

```json
{
	"_comment": "2026-07-26 spec 4: discovery-driven spine. Beats complete on lattice counters the REGIONS bank (witch/hedault/forge arms); journal copy points at reach, never objects. Starts from Pisces at door_awakened.",
	"id": "where_the_door_reaches",
	"title": "Where the Door Reaches",
	"beats": [
		{ "id": "riverfarm_reach", "description": "The Door reaches Riverfarm now. See what's out there.", "complete_when": { "lattice_witch_lore": 1 } },
		{ "id": "invrisil_reach", "description": "The Door reaches Invrisil now. A city that size holds people worth knowing.", "complete_when": { "lattice_hedault_reading": 1 } },
		{ "id": "pallass_reach", "description": "The Door reaches Pallass now. The Walled City does not open for just anyone.", "complete_when": { "lattice_forge_rune": 1 } },
		{ "id": "return", "description": "Pisces has been collecting everything you've learned. Hear him out, by the Guild steps.", "complete_when": { "seal_descent_agreed": 1 } }
	]
}
```

- [ ] **Step 2: pisces_magic.json** — attune-completion surface (wherever `door_awakened` banks) gains effects `[{"quest": "where_the_door_reaches"}, {"accomplishment": "spine_started"}]` + foreshadow line: "The Door will show you how far it wants to go. And somewhere under this city is wardwork by the same hand, still fed, still waiting. I intend to understand both. Go — see where it reaches." Add three reaction nodes (one per lattice counter, `text_variants` on his hub keyed to each) contextualizing after each discovery — e.g. witch: "Ward-lore from a hedge witch. Do not make that face — hers is older than the Guild's and she FED hers too. That word keeps recurring."
- [ ] **Step 3:** Tests; **commit** `feat(quests): the pilgrimage spine, reach-not-fetch`.

### Task 6.2: Three capstone arms

**Files:**
- Modify: `data/dialogue/riverfarm_witch.json` (beside its `invrisil_attuned` bank, :233-244), `data/dialogue/hedault_enchanting.json`, `data/dialogue/pallass_forge_clerk.json` (or pallass_grimalkin.json — read both, pick the forge-rune-natural surface)
- Test: test_dialogue, test_content

- [ ] **Step 1: Witch arm** (gated on her chain's terminal + `spine_started`, hide_when `lattice_witch_lore`): she raises it herself — "Your door smells of a feeding ward. I keep one myself — smaller. Sit. If you're going to live over one, you'll learn what it eats." → banks `lattice_witch_lore`. Revisit-reachable (not chain-tail) — spec §8.
- [ ] **Step 2: Hedault arm** (gated `brothers_job_done` + `spine_started`, hide `lattice_hedault_reading`): he notices the door's craft from the player's enchanting business — banks `lattice_hedault_reading`.
- [ ] **Step 3: Forge arm** (gated `elevator_pass_stamped` + `spine_started`, hide `lattice_forge_rune`): forge-tier rune work surfaces the feeding principle — banks `lattice_forge_rune`.
- [ ] **Step 4:** Every arm: NPC raises the topic; player never asks for a component. Tests; **commit.**

### Task 6.3: Phase gate

- [ ] wi-verifying-changes gate set + machine playtest of the full spine; PR.

## Phase 7 — Act V (PR `wave/mq4-act5`)

Execute docs/design/2026-07-20-door-continuation-spec.md beats 1–3 + Act V, AS AMENDED by main-quest spec §7: no "second door" language anywhere (re-copy every `heard_pisces_second_door` surface; keep the frozen id); counter `seal_descent_agreed` (not `second_door_descent_agreed`); descent ask fires when `lattice_forge_rune` banks (Beat 1's gate becomes the spine's `return` beat completing). New map `data/maps/dungeon/seal_vault.json` (small, wi-adding-a-scene validators); warden = roster-only retint of ruin_warden rig (combatants.json contract: distinct id per context, :401 comment); 0.55–0.95 harness cell mandatory. acts.json gains act_v ("What the Seal Was Feeding") advancing on `seal_resolved`; act_iv advance_when updates to `{lattice_forge_rune: 1, seal_kept_reported: 1}`. All three paths bank `seal_resolved` + path counter (`seal_opened` / `seal_kept_fed` / `seal_rewarded`).

- [ ] **Task 7.1:** Beat 1 descent ask (Pisces `seal_descent_agreed`, quest `what_the_seal_was_feeding` per #270 shape).
- [ ] **Task 7.2:** Beat 2 reading (`skill_uses` arms on seal_kept_door; `read_the_seal_runes` / `read_the_feeding_ward`; `detected_wardwork >= 3` text_variant).
- [ ] **Task 7.3:** Beat 3 three paths + seal_vault map + warden encounter + rewards per #270 (FIGHT/TALK/SKILL exactly as specced).
- [ ] **Task 7.4:** acts.json act_v + act_iv advance update + test_acts pins.
- [ ] **Task 7.5:** Harness cell (sim_combat_batch) + QA + machine playtest; PR.

## Phase 8 — Finale sequence, epilogue retired (PR `wave/mq5-finale`)

### Task 8.1: sleep_veil rework

**Files:**
- Modify: `src/ui/sleep_veil.gd` (:57-68 constants, :181-193 arming, :273-296 epilogue)
- Test: `res://tests/test_sleep_veil.gd`

- [ ] **Step 1:** Arm on `seal_resolved` (not `raskghar_sealed`); delete the raskghar arm; `play_epilogue` gate flips from `post_game` to a new one-shot counter `finale_played` (post_game banks mid-story now — Task 1.2 — and can no longer guard the finale).
- [ ] **Step 2:** Replace `_epilogue_lines()`: open lines kept ("[When you came to Liscor, there was nothing to record.] [This is no longer true.]"), then class recount (existing loop), then region recap — three lines emitted only if their counter banked: `lattice_witch_lore` → "[Riverfarm keeps a witch who taught you what a ward eats.]"; `lattice_hedault_reading` → "[Invrisil keeps an enchanter who called your Door 'competent work'. From him, that is a parade.]"; `lattice_forge_rune` → "[Pallass stamped your name into a forge tier's ledger.]" — then ONE path close: `seal_opened` → "[You opened what was fed. The record does not flinch.]"; `seal_kept_fed` → "[You chose to keep feeding it. Some seals are promises.]"; `seal_rewarded` → "[You re-cut the ward with your own hands. It will hold longer than the city.]" — then EPILOGUE_LINK_LINE unchanged.
- [ ] **Step 3:** `_bank_post_game()` → banks `finale_played` instead (post_game untouched here since Task 1.2 owns it). raskghar_sealed keeps its light transition via the normal sleep-beat toast (already shipped GDI seal line — verify, don't duplicate).
- [ ] **Step 4:** Re-pin test_sleep_veil + QA canonicals to the new trigger; run; **commit + PR.** New counter: `finale_played`.

## Phase 9 — Difficulty bands + harness (PR `wave/mq6-bands`)

- [ ] **Task 9.1:** Derive current expected class-levels at each main-line milestone from `tests/sim_progression_pace.gd` runs (challenge-weighted #211 flag-on). Record the table in the PR body.
- [ ] **Task 9.2:** Retune region encounter stats (combatants.json overrides per arena) so Riverfarm < Invrisil < Pallass < seal-warden, one band apart; load `wi-adding-an-encounter` for every stat touch.
- [ ] **Task 9.3:** Add/refresh 0.55–0.95 winrate cells (sim_combat_batch) per stop at expected level; re-derive pinned rng_state in every touched fixture via `tests/_derive_rng_state.gd`.
- [ ] **Task 9.4:** Full QA sweep + machine playtest of the whole main line start→finale; VISUAL-LOG drain; PR.

---

## Wave close

- [ ] Release-freeze step-0 when tagging (ROADMAP discipline): bump RELEASE in generate_shipped_ids.py, regen, grep new `record_accomplishment` literals against STRUCTURAL_LITERALS in BOTH lists. All new counters this wave: `horns_dig_started, horns_dig_joined, pedestal_breached, door_retrieved, door_mounted, spine_started, lattice_witch_lore, lattice_hedault_reading, lattice_forge_rune, seal_descent_agreed, read_the_seal_runes, read_the_feeding_ward, seal_opened, seal_kept_fed, seal_rewarded, seal_resolved, chatted_with_rags, chatted_with_grimalkin, finale_played` (+ Phase 7's `pallass_return_carved` only if the B-side ships).
- [ ] Update docs/ROADMAP.md (v0.14 = this wave) + HANDOFF.md continuously (user directive).
- [ ] Title ACKs already given: "The Dig", "Where the Door Reaches".
