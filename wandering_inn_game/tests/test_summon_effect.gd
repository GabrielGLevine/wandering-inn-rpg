extends SceneTree
## #460 THE SUMMON EFFECT, unit-pinned. Every clause of the mechanic contract
## (spec sec.1) that a sim can decide on its own: deterministic placement,
## next-round turn entry, zero rng, cooldown, `fight_limit`, the capacity
## refusal, and the anti-farming guarantee that a raised body adds no banking
## surface.
##
## WHY A FILE OF ITS OWN rather than more tail on `test_combat_sim.gd`: this is
## the first effect that grows `combatants` and `turn_order` after `_init`, so
## its assertions need a roster and a turn cursor the shared `_make` helper does
## not field, and every one of them wants the summoner active on demand.
##
## FAILURE DISCIPLINE: collected into `_failures` and reported through `quit(1)`
## BEFORE any assert, because a failed `assert` aborts the enclosing function
## and a `--script` SceneTree with no quit requested then idles until the
## watchdog -- the exact dishonest-green shape `sim_spine_viability.gd` documents.

const LICH := "crypt_lich"
const THRALL := "bone_thrall"
const RAISE := "raise_bones"
## THE AUTHORED NUMBERS, pinned once. Everything below derives from `_limit()` so
## a retune moves the logic assertions with the data, but a retune that moves
## these two reds HERE -- both are balance-measured (skills.json's own comment
## carries the readings), so a silent edit must not slip through green.
const AUTHORED_FIGHT_LIMIT := 2
const AUTHORED_COOLDOWN := 1

var _events: Array = []
var _failures: Array = []


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _arena(id: String) -> Dictionary:
	for a: Dictionary in _load("res://data/arenas.json")["arenas"]:
		if String(a[WIKeys.ID]) == id:
			return a
	_failures.append("no arena %s" % id)
	return {}


func _catalog() -> Dictionary:
	var by_id := {}
	for c: Dictionary in _load("res://data/combatants.json")["combatants"]:
		by_id[String(c[WIKeys.ID])] = c
	return by_id


## A fight with the summon roster injected the way `wi_game.start_combat` injects
## it -- never a hand-built stand-in, so a wiring change there shows up here.
func _fight(roster: Array, seed_v: int) -> WICombat:
	var by_id := _catalog()
	var cfgs: Array = []
	for want: Variant in roster:
		cfgs.append((by_id[String(want)] as Dictionary).duplicate(true))
	var combat := WICombat.new(_arena("ruin_court"), cfgs, _load("res://data/skills.json"), _sink, seed_v)
	combat.summon_catalog = by_id
	combat.begin()
	return combat


func _activate(combat: WICombat, id: String) -> void:
	combat.active_index = combat.turn_order.find(id)
	combat._start_turn()


func _events_of(type: String) -> Array:
	var out: Array = []
	for e: Dictionary in _events:
		if String(e["type"]) == type:
			out.append(e["payload"])
	return out


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _enemy_ids(combat: WICombat) -> Array:
	var out: Array = []
	for id: String in combat.combatants:
		if String(combat.combatants[id][WIKeys.SIDE]) == "enemy":
			out.append(id)
	out.sort()
	return out


func _limit() -> int:
	for sk: Dictionary in _load("res://data/skills.json")[WIKeys.SKILLS]:
		if String(sk[WIKeys.ID]) == RAISE:
			return int((sk[WIKeys.EFFECT] as Dictionary)["fight_limit"])
	_failures.append("skills.json has no %s" % RAISE)
	return 0


func _cooldown() -> int:
	for sk: Dictionary in _load("res://data/skills.json")[WIKeys.SKILLS]:
		if String(sk[WIKeys.ID]) == RAISE:
			return int(sk["cooldown_rounds"])
	return 0


