# M4 — Playtest Fixes + Asset Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every 2026-07-02 human-playtest directive (dialogue gating, cleaning-quest rewire, hubs, defeat QA, discoverability, greying, paced AI turns, overlap) and put real Pixel Crawler art on screen (tiles + sprites) inside the data→codegen architecture.

**Architecture:** Sim core stays pure and untouched except `WIDialogue`/`WIGame` dialogue-flow changes (Phase A). All rendering changes live in the presentation layer (`world.gd`, `combat_screen.gd`, new `sprite_registry.gd`) driven by the same bus events. Art is data: `data/sprites.json` + `data/biomes.json` catalogs, `sprite` fields on entities/combatants, curated PNG extracts committed under `wandering_inn_game_v4/assets/`.

**Tech Stack:** Godot 4.7 (`/usr/local/bin/godot`), GDScript (tabs, static typing), SceneTree unit tests, declarative QA scripts via `qa/run_qa.sh`.

**Spec:** `docs/superpowers/specs/2026-07-02-wandering-inn-m4-playtest-and-art-design.md` (read it first; [D] register + parked items live there).

## Global Constraints

- **Never show raw STR/DEX/INT etc. anywhere player-facing.** HP/damage numbers ARE allowed (M2 decision).
- Work directly on `main`. Commit per task. Keep `HANDOFF.md` live.
- Sim purity: nothing under `src/core/` may reference autoloads/Nodes/scene tree. `sprite`/tile data passes THROUGH the sim as inert config; only presentation reads it.
- Zero warnings tolerated: `/usr/local/bin/godot --headless --path wandering_inn_game_v4 --quit` must stay clean; run `--import` after creating any `.gd`; commit `*.uid` sidecars.
- After ANY change: run the QA scripts named in the task, plus `load_gate`. Canonical seeds: `combat_walkthrough`/`mage_unlock_loop`/`line_of_sight_denial`/dialogue+quest+save scripts = 9, `level_up_loop` = 11. No task here changes combat rules/data, so seeds must still hold — treat drift as a bug in your change.
- QA scripts drive dialogue by VISIBLE option index (hidden options shift indices). Task 1 changes visibility rules — every dialogue-driving script must be re-walked.
- GDQuest style: `class_name` + `##` doc comments; match surrounding idiom. Check `godot-prompter:*` skills (dialogue-system, godot-ui, 2d-essentials, tween-animation) before implementing that system.
- `potential_assets/` is gitignored and must stay so. Curated extracts under `wandering_inn_game_v4/assets/` ARE committed (Terms.txt permits functional use in games; never commit the packs wholesale).
- macOS: no `timeout` command; zsh does not word-split unquoted vars — pass QA args explicitly.

## File Structure (who owns what)

```
wandering_inn_game_v4/
  src/core/dialogue.gd        # T1: choose/advance split, set_ctx, gating split
  src/core/wi_game.gd         # T1: dialogue_choose refresh; _build_dialogue_ctx extraction
  src/ui/message_layer.gd     # T4: persistent footer hint
  src/core/game.gd            # T4: first-autosave toast
  src/combat/combat_screen.gd # T5 greying; T6 CELL=64; T9 PC sprite + cast flashes; T10 paced playback
  src/world/world.gd          # T7 tile floor; T8 entity sprites
  src/world/sprite_registry.gd# T6 (new): sprites.json -> SpriteFrames cache
  qa/test_driver.gd           # T10: active() helper
  data/dialogue/*.json        # T2, T3: content edits
  data/sprites.json           # T6 (new)
  data/biomes.json            # T7 (new)
  data/skeleton_scene.json    # T7 biome tags; T8 sprite/tint fields
  data/arenas.json            # T7 biome tags
  data/combatants.json        # T9 sprite field (pc only)
  assets/sprites/**, assets/tiles/**  # T6 (new, committed PNGs)
  tools/sync_assets.py        # T6 (new): curated copy from potential_assets
  qa/scripts/dialogue_hub_loop.json   # T3 (new)
  qa/scripts/defeat_reload.json       # T4 (new)
  tests/test_dialogue.gd      # T1 additions
  project.godot               # T6: viewport 1024x640
```

Phases must land in order (A: T1–T5, B: T6–T9, C: T10–T11); tasks within a phase are sequential too (T2/T3 depend on T1; T7–T9 on T6; T11 on everything).

---

### Task 1: Dialogue gating split + per-node ctx refresh

Playtest findings 3 + 9 (engine half). Two behavior changes in the pure core:
1. Unmet `accomplishment`-keyed `requires` **hides** the option (progress gates must not leak); unmet `skill`/`class` requires stay **visible-locked** (the tease is deliberate).
2. ctx refreshes on every node advance, so effects applied mid-conversation affect gating in the same conversation (kills the documented staleness; prerequisite for hubs).

**Files:**
- Modify: `wandering_inn_game_v4/src/core/dialogue.gd`
- Modify: `wandering_inn_game_v4/src/core/wi_game.gd` (`start_dialogue`, `dialogue_choose`)
- Test: `wandering_inn_game_v4/tests/test_dialogue.gd`

**Interfaces:**
- Consumes: existing `WIDialogue._init(graph, ctx, event_sink)`, `_meets(req)`, `_visible_options()`.
- Produces: `WIDialogue.choose(index) -> Dictionary` now returns `{effects, ended, next}` and does NOT advance; new `WIDialogue.advance(next_id: String) -> void` enters the node; new `WIDialogue.set_ctx(ctx: Dictionary) -> void`. `WIGame` gains `_build_dialogue_ctx() -> Dictionary`. T2/T3 content and the dialogue panel rely on: hidden = unmet accomplishment-requires OR met hide_when.

- [ ] **Step 1: Write failing tests** — append to `tests/test_dialogue.gd` (match its existing harness conventions — read the file first; it is a SceneTree script with its own assert helpers):

