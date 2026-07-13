extends SceneTree
## Validates combat data shapes and cross-references.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_combat_data.gd


## GH#94 (no-new-art icon drain): a field:true/ap_cost>0 skill with no icon
## falls back to WIHotbar's overflowing raw-bracket text label (the only 3
## icon consumers -- field_hotbar.gd/hotbar.gd/combat_hud.gd -- are all
## player-hotbar surfaces). Class-foundation R1-R5 shipped 18+ more iconless
## skills past #94's own "19/50" baseline (docs/VISUAL-LOG.md's SKILL ICONS
## entry) -- too large to close in one no-new-art pass, so this is a DRIFT
## TRIPWIRE, not a completeness assert: KNOWN_ICONLESS_SKILLS pins today's
## exact disclosed debt (every enemy-exclusive id here -- guarding_ward/
## raskghar_maul/slam -- is never actually rendered, since nothing but a
## player's own hotbar ever reads an icon, but still tracked so the set
## stays literally true). Checked BOTH directions (test_effect_text.gd's
## EXPECTED_* idiom): a hotbar-visible skill OUTSIDE this set with no icon
## fails LOUD (a silent new gap); an id INSIDE this set that has since
## gained an icon also fails LOUD (shrink the allowlist, never let it rot).
const KNOWN_ICONLESS_SKILLS := {
	"appraise_goods": true,
	"called_shot": true,
	"directed_strike": true,
	"disarm_trap": true,
	"find_trap": true,
	"flame_dart": true,
	"flame_pillar": true,
	"guarding_ward": true,
	"measured_words": true,
	"open_doors": true,
	"perfect_hospitality": true,
	"piercing_volley": true,
	"raskghar_maul": true,
	"slam": true,
	"soothing_presence": true,
}


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON: " + path)
	return parsed


## BFS flood-fill from `start` over non-blocked, in-bounds cells. Returns the
## set of reachable cells (as a Dictionary used like a Set) — pure, 4-directional,
## deterministic (no rng), used to prove every arena spawn can path to every
## other spawn (the sim's BFS-based approach AI depends on this holding).
func _reachable_from(start: Vector2i, w: int, h: int, blocked: Dictionary) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for dir: Vector2i in dirs:
			var next: Vector2i = cur + dir
			if next.x < 0 or next.y < 0 or next.x >= w or next.y >= h:
				continue
			if blocked.has(next) or seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return seen


