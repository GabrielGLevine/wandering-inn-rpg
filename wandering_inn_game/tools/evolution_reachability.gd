extends SceneTree
## Issue #96 evidence harness: evolution/consolidation REACHABILITY audit.
## Pure sim, seeded, deterministic -- the sim_combat_batch discipline (same
## WICombat/WICombatAI construction `tests/sim_combat_batch.gd` uses, same
## data files, no invented shortcuts). Never re-derives WIProgression's gate
## math -- every outcome below comes from calling `check_class_gains`/
## `check_level_ups`/`check_evolutions`/`check_consolidation` VERBATIM, the
## same functions `wi_game.gd`'s real `sleep()` calls, in the same order
## (`_resolve_sleep` below mirrors `sleep()`'s class-gains -> level-ups ->
## consolidation-offer -> evolutions sequence, including the REAL rule that
## a live consolidation offer defers evolutions that sleep unless declined).
##
## WHY REAL FIGHTS, NOT INVENTED PER-FIGHT NUMBERS: the accomplishment
## counters this audit cares about (spell_cast/ice_cast/fire_cast/melee_hit/
## sword_skill_used/spear_skill_used/ranged_hit) are banked ONLY from a real
## WICombat's `action_tally` on a genuine victory (`wi_game.gd`'s
## `_bank_action_tally`, mirrored below by `_run_waking_fight`). Running the
## actual sim against the actual shipped compositions is the only way to
## ground "what a real fight banks" instead of guessing a flat rate.
##
## PC "POLICY" CALLABLES stand in for a human's SKILL CHOICE, which
## `combat_ai.gd`'s shipped AI profiles do not fully represent for this
## audit's purposes: "melee" hardcodes power_strike only (never
## piercing_strikes, see `sim_combat_batch.gd`'s own loadout-cell doc
## comment), and "caster"'s line-skill branch only fires on a >=2-enemy
## aligned shot with no ally in the way (`combat_ai.gd::_act_line`) -- far
## stricter than a human choosing to cast a line skill at a single visible
## foe. Each policy below is a minimal, deterministic turn-script built from
## WICombat's OWN public API (`use_skill`/`attack`/`move_active`/`dash`) plus
## `WICombatAI`'s pure pathing/afford helpers (reused, not re-derived) so a
## profile can force "always try to cast X" the way a real player would.
##
## KIT SIMPLIFICATION (documented, not hidden): PCs here are built via
## `WIProgression.granted_skills` directly, WITHOUT `WICombatBuild.
## weapon_gated_kit`'s equipment filter -- the SAME convention every
## un-gear'd row in `sim_combat_batch.gd`'s BUILDS table already uses. This
## is a DELIBERATE scope choice: this audit is about the CLASS-PROGRESSION
## math (dominance/min_uses/thresholds), not equipment availability. It is
## also the more GENEROUS reading for the warrior axis (real play would
## equipment-gate power_strike XOR piercing_strikes to a single weapon slot;
## skipping that gate here only makes the counterfactual "hypothetical mixed
## warrior" row possible to model at all -- see that profile's own comment).
## It changes nothing for the mage axis: frost_bolt/flame_jet carry no
## `weapon` tag in skills.json, so they were never equipment-gated in real
## play either.
##
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tools/evolution_reachability.gd

const COMPOSITIONS := [
	{"arena": "goblin_ambush", "enemies": ["goblin_raider"]},
	{"arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"]},
	{"arena": "cave_mouth", "enemies": ["goblin_chieftain", "goblin_raider", "cave_spider"]},
]

var _catalog: Dictionary
var _skills_cfg: Dictionary
var _skills_by_id: Dictionary
var _by_id: Dictionary
var _arenas_by_id: Dictionary
var _pc_template: Dictionary


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# ---------------------------------------------------------------------------
# PC turn policies -- deterministic scripted turn choices standing in for a
# human's skill choice (see file doc comment for why the shipped AI profiles
# under-represent several of these playstyles).
# ---------------------------------------------------------------------------

