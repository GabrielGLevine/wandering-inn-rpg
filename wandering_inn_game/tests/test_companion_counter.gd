extends SceneTree
## #474 THE COMPANION COUNTER, unit-pinned.
##
## The mechanic is two halves that are each inert alone: `bonded: true` on a
## combatant row (a ROLE -- this body is here because a bond, a taming or a
## raising put it here) and `target_rule: "bonded"` on a Skill. `data_lint`'s
## `check_companion_counter` proves the two halves are WIRED in shipped data;
## this proves the ENGINE honours them, which is a different question and fails
## in a different way.
##
## WHY IT NEEDS A GATE AT ALL. Both failure modes are silent. A `target_rule`
## the resolver ignored would turn a companion-answering Skill into a 2.0x strike
## on the PC at three shipped encounters, and nothing would red -- it would read
## as an unexplained difficulty spike in a sim table. A `target_rule` the AI
## never spent would leave the counter unfired, and nothing would red either --
## it would read as an unexplained ceiling in the same table. So both directions
## are asserted here: it MUST land on a bonded body, and it MUST refuse a body
## that is not one.
##
## FAILURE DISCIPLINE, the house shape: collected into `_failures` and reported
## through `quit(1)` BEFORE any assert, because a failed `assert` aborts the
## enclosing function and a `--script` SceneTree with no quit requested then
## idles to the watchdog at rc 142 instead of failing now.

const COUNTER := "sunder_the_bond"
## The three apex bodies the lane authored it onto -- the boss of each fight a
## bonded companion was measured to trivialise. Pinned by NAME so a silent
## removal from any of the three reds here rather than surfacing as a table cell
## that moved for no recorded reason.
const CARRIERS := ["seal_warden", "raskghar_awakened", "shield_spider_matriarch"]
## Every row that reaches the field through a bond, a taming or a raising.
## `data_lint` derives this set from map `companion_source` rows and requires the
## flag; this list is the mirror, so the two disagree loudly if one is edited.
const BONDED_ROWS := ["wolf_companion", "razorbeak_companion", "skeleton_ally"]

var _events: Array = []
var _failures: Array = []


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _arena() -> Dictionary:
	for a: Dictionary in _load("res://data/arenas.json")["arenas"]:
		if String(a[WIKeys.ID]) == "vault":
			return a
	_failures.append("no vault arena")
	return {}


func _catalog() -> Dictionary:
	var by_id := {}
	for c: Dictionary in _load("res://data/combatants.json")["combatants"]:
		by_id[String(c[WIKeys.ID])] = c
	return by_id


## The warden and whoever else the caller names, on the shipped arena, with the
## shipped rows -- never a hand-built stand-in, so a data change reaches here.
func _fight(roster: Array, seed_v: int) -> WICombat:
	var by_id := _catalog()
	var cfgs: Array = []
	for want: Variant in roster:
		cfgs.append((by_id[String(want)] as Dictionary).duplicate(true))
	var combat := WICombat.new(_arena(), cfgs, _load("res://data/skills.json"), _sink, seed_v)
	combat.begin()
	return combat


func _activate(combat: WICombat, id: String) -> void:
	combat.active_index = combat.turn_order.find(id)
	combat._start_turn()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


## Put the two bodies in contact. The counter is weapon-shaped (a `damage_mult`),
## so `resolve_active` clips it on `in_weapon_range`, and a probe that left them
## apart would "prove" a refusal that was only ever a distance.
func _place_adjacent(combat: WICombat, a_id: String, b_id: String) -> void:
	var anchor: Vector2i = combat.combatants[a_id][WIKeys.CELL]
	combat.combatants[b_id][WIKeys.CELL] = anchor + Vector2i.RIGHT


func _skill_targets(skill_id: String) -> Array:
	var out: Array = []
	for e: Dictionary in _events:
		if String(e["type"]) != WIEvents.SKILL_RESOLVED:
			continue
		if String((e["payload"] as Dictionary).get("skill", "")) == skill_id:
			out.append(String((e["payload"] as Dictionary).get("target", "")))
	return out