func _init() -> void:
	WITestWatchdog.arm(self)
	var skills := _load("res://data/skills.json")
	var combatants := _load("res://data/combatants.json")
	var classes := _load("res://data/classes.json")
	var arenas := _load("res://data/arenas.json")
	var scene := WISceneCatalog.compose()

	var skill_ids := {}
	var iconless_seen := {}
	for s: Dictionary in skills[WIKeys.SKILLS]:
		var sid := String(s[WIKeys.ID])
		skill_ids[sid] = true
		assert(s.has(WIKeys.CONTEXTS) and s.has(WIKeys.DISPLAY_NAME), "skill missing fields: " + sid)
		if (s[WIKeys.CONTEXTS] as Array).has("combat"):
			assert(s.has(WIKeys.AP_COST) and s.has(WIKeys.EFFECT), "combat skill missing ap_cost/effect: " + sid)
		var hotbar_visible := bool(s.get(WIKeys.FIELD, false)) or float(s.get(WIKeys.AP_COST, 0)) > 0.0
		if hotbar_visible and not s.has("icon"):
			iconless_seen[sid] = true
			assert(KNOWN_ICONLESS_SKILLS.has(sid), "skill %s is hotbar-visible (field/ap_cost) but ships with no icon -- add icon_%s or track it in KNOWN_ICONLESS_SKILLS" % [sid, sid])
	for known_sid: String in KNOWN_ICONLESS_SKILLS:
		assert(iconless_seen.has(known_sid), "KNOWN_ICONLESS_SKILLS lists %s but it now carries an icon -- shrink the allowlist" % known_sid)

	var combatant_ids := {}
	for c: Dictionary in combatants["combatants"]:
		combatant_ids[String(c[WIKeys.ID])] = true
		for key: String in ["id", "display_name", "side", "stats", "weapon_die", "ai", "skills"]:
			assert(c.has(key), "combatant %s missing %s" % [c.get(WIKeys.ID, "?"), key])
		for stat: String in ["str", "dex", "con", "int", "wis", "cha"]:
			assert(c[WIKeys.STATS].has(stat), "combatant %s missing stat %s" % [c[WIKeys.ID], stat])
		for sk: Variant in c[WIKeys.SKILLS]:
			assert(skill_ids.has(String(sk)), "combatant %s references unknown skill %s" % [c[WIKeys.ID], sk])

	for cls: Dictionary in classes["classes"]:
		# GH#54 sparse-table convention: evolution-only classes start at a
		# derived floor, not 1 -- this file only asserts contiguity from the
		# FIRST entry; the floor itself (and no-sub-floor padding) is
		# test_content.gd's _validate_class_level_tables, which derives it
		# from the evolution/consolidation data. TRAP: these two validators
		# overlap -- the old contiguous-from-1 assert here went CI-red the
		# moment #54's trim landed (the lane verified test_content, the
		# sweep never runs unit suites). Change one, grep for the other.
		var prev_level := -1
		for lv: Dictionary in cls["levels"]:
			assert(prev_level == -1 or int(lv["level"]) == prev_level + 1, "class %s levels must be contiguous (gap before %d)" % [String(cls.get("id", "?")), int(lv["level"])])
			prev_level = int(lv["level"])
			for sk: Variant in lv["grants"]:
				assert(skill_ids.has(String(sk)), "class grant references unknown skill %s" % sk)

	var arena_ids := {}
	for a: Dictionary in arenas["arenas"]:
		var id := String(a[WIKeys.ID])
		arena_ids[id] = true
		var w := int(a["grid"]["width"])
		var h := int(a["grid"]["height"])
		assert(w == 12 and h == 8, "M1 arenas are 12x8")
		for cell: Array in (a["blocked"] as Array) + (a["player_spawns"] as Array) + (a["enemy_spawns"] as Array):
			assert(int(cell[0]) >= 0 and int(cell[0]) < w and int(cell[1]) >= 0 and int(cell[1]) < h, "cell out of bounds")
		assert((a["player_spawns"] as Array).size() >= 4, "need 4 player spawns (design-for-4)")

		# Spawn reachability: every player/enemy spawn cell must sit on the
		# same connected component of non-blocked cells, since combat_ai's
		# BFS approach logic assumes a spawn can always path toward any foe.
		var blocked := {}
		for cell: Array in a["blocked"]:
			blocked[Vector2i(int(cell[0]), int(cell[1]))] = true
		var all_spawns: Array = (a["player_spawns"] as Array) + (a["enemy_spawns"] as Array)
		assert(not all_spawns.is_empty(), "arena %s has no spawns" % id)
		var first: Vector2i = Vector2i(int(all_spawns[0][0]), int(all_spawns[0][1]))
		assert(not blocked.has(first), "arena %s spawn %s is itself blocked" % [id, first])
		var reachable := _reachable_from(first, w, h, blocked)
		for spawn: Array in all_spawns:
			var cell := Vector2i(int(spawn[0]), int(spawn[1]))
			assert(not blocked.has(cell), "arena %s spawn %s is itself blocked" % [id, cell])
			assert(reachable.has(cell), "arena %s spawn %s is unreachable from spawn %s" % [id, cell, first])

	for map_id: String in (scene["maps"] as Dictionary):
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in (map.get("entities", []) as Array):
			if String(entity.get(WIKeys.KIND, "")) != "encounter":
				continue
			var eid := String(entity[WIKeys.ID])
			for key: String in ["arena", "enemies", "allies", "on_victory"]:
				assert(entity.has(key), "encounter %s missing %s" % [eid, key])
			assert(arena_ids.has(String(entity["arena"])), "encounter %s references unknown arena %s" % [eid, entity["arena"]])
			for enemy_id: Variant in entity["enemies"]:
				assert(combatant_ids.has(String(enemy_id)), "encounter %s references unknown enemy %s" % [eid, enemy_id])
			for ally_id: Variant in entity["allies"]:
				assert(combatant_ids.has(String(ally_id)), "encounter %s references unknown ally %s" % [eid, ally_id])

	_check_boss_veto_roster(scene, skills, combatants, classes, arenas)

	print("PASS: combat data is well-formed and cross-referenced")


## The party-veto's ROSTER proof at unit level -- the
## dedicated canonical script was cut; the 0.04 solo cell (sim_combat_batch.gd
## BOSS_CELLS) already documents the difficulty, so all that remains to prove is
## the WIRING: declining fields NO ally. Builds a real WIGame twice against the
## `awakened_boss` encounter (find_entity searches all maps, so no player
## position is needed) and checks the live combat roster: DECLINE (went_alone
## banked, relc_joined_descent NOT) -> ally_requires unmet -> no Relc; JOIN
## (relc_joined_descent banked) -> Relc fielded. This exercises the SAME generic
## ally_requires gate start_combat runs for every allied encounter, bound to the
## A3-specific keys the relc_descent dialogue banks.
func _check_boss_veto_roster(scene: Dictionary, skills: Dictionary, combatants: Dictionary, classes: Dictionary, arenas: Dictionary) -> void:
	var sink := func(_t: String, _p: Dictionary) -> void: pass
	var cfg := {
		"combatants": combatants, "classes": classes, "arenas": arenas,
		"items": _load("res://data/items.json"), "quests": _load("res://data/quests.json"),
		"acts": _load("res://data/acts.json"), "dialogue": {},
	}
	# DECLINE / solo: went_alone banked, relc_joined_descent absent.
	var g_solo := WIGame.new(scene, skills, sink, 1, cfg)
	g_solo.record_accomplishment("went_alone")
	assert(g_solo.start_combat("awakened_boss"), "solo start_combat(awakened_boss) failed")
	var solo: Dictionary = g_solo.combat.snapshot()["combatants"]
	assert(solo.has("pc") and solo.has("raskghar_awakened"), "solo roster missing pc/boss")
	assert(not solo.has("relc"), "VETO path must field NO ally, but Relc is in the roster")
	# JOIN: relc_joined_descent banked -> Relc fielded (ally_requires met).
	var g_join := WIGame.new(scene, skills, sink, 1, cfg)
	g_join.record_accomplishment("relc_joined_descent")
	assert(g_join.start_combat("awakened_boss"), "join start_combat(awakened_boss) failed")
	var join: Dictionary = g_join.combat.snapshot()["combatants"]
	assert(join.has("relc"), "JOIN path must field Relc as an ally, but he is absent")
	quit(0)