func _init() -> void:
	WITestWatchdog.arm(self)
	_check(_limit() == AUTHORED_FIGHT_LIMIT, "fight_limit is authored %d, data says %d -- balance-measured, see skills.json" % [AUTHORED_FIGHT_LIMIT, _limit()])
	_check(_cooldown() == AUTHORED_COOLDOWN, "cooldown_rounds is authored %d, data says %d -- balance-measured, see skills.json" % [AUTHORED_COOLDOWN, _cooldown()])
	_placement_is_spawn_array_order()
	_arrival_acts_from_the_next_round()
	_widened_advance_bound_is_load_bearing()
	_summon_draws_no_rng()
	_cooldown_and_fight_limit()
	_capacity_refuses_and_charges_nothing()
	_ai_arm_actually_fires()
	_summons_add_no_banking_surface()

	if not _failures.is_empty():
		for f: String in _failures:
			printerr("FAIL [summon] %s" % f)
		# ORDER MATTERS: a failed assert aborts this function, so the exit code is
		# claimed BEFORE it or `quit(1)` never runs at all.
		quit(1)
		assert(false, "summon effect contract broken; see the FAIL lines above")
		return
	print("PASS: summon places by spawn-array order, joins next round, draws no rng, honors cooldown/fight_limit/capacity, and banks nothing per body")
	quit(0)


## PLACEMENT: first FREE cell of the summoner's own `enemy_spawns`, IN ARRAY
## ORDER. The discriminator is deliberate -- `ruin_court`'s enemy spawns are
## [[10,3],[10,4],[9,3],[9,4]] and the PLAYER side sits west at x<=2, so
## "nearest to the enemy" and "next in the array" name DIFFERENT cells: array
## order says (10,4), nearest-first would say (9,3). A rewrite to nearest-first
## reds this test rather than passing it quietly.
func _placement_is_spawn_array_order() -> void:
	_events.clear()
	var combat := _fight(["pc", LICH], 7)
	var spawns: Array = combat.arena_config["enemy_spawns"]
	_check(combat.combatants[LICH][WIKeys.CELL] == Vector2i(int(spawns[0][0]), int(spawns[0][1])),
		"control: the Lich should hold enemy_spawns[0], otherwise 'first FREE cell' is vacuous")
	_activate(combat, LICH)
	_check(combat.use_skill(RAISE, LICH), "the raising resolves")

	var added := _events_of(WIEvents.COMBATANT_ADDED)
	_check(added.size() == 1, "exactly one COMBATANT_ADDED for count:1, got %d" % added.size())
	if added.is_empty():
		return
	var payload: Dictionary = added[0]
	var new_id := String(payload["id"])
	var want := Vector2i(int(spawns[1][0]), int(spawns[1][1]))
	var nearest := Vector2i(int(spawns[2][0]), int(spawns[2][1]))
	_check(combat.combatants[new_id][WIKeys.CELL] == want,
		"placed at enemy_spawns[1] %s, got %s" % [want, combat.combatants[new_id][WIKeys.CELL]])
	_check(want != nearest, "control: the array-order cell and the nearest-first cell must differ or this proves nothing")
	_check(String(payload["template"]) == THRALL, "template is the authored summon target")
	_check(String(payload["side"]) == "enemy", "the summon takes the summoner's side")
	_check(String(payload["source"]) == LICH and String(payload["skill"]) == RAISE, "the beat names its summoner and Skill")
	_check(payload["cell"] == [want.x, want.y], "the beat carries the cell the body landed on")
	_check(int(payload["round"]) == 1, "the beat reports the round it arrived in")
	_check(combat.combatants[new_id][WIKeys.TEMPLATE_ID] == THRALL, "the record keeps its catalog id for sprite/power lookups")
	_check(int(combat.combatants[new_id][WIKeys.MAX_HP]) == 20 + int(_catalog()[THRALL][WIKeys.STATS]["con"]),
		"a summon is built through the SAME max_hp derivation as a rostered body")

	# A SECOND raising must not stack onto the first body's cell.
	combat.round_number = 3
	_activate(combat, LICH)
	_check(combat.use_skill(RAISE, LICH), "the second raising resolves once the cooldown has run")
	var all_added := _events_of(WIEvents.COMBATANT_ADDED)
	_check(all_added.size() == 2, "two arrivals now")
	if all_added.size() == 2:
		_check(all_added[0]["cell"] != all_added[1]["cell"], "two summons never share a cell")
		_check(all_added[1]["cell"] == [int(spawns[2][0]), int(spawns[2][1])],
			"the second takes enemy_spawns[2], the next free entry in array order")


