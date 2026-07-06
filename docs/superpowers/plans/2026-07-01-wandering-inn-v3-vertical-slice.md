# Wandering Inn v3 "Defend the Inn" Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the v2 MVP loop into a complete "Defend the Inn" vertical slice: Erin frames a goblin threat, the player fights the reused Shield Spider, fortifies the inn, sleeps to level up Fighter to 2 (unlocking Counter Strike), then fights a new Goblin Raider + Goblin Shaman pair alongside Relc.

**Architecture:** Extends `WIPlayerState` with a single `accomplishments` flag dictionary and an explicit (not generic) Fighter-1-to-2 leveling rule. New content (Bed, 3 fortify props, 2 goblin enemies, a new combat arena) all follows exactly the same patterns already proven in `wandering_inn_game_v2` — no new engine mechanisms. Leveling happens at a "sleep" beat *before* the climax fight, so `PCBattlerBuilder` and the combat engine need zero changes.

**Tech Stack:** Godot 4.6.2 (GDScript), Dialogic plugin (already in use), no new test framework.

**Design spec:** `/Users/gabriel/wandering_inn_rpg/docs/superpowers/specs/2026-07-01-wandering-inn-v3-vertical-slice-design.md` — read this first for the why behind every decision below.

## Global Constraints

- Engine: Godot **4.6.2** exactly, installed at `/usr/local/bin/godot`.
- Project path: `/Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2`. Every new `.gd` file needs a headless import pass before `class_name` registration works: `/usr/local/bin/godot --headless --path wandering_inn_game_v2 --import`.
- **Stats are internal only.** No task in this plan displays raw STR/DEX/etc. or derived combat numbers — the level-up toast shows only class/level/skill names.
- **No generic leveling-curve system.** `check_for_level_up()` is written explicitly for the one Fighter 1→2 transition this slice needs — do not build a scalable multi-level framework.
- **No new test framework.** Extend the existing `tests/test_wi_scene_contracts.gd` pattern (raw-text `.contains()` assertions against `.tscn`/`.dtl` file contents, run via `godot --headless --path <project> --script res://tests/<name>.gd`) — this is the established convention as of the post-v2 debugging pass, distinct from the resource-instantiation style used in `tests/test_wi_resources.gd`/`test_pc_battler_builder.gd`. Use scene-contract (string-matching) tests for `.tscn`/`.dtl` content, and direct instantiation tests for pure `WIPlayerState` logic.
- **Before starting implementation, re-verify the v2 MVP loop works end-to-end in a live playtest** (see Task 0) — HANDOFF.md's debugging notes claim prior bugs are fixed, but this has not been visually re-confirmed by the user since those fixes landed.
- Existing `ext_resource` ids in `src/main.tscn` currently top out at `106_spider_marker` — this plan uses fresh ids in the `200_...` range to guarantee no collisions.
- Dialogic dialogue-choice syntax (verified against `erin_intro.dtl`/`relc_recruit.dtl`): linear lines as `speaker (Portrait): text`, then `label <name>_questions`, then repeated `- <choice text>` blocks with tab-indented response lines, `\tjump <name>_questions` to loop back (omit on the final/exit choice), ending with `[end_timeline]`.
- Static "prop" interactables (Bed, fortify props) follow the exact node structure already proven for Erin in `src/main.tscn`: `<Name>` (`instance=ExtResource("11_yntrj")`, the generic `gamepiece.tscn`) → `Interaction` (child, `instance=ExtResource("19_sa6jd")`, custom `script` + optional `timeline`) → `InteractionPopup` (child of `Interaction`, `instance=ExtResource("34_qs25x")`).

## File Structure

```
wandering_inn_game_v2/
  src/rpg/state/wi_player_state.gd       (MODIFY: add accomplishments, seen_hints, record_accomplishment, check_for_level_up)
  src/rpg/ui/level_up_toast.tscn         (NEW)
  src/rpg/ui/level_up_toast.gd           (NEW)
  overworld/maps/house/
    erin_intro.dtl                       (MODIFY: add threat-framing branch + combat hint)
    bed_interaction.gd                   (NEW)
    fortify_interaction.gd               (NEW: one parameterized script, reused for all 3 props)
  overworld/maps/town/
    goblin_raid_climax.dtl               (NEW: Erin's closing dialogue after victory)
    battles/
      defend_inn_combat_arena.tscn       (NEW)
      defend_inn_combat_arena.gd         (NEW)
  combat/battlers/
    goblin_raider/goblin_raider_stats.tres   (NEW)
    goblin_raider/goblin_raider_attack.tres  (NEW)
    goblin_shaman/goblin_shaman_stats.tres   (NEW)
    goblin_shaman/goblin_shaman_spell.tres   (NEW)
  src/main.tscn                          (MODIFY: Bed + 3 fortify props in House; Choices UI fix; new climax CombatTrigger in Town)
  tests/test_wi_scene_contracts.gd       (MODIFY: add v3 contract assertions)
  tests/test_wi_player_state_accomplishments.gd (NEW: logic tests)
```

---

### Task 0: Re-verify the v2 MVP loop end-to-end

**Files:** None (verification only).

- [ ] **Step 1: Headless parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: exit 0, no `SCRIPT ERROR`/`Parse Error`.