## The shipped, unmodified AI profile dispatch (`c["ai"]` selects melee/
## caster/ranged) -- represents an UN-OPTIMIZED player who just uses
## whatever the kit's natural scan order favors, never deliberately avoiding
## a skill.
func _policy_builtin(combat: WICombat, id: String) -> bool:
	return WICombatAI._act_once(combat, id)


func _policy_melee_fallback(combat: WICombat, id: String) -> bool:
	var c: Dictionary = combat.combatants[id]
	var foes: Array = combat.alive_enemies_of(id)
	if foes.is_empty():
		return false
	for foe: String in foes:
		if combat.is_adjacent(id, foe):
			if int(c[WIKeys.AP]) >= WICombat.ATTACK_COST:
				return combat.attack(foe)
			return false
	var goal: Vector2i = combat.combatants[String(foes[0])][WIKeys.CELL]
	if int(c[WIKeys.MOVE_POOL]) >= WICombat.MOVE_COST:
		var dir := WICombatAI._path_step(combat, c[WIKeys.CELL], goal, 1)
		if dir == Vector2i.ZERO:
			return false
		return combat.move_active(dir)
	if WICombatAI._should_dash(combat, c, goal, 1, WICombat.ATTACK_COST):
		return combat.dash()
	return false


## Forces a single-target `spell_damage` cast (frost_bolt/ice_shard/
## flame_bolt/flare_burst shape) whenever affordable+in range, UNCONDITIONAL
## on kit scan order -- a deliberate "always pick element X" choice.
func _policy_force_spell(combat: WICombat, id: String, skill_id: String) -> bool:
	var c: Dictionary = combat.combatants[id]
	if not (c[WIKeys.SKILLS] as Array).has(skill_id):
		return _policy_melee_fallback(combat, id)
	var s: Dictionary = combat.skills[skill_id]
	if not WICombatAI._can_afford(combat, c, s):
		return _policy_melee_fallback(combat, id)
	var foes: Array = combat.alive_enemies_of(id)
	if foes.is_empty():
		return false
	var los_foes: Array = []
	for foe: String in foes:
		if combat.has_los(id, foe):
			los_foes.append(foe)
	if los_foes.is_empty():
		return _policy_melee_fallback(combat, id)
	var target := String(los_foes[0])
	var spell_range := int(s[WIKeys.EFFECT][WIKeys.RANGE])
	if combat.chebyshev(id, target) <= spell_range:
		return combat.use_skill(skill_id, target)
	var goal: Vector2i = combat.combatants[target][WIKeys.CELL]
	if int(c[WIKeys.MOVE_POOL]) >= WICombat.MOVE_COST:
		var dir := WICombatAI._path_step(combat, c[WIKeys.CELL], goal, spell_range)
		if dir == Vector2i.ZERO:
			return _policy_melee_fallback(combat, id)
		return combat.move_active(dir)
	if WICombatAI._should_dash(combat, c, goal, spell_range, combat.effective_ap_cost(c, s)):
		return combat.dash()
	return _policy_melee_fallback(combat, id)


## Forces a `line_damage` cast (flame_jet shape) on ANY safe lined-up foe --
## relaxed vs `combat_ai.gd::_act_line`'s own >=2-enemy gate (>=1 here): a
## human choosing "cast my one fire skill" isn't restricted to multi-hits,
## only to not clipping an ally. Falls to melee when no safe line exists.
func _policy_force_line(combat: WICombat, id: String, skill_id: String) -> bool:
	var c: Dictionary = combat.combatants[id]
	if not (c[WIKeys.SKILLS] as Array).has(skill_id):
		return _policy_melee_fallback(combat, id)
	var s: Dictionary = combat.skills[skill_id]
	if not WICombatAI._can_afford(combat, c, s):
		return _policy_melee_fallback(combat, id)
	var length := int(s[WIKeys.EFFECT][WIKeys.LENGTH])
	var side := String(c[WIKeys.SIDE])
	var token_by_dir := {
		Vector2i.UP: "up", Vector2i.DOWN: "down", Vector2i.LEFT: "left", Vector2i.RIGHT: "right",
	}
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var cells: Array[Vector2i] = combat.line_cells(c[WIKeys.CELL], dir, length)
		if cells.is_empty():
			continue
		var enemies_hit := 0
		var hits_ally := false
		for other_id: String in combat.combatants:
			var other: Dictionary = combat.combatants[other_id]
			if not bool(other[WIKeys.ALIVE]) or other_id == id:
				continue
			if not ((other[WIKeys.CELL] as Vector2i) in cells):
				continue
			if String(other[WIKeys.SIDE]) == side:
				hits_ally = true
			else:
				enemies_hit += 1
		if enemies_hit >= 1 and not hits_ally:
			return combat.use_skill(skill_id, String(token_by_dir[dir]))
	var foes: Array = combat.alive_enemies_of(id)
	if foes.is_empty():
		return false
	var goal: Vector2i = combat.combatants[String(foes[0])][WIKeys.CELL]
	if int(c[WIKeys.MOVE_POOL]) >= WICombat.MOVE_COST:
		var mdir := WICombatAI._path_step(combat, c[WIKeys.CELL], goal, 1)
		if mdir == Vector2i.ZERO:
			return _policy_melee_fallback(combat, id)
		return combat.move_active(mdir)
	return _policy_melee_fallback(combat, id)