```gdscript
func test_accomplishment_requires_hides_until_met() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "secret", "requires": {"accomplishment": {"deed": 1}}, "end": true},
		{"text": "always", "end": true},
	]}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}}, Callable())
	d.begin()
	assert_eq(d.current_options().size(), 1, "accomplishment-gated option hidden when unmet")
	assert_eq(String(d.current_options()[0]["text"]), "always", "only the ungated option shows")
	var d2 := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {"deed": 1}, "names": {}}, Callable())
	d2.begin()
	assert_eq(d2.current_options().size(), 2, "accomplishment-gated option visible once met")

func test_skill_and_class_requires_stay_visible_locked() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "skillful", "requires": {"skill": "basic_cleaning"}, "end": true},
		{"text": "classy", "requires": {"class": {"fighter": 2}}, "end": true},
		{"text": "leave", "end": true},
	]}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {"fighter": 1}, "accomplishments": {}, "names": {}}, Callable())
	d.begin()
	assert_eq(d.current_options().size(), 3, "skill/class gates remain visible")
	assert_true(bool(d.current_options()[0]["locked"]), "unmet skill gate locked")
	assert_true(bool(d.current_options()[1]["locked"]), "unmet class gate locked")

func test_ctx_refresh_regates_mid_conversation() -> void:
	# Full-loop through WIGame: choosing an option whose effect grants an
	# accomplishment must make an accomplishment-gated option visible when the
	# SAME conversation loops back to the hub (goto), without restarting it.
	var graph := {"start": "hub", "nodes": {
		"hub": {"speaker": "S", "text": "t", "options": [
			{"text": "do deed", "hide_when": {"accomplishment": {"deed": 1}}, "effects": [{"accomplishment": "deed"}], "goto": "mid"},
			{"text": "report deed", "requires": {"accomplishment": {"deed": 1}}, "end": true},
			{"text": "leave", "end": true},
		]},
		"mid": {"speaker": "S", "text": "done", "options": [{"text": "back", "goto": "hub"}]},
	}}
	var game := _make_game_with_dialogue(graph)  # helper: build WIGame whose combat_config.dialogue = {"test_conv": graph}; see existing tests for the minimal scene/skill config shape
	game.start_dialogue("test_conv", "npc_x")
	assert_eq(game.dialogue.current_options().size(), 2, "report hidden, do-deed + leave visible")
	game.dialogue_choose(0)   # do deed -> grants accomplishment, goto mid
	game.dialogue_choose(0)   # back -> hub
	var texts: Array = []
	for o: Dictionary in game.dialogue.current_options():
		texts.append(String(o["text"]))
	assert_true(texts.has("report deed"), "refresh made accomplishment-gated option visible mid-conversation")
	assert_false(texts.has("do deed"), "hide_when now hides the consumed option")
```

- [ ] **Step 2: Run to verify failure:** `/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_dialogue.gd` — expect the three new tests FAIL (and note exactly how: sizes off by the grey rows / stale ctx).

- [ ] **Step 3: Implement `dialogue.gd`.** Complete new/changed members (rest of file unchanged):

```gdscript
## True when this requires-dict gates on player PROGRESS (accomplishments):
## progress-gated options are HIDDEN until met (playtest policy, M4), while
## skill/class gates stay visible-locked as a deliberate tease.
func _progress_gated(req: Dictionary) -> bool:
	return req.has("accomplishment")


func _visible_options() -> Array:
	var out: Array = []
	var options: Array = _node().get("options", [])
	for authored_index: int in options.size():
		var opt: Dictionary = options[authored_index]
		var hide_when: Dictionary = opt.get("hide_when", {})
		if not hide_when.is_empty() and _meets(hide_when):
			continue
		var req: Dictionary = opt.get("requires", {})
		if _progress_gated(req) and not _meets(req):
			continue
		out.append({"authored_index": authored_index, "option": opt})
	return out


## Re-injects a fresh context snapshot. Called by the owner (WIGame) after
## applying a chosen option's effects so the NEXT node's gating sees them.
func set_ctx(ctx: Dictionary) -> void:
	_ctx = ctx


## Resolves the chosen visible option WITHOUT advancing: returns
## {effects, ended, next}. The owner applies effects, refreshes ctx
## (set_ctx), then calls advance(next) — that ordering is the whole point.
func choose(index: int) -> Dictionary:
	if finished:
		return {}
	var visible: Array = _visible_options()
	if index < 0 or index >= visible.size():
		return {}
	var opt: Dictionary = visible[index]["option"]
	if not _meets(opt.get("requires", {})):
		return {}
	var effects: Array = (opt.get("effects", []) as Array).duplicate(true)
	var ended := bool(opt.get("end", false))
	if ended:
		finished = true
		_emit("dialogue_ended", {})
	return {"effects": effects, "ended": ended, "next": "" if ended else String(opt["goto"])}


## Enters the node a choose() result pointed at. No-op once finished.
func advance(next_id: String) -> void:
	if finished or next_id.is_empty():
		return
	_enter(next_id)
```

- [ ] **Step 4: Implement `wi_game.gd`.** Extract ctx building; rewire `dialogue_choose` to the apply-effects → refresh → advance order. Replace the body of `start_dialogue`'s ctx block and `dialogue_choose` entirely:

```gdscript
## Snapshot of everything dialogue gating can see. Rebuilt per node advance
## (M4): effects applied mid-conversation re-gate the same conversation.
func _build_dialogue_ctx() -> Dictionary:
	var names: Dictionary = {}
	for sk_id: String in skills:
		names[sk_id] = String(skills[sk_id].get("display_name", sk_id))
	if not _combat_config.is_empty() and _combat_config.has("classes"):
		for cls: Dictionary in _combat_config["classes"]["classes"]:
			names[String(cls["id"])] = String(cls["display_name"])
	return {"skills": known_skills(), "classes": classes.duplicate(true), "accomplishments": accomplishments.duplicate(true), "names": names}


func start_dialogue(conversation_id: String, source_entity_id: String) -> bool:
	if dialogue != null or combat != null:
		return false
	var graphs: Dictionary = _combat_config.get("dialogue", {})
	if not graphs.has(conversation_id):
		return false
	_emit("dialogue_started", {"conversation": conversation_id, "entity": source_entity_id})
	dialogue = WIDialogue.new(graphs[conversation_id], _build_dialogue_ctx(), _event_sink)
	dialogue.begin()
	return true


## Applies the selected option's effects, refreshes the dialogue ctx, then
## advances — so the next node's gating sees this choice's effects (M4).
## start_combat effects still only fire on conversation-ending options.
func dialogue_choose(index: int) -> bool:
	if dialogue == null:
		return false
	var result: Dictionary = dialogue.choose(index)
	if result.is_empty():
		return false
	_emit("dialogue_choice", {"index": index})
	var walker := dialogue
	if bool(result["ended"]):
		dialogue = null
	var pending_combat := ""
	for effect: Dictionary in result["effects"]:
		if effect.has("accomplishment"):
			record_accomplishment(String(effect["accomplishment"]))
		elif effect.has("quest"):
			start_quest(String(effect["quest"]))
		elif effect.has("remove_entity"):
			remove_entity(String(effect["remove_entity"]))
		elif effect.has("start_combat"):
			pending_combat = String(effect["start_combat"])
	if not bool(result["ended"]):
		walker.set_ctx(_build_dialogue_ctx())
		walker.advance(String(result["next"]))
	if pending_combat != "":
		if not start_combat(pending_combat):
			_emit("dialogue_effect_failed", {"effect": "start_combat", "id": pending_combat})
	return true
```

Also update the two stale `##` doc comments referencing "snapshot taken here; effects applied mid-conversation do NOT refresh" (start_dialogue) — the M2 staleness caveat is now false.

- [ ] **Step 5: Run tests:** all of `test_dialogue.gd` passes; then the full unit sweep (all `tests/test_*.gd` individually) — `test_content.gd` may enforce graph invariants, keep it green.

- [ ] **Step 6: Re-walk EVERY dialogue-driving QA script.** The split hides previously-grey rows (Erin hub options 3/4 pre-epilogue; Selys hub rows 1/3 pre-delivery), shifting visible indices. Run:
`wandering_inn_game_v4/qa/run_qa.sh dialogue_walkthrough headless --seed=9`, same for `quest_errand_fight`, `quest_errand_parley`, `save_load_roundtrip`, `inn_walkthrough`, then `load_gate`. Fix any navigation drift in the SCRIPTS (movement/`move_down` counts), never by weakening assertions. Expected: all PASS.