- [ ] **Step 2: Run the existing scene-contract test**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --script res://tests/test_wi_scene_contracts.gd
```
Expected: `PASS: Wandering Inn scene contracts are wired correctly`.

- [ ] **Step 3: Manual playtest — full MVP loop**

Run `/usr/local/bin/godot --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2` and walk through: create a character → land in the House near Erin (not on her tile) → talk to Erin (choice tree works, loops back via "Where am I?"/"Any advice?", exits via "I'm heading out.") → walk to Town via `HouseToTown` → confirm old demo NPCs are gone → talk to Relc (choice tree works, recruits via "I'll help with the monster.") → walk into the Shield Spider trigger (marked with a visible sprite) → fight it (combat asset shows a spider proxy, not bugcat placeholder confusion) → win → confirm the trigger removes itself → walk back to the `TownToInn` door → confirm you're back inside the inn with music restored.

**If any step fails, stop and fix it before proceeding to Task 1** — this plan's new content builds directly on top of this loop (the climax trigger sits in the same Town scene, Erin's dialogue hub gets a new branch, etc.), so a broken foundation will compound.

- [ ] **Step 4: Report outcome**

No commit for this task (verification only). If fixes were needed, that's a separate, smaller task cycle before continuing — do not fold undocumented fixes into Task 1.

---

### Task 1: `WIPlayerState` accomplishments and leveling

**Files:**
- Modify: `wandering_inn_game_v2/src/rpg/state/wi_player_state.gd`
- Test: `wandering_inn_game_v2/tests/test_wi_player_state_accomplishments.gd`

**Interfaces:**
- Consumes: existing `WIPlayerState.classes: Dictionary` (unchanged)
- Produces: `WIPlayerState.accomplishments: Dictionary`, `WIPlayerState.seen_hints: Dictionary`, `record_accomplishment(id: String) -> void`, `check_for_level_up() -> bool`

**Skills:** `godot-prompter:resource-pattern`, `godot-prompter:ability-system`

- [ ] **Step 1: Write the failing test**

Create `tests/test_wi_player_state_accomplishments.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var human: = load("res://combat/races/human.tres") as WIRaceData
	WIPlayerState.create_character("Test Hero", human, "fighter")

	assert(WIPlayerState.accomplishments.is_empty(), "accomplishments should start empty")
	assert(WIPlayerState.seen_hints.is_empty() or not WIPlayerState.seen_hints.get("combat", false), "combat hint should start unseen")

	assert(not WIPlayerState.check_for_level_up(), "should not level with zero accomplishments")

	WIPlayerState.record_accomplishment("won_melee_combat")
	assert(not WIPlayerState.check_for_level_up(), "should not level with only one of two required accomplishments")

	WIPlayerState.record_accomplishment("fortify_door")
	WIPlayerState.record_accomplishment("fortify_barrel")
	assert(not WIPlayerState.accomplishments.has("protected_ally_or_inn"), "umbrella flag should not be set until all 3 fortify sub-flags are present")
	WIPlayerState.record_accomplishment("fortify_patron")
	assert(WIPlayerState.accomplishments.has("protected_ally_or_inn"), "umbrella flag should be set once all 3 fortify sub-flags are present")

	assert(WIPlayerState.classes["fighter"] == 1, "should still be level 1 before the level-up check")
	assert(WIPlayerState.check_for_level_up(), "should level up once both required accomplishments are present")
	assert(WIPlayerState.classes["fighter"] == 2, "fighter should now be level 2")

	assert(not WIPlayerState.check_for_level_up(), "should not level up again past 2")

	print("PASS: WIPlayerState accomplishments and leveling behave correctly")
	quit()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --script res://tests/test_wi_player_state_accomplishments.gd`
Expected: `SCRIPT ERROR` or assertion failure — `record_accomplishment`/`check_for_level_up` don't exist yet.

- [ ] **Step 3: Implement**

Replace the full contents of `src/rpg/state/wi_player_state.gd`:

```gdscript
extends Node

signal character_created

var character_name: String = ""
var race: WIRaceData = null
## class_id (String) -> level (int)
var classes: Dictionary = {}
var has_relc: bool = false
## General-purpose progress-flag store for the "Defend the Inn" quest: combat/fortify
## accomplishments and the umbrella flags derived from them all live here as one source
## of truth rather than several parallel boolean fields.
var accomplishments: Dictionary = {}
## One-time tutorial hint flags, e.g. {"combat": false, "fortify": false}.
var seen_hints: Dictionary = {}


func create_character(p_name: String, p_race: WIRaceData, starting_class_id: String) -> void:
	character_name = p_name
	race = p_race
	classes = {starting_class_id: 1}
	has_relc = false
	accomplishments = {}
	seen_hints = {}
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


## Records a quest-progress flag. Fortify sub-flags additionally roll up into the
## umbrella "protected_ally_or_inn" flag once all 3 are present.
func record_accomplishment(id: String) -> void:
	accomplishments[id] = true
	if id.begins_with("fortify_"):
		var fortify_ids: = ["fortify_door", "fortify_barrel", "fortify_patron"]
		var all_present: = true
		for fortify_id in fortify_ids:
			if not accomplishments.has(fortify_id):
				all_present = false
				break
		if all_present:
			accomplishments["protected_ally_or_inn"] = true


## This slice's leveling rule is written explicitly for the one transition it needs
## (Fighter 1 -> 2) -- not a generic leveling curve. Returns true if a level-up occurred.
func check_for_level_up() -> bool:
	if classes.get("fighter", 0) == 1 and accomplishments.has("won_melee_combat") and accomplishments.has("protected_ally_or_inn"):
		classes["fighter"] = 2
		return true
	return false
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --script res://tests/test_wi_player_state_accomplishments.gd`
Expected: `PASS: WIPlayerState accomplishments and leveling behave correctly`, exit code 0.