## Forces a weapon-tagged `damage_mult` skill (power_strike/piercing_strikes
## shape) whenever adjacent+affordable, else a bare Attack, else approach --
## `_act_melee`'s own shape, with the forced skill id parameterized instead
## of hardcoded to "power_strike".
func _policy_force_weapon(combat: WICombat, id: String, skill_id: String, ap_cost: int) -> bool:
	var c: Dictionary = combat.combatants[id]
	var foes: Array = combat.alive_enemies_of(id)
	if foes.is_empty():
		return false
	for foe: String in foes:
		if combat.is_adjacent(id, foe):
			if (c[WIKeys.SKILLS] as Array).has(skill_id) and int(c[WIKeys.AP]) >= ap_cost:
				return combat.use_skill(skill_id, foe)
			if int(c[WIKeys.AP]) >= WICombat.ATTACK_COST:
				return combat.attack(foe)
			return false
	var goal: Vector2i = combat.combatants[String(foes[0])][WIKeys.CELL]
	if int(c[WIKeys.MOVE_POOL]) >= WICombat.MOVE_COST:
		var dir := WICombatAI._path_step(combat, c[WIKeys.CELL], goal, 1)
		if dir == Vector2i.ZERO:
			return false
		return combat.move_active(dir)
	if WICombatAI._should_dash(combat, c, goal, 1, WICombat.ATTACK_COST):
		return combat.dash()
	return false


## Forces a ranged weapon-tagged `damage_mult` skill (power_shot/quick_nock
## shape -- [Archer]'s kit, distinct from `_policy_force_weapon`'s melee-only
## adjacency check): moves into `weapon_range` first (not bare adjacency),
## then casts, falling back to a bare Attack (also `in_weapon_range`-gated,
## `wi_combat.gd::attack`) when the skill itself is unaffordable. Needs the
## PC's own `weapon_range` set (`_build_pc`'s `weapon_range` param) -- at the
## default 1 this degenerates to melee-only range, same as every other
## profile.
func _policy_force_ranged_weapon(combat: WICombat, id: String, skill_id: String, ap_cost: int) -> bool:
	var c: Dictionary = combat.combatants[id]
	var foes: Array = combat.alive_enemies_of(id)
	if foes.is_empty():
		return false
	var los_foes: Array = []
	for foe: String in foes:
		if combat.has_los(id, foe):
			los_foes.append(foe)
	if los_foes.is_empty():
		return _policy_melee_fallback(combat, id)
	var target := String(los_foes[0])
	var weapon_range := int(c.get(WIKeys.WEAPON_RANGE, 1))
	if combat.chebyshev(id, target) <= weapon_range:
		if (c[WIKeys.SKILLS] as Array).has(skill_id) and int(c[WIKeys.AP]) >= ap_cost:
			return combat.use_skill(skill_id, target)
		if int(c[WIKeys.AP]) >= WICombat.ATTACK_COST:
			return combat.attack(target)
		return false
	var goal: Vector2i = combat.combatants[target][WIKeys.CELL]
	if int(c[WIKeys.MOVE_POOL]) >= WICombat.MOVE_COST:
		var dir := WICombatAI._path_step(combat, c[WIKeys.CELL], goal, weapon_range)
		if dir == Vector2i.ZERO:
			return false
		return combat.move_active(dir)
	if WICombatAI._should_dash(combat, c, goal, weapon_range, WICombat.ATTACK_COST):
		return combat.dash()
	return false


