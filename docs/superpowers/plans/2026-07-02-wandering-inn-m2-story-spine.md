# Wandering Inn M2 — Story Spine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Combat-polish opener (HP/damage numbers, AP costs, skill descriptions), then the story spine: pure dialogue system with visible possession-gated [Skill] checks, counter-derived quests, save/load with RNG-state fidelity, two maps with door transitions, and "The Errand" quest (Erin/Lyonette/Selys) with a non-combat resolution path — all QA-scripted.

**Architecture:** Every new system is a pure class under the M0 purity rule, owned by `WIGame` exactly like combat: `WIDialogue` walks conversation graphs and returns effects for `WIGame` to apply; `WIQuests` derives beat progress as a pure function of accomplishment counters (no parallel state); `WISave` serializes/restores the full sim including `rng.state`. Presentation stays thin, code-built, event-driven.

**Tech Stack:** Godot 4.7 GDScript (statically typed), JSON data, existing M0/M1 QA harness.

**Spec:** `docs/superpowers/specs/2026-07-02-wandering-inn-m2-story-spine-design.md` — read it first.

## Global Constraints

- Godot `/usr/local/bin/godot` (4.7.stable); repo root `/Users/gabriel/wandering_inn_rpg`; branch `main`; commit per task, trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- **Purity rule:** everything in `src/core/` references no autoload/Node/scene-tree API. `WIGame` may reference the pure classes (`WICombat`, `WIProgression`, `WIDialogue`, `WIQuests`, `WISave`). File I/O lives ONLY in the `Game` autoload / TestDriver, never in pure classes.
- `--import` after any new `.gd` before tests; commit `*.uid` sidecars; zero `SCRIPT ERROR`/`Parse Error`/`WARNING` (deliberate RED runs excepted).
- **Numbers policy (updated by spec decision 5):** HP readouts and damage numbers ARE player-visible. Raw STR/DEX/CON/INT/WIS/CHA remain forbidden player-visible, everywhere, always.
- Constructors of pure gameplay classes are SILENT; a `begin()` starts event emission (M1 lesson — applies to `WIDialogue`).
- Skill checks are possession-gated and deterministic: `requires` = skill possession / class level / accomplishment count. Locked options are visible with a requirement string. No dice.
- Quest progress is derived from accomplishment counters via `WIQuests` — storing quest progress anywhere else is a defect.
- Save state includes world `rng.state` **serialized as a String** (u64 exceeds JSON double precision).
- All randomness via injected seeded rng; combat QA scripts run with `--seed=<n>`; canonical seed re-verified in Task 9 (start from 9).
- Style: tabs, static typing, `class_name` + `##` doc comments; content = data + code, no new `.tscn`.
- Tests: plain SceneTree scripts under `tests/`, `--script`-mode, pure classes only.

## File Structure

```
src/core/dialogue.gd        # T3  WIDialogue (pure graph walker)
src/core/quests.gd          # T5  WIQuests (pure derivation)
src/core/save.gd            # T6  WISave (pure serialize/apply)
src/core/wi_game.gd         # T2 maps/doors; T4 dialogue integration; T5 quest hooks; T6 removed-entity tracking + events
src/core/game.gd            # T4 dialogue/quests config load; T6 save orchestration + autosave
src/combat/combat_screen.gd # T1 opener (AP costs, descriptions, HP numbers)
src/ui/message_layer.gd     # T1 toast wrap
src/world/world.gd          # T1 field-hide; T2 map rebuild + blocked cells; T7 panel hosting
src/ui/dialogue_panel.gd    # T7
src/ui/journal.gd           # T7
src/ui/pause_menu.gd        # T7
data/skeleton_scene.json    # T2 multi-map reshape; T8 content entities
data/dialogue/{erin_errand,lyonette_tip,selys_delivery,goblin_parley}.json  # T8
data/quests.json            # T8
project.godot               # T7 journal action
tests/test_dialogue.gd (T3) / test_quests.gd (T5) / test_save.gd (T6) / test_content.gd (T8)
qa/scripts/{inn_walkthrough (T2), dialogue_walkthrough, quest_errand_fight, quest_errand_parley, save_load_roundtrip (T9)}.json
```

---

### Task 1: Combat-polish opener

**Files:**
- Modify: `wandering_inn_game_v4/src/combat/combat_screen.gd`
- Modify: `wandering_inn_game_v4/src/ui/message_layer.gd`
- Modify: `wandering_inn_game_v4/src/world/world.gd`
- Modify: `wandering_inn_game_v4/data/skeleton_scene.json`
- Modify: `wandering_inn_game_v4/qa/scripts/level_up_loop.json`
- Modify: `wandering_inn_game_v4/CLAUDE.md`

**Interfaces:**
- Consumes: existing `attack_resolved {damage, target_hp}`, `skill_resolved`, snapshot shapes.
- Produces: no API changes — presentation + data-name changes only. Encounter display names become "Goblin Ambush" (`goblin_encounter_1`) and "Goblin Warband" (`goblin_encounter_2`).

- [ ] **Step 1: HP numbers + AP costs + descriptions in `combat_screen.gd`**

(a) In `_build_board`'s combatant loop, add an HP label under each square and keep a reference:

```gdscript
		var hp_label := Label.new()
		hp_label.position = Vector2(0, CELL - 6)
		hp_label.add_theme_font_size_override("font_size", 10)
		hp_label.add_theme_color_override("font_color", Color.BLACK)
		sq.add_child(hp_label)
		_hp_labels[id] = hp_label
```
with `var _hp_labels: Dictionary = {}` declared alongside `_hp_bars` and cleared in `_build_board`.

(b) In `_refresh`'s per-combatant loop: `(_hp_labels[id] as Label).text = "%d/%d" % [int(s["hp"]), int(s["max_hp"])]`.

(c) `_menu_text` MENU mode: render costs — `Move ●/step`, `Attack ●●`, `Skill`, `End Turn`:

```gdscript
		Mode.MENU:
			var costs := {"Move": "●/step", "Attack": "●●", "Skill": "", "End Turn": ""}
			var lines: Array = []
			for i in _menu_items.size():
				var item := String(_menu_items[i])
				var suffix: String = ("  " + String(costs[item])) if String(costs[item]) != "" else ""
				lines.append(("> " if i == _menu_index else "  ") + item + suffix)
			return head + "\n".join(lines)
```

(d) `_menu_text` SKILL_PICK mode: each row gains pips + the selected skill's description on a second line:

```gdscript
		Mode.SKILL_PICK:
			var lines: Array = []
			for i in _skill_ids.size():
				var sk: Dictionary = combat.skills[_skill_ids[i]]
				lines.append(("> " if i == _menu_index else "  ") + String(sk["display_name"]) + "  " + "●".repeat(int(sk.get("ap_cost", 0))))
			var desc := ""
			if not _skill_ids.is_empty():
				desc = "\n" + String((combat.skills[_skill_ids[_menu_index]] as Dictionary).get("description", ""))
			return head + ("\n".join(lines) + desc if not lines.is_empty() else "No usable skills (Esc)")
```

(e) Targeting text shows target HP: in `_menu_text`'s ATTACK/SKILL_TARGET branch, replace the target line with:

```gdscript
			var t: Dictionary = combat.combatants[_targets[_target_index]]
			return head + "Target: %s (%d/%d) (Tab cycles, Enter confirms)" % [String(t["display_name"]), int(t["hp"]), int(t["max_hp"])]
```

(f) Feed gains damage numbers — in `_push_feed`'s `attack_resolved` branch:

```gdscript
			line = ("%s strikes %s for %d!" % [attacker, target, int(payload["damage"])]) if bool(payload["hit"]) else "%s misses %s." % [attacker, target]
```

(g) Parenthesize the `_unhandled_input` guard: `if _mode == Mode.INACTIVE or (Game.sim.combat == null and _mode != Mode.BANNER):`.

- [ ] **Step 2: Toast wrap in `message_layer.gd`** — on `_toast_label` creation add `_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`, and widen the panel: `_toast_panel.position = Vector2(70, 16)`, `custom_minimum_size = Vector2(500, 40)`.

- [ ] **Step 3: Field hides during combat in `world.gd`** — the world visuals move under one container: in `_ready`, create `var _field_root := Node2D.new()` FIRST, `add_child(_field_root)`, and make `_build_floor`/`_build_entities`/`_make_square` parent into `_field_root` instead of `self` (keep the message layer and combat screen as direct children of the World node). In `_on_domain_event` add:

```gdscript
	elif type == "combat_started":
		_field_root.visible = false
	elif type == "ui_combat_hidden":
		_field_root.visible = true
```

- [ ] **Step 4: Encounter names + QA assertion** — in `data/skeleton_scene.json` set `goblin_encounter_2`'s `display_name` to `"Goblin Warband"` (encounter_1 stays "Goblin Ambush"). In `qa/scripts/level_up_loop.json`, after fight 2's `combat_finished` wait and the `reaction_triggered` assertion, add:

```json
		{ "action": "press", "name": "confirm" },
		{ "action": "wait_for_event", "type": "ui_combat_hidden", "timeout_sec": 5 },
		{ "action": "assert_event_logged", "type": "entity_removed", "payload_contains": { "id": "goblin_encounter_2" } },
```
(and remove the now-duplicated trailing `press confirm` so confirm happens exactly once; keep the final screenshot last).

- [ ] **Step 5: CLAUDE.md constraint wording** — in `wandering_inn_game_v4/CLAUDE.md`, replace the combat bullet's "NO damage numbers, ever" with "HP readouts and damage numbers are player-visible (playtest decision, M2); raw STR/DEX/etc. remain forbidden", and update the "Product constraints" paragraph likewise.

- [ ] **Step 6: Verify** — `--import`; `qa/run_qa.sh combat_walkthrough headless --seed=9`; `qa/run_qa.sh level_up_loop headless --seed=9`; `qa/run_qa.sh skeleton_walkthrough headless`; `qa/run_qa.sh load_gate headless`; `--script res://tests/test_combat_sim.gd`. All PASS (display names don't feed the RNG — seed 9 must hold; if a script fails on the new assertion order, fix the script per Step 4's intent, not the assertion).

- [ ] **Step 7: Commit** — `git add wandering_inn_game_v4 && git commit -m "Combat polish: HP/damage numbers, AP costs, skill descriptions, field hide"`

---

### Task 2: Multi-map world + doors

**Files:**
- Modify: `wandering_inn_game_v4/src/core/wi_game.gd`
- Modify: `wandering_inn_game_v4/data/skeleton_scene.json`
- Modify: `wandering_inn_game_v4/src/world/world.gd`
- Create: `wandering_inn_game_v4/qa/scripts/inn_walkthrough.json` (supersedes `skeleton_walkthrough.json` — delete the old file and its uses)
- Modify: `wandering_inn_game_v4/qa/scripts/{combat_walkthrough,level_up_loop}.json` (routes)
- Modify: `wandering_inn_game_v4/tests/test_sim_core.gd`

**Interfaces:**
- Consumes: existing `WIGame` internals.
- Produces: scene config shape `{"start_map": String, "player": {...}, "maps": {id: {"grid": {...}, "blocked": [[x,y],...], "entities": [...]}}}`; `WIGame.current_map: String`; `entities`/`grid_size`/`blocked_cells` always reflect the current map (Dictionary/array reference rebind on transition); new entity kind `"door"` with `to_map`/`to_cell` (interact → transition); events `map_changed {map, cell}`. `is_cell_blocked` additionally consults the map's `blocked` list. Every later task relies on: `_maps: Dictionary` internal, `transition(to_map: String, to_cell: Vector2i)` method, and `find_entity(id) -> Dictionary` that searches ALL maps (returns `{}` if absent) for save/remove logic.

- [ ] **Step 1: Reshape `data/skeleton_scene.json`** to:

```json
{
	"start_map": "inn",
	"player": {
		"cell": [2, 3],
		"display_name": "Traveler",
		"skills": ["basic_cleaning"],
		"classes": { "fighter": 1 }
	},
	"maps": {
		"inn": {
			"grid": { "width": 10, "height": 6 },
			"blocked": [],
			"entities": [
				{ "id": "erin", "kind": "npc", "cell": [7, 2], "display_name": "Erin",
				  "dialogue": [ { "speaker": "Erin", "text": "Welcome to The Wandering Inn! Mind giving that table a wipe?" } ] },
				{ "id": "lyonette", "kind": "npc", "cell": [4, 1], "display_name": "Lyonette",
				  "dialogue": [ { "speaker": "Lyonette", "text": "Mind the floors, they're just done." } ] },
				{ "id": "dirty_table", "kind": "prop", "cell": [5, 4], "display_name": "Dirty Table",
				  "requires_skill": "basic_cleaning",
				  "on_skill_use": { "accomplishment": "cleaned_the_inn", "toast": "[Basic Cleaning] — The table is spotless." } },
				{ "id": "bed", "kind": "prop", "sleep": true, "cell": [1, 2], "display_name": "Bed" },
				{ "id": "inn_door", "kind": "door", "cell": [9, 3], "display_name": "To Liscor",
				  "to_map": "street", "to_cell": [1, 3] }
			]
		},
		"street": {
			"grid": { "width": 10, "height": 6 },
			"blocked": [[5, 0], [5, 1], [5, 2], [5, 4], [5, 5]],
			"entities": [
				{ "id": "street_door", "kind": "door", "cell": [0, 3], "display_name": "To the Inn",
				  "to_map": "inn", "to_cell": [8, 3] },
				{ "id": "goblin_encounter_2", "kind": "encounter", "cell": [5, 3], "display_name": "Goblin Warband",
				  "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "allies": ["relc"],
				  "on_victory": "street_cleared" },
				{ "id": "goblin_encounter_1", "kind": "encounter", "cell": [8, 5], "display_name": "Goblin Ambush",
				  "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "allies": ["relc"],
				  "on_victory": "won_combat" },
				{ "id": "selys", "kind": "npc", "cell": [8, 1], "display_name": "Selys",
				  "dialogue": [ { "speaker": "Selys", "text": "Adventurers. Always tracking mud in." } ] }
			]
		}
	}
}
```
NOTE: the warband at [5,3] plugs the only gap in the x=5 wall — the street's east side is unreachable until it's resolved. Task 8 gives it a parley conversation and its `on_victory` already records `street_cleared`. `won_combat` (level-up requirement) moves to encounter_1 — the level flow becomes: clear the warband (either path), fight the Ambush at [8,5] for `won_combat`... **No — keep the M1 level flow simple:** swap the two `on_victory` values so the WARBAND (first reachable fight) records `won_combat` AND `street_cleared`. Since `on_victory` is a single id, give the warband `"on_victory": "won_combat"` and ALSO extend `resolve_combat` in Step 3 to accept `on_victory` as String OR Array. Set warband `"on_victory": ["won_combat", "street_cleared"]` and ambush `"on_victory": ["won_combat"]` in the JSON above (adjust when transcribing).

