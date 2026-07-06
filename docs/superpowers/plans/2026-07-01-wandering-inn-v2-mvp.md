# Wandering Inn RPG v2 MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable MVP slice of `wandering_inn_game_v2`: clone `godot-open-rpg`'s engine, add a new Wandering-Inn class/race/skill/leveling layer it doesn't have, and reskin two of its existing maps (house→Inn, town→Liscor) so a player can create a custom Fighter or Mage PC, talk to Erin, recruit Relc Grasstongue, and fight a Shield Spider using open-rpg's unmodified readiness-bar combat engine.

**Architecture:** New WI-specific Resources (`WIRaceData`, `WIClassData`, `PassiveEffect`, `ReactiveSkillGrant`/`ReactiveSkill`) live in a new `src/rpg/` folder alongside open-rpg's existing `src/combat/`, `src/field/`, `src/common/`. Content (races/classes/skills) is generated once by a small headless GDScript tool rather than hand-typed as `.tres` text, to avoid getting Godot's resource serialization format wrong by hand. The player character's `Battler`/`BattlerStats` are built dynamically at combat-start from `WIPlayerState`; companions and enemies stay hand-authored static `Battler` scenes, matching open-rpg's existing pattern.

**Tech Stack:** Godot 4.6.2 (GDScript), Dialogic plugin (bundled in the clone source), no external test framework (matches upstream convention — see Testing Strategy below).

**Design spec:** `/Users/gabriel/wandering_inn_rpg/docs/superpowers/specs/2026-07-01-wandering-inn-v2-design.md` — read this first for the why behind every decision below.

## Global Constraints

- Engine: Godot **4.6.2** exactly, installed at `/usr/local/bin/godot` on this machine.
- Every new `.gd` file needs a headless import pass before `class_name` registration works: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import`. Run this after any task that adds new scripts.
- **Stats are internal only.** `STR/DEX/CON/INT/WIS/CHA` and derived `BattlerStats` values are never displayed in any UI built in this plan — no task in this plan builds a stat-display screen.
- MVP scope only: Fighter + Mage classes, 5 races (selectable regardless of race/class lore-pairing — no race gating in this MVP), 1 companion (Relc Grasstongue), 1 enemy (Shield Spider), 2 locations (Wandering Inn interior, Liscor). Everything else from `wandering_inn_game_v1`'s data is explicitly deferred — do not add it in this plan. The exact 13 skills ported (9 direct, 4 reinterpreted) are enumerated in the design spec's "MVP skill mapping" section — do not add skills beyond that list (e.g. no Fighter `weapon_mastery`/level-10 content; it was never approved).
- The PC starts and stays at level 1 in their chosen class for this MVP (`WIPlayerState.create_character` sets `classes = {starting_class_id: 1}` and nothing increments it). The data model supports higher levels (`WIClassData.level_skills` has entries above level 1), but the accomplishment-tracking mechanism that would actually trigger a level-up during play is out of scope — nothing in the MVP playtest loop (one fight) would exercise it anyway.
- Lore reference for any flavor text/description: https://wiki.wanderinginn.com/The_Wandering_Inn_Wiki
- **No new test framework.** Neither `godot-open-rpg` nor `wandering_inn_game_v1` has one configured, and none should be introduced. Verification uses one of two methods, specified per task:
  - **Logic tests**: standalone headless GDScript scripts extending `SceneTree`, run via `godot --headless --path <project> --script res://tests/<name>.gd`, using `assert()` and a final `print("PASS: ...")`. These live in `tests/` and are throwaway verification aids, not a suite that runs in CI.
  - **Integration checks**: `godot --headless --path <project> --quit` to catch parse/autoload errors, plus an explicit manual play-test checklist (steps to take in a running `godot --path <project>` window, and what you should see).