# ---------------------------------------------------------------------------
# Fight / waking / sleep plumbing
# ---------------------------------------------------------------------------

func _run_pc_turn(combat: WICombat, policy: Callable) -> void:
	var id := "pc"
	var guard := 0
	while not combat.finished and combat.get_active() == id and guard < 24:
		guard += 1
		if not policy.call(combat, id):
			break
	if not combat.finished and combat.get_active() == id:
		combat.end_turn()


func _run_fight(arena: Dictionary, cfgs: Array, seed_v: int, policy: Callable) -> WICombat:
	var sink := func(_t: String, _p: Dictionary) -> void: pass
	var combat := WICombat.new(arena, cfgs, _skills_cfg, sink, seed_v)
	combat.begin()
	var guard := 0
	while not combat.finished and guard < 6000:
		guard += 1
		if combat.get_active() == "pc":
			_run_pc_turn(combat, policy)
		else:
			WICombatAI.take_turn(combat)
	assert(combat.finished, "evolution_reachability fight did not terminate (seed %d)" % seed_v)
	return combat


## `weapon_range` mirrors `wi_game.gd::_build_player_combatant`'s injection of
## the EQUIPPED weapon's `items.json` `range` field (default 1/melee) -- the
## only field the ungated-kit simplification (see file doc comment) still
## needs to thread through by hand, since `ranged_hit` ([Archer]'s own axis)
## tallies ONLY when `weapon_range > 1` (`wi_combat.gd::_resolve_hit`).
## training_bow/hunting_bow both carry `range: 4` in items.json.
func _build_pc(classes: Dictionary, ai: String, generalist_classes: Array, weapon_range: int = 1) -> Dictionary:
	var pc: Dictionary = _pc_template.duplicate(true)
	pc[WIKeys.AI] = ai
	pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], classes, _catalog)
	pc[WIKeys.SKILLS] = WIProgression.granted_skills(classes, _catalog, generalist_classes)
	pc[WIKeys.WEAPON_RANGE] = weapon_range
	return pc


## Runs ONE fight for this waking and, on victory, banks won_combat + the
## real `action_tally` into `accomplishments` -- the SAME victory-only,
## trivial-exempt bank `wi_game.gd::_bank_action_tally` performs (no trivial
## fights are modeled here, so the gate is always live).
func _run_waking_fight(classes: Dictionary, accomplishments: Dictionary, generalist_classes: Array, ai: String, policy: Callable, comp_index: int, seed_v: int, weapon_range: int = 1) -> void:
	var comp: Dictionary = COMPOSITIONS[comp_index % COMPOSITIONS.size()]
	var arena: Dictionary = _arenas_by_id[String(comp["arena"])]
	var pc := _build_pc(classes, ai, generalist_classes, weapon_range)
	var cfgs: Array = [pc, (_by_id["relc"] as Dictionary).duplicate(true)]
	for enemy_id: String in (comp["enemies"] as Array):
		cfgs.append((_by_id[String(enemy_id)] as Dictionary).duplicate(true))
	var combat := _run_fight(arena, cfgs, seed_v, policy)
	if bool(combat.outcome.get("victory", false)):
		accomplishments["won_combat"] = int(accomplishments.get("won_combat", 0)) + 1
		var tally: Dictionary = combat.action_tally.get("pc", {})
		for counter: String in tally:
			accomplishments[counter] = int(accomplishments.get(counter, 0)) + int(tally[counter])