- [ ] **Step 2: Failing test additions** — in `tests/test_sim_core.gd`, update ALL existing constructions/assertions for the new shape (the M0 sections' cells are unchanged inside the inn map; `_load_json("res://data/skeleton_scene.json")` still works), then append:

```gdscript
	# --- M2 Task 2: multi-map + doors ---
	var g2 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(g2.current_map == "inn", "starts on start_map")
	assert(g2.entities.has("erin") and not g2.entities.has("selys"), "entities are per-map")
	# Door transition: walk to face inn_door at [9,3] from [8,3]
	g2.player_cell = Vector2i(8, 3)
	g2.player_facing = Vector2i.RIGHT
	_events.clear()
	g2.interact()
	assert(g2.current_map == "street", "door transitions map")
	assert(g2.player_cell == Vector2i(1, 3), "arrives at to_cell")
	assert(_count("map_changed") == 1, "map_changed emitted")
	assert(g2.entities.has("selys") and not g2.entities.has("erin"), "entity view rebound")
	assert(g2.is_cell_blocked(Vector2i(5, 1)), "street wall blocks")
	assert(not g2.is_cell_blocked(Vector2i(4, 1)), "open street cell clear")
	assert(g2.find_entity("erin").size() > 0 and g2.find_entity("nobody").is_empty(), "find_entity searches all maps")
	# Multi-id on_victory
	g2.player_cell = Vector2i(4, 3)
	g2.player_facing = Vector2i.RIGHT
	g2.interact()
	assert(g2.combat != null, "warband starts combat (no conversation yet)")
	g2.combat.apply_damage("goblin_raider", 999, "pc", true)
	g2.combat.apply_damage("goblin_shaman", 999, "pc", true)
	g2.resolve_combat()
	assert(g2.accomplishment_count("won_combat") == 1 and g2.accomplishment_count("street_cleared") == 1, "array on_victory records all")
```

- [ ] **Step 3: Implement in `wi_game.gd`** — replace the single-map parsing:

```gdscript
var current_map: String = ""
var _maps: Dictionary = {}
var _map_blocked: Dictionary = {}   # current map's blocked set: Vector2i -> true
```

In `_init`, replace grid/entity parsing with:

```gdscript
	for map_id: String in scene_config["maps"]:
		var m: Dictionary = scene_config["maps"][map_id]
		var ents := {}
		for e: Dictionary in m.get("entities", []):
			var ent: Dictionary = e.duplicate(true)
			ent["cell"] = Vector2i(int(e["cell"][0]), int(e["cell"][1]))
			ents[String(e["id"])] = ent
		var blocked := {}
		for cell: Array in m.get("blocked", []):
			blocked[Vector2i(int(cell[0]), int(cell[1]))] = true
		_maps[map_id] = {
			"grid": Vector2i(int(m["grid"]["width"]), int(m["grid"]["height"])),
			"entities": ents, "blocked": blocked,
		}
	_bind_map(String(scene_config["start_map"]))
```

with:

```gdscript
func _bind_map(map_id: String) -> void:
	current_map = map_id
	grid_size = _maps[map_id]["grid"]
	entities = _maps[map_id]["entities"]
	_map_blocked = _maps[map_id]["blocked"]


func transition(to_map: String, to_cell: Vector2i) -> void:
	_bind_map(to_map)
	player_cell = to_cell
	_emit("map_changed", {"map": to_map, "cell": [to_cell.x, to_cell.y]})


func find_entity(id: String) -> Dictionary:
	for map_id: String in _maps:
		if (_maps[map_id]["entities"] as Dictionary).has(id):
			return (_maps[map_id]["entities"] as Dictionary)[id]
	return {}
```

`is_cell_blocked` adds `if _map_blocked.has(cell): return true` before the entity loop. `interact()` gains a `"door"` arm:

```gdscript
		"door":
			transition(String(target["to_map"]), Vector2i(int(target["to_cell"][0]), int(target["to_cell"][1])))
			return {"map": current_map}
```

`resolve_combat` handles String-or-Array `on_victory`:

```gdscript
	var victories: Variant = entity.get("on_victory", "won_combat")
	for vid: Variant in (victories if victories is Array else [victories]):
		record_accomplishment(String(vid))
```

(Entity removal in `resolve_combat`/future dialogue effects must erase from the entity's OWNING map: use a helper `func remove_entity(id: String) -> void:` that finds the owning map, erases there, appends to `removed_entities: Array[String]` (new var), and emits `entity_removed {id}` — switch `resolve_combat` to it. Declare `var removed_entities: Array[String] = []`.) Add `removed_entities` to `snapshot()` and `"current_map": current_map` too.

- [ ] **Step 4: Presentation** — in `world.gd`: extract entity/floor building into `_rebuild_field()` (clears `_field_root` children + `_entity_rects`, rebuilds floor sized to `Game.sim.grid_size`, draws the current map's blocked cells as dark rects (reuse combat's `BLOCKED_COLOR` value), rebuilds entity squares + player square); call it from `_ready` and on `"map_changed"` in `_on_domain_event`.

- [ ] **Step 5: QA scripts** — create `qa/scripts/inn_walkthrough.json` replicating the old skeleton beats on the inn map (world_ready → talk to Erin at [7,2] via up 1/right 4/right-blocked/interact → dialogue_line + ui_dialogue_rendered → down 2/left-blocked table → interact → skill/toast asserts → `assert_state accomplishments.cleaned_the_inn equals 1`), delete `qa/scripts/skeleton_walkthrough.json`, and update `combat_walkthrough.json`/`level_up_loop.json` routes for the new geography — combat_walkthrough: from [2,3]: right ×6 → [8,3]; right-blocked (door [9,3]); interact (arrive street [1,3]); right ×3 → [4,3]; right-blocked (warband [5,3]); interact → combat starts; tripwire/autoplay/victory/resolve as before; final asserts `won_combat == 1` AND `street_cleared == 1`. level_up_loop: same start through victory+confirm; then back through street_door: left ×1... player still at [1,3]? After combat the field piece hasn't moved: at [4,3]; route home: left ×3 → [1,3]; left-blocked (street_door [0,3]); interact (arrive inn [8,3]); left ×6 → [2,3]... bed at [1,2]: up 1 → [2,2]; left-blocked (bed); interact (sleep); then return: right ×6 → [8,2]?? row 2 has erin [7,2] — use row 3: from [2,2]: down 1 → [2,3]; right ×6 → [8,3]; right-blocked door; interact; street [1,3]; warband gone (removed on victory): right ×6 → [7,3]; down 2 → [7,5]; right-blocked (ambush [8,5]); interact → fight 2; riposte assert; confirm; entity_removed goblin_encounter_1 assert. Adjust step counts to the actual blocked/clear cells — the implementer MUST dry-run the route mentally against the JSON and fix any miscount, reporting corrections.

- [ ] **Step 6: Verify** — `--import`; `test_sim_core.gd` PASS; `test_combat_sim.gd`, `test_progression.gd`, `test_combat_data.gd`, `sim_combat_batch.gd` (exactly `win_rate=0.70 median_rounds=5` — map changes must not touch combat rng) all PASS; `inn_walkthrough` headless PASS; `combat_walkthrough`/`level_up_loop` headless `--seed=9` — fight 1 is still the first `rng.randi()` draw so seed 9 SHOULD hold; if either fails on fight outcome (not on routing), re-run the Task 9 seed discipline early (try 10, 11, … ≤ 20), record the new canonical seed, and update both invocations; `load_gate` PASS.

- [ ] **Step 7: Commit** — `git add -A wandering_inn_game_v4 && git commit -m "Add multi-map world with door transitions; move encounters to Liscor street"`

---

### Task 3: WIDialogue (pure) + tests

**Files:**
- Create: `wandering_inn_game_v4/src/core/dialogue.gd`
- Test: `wandering_inn_game_v4/tests/test_dialogue.gd`

**Interfaces:**
- Produces `class_name WIDialogue extends RefCounted`:
  - `_init(graph: Dictionary, ctx: Dictionary, event_sink: Callable)` — ctx: `{"skills": Array, "classes": Dictionary, "accomplishments": Dictionary, "names": Dictionary}` (`names` maps skill/class ids → display names). Constructor SILENT.
  - `begin() -> void` — enters `graph["start"]`, emits first `dialogue_node`.
  - `current_options() -> Array` — `[{text: String, locked: bool, requirement: String}]` in authored order.
  - `choose(index: int) -> Dictionary` — `{}` for invalid/locked (no state change); else `{"effects": Array, "ended": bool}`; advances to `goto` node (emitting `dialogue_node`) or ends (emitting `dialogue_ended {}`, sets `finished`).
  - `var finished: bool`, `var current_id: String`.
- Graph schema: `{"start": id, "nodes": {id: {"speaker", "text", "options": [{"text", "goto"? , "end"?: true, "requires"?: {...}, "effects"?: [...]}]}}}`. `requires` forms: `{"skill": id}`, `{"class": {id: min_level}}`, `{"accomplishment": {id: min_count}}`. Requirement strings: skill → `"requires %s" % names[id]`; class → `"requires %s %d"`; accomplishment → `"requires more progress"`.
- Events: `dialogue_node {speaker, text, options: [{text, locked, requirement}]}`, `dialogue_ended {}`. (`dialogue_started`/`dialogue_choice` are WIGame's, Task 4.)

- [ ] **Step 1: Failing test** — `tests/test_dialogue.gd`:

```gdscript
extends SceneTree
## Pure dialogue-graph tests.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_dialogue.gd

var _events: Array = []


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


func _count(type: String) -> int:
	var n := 0
	for e: Dictionary in _events:
		if e["type"] == type:
			n += 1
	return n


const GRAPH := {
	"start": "hub",
	"nodes": {
		"hub": {"speaker": "Erin", "text": "Need anything?", "options": [
			{"text": "Just chatting.", "goto": "chat"},
			{"text": "Let me clean that.", "requires": {"skill": "basic_cleaning"}, "effects": [{"accomplishment": "cleaned_the_inn"}], "goto": "thanks"},
			{"text": "Show me the drills.", "requires": {"class": {"fighter": 2}}, "goto": "thanks"},
			{"text": "About that goblin...", "requires": {"accomplishment": {"street_cleared": 1}}, "goto": "thanks"},
			{"text": "Bye.", "end": true},
		]},
		"chat": {"speaker": "Erin", "text": "Chat away!", "options": [{"text": "Back.", "goto": "hub"}]},
		"thanks": {"speaker": "Erin", "text": "Thanks!", "options": [{"text": "Bye.", "end": true, "effects": [{"quest": "the_errand"}]}]},
	},
}


func _init() -> void:
	var ctx := {
		"skills": ["basic_cleaning"], "classes": {"fighter": 1},
		"accomplishments": {}, "names": {"basic_cleaning": "[Basic Cleaning]", "fighter": "Fighter"},
	}
	var d := WIDialogue.new(GRAPH, ctx, _sink)
	assert(_events.is_empty(), "constructor is silent")
	d.begin()
	assert(_count("dialogue_node") == 1, "begin emits first node")
	assert(d.current_id == "hub", "starts at start node")

	var opts := d.current_options()
	assert(opts.size() == 5, "all options visible")
	assert(not opts[0]["locked"] and not opts[1]["locked"], "no-req and skill-possessed unlocked")
	assert(opts[2]["locked"] and opts[2]["requirement"] == "requires Fighter 2", "class-gated locked with name")
	assert(opts[3]["locked"] and opts[3]["requirement"] == "requires more progress", "accomplishment lock generic")

	assert(d.choose(2).is_empty(), "locked choose refused")
	assert(d.current_id == "hub", "refusal does not advance")
	assert(d.choose(99).is_empty(), "out-of-range refused")

	var r := d.choose(1)
	assert(r["ended"] == false and (r["effects"] as Array).size() == 1, "effects returned to caller")
	assert(d.current_id == "thanks" and _count("dialogue_node") == 2, "advanced with node event")

	var r2 := d.choose(0)
	assert(r2["ended"] == true and String((r2["effects"] as Array)[0]["quest"]) == "the_errand", "end option carries effects")
	assert(d.finished and _count("dialogue_ended") == 1, "ended emits and finishes")
	assert(d.choose(0).is_empty(), "finished dialogue refuses input")

	# Loop-back navigation
	var d2 := WIDialogue.new(GRAPH, ctx, _sink)
	d2.begin()
	d2.choose(0)
	assert(d2.current_id == "chat", "goto chat")
	d2.choose(0)
	assert(d2.current_id == "hub", "hub loop-back works")

	print("PASS: dialogue graphs walk, gate, and end correctly")
	quit(0)
```

- [ ] **Step 2: RED run.** Expected: `WIDialogue` not declared.

- [ ] **Step 3: Implement `src/core/dialogue.gd`**

```gdscript
class_name WIDialogue
extends RefCounted
## Pure conversation-graph walker. PURITY RULE: no autoload/Node/scene-tree
## references; context (skills/classes/accomplishments/display names) is
## injected, and chosen options' effects are RETURNED to the caller (WIGame)
## to apply — this class never mutates game state. Constructor is silent;
## begin() starts emission (see WICombat.begin for the lesson behind this).

var finished := false
var current_id := ""

var _graph: Dictionary
var _ctx: Dictionary
var _event_sink: Callable


func _init(graph: Dictionary, ctx: Dictionary, event_sink: Callable) -> void:
	_graph = graph
	_ctx = ctx
	_event_sink = event_sink


func begin() -> void:
	_enter(String(_graph["start"]))


func current_options() -> Array:
	if finished:
		return []
	var out: Array = []
	for opt: Dictionary in _node().get("options", []):
		var req: Dictionary = opt.get("requires", {})
		var locked := not _meets(req)
		out.append({"text": String(opt["text"]), "locked": locked, "requirement": _requirement_text(req) if locked else ""})
	return out


func choose(index: int) -> Dictionary:
	if finished:
		return {}
	var options: Array = _node().get("options", [])
	if index < 0 or index >= options.size():
		return {}
	var opt: Dictionary = options[index]
	if not _meets(opt.get("requires", {})):
		return {}
	var effects: Array = (opt.get("effects", []) as Array).duplicate(true)
	var ended := bool(opt.get("end", false))
	if ended:
		finished = true
		_emit("dialogue_ended", {})
	else:
		_enter(String(opt["goto"]))
	return {"effects": effects, "ended": ended}


func _node() -> Dictionary:
	return (_graph["nodes"] as Dictionary)[current_id]


func _enter(id: String) -> void:
	current_id = id
	var n := _node()
	_emit("dialogue_node", {"speaker": String(n["speaker"]), "text": String(n["text"]), "options": current_options()})


func _meets(req: Dictionary) -> bool:
	if req.is_empty():
		return true
	if req.has("skill"):
		return (_ctx["skills"] as Array).has(String(req["skill"]))
	if req.has("class"):
		for id: String in req["class"]:
			if int((_ctx["classes"] as Dictionary).get(id, 0)) < int(req["class"][id]):
				return false
		return true
	if req.has("accomplishment"):
		for id: String in req["accomplishment"]:
			if int((_ctx["accomplishments"] as Dictionary).get(id, 0)) < int(req["accomplishment"][id]):
				return false
		return true
	return false


func _requirement_text(req: Dictionary) -> String:
	var names: Dictionary = _ctx.get("names", {})
	if req.has("skill"):
		return "requires %s" % String(names.get(String(req["skill"]), String(req["skill"])))
	if req.has("class"):
		for id: String in req["class"]:
			return "requires %s %d" % [String(names.get(id, id)), int(req["class"][id])]
	return "requires more progress"


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
```

NOTE: `_enter` calls `current_options()` which reads `current_id` — set before use (as written). Recursion between `_enter`→`current_options` is one level, safe.

- [ ] **Step 4: Import, GREEN**, plus `load_gate` PASS.

- [ ] **Step 5: Commit** — `"Add WIDialogue: pure conversation graphs with possession-gated visible options"`

---

### Task 4: WIGame dialogue integration

**Files:**
- Modify: `wandering_inn_game_v4/src/core/wi_game.gd`
- Modify: `wandering_inn_game_v4/src/core/game.gd`
- Test: extend `wandering_inn_game_v4/tests/test_sim_core.gd`

**Interfaces:**
- Consumes: `WIDialogue` (T3), multi-map (T2).
- Produces on `WIGame`:
  - config: `combat_config` may now carry `"dialogue": {conversation_id: graph}` (Game loads every `data/dialogue/*.json` keyed by basename).
  - `var dialogue: WIDialogue` (active-or-null); `known_skills() -> Array` (innate + `WIProgression.granted_skills`, deduped, empty-combat_config-safe).
  - `start_dialogue(conversation_id: String, source_entity_id: String) -> bool` — guards: no combat, no dialogue, graph exists. Emits `dialogue_started {conversation, entity}` then `dialogue.begin()`.
  - `dialogue_choose(index: int) -> bool` — delegates, applies returned effects in order (`accomplishment` → `record_accomplishment`; `quest` → `start_quest` (T5 — until then, stash into `started_quests` array directly and emit `quest_started {id}`); `remove_entity` → `remove_entity`; `start_combat` → deferred until dialogue cleared), emits `dialogue_choice {index}`. When `ended`: `dialogue = null` FIRST, then apply effects (so a `start_combat` effect passes the no-dialogue guard).
  - `interact()` routing: npc with `"conversation"` field → `start_dialogue`; encounter with `"conversation"` → `start_dialogue` (combat NOT auto-started); plain encounter unchanged.
  - `move_player` refuses while `dialogue != null` (sim-level belt; UI gates too).
  - `var started_quests: Array[String] = []` (full quest machinery is T5).
  - New event: `combat_resolved {victory}` emitted at the end of `resolve_combat` on victory (T6's autosave hook; defeat keeps `game_over`).

- [ ] **Step 1: Failing test** — append to `tests/test_sim_core.gd` (reuse `combat_config`; build it with a dialogue graph):

```gdscript
	# --- M2 Task 4: dialogue integration ---
	var dlg_graph := {
		"start": "n1",
		"nodes": {"n1": {"speaker": "Erin", "text": "Hello!", "options": [
			{"text": "Fight me.", "effects": [{"start_combat": "goblin_encounter_1"}], "end": true},
			{"text": "Clear the road.", "effects": [{"remove_entity": "goblin_encounter_2"}, {"accomplishment": "street_cleared"}], "goto": "n2"},
			{"text": "Bye.", "end": true}]},
		"n2": {"speaker": "Erin", "text": "Done.", "options": [{"text": "Bye.", "end": true}]}},
	}
	var cc2: Dictionary = combat_config.duplicate(true)
	cc2["dialogue"] = {"test_conv": dlg_graph}
	var g4 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, cc2)
	assert(g4.known_skills().has("basic_cleaning") and g4.known_skills().has("power_strike"), "known = innate + grants")
	_events.clear()
	assert(g4.start_dialogue("test_conv", "erin"), "dialogue starts")
	assert(g4.dialogue != null and _count("dialogue_started") == 1 and _count("dialogue_node") == 1, "started + node")
	assert(not g4.move_player(Vector2i.RIGHT), "movement refused during dialogue")
	assert(not g4.start_dialogue("test_conv", "erin"), "no dialogue during dialogue")
	# remove_entity + accomplishment effects, then loop continues
	assert(g4.dialogue_choose(1), "choose applies effects")
	assert(g4.find_entity("goblin_encounter_2").is_empty(), "entity removed cross-map via effect")
	assert(g4.accomplishment_count("street_cleared") == 1, "accomplishment effect recorded")
	assert(g4.dialogue != null, "goto continues dialogue")
	assert(g4.dialogue_choose(0), "end option")
	assert(g4.dialogue == null and _count("dialogue_ended") == 1, "dialogue cleared on end")
	# start_combat effect: end-then-fight ordering
	assert(g4.start_dialogue("test_conv", "erin"), "restart")
	assert(g4.dialogue_choose(0), "fight option")
	assert(g4.dialogue == null and g4.combat != null, "dialogue ended then combat started")
	g4.combat.apply_damage("goblin_raider", 999, "pc", true)
	g4.combat.apply_damage("goblin_shaman", 999, "pc", true)
	_events.clear()
	g4.resolve_combat()
	assert(_count("combat_resolved") == 1, "combat_resolved emitted on victory")
```

- [ ] **Step 2: RED run.**

- [ ] **Step 3: Implement** — `wi_game.gd`:

```gdscript
var dialogue: WIDialogue = null
var started_quests: Array[String] = []
```

```gdscript
func known_skills() -> Array:
	var out: Array = player_skills.duplicate()
	if not _combat_config.is_empty():
		for sk: Variant in WIProgression.granted_skills(classes, _combat_config["classes"]):
			if not out.has(String(sk)):
				out.append(String(sk))
	return out


func start_dialogue(conversation_id: String, source_entity_id: String) -> bool:
	if dialogue != null or combat != null:
		return false
	var graphs: Dictionary = _combat_config.get("dialogue", {})
	if not graphs.has(conversation_id):
		return false
	var names := {}
	for sk_id: String in skills:
		names[sk_id] = String(skills[sk_id].get("display_name", sk_id))
	if not _combat_config.is_empty():
		for cls: Dictionary in _combat_config["classes"]["classes"]:
			names[String(cls["id"])] = String(cls["display_name"])
	var ctx := {"skills": known_skills(), "classes": classes.duplicate(true), "accomplishments": accomplishments.duplicate(true), "names": names}
	_emit("dialogue_started", {"conversation": conversation_id, "entity": source_entity_id})
	dialogue = WIDialogue.new(graphs[conversation_id], ctx, _event_sink)
	dialogue.begin()
	return true


func dialogue_choose(index: int) -> bool:
	if dialogue == null:
		return false
	var result := dialogue.choose(index)
	if result.is_empty():
		return false
	_emit("dialogue_choice", {"index": index})
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
	if pending_combat != "":
		start_combat(pending_combat)
	return true


func start_quest(id: String) -> void:
	if started_quests.has(id):
		return
	started_quests.append(id)
	_emit("quest_started", {"id": id})
```

`interact()`: in the `"npc"` arm, check `target.has("conversation")` FIRST → `start_dialogue(String(target["conversation"]), String(target["id"]))`, falling back to the M0 one-liner `dialogue_line` otherwise; in the `"encounter"` arm, same conversation-first check before `start_combat`. `move_player` gains `if dialogue != null: return false` after the finished/alive guards... (`move_player` has no such guards — add at top: `if dialogue != null: return false`). `resolve_combat` victory branch ends with `_emit("combat_resolved", {"victory": true})`.

`remove_entity` (from T2) already handles cross-map erase via `find_entity`-style search — ensure it searches `_maps`, not just the current map.

`game.gd` `_build_sim` loads dialogue graphs:

```gdscript
	var dialogue_graphs := {}
	var dir := DirAccess.open("res://data/dialogue")
	if dir != null:
		for f: String in dir.get_files():
			if f.ends_with(".json"):
				dialogue_graphs[f.get_basename()] = _load_json("res://data/dialogue/" + f)
	combat_config["dialogue"] = dialogue_graphs
```
(NOTE for the web export later: `.json` files under `data/dialogue/` are packed via the existing `include_filter` pattern — extend `export_presets.cfg`'s `include_filter` with `data/dialogue/*.json`.)

- [ ] **Step 4: Import; GREEN; regressions** (`test_dialogue.gd`, `test_combat_sim.gd`, `inn_walkthrough`, `load_gate`) PASS. Create `data/dialogue/` with a `.gdignore`-free placeholder? NO — `DirAccess` returning null is handled; the directory arrives with content in Task 8. Add `export_presets.cfg` include_filter now.

- [ ] **Step 5: Commit** — `"Wire dialogue into world sim: conversations, effects, combat-from-parley"`

---

### Task 5: WIQuests + quest events

**Files:**
- Create: `wandering_inn_game_v4/src/core/quests.gd`
- Modify: `wandering_inn_game_v4/src/core/wi_game.gd`
- Test: `wandering_inn_game_v4/tests/test_quests.gd`

**Interfaces:**
- Produces `class_name WIQuests extends RefCounted`, static + pure:
  - `beat_index(quest: Dictionary, accomplishments: Dictionary) -> int` — first beat whose `complete_when` is unmet (every `{id: min}` pair must satisfy `accomplishments.get(id,0) >= min`); returns `beats.size()` when all complete.
  - `evaluate(quest_catalog: Dictionary, started: Array, accomplishments: Dictionary) -> Dictionary` — `{quest_id: {"beat_index": int, "completed": bool, "beat_description": String}}` for started quests only (`beat_description` = current beat's, or `""` when completed).
- `WIGame`: `_combat_config` may carry `"quests"` (quests.json dict). After EVERY `record_accomplishment`, re-evaluate started quests against a cached `_quest_progress: Dictionary` and emit `quest_beat_completed {id, beat}` per newly passed beat and `quest_completed {id}` once, each with a `toast` event (`"Quest updated: <beat desc>"` / `"Quest complete: <title>"`). `start_quest` initializes the cache entry and toasts `"New quest: <title>"`.

- [ ] **Step 1: Failing test** — `tests/test_quests.gd`:

```gdscript
extends SceneTree
## Pure quest-derivation tests.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_quests.gd

const CATALOG := {"quests": [{"id": "the_errand", "title": "The Errand", "beats": [
	{"id": "deliver", "description": "Deliver the package.", "complete_when": {"package_delivered": 1}},
	{"id": "decide", "description": "Decide about the reward.", "complete_when": {"errand_decided": 1}},
]}]}


func _init() -> void:
	var q: Dictionary = CATALOG["quests"][0]
	assert(WIQuests.beat_index(q, {}) == 0, "nothing done = beat 0")
	assert(WIQuests.beat_index(q, {"package_delivered": 1}) == 1, "first beat done")
	assert(WIQuests.beat_index(q, {"package_delivered": 1, "errand_decided": 1}) == 2, "all done = beats.size()")
	assert(WIQuests.beat_index(q, {"errand_decided": 1}) == 0, "later accomplishment alone doesn't skip beats")

	var ev := WIQuests.evaluate(CATALOG, ["the_errand"], {"package_delivered": 1})
	assert(ev["the_errand"]["beat_index"] == 1 and not ev["the_errand"]["completed"], "evaluate mid-quest")
	assert(ev["the_errand"]["beat_description"] == "Decide about the reward.", "current beat description")
	assert(WIQuests.evaluate(CATALOG, [], {}).is_empty(), "unstarted quests absent")
	var done := WIQuests.evaluate(CATALOG, ["the_errand"], {"package_delivered": 1, "errand_decided": 1})
	assert(done["the_errand"]["completed"] and done["the_errand"]["beat_description"] == "", "completed shape")

	print("PASS: quest progress derives purely from accomplishment counters")
	quit(0)
```

- [ ] **Step 2: RED. Step 3: Implement `src/core/quests.gd`:**

```gdscript
class_name WIQuests
extends RefCounted
## Pure quest-beat derivation. Quest progress is a FUNCTION of accomplishment
## counters — never stored (the v2 dead-quest-chain lesson, structural form).


static func beat_index(quest: Dictionary, accomplishments: Dictionary) -> int:
	var beats: Array = quest.get("beats", [])
	for i in beats.size():
		for req_id: String in beats[i].get("complete_when", {}):
			if int(accomplishments.get(req_id, 0)) < int(beats[i]["complete_when"][req_id]):
				return i
	return beats.size()


static func evaluate(quest_catalog: Dictionary, started: Array, accomplishments: Dictionary) -> Dictionary:
	var out := {}
	for quest: Dictionary in quest_catalog.get("quests", []):
		var id := String(quest["id"])
		if not started.has(id):
			continue
		var idx := beat_index(quest, accomplishments)
		var beats: Array = quest.get("beats", [])
		out[id] = {
			"beat_index": idx,
			"completed": idx >= beats.size(),
			"beat_description": String(beats[idx]["description"]) if idx < beats.size() else "",
		}
	return out
```

- [ ] **Step 4: WIGame hooks** — add `var _quest_progress: Dictionary = {}`; in `start_quest` after append: evaluate once, cache, and `_emit("toast", {"text": "New quest: %s" % _quest_title(id)})`. Append to `record_accomplishment`:

```gdscript
	_check_quests()
```

```gdscript
func _check_quests() -> void:
	var catalog: Dictionary = _combat_config.get("quests", {})
	if catalog.is_empty() or started_quests.is_empty():
		return
	var now := WIQuests.evaluate(catalog, started_quests, accomplishments)
	for id: String in now:
		var prev: Dictionary = _quest_progress.get(id, {"beat_index": 0, "completed": false})
		if int(now[id]["beat_index"]) > int(prev["beat_index"]) and not bool(now[id]["completed"]):
			_emit("quest_beat_completed", {"id": id, "beat": now[id]["beat_index"]})
			_emit("toast", {"text": "Quest updated: %s" % String(now[id]["beat_description"])})
		if bool(now[id]["completed"]) and not bool(prev["completed"]):
			_emit("quest_beat_completed", {"id": id, "beat": now[id]["beat_index"]})
			_emit("quest_completed", {"id": id})
			_emit("toast", {"text": "Quest complete: %s" % _quest_title(id)})
	_quest_progress = now
```

with `_quest_title(id)` scanning the catalog for `title`. Add a WIGame-level assertion block to `test_sim_core.gd` (quests key on cc2, start quest via dialogue effect, record both accomplishments, assert `quest_beat_completed` ×2 + `quest_completed` ×1 exactly).

- [ ] **Step 5: Import; GREEN both tests; regressions; commit** — `"Add WIQuests: beat progress derived from accomplishment counters"`

---

### Task 6: WISave + Game orchestration + autosave

**Files:**
- Create: `wandering_inn_game_v4/src/core/save.gd`
- Modify: `wandering_inn_game_v4/src/core/wi_game.gd` (snapshot additions only, if any missing)
- Modify: `wandering_inn_game_v4/src/core/game.gd`
- Test: `wandering_inn_game_v4/tests/test_save.gd`

**Interfaces:**
- Produces `class_name WISave extends RefCounted`, static + pure (Dictionaries only, NO file I/O):
  - `const VERSION := 1`
  - `serialize(game: WIGame) -> Dictionary` — `{"version": 1, "state": {"current_map", "player_cell": [x,y], "player_facing": [x,y], "classes", "accomplishments", "player_skills", "removed_entities", "started_quests", "rng_state": String}}` (rng_state = `str(game.rng.state)` — u64 exceeds JSON double precision, hence String).
  - `apply(game: WIGame, data: Dictionary) -> bool` — false on version mismatch/malformed; restores onto a FRESHLY constructed WIGame: re-removes each `removed_entities` id (via `game.remove_entity`-equivalent silent erase — add `game.erase_entity_silent(id)` that erases from the owning map WITHOUT emitting, used only here), rebinds `current_map` via `transition`-without-event (add `game.bind_map_silent(map, cell)`), overwrites dicts/arrays (duplicated), sets `game.rng.state = int(String(...))`. Emits nothing (Game emits `game_loaded` after).
- `Game` autoload: `save_manual() -> bool` / `save_auto() -> void` / `load_slot(slot: String) -> bool` (`"manual"`/`"auto"`; paths `user://saves/<slot>.json`). `save_manual` refuses (toast `"Cannot save right now."`) when `sim.combat != null or sim.dialogue != null`, else writes + toast `"Game saved."`. `load_slot`: reads/parses; `_build_sim()`; `WISave.apply`; emit `game_loaded {}` (world.gd treats it exactly like `game_reset` — scene reload); false + toast `"No save found."` when missing. Autosave: Game connects to `ObservableBus.domain_event` and calls `save_auto()` on `combat_resolved`, `class_level_up`, `quest_beat_completed`, and `map_changed`.

- [ ] **Step 1: Failing test** — `tests/test_save.gd` (constructs two WIGames with the full combat_config incl. dialogue+quests, mutates the first — walk, level classes directly, record accomplishments, remove an entity via `remove_entity`, start a quest — serializes, applies to the second, asserts: every state field equal, `find_entity` confirms removal carried, `rng.state` equal, and **determinism**: draw `randi()` from both → identical; then version-mismatch `{"version": 99}` → `apply` returns false and the target is untouched). Write the full script following the established test style, ~60 lines, PASS line `"PASS: save round-trips the full sim including rng state"`.

- [ ] **Step 2: RED. Step 3: Implement `save.gd` + the two silent helpers on WIGame + `game.gd` orchestration** per the Interfaces block. `game.gd` additions:

```gdscript
const SAVE_DIR := "user://saves"


func _ready() -> void:
	_build_sim()
	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, _payload: Dictionary) -> void:
	if type in ["combat_resolved", "class_level_up", "quest_beat_completed", "map_changed"]:
		save_auto()


func save_auto() -> void:
	_write_slot("auto")


func save_manual() -> bool:
	if sim.combat != null or sim.dialogue != null:
		ObservableBus.emit_domain_event("toast", {"text": "Cannot save right now."})
		return false
	_write_slot("manual")
	ObservableBus.emit_domain_event("toast", {"text": "Game saved."})
	return true


func _write_slot(slot: String) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open("%s/%s.json" % [SAVE_DIR, slot], FileAccess.WRITE)
	f.store_string(JSON.stringify(WISave.serialize(sim)))
	f.close()


func load_slot(slot: String) -> bool:
	var path := "%s/%s.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(path):
		ObservableBus.emit_domain_event("toast", {"text": "No save found."})
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return false
	_build_sim()
	if not WISave.apply(sim, data):
		return false
	ObservableBus.emit_domain_event("game_loaded", {})
	return true
```

`world.gd`: treat `"game_loaded"` like `"game_reset"` (scene reload). WISave core:

```gdscript
class_name WISave
extends RefCounted
## Pure save serialization. NO file I/O here — the Game autoload owns disk.
## rng_state travels as a String: u64 states exceed JSON double precision.

const VERSION := 1


static func serialize(game: WIGame) -> Dictionary:
	return {"version": VERSION, "state": {
		"current_map": game.current_map,
		"player_cell": [game.player_cell.x, game.player_cell.y],
		"player_facing": [game.player_facing.x, game.player_facing.y],
		"classes": game.classes.duplicate(true),
		"accomplishments": game.accomplishments.duplicate(true),
		"player_skills": game.player_skills.duplicate(),
		"removed_entities": game.removed_entities.duplicate(),
		"started_quests": game.started_quests.duplicate(),
		"rng_state": str(game.rng.state),
	}}


static func apply(game: WIGame, data: Dictionary) -> bool:
	if int(data.get("version", -1)) != VERSION or not (data.get("state") is Dictionary):
		return false
	var s: Dictionary = data["state"]
	for id: Variant in s["removed_entities"]:
		game.erase_entity_silent(String(id))
		game.removed_entities.append(String(id))
	game.bind_map_silent(String(s["current_map"]), Vector2i(int(s["player_cell"][0]), int(s["player_cell"][1])))
	game.player_facing = Vector2i(int(s["player_facing"][0]), int(s["player_facing"][1]))
	game.classes = (s["classes"] as Dictionary).duplicate(true)
	game.accomplishments = (s["accomplishments"] as Dictionary).duplicate(true)
	game.player_skills.assign(s["player_skills"])
	game.started_quests.assign(s["started_quests"])
	game.rng.state = int(String(s["rng_state"]))
	return true
```
(Also re-prime `game._quest_progress` after apply: call the existing `game._check_quests()`-safe path by having `apply` end with a direct re-evaluation — add `game.reprime_quests()` public method on WIGame that recomputes `_quest_progress` WITHOUT emitting, and call it from `apply`. This prevents a load from re-toasting past beats.)

- [ ] **Step 4: Import; GREEN; regressions incl. `sim_combat_batch` (autosave hooks touch no combat rng — exact numbers); commit** — `"Add WISave: versioned full-state round-trip with rng fidelity; autosaves at beats"`

---

### Task 7: UI batch — dialogue panel, journal, pause menu

**Files:**
- Create: `wandering_inn_game_v4/src/ui/dialogue_panel.gd`, `src/ui/journal.gd`, `src/ui/pause_menu.gd`
- Modify: `wandering_inn_game_v4/src/world/world.gd` (instantiate all three; gate input on `Game.sim.dialogue != null`; J/Esc handling lives in the new components)
- Modify: `wandering_inn_game_v4/project.godot` (input action `journal` = physical_keycode 74, same InputEventKey format as existing actions)

**Interfaces:**
- Consumes: `dialogue_started/dialogue_node/dialogue_ended` events, `Game.sim.dialogue_choose(i)`, `WIQuests.evaluate`, `Game.save_manual()/load_slot()`.
- Produces bus events: `ui_dialogue_shown {}` / `ui_dialogue_hidden {}` (QA waits on them), `ui_journal_shown/hidden`, `ui_pause_shown/hidden`.
- **dialogue_panel.gd** (CanvasLayer, code-built): on `dialogue_node` — bottom panel: speaker name line, text (autowrap), numbered option rows; cursor via move_up/move_down; locked rows rendered `"  N. <text>  (<requirement>)"` in grey (`Color(0.45,0.45,0.45)`), unlocked black with `"> "` cursor mark; confirm → `Game.sim.dialogue_choose(cursor)` (locked/refused = no-op); `dialogue_ended` → hide + `ui_dialogue_hidden`. Panel: `position Vector2(20, 240)`, `custom_minimum_size Vector2(600, 150)`. First `dialogue_node` after `dialogue_started` shows + emits `ui_dialogue_shown`.
- **journal.gd** (CanvasLayer): `journal` action toggles when no combat/dialogue/pause; center panel listing, per started quest, `"<title> — <beat_description>"` (or `"<title> — Complete"`), from `WIQuests.evaluate(Game.sim._combat_config["quests"], Game.sim.started_quests, Game.sim.accomplishments)` — expose via a small `Game.sim.quest_summary() -> Array[String]` method added here (WIGame builds strings; UI renders — keeps UI out of sim internals).
- **pause_menu.gd** (CanvasLayer): `cancel` (Esc) toggles when field-idle (no combat/dialogue/journal); rows Resume / Save / Load / Load Autosave; up/down + confirm; Save → `Game.save_manual()`, Load → `Game.load_slot("manual")`, Load Autosave → `Game.load_slot("auto")` (menu closes first on any load — the scene reload replaces everything).
- Input arbitration (documented in each file's doc comment): combat active → combat_screen owns input; else dialogue active → dialogue_panel; else pause open → pause_menu; else journal open → journal; else world. Each `_unhandled_input` checks its own precondition and returns otherwise; `world.gd` adds `or Game.sim.dialogue != null` to its gate plus checks the pause/journal visible flags via the components (expose `var open: bool` on journal/pause; world holds references it created).

- [ ] **Step 1: Implement all three components + world wiring + project.godot action.** Complete code, following combat_screen.gd's established patterns (mode guards, `_make_label`-style builders, bus connect in `_ready`). ~120 lines each for dialogue_panel/pause_menu, ~60 for journal. `quest_summary()` on WIGame:

```gdscript
func quest_summary() -> Array:
	var catalog: Dictionary = _combat_config.get("quests", {})
	var out: Array = []
	var ev := WIQuests.evaluate(catalog, started_quests, accomplishments)
	for id: String in started_quests:
		if not ev.has(id):
			continue
		var title := _quest_title(id)
		out.append("%s — %s" % [title, "Complete" if bool(ev[id]["completed"]) else String(ev[id]["beat_description"])])
	return out
```

- [ ] **Step 2: Verify** — import; headless boot clean; `--quit-after 300` windowed sanity clean; `load_gate` + `inn_walkthrough` PASS (dialogue panel must not break the M0 one-liner NPC path — Erin still has no `conversation` until Task 8; the panel only reacts to `dialogue_started`).

- [ ] **Step 3: Commit** — `"Add dialogue panel, quest journal, and pause menu with save/load"`

---

### Task 8: Content — "The Errand"

**Files:**
- Create: `wandering_inn_game_v4/data/dialogue/erin_errand.json`, `lyonette_tip.json`, `selys_delivery.json`, `goblin_parley.json`
- Create: `wandering_inn_game_v4/data/quests.json`
- Modify: `wandering_inn_game_v4/data/skeleton_scene.json` (attach `conversation` fields)
- Modify: `wandering_inn_game_v4/src/core/game.gd` (load quests.json into config `"quests"`)
- Test: `wandering_inn_game_v4/tests/test_content.gd`

**Interfaces:**
- Consumes: everything prior. Voice/canon: characters per the Wandering Inn Wiki (Erin Solstice — innkeeper; Lyonette — princess-turned-barmaid; Selys Shivertail — Drake, Adventurer's Guild receptionist); v1 `wandering_inn_game_v1/data/dialogue/*.json` may be read for tone reference only.
- Produces: scene entities gain `"conversation"`: erin → `erin_errand`, lyonette → `lyonette_tip`, selys → `selys_delivery`, goblin_encounter_2 (Warband) → `goblin_parley`. Accomplishment vocabulary: `has_package`, `package_delivered`, `lyonette_tip`, `street_cleared`, `kept_reward`, `gave_reward`, `errand_decided`, plus existing `cleaned_the_inn`/`won_combat`.

- [ ] **Step 1: `data/quests.json`**

```json
{
	"quests": [
		{
			"id": "the_errand",
			"title": "The Errand",
			"beats": [
				{ "id": "deliver", "description": "Deliver Erin's package to Selys at the Adventurer's Guild.", "complete_when": { "package_delivered": 1 } },
				{ "id": "decide", "description": "Decide what to do with Selys's reward.", "complete_when": { "errand_decided": 1 } }
			]
		}
	]
}
```

- [ ] **Step 2: Dialogue graphs.** Exact content (voice may be lightly improved, structure/ids/requires/effects must not change):

`erin_errand.json`:
```json
{
	"start": "hub",
	"nodes": {
		"hub": { "speaker": "Erin", "text": "Oh good, someone with working legs! I've got a package for Selys at the Guild — mind running it over? Also the common room is a disaster, don't look at it.", "options": [
			{ "text": "I'll take the package.", "effects": [ { "quest": "the_errand" }, { "accomplishment": "has_package" } ], "goto": "package" },
			{ "text": "Let me deal with that table. ([Basic Cleaning])", "requires": { "skill": "basic_cleaning" }, "effects": [ { "accomplishment": "cleaned_the_inn" } ], "goto": "cleaned" },
			{ "text": "You sent it back!", "requires": { "accomplishment": { "gave_reward": 1 } }, "goto": "epilogue_gave" },
			{ "text": "Delivery's done. I kept the tip.", "requires": { "accomplishment": { "kept_reward": 1 } }, "goto": "epilogue_kept" },
			{ "text": "Just passing through.", "end": true }
		] },
		"package": { "speaker": "Erin", "text": "You're a lifesaver! Selys is out the door, past the... goblin situation. She's the Drake who looks like she's already done with your nonsense.", "options": [ { "text": "On my way.", "end": true } ] },
		"cleaned": { "speaker": "Erin", "text": "Whoa. That was — the table's actually reflective now. Skills are so unfair.", "options": [ { "text": "All part of the service.", "end": true } ] },
		"epilogue_gave": { "speaker": "Erin", "text": "Selys sent the whole reward back with you? That Drake pretends she's all scales. Free breakfast for a week, I mean it.", "options": [ { "text": "Happy to help.", "end": true } ] },
		"epilogue_kept": { "speaker": "Erin", "text": "Good! You earned it — goblins and Drake bureaucracy in one afternoon. Just don't spend it all on Krshia's stall.", "options": [ { "text": "No promises.", "end": true } ] }
	}
}
```

`lyonette_tip.json`:
```json
{
	"start": "hub",
	"nodes": {
		"hub": { "speaker": "Lyonette", "text": "If you're headed to the Guild, a word of advice would cost you nothing to hear.", "options": [
			{ "text": "Go on. (Fighter 2)", "requires": { "class": { "fighter": 2 } }, "effects": [ { "accomplishment": "lyonette_tip" } ], "goto": "tip" },
			{ "text": "Maybe later.", "end": true }
		] },
		"tip": { "speaker": "Lyonette", "text": "Selys respects competence, not chatter. Stand like you've held a line before — which, evidently, you have — and skip the small talk.", "options": [ { "text": "Noted.", "end": true } ] }
	}
}
```

`goblin_parley.json`:
```json
{
	"start": "hub",
	"nodes": {
		"hub": { "speaker": "Goblin Warband", "text": "The goblins fan out across the street, blades low. One eyes your gear, weighing something.", "options": [
			{ "text": "Draw steel.", "effects": [ { "start_combat": "goblin_encounter_2" } ], "end": true },
			{ "text": "Stand aside. I've killed things bigger than your whole warband. (Fighter)", "requires": { "class": { "fighter": 1 } }, "effects": [ { "accomplishment": "street_cleared" }, { "remove_entity": "goblin_encounter_2" } ], "goto": "backdown" },
			{ "text": "Back away slowly.", "end": true }
		] },
		"backdown": { "speaker": "Goblin Warband", "text": "A long pause. The lead goblin sniffs, spits, and waves the others off the road. They keep their eyes on you until the corner.", "options": [ { "text": "Move on.", "end": true } ] }
	}
}
```

`selys_delivery.json`:
```json
{
	"start": "hub",
	"nodes": {
		"hub": { "speaker": "Selys", "text": "Guild's closed for lunch. Unless you're here about the thing Erin won't stop signing her letters about?", "options": [
			{ "text": "Package for you, from Erin.", "requires": { "accomplishment": { "has_package": 1 } }, "effects": [ { "accomplishment": "package_delivered" } ], "goto": "delivered" },
			{ "text": "Erin's package. I'll spare you the small talk. (Lyonette's advice)", "requires": { "accomplishment": { "lyonette_tip": 1 } }, "effects": [ { "accomplishment": "package_delivered" }, { "accomplishment": "selys_impressed" } ], "goto": "delivered_smooth" },
			{ "text": "Just looking around.", "end": true }
		] },
		"delivered": { "speaker": "Selys", "text": "Finally. Here — she overpaid the courier fee, as always. Take it back or keep it, I honestly don't care which.", "options": [
			{ "text": "I'll keep it. Courier's fee.", "effects": [ { "accomplishment": "kept_reward" }, { "accomplishment": "errand_decided" } ], "end": true },
			{ "text": "Send it back to Erin.", "effects": [ { "accomplishment": "gave_reward" }, { "accomplishment": "errand_decided" } ], "end": true }
		] },
		"delivered_smooth": { "speaker": "Selys", "text": "Hm. Someone's been talking to Lyonette. Fine — here's the fee Erin overpaid, and tell that barmaid she's wasted on pouring drinks.", "options": [
			{ "text": "I'll keep it. Courier's fee.", "effects": [ { "accomplishment": "kept_reward" }, { "accomplishment": "errand_decided" } ], "end": true },
			{ "text": "Send it back to Erin.", "effects": [ { "accomplishment": "gave_reward" }, { "accomplishment": "errand_decided" } ], "end": true }
		] }
	}
}
```

- [ ] **Step 3: Wire** — scene entities gain their `conversation` fields (erin/lyonette/selys/goblin_encounter_2 per Interfaces; the Ambush keeps none); `game.gd` `_build_sim` adds `combat_config["quests"] = _load_json("res://data/quests.json")`; `export_presets.cfg` include_filter gains `data/quests.json` (dialogue glob added in T4).

- [ ] **Step 4: Content validation test** — `tests/test_content.gd`: loads every dialogue graph + quests + scene + skills + classes; asserts: every `goto` target exists in the same graph; every option has exactly one of `goto`/`end`; every `requires.skill` exists in skills.json; every `requires.class`/quest-grant class id exists in classes.json; every `remove_entity`/`start_combat` effect id exists in some map's entities; every entity `conversation` value has a matching graph file; every `complete_when` id is produced somewhere (grep the union of dialogue effects + `on_victory` arrays + prop `on_skill_use.accomplishment`); quests referenced by `quest` effects exist. Print `"PASS: errand content is fully cross-referenced"`.

- [ ] **Step 5: Verify** — import; `test_content.gd` PASS; ALL prior tests PASS; `inn_walkthrough` — **Erin now opens a graph, not the one-liner**: update `inn_walkthrough.json` to wait `dialogue_started` + `ui_dialogue_shown`, choose the farewell option (down ×4, confirm — verify against the authored option order), wait `ui_dialogue_hidden`, keep the table/toast beats; `load_gate` PASS.

- [ ] **Step 6: Commit** — `"Add The Errand: four conversations, quest data, canon-voiced content"`

---

### Task 9: QA scripts for the story spine

**Files:**
- Create: `wandering_inn_game_v4/qa/scripts/dialogue_walkthrough.json`, `quest_errand_fight.json`, `quest_errand_parley.json`, `save_load_roundtrip.json`
- Modify: `wandering_inn_game_v4/qa/test_driver.gd` (one new action: `assert_save_exists {slot}` → `FileAccess.file_exists("user://saves/<slot>.json")` else `_fail`)

**Interfaces:**
- Consumes: everything. Seed discipline: combat-bearing scripts run `--seed=<canonical>` (9 unless Task 2 re-searched — use the ledger's canonical). Dialogue choices are injected via move_down ×n + confirm against the AUTHORED option orders (fixed data = deterministic).
- Produces four passing scripts, each asserting from event payloads (never pixels):
  - `dialogue_walkthrough` — inn: talk to Lyonette → assert `dialogue_node` with `payload_contains` on the full options array showing the Fighter-2 option `locked: true`; exit; (combat path to level: door → street → parley → FIGHT option → autoplay victory → confirm → back to inn) → bed sleep → Fighter 2 → talk to Lyonette again → assert same option now `locked: false` → choose it → assert `accomplishment_recorded {id: "lyonette_tip"}`.
  - `quest_errand_fight` — Erin: take package (assert `quest_started {id: "the_errand"}`) → street → parley → Fight → autoplay → victory/confirm → Selys → deliver (assert `quest_beat_completed`) → keep reward → assert `quest_completed` + `kept_reward` ≥1 → return to Erin → assert the kept-epilogue node's `dialogue_node` (payload_contains on speaker+text).
  - `quest_errand_parley` — same through the package, but parley chooses the Fighter stand-aside option: assert `entity_removed {id: "goblin_encounter_2"}` AND `assert_event_logged` must show ZERO `combat_started` — add a tiny TestDriver action `assert_event_absent {type}` (fails if `_has_event`) for this — → deliver → give reward back → `quest_completed` + `gave_reward` → Erin epilogue-gave node asserted.
  - `save_load_roundtrip` — play to post-delivery; Esc → Save (assert toast `"Game saved."` via payload_contains + `assert_save_exists {slot: "manual"}`); make divergent progress (choose keep-reward); Esc → Load; after `game_loaded` + world_ready: assert `errand_decided` count 0, `package_delivered` 1, `current_map` correct — divergence erased. Also `assert_save_exists {slot: "auto"}` right after any beat completion.

- [ ] **Step 1: TestDriver additions** (`assert_save_exists`, `assert_event_absent`) — ~12 lines total, matching existing action style.
- [ ] **Step 2: Author the four scripts.** Routes computed against the Task 2/8 geography; the implementer MUST dry-run each route against `skeleton_scene.json` and the authored option orders, fixing miscounts (report any correction). Combat sections reuse the tripwire+autoplay pattern from `combat_walkthrough.json` verbatim.
- [ ] **Step 3: Run all four headless with the canonical seed** (dialogue-only scripts still take the seed — combat inside them must be deterministic). If the canonical seed loses a required fight or misses the riposte (not needed here), seed-search ≤ 20 per the M1 discipline and record. Then the full regression sweep: every `tests/*.gd`, `inn_walkthrough`, `combat_walkthrough`, `level_up_loop`, `load_gate`. All PASS.
- [ ] **Step 4: Commit** — `"Add story-spine QA: dialogue locks, both errand paths, save/load round-trip"`

---

### Task 10: Docs, windowed verification, HANDOFF (controller-executed)

- [ ] **Step 1:** Windowed runs (canonical seed): `quest_errand_parley`, `save_load_roundtrip`, plus `dialogue_walkthrough` — read the PNGs: dialogue panel legible with a visibly greyed locked option + requirement text; journal renders a beat line; pause menu legible; no raw stats anywhere (HP/damage numbers are expected and correct now).
- [ ] **Step 2:** Update `wandering_inn_game_v4/CLAUDE.md`: new commands (story QA scripts, journal/pause keys), architecture paragraphs (WIDialogue/WIQuests/WISave one-liner each + the effects-applied-by-WIGame rule + quest-progress-is-derived rule + rng-state-as-String gotcha), conventions (dialogue content validation via `test_content.gd`).
- [ ] **Step 3:** Update `HANDOFF.md`: M2 shipped section (systems, content, canonical seed, deferred list unchanged), human playtest instructions (the errand both ways, save/load, journal).
- [ ] **Step 4:** Commit — `"Document M2 story spine; log completion in HANDOFF"`

---

## Self-Review Notes

- **Spec coverage:** Part 0 → T1; dialogue system → T3/T4/T7; quests → T5 (+T7 journal); save/load → T6 (+T7 pause menu); maps → T2; content → T8; QA → T9 (+T2's inn_walkthrough); docs → T10. Spec's `dialogue_started` gating, effects list (accomplishment/quest/remove_entity/start_combat + end), mid-combat/dialogue save refusal, autosave triggers (combat_resolved/class_level_up≈sleep/quest_beat_completed/map_changed), version envelope, rng-state fidelity — all present. Non-goals respected.
- **Sequencing note:** T2 moves encounters to the street and may invalidate seed 9 early — its Step 6 pulls Task 9's seed discipline forward if needed; the ledger carries the canonical seed between tasks.
- **Type consistency:** `WIDialogue.choose -> Dictionary {effects, ended}` consumed by `WIGame.dialogue_choose` (T4); `WIQuests.evaluate` shape consumed by `_check_quests` (T5) and `quest_summary` (T7); `WISave.serialize/apply` consumed by `game.gd` (T6); `find_entity`/`remove_entity`/`erase_entity_silent`/`bind_map_silent`/`transition` defined T2/T6 and used T4/T6; events `dialogue_started/dialogue_node/dialogue_ended/dialogue_choice/quest_started/quest_beat_completed/quest_completed/combat_resolved/map_changed/game_loaded` consistent across emitters (T2-T6) and consumers (T7/T9).
- The final whole-branch review is part of the subagent-driven-development process — do not skip it (it has caught a Critical every milestone so far).