- [ ] **Step 5: Headless import + full parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/src/rpg/state/wi_player_state.gd wandering_inn_game_v2/tests/test_wi_player_state_accomplishments.gd
git commit -m "$(cat <<'EOF'
Add accomplishment tracking and Fighter 1->2 leveling to WIPlayerState

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Goblin Raider and Goblin Shaman battler content

**Files:**
- Create: `wandering_inn_game_v2/combat/battlers/goblin_raider/goblin_raider_stats.tres`
- Create: `wandering_inn_game_v2/combat/battlers/goblin_raider/goblin_raider_attack.tres`
- Create: `wandering_inn_game_v2/combat/battlers/goblin_shaman/goblin_shaman_stats.tres`
- Create: `wandering_inn_game_v2/combat/battlers/goblin_shaman/goblin_shaman_spell.tres`

Ported from `wandering_inn_game_v1/data/enemies.json`'s `goblin_raider` (hp 15, damage 3-7) and `goblin_shaman` (hp 20, damage 5-10, fire) entries. Pure data, reusing existing `AttackBattlerAction`/`RangedBattlerAction` scripts — no new GDScript.

**Skills:** `godot-prompter:resource-pattern`

- [ ] **Step 1: Create the directories**

```bash
mkdir -p /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2/combat/battlers/goblin_raider
mkdir -p /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2/combat/battlers/goblin_shaman
```

- [ ] **Step 2: Create Goblin Raider's stats**

Create `combat/battlers/goblin_raider/goblin_raider_stats.tres`:

```
[gd_resource type="Resource" script_class="BattlerStats" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/combat/battlers/battler_stats.gd" id="1"]

[resource]
script = ExtResource("1")
affinity = 0
base_max_health = 15
base_max_energy = 0
base_attack = 5
base_defense = 2
base_speed = 55
base_hit_chance = 90
base_evasion = 8
```

- [ ] **Step 3: Create Goblin Raider's attack**

Create `combat/battlers/goblin_raider/goblin_raider_attack.tres`:

```
[gd_resource type="Resource" script_class="AttackBattlerAction" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/combat/actions/battler_action_attack.gd" id="1"]

[resource]
script = ExtResource("1")
name = "Crude Slash"
description = "A Goblin Raider hacks with a notched blade."
target_scope = 1
targets_friendlies = false
targets_enemies = true
energy_cost = 0
hit_chance = 90.0
base_damage = 5
```

- [ ] **Step 4: Create Goblin Shaman's stats**

Create `combat/battlers/goblin_shaman/goblin_shaman_stats.tres`:

```
[gd_resource type="Resource" script_class="BattlerStats" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/combat/battlers/battler_stats.gd" id="1"]

[resource]
script = ExtResource("1")
affinity = 0
base_max_health = 20
base_max_energy = 6
base_attack = 3
base_defense = 1
base_speed = 45
base_hit_chance = 90
base_evasion = 5
```

- [ ] **Step 5: Create Goblin Shaman's spell (reuses `RangedBattlerAction`, the same class Mage's Fire Bolt uses)**

Create `combat/battlers/goblin_shaman/goblin_shaman_spell.tres`:

```
[gd_resource type="Resource" script_class="RangedBattlerAction" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/combat/actions/battler_action_projectile.gd" id="1"]

[resource]
script = ExtResource("1")
name = "Flame Jet"
description = "The Goblin Shaman spits a jet of fire."
target_scope = 1
targets_friendlies = false
targets_enemies = true
energy_cost = 2
hit_chance = 90.0
base_damage = 8
```

- [ ] **Step 6: Run headless import**

Run: `/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import`
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/combat/battlers/goblin_raider wandering_inn_game_v2/combat/battlers/goblin_shaman
git commit -m "$(cat <<'EOF'
Add Goblin Raider and Goblin Shaman battler content

Ported from wandering_inn_game_v1's enemies.json. Pure data, reusing
the existing AttackBattlerAction/RangedBattlerAction scripts.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Erin's threat-framing dialogue branch + combat hint

**Files:**
- Modify: `wandering_inn_game_v2/overworld/maps/house/erin_intro.dtl`

