extends SceneTree
## Headless test for the pure sim core (no autoloads, no scene tree).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sim_core.gd

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


## Skills Wave Task K2: every `toast` payload's text seen so far, in order --
## a small helper so the sneak toggle/break blocks below don't hand-roll the
## same scan-for-a-type loop repeatedly.
func _toast_texts() -> Array:
	var out: Array = []
	for e: Dictionary in _events:
		if e["type"] == "toast":
			out.append(String(e["payload"].get("text", "")))
	return out


## Forces the pc active and lands one guaranteed melee hit on goblin_raider:
## hit_bonus 1000 makes hit_chance certain (85 + 1000 - dex/4), so no seed
## search is needed. Leaves the raider alive on 999 HP.
func _land_pc_hit(g: WIGame) -> void:
	var cb: WICombat = g.combat
	cb.combatants["pc"][WIKeys.CELL] = (cb.combatants["goblin_raider"][WIKeys.CELL] as Vector2i) + Vector2i.RIGHT
	cb.combatants["goblin_raider"][WIKeys.HP] = 999
	cb.combatants["pc"]["hit_bonus"] = 1000
	cb.active_index = cb.turn_order.find("pc")
	cb._start_turn()
	assert(cb.attack("goblin_raider"), "guaranteed melee hit lands")