## Mirrors `wi_game.gd::sleep()`'s progression resolution order EXACTLY:
## class gains -> level-ups -> consolidation offer (which DEFERS evolutions
## this same beat, real rule) -> evolutions. `always_decline` mirrors a
## player who declines every consolidation offer (`decline_consolidation()`
## resolves evolutions in the SAME beat it declines in, real rule) so this
## audit can still see mage/warrior's own evolution timing past the offer.
## Returns the events that fired this waking for the caller to inspect.
func _resolve_sleep(classes: Dictionary, accomplishments: Dictionary, generalist_classes: Array, always_decline: bool) -> Dictionary:
	var out := {"class_gains": [], "level_ups": [], "consolidation_offer": {}, "evolutions": []}
	for cid: String in WIProgression.check_class_gains(classes, accomplishments, _catalog):
		classes[cid] = 1
		out["class_gains"].append(cid)
	for gain: Dictionary in WIProgression.check_level_ups(classes, accomplishments, _catalog):
		classes[String(gain["class"])] = int(gain["level"])
		out["level_ups"].append(gain)
	var offer: Dictionary = WIProgression.check_consolidation(classes, _catalog)
	if not offer.is_empty():
		out["consolidation_offer"] = offer.duplicate(true)
		if not always_decline:
			return out
	for outcome: Dictionary in WIProgression.check_evolutions(classes, accomplishments, _catalog, generalist_classes):
		var cid2 := String(outcome["class"])
		if outcome.has("to"):
			classes[String(outcome["to"])] = int(outcome["level"])
			classes.erase(cid2)
		elif bool(outcome.get("generalist", false)):
			if not generalist_classes.has(cid2):
				generalist_classes.append(cid2)
		out["evolutions"].append(outcome)
	return out


func _class_by_id(class_id: String) -> Dictionary:
	for cls: Dictionary in _catalog.get("classes", []):
		if String(cls[WIKeys.ID]) == class_id:
			return cls
	return {}


## Explains WHY `class_id`'s evolution hasn't resolved, read straight off the
## same fields `check_evolutions` reads -- for the NEVER rows' reason column.
func _diagnose_evolution(class_id: String, classes: Dictionary, accomplishments: Dictionary) -> String:
	if not classes.has(class_id):
		return "class no longer held (already resolved or consolidated away)"
	var cls := _class_by_id(class_id)
	var evo: Dictionary = cls.get("evolution", {})
	var held := int(classes[class_id])
	var at_level := int(evo.get("at_level", 0))
	if held < at_level:
		return "level %d < at_level %d (not yet eligible)" % [held, at_level]
	var targets: Dictionary = evo.get("targets", {})
	var counts := {}
	var total := 0
	for key: String in targets:
		var c := int(accomplishments.get(key, 0))
		counts[key] = c
		total += c
	var min_uses := int(evo.get("min_uses", 0))
	if total < min_uses:
		return "min_uses unreached: total %d < %d %s" % [total, min_uses, str(counts)]
	var top := 0
	for key: String in targets:
		top = maxi(top, int(counts[key]))
	var share := float(top) / float(total) if total > 0 else 0.0
	var dom: float = float(evo.get("dominance_share", 1.0))
	if share < dom:
		var has_generalist := evo.has("balanced_grants")
		return "dominance unresolved: top share %.2f < %.2f %s%s" % [
			share, dom, str(counts),
			" (Generalist should have fired instead -- check balanced_grants wiring)" if has_generalist else " (no balanced_grants -- perpetual Waiting by design)",
		]
	return "UNEXPECTED -- should have resolved, re-check this diagnosis"


# ---------------------------------------------------------------------------
# Profile runner
# ---------------------------------------------------------------------------