## TURN ORDER: appended to the tail, acting only from the NEXT round, with every
## existing entry left exactly where it was.
func _arrival_acts_from_the_next_round() -> void:
	_events.clear()
	var combat := _fight(["pc", LICH], 7)
	# The Lich must act EARLY in the order or the claim is untestable: if it were
	# last, the round would roll over before the appended index was ever reached
	# and a missing `joins_round` gate would pass by accident.
	combat.active_index = 0
	combat.turn_order = [LICH, "pc"]
	combat._start_turn()
	var order_before: Array = combat.turn_order.duplicate()
	_check(combat.use_skill(RAISE, LICH), "the raising resolves")
	var added := _events_of(WIEvents.COMBATANT_ADDED)
	if added.is_empty():
		_check(false, "no arrival to test turn order with")
		return
	var new_id := String(added[0]["id"])
	_check(combat.turn_order.size() == order_before.size() + 1, "the order grew by exactly one")
	_check(String(combat.turn_order[combat.turn_order.size() - 1]) == new_id, "the arrival is APPENDED to the tail")
	for i in order_before.size():
		_check(String(combat.turn_order[i]) == String(order_before[i]),
			"nothing already in the order moved (index %d)" % i)

	_events.clear()
	var opening_round := combat.round_number
	combat.end_turn()  # Lich -> pc
	combat.end_turn()  # pc -> wraps; the arrival's index sits between
	var guard := 0
	while combat.round_number == opening_round and not combat.finished and guard < 12:
		guard += 1
		combat.end_turn()
	_check(combat.round_number > opening_round, "the round rolled over")
	# WALK THE STREAM, don't read the clock. Testing `combat.round_number` after the
	# loop compares against a number that has ALREADY advanced, which makes the
	# guard vacuous -- it passed with the `joins_round` gate deleted (mutation run,
	# 2026-08-14). ROUND_STARTED is the only honest marker of which round a
	# TURN_STARTED belongs to.
	var stream_round := opening_round
	var acted_in_opening_round := false
	for e: Dictionary in _events:
		if String(e["type"]) == WIEvents.ROUND_STARTED:
			stream_round = int((e["payload"] as Dictionary)["round"])
		elif String(e["type"]) == WIEvents.TURN_STARTED and String((e["payload"] as Dictionary)["id"]) == new_id \
				and stream_round == opening_round:
			acted_in_opening_round = true
	_check(not acted_in_opening_round, "a body raised this round took a turn IN it")
	# And it IS eligible now -- otherwise the gate above would pass by simply
	# never letting the summon act at all.
	var acted := false
	guard = 0
	while not acted and not combat.finished and guard < 12:
		guard += 1
		if combat.get_active() == new_id:
			acted = true
			break
		combat.end_turn()
	_check(acted, "the arrival takes its first turn in the round AFTER the one it arrived in")