- [ ] **Step 7: Commit** `feat(m4-t1): dialogue gating split (progress gates hide) + per-node ctx refresh`

---

### Task 2: [Basic Cleaning] flows through the Dirty Table prop

Playtest finding 2 (user directive). The prop interaction path ALREADY grants `cleaned_the_inn` (`dirty_table.requires_skill` + `on_skill_use` in `skeleton_scene.json` → `WIGame.use_skill`). The bug is purely that Erin's dialogue option grants it inline too. Data-only fix.

**Files:**
- Modify: `wandering_inn_game_v4/data/dialogue/erin_errand.json`
- Modify: `wandering_inn_game_v4/qa/scripts/dialogue_walkthrough.json` (or the errand scripts if they touch cleaning)

**Interfaces:**
- Consumes: T1's hidden-progress-gate rule (`requires {accomplishment: cleaned_the_inn}` row invisible until the deed).
- Produces: accomplishments `cleaned_the_inn` (prop-only now) and `reported_cleaning` (new, Erin's congratulation); T3's hub loop-backs assume these node ids: `cleaning_directions`, `cleaned`.

- [ ] **Step 1: Rewrite Erin's hub cleaning options.** In `erin_errand.json`, replace hub option 2 (the current inline-grant) with a *direction* option, and add a *report* option:

```json
{
  "text": "Let me deal with that table. ([Basic Cleaning])",
  "requires": {"skill": "basic_cleaning"},
  "hide_when": {"accomplishment": {"cleaned_the_inn": 1}},
  "goto": "cleaning_directions"
},
{
  "text": "The table situation is handled.",
  "requires": {"accomplishment": {"cleaned_the_inn": 1}},
  "hide_when": {"accomplishment": {"reported_cleaning": 1}},
  "effects": [{"accomplishment": "reported_cleaning"}],
  "goto": "cleaned"
}
```

Add the new node (keep the existing `cleaned` node exactly as is):

```json
"cleaning_directions": {
  "speaker": "Erin",
  "text": "Really? It's the horror show by the south wall. I owe you one - or the table does.",
  "options": [{"text": "On it.", "end": true}]
}
```

- [ ] **Step 2: Extend QA.** In `dialogue_walkthrough.json` (read it first; extend where it visits Erin): choose the cleaning option → `wait_for_event dialogue_node` → close dialogue → walk to the dirty table (inn cell [5,4]; player must stand adjacent facing it) → `press interact` → `wait_for_event skill_used {"skill": "basic_cleaning"}` → `wait_for_event accomplishment_recorded {"id": "cleaned_the_inn"}` → `wait_for_event ui_toast_rendered` → return to Erin → choose the report option → `wait_for_event accomplishment_recorded {"id": "reported_cleaning"}`. Also add `{"action": "assert_event_absent", "type": "accomplishment_recorded", "payload_contains": {"id": "cleaned_the_inn", "count": 2}}` — the accomplishment must be granted exactly once (dialogue no longer grants it).

- [ ] **Step 3: Run:** `dialogue_walkthrough` seed 9 PASS; `quest_errand_fight`/`quest_errand_parley` seed 9 still PASS; `load_gate` PASS.

- [ ] **Step 4: Commit** `fix(m4-t2): [Basic Cleaning] granted by the Dirty Table prop, not Erin's dialogue`

---

### Task 3: hide_when sweep + conversation hubs

Playtest findings 4 + 9 (content half). Make committed decisions disappear and conversations loop back.

**Files:**
- Modify: `wandering_inn_game_v4/data/dialogue/erin_errand.json`, `selys_delivery.json`, `lyonette_tip.json`
- Create: `wandering_inn_game_v4/qa/scripts/dialogue_hub_loop.json`
- Modify: `wandering_inn_game_v4/qa/run_qa.sh` only if scripts are enumerated there (read it; likely path-generic)

**Interfaces:**
- Consumes: T1 ctx refresh (hub re-entry re-gates), T2 node ids.
- Produces: the errand content graph final for M4; QA script name `dialogue_hub_loop` (canonical seed 9).

- [ ] **Step 1: Author loop-backs.** Every non-epilogue leaf node whose only option is `end: true` gains a second option `{"text": "Actually - one more thing.", "goto": "hub"}` ahead of the end option. Apply to: `erin_errand` nodes `package`, `cleaned`, `cleaning_directions`; `selys_delivery` nodes `delivered`, `delivered_smooth` (CAREFUL: in Selys's two delivered nodes the loop-back must sit AFTER the keep/return decision options, and those two decision options each also need `"hide_when": {"accomplishment": {"errand_decided": 1}}` so looping back in and revisiting `delivered` after deciding can't double-decide — that's exactly finding 4); `lyonette_tip` node `tip`. Do NOT touch `goblin_parley` (it's a tension scene, not a chat) or the two `epilogue_*` nodes (one-shot payoffs).
- [ ] **Step 2: Decision-invalidation sweep.** Audit every option across the three graphs: any option whose *meaning* is invalidated by a recorded decision gets a `hide_when` on the deciding accomplishment. Known concrete cases: Selys's `About that reward...` already has it; the keep/return pairs per Step 1; Erin's hub package option already covered by `has_package`. Verify each with the graph in front of you rather than assuming this list is complete.
- [ ] **Step 3: New QA script** `qa/scripts/dialogue_hub_loop.json` (seed 9): walk to Erin → take package (goto `package` node) → choose "Actually - one more thing." → `wait_for_event dialogue_node` and `assert` we're back at the hub (assert on the hub's text via `payload_contains` `{"speaker": "Erin"}` plus a subsequent options-count `assert_state` is not possible — instead `wait_for_event dialogue_node {"text": "Oh good, someone with working legs! ..."}` matching the hub text verbatim) → confirm the package option is GONE on re-entry (script: the hub's visible option count drops — assert by choosing what is now the first option and watching which node it lands in, or add `assert_event_absent` for a second `quest_started`). Then Esc-free path: end the conversation, sleep is NOT needed. Also cover Selys: street → deliver → decide keep → loop back → assert the decision pair no longer renders (choose index 0 on the re-entered node and assert it does NOT emit a second `errand_decided`; add `{"action": "assert_event_absent", "type": "accomplishment_recorded", "payload_contains": {"id": "errand_decided", "count": 2}}` at the end).
- [ ] **Step 4: Run** `dialogue_hub_loop` seed 9 → PASS; re-run all four pre-existing dialogue/quest scripts + `save_load_roundtrip` (dialogue graphs serialize? they don't — but the walkthrough scripts traverse them) → PASS; `load_gate` → PASS.
- [ ] **Step 5: Update** `wandering_inn_game_v4/CLAUDE.md` seed table with `dialogue_hub_loop | 9`.
- [ ] **Step 6: Commit** `feat(m4-t3): conversation hubs + decision-invalidated options disappear`

---

### Task 4: defeat_reload QA script + save/load discoverability

Playtest findings 1 (regression guard for hotfix `a9b4dc2`) + 8.

**Files:**
- Create: `wandering_inn_game_v4/qa/scripts/defeat_reload.json`
- Modify: `wandering_inn_game_v4/src/ui/message_layer.gd` (footer hint)
- Modify: `wandering_inn_game_v4/src/core/game.gd` (first-autosave toast)

**Interfaces:**
- Consumes: defeat path `combat_finished{victory:false}` → banner → confirm → `Game.load_slot("auto")` → `game_loaded`; autosave fires on `map_changed`.
- Produces: bus event `ui_hint_rendered {text}` (T11's layout audit includes the hint); QA script `defeat_reload` with its own pinned seed.

- [ ] **Step 1: Write `defeat_reload.json`.** Flow (fighter-only PC — do NOT read the scroll): wait `world_ready` → walk inn → exit to street (`map_changed {"map": "street"}` fires the autosave) → `assert_save_exists auto` → walk from street entry [1,3] to the `chieftains_raid` encounter at [2,0] (up 3, then face it) → `press interact` → `wait_for_event combat_started` → `combat_autoplay` → `wait_for_event combat_finished {"victory": false}` → `press confirm` → `wait_for_event game_loaded` → `assert_state current_map = "street"` → `assert_state accomplishments.won_combat` equals its pre-fight value (0 for a fresh run — assert path missing is a fail, so instead assert `removed_entities` does NOT contain the encounter: `{"action": "assert_state", "path": "removed_entities", "equals": []}`) → `assert_event_absent game_reset` (the hotfix's whole point: reload, not reset).
- [ ] **Step 2: Find the losing seed.** Win rate is 0.61, so ~4 in 10 seeds lose. Run `for s in 1 2 3 4 5 6 7 8 9 10 11 12; do wandering_inn_game_v4/qa/run_qa.sh defeat_reload headless --seed=$s && echo "LOSING_SEED=$s" && break; done` (a seed where the script PASSES is a losing fight — the script asserts defeat). Pin the first passing seed in the script's doc comment, `wandering_inn_game_v4/CLAUDE.md` seed table, and the Commands block.
- [ ] **Step 3: Footer hint.** In `message_layer.gd _ready()`, after the dialogue panel setup, add a persistent bottom-left hint label + emit confirmation:

```gdscript
	_hint_label = Label.new()
	_hint_label.text = "Esc — menu (save/load)   J — journal"
	_hint_label.position = Vector2(8, 382)
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", Color(0.25, 0.22, 0.18))
	root.add_child(_hint_label)
	ObservableBus.emit_domain_event.call_deferred("ui_hint_rendered", {"text": _hint_label.text})
```

(declare `var _hint_label: Label` with the other vars). Hide it during combat: in `_on_domain_event`, `"combat_started": _hint_label.hide()` / `"ui_combat_hidden": _hint_label.show()`. NOTE: position 382 assumes the 640×400 viewport; T6 bumps the viewport and T11 re-anchors this with proper anchors — leave a `# repositioned in T11` comment.
- [ ] **Step 4: First-autosave toast.** In `game.gd`: add `var _autosave_announced := false`; in `save_auto()` after `_write_slot("auto")`:

```gdscript
	if not _autosave_announced:
		_autosave_announced = true
		ObservableBus.emit_domain_event("toast", {"text": "Autosaved. (Esc — save/load anytime)"})
```

- [ ] **Step 5: QA.** Extend `inn_walkthrough.json` with `{"action": "assert_event_logged", "type": "ui_hint_rendered"}`; run `inn_walkthrough`, `save_load_roundtrip` seed 9, `defeat_reload` at its pinned seed, `combat_walkthrough` seed 9, `load_gate` → all PASS. Headless smoke clean.
- [ ] **Step 6: Commit** `feat(m4-t4): defeat_reload QA guard + save/load discoverability hint`

---

### Task 5: Complete combat affordability greying

Playtest finding 6. Attack and Move rows must grey (and refuse confirm) when unaffordable, matching Dash/skill behavior.

**Files:**
- Modify: `wandering_inn_game_v4/src/combat/combat_screen.gd` (`_menu_text` MENU branch, `_input_menu`)

**Interfaces:**
- Consumes: `WICombat.ATTACK_COST`, active combatant `ap`/`move_pool`; existing `_grey()`.
- Produces: helper `_menu_row_affordable(item: String, c: Dictionary) -> bool` (T10 reuses it when rebuilding the menu after playback).

- [ ] **Step 1: Add the helper** (near `_skill_affordable`):

```gdscript
## Whether a main-menu row is currently actionable — mirrors the gates the
## sim would enforce, purely for greying + confirm-refusal (playtest: Attack
## and Move must grey like Dash/skills already do).
func _menu_row_affordable(item: String, c: Dictionary) -> bool:
	match item:
		"Attack":
			return int(c["ap"]) >= WICombat.ATTACK_COST
		"Dash":
			return int(c["ap"]) >= WICombat.DASH_COST
		"Move":
			return int(c["move_pool"]) > 0 or int(c["ap"]) >= WICombat.DASH_COST
		_:
			return true
```

- [ ] **Step 2: Use it in `_menu_text` MENU branch** — replace the Dash-only special case:

```gdscript
				var line_text := ("> " if i == _menu_index else "  ") + item + suffix
				if not _menu_row_affordable(item, c):
					line_text = _grey(line_text)
				lines.append(line_text)
```

- [ ] **Step 3: Refuse confirm on greyed rows** in `_input_menu` — wrap the `match` on confirm:

```gdscript
		elif event.is_action_pressed("confirm"):
			if not _menu_row_affordable(String(_menu_items[_menu_index]), _active_combatant()):
				get_viewport().set_input_as_handled()
				_refresh()
				return
			match String(_menu_items[_menu_index]):
```

(then remove Dash's now-redundant inner `if int(c["ap"]) >= WICombat.DASH_COST` guard).
- [ ] **Step 4: Verify.** Autoplay bypasses this UI, so: `combat_walkthrough` seed 9 + `level_up_loop` seed 11 headless (regression only), then ONE windowed run `wandering_inn_game_v4/qa/run_qa.sh combat_walkthrough windowed --seed=9` and read the screenshots: menu renders, no errors. Reviewer checks the greying logic by reading; a human sees it next playtest. Headless smoke clean.
- [ ] **Step 5: Commit** `fix(m4-t5): grey + refuse unaffordable Attack/Move rows`

---

### Task 6: Asset extraction + sprite registry + 64px combat cells + viewport

Phase B plumbing. No gameplay change; everything still renders as squares after this task — but the registry, committed art, cell size, and viewport are in place.

**Files:**
- Create: `wandering_inn_game_v4/tools/sync_assets.py`, `wandering_inn_game_v4/assets/**` (committed PNGs), `wandering_inn_game_v4/data/sprites.json`, `wandering_inn_game_v4/src/world/sprite_registry.gd`
- Modify: `wandering_inn_game_v4/project.godot` (viewport 1024×640), `wandering_inn_game_v4/src/combat/combat_screen.gd` (CELL 48→64 + panel positions), `wandering_inn_game_v4/.gitignore` check (assets/ must NOT be ignored)

**Interfaces:**
- Produces: `class_name WISpriteRegistry` (a Node-free `RefCounted` living in `src/world/` — it uses `ResourceLoader`, so it must NOT live in `src/core/`): `static func frames_for(sprite_id: String) -> SpriteFrames` (cached), `static func has_sprite(sprite_id: String) -> bool`, reading `res://data/sprites.json`. sprites.json schema per entry:

```json
"body_a": {
  "directional": true,
  "animations": {
    "idle": {"sheet_down": "res://assets/sprites/body_a/Idle_Down-Sheet.png", "sheet_side": "...", "sheet_up": "...", "frame_size": [64, 64], "fps": 6},
    "walk": {"sheet_down": "...", "sheet_side": "...", "sheet_up": "...", "frame_size": [64, 64], "fps": 8}
  }
}
```

Directional entries produce SpriteFrames animations named `idle_down`, `idle_side`, `idle_up`, `walk_down`… (side mirrored for left via `flip_h` at the consumer). Non-directional entries use a single `sheet` key and produce plain `idle`/`walk`/`hit`/`death` animations.

- [ ] **Step 1: Curation script.** `tools/sync_assets.py` (stdlib only — no Pillow on this machine): a declarative `MANIFEST: list[tuple[src_rel, dst_rel]]` copying ONLY needed sheets from `potential_assets/` into `wandering_inn_game_v4/assets/`. First VERIFY real paths with `find` (Free Pack **2.1** is canonical; its inner root is `Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/`). Minimum manifest: Body_A `Idle_Base`/`Walk_Base`/`Slice_Base`/`Hit_Base`/`Death_Base` sheets (all facings present per animation); Citizen_F Tavern_A idle+walk sheets; `Environment/Tilesets/Floors_Tiles.png`, `Wall_Tiles.png`; `Environment/Structures/Buildings/Interior/Interior_Props_01.png`; `Environment/Props/Static/Esoteric.png` + `Furniture.png`; Cave pack tileset sheet(s) (find under `Pixel Crawler - Cave/.../Assets/` — verify the actual tileset filename). Copy each pack's `Terms.txt` alongside as `assets/LICENSES/<pack>-Terms.txt`. Run it; commit the PNGs + script.
- [ ] **Step 2: Viewport.** `project.godot`: `window/size/viewport_width=1024`, `viewport_height=640` (stretch mode stays `canvas_items`). This is required: a 12×8 board at 64px (768×512) + menu panel cannot fit 640×400. Every existing absolute UI position keeps working (top-left anchored) but sits high/left — T11 re-lays out; do not chase pixel-perfection here.
- [ ] **Step 3: sprites.json + registry.** Write `data/sprites.json` with `body_a`, `citizen_f` (directional) — combat/prop/tile entries arrive in T7–T9. Implement `sprite_registry.gd`:

```gdscript
class_name WISpriteRegistry
extends RefCounted
## Builds and caches SpriteFrames from the data/sprites.json catalog.
## Presentation-side only (uses ResourceLoader) — never referenced from src/core.

static var _catalog: Dictionary = {}
static var _cache: Dictionary = {}


static func _load_catalog() -> void:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/sprites.json"))
		assert(parsed is Dictionary, "invalid sprites.json")
		_catalog = parsed


static func has_sprite(sprite_id: String) -> bool:
	_load_catalog()
	return _catalog.has(sprite_id)


static func frames_for(sprite_id: String) -> SpriteFrames:
	_load_catalog()
	if _cache.has(sprite_id):
		return _cache[sprite_id]
	var entry: Dictionary = _catalog[sprite_id]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var directional := bool(entry.get("directional", false))
	for anim_name: String in entry["animations"]:
		var anim: Dictionary = entry["animations"][anim_name]
		var facings: Array = ["down", "side", "up"] if directional else [""]
		for facing: String in facings:
			var sheet_key := "sheet_%s" % facing if facing != "" else "sheet"
			var full_name := "%s_%s" % [anim_name, facing] if facing != "" else anim_name
			_add_strip(frames, full_name, String(anim[sheet_key]), Vector2i(int(anim["frame_size"][0]), int(anim["frame_size"][1])), float(anim.get("fps", 6)))
	_cache[sprite_id] = frames
	return frames


static func _add_strip(frames: SpriteFrames, anim_name: String, sheet_path: String, frame_size: Vector2i, fps: float) -> void:
	var tex: Texture2D = load(sheet_path)
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, not (anim_name.begins_with("death") or anim_name.begins_with("hit") or anim_name.begins_with("slice")))
	var count := int(tex.get_width() / frame_size.x)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.add_frame(anim_name, at)
```

Run `--import` after creating the .gd; commit the `.uid`.
- [ ] **Step 4: Smoke-test the registry** with a throwaway SceneTree script (delete after): load `body_a`, assert `frames_for("body_a").has_animation("idle_down")` and frame counts match the sheets (Idle 4, Walk per sheet width). Alternatively add a small permanent `tests/test_sprite_registry.gd` (it CAN run headless — ResourceLoader works in `--script` mode) asserting animation presence + non-zero frames for every catalog entry. Prefer the permanent test; add it to the unit-test list in `wandering_inn_game_v4/CLAUDE.md`.
- [ ] **Step 5: Combat CELL 64.** In `combat_screen.gd`: `CELL := 64`, `ORIGIN := Vector2(32, 24)`; move panels clear of the 768×512 board: `_order_label` → `Vector2(32, 560)`, `_feed_label` → `Vector2(32, 452)` size `Vector2(700, 96)`, `_menu_label` → `Vector2(820, 40)` size `Vector2(190, 320)`, `_banner_label` → `Vector2(392, 280)`. (T11 finalizes; these keep everything non-overlapping meanwhile.)
- [ ] **Step 6: Full verification.** All 11 QA scripts at canonical seeds headless (T4's defeat seed included) → PASS; smoke clean; one windowed `combat_walkthrough` — read screenshots: board fills the window, no clipped panels.
- [ ] **Step 7: Commit** `feat(m4-t6): committed asset extracts, sprite registry, 1024x640 viewport, 64px combat cells`

---

### Task 7: Environment tile codegen (field + arenas)

Replace floor/blocked ColorRects with TileMapLayer cells built from data. Visual floor only — walk/block logic stays sim-side and untouched.

**Files:**
- Create: `wandering_inn_game_v4/data/biomes.json`
- Modify: `wandering_inn_game_v4/data/skeleton_scene.json` (map `biome` tags), `wandering_inn_game_v4/data/arenas.json` (arena `biome` tags), `wandering_inn_game_v4/src/world/world.gd` (`_build_floor`), `wandering_inn_game_v4/src/combat/combat_screen.gd` (`_build_board` floor), `wandering_inn_game_v4/src/world/sprite_registry.gd` (tile helper)

**Interfaces:**
- Consumes: T6 assets + registry.
- Produces: `data/biomes.json` schema `{"inn": {"sheet": "res://assets/tiles/Floors_Tiles.png", "tile_px": 32, "floor": [x, y], "blocked": [x, y]}, "street": {...}, "cave": {...}}` where `floor`/`blocked` are atlas tile coords on the sheet; `WISpriteRegistry.tile_set_for(sheet_path, tile_px) -> TileSet` (cached); bus event `ui_map_rendered {"map": id, "floor_cells": N, "blocked_cells": M}` emitted by world.gd after building, and `ui_arena_rendered {...}` by combat_screen. Sim passes `biome` through untouched (it lives in the same config dicts the sim already stores; presentation reads it via `Game.sim` map/arena config — world.gd reads the raw JSON‑derived dicts it already has access to).

- [ ] **Step 1: Pick tile coords.** Open `Floors_Tiles.png`/`Wall_Tiles.png`/the Cave sheet (windowed run or image viewer via screenshots); choose one solid interior-wood floor tile + wall tile for `inn`, cobble/dirt + barricade for `street`, cave floor + rock for `cave`. Record coords in `data/biomes.json`. There is no automated way to assert "looks right" — the windowed screenshot in Step 5 is the check.
- [ ] **Step 2: Registry tile helper** (append to `sprite_registry.gd`):

```gdscript
static var _tile_sources: Dictionary = {}

## Cached TileSetAtlasSource for a sheet, gridded at tile_px. Each distinct
## sheet gets one TileSet the callers share via source id 0.
static func tile_set_for(sheet_path: String, tile_px: int) -> TileSet:
	var key := "%s@%d" % [sheet_path, tile_px]
	if _tile_sources.has(key):
		return _tile_sources[key]
	var src := TileSetAtlasSource.new()
	src.texture = load(sheet_path)
	src.texture_region_size = Vector2i(tile_px, tile_px)
	var grid := Vector2i(src.texture.get_width() / tile_px, src.texture.get_height() / tile_px)
	for x in grid.x:
		for y in grid.y:
			src.create_tile(Vector2i(x, y))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_px, tile_px)
	ts.add_source(src, 0)
	_tile_sources[key] = ts
	return ts
```

- [ ] **Step 3: world.gd `_build_floor` replacement.** Load `biomes.json` once (`static`/member cache); resolve the current map's `biome` (from the scene config — thread it: `WIGame` already stores `_maps`; ADD a public `map_biome(map_id)`? NO — sim purity says don't grow the sim for presentation. Instead world.gd loads `res://data/skeleton_scene.json` itself once and reads `maps[current_map].biome`). Build:

```gdscript
	var layer := TileMapLayer.new()
	layer.tile_set = WISpriteRegistry.tile_set_for(String(biome["sheet"]), int(biome["tile_px"]))
	layer.scale = Vector2(2, 2)  # 32px tiles at 64px cells
	var floor_coord := Vector2i(int(biome["floor"][0]), int(biome["floor"][1]))
	var blocked_coord := Vector2i(int(biome["blocked"][0]), int(biome["blocked"][1]))
	for x in Game.sim.grid_size.x:
		for y in Game.sim.grid_size.y:
			layer.set_cell(Vector2i(x, y), 0, floor_coord)
	for cell: Vector2i in Game.sim.blocked_cells.keys():
		layer.set_cell(cell, 0, blocked_coord)
	_field_root.add_child(layer)
	ObservableBus.emit_domain_event("ui_map_rendered", {"map": Game.sim.current_map, "floor_cells": Game.sim.grid_size.x * Game.sim.grid_size.y, "blocked_cells": Game.sim.blocked_cells.size()})
```

- [ ] **Step 4: combat_screen.gd `_build_board`** — same pattern for the arena floor + blocked cells (arena `biome` read from `arenas.json` via the combat's arena id — `WICombat` stores the arena dict; check what it exposes (`combat.blocked` exists; if the arena id/biome isn't exposed, read arenas.json in the screen and match by grid+blocked, OR — better — pass the full arena dict through: `WICombat` already received it in `_init`; if it keeps a reference, read `biome` off it; confirm by reading `wi_combat.gd` first). Emit `ui_arena_rendered`.
- [ ] **Step 5: Verify.** `assert_event_logged ui_map_rendered` added to `inn_walkthrough.json`; all QA scripts headless PASS; windowed `inn_walkthrough` + `combat_walkthrough` — READ the screenshots: tiles visible on both maps and in the arena, entities/squares still on top, nothing black. Smoke clean.
- [ ] **Step 6: Commit** `feat(m4-t7): data-driven TileMapLayer floors for maps and arenas`

---

### Task 8: Field entity sprites (PC, NPCs, props)

Replace field ColorRect squares with AnimatedSprite2D where a `sprite` field exists; tint variants differentiate the three female NPCs (no Pillow on this machine — runtime `modulate` tint is the v1 differentiation, refining spec §3.3's palette-swap idea; record as an execution-refined [D] in the ledger).

**Files:**
- Modify: `wandering_inn_game_v4/data/skeleton_scene.json` (entity `sprite` + `tint` fields; player `sprite`), `wandering_inn_game_v4/data/sprites.json` (prop entries), `wandering_inn_game_v4/src/world/world.gd`

**Interfaces:**
- Consumes: T6 registry (`frames_for`, `has_sprite`), T7 tile floor.
- Produces: entity schema fields `"sprite": "<registry id>"`, optional `"tint": [r, g, b]` (0–1 floats); world.gd helper `_make_entity_visual(ent) -> Node2D` used for player + entities; walk/idle/facing behavior for the player sprite.

- [ ] **Step 1: Data.** `skeleton_scene.json`: player gains `"sprite": "body_a"`; `erin`/`lyonette`/`selys` gain `"sprite": "citizen_f"` with tints (Erin none, Lyonette `[0.95, 0.85, 1.0]`, Selys `[0.8, 1.0, 0.9]` — visibly distinct in a screenshot, tune there); props: add `sprites.json` static single-frame entries `dusty_scroll` (Esoteric sheet region), `dirty_table`, `bed`, `door` (Interior_Props/Furniture regions — pick regions by inspecting the sheets, same method as T7 Step 1; static prop entries use a 1-frame `idle` with the region encoded as a `frame_size` + `region` addition: extend the registry `_add_strip` to honor an optional `"region": [x, y, w, h]` that offsets the strip within the sheet). Doors/encounters on the street keep squares if no good sprite fits — an explicit fallback is fine.
- [ ] **Step 2: world.gd rendering.** Replace `_make_square` usage with:

```gdscript
func _make_entity_visual(cell: Vector2i, sprite_id: String, tint: Array, label_text: String) -> Node2D:
	var holder := Node2D.new()
	holder.position = Vector2(cell) * CELL
	if sprite_id != "" and WISpriteRegistry.has_sprite(sprite_id):
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = WISpriteRegistry.frames_for(sprite_id)
		spr.centered = false
		var anim := "idle_down" if spr.sprite_frames.has_animation("idle_down") else "idle"
		spr.play(anim)
		if tint.size() == 3:
			spr.modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]))
		holder.add_child(spr)
	else:
		var rect := ColorRect.new()
		rect.color = PROP_COLOR
		rect.size = Vector2(CELL - 8, CELL - 8)
		rect.position = Vector2(4, 4)
		holder.add_child(rect)
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(-4, -22)
	label.add_theme_color_override("font_color", Color.BLACK)
	holder.add_child(label)
	_field_root.add_child(holder)
	return holder
```

Adapt `_build_entities`/player creation to pass `String(ent.get("sprite", ""))` and `ent.get("tint", [])`; keep `_entity_rects` (rename `_entity_visuals`). Player movement: on `player_moved`, update position AND facing animation — track last dir from the sim (`Game.sim.player_facing`), map to `walk_down/up/side` (+ `flip_h` for left), and flip back to `idle_*` after a short `create_timer(0.18)` — one helper `_play_player_anim(prefix: String)`.
- [ ] **Step 3: Emit render confirmation** `ui_entities_rendered {"sprites": n_sprites, "fallbacks": n_rects}` after `_rebuild_field`; assert it (`sprites` ≥ 4: player + 3 NPCs) in `inn_walkthrough.json`.
- [ ] **Step 4: Verify.** All QA headless PASS; windowed `inn_walkthrough` — read screenshots: PC + Erin/Lyonette/Selys as sprites with visibly different tints, props render, labels legible, no z-fighting with tiles. NOTE the repo gotcha: three NPCs sharing one body reads as clones — the tints must be OBVIOUS in the screenshot, not subtle; iterate values until they are.
- [ ] **Step 5: Commit** `feat(m4-t8): field sprites for PC/NPCs/props with tint differentiation`

---

### Task 9: Combat PC sprite + minimal cast visuals

The PC renders as Body_A in combat (idle/attack/hurt/death); spells get cheap readable flashes. Enemies stay squares (canon sprites PARKED — spec §0).

**Files:**
- Modify: `wandering_inn_game_v4/data/sprites.json` (body_a combat anims), `wandering_inn_game_v4/data/combatants.json` (pc `"sprite": "body_a"`), `wandering_inn_game_v4/src/combat/combat_screen.gd`

**Interfaces:**
- Consumes: T6 registry + CELL 64; sim events `attack_resolved{attacker,target}`, `skill_resolved{actor,skill,cells?}`, `combatant_downed{id}`, existing `_squares` dict.
- Produces: `_squares[id]` may now hold a Node2D wrapper (sprite or rect inside) — `_refresh` and T10's playback use `_visual_for(id)`; cast-flash helper `_flash_cells(cells: Array, color: Color)`.

- [ ] **Step 1: sprites.json** — extend `body_a` with `slice` (attack), `hit`, `death` directional strips from the T6 extracts (verify each facing sheet exists; Slice/Hit/Death ship Down/Side/Up like Idle — confirm with `find`, else use side-only and mirror).
- [ ] **Step 2: combat_screen `_build_board`** — for combatants whose config carries a `sprite` known to the registry, build the same holder pattern as T8 (AnimatedSprite2D, `idle_side` default, name label + HP bar/labels attached to the holder exactly as they attach to squares today); everyone else keeps the ColorRect. Keep `_squares[id]` as the holder Node2D in both cases so `_refresh` positioning code changes minimally (`sq.position = ORIGIN + Vector2(cell) * CELL` — drop the `+ Vector2(3,3)` for sprite holders).
- [ ] **Step 3: Event-driven anims + flashes.** In `_on_domain_event` (pre-T10 this is immediate; T10 will route the same calls through the playback queue): `attack_resolved` → attacker plays `slice_side` (flip toward target by x-compare), target plays `hit_side` (sprite) or a 0.15s white modulate flash (rect); `combatant_downed` → `death_side` or fade rect to 30% alpha; `skill_resolved` for `frost_bolt`/`flame_jet`/spells → `_flash_cells`:

```gdscript
## Cheap cast readability: tween a translucent colored rect over each cell.
func _flash_cells(cells: Array, color: Color) -> void:
	for cell: Vector2i in cells:
		var f := ColorRect.new()
		f.color = Color(color.r, color.g, color.b, 0.55)
		f.position = ORIGIN + Vector2(cell) * CELL
		f.size = Vector2(CELL, CELL)
		_board.add_child(f)
		var tw := create_tween()
		tw.tween_property(f, "modulate:a", 0.0, 0.35)
		tw.tween_callback(f.queue_free)
```

Colors: frost = `Color(0.5, 0.8, 1.0)`, flame = `Color(1.0, 0.45, 0.15)`, shield absorb (`reaction_triggered` mana_shield) = `Color(0.4, 0.6, 1.0)` on the reactor's cell. Line cells: `skill_resolved` payload — read `wi_combat.gd` to see whether hit cells ship in the payload; if not, recompute via `combat.line_cells` for line skills / target cell for bolts. Do NOT modify the sim to add payload fields unless it already emits them.
- [ ] **Step 4: Verify.** All combat QA headless at canonical seeds PASS; windowed `mage_unlock_loop` seed 9 + `combat_walkthrough` seed 9 — read screenshots: PC sprite on the board with HP bar, enemy squares intact, no misaligned labels. (Casts are autoplay-invisible for the PC — the flash code paths for player casts get exercised next human playtest; enemy shaman `flame_bolt` casts DO fire under autoplay and must show.) Smoke clean.
- [ ] **Step 5: Commit** `feat(m4-t9): PC combat sprite + readable cast flashes`

---

### Task 10: Paced AI-turn playback

Playtest finding 5 — the biggest presentation fix. Sim resolves AI turns instantly (unchanged); the combat screen buffers the resulting events and REPLAYS them at a readable pace, highlighting each actor. Skippable; zero-delay under QA.

**Files:**
- Modify: `wandering_inn_game_v4/src/combat/combat_screen.gd`, `wandering_inn_game_v4/qa/test_driver.gd` (+3 lines)

**Interfaces:**
- Consumes: every event type already handled in `_on_domain_event`; T5's `_menu_row_affordable`; T9's anim/flash helpers.
- Produces: `TestDriver.active() -> bool`; playback constants `AI_BEAT_SECONDS := 0.5`; bus event `ui_ai_playback_done {"beats": N}` after each drained queue (QA-visible pacing marker).

- [ ] **Step 1: TestDriver helper** (`qa/test_driver.gd`):

```gdscript
## True when a QA script is driving this run (native --qa-script or web bridge).
func active() -> bool:
	return not _script_path.is_empty()
```

- [ ] **Step 2: Queue + drain in `combat_screen.gd`.** Design (read current `_on_domain_event`/`_on_turn_started`/`_run_ai_turn` carefully before editing — this refactor is the task's risk center):
  - New state: `var _playback: Array = []`, `var _playing := false`, `const AI_BEAT_SECONDS := 0.5`.
  - `func _beat_delay() -> float:` returns `0.0` when `TestDriver.active()` or `DisplayServer.get_name() == "headless"`, else `AI_BEAT_SECONDS`.
  - In `_on_domain_event`: while `_mode == Mode.WAIT_AI` (i.e. AI acting), visual event types (`combatant_moved, ap_changed, combatant_downed, attack_resolved, skill_resolved, reaction_triggered, dashed, status_applied, status_expired, action_refused`) are APPENDED to `_playback` instead of applied; `turn_started` and `combat_finished` are also appended as terminal markers instead of switching mode immediately. When not in WAIT_AI (player acting), behavior is unchanged (immediate).
  - After `_run_ai_turn()` finishes (`WICombatAI.take_turn` returned — all events are queued), call `_drain_playback()`:

```gdscript
func _drain_playback() -> void:
	if _playing:
		return
	_playing = true
	var beats := 0
	while not _playback.is_empty():
		var e: Dictionary = _playback.pop_front()
		var etype := String(e["type"])
		match etype:
			"turn_started":
				_apply_turn_started(String(e["payload"]["id"]))
			"combat_finished":
				_mode = Mode.BANNER
				_banner_label.text = ("Victory! — Enter" if bool(e["payload"]["victory"]) else "Defeat… — Enter")
				_refresh()
			_:
				_highlight_actor(e)
				_push_feed(etype, e["payload"])
				_play_event_visual(etype, e["payload"])   # T9 anims/flashes routed here
				_refresh()
		beats += 1
		var delay := _beat_delay()
		if delay > 0.0 and not _playback.is_empty():
			await get_tree().create_timer(delay).timeout
			if _skip_requested:
				_skip_requested = false
				# finish the rest instantly
				while not _playback.is_empty():
					var rest: Dictionary = _playback.pop_front()
					var rtype := String(rest["type"])
					if rtype == "turn_started":
						_apply_turn_started(String(rest["payload"]["id"]))
					elif rtype == "combat_finished":
						_mode = Mode.BANNER
						_banner_label.text = ("Victory! — Enter" if bool(rest["payload"]["victory"]) else "Defeat… — Enter")
					else:
						_push_feed(rtype, rest["payload"])
					beats += 1
				_refresh()
	_playing = false
	ObservableBus.emit_domain_event("ui_ai_playback_done", {"beats": beats})
```

  - `_apply_turn_started(id)` = the current `_on_turn_started` body EXCEPT: when the next actor is ALSO AI it must schedule `_run_ai_turn.call_deferred()` again (chain), preserving the existing stale-deferred guard; when it's the player, build the menu via existing code (using `_menu_row_affordable` from T5).
  - `_highlight_actor(e)`: brief modulate pulse on the acting combatant's visual (payload key varies: `id`/`attacker`/`actor` — coalesce).
  - Skip: `var _skip_requested := false`; in `_unhandled_input`, when `_mode == Mode.WAIT_AI and _playing` any `confirm`/`cancel` press sets `_skip_requested = true`.
  - CRITICAL re-entrancy notes: (a) `combat_autoplay` in QA calls `WICombatAI.take_turn` directly for the PLAYER — those events flow while `_mode` may be MENU; immediate path handles them as today. (b) `_run_ai_turn`'s existing guard stays. (c) With `_beat_delay() == 0`, `_drain_playback` runs the whole while-loop synchronously — QA ordering identical to pre-T10 behavior.
- [ ] **Step 3: Verify ordering under QA.** All 4 combat scripts + `defeat_reload` headless at canonical seeds → PASS unchanged (this is the regression proof that zero-delay playback preserves event/mode ordering). Add `{"action": "assert_event_logged", "type": "ui_ai_playback_done"}` to `combat_walkthrough.json`.
- [ ] **Step 4: Verify pacing visually.** Windowed `combat_walkthrough` seed 9 — screenshots can't show pacing; instead run windowed and CONFIRM in the recorded events (`events.jsonl`) that `ui_ai_playback_done.beats` > 0 and, by wall-clock, the run took ≥ beats × 0.5s longer than headless. State the numbers in the task report.
- [ ] **Step 5: Commit** `feat(m4-t10): paced, skippable AI-turn playback`

---

### Task 11: Layout/overlap pass + screenshot recapture + docs

Playtest finding 7 + M3's deferred enemy-label overlap + everything T6's viewport bump displaced. LAST task before final review.

**Files:**
- Modify: `wandering_inn_game_v4/src/combat/combat_screen.gd`, `src/ui/message_layer.gd`, `src/ui/dialogue_panel.gd`, `src/ui/journal.gd`, `src/ui/pause_menu.gd` (whichever need re-anchoring at 1024×640)
- Modify: `wandering_inn_game_v4/CLAUDE.md`, `HANDOFF.md`

**Interfaces:** consumes everything prior; produces the final M4 layout + refreshed docs/screenshots.

- [ ] **Step 1: Combat label collision.** Enemy name labels at x≥9 overlap the menu panel (`qa_output/mage_unlock_loop/03_mage_kit_combat.png` shows the M3 instance). Fix: when a combatant's cell x ≥ 10 (board columns near the 820px menu), right-align the label to the square's left edge (`label.position.x = -(label.size.x) + CELL - 6` after a deferred size read, or simpler: `label.horizontal_alignment = RIGHT` with a fixed-width label spanning leftward). Verify with a windowed `mage_unlock_loop` screenshot (enemies spawn right-side there).
- [ ] **Step 2: Whole-app audit at 1024×640.** Windowed runs of `inn_walkthrough`, `dialogue_walkthrough`, `combat_walkthrough`, `mage_unlock_loop`, plus manual screens (journal J, pause Esc — drive via a tiny throwaway QA script if needed). Read EVERY screenshot for: overlapping text, clipped panels, off-screen labels, the T4 hint position (re-anchor to bottom: `position = Vector2(8, 620)` or proper `PRESET_BOTTOM_LEFT` anchors — prefer anchors per godot-ui conventions). Fix what you find; re-run; iterate until clean.
- [ ] **Step 3: Recapture ALL windowed baselines.** Every QA script that takes screenshots gets a fresh windowed run at its canonical seed; stale placeholder-era PNGs in `qa_output/` are overwritten. Note in HANDOFF: "screenshot baselines recaptured post-art — do not diff against pre-M4 PNGs."
- [ ] **Step 4: Docs.** `wandering_inn_game_v4/CLAUDE.md`: new M4 block (gating split semantics + per-node ctx refresh, sprite registry/biomes schemas, playback constants, viewport, new QA scripts + seed table rows for `dialogue_hub_loop` + `defeat_reload`), update the Architecture and Gotchas sections it touches (the documented ctx-staleness gotcha is now FIXED — rewrite it). `HANDOFF.md`: playtest-findings section marked fixed item-by-item; parked list current (sprite sourcing, VFX, Tiny RPG licenses, epilogue spoilers); next-playtest checklist (save/load discoverability retest, mage active-cast feel, chieftain difficulty re-check, hub conversations, paced AI turns).
- [ ] **Step 5: Full sweep.** Headless smoke; ALL unit tests; ALL 12 QA scripts at canonical seeds (native) + `qa/web/run_web_qa.sh combat_walkthrough 9` (web parity) → PASS.
- [ ] **Step 6: Commit** `feat(m4-t11): 1024x640 layout pass, screenshot recapture, M4 docs`

---

## Final gate (process, not a task)

Mandatory whole-branch final review on Opus (`git diff <M4 first commit>^..HEAD`), READY-TO-SHIP verdict required; fix wave + re-verification per M2/M3 precedent; ledger + HANDOFF close-out.

## Self-review notes (writing-time)

- Spec §2.1 "quest-gated" requirements: `WIDialogue._meets` has no `quest` key — accomplishment gating IS the progress-gating mechanism (quests derive from accomplishments). The split implements accomplishment→hidden, skill/class→locked. Recorded here so the reviewer doesn't hunt for a phantom `quest` branch.
- Spec §3.3 palette-swap recolors → runtime `modulate` tints (no Pillow on the machine; tint is data-driven and reversible). Execution-refined [D]; note in ledger at T8.
- T4 hint label hard-position vs T11 anchors: deliberate two-step to keep T4 small; T11 owns final anchoring.
- `_squares` holding Node2D holders (T9) changes `_refresh` positioning offsets — T9 Step 2 covers it; T10 consumes `_squares` only via highlight/modulate (holder-safe).
