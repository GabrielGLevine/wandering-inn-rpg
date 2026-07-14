# Wandering Inn M1 — Tactical Combat + Progression Spine Implementation Plan

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tactical AP-pool combat (pure `WICombat` sim, skill-effect registry, role AI), data-driven progression (`WIProgression`, sleep-beat leveling), a 200-run balance harness, functional-minimal combat UI, and QA playtest scripts — delivering the loop: fight → win → sleep → Fighter 2 → Counter Strike live in fight 2.

**Architecture:** `WICombat` is a per-encounter pure RefCounted sim (same purity rule as `WIGame`): grid, 4-AP turns, precomputed initiative, seeded RNG, reactions at `on_hit_received`/`on_kill` hooks. `WIGame` triggers combat from a new `encounter` entity kind, consumes the outcome into accomplishment **counters**, and resolves level-ups only at the Bed via pure `WIProgression` reading `classes.json`. Presentation (combat screen) and AI both drive the sim through the same intent methods; the balance harness runs 200 seeded AI-vs-AI fights with no scene tree at all.

**Tech Stack:** Godot 4.7 GDScript (statically typed), JSON data, existing M0 QA harness (TestDriver/ObservableBus/run_qa.sh).

**Spec:** `docs/superpowers/specs/2026-07-01-wandering-inn-m1-tactical-combat-design.md` — read it first.

## Global Constraints

- Godot binary: `/usr/local/bin/godot`, version **4.7.stable**. Repo root `/Users/gabriel/wandering_inn_rpg`; branch `main` directly; commit per task with trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- **Purity rule:** everything under `src/core/` references no autoload, Node, or scene-tree API. Dependencies injected (configs, event-sink Callable, seed).
- After creating any `.gd`: `/usr/local/bin/godot --headless --path wandering_inn_game_v4 --import` before tests; commit `*.uid` sidecars.
- Zero `SCRIPT ERROR` / `Parse Error` / `WARNING` in any run — fresh-project rule, no normalized noise.
- **All randomness through the injected `rng`.** Never roll inside a sort comparator — initiative values are precomputed then sorted.
- **No raw stat numbers player-visible** (STR/DEX/etc.). HP bars + AP pips + prose event text only; **no damage numbers in UI**. Exact numbers go in sim events (QA reads them there).
- Every player-visible message flows through ObservableBus; UI emits `ui_*_rendered` confirmations.
- Combat rules (exact): grid 12×8; 4 AP/turn; move 1 AP/cell (4-dir); basic attack 2 AP (melee = Chebyshev ≤ 1); base hit 85; round cap 30 (draw = non-victory); initiative = DEX + seeded d6, precomputed, fixed whole fight; riposte = 80% weapon damage, melee-incoming only, no chains; Battle Momentum +1 AP on kill, once per turn.
- GDScript style: tabs, static typing, `class_name` + `##` doc comments.
- Tests: plain SceneTree scripts under `tests/`, run individually via `--script`.

## File Structure

```
src/core/wi_game.gd               # T1 counters + diagnostics; T7 combat handoff + sleep beat
src/core/combat/wi_combat.gd      # T3 — WICombat pure sim
src/core/combat/skill_effects.gd  # T4 — WISkillEffects registry
src/core/combat/combat_ai.gd      # T5 — WICombatAI role profiles
src/core/progression.gd           # T6 — WIProgression
src/combat/combat_screen.gd       # T8 — combat presentation
src/world/world.gd                # T8 — input gating + entity removal
data/skills.json                  # T2 — combat tranche added
data/combatants.json, classes.json, arenas.json   # T2
data/skeleton_scene.json          # T7 — encounters + bed + player classes
tests/test_sim_core.gd            # T1 — counter semantics
tests/test_combat_data.gd         # T2
tests/test_combat_sim.gd          # T3 core rules + determinism; T4 extends (effects/reactions)
tests/test_progression.gd         # T6
tests/sim_combat_batch.gd         # T5 — balance harness
qa/test_driver.gd                 # T9 — assert paths, payload match, combat_autoplay, keys
qa/run_qa.sh                      # T9 — extra-arg passthrough (--seed)
qa/scripts/combat_walkthrough.json, level_up_loop.json   # T9
qa/scripts/skeleton_walkthrough.json  # T1 — equals 1 instead of true
project.godot                     # T8 — confirm/cancel/cycle input actions
wandering_inn_game_v4/CLAUDE.md   # T10
```

---

### Task 1: Accomplishment counters + sim diagnostics

**Files:**
- Modify: `wandering_inn_game_v4/src/core/wi_game.gd`
- Modify: `wandering_inn_game_v4/tests/test_sim_core.gd`
- Modify: `wandering_inn_game_v4/qa/scripts/skeleton_walkthrough.json`

**Interfaces:**
- Produces: `accomplishments: Dictionary` now maps id → **int count**. `record_accomplishment(id)` increments and emits `accomplishment_recorded {id, count}`. New `accomplishment_count(id: String) -> int` (0 when absent). `interact()` gains a `_:` match arm emitting `interact_unhandled {kind, id}`; `use_skill()` distinguishes `skill_unknown {skill}` (actor lacks skill) from `skill_no_effect {skill, target}` (target lacks `on_skill_use`).

- [ ] **Step 1: Update the test to the new semantics (failing first)**

In `tests/test_sim_core.gd` replace the idempotency + snapshot assertions:

```gdscript
	# Counter semantics: re-use increments the count, event fires each time
	game.interact()
	assert(_count("skill_used") == 2, "second use still emits skill_used")
	assert(_count("accomplishment_recorded") == 2, "counter records each increment")
	assert(game.accomplishment_count("cleaned_the_inn") == 2, "count is 2 after two uses")
	assert(game.accomplishment_count("never_done") == 0, "absent id counts 0")
```

and in the snapshot section:

```gdscript
	assert(snap["accomplishments"]["cleaned_the_inn"] == 2, "snapshot carries counts")
```

Also add, after the unknown-skill assertion:

```gdscript
	# Diagnostic events for unhandled cases
	var stray := game.use_skill("basic_cleaning", "erin")
	assert(stray.is_empty(), "skill on target without on_skill_use returns empty")
	assert(_count("skill_no_effect") == 1, "skill_no_effect emitted for inert target")
```

- [ ] **Step 2: Run to verify failure**

`/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_sim_core.gd`
Expected: assertion failure (accomplishment_recorded count / missing method).

- [ ] **Step 3: Implement in `wi_game.gd`**

Replace `record_accomplishment` and add the count accessor:

```gdscript
func record_accomplishment(id: String) -> void:
	accomplishments[id] = int(accomplishments.get(id, 0)) + 1
	_emit("accomplishment_recorded", {"id": id, "count": accomplishments[id]})


func accomplishment_count(id: String) -> int:
	return int(accomplishments.get(id, 0))
```

In `interact()`, add a default arm to the `match`:

```gdscript
		_:
			_emit("interact_unhandled", {"kind": String(target["kind"]), "id": String(target["id"])})
			return {}
```

In `use_skill()`, split the second failure path:

```gdscript
	if target.is_empty() or not target.has("on_skill_use"):
		_emit("skill_no_effect", {"skill": skill_id, "target": target_id})
		return {}
```

(The first path — actor lacks the skill — keeps emitting `skill_unknown {skill}`.)

- [ ] **Step 4: Import, run test (PASS), update the QA script assertion**

In `qa/scripts/skeleton_walkthrough.json` change
`{ "action": "assert_state", "path": "accomplishments.cleaned_the_inn", "equals": true }`
to `"equals": 1`.

Run:
```
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --import
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_sim_core.gd
wandering_inn_game_v4/qa/run_qa.sh skeleton_walkthrough headless
wandering_inn_game_v4/qa/run_qa.sh load_gate headless
```
Expected: PASS / QA_RESULT: PASS / QA_RESULT: PASS.

- [ ] **Step 5: Commit**

`git add wandering_inn_game_v4 && git commit -m "Generalize accomplishments to counters; add sim diagnostic events"`

---

### Task 2: Combat data files + validation test

**Files:**
- Modify: `wandering_inn_game_v4/data/skills.json`
- Create: `wandering_inn_game_v4/data/combatants.json`, `data/classes.json`, `data/arenas.json`
- Test: `wandering_inn_game_v4/tests/test_combat_data.gd`

**Interfaces:**
- Produces the exact data shapes every later task consumes. Combat skill entries add `ap_cost: int` and `effect: {type, ...}`; `contexts` arrays now include `"combat"`. Combatant entries: `{id, display_name, side, stats: {str,dex,con,int,wis,cha}, weapon_die: int, ai: String, skills: Array[String]}` (pc entry has `"skills": []` — class grants supply them). Class levels: `{level, requires: {accomplishment_id: min_count}, grants: [skill ids]}`.

- [ ] **Step 1: Extend `data/skills.json`** — append to the `skills` array (keep `basic_cleaning` untouched):

```json
		{
			"id": "basic_swordwork",
			"display_name": "[Basic Swordwork]",
			"contexts": ["combat"],
			"ap_cost": 0,
			"effect": { "type": "hit_bonus", "amount": 5 },
			"description": "Steadier hands with any blade."
		},
		{
			"id": "tough_body",
			"display_name": "[Tough Body]",
			"contexts": ["combat"],
			"ap_cost": 0,
			"effect": { "type": "hp_bonus", "amount": 10 },
			"description": "A frame hardened by work and worse."
		},
		{
			"id": "power_strike",
			"display_name": "[Power Strike]",
			"contexts": ["combat"],
			"ap_cost": 3,
			"effect": { "type": "damage_mult", "mult": 2.0 },
			"description": "Everything behind one blow."
		},
		{
			"id": "counter_strike",
			"display_name": "[Counter Strike]",
			"contexts": ["combat"],
			"ap_cost": 0,
			"effect": { "type": "riposte", "mult": 0.8 },
			"description": "The next blade that finds you meets an answer."
		},
		{
			"id": "battle_momentum",
			"display_name": "[Battle Momentum]",
			"contexts": ["combat"],
			"ap_cost": 0,
			"effect": { "type": "ap_on_kill", "amount": 1 },
			"description": "A felled foe quickens the blood."
		},
		{
			"id": "flame_bolt",
			"display_name": "[Flame Bolt]",
			"contexts": ["combat"],
			"ap_cost": 2,
			"effect": { "type": "spell_damage", "die": 6, "range": 4 },
			"description": "A hissing dart of goblin fire."
		}
```

- [ ] **Step 2: Create `data/combatants.json`**

```json
{
	"combatants": [
		{
			"id": "pc",
			"display_name": "Traveler",
			"side": "player",
			"stats": { "str": 12, "dex": 10, "con": 12, "int": 8, "wis": 8, "cha": 10 },
			"weapon_die": 6,
			"ai": "",
			"skills": []
		},
		{
			"id": "relc",
			"display_name": "Relc",
			"side": "player",
			"stats": { "str": 14, "dex": 12, "con": 14, "int": 8, "wis": 8, "cha": 8 },
			"weapon_die": 6,
			"ai": "melee",
			"skills": ["basic_swordwork"]
		},
		{
			"id": "goblin_raider",
			"display_name": "Goblin Raider",
			"side": "enemy",
			"stats": { "str": 10, "dex": 12, "con": 6, "int": 6, "wis": 6, "cha": 6 },
			"weapon_die": 4,
			"ai": "melee",
			"skills": []
		},
		{
			"id": "goblin_shaman",
			"display_name": "Goblin Shaman",
			"side": "enemy",
			"stats": { "str": 6, "dex": 10, "con": 6, "int": 12, "wis": 10, "cha": 6 },
			"weapon_die": 4,
			"ai": "ranged",
			"skills": ["flame_bolt"]
		}
	]
}
```