func _init() -> void:
	WITestWatchdog.arm(self)
	var skills := _load("res://data/skills.json")
	var counter := {}
	for s: Dictionary in skills[WIKeys.SKILLS]:
		if String(s[WIKeys.ID]) == COUNTER:
			counter = s
	_check(not counter.is_empty(), "skills.json has no %s" % COUNTER)
	_check(String(counter.get(WIKeys.TARGET_RULE, "")) == "bonded",
		("%s must carry target_rule 'bonded'; the counter's whole safety property is that it "
		+ "refuses a body that is not a companion") % COUNTER)

	var by_id := _catalog()
	for row_id: String in BONDED_ROWS:
		_check(bool((by_id.get(row_id, {}) as Dictionary).get(WIKeys.BONDED, false)),
			("combatants.json: %s must carry `bonded: true` -- it reaches the field as a companion, "
			+ "so every counter authored against the role must be able to answer it") % row_id)
	for carrier: String in CARRIERS:
		var carrier_kit: Array = (by_id.get(carrier, {}) as Dictionary).get(WIKeys.SKILLS, [])
		_check(carrier_kit.has(COUNTER),
			("combatants.json: %s no longer carries %s -- the per-spine table's companion cells "
			+ "move with this and nothing else would say why") % [carrier, COUNTER])

	# --- 1. THE ROLE SURVIVES THE ROSTER. `_build_combatant` has to carry the
	# flag off the cfg or every check below is asking a dictionary that forgot.
	var combat := _fight(["pc", "wolf_companion", "seal_warden"], 5)
	_check(bool(combat.combatants["wolf_companion"][WIKeys.BONDED]),
		"the bonded role did not survive _build_combatant")
	_check(not bool(combat.combatants["pc"][WIKeys.BONDED]),
		"the PC must not read as bonded -- the counter would then be spendable on the player")

	# --- 2. IT LANDS ON THE COMPANION. Same fight, warden made active, wolf in
	# reach: the resolver must accept and the wolf must lose HP.
	_place_adjacent(combat, "seal_warden", "wolf_companion")
	_activate(combat, "seal_warden")
	var wolf_before := int(combat.combatants["wolf_companion"][WIKeys.HP])
	var landed := combat.use_skill(COUNTER, "wolf_companion")
	_check(landed, "%s refused a bonded body in weapon reach" % COUNTER)
	_check(int(combat.combatants["wolf_companion"][WIKeys.HP]) < wolf_before,
		"%s resolved without moving the companion's HP" % COUNTER)

	# --- 3. IT REFUSES THE PC. A fresh fight (the cooldown from arm 2 would
	# refuse for the WRONG reason and pass this by accident), warden adjacent to
	# the PC, no companion on the board at all.
	_events.clear()
	var solo := _fight(["pc", "seal_warden"], 5)
	_place_adjacent(solo, "seal_warden", "pc")
	_activate(solo, "seal_warden")
	_check(solo.cooldown_remaining("seal_warden", COUNTER) == 0,
		"probe setup is wrong: the counter must be OFF cooldown for the refusal to mean anything")
	var pc_before := int(solo.combatants["pc"][WIKeys.HP])
	var refused := solo.use_skill(COUNTER, "pc")
	_check(not refused, "%s was spendable on the PC -- target_rule is not being read" % COUNTER)
	_check(int(solo.combatants["pc"][WIKeys.HP]) == pc_before,
		"%s damaged the PC despite refusing" % COUNTER)

	# --- 4. THE AI SPENDS IT, and spends it on the companion. This is the half
	# `data_lint` cannot see: a counter the shipped AI never reaches for is a
	# ceiling in the sim table with no explanation attached.
	_events.clear()
	var driven := _fight(["pc", "wolf_companion", "seal_warden"], 7)
	_place_adjacent(driven, "seal_warden", "wolf_companion")
	_activate(driven, "seal_warden")
	WICombatAI.take_turn(driven)
	var targets := _skill_targets(COUNTER)
	_check(not targets.is_empty(),
		"the shipped AI never spent %s with a bonded body in reach" % COUNTER)
	for t: String in targets:
		_check(t == "wolf_companion",
			"the AI spent %s on %s, which is not the bonded body" % [COUNTER, t])

	# --- 5. A COMPANIONLESS FIGHT IS UNTOUCHED. The counter's licence to sit on
	# a SHARED encounter row rests entirely on this: a build with no companion
	# must fight the identical fight it fought before the counter existed.
	_events.clear()
	var untouched := _fight(["pc", "seal_warden"], 7)
	_place_adjacent(untouched, "seal_warden", "pc")
	_activate(untouched, "seal_warden")
	WICombatAI.take_turn(untouched)
	_check(_skill_targets(COUNTER).is_empty(),
		"%s fired in a fight with no bonded body on the board" % COUNTER)

	if not _failures.is_empty():
		for line: String in _failures:
			printerr("FAIL %s" % line)
		quit(1)
		assert(false, "companion counter contract broken -- see FAIL lines above")
		return
	print("PASS: companion counter -- role carried, lands on the bonded body, refuses the PC, "
		+ "spent by the shipped AI, and inert in a companionless fight")
	quit(0)