## THE ADVANCE BOUND, and it is a SEPARATE claim from "the waiter is skipped".
##
## `_advance_turn` walks one index per iteration, so a bound of `size() + 1` is
## enough to visit every seat ONCE -- which is why the ordinary skip-the-dead
## loop lived on it happily for the whole life of the file. A JOIN-WAITER breaks
## that arithmetic, because its eligibility CHANGES at the wrap: the cursor has
## to pass it while it is still waiting, wrap (which is what makes it eligible),
## and come all the way back. When the waiter is the ONLY body that can act, that
## is 2N-1 steps from the head, and at the old bound the loop simply FELL OUT --
## no `_start_turn`, no TURN_STARTED, the fight parked with nobody active and the
## driver spinning on a combat that would never finish.
##
## THE SHAPE THAT REACHES IT: cursor at the head, every later seat dead, the
## summoner itself downed after its cast (a riposte kill, an ordinary end to a
## caster's turn), and the body it raised a moment ago as the last thing
## standing. Reverting the bound to `size() + 1` reds this and nothing else.
func _widened_advance_bound_is_load_bearing() -> void:
	_events.clear()
	var combat := _fight(["pc", LICH], 23)
	# Cursor at the HEAD, which is the worst case: the walk to the tail and the
	# walk back after the wrap are both full length.
	combat.turn_order = [LICH, "pc"]
	combat.active_index = 0
	combat._start_turn()
	_check(combat.use_skill(RAISE, LICH), "the raising resolves")
	var added := _events_of(WIEvents.COMBATANT_ADDED)
	if added.is_empty():
		_check(false, "no arrival to test the bound with")
		return
	var waiter := String(added[0]["id"])
	_check(String(combat.turn_order[combat.turn_order.size() - 1]) == waiter, "control: the waiter is the tail seat")

	# Everything except the waiter is now down -- including the summoner, which is
	# what forces the loop past the wrap instead of landing back on it. Set
	# directly rather than through damage: `_post_damage` would run `_check_end`
	# and finish the fight, and a finished fight never advances a turn.
	for id: String in combat.combatants:
		if id != waiter:
			combat.combatants[id][WIKeys.ALIVE] = false
	var round_before := combat.round_number
	_check(int(combat.combatants[waiter].get(WICombat.JOINS_ROUND, 0)) == round_before + 1,
		"control: the waiter is still waiting in this round, so the wrap is REQUIRED to seat it")

	_events.clear()
	combat._advance_turn()
	_check(not combat.finished, "control: nothing here should have ended the fight")
	_check(combat.round_number == round_before + 1, "the loop wrapped into the next round")
	_check(combat.get_active() == waiter,
		"the walk reached the waiter after the wrap; got '%s' -- at a `size() + 1` bound the loop falls out with nobody seated" % combat.get_active())
	var seated := false
	for started: Dictionary in _events_of(WIEvents.TURN_STARTED):
		if String(started["id"]) == waiter:
			seated = true
	_check(seated, "and it actually STARTED a turn -- a parked cursor emits none")


## RNG DOCTRINE: a summon rolls no initiative and consumes no draw, so every
## downstream pin in a fight that contains one stays where it was.
func _summon_draws_no_rng() -> void:
	_events.clear()
	var combat := _fight(["pc", LICH], 11)
	_activate(combat, LICH)
	var state_before := combat.rng.state
	var seed_before := combat.rng.seed
	_check(combat.use_skill(RAISE, LICH), "the raising resolves")
	_check(combat.rng.state == state_before and combat.rng.seed == seed_before,
		"the summon consumed an rng draw (state %d -> %d)" % [state_before, combat.rng.state])


## COOLDOWN and `fight_limit` (both AUTHORED, both read from the data below --
## `_limit()`/`_cooldown()` -- so a measured retune moves the logic with it while
## AUTHORED_FIGHT_LIMIT/AUTHORED_COOLDOWN keep the numbers themselves pinned
## per fight). Measured with capacity deliberately kept OPEN -- each thrall is
## walked off its spawn cell -- so this test decides the LIMIT and never
## accidentally decides the board size.
func _cooldown_and_fight_limit() -> void:
	_events.clear()
	var limit := _limit()
	var cooldown := _cooldown()
	var combat := _fight(["pc", LICH], 13)
	_activate(combat, LICH)
	_check(combat.summon_remaining(LICH, RAISE) == limit, "the allowance starts at the authored fight_limit")
	_check(combat.use_skill(RAISE, LICH), "first raising")
	_check(combat.cooldown_remaining(LICH, RAISE) == cooldown, "the authored cooldown is stamped at the cast")
	_check(not combat.skill_available(LICH, RAISE), "and the Skill is unavailable while it cools")
	_check(not combat.use_skill(RAISE, LICH), "a second raising in the same round is refused")
	_check(_events_of(WIEvents.COMBATANT_ADDED).size() == 1, "and adds no body")
	# The stamp is ABSOLUTE (`round_number + cooldown_rounds`), so it is spent
	# exactly `cooldown` rounds after the round it was cast in.
	combat.round_number = 1 + cooldown
	_check(combat.skill_available(LICH, RAISE), "ready again on R+cooldown_rounds")

	# Walk each thrall off its spawn cell so ONLY the limit can bind below --
	# otherwise this test would silently be deciding the board size instead.
	var next_round := 1 + cooldown
	for i in limit - 1:
		next_round += cooldown + 1
		_free_the_spawns(combat)
		combat.round_number = next_round
		_activate(combat, LICH)
		_check(combat.use_skill(RAISE, LICH), "raising %d of %d" % [i + 2, limit])
	_check(_events_of(WIEvents.COMBATANT_ADDED).size() == limit, "the authored ceiling of bodies is raised")
	_check(combat.summon_remaining(LICH, RAISE) == 0, "the allowance is spent")
	_check(combat.summon_refusal(LICH, RAISE) == "summon_limit", "and the refusal names the LIMIT, not the board")

	combat.round_number = next_round + 20
	_free_the_spawns(combat)
	_activate(combat, LICH)
	_check(combat.cooldown_remaining(LICH, RAISE) == 0, "control: nothing is cooling, so only the limit can refuse")
	_check(not combat.skill_available(LICH, RAISE), "an exhausted limit makes the Skill unavailable")
	_check(not combat.use_skill(RAISE, LICH), "one raising past the ceiling is refused")
	_check(_events_of(WIEvents.COMBATANT_ADDED).size() == limit, "and the board is unchanged")