(Numbers are the starting balance guess; Task 5's batch harness is the authority and may tune them — data edits only, reported in that task.)

- [ ] **Step 3: Create `data/classes.json`**

```json
{
	"classes": [
		{
			"id": "fighter",
			"display_name": "Fighter",
			"levels": [
				{ "level": 1, "requires": {}, "grants": ["basic_swordwork", "tough_body", "power_strike"] },
				{ "level": 2, "requires": { "won_combat": 1 }, "grants": ["counter_strike", "battle_momentum"] }
			]
		}
	]
}
```

- [ ] **Step 4: Create `data/arenas.json`**

```json
{
	"arenas": [
		{
			"id": "goblin_ambush",
			"grid": { "width": 12, "height": 8 },
			"blocked": [[5, 3], [6, 4], [3, 5], [8, 2]],
			"player_spawns": [[2, 3], [2, 4], [1, 3], [1, 4]],
			"enemy_spawns": [[9, 3], [9, 4], [10, 3], [10, 4]]
		}
	]
}
```

- [ ] **Step 5: Write and run the validation test**

`tests/test_combat_data.gd`:

```gdscript
extends SceneTree
## Validates combat data shapes and cross-references.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_combat_data.gd


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON: " + path)
	return parsed


func _init() -> void:
	var skills := _load("res://data/skills.json")
	var combatants := _load("res://data/combatants.json")
	var classes := _load("res://data/classes.json")
	var arenas := _load("res://data/arenas.json")

	var skill_ids := {}
	for s: Dictionary in skills["skills"]:
		skill_ids[String(s["id"])] = true
		assert(s.has("contexts") and s.has("display_name"), "skill missing fields: " + String(s["id"]))
		if (s["contexts"] as Array).has("combat"):
			assert(s.has("ap_cost") and s.has("effect"), "combat skill missing ap_cost/effect: " + String(s["id"]))

	for c: Dictionary in combatants["combatants"]:
		for key: String in ["id", "display_name", "side", "stats", "weapon_die", "ai", "skills"]:
			assert(c.has(key), "combatant %s missing %s" % [c.get("id", "?"), key])
		for stat: String in ["str", "dex", "con", "int", "wis", "cha"]:
			assert(c["stats"].has(stat), "combatant %s missing stat %s" % [c["id"], stat])
		for sk: Variant in c["skills"]:
			assert(skill_ids.has(String(sk)), "combatant %s references unknown skill %s" % [c["id"], sk])

	for cls: Dictionary in classes["classes"]:
		var prev_level := 0
		for lv: Dictionary in cls["levels"]:
			assert(int(lv["level"]) == prev_level + 1, "class levels must be contiguous from 1")
			prev_level = int(lv["level"])
			for sk: Variant in lv["grants"]:
				assert(skill_ids.has(String(sk)), "class grant references unknown skill %s" % sk)

	for a: Dictionary in arenas["arenas"]:
		var w := int(a["grid"]["width"])
		var h := int(a["grid"]["height"])
		assert(w == 12 and h == 8, "M1 arenas are 12x8")
		for cell: Array in (a["blocked"] as Array) + (a["player_spawns"] as Array) + (a["enemy_spawns"] as Array):
			assert(int(cell[0]) >= 0 and int(cell[0]) < w and int(cell[1]) >= 0 and int(cell[1]) < h, "cell out of bounds")
		assert((a["player_spawns"] as Array).size() >= 4, "need 4 player spawns (design-for-4)")

	print("PASS: combat data is well-formed and cross-referenced")
	quit(0)
```

Run (expect FAIL before files exist if test written first; with files in place):
`/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_combat_data.gd` → `PASS: combat data is well-formed and cross-referenced`.
Also `wandering_inn_game_v4/qa/run_qa.sh load_gate headless` → PASS.

- [ ] **Step 6: Commit**

`git add wandering_inn_game_v4 && git commit -m "Add combat data: skill tranche, combatants, classes, arenas + validation test"`

---

### Task 3: WICombat core sim + determinism proof

**Files:**
- Create: `wandering_inn_game_v4/src/core/combat/wi_combat.gd`
- Test: `wandering_inn_game_v4/tests/test_combat_sim.gd`

**Interfaces:**
- Produces `class_name WICombat extends RefCounted`:
  - `_init(arena_cfg: Dictionary, combatant_cfgs: Array, skills_cfg: Dictionary, event_sink: Callable, rng_seed: int)`
  - Intents (all return `bool` success except `end_turn`): `move_active(dir: Vector2i) -> bool`, `attack(target_id: String) -> bool`, `use_skill(skill_id: String, target_id: String) -> bool`, `end_turn() -> void`
  - Queries: `get_active() -> String`, `snapshot() -> Dictionary`, `is_adjacent(a_id, b_id) -> bool`, `alive_enemies_of(id) -> Array[String]` (sorted hp asc, id asc)
  - Public state: `combatants: Dictionary` (id → state dict with keys `id, display_name, side, cell: Vector2i, hp, max_hp, ap, alive, stats, weapon_die, skills: Array[String], hit_bonus, ai`), `turn_order: Array`, `round_number: int`, `finished: bool`, `outcome: Dictionary` (`{victory: bool, rounds: int, survivors: Array, draw: bool}` when finished), `grid_size: Vector2i`, `blocked: Dictionary`
  - Events emitted: `combat_started {order}`, `round_started {round}`, `turn_started {id, ap}`, `combatant_moved {id, cell}`, `ap_changed {id, ap}`, `attack_resolved {attacker, target, hit, damage, target_hp, melee}`, `reaction_triggered {id, skill}`, `combatant_downed {id}`, `turn_ended {id}`, `combat_finished {victory, rounds, draw}`
  - Constants: `MAX_AP=4, MOVE_COST=1, ATTACK_COST=2, BASE_HIT=85, ROUND_CAP=30`
- Skill effects beyond passives are Task 4 — in this task `use_skill` handles only structure/validation and returns false for effect types it doesn't know; Task 4 fills the registry.

- [ ] **Step 1: Write the failing core test** — `tests/test_combat_sim.gd`:

```gdscript
extends SceneTree
## Pure combat-sim tests: rules, ordering, and determinism.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_combat_sim.gd

var _events: Array = []


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


func _count(type: String) -> int:
	var n := 0
	for e: Dictionary in _events:
		if e["type"] == type:
			n += 1
	return n


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _cfgs(ids: Array) -> Array:
	var all := _load("res://data/combatants.json")
	var out: Array = []
	for want: String in ids:
		for c: Dictionary in all["combatants"]:
			if String(c["id"]) == want:
				out.append(c.duplicate(true))
	return out


func _make(seed_v: int, sink: Callable) -> WICombat:
	var arena: Dictionary = _load("res://data/arenas.json")["arenas"][0]
	return WICombat.new(arena, _cfgs(["pc", "relc", "goblin_raider", "goblin_shaman"]), _load("res://data/skills.json"), sink, seed_v)


func _init() -> void:
	var combat := _make(42, _sink)

	# Setup: four combatants at spawn cells, initiative precomputed, round 1 started
	assert(combat.turn_order.size() == 4, "all four in initiative order")
	assert(combat.combatants["pc"]["cell"] == Vector2i(2, 3), "pc at first player spawn")
	assert(combat.combatants["goblin_raider"]["cell"] == Vector2i(9, 3), "raider at first enemy spawn")
	assert(_count("combat_started") == 1 and _count("round_started") == 1 and _count("turn_started") == 1, "start events")
	assert(combat.combatants[combat.get_active()]["ap"] == WICombat.MAX_AP, "active has full AP")

	# Movement: costs 1 AP, respects bounds/blocked/occupied
	var active: String = combat.get_active()
	var before: Vector2i = combat.combatants[active]["cell"]
	assert(combat.move_active(Vector2i.RIGHT) or combat.move_active(Vector2i.LEFT) or combat.move_active(Vector2i.UP) or combat.move_active(Vector2i.DOWN), "some direction is open")
	assert(combat.combatants[active]["ap"] == WICombat.MAX_AP - 1, "move cost 1 AP")
	assert(combat.combatants[active]["cell"] != before, "cell changed")

	# Turn/round advance
	combat.end_turn()
	assert(_count("turn_ended") == 1 and _count("turn_started") == 2, "turn advanced")
	combat.end_turn()
	combat.end_turn()
	combat.end_turn()
	assert(_count("round_started") == 2, "wrapping order starts round 2")
	assert(combat.round_number == 2, "round counter")

	# Attack validation: non-adjacent attack refused, no AP spent
	var atk: String = combat.get_active()
	var foes: Array = combat.alive_enemies_of(atk)
	assert(not foes.is_empty(), "has living enemies")
	if not combat.is_adjacent(atk, String(foes[0])):
		assert(not combat.attack(String(foes[0])), "non-adjacent attack refused")
		assert(combat.combatants[atk]["ap"] == WICombat.MAX_AP, "refused attack costs nothing")

	# Determinism: same seed + same scripted intents → identical event streams
	var stream_a: Array = []
	var stream_b: Array = []
	for stream: Array in [stream_a, stream_b]:
		var ev := func(type: String, payload: Dictionary) -> void:
			stream.append(JSON.stringify({"t": type, "p": payload}))
		var c := _make(99, ev)
		for i in 40:
			if c.finished:
				break
			if not c.move_active(Vector2i.LEFT):
				if not c.move_active(Vector2i.UP):
					c.end_turn()
	assert(stream_a.size() > 10, "scripted run produced events")
	assert(stream_a == stream_b, "same seed + same intents = identical event stream")

	# Forced kill path: down a combatant directly, victory fires when enemies gone
	var c2 := _make(7, _sink)
	_events.clear()
	c2.apply_damage("goblin_raider", 999, "pc", true)
	assert(_count("combatant_downed") == 1, "downed event")
	assert(not c2.finished, "one enemy left, not finished")
	c2.apply_damage("goblin_shaman", 999, "pc", true)
	assert(c2.finished and c2.outcome["victory"] == true, "all enemies down = victory")
	assert(_count("combat_finished") == 1, "combat_finished emitted")

	# Round cap: draw counts as non-victory
	var c3 := _make(7, _sink)
	_events.clear()
	while not c3.finished:
		c3.end_turn()
	assert(c3.outcome["draw"] == true and c3.outcome["victory"] == false, "round cap = draw, non-victory")

	print("PASS: combat sim core rules and determinism hold")
	quit(0)
```

- [ ] **Step 2: Run to verify it fails** (`WICombat` not declared).

- [ ] **Step 3: Implement `src/core/combat/wi_combat.gd`**

```gdscript
class_name WICombat
extends RefCounted
## Pure tactical combat simulation for one encounter.
##
## PURITY RULE: no autoload, Node, or scene-tree references. Dependencies are
## injected (arena/combatant/skill configs, event-sink Callable, RNG seed).
## All randomness flows through `rng`; initiative is precomputed then sorted —
## never roll inside a comparator.

const MAX_AP := 4
const MOVE_COST := 1
const ATTACK_COST := 2
const BASE_HIT := 85
const ROUND_CAP := 30

var grid_size: Vector2i
var blocked: Dictionary = {}
var combatants: Dictionary = {}
var turn_order: Array = []
var active_index: int = 0
var round_number: int = 0
var finished := false
var outcome: Dictionary = {}
var skills: Dictionary = {}
var rng := RandomNumberGenerator.new()

var _event_sink: Callable
var _momentum_used: Dictionary = {}


func _init(arena_cfg: Dictionary, combatant_cfgs: Array, skills_cfg: Dictionary, event_sink: Callable, rng_seed: int) -> void:
	_event_sink = event_sink
	rng.seed = rng_seed
	grid_size = Vector2i(int(arena_cfg["grid"]["width"]), int(arena_cfg["grid"]["height"]))
	for cell: Array in arena_cfg.get("blocked", []):
		blocked[Vector2i(int(cell[0]), int(cell[1]))] = true
	for s: Dictionary in skills_cfg.get("skills", []):
		skills[String(s["id"])] = s
	var spawn_i := {"player": 0, "enemy": 0}
	for cfg: Dictionary in combatant_cfgs:
		var side := String(cfg["side"])
		var spawns: Array = arena_cfg["player_spawns"] if side == "player" else arena_cfg["enemy_spawns"]
		var spawn: Array = spawns[spawn_i[side]]
		spawn_i[side] += 1
		var c := {
			"id": String(cfg["id"]),
			"display_name": String(cfg["display_name"]),
			"side": side,
			"cell": Vector2i(int(spawn[0]), int(spawn[1])),
			"stats": (cfg["stats"] as Dictionary).duplicate(true),
			"weapon_die": int(cfg["weapon_die"]),
			"ai": String(cfg.get("ai", "")),
			"skills": [],
			"hit_bonus": 0,
			"max_hp": 20 + int(cfg["stats"]["con"]),
			"ap": 0,
			"alive": true,
		}
		for sk: Variant in cfg.get("skills", []):
			c["skills"].append(String(sk))
		_apply_passives(c)
		c["hp"] = c["max_hp"]
		combatants[c["id"]] = c
	_roll_initiative()
	_emit("combat_started", {"order": turn_order.duplicate()})
	_start_round()
	_start_turn()


func _apply_passives(c: Dictionary) -> void:
	for sk: String in c["skills"]:
		var effect: Dictionary = skills.get(sk, {}).get("effect", {})
		match String(effect.get("type", "")):
			"hp_bonus":
				c["max_hp"] += int(effect["amount"])
			"hit_bonus":
				c["hit_bonus"] += int(effect["amount"])


func _roll_initiative() -> void:
	var entries: Array = []
	var ids := combatants.keys()
	ids.sort()
	for id: String in ids:
		entries.append({"id": id, "init": int(combatants[id]["stats"]["dex"]) + rng.randi_range(1, 6)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["init"] != b["init"]:
			return a["init"] > b["init"]
		return String(a["id"]) < String(b["id"]))
	turn_order = entries.map(func(e: Dictionary) -> String: return String(e["id"]))


func get_active() -> String:
	return String(turn_order[active_index])


func is_adjacent(a_id: String, b_id: String) -> bool:
	var d: Vector2i = (combatants[a_id]["cell"] as Vector2i) - (combatants[b_id]["cell"] as Vector2i)
	return maxi(absi(d.x), absi(d.y)) <= 1


func chebyshev(a_id: String, b_id: String) -> int:
	var d: Vector2i = (combatants[a_id]["cell"] as Vector2i) - (combatants[b_id]["cell"] as Vector2i)
	return maxi(absi(d.x), absi(d.y))


func alive_enemies_of(id: String) -> Array:
	var side := String(combatants[id]["side"])
	var out: Array = []
	for other_id: String in combatants:
		var o: Dictionary = combatants[other_id]
		if o["alive"] and String(o["side"]) != side:
			out.append(other_id)
	out.sort_custom(func(a: String, b: String) -> bool:
		if combatants[a]["hp"] != combatants[b]["hp"]:
			return int(combatants[a]["hp"]) < int(combatants[b]["hp"])
		return a < b)
	return out


func is_cell_free(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return false
	if blocked.has(cell):
		return false
	for c: Dictionary in combatants.values():
		if c["alive"] and c["cell"] == cell:
			return false
	return true


func move_active(dir: Vector2i) -> bool:
	if finished:
		return false
	var c: Dictionary = combatants[get_active()]
	if int(c["ap"]) < MOVE_COST:
		return false
	var target: Vector2i = (c["cell"] as Vector2i) + dir
	if absi(dir.x) + absi(dir.y) != 1 or not is_cell_free(target):
		return false
	c["cell"] = target
	c["ap"] = int(c["ap"]) - MOVE_COST
	_emit("combatant_moved", {"id": c["id"], "cell": [target.x, target.y]})
	_emit("ap_changed", {"id": c["id"], "ap": c["ap"]})
	return true


func attack(target_id: String) -> bool:
	if finished:
		return false
	var attacker_id := get_active()
	var a: Dictionary = combatants[attacker_id]
	var t: Dictionary = combatants.get(target_id, {})
	if t.is_empty() or not t["alive"] or String(t["side"]) == String(a["side"]):
		return false
	if int(a["ap"]) < ATTACK_COST or not is_adjacent(attacker_id, target_id):
		return false
	a["ap"] = int(a["ap"]) - ATTACK_COST
	_emit("ap_changed", {"id": attacker_id, "ap": a["ap"]})
	_resolve_hit(attacker_id, target_id, 1.0, true, true)
	return true


func use_skill(skill_id: String, target_id: String) -> bool:
	if finished:
		return false
	var actor_id := get_active()
	var a: Dictionary = combatants[actor_id]
	if not (a["skills"] as Array).has(skill_id):
		return false
	var skill: Dictionary = skills.get(skill_id, {})
	if not (skill.get("contexts", []) as Array).has("combat"):
		return false
	if int(a["ap"]) < int(skill.get("ap_cost", 0)):
		return false
	return WISkillEffects.resolve_active(self, actor_id, target_id, skill)


## Applies damage directly (used by hit resolution and tests).
func apply_damage(target_id: String, amount: int, source_id: String, melee: bool) -> void:
	var t: Dictionary = combatants[target_id]
	if not t["alive"]:
		return
	t["hp"] = maxi(0, int(t["hp"]) - amount)
	if int(t["hp"]) == 0:
		t["alive"] = false
		_emit("combatant_downed", {"id": target_id})
		_on_kill(source_id)
		_check_end()


func _resolve_hit(attacker_id: String, target_id: String, mult: float, melee: bool, allow_riposte: bool) -> void:
	var a: Dictionary = combatants[attacker_id]
	var t: Dictionary = combatants[target_id]
	var hit_chance: int = BASE_HIT + int(a["hit_bonus"]) - int(t["stats"]["dex"]) / 4
	var hit := rng.randi_range(1, 100) <= hit_chance
	var damage := 0
	if hit:
		var stat: int = int(a["stats"]["str"]) if melee else int(a["stats"]["int"])
		damage = maxi(1, int((stat / 2 + rng.randi_range(1, int(a["weapon_die"]))) * mult))
	_emit("attack_resolved", {
		"attacker": attacker_id, "target": target_id, "hit": hit,
		"damage": damage, "target_hp": maxi(0, int(t["hp"]) - damage), "melee": melee,
	})
	if not hit:
		return
	apply_damage(target_id, damage, attacker_id, melee)
	if finished:
		return
	var target_now: Dictionary = combatants[target_id]
	if allow_riposte and melee and target_now["alive"] \
			and (target_now["skills"] as Array).has("counter_strike") \
			and is_adjacent(target_id, attacker_id):
		var riposte_mult := float(skills["counter_strike"]["effect"]["mult"])
		_emit("reaction_triggered", {"id": target_id, "skill": "counter_strike"})
		_resolve_hit(target_id, attacker_id, riposte_mult, true, false)


func _on_kill(killer_id: String) -> void:
	var k: Dictionary = combatants.get(killer_id, {})
	if k.is_empty() or not k.get("alive", false):
		return
	if (k["skills"] as Array).has("battle_momentum") and not _momentum_used.get(killer_id, false):
		_momentum_used[killer_id] = true
		k["ap"] = int(k["ap"]) + int(skills["battle_momentum"]["effect"]["amount"])
		_emit("reaction_triggered", {"id": killer_id, "skill": "battle_momentum"})
		_emit("ap_changed", {"id": killer_id, "ap": k["ap"]})


func end_turn() -> void:
	if finished:
		return
	_emit("turn_ended", {"id": get_active()})
	_advance_turn()


func _advance_turn() -> void:
	var tries := 0
	while tries < turn_order.size() + 1:
		tries += 1
		active_index += 1
		if active_index >= turn_order.size():
			active_index = 0
			round_number += 1
			if round_number > ROUND_CAP:
				_finish(false, true)
				return
			_emit("round_started", {"round": round_number})
		if combatants[get_active()]["alive"]:
			_start_turn()
			return


func _start_round() -> void:
	round_number = 1
	_emit("round_started", {"round": 1})


func _start_turn() -> void:
	var c: Dictionary = combatants[get_active()]
	c["ap"] = MAX_AP
	_momentum_used.erase(c["id"])
	_emit("turn_started", {"id": c["id"], "ap": MAX_AP})


func _check_end() -> void:
	var sides_alive := {"player": false, "enemy": false}
	for c: Dictionary in combatants.values():
		if c["alive"]:
			sides_alive[String(c["side"])] = true
	if not sides_alive["enemy"]:
		_finish(true, false)
	elif not sides_alive["player"]:
		_finish(false, false)


func _finish(victory: bool, draw: bool) -> void:
	if finished:
		return
	finished = true
	var survivors: Array = []
	for id: String in combatants:
		if combatants[id]["alive"]:
			survivors.append(id)
	survivors.sort()
	outcome = {"victory": victory, "rounds": round_number, "survivors": survivors, "draw": draw}
	_emit("combat_finished", {"victory": victory, "rounds": round_number, "draw": draw})


func snapshot() -> Dictionary:
	var cs := {}
	for id: String in combatants:
		var c: Dictionary = combatants[id]
		cs[id] = {
			"cell": [(c["cell"] as Vector2i).x, (c["cell"] as Vector2i).y],
			"hp": c["hp"], "max_hp": c["max_hp"], "ap": c["ap"],
			"alive": c["alive"], "side": c["side"],
		}
	return {
		"round": round_number, "active": get_active() if not turn_order.is_empty() else "",
		"finished": finished, "victory": outcome.get("victory", false),
		"order": turn_order.duplicate(), "combatants": cs,
	}


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
```

Note: `use_skill` calls `WISkillEffects.resolve_active` — Task 4 creates it. For THIS task, create a minimal stub `src/core/combat/skill_effects.gd` so the core compiles:

```gdscript
class_name WISkillEffects
extends RefCounted
## Skill-effect registry. Task 4 fills the resolvers; this stub keeps the
## combat core compiling — unknown effects are refused (return false).


static func resolve_active(_combat: WICombat, _actor_id: String, _target_id: String, _skill: Dictionary) -> bool:
	return false
```

- [ ] **Step 4: Import, run test**

```
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --import
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_combat_sim.gd
```
Expected: `PASS: combat sim core rules and determinism hold`. Also run `test_sim_core.gd` and `load_gate` (both PASS — no regressions).

- [ ] **Step 5: Commit**

`git add wandering_inn_game_v4 && git commit -m "Add WICombat pure sim core: AP turns, precomputed initiative, deterministic streams"`

---

### Task 4: Skill-effect registry + reactions

**Files:**
- Modify: `wandering_inn_game_v4/src/core/combat/skill_effects.gd` (replace stub)
- Test: extend `wandering_inn_game_v4/tests/test_combat_sim.gd`

**Interfaces:**
- Consumes: `WICombat` internals per Task 3 (`combatants`, `skills`, `is_adjacent`, `chebyshev`, `_resolve_hit`, `_emit`).
- Produces: `WISkillEffects.resolve_active(combat, actor_id, target_id, skill) -> bool` handling `damage_mult` (melee, adjacency, riposte-able) and `spell_damage` (ranged ≤ `effect.range`, INT-based, never riposted). Both spend `ap_cost`, emit `ap_changed`, then `skill_resolved {actor, skill, target}` before hit resolution. Riposte/momentum already live in WICombat hooks (Task 3) — this task proves them with tests.

- [ ] **Step 1: Add failing tests** — append to `tests/test_combat_sim.gd` before the final `print` (helper `_teleport` sets cells directly for setup):

```gdscript
	# --- Task 4: skill effects and reactions ---
	var c4 := _make(11, _sink)
	_events.clear()
	# Teleport pc adjacent to raider for controlled melee tests
	c4.combatants["pc"]["cell"] = Vector2i(8, 3)
	c4.combatants["goblin_raider"]["cell"] = Vector2i(9, 3)
	# Force pc active regardless of initiative
	c4.active_index = c4.turn_order.find("pc")
	c4._start_turn()
	c4.combatants["pc"]["skills"] = ["power_strike", "counter_strike", "battle_momentum"]

	# power_strike: costs 3 AP, resolves as melee hit
	assert(c4.use_skill("power_strike", "goblin_raider"), "power strike usable adjacent with 4 AP")
	assert(c4.combatants["pc"]["ap"] == 1, "power strike cost 3 AP")
	assert(_count("skill_resolved") == 1 and _count("attack_resolved") >= 1, "skill resolved into a hit roll")

	# spell_damage: range-checked, refused out of range, never riposted
	var c5 := _make(11, _sink)
	_events.clear()
	c5.combatants["goblin_shaman"]["cell"] = Vector2i(9, 3)
	c5.combatants["pc"]["cell"] = Vector2i(2, 3)
	c5.combatants["pc"]["skills"] = ["counter_strike"]
	c5.active_index = c5.turn_order.find("goblin_shaman")
	c5._start_turn()
	assert(not c5.use_skill("flame_bolt", "pc"), "flame bolt refused beyond range 4")
	c5.combatants["goblin_shaman"]["cell"] = Vector2i(5, 3)
	assert(c5.use_skill("flame_bolt", "pc"), "flame bolt in range")
	assert(_count("reaction_triggered") == 0, "spells never trigger riposte")

	# riposte: melee hit on counter_strike holder answers at 0.8, no chains
	var c6 := _make(3, _sink)
	_events.clear()
	c6.combatants["pc"]["cell"] = Vector2i(8, 3)
	c6.combatants["pc"]["skills"] = ["counter_strike"]
	c6.combatants["goblin_raider"]["cell"] = Vector2i(9, 3)
	c6.combatants["goblin_raider"]["skills"] = ["counter_strike"]
	c6.active_index = c6.turn_order.find("goblin_raider")
	c6._start_turn()
	var hits_before: int = _count("attack_resolved")
	c6.attack("pc")
	var raider_hit: bool = false
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved" and e["payload"]["attacker"] == "goblin_raider":
			raider_hit = bool(e["payload"]["hit"])
	if raider_hit:
		assert(_count("reaction_triggered") == 1, "riposte fired once")
		assert(_count("attack_resolved") == hits_before + 2, "exactly one answer, no chains")
	else:
		assert(_count("reaction_triggered") == 0, "no riposte on a miss")

	# battle_momentum: +1 AP on kill, once per turn
	var c7 := _make(5, _sink)
	_events.clear()
	c7.combatants["pc"]["skills"] = ["battle_momentum"]
	c7.active_index = c7.turn_order.find("pc")
	c7._start_turn()
	c7.combatants["goblin_raider"]["hp"] = 1
	c7.combatants["pc"]["cell"] = Vector2i(8, 3)
	c7.combatants["goblin_raider"]["cell"] = Vector2i(9, 3)
	var ap_before: int = int(c7.combatants["pc"]["ap"])
	c7.apply_damage("goblin_raider", 1, "pc", true)
	assert(int(c7.combatants["pc"]["ap"]) == ap_before + 1, "momentum granted +1 AP on kill")
	c7.combatants["goblin_shaman"]["hp"] = 1
	c7.apply_damage("goblin_shaman", 1, "pc", true)
	assert(c7.finished, "second kill ended combat")
	assert(_count("reaction_triggered") == 1, "momentum capped once per turn")
```

- [ ] **Step 2: Run** — expect FAIL (power_strike refused: stub returns false).

- [ ] **Step 3: Replace the stub `skill_effects.gd`**

```gdscript
class_name WISkillEffects
extends RefCounted
## Registry of active combat skill-effect resolvers, keyed by effect type.
## Pure: operates only on the passed-in WICombat. Passives (hp_bonus,
## hit_bonus) are applied at combatant build inside WICombat; reactions
## (riposte, ap_on_kill) live at WICombat's resolution hooks. This registry
## covers effects a combatant actively spends AP on.


static func resolve_active(combat: WICombat, actor_id: String, target_id: String, skill: Dictionary) -> bool:
	var effect: Dictionary = skill.get("effect", {})
	var a: Dictionary = combat.combatants[actor_id]
	var t: Dictionary = combat.combatants.get(target_id, {})
	if t.is_empty() or not t.get("alive", false) or String(t["side"]) == String(a["side"]):
		return false
	var cost := int(skill.get("ap_cost", 0))
	match String(effect.get("type", "")):
		"damage_mult":
			if not combat.is_adjacent(actor_id, target_id):
				return false
			_spend(combat, a, cost)
			combat._emit("skill_resolved", {"actor": actor_id, "skill": String(skill["id"]), "target": target_id})
			combat._resolve_hit(actor_id, target_id, float(effect["mult"]), true, true)
			return true
		"spell_damage":
			if combat.chebyshev(actor_id, target_id) > int(effect["range"]):
				return false
			_spend(combat, a, cost)
			combat._emit("skill_resolved", {"actor": actor_id, "skill": String(skill["id"]), "target": target_id})
			combat._resolve_hit(actor_id, target_id, 1.0, false, false)
			return true
	return false


static func _spend(combat: WICombat, c: Dictionary, cost: int) -> void:
	c["ap"] = int(c["ap"]) - cost
	combat._emit("ap_changed", {"id": String(c["id"]), "ap": c["ap"]})
```

Note: `spell_damage` uses the caster's `weapon_die` for the roll via `_resolve_hit`'s existing formula with `melee=false` (INT stat). The shaman's `weapon_die: 4` plus the skill's `die: 6` — the sim uses `effect.die` only if you extend `_resolve_hit`; for M1 **keep `_resolve_hit` unchanged and accept weapon_die for spells** (shaman's 4). The `die` field stays in data for M2. This is a deliberate simplification — do not add a parameter for it.

- [ ] **Step 4: Import, run** — all `test_combat_sim.gd` assertions PASS; re-run `test_sim_core.gd`, `test_combat_data.gd`, `load_gate` (PASS).

- [ ] **Step 5: Commit**

`git add wandering_inn_game_v4 && git commit -m "Fill skill-effect registry: power strike, flame bolt; prove riposte and momentum"`

---

### Task 5: Combat AI + balance harness (200-run batch)

**Files:**
- Create: `wandering_inn_game_v4/src/core/combat/combat_ai.gd`
- Test: `wandering_inn_game_v4/tests/sim_combat_batch.gd`

**Interfaces:**
- Consumes: `WICombat` per Task 3/4.
- Produces: `WICombatAI.take_turn(combat: WICombat) -> void` — plays the active combatant to completion (spends AP per its profile: `"melee"` default, `"ranged"`) and always ends the turn. Deterministic: all target/step tie-breaks are sorted (hp asc then id; direction order RIGHT, LEFT, UP, DOWN).

- [ ] **Step 1: Implement `combat_ai.gd`**

```gdscript
class_name WICombatAI
extends RefCounted
## Role-profile AI. Pure static functions over a WICombat; deterministic:
## every choice is sorted (targets: hp asc then id; step directions in the
## fixed order RIGHT, LEFT, UP, DOWN choosing the first that most reduces
## Chebyshev distance).

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]


static func take_turn(combat: WICombat) -> void:
	var id := combat.get_active()
	var guard := 0
	while not combat.finished and combat.get_active() == id and guard < 24:
		guard += 1
		if not _act_once(combat, id):
			break
	if not combat.finished and combat.get_active() == id:
		combat.end_turn()


static func _act_once(combat: WICombat, id: String) -> bool:
	var c: Dictionary = combat.combatants[id]
	var profile := String(c.get("ai", ""))
	if profile == "":
		profile = "melee"
	var foes: Array = combat.alive_enemies_of(id)
	if foes.is_empty():
		return false
	match profile:
		"ranged":
			return _act_ranged(combat, id, c, foes)
		_:
			return _act_melee(combat, id, c, foes)


static func _act_melee(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	for foe: String in foes:
		if combat.is_adjacent(id, foe):
			if (c["skills"] as Array).has("power_strike") and int(c["ap"]) >= 3:
				return combat.use_skill("power_strike", foe)
			if int(c["ap"]) >= WICombat.ATTACK_COST:
				return combat.attack(foe)
			return false
	if int(c["ap"]) >= WICombat.MOVE_COST:
		return _step(combat, id, String(foes[0]), true)
	return false


static func _act_ranged(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	var spell_id := ""
	for sk: String in c["skills"]:
		if String(combat.skills.get(sk, {}).get("effect", {}).get("type", "")) == "spell_damage":
			spell_id = sk
			break
	var target := String(foes[0])
	if spell_id != "":
		var s: Dictionary = combat.skills[spell_id]
		var in_range := combat.chebyshev(id, target) <= int(s["effect"]["range"])
		if in_range and int(c["ap"]) >= int(s["ap_cost"]):
			if combat.is_adjacent(id, target) and int(c["ap"]) >= int(s["ap_cost"]) + WICombat.MOVE_COST:
				if _step(combat, id, target, false):
					return true
			return combat.use_skill(spell_id, target)
		if not in_range and int(c["ap"]) >= WICombat.MOVE_COST:
			return _step(combat, id, target, true)
	return false


## Steps one cell toward (or away from) the target; returns false if no step improves.
static func _step(combat: WICombat, id: String, target_id: String, toward: bool) -> bool:
	var from: Vector2i = combat.combatants[id]["cell"]
	var goal: Vector2i = combat.combatants[target_id]["cell"]
	var current := maxi(absi((from - goal).x), absi((from - goal).y))
	var best_dir := Vector2i.ZERO
	var best := current
	for dir: Vector2i in DIRS:
		var cell := from + dir
		if not combat.is_cell_free(cell):
			continue
		var d := maxi(absi((cell - goal).x), absi((cell - goal).y))
		if (toward and d < best) or (not toward and d > best):
			best = d
			best_dir = dir
	if best_dir == Vector2i.ZERO:
		return false
	return combat.move_active(best_dir)
```

- [ ] **Step 2: Write the balance harness** — `tests/sim_combat_batch.gd`:

```gdscript
extends SceneTree
## Balance harness: 200 seeded AI-vs-AI runs of the M1 encounter.
## Asserts: termination, win-rate 0.55–0.95, median rounds 3–12.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/sim_combat_batch.gd

const RUNS := 200


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _init() -> void:
	var arena: Dictionary = _load("res://data/arenas.json")["arenas"][0]
	var skills := _load("res://data/skills.json")
	var classes := _load("res://data/classes.json")
	var catalog := _load("res://data/combatants.json")
	var by_id := {}
	for c: Dictionary in catalog["combatants"]:
		by_id[String(c["id"])] = c

	var wins := 0
	var rounds: Array[int] = []
	var sink := func(_t: String, _p: Dictionary) -> void: pass
	for seed_v in range(1, RUNS + 1):
		var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
		pc["ai"] = "melee"
		pc["skills"] = WIProgression.granted_skills({"fighter": 1}, classes)
		var cfgs: Array = [pc, (by_id["relc"] as Dictionary).duplicate(true),
			(by_id["goblin_raider"] as Dictionary).duplicate(true),
			(by_id["goblin_shaman"] as Dictionary).duplicate(true)]
		var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
		var guard := 0
		while not combat.finished and guard < 2000:
			guard += 1
			WICombatAI.take_turn(combat)
		assert(combat.finished, "fight %d did not terminate" % seed_v)
		if combat.outcome["victory"]:
			wins += 1
		rounds.append(int(combat.outcome["rounds"]))

	rounds.sort()
	var win_rate := float(wins) / float(RUNS)
	var median: int = rounds[RUNS / 2]
	print("win_rate=%.2f median_rounds=%d min=%d max=%d" % [win_rate, median, rounds[0], rounds[-1]])
	var hist := {}
	for r: int in rounds:
		hist[r] = int(hist.get(r, 0)) + 1
	print("rounds histogram: ", hist)
	assert(win_rate >= 0.55 and win_rate <= 0.95, "win rate %.2f outside 0.55-0.95" % win_rate)
	assert(median >= 3 and median <= 12, "median rounds %d outside 3-12" % median)
	print("PASS: balance within bounds over %d seeded runs" % RUNS)
	quit(0)
```

NOTE: this harness uses `WIProgression.granted_skills` — Task 6 creates it. **Task ordering exception:** implement Task 6 FIRST if executing strictly in order is required; otherwise (recommended) replace that one line for now with `pc["skills"] = ["basic_swordwork", "tough_body", "power_strike"]` and leave a step in Task 6 to switch it back. Take the recommended path: hardcode now, Task 6 Step 5 swaps it.

- [ ] **Step 3: Import, run the batch**

`/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/sim_combat_batch.gd`

Expected: prints distributions + `PASS: balance within bounds over 200 seeded runs`.

**If assertions fail (likely on the first run — this step IS the balancing):** adjust ONLY `data/combatants.json` numbers (goblin `con`/`str`/`dex`, at most ±4 from current) and/or `weapon_die`, re-run until bounds hold. Do not touch sim code or bounds. Record the final numbers and the final printed distribution in your report. Re-run `test_combat_data.gd` and `test_combat_sim.gd` after any data change (both must still PASS).

- [ ] **Step 4: Commit**

`git add wandering_inn_game_v4 && git commit -m "Add role-profile combat AI and 200-run seeded balance harness"`

---

### Task 6: WIProgression + tests

**Files:**
- Create: `wandering_inn_game_v4/src/core/progression.gd`
- Test: `wandering_inn_game_v4/tests/test_progression.gd`
- Modify: `wandering_inn_game_v4/tests/sim_combat_batch.gd` (swap in `granted_skills`)

**Interfaces:**
- Consumes: `classes.json` shape from Task 2.
- Produces `class_name WIProgression extends RefCounted`, static + pure:
  - `granted_skills(classes: Dictionary, class_catalog: Dictionary) -> Array` — all `grants` for every class at every level ≤ current, order = catalog order, no duplicates.
  - `check_level_ups(classes: Dictionary, accomplishments: Dictionary, class_catalog: Dictionary) -> Array` — for each held class, if the NEXT level exists and every `requires` counter is met (`accomplishments.get(id,0) >= min`), one entry `{class: id, level: next, grants: [...]}`. One level per class per call (sleep once = one level).

- [ ] **Step 1: Failing test** — `tests/test_progression.gd`:

```gdscript
extends SceneTree
## Pure progression tests.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_progression.gd


func _init() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json"))

	var l1 := WIProgression.granted_skills({"fighter": 1}, catalog)
	assert(l1 == ["basic_swordwork", "tough_body", "power_strike"], "L1 grants in catalog order")
	var l2 := WIProgression.granted_skills({"fighter": 2}, catalog)
	assert(l2.has("counter_strike") and l2.has("battle_momentum") and l2.size() == 5, "L2 adds both grants")

	assert(WIProgression.check_level_ups({"fighter": 1}, {}, catalog).is_empty(), "no accomplishments = no level")
	assert(WIProgression.check_level_ups({"fighter": 1}, {"won_combat": 0}, catalog).is_empty(), "zero count insufficient")
	var ups := WIProgression.check_level_ups({"fighter": 1}, {"won_combat": 1}, catalog)
	assert(ups.size() == 1 and ups[0]["class"] == "fighter" and ups[0]["level"] == 2, "fighter 2 pending")
	assert((ups[0]["grants"] as Array).has("counter_strike"), "gains carry grants")
	assert(WIProgression.check_level_ups({"fighter": 2}, {"won_combat": 5}, catalog).is_empty(), "no level 3 defined = no gain")

	print("PASS: progression checks behave correctly")
	quit(0)
```

- [ ] **Step 2: Run → FAIL** (WIProgression not declared).

- [ ] **Step 3: Implement `src/core/progression.gd`**

```gdscript
class_name WIProgression
extends RefCounted
## Pure, data-driven progression checks over classes.json. No autoload/Node/
## scene-tree references. Level-ups are evaluated ONLY at the sleep beat
## (canon: characters level when they sleep) — callers enforce the when,
## this class answers the what.


static func granted_skills(classes: Dictionary, class_catalog: Dictionary) -> Array:
	var out: Array = []
	for cls: Dictionary in class_catalog.get("classes", []):
		var held := int(classes.get(String(cls["id"]), 0))
		for lv: Dictionary in cls.get("levels", []):
			if int(lv["level"]) <= held:
				for sk: Variant in lv.get("grants", []):
					if not out.has(String(sk)):
						out.append(String(sk))
	return out


static func check_level_ups(classes: Dictionary, accomplishments: Dictionary, class_catalog: Dictionary) -> Array:
	var gains: Array = []
	for cls: Dictionary in class_catalog.get("classes", []):
		var id := String(cls["id"])
		if not classes.has(id):
			continue
		var next := int(classes[id]) + 1
		for lv: Dictionary in cls.get("levels", []):
			if int(lv["level"]) != next:
				continue
			var met := true
			for req_id: String in lv.get("requires", {}):
				if int(accomplishments.get(req_id, 0)) < int(lv["requires"][req_id]):
					met = false
					break
			if met:
				gains.append({"class": id, "level": next, "grants": (lv["grants"] as Array).duplicate()})
	return gains
```

- [ ] **Step 4: Import, run → PASS.**

- [ ] **Step 5: Swap the batch harness to the real call** — in `tests/sim_combat_batch.gd` replace the hardcoded
`pc["skills"] = ["basic_swordwork", "tough_body", "power_strike"]` with
`pc["skills"] = WIProgression.granted_skills({"fighter": 1}, classes)` (the `classes` load line is already there). Re-run the batch → still PASS (identical skills).

- [ ] **Step 6: Commit**

`git add wandering_inn_game_v4 && git commit -m "Add WIProgression: data-driven grants and sleep-beat level checks"`

---

### Task 7: WIGame combat handoff + sleep beat + M1 map content

**Files:**
- Modify: `wandering_inn_game_v4/src/core/wi_game.gd`
- Modify: `wandering_inn_game_v4/src/core/game.gd`
- Modify: `wandering_inn_game_v4/data/skeleton_scene.json`
- Test: extend `wandering_inn_game_v4/tests/test_sim_core.gd`

**Interfaces:**
- Consumes: `WICombat`, `WIProgression`, data files.
- Produces on `WIGame`:
  - `_init` gains a 5th optional param `combat_config: Dictionary = {}` holding `{"combatants": <combatants.json dict>, "classes": <classes.json dict>, "arenas": <arenas.json dict>}`. Empty = combat disabled (M0 tests unaffected).
  - `var classes: Dictionary` (from scene config `player.classes`, default `{}`), `var combat: WICombat` (null when not fighting).
  - New entity kinds handled in `interact()`: `"encounter"` (entity data: `{"arena": "goblin_ambush", "enemies": ["goblin_raider","goblin_shaman"], "allies": ["relc"], "on_victory": "won_combat"}`) → `start_combat(entity_id)`; prop with `"sleep": true` → `sleep()`.
  - `start_combat(entity_id: String) -> bool` — builds PC (template + `WIProgression.granted_skills(classes, ...)`) + allies + enemies, seed = `rng.randi()`, constructs `combat` (sink = same event sink). Emits nothing itself — WICombat emits `combat_started`.
  - `resolve_combat() -> void` — requires `combat != null and combat.finished`. Victory: `record_accomplishment(entity's on_victory)`, remove entity (`entities.erase` + emit `entity_removed {id}`). Defeat/draw: emit `game_over {}`. Either way `combat = null`.
  - `sleep() -> void` — gains = `WIProgression.check_level_ups(classes, accomplishments, class_catalog)`; applies each (`classes[id] = level`), emits `class_level_up {class, level}` + `skill_unlocked {skill}` per grant + one `toast` (`"[Fighter Level 2] — unlocked [Counter Strike]"` formatted from data display_names); if no gains → `toast {"text": "You sleep soundly."}`.
- `Game` autoload loads the three new JSONs and passes `combat_config`; exposes nothing new (`Game.sim.combat` reachable). Adds `reset()` → rebuilds `sim` fresh (same configs, same seed source).

- [ ] **Step 1: Update `data/skeleton_scene.json`** — add to the `player` block:

```json
		"classes": { "fighter": 1 },
```

and append to `entities`:

```json
		{
			"id": "goblin_encounter_1",
			"kind": "encounter",
			"cell": [4, 2],
			"display_name": "Goblin Ambush",
			"arena": "goblin_ambush",
			"enemies": ["goblin_raider", "goblin_shaman"],
			"allies": ["relc"],
			"on_victory": "won_combat"
		},
		{
			"id": "goblin_encounter_2",
			"kind": "encounter",
			"cell": [8, 4],
			"display_name": "Goblin Ambush",
			"arena": "goblin_ambush",
			"enemies": ["goblin_raider", "goblin_shaman"],
			"allies": ["relc"],
			"on_victory": "won_combat"
		},
		{
			"id": "bed",
			"kind": "prop",
			"sleep": true,
			"cell": [1, 2],
			"display_name": "Bed"
		}
```

(Cells verified against the 10×6 grid and existing entities erin [7,2] / dirty_table [5,4]: no overlaps; paths stay walkable.)

- [ ] **Step 2: Failing tests** — append to `tests/test_sim_core.gd` (before final print). Note the test builds a combat-enabled game:

```gdscript
	# --- Task 7: combat handoff + sleep beat ---
	var combat_config := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
	}
	_events.clear()
	var g := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(g.classes.get("fighter", 0) == 1, "player classes from scene config")

	# Sleep with nothing earned: soft toast, no level
	g.sleep()
	assert(_count("class_level_up") == 0, "no level without accomplishments")
	assert(_count("toast") == 1, "sleep always toasts")

	# Start combat via the encounter entity
	assert(g.start_combat("goblin_encounter_1"), "combat starts")
	assert(g.combat != null and g.combat.combatants.has("pc") and g.combat.combatants.has("relc"), "pc + relc fielded")
	assert((g.combat.combatants["pc"]["skills"] as Array).has("power_strike"), "pc skills from class grants")
	assert(not (g.combat.combatants["pc"]["skills"] as Array).has("counter_strike"), "no L2 skills at L1")

	# Force a victory and resolve
	g.combat.apply_damage("goblin_raider", 999, "pc", true)
	g.combat.apply_damage("goblin_shaman", 999, "pc", true)
	assert(g.combat.finished and g.combat.outcome["victory"], "forced victory")
	g.resolve_combat()
	assert(g.combat == null, "combat cleared")
	assert(g.accomplishment_count("won_combat") == 1, "victory recorded")
	assert(not g.entities.has("goblin_encounter_1"), "encounter removed")
	assert(_count("entity_removed") == 1, "entity_removed emitted")

	# Sleep now levels Fighter 2
	_events.clear()
	g.sleep()
	assert(g.classes["fighter"] == 2, "fighter leveled at sleep")
	assert(_count("class_level_up") == 1 and _count("skill_unlocked") == 2, "level + two skill unlocks")

	# Second combat: counter_strike present
	assert(g.start_combat("goblin_encounter_2"), "second combat starts")
	assert((g.combat.combatants["pc"]["skills"] as Array).has("counter_strike"), "L2 grant fielded")

	# Defeat path: game_over emitted, encounter stays
	g.combat.apply_damage("pc", 999, "goblin_raider", true)
	g.combat.apply_damage("relc", 999, "goblin_raider", true)
	assert(g.combat.finished and not g.combat.outcome["victory"], "forced defeat")
	_events.clear()
	g.resolve_combat()
	assert(_count("game_over") == 1, "game_over on defeat")
	assert(g.entities.has("goblin_encounter_2"), "encounter persists after defeat")
```

(Uses the existing `_load_json` helper; the earlier M0 sections keep constructing `WIGame` with 4 args — the new param must default.)

- [ ] **Step 3: Run → FAIL. Implement in `wi_game.gd`:**

Add state and extend `_init`:

```gdscript
var classes: Dictionary = {}
var combat: WICombat = null

var _combat_config: Dictionary = {}
var _pending_encounter := ""
```

`_init` signature becomes
`func _init(scene_config: Dictionary, skill_config: Dictionary, event_sink: Callable, rng_seed: int = 0, combat_config: Dictionary = {}) -> void:`
with, inside (after player parsing):

```gdscript
	_combat_config = combat_config
	classes = (scene_config["player"].get("classes", {}) as Dictionary).duplicate(true)
```

In `interact()`'s match, add before the `_:` arm:

```gdscript
		"encounter":
			if start_combat(String(target["id"])):
				return {"combat": true}
			return {}
```

and change the `"prop"` arm to check sleep first:

```gdscript
		"prop":
			if bool(target.get("sleep", false)):
				sleep()
				return {"slept": true}
			return use_skill(String(target.get("requires_skill", "")), String(target["id"]))
```

New methods:

```gdscript
func start_combat(entity_id: String) -> bool:
	if combat != null or _combat_config.is_empty():
		return false
	var entity: Dictionary = entities.get(entity_id, {})
	if entity.is_empty() or String(entity["kind"]) != "encounter":
		return false
	var by_id := {}
	for c: Dictionary in _combat_config["combatants"]["combatants"]:
		by_id[String(c["id"])] = c
	var cfgs: Array = [_build_player_combatant(by_id["pc"])]
	for ally: Variant in entity.get("allies", []):
		cfgs.append((by_id[String(ally)] as Dictionary).duplicate(true))
	for enemy: Variant in entity.get("enemies", []):
		cfgs.append((by_id[String(enemy)] as Dictionary).duplicate(true))
	var arena: Dictionary = {}
	for a: Dictionary in _combat_config["arenas"]["arenas"]:
		if String(a["id"]) == String(entity["arena"]):
			arena = a
	if arena.is_empty():
		return false
	_pending_encounter = entity_id
	combat = WICombat.new(arena, cfgs, skills_config_raw(), _event_sink, rng.randi())
	return true


func _build_player_combatant(template: Dictionary) -> Dictionary:
	var pc: Dictionary = template.duplicate(true)
	pc["skills"] = WIProgression.granted_skills(classes, _combat_config["classes"])
	return pc


func resolve_combat() -> void:
	if combat == null or not combat.finished:
		return
	var entity: Dictionary = entities.get(_pending_encounter, {})
	if combat.outcome["victory"]:
		record_accomplishment(String(entity.get("on_victory", "won_combat")))
		entities.erase(_pending_encounter)
		_emit("entity_removed", {"id": _pending_encounter})
	else:
		_emit("game_over", {})
	combat = null
	_pending_encounter = ""


func sleep() -> void:
	if _combat_config.is_empty():
		_emit("toast", {"text": "You sleep soundly."})
		return
	var gains := WIProgression.check_level_ups(classes, accomplishments, _combat_config["classes"])
	if gains.is_empty():
		_emit("toast", {"text": "You sleep soundly."})
		return
	for gain: Dictionary in gains:
		classes[String(gain["class"])] = int(gain["level"])
		_emit("class_level_up", {"class": gain["class"], "level": gain["level"]})
		var names: Array = []
		for sk: Variant in gain["grants"]:
			_emit("skill_unlocked", {"skill": String(sk)})
			names.append(String(skills.get(String(sk), {}).get("display_name", String(sk))))
		var cls_name := String(_class_display_name(String(gain["class"])))
		_emit("toast", {"text": "[%s Level %d] — unlocked %s" % [cls_name, int(gain["level"]), ", ".join(names)]})


func _class_display_name(id: String) -> String:
	for cls: Dictionary in _combat_config["classes"]["classes"]:
		if String(cls["id"]) == id:
			return String(cls["display_name"])
	return id
```

Also add a raw-skills accessor (WICombat wants the whole dict shape):

```gdscript
func skills_config_raw() -> Dictionary:
	return {"skills": skills.values()}
```

Extend `snapshot()` with `"classes": classes.duplicate(true)`.

- [ ] **Step 4: Update `game.gd`** to load and pass the combat config, and add reset:

```gdscript
func _ready() -> void:
	_build_sim()


func reset() -> void:
	_build_sim()
	ObservableBus.emit_domain_event("game_reset", {})


func _build_sim() -> void:
	var scene_config := _load_json("res://data/skeleton_scene.json")
	var skill_config := _load_json("res://data/skills.json")
	var combat_config := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
	}
	var rng_seed := int(String(QAPaths.user_args().get("seed", "0")))
	sim = WIGame.new(scene_config, skill_config, ObservableBus.emit_domain_event, rng_seed, combat_config)
```

- [ ] **Step 5: Import, run everything**

`test_sim_core.gd`, `test_combat_sim.gd`, `test_progression.gd`, `test_combat_data.gd`, `sim_combat_batch.gd`, then `run_qa.sh load_gate headless` and `run_qa.sh skeleton_walkthrough headless`.
All PASS. (skeleton_walkthrough exercises the M0 path with the new entities present — the walk route [2,3]→[2,2]→[6,2] and [6,2]→[6,4]→face-table must not collide with bed [1,2] / encounter [4,2] / encounter [8,4]. It does not — verify in the run.)

- [ ] **Step 6: Commit**

`git add wandering_inn_game_v4 && git commit -m "Wire combat handoff and sleep-beat leveling into world sim; add M1 map entities"`

---

### Task 8: Combat presentation + input routing

**Files:**
- Create: `wandering_inn_game_v4/src/combat/combat_screen.gd`
- Modify: `wandering_inn_game_v4/src/world/world.gd`
- Modify: `wandering_inn_game_v4/project.godot` (three input actions)

**Interfaces:**
- Consumes: `Game.sim.combat` (WICombat), `WICombatAI.take_turn`, ObservableBus events from Tasks 3/7.
- Produces: player-visible combat per the spec's "functional minimal" section; bus events `ui_combat_shown`, `ui_combat_hidden` (QA waits on them). Input actions `confirm` (Enter), `cancel` (Esc), `cycle` (Tab) in project.godot. World input is gated off while `Game.sim.combat != null`; world removes entity squares on `entity_removed` and rebuilds on `game_reset`.
- Interaction model (exact): while combat active — MENU mode lists `Move / Attack / Skill / End Turn` (up/down + confirm); MOVE mode: arrow key steps the active combatant 1 cell per press (cancel returns to menu); ATTACK: `cycle` cycles valid adjacent targets, confirm attacks; SKILL: up/down selects an active combat skill (those with `ap_cost > 0`), confirm → target cycling like ATTACK; End Turn confirms immediately. AI-side turns (any combatant with `ai != ""` or side `enemy`) auto-play via `WICombatAI.take_turn` deferred one frame after their `turn_started`. On `combat_finished`: banner ("Victory!" / "Defeat…") + "Press Enter"; confirm → `Game.sim.resolve_combat()` (and on defeat, `Game.reset()`), screen hides, emits `ui_combat_hidden`.

- [ ] **Step 1: Add input actions to `project.godot`** — append to `[input]` (same InputEventKey object format as the existing actions):

```
confirm={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194309,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
cancel={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194305,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
cycle={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194306,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 2: Gate world input + entity removal in `world.gd`**

At the top of `_unhandled_input`: `if Game.sim.combat != null: return`.
Change `_build_entities` to store rects: add `var _entity_rects: Dictionary = {}` and `_entity_rects[String(ent["id"])] = _make_square(...)`.
In `_on_domain_event` add:

```gdscript
	elif type == "entity_removed":
		var rect: ColorRect = _entity_rects.get(String(payload["id"]))
		if rect != null:
			rect.queue_free()
			_entity_rects.erase(String(payload["id"]))
	elif type == "game_reset":
		get_tree().reload_current_scene()
```

Instantiate the combat screen in `_ready()` alongside the message layer:
`add_child(preload("res://src/combat/combat_screen.gd").new())`.

- [ ] **Step 3: Implement `src/combat/combat_screen.gd`** (complete file):

```gdscript
extends CanvasLayer
## Functional-minimal combat presentation. Renders the WICombat snapshot as
## a grid of squares with HP bars and AP pips, a turn-order strip, a menu-
## driven action UI, and a prose event feed. No damage numbers, no raw stats
## (repo product constraint) — exact numbers live in the sim event log only.
##
## GOTCHA: CanvasLayer has no `modulate`; only child Controls are styled.

const CELL := 48
const ORIGIN := Vector2(32, 8)
const PLAYER_COLOR := Color(0.25, 0.45, 0.9)
const ENEMY_COLOR := Color(0.75, 0.25, 0.2)
const FLOOR_COLOR := Color(0.85, 0.82, 0.7)
const BLOCKED_COLOR := Color(0.45, 0.4, 0.32)
const FEED_LINES := 3

enum Mode { INACTIVE, MENU, MOVE, ATTACK, SKILL_PICK, SKILL_TARGET, WAIT_AI, BANNER }

var _mode: int = Mode.INACTIVE
var _root: Control
var _board: Control
var _squares: Dictionary = {}
var _hp_bars: Dictionary = {}
var _menu_label: Label
var _order_label: Label
var _feed_label: Label
var _banner_label: Label
var _menu_index := 0
var _menu_items: Array = []
var _targets: Array = []
var _target_index := 0
var _skill_ids: Array = []
var _feed: Array = []


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.hide()
	add_child(_root)
	_board = Control.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_board)
	_order_label = _make_label(Vector2(32, 372), Vector2(400, 20))
	_menu_label = _make_label(Vector2(460, 40), Vector2(170, 200))
	_feed_label = _make_label(Vector2(32, 300), Vector2(400, 64))
	_banner_label = _make_label(Vector2(200, 180), Vector2(240, 40))
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ObservableBus.domain_event.connect(_on_domain_event)


func _make_label(pos: Vector2, size: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.custom_minimum_size = size
	l.add_theme_color_override("font_color", Color.BLACK)
	_root.add_child(l)
	return l


func _combat() -> WICombat:
	return Game.sim.combat


func _on_domain_event(type: String, payload: Dictionary) -> void:
	match type:
		"combat_started":
			_show_combat()
		"turn_started":
			if _mode != Mode.INACTIVE:
				_on_turn_started(String(payload["id"]))
		"combat_finished":
			if _mode != Mode.INACTIVE:
				_mode = Mode.BANNER
				_banner_label.text = ("Victory! — Enter" if bool(payload["victory"]) else "Defeat… — Enter")
				_refresh()
		"combatant_moved", "ap_changed", "combatant_downed", "attack_resolved", "skill_resolved", "reaction_triggered":
			if _mode != Mode.INACTIVE:
				_push_feed(type, payload)
				_refresh()


func _show_combat() -> void:
	_mode = Mode.WAIT_AI
	_feed.clear()
	_build_board()
	_root.show()
	ObservableBus.emit_domain_event("ui_combat_shown", {})
	_on_turn_started(_combat().get_active())


func _build_board() -> void:
	for child in _board.get_children():
		child.queue_free()
	_squares.clear()
	_hp_bars.clear()
	var combat := _combat()
	var floor_rect := ColorRect.new()
	floor_rect.color = FLOOR_COLOR
	floor_rect.position = ORIGIN
	floor_rect.size = Vector2(combat.grid_size) * CELL
	_board.add_child(floor_rect)
	for cell: Vector2i in combat.blocked:
		var b := ColorRect.new()
		b.color = BLOCKED_COLOR
		b.position = ORIGIN + Vector2(cell) * CELL
		b.size = Vector2(CELL, CELL)
		_board.add_child(b)
	for id: String in combat.combatants:
		var c: Dictionary = combat.combatants[id]
		var sq := ColorRect.new()
		sq.color = PLAYER_COLOR if String(c["side"]) == "player" else ENEMY_COLOR
		sq.size = Vector2(CELL - 6, CELL - 6)
		var name_label := Label.new()
		name_label.text = String(c["display_name"])
		name_label.position = Vector2(-2, -20)
		name_label.add_theme_color_override("font_color", Color.BLACK)
		sq.add_child(name_label)
		var bar := ColorRect.new()
		bar.color = Color(0.2, 0.8, 0.2)
		bar.position = Vector2(0, CELL - 10)
		bar.size = Vector2(CELL - 6, 4)
		sq.add_child(bar)
		_board.add_child(sq)
		_squares[id] = sq
		_hp_bars[id] = bar
	_refresh()


func _refresh() -> void:
	var combat := _combat()
	if combat == null:
		return
	var snap := combat.snapshot()
	for id: String in _squares:
		var s: Dictionary = snap["combatants"][id]
		var sq: ColorRect = _squares[id]
		sq.position = ORIGIN + Vector2(int(s["cell"][0]), int(s["cell"][1])) * CELL + Vector2(3, 3)
		sq.visible = bool(s["alive"])
		(_hp_bars[id] as ColorRect).size.x = (CELL - 6) * float(s["hp"]) / float(s["max_hp"])
	var order_bits: Array = []
	for id: String in snap["order"]:
		var mark := "> " if id == snap["active"] else ""
		if bool(snap["combatants"][id]["alive"]):
			order_bits.append(mark + String(combat.combatants[id]["display_name"]))
	_order_label.text = "Turn: " + "  |  ".join(order_bits)
	_feed_label.text = "\n".join(_feed)
	_banner_label.visible = _mode == Mode.BANNER
	_menu_label.visible = _mode in [Mode.MENU, Mode.MOVE, Mode.ATTACK, Mode.SKILL_PICK, Mode.SKILL_TARGET]
	if _menu_label.visible:
		_menu_label.text = _menu_text()


func _menu_text() -> String:
	var combat := _combat()
	var c: Dictionary = combat.combatants[combat.get_active()]
	var head := "%s  AP %s\n" % [String(c["display_name"]), "●".repeat(int(c["ap"]))]
	match _mode:
		Mode.MENU:
			var lines: Array = []
			for i in _menu_items.size():
				lines.append(("> " if i == _menu_index else "  ") + String(_menu_items[i]))
			return head + "\n".join(lines)
		Mode.MOVE:
			return head + "Move: arrows, Esc done"
		Mode.ATTACK, Mode.SKILL_TARGET:
			if _targets.is_empty():
				return head + "No target in reach (Esc)"
			return head + "Target: %s (Tab cycles, Enter confirms)" % String(combat.combatants[_targets[_target_index]]["display_name"])
		Mode.SKILL_PICK:
			var lines: Array = []
			for i in _skill_ids.size():
				var sk: Dictionary = combat.skills[_skill_ids[i]]
				lines.append(("> " if i == _menu_index else "  ") + String(sk["display_name"]))
			return head + ("\n".join(lines) if not lines.is_empty() else "No usable skills (Esc)")
	return head


func _push_feed(type: String, payload: Dictionary) -> void:
	var combat := _combat()
	var line := ""
	match type:
		"attack_resolved":
			var attacker := String(combat.combatants[payload["attacker"]]["display_name"])
			var target := String(combat.combatants[payload["target"]]["display_name"])
			line = "%s strikes %s!" % [attacker, target] if bool(payload["hit"]) else "%s misses %s." % [attacker, target]
		"reaction_triggered":
			line = "%s answers with %s!" % [String(combat.combatants[payload["id"]]["display_name"]), String(combat.skills[payload["skill"]]["display_name"])]
		"skill_resolved":
			line = "%s uses %s!" % [String(combat.combatants[payload["actor"]]["display_name"]), String(combat.skills[payload["skill"]]["display_name"])]
		"combatant_downed":
			line = "%s falls!" % String(combat.combatants[payload["id"]]["display_name"])
	if line != "":
		_feed.append(line)
		while _feed.size() > FEED_LINES:
			_feed.pop_front()


func _on_turn_started(id: String) -> void:
	var combat := _combat()
	var c: Dictionary = combat.combatants[id]
	if String(c["side"]) == "enemy" or String(c["ai"]) != "":
		_mode = Mode.WAIT_AI
		_refresh()
		_run_ai_turn.call_deferred()
	else:
		_mode = Mode.MENU
		_menu_items = ["Move", "Attack", "Skill", "End Turn"]
		_menu_index = 0
		_refresh()


func _run_ai_turn() -> void:
	var combat := _combat()
	if combat != null and not combat.finished:
		WICombatAI.take_turn(combat)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _mode == Mode.INACTIVE or Game.sim.combat == null and _mode != Mode.BANNER:
		return
	if _mode == Mode.BANNER and event.is_action_pressed("confirm"):
		_close_banner()
		return
	match _mode:
		Mode.MENU:
			_input_menu(event)
		Mode.MOVE:
			_input_move(event)
		Mode.ATTACK, Mode.SKILL_TARGET:
			_input_target(event)
		Mode.SKILL_PICK:
			_input_skill_pick(event)


func _close_banner() -> void:
	var was_victory: bool = _combat() != null and _combat().outcome.get("victory", false)
	Game.sim.resolve_combat()
	_mode = Mode.INACTIVE
	_root.hide()
	ObservableBus.emit_domain_event("ui_combat_hidden", {})
	if not was_victory:
		Game.reset()


func _input_menu(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_menu_index = maxi(0, _menu_index - 1)
	elif event.is_action_pressed("move_down"):
		_menu_index = mini(_menu_items.size() - 1, _menu_index + 1)
	elif event.is_action_pressed("confirm"):
		match String(_menu_items[_menu_index]):
			"Move":
				_mode = Mode.MOVE
			"Attack":
				_enter_targeting(Mode.ATTACK)
			"Skill":
				_enter_skill_pick()
			"End Turn":
				_combat().end_turn()
	_refresh()


func _input_move(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		_mode = Mode.MENU
	elif event.is_action_pressed("move_up"):
		_combat().move_active(Vector2i.UP)
	elif event.is_action_pressed("move_down"):
		_combat().move_active(Vector2i.DOWN)
	elif event.is_action_pressed("move_left"):
		_combat().move_active(Vector2i.LEFT)
	elif event.is_action_pressed("move_right"):
		_combat().move_active(Vector2i.RIGHT)
	_refresh()


func _enter_targeting(mode: int) -> void:
	var combat := _combat()
	var me := combat.get_active()
	_targets = []
	for foe: String in combat.alive_enemies_of(me):
		if mode == Mode.ATTACK and combat.is_adjacent(me, foe):
			_targets.append(foe)
		elif mode == Mode.SKILL_TARGET:
			_targets.append(foe)
	_target_index = 0
	_mode = mode


func _enter_skill_pick() -> void:
	var combat := _combat()
	_skill_ids = []
	for sk: String in combat.combatants[combat.get_active()]["skills"]:
		var s: Dictionary = combat.skills.get(sk, {})
		if (s.get("contexts", []) as Array).has("combat") and int(s.get("ap_cost", 0)) > 0:
			_skill_ids.append(sk)
	_menu_index = 0
	_mode = Mode.SKILL_PICK


func _input_skill_pick(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		_mode = Mode.MENU
	elif event.is_action_pressed("move_up"):
		_menu_index = maxi(0, _menu_index - 1)
	elif event.is_action_pressed("move_down"):
		_menu_index = mini(maxi(0, _skill_ids.size() - 1), _menu_index + 1)
	elif event.is_action_pressed("confirm") and not _skill_ids.is_empty():
		_enter_targeting(Mode.SKILL_TARGET)
	_refresh()


func _input_target(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		_mode = Mode.MENU
	elif event.is_action_pressed("cycle") and not _targets.is_empty():
		_target_index = (_target_index + 1) % _targets.size()
	elif event.is_action_pressed("confirm") and not _targets.is_empty():
		var combat := _combat()
		if _mode == Mode.ATTACK:
			combat.attack(String(_targets[_target_index]))
		else:
			combat.use_skill(String(_skill_ids[_menu_index]), String(_targets[_target_index]))
		_mode = Mode.MENU
	_refresh()
```

- [ ] **Step 4: Import + boot checks**

```
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --import
/usr/local/bin/godot --headless --path wandering_inn_game_v4 --quit
/usr/local/bin/godot --path wandering_inn_game_v4 --quit-after 300 2>&1 | grep -E "SCRIPT ERROR|Parse Error|WARNING" || echo CLEAN
wandering_inn_game_v4/qa/run_qa.sh load_gate headless
wandering_inn_game_v4/qa/run_qa.sh skeleton_walkthrough headless
```
All clean/PASS.

- [ ] **Step 5: Commit**

`git add wandering_inn_game_v4 && git commit -m "Add functional-minimal combat screen and world input gating"`

---

### Task 9: TestDriver extensions + combat QA scripts

**Files:**
- Modify: `wandering_inn_game_v4/qa/test_driver.gd`
- Modify: `wandering_inn_game_v4/qa/run_qa.sh`
- Create: `wandering_inn_game_v4/qa/scripts/combat_walkthrough.json`, `qa/scripts/level_up_loop.json`

**Interfaces:**
- Consumes: everything prior.
- Produces TestDriver capabilities (spec section "QA & Balance"):
  - `ACTION_KEYS` gains `"confirm": KEY_ENTER, "cancel": KEY_ESCAPE, "cycle": KEY_TAB`.
  - `assert_state` path-walk: a path segment that `is_valid_int()` indexes Arrays (bounds-checked fail); a path starting `combat.` resolves against `Game.sim.combat.snapshot()` (fail if no combat).
  - `wait_for_event` + `assert_event_logged` accept optional `"payload_contains": {…}` — event matches when type matches AND every key in the subset `_loosely_equal`s the event payload's value.
  - New action `{"action": "combat_autoplay", "max_turns": 200}` — loops: break when `Game.sim.combat == null or .finished`; if the active combatant is player-side with `ai == ""`, call `WICombatAI.take_turn(Game.sim.combat)`; await one process frame per iteration (AI-side turns are driven by the combat screen). Fails on `max_turns` exhaustion.
- `run_qa.sh` passes any extra args through to godot user args (combat scripts REQUIRE `--seed=<n>` for determinism).

- [ ] **Step 1: TestDriver edits**

`ACTION_KEYS` (add three entries):

```gdscript
	"confirm": KEY_ENTER,
	"cancel": KEY_ESCAPE,
	"cycle": KEY_TAB,
```

Replace `_has_event` and `_wait_for_event`'s matching with subset support:

```gdscript
func _event_matches(e: Dictionary, type: String, subset: Dictionary) -> bool:
	if e["type"] != type:
		return false
	for key: String in subset:
		var p: Dictionary = e["payload"]
		if not p.has(key) or not _loosely_equal(p[key], subset[key]):
			return false
	return true


func _has_event(type: String, subset: Dictionary = {}) -> bool:
	for e: Dictionary in _events_seen:
		if _event_matches(e, type, subset):
			return true
	return false
```

In `_execute`, thread the subset through:

```gdscript
		"wait_for_event":
			await _wait_for_event(String(step["type"]), float(step.get("timeout_sec", 5.0)), step.get("payload_contains", {}))
		"assert_event_logged":
			if not _has_event(String(step["type"]), step.get("payload_contains", {})):
				_fail("expected event was never emitted: " + String(step["type"]))
		"combat_autoplay":
			await _combat_autoplay(int(step.get("max_turns", 200)))
```

(`_wait_for_event` gains the third param and passes it to `_has_event`.)

Replace `_assert_state`'s snapshot fetch and walk:

```gdscript
func _assert_state(step: Dictionary) -> void:
	var path := String(step["path"])
	var cur: Variant
	if path.begins_with("combat."):
		if Game.sim.combat == null:
			_fail("assert_state: no active combat for path " + path)
			return
		cur = Game.sim.combat.snapshot()
		path = path.trim_prefix("combat.")
	else:
		cur = Game.sim.snapshot()
	for key: String in path.split("."):
		if cur is Dictionary and cur.has(key):
			cur = cur[key]
		elif cur is Array and key.is_valid_int() and int(key) >= 0 and int(key) < (cur as Array).size():
			cur = cur[int(key)]
		else:
			_fail("assert_state: path not found: " + String(step["path"]))
			return
	if not _loosely_equal(cur, step["equals"]):
		_fail("assert_state: %s expected %s, got %s" % [String(step["path"]), str(step["equals"]), str(cur)])
```

Add autoplay:

```gdscript
func _combat_autoplay(max_turns: int) -> void:
	for i in max_turns:
		var combat: WICombat = Game.sim.combat
		if combat == null or combat.finished:
			return
		var active: Dictionary = combat.combatants[combat.get_active()]
		if String(active["side"]) == "player" and String(active["ai"]) == "":
			WICombatAI.take_turn(combat)
		await get_tree().process_frame
	_fail("combat_autoplay: combat did not finish within %d turns" % max_turns)
```

- [ ] **Step 2: `run_qa.sh` passthrough** — change the godot invocation line to append extra args:

```bash
EXTRA=("${@:3}")
/usr/local/bin/godot $FLAGS --path "$PROJ" -- "--qa-script=res://qa/scripts/$NAME.json" "--qa-out=$OUT" "${EXTRA[@]}"
```

- [ ] **Step 3: Write `qa/scripts/combat_walkthrough.json`** (run with `--seed=7`; map: player [2,3], encounter1 [4,3] — moved off the M0 walkthrough route during Task 7 review):

```json
{
	"steps": [
		{ "action": "wait_for_event", "type": "world_ready", "timeout_sec": 5 },
		{ "action": "move", "direction": "right", "steps": 2 },
		{ "action": "press", "name": "interact" },
		{ "action": "wait_for_event", "type": "combat_started", "timeout_sec": 5 },
		{ "action": "wait_for_event", "type": "ui_combat_shown", "timeout_sec": 5 },
		{ "action": "screenshot", "name": "01_combat_start" },
		{ "action": "combat_autoplay", "max_turns": 300 },
		{ "action": "wait_for_event", "type": "combat_finished", "payload_contains": { "victory": true }, "timeout_sec": 10 },
		{ "action": "screenshot", "name": "02_victory_banner" },
		{ "action": "press", "name": "confirm" },
		{ "action": "wait_for_event", "type": "ui_combat_hidden", "timeout_sec": 5 },
		{ "action": "wait_frames", "frames": 5 },
		{ "action": "assert_state", "path": "accomplishments.won_combat", "equals": 1 },
		{ "action": "assert_event_logged", "type": "entity_removed" },
		{ "action": "screenshot", "name": "03_back_to_field" }
	]
}
```

Path note: [2,3] → right ×2: first right reaches [3,3], the second is blocked by the encounter at [4,3] and sets facing; interact fires the encounter. If seed 7 loses the fight, try seeds 8, 9, … and use the first winning seed consistently in this script's runner invocation AND in `run_qa.sh` docs; record the chosen seed in your report.

- [ ] **Step 4: Write `qa/scripts/level_up_loop.json`** (same seed discipline; bed [1,2], encounter2 [8,4]):

```json
{
	"steps": [
		{ "action": "wait_for_event", "type": "world_ready", "timeout_sec": 5 },
		{ "action": "move", "direction": "right", "steps": 2 },
		{ "action": "press", "name": "interact" },
		{ "action": "wait_for_event", "type": "ui_combat_shown", "timeout_sec": 5 },
		{ "action": "combat_autoplay", "max_turns": 300 },
		{ "action": "wait_for_event", "type": "combat_finished", "payload_contains": { "victory": true }, "timeout_sec": 10 },
		{ "action": "press", "name": "confirm" },
		{ "action": "wait_for_event", "type": "ui_combat_hidden", "timeout_sec": 5 },
		{ "action": "move", "direction": "left", "steps": 1 },
		{ "action": "move", "direction": "up", "steps": 1 },
		{ "action": "move", "direction": "left", "steps": 1 },
		{ "action": "press", "name": "interact" },
		{ "action": "wait_for_event", "type": "skill_unlocked", "payload_contains": { "skill": "counter_strike" }, "timeout_sec": 5 },
		{ "action": "wait_for_event", "type": "ui_toast_rendered", "timeout_sec": 5 },
		{ "action": "screenshot", "name": "01_level_up_toast" },
		{ "action": "assert_state", "path": "classes.fighter", "equals": 2 },
		{ "action": "move", "direction": "down", "steps": 1 },
		{ "action": "move", "direction": "right", "steps": 5 },
		{ "action": "move", "direction": "down", "steps": 1 },
		{ "action": "move", "direction": "right", "steps": 1 },
		{ "action": "press", "name": "interact" },
		{ "action": "wait_for_event", "type": "ui_combat_shown", "timeout_sec": 5 },
		{ "action": "screenshot", "name": "02_second_fight" },
		{ "action": "combat_autoplay", "max_turns": 300 },
		{ "action": "wait_for_event", "type": "combat_finished", "timeout_sec": 10 },
		{ "action": "assert_event_logged", "type": "reaction_triggered", "payload_contains": { "skill": "counter_strike" } },
		{ "action": "press", "name": "confirm" },
		{ "action": "screenshot", "name": "03_loop_complete" }
	]
}
```

Path notes: after combat 1 the player is still at [3,3] (combat doesn't move the field piece); left → [2,3], up → [2,2], left → [1,2] is the bed's cell → blocked, faces bed; interact sleeps. Then down → [2,3], right ×5 → [7,3], down → [7,4], right → [8,4] encounter2 blocked/faces, interact. The riposte assertion requires a seed where the PC gets melee-hit in fight 2 while adjacent — near-certain with a melee raider, but verify with the chosen seed; if it doesn't trigger, pick the next seed that wins both fights AND triggers it, and record it.

- [ ] **Step 5: Run both, headless, with the chosen seed**

```
wandering_inn_game_v4/qa/run_qa.sh combat_walkthrough headless --seed=7
wandering_inn_game_v4/qa/run_qa.sh level_up_loop headless --seed=7
wandering_inn_game_v4/qa/run_qa.sh skeleton_walkthrough headless
wandering_inn_game_v4/qa/run_qa.sh load_gate headless
```
All `QA_RESULT: PASS`. Include both result.json contents in the report.

- [ ] **Step 6: Commit**

`git add wandering_inn_game_v4 && git commit -m "Extend TestDriver for combat QA; add combat and level-up-loop playtest scripts"`

---

### Task 10: Docs, windowed screenshot verification, HANDOFF

**Files:**
- Modify: `wandering_inn_game_v4/CLAUDE.md`, `/Users/gabriel/wandering_inn_rpg/HANDOFF.md`

- [ ] **Step 1: Windowed runs + read the PNGs**

```
wandering_inn_game_v4/qa/run_qa.sh combat_walkthrough windowed --seed=<chosen>
wandering_inn_game_v4/qa/run_qa.sh level_up_loop windowed --seed=<chosen>
```
Both PASS; read `01_combat_start.png` (grid, four combatants, HP bars, turn strip legible), `02_victory_banner.png` (banner text), `01_level_up_toast.png` (toast `[Fighter Level 2] — unlocked [Counter Strike], [Battle Momentum]`), `02_second_fight.png` with the Read tool and confirm a first-time player would understand each. Confirm NO raw stat numbers and NO damage numbers appear in any frame.

- [ ] **Step 2: Update `wandering_inn_game_v4/CLAUDE.md`**

Add to Commands:

```
	# Combat + progression tests
	/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_combat_data.gd
	/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_combat_sim.gd
	/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_progression.gd

	# Balance harness — 200 seeded AI-vs-AI fights; the authority on combat data tuning
	/usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/sim_combat_batch.gd

	# Combat QA scripts REQUIRE a fixed seed (deterministic fights)
	wandering_inn_game_v4/qa/run_qa.sh combat_walkthrough headless --seed=<n>
	wandering_inn_game_v4/qa/run_qa.sh level_up_loop headless --seed=<n>
```

Add to Architecture: one paragraph each for `WICombat`/`WISkillEffects`/`WICombatAI` (pure combat sim, effect registry, deterministic AI) and `WIProgression` (sleep-beat leveling, classes.json). Add convention: "Balance changes are `combatants.json`/`skills.json` edits validated by `sim_combat_batch.gd` — never tune by feel."

- [ ] **Step 3: Update `HANDOFF.md`** — replace the "Next: M1 planning" tail of the M0 section with M1 completion state: what shipped, the chosen QA seed(s), balance numbers + final batch distribution, and that final whole-branch review is next.

- [ ] **Step 4: Commit**

`git add wandering_inn_game_v4/CLAUDE.md HANDOFF.md && git commit -m "Document M1 combat systems, balance harness, and seeded combat QA"`

---

## Self-Review Notes

- **Spec coverage:** module layout (T3/T4/T5/T6/T8), combat rules incl. exact constants (T3), skill tranche (T2/T4), reactions (T3 hooks, T4 tests), progression counters/classes/sleep-only (T1/T6/T7), M1 loop content (T7), balance harness with spec bounds (T5), determinism assertion (T3), QA scripts + TestDriver extensions incl. array indexing/`combat.` root/payload_contains (T9), M0 deferred diagnostics (T1), no-damage-numbers + no-stats verified visually (T10), functional-minimal UI (T8). Spec's `data/skills.json` `die` field intentionally dormant (documented in T4 Step 3 note).
- **Known ordering exception:** T5's harness references `WIProgression` (T6); resolved via explicit hardcode-then-swap steps (T5 Step 2 note, T6 Step 5).
- **Type consistency check:** `WICombat` API names used in T4 (`is_adjacent`, `chebyshev`, `_resolve_hit`, `_emit`), T5 (`get_active`, `alive_enemies_of`, `is_cell_free`, `move_active`, `attack`, `use_skill`, `end_turn`, constants), T7 (`apply_damage`, `finished`, `outcome`, `combatants`), T8 (`snapshot`, `skills`, `blocked`, `grid_size`), T9 (`snapshot`, `combatants`, `get_active`, `finished`) — all defined in T3. `WIProgression.granted_skills/check_level_ups` (T6) match T5/T7 call sites. Event names in T8/T9 match T3/T7 emissions.
- The final whole-branch review is part of the subagent-driven-development process — do not skip it.
