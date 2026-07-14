# Wandering Inn v4 — Agent-QA Foundation (M0 Spike) Implementation Plan

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fresh Godot 4.7 project `wandering_inn_game_v4/` containing an agent-driven QA harness (ObservableBus event log, in-engine TestDriver, script-load gate, Playwright web-export rig) proven against a walking-skeleton game (move → talk to NPC → use a [Skill] on a prop → toast).

**Architecture:** Strict sim/presentation split — `WIGame` is a pure `RefCounted` simulation with zero scene-tree/autoload dependencies, driven by input in a thin presentation layer and observed via an `ObservableBus` autoload that both drives UI and appends a machine-readable JSONL event log. A `TestDriver` autoload (inert without a CLI flag) executes declarative JSON playtest scripts: injects real keyboard events, waits for bus events, captures screenshots, asserts on sim snapshots, and writes a pass/fail `result.json`. Phase B exports to HTML5 and drives the same scripts under headless Chromium via Playwright.

**Tech Stack:** Godot 4.7 (GDScript, statically typed), JSON data files, bash runner scripts, Node.js + Playwright (Phase B only).

**Spec:** `docs/superpowers/specs/2026-07-01-wandering-inn-v4-agent-qa-foundation-design.md` — read it first.

## Global Constraints

- Godot binary: `/usr/local/bin/godot`, version **4.7.stable** (verify with `--version`; upgraded 2026-07-01 with user approval — greenfield project, no legacy pin). Godot 4.6.2 remains at `/Applications/Godot4.6.app/Contents/MacOS/Godot` solely for running the frozen `wandering_inn_game_v2/` reference.
- All commands run from repo root `/Users/gabriel/wandering_inn_rpg` unless noted.
- Work directly on `main`; commit at the end of every task. Commit messages: imperative subject, body only when the why isn't obvious, trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- **After creating any new `.gd` file, run `/usr/local/bin/godot --headless --path wandering_inn_game_v4 --import` before running tests** — `class_name` registration needs the import pass (`.uid` sidecars). Commit the generated `*.uid` files.
- GDScript style: GDQuest guidelines — tabs for indentation, static typing everywhere, `class_name` + `##` doc comments on public classes.
- **Sim-core purity rule:** nothing under `src/core/wi_game.gd` (or future sim code) may reference an autoload, a Node, or the scene tree. Dependencies are passed in (`Callable` event sink, parsed config Dictionaries). This is what makes `--script`-mode headless tests possible.
- **Every player-visible message flows through `ObservableBus.emit_domain_event()`** — never `print()` for anything a player should see.
- **Never show raw stat numbers (STR/DEX/etc.) to the player** — repo-wide product constraint (no stats exist in M0; keep it that way).
- Content is data + code: JSON under `data/`, UI built in code. No hand-authored `.tscn` beyond the single trivial `src/world/world.tscn` root.
- This is a fresh project: there are **no** known-harmless warnings. Any `SCRIPT ERROR`, `Parse Error`, or `WARNING` in output is a regression — fix it, don't normalize it.
- Tests are plain `SceneTree`-extending scripts under `tests/`, run individually with `--script` (project convention; no GUT/gdUnit).

## File Structure

```
wandering_inn_game_v4/
├── project.godot                 # T1; autoloads added in T3 (ObservableBus, Game) and T5 (TestDriver)
├── .gitignore                    # T1
├── CLAUDE.md                     # T6
├── export_presets.cfg            # T7
├── src/
│   ├── core/
│   │   ├── wi_game.gd            # T2 — pure sim (WIGame)
│   │   ├── event_log.gd          # T3 — pure JSONL writer (WIEventLog)
│   │   ├── qa_paths.gd           # T3 — pure arg/paths helper (QAPaths)
│   │   ├── observable_bus.gd     # T3 — autoload
│   │   └── game.gd               # T3 — autoload owning the WIGame instance
│   ├── world/
│   │   ├── world.tscn            # T1 — trivial root scene
│   │   └── world.gd              # T1 stub, T4 real presentation + input
│   └── ui/
│       └── message_layer.gd      # T4 — toast/dialogue rendering (code-built CanvasLayer)
├── data/
│   ├── skeleton_scene.json       # T2
│   └── skills.json               # T2
├── qa/
│   ├── test_driver.gd            # T5 — autoload, inert without --qa-script
│   ├── run_qa.sh                 # T5
│   ├── scripts/
│   │   ├── load_gate.json        # T5
│   │   └── skeleton_walkthrough.json  # T5
│   └── web/                      # T8 — package.json, run_web_qa.mjs, run_web_qa.sh
├── tests/
│   ├── test_sim_core.gd          # T2
│   └── test_event_log.gd         # T3
├── build/                        # gitignored (web export output)
└── qa_output/                    # gitignored (screenshots, events.jsonl, result.json)
```

---

### Task 1: Project scaffold + clean boot

**Files:**
- Create: `wandering_inn_game_v4/project.godot`
- Create: `wandering_inn_game_v4/.gitignore`
- Create: `wandering_inn_game_v4/src/world/world.tscn`
- Create: `wandering_inn_game_v4/src/world/world.gd`

**Interfaces:**
- Produces: bootable project; input actions `move_up`, `move_down`, `move_left`, `move_right`, `interact` (used by T4 `world.gd` and T5 `TestDriver.ACTION_KEYS`).

- [ ] **Step 1: Create `project.godot`**

```ini
; Engine configuration file.
config_version=5

[application]

config/name="Wandering Inn RPG v4"
run/main_scene="res://src/world/world.tscn"
config/features=PackedStringArray("4.7")

[display]

window/size/viewport_width=640
window/size/viewport_height=400
window/stretch/mode="canvas_items"

[input]

move_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":115,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194322,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
interact={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":101,"location":0,"echo":false,"script":null)
]
}
```

(Bindings: WASD + arrows for movement, Space + E for interact.)

- [ ] **Step 2: Create `.gitignore`**

```gitignore
.godot/
build/
qa_output/
node_modules/
*.tmp
.DS_Store
```

- [ ] **Step 3: Create the root scene and stub script**

`wandering_inn_game_v4/src/world/world.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/world/world.gd" id="1"]

[node name="World" type="Node2D"]
script = ExtResource("1")
```

`wandering_inn_game_v4/src/world/world.gd` (stub, replaced in Task 4):

```gdscript
extends Node2D
## Walking-skeleton presentation layer. Stub — real implementation in Task 4.
```

- [ ] **Step 4: Import pass, then verify clean boot**

Run:
```bash
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --import
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --quit
```
Expected: exit code 0; output contains **no** `SCRIPT ERROR`, `Parse Error`, or `WARNING` lines.

- [ ] **Step 5: Commit**

```bash
git add wandering_inn_game_v4
git commit -m "Scaffold wandering_inn_game_v4: fresh Godot 4.6 project for M0 agent-QA spike"
```

---

### Task 2: Pure sim core (`WIGame`) + skeleton data

**Files:**
- Create: `wandering_inn_game_v4/data/skills.json`
- Create: `wandering_inn_game_v4/data/skeleton_scene.json`
- Create: `wandering_inn_game_v4/src/core/wi_game.gd`
- Test: `wandering_inn_game_v4/tests/test_sim_core.gd`