func _free_the_spawns(combat: WICombat) -> void:
	var parked := 0
	for id: String in combat.combatants:
		if String(combat.combatants[id][WIKeys.TEMPLATE_ID]) == THRALL:
			parked += 1
			combat.combatants[id][WIKeys.CELL] = Vector2i(5, parked)


## CAPACITY, the crowded-field mirror. The opening roster fills every
## `enemy_spawns` cell, so there is nowhere for the dead to rise -- which is also
## exactly the `fight_limit`-CEILING composition the balance guardrail measures.
## A refusal must cost the summoner NOTHING: no AP, no cooldown, no allowance.
func _capacity_refuses_and_charges_nothing() -> void:
	_events.clear()
	var combat := _fight(["pc", LICH, THRALL, THRALL, THRALL], 17)
	_check(_enemy_ids(combat).size() == 4, "control: four enemy bodies fill all four enemy spawns")
	_activate(combat, LICH)
	var ap_before := int(combat.combatants[LICH][WIKeys.AP])
	_check(combat.free_spawn_cell("enemy") == null, "control: no free enemy spawn cell")
	_check(combat.cooldown_remaining(LICH, RAISE) == 0, "control: nothing is cooling")
	_check(combat.summon_remaining(LICH, RAISE) == _limit(), "control: the whole allowance is intact")
	_check(combat.summon_refusal(LICH, RAISE) == "no_room", "the refusal names the crowded field")
	_check(not combat.skill_available(LICH, RAISE), "skill_available folds capacity in, per spec sec.1")

	_events.clear()
	_check(not combat.use_skill(RAISE, LICH), "the raising is refused")
	var refusals := _events_of(WIEvents.ACTION_REFUSED)
	_check(refusals.size() == 1, "the refusal SPEAKS once, got %d" % refusals.size())
	if not refusals.is_empty():
		_check(String(refusals[0]["reason"]) == "no_room" and String(refusals[0]["skill"]) == RAISE,
			"and it names the reason and the Skill")
	_check(_events_of(WIEvents.COMBATANT_ADDED).is_empty(), "nobody arrived")
	_check(int(combat.combatants[LICH][WIKeys.AP]) == ap_before, "a refused raising spends no AP")
	_check(combat.cooldown_remaining(LICH, RAISE) == 0, "a refused raising starts no cooldown")
	_check(combat.summon_remaining(LICH, RAISE) == _limit(), "a refused raising banks nothing against the limit")

	_events.clear()
	_check(not combat.use_skill(RAISE, LICH), "still refused on a retry in the same round")
	_check(_events_of(WIEvents.ACTION_REFUSED).is_empty(),
		"and the tell does NOT repeat inside one round (`_summon_refusal_round` latch)")
	combat.round_number += 1
	_events.clear()
	_check(not combat.use_skill(RAISE, LICH), "still refused next round")
	_check(_events_of(WIEvents.ACTION_REFUSED).size() == 1, "and the tell speaks again in a NEW round")

	# THE REFUSAL MUST NOT COST THE CASTER ITS TURN, which is the whole reason
	# `_try_summon` falls through instead of returning: `take_turn` breaks on the
	# FIRST refused action. The PC is walked into spell range first so the turn has
	# a CAST available to spend -- from the opening spawns the two sides are nine
	# cells apart and a caster would legitimately spend the turn walking, which
	# would make this assertion measure the board instead of the fall-through.
	_events.clear()
	combat.combatants["pc"][WIKeys.CELL] = Vector2i(7, 3)
	_activate(combat, LICH)
	WICombatAI.take_turn(combat)
	var acted := false
	for resolved: Dictionary in _events_of(WIEvents.SKILL_RESOLVED):
		if String(resolved["actor"]) == LICH and String(resolved["skill"]) != RAISE:
			acted = true
	for attack: Dictionary in _events_of(WIEvents.ATTACK_RESOLVED):
		if String(attack["attacker"]) == LICH:
			acted = true
	_check(acted, "a summoner on a full board still spends its turn on its spells")