**Interfaces:**
- Consumes: existing `erin_questions` label hub (verbatim, from Task 0's verified file)
- Produces: a new `- The dungeon sounds bad. Anything else?` choice is NOT added; instead a new linear branch is appended before `label erin_questions` framing the threat, plus the combat hint folded into it

**Skills:** `godot-prompter:dialogue-system`

- [ ] **Step 1: Write the updated dialogue file**

Replace the full contents of `overworld/maps/house/erin_intro.dtl` (adds a threat-framing paragraph with the one-time combat hint folded in, right after the existing intro lines and before the question hub; the existing hub and its 3 choices are otherwise untouched):

```
erin (Default): Oh! Hey! Welcome, welcome — you look like you just walked a million miles. Come in, sit down, I'll get you something to eat. I'm Erin, this is The Wandering Inn!
erin (Default): Fair warning: the stew is amazing, the bread is fresh, and occasionally a goblin tries to walk in through the front door. I handle it. Mostly.
erin (Default): So — adventurer? You've got that look. You know, the 'I have no idea what I'm doing but I'm going to do it anyway' look. I recognize it. I had it too.
erin (Default): The dungeon under Liscor has been really active lately. Lots of adventurers passing through. If you're heading that way, just... be careful, okay? Gold-rank dangerous down there.
erin (Default): Actually — funny you're here now. Goblins have been massing near the floodplains east of Liscor. If they decide the inn looks like an easy target, I'd rather we weren't caught flat-footed.
erin (Default): There's a Shield Spider out past the east gate too, probably scouting the same ground. Deal with that first — it'll tell us how serious this is.
erin (Default): If you haven't been in a proper fight yet: pick an action from the combat menu, then pick who it targets. That's really all there is to it. You'll figure out the rest by doing it.
label erin_questions
- Where am I?
	erin (Default): You're in my inn, just outside Liscor. Well, technically above Liscor. The city is down the hill, full of Drakes, Gnolls, Antinium, guards, merchants, and at least three people who will overcharge you for lunch.
	erin (Default): If this is your first day in this world, breathe. Eat something. Then panic in a more organized way.
	jump erin_questions
- Any advice?
	erin (Default): Be polite to Antinium, don't call Drakes lizards, don't wander into the dungeon alone, and if someone shouts a Skill name, duck first and ask questions later.
	erin (Default): Also, Relc is loud but helpful. If you see a green Drake guardsman in Liscor, that's probably him.
	jump erin_questions
- I'm heading out.
	erin (Default): Then take care of yourself. The door leads down toward Liscor, and if anything with too many legs starts skittering at you, run toward the guards.
[end_timeline]
```

Note: the combat hint line is unconditional here (shown every time Erin's intro plays) rather than flag-gated. This dialogue only plays once per playthrough in practice (it's the fixed intro timeline, not replayable via the question hub), so a `seen_hints` check isn't needed for this specific hint — `seen_hints["combat"]` is reserved for a future replay-safe use if this timeline is ever made re-triggerable, but is not read or written in this task.

- [ ] **Step 2: Run headless parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/overworld/maps/house/erin_intro.dtl
git commit -m "$(cat <<'EOF'
Add goblin-threat framing and combat hint to Erin's intro dialogue

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Fortify-the-inn interaction script and props

**Files:**
- Create: `wandering_inn_game_v2/overworld/maps/house/fortify_interaction.gd`
- Modify: `wandering_inn_game_v2/src/main.tscn` (add 3 nodes under `Field/Map/House/Gamepieces`)

**Interfaces:**
- Consumes: `WIPlayerState.record_accomplishment(id: String)` (Task 1), `WIPlayerState.seen_hints` (Task 1)
- Produces: node structure for 3 fortify props, reused by Task 6 (Bed) for its own similar script

**Skills:** `godot-prompter:dialogue-system`, `godot-prompter:scene-organization`

- [ ] **Step 1: Write the fortify interaction script**

One parameterized script reused by all 3 props via an `@export var accomplishment_id: String` and `@export var hint_text: String` (only the first prop sets `hint_text`; the other two leave it empty).

Create `overworld/maps/house/fortify_interaction.gd`:

```gdscript
extends Interaction

## e.g. "fortify_door", "fortify_barrel", "fortify_patron" -- passed to
## WIPlayerState.record_accomplishment on interact.
@export var accomplishment_id: String = ""
## If non-empty, shown once (gated by WIPlayerState.seen_hints["fortify"]) the first time
## this specific prop is interacted with. Leave empty on props that shouldn't show it.
@export var hint_text: String = ""


func _execute() -> void:
	if hint_text != "" and not WIPlayerState.seen_hints.get("fortify", false):
		WIPlayerState.seen_hints["fortify"] = true
		print(hint_text)
	WIPlayerState.record_accomplishment(accomplishment_id)
	await get_tree().process_frame
```

Note: `print(hint_text)` is a placeholder-free, functional choice for this task — it's a one-line console message visible during manual/headless testing. A future task could route this through the same toast UI Task 5 builds instead; that's not required for this task's scope and is not a TODO left in the code, just a simple working mechanism.

- [ ] **Step 2: Add the 3 fortify prop nodes to `src/main.tscn`**

Locate `Field/Map/House/Gamepieces` (contains `Erin`, confirmed in Task 0's verification). Add these 3 node blocks after Erin's block, following her exact proven structure:

```
[node name="FortifyDoor" parent="Field/Map/House/Gamepieces" instance=ExtResource("11_yntrj")]
position = Vector2(792, 104)
animation_scene = ExtResource("12_oablq")

[node name="Interaction" parent="Field/Map/House/Gamepieces/FortifyDoor" instance=ExtResource("19_sa6jd")]
script = ExtResource("200_fortify")
accomplishment_id = "fortify_door"
hint_text = "There are a few more things around the inn worth preparing before nightfall."

[node name="InteractionPopup" parent="Field/Map/House/Gamepieces/FortifyDoor/Interaction" instance=ExtResource("34_qs25x")]

[node name="FortifyBarrel" parent="Field/Map/House/Gamepieces" instance=ExtResource("11_yntrj")]
position = Vector2(856, 88)
animation_scene = ExtResource("12_oablq")

[node name="Interaction" parent="Field/Map/House/Gamepieces/FortifyBarrel" instance=ExtResource("19_sa6jd")]
script = ExtResource("200_fortify")
accomplishment_id = "fortify_barrel"

[node name="InteractionPopup" parent="Field/Map/House/Gamepieces/FortifyBarrel/Interaction" instance=ExtResource("34_qs25x")]

[node name="FortifyPatron" parent="Field/Map/House/Gamepieces" instance=ExtResource("11_yntrj")]
position = Vector2(856, 120)
animation_scene = ExtResource("12_oablq")

[node name="Interaction" parent="Field/Map/House/Gamepieces/FortifyPatron" instance=ExtResource("19_sa6jd")]
script = ExtResource("200_fortify")
accomplishment_id = "fortify_patron"

[node name="InteractionPopup" parent="Field/Map/House/Gamepieces/FortifyPatron/Interaction" instance=ExtResource("34_qs25x")]
```

Positions are chosen near Erin's existing `Vector2(840, 120)` cell, spaced by at least one 16px cell in each direction to avoid overlapping her or each other or the player's `Vector2(824, 104)` spawn point (all confirmed coordinates from Task 0's verification and the existing scene-contract test).

Add the one new `ext_resource` line near the top of the file (a fresh id per the Global Constraints' `200_...` convention; `12_oablq` and `19_sa6jd`/`34_qs25x`/`11_yntrj` are all already declared, confirmed in Task 0):

```
[ext_resource type="Script" path="res://overworld/maps/house/fortify_interaction.gd" id="200_fortify"]
```

- [ ] **Step 3: Run headless import + parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: no errors, no dangling `ExtResource` warnings.

- [ ] **Step 4: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/overworld/maps/house/fortify_interaction.gd wandering_inn_game_v2/src/main.tscn
git commit -m "$(cat <<'EOF'
Add fortify-the-inn props (door, barrel, patron)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Level-up toast UI

**Files:**
- Create: `wandering_inn_game_v2/src/rpg/ui/level_up_toast.tscn`
- Create: `wandering_inn_game_v2/src/rpg/ui/level_up_toast.gd`

**Interfaces:**
- Produces: `LevelUpToast.show_message(text: String) -> void` (static-style usage: instantiate the scene, add to tree, call this)

**Skills:** `godot-prompter:godot-ui`

- [ ] **Step 1: Write the toast scene**

Follows the CanvasLayer-wrapper pattern already fixed for `character_creation.tscn` (a bare full-rect `Control` at the literal scene root does not reliably fill the viewport in this project — confirmed during v2 debugging).

Create `src/rpg/ui/level_up_toast.tscn`:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://src/rpg/ui/level_up_toast.gd" id="1"]

[node name="LevelUpToast" type="CanvasLayer"]
script = ExtResource("1")

[node name="Root" type="Control" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="Label" type="Label" parent="Root"]
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
anchor_top = 0.1
offset_left = -300.0
offset_right = 300.0
grow_horizontal = 2
horizontal_alignment = 1
```

- [ ] **Step 2: Write the toast script**

Create `src/rpg/ui/level_up_toast.gd`:

```gdscript
extends CanvasLayer

@onready var _label: Label = $Root/Label


func show_message(text: String) -> void:
	_label.text = text
	modulate.a = 1.0
	await get_tree().create_timer(2.0).timeout
	var tween: = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()
```

- [ ] **Step 3: Run headless import + parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/src/rpg/ui/level_up_toast.tscn wandering_inn_game_v2/src/rpg/ui/level_up_toast.gd
git commit -m "$(cat <<'EOF'
Add level-up toast UI

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Bed interactable (sleep beat)

**Files:**
- Create: `wandering_inn_game_v2/overworld/maps/house/bed_interaction.gd`
- Modify: `wandering_inn_game_v2/src/main.tscn` (add `Bed` node under `Field/Map/House/Gamepieces`)

**Interfaces:**
- Consumes: `WIPlayerState.check_for_level_up() -> bool` (Task 1), `LevelUpToast` scene (Task 5)
- Consumes: existing `Transition` autoload (`Transition.cover(duration)`/`Transition.clear(duration)`, confirmed usage pattern from `src/field/cutscenes/templates/area_transitions/area_transition.gd`)

**Skills:** `godot-prompter:dialogue-system`, `godot-prompter:ability-system`

- [ ] **Step 1: Write the Bed interaction script**

Create `overworld/maps/house/bed_interaction.gd`:

```gdscript
extends Interaction

const LEVEL_UP_TOAST: = preload("res://src/rpg/ui/level_up_toast.tscn")


func _execute() -> void:
	await Transition.cover(0.2)
	var leveled_up: = WIPlayerState.check_for_level_up()
	await Transition.clear(0.2)
	if leveled_up:
		var toast: = LEVEL_UP_TOAST.instantiate()
		get_tree().current_scene.add_child(toast)
		toast.show_message("[Fighter Level 2] — unlocked Counter Strike")
```

- [ ] **Step 2: Add the Bed node to `src/main.tscn`**

Add after the fortify props in `Field/Map/House/Gamepieces`:

```
[node name="Bed" parent="Field/Map/House/Gamepieces" instance=ExtResource("11_yntrj")]
position = Vector2(792, 136)
animation_scene = ExtResource("12_oablq")

[node name="Interaction" parent="Field/Map/House/Gamepieces/Bed" instance=ExtResource("19_sa6jd")]
script = ExtResource("201_bed")

[node name="InteractionPopup" parent="Field/Map/House/Gamepieces/Bed/Interaction" instance=ExtResource("34_qs25x")]
```

Add the new `ext_resource` line:

```
[ext_resource type="Script" path="res://overworld/maps/house/bed_interaction.gd" id="201_bed"]
```

- [ ] **Step 3: Run headless import + parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/overworld/maps/house/bed_interaction.gd wandering_inn_game_v2/src/main.tscn
git commit -m "$(cat <<'EOF'
Add Bed interactable for sleep-based leveling

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Defend Inn combat arena

**Files:**
- Create: `wandering_inn_game_v2/overworld/maps/town/battles/defend_inn_combat_arena.tscn`
- Create: `wandering_inn_game_v2/overworld/maps/town/battles/defend_inn_combat_arena.gd`

**Interfaces:**
- Consumes: `PCBattlerBuilder` (unmodified), `WIPlayerState` (Task 1), Relc's existing `.tres` (`combat/battlers/relc/relc_stats.tres`, `relc_attack.tres`, `relc_power_strike.tres`), Goblin Raider/Shaman `.tres` (Task 2)
- Produces: a `PackedScene` referenced by the climax `CombatTrigger` (Task 8)

Structurally identical to `liscor_combat_arena.tscn`/`.gd` (confirmed exact pattern in Task 0's file read) — same `CombatArena` base, same `PC` placeholder-then-rebuilt pattern, same `pc.name` assignment, different static battlers.

**Skills:** `godot-prompter:scene-organization`, `godot-prompter:ability-system`

- [ ] **Step 1: Write the arena script**

Create `overworld/maps/town/battles/defend_inn_combat_arena.gd`:

```gdscript
extends CombatArena


func _ready() -> void:
	var pc: Battler = $Battlers/PC
	pc.name = WIPlayerState.character_name if WIPlayerState.character_name != "" else "PC"

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

- [ ] **Step 2: Create the arena scene**

Modeled on `liscor_combat_arena.tscn`'s exact structure (confirmed in Task 0), swapping Shield Spider for the two goblins:

```
[gd_scene load_steps=16 format=3]

[ext_resource type="PackedScene" path="res://src/combat/combat_arena.tscn" id="1"]
[ext_resource type="Texture2D" path="res://combat/arenas/steppes.png" id="2"]
[ext_resource type="AudioStream" path="res://assets/music/squashin_bugs_fixed.mp3" id="3"]
[ext_resource type="Script" path="res://src/combat/battlers/battler.gd" id="4"]
[ext_resource type="Script" path="res://overworld/maps/town/battles/defend_inn_combat_arena.gd" id="5"]
[ext_resource type="Resource" path="res://combat/battlers/bear/bear_stats.tres" id="6"]
[ext_resource type="Resource" path="res://combat/skills/shared/basic_attack.tres" id="7"]
[ext_resource type="PackedScene" path="res://combat/battlers/pc/pc_anim.tscn" id="8"]
[ext_resource type="Resource" path="res://combat/battlers/relc/relc_stats.tres" id="9"]
[ext_resource type="Resource" path="res://combat/battlers/relc/relc_attack.tres" id="10"]
[ext_resource type="Resource" path="res://combat/battlers/relc/relc_power_strike.tres" id="11"]
[ext_resource type="PackedScene" path="res://combat/battlers/relc/relc_anim.tscn" id="12"]
[ext_resource type="Resource" path="res://combat/battlers/goblin_raider/goblin_raider_stats.tres" id="13"]
[ext_resource type="Resource" path="res://combat/battlers/goblin_raider/goblin_raider_attack.tres" id="14"]
[ext_resource type="Resource" path="res://combat/battlers/goblin_shaman/goblin_shaman_stats.tres" id="15"]
[ext_resource type="Resource" path="res://combat/battlers/goblin_shaman/goblin_shaman_spell.tres" id="16"]
[ext_resource type="PackedScene" path="res://combat/battlers/wolf/wolf_anim.tscn" id="17"]
[ext_resource type="PackedScene" path="res://src/combat/CombatAI.tscn" id="18"]

[node name="DefendInnCombatArena" instance=ExtResource("1")]
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

[node name="GoblinRaider" type="Node2D" parent="Battlers"]
position = Vector2(465, 722)
script = ExtResource("4")
stats = ExtResource("13")
actions = [ExtResource("14")]
battler_anim_scene = ExtResource("17")
ai_scene = ExtResource("18")

[node name="GoblinShaman" type="Node2D" parent="Battlers"]
position = Vector2(606, 550)
script = ExtResource("4")
stats = ExtResource("15")
actions = [ExtResource("16")]
battler_anim_scene = ExtResource("17")
ai_scene = ExtResource("18")
```

`PC`'s `stats`/`actions` are placeholders (required for `Battler._ready()`'s non-null assertion), overwritten at runtime by the arena script — same pattern as `liscor_combat_arena.tscn`. Both goblins reuse `wolf_anim.tscn` as a placeholder visual (no new art, per project convention) and the existing generic `CombatAI.tscn`.

- [ ] **Step 3: Run headless import + parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: no missing-resource or parse errors. If any `ext_resource` path doesn't resolve (e.g. `combat/battlers/pc/pc_anim.tscn` or `combat/battlers/relc/relc_anim.tscn` — both referenced in the existing `test_wi_scene_contracts.gd` from the post-v2 debugging pass, so they should exist, but confirm with `ls` first), fix the path rather than guessing a substitute.

- [ ] **Step 4: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/overworld/maps/town/battles/defend_inn_combat_arena.tscn wandering_inn_game_v2/overworld/maps/town/battles/defend_inn_combat_arena.gd
git commit -m "$(cat <<'EOF'
Add Defend Inn combat arena (PC + Relc vs Goblin Raider + Shaman)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Climax combat trigger and Erin's closing dialogue

**Files:**
- Create: `wandering_inn_game_v2/overworld/maps/town/goblin_raid_climax.dtl`
- Modify: `wandering_inn_game_v2/src/main.tscn` (add climax `CombatTrigger` in Town; add Erin's closing branch)

**Interfaces:**
- Consumes: `defend_inn_combat_arena.tscn` (Task 7), existing `Trigger.tscn` base scene + `roaming_combat_trigger.gd` (confirmed reused pattern from `ShieldSpiderEncounter` in Task 0)

**Skills:** `godot-prompter:scene-organization`, `godot-prompter:dialogue-system`

- [ ] **Step 1: Write Erin's closing dialogue**

Create `overworld/maps/town/goblin_raid_climax.dtl`:

```
erin (Default): You did it! I heard the noise all the way from the kitchen. Goblins, gone, inn still standing — that's a good day around here.
erin (Default): And look at you — leveled up and everything. I knew you had it in you.
[end_timeline]
```

- [ ] **Step 2: Add the climax `CombatTrigger` to Town**

Locate `ShieldSpiderEncounter` in `Field/Map/Town/Gamepieces` (confirmed exact structure in Task 0: instances `ExtResource("105_trigger")`, i.e. `Trigger.tscn`, with `script = ExtResource("33_0gswb")` i.e. `roaming_combat_trigger.gd`, which queues itself free after victory). Add a new trigger following the same pattern, placed near the inn side of Town (so it's encountered after returning from the Bed, not before):

```
[node name="GoblinRaidEncounter" parent="Field/Map/Town/Gamepieces" instance=ExtResource("105_trigger")]
position = Vector2(120, 200)
script = ExtResource("33_0gswb")
combat_arena = ExtResource("202_defend_inn_arena")
```

Add the new `ext_resource` line:

```
[ext_resource type="PackedScene" path="res://overworld/maps/town/battles/defend_inn_combat_arena.tscn" id="202_defend_inn_arena"]
```

- [ ] **Step 3: Wire Erin's closing dialogue**

This slice's resolution beat (talking to Erin after the climax) reuses Erin's existing `Interaction` node in the House, but needs to show the closing dialogue instead of the intro once the climax is won. Confirmed current state of that node in `src/main.tscn`:

```
[node name="Interaction" parent="Field/Map/House/Gamepieces/Erin" unique_id=1046466063 instance=ExtResource("19_sa6jd")]
script = ExtResource("14_b3y71")
timeline = ExtResource("100_erin")
```

`ExtResource("14_b3y71")` is `conversation_template.gd` (`InteractionTemplateConversation`) used directly, and `ExtResource("100_erin")` is `erin_intro.dtl`. Create a small router script that picks the timeline based on quest progress:

Create `overworld/maps/house/erin_dialogue_router.gd`:

```gdscript
@tool
extends InteractionTemplateConversation

@export var intro_timeline: DialogicTimeline
@export var climax_timeline: DialogicTimeline


func _execute() -> void:
	if WIPlayerState.accomplishments.has("protected_ally_or_inn") and WIPlayerState.classes.get("fighter", 0) == 2:
		timeline = climax_timeline
	else:
		timeline = intro_timeline
	await super._execute()
```

`@tool` is required — every subclass of `InteractionTemplateConversation` in this codebase carries it (confirmed convention from v2's Task 12 fix), since the base class is `@tool` and GDScript doesn't inherit the annotation.

Update Erin's `Interaction` node in `src/main.tscn`, replacing its `script`/`timeline` lines:

```
script = ExtResource("203_erin_router")
intro_timeline = ExtResource("100_erin")
climax_timeline = ExtResource("204_goblin_climax")
```

Add the two new `ext_resource` lines (`100_erin` already exists — do not redeclare it):

```
[ext_resource type="Script" path="res://overworld/maps/house/erin_dialogue_router.gd" id="203_erin_router"]
[ext_resource type="Resource" path="res://overworld/maps/town/goblin_raid_climax.dtl" id="204_goblin_climax"]
```

- [ ] **Step 4: Run headless import + parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/overworld/maps/town/goblin_raid_climax.dtl wandering_inn_game_v2/overworld/maps/house/erin_dialogue_router.gd wandering_inn_game_v2/src/main.tscn
git commit -m "$(cat <<'EOF'
Add climax combat trigger and Erin's post-climax dialogue

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Dialogue Choices UI readability polish

**Files:**
- Modify: `wandering_inn_game_v2/src/main.tscn` (`Choices` `VBoxContainer` under `UI/DialogueLayout`)

The panel-covering bug from v2 is already fixed (`Choices` sits above `BoxMargins`, confirmed by the existing `offset_bottom = -112.0` scene-contract assertion in `test_wi_scene_contracts.gd`). The remaining complaint is readability: the choice buttons currently float directly over whatever's behind them (world/portrait art) with no background panel, at `anchor_left/right = 0.5` (horizontally centered) spanning `offset_top = -360.0` to `offset_bottom = -112.0` — a 248px-tall region with `alignment = 2` (bottom-aligned), so buttons cluster near the bottom of that region with empty space above.

**Skills:** `godot-prompter:godot-ui`, `godot-prompter:dialogue-system`

- [ ] **Step 1: Confirm current values before editing**

```bash
grep -n -A20 'node name="Choices" type="VBoxContainer"' /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2/src/main.tscn
```
Confirm the values match what's described above (from this plan's research) before proceeding — if they've changed, adjust the edit in Step 2 accordingly rather than blindly overwriting.

- [ ] **Step 2: Add a background panel behind the choices, tightened to the content**

Add a `PanelContainer` as a new child of `DialogueLayout`, positioned as a sibling of `Choices` at the same rect, so it renders behind the buttons (Godot draws children in order, so declare it in the `.tscn` immediately before the `Choices` node block). Also change `Choices`'s `alignment` from `2` (end/bottom) to `1` (center) so the buttons sit centered within a tightened box rather than bottom-clustered with dead space above:

```
[node name="ChoicesBackground" type="PanelContainer" parent="UI/DialogueLayout"]
layout_mode = 1
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -380.0
offset_top = -300.0
offset_right = 380.0
offset_bottom = -104.0
grow_horizontal = 2
grow_vertical = 0
```

Then change the existing `Choices` node's `alignment` value from `2` to `1`, and tighten its own bounds to sit inside the new background with a small margin (matching the background's inner area minus ~20px padding on each side):

```
offset_left = -360.0
offset_top = -280.0
offset_right = 360.0
offset_bottom = -124.0
alignment = 1
```

(All other `Choices` properties — `layout_mode`, `anchors_preset`, `anchor_left/top/right/bottom`, `grow_horizontal/vertical`, `theme_override_constants/separation` — stay as confirmed in Step 1.)

- [ ] **Step 3: Run headless import + parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --import
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: no errors.

- [ ] **Step 4: Note for manual verification**

This is a visual polish fix that cannot be confirmed without a live playtest (no screenshot/input-injection tooling available in this environment, per the v2 MVP's final review — same limitation applies here). Flag this explicitly in the task report rather than claiming it's visually correct — the background panel + centered alignment is a reasonable first attempt based on the confirmed current values, not a guaranteed-correct visual fix. Include it in Task 10's manual playtest checklist.

- [ ] **Step 5: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/src/main.tscn
git commit -m "$(cat <<'EOF'
Add background panel and re-center dialogue choice buttons

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Scene-contract test updates and full verification pass

**Files:**
- Modify: `wandering_inn_game_v2/tests/test_wi_scene_contracts.gd`

**Skills:** `godot-prompter:godot-testing`

- [ ] **Step 1: Add new contract assertions**

Append to `_init()` in `tests/test_wi_scene_contracts.gd` (before the existing `print("PASS: ...")`/`quit()` lines — read the current file first, since Task 0 already confirmed its exact content, and insert before the final two lines):

```gdscript
	assert(main_scene.contains("[node name=\"FortifyDoor\" parent=\"Field/Map/House/Gamepieces\""), "Fortify door prop should exist")
	assert(main_scene.contains("[node name=\"FortifyBarrel\" parent=\"Field/Map/House/Gamepieces\""), "Fortify barrel prop should exist")
	assert(main_scene.contains("[node name=\"FortifyPatron\" parent=\"Field/Map/House/Gamepieces\""), "Fortify patron prop should exist")
	assert(main_scene.contains("[node name=\"Bed\" parent=\"Field/Map/House/Gamepieces\""), "Bed interactable should exist")
	assert(main_scene.contains("[node name=\"GoblinRaidEncounter\" parent=\"Field/Map/Town/Gamepieces\""), "Climax combat trigger should exist")

	var defend_inn_arena: = FileAccess.get_file_as_string("res://overworld/maps/town/battles/defend_inn_combat_arena.tscn")
	assert(defend_inn_arena.contains("path=\"res://combat/battlers/goblin_raider/goblin_raider_stats.tres\""), "Defend Inn arena should include Goblin Raider")
	assert(defend_inn_arena.contains("path=\"res://combat/battlers/goblin_shaman/goblin_shaman_stats.tres\""), "Defend Inn arena should include Goblin Shaman")
	assert(defend_inn_arena.contains("path=\"res://combat/battlers/relc/relc_stats.tres\""), "Defend Inn arena should include Relc")

	assert(main_scene.contains("[node name=\"ChoicesBackground\" type=\"PanelContainer\" parent=\"UI/DialogueLayout\""), "Dialogue choices should have a background panel")
```

- [ ] **Step 2: Run the updated test**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --script res://tests/test_wi_scene_contracts.gd
```
Expected: `PASS: Wandering Inn scene contracts are wired correctly`.

- [ ] **Step 3: Run all logic tests**

```bash
cd /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2
/usr/local/bin/godot --headless --path . --script res://tests/test_wi_player_state_accomplishments.gd
/usr/local/bin/godot --headless --path . --script res://tests/test_pc_battler_builder.gd
/usr/local/bin/godot --headless --path . --script res://tests/test_wi_resources.gd
/usr/local/bin/godot --headless --path . --script res://tests/verify_content.gd
```
Expected: every script prints its `PASS: ...` line.

- [ ] **Step 4: Full headless parse check**

```bash
/usr/local/bin/godot --headless --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2 --quit
```
Expected: exit 0, no `SCRIPT ERROR`/`Parse Error`.

- [ ] **Step 5: Manual playtest — full v3 loop**

Run `/usr/local/bin/godot --path /Users/gabriel/wandering_inn_rpg/wandering_inn_game_v2` and walk through:
1. Create a character, land near Erin.
2. Talk to Erin — confirm the new threat-framing lines and combat hint appear before the question hub.
3. Walk to Liscor, fight the Shield Spider, win.
4. Return to the inn, interact with all 3 fortify props (confirm the fortify hint shows on the first one only).
5. Interact with the Bed — confirm the level-up toast appears (`[Fighter Level 2] — unlocked Counter Strike`).
6. Confirm the dialogue choice buttons now have a visible background and look readable (Task 9's polish — this is the one item most likely to need another iteration based on what you actually see).
7. Walk to the `GoblinRaidEncounter` trigger in Town — confirm the Defend Inn arena starts with PC (Counter Strike available), Relc, Goblin Raider, and Goblin Shaman all present.
8. Win the fight, return to Erin — confirm her closing dialogue plays instead of the intro.
9. Confirm no errors appear in the console at any point.

- [ ] **Step 6: Commit**

```bash
cd /Users/gabriel/wandering_inn_rpg
git add wandering_inn_game_v2/tests/test_wi_scene_contracts.gd
git commit -m "$(cat <<'EOF'
Add v3 scene-contract assertions and run full verification pass

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```