## Runs a combat-accruing profile until `target_class_id` either evolves
## (Replacement), goes Generalist, or `max_wakings` is exhausted (NEVER).
## `policy_for_waking` picks the PC turn-policy for waking N (1-indexed),
## letting a profile alternate playstyle waking-to-waking (e.g. the mixed
## mage+warrior profile below).
func _simulate_combat_profile(name: String, seed_classes: Dictionary, target_class_id: String, ai: String, policy_for_waking: Callable, max_wakings: int, seed_base: int, weapon_range: int = 1) -> Dictionary:
	var classes := seed_classes.duplicate(true)
	var accomplishments := {}
	var generalist_classes: Array = []
	var comp_index := 0
	var first_consolidation_waking := -1
	var first_consolidation_offer := {}
	for waking in range(1, max_wakings + 1):
		var policy: Callable = policy_for_waking.call(waking)
		_run_waking_fight(classes, accomplishments, generalist_classes, ai, policy, comp_index, seed_base + waking, weapon_range)
		comp_index += 1
		var result := _resolve_sleep(classes, accomplishments, generalist_classes, true)
		if first_consolidation_waking < 0 and not (result["consolidation_offer"] as Dictionary).is_empty():
			first_consolidation_waking = waking
			first_consolidation_offer = (result["consolidation_offer"] as Dictionary).duplicate(true)
		for outcome: Dictionary in (result["evolutions"] as Array):
			if String(outcome["class"]) != target_class_id:
				continue
			if outcome.has("to"):
				return {
					"outcome": "replacement", "to": String(outcome["to"]), "waking": waking,
					"level": int(outcome["level"]), "accomplishments": accomplishments.duplicate(true),
					"consolidation_waking": first_consolidation_waking, "consolidation_offer": first_consolidation_offer,
				}
			if bool(outcome.get("generalist", false)):
				return {
					"outcome": "generalist", "waking": waking, "level": int(classes.get(target_class_id, -1)),
					"accomplishments": accomplishments.duplicate(true),
					"consolidation_waking": first_consolidation_waking, "consolidation_offer": first_consolidation_offer,
				}
	return {
		"outcome": "never", "waking": max_wakings,
		"reason": _diagnose_evolution(target_class_id, classes, accomplishments),
		"accomplishments": accomplishments.duplicate(true),
		"consolidation_waking": first_consolidation_waking, "consolidation_offer": first_consolidation_offer,
	}


## Non-combat variant for Helper (served_customer/delivered_item/
## cleaned_the_inn are exploration/economy accomplishments, not combat
## tallies). `per_waking` adds a fixed accomplishment delta each waking --
## grounded in the REAL `once_per_waking` cap on Serve (`patron_serving.json`)
## and the delivery wage (`skeleton_scene.json`'s `on_interact_accomplishment:
## "delivered_item"`, also `once_per_waking`): at most 1 of each per waking in
## real play, so 1/waking here is the TRUE ceiling, not a guess.
func _simulate_chore_profile(name: String, target_class_id: String, per_waking: Callable, max_wakings: int) -> Dictionary:
	var classes := {"helper": 1}
	var accomplishments := {}
	var generalist_classes: Array = []
	for waking in range(1, max_wakings + 1):
		per_waking.call(accomplishments, waking)
		var result := _resolve_sleep(classes, accomplishments, generalist_classes, true)
		for outcome: Dictionary in (result["evolutions"] as Array):
			if String(outcome["class"]) != target_class_id:
				continue
			if outcome.has("to"):
				return {"outcome": "replacement", "to": String(outcome["to"]), "waking": waking, "level": int(outcome["level"]), "accomplishments": accomplishments.duplicate(true)}
			if bool(outcome.get("generalist", false)):
				return {"outcome": "generalist", "waking": waking, "level": int(classes.get(target_class_id, -1)), "accomplishments": accomplishments.duplicate(true)}
	return {"outcome": "never", "waking": max_wakings, "reason": _diagnose_evolution(target_class_id, classes, accomplishments), "accomplishments": accomplishments.duplicate(true)}


func _fmt_result(profile: String, target: String, result: Dictionary) -> String:
	var line := "%-32s -> %-22s : " % [profile, target]
	match String(result["outcome"]):
		"replacement":
			line += "REPLACEMENT to [%s] at waking %d (level %d)" % [String(result["to"]), int(result["waking"]), int(result["level"])]
		"generalist":
			line += "GENERALIST at waking %d (level %d)" % [int(result["waking"]), int(result["level"])]
		"never":
			line += "NEVER (stopped at waking %d) -- %s" % [int(result["waking"]), String(result["reason"])]
	if result.has("consolidation_waking") and int(result["consolidation_waking"]) > 0:
		var offer: Dictionary = result["consolidation_offer"]
		line += " | consolidation offered at waking %d (-> [%s] level %d)" % [int(result["consolidation_waking"]), String(offer.get("target", "")), int(offer.get("level", -1))]
	line += " | final tally %s" % str(result["accomplishments"])
	return line