## The archetype is only real if the shipped AI reaches for it. `ai: caster`
## routes through `_act_caster`, which is where `_try_summon` lives.
func _ai_arm_actually_fires() -> void:
	_events.clear()
	var combat := _fight(["pc", LICH], 5)
	_check(String(combat.combatants[LICH][WIKeys.AI]) == "caster",
		"control: a melee-profile Lich would neither cast nor raise")
	_activate(combat, LICH)
	WICombatAI.take_turn(combat)
	_check(_events_of(WIEvents.COMBATANT_ADDED).size() == 1,
		"the shipped enemy AI raises on its own turn without being told to")


## ANTI-FARMING (spec sec.1): a raised body is an ordinary combatant to kill and
## adds NO per-kill accomplishment surface. The claim is asserted as an
## INDEPENDENCE -- the encounter's `on_victory` ids bank the same number of times
## whether the Lich raised nobody or its whole allowance.
func _summons_add_no_banking_surface() -> void:
	var counts_empty := _bank_counts([])
	var counts_full := _bank_counts(_thrall_roster())
	for key: String in ["crypt_lich_put_down", "victories"]:
		_check(int(counts_empty.get(key, 0)) == 1, "'%s' banks exactly once with no summons" % key)
		_check(int(counts_full.get(key, 0)) == int(counts_empty.get(key, 0)),
			"'%s' banked %d times with the whole allowance dead against %d with none -- a per-kill surface" % [
				key, int(counts_full.get(key, 0)), int(counts_empty.get(key, 0))])


## One thrall per point of the authored allowance -- the board a summoner can
## actually build toward, so the independence below is asserted against the
## fully-raised fight rather than an arbitrary count.
func _thrall_roster() -> Array:
	var out: Array = []
	for _i in _limit():
		out.append(THRALL)
	return out


func _bank_counts(extra: Array) -> Dictionary:
	var combat := _fight(["pc", LICH] + extra, 3)
	for id: String in combat.combatants:
		if String(combat.combatants[id][WIKeys.SIDE]) == "enemy":
			combat.combatants[id][WIKeys.ALIVE] = false
			combat.combatants[id][WIKeys.HP] = 0
	combat.finished = true
	combat.outcome = {"victory": true, "rounds": 4, "survivors": ["pc"], "draw": false}
	var counts := {}
	var entity := {
		WIKeys.ID: "crypt_lich_mouth", WIKeys.KIND: "encounter",
		"on_victory": ["crypt_lich_put_down", "won_combat"],
	}
	var banking := WICombatBanking.new(
		func(_t: String, _p: Dictionary) -> void: pass,
		func(_s: String) -> void: pass,
		func(_id: String) -> Dictionary: return entity,
		func(id: String, amount: int = 1) -> void: counts[id] = int(counts.get(id, 0)) + amount,
		func(_id: String) -> int: return 0,
		func(_e: Dictionary) -> void: pass,
		func(_id: String) -> void: pass)
	var dormant: Array[String] = []
	banking.resolve(combat, "crypt_lich_mouth", dormant)
	return counts