**Interfaces:**
- Produces: `class_name WIGame extends RefCounted` with:
  - `_init(scene_config: Dictionary, skill_config: Dictionary, event_sink: Callable, rng_seed: int = 0)`
  - `move_player(dir: Vector2i) -> bool` — false and no move if blocked; **always** updates `player_facing`
  - `interact() -> Dictionary` — acts on the entity in the faced cell (npc → dialogue event; prop → skill use)
  - `use_skill(skill_id: String, target_id: String) -> Dictionary`
  - `record_accomplishment(id: String) -> void` (idempotent)
  - `snapshot() -> Dictionary` with keys `player_cell: Array[int]`, `player_facing: Array[int]`, `player_skills: Array`, `accomplishments: Dictionary`
  - public vars: `grid_size: Vector2i`, `player_cell: Vector2i`, `entities: Dictionary` (id → Dictionary with `kind`, `cell: Vector2i`, `display_name`, …)
- Event sink signature: `func sink(type: String, payload: Dictionary) -> void`. Event types emitted: `sim_initialized`, `player_moved`, `player_blocked`, `interact_nothing`, `dialogue_line`, `skill_used`, `skill_unknown`, `accomplishment_recorded`, `toast`.

- [ ] **Step 1: Create the data files**

`wandering_inn_game_v4/data/skills.json`:

```json
{
	"skills": [
		{
			"id": "basic_cleaning",
			"display_name": "[Basic Cleaning]",
			"contexts": ["exploration"],
			"description": "Cleans mundane messes with supernatural ease."
		}
	]
}
```

`wandering_inn_game_v4/data/skeleton_scene.json`:

```json
{
	"grid": { "width": 10, "height": 6 },
	"player": {
		"cell": [2, 3],
		"display_name": "Traveler",
		"skills": ["basic_cleaning"]
	},
	"entities": [
		{
			"id": "erin",
			"kind": "npc",
			"cell": [7, 2],
			"display_name": "Erin",
			"dialogue": [
				{ "speaker": "Erin", "text": "Welcome to The Wandering Inn! Mind giving that table a wipe?" }
			]
		},
		{
			"id": "dirty_table",
			"kind": "prop",
			"cell": [5, 4],
			"display_name": "Dirty Table",
			"requires_skill": "basic_cleaning",
			"on_skill_use": {
				"accomplishment": "cleaned_the_inn",
				"toast": "[Basic Cleaning] — The table is spotless."
			}
		}
	]
}
```

- [ ] **Step 2: Write the failing test**

`wandering_inn_game_v4/tests/test_sim_core.gd`:

```gdscript
extends SceneTree
## Headless test for the pure sim core (no autoloads, no scene tree).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_sim_core.gd

var _events: Array = []


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


func _count(type: String) -> int:
	var n := 0
	for e: Dictionary in _events:
		if e["type"] == type:
			n += 1
	return n


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _init() -> void:
	var scene_config := _load_json("res://data/skeleton_scene.json")
	var skill_config := _load_json("res://data/skills.json")
	var game := WIGame.new(scene_config, skill_config, _sink, 12345)

	# Initialization
	assert(game.grid_size == Vector2i(10, 6), "grid size from config")
	assert(game.player_cell == Vector2i(2, 3), "player start cell from config")
	assert(_count("sim_initialized") == 1, "sim_initialized emitted once")

	# Movement + bounds blocking
	assert(game.move_player(Vector2i.UP), "open-cell move succeeds")
	assert(game.player_cell == Vector2i(2, 2), "player moved up")
	for i in 10:
		game.move_player(Vector2i.LEFT)
	assert(game.player_cell.x == 0, "left edge clamps at x=0")
	assert(_count("player_blocked") >= 1, "blocked moves emit player_blocked")

	# Walk to Erin (npc at [7,2]); entity cells block movement but set facing
	while game.player_cell.x < 6:
		assert(game.move_player(Vector2i.RIGHT), "row y=2 is open up to x=6")
	assert(not game.move_player(Vector2i.RIGHT), "npc cell blocks movement")
	assert(game.player_facing == Vector2i.RIGHT, "blocked move still sets facing")

	# Interact with npc -> dialogue_line
	var line := game.interact()
	assert(line.get("speaker", "") == "Erin", "npc interact returns dialogue line")
	assert(_count("dialogue_line") == 1, "dialogue_line emitted")

	# Walk to face the table (prop at [5,4]) from [6,4]
	game.move_player(Vector2i.DOWN)  # (6,3)
	game.move_player(Vector2i.DOWN)  # (6,4)
	game.move_player(Vector2i.LEFT)  # blocked by table, faces it
	assert(game.player_cell == Vector2i(6, 4), "player stands right of table")

	# Interact with prop -> skill chain
	var effect := game.interact()
	assert(effect.get("accomplishment", "") == "cleaned_the_inn", "prop interact returns effect")
	assert(_count("skill_used") == 1, "skill_used emitted")
	assert(_count("accomplishment_recorded") == 1, "accomplishment_recorded emitted")
	assert(_count("toast") == 1, "toast emitted")
	assert(game.accomplishments.get("cleaned_the_inn", false) == true, "accomplishment stored")

	# Idempotent re-use: skill fires again, accomplishment does not re-record
	game.interact()
	assert(_count("skill_used") == 2, "second use still emits skill_used")
	assert(_count("accomplishment_recorded") == 1, "accomplishment not re-recorded")

	# Unknown skill is rejected
	var none := game.use_skill("fireball", "dirty_table")
	assert(none.is_empty(), "unknown skill returns empty")
	assert(_count("skill_unknown") == 1, "skill_unknown emitted")

	# Snapshot shape
	var snap := game.snapshot()
	assert(snap["player_cell"] == [6, 4], "snapshot player_cell")
	assert(snap["accomplishments"]["cleaned_the_inn"] == true, "snapshot accomplishments")

	print("PASS: sim core behaves correctly")
	quit(0)
```

- [ ] **Step 3: Run test to verify it fails**

Run:
```bash
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_sim_core.gd
```
Expected: FAIL — parse error, `WIGame` not declared.

- [ ] **Step 4: Implement `wi_game.gd`**

`wandering_inn_game_v4/src/core/wi_game.gd`:

```gdscript
class_name WIGame
extends RefCounted
## Pure simulation core for the walking skeleton.
##
## PURITY RULE: this class must never reference an autoload, a Node, or the
## scene tree. All dependencies are injected (config Dictionaries, an event
## sink Callable, an RNG seed). This is what makes the sim testable headless
## and mass-simulatable later (combat balance sims, etc.).

var grid_size: Vector2i
var player_cell: Vector2i
var player_facing := Vector2i.RIGHT
var player_skills: Array[String] = []
var accomplishments: Dictionary = {}
var entities: Dictionary = {}
var skills: Dictionary = {}
var rng := RandomNumberGenerator.new()

var _event_sink: Callable


func _init(scene_config: Dictionary, skill_config: Dictionary, event_sink: Callable, rng_seed: int = 0) -> void:
	_event_sink = event_sink
	rng.seed = rng_seed
	for s: Dictionary in skill_config.get("skills", []):
		skills[String(s["id"])] = s
	grid_size = Vector2i(int(scene_config["grid"]["width"]), int(scene_config["grid"]["height"]))
	var p: Dictionary = scene_config["player"]
	player_cell = Vector2i(int(p["cell"][0]), int(p["cell"][1]))
	for sk: Variant in p.get("skills", []):
		player_skills.append(String(sk))
	for e: Dictionary in scene_config.get("entities", []):
		var ent: Dictionary = e.duplicate(true)
		ent["cell"] = Vector2i(int(e["cell"][0]), int(e["cell"][1]))
		entities[String(e["id"])] = ent
	_emit("sim_initialized", {"seed": rng_seed})


func is_cell_blocked(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return true
	for ent: Dictionary in entities.values():
		if ent["cell"] == cell:
			return true
	return false


func entity_at(cell: Vector2i) -> Dictionary:
	for ent: Dictionary in entities.values():
		if ent["cell"] == cell:
			return ent
	return {}


func move_player(dir: Vector2i) -> bool:
	player_facing = dir
	var target := player_cell + dir
	if is_cell_blocked(target):
		_emit("player_blocked", {"cell": [target.x, target.y]})
		return false
	player_cell = target
	_emit("player_moved", {"cell": [target.x, target.y]})
	return true


func interact() -> Dictionary:
	var target := entity_at(player_cell + player_facing)
	if target.is_empty():
		_emit("interact_nothing", {})
		return {}
	match String(target["kind"]):
		"npc":
			var line: Dictionary = target["dialogue"][0]
			_emit("dialogue_line", line)
			return line
		"prop":
			return use_skill(String(target.get("requires_skill", "")), String(target["id"]))
	return {}


func use_skill(skill_id: String, target_id: String) -> Dictionary:
	if not player_skills.has(skill_id):
		_emit("skill_unknown", {"skill": skill_id})
		return {}
	var target: Dictionary = entities.get(target_id, {})
	if target.is_empty() or not target.has("on_skill_use"):
		_emit("skill_unknown", {"skill": skill_id, "target": target_id})
		return {}
	var effect: Dictionary = target["on_skill_use"]
	_emit("skill_used", {"skill": skill_id, "context": "exploration", "target": target_id})
	record_accomplishment(String(effect["accomplishment"]))
	_emit("toast", {"text": String(effect["toast"])})
	return effect


func record_accomplishment(id: String) -> void:
	if accomplishments.get(id, false):
		return
	accomplishments[id] = true
	_emit("accomplishment_recorded", {"id": id})


func snapshot() -> Dictionary:
	return {
		"player_cell": [player_cell.x, player_cell.y],
		"player_facing": [player_facing.x, player_facing.y],
		"player_skills": player_skills.duplicate(),
		"accomplishments": accomplishments.duplicate(true),
	}


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
```

- [ ] **Step 5: Import pass, run test to verify it passes**

Run:
```bash
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --import
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_sim_core.gd
```
Expected: `PASS: sim core behaves correctly`, exit 0, no errors/warnings.

- [ ] **Step 6: Commit**

```bash
git add wandering_inn_game_v4
git commit -m "Add pure sim core (WIGame) with skeleton scene/skill data and headless tests"
```

---

### Task 3: Event log, QA paths, ObservableBus + Game autoloads

**Files:**
- Create: `wandering_inn_game_v4/src/core/event_log.gd`
- Create: `wandering_inn_game_v4/src/core/qa_paths.gd`
- Create: `wandering_inn_game_v4/src/core/observable_bus.gd`
- Create: `wandering_inn_game_v4/src/core/game.gd`
- Modify: `wandering_inn_game_v4/project.godot` (add `[autoload]` section)
- Test: `wandering_inn_game_v4/tests/test_event_log.gd`

**Interfaces:**
- Consumes: `WIGame` from Task 2.
- Produces:
  - `class_name WIEventLog extends RefCounted` — `_init(path: String)`, `append(type: String, payload: Dictionary) -> void`, `close() -> void`. Each line is JSON: `{"t": <msec int>, "type": <String>, "payload": <Dictionary>}`.
  - `class_name QAPaths extends RefCounted` — `static parse_args(args: PackedStringArray) -> Dictionary` (parses `--key=value`), `static user_args() -> Dictionary` (wraps `OS.get_cmdline_user_args()`), `static out_dir() -> String` (value of `--qa-out`, else `OS.get_user_data_dir().path_join("qa")`).
  - Autoload `ObservableBus` — `signal domain_event(type: String, payload: Dictionary)`; `emit_domain_event(type: String, payload: Dictionary = {}) -> void` (logs to `<out_dir>/events.jsonl` then emits the signal; file logging skipped on web builds).
  - Autoload `Game` — `var sim: WIGame`, built in `_ready()` from the two data JSONs, sink wired to `ObservableBus.emit_domain_event`, seed from `--seed=<int>` user arg (default 0).

- [ ] **Step 1: Write the failing test**

`wandering_inn_game_v4/tests/test_event_log.gd`:

```gdscript
extends SceneTree
## Headless test for WIEventLog and QAPaths (pure classes, no autoloads).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_event_log.gd


func _init() -> void:
	# QAPaths.parse_args
	var args := QAPaths.parse_args(PackedStringArray(["--qa-script=res://qa/x.json", "--seed=42", "loose"]))
	assert(args["qa-script"] == "res://qa/x.json", "parses --key=value")
	assert(args["seed"] == "42", "parses numeric value as string")
	assert(not args.has("loose"), "ignores args without --key= form")

	# WIEventLog round-trip
	var path := OS.get_user_data_dir().path_join("test_qa/events.jsonl")
	var log := WIEventLog.new(path)
	log.append("toast", {"text": "hello"})
	log.append("skill_used", {"skill": "basic_cleaning"})
	log.close()

	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	assert(lines.size() == 2, "two JSONL lines written")
	var first: Variant = JSON.parse_string(lines[0])
	assert(first is Dictionary, "line 0 is valid JSON")
	assert(first["type"] == "toast", "type field round-trips")
	assert(first["payload"]["text"] == "hello", "payload round-trips")
	assert(first.has("t"), "timestamp present")

	print("PASS: event log and QA paths behave correctly")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_event_log.gd
```
Expected: FAIL — `QAPaths`/`WIEventLog` not declared.

- [ ] **Step 3: Implement the two pure classes**

`wandering_inn_game_v4/src/core/event_log.gd`:

```gdscript
class_name WIEventLog
extends RefCounted
## Append-only JSONL event log. Pure class — path is injected; no autoload use.


var _file: FileAccess


func _init(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_file = FileAccess.open(path, FileAccess.WRITE)


func append(type: String, payload: Dictionary) -> void:
	if _file == null:
		return
	_file.store_line(JSON.stringify({"t": Time.get_ticks_msec(), "type": type, "payload": payload}))
	_file.flush()


func close() -> void:
	if _file != null:
		_file.close()
		_file = null
```

`wandering_inn_game_v4/src/core/qa_paths.gd`:

```gdscript
class_name QAPaths
extends RefCounted
## Parses QA-related command-line user args (everything after `--`) and
## resolves the QA output directory.


static func parse_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a: String in args:
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			out[kv[0]] = kv[1]
	return out


static func user_args() -> Dictionary:
	return parse_args(OS.get_cmdline_user_args())


static func out_dir() -> String:
	var args := user_args()
	if args.has("qa-out"):
		return String(args["qa-out"])
	return OS.get_user_data_dir().path_join("qa")
```

- [ ] **Step 4: Import pass, run test to verify it passes**

Run:
```bash
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --import
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_event_log.gd
```
Expected: `PASS: event log and QA paths behave correctly`.

- [ ] **Step 5: Implement the two autoloads**

`wandering_inn_game_v4/src/core/observable_bus.gd`:

```gdscript
extends Node
## Autoload: the single pipe for every player-visible / QA-relevant domain
## event. Logs each event as JSONL, then emits it as a signal for UI and the
## TestDriver. Never bypass this with print() for player-facing messages.

signal domain_event(type: String, payload: Dictionary)

var _log: WIEventLog


func _ready() -> void:
	if not OS.has_feature("web"):
		_log = WIEventLog.new(QAPaths.out_dir().path_join("events.jsonl"))


func emit_domain_event(type: String, payload: Dictionary = {}) -> void:
	if _log != null:
		_log.append(type, payload)
	domain_event.emit(type, payload)
```