func _init() -> void:
	var watchdog_timeout := 240.0
	create_timer(watchdog_timeout).timeout.connect(func() -> void:
		print("WATCHDOG: evolution_reachability timed out after %ds" % int(watchdog_timeout))
		quit(1)
	)

	_arenas_by_id = {}
	for a: Dictionary in _load("res://data/arenas.json")["arenas"]:
		_arenas_by_id[String(a[WIKeys.ID])] = a
	_skills_cfg = _load("res://data/skills.json")
	_catalog = _load("res://data/classes.json")
	var combatants_catalog := _load("res://data/combatants.json")
	_by_id = {}
	for c: Dictionary in combatants_catalog["combatants"]:
		_by_id[String(c[WIKeys.ID])] = c
	_pc_template = _by_id["pc"]
	_skills_by_id = {}
	for s: Dictionary in (_skills_cfg[WIKeys.SKILLS] as Array):
		_skills_by_id[String(s[WIKeys.ID])] = s

	print("=== Issue #96: evolution/consolidation reachability audit ===")
	print("(profile -> target : outcome | consolidation cross-check | final per-fight-banked tally)")
	print("")

	var rows: Array[String] = []

	# --- Mage: ice/fire Replacement + Generalist ---------------------------
	var pol_builtin: Callable = func(_w: int) -> Callable: return _policy_builtin
	var pol_mono_ice: Callable = func(_w: int) -> Callable: return _policy_force_spell.bind("frost_bolt")
	var pol_mono_fire: Callable = func(_w: int) -> Callable: return _policy_force_line.bind("flame_jet")
	var pol_mage_balanced: Callable = func(w: int) -> Callable:
		return _policy_force_spell.bind("frost_bolt") if w % 2 == 0 else _policy_force_line.bind("flame_jet")

	rows.append(_fmt_result("mage_default_caster (un-optimized, shipped AI)", "mage",
		_simulate_combat_profile("mage_default_caster", {"mage": 1}, "mage", "caster", pol_builtin, 150, 10000)))
	rows.append(_fmt_result("mage_mono_ice (deliberate)", "mage",
		_simulate_combat_profile("mage_mono_ice", {"mage": 1}, "mage", "melee", pol_mono_ice, 150, 20000)))
	rows.append(_fmt_result("mage_mono_fire (deliberate)", "mage",
		_simulate_combat_profile("mage_mono_fire", {"mage": 1}, "mage", "melee", pol_mono_fire, 150, 30000)))
	rows.append(_fmt_result("mage_deliberate_balanced (ice/fire alt.)", "mage",
		_simulate_combat_profile("mage_deliberate_balanced", {"mage": 1}, "mage", "melee", pol_mage_balanced, 150, 40000)))

	# --- Warrior: sword/spear Replacement + counterfactual mixed -----------
	var pol_spear: Callable = func(_w: int) -> Callable: return _policy_force_weapon.bind("piercing_strikes", 2)
	var pol_warrior_mixed: Callable = func(w: int) -> Callable:
		return _policy_force_weapon.bind("power_strike", 3) if w % 2 == 0 else _policy_force_weapon.bind("piercing_strikes", 2)

	rows.append(_fmt_result("warrior_sword (shipped melee AI)", "warrior",
		_simulate_combat_profile("warrior_sword", {"warrior": 1}, "warrior", "melee", pol_builtin, 150, 50000)))
	rows.append(_fmt_result("warrior_spear (deliberate)", "warrior",
		_simulate_combat_profile("warrior_spear", {"warrior": 1}, "warrior", "melee", pol_spear, 150, 60000)))
	rows.append(_fmt_result("warrior_hypothetical_mixed (sword/spear alt., NOT reachable in real play -- one weapon slot forces exclusivity; modeled to isolate WHY mage differs)", "warrior",
		_simulate_combat_profile("warrior_hypothetical_mixed", {"warrior": 1}, "warrior", "melee", pol_warrior_mixed, 150, 70000)))

	# --- Archer: single-axis Replacement (sanity check) ---------------------
	# training_bow/hunting_bow both carry range:4 (items.json) -- threaded by
	# hand via `weapon_range` since the ungated-kit simplification skips the
	# real equip() path (see `_build_pc`'s own doc comment). The shipped
	# "ranged" AI profile only knows spell_damage/line_damage skills
	# (`combat_ai.gd::_act_ranged`) -- archer's kit is `damage_mult`
	# (power_shot/quick_nock), a shape that profile can't drive at all, so
	# this profile uses the dedicated `_policy_force_ranged_weapon` instead.
	var pol_archer: Callable = func(_w: int) -> Callable: return _policy_force_ranged_weapon.bind("power_shot", 3)
	rows.append(_fmt_result("archer_bow (deliberate, power_shot at range)", "archer",
		_simulate_combat_profile("archer_bow", {"archer": 1}, "archer", "melee", pol_archer, 150, 80000, 4)))

	# --- Helper: serve/deliver Replacement + the cleaning-only trap ---------
	var chore_serve: Callable = func(acc: Dictionary, _w: int) -> void:
		acc["served_customer"] = int(acc.get("served_customer", 0)) + 1
	var chore_deliver: Callable = func(acc: Dictionary, _w: int) -> void:
		acc["delivered_item"] = int(acc.get("delivered_item", 0)) + 1
	var chore_balanced: Callable = func(acc: Dictionary, w: int) -> void:
		if w % 2 == 0:
			acc["served_customer"] = int(acc.get("served_customer", 0)) + 1
		else:
			acc["delivered_item"] = int(acc.get("delivered_item", 0)) + 1
	var chore_cleaner: Callable = func(acc: Dictionary, _w: int) -> void:
		acc["cleaned_the_inn"] = int(acc.get("cleaned_the_inn", 0)) + 1

	rows.append(_fmt_result("helper_serve_mono", "helper",
		_simulate_chore_profile("helper_serve_mono", "helper", chore_serve, 150)))
	rows.append(_fmt_result("helper_deliver_mono", "helper",
		_simulate_chore_profile("helper_deliver_mono", "helper", chore_deliver, 150)))
	rows.append(_fmt_result("helper_deliberate_balanced (serve/deliver alt.)", "helper",
		_simulate_chore_profile("helper_deliberate_balanced", "helper", chore_balanced, 150)))
	rows.append(_fmt_result("helper_cleaner_only (levels via cleaned_the_inn, never serves/delivers)", "helper",
		_simulate_chore_profile("helper_cleaner_only", "helper", chore_cleaner, 150)))

	# --- THE user's profile: mixed mage+warrior -> consolidation ------------
	# waking%4 pattern: 2 of every 4 wakings warrior-focused (power_strike),
	# 1 ice, 1 fire -- a player genuinely splitting time across both classes
	# AND both elements, exactly the "mage+warrior mixed" shape the issue
	# names as the profile that produced the real [Spellsword] offer.
	var pol_mixed_mw: Callable = func(w: int) -> Callable:
		var phase := w % 4
		if phase == 1:
			return _policy_force_spell.bind("frost_bolt")
		if phase == 3:
			return _policy_force_line.bind("flame_jet")
		return _policy_force_weapon.bind("power_strike", 3)

	rows.append(_fmt_result("mixed_mage_warrior (DECLINE consolidation every offer)", "mage",
		_simulate_combat_profile("mixed_mw_mage_decline", {"warrior": 1, "mage": 1}, "mage", "melee", pol_mixed_mw, 300, 90000)))
	rows.append(_fmt_result("mixed_mage_warrior (DECLINE consolidation every offer)", "warrior",
		_simulate_combat_profile("mixed_mw_warrior_decline", {"warrior": 1, "mage": 1}, "warrior", "melee", pol_mixed_mw, 300, 90000)))

	print("")
	for line: String in rows:
		print(line)
	print("")
	print("=== end audit ===")
	quit(0)
