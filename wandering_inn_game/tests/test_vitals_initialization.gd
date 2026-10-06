extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	var skills := {"skills": [{"id": "bolt", "mp_cost": 2}]}
	var arena := {"id": "resources", "grid": {"width": 3, "height": 3}, "player_spawns": [[0, 0], [1, 0]], "enemy_spawns": [[2, 2]]}
	var pc := {"id": "pc", "display_name": "PC", "side": "player", "stats": {"str": 10, "dex": 10, "con": 10, "int": 10}, "weapon_die": 4, "skills": ["bolt"], "initial_hp": 3, "initial_mp": 0}
	var enemy: Dictionary = pc.duplicate(true)
	enemy["id"] = "enemy"
	enemy["side"] = "enemy"
	var ally: Dictionary = pc.duplicate(true)
	ally["id"] = "ally"
	var fight := WICombat.new(arena, [pc, ally, enemy], skills, Callable(), 1)
	assert(int(fight.combatants["pc"]["hp"]) == 3, "explicit PC depletion survives construction")
	assert(int(fight.combatants["pc"]["mp"]) == 0, "zero MP survives construction")
	assert(int(fight.combatants["enemy"]["hp"]) == 30, "enemy stays encounter-local")
	assert(int(fight.combatants["enemy"]["mp"]) == 13, "enemy stays fully rested")
	assert(int(fight.combatants["ally"]["hp"]) == 30 and int(fight.combatants["ally"]["mp"]) == 13, "companion stays encounter-local")
	pc["initial_hp"] = 100
	pc["initial_mp"] = 100
	var capped := WICombat.new(arena, [pc], skills, Callable(), 1)
	assert(int(capped.combatants["pc"]["hp"]) == 30 and int(capped.combatants["pc"]["mp"]) == 13, "explicit inputs clamp to derived maxima")
	pc.erase("initial_hp")
	pc.erase("initial_mp")
	var rested := WICombat.new(arena, [pc], skills, Callable(), 1)
	assert(rested.combatants["pc"]["hp"] == capped.combatants["pc"]["hp"], "standalone default starts rested")
	pc["skills"] = ["bolt", "fortitude", "stance"]
	skills["skills"].append({"id": "fortitude", "effect": {"type": "hp_bonus", "amount": 10}})
	skills["skills"].append({"id": "stance", "family": "tactic", "effect": {"type": "hit_bonus", "amount": 3}})
	var passive_fight := WICombat.new(arena, [pc], skills, Callable(), 1)
	assert(int(passive_fight.combatants["pc"]["max_hp"]) == 40, "passive HP is added exactly once")
	assert(int(passive_fight.combatants["pc"]["hit_bonus"]) == 3, "unrelated hit passive remains active")
	assert(passive_fight.used_skills_tally["pc"].has("stance"), "tactic passive still banks actual use")
	print("PASS test_vitals_initialization")
	quit(0)