`wandering_inn_game_v4/src/core/game.gd`:

```gdscript
extends Node
## Autoload owning the sim instance; bridges sim domain events onto ObservableBus.

var sim: WIGame


func _ready() -> void:
	var scene_config := _load_json("res://data/skeleton_scene.json")
	var skill_config := _load_json("res://data/skills.json")
	var rng_seed := int(String(QAPaths.user_args().get("seed", "0")))
	sim = WIGame.new(scene_config, skill_config, ObservableBus.emit_domain_event, rng_seed)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed
```

- [ ] **Step 6: Register the autoloads**

Add to `wandering_inn_game_v4/project.godot` (order matters — bus before Game):

```ini
[autoload]

ObservableBus="*res://src/core/observable_bus.gd"
Game="*res://src/core/game.gd"
```

- [ ] **Step 7: Import pass + clean boot check**

Run:
```bash
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --import
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --quit
```
Expected: exit 0, no errors/warnings. Then confirm the boot wrote an event log:
```bash
cat "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG v4/qa/events.jsonl"
```
Expected: one `sim_initialized` line.

- [ ] **Step 8: Commit**

```bash
git add wandering_inn_game_v4
git commit -m "Add ObservableBus event pipe, JSONL event log, and Game autoload owning the sim"
```

---

### Task 4: Presentation layer — world rendering, input, message layer

**Files:**
- Modify: `wandering_inn_game_v4/src/world/world.gd` (replace stub)
- Create: `wandering_inn_game_v4/src/ui/message_layer.gd`

**Interfaces:**
- Consumes: `Game.sim` (`WIGame`), `ObservableBus.domain_event` / `emit_domain_event`, input actions from Task 1.
- Produces: bus events `world_ready` (world), `ui_toast_rendered {text}` and `ui_dialogue_rendered {text}` (message layer) — Task 5's walkthrough script waits on these.

- [ ] **Step 1: Implement `world.gd` (replace the stub)**

```gdscript
extends Node2D
## Presentation layer for the walking skeleton. Renders the sim's grid and
## entities as labeled colored squares (placeholder art), forwards input
## intents to the sim, and repositions the player on bus events.
##
## All UI/visuals are built in code — no hand-authored scenes (repo principle:
## content is data + code).

const CELL := 64
const PLAYER_COLOR := Color(0.25, 0.45, 0.9)
const NPC_COLOR := Color(0.3, 0.7, 0.35)
const PROP_COLOR := Color(0.55, 0.4, 0.25)
const FLOOR_COLOR := Color(0.93, 0.88, 0.76)

var _player_rect: ColorRect


func _ready() -> void:
	_build_floor()
	_build_entities()
	_player_rect = _make_square(Game.sim.player_cell, PLAYER_COLOR, "You")
	add_child(preload("res://src/ui/message_layer.gd").new())
	ObservableBus.domain_event.connect(_on_domain_event)
	ObservableBus.emit_domain_event("world_ready", {})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		Game.sim.interact()
	elif event.is_action_pressed("move_up"):
		Game.sim.move_player(Vector2i.UP)
	elif event.is_action_pressed("move_down"):
		Game.sim.move_player(Vector2i.DOWN)
	elif event.is_action_pressed("move_left"):
		Game.sim.move_player(Vector2i.LEFT)
	elif event.is_action_pressed("move_right"):
		Game.sim.move_player(Vector2i.RIGHT)


func _build_floor() -> void:
	var floor_rect := ColorRect.new()
	floor_rect.color = FLOOR_COLOR
	floor_rect.size = Vector2(Game.sim.grid_size) * CELL
	add_child(floor_rect)


func _build_entities() -> void:
	for ent: Dictionary in Game.sim.entities.values():
		var color := NPC_COLOR if String(ent["kind"]) == "npc" else PROP_COLOR
		_make_square(ent["cell"], color, String(ent["display_name"]))


func _make_square(cell: Vector2i, color: Color, label_text: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.size = Vector2(CELL - 8, CELL - 8)
	rect.position = Vector2(cell) * CELL + Vector2(4, 4)
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(-4, -22)
	label.add_theme_color_override("font_color", Color.BLACK)
	rect.add_child(label)
	add_child(rect)
	return rect


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if type == "player_moved":
		var cell := Vector2i(int(payload["cell"][0]), int(payload["cell"][1]))
		_player_rect.position = Vector2(cell) * CELL + Vector2(4, 4)
```

- [ ] **Step 2: Implement `message_layer.gd`**

```gdscript
extends CanvasLayer
## Renders toasts and dialogue lines from ObservableBus domain events, and
## confirms actual rendering back onto the bus (ui_toast_rendered /
## ui_dialogue_rendered) so QA scripts can assert "the player saw this".
##
## GOTCHA (shipped a dead quest chain in v2): CanvasLayer has NO `modulate`
## property. Fade/tint the child Control panels, never `self`.

const TOAST_SECONDS := 2.5
const DIALOGUE_SECONDS := 3.0

var _toast_panel: PanelContainer
var _toast_label: Label
var _dialogue_panel: PanelContainer
var _dialogue_label: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_toast_panel = PanelContainer.new()
	_toast_panel.position = Vector2(160, 16)
	_toast_panel.custom_minimum_size = Vector2(320, 40)
	_toast_panel.hide()
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast_label)
	root.add_child(_toast_panel)

	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.position = Vector2(40, 330)
	_dialogue_panel.custom_minimum_size = Vector2(560, 56)
	_dialogue_panel.hide()
	_dialogue_label = Label.new()
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_panel.add_child(_dialogue_label)
	root.add_child(_dialogue_panel)

	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	match type:
		"toast":
			_show(_toast_panel, _toast_label, String(payload["text"]), TOAST_SECONDS, "ui_toast_rendered")
		"dialogue_line":
			var text := "%s: %s" % [String(payload["speaker"]), String(payload["text"])]
			_show(_dialogue_panel, _dialogue_label, text, DIALOGUE_SECONDS, "ui_dialogue_rendered")


func _show(panel: PanelContainer, label: Label, text: String, seconds: float, rendered_event: String) -> void:
	label.text = text
	panel.show()
	await get_tree().process_frame
	ObservableBus.emit_domain_event(rendered_event, {"text": text})
	await get_tree().create_timer(seconds).timeout
	panel.hide()
```

(Known M0 limitation, acceptable: overlapping messages of the same kind share one panel — the second overwrites the first.)

- [ ] **Step 3: Import pass + clean boot, brief windowed sanity run**

Run:
```bash
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --import
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --quit
```
Expected: exit 0, no errors/warnings.

Then a 5-second windowed run (a window will open and close — expected):
```bash
/usr/local/bin/godot --path wandering_inn_game_v4 --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error" || echo "CLEAN"
```
Expected: `CLEAN`.

- [ ] **Step 4: Commit**

```bash
git add wandering_inn_game_v4
git commit -m "Add walking-skeleton presentation: grid rendering, input intents, message layer"
```

---

### Task 5: TestDriver, QA scripts, runner — the Phase A payoff

**Files:**
- Create: `wandering_inn_game_v4/qa/test_driver.gd`
- Create: `wandering_inn_game_v4/qa/scripts/load_gate.json`
- Create: `wandering_inn_game_v4/qa/scripts/skeleton_walkthrough.json`
- Create: `wandering_inn_game_v4/qa/run_qa.sh` (mode `0755`)
- Modify: `wandering_inn_game_v4/project.godot` (add TestDriver autoload, after Game)