func _init() -> void:
	WITestWatchdog.arm(self)
	var scene_config := _load_json("res://data/skeleton_scene.json")
	var skill_config := _load_json("res://data/skills.json")
	var game := WIGame.new(scene_config, skill_config, _sink, 12345)

	# Initialization (M5 E3 inn: 16x10 grid, 4-side wall-segment perimeter)
	assert(game.grid_size == Vector2i(16, 10), "grid size from config")
	assert(game.player_cell == Vector2i(2, 3), "player start cell from config")
	assert(_count("sim_initialized") == 1, "sim_initialized emitted once")

	# M-ARC §5: character-creation cosmetic identity (defaults + creation_config
	# + tolerant sanitize + pure sprite-variant key + snapshot exposure). All
	# cosmetic -- none of these touch a mechanical field.
	assert(game.pc_name == "Traveler" and game.pc_race == "human" and game.pc_gender == "m", "default identity is Human/male/Traveler")
	assert(game.pc_sprite_variant() == "pc_human_m", "default variant key")
	var id_snap := game.snapshot()
	assert(id_snap["pc_name"] == "Traveler" and id_snap["pc_race"] == "human" and id_snap["pc_gender"] == "m", "identity exposed in snapshot")
	assert(id_snap["pc_sprite"] == "pc_human_m", "variant key exposed in snapshot")
	var made := WIGame.new(scene_config, skill_config, _sink, 1, {}, {}, {"pc_name": "Sella", "pc_race": "drake", "pc_gender": "f"})
	assert(made.pc_name == "Sella" and made.pc_race == "drake" and made.pc_gender == "f", "creation_config sets identity")
	assert(made.pc_sprite_variant() == "pc_drake_f", "chosen variant key")
	var dirty := WIGame.new(scene_config, skill_config, _sink, 1, {}, {}, {"pc_name": "  Trimmed  Overlong Name Here  ", "pc_race": "elf", "pc_gender": "x"})
	assert(dirty.pc_race == "human" and dirty.pc_gender == "m", "unknown race/gender sanitized to defaults")
	assert(dirty.pc_name.length() <= WIGame.PC_NAME_MAX and dirty.pc_name.strip_edges() == dirty.pc_name, "name trimmed + length-capped")
	var blank := WIGame.new(scene_config, skill_config, _sink, 1, {}, {}, {"pc_name": "   "})
	assert(blank.pc_name == "Traveler", "blank name falls back to Traveler")

	# Movement + perimeter blocking (west wall segment occupies column x=0)
	assert(game.move_player(Vector2i.UP), "open-cell move succeeds")
	assert(game.player_cell == Vector2i(2, 2), "player moved up")
	for i in 10:
		game.move_player(Vector2i.LEFT)
	assert(game.player_cell.x == 1, "west wall segment at x=0 blocks movement")
	assert(_count("player_blocked") >= 1, "blocked moves emit player_blocked")

	# Bar counters block row 2 (blocked cells at [5,2]/[6,2]); walk to Erin
	# ([7,2], in the bar line) along the open row 3 and bump from below.
	game.move_player(Vector2i.DOWN)  # (1,3)
	while game.player_cell.x < 7:
		assert(game.move_player(Vector2i.RIGHT), "row y=3 is open up to x=7")
	assert(not game.move_player(Vector2i.UP), "npc cell blocks movement")
	assert(game.player_facing == Vector2i.UP, "blocked move still sets facing")

	# Interact with npc -> dialogue_line
	var line := game.interact()
	assert(line.get("speaker", "") == "Erin", "npc interact returns dialogue line")
	assert(_count("dialogue_line") == 1, "dialogue_line emitted")

	# Walk to face the table (prop at [5,4]) from [6,4]
	game.move_player(Vector2i.DOWN)  # (7,4)
	game.move_player(Vector2i.LEFT)  # (6,4)
	game.move_player(Vector2i.LEFT)  # blocked by table, faces it
	assert(game.player_cell == Vector2i(6, 4), "player stands right of table")

	# Interact with prop -> skill chain
	var effect := game.interact()
	assert(effect.get("accomplishment", "") == "cleaned_the_inn", "prop interact returns effect")
	assert(_count("skill_used") == 1, "skill_used emitted")
	assert(_count("accomplishment_recorded") == 1, "accomplishment_recorded emitted")
	# Economy v1 D2: dirty_table's on_skill_use now carries a `gold: 1` wage, so
	# cleaning emits TWO toasts (the "[Basic Cleaning]..." accomplishment toast +
	# the "Earned 1 gold." wage toast) and one gold_changed, and the purse gains 1.
	assert(_count("toast") == 2, "cleaning toast + D2 wage toast both emitted")
	assert(_count("gold_changed") == 1, "cleaning wage emits one gold_changed")
	assert(game.gold == 1, "cleaning the table pays the D2 wage of 1 gold")
	assert(game.accomplishment_count("cleaned_the_inn") == 1, "accomplishment stored")
	# UI wave item 19: the exploration skill_used path records into the
	# used_skills SET (journal first-use reveal gate).
	assert(game.used_skills.has("basic_cleaning"), "exploration use_skill records into used_skills")

	# Counter semantics: re-use increments the count, event fires each time
	game.interact()
	assert(_count("skill_used") == 2, "second use still emits skill_used")
	assert(_count("accomplishment_recorded") == 2, "counter records each increment")
	assert(game.accomplishment_count("cleaned_the_inn") == 2, "count is 2 after two uses")
	assert(game.accomplishment_count("never_done") == 0, "absent id counts 0")

	# Unknown skill is rejected
	var none := game.use_skill("fireball", "dirty_table")
	assert(none.is_empty(), "unknown skill returns empty")
	assert(_count("skill_unknown") == 1, "skill_unknown emitted")

	# Diagnostic events for unhandled cases
	var stray := game.use_skill("basic_cleaning", "erin")
	assert(stray.is_empty(), "skill on target without on_skill_use returns empty")
	assert(_count("skill_no_effect") == 1, "skill_no_effect emitted for inert target")

	# Snapshot shape
	var snap := game.snapshot()
	assert(snap["player_cell"] == [6, 4], "snapshot player_cell")
	assert(snap["current_map"] == "inn", "snapshot current_map")
	assert(snap["accomplishments"]["cleaned_the_inn"] == 2, "snapshot carries counts")
	assert(snap["removed_entities"].is_empty(), "snapshot carries removed_entities")

	# --- Task 7: combat handoff + sleep beat ---
	var combat_config := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"items": _load_json("res://data/items.json"),
	}
	_events.clear()
	var g := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	# Onboarding rev Task O1: the scene config no longer seeds a starting class
	# (classless start -- player.classes is now {}). This fixture's intent is
	# combat-handoff/sleep-leveling machinery, not the classless-start
	# behavior itself (covered separately), so seed Warrior 1 explicitly.
	g.classes = {"warrior": 1}
	assert(g.classes.get("warrior", 0) == 1, "fixture: warrior 1 seeded explicitly (scene config no longer starts classed)")

	# Sleep with nothing earned: soft toast, no level
	g.sleep()
	assert(_count("class_level_up") == 0, "no level without accomplishments")
	assert(_count("toast") == 1, "sleep always toasts")

	# W2 fix: goblin_encounter_2 (and _1, same roster) now gate the relc ally
	# on met_relc via the real dialogue-effect API, before either fight in
	# this block -- accomplishments persist on this g instance across both.
	g.record_accomplishment("met_relc")

	# Start combat via the goblin encounter entity (W1 moved goblin_encounter_1/_2
	# off "street" onto "floodplains" -- transition there so `g.entities.has(...)`
	# checks below reflect the map that actually owns these encounters).
	g.transition("floodplains", Vector2i(27, 18))
	assert(g.start_combat("goblin_encounter_2"), "combat starts")
	assert(g.combat != null and g.combat.combatants.has("pc") and g.combat.combatants.has("relc"), "pc + relc fielded")
	assert((g.combat.combatants["pc"][WIKeys.SKILLS] as Array).has("power_strike"), "pc skills from class grants")
	assert(not (g.combat.combatants["pc"][WIKeys.SKILLS] as Array).has("counter_strike"), "no L2 skills at L1")

	# Force a victory and resolve
	g.combat.apply_damage("goblin_raider", 999, "pc", true)
	g.combat.apply_damage("goblin_shaman", 999, "pc", true)
	assert(g.combat.finished and g.combat.outcome["victory"], "forced victory")
	g.resolve_combat()
	assert(g.combat == null, "combat cleared")
	assert(g.accomplishment_count("won_combat") == 1, "victory recorded")
	assert(g.accomplishment_count("street_cleared") == 1, "street clear recorded")
	assert(not g.entities.has("goblin_encounter_2"), "encounter removed")
	assert(_count("entity_removed") == 1, "entity_removed emitted")
	assert((g.removed_entities as Array[String]).has("goblin_encounter_2"), "removed_entities tracks encounter")

	# Sleep now levels Warrior 2
	_events.clear()
	g.sleep()
	assert(g.classes["warrior"] == 2, "warrior leveled at sleep")
	assert(_count("class_level_up") == 1 and _count("skill_unlocked") == 2, "level + two skill unlocks")

	# Second combat: counter_strike present
	assert(g.start_combat("goblin_encounter_1"), "second combat starts")
	assert((g.combat.combatants["pc"][WIKeys.SKILLS] as Array).has("counter_strike"), "L2 grant fielded")

	# Defeat path: game_over emitted, encounter stays
	g.combat.apply_damage("pc", 999, "goblin_raider", true)
	g.combat.apply_damage("relc", 999, "goblin_raider", true)
	assert(g.combat.finished and not g.combat.outcome["victory"], "forced defeat")
	_events.clear()
	g.resolve_combat()
	assert(_count("game_over") == 1, "game_over on defeat")
	assert(g.entities.has("goblin_encounter_1"), "encounter persists after defeat")

	# --- M2 Task 2: multi-map + doors ---
	var g2 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(g2.current_map == "inn", "starts on start_map")
	assert(g2.entities.has("erin") and not g2.entities.has("selys"), "entities are per-map")
	# Door transition: walk to face inn_door at [15,3] from [14,3]
	g2.player_cell = Vector2i(14, 3)
	g2.player_facing = Vector2i.RIGHT
	_events.clear()
	g2.interact()
	# W1 retargeted the inn door to "floodplains" (was "street") -- the inn
	# door test now proves that transition, not the old street arrival.
	assert(g2.current_map == "floodplains", "door transitions map")
	assert(g2.player_cell == Vector2i(7, 6), "arrives at to_cell")
	assert(_count("map_changed") == 1, "map_changed emitted")
	assert(g2.entities.has("relc") and not g2.entities.has("erin"), "entity view rebound")
	assert(g2.is_cell_blocked(Vector2i(7, 4)), "floodplains wall blocks")
	assert(not g2.is_cell_blocked(Vector2i(7, 3)), "open floodplains cell clear")
	assert(g2.find_entity("erin").size() > 0 and g2.find_entity("nobody").is_empty(), "find_entity searches all maps")
	# Multi-id on_victory (goblin_encounter_2 now lives on floodplains at [28, 18])
	g2.player_cell = Vector2i(27, 18)
	g2.player_facing = Vector2i.RIGHT
	g2.interact()
	assert(g2.combat != null, "warband starts combat (no conversation yet)")
	g2.combat.apply_damage("goblin_raider", 999, "pc", true)
	g2.combat.apply_damage("goblin_shaman", 999, "pc", true)
	g2.resolve_combat()
	assert(g2.accomplishment_count("won_combat") == 1 and g2.accomplishment_count("street_cleared") == 1, "array on_victory records all")

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
	# Onboarding rev Task O1: classless start means g4 has no class grants by
	# default; this fixture's intent is proving known_skills() folds innate +
	# class grants together, so seed Warrior 1 explicitly.
	g4.classes = {"warrior": 1}
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

	# --- M2 Task 5: quest progress events derive from accomplishments ---
	var quest_catalog := {"quests": [{WIKeys.ID: "the_errand", "title": "The Errand", "beats": [
		{WIKeys.ID: "deliver", "description": "Deliver the package.", "complete_when": {"package_delivered": 1}},
		{WIKeys.ID: "decide", "description": "Decide about the reward.", "complete_when": {"errand_decided": 1}},
	]}]}
	var cc4: Dictionary = cc2.duplicate(true)
	cc4["quests"] = quest_catalog
	var g6 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, cc4)
	_events.clear()
	g6.start_quest("the_errand")
	assert(_count("quest_started") == 1 and _count("toast") == 1, "start_quest emits event + toast")
	g6.record_accomplishment("package_delivered")
	g6.record_accomplishment("errand_decided")
	assert(_count("quest_beat_completed") == 2, "both quest beats emitted exactly once")
	assert(_count("quest_completed") == 1, "quest_completed emitted exactly once")

	var edge_graph := {
		"start": "n1",
		"nodes": {"n1": {"speaker": "Erin", "text": "Take this.", "options": [
			{"text": "Done.", "effects": [{"accomplishment": "package_delivered"}, {"quest": "the_errand"}], "end": true},
		]}},
	}
	var cc5: Dictionary = combat_config.duplicate(true)
	cc5["dialogue"] = {"edge_conv": edge_graph}
	cc5["quests"] = quest_catalog
	var g7 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, cc5)
	assert(g7.start_dialogue("edge_conv", "erin"), "edge dialogue starts")
	_events.clear()
	assert(g7.dialogue_choose(0), "accomplishment before quest effect is accepted")
	assert(_count("quest_beat_completed") == 0 and _count("quest_completed") == 0, "unstarted quest does not emit beat events")
	g7.record_accomplishment("errand_decided")
	assert(_count("quest_beat_completed") == 1 and _count("quest_completed") == 1, "edge quest completes from cached started progress")

	# Non-ending start_combat effect fails loudly, not silently
	var dlg_graph2 := {"start": "n1", "nodes": {"n1": {"speaker": "X", "text": "t", "options": [
		{"text": "fight mid-convo", "effects": [{"start_combat": "goblin_encounter_1"}], "goto": "n2"}]},
		"n2": {"speaker": "X", "text": "t2", "options": [{"text": "bye", "end": true}]}}}
	var cc3: Dictionary = combat_config.duplicate(true)
	cc3["dialogue"] = {"conv2": dlg_graph2}
	var g5 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, cc3)
	g5.start_dialogue("conv2", "erin")
	_events.clear()
	assert(g5.dialogue_choose(0), "choice itself succeeds")
	assert(g5.combat == null, "combat not started mid-dialogue")
	assert(_count("dialogue_effect_failed") == 1, "failure surfaced as event")

	# --- M3 Task 5 / Onboarding rev O4: earned multiclass ([Mage] via Pisces) ---
	# The Dusty Scroll RETIRED to flavor (O4): interacting it banks
	# read_dusty_scroll and grants NO class. [Mage] is now earned from Pisces'
	# lesson (learned_magic_from_pisces) + the sleep beat.
	_events.clear()
	var g8 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g8.player_cell = Vector2i(12, 6)
	g8.player_facing = Vector2i.DOWN
	g8.interact()
	assert(g8.accomplishment_count("read_dusty_scroll") == 1, "scroll records its flavor accomplishment")
	assert(g8.accomplishment_count("used_magic") == 0, "scroll no longer banks used_magic (O4 retirement)")
	assert(_count("accomplishment_recorded") == 1, "accomplishment_recorded emitted")
	assert(_count("toast") == 1, "scroll toasts")
	# Repeatable-harmless: interacting again just re-records, no error
	g8.interact()
	assert(g8.accomplishment_count("read_dusty_scroll") == 2, "scroll is repeatable")

	# The retired scroll grants no class at the sleep beat.
	_events.clear()
	g8.sleep()
	assert(g8.classes.get("mage", 0) == 0, "retired scroll no longer grants [Mage]")

	# [Mage] earned for real via Pisces' lesson + sleep: level 1, no level-up
	# (won_combat unmet), and the O4 grants-listing gain toast.
	g8.record_accomplishment("learned_magic_from_pisces")
	_events.clear()
	g8.sleep()
	assert(g8.classes.get("mage", 0) == 1, "mage class gained at sleep")
	assert(_count("class_gained") == 1, "class_gained emitted")
	assert(_count("class_level_up") == 0, "no mage level without won_combat 3")
	var gain_toast: Dictionary = _events[_events.size() - 1]
	assert(gain_toast["type"] == "toast" and gain_toast["payload"]["text"] == "[Mage] class gained! — [Frost Bolt], [Quick Cast], [Light]", "O4 grants-listing gain toast text")

	# Same-sleep composition: gain + immediate level when thresholds already met
	var g9 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	for i in 3:
		g9.record_accomplishment("won_combat")
	g9.record_accomplishment("learned_magic_from_pisces")
	_events.clear()
	g9.sleep()
	assert(g9.classes.get("mage", 0) == 2, "mage gains then immediately levels to 2 in the same sleep")
	assert(_count("class_gained") == 1, "gain event fires once")
	var mage_level_ups := 0
	for e: Dictionary in _events:
		if e["type"] == "class_level_up" and String(e["payload"]["class"]) == "mage":
			mage_level_ups += 1
	assert(mage_level_ups == 1, "mage level event also fires this sleep (warrior incidentally levels too on won_combat 3)")

	# PC combat build carries the mage kit once gained
	g9.transition("street", Vector2i(4, 3))
	assert(g9.start_combat("goblin_encounter_2"), "combat starts with mage-build pc")
	var pc_skills: Array = g9.combat.combatants["pc"][WIKeys.SKILLS]
	assert(pc_skills.has("frost_bolt") and pc_skills.has("quick_cast") and pc_skills.has("flame_jet") and pc_skills.has("mana_shield"), "pc fields full mage kit")
	assert(int(g9.combat.combatants["pc"][WIKeys.MAX_MP]) > 0, "pc has an mp pool once a caster")

	# walls.segments (M5 E3): covered cells resolve as an inclusive rect and
	# merge into blocked_cells at map parse (single-authoring — the renderer
	# paints wall art on exactly these cells).
	var seg_h: Array[Vector2i] = WIGame.segment_cells({"from": [2, 5], "to": [5, 5]})
	var expected_h: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)]
	assert(seg_h == expected_h, "horizontal segment covers the inclusive run")
	var seg_v: Array[Vector2i] = WIGame.segment_cells({"from": [7, 4], "to": [7, 2]})
	assert(seg_v.size() == 3 and seg_v.has(Vector2i(7, 2)) and seg_v.has(Vector2i(7, 4)), "vertical segment covers the run regardless of from/to order")
	assert(WIGame.segment_cells({"from": [3, 3]}).size() == 1, "to defaults to from (single-cell segment)")
	assert(WIGame.segment_cells({}).is_empty(), "malformed segment resolves to no cells")
	var seg_config := {
		"start_map": "room",
		"player": {WIKeys.CELL: [0, 0], "classes": {}, WIKeys.SKILLS: []},
		"maps": {"room": {
			"grid": {"width": 6, "height": 6},
			"blocked": [[4, 4]],
			"walls": {"segments": [{"from": [1, 2], "to": [3, 2], "cap": [0, 0], "face": [0, 1]}]},
			"entities": [],
		}},
	}
	var g10 := WIGame.new(seg_config, skill_config, _sink, 1)
	assert(g10.blocked_cells.size() == 4, "segment cells join listed blocked cells")
	assert(g10.is_cell_blocked(Vector2i(2, 2)), "segment interior cell blocks movement")
	assert(g10.is_cell_blocked(Vector2i(4, 4)), "listed blocked cell still blocks")
	assert(not g10.is_cell_blocked(Vector2i(2, 1)), "cap row above a face segment stays walkable")

	# --- M6 T1: victory banks the PC's action tally into accomplishments ---
	# (spec §2.1 REV 2 — liveness is the `trivial: true` DATA flag only; no
	# round-count or damage heuristic exists. Defeat banks nothing.)
	var g11 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g11.transition("street", Vector2i(4, 3))
	assert(g11.start_combat("goblin_encounter_2"), "tally-bank combat starts")
	var cb11 := g11.combat
	_land_pc_hit(g11)
	(cb11.combatants["pc"][WIKeys.SKILLS] as Array).append("frost_bolt")
	cb11.combatants["pc"][WIKeys.MP] = 10
	_events.clear()
	assert(cb11.use_skill("frost_bolt", "goblin_raider"), "pc casts an ice spell")
	# M-LEGIBILITY L4: the enrichment lives in _combat_event_relay, which is
	# wired as this combat's event sink at start_combat time -- so it fires
	# on this direct WICombat.use_skill call exactly as it would through the
	# real UI, no different setup needed.
	assert(g11.seen_statuses.has("slowed"), "first-ever slowed application banks into seen_statuses")
	var status_applied_11: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "status_applied":
			status_applied_11 = e["payload"]
	assert(bool(status_applied_11.get("first_seen", false)), "first application of a status carries first_seen:true")
	assert(String(status_applied_11.get("status_text", "")) == WIEffectText.status_line("slowed"), "status_applied carries the L1-generated glossary sentence on first encounter")
	cb11.end_turn()
	var guard11 := 0
	while cb11.get_active() != "pc" and guard11 < 8:
		cb11.end_turn()
		guard11 += 1
	assert(cb11.get_active() == "pc", "cycled back to pc's turn")
	assert(cb11.attack("goblin_raider"), "pc lands a second melee hit")
	cb11.apply_damage("goblin_raider", 9999, "pc", true)
	cb11.apply_damage("goblin_shaman", 9999, "pc", true)
	assert(cb11.finished and cb11.outcome["victory"], "forced victory")
	_events.clear()
	g11.resolve_combat()
	assert(g11.accomplishment_count("melee_hit") == 2, "melee hits banked on victory")
	assert(g11.accomplishment_count("spell_cast") == 1, "spell cast banked on victory")
	assert(g11.accomplishment_count("ice_cast") == 1, "element counter banked on victory")
	assert(g11.accomplishment_count("won_combat") == 1, "on_victory records still fire")
	# UI wave item 19: combat's use_skill resolution records into used_skills
	# too (merged from WICombat.used_skills_tally by resolve_combat).
	assert(g11.used_skills.has("frost_bolt"), "combat use_skill records into used_skills")
	# Multi-count counters bank as ONE record_accomplishment call carrying the
	# amount — not N unit increments (event volume stays sane).
	var melee_events := 0
	for e: Dictionary in _events:
		if e["type"] == "accomplishment_recorded" and String(e["payload"][WIKeys.ID]) == "melee_hit":
			melee_events += 1
			assert(int(e["payload"]["count"]) == 2, "banked counter lands in one increment")
	assert(melee_events == 1, "one accomplishment_recorded per banked counter")

	# --- M-LEGIBILITY L4: seen_statuses once-only + cross-fight persistence ---
	var gStatus := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 777, combat_config)
	gStatus.record_accomplishment("met_relc")
	gStatus.transition("floodplains", Vector2i(27, 18))
	assert(gStatus.start_combat("goblin_encounter_2"), "status test: fight 1 starts")
	var cbS := gStatus.combat
	_land_pc_hit(gStatus)
	(cbS.combatants["pc"][WIKeys.SKILLS] as Array).append("frost_bolt")
	cbS.combatants["pc"][WIKeys.MP] = 20
	_events.clear()
	assert(cbS.use_skill("frost_bolt", "goblin_raider"), "status test: cast 1 lands")
	assert(gStatus.seen_statuses == (["slowed"] as Array[String]), "seen_statuses banks exactly one entry after the first-ever application")
	var applied1: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "status_applied":
			applied1 = e["payload"]
	assert(bool(applied1.get("first_seen", false)) and String(applied1.get("status_text", "")) != "", "cast 1's status_applied is first_seen with glossary text")
	# Cycle back to the pc's own turn (dummies-precedent guard loop; goblin_raider/
	# shaman never get a real AI turn here -- end_turn alone just advances the
	# index, matching g11's technique above) and cast again, SAME fight: the
	# once-only property must hold even for a second application within one
	# combat instance (the exact edge case a deferred resolve_combat-time merge
	# would get wrong -- see seen_statuses' own doc comment).
	var guardS := 0
	while cbS.get_active() != "pc" and guardS < 8:
		cbS.end_turn()
		guardS += 1
	assert(cbS.get_active() == "pc", "status test: cycled back to pc for cast 2")
	_events.clear()
	assert(cbS.use_skill("frost_bolt", "goblin_raider"), "status test: cast 2 lands (same target, still alive at 999 hp)")
	assert(gStatus.seen_statuses == (["slowed"] as Array[String]), "a second application of an already-seen status does not duplicate the entry")
	var applied2: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "status_applied":
			applied2 = e["payload"]
	assert(not bool(applied2.get("first_seen", false)), "cast 2's status_applied is NOT first_seen (once-only property: no second toast)")
	assert(String(applied2.get("status_text", "")) == "", "a repeat application carries no glossary text (nothing new to formatting-cost)")
	# Finish and resolve fight 1: seen_statuses is untouched by resolve_combat
	# (proves the real-time relay bank, not a deferred tally, is what's live).
	cbS.apply_damage("goblin_raider", 9999, "pc", true)
	cbS.apply_damage("goblin_shaman", 9999, "pc", true)
	assert(cbS.finished and cbS.outcome["victory"], "status test: fight 1 forced victory")
	gStatus.resolve_combat()
	assert(gStatus.seen_statuses == (["slowed"] as Array[String]), "resolve_combat does not re-merge or duplicate seen_statuses")
	# Fight 2 (a SEPARATE WICombat instance, same WIGame): a status already
	# seen in a PRIOR fight must not re-fire first_seen either -- the
	# cross-fight half of "once ever", not just "once per fight".
	assert(gStatus.start_combat("goblin_encounter_1"), "status test: fight 2 starts")
	var cbS2 := gStatus.combat
	_land_pc_hit(gStatus)
	cbS2.combatants["goblin_raider"][WIKeys.HP] = 999
	(cbS2.combatants["pc"][WIKeys.SKILLS] as Array).append("frost_bolt")
	cbS2.combatants["pc"][WIKeys.MP] = 20
	_events.clear()
	assert(cbS2.use_skill("frost_bolt", "goblin_raider"), "status test: fight 2 cast lands")
	var applied3: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "status_applied":
			applied3 = e["payload"]
	assert(not bool(applied3.get("first_seen", false)), "a status seen in a PRIOR fight is not first_seen in a later one")
	assert(gStatus.seen_statuses == (["slowed"] as Array[String]), "cross-fight: still exactly one seen_statuses entry")

	# `trivial: true` on the ENCOUNTER banks nothing, silently; the fight
	# still resolves normally (on_victory records, entity removed).
	var g12 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g12.find_entity("goblin_encounter_2")["trivial"] = true
	# W1 moved goblin_encounter_2 to "floodplains" -- transition there so the
	# entities.has() check below reads the map that actually owns it.
	g12.transition("floodplains", Vector2i(27, 18))
	assert(g12.start_combat("goblin_encounter_2"), "trivial combat starts")
	_land_pc_hit(g12)
	# UI wave item 19's tally-suppression proof: cast a skill inside the
	# SAME trivial fight that suppresses the ACCOMPLISHMENT tally below, and
	# confirm used_skills still records it — the hook point (WICombat.
	# spend_skill_costs -> resolve_combat's unconditional merge) sits OUTSIDE
	# _bank_action_tally's `trivial` gate, unlike spell_cast/ice_cast.
	(g12.combat.combatants["pc"][WIKeys.SKILLS] as Array).append("frost_bolt")
	g12.combat.combatants["pc"][WIKeys.MP] = 10
	assert(g12.combat.use_skill("frost_bolt", "goblin_raider"), "pc casts an ice spell in the trivial fight")
	g12.combat.apply_damage("goblin_raider", 9999, "pc", true)
	g12.combat.apply_damage("goblin_shaman", 9999, "pc", true)
	g12.resolve_combat()
	assert(g12.accomplishment_count("melee_hit") == 0, "trivial encounter banks no counters")
	assert(g12.accomplishment_count("spell_cast") == 0, "trivial encounter banks no spell_cast counter either")
	assert(g12.used_skills.has("frost_bolt"), "used_skills records the cast DESPITE the trivial encounter suppressing its accomplishment tally")
	assert(g12.accomplishment_count("won_combat") == 1, "on_victory accomplishments still record")
	assert(not g12.entities.has("goblin_encounter_2"), "trivial fight still removes the encounter")

	# `trivial: true` on the ARENA config also suppresses the bank.
	var g13 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g13.transition("street", Vector2i(4, 3))
	assert(g13.start_combat("goblin_encounter_2"), "arena-trivial combat starts")
	g13.combat.arena_config["trivial"] = true
	_land_pc_hit(g13)
	g13.combat.apply_damage("goblin_raider", 9999, "pc", true)
	g13.combat.apply_damage("goblin_shaman", 9999, "pc", true)
	g13.resolve_combat()
	assert(g13.accomplishment_count("melee_hit") == 0, "trivial arena banks no counters")
	assert(g13.accomplishment_count("won_combat") == 1, "on_victory records unaffected by arena flag")

	# Defeat banks NOTHING — defeat reloads the autosave, so lost tallies are
	# consistent with the reload.
	var g14 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	# W2 fix: this block damages "relc" directly, so the ally_requires gate
	# must be met before the encounter starts or relc is never fielded.
	g14.record_accomplishment("met_relc")
	g14.transition("street", Vector2i(4, 3))
	assert(g14.start_combat("goblin_encounter_2"), "defeat-path combat starts")
	_land_pc_hit(g14)
	g14.combat.apply_damage("pc", 9999, "goblin_raider", true)
	g14.combat.apply_damage("relc", 9999, "goblin_raider", true)
	assert(g14.combat.finished and not g14.combat.outcome["victory"], "forced defeat")
	_events.clear()
	g14.resolve_combat()
	assert(_count("game_over") == 1, "game_over on defeat")
	assert(g14.accomplishment_count("melee_hit") == 0, "defeat banks nothing")

	# --- M6 T2: use_skill gates on the FULL known-skills set ---
	# Class-granted exploration skills ([Light], mage L1) fire props without
	# ever entering innate player_skills.
	var g15 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	_events.clear()
	assert(g15.use_skill("light", "unlit_lantern").is_empty(), "ungranted class skill is still unknown")
	assert(_count("skill_unknown") == 1, "unknown-skill event fires pre-grant")
	g15.record_accomplishment("learned_magic_from_pisces")
	g15.sleep()
	assert(g15.classes.get("mage", 0) == 1, "mage gained at the sleep beat")
	assert(not g15.player_skills.has("light"), "light stays class-granted, never innate")
	assert(g15.known_skills().has("light"), "light is in the known set once mage is held")
	_events.clear()
	var lit := g15.use_skill("light", "unlit_lantern")
	assert(lit.get("accomplishment", "") == "lit_the_common_room", "class-granted skill fires the prop")
	assert(g15.accomplishment_count("lit_the_common_room") == 1, "prop accomplishment recorded")
	assert(_count("skill_used") == 1 and _count("toast") == 1, "skill_used + toast emitted")

	# --- M6 T2: multi-level sleeps (spec §2.2 REV 2) ---
	# One sleep resolves ALL earned level-ups in order, announced as ONE
	# batched toast per class (results only — no progress-toward text).
	var g16 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g16.classes["warrior"] = 2
	g16.classes["mage"] = 1
	g16.record_accomplishment("melee_hit", 18)
	_events.clear()
	g16.sleep()
	assert(g16.classes["warrior"] == 5, "one sleep resolves ALL earned levels (2 -> 5)")
	assert(g16.classes["mage"] == 1, "second class untouched (its won_combat gate unmet)")
	var warrior_levels: Array = []
	var warrior_toasts: Array = []
	for e: Dictionary in _events:
		if e["type"] == "class_level_up" and String(e["payload"]["class"]) == "warrior":
			warrior_levels.append(int(e["payload"]["level"]))
		if e["type"] == "toast" and String(e["payload"]["text"]).begins_with("[Warrior"):
			warrior_toasts.append(String(e["payload"]["text"]))
	assert(warrior_levels == [3, 4, 5], "a class_level_up event per earned level, ascending")
	assert(warrior_toasts.size() == 1, "ONE batched toast per class")
	assert(warrior_toasts[0] == "[Warrior Level 2 → 5] — unlocked [Quick Movement], [Second Wind], [Dangersense]", "batched toast announces span + all unlocks")
	assert(_count("skill_unlocked") == 3, "per-level grants all unlock")
	# Grant-less spans keep the toast clean (no dangling unlock clause).
	g16.record_accomplishment("melee_hit", 30)
	_events.clear()
	g16.sleep()
	assert(g16.classes["warrior"] == 9, "second sleep walks 5 -> 9 on melee_hit 48")
	var span_toast := ""
	for e: Dictionary in _events:
		if e["type"] == "toast" and String(e["payload"]["text"]).begins_with("[Warrior"):
			span_toast = String(e["payload"]["text"])
	assert(span_toast == "[Warrior Level 5 → 9]", "grant-less batch toasts the span only")
	# Single-level sleeps keep the established single-level shape (mage L2 on
	# won_combat 3; warrior is past L2 and has no won_combat gate above it).
	g16.record_accomplishment("won_combat", 3)
	_events.clear()
	g16.sleep()
	var mage_toast := ""
	for e: Dictionary in _events:
		if e["type"] == "toast" and String(e["payload"]["text"]).begins_with("[Mage"):
			mage_toast = String(e["payload"]["text"])
	assert(mage_toast == "[Mage Level 2] — unlocked [Flame Jet], [Mana Shield]", "single level keeps the plain shape")

	# --- M6 T2: respawning encounters (spec §2.2 — the counter volume valve) ---
	# Victory over a `respawns: true` encounter leaves it on the map but
	# dormant; the next sleep re-arms it and it fights (and banks) again.
	var g17 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g17.find_entity("goblin_encounter_2")["respawns"] = true
	# W1 moved goblin_encounter_2 to "floodplains" -- transition there so the
	# entities.has() check below reads the map that actually owns it.
	g17.transition("floodplains", Vector2i(27, 18))
	assert(g17.start_combat("goblin_encounter_2"), "respawning combat starts")
	_land_pc_hit(g17)
	g17.combat.apply_damage("goblin_raider", 9999, "pc", true)
	g17.combat.apply_damage("goblin_shaman", 9999, "pc", true)
	_events.clear()
	g17.resolve_combat()
	assert(g17.entities.has("goblin_encounter_2"), "respawning encounter stays on the map")
	assert(_count("entity_removed") == 0, "no removal event for a respawner")
	assert(_count("combat_resolved") == 1, "victory still resolves normally")
	assert(Array(g17.dormant_encounters) == ["goblin_encounter_2"], "beaten respawner is dormant")
	assert(g17.snapshot()["dormant_encounters"] == ["goblin_encounter_2"], "snapshot exposes dormancy for QA")
	assert(g17.accomplishment_count("melee_hit") == 1, "respawner victories bank counters")
	assert(not g17.start_combat("goblin_encounter_2"), "dormant encounter refuses to re-fight before sleep")
	g17.sleep()
	assert(g17.dormant_encounters.is_empty(), "sleep re-arms respawners")
	assert(g17.start_combat("goblin_encounter_2"), "re-armed encounter fights again")
	_land_pc_hit(g17)
	g17.combat.apply_damage("goblin_raider", 9999, "pc", true)
	g17.combat.apply_damage("goblin_shaman", 9999, "pc", true)
	g17.resolve_combat()
	assert(g17.accomplishment_count("won_combat") == 2, "second win records again")
	assert(g17.accomplishment_count("melee_hit") == 2, "second win banks counters again")

	# --- M-FP S1: `persistent` encounters (rewarding a repeatable spar) ---
	# Victory over a `persistent: true` (and non-respawning) encounter leaves
	# it live and immediately re-fightable -- no dormancy detour, no removal.
	var gp1 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gp1.find_entity("goblin_encounter_2")["persistent"] = true
	# W1 moved goblin_encounter_2 to "floodplains" -- transition there so the
	# entities.has() check below reads the map that actually owns it.
	gp1.transition("floodplains", Vector2i(27, 18))
	assert(gp1.start_combat("goblin_encounter_2"), "persistent combat starts")
	_land_pc_hit(gp1)
	gp1.combat.apply_damage("goblin_raider", 9999, "pc", true)
	gp1.combat.apply_damage("goblin_shaman", 9999, "pc", true)
	_events.clear()
	gp1.resolve_combat()
	assert(gp1.entities.has("goblin_encounter_2"), "persistent encounter stays on the map")
	assert(gp1.find_entity("goblin_encounter_2").size() > 0, "persistent encounter still findable")
	assert((gp1.removed_entities as Array[String]).is_empty(), "removed_entities untouched by a persistent win")
	assert(_count("entity_removed") == 0, "no entity_removed for a persistent win")
	assert(gp1.dormant_encounters.is_empty(), "persistent (non-respawning) win never goes dormant")
	assert(gp1.start_combat("goblin_encounter_2"), "persistent encounter is immediately re-fightable")

	# g-persist-2: a non-persistent (and non-respawning) encounter is removed
	# exactly as before -- the persistent flag adds a branch, it doesn't
	# change the default.
	var gp2 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	# W1 moved goblin_encounter_2 to "floodplains" -- transition there so the
	# entities.has() checks below read the map that actually owns it.
	gp2.transition("floodplains", Vector2i(27, 18))
	assert(gp2.start_combat("goblin_encounter_2"), "non-persistent combat starts")
	_land_pc_hit(gp2)
	gp2.combat.apply_damage("goblin_raider", 9999, "pc", true)
	gp2.combat.apply_damage("goblin_shaman", 9999, "pc", true)
	_events.clear()
	gp2.resolve_combat()
	assert(not gp2.entities.has("goblin_encounter_2"), "non-persistent encounter removed as today")
	assert((gp2.removed_entities as Array[String]).has("goblin_encounter_2"), "removed_entities tracks it")
	assert(_count("entity_removed") == 1, "entity_removed emitted as today")

	# --- M-FP S1: `ally_requires` roster gate ---
	# g-ally-1: the accomplishment counter isn't met -> the allies list is
	# gated empty even though the entity still declares `allies`.
	var ga1 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	ga1.find_entity("goblin_encounter_2")["ally_requires"] = {"met_relc": 1}
	ga1.transition("street", Vector2i(4, 3))
	assert(ga1.start_combat("goblin_encounter_2"), "combat starts without the ally requirement met")
	assert(not ga1.combat.combatants.has("relc"), "ungated allies stay off the roster when the requirement isn't met")

	# g-ally-2: same encounter, requirement satisfied -> relc is fielded.
	var ga2 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	ga2.find_entity("goblin_encounter_2")["ally_requires"] = {"met_relc": 1}
	ga2.record_accomplishment("met_relc")
	ga2.transition("street", Vector2i(4, 3))
	assert(ga2.start_combat("goblin_encounter_2"), "combat starts with the ally requirement met")
	assert(ga2.combat.combatants.has("relc"), "ally fielded once the requirement is met")

	# --- M6 T2 + Skills Wave K4: a mixed wired/unresolved-effect kit builds
	# fine either way; the WIRED ones now actually resolve ---
	# Warrior 5's kit fields second_wind/quick_movement/dangersense. K4 wired
	# second_wind (self-heal) and quick_movement (turn-start move_pool
	# passive) for real; dangersense remains a confirmed, intentional no-op
	# (no clean currency read -- see effect_text.gd's `_effect_phrase` doc
	# comment) -- it was never one of K4's four wiring items, unchanged.
	var g18 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g18.classes["warrior"] = 5
	g18.transition("street", Vector2i(4, 3))
	assert(g18.start_combat("goblin_encounter_2"), "combat builds with a mixed wired/unresolved-effect kit")
	var cb18 := g18.combat
	var pc18: Dictionary = cb18.combatants["pc"]
	assert((pc18[WIKeys.SKILLS] as Array).has("second_wind") and (pc18[WIKeys.SKILLS] as Array).has("quick_movement") and (pc18[WIKeys.SKILLS] as Array).has("dangersense"), "new-type skills fielded")
	cb18.active_index = cb18.turn_order.find("pc")
	cb18._start_turn()
	# Skills Wave Task K4: quick_movement's 0-cost passive fires at THIS
	# _start_turn, unconditionally -- base MOVE_POOL (3) + its amount (1).
	assert(int(pc18[WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL + 1, "quick_movement's passive grants +1 move_pool every turn start")
	pc18[WIKeys.HP] = int(pc18[WIKeys.MAX_HP]) - 5
	var hp_before := int(pc18[WIKeys.HP])
	var ap_before := int(pc18[WIKeys.AP])
	assert(cb18.use_skill("second_wind", "pc"), "second_wind now resolves as a self-heal")
	assert(int(pc18[WIKeys.HP]) == mini(hp_before + 8, int(pc18[WIKeys.MAX_HP])), "second_wind restores effect.amount HP, capped at max_hp")
	assert(int(pc18[WIKeys.AP]) == ap_before - 2, "second_wind costs 2 AP")
	var ap_before2 := int(pc18[WIKeys.AP])
	assert(not cb18.use_skill("second_wind", "goblin_raider"), "second_wind still refuses an enemy target (the type-keyed same-side gate)")
	assert(not cb18.use_skill("dangersense", "goblin_raider"), "unresolved passive-shaped active still refuses")
	assert(int(pc18[WIKeys.AP]) == ap_before2, "refused casts spend nothing")
	_land_pc_hit(g18)

	# --- M6 T5: consolidation offer defers the sleep beat's evolution stage ---
	# (spec §2.5 REV 2): a sleep that fires an offer emits consolidation_offered,
	# stores the pending offer, and STOPS before evolutions resolve -- the
	# "You sleep soundly." fallback must not fire on a sleep that produced one.
	var g19 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g19.classes = {"warrior": 10, "mage": 10}
	g19.accomplishments = {"sword_skill_used": 12, "spear_skill_used": 2, "ice_cast": 13, "fire_cast": 1}
	_events.clear()
	g19.sleep()
	assert(_count("consolidation_offered") == 1, "qualifying sleep emits consolidation_offered")
	var offered_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "consolidation_offered":
			offered_payload = e["payload"]
	assert((offered_payload["parents"] as Array) == ["warrior", "mage"], "offer payload carries parents")
	assert(offered_payload["target"] == "spellsword", "offer payload carries target")
	assert(int(offered_payload["level"]) == 14, "offer payload carries merged level (10,10) -> 14")
	assert(_count("class_evolved") == 0, "evolutions are DEFERRED, not resolved, on the offering sleep")
	assert(not _events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "You sleep soundly."), "the soundly-sleep fallback never fires on an offering sleep")
	assert(g19.classes.has("warrior") and g19.classes.has("mage"), "parents are untouched until the offer resolves")
	assert(g19.pending_consolidation.get("target", "") == "spellsword", "pending offer stored on the game")

	# accept_consolidation: consumes both parents into the target at the
	# merged level; NO evolutions run this sleep; emits consolidation_accepted.
	_events.clear()
	g19.accept_consolidation()
	assert(_count("consolidation_accepted") == 1, "accept emits consolidation_accepted")
	assert(not g19.classes.has("warrior") and not g19.classes.has("mage"), "both parent classes are erased")
	assert(int(g19.classes.get("spellsword", 0)) == 14, "target class set at the merged level")
	assert(_count("class_evolved") == 0, "accept never runs the evolution stage")
	assert(g19.pending_consolidation.is_empty(), "pending offer cleared after accept")
	# Skills fold via the existing inherits chain: spellsword inherits BOTH
	# parents, so the kit still resolves warrior's and mage's grants.
	var post_accept_skills := g19.known_skills()
	assert(post_accept_skills.has("basic_swordwork") and post_accept_skills.has("frost_bolt"), "spellsword's inherits chain still resolves both parents' kits")
	assert(post_accept_skills.has("keener_edge"), "spellsword's own signature grant is present")

	# accept_consolidation with NO pending offer is a safe no-op.
	_events.clear()
	g19.accept_consolidation()
	assert(_events.is_empty(), "accept with no pending offer emits nothing")

	# decline_consolidation: emits consolidation_declined, then runs evolutions
	# EXACTLY as an un-offered sleep would (recomputed from CURRENT counters
	# at answer time -- not stashed derived results from the offering sleep).
	var g20 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g20.classes = {"warrior": 10, "mage": 10}
	g20.accomplishments = {"sword_skill_used": 12, "spear_skill_used": 2, "ice_cast": 13, "fire_cast": 1}
	_events.clear()
	g20.sleep()
	assert(g20.pending_consolidation.get("target", "") == "spellsword", "same setup defers with a pending offer")
	_events.clear()
	g20.decline_consolidation()
	assert(_count("consolidation_declined") == 1, "decline emits consolidation_declined")
	assert(g20.pending_consolidation.is_empty(), "pending offer cleared after decline")
	assert(_count("class_evolved") == 2, "decline resolves BOTH classes' evolutions (warrior->swordsman, mage->ice_mage)")
	assert(g20.classes.has("swordsman") and not g20.classes.has("warrior"), "warrior evolves to swordsman on decline")
	assert(g20.classes.has("ice_mage") and not g20.classes.has("mage"), "mage evolves to ice_mage on decline")

	# decline_consolidation with NO pending offer is a safe no-op.
	_events.clear()
	g20.decline_consolidation()
	assert(_events.is_empty(), "decline with no pending offer emits nothing")

	# Decline where the evolution stage produces NO outcome at all (neither
	# parent at its evolution at_level yet) still falls through to the
	# "You sleep soundly." fallback -- decline's evolution stage behaves
	# exactly like a normal non-offering sleep, including that fallback.
	var g20b := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g20b.classes = {"warrior": 6, "mage": 7}
	_events.clear()
	g20b.sleep()
	assert(g20b.pending_consolidation.get("target", "") == "spellsword", "warrior 6 / mage 7 (sum 13) still triggers the offer below evolution's at_level 10")
	_events.clear()
	g20b.decline_consolidation()
	assert(_count("class_evolved") == 0, "neither class is at its evolution at_level yet -- no outcome at all")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "You sleep soundly."), "decline with zero evolution outcomes still falls through to the soundly-sleep fallback")

	# Decline -> re-offered at every future qualifying sleep (no decline-memory
	# suppression). Simulate: rebuild the same pre-evolution state and sleep
	# again; the offer must fire again identically.
	var g21 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g21.classes = {"warrior": 10, "mage": 10}
	g21.accomplishments = {"sword_skill_used": 12, "spear_skill_used": 2, "ice_cast": 13, "fire_cast": 1}
	g21.sleep()
	_events.clear()
	g21.decline_consolidation()
	# Nothing else changed; re-arm the same qualifying state (evolutions already
	# consumed warrior/mage on decline, so re-create the parents to prove
	# re-offer works on a FRESH qualifying instance, not the same evolved one).
	g21.classes = {"warrior": 10, "mage": 10}
	_events.clear()
	g21.sleep()
	assert(_count("consolidation_offered") == 1, "decline does not suppress future offers -- re-offered at the next qualifying sleep")

	# recompute at answer time: a decline that happens after counters CHANGED
	# between offer and answer must evolve based on CURRENT counters, not
	# stashed derived results from the offering sleep.
	var g22 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g22.classes = {"warrior": 10, "mage": 10}
	g22.accomplishments = {"sword_skill_used": 12, "spear_skill_used": 2, "ice_cast": 13, "fire_cast": 1}
	g22.sleep()
	assert(g22.pending_consolidation.get("target", "") == "spellsword", "offer pending")
	# Mutate the accomplishments AFTER the offer, BEFORE the decline answer --
	# warrior's dominant weapon flips from sword to spear.
	g22.accomplishments["spear_skill_used"] = 20
	_events.clear()
	g22.decline_consolidation()
	assert(g22.classes.has("spearmaster"), "decline recomputes evolutions from CURRENT (post-offer-mutation) counters, not stale ones")
	assert(not g22.classes.has("swordsman"), "the stale sword-dominant outcome from offer time is NOT applied")

	# no-pending no-op safety on a game that never had ANY offer at all.
	var g23 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	_events.clear()
	g23.accept_consolidation()
	g23.decline_consolidation()
	assert(_events.is_empty(), "accept/decline on a game with no offer ever emits nothing")

	# --- M-ARC AF I1: consolidation must NOT regress the Act III gate ---
	# The exact review scenario: a Warrior/Mage who reaches the consolidation
	# threshold AT the Act II boundary and ACCEPTS the [Spellsword] merge (2
	# classes -> 1) must still (a) keep the journal act-line at Act III and (b)
	# fire the tremor pointer -- both now read the MONOTONIC reached_two_classes
	# flag, never the live class count. Needs acts + quests config so
	# act_summary()/_quests_completed_count() are live (base combat_config omits
	# both). A minimal 3-quest catalog (each completing on one accomplishment)
	# stands in for the shipped quests -- WIActs only counts COMPLETED quests.
	var cc_arc := combat_config.duplicate(true)
	cc_arc["acts"] = _load_json("res://data/acts.json")
	cc_arc["quests"] = {"quests": [
		{WIKeys.ID: "q_a", "beats": [{WIKeys.ID: "b", "description": "", "complete_when": {"qa_done": 1}}]},
		{WIKeys.ID: "q_b", "beats": [{WIKeys.ID: "b", "description": "", "complete_when": {"qb_done": 1}}]},
		{WIKeys.ID: "q_c", "beats": [{WIKeys.ID: "b", "description": "", "complete_when": {"qc_done": 1}}]},
	]}
	var arc := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, cc_arc)
	# Act II complete: warrior+mage at the consolidation threshold (6/7, sum 13),
	# 3 quests done, reached_liscor -- but reached_two_classes NOT yet banked
	# (this game never loaded a save), no Act III keys.
	arc.classes = {"warrior": 6, "mage": 7}
	arc.started_quests.assign(["q_a", "q_b", "q_c"])
	arc.accomplishments = {"reached_liscor": 1, "qa_done": 1, "qb_done": 1, "qc_done": 1}
	arc.reprime_quests()
	# Baseline: the act line reads Act II until the monotonic flag is banked,
	# even though two classes are already held (the gate no longer reads size).
	assert(arc.act_summary()[WIKeys.ID] == "act_ii", "AF I1 baseline: pre-flag act line sits at Act II (gate reads reached_two_classes, not classes.size())")

	# Sleep 1: banks reached_two_classes (two classes held) BEFORE the
	# consolidation offer defers the rest of the beat. The tremor is deferred to
	# a later sleep (the offer returns early) -- the honest one-sleep delay.
	_events.clear()
	arc.sleep()
	assert(arc.accomplishment_count("reached_two_classes") == 1, "AF I1: the qualifying sleep banks reached_two_classes")
	assert(arc.pending_consolidation.get("target", "") == "spellsword", "AF I1: that sleep defers with a [Spellsword] offer")
	assert(arc.accomplishment_count("watch_runner_pointed") == 0, "AF I1: the offer sleep defers the tremor pointer (one-sleep delay)")
	assert(arc.act_summary()[WIKeys.ID] == "act_iii", "AF I1: flag banked -> act line advances to Act III")

	# ACCEPT the merge: 2 classes -> 1 [Spellsword]; the live count drops to 1.
	arc.accept_consolidation()
	assert(arc.classes.size() == 1 and arc.classes.has("spellsword"), "AF I1: accepted merge leaves a single [Spellsword] class")
	assert(arc.accomplishment_count("reached_two_classes") == 1, "AF I1: reached_two_classes survives the merge (monotonic, never un-banked)")
	# TOOTH (a): the act line does NOT regress -- still Act III at classes.size()==1.
	assert(arc.act_summary()[WIKeys.ID] == "act_iii", "AF I1: post-consolidation act line stays Act III, never walks back to Act II")

	# TOOTH (b): the tremor pointer STILL fires on the next sleep despite
	# classes.size()==1 -- pre-fix the gate read `classes.size() < 2` and would
	# have returned false forever, silently locking Act III.
	_events.clear()
	arc.sleep()
	assert(arc.accomplishment_count("watch_runner_pointed") == 1, "AF I1: post-consolidation sleep fires the tremor pointer (gate reads the flag, not the live count)")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "A Watch runner is looking for you."), "AF I1: the Watch-runner pointer toast renders after consolidation")

	# --- M7 Task E2: equipment state, API, combat-build injection ---
	# Default start state (skeleton_scene.json player block, same idiom as
	# player.skills): the starter sword is BOTH equipped AND possessed.
	var e1 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(e1.inventory.has("rusty_sword"), "PC starts carrying the starter sword")
	assert(String(e1.equipped.get(WIKeys.WEAPON, "")) == "rusty_sword", "PC starts with the starter sword equipped")
	assert(String(e1.equipped.get("armor", "")) == "", "PC starts with no armor equipped")
	# M-GEAR Task G1: three accessory slots + the resonance budget, both fresh.
	assert(String(e1.equipped.get("accessory_1", "?")) == "", "PC starts with no accessory_1 equipped")
	assert(String(e1.equipped.get("accessory_2", "?")) == "", "PC starts with no accessory_2 equipped")
	assert(String(e1.equipped.get("accessory_3", "?")) == "", "PC starts with no accessory_3 equipped")
	assert(e1.resonance_capacity == 2, "PC starts with the default resonance_capacity of 2")
	assert(e1.item("rusty_sword").get(WIKeys.KIND, "") == "weapon", "item() resolves the starter sword's catalog record")
	assert(e1.item("nonexistent_item").is_empty(), "item() returns {} for an unknown id")

	# pickup(): idempotent, emits ITEM_GAINED with source provenance.
	_events.clear()
	assert(e1.pickup("leather_jerkin", "inn_chest"), "pickup adds a new item")
	assert(e1.inventory.has("leather_jerkin"), "picked-up item joins inventory")
	assert(_count("item_gained") == 1, "item_gained emitted once")
	var gained_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "item_gained":
			gained_payload = e["payload"]
	assert(gained_payload.get("item", "") == "leather_jerkin" and gained_payload.get("source", "") == "inn_chest", "item_gained payload carries item + source")
	_events.clear()
	assert(not e1.pickup("leather_jerkin", "inn_chest"), "repeat pickup of an already-carried item is a no-op")
	assert(_events.is_empty(), "repeat pickup emits nothing")

	# equip()/unequip(): kind/possession validated, invariant maintained.
	_events.clear()
	assert(not e1.equip("chipped_spear"), "cannot equip an item not in inventory")
	assert(_events.is_empty(), "unpossessed equip attempt emits nothing")
	assert(not e1.equip("nonexistent_item"), "cannot equip an unknown item id")
	assert(e1.equip("leather_jerkin"), "equip succeeds once possessed")
	assert(String(e1.equipped.get("armor", "")) == "leather_jerkin", "armor slot holds the equipped item")
	assert(_count("item_equipped") == 1, "item_equipped emitted once")
	var equipped_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "item_equipped":
			equipped_payload = e["payload"]
	assert(equipped_payload.get("item", "") == "leather_jerkin" and equipped_payload.get("slot", "") == "armor", "item_equipped payload carries item + slot")
	for slot: String in e1.equipped:
		var eq_id := String(e1.equipped[slot])
		assert(eq_id == "" or e1.inventory.has(eq_id), "invariant: every non-empty equipped slot is also in inventory")

	_events.clear()
	assert(e1.unequip("armor"), "unequip clears a filled slot")
	assert(String(e1.equipped.get("armor", "")) == "", "armor slot is empty after unequip")
	assert(_count("item_unequipped") == 1, "item_unequipped emitted once")
	assert(not e1.unequip("armor"), "unequip on an already-empty slot is a no-op")
	assert(not e1.unequip("bogus_slot"), "unequip on an unknown slot name is a no-op")

	# Field-only guard: equip/unequip refuse while a fight is active.
	e1.transition("floodplains", Vector2i(27, 18))
	e1.record_accomplishment("met_relc")
	assert(e1.start_combat("goblin_encounter_2"), "combat starts for the field-only guard check")
	_events.clear()
	assert(not e1.equip("leather_jerkin"), "equip refuses mid-combat (field-only action)")
	assert(not e1.unequip("weapon"), "unequip refuses mid-combat (field-only action)")
	assert(_events.is_empty(), "mid-combat equip/unequip attempts emit nothing")
	e1.combat.apply_damage("goblin_raider", 999, "pc", true)
	e1.combat.apply_damage("goblin_shaman", 999, "pc", true)
	e1.resolve_combat()

	# --- M-GEAR Task G1: resonance-limited accessory slots ---
	# Test-fixture accessory items (temporary, in-test only -- data/items.json
	# stays G2's, per the plan). Each isolates one combat-build field so the
	# fold-through assertion below can attribute a nonzero result to a single
	# accessory unambiguously.
	var cc_g1: Dictionary = combat_config.duplicate(true)
	var g1_items: Array = ((cc_g1["items"] as Dictionary)["items"] as Array).duplicate(true)
	g1_items.append_array([
		{WIKeys.ID: "test_charm_hp", WIKeys.KIND: "accessory", WIKeys.HP_MOD: 3, WIKeys.RESONANCE: 0},
		{WIKeys.ID: "test_charm_dmg", WIKeys.KIND: "accessory", WIKeys.DAMAGE_MOD: 2, WIKeys.RESONANCE: 0},
		{WIKeys.ID: "test_charm_reduc", WIKeys.KIND: "accessory", WIKeys.DAMAGE_REDUCTION: 4, WIKeys.RESONANCE: 0},
		{WIKeys.ID: "test_charm_over", WIKeys.KIND: "accessory", WIKeys.RESONANCE: 3},
		{WIKeys.ID: "test_charm_extra", WIKeys.KIND: "accessory", WIKeys.RESONANCE: 0},
		{WIKeys.ID: "test_ring_res1", WIKeys.KIND: "accessory", WIKeys.RESONANCE: 1},
		{WIKeys.ID: "test_blade_res1", WIKeys.KIND: "weapon", "weapon_family": "sword", WIKeys.RESONANCE: 1},
		{WIKeys.ID: "test_blade_res1b", WIKeys.KIND: "weapon", "weapon_family": "sword", WIKeys.RESONANCE: 1},
	])
	cc_g1["items"] = {"items": g1_items}
	var gAcc := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, cc_g1)
	for fixture_id: String in ["test_charm_hp", "test_charm_dmg", "test_charm_reduc", "test_charm_over", "test_charm_extra", "test_ring_res1", "test_blade_res1", "test_blade_res1b"]:
		gAcc.pickup(fixture_id, "test_fixture")

	# equip() routes an "accessory" kind item into the first EMPTY accessory
	# slot (kind routing "exactly the way weapon/armor routing works today").
	_events.clear()
	assert(gAcc.equip("test_charm_hp"), "equip an accessory into the first empty slot")
	assert(String(gAcc.equipped.get("accessory_1", "")) == "test_charm_hp", "first accessory equip lands in accessory_1")
	var acc_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "item_equipped":
			acc_payload = e["payload"]
	assert(acc_payload.get("item", "") == "test_charm_hp" and acc_payload.get("slot", "") == "accessory_1", "item_equipped payload carries item + the actual accessory slot")
	assert(gAcc.equip("test_charm_dmg"), "equip a second accessory")
	assert(String(gAcc.equipped.get("accessory_2", "")) == "test_charm_dmg", "second accessory equip lands in accessory_2 (first still occupied)")

	# G1 review fix (Finding 1): an accessory ALREADY WORN in one slot must
	# not equip again into another empty slot -- a duplicate id would double
	# its contribution in both the resonance sum and the combat-build fold.
	_events.clear()
	assert(not gAcc.equip("test_charm_hp"), "re-equipping an already-worn accessory is refused")
	assert(String(gAcc.equipped.get("accessory_3", "?")) == "", "the duplicate never lands in accessory_3")
	assert(_count("item_equipped") == 0 and _count("toast") == 0, "duplicate-equip refusal is silent (guard idiom), no event")

	# Capacity refusal: resonance_capacity is 2; the sum so far is 0 (weapon
	# rusty_sword + both charms above all carry resonance 0). Equipping
	# test_charm_over (resonance 3) would push the total to 3 > 2 -- refused
	# via the diegetic capacity toast, DESPITE accessory_3 still being free
	# (proves capacity and slot-fullness are independent checks).
	_events.clear()
	assert(not gAcc.equip("test_charm_over"), "over-capacity equip is refused")
	assert(String(gAcc.equipped.get("accessory_3", "?")) == "", "refused equip leaves accessory_3 empty")
	assert(_count("item_equipped") == 0, "refused equip emits no item_equipped")
	assert(_count("toast") == 1 and String(_events[-1]["payload"]["text"]) == "It buzzes once against the others, like a wasp against glass, and will not settle.", "over-capacity equip emits the capacity refusal toast idiom")
	assert(gAcc.inventory.has("test_charm_over"), "the refused item is still carried (never equipped, never dropped)")

	# Fill the last accessory slot with a zero-resonance item so capacity
	# stays satisfied, then prove the slot-full refusal is a DIFFERENT toast
	# from the capacity one, even though this equip would be well within budget.
	assert(gAcc.equip("test_charm_reduc"), "equip the third (zero-resonance) accessory, filling all three slots")
	_events.clear()
	assert(not gAcc.equip("test_charm_extra"), "a 4th accessory is refused: no free slot")
	assert(_count("item_equipped") == 0, "refused equip emits no item_equipped")
	assert(_count("toast") == 1 and String(_events[-1]["payload"]["text"]) == "No room left for another charm — something has to come off first.", "slot-full equip emits the DISTINCT slot-full refusal toast, not the capacity one")

	# equipped ⊆ inventory holds across the wider (5-key) dict.
	for slot: String in gAcc.equipped:
		var eq_id := String(gAcc.equipped[slot])
		assert(eq_id == "" or gAcc.inventory.has(eq_id), "invariant holds across all 5 slots: every non-empty equipped slot is also in inventory")

	# Unequipping frees the departing item's resonance back into the budget:
	# with accessory_3 (test_charm_reduc, resonance 0) freed, the over-capacity
	# item still refuses (freeing a 0-resonance item doesn't change the sum);
	# freeing accessory_2 (test_charm_dmg, also resonance 0) then equipping
	# test_charm_over (resonance 3) still exceeds 2 alone (weapon 0 + hp 0 +
	# over 3 = 3), so free accessory_1 (test_charm_hp) too -- total then is
	# exactly 3 (just test_charm_over), still over capacity 2, confirming the
	# gate checks the RESULTING total, not just "is there room" — go one step
	# further and also unequip the weapon (frees its own 0 contribution, no
	# change) to keep the assertion honest: the fixture's over-capacity item
	# alone (resonance 3) can never fit under capacity 2, by construction.
	assert(gAcc.unequip("accessory_1") and gAcc.unequip("accessory_2") and gAcc.unequip("accessory_3"), "unequip clears all three accessory slots")
	_events.clear()
	assert(not gAcc.equip("test_charm_over"), "test_charm_over (resonance 3) alone still exceeds capacity 2 even with every slot free")
	assert(String(_events[-1]["payload"]["text"]) == "It buzzes once against the others, like a wasp against glass, and will not settle.", "same capacity refusal, now with all slots free -- proves it's a resonance gate, not a slot-count gate")

	# G1 review fix (Finding 2): swap-at-capacity SUCCEEDS -- the capacity
	# arithmetic subtracts the target slot's current occupant before adding
	# the incoming item. Build the exact-full state (ring 1 + blade 1 =
	# capacity 2), then swap the weapon for another resonance-1 weapon: the
	# subtract-then-add nets 2 <= 2 and must pass, while a resonance-3 item
	# at the same full state still refuses.
	assert(gAcc.equip("test_ring_res1"), "resonance-1 ring equips into the freed accessory slot")
	assert(gAcc.equip("test_blade_res1"), "resonance-1 weapon swap onto rusty_sword (0->1) fits: total exactly 2")
	_events.clear()
	assert(gAcc.equip("test_blade_res1b"), "swap-at-capacity succeeds: displaced resonance-1 weapon is subtracted before the incoming resonance-1 weapon is added")
	assert(String(gAcc.equipped.get(WIKeys.WEAPON, "")) == "test_blade_res1b", "the swap actually landed")
	assert(not gAcc.equip("test_charm_over"), "and a resonance-3 item at the same full state still refuses")
	# Restore the pre-swap state so the fold-through block below (which
	# re-equips all three zero-resonance charms and attributes each combat
	# field to exactly one of them) sees the same slots/mods it always did.
	assert(gAcc.unequip("accessory_1"), "swap-test cleanup: free the ring's slot")
	assert(gAcc.equip("rusty_sword"), "swap-test cleanup: swap the weapon back (resonance 1 -> 0)")

	# Combat-build fold-through: a fresh, unequipped baseline (same fixture
	# catalog, same seed/map/encounter) establishes base_max_hp, THEN
	# gAcc re-equips all three charms and starts a fight -- confirming each
	# accessory's own field rides the SAME three combatant keys weapons/armor
	# use (no new combat field): hp_mod folds into max_hp exactly like an
	# armor's hp_mod does (wi_combat.gd consumes it at build time, does not
	# keep a bare "hp_mod" key on the combatant dict -- the e4/e4b precedent
	# below asserts the same way), damage_mod/damage_reduction each
	# attributable to exactly one charm (isolated above).
	var gAccBase := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, cc_g1)
	gAccBase.transition("floodplains", Vector2i(27, 18))
	gAccBase.record_accomplishment("met_relc")
	assert(gAccBase.start_combat("goblin_encounter_2"), "baseline (no accessories) combat starts")
	var acc_base_max_hp := int(gAccBase.combat.combatants["pc"][WIKeys.MAX_HP])

	assert(gAcc.equip("test_charm_hp") and gAcc.equip("test_charm_dmg") and gAcc.equip("test_charm_reduc"), "re-equip all three (zero-resonance) accessories")
	gAcc.transition("floodplains", Vector2i(27, 18))
	gAcc.record_accomplishment("met_relc")
	assert(gAcc.start_combat("goblin_encounter_2"), "accessory-equipped combat starts")
	assert(int(gAcc.combat.combatants["pc"][WIKeys.MAX_HP]) == acc_base_max_hp + 3, "accessory hp_mod (3) folds into max_hp at build time, exactly like armor's hp_mod (weapon/armor both contribute 0 here)")
	assert(int(gAcc.combat.combatants["pc"][WIKeys.DAMAGE_MOD]) == 2, "accessory damage_mod (2) folds into the combat build (rusty_sword contributes 0)")
	assert(int(gAcc.combat.combatants["pc"][WIKeys.DAMAGE_REDUCTION]) == 4, "accessory damage_reduction (4) folds into the combat build (no armor equipped)")

	# --- Kit-intersection: weapon-family gate on the combat build ---
	# Each sub-case uses a FRESH instance fighting goblin_encounter_2 once:
	# it's a non-respawning, non-persistent encounter (removed after one
	# win), and goblin_encounter_1 is `respawns: true` (goes DORMANT after a
	# win until the next sleep re-arms it) -- reusing either across sequential
	# fights on the SAME instance would refuse the second start_combat call,
	# so every sub-case below gets its own instance instead.
	#
	# Default rusty_sword (sword family): the base warrior kit at L1 grants
	# BOTH power_strike (sword) and piercing_strikes (spear); sword-equipped
	# fields power_strike, excludes piercing_strikes.
	var e2 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	# Onboarding rev Task O1: classless start -- this sub-case's whole intent
	# is the weapon-family kit gate on a WARRIOR build, so seed it explicitly.
	e2.classes = {"warrior": 1}
	e2.transition("floodplains", Vector2i(27, 18))
	e2.record_accomplishment("met_relc")
	assert(e2.start_combat("goblin_encounter_2"), "sword-build combat starts")
	var sword_kit: Array = e2.combat.combatants["pc"][WIKeys.SKILLS]
	assert(sword_kit.has("power_strike"), "sword-equipped warrior fields the sword-tagged grant")
	assert(not sword_kit.has("piercing_strikes"), "sword-equipped warrior does NOT field the spear-tagged grant")
	assert(sword_kit.has("basic_swordwork") and sword_kit.has("tough_body"), "untagged passives always field regardless of weapon")
	assert(int(e2.combat.combatants["pc"][WIKeys.DAMAGE_MOD]) == 0, "rusty_sword's damage_mod (0) rides the combat build")
	assert(int(e2.combat.combatants["pc"][WIKeys.DAMAGE_REDUCTION]) == 0, "no armor equipped -> damage_reduction 0")

	# Spear-equipped warrior loses the sword-tagged grant, gains the spear one.
	var e2b := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	# Onboarding rev Task O1: classless start -- seed Warrior 1 explicitly (same reason as e2 above).
	e2b.classes = {"warrior": 1}
	e2b.transition("floodplains", Vector2i(27, 18))
	e2b.record_accomplishment("met_relc")
	e2b.pickup("chipped_spear", "test")
	assert(e2b.equip("chipped_spear"), "equip the spear")
	assert(e2b.start_combat("goblin_encounter_2"), "spear-build combat starts")
	var spear_kit: Array = e2b.combat.combatants["pc"][WIKeys.SKILLS]
	assert(spear_kit.has("piercing_strikes"), "spear-equipped warrior fields the spear-tagged grant")
	assert(not spear_kit.has("power_strike"), "spear-equipped warrior does NOT field the sword-tagged grant")

	# Unarmed (deliberate unequip): only untagged skills field, neither
	# weapon-tagged grant is present.
	var e2c := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	# Onboarding rev Task O1: classless start -- seed Warrior 1 explicitly (same reason as e2 above).
	e2c.classes = {"warrior": 1}
	e2c.transition("floodplains", Vector2i(27, 18))
	e2c.record_accomplishment("met_relc")
	assert(e2c.unequip("weapon"), "deliberately go unarmed")
	assert(e2c.start_combat("goblin_encounter_2"), "unarmed combat starts")
	var unarmed_kit: Array = e2c.combat.combatants["pc"][WIKeys.SKILLS]
	assert(not unarmed_kit.has("power_strike") and not unarmed_kit.has("piercing_strikes"), "unarmed fields neither weapon-tagged grant")
	assert(unarmed_kit.has("basic_swordwork") and unarmed_kit.has("tough_body"), "unarmed still fields untagged skills (base attack + untagged)")
	assert(int(e2c.combat.combatants["pc"][WIKeys.DAMAGE_MOD]) == 0, "unarmed carries no weapon damage_mod")

	# Mage spells are always fieldable regardless of the equipped weapon
	# (E1's cross-ref: no spell carries a weapon tag) -- reuses g9's earned
	# mage build (frost_bolt/quick_cast/flame_jet/mana_shield all untagged).
	var e3 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	# Onboarding rev Task O1: classless start -- this sub-case's intent is a
	# mage/warrior SPLIT build (line 859 below asserts the warrior half of the
	# kit still gates on the equipped weapon), so seed Warrior 1 explicitly;
	# the mage half is still earned for real via learned_magic_from_pisces
	# (O4: Pisces replaced the retired scroll) + sleep() below.
	e3.classes = {"warrior": 1}
	for i in 3:
		e3.record_accomplishment("won_combat")
	e3.record_accomplishment("learned_magic_from_pisces")
	e3.sleep()
	assert(e3.classes.get("mage", 0) == 2, "mage build fixture: gained + leveled")
	e3.pickup("chipped_spear", "test")
	assert(e3.equip("chipped_spear"), "equip a spear on the mage/warrior split build")
	e3.transition("street", Vector2i(4, 3))
	assert(e3.start_combat("goblin_encounter_2"), "spear-equipped mage-build combat starts")
	var mage_spear_kit: Array = e3.combat.combatants["pc"][WIKeys.SKILLS]
	assert(mage_spear_kit.has("frost_bolt") and mage_spear_kit.has("quick_cast") and mage_spear_kit.has("flame_jet") and mage_spear_kit.has("mana_shield"), "mage spells field regardless of the equipped weapon (untagged)")
	assert(mage_spear_kit.has("piercing_strikes") and not mage_spear_kit.has("power_strike"), "the warrior half of the kit still gates on the equipped weapon")

	# Armor injection: hp_mod adds to max_hp, damage_reduction rides the
	# build -- again one fresh instance per sub-case (same non-reuse reason).
	var e4 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	e4.transition("street", Vector2i(4, 3))
	assert(e4.start_combat("goblin_encounter_2"), "baseline (no armor) combat starts")
	var base_max_hp := int(e4.combat.combatants["pc"][WIKeys.MAX_HP])

	var e4b := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	e4b.transition("street", Vector2i(4, 3))
	e4b.pickup("leather_jerkin", "test")
	assert(e4b.equip("leather_jerkin"), "equip the jerkin")
	assert(e4b.start_combat("goblin_encounter_2"), "armored combat starts")
	assert(int(e4b.combat.combatants["pc"][WIKeys.MAX_HP]) == base_max_hp + 4, "leather_jerkin's hp_mod (+4) rides the combat build")
	assert(int(e4b.combat.combatants["pc"][WIKeys.HP]) == int(e4b.combat.combatants["pc"][WIKeys.MAX_HP]), "starting hp is the boosted max_hp")
	assert(int(e4b.combat.combatants["pc"][WIKeys.DAMAGE_REDUCTION]) == 0, "leather_jerkin carries no damage_reduction")

	var e4c := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	e4c.transition("street", Vector2i(4, 3))
	e4c.pickup("watch_issue_gambeson", "test")
	assert(e4c.equip("watch_issue_gambeson"), "equip the gambeson")
	assert(e4c.start_combat("goblin_encounter_2"), "damage_reduction armor combat starts")
	assert(int(e4c.combat.combatants["pc"][WIKeys.DAMAGE_REDUCTION]) == 1, "watch_issue_gambeson's damage_reduction (1) rides the combat build")
	assert(int(e4c.combat.combatants["pc"][WIKeys.MAX_HP]) == base_max_hp, "watch_issue_gambeson carries no hp_mod")

	# Weapon damage_mod injection: relcs_spare_spear (+1) rides the build.
	var e5 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	e5.pickup("relcs_spare_spear", "relc_intro")
	assert(e5.equip("relcs_spare_spear"), "equip Relc's spare spear")
	e5.transition("street", Vector2i(4, 3))
	assert(e5.start_combat("goblin_encounter_2"), "spear-with-damage-mod combat starts")
	assert(int(e5.combat.combatants["pc"][WIKeys.DAMAGE_MOD]) == 1, "relcs_spare_spear's damage_mod (+1) rides the combat build")

	# --- Dialogue effect {"item": id}: pickup with source = conversation id ---
	var item_graph := {
		"start": "n1",
		"nodes": {"n1": {"speaker": "Relc", "text": "Here, take this.", "options": [
			{"text": "Thanks.", "effects": [{"item": "relcs_spare_spear"}], "end": true},
		]}},
	}
	var cc6: Dictionary = combat_config.duplicate(true)
	cc6["dialogue"] = {"gift_conv": item_graph}
	var e6 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, cc6)
	assert(e6.start_dialogue("gift_conv", "relc"), "gift dialogue starts")
	assert(not e6.inventory.has("relcs_spare_spear"), "spare spear not carried before the gift is accepted")
	_events.clear()
	assert(e6.dialogue_choose(0), "accept the gift option")
	assert(e6.inventory.has("relcs_spare_spear"), "dialogue {\"item\": id} effect grants the item via pickup")
	assert(_count("item_gained") == 1, "item_gained emitted for the dialogue-granted item")
	var dlg_item_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "item_gained":
			dlg_item_payload = e["payload"]
	assert(dlg_item_payload.get("item", "") == "relcs_spare_spear" and dlg_item_payload.get("source", "") == "gift_conv", "dialogue item-gift's pickup source is the conversation id")

	# --- M-BEAUTY FOLD: actions_since_sleep + phase() ---
	var e7 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(e7.actions_since_sleep == 0, "fresh game starts with a zeroed action clock")
	assert(e7.phase() == "day", "fresh game starts in phase day")
	var rng_before_ticks := e7.rng.state
	# 39 successful moves (bouncing right/left so every step actually lands
	# on an open cell) keep the clock under the default dusk threshold (40).
	for i in 39:
		var dir := Vector2i.RIGHT if i % 2 == 0 else Vector2i.LEFT
		assert(e7.move_player(dir), "move %d succeeds (open cell)" % i)
	assert(e7.actions_since_sleep == 39, "39 successful moves tick the clock 39 times")
	assert(e7.phase() == "day", "39 actions stays under the dusk threshold (40)")
	_events.clear()
	assert(e7.move_player(Vector2i.RIGHT), "the 40th move crosses the dusk threshold")
	assert(e7.actions_since_sleep == 40, "clock reads 40 after the 40th action")
	assert(e7.phase() == "dusk", "40 actions crosses into dusk")
	assert(_count("phase_changed") == 1, "phase_changed emitted exactly once on the crossing")
	var dusk_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "phase_changed":
			dusk_payload = e["payload"]
	assert(dusk_payload.get("phase", "") == "dusk", "phase_changed payload carries the new phase")
	# interact() also ticks the clock unconditionally (even a "nothing here").
	_events.clear()
	e7.player_facing = Vector2i.UP
	e7.interact()
	assert(e7.actions_since_sleep == 41, "interact() ticks the clock too, regardless of outcome")
	assert(_count("phase_changed") == 0, "no further crossing yet (still dusk)")
	# Walk the clock the rest of the way to the night threshold (90).
	for i in 48:
		var dir2 := Vector2i.RIGHT if i % 2 == 0 else Vector2i.LEFT
		e7.move_player(dir2)
	assert(e7.actions_since_sleep == 89, "clock reads 89 just before the night threshold")
	assert(e7.phase() == "dusk", "89 actions stays in dusk")
	_events.clear()
	e7.move_player(Vector2i.RIGHT)
	assert(e7.actions_since_sleep == 90, "clock reads 90 at the night threshold")
	assert(e7.phase() == "night", "90 actions crosses into night")
	assert(_count("phase_changed") == 1, "phase_changed emitted exactly once on the night crossing")
	# A BLOCKED move does not tick the clock at all.
	e7.player_cell = Vector2i(0, 3)
	e7.player_facing = Vector2i.LEFT
	var stuck_count := e7.actions_since_sleep
	assert(not e7.move_player(Vector2i.LEFT), "west wall segment blocks this move")
	assert(e7.actions_since_sleep == stuck_count, "a blocked move does not tick the clock")
	# sleep() resets the clock to 0 and emits phase_changed UNCONDITIONALLY,
	# even crossing back from night to day in one step.
	_events.clear()
	e7.sleep()
	assert(e7.actions_since_sleep == 0, "sleep() resets the action clock to 0")
	assert(e7.phase() == "day", "reset clock reads phase day")
	assert(_count("phase_changed") == 1, "sleep() emits phase_changed exactly once")
	var sleep_phase_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "phase_changed":
			sleep_phase_payload = e["payload"]
	assert(sleep_phase_payload.get("phase", "") == "day", "sleep()'s phase_changed payload reads day")
	# A second sleep with the clock already at 0 (day->day, no real crossing)
	# STILL emits phase_changed -- the reset itself is the trigger.
	_events.clear()
	e7.sleep()
	assert(_count("phase_changed") == 1, "sleep() emits phase_changed even on a same-phase (day->day) reset")
	# The whole walk consumed NO rng: the sim's rng stream is untouched by
	# any of move_player/interact/sleep/phase().
	assert(e7.rng.state == rng_before_ticks, "actions_since_sleep/phase bookkeeping consumes no rng")

	# A combat turn (the PC's own turn_started) also ticks the clock, via
	# _combat_event_relay -- forced onto the PC's turn the same way
	# _land_pc_hit does elsewhere in this file (initiative order for this
	# seed doesn't guarantee "pc" goes first, so the check can't just read
	# the clock right after start_combat()).
	var e8 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(e8.actions_since_sleep == 0, "fresh game, zeroed clock")
	e8.transition("street", Vector2i(4, 3))
	assert(e8.start_combat("goblin_encounter_2"), "combat starts")
	var clock_before_pc_turn := e8.actions_since_sleep
	e8.combat.active_index = e8.combat.turn_order.find("pc")
	e8.combat._start_turn()
	assert(e8.actions_since_sleep == clock_before_pc_turn + 1, "forcing the PC's own turn_started ticks the clock exactly once, via _combat_event_relay")

	# --- M7 Task E3: victory loot roll, LOOT RNG ISOLATION (Plan-time
	# correction 3) --- Every sub-case forces a quick win the same way the
	# kit-intersection block above does (999-damage apply_damage on both
	# enemies, then resolve_combat()); goblin_encounter_1 (loot: crude_blade
	# @0.25) and goblin_encounter_2 (loot: chipped_spear @0.25) both carry
	# the two shared enemies (goblin_raider/goblin_shaman) that pattern
	# already relies on.
	#
	# Same run seed + same encounter id -> IDENTICAL drop outcome across two
	# fully independent instances (no shared state besides the seed).
	var L1a := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 777, combat_config)
	L1a.record_accomplishment("met_relc")
	L1a.transition("floodplains", Vector2i(20, 12))
	assert(L1a.start_combat("goblin_encounter_1"), "loot determinism: instance A starts encounter_1")
	L1a.combat.apply_damage("goblin_raider", 999, "pc", true)
	L1a.combat.apply_damage("goblin_shaman", 999, "pc", true)
	L1a.resolve_combat()
	var l1a_dropped := L1a.inventory.has("crude_blade")

	var L1b := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 777, combat_config)
	L1b.record_accomplishment("met_relc")
	L1b.transition("floodplains", Vector2i(20, 12))
	assert(L1b.start_combat("goblin_encounter_1"), "loot determinism: instance B starts encounter_1")
	L1b.combat.apply_damage("goblin_raider", 999, "pc", true)
	L1b.combat.apply_damage("goblin_shaman", 999, "pc", true)
	L1b.resolve_combat()
	var l1b_dropped := L1b.inventory.has("crude_blade")
	assert(l1a_dropped == l1b_dropped, "same run seed + same encounter id -> identical loot roll outcome across independent instances")

	# Different encounter ids draw from INDEPENDENT streams: fighting
	# goblin_encounter_1 first must not perturb goblin_encounter_2's own
	# deterministic roll (same run seed) relative to a standalone instance
	# that only ever fights goblin_encounter_2 -- a real proof of stream
	# isolation between encounters, not a coincidence check.
	var L2both := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 777, combat_config)
	L2both.record_accomplishment("met_relc")
	L2both.transition("floodplains", Vector2i(20, 12))
	assert(L2both.start_combat("goblin_encounter_1"), "loot independence: both-fights instance starts encounter_1")
	L2both.combat.apply_damage("goblin_raider", 999, "pc", true)
	L2both.combat.apply_damage("goblin_shaman", 999, "pc", true)
	L2both.resolve_combat()
	L2both.transition("floodplains", Vector2i(27, 18))
	assert(L2both.start_combat("goblin_encounter_2"), "loot independence: both-fights instance starts encounter_2 after encounter_1")
	L2both.combat.apply_damage("goblin_raider", 999, "pc", true)
	L2both.combat.apply_damage("goblin_shaman", 999, "pc", true)
	L2both.resolve_combat()
	var both_e2_dropped := L2both.inventory.has("chipped_spear")

	var L2solo := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 777, combat_config)
	L2solo.record_accomplishment("met_relc")
	L2solo.transition("floodplains", Vector2i(27, 18))
	assert(L2solo.start_combat("goblin_encounter_2"), "loot independence: solo instance starts encounter_2 directly")
	L2solo.combat.apply_damage("goblin_raider", 999, "pc", true)
	L2solo.combat.apply_damage("goblin_shaman", 999, "pc", true)
	L2solo.resolve_combat()
	var solo_e2_dropped := L2solo.inventory.has("chipped_spear")
	assert(both_e2_dropped == solo_e2_dropped, "encounter_2's loot roll is independent of whether encounter_1 already rolled -- different encounter ids draw from separate streams")

	# The live sim rng stream is untouched by a loot roll: rng.state right
	# after start_combat (the one legitimate draw, seeding WICombat) equals
	# rng.state right after resolve_combat (post loot roll) -- the loot roll
	# uses its OWN brand-new RandomNumberGenerator, never `self.rng`.
	var L3 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 777, combat_config)
	L3.record_accomplishment("met_relc")
	L3.transition("floodplains", Vector2i(20, 12))
	assert(L3.start_combat("goblin_encounter_1"), "loot rng isolation: instance starts combat")
	var rng_state_after_start := L3.rng.state
	L3.combat.apply_damage("goblin_raider", 999, "pc", true)
	L3.combat.apply_damage("goblin_shaman", 999, "pc", true)
	L3.resolve_combat()
	assert(L3.rng.state == rng_state_after_start, "a loot roll consumes ZERO draws from the live sim rng stream")

	# --- M7 Task E3: container props (`contains` + `container_state`) ---
	# Reach inn_chest ([1,8]): from the start cell (2,3), one step left onto
	# the open x=1 corridor (west wall is x=0 only), then four steps down
	# (bed sits at [2,7], not [1,7], so this column is clear) lands on [1,7]
	# facing down -- squarely facing the chest.
	var gC := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(not gC.inventory.has("leather_jerkin"), "inn_chest's contents not carried before opening")
	assert(gC.move_player(Vector2i.LEFT), "step onto the open x=1 corridor")
	for i in 4:
		assert(gC.move_player(Vector2i.DOWN), "corridor west of the bed is clear down to the chest")
	assert(gC.player_cell == Vector2i(1, 7), "player stands one cell north of inn_chest, facing down")
	_events.clear()
	var chest_result := gC.interact()
	assert(chest_result.get("container", "") == "inn_chest", "container interact returns its own id")
	assert((chest_result.get("items", []) as Array).has("leather_jerkin"), "container interact returns the granted item ids")
	assert(gC.inventory.has("leather_jerkin"), "opening the chest grants its contents")
	assert(_count("item_gained") == 1, "one item_gained for the chest's single item")
	assert(bool(gC.container_state.get("inn_chest", false)), "container_state marks the chest emptied")
	var chest_toast := ""
	for e: Dictionary in _events:
		if e["type"] == "toast":
			chest_toast = String(e["payload"].get("text", ""))
	assert(chest_toast == "Got: Leather Jerkin", "pickup's toast reads 'Got: <name>'")

	# Re-interact: no re-grant, an "Empty." toast, no new item_gained.
	_events.clear()
	var chest_again := gC.interact()
	assert(bool(chest_again.get("empty", false)), "re-interacting an emptied container returns the empty marker")
	assert(_count("item_gained") == 0, "re-interact grants nothing")
	assert(_count("toast") == 1, "re-interact emits exactly one toast")
	var empty_toast := ""
	for e: Dictionary in _events:
		if e["type"] == "toast":
			empty_toast = String(e["payload"].get("text", ""))
	assert(empty_toast == "Empty.", "re-interact toasts exactly 'Empty.'")

	# A container restored from a persisted `container_state` (the save/load
	# shape -- WISave round-trips this field verbatim, see save.gd) behaves
	# IDENTICALLY to a live re-interact on its very first live interact --
	# proof the interact-side logic reads `container_state` directly rather
	# than re-deriving "already opened" some other way that a load could miss.
	var gC2 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gC2.container_state["inn_chest"] = true
	gC2.move_player(Vector2i.LEFT)
	for i in 4:
		gC2.move_player(Vector2i.DOWN)
	_events.clear()
	var restored_result := gC2.interact()
	assert(bool(restored_result.get("empty", false)), "a pre-marked-emptied container_state (the post-load shape) is respected on its first LIVE interact")
	assert(not gC2.inventory.has("leather_jerkin"), "a pre-marked-emptied container grants nothing")
	assert(_count("item_gained") == 0, "a pre-marked-emptied container emits no item_gained on interact")

	# --- Onboarding rev Task O2: proximity trigger (`trigger_radius`) ---
	# `goblin_encounter_1` ships at floodplains (30,23), `trigger_radius: 2`
	# (see skeleton_scene.json's O2 comment + the task report's BFS proof for
	# why this placement makes the ambush unavoidable on the way to
	# liscor_gate). All five cases below drive the REAL `move_player`/
	# `transition` paths (not a direct `start_combat` call) since the whole
	# point under test is the move-triggered call site itself.

	# Case 1: trigger fires on entry -- one step from Chebyshev distance 3
	# (outside) to distance 2 (inside) starts the fight with no interact.
	var gT1 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gT1.transition("floodplains", Vector2i(30, 20))
	assert(gT1.combat == null, "fixture: starts outside the trigger zone (dist 3)")
	_events.clear()
	assert(gT1.move_player(Vector2i.DOWN), "step succeeds (open cell)")
	assert(gT1.player_cell == Vector2i(30, 21), "player lands at dist 2 from the encounter")
	assert(gT1.combat != null, "entering the zone starts combat with no interact call")
	assert(_count("combat_started") == 1, "one combat_started fired from the move alone")
	assert(gT1.combat.combatants.has("goblin_raider"), "the real goblin_encounter_1 roster fielded")

	# Case 2: no trigger adjacent-outside -- one step to dist 3 (still
	# outside a radius-2 zone) must NOT start combat.
	var gT2 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gT2.transition("floodplains", Vector2i(30, 19))
	assert(gT2.move_player(Vector2i.DOWN), "step succeeds (open cell)")
	assert(gT2.player_cell == Vector2i(30, 20), "player lands at dist 3 -- adjacent-outside the zone")
	assert(gT2.combat == null, "adjacent-outside the radius does not trigger")

	# Case 3: dormant respawner does not trigger. Force the encounter
	# already-dormant (as if just beaten), then walk into the zone -- no
	# fight, matching start_combat's own dormant refusal (interact-parity).
	var gT3 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gT3.dormant_encounters.append("goblin_encounter_1")
	gT3.transition("floodplains", Vector2i(30, 20))
	gT3.move_player(Vector2i.DOWN)  # (30,21), dist 2
	_events.clear()
	assert(gT3.move_player(Vector2i.DOWN), "step succeeds (open cell)")
	assert(gT3.player_cell == Vector2i(30, 22), "player lands at dist 1, deep inside the zone")
	assert(gT3.combat == null, "a dormant encounter's zone does not trigger a fight")
	assert(_count("combat_started") == 0, "no combat_started while dormant")

	# Case 4: re-armed after sleep CAN trigger again -- the repeatable-
	# skirmish valve now has teeth: walking past a re-armed ambush re-fights
	# it. Continue gT3 past its sleep beat -- gT3 is still standing at dist 1
	# (30,22) from case 3's no-trigger move, so the very next successful
	# move (still inside the radius-2 zone) fires the now-live encounter.
	gT3.sleep()
	assert(gT3.dormant_encounters.is_empty(), "sleep re-arms the respawner")
	_events.clear()
	assert(gT3.move_player(Vector2i.RIGHT), "step succeeds (open cell)")
	assert(gT3.player_cell == Vector2i(31, 22), "player lands at dist 1, still inside the zone")
	assert(gT3.combat != null, "re-armed encounter fights again on re-entry")
	assert(_count("combat_started") == 1, "one fresh combat_started on the re-trigger")

	# Case 5: teleport does not trigger. A fresh (non-dormant) instance
	# landed INSIDE the zone via `transition` (the same sim call QA's
	# `teleport` step uses, see qa/test_driver.gd) must NOT start combat --
	# only `move_player` calls `_check_trigger_radius`.
	var gT4 := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	_events.clear()
	gT4.transition("floodplains", Vector2i(30, 22))  # dist 1, well inside the zone
	assert(gT4.combat == null, "transition (teleport/door/load-restore) never triggers the ambush")
	assert(_count("combat_started") == 0, "no combat_started from a bare transition")

	# --- Skills Wave Task K2: the sneak seam (stealth state) ---
	# The PROVISIONAL [Stealth] skill is QA-fixture-only (no shipped class grants
	# it -- K1's frost_touch/kindle disclosure precedent), so every case below
	# grants it directly via player_skills, exactly like those two.

	# Toggle: keyed on the `sneaks: true` DATA TAG, NOT this skill's id (plan
	# decision) -- prove it with a SYNTHETIC skill carrying the tag under a
	# DIFFERENT id, so a tag-vs-id regression (accidentally keying on
	# `skill_id == "sneak"`) would fail this even though the shipped skill
	# would still pass.
	var tag_skills_raw: Dictionary = _load_json("res://data/skills.json")
	var tagged_skill_list: Array = (tag_skills_raw[WIKeys.SKILLS] as Array).duplicate(true)
	tagged_skill_list.append({WIKeys.ID: "stealth_ritual", WIKeys.DISPLAY_NAME: "[Stealth Ritual]", WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true, "sneaks": true})
	var gTagK2 := WIGame.new(_load_json("res://data/skeleton_scene.json"), {WIKeys.SKILLS: tagged_skill_list}, _sink, 12345, combat_config)
	gTagK2.player_skills.append("stealth_ritual")
	assert(not gTagK2.sneaking, "fixture: not sneaking at start")
	_events.clear()
	gTagK2.use_skill_field("stealth_ritual")
	assert(gTagK2.sneaking, "a DIFFERENT skill id carrying sneaks:true still toggles sneaking on (tag-keyed, not id-keyed)")
	assert(_count("sneak_started") == 1, "sneak_started fires on a tag toggle")
	assert(_toast_texts() == ["You soften your step."], "the on-toast fires exactly once, tag-toggle case")
	_events.clear()
	gTagK2.use_skill_field("stealth_ritual")
	assert(not gTagK2.sneaking, "the SAME tagged skill toggles back off")
	assert(_count("sneak_ended") == 1, "sneak_ended fires on the off-toggle")
	assert(_toast_texts() == ["You straighten up."], "the off-toast fires exactly once")

	# Toggle via the REAL shipped [Stealth] skill: on/off, skill_used + journal
	# reveal, sneaking reflected in snapshot().
	var gSneak := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gSneak.player_skills.append("sneak")
	_events.clear()
	var sneak_on := gSneak.use_skill_field("sneak")
	assert(sneak_on.get("sneaking", false) == true, "use_skill_field returns the new sneaking state")
	assert(gSneak.sneaking, "sneaking flips true")
	assert(gSneak.snapshot()["sneaking"] == true, "snapshot carries sneaking")
	assert(gSneak.used_skills.has("sneak"), "sneak is marked used (journal reveal)")
	assert(_count("skill_used") == 1, "the toggle emits exactly one skill_used")

	# --- Trigger-skip while sneaking (the whole point): walk the REAL
	# goblin_encounter_1 zone sneaking -> no combat_started at all; then
	# straighten up and re-enter -> the positive control fires. Mirrors the O2
	# block above exactly, sneaking added.
	gSneak.transition("floodplains", Vector2i(30, 20))
	_events.clear()
	assert(gSneak.move_player(Vector2i.DOWN), "step to dist 2 succeeds")
	assert(gSneak.combat == null, "sneaking skips the trigger entirely at dist 2")
	assert(gSneak.move_player(Vector2i.DOWN), "step to dist 1 succeeds")
	assert(gSneak.combat == null, "sneaking skips the trigger entirely at dist 1 too")
	assert(_count("combat_started") == 0, "no combat_started anywhere in the sneaking approach")
	# The positive control, same instance, same standing cell (still dist 1,
	# deep inside the zone): straighten up (re-press the same toggle) -- the
	# VERY NEXT move (still inside the radius) fires the ambush for real, since
	# _check_trigger_radius no longer skips. Proves the skip is `sneaking`
	# itself, not merely "already inside the zone once".
	gSneak.use_skill_field("sneak")
	assert(not gSneak.sneaking, "the re-press straightens up")
	_events.clear()
	assert(gSneak.move_player(Vector2i.RIGHT), "step succeeds (open cell), still dist 1")
	assert(gSneak.combat != null, "NOT sneaking: the same zone now fires the ambush for real")
	assert(_count("combat_started") == 1, "one combat_started on the not-sneaking step")

	# --- Break conditions ---
	# 1. interact() reaching a real prop response breaks it (dirty_table,
	# the same requires_skill/on_skill_use prop the P1 byte-parity test below
	# uses) -- BEFORE the prop's own emits (off-toast reads first).
	var gBreakProp := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gBreakProp.player_skills.append("sneak")
	gBreakProp.use_skill_field("sneak")
	assert(gBreakProp.sneaking, "fixture: sneaking before the interact")
	gBreakProp.player_cell = Vector2i(6, 4)
	gBreakProp.player_facing = Vector2i.LEFT  # faces dirty_table at (5,4)
	_events.clear()
	gBreakProp.interact()
	assert(not gBreakProp.sneaking, "interact() reaching a prop response breaks sneaking")
	assert(_toast_texts()[0] == "You straighten up.", "the off-toast is emitted BEFORE the prop's own toast")
	assert(_count("sneak_ended") == 1, "sneak_ended fires from the interact break")

	# 2. A door does NOT break it ("crossing a door quietly is the point") --
	# inn_door (inn [15,3]) is a real `door` entity.
	var gBreakDoor := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gBreakDoor.player_skills.append("sneak")
	gBreakDoor.use_skill_field("sneak")
	gBreakDoor.player_cell = Vector2i(14, 3)
	gBreakDoor.player_facing = Vector2i.RIGHT  # faces inn_door at (15,3)
	_events.clear()
	gBreakDoor.interact()
	assert(gBreakDoor.sneaking, "a door transition KEEPS sneaking")
	assert(_count("sneak_ended") == 0, "no sneak_ended from a door crossing")
	assert(gBreakDoor.current_map == "floodplains", "fixture: the door actually transitioned")

	# 3. interact() with NOTHING faced does not break it either (no response
	# reached at all -- distinct from the door case, which IS a response).
	var gBreakNothing := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gBreakNothing.player_skills.append("sneak")
	gBreakNothing.use_skill_field("sneak")
	gBreakNothing.player_cell = Vector2i(2, 3)
	gBreakNothing.player_facing = Vector2i.DOWN  # open floor, nothing faced
	gBreakNothing.interact()
	assert(gBreakNothing.sneaking, "interact() reaching nothing does not break sneaking")

	# 4. A successful field-skill use ON A TARGET breaks it (basic_cleaning on
	# dirty_table); the SAME skill's field_ambient no-op (no qualifying faced
	# entity) does NOT ("a whiffed flourish isn't a commitment").
	var gBreakFieldTarget := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gBreakFieldTarget.player_skills.append("sneak")
	gBreakFieldTarget.use_skill_field("sneak")
	gBreakFieldTarget.player_cell = Vector2i(6, 4)
	gBreakFieldTarget.player_facing = Vector2i.LEFT  # faces dirty_table
	gBreakFieldTarget.use_skill_field("basic_cleaning")
	assert(not gBreakFieldTarget.sneaking, "a field-skill use that resolves on a real target breaks sneaking")

	var gBreakAmbient := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gBreakAmbient.player_skills.append("sneak")
	gBreakAmbient.use_skill_field("sneak")
	gBreakAmbient.player_cell = Vector2i(2, 3)
	gBreakAmbient.player_facing = Vector2i.DOWN  # open floor, no entity faced
	gBreakAmbient.use_skill_field("basic_cleaning")  # falls through to field_ambient
	assert(gBreakAmbient.sneaking, "a field_ambient no-op flourish does NOT break sneaking")

	# 5. start_combat firing for ANY cause breaks it -- prove at the
	# start_combat call site directly (a dialogue-effect start_combat is the
	# other real caller besides interact()'s encounter branch, already
	# covered above by the trigger-radius block's own combat_started proof).
	# A REFUSED start_combat (dormant encounter) must NOT break it.
	var gBreakCombat := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gBreakCombat.player_skills.append("sneak")
	gBreakCombat.record_accomplishment("met_relc")
	# goblin_encounter_2 lives on floodplains (W1 relocation, see the combat-
	# handoff fixture above) -- find_entity/start_combat are map-agnostic, but
	# transition anyway to match that fixture's own convention.
	gBreakCombat.transition("floodplains", Vector2i(27, 18))
	gBreakCombat.use_skill_field("sneak")
	gBreakCombat.dormant_encounters.append("goblin_encounter_2")
	assert(not gBreakCombat.start_combat("goblin_encounter_2"), "fixture: the dormant encounter refuses to start")
	assert(gBreakCombat.sneaking, "a REFUSED start_combat does not break sneaking")
	gBreakCombat.dormant_encounters.clear()
	assert(gBreakCombat.start_combat("goblin_encounter_2"), "a real start_combat succeeds once un-dormant")
	assert(not gBreakCombat.sneaking, "start_combat succeeding breaks sneaking for ANY cause")

	# --- NOT SAVED (round-trip honesty; the dedicated test_save.gd assertion
	# is the canonical proof -- this is the sim-level companion): sleep also
	# clears it silently, "with everything else". ---
	var gSleepClear := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gSleepClear.player_skills.append("sneak")
	gSleepClear.use_skill_field("sneak")
	assert(gSleepClear.sneaking, "fixture: sneaking before sleep")
	_events.clear()
	gSleepClear.sleep()
	assert(not gSleepClear.sneaking, "sleep clears sneaking")
	assert(_count("sneak_ended") == 0, "sleep's clear is silent -- no sneak_ended (matches light_active/frozen_cells)")

	# --- Three Pillars P1: use_skill_field (overworld field-skill dispatch) ---
	# The core promise: pressing a field skill while FACING a qualifying prop
	# emits a BYTE-IDENTICAL event stream to today's interact-with-requires_skill
	# on that same prop. Prove it by event-for-event comparison on the inn's
	# dirty_table (requires_skill=basic_cleaning, innate) from [6,4] facing LEFT.
	var scene_p1 := _load_json("res://data/skeleton_scene.json")
	var skills_p1 := _load_json("res://data/skills.json")

	var g_interact := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_interact.player_cell = Vector2i(6, 4)
	g_interact.player_facing = Vector2i.LEFT  # faces dirty_table at [5,4]
	_events.clear()
	g_interact.interact()
	var interact_events := _events.duplicate(true)

	var g_field := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_field.player_cell = Vector2i(6, 4)
	g_field.player_facing = Vector2i.LEFT
	_events.clear()
	var fx := g_field.use_skill_field("basic_cleaning")
	var field_events := _events.duplicate(true)
	assert(fx.get("accomplishment", "") == "cleaned_the_inn", "field use of a faced prop returns the prop's effect")
	assert(interact_events == field_events, "faced-prop field use is byte-same events as interact-with-requires_skill")
	assert(g_field.accomplishment_count("cleaned_the_inn") == 1, "faced-prop field use fires the SAME accomplishment as interact")
	assert(g_field.used_skills.has("basic_cleaning"), "faced-prop field use records used_skills (journal reveal)")

	# Ambient fallback: same skill, NO qualifying faced entity -> the skill's
	# field_ambient flavor toast (marks used, no accomplishment, no prop).
	var g_amb := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_amb.player_cell = Vector2i(2, 3)
	g_amb.player_facing = Vector2i.DOWN  # open cell, no entity faced
	assert(g_amb.entity_at(g_amb.player_cell + g_amb.player_facing).is_empty(), "faced cell is empty for the ambient case")
	_events.clear()
	var amb := g_amb.use_skill_field("basic_cleaning")
	assert(amb.get("ambient", "") == "basic_cleaning", "no faced prop -> ambient result")
	assert(_count("skill_used") == 1, "ambient still emits skill_used")
	assert(_count("toast") == 1, "ambient emits its flavor toast")
	assert(_count("accomplishment_recorded") == 0, "ambient banks no accomplishment")
	assert(g_amb.used_skills.has("basic_cleaning"), "ambient use reveals the skill in the journal")

	# --- Playtest feature 3: [Light] ambient cast sets the light_active glow flag ---
	# The ambient (no-qualifying-prop) cast of [Light] flips light_active true so
	# the presentation can conjure a PC-following glow; sleep() clears it (the orb
	# winks out on rest). basic_cleaning's ambient cast must NOT touch the flag.
	var g_glow := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_glow.player_skills.append("light")
	assert(g_glow.known_skills().has("light"), "light is known for the glow case")
	g_glow.player_cell = Vector2i(2, 3)
	g_glow.player_facing = Vector2i.DOWN  # proven-empty faced cell (the ambient case above)
	assert(not g_glow.light_active, "light_active defaults false")
	_events.clear()
	var glow_res := g_glow.use_skill_field("light")
	assert(glow_res.get("ambient", "") == "light", "ambient [Light] cast returns {ambient:light}")
	assert(g_glow.light_active, "ambient [Light] cast flips light_active true")
	assert(_count("ui_pc_light_rendered") == 0, "the SIM emits no ui_pc_light_rendered (that is the presentation's confirmation)")
	# Re-cast while lit: still true (idempotent), the ambient stream fires again.
	g_glow.use_skill_field("light")
	assert(g_glow.light_active, "re-casting [Light] while lit leaves light_active true")
	# A non-light ambient cast never sets the flag.
	var g_noglow := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_noglow.player_cell = Vector2i(2, 3)
	g_noglow.player_facing = Vector2i.DOWN
	g_noglow.use_skill_field("basic_cleaning")
	assert(not g_noglow.light_active, "a non-[Light] ambient cast leaves light_active false")
	# sleep() clears the glow (winks out on rest).
	g_glow.sleep()
	assert(not g_glow.light_active, "sleep() clears light_active (the orb winks out)")

	# Unknown-to-PC skill: refusal path preserved (SKILL_UNKNOWN + generic toast).
	_events.clear()
	var unk := g_amb.use_skill_field("frost_bolt")  # not known by a classless PC
	assert(unk.is_empty(), "unknown field skill returns empty")
	assert(_count("skill_unknown") == 1, "unknown field skill emits skill_unknown")
	assert(_count("toast") == 1, "unknown field skill toasts the generic refusal")
	assert(_count("skill_used") == 0, "unknown field skill does nothing")

	# Non-field skill known to the PC is refused in the field (no overworld verb).
	var g_nf := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_nf.player_skills.append("power_strike")  # combat skill, no `field` tag
	assert(g_nf.known_skills().has("power_strike"), "power_strike is known for this case")
	_events.clear()
	var nf := g_nf.use_skill_field("power_strike")
	assert(nf.is_empty(), "non-field skill is refused in the field")
	assert(_count("skill_no_effect") == 1, "non-field field-use emits skill_no_effect")
	assert(_count("toast") == 1, "non-field field-use toasts a refusal")
	assert(_count("skill_used") == 0, "non-field field-use fires nothing")

	# Field-tagged skill with NO field_ambient authored -> the established
	# refusal toast (no target, no ambient). Inject a synthetic field skill.
	var g_na := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_na.skills["synthetic_field"] = {WIKeys.ID: "synthetic_field", WIKeys.DISPLAY_NAME: "[Synthetic]", WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true}
	g_na.player_skills.append("synthetic_field")
	g_na.player_cell = Vector2i(2, 3)
	g_na.player_facing = Vector2i.DOWN
	_events.clear()
	var na := g_na.use_skill_field("synthetic_field")
	assert(na.is_empty(), "field skill with no ambient and no target is refused")
	assert(_count("skill_no_effect") == 1, "no-ambient field-use emits skill_no_effect")
	assert(_count("toast") == 1, "no-ambient field-use toasts the established refusal")
	assert(_count("skill_used") == 0, "no-ambient field-use fires nothing")

	# --- Three Pillars P3: [Appraise Foe] field skill (faced-entity flavor + observed_things) ---
	# [Appraise Foe] reads a faced entity's `observe` flavor string (a DIFFERENT field
	# than the requires_skill/on_skill_use seam above) and banks observed_things
	# (opaque; feeds [Tactician]'s levels). Flavor only -- never numbers/stats.
	var g_obs := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_obs.player_skills.append("observe")
	assert(g_obs.known_skills().has("observe"), "observe is known for this case")
	# Faced entity carrying an `observe` string -> that exact string as the toast.
	g_obs.player_cell = Vector2i(7, 3)
	g_obs.player_facing = Vector2i.UP  # faces erin at [7,2]
	_events.clear()
	var ob := g_obs.use_skill_field("observe")
	assert(ob.get("observed", "") == "erin", "observe on a faced entity returns {observed:id}")
	assert(_count("skill_used") == 1, "observe emits skill_used")
	assert(g_obs.accomplishment_count("observed_things") == 1, "observe banks observed_things +1 (opaque tactician feed)")
	assert(g_obs.used_skills.has("observe"), "observe reveals itself in the journal on first use")
	var ob_toast: Dictionary = _events[_events.size() - 1]
	assert(ob_toast["type"] == "toast" and String(ob_toast["payload"]["text"]).begins_with("A young human"), "observe emits the entity's own observe string as the toast")

	# Faced entity that carries NO `observe` string -> the generic fallback,
	# still an observation (banks observed_things again).
	g_obs.player_cell = Vector2i(6, 4)
	g_obs.player_facing = Vector2i.LEFT  # faces the dirty_table prop (no `observe` string)
	_events.clear()
	var ob2 := g_obs.use_skill_field("observe")
	assert(not ob2.is_empty() and ob2.has("observed"), "observe on an unlabelled entity still resolves")
	var ob2_toast: Dictionary = _events[_events.size() - 1]
	assert(ob2_toast["payload"]["text"] == "You watch. Details surface.", "generic observe fallback string")
	assert(g_obs.accomplishment_count("observed_things") == 2, "generic-fallback observe still banks observed_things")

	# Empty faced cell -> observe's own field_ambient flavor, banks NOTHING.
	g_obs.player_cell = Vector2i(2, 3)
	g_obs.player_facing = Vector2i.DOWN
	assert(g_obs.entity_at(g_obs.player_cell + g_obs.player_facing).is_empty(), "faced cell empty for observe ambient")
	_events.clear()
	var oba := g_obs.use_skill_field("observe")
	assert(oba.get("ambient", "") == "observe", "empty-cell observe -> ambient result")
	assert(_count("accomplishment_recorded") == 0, "empty-cell observe banks no accomplishment")
	assert(g_obs.accomplishment_count("observed_things") == 2, "observed_things unchanged by an ambient (empty-cell) observe")

	# --- Social Pillar S1: rotating talk pools + per-waking social dedup ---
	# Synthetic scene: one NPC carrying BOTH a talk_pool (3 rotating lines) and
	# a real conversation graph, so we can prove (a) the pool line plays on the
	# first talk of a waking, (b) a SECOND talk this waking falls through to the
	# real conversation EXACTLY, (c) sleep() re-arms the pool, (d) the line index
	# rotates deterministically (chatted_with_<id> % pool_size) incl. wraparound.
	var social_scene := {
		"start_map": "plaza",
		"player": {WIKeys.CELL: [1, 1], "classes": {}, WIKeys.SKILLS: ["observe"]},
		"maps": {"plaza": {
			"grid": {"width": 6, "height": 6},
			"blocked": [],
			"entities": [
				{WIKeys.ID: "gossip_npc", WIKeys.KIND: "npc", WIKeys.CELL: [2, 1], WIKeys.DISPLAY_NAME: "Krshia",
				 "talk_pool": ["Gossip one.", "Gossip two.", "Gossip three."],
				 WIKeys.CONVERSATION: "krshia_convo",
				 "observe": "She weighs you like a sack of produce.",
				 "friendly_line": "Hrr. For you, a fair price - and I mean it."},
			],
		}},
	}
	# Full combat_config (classes/combatants/arenas/items) + the test dialogue,
	# so sleep()'s progression machinery has the config it reads when non-empty.
	var social_cc: Dictionary = combat_config.duplicate(true)
	social_cc["dialogue"] = {"krshia_convo": {
		"start": "n1",
		"nodes": {"n1": {"speaker": "Krshia", "text": "Real conversation.", "options": [{"text": "Bye.", "end": true}]}},
	}}
	var gS := WIGame.new(social_scene, skill_config, _sink, 7, social_cc)
	# Player at (1,1) faces RIGHT by default -> faces gossip_npc at (2,1).
	assert(gS.player_facing == Vector2i.RIGHT and gS.entity_at(Vector2i(2, 1)).get(WIKeys.ID, "") == "gossip_npc", "fixture: player faces the gossip NPC")

	# First talk of the waking: pool line index 0, banks both counters, sets flag.
	_events.clear()
	var t0 := gS.interact()
	assert(t0.get("talked", "") == "gossip_npc" and int(t0.get("index", -1)) == 0, "first talk plays pool line index 0")
	assert(gS.dialogue == null, "the pool line does NOT open the real conversation")
	assert(_count("dialogue_line") == 1 and _count("dialogue_started") == 0, "pool line rides the plain DIALOGUE_LINE surface (gate_guard idiom), not a graph")
	var pool_line0: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "dialogue_line":
			pool_line0 = e["payload"]
	assert(pool_line0.get("speaker", "") == "Krshia" and pool_line0.get("text", "") == "Gossip one.", "pool line carries {speaker=display_name, text=pool[0]}")
	assert(gS.accomplishment_count("chatted_with_gossip_npc") == 1, "first talk banks chatted_with_<id>")
	assert(gS.accomplishment_count("heard_gossip") == 1, "first talk banks heard_gossip")
	assert(bool(gS.social_talked.get("gossip_npc", false)), "first talk sets the social_talked flag")

	# Second talk THIS waking: falls through to the real conversation EXACTLY.
	_events.clear()
	var t1 := gS.interact()
	assert(t1.get("dialogue", false) == true, "second talk this waking starts the real conversation")
	assert(gS.dialogue != null and _count("dialogue_started") == 1, "the flagged path is today's exact conversation behavior")
	assert(_count("dialogue_line") == 0, "no pool line on the fallthrough talk")
	assert(gS.accomplishment_count("chatted_with_gossip_npc") == 1, "fallthrough talk does not re-bank the counter")
	assert(gS.dialogue_choose(0), "close the real conversation")
	assert(gS.dialogue == null, "conversation closed")

	# sleep() re-arms the pool; the NEXT talk plays index 1 (counter is now 1).
	gS.sleep()
	assert(not bool(gS.social_talked.get("gossip_npc", false)), "sleep clears social_talked (re-arms the pool)")
	_events.clear()
	var t2 := gS.interact()
	assert(int(t2.get("index", -1)) == 1, "next waking rotates to pool line index 1")
	var pool_line1 := ""
	for e: Dictionary in _events:
		if e["type"] == "dialogue_line":
			pool_line1 = String(e["payload"]["text"])
	assert(pool_line1 == "Gossip two.", "index 1 is the second pool line")
	assert(gS.accomplishment_count("chatted_with_gossip_npc") == 2, "second waking's talk banks the counter to 2")

	# Rotate through index 2, then WRAP back to index 0 (counter 3 % 3 == 0).
	gS.sleep()
	var t3 := gS.interact()
	assert(int(t3.get("index", -1)) == 2, "third waking rotates to pool line index 2")
	gS.sleep()
	_events.clear()
	var t4 := gS.interact()
	assert(int(t4.get("index", -1)) == 0, "fourth waking WRAPS the rotation back to index 0 (3 %% 3)")
	var pool_line_wrap := ""
	for e: Dictionary in _events:
		if e["type"] == "dialogue_line":
			pool_line_wrap = String(e["payload"]["text"])
	assert(pool_line_wrap == "Gossip one.", "wraparound replays the first pool line")

	# An NPC with NO talk_pool is byte-unchanged: the plain gate_guard dialogue
	# line still fires exactly as today (proves the talk_pool gate is opt-in).
	var plain_scene := {
		"start_map": "plaza",
		"player": {WIKeys.CELL: [1, 1], "classes": {}, WIKeys.SKILLS: []},
		"maps": {"plaza": {
			"grid": {"width": 6, "height": 6}, "blocked": [],
			"entities": [{WIKeys.ID: "guard", WIKeys.KIND: "npc", WIKeys.CELL: [2, 1], WIKeys.DISPLAY_NAME: "Guard",
				"dialogue": [{"speaker": "Guard", "text": "Move along."}]}],
		}},
	}
	var gPlain := WIGame.new(plain_scene, skill_config, _sink, 7)
	_events.clear()
	var pl := gPlain.interact()
	assert(pl.get("speaker", "") == "Guard" and pl.get("text", "") == "Move along.", "a no-talk_pool NPC returns its plain dialogue line unchanged")
	assert(_count("dialogue_line") == 1, "plain NPC still emits exactly one dialogue_line")
	assert(gPlain.accomplishment_count("heard_gossip") == 0, "a no-talk_pool NPC banks no social counters")

	# Observe dedup (resolves the TP-review Observe-farm): observing the SAME
	# entity twice in one waking banks observed_things ONCE; sleep re-arms it.
	var gObs := WIGame.new(social_scene, skill_config, _sink, 7, social_cc)
	assert(gObs.known_skills().has("observe"), "observe is known for the dedup case")
	# Faces gossip_npc at (2,1).
	_events.clear()
	var ob_a := gObs.use_skill_field("observe")
	assert(ob_a.get("observed", "") == "gossip_npc", "first observe resolves on the faced entity")
	assert(gObs.accomplishment_count("observed_things") == 1, "first observe banks observed_things")
	assert(_count("skill_used") == 1, "first observe emits skill_used")
	# Second observe of the SAME entity this waking: line + skill_used still fire,
	# but the counter is NOT re-banked.
	_events.clear()
	var ob_b := gObs.use_skill_field("observe")
	assert(ob_b.get("observed", "") == "gossip_npc", "repeat observe still resolves (flavor + reveal fire)")
	assert(_count("skill_used") == 1, "repeat observe still emits skill_used (only the bank is deduped)")
	assert(_count("toast") == 1, "repeat observe still shows the flavor toast")
	assert(gObs.accomplishment_count("observed_things") == 1, "repeat observe of the same entity banks NOTHING (farm resolved)")
	assert(_count("accomplishment_recorded") == 0, "no accomplishment_recorded on the deduped repeat observe")
	# sleep() re-arms the first-use dict: observing again next waking banks again.
	gObs.sleep()
	assert(gObs.entity_first_use.is_empty(), "sleep clears entity_first_use (re-arms first-use banks)")
	var ob_c := gObs.use_skill_field("observe")
	assert(ob_c.get("observed", "") == "gossip_npc", "post-sleep observe resolves again")
	assert(gObs.accomplishment_count("observed_things") == 2, "post-sleep observe of the same entity banks again (re-armed)")

	# --- Social Pillar S3: [Charming Smile] field skill (friendly_line + befriended_moments dedup) ---
	# Mirrors the [Appraise Foe] seam: reads a faced entity's friendly_line, banks
	# befriended_moments once per entity per waking through the SHARED dedup dict
	# under the DISTINCT verb "friendly", and falls through to field_ambient on an
	# empty cell. The dedup key is independent of observe's, so charm and observe
	# on the SAME entity in the SAME waking each bank exactly once (composite key).
	var gCharm := WIGame.new(social_scene, skill_config, _sink, 7, social_cc)
	gCharm.player_skills.append("charming_smile")
	assert(gCharm.known_skills().has("charming_smile"), "charming_smile is known for this case")
	# Faces gossip_npc at (2,1) which carries a friendly_line.
	_events.clear()
	var ch_a := gCharm.use_skill_field("charming_smile")
	assert(ch_a.get("befriended", "") == "gossip_npc", "charm on a faced entity returns {befriended:id}")
	assert(gCharm.accomplishment_count("befriended_moments") == 1, "first charm banks befriended_moments +1 (opaque diplomat feed)")
	assert(_count("skill_used") == 1, "charm emits skill_used")
	assert(gCharm.used_skills.has("charming_smile"), "charm reveals itself in the journal on first use")
	var ch_toast: Dictionary = _events[_events.size() - 1]
	assert(ch_toast["type"] == "toast" and ch_toast["payload"]["text"] == "Hrr. For you, a fair price - and I mean it.", "charm emits the entity's own friendly_line as the toast")
	# Repeat charm of the SAME entity this waking: line + skill_used fire, no re-bank.
	_events.clear()
	var ch_b := gCharm.use_skill_field("charming_smile")
	assert(ch_b.get("befriended", "") == "gossip_npc", "repeat charm still resolves (flavor + reveal fire)")
	assert(_count("skill_used") == 1, "repeat charm still emits skill_used (only the bank is deduped)")
	assert(_count("toast") == 1, "repeat charm still shows the friendly toast")
	assert(gCharm.accomplishment_count("befriended_moments") == 1, "repeat charm of the same entity banks NOTHING (farm resolved, mirrors observe)")
	# observe on the same entity this waking banks INDEPENDENTLY (distinct verb key).
	gCharm.player_skills.append("observe")
	var ch_ob := gCharm.use_skill_field("observe")
	assert(ch_ob.get("observed", "") == "gossip_npc", "observe on the already-charmed entity resolves")
	assert(gCharm.accomplishment_count("observed_things") == 1, "observe banks independently of charm on the SAME entity (composite dedup key)")
	assert(gCharm.accomplishment_count("befriended_moments") == 1, "the independent observe did NOT touch befriended_moments")
	# sleep() re-arms the friendly bank via the shared entity_first_use clear.
	gCharm.sleep()
	assert(gCharm.entity_first_use.is_empty(), "sleep clears the shared first-use dict (re-arms the friendly bank too)")
	var ch_c := gCharm.use_skill_field("charming_smile")
	assert(ch_c.get("befriended", "") == "gossip_npc", "post-sleep charm resolves again")
	assert(gCharm.accomplishment_count("befriended_moments") == 2, "post-sleep charm of the same entity banks again (re-armed)")
	# Faced entity with NO friendly_line -> the generic fallback line, still banks.
	var charm_scene2: Dictionary = social_scene.duplicate(true)
	(charm_scene2["maps"]["plaza"]["entities"] as Array)[0].erase("friendly_line")
	var gCharm2 := WIGame.new(charm_scene2, skill_config, _sink, 7, social_cc)
	gCharm2.player_skills.append("charming_smile")
	_events.clear()
	var ch2 := gCharm2.use_skill_field("charming_smile")
	assert(not ch2.is_empty() and ch2.has("befriended"), "charm on a friendly_line-less entity still resolves")
	var ch2_toast: Dictionary = _events[_events.size() - 1]
	assert(String(ch2_toast["payload"]["text"]).begins_with("You offer a warm"), "generic friendly fallback string")
	assert(gCharm2.accomplishment_count("befriended_moments") == 1, "generic-fallback charm still banks befriended_moments")
	# Empty faced cell -> charm's own field_ambient flavor, banks NOTHING.
	gCharm2.player_cell = Vector2i(4, 4)
	gCharm2.player_facing = Vector2i.DOWN
	assert(gCharm2.entity_at(gCharm2.player_cell + gCharm2.player_facing).is_empty(), "faced cell empty for charm ambient")
	_events.clear()
	var chamb := gCharm2.use_skill_field("charming_smile")
	assert(chamb.get("ambient", "") == "charming_smile", "empty-cell charm -> ambient result")
	assert(_count("accomplishment_recorded") == 0, "empty-cell charm banks no accomplishment")

	# Save round-trip of the two new per-waking dicts (the sim-core half of the
	# S1 save contract; test_save.gd owns the tolerant-default/migration cases).
	var gSaveA := WIGame.new(social_scene, skill_config, _sink, 7, social_cc)
	gSaveA.interact()  # bank a talk-pool line -> populates social_talked + counters
	gSaveA.use_skill_field("observe")  # populate entity_first_use
	assert(bool(gSaveA.social_talked.get("gossip_npc", false)), "round-trip fixture: social_talked populated")
	assert(not gSaveA.entity_first_use.is_empty(), "round-trip fixture: entity_first_use populated")
	var s1_data := WISave.serialize(gSaveA)
	var gSaveB := WIGame.new(social_scene, skill_config, _sink, 7, social_cc)
	assert(WISave.apply(gSaveB, s1_data), "S1 save applies")
	assert(gSaveB.social_talked == gSaveA.social_talked, "social_talked round-trips")
	assert(gSaveB.entity_first_use == gSaveA.entity_first_use, "entity_first_use round-trips")

	# --- Content Wave C1: the grate-gate seam (door_when on a prop) ---
	# Pre-quest (gate UNMET) the street sewer_grate interact must be
	# byte-identical to a plain on_interact_accomplishment prop; once the gate
	# accomplishment is banked it transitions to the sewers instead.
	var gGrate := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gGrate.transition("street", Vector2i(15, 11))
	gGrate.player_facing = Vector2i.RIGHT  # faces the sewer_grate at (16,11)
	assert(gGrate.entity_at(Vector2i(16, 11)).get(WIKeys.ID, "") == "sewer_grate", "grate is at (16,11) facing cell")
	# Gate UNMET: falls through to on_interact_accomplishment -> byte-identical.
	_events.clear()
	var pre := gGrate.interact()
	assert(pre.get("accomplishment", "") == "heard_the_sewers", "unmet grate banks heard_the_sewers (unchanged pre-quest behavior)")
	assert(gGrate.current_map == "street", "unmet grate does NOT transition")
	assert(_count("map_changed") == 0, "unmet grate emits no map_changed")
	assert(_count("toast") == 1 and String(_events[-1]["payload"].get("text", "")).begins_with("A heavy iron grate"), "unmet grate fires the exact pre-quest toast")
	assert(gGrate.accomplishment_count("heard_the_sewers") == 1, "heard_the_sewers banked once")
	# Bank the gate accomplishment (C3 will bank this from Olesm). Re-facing the
	# grate and interacting now descends to the sewers.
	gGrate.record_accomplishment("heard_about_cisterns")
	gGrate.player_cell = Vector2i(15, 11)
	gGrate.player_facing = Vector2i.RIGHT
	_events.clear()
	var opened := gGrate.interact()
	assert(opened.get("map", "") == "sewers", "met grate transitions to sewers")
	assert(gGrate.current_map == "sewers", "now on the sewers map")
	assert(gGrate.player_cell == Vector2i(2, 2), "descends to the sewers landing (2,2)")
	assert(_count("map_changed") == 1, "met grate emits map_changed")
	assert(gGrate.accomplishment_count("heard_the_sewers") == 1, "met grate does NOT re-bank heard_the_sewers")
	# The sewers map loaded its own entities (nest + exit).
	assert(gGrate.entities.has("shield_spiders") and gGrate.entities.has("sewer_exit"), "sewers entities bound")
	# The sewer_exit ladder returns to the street beside the grate.
	gGrate.player_cell = Vector2i(2, 2)
	gGrate.player_facing = Vector2i.UP
	gGrate.interact()
	assert(gGrate.current_map == "street" and gGrate.player_cell == Vector2i(15, 11), "ladder returns to the street grate")

	# --- Economy v1 Task D1: gold seam (earn/spend/refusal + loot-gold) ---
	var gGold := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(gGold.gold == 0, "fresh purse starts at 0")
	# earn round-trip: purse grows, gold_changed {delta,total,source} + toast.
	_events.clear()
	gGold.earn_gold(5, "test_chore")
	assert(gGold.gold == 5, "earn_gold adds to the purse")
	assert(String(_events[0]["type"]) == "gold_changed" and int(_events[0]["payload"]["delta"]) == 5 and int(_events[0]["payload"]["total"]) == 5 and String(_events[0]["payload"]["source"]) == "test_chore", "earn emits gold_changed {delta,total,source}")
	assert(_count("toast") == 1 and String(_events[-1]["payload"]["text"]) == "Earned 5 gold.", "earn emits the diegetic toast")
	# spend within budget round-trips (signed delta).
	_events.clear()
	assert(gGold.spend_gold(3, "krshia_shop"), "spend within budget succeeds")
	assert(gGold.gold == 2, "spend deducts from the purse")
	assert(String(_events[0]["type"]) == "gold_changed" and int(_events[0]["payload"]["delta"]) == -3 and int(_events[0]["payload"]["total"]) == 2 and String(_events[0]["payload"]["source"]) == "krshia_shop", "spend emits signed gold_changed with the sink as source")
	assert(String(_events[-1]["payload"]["text"]) == "Paid 3 gold.", "spend emits the diegetic toast")
	# spend refusal at insufficient gold: no debt, refusal toast, no gold_changed.
	_events.clear()
	assert(not gGold.spend_gold(99, "krshia_shop"), "spend refuses when short (no debt)")
	assert(gGold.gold == 2, "refused spend leaves the purse untouched")
	assert(_count("gold_changed") == 0, "refused spend emits no gold_changed")
	assert(_count("toast") == 1 and String(_events[-1]["payload"]["text"]) == "Not enough gold.", "refused spend emits the refusal toast idiom")
	# non-positive earn/spend are silent no-ops (no event, no mutation).
	_events.clear()
	gGold.earn_gold(0, "x")
	assert(not gGold.spend_gold(0, "x"), "zero spend refuses")
	assert(gGold.gold == 2 and _events.is_empty(), "non-positive gold ops are silent no-ops")

	# loot-gold determinism per run_seed (SYNTHETIC entity -- no data file gains
	# gold in D1). Same run seed + encounter id -> identical coin roll across two
	# fully independent instances, off the ISOLATED per-encounter loot_rng.
	var loot_entity := {WIKeys.ID: "econ_test_encounter", "loot": [{"gold": 7, "chance": 0.5}, {"gold": 3, "chance": 0.5}]}
	var GldA := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 4242, combat_config)
	GldA._roll_loot(loot_entity)
	var GldB := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 4242, combat_config)
	GldB._roll_loot(loot_entity)
	assert(GldA.gold == GldB.gold, "same run_seed + encounter id -> identical loot-gold roll across independent instances")
	# A guaranteed coin drop (chance 1.0) routes through earn_gold: loot_dropped
	# {gold} matches the earned total, one gold_changed, no items key.
	var sure_loot := {WIKeys.ID: "econ_sure_encounter", "loot": [{"gold": 7, "chance": 1.0}]}
	var GldC := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 4242, combat_config)
	_events.clear()
	GldC._roll_loot(sure_loot)
	assert(GldC.gold == 7, "guaranteed coin drop earns exactly the listed gold")
	assert(_count("loot_dropped") == 1, "coin drop emits one loot_dropped")
	assert(_count("gold_changed") == 1, "loot-gold routes through earn_gold (one gold_changed)")
	var econ_ld: Dictionary = {}
	for e: Dictionary in _events:
		if String(e["type"]) == "loot_dropped":
			econ_ld = e["payload"]
	assert(int(econ_ld.get("gold", 0)) == 7, "loot_dropped carries {gold}")
	assert(not econ_ld.has("items"), "pure-coin loot payload omits the items key (item-only stream stays byte-identical)")

	# --- Skills Wave Task K2b: hotbar loadout (AUTO parity + apply_loadout + toggle) ---
	var gLoad := WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gLoad.classes = {"warrior": 1, "tactician": 1, "helper": 1}
	assert(gLoad.hotbar_loadout.is_empty(), "fresh game starts in AUTO mode (empty loadout)")
	# AUTO-default byte-parity: field_hotbar_loadout() must equal the manual
	# known_skills()-filtered-by-field derivation, in the SAME order -- this
	# derive-both-ways-and-compare IS the parity proof the plan requires.
	var manual_field: Array = []
	for raw: Variant in gLoad.known_skills():
		var id := String(raw)
		if bool((gLoad.skills.get(id, {}) as Dictionary).get("field", false)):
			manual_field.append(id)
	assert(gLoad.field_hotbar_loadout() == manual_field, "AUTO field_hotbar_loadout() matches the manual known_skills()-filtered-by-field derivation exactly (byte-parity proof)")
	assert(gLoad.field_hotbar_loadout() == ["basic_cleaning", "basic_cooking", "observe"], "AUTO field order: innate first, then catalog-order class grants (warrior contributes no field skills; helper's basic_cooking, then tactician's observe)")

	# apply_loadout: the pure static filter -- AUTO passthrough, reorder-by-
	# loadout-order, and the silent-drop-of-an-unresolvable-id proof (the
	# "invalid ids filtered on read" contract, e.g. a K3-renamed skill).
	assert(WIGame.apply_loadout(["a", "b", "c"], []) == ["a", "b", "c"], "empty loadout is a pure passthrough (AUTO)")
	assert(WIGame.apply_loadout(["a", "b", "c"], ["c", "a"]) == ["c", "a"], "non-empty loadout reorders to LOADOUT order and drops unlisted candidates")
	assert(WIGame.apply_loadout(["a", "b"], ["nonexistent_skill", "b"]) == ["b"], "a loadout id absent from candidates (unknown/renamed) is silently dropped, never an error")

	# loadout_toggle: assign appends to the end (v1-minimal reorder), emits
	# LOADOUT_CHANGED {skill, assigned, loadout}; unassign erases (not
	# re-appends) and emits assigned:false.
	_events.clear()
	gLoad.loadout_toggle("observe")
	assert(gLoad.hotbar_loadout == ["observe"], "toggle on an unslotted skill assigns it (appends)")
	assert(_count("loadout_changed") == 1, "assign emits exactly one loadout_changed")
	assert(bool(_events[-1]["payload"]["assigned"]) == true and String(_events[-1]["payload"]["skill"]) == "observe" and (_events[-1]["payload"]["loadout"] as Array) == ["observe"], "loadout_changed payload carries {skill, assigned, loadout} exactly")
	# Non-empty loadout now filters the field bar down to the intersection, in
	# LOADOUT order -- observe was AUTO slot 3, now the ONLY slot (the
	# "remapped slot" the plan's QA note calls out).
	assert(gLoad.field_hotbar_loadout() == ["observe"], "a non-empty loadout intersects+reorders the field bar (basic_cleaning/basic_cooking drop out, unslotted this walk)")
	gLoad.loadout_toggle("basic_cleaning")
	assert(gLoad.hotbar_loadout == ["observe", "basic_cleaning"], "a second assign appends after the first (v1-minimal reorder: assignment order IS the order)")
	assert(gLoad.field_hotbar_loadout() == ["observe", "basic_cleaning"], "field bar order follows LOADOUT order, not known_skills() order")
	_events.clear()
	gLoad.loadout_toggle("observe")
	assert(gLoad.hotbar_loadout == ["basic_cleaning"], "toggling an already-slotted skill unassigns it (erase, not re-append)")
	assert(bool(_events[-1]["payload"]["assigned"]) == false, "unassign emits loadout_changed with assigned:false")
	gLoad.loadout_toggle("basic_cleaning")
	assert(gLoad.hotbar_loadout.is_empty(), "unassigning the last entry returns to AUTO (empty loadout)")
	assert(gLoad.field_hotbar_loadout() == manual_field, "back to AUTO once the loadout empties out again -- exact parity with the original derivation")

	# Invalid-id filter (a save carrying a renamed/removed skill id): the write
	# side doesn't gate on known-ness (loadout_toggle has no such guard -- see
	# its own doc comment), but the READ side (field_hotbar_loadout/
	# apply_loadout) silently drops it -- never a phantom slot, never a crash.
	gLoad.loadout_toggle("not_a_real_skill_id")
	assert(gLoad.hotbar_loadout.has("not_a_real_skill_id"), "loadout_toggle doesn't gate on known-ness at write time")
	assert(not gLoad.field_hotbar_loadout().has("not_a_real_skill_id"), "an unknown id in the loadout is silently filtered out at READ time")
	gLoad.loadout_toggle("not_a_real_skill_id")
	assert(gLoad.hotbar_loadout.is_empty(), "cleanup: unassigned back to AUTO")

	print("PASS: sim core behaves correctly")
	quit(0)