- All new WI-authored GDScript files get a `class_name` per Godot convention (matching every existing script in `godot-open-rpg`); autoload scripts do not (matching `src/common/player.gd`'s existing convention).

## File Structure

New/modified files in `wandering_inn_game_v2/` (created by Task 1 as a clone of `godot-open-rpg`):

```
src/
  combat/
    battlers/battler.gd            (MODIFY: add hit_taken/dealt_killing_blow signals)
    actions/battler_hit.gd         (MODIFY: add `source` field)
    actions/battler_action_attack.gd (MODIFY: pass `source` into BattlerHit)
  rpg/
    data/
      wi_race_data.gd              (NEW: WIRaceData resource)
      passive_effect.gd            (NEW: PassiveEffect resource)
      wi_class_data.gd             (NEW: WIClassData resource)
    reactive_skills/
      reactive_skill.gd            (NEW: abstract ReactiveSkill resource)
      reactive_skill_counter_strike.gd (NEW: CounterStrikeSkill)
      reactive_skill_battle_momentum.gd (NEW: BattleMomentumSkill)
      reactive_skill_grant.gd      (NEW: ReactiveSkillGrant resource)
      reactive_skill_controller.gd (NEW: ReactiveSkillController node)
    actions/
      battler_action_power_strike.gd (NEW: PowerStrikeBattlerAction)
      battler_action_arm_reactive_skill.gd (NEW: ArmReactiveSkillAction)
    state/
      wi_player_state.gd           (NEW autoload: WIPlayerState)
      wi_class_catalog.gd          (NEW autoload: WIClassCatalog)
    pc_battler_builder.gd          (NEW: PCBattlerBuilder static helpers)
    ui/
      character_creation.gd        (NEW: new run/main_scene script)
      character_creation.tscn      (NEW)
tools/
  build_content.gd                 (NEW: one-shot content generator)
tests/
  test_engine_hooks.gd             (NEW)
  verify_content.gd                (NEW)
combat/
  races/{human,drake,gnoll,antinium,half_elf}.tres  (NEW, generated)
  classes/{fighter,mage}.tres                       (NEW, generated)
  skills/shared/basic_attack.tres                   (NEW, generated)
  battlers/relc/{relc_stats.tres, relc_attack.tres, relc_power_strike.tres} (NEW, hand-authored)
  battlers/shield_spider/{shield_spider_stats.tres, shield_spider_attack.tres} (NEW, hand-authored)
overworld/
  maps/house/... (MODIFY within src/main.tscn: remove PedestalPuzzle/TreasureChest, add Erin NPC)
  maps/town/...  (MODIFY within src/main.tscn: add Relc NPC + Shield Spider CombatTrigger)
  maps/house/erin_intro.dtl        (NEW)
  maps/house/erin.dch              (NEW)
  maps/town/relc_recruit.dtl       (NEW)
  maps/town/relc.dch               (NEW)
  maps/town/relc_recruit_interaction.gd (NEW)
  maps/town/battles/liscor_combat_arena.tscn (NEW)
  maps/town/battles/liscor_combat_arena.gd   (NEW)
project.godot (MODIFY: new autoloads, run/main_scene, dialogic directories)
```

---

### Task 1: Bootstrap `wandering_inn_game_v2`

**Files:**
- Create: `wandering_inn_game_v2/` (entire directory, cloned from `godot-open-rpg/`)
- Modify: `wandering_inn_game_v2/project.godot:3` (`config/name`)

**Interfaces:** None (first task).

- [ ] **Step 1: Clone the project**

```bash
cd /Users/gabriel/wandering_inn_rpg
cp -R godot-open-rpg wandering_inn_game_v2
rm -rf wandering_inn_game_v2/.git
```

- [ ] **Step 2: Rename the project**

Edit `wandering_inn_game_v2/project.godot`, change:
```ini
config/name="OpenRPG"
```
to:
```ini
config/name="Wandering Inn"
```

- [ ] **Step 3: Verify the clone runs headlessly**

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit`
Expected: exits cleanly (exit code 0), no `SCRIPT ERROR` or `Parse Error` lines in output. Some `.godot/` cache-rebuild output on first run is normal.

- [ ] **Step 4: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2
git commit -m "$(cat <<'EOF'
Bootstrap wandering_inn_game_v2 from godot-open-rpg clone

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Battler engine hooks (hit source tracking, reactive-skill signals)

These are small, additive changes to open-rpg's core combat files, needed so later tasks can implement Counter Strike (reactive to being hit) and Battle Momentum (reactive to landing a killing blow) without subclassing `Battler` itself.

**Files:**
- Modify: `wandering_inn_game_v2/src/combat/actions/battler_hit.gd`
- Modify: `wandering_inn_game_v2/src/combat/battlers/battler.gd`
- Modify: `wandering_inn_game_v2/src/combat/actions/battler_action_attack.gd`
- Test: `wandering_inn_game_v2/tests/test_engine_hooks.gd`

**Interfaces:**
- Produces: `BattlerHit._init(dmg: int, to_hit: float = 100.0, hit_source: Battler = null)`, `BattlerHit.source: Battler`
- Produces: `Battler.hit_taken(hit: BattlerHit)` signal, `Battler.dealt_killing_blow` signal

- [ ] **Step 1: Add `source` to `BattlerHit`**

Replace the full contents of `src/combat/actions/battler_hit.gd`:

```gdscript
## Represents a damage-dealing hit to be applied to a target Battler.
## Encapsulates calculations for how hits are applied based on some properties.
class_name BattlerHit extends RefCounted

var damage: = 0
var hit_chance: = 100.0
## The Battler that caused this hit, if any. Used by reactive skills (e.g. counter-attacks)
## that need to retaliate against whoever landed the hit.
var source: Battler = null


func _init(dmg: int, to_hit := 100.0, hit_source: Battler = null) -> void:
	damage = dmg
	hit_chance = to_hit
	source = hit_source


func is_successful() -> bool:
	return randf() * 100.0 < hit_chance
```

- [ ] **Step 2: Add reactive-skill signals to `Battler`**

In `src/combat/battlers/battler.gd`, add two signals near the top alongside the existing ones (after `signal selection_toggled(value: bool)`):

```gdscript
## Emitted whenever this Battler successfully receives a hit, before checking if it was lethal.
## Used by reactive skills (e.g. Counter Strike) that trigger off being hit.
signal hit_taken(hit: BattlerHit)
## Emitted when this Battler's action reduces a target's health to 0 or below.
## Used by reactive skills (e.g. Battle Momentum) that trigger off landing a killing blow.
signal dealt_killing_blow
```

Then replace the `take_hit` function body:

```gdscript
func take_hit(hit: BattlerHit) -> void:
	if hit.is_successful():
		hit_received.emit(hit.damage)
		stats.health -= hit.damage
		hit_taken.emit(hit)
		if stats.health <= 0 and hit.source:
			hit.source.dealt_killing_blow.emit()
	else:
		hit_missed.emit()
```

- [ ] **Step 3: Pass `source` into the `BattlerHit` created by `AttackBattlerAction`**

In `src/combat/actions/battler_action_attack.gd`, change:
```gdscript
		var hit: = BattlerHit.new(damage_dealt, to_hit)
```
to:
```gdscript
		var hit: = BattlerHit.new(damage_dealt, to_hit, source)
```

- [ ] **Step 4: Run headless import to register the changes**

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import`
Expected: no `SCRIPT ERROR` lines.

- [ ] **Step 5: Write and run a logic test for `BattlerHit.source`**

Create `tests/test_engine_hooks.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	# Battler.new() works standalone: _ready() (which needs `stats` and a BattlerRoster
	# parent) only fires on add_child, so a bare instance is fine for this field check.
	var fake_battler: = Battler.new()

	var hit_no_source: = BattlerHit.new(10, 100.0)
	assert(hit_no_source.source == null, "default source should be null")

	var hit_with_source: = BattlerHit.new(10, 100.0, fake_battler)
	assert(hit_with_source.source == fake_battler, "source should store the given Battler")

	print("PASS: BattlerHit.source field wired correctly")
	quit()
```

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --script res://tests/test_engine_hooks.gd`
Expected output: `PASS: BattlerHit.source field wired correctly`, exit code 0.

- [ ] **Step 6: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/src/combat wandering_inn_game_v2/tests
git commit -m "$(cat <<'EOF'
Add hit-source tracking and reactive-skill signals to Battler

Additive-only changes to open-rpg's core combat classes: BattlerHit now
carries an optional source Battler, and Battler emits hit_taken/
dealt_killing_blow so WI-specific reactive skills (Counter Strike,
Battle Momentum) can hook in without subclassing Battler.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Core WI resource script definitions

**Files:**
- Create: `wandering_inn_game_v2/src/rpg/data/wi_race_data.gd`
- Create: `wandering_inn_game_v2/src/rpg/data/passive_effect.gd`
- Create: `wandering_inn_game_v2/src/rpg/data/wi_class_data.gd`
- Create: `wandering_inn_game_v2/src/rpg/reactive_skills/reactive_skill.gd`
- Create: `wandering_inn_game_v2/src/rpg/reactive_skills/reactive_skill_counter_strike.gd`
- Create: `wandering_inn_game_v2/src/rpg/reactive_skills/reactive_skill_battle_momentum.gd`
- Create: `wandering_inn_game_v2/src/rpg/reactive_skills/reactive_skill_grant.gd`
- Test: `wandering_inn_game_v2/tests/test_wi_resources.gd`

**Interfaces:**
- Consumes: `BattlerStats.add_modifier(stat_name: String, value: int) -> int`, `BattlerStats.add_multiplier(stat_name: String, value: float) -> int` (existing, `src/combat/battlers/battler_stats.gd`)
- Consumes: `Battler.stats`, `Battler.hit_taken`, `Battler.dealt_killing_blow` (from Task 2)
- Produces: `WIRaceData{id, display_name, stat_bonus: Dictionary, trait_name, trait_desc}`
- Produces: `PassiveEffect{display_name, description, stat_name, modifier_value: int, multiplier_value: float, is_multiplier: bool, special_id: String}.apply_to(stats: BattlerStats) -> void`
- Produces: `WIClassData{id, display_name, gained_by, level_skills: Dictionary}.get_skills_up_to_level(level: int) -> Array[Resource]`
- Produces: `ReactiveSkill.on_trigger(battler: Battler, context: Dictionary) -> void` (abstract), `CounterStrikeSkill{damage_mult}`, `BattleMomentumSkill{speed_bonus}`
- Produces: `ReactiveSkillGrant{trigger: Trigger enum(ON_HIT_TAKEN, ON_KILL), skill: ReactiveSkill, requires_activation: bool, controller_name: String}`

- [ ] **Step 1: Write `WIRaceData`**

Create `src/rpg/data/wi_race_data.gd`:

```gdscript
## A playable race's flavor and internal stat bonuses. Stat values are never shown to the
## player directly (The Wandering Inn has no visible stat sheet) — they only feed into
## BattlerStats derivation in PCBattlerBuilder.
class_name WIRaceData extends Resource

@export var id: String = ""
@export var display_name: String = ""
## Internal-only. Keys: "STR","DEX","CON","INT","WIS","CHA". Never displayed in UI.
@export var stat_bonus: Dictionary = {}
@export var trait_name: String = ""
@export var trait_desc: String = ""
```

- [ ] **Step 2: Write `PassiveEffect`**

Create `src/rpg/data/passive_effect.gd`:

```gdscript
## A passive skill effect applied to a Battler's stats when its granting class level is reached.
## An empty `stat_name` means the skill is flavor-only with no mechanical effect.
class_name PassiveEffect extends Resource

@export var display_name: String = ""
@export var description: String = ""
## One of BattlerStats.MODIFIABLE_STATS, or "" for a flavor-only skill with no mechanical effect.
@export var stat_name: String = ""
@export var modifier_value: int = 0
@export var multiplier_value: float = 0.0
@export var is_multiplier: bool = false
## Non-empty for skills PCBattlerBuilder handles as special cases (e.g. "quick_cast",
## "spell_evolution") rather than a plain stat modifier.
@export var special_id: String = ""


func apply_to(stats: BattlerStats) -> void:
	if stat_name == "":
		return
	if is_multiplier:
		stats.add_multiplier(stat_name, multiplier_value)
	else:
		stats.add_modifier(stat_name, modifier_value)
```

- [ ] **Step 3: Write `WIClassData`**

Create `src/rpg/data/wi_class_data.gd`:

```gdscript
## A Wandering-Inn-style class: no XP, gained by meeting a narrative condition and leveled by
## tracked accomplishments. `level_skills` maps a level threshold to the skills granted at that
## level — each entry is a PassiveEffect, a BattlerAction, or a ReactiveSkillGrant.
class_name WIClassData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var gained_by: String = ""
## Dictionary[int, Array[Resource]]. Left untyped so hand- or script-generated .tres files
## don't need to match Godot's typed-container serialization format exactly.
@export var level_skills: Dictionary = {}


func get_skills_up_to_level(level: int) -> Array[Resource]:
	var result: Array[Resource] = []
	for lvl in level_skills:
		if int(lvl) <= level:
			var skills: Array = level_skills[lvl]
			for skill in skills:
				result.append(skill)
	return result
```

- [ ] **Step 4: Write the `ReactiveSkill` base class and its two MVP subclasses**

Create `src/rpg/reactive_skills/reactive_skill.gd`:

```gdscript
## Base for skills that trigger reactively (off being hit, or off landing a killing blow)
## rather than being chosen from the action menu. See ReactiveSkillController.
@abstract
class_name ReactiveSkill extends Resource

@export var display_name: String = ""
@export var description: String = ""

@abstract
func on_trigger(battler: Battler, context: Dictionary) -> void
```

Create `src/rpg/reactive_skills/reactive_skill_counter_strike.gd`:

```gdscript
## Ports Fighter's "Counter Strike": once armed, the next hit taken triggers an immediate
## counter-attack against whoever landed it, at a fraction of normal weapon damage.
class_name CounterStrikeSkill extends ReactiveSkill

@export var damage_mult: float = 0.8


func on_trigger(battler: Battler, context: Dictionary) -> void:
	var attacker: Battler = context.get("attacker")
	if attacker == null or attacker.stats.health <= 0:
		return
	var damage: = int(battler.stats.attack * damage_mult)
	var hit: = BattlerHit.new(damage, 100.0, battler)
	attacker.take_hit(hit)
```

Create `src/rpg/reactive_skills/reactive_skill_battle_momentum.gd`:

```gdscript
## Reinterpretation of Fighter's "Battle Momentum" (originally "+1 AP on kill", which has no
## equivalent in a non-AP readiness-bar system): grants a permanent-for-the-battle speed boost
## whenever the battler lands a killing blow.
class_name BattleMomentumSkill extends ReactiveSkill

@export var speed_bonus: int = 5


func on_trigger(battler: Battler, context: Dictionary) -> void:
	battler.stats.add_modifier("speed", speed_bonus)
```

- [ ] **Step 5: Write `ReactiveSkillGrant`**

Create `src/rpg/reactive_skills/reactive_skill_grant.gd`:

```gdscript
## A WIClassData.level_skills entry that grants a ReactiveSkill. If `requires_activation` is
## true, the player must first select an arm action (see ArmReactiveSkillAction) before the
## skill can trigger; otherwise it is always active once granted.
class_name ReactiveSkillGrant extends Resource

enum Trigger { ON_HIT_TAKEN, ON_KILL }

@export var trigger: Trigger = Trigger.ON_HIT_TAKEN
@export var skill: ReactiveSkill
@export var requires_activation: bool = false
## Node name given to the runtime ReactiveSkillController so an ArmReactiveSkillAction can find
## it via `source.get_node(controller_name)`. Only meaningful when requires_activation is true.
@export var controller_name: String = ""
```

- [ ] **Step 6: Run headless import**

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import`
Expected: no `SCRIPT ERROR` lines.

- [ ] **Step 7: Write and run a logic test**

Create `tests/test_wi_resources.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var race := WIRaceData.new()
	race.id = "human"
	race.stat_bonus = {"STR": 1, "DEX": 1}
	assert(race.stat_bonus["DEX"] == 1)

	var effect := PassiveEffect.new()
	effect.stat_name = "max_health"
	effect.modifier_value = 10
	var stats := BattlerStats.new()
	effect.apply_to(stats)
	assert(stats.max_health == 110, "expected 100 + 10, got %s" % stats.max_health)

	var flavor_only := PassiveEffect.new()
	flavor_only.stat_name = ""
	flavor_only.apply_to(stats) # must be a no-op, not crash
	assert(stats.max_health == 110, "flavor-only effect must not change stats")

	var skill_a := PassiveEffect.new()
	var skill_b := PassiveEffect.new()
	var class_data := WIClassData.new()
	class_data.level_skills = {1: [skill_a], 3: [skill_b]}
	assert(class_data.get_skills_up_to_level(1).size() == 1)
	assert(class_data.get_skills_up_to_level(2).size() == 1)
	assert(class_data.get_skills_up_to_level(3).size() == 2)

	var grant := ReactiveSkillGrant.new()
	grant.trigger = ReactiveSkillGrant.Trigger.ON_KILL
	assert(grant.trigger == ReactiveSkillGrant.Trigger.ON_KILL)

	print("PASS: WI resource scripts behave correctly")
	quit()
```

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --script res://tests/test_wi_resources.gd`
Expected: `PASS: WI resource scripts behave correctly`, exit code 0.

- [ ] **Step 8: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/src/rpg wandering_inn_game_v2/tests
git commit -m "$(cat <<'EOF'
Add core WI race/class/skill resource types

WIRaceData, PassiveEffect, WIClassData, and the ReactiveSkill framework
(CounterStrikeSkill, BattleMomentumSkill, ReactiveSkillGrant) — the new
progression layer open-rpg has no equivalent of.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Reactive skill controller and new BattlerAction subclasses

**Files:**
- Create: `wandering_inn_game_v2/src/rpg/reactive_skills/reactive_skill_controller.gd`
- Create: `wandering_inn_game_v2/src/rpg/actions/battler_action_arm_reactive_skill.gd`
- Create: `wandering_inn_game_v2/src/rpg/actions/battler_action_power_strike.gd`

**Interfaces:**
- Consumes: `Battler.hit_taken`, `Battler.dealt_killing_blow` (Task 2); `ReactiveSkill.on_trigger`, `ReactiveSkillGrant.Trigger` (Task 3)
- Consumes: `AttackBattlerAction` (existing, `src/combat/actions/battler_action_attack.gd`) — `PowerStrikeBattlerAction` extends it
- Produces: `ReactiveSkillController{trigger, skill, is_armed: bool, requires_activation: bool}` (Node, attached as a child of a Battler)
- Produces: `ArmReactiveSkillAction extends BattlerAction {controller_name: String}`
- Produces: `PowerStrikeBattlerAction extends AttackBattlerAction {damage_mult: float}`

- [ ] **Step 1: Write `ReactiveSkillController`**

Create `src/rpg/reactive_skills/reactive_skill_controller.gd`:

```gdscript
## Attached as a runtime child of a Battler to wire a ReactiveSkill to that Battler's
## hit_taken/dealt_killing_blow signals. See PCBattlerBuilder.attach_reactive_controllers.
class_name ReactiveSkillController extends Node

@export var trigger: ReactiveSkillGrant.Trigger = ReactiveSkillGrant.Trigger.ON_HIT_TAKEN
@export var skill: ReactiveSkill
@export var requires_activation: bool = false

var is_armed: bool = false


func _ready() -> void:
	var battler: = get_parent() as Battler
	assert(battler, "ReactiveSkillController must be a direct child of a Battler.")
	if trigger == ReactiveSkillGrant.Trigger.ON_HIT_TAKEN:
		battler.hit_taken.connect(_on_hit_taken)
	else:
		battler.dealt_killing_blow.connect(_on_dealt_killing_blow)


func _on_hit_taken(hit: BattlerHit) -> void:
	if requires_activation and not is_armed:
		return
	is_armed = false
	skill.on_trigger(get_parent() as Battler, {"attacker": hit.source})


func _on_dealt_killing_blow() -> void:
	skill.on_trigger(get_parent() as Battler, {})
```

- [ ] **Step 2: Write `ArmReactiveSkillAction`**

Create `src/rpg/actions/battler_action_arm_reactive_skill.gd`:

```gdscript
## A self-targeted BattlerAction that arms a ReactiveSkillController on the acting Battler
## (e.g. selecting "Counter Strike" from the menu arms the counter for the next hit taken).
class_name ArmReactiveSkillAction extends BattlerAction

@export var controller_name: String = ""


func execute() -> void:
	var controller: = source.get_node_or_null(controller_name) as ReactiveSkillController
	assert(controller, "ArmReactiveSkillAction could not find controller '%s' on %s" % [controller_name, source.name])
	controller.is_armed = true
	await source.get_tree().process_frame
```

- [ ] **Step 3: Write `PowerStrikeBattlerAction`**

This mirrors `AttackBattlerAction.execute()` exactly (matching the codebase's existing convention of each action being a fully self-contained `execute()`, rather than trying to share code via composition), with `damage_mult` applied to the damage formula.

Create `src/rpg/actions/battler_action_power_strike.gd`:

```gdscript
## Ports Fighter's "Power Strike": a single melee hit at damage_mult (150%) weapon damage.
## Mirrors AttackBattlerAction.execute() exactly, with the multiplier applied.
class_name PowerStrikeBattlerAction extends AttackBattlerAction

@export var damage_mult: float = 1.5


func execute() -> void:
	assert(not cached_targets.is_empty(), "Power Strike requires a target.")
	var first_target: = cached_targets[0]

	await source.get_tree().create_timer(0.1).timeout

	var origin: = source.position
	var attack_normal: float = sign(source.position.x - first_target.position.x)
	var destination: = first_target.position + Vector2(ATTACK_DISTANCE * attack_normal, 0)

	var tween: = source.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(source, "position", destination, 0.25)
	await tween.finished

	await source.get_tree().create_timer(0.1).timeout
	for target in cached_targets:
		var modified_damage: = (base_damage + source.stats.attack) * damage_mult
		var damage_dealt: = modified_damage + (randf() - 0.5) * 0.2 * modified_damage
		var to_hit: = hit_chance * (source.stats.hit_chance / 100.0)
		var hit: = BattlerHit.new(int(damage_dealt), to_hit, source)
		target.take_hit(hit)
		await source.get_tree().create_timer(0.1).timeout

	await source.get_tree().create_timer(0.1).timeout
	tween = source.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(source, "position", origin, 0.25)
	await tween.finished
	await source.get_tree().create_timer(0.1).timeout
```

- [ ] **Step 4: Run headless import**

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import`
Expected: no `SCRIPT ERROR` lines. (`ArmReactiveSkillAction` and `PowerStrikeBattlerAction` can't be meaningfully unit-tested standalone — they require a live `Battler` in a scene tree. They're exercised in Task 11's manual playtest.)

- [ ] **Step 5: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/src/rpg
git commit -m "$(cat <<'EOF'
Add ReactiveSkillController and Power Strike / arm-skill actions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Generate race/class/skill content

Content is generated by a one-shot headless script rather than hand-typed as `.tres` text, to avoid getting Godot's resource serialization format wrong by hand (this matters especially for `WIClassData.level_skills`, a `Dictionary` of `Array[Resource]`).

**Files:**
- Create: `wandering_inn_game_v2/tools/build_content.gd`
- Create: `wandering_inn_game_v2/tests/verify_content.gd`
- Generates: `combat/races/{human,drake,gnoll,antinium,half_elf}.tres`, `combat/classes/{fighter,mage}.tres`, `combat/skills/shared/basic_attack.tres`

**Interfaces:**
- Consumes: `WIRaceData`, `PassiveEffect`, `WIClassData`, `CounterStrikeSkill`, `BattleMomentumSkill`, `ReactiveSkillGrant` (Task 3), `PowerStrikeBattlerAction` (Task 4)
- Consumes: `RangedBattlerAction`, `AttackBattlerAction` (existing, `src/combat/actions/`)
- Produces: on-disk `.tres` resources consumed by `WIClassCatalog` (Task 6) and `PCBattlerBuilder` (Task 7)

- [ ] **Step 1: Create the output directories**

```bash
mkdir -p /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2/combat/races
mkdir -p /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2/combat/classes
mkdir -p /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2/combat/skills/shared
mkdir -p /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2/tools
```

- [ ] **Step 2: Write the content generator**

Create `tools/build_content.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	_build_races()
	_build_fighter()
	_build_mage()
	_build_shared_actions()
	print("Content generation complete.")
	quit()


func _build_races() -> void:
	var races: = [
		{"id": "human", "display_name": "Human", "stat_bonus": {"STR": 1, "DEX": 1, "CON": 1, "INT": 1, "WIS": 1, "CHA": 1},
			"trait_name": "Versatile", "trait_desc": "Adapts quickly to any walk of life, picking up new techniques with ease."},
		{"id": "drake", "display_name": "Drake", "stat_bonus": {"STR": 1, "DEX": 2, "CON": 1, "INT": 0, "WIS": 0, "CHA": 0},
			"trait_name": "Drake Heritage", "trait_desc": "Tail Sweep: a free action once per combat to knock adjacent enemies prone."},
		{"id": "gnoll", "display_name": "Gnoll", "stat_bonus": {"STR": 2, "DEX": 0, "CON": 0, "INT": 0, "WIS": 2, "CHA": 0},
			"trait_name": "Pack Hunter", "trait_desc": "Deals bonus damage fighting alongside an ally, and senses hidden enemies nearby."},
		{"id": "antinium", "display_name": "Antinium", "stat_bonus": {"STR": 3, "DEX": 0, "CON": 3, "INT": 0, "WIS": 0, "CHA": -2},
			"trait_name": "Four Arms", "trait_desc": "Dual-wields without penalty and gains its first class faster than other races."},
		{"id": "half_elf", "display_name": "Half-Elf", "stat_bonus": {"STR": 0, "DEX": 0, "CON": 0, "INT": 3, "WIS": 1, "CHA": -1},
			"trait_name": "Magic Affinity", "trait_desc": "Begins already knowing a touch of magic, even without training as a Mage."},
	]
	for race_dict in races:
		var race: = WIRaceData.new()
		race.id = race_dict["id"]
		race.display_name = race_dict["display_name"]
		race.stat_bonus = race_dict["stat_bonus"]
		race.trait_name = race_dict["trait_name"]
		race.trait_desc = race_dict["trait_desc"]
		ResourceSaver.save(race, "res://combat/races/%s.tres" % race.id)


func _build_fighter() -> void:
	var basic_swordwork: = PassiveEffect.new()
	basic_swordwork.display_name = "Basic Swordwork"
	basic_swordwork.description = "+5% hit chance with all melee weapons."
	basic_swordwork.stat_name = "hit_chance"
	basic_swordwork.modifier_value = 5

	var tough_body: = PassiveEffect.new()
	tough_body.display_name = "Tough Body"
	tough_body.description = "+10 maximum HP."
	tough_body.stat_name = "max_health"
	tough_body.modifier_value = 10

	var counter_strike_skill: = CounterStrikeSkill.new()
	counter_strike_skill.display_name = "Counter Strike"
	counter_strike_skill.description = "Riposte: the next melee attack that hits you triggers an immediate counter-attack at 80% of your normal weapon damage."
	counter_strike_skill.damage_mult = 0.8

	var counter_strike: = ReactiveSkillGrant.new()
	counter_strike.trigger = ReactiveSkillGrant.Trigger.ON_HIT_TAKEN
	counter_strike.skill = counter_strike_skill
	counter_strike.requires_activation = true
	counter_strike.controller_name = "CounterStrikeController"

	var power_strike: = PowerStrikeBattlerAction.new()
	power_strike.name = "Power Strike"
	power_strike.description = "Strike with 150% weapon damage in a single powerful blow."
	power_strike.target_scope = BattlerAction.TargetScope.SINGLE
	power_strike.targets_enemies = true
	power_strike.energy_cost = 2
	power_strike.damage_mult = 1.5

	var battle_momentum_skill: = BattleMomentumSkill.new()
	battle_momentum_skill.display_name = "Battle Momentum"
	battle_momentum_skill.description = "Gain a burst of speed whenever you land a killing blow."
	battle_momentum_skill.speed_bonus = 5

	var battle_momentum: = ReactiveSkillGrant.new()
	battle_momentum.trigger = ReactiveSkillGrant.Trigger.ON_KILL
	battle_momentum.skill = battle_momentum_skill
	battle_momentum.requires_activation = false

	var guard_formation: = PassiveEffect.new()
	guard_formation.display_name = "Guard Formation"
	guard_formation.description = "You know how to hold a defensive line with allies at your side."

	var fighter: = WIClassData.new()
	fighter.id = "fighter"
	fighter.display_name = "Fighter"
	fighter.gained_by = "Win 5 melee combats"
	fighter.level_skills = {
		1: [basic_swordwork, tough_body],
		2: [counter_strike],
		3: [power_strike],
		4: [battle_momentum, guard_formation],
	}
	ResourceSaver.save(fighter, "res://combat/classes/fighter.tres")


func _build_mage() -> void:
	var mana_sense: = PassiveEffect.new()
	mana_sense.display_name = "Mana Sense"
	mana_sense.description = "You can feel the presence of active spells and enchantments nearby."

	var magic_missile: = RangedBattlerAction.new()
	magic_missile.name = "Magic Missile"
	magic_missile.description = "A bolt of raw force hurled at a single enemy."
	magic_missile.target_scope = BattlerAction.TargetScope.SINGLE
	magic_missile.targets_enemies = true
	magic_missile.energy_cost = 2
	magic_missile.base_damage = 30

	var arcane_sight: = PassiveEffect.new()
	arcane_sight.display_name = "Arcane Sight"
	arcane_sight.description = "You can perceive faint traces of magic others would miss."

	var fire_bolt: = RangedBattlerAction.new()
	fire_bolt.name = "Fire Bolt"
	fire_bolt.description = "A searing bolt of flame."
	fire_bolt.target_scope = BattlerAction.TargetScope.SINGLE
	fire_bolt.targets_enemies = true
	fire_bolt.energy_cost = 4
	fire_bolt.base_damage = 55

	var quick_cast: = PassiveEffect.new()
	quick_cast.display_name = "Quick Cast"
	quick_cast.description = "Your spells cost 1 less mana to cast."
	quick_cast.special_id = "quick_cast"

	var mana_conservation: = PassiveEffect.new()
	mana_conservation.display_name = "Mana Conservation"
	mana_conservation.description = "+4 maximum mana."
	mana_conservation.stat_name = "max_energy"
	mana_conservation.modifier_value = 4

	var spell_evolution: = PassiveEffect.new()
	spell_evolution.display_name = "Spell Evolution"
	spell_evolution.description = "Your Fire Bolt deals significantly more damage."
	spell_evolution.special_id = "spell_evolution"

	var mage: = WIClassData.new()
	mage.id = "mage"
	mage.display_name = "Mage"
	mage.gained_by = "Cast 5 spells successfully"
	mage.level_skills = {
		1: [mana_sense, magic_missile],
		2: [arcane_sight],
		3: [fire_bolt, quick_cast],
		4: [mana_conservation],
		10: [spell_evolution],
	}
	ResourceSaver.save(mage, "res://combat/classes/mage.tres")


func _build_shared_actions() -> void:
	var basic_attack: = AttackBattlerAction.new()
	basic_attack.name = "Attack"
	basic_attack.description = "A basic weapon strike."
	basic_attack.target_scope = BattlerAction.TargetScope.SINGLE
	basic_attack.targets_enemies = true
	basic_attack.energy_cost = 0
	basic_attack.base_damage = 15
	ResourceSaver.save(basic_attack, "res://combat/skills/shared/basic_attack.tres")
```

- [ ] **Step 3: Run headless import, then run the generator**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --script res://tools/build_content.gd
```
Expected: final line `Content generation complete.`, and these files now exist:
```bash
ls /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2/combat/races/
ls /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2/combat/classes/
ls /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2/combat/skills/shared/
```

- [ ] **Step 4: Write and run the content verification script**

Create `tests/verify_content.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var human: = load("res://combat/races/human.tres") as WIRaceData
	assert(human != null, "human.tres failed to load")
	assert(human.stat_bonus["DEX"] == 1, "human DEX bonus wrong")

	var fighter: = load("res://combat/classes/fighter.tres") as WIClassData
	assert(fighter != null, "fighter.tres failed to load")
	assert(fighter.level_skills[1].size() == 2, "fighter level 1 should grant 2 skills")
	assert(fighter.level_skills[2][0] is ReactiveSkillGrant, "fighter level 2 skill should be a ReactiveSkillGrant")
	assert(fighter.level_skills[3][0] is PowerStrikeBattlerAction, "fighter level 3 skill should be Power Strike")

	var mage: = load("res://combat/classes/mage.tres") as WIClassData
	assert(mage != null, "mage.tres failed to load")
	assert(mage.level_skills[1][1] is RangedBattlerAction, "mage level 1 should grant Magic Missile action")
	assert(mage.level_skills[3][1].special_id == "quick_cast", "mage level 3 should include quick_cast marker")

	var basic_attack: = load("res://combat/skills/shared/basic_attack.tres") as AttackBattlerAction
	assert(basic_attack != null, "basic_attack.tres failed to load")

	print("PASS: all content resources load correctly")
	quit()
```

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --script res://tests/verify_content.gd`
Expected: `PASS: all content resources load correctly`, exit code 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/tools wandering_inn_game_v2/tests wandering_inn_game_v2/combat/races wandering_inn_game_v2/combat/classes wandering_inn_game_v2/combat/skills
git commit -m "$(cat <<'EOF'
Generate Fighter/Mage class content and 5 WI races

Generated via tools/build_content.gd (a one-shot headless script)
rather than hand-typed .tres, avoiding hand-authoring Godot's typed
Dictionary/Array resource serialization format.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `WIClassCatalog` and `WIPlayerState` autoloads

**Files:**
- Create: `wandering_inn_game_v2/src/rpg/state/wi_class_catalog.gd`
- Create: `wandering_inn_game_v2/src/rpg/state/wi_player_state.gd`
- Modify: `wandering_inn_game_v2/project.godot` (`[autoload]` section)
- Test: `wandering_inn_game_v2/tests/test_player_state.gd`

**Interfaces:**
- Consumes: `WIClassData` (Task 3), `combat/classes/fighter.tres`, `combat/classes/mage.tres` (Task 5)
- Produces: autoload `WIClassCatalog.get_class_data(class_id: String) -> WIClassData`
- Produces: autoload `WIPlayerState.character_name/race/classes/has_relc`, `.create_character(p_name, p_race, starting_class_id)`, `.get_total_level() -> int`, `.get_unlocked_skills() -> Array[Resource]`

- [ ] **Step 1: Write `WIClassCatalog`**

Create `src/rpg/state/wi_class_catalog.gd`:

```gdscript
extends Node

var _classes: Dictionary = {}


func _ready() -> void:
	_classes["fighter"] = load("res://combat/classes/fighter.tres") as WIClassData
	_classes["mage"] = load("res://combat/classes/mage.tres") as WIClassData


func get_class_data(class_id: String) -> WIClassData:
	return _classes.get(class_id, null)


func get_all_classes() -> Array[WIClassData]:
	var result: Array[WIClassData] = []
	result.assign(_classes.values())
	return result
```

- [ ] **Step 2: Write `WIPlayerState`**

Create `src/rpg/state/wi_player_state.gd`:

```gdscript
extends Node

signal character_created

var character_name: String = ""
var race: WIRaceData = null
## class_id (String) -> level (int)
var classes: Dictionary = {}
var has_relc: bool = false


func create_character(p_name: String, p_race: WIRaceData, starting_class_id: String) -> void:
	character_name = p_name
	race = p_race
	classes = {starting_class_id: 1}
	has_relc = false
	character_created.emit()


func get_total_level() -> int:
	var total: = 0
	for lvl in classes.values():
		total += lvl
	return total


func get_unlocked_skills() -> Array[Resource]:
	var result: Array[Resource] = []
	for class_id in classes:
		var class_data: WIClassData = WIClassCatalog.get_class_data(class_id)
		if class_data:
			result.append_array(class_data.get_skills_up_to_level(classes[class_id]))
	return result
```

- [ ] **Step 3: Register both as autoloads**

In `project.godot`, add to the `[autoload]` section (order matters: `WIClassCatalog` must load before `WIPlayerState` since `WIPlayerState.get_unlocked_skills()` calls into it):

```ini
WIClassCatalog="*res://src/rpg/state/wi_class_catalog.gd"
WIPlayerState="*res://src/rpg/state/wi_player_state.gd"
```

- [ ] **Step 4: Run headless check**

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit`
Expected: no autoload/parse errors.

- [ ] **Step 5: Write and run a logic test**

Create `tests/test_player_state.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	await process_frame # let autoloads finish _ready()

	var fighter_data: WIClassData = WIClassCatalog.get_class_data("fighter")
	assert(fighter_data != null, "WIClassCatalog should have fighter registered")

	var human: = load("res://combat/races/human.tres") as WIRaceData
	WIPlayerState.create_character("Test Hero", human, "fighter")
	assert(WIPlayerState.get_total_level() == 1)

	var skills: = WIPlayerState.get_unlocked_skills()
	assert(skills.size() == 2, "level 1 fighter should have 2 unlocked skills, got %s" % skills.size())

	WIPlayerState.classes["fighter"] = 3
	skills = WIPlayerState.get_unlocked_skills()
	assert(skills.size() == 4, "level 3 fighter should have basic_swordwork+tough_body+counter_strike+power_strike (4), got %s" % skills.size())

	print("PASS: WIClassCatalog and WIPlayerState behave correctly")
	quit()
```

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --script res://tests/test_player_state.gd`
Expected: `PASS: WIClassCatalog and WIPlayerState behave correctly`, exit code 0. Project autoloads are expected to be available to a `--script`-run `SceneTree` (this is a standard headless-tooling pattern), but if `WIClassCatalog`/`WIPlayerState` come back as null/unresolved identifiers here, treat Step 4's `--quit` check (which uses the normal project bootstrap) as the authoritative signal instead and skip this standalone script.

- [ ] **Step 6: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/src/rpg/state wandering_inn_game_v2/project.godot wandering_inn_game_v2/tests
git commit -m "$(cat <<'EOF'
Add WIClassCatalog and WIPlayerState autoloads

The new leveling/progression state layer — open-rpg's Player autoload
has no equivalent (it only tracks the field gamepiece reference).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `PCBattlerBuilder`

**Files:**
- Create: `wandering_inn_game_v2/src/rpg/pc_battler_builder.gd`
- Test: `wandering_inn_game_v2/tests/test_pc_battler_builder.gd`

**Interfaces:**
- Consumes: `WIRaceData`, `PassiveEffect`, `ReactiveSkillGrant` (Task 3), `ReactiveSkillController` (Task 4), `WIPlayerState` (Task 6)
- Consumes: `BattlerStats` (existing), `Battler`, `BattlerAction`, `BattlerRoster`, `RangedBattlerAction` (existing)
- Produces: `PCBattlerBuilder.build_stats(race, total_level) -> BattlerStats`, `.apply_passive_effects(unlocked_skills, stats) -> void`, `.build_actions(unlocked_skills) -> Array[BattlerAction]`, `.finalize_actions(actions, pc_battler, roster) -> void`, `.attach_reactive_controllers(unlocked_skills, pc_battler) -> void`

- [ ] **Step 1: Write `PCBattlerBuilder`**

Create `src/rpg/pc_battler_builder.gd`:

```gdscript
## Builds a player character's BattlerStats/actions/reactive-skill controllers at runtime from
## WIPlayerState, since (unlike companions and enemies) the PC's race/class/level combination
## varies per playthrough rather than being a fixed, hand-authored Battler scene.
class_name PCBattlerBuilder extends RefCounted

const BASIC_ATTACK_PATH: = "res://combat/skills/shared/basic_attack.tres"


static func build_stats(race: WIRaceData, total_level: int) -> BattlerStats:
	var stats: = BattlerStats.new()
	var str_stat: int = 10 + int(race.stat_bonus.get("STR", 0))
	var dex_stat: int = 10 + int(race.stat_bonus.get("DEX", 0))
	var con_stat: int = 10 + int(race.stat_bonus.get("CON", 0))
	var int_stat: int = 10 + int(race.stat_bonus.get("INT", 0))
	stats.base_max_health = 80 + con_stat * 4 + total_level * 5
	stats.base_max_energy = 6 + int(int_stat / 2.0)
	stats.base_attack = 8 + str_stat
	stats.base_defense = 5 + int(con_stat / 2.0)
	stats.base_speed = 40 + dex_stat
	stats.base_hit_chance = 90
	stats.base_evasion = int(dex_stat / 2.0)
	return stats


static func apply_passive_effects(unlocked_skills: Array[Resource], stats: BattlerStats) -> void:
	for skill in unlocked_skills:
		if skill is PassiveEffect:
			skill.apply_to(stats)


static func build_actions(unlocked_skills: Array[Resource]) -> Array[BattlerAction]:
	var result: Array[BattlerAction] = []
	result.append((load(BASIC_ATTACK_PATH) as BattlerAction).duplicate())

	var has_quick_cast: = false
	var has_spell_evolution: = false
	for skill in unlocked_skills:
		if skill is PassiveEffect:
			if skill.special_id == "quick_cast":
				has_quick_cast = true
			elif skill.special_id == "spell_evolution":
				has_spell_evolution = true

	for skill in unlocked_skills:
		if skill is BattlerAction:
			var action: BattlerAction = skill.duplicate()
			if action is RangedBattlerAction and has_quick_cast:
				action.energy_cost = maxi(1, action.energy_cost - 1)
			if action.name == "Fire Bolt" and has_spell_evolution:
				action.base_damage += 15
			result.append(action)
		elif skill is ReactiveSkillGrant and skill.requires_activation:
			var arm_action: = ArmReactiveSkillAction.new()
			arm_action.name = skill.skill.display_name
			arm_action.description = skill.skill.description
			arm_action.target_scope = BattlerAction.TargetScope.SELF
			arm_action.energy_cost = 1
			arm_action.controller_name = skill.controller_name
			result.append(arm_action)
	return result


static func finalize_actions(actions: Array[BattlerAction], pc_battler: Battler, roster: BattlerRoster) -> void:
	for action in actions:
		action.source = pc_battler
		action.battler_roster = roster


static func attach_reactive_controllers(unlocked_skills: Array[Resource], pc_battler: Battler) -> void:
	for skill in unlocked_skills:
		if skill is ReactiveSkillGrant:
			var controller: = ReactiveSkillController.new()
			controller.name = skill.controller_name if skill.controller_name != "" else "ReactiveController_%s" % skill.skill.display_name
			controller.trigger = skill.trigger
			controller.skill = skill.skill
			controller.requires_activation = skill.requires_activation
			pc_battler.add_child(controller)
```

- [ ] **Step 2: Run headless import**

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import`
Expected: no `SCRIPT ERROR` lines.

- [ ] **Step 3: Write and run a logic test for the stat-building and action-building paths (no live Battler needed)**

Create `tests/test_pc_battler_builder.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var drake: = load("res://combat/races/drake.tres") as WIRaceData
	var stats: = PCBattlerBuilder.build_stats(drake, 1)
	assert(stats.base_attack == 8 + 10 + 1, "drake STR bonus should raise base_attack")
	assert(stats.base_speed == 40 + 10 + 2, "drake DEX bonus should raise base_speed")

	var fighter_data: WIClassData = load("res://combat/classes/fighter.tres")
	var unlocked: = fighter_data.get_skills_up_to_level(3) # basic_swordwork, tough_body, counter_strike, power_strike
	PCBattlerBuilder.apply_passive_effects(unlocked, stats)
	# drake CON bonus is +1 (con_stat = 11), so base_max_health = 80 + 11*4 + 1*5 = 129
	assert(stats.max_health == (80 + 11 * 4 + 1 * 5) + 10, "tough_body should add +10 max_health")

	var actions: = PCBattlerBuilder.build_actions(unlocked)
	# Expect: basic_attack, ArmReactiveSkillAction (Counter Strike), PowerStrikeBattlerAction
	assert(actions.size() == 3, "expected 3 actions, got %s" % actions.size())
	var has_arm_action: = false
	var has_power_strike: = false
	for action in actions:
		if action is ArmReactiveSkillAction:
			has_arm_action = true
		if action is PowerStrikeBattlerAction:
			has_power_strike = true
	assert(has_arm_action, "expected an ArmReactiveSkillAction for Counter Strike")
	assert(has_power_strike, "expected a PowerStrikeBattlerAction for Power Strike")

	print("PASS: PCBattlerBuilder produces correct stats and actions")
	quit()
```

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --script res://tests/test_pc_battler_builder.gd`
Expected: `PASS: PCBattlerBuilder produces correct stats and actions`, exit code 0.

- [ ] **Step 4: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/src/rpg/pc_battler_builder.gd wandering_inn_game_v2/tests
git commit -m "$(cat <<'EOF'
Add PCBattlerBuilder for dynamic player-character construction

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Character creation UI

**Files:**
- Create: `wandering_inn_game_v2/src/rpg/ui/character_creation.gd`
- Create: `wandering_inn_game_v2/src/rpg/ui/character_creation.tscn`
- Modify: `wandering_inn_game_v2/project.godot` (`run/main_scene`)

**Interfaces:**
- Consumes: `WIPlayerState.create_character(p_name, p_race, starting_class_id)` (Task 6)
- Consumes: `combat/races/*.tres` (Task 5)
- Produces: the new game entry point; on completion, transitions to `res://src/main.tscn`

- [ ] **Step 1: Write the character creation script**

Built with plain `Control` nodes created in code (matching `wandering_inn_game_v1`'s proven `CharCreate.gd` approach), since open-rpg has no comparable full-screen menu scene to follow instead.

Create `src/rpg/ui/character_creation.gd`:

```gdscript
extends Control

const RACE_PATHS: = [
	"res://combat/races/human.tres",
	"res://combat/races/drake.tres",
	"res://combat/races/gnoll.tres",
	"res://combat/races/antinium.tres",
	"res://combat/races/half_elf.tres",
]
const CLASS_IDS: = ["fighter", "mage"]
const MAIN_SCENE_PATH: = "res://src/main.tscn"

var _races: Array[WIRaceData] = []
var _selected_race_index: int = 0
var _selected_class_id: String = "fighter"
var _name_input: LineEdit


func _ready() -> void:
	for path in RACE_PATHS:
		_races.append(load(path) as WIRaceData)
	_build_ui()


func _build_ui() -> void:
	var bg: = ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.03)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var layout: = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(layout)

	var title: = Label.new()
	title.text = "Create Your Character"
	layout.add_child(title)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Character name"
	_name_input.text = "Traveler"
	layout.add_child(_name_input)

	var race_option: = OptionButton.new()
	for race in _races:
		race_option.add_item("%s — %s" % [race.display_name, race.trait_name])
	race_option.item_selected.connect(func(index: int) -> void: _selected_race_index = index)
	layout.add_child(race_option)

	var class_option: = OptionButton.new()
	for class_id in CLASS_IDS:
		var class_data: WIClassData = WIClassCatalog.get_class_data(class_id)
		class_option.add_item(class_data.display_name)
	class_option.item_selected.connect(func(index: int) -> void: _selected_class_id = CLASS_IDS[index])
	layout.add_child(class_option)

	var confirm_button: = Button.new()
	confirm_button.text = "Begin"
	confirm_button.pressed.connect(_on_confirm_pressed)
	layout.add_child(confirm_button)


func _on_confirm_pressed() -> void:
	var chosen_name: = _name_input.text if _name_input.text != "" else "Traveler"
	var chosen_race: = _races[_selected_race_index]
	WIPlayerState.create_character(chosen_name, chosen_race, _selected_class_id)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
```

- [ ] **Step 2: Create the scene file**

Create `src/rpg/ui/character_creation.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/rpg/ui/character_creation.gd" id="1"]

[node name="CharacterCreation" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 3: Set as the game's entry point**

In `project.godot`, change:
```ini
run/main_scene="res://src/main.tscn"
```
to:
```ini
run/main_scene="res://src/rpg/ui/character_creation.tscn"
```

- [ ] **Step 4: Run headless import and parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: no parse/scene-load errors.

- [ ] **Step 5: Manual verification**

Run: `/usr/local/bin/godot --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2`
Expected: a window opens showing "Create Your Character" with a name field, a race dropdown (5 entries, each showing race name + trait name), a class dropdown (Fighter/Mage), and a "Begin" button. Selecting a race/class, entering a name, and clicking "Begin" should transition to the field map (open-rpg's town scene, unmodified until Task 13) without errors in the console.

- [ ] **Step 6: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/src/rpg/ui wandering_inn_game_v2/project.godot
git commit -m "$(cat <<'EOF'
Add character creation screen as the game's new entry point

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Relc Grasstongue companion Battler

**Files:**
- Create: `wandering_inn_game_v2/combat/battlers/relc/relc_stats.tres`
- Create: `wandering_inn_game_v2/combat/battlers/relc/relc_attack.tres`
- Create: `wandering_inn_game_v2/combat/battlers/relc/relc_power_strike.tres`

Relc is a fixed, hand-authored static `Battler` (matching open-rpg's own pattern for every non-PC character), not built via `PCBattlerBuilder`. He reuses `PowerStrikeBattlerAction` from Task 4 (thematically fitting for a City Watch guardsman) and an existing placeholder sprite/animation from the cloned demo assets (per the design spec's non-goal: no new custom art for this MVP).

**Interfaces:**
- Consumes: `PowerStrikeBattlerAction` (Task 4), existing `AttackBattlerAction`, `BattlerStats` (unmodified engine classes)
- Consumes existing placeholder art: `combat/battlers/bugcat/bugcat_anim.tscn`
- Produces: `.tres` resources referenced directly by node path in Task 11's combat arena scene

- [ ] **Step 1: Create Relc's stats resource**

```bash
mkdir -p /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2/combat/battlers/relc
```

Create `combat/battlers/relc/relc_stats.tres`:

```
[gd_resource type="Resource" script_class="BattlerStats" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/combat/battlers/battler_stats.gd" id="1"]

[resource]
script = ExtResource("1")
affinity = 0
base_max_health = 140
base_max_energy = 4
base_attack = 16
base_defense = 12
base_speed = 55
base_hit_chance = 100
base_evasion = 5
```

- [ ] **Step 2: Create Relc's basic attack action**

Create `combat/battlers/relc/relc_attack.tres`:

```
[gd_resource type="Resource" script_class="AttackBattlerAction" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/combat/actions/battler_action_attack.gd" id="1"]

[resource]
script = ExtResource("1")
name = "Spear Thrust"
description = "A quick spear jab."
target_scope = 1
targets_friendlies = false
targets_enemies = true
energy_cost = 0
hit_chance = 100.0
base_damage = 18
```

(`target_scope = 1` is `BattlerAction.TargetScope.SINGLE`; see the enum in `src/combat/actions/battler_action.gd`.)

- [ ] **Step 3: Create Relc's Power Strike instance**

Create `combat/battlers/relc/relc_power_strike.tres`:

```
[gd_resource type="Resource" script_class="PowerStrikeBattlerAction" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/rpg/actions/battler_action_power_strike.gd" id="1"]

[resource]
script = ExtResource("1")
name = "Guardsman's Strike"
description = "Relc puts his full weight behind a spear thrust."
target_scope = 1
targets_friendlies = false
targets_enemies = true
energy_cost = 2
hit_chance = 100.0
base_damage = 18
damage_mult = 1.5
```

- [ ] **Step 4: Run headless import**

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import`
Expected: no errors, and re-opening the project in the editor should show these 3 files as valid resources (spot check: `base_attack`/`damage_mult` fields visible in the inspector if opened manually). No standalone test needed — these are plain data resources exercised directly in Task 11's manual playtest.

- [ ] **Step 5: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/combat/battlers/relc
git commit -m "$(cat <<'EOF'
Add Relc Grasstongue companion Battler stats/actions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Shield Spider enemy Battler

**Files:**
- Create: `wandering_inn_game_v2/combat/battlers/shield_spider/shield_spider_stats.tres`
- Create: `wandering_inn_game_v2/combat/battlers/shield_spider/shield_spider_attack.tres`

Stats derived from `wandering_inn_game_v1/data/enemies.json`'s `shield_spider` entry (hp 22, damage 4–8, defense 3 — a Liscor Floodplains monster per lore). Its v1 skills (`web_shot`, `armored_carapace`) are grid/status-effect mechanics out of MVP scope (per the design spec's skill-porting rules) — it fights with a basic attack only.

**Interfaces:**
- Consumes: existing `AttackBattlerAction`, `BattlerStats` (unmodified engine classes)
- Consumes existing placeholder art + AI: `combat/battlers/wolf/wolf_anim.tscn`, `src/combat/CombatAI.tscn`
- Produces: `.tres` resources referenced directly by node path in Task 11's combat arena scene

- [ ] **Step 1: Create Shield Spider's stats resource**

```bash
mkdir -p /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2/combat/battlers/shield_spider
```

Create `combat/battlers/shield_spider/shield_spider_stats.tres`:

```
[gd_resource type="Resource" script_class="BattlerStats" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/combat/battlers/battler_stats.gd" id="1"]

[resource]
script = ExtResource("1")
affinity = 0
base_max_health = 22
base_max_energy = 0
base_attack = 6
base_defense = 3
base_speed = 50
base_hit_chance = 90
base_evasion = 10
```

- [ ] **Step 2: Create Shield Spider's attack action**

Create `combat/battlers/shield_spider/shield_spider_attack.tres`:

```
[gd_resource type="Resource" script_class="AttackBattlerAction" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/combat/actions/battler_action_attack.gd" id="1"]

[resource]
script = ExtResource("1")
name = "Bite"
description = "The Shield Spider lunges with venomous mandibles."
target_scope = 1
targets_friendlies = false
targets_enemies = true
energy_cost = 0
hit_chance = 90.0
base_damage = 6
```

- [ ] **Step 3: Run headless import**

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/combat/battlers/shield_spider
git commit -m "$(cat <<'EOF'
Add Shield Spider enemy Battler stats/action

Ported from wandering_inn_game_v1's enemies.json (Liscor Floodplains
monster). Its grid/status skills (web_shot, armored_carapace) are out
of MVP scope; it fights with a basic attack only.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Liscor combat arena

Assembles the PC (dynamic), Relc (static), and Shield Spider (static) into a `CombatArena` scene, following `overworld/maps/town/battles/test_combat_arena.tscn`'s exact existing structure. The PC's `Battler` node starts with placeholder stats/actions (required for the scene to be valid — `Battler._ready()` asserts `stats` is non-null) which a small script overwrites at runtime via `PCBattlerBuilder`.

**Files:**
- Create: `wandering_inn_game_v2/overworld/maps/town/battles/liscor_combat_arena.tscn`
- Create: `wandering_inn_game_v2/overworld/maps/town/battles/liscor_combat_arena.gd`

**Interfaces:**
- Consumes: `PCBattlerBuilder` (Task 7), `WIPlayerState` (Task 6), Relc's resources (Task 9), Shield Spider's resources (Task 10)
- Consumes: existing `CombatArena`, `Battler`, `BattlerRoster`, `CombatAI.tscn` (unmodified engine classes)
- Produces: a `PackedScene` referenced by a `CombatTrigger.combat_arena` export in Task 13

- [ ] **Step 1: Create the arena scene**

Modeled directly on `overworld/maps/town/battles/test_combat_arena.tscn`'s node structure (`CombatArena` → `Battlers` (BattlerRoster) → child `Battler` nodes with `position`, `stats`, `actions`, `battler_anim_scene`, `ai_scene`, `is_player`).

Create `overworld/maps/town/battles/liscor_combat_arena.tscn`:

```
[gd_scene load_steps=13 format=3]

[ext_resource type="PackedScene" path="res://src/combat/combat_arena.tscn" id="1"]
[ext_resource type="Texture2D" path="res://combat/arenas/steppes.png" id="2"]
[ext_resource type="AudioStream" path="res://assets/music/squashin_bugs_fixed.mp3" id="3"]
[ext_resource type="Script" path="res://src/combat/battlers/battler.gd" id="4"]
[ext_resource type="Script" path="res://overworld/maps/town/battles/liscor_combat_arena.gd" id="5"]
[ext_resource type="Resource" path="res://combat/battlers/bear/bear_stats.tres" id="6"]
[ext_resource type="Resource" path="res://combat/skills/shared/basic_attack.tres" id="7"]
[ext_resource type="PackedScene" path="res://combat/battlers/bear/bear_anim.tscn" id="8"]
[ext_resource type="Resource" path="res://combat/battlers/relc/relc_stats.tres" id="9"]
[ext_resource type="Resource" path="res://combat/battlers/relc/relc_attack.tres" id="10"]
[ext_resource type="Resource" path="res://combat/battlers/relc/relc_power_strike.tres" id="11"]
[ext_resource type="PackedScene" path="res://combat/battlers/bugcat/bugcat_anim.tscn" id="12"]
[ext_resource type="Resource" path="res://combat/battlers/shield_spider/shield_spider_stats.tres" id="13"]
[ext_resource type="Resource" path="res://combat/battlers/shield_spider/shield_spider_attack.tres" id="14"]
[ext_resource type="PackedScene" path="res://combat/battlers/wolf/wolf_anim.tscn" id="15"]
[ext_resource type="PackedScene" path="res://src/combat/CombatAI.tscn" id="16"]

[node name="LiscorCombatArena" instance=ExtResource("1")]
script = ExtResource("5")
music = ExtResource("3")

[node name="Background" parent="." index="0"]
texture = ExtResource("2")

[node name="PC" type="Node2D" parent="Battlers"]
position = Vector2(1370, 738)
script = ExtResource("4")
stats = ExtResource("6")
actions = [ExtResource("7")]
battler_anim_scene = ExtResource("8")
is_player = true

[node name="Relc" type="Node2D" parent="Battlers"]
position = Vector2(1243, 906)
script = ExtResource("4")
stats = ExtResource("9")
actions = [ExtResource("10"), ExtResource("11")]
battler_anim_scene = ExtResource("12")
is_player = true

[node name="ShieldSpider" type="Node2D" parent="Battlers"]
position = Vector2(465, 722)
script = ExtResource("4")
stats = ExtResource("13")
actions = [ExtResource("14")]
battler_anim_scene = ExtResource("15")
ai_scene = ExtResource("16")
```

Note: `PC`'s `stats`/`actions` above (`bear_stats.tres`/`basic_attack.tres`) are **placeholders only**, required so the scene is valid and `Battler._ready()`'s `assert(stats, ...)` doesn't fire — `liscor_combat_arena.gd` overwrites both at runtime in the next step.

- [ ] **Step 2: Write the arena script that builds the real PC Battler**

Create `overworld/maps/town/battles/liscor_combat_arena.gd`:

```gdscript
extends CombatArena


func _ready() -> void:
	var pc: Battler = $Battlers/PC
	var roster: = get_battler_roster()
	var unlocked_skills: = WIPlayerState.get_unlocked_skills()

	var stats: = PCBattlerBuilder.build_stats(WIPlayerState.race, WIPlayerState.get_total_level())
	PCBattlerBuilder.apply_passive_effects(unlocked_skills, stats)
	stats.initialize()
	pc.stats = stats

	var actions: = PCBattlerBuilder.build_actions(unlocked_skills)
	PCBattlerBuilder.finalize_actions(actions, pc, roster)
	pc.actions = actions

	PCBattlerBuilder.attach_reactive_controllers(unlocked_skills, pc)
```

- [ ] **Step 3: Run headless import and parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: no parse/scene-load errors. This hand-written file omits the optional `uid="..."` attribute that Godot's editor normally adds to `ext_resource`/`gd_scene` lines — that's fine, plain `path="..."` references without a `uid` are a fully supported, simpler format (the risk to avoid is inventing a fake `uid://...` value, not omitting it).

- [ ] **Step 4: Manual verification**

Run `godot --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 res://overworld/maps/town/battles/liscor_combat_arena.tscn` directly (bypassing character creation, so `WIPlayerState.race`/`classes` will be unset — expect the PC to build with a `null` race and crash on `race.stat_bonus.get(...)`). This confirms the scene *loads*; full behavioral verification (with a real character) happens in Task 14's end-to-end playtest once the field trigger wires everything together.

- [ ] **Step 5: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/overworld/maps/town/battles/liscor_combat_arena.tscn wandering_inn_game_v2/overworld/maps/town/battles/liscor_combat_arena.gd
git commit -m "$(cat <<'EOF'
Add Liscor combat arena (PC + Relc vs Shield Spider)

PC's Battler starts with placeholder stats/actions in the scene file
(required for Battler._ready()'s non-null assertion) and is rebuilt
from WIPlayerState via PCBattlerBuilder at runtime.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Reskin House → The Wandering Inn interior

Removes the existing demo's wand-pedestal puzzle content from the `House` region of `src/main.tscn` and adds Erin Solstice as an NPC with a conversation, following the exact pattern the `Smith` NPC in `Town` already uses — the closer structural analog to Erin (stationary, single-speaker) than the `Runner` NPC (which is mover-specific and needs an extra `InteractionPopup`/`moving_interaction_popup.gd` layer Erin doesn't need). Confirmed against `addons/dialogic/Modules/Text/event_text.gd`'s actual line parser and every existing `.dtl`/`.dch` pair in this project — Dialogic timelines use per-line `name (Portrait): text` prefixes keyed against a registered `.dch` character resource, not a `[character=...]` block header (that syntax doesn't exist anywhere in this codebase or the bundled addon).

**Files:**
- Modify: `wandering_inn_game_v2/src/main.tscn` (within the `Field/Map/House` subtree)
- Create: `wandering_inn_game_v2/overworld/maps/house/erin_intro.dtl`
- Create: `wandering_inn_game_v2/overworld/maps/house/erin.dch`
- Modify: `wandering_inn_game_v2/project.godot` (`[dialogic]` `directories/dtl_directory` and `directories/dch_directory`)

**Interfaces:**
- Consumes: existing `res://src/field/gamepieces/gamepiece.tscn`, `res://src/field/cutscenes/Interaction.tscn`, `res://src/field/cutscenes/templates/conversations/conversation_template.gd` (`InteractionTemplateConversation`)
- Consumes: existing field-graphics scene `res://overworld/characters/smith_gfx.tscn` for Erin's field sprite, and existing portrait image `res://overworld/characters/smith.atlastex` for her dialogue portrait (both placeholders — no new art per the design spec's non-goals; reusing the same underlying character asset for both keeps her look consistent across field and dialogue)

- [ ] **Step 1: Write Erin's dialogue character resource**

Modeled exactly on the existing `overworld/maps/town/smith.dch` (verified working pattern — every NPC using `name (Portrait): text`-style dialogue has one of these, registered in `project.godot`'s `dch_directory`).

Create `overworld/maps/house/erin.dch`:

```
{
"@path": "res://addons/dialogic/Resources/character.gd",
"@subpath": NodePath(""),
&"_translation_id": "",
&"color": Color(1, 1, 1, 1),
&"custom_info": {
"sound_mood_default": "",
"sound_moods": {},
"style": ""
},
&"default_portrait": "Default",
&"description": "",
&"display_name": "Erin Solstice",
&"mirror": false,
&"nicknames": [""],
&"offset": Vector2(0, 0),
&"portraits": {
"Default": {
"export_overrides": {
"image": "\"res://overworld/characters/smith.atlastex\""
},
"image": "",
"mirror": false,
"offset": Vector2(0, 0),
"scale": 1,
"scene": "res://addons/dialogic/Modules/Character/default_portrait.tscn"
}
},
&"scale": 1.0
}
```

- [ ] **Step 2: Write Erin's introduction dialogue**

Ported from `wandering_inn_game_v1/data/dialogue/erin.json`'s `erin_first_meeting` node (verbatim lines, no branching choices — the MVP does not build a dialogue-choice/quest system). Each line is prefixed `erin (Default):` — the per-line format `smith.dtl`/`monk.dtl`/`warrior.dtl` all actually use, where `erin` is the key that must match the `dch_directory` registration in Step 4.

Create `overworld/maps/house/erin_intro.dtl`:

```
erin (Default): Oh! Hey! Welcome, welcome — you look like you just walked a million miles. Come in, sit down, I'll get you something to eat. I'm Erin, this is The Wandering Inn!
erin (Default): Fair warning: the stew is amazing, the bread is fresh, and occasionally a goblin tries to walk in through the front door. I handle it. Mostly.
erin (Default): So — adventurer? You've got that look. You know, the 'I have no idea what I'm doing but I'm going to do it anyway' look. I recognize it. I had it too.
erin (Default): The dungeon under Liscor has been really active lately. Lots of adventurers passing through. If you're heading that way, just... be careful, okay? Gold-rank dangerous down there.
[end_timeline]
```

- [ ] **Step 3: Remove the wand-pedestal puzzle from House, add Erin**

Open `src/main.tscn` and locate the `Field/Map/House` subtree (node names `TreasureChest`, `PedestalPuzzle` and its children `GreenPedestal`/`BluePedestal`/`RedPedestal`/`Pedestal`, all parented under `Field/Map/House/Gamepieces`).

Delete these node blocks:
- `[node name="TreasureChest" parent="Field/Map/House/Gamepieces" ...]`
- `[node name="PedestalPuzzle" ...]` and all of its child node blocks (`GreenPedestal`, `BluePedestal`, `RedPedestal`, `Pedestal`, and `Pedestal`'s own children `Sprite2D`/`AnimationPlayer`/`SpikesClick`)

Add a new NPC node in the same place, following the `Smith` NPC's exact structure from `Field/Map/Town/Gamepieces` (verified directly against `src/main.tscn:422-431`): a stationary single-speaker NPC has `Interaction` as a direct child of the gamepiece, and `InteractionPopup` as a child of `Interaction` (not the other way around — that inverted nesting, `NPC → InteractionPopup → Interaction`, is specific to the mover-only `Runner`/`moving_interaction_popup.gd` pattern, which doesn't apply here):

```
[node name="Erin" parent="Field/Map/House/Gamepieces" instance=ExtResource("11_yntrj")]
position = Vector2(200, 150)
animation_scene = ExtResource("18_2msel")
metadata/_edit_group_ = true

[node name="Interaction" parent="Field/Map/House/Gamepieces/Erin" instance=ExtResource("19_sa6jd")]
script = ExtResource("14_b3y71")
timeline = ExtResource("100_erin")

[node name="InteractionPopup" parent="Field/Map/House/Gamepieces/Erin/Interaction" instance=ExtResource("34_qs25x")]
```

Add the corresponding `ext_resource` line near the top of the file (matching the existing numbering style, using a fresh id not already in use — check the file's existing highest `id="N_..."` first and increment). `ExtResource("34_qs25x")` (`res://src/field/cutscenes/popups/interaction_popup.tscn`) is already declared in this file (confirmed at line 47) — do not add a duplicate `ext_resource` line for it:

```
[ext_resource type="Resource" path="res://overworld/maps/house/erin_intro.dtl" id="100_erin"]
```

`ExtResource("18_2msel")` is `smith_gfx.tscn`, already imported elsewhere in this file (confirmed present in the codebase research for this plan) — reused here as Erin's placeholder field sprite. `ExtResource("14_b3y71")` is `conversation_template.gd` (`InteractionTemplateConversation`), also already present.

- [ ] **Step 4: Register the new dialogue and character files in Dialogic's config**

In `project.godot`, add to `[dialogic]`'s `directories/dtl_directory` dictionary:
```ini
"erin_intro": "res://overworld/maps/house/erin_intro.dtl",
```

And add to `[dialogic]`'s `directories/dch_directory` dictionary:
```ini
"erin": "res://overworld/maps/house/erin.dch",
```

- [ ] **Step 5: Run headless import and parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: no parse errors, no dangling `ExtResource` references (a leftover reference to a deleted pedestal's script would show as a missing-dependency warning — if seen, also remove the now-unused `ext_resource` lines for `wand_pedestal_interaction.gd`/`treasure_chest` at the top of the file).

- [ ] **Step 6: Manual verification**

Run `/usr/local/bin/godot --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2`, create a character, and confirm: you start in (or can walk into) the House area, the pedestal puzzle is gone, and walking up to Erin and interacting shows her 4-line introduction dialogue with her name/portrait attributed correctly.

- [ ] **Step 7: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/src/main.tscn wandering_inn_game_v2/overworld/maps/house/erin_intro.dtl wandering_inn_game_v2/overworld/maps/house/erin.dch wandering_inn_game_v2/project.godot
git commit -m "$(cat <<'EOF'
Reskin House area into The Wandering Inn interior with Erin

Removes the demo's wand-pedestal puzzle content and adds Erin Solstice
as an NPC with an introduction conversation, ported from
wandering_inn_game_v1's erin.json. Follows the Smith NPC's dialogue
pattern (name (Portrait): text per-line, backed by a .dch character
resource) rather than a guessed bracket-header syntax that doesn't
exist in this Dialogic install.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: Reskin Town → Liscor with Relc recruitment and the Shield Spider encounter

Adds Relc as a recruitable NPC and a `CombatTrigger` for the Shield Spider fight. Existing demo NPCs (MoodyHero, Runner, Thief, Monk, Smith, Wizard, AdoringFan, etc.) are left in place — removing them is a cosmetic cleanup deferred past this MVP (see Task 13's note below), not required for the playable loop. Dialogue follows the same verified `name (Portrait): text` + `.dch` pattern established in Task 12 (not a `[character=...]` block header, which doesn't exist in this Dialogic install).

**Files:**
- Modify: `wandering_inn_game_v2/src/main.tscn` (within the `Field/Map/Town` subtree)
- Create: `wandering_inn_game_v2/overworld/maps/town/relc_recruit.dtl`
- Create: `wandering_inn_game_v2/overworld/maps/town/relc.dch`
- Create: `wandering_inn_game_v2/overworld/maps/town/relc_recruit_interaction.gd`
- Modify: `wandering_inn_game_v2/project.godot` (`[dialogic]` `directories/dtl_directory` and `directories/dch_directory`)

**Interfaces:**
- Consumes: `WIPlayerState.has_relc` (Task 6), `res://overworld/maps/town/battles/liscor_combat_arena.tscn` (Task 11)
- Consumes: existing `res://src/field/cutscenes/templates/combat/combat_trigger.gd` (`CombatTrigger`), `res://src/field/cutscenes/templates/conversations/conversation_template.gd` (`InteractionTemplateConversation`)
- Consumes: existing field-graphics scene `res://overworld/characters/thief_gfx.tscn` for Relc's field sprite, and existing portrait image `res://overworld/characters/thief.atlastex` for his dialogue portrait (both placeholders, same pairing the existing `Thief` NPC already uses)

- [ ] **Step 1: Write Relc's dialogue character resource**

Modeled exactly on `overworld/maps/town/thief.dch` (verified working pattern).

Create `overworld/maps/town/relc.dch`:

```
{
"@path": "res://addons/dialogic/Resources/character.gd",
"@subpath": NodePath(""),
&"_translation_id": "",
&"color": Color(1, 1, 1, 1),
&"custom_info": {
"sound_mood_default": "",
"sound_moods": {},
"style": ""
},
&"default_portrait": "Default",
&"description": "",
&"display_name": "Relc Grasstongue",
&"mirror": false,
&"nicknames": [""],
&"offset": Vector2(0, 0),
&"portraits": {
"Default": {
"export_overrides": {
"image": "\"res://overworld/characters/thief.atlastex\""
},
"image": "",
"mirror": false,
"offset": Vector2(0, 0),
"scale": 1,
"scene": "res://addons/dialogic/Modules/Character/default_portrait.tscn"
}
},
&"scale": 1.0
}
```

- [ ] **Step 2: Write Relc's recruitment dialogue**

Ported from `wandering_inn_game_v1/data/dialogue/relc.json`'s `relc_first_meeting` node (verbatim lines), plus one new line written for this recruitment (v1 had no "join the party" flow to port, since v1 was solo-PC-only). Each line prefixed `relc (Default):`, matching the key registered in Step 5.

Create `overworld/maps/town/relc_recruit.dtl`:

```
relc (Default): WHOA. New face! New adventurer, yeah? I can tell — you've got the look. The pack, the slightly confused expression, the 'I have no idea where I am but I look confident about it' energy.
relc (Default): I'm Relc. Senior Guardsman, City Watch, Liscor. THE best fighter in the city — before you ask, yes, including against monsters. Especially against monsters, actually.
relc (Default): Klbkch over there is, uh, also pretty good, I guess. In a different way. More... methodical. Less awesome. Don't tell him I said that, he'll make a whole thing of it.
relc (Default): Actually — I've got a hunch there's something nasty crawled up from the floodplains past the east gate. Could use an extra pair of hands. What do you say?
[end_timeline]
```

- [ ] **Step 3: Write a subclass of `InteractionTemplateConversation` that sets `has_relc` after the dialogue finishes**

Rather than relying on Dialogic's in-timeline signal-event syntax (unverified in this codebase), the flag is set in GDScript immediately after the base class's dialogue playback completes.

Create `overworld/maps/town/relc_recruit_interaction.gd`. Note `@tool`: every existing subclass of `InteractionTemplateConversation`/`Interaction` in this codebase (`gang_of_four_conversation.gd`, `strange_tree_interaction.gd`, `door_unlock_interaction.gd`) carries `@tool` matching the base class's own `@tool` annotation — GDScript doesn't inherit the annotation automatically, and omitting it produces a `@tool`-mismatch warning when the scene loads:

```gdscript
@tool
extends InteractionTemplateConversation


func _execute() -> void:
	await super._execute()
	WIPlayerState.has_relc = true
```

- [ ] **Step 4: Add Relc NPC and the Shield Spider combat trigger to Town**

Locate `Field/Map/Town/Gamepieces` in `src/main.tscn`. Add Relc following the `Thief` NPC's exact structure (verified directly against `src/main.tscn:400-409`): `Interaction` is a direct child of the gamepiece, and `InteractionPopup` is a child of `Interaction` — but with the new interaction script from Step 3:

```
[node name="Relc" parent="Field/Map/Town/Gamepieces" instance=ExtResource("11_yntrj")]
position = Vector2(700, 400)
animation_scene = ExtResource("17_sieyv")
metadata/_edit_group_ = true

[node name="Interaction" parent="Field/Map/Town/Gamepieces/Relc" instance=ExtResource("19_sa6jd")]
script = ExtResource("101_relc_recruit")
timeline = ExtResource("102_relc_dtl")

[node name="InteractionPopup" parent="Field/Map/Town/Gamepieces/Relc/Interaction" instance=ExtResource("34_qs25x")]
```

`ExtResource("34_qs25x")` (`res://src/field/cutscenes/popups/interaction_popup.tscn`) is already declared in this file (confirmed at line 47) — do not add a duplicate `ext_resource` line for it.

Add a `CombatTrigger` further into the map (east of Relc's position, so the player naturally meets Relc first — this physical placement is the encounter's only gate, no code-level flag check needed).

`Trigger` (`src/field/cutscenes/trigger.gd`) requires an explicit signal connection from a child `Area2D`'s `area_entered` to its own `_on_area_entered` method — a bare `Area2D` with the script attached directly and no connection will never fire (`Trigger._get_configuration_warnings()` checks for exactly this and would flag it). `src/field/cutscenes/Trigger.tscn` is the existing base scene built for this: `Trigger` (`Node2D`) → child `Area2D` (`collision_layer=32`, `collision_mask=4`) → `CollisionShape2D`, with the `area_entered`/`area_exited` connections already wired. Every existing Trigger-family node in this file (e.g. `AreaTransition`, confirmed via `src/field/cutscenes/templates/area_transitions/area_transition.tscn`) is built by **instancing `Trigger.tscn` and overriding its `script`**, not by hand-declaring a raw `Area2D` — do the same here:

```
[node name="ShieldSpiderEncounter" parent="Field/Map/Town/Gamepieces" instance=ExtResource("105_trigger")]
position = Vector2(1400, 400)
script = ExtResource("103_combat_trigger")
combat_arena = ExtResource("104_liscor_arena")
```

Add the new `ext_resource` entries near the top of the file (using fresh ids per the file's existing numbering convention):

```
[ext_resource type="Script" path="res://overworld/maps/town/relc_recruit_interaction.gd" id="101_relc_recruit"]
[ext_resource type="Resource" path="res://overworld/maps/town/relc_recruit.dtl" id="102_relc_dtl"]
[ext_resource type="Script" path="res://src/field/cutscenes/templates/combat/combat_trigger.gd" id="103_combat_trigger"]
[ext_resource type="PackedScene" path="res://overworld/maps/town/battles/liscor_combat_arena.tscn" id="104_liscor_arena"]
[ext_resource type="PackedScene" path="res://src/field/cutscenes/Trigger.tscn" id="105_trigger"]
```

No `CollisionShape2D`/`sub_resource` needed — both are inherited from the instanced `Trigger.tscn` base (a 14×14px `RectangleShape2D` by default, which is fine for MVP; the collision layer/mask are also inherited and already correctly configured for detecting the player gamepiece).

- [ ] **Step 5: Register the new dialogue and character files in Dialogic's config**

In `project.godot`, add to `[dialogic]`'s `directories/dtl_directory` dictionary:
```ini
"relc_recruit": "res://overworld/maps/town/relc_recruit.dtl",
```

And add to `[dialogic]`'s `directories/dch_directory` dictionary:
```ini
"relc": "res://overworld/maps/town/relc.dch",
```

- [ ] **Step 6: Run headless import and parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: no parse errors.

- [ ] **Step 7: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/src/main.tscn wandering_inn_game_v2/overworld/maps/town/relc_recruit.dtl wandering_inn_game_v2/overworld/maps/town/relc.dch wandering_inn_game_v2/overworld/maps/town/relc_recruit_interaction.gd wandering_inn_game_v2/project.godot
git commit -m "$(cat <<'EOF'
Add Relc recruitment and Shield Spider encounter to Liscor

Relc's recruitment is dialogue-gated (talking to him sets
WIPlayerState.has_relc); the Shield Spider CombatTrigger is placed
further into the map so the player meets Relc first by layout, with
no additional code-level gate needed. Existing demo NPCs are left in
place for this MVP — removing them is a deferred cosmetic cleanup.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: Full-project verification pass

**Files:** None (verification only).

- [ ] **Step 1: Run every logic test in sequence**

```bash
cd /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2
/usr/local/bin/godot --headless --path . --script res://tests/test_engine_hooks.gd
/usr/local/bin/godot --headless --path . --script res://tests/test_wi_resources.gd
/usr/local/bin/godot --headless --path . --script res://tests/verify_content.gd
/usr/local/bin/godot --headless --path . --script res://tests/test_player_state.gd
/usr/local/bin/godot --headless --path . --script res://tests/test_pc_battler_builder.gd
```
Expected: every script prints its `PASS: ...` line, no assertion failures.

- [ ] **Step 2: Full headless project parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: exit code 0, no `SCRIPT ERROR`/`Parse Error` lines anywhere in the output.

- [ ] **Step 3: Manual end-to-end playtest**

Run `/usr/local/bin/godot --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2` and walk through the full MVP loop:

1. Character creation screen appears. Create a Drake Fighter named "Test Hero." Click Begin.
2. You arrive in the field, in or near the House area (The Wandering Inn interior).
3. Walk to Erin and interact: her 4-line introduction plays, then closes.
4. Walk (via the existing House↔Town `AreaTransition`) into the Town area (Liscor).
5. Walk to Relc and interact: his dialogue plays, ending with his recruitment line. `WIPlayerState.has_relc` is now `true` (not visible on-screen, but confirmable by continuing to step 6).
6. Walk east into the Shield Spider's `CombatTrigger` area. Combat begins.
7. In combat, confirm: your PC Battler shows HP/energy matching a level-1 Fighter (80 + 11*4 + 1*5 = 129 max HP, given Drake's CON+1 bonus making con_stat=11), and has only the basic "Attack" action available — Counter Strike unlocks at level 2 and Power Strike at level 3, and this MVP's PC never levels past 1 (`WIPlayerState.create_character` sets level 1 and nothing increments it), so neither is expected here. The reactive-skill (Counter Strike) and Power Strike code paths are exercised only by `tests/test_pc_battler_builder.gd`'s level-3 unit-test path and by Relc's static "Guardsman's Strike" action, not by this playtest's level-1 PC. Relc is present as a second ally Battler with "Spear Thrust" and "Guardsman's Strike" actions. The Shield Spider acts on its own via AI.
8. Fight to a win or loss. Confirm `CombatEvents.combat_finished` resolves correctly (the screen transitions back to the field either way, per `CombatTrigger`'s existing victory/loss cutscene hooks).
9. Confirm no errors appear in the Godot console/output at any point during this sequence.

- [ ] **Step 4: Record the outcome**

If all steps pass, the MVP is complete. If any step fails, use `superpowers:systematic-debugging` to diagnose before considering this plan done — do not mark this task complete with known-broken behavior.