**Interfaces:**
- Consumes: `ObservableBus.domain_event`, `Game.sim.snapshot()`, input actions from Task 1.
- Produces: QA contract used by Task 6 (windowed verification) and Task 8 (web): declarative script actions `wait_frames`, `press`, `move`, `wait_for_event`, `screenshot`, `assert_state`, `assert_event_logged`, `load_all_resources`; output files `<qa-out>/result.json` (`{passed: bool, failures: [], screenshots: [], events_seen: int, script: String}`), `<qa-out>/*.png`, `<qa-out>/events.jsonl`; process exit code 0/1; stdout markers `QA_RESULT: PASS|FAIL`, `QA_FAILURE: <msg>`.

- [ ] **Step 1: Implement `qa/test_driver.gd`**

```gdscript
extends Node
## Autoload QA driver. Inert unless `--qa-script=<path>` is passed after `--`.
## Executes a declarative JSON playtest script: injects real keyboard events
## (so the full input pipeline is exercised), waits for ObservableBus events,
## captures screenshots, asserts on the sim snapshot, and writes result.json.
##
## Input injection uses InputEventKey with physical keycodes (NOT
## InputEventAction — action events don't traverse the full input pipeline).

const ACTION_KEYS := {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"interact": KEY_E,
}

var _script_path := ""
var _out_dir := ""
var _failures: PackedStringArray = []
var _events_seen: Array = []
var _screenshots: PackedStringArray = []


func _ready() -> void:
	_out_dir = QAPaths.out_dir()
	_script_path = String(QAPaths.user_args().get("qa-script", ""))
	if _script_path.is_empty() and OS.has_feature("web"):
		var js_cfg: Variant = JavaScriptBridge.eval("window.__WI_QA__ ? window.__WI_QA__.script : ''", true)
		_script_path = String(js_cfg) if js_cfg != null else ""
	if _script_path.is_empty():
		set_process(false)
		return
	ObservableBus.domain_event.connect(_on_domain_event)
	_run.call_deferred()


func _on_domain_event(type: String, payload: Dictionary) -> void:
	_events_seen.append({"type": type, "payload": payload})


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_script_path))
	if parsed == null or not (parsed is Dictionary) or not parsed.has("steps"):
		_fail("could not parse qa script: " + _script_path)
		_finish()
		return
	for step: Dictionary in parsed["steps"]:
		await _execute(step)
	_finish()


func _execute(step: Dictionary) -> void:
	match String(step["action"]):
		"wait_frames":
			for i in int(step.get("frames", 1)):
				await get_tree().process_frame
		"press":
			_inject_action(String(step["name"]))
			await get_tree().process_frame
			await get_tree().process_frame
		"move":
			for i in int(step.get("steps", 1)):
				_inject_action("move_" + String(step["direction"]))
				await get_tree().process_frame
				await get_tree().process_frame
		"wait_for_event":
			await _wait_for_event(String(step["type"]), float(step.get("timeout_sec", 5.0)))
		"screenshot":
			await _screenshot(String(step["name"]))
		"assert_state":
			_assert_state(step)
		"assert_event_logged":
			if not _has_event(String(step["type"])):
				_fail("expected event was never emitted: " + String(step["type"]))
		"load_all_resources":
			_load_all_resources()
		_:
			_fail("unknown action: " + String(step["action"]))


func _inject_action(action_name: String) -> void:
	if not ACTION_KEYS.has(action_name):
		_fail("no key mapping for action: " + action_name)
		return
	var key: Key = ACTION_KEYS[action_name]
	var press := InputEventKey.new()
	press.physical_keycode = key
	press.keycode = key
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.physical_keycode = key
	release.keycode = key
	release.pressed = false
	Input.parse_input_event(release)


func _has_event(type: String) -> bool:
	for e: Dictionary in _events_seen:
		if e["type"] == type:
			return true
	return false


func _wait_for_event(type: String, timeout_sec: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if _has_event(type):
			return
		await get_tree().process_frame
	_fail("timeout (%.1fs) waiting for event: %s" % [timeout_sec, type])


func _screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		_events_seen.append({"type": "screenshot_skipped_headless", "payload": {"name": name}})
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__WI_QA_SHOT__ = %s" % JSON.stringify(name), true)
		var deadline := Time.get_ticks_msec() + 10000
		while Time.get_ticks_msec() < deadline:
			var pending: Variant = JavaScriptBridge.eval("window.__WI_QA_SHOT__", true)
			if pending == null:
				_screenshots.append(name + ".png")
				return
			await get_tree().process_frame
		_fail("web screenshot never acknowledged: " + name)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var path := _out_dir.path_join(name + ".png")
	img.save_png(path)
	_screenshots.append(path)


func _assert_state(step: Dictionary) -> void:
	var snap: Dictionary = Game.sim.snapshot()
	var cur: Variant = snap
	for key: String in String(step["path"]).split("."):
		if cur is Dictionary and cur.has(key):
			cur = cur[key]
		else:
			_fail("assert_state: path not found: " + String(step["path"]))
			return
	if not _loosely_equal(cur, step["equals"]):
		_fail("assert_state: %s expected %s, got %s" % [String(step["path"]), str(step["equals"]), str(cur)])


## JSON numbers parse as floats; sim state uses ints/bools. Compare loosely.
func _loosely_equal(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _loosely_equal(a[i], b[i]):
				return false
		return true
	return a == b


## The script-load gate: load every .gd/.tscn/.tres in the project. A parse
## error in ANY script fails the run — this is the class of bug that shipped
## v2's dead quest chain (load-time parse error in level_up_toast.gd).
func _load_all_resources() -> void:
	var to_scan: Array[String] = ["res://"]
	var loaded := 0
	while not to_scan.is_empty():
		var dir_path: String = to_scan.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.include_hidden = false
		for sub: String in dir.get_directories():
			if sub.begins_with(".") or sub in ["addons", "build", "node_modules"]:
				continue
			to_scan.append(dir_path.path_join(sub))
		for f: String in dir.get_files():
			if f.get_extension() in ["gd", "tscn", "tres"]:
				var p := dir_path.path_join(f)
				if ResourceLoader.load(p) == null:
					_fail("failed to load resource: " + p)
				else:
					loaded += 1
	_events_seen.append({"type": "load_gate_done", "payload": {"loaded": loaded}})
	if loaded == 0:
		_fail("load gate scanned zero resources — scan is broken")


func _fail(msg: String) -> void:
	_failures.append(msg)


func _finish() -> void:
	var result := {
		"passed": _failures.is_empty(),
		"failures": Array(_failures),
		"screenshots": Array(_screenshots),
		"events_seen": _events_seen.size(),
		"script": _script_path,
	}
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var f := FileAccess.open(_out_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "  "))
	f.close()
	print("QA_RESULT: " + ("PASS" if _failures.is_empty() else "FAIL"))
	for failure: String in _failures:
		print("QA_FAILURE: " + failure)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__WI_RESULT__ = %s" % JSON.stringify(result), true)
	else:
		get_tree().quit(0 if _failures.is_empty() else 1)
```

- [ ] **Step 2: Register the autoload**

In `wandering_inn_game_v4/project.godot`, `[autoload]` section, add **after** `Game` (TestDriver depends on both):

```ini
TestDriver="*res://qa/test_driver.gd"
```

- [ ] **Step 3: Write the two QA scripts**

`wandering_inn_game_v4/qa/scripts/load_gate.json`:

```json
{
	"steps": [
		{ "action": "wait_frames", "frames": 5 },
		{ "action": "load_all_resources" }
	]
}
```

`wandering_inn_game_v4/qa/scripts/skeleton_walkthrough.json` — the full player journey. Player starts at [2,3]; Erin (npc) at [7,2]; Dirty Table (prop) at [5,4]. Moving into an occupied cell is blocked but sets facing:

```json
{
	"steps": [
		{ "action": "wait_frames", "frames": 10 },
		{ "action": "wait_for_event", "type": "world_ready", "timeout_sec": 5 },
		{ "action": "screenshot", "name": "01_start" },
		{ "action": "move", "direction": "up", "steps": 1 },
		{ "action": "move", "direction": "right", "steps": 4 },
		{ "action": "move", "direction": "right", "steps": 1 },
		{ "action": "press", "name": "interact" },
		{ "action": "wait_for_event", "type": "dialogue_line", "timeout_sec": 5 },
		{ "action": "wait_for_event", "type": "ui_dialogue_rendered", "timeout_sec": 5 },
		{ "action": "screenshot", "name": "02_erin_dialogue" },
		{ "action": "move", "direction": "down", "steps": 2 },
		{ "action": "move", "direction": "left", "steps": 1 },
		{ "action": "press", "name": "interact" },
		{ "action": "wait_for_event", "type": "skill_used", "timeout_sec": 5 },
		{ "action": "wait_for_event", "type": "toast", "timeout_sec": 5 },
		{ "action": "wait_for_event", "type": "ui_toast_rendered", "timeout_sec": 5 },
		{ "action": "screenshot", "name": "03_skill_toast" },
		{ "action": "assert_state", "path": "accomplishments.cleaned_the_inn", "equals": true },
		{ "action": "assert_state", "path": "player_cell", "equals": [6, 4] },
		{ "action": "assert_event_logged", "type": "accomplishment_recorded" },
		{ "action": "screenshot", "name": "04_final" }
	]
}
```

- [ ] **Step 4: Write the runner**

`wandering_inn_game_v4/qa/run_qa.sh` (then `chmod +x`):

```bash
#!/usr/bin/env bash
# Run a declarative QA script against the game.
# Usage: qa/run_qa.sh <script-name> [headless|windowed]
#   script-name: basename of a file in qa/scripts/ (no .json)
#   mode: headless (default; screenshots skipped) or windowed (screenshots saved)
set -u
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:?usage: run_qa.sh <script-name> [headless|windowed]}"
MODE="${2:-headless}"
OUT="$PROJ/qa_output/$NAME"
rm -rf "$OUT"
mkdir -p "$OUT"
FLAGS=""
if [ "$MODE" = "headless" ]; then
	FLAGS="--headless"
fi
/usr/local/bin/godot $FLAGS --path "$PROJ" -- "--qa-script=res://qa/scripts/$NAME.json" "--qa-out=$OUT"
CODE=$?
echo "--- result.json ---"
cat "$OUT/result.json" 2>/dev/null || echo "(missing result.json)"
echo ""
exit $CODE
```

- [ ] **Step 5: Run the load gate headless — verify it passes**

```bash
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --import
wandering_inn_game_v4/qa/run_qa.sh load_gate headless
```
Expected: `QA_RESULT: PASS`, result.json `"passed": true`, exit 0.

- [ ] **Step 6: Prove the load gate catches the v2 bug class**

Temporarily add a line referencing `modulate` at the top of `message_layer.gd`'s `_ready()` — no, simpler and closer to the real bug: temporarily create `wandering_inn_game_v4/src/ui/broken_probe.gd` containing:

```gdscript
extends CanvasLayer
var x := modulate
```

Run `wandering_inn_game_v4/qa/run_qa.sh load_gate headless`.
Expected: `QA_RESULT: FAIL` with `QA_FAILURE: failed to load resource: res://src/ui/broken_probe.gd`, exit 1.

Delete `broken_probe.gd` (and its `.uid` if generated), re-run, confirm PASS again.

- [ ] **Step 7: Run the walkthrough headless — verify the full journey passes**

```bash
wandering_inn_game_v4/qa/run_qa.sh skeleton_walkthrough headless
```
Expected: `QA_RESULT: PASS`, exit 0, result.json shows 4 screenshots skipped (headless) and `"passed": true`. `qa_output/skeleton_walkthrough/events.jsonl` contains `dialogue_line`, `ui_dialogue_rendered`, `skill_used`, `toast`, `ui_toast_rendered`, `accomplishment_recorded`.

**Contingency (do NOT silently work around):** if injected key events do not reach `_unhandled_input` under `--headless`, stop and report back in the task summary — the fallback design (a `--qa-input=direct` mode where `move`/`press` call `Game.sim` intents directly, keeping key injection for windowed/web) needs lead sign-off before implementing.

- [ ] **Step 8: Commit**

```bash
git add wandering_inn_game_v4
git commit -m "Add TestDriver QA harness: declarative playtest scripts, load gate, runner"
```

---

### Task 6: Phase A verification (windowed screenshots) + project docs

**Files:**
- Create: `wandering_inn_game_v4/CLAUDE.md`
- Modify: `/Users/gabriel/wandering_inn_rpg/CLAUDE.md` (repo root — active-project pointer)
- Modify: `/Users/gabriel/wandering_inn_rpg/HANDOFF.md`

- [ ] **Step 1: Run the walkthrough windowed and verify screenshots**

```bash
wandering_inn_game_v4/qa/run_qa.sh skeleton_walkthrough windowed
```
(A game window opens and closes by itself — expected.)
Expected: `QA_RESULT: PASS`, exit 0, and 4 PNGs in `wandering_inn_game_v4/qa_output/skeleton_walkthrough/`.

Verify the PNGs are non-trivial (not black/empty):
```bash
ls -la wandering_inn_game_v4/qa_output/skeleton_walkthrough/*.png
file wandering_inn_game_v4/qa_output/skeleton_walkthrough/*.png
```
Expected: 4 PNGs, each > 5 KB, `640 x 400` per `file` output.

Then **visually read** `02_erin_dialogue.png` (dialogue panel with Erin's line visible at bottom) and `03_skill_toast.png` (toast `[Basic Cleaning] — The table is spotless.` visible at top) with the Read tool. This step is the point of the whole spike — an agent confirming player-visible output without a human.

- [ ] **Step 2: Write `wandering_inn_game_v4/CLAUDE.md`**

```markdown
# CLAUDE.md

Guidance for Claude Code when working in `wandering_inn_game_v4/` — the active
Wandering Inn RPG project (M0: agent-QA foundation + walking skeleton).

## What this is

A fresh Godot 4.7 project built QA-first: every feature must be verifiable
by an agent without a human playtest. See
`docs/superpowers/specs/2026-07-01-wandering-inn-v4-agent-qa-foundation-design.md`
for the architecture rationale and north star (BG3-in-Wandering-Inn, team of 1,
[Skills] usable outside combat).

**Product constraints (repo-wide, non-negotiable):** never show raw stat
numbers (STR/DEX/etc.) to the player. Lore canon comes from the Wandering Inn
Wiki, not invention.

## Commands

	# Run the game (windowed)
	/usr/local/bin/godot --path wandering_inn_game_v4

	# Import pass — REQUIRED after creating any new .gd file (class_name registration)
	/usr/local/bin/godot --headless --path wandering_inn_game_v4 --import

	# Headless smoke check
	/usr/local/bin/godot --headless --path wandering_inn_game_v4 --quit

	# Unit tests (pure classes only — SceneTree scripts, run individually)
	/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_sim_core.gd
	/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_event_log.gd

	# QA playtest scripts (THE verification tool — prefer this over manual reasoning)
	wandering_inn_game_v4/qa/run_qa.sh load_gate headless          # loads every .gd/.tscn/.tres; catches parse errors
	wandering_inn_game_v4/qa/run_qa.sh skeleton_walkthrough headless   # full player journey, no screenshots
	wandering_inn_game_v4/qa/run_qa.sh skeleton_walkthrough windowed   # same + screenshots (a window opens briefly)
	# Output: qa_output/<script>/result.json, events.jsonl, *.png — read the PNGs to see what a player sees

This is a fresh project with ZERO known-harmless warnings. Any SCRIPT ERROR,
Parse Error, or WARNING in any run is a regression.

## Architecture

- **Sim core (`src/core/wi_game.gd`)** — `WIGame`, a pure RefCounted simulation.
  PURITY RULE: no autoload, Node, or scene-tree references in sim code, ever.
  Dependencies are injected (config Dictionaries, event-sink Callable, seed).
  This keeps the sim testable headless and mass-simulatable.
- **ObservableBus (autoload)** — the single pipe for every player-visible /
  QA-relevant domain event. `emit_domain_event(type, payload)` logs JSONL and
  emits a signal. NEVER print() anything a player should see; put it on the bus
  and let a UI node render it. UI nodes emit `ui_*_rendered` confirmations back
  onto the bus after actually showing something.
- **Game (autoload)** — owns the `WIGame` instance; wires its event sink to the bus.
- **Presentation (`src/world/world.gd`, `src/ui/message_layer.gd`)** — thin:
  forwards input intents to `Game.sim`, renders state from bus events. All UI
  is built in code; content lives in `data/*.json`. No hand-authored .tscn
  beyond the trivial `src/world/world.tscn` root.
- **TestDriver (autoload, `qa/test_driver.gd`)** — inert unless
  `--qa-script=...` is passed after `--`. Executes declarative JSON playtests:
  injects real keyboard events, waits for bus events, screenshots, asserts on
  `Game.sim.snapshot()`, writes result.json, exits 0/1.

## Working conventions

- When you add ANY player-visible feature, extend a QA script (or add a new one
  in `qa/scripts/`) that walks it and asserts both the domain event AND the
  `ui_*_rendered` confirmation, then run it before claiming the feature works.
- Content is data + code: new entities/skills go in `data/*.json`; new
  behavior goes in the sim; presentation only renders.
- Tests are plain SceneTree scripts under `tests/` (no GUT/gdUnit). Pure
  classes only — anything needing autoloads is QA-script territory instead.
- GDQuest GDScript style: tabs, static typing, `class_name` + `##` doc comments.

## Gotchas

- `CanvasLayer` has no `modulate` — tint/fade child Controls instead (this
  exact bug shipped a dead quest chain in v2).
- `--script`-mode runs don't resolve autoloads as bare identifiers — that's why
  the purity rule exists; don't reference autoloads from `src/core/` or `tests/`.
- Commit generated `*.uid` sidecars alongside new `.gd` files.

## GodotPrompter

This is a Godot project with GodotPrompter skills available. Before
implementing any game system, you MUST check for a matching `godot-prompter:*`
skill and invoke it. This applies to all agents, subagents, and sessions
working in this repository.

Key skills: `gdscript-patterns`, `scene-organization`, `component-system`,
`resource-pattern`, `event-bus`, `godot-ui`, `state-machine`, `godot-testing`.

For the full skill list, invoke `godot-prompter:using-godot-prompter`.
```

- [ ] **Step 3: Update root `CLAUDE.md`**

In `/Users/gabriel/wandering_inn_rpg/CLAUDE.md`, "Repo Layout" section, change the `wandering_inn_game_v2/` bullet's bold tail from "**This is where nearly all current work happens.**" to "**Frozen as a reference implementation as of 2026-07-01 — do not build on it; mine it.**", and add a new first bullet:

```markdown
- **`wandering_inn_game_v4/`** — the active project. A fresh Godot 4.7 build (no GDQuest base) designed QA-first for agent-driven development: pure sim core, ObservableBus event log, declarative QA playtest scripts (`qa/run_qa.sh`). Has its own `CLAUDE.md` — read it when working here.
```

Also update the "Commands" section's three example commands to point at `wandering_inn_game_v4` and mention `wandering_inn_game_v4/qa/run_qa.sh <script> headless|windowed` as the primary verification tool (keep the v2 commands in place, labeled as applying to the frozen reference project).

- [ ] **Step 4: Update `HANDOFF.md`**

Replace the "Next Step" section's body with the current truth: M0 spike Phase A complete (list the passing commands and where outputs land), Phase B (web export + Playwright) next, per the plan file `docs/superpowers/plans/2026-07-01-wandering-inn-v4-agent-qa-foundation.md`. Note that `wandering_inn_game_v4/` is now the active project and its `CLAUDE.md` documents the QA loop.

- [ ] **Step 5: Commit**

```bash
git add wandering_inn_game_v4/CLAUDE.md CLAUDE.md HANDOFF.md
git commit -m "Document v4 QA-first project; mark v2 frozen; log Phase A completion"
```

---

### Task 7: Web export pipeline (Phase B, part 1)

**Files:**
- Create: `wandering_inn_game_v4/export_presets.cfg`
- Create: `wandering_inn_game_v4/qa/web/export_web.sh` (mode `0755`)

**Interfaces:**
- Produces: `wandering_inn_game_v4/build/web/index.html` + `.wasm`/`.pck`/`.js` artifacts consumed by Task 8's Playwright runner.

- [ ] **Step 1: Ensure export templates are installed**

```bash
TPL_DIR="$HOME/Library/Application Support/Godot/export_templates/4.7.stable"
ls "$TPL_DIR" 2>/dev/null | grep -q web_nothreads_release.zip && echo "TEMPLATES OK" || echo "TEMPLATES MISSING"
```

If MISSING:
```bash
curl -L -o /tmp/godot_templates.tpz "https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_export_templates.tpz"
mkdir -p "$HOME/Library/Application Support/Godot/export_templates/4.7.stable"
cd /tmp && unzip -o -q godot_templates.tpz
cp /tmp/templates/* "$HOME/Library/Application Support/Godot/export_templates/4.7.stable/"
```
Re-run the check; expected `TEMPLATES OK`. (~1 GB download — this is one-time per machine.)

- [ ] **Step 2: Create `export_presets.cfg`**

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="qa/scripts/*.json,data/*.json"
exclude_filter=""
export_path="build/web/index.html"

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
```

(`thread_support=false` is deliberate: the no-threads build runs without COOP/COEP isolation headers, so a plain static file server works. `include_filter` guarantees the QA script and data JSONs are packed even though they're non-resource files.)

- [ ] **Step 3: Create `qa/web/export_web.sh`**

```bash
#!/usr/bin/env bash
# Export the web build. Usage: qa/web/export_web.sh
set -euo pipefail
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$PROJ/build/web"
/usr/local/bin/godot --headless --path "$PROJ" --export-release "Web" build/web/index.html
ls -la "$PROJ/build/web"
```

- [ ] **Step 4: Run the export and verify artifacts**

```bash
chmod +x wandering_inn_game_v4/qa/web/export_web.sh
wandering_inn_game_v4/qa/web/export_web.sh
```
Expected: exit 0; `build/web/` contains `index.html`, `index.wasm`, `index.pck`, `index.js`. If the export logs template errors, re-check Step 1.

- [ ] **Step 5: Commit**

```bash
git add wandering_inn_game_v4/export_presets.cfg wandering_inn_game_v4/qa/web/export_web.sh
git commit -m "Add web export preset and script (no-threads build for header-free serving)"
```

---

### Task 8: Playwright runner (Phase B, part 2)

**Files:**
- Create: `wandering_inn_game_v4/qa/web/package.json`
- Create: `wandering_inn_game_v4/qa/web/run_web_qa.mjs`
- Create: `wandering_inn_game_v4/qa/web/run_web_qa.sh` (mode `0755`)
- Modify: `/Users/gabriel/wandering_inn_rpg/HANDOFF.md` (Phase B outcome)

**Interfaces:**
- Consumes: `build/web/` artifacts (Task 7); TestDriver's web protocol (Task 5): reads script path from `window.__WI_QA__.script`, requests screenshots via `window.__WI_QA_SHOT__` (string name; runner screenshots then sets it to `null`), publishes final result to `window.__WI_RESULT__`.
- Produces: `qa_output/web_<script>/*.png` + `result.json`; process exit 0/1. This is the fully-headless agent QA loop.

- [ ] **Step 1: Create the Node package and install Playwright**

`wandering_inn_game_v4/qa/web/package.json`:

```json
{
	"name": "wi-v4-web-qa",
	"private": true,
	"type": "module",
	"dependencies": {
		"playwright": "^1.49.0"
	}
}
```

```bash
cd wandering_inn_game_v4/qa/web && npm install && npx playwright install chromium
```
Expected: installs cleanly (chromium download is one-time, ~150 MB).

- [ ] **Step 2: Write `run_web_qa.mjs`**

```javascript
// Drive the Godot web export through a QA script under headless Chromium.
// Usage: node run_web_qa.mjs <script-name>
// Serves build/web/ on a local port, loads the game with window.__WI_QA__ set,
// polls for screenshot requests (__WI_QA_SHOT__) and the final result
// (__WI_RESULT__). All assertions run in-engine; this runner is only the
// renderer, screenshot hands, and result reader.
import { createServer } from "node:http";
import { readFile, writeFile, mkdir, rm } from "node:fs/promises";
import { join, dirname, extname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const scriptName = process.argv[2];
if (!scriptName) {
	console.error("usage: node run_web_qa.mjs <script-name>");
	process.exit(2);
}

const here = dirname(fileURLToPath(import.meta.url));
const projRoot = resolve(here, "../..");
const webRoot = join(projRoot, "build/web");
const outDir = join(projRoot, "qa_output", `web_${scriptName}`);
const PORT = 8060;
const TIMEOUT_MS = 120_000;

const MIME = {
	".html": "text/html",
	".js": "text/javascript",
	".wasm": "application/wasm",
	".pck": "application/octet-stream",
	".png": "image/png",
	".ico": "image/x-icon",
	".json": "application/json",
};

const server = createServer(async (req, res) => {
	const path = join(webRoot, req.url === "/" ? "index.html" : req.url.split("?")[0]);
	try {
		const body = await readFile(path);
		res.writeHead(200, { "Content-Type": MIME[extname(path)] ?? "application/octet-stream" });
		res.end(body);
	} catch {
		res.writeHead(404);
		res.end("not found");
	}
});

await rm(outDir, { recursive: true, force: true });
await mkdir(outDir, { recursive: true });
await new Promise((ok) => server.listen(PORT, "127.0.0.1", ok));

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 640, height: 400 } });
page.on("console", (msg) => {
	const text = msg.text();
	if (text.startsWith("QA_")) console.log(`[game] ${text}`);
});
await page.addInitScript((name) => {
	window.__WI_QA__ = { script: `res://qa/scripts/${name}.json` };
}, scriptName);
await page.goto(`http://127.0.0.1:${PORT}/index.html`);

const deadline = Date.now() + TIMEOUT_MS;
let result = null;
while (Date.now() < deadline) {
	const shot = await page.evaluate(() => window.__WI_QA_SHOT__ ?? null);
	if (shot) {
		await page.screenshot({ path: join(outDir, `${shot}.png`) });
		await page.evaluate(() => {
			window.__WI_QA_SHOT__ = null;
		});
	}
	result = await page.evaluate(() => window.__WI_RESULT__ ?? null);
	if (result) break;
	await new Promise((ok) => setTimeout(ok, 100));
}

await browser.close();
server.close();

if (!result) {
	console.error(`FAIL: no result within ${TIMEOUT_MS / 1000}s (game never finished the QA script)`);
	process.exit(1);
}
await writeFile(join(outDir, "result.json"), JSON.stringify(result, null, 2));
console.log(`result: ${JSON.stringify(result, null, 2)}`);
console.log(`outputs in: ${outDir}`);
process.exit(result.passed ? 0 : 1);
```

- [ ] **Step 3: Write `run_web_qa.sh`**

```bash
#!/usr/bin/env bash
# Full headless web QA: (re-)export, then drive under headless Chromium.
# Usage: qa/web/run_web_qa.sh <script-name> [--skip-export]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:?usage: run_web_qa.sh <script-name> [--skip-export]}"
if [ "${2:-}" != "--skip-export" ]; then
	"$HERE/export_web.sh"
fi
cd "$HERE" && node run_web_qa.mjs "$NAME"
```

- [ ] **Step 4: Run the full headless web QA loop**

```bash
chmod +x wandering_inn_game_v4/qa/web/run_web_qa.sh
wandering_inn_game_v4/qa/web/run_web_qa.sh skeleton_walkthrough
```
Expected: exit 0; `qa_output/web_skeleton_walkthrough/` contains `result.json` (`"passed": true`) and 4 PNGs. Visually read `02_erin_dialogue.png` and `03_skill_toast.png` — dialogue and toast must be legible, as in Task 6.

**Kill criterion (from the spec):** if headless Chromium cannot render/drive the export reliably within ~2 working sessions of debugging, STOP — report back rather than sinking more time. Phase A (Task 6's windowed rig) then becomes the standing QA loop.

- [ ] **Step 5: Update `HANDOFF.md` with the Phase B outcome and commit**

Record: Phase B works (or was killed, and why), the exact commands for both QA loops, and that M0 is complete pending the final whole-branch review.

```bash
git add wandering_inn_game_v4/qa/web HANDOFF.md
git commit -m "Add Playwright headless web QA runner — full agent QA loop complete"
```

---

## Self-Review Notes

- Spec coverage: ObservableBus (T3), TestDriver (T5), script-load gate (T5 incl. a deliberate broken-script probe), walkthrough with skill-on-prop beat (T2/T5), screenshots agents read (T6/T8), deterministic seed plumb-through (T3 `--seed`, sim RNG in T2), Playwright rig + kill criterion (T7/T8), CLAUDE.md/HANDOFF deliverables (T6/T8), three historical bug classes each mapped to a catch (load gate; `ui_*_rendered` bus confirmations; real-input walkthrough + snapshot asserts).
- The final whole-branch review is part of the subagent-driven-development process, not a plan task — **do not skip it** (it caught v3's dead quest chain).
- Type consistency checked: `WIGame` API (T2) matches T3 (`Game.sim`), T4 (`move_player`/`interact`), T5 (`snapshot()`); `QAPaths` API matches T3/T5 use; TestDriver web protocol (T5) matches T8's runner.
