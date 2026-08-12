class_name WICombatPolicies
extends RefCounted

## SIM-ONLY combat policies (#437). Two of them:
##
##   `dumb`      -- today's autoplay, byte-for-byte: it IS `WICombatAI`.
##   `competent` -- the TUNING REFERENCE. A player who uses their kit: heals
##                  when low, drinks a carried draught, casts when the cast
##                  beats the swing, keeps range with a reaching weapon.
##
## WHY THIS EXISTS (issue #437 amendment + CHOICE-LOG 2026-08-11): QA victory
## pins are authored against `combat_autoplay`, which is the melee profile --
## it never casts a PC spell, never drinks, never uses [Second Wind]. Pinning
## victory to THAT policy made every spine fight winnable by the weakest
## possible play, which is a balance ratchet: any retune toward the intended
## difficulty reds CI. So difficulty is proven HERE instead, against a policy
## that spends what the build is carrying, and QA keeps proving completability.
##
## THIS IS NOT SHIPPED AI. Nothing under `src/` loads this file. Enemies keep
## their authored profiles (`combat_ai.gd`) in every run -- `driven` names the
## handful of ids the competent policy steers, and everyone else falls through
## to `WICombatAI.take_turn` exactly as they do in the game.
##
## CONSTRUCTION RULES (balance-bands-and-policy.md):
##   - Deterministic given (state, rng). Table rows must reproduce.
##   - No lookahead past the current turn; no target choice beyond
##     lowest-HP-reachable. The point is "uses resources", not "plays well".
##   - The policy never reimplements game math. Every action goes through the
##     public `WICombat` verbs (`attack`, `use_skill`, `move_active`, `dash`,
##     `end_turn`) or through `WIItems.resolve_use`, the same call the hotbar's
##     item slot makes. Targeting geometry for line/area casts is BORROWED from
##     `WICombatAI` rather than restated, so it cannot drift from the shipped
##     rule. The one piece of arithmetic that is unavoidably local is
##     `expected_damage` (a comparison, not an effect) -- and
##     `tests/test_combat_policies.gd` pins it against the engine's own measured
##     output rather than against a copy of the formula.

const DUMB := "dumb"
const COMPETENT := "competent"

## Below this fraction of max HP the competent policy stops fighting and fixes
## itself. 0.35 is the balance doc's number.
const SURVIVE_HP_FRACTION := 0.35

## Mirrors `WICombatAI.take_turn`'s own runaway guard, for the same reason: an
## action that reports success without consuming anything must not spin.
const ACT_GUARD := 24

## Which policy `take_turn` applies to the `driven` ids.
var policy := DUMB

## items.json records keyed by id -- the catalog `carried` ids resolve against.
var items_by_id: Dictionary = {}

## actor id -> Array of carried consumable item ids. Drinking erases from this
## array, so a fight's draughts are finite exactly as a run's pack is.
var carried: Dictionary = {}

## Optional sink for the drink action. UNSET (the sim harnesses) → the policy
## calls `WIItems.resolve_use` itself, because a bare-combat harness has no
## WIGame to hold a pack. SET (the QA driver's `policy: competent` autoplay) →
## the policy calls it with the item id and lets the live game own the whole
## transaction: inventory erase, `item_used` event, toast. Either way the
## effect arithmetic is `WIItems`', never a copy of it.
var use_item_fn: Callable = Callable()

## Ids the competent policy drives. Everything else -- every enemy, every ally
## -- keeps its shipped profile. The PC-side kit gap is the whole subject.
var driven: Dictionary = {"pc": true}

## Per-turn latch: at most ONE survive action per turn. Without it a holder of
## [Second Wind] (2 AP, no cooldown, no once_per_fight) heals twice a turn for
## as long as it is under threshold, which is optimal play and therefore off
## this policy's brief.
var _survive_spent_this_turn := false


func _init(policy_name: String = DUMB) -> void:
	policy = policy_name


## Drive whoever is active. Signature mirrors `WICombatAI.take_turn` so the two
## are interchangeable at every call site in the harnesses.
func take_turn(combat: WICombat) -> void:
	var id := combat.get_active()
	if policy != COMPETENT or not bool(driven.get(id, false)):
		WICombatAI.take_turn(combat)
		return
	_survive_spent_this_turn = false
	var guard := 0
	while not combat.finished and combat.get_active() == id and guard < ACT_GUARD:
		guard += 1
		if not _competent_act_once(combat, id):
			break
	if not combat.finished and combat.get_active() == id:
		combat.end_turn()


## The five-step framework, in priority order (balance-bands-and-policy.md).
## Returns true when it took an action and wants another look at the state.
func _competent_act_once(combat: WICombat, id: String) -> bool:
	var c: Dictionary = combat.combatants[id]
	var foes: Array = []
	for foe_v: Variant in combat.alive_enemies_of(id):
		var foe := String(foe_v)
		if not _is_untargetable(combat, foe):
			foes.append(foe)
	if foes.is_empty():
		return false
	# `alive_enemies_of` already sorts HP-ascending with an id tiebreak, so
	# "lowest-HP" is just "first that qualifies" everywhere below.
	if _survive(combat, id, c):
		return true
	if _nuke(combat, id, c, foes):
		return true
	if _attack(combat, id, c, foes):
		return true
	if _position(combat, id, c, foes):
		return true
	return false


# --- 1. SURVIVE ------------------------------------------------------------

func _survive(combat: WICombat, id: String, c: Dictionary) -> bool:
	if _survive_spent_this_turn:
		return false
	var max_hp := maxf(1.0, float(c[WIKeys.MAX_HP]))
	if float(c[WIKeys.HP]) / max_hp >= SURVIVE_HP_FRACTION:
		return false
	var heal_id := _best_heal_skill(combat, c)
	if heal_id != "" and combat.use_skill(heal_id, id):
		_survive_spent_this_turn = true
		return true
	if _drink_best_draught(combat, id, c):
		_survive_spent_this_turn = true
		return true
	var escape_id := _escape_skill(combat, c)
	if escape_id != "" and combat.use_skill(escape_id, id):
		_survive_spent_this_turn = true
		return true
	return false


## Highest-amount SELF heal in kit that is affordable and off cooldown.
## `_resolve_heal` refuses a non-self target without `ally_target`, so the
## self-cast restriction is read from the same data the engine enforces.
func _best_heal_skill(combat: WICombat, c: Dictionary) -> String:
	var best := ""
	var best_amount := 0
	for raw: Variant in (c[WIKeys.SKILLS] as Array):
		var sk := String(raw)
		var s: Dictionary = combat.skills.get(sk, {})
		var effect: Dictionary = s.get(WIKeys.EFFECT, {})
		if String(effect.get(WIKeys.TYPE, "")) != "heal":
			continue
		if not _castable(combat, c, s):
			continue
		var amount := int(effect.get(WIKeys.AMOUNT, 0))
		if amount > best_amount:
			best_amount = amount
			best = sk
	return best


## The `combat_use_item` path, minus the WIGame inventory it cannot reach from
## a bare-combat harness: `WIItems.resolve_use` is the same function
## `WIGame.combat_use_item` calls, so the AP charge, the clamp and the heal are
## the shipped ones. `carried` stands in for the pack.
func _drink_best_draught(combat: WICombat, id: String, c: Dictionary) -> bool:
	var pack: Array = carried.get(id, [])
	if pack.is_empty():
		return false
	if int(c[WIKeys.AP]) < WIItems.FLAT_AP_COST:
		return false
	var best_index := -1
	var best_heal := 0
	for i in pack.size():
		var rec: Dictionary = items_by_id.get(String(pack[i]), {})
		var heal := int((rec.get(WIKeys.USE_EFFECT, {}) as Dictionary).get("heal", 0))
		if heal > best_heal:
			best_heal = heal
			best_index = i
	if best_index < 0:
		return false
	var item_id := String(pack[best_index])
	var ok := false
	if use_item_fn.is_valid():
		ok = bool(use_item_fn.call(item_id))
	else:
		ok = bool(WIItems.resolve_use(items_by_id[item_id], combat).get("ok", false))
	if not ok:
		return false
	pack.remove_at(best_index)
	carried[id] = pack
	return true


## An escape-shaped ability: anything whose effect makes the holder
## untargetable ([Invisibility], and whatever else lands that status later).
## Read from the effect's `applies` block, never from an id list.
func _escape_skill(combat: WICombat, c: Dictionary) -> String:
	for raw: Variant in (c[WIKeys.SKILLS] as Array):
		var sk := String(raw)
		var s: Dictionary = combat.skills.get(sk, {})
		var effect: Dictionary = s.get(WIKeys.EFFECT, {})
		if not _castable(combat, c, s):
			continue
		var applies: Dictionary = effect.get(WIKeys.APPLIES, {})
		for status_id: String in applies:
			if bool((applies[status_id] as Dictionary).get("untargetable", false)):
				return sk
	return ""


# --- 2. NUKE ---------------------------------------------------------------

## Cast when the cast beats the swing. Multi-target line/area first (the
## shipped ranged profile's own preference and its own >=2-foes-no-ally rule,
## reused rather than restated), then the best single-target option.
func _nuke(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	if foes.size() >= 2 and _nuke_area(combat, id, c, foes):
		return true
	var basic := _basic_attack_expected(combat, id, c, foes)
	var best_skill := ""
	var best_target := ""
	var best_value := basic
	for raw: Variant in (c[WIKeys.SKILLS] as Array):
		var sk := String(raw)
		var s: Dictionary = combat.skills.get(sk, {})
		if not _castable(combat, c, s):
			continue
		var effect: Dictionary = s.get(WIKeys.EFFECT, {})
		var effect_type := String(effect.get(WIKeys.TYPE, ""))
		var melee := effect_type == "damage_mult"
		if effect_type != "damage_mult" and effect_type != "spell_damage":
			continue
		var mult := float(effect.get(WIKeys.MULT, 1.0)) if melee else 1.0
		for foe_v: Variant in foes:
			var foe := String(foe_v)
			if melee:
				if not combat.in_weapon_range(id, foe):
					continue
			else:
				if combat.chebyshev(id, foe) > int(effect.get(WIKeys.RANGE, 0)):
					continue
				if not combat.has_los(id, foe):
					continue
			var value := expected_damage(combat, c, combat.combatants[foe], mult, melee)
			if value > best_value:
				best_value = value
				best_skill = sk
				best_target = foe
			break  # foes is HP-ascending: the first reachable one is the pick
	if best_skill == "":
		return false
	return combat.use_skill(best_skill, best_target)


## Line and area casts. `WICombatAI._act_line` / `_act_area` own the geometry
## AND the "hits >=2 foes and no ally" rule; borrowing them keeps the competent
## policy from inventing a second, divergent answer to the same question.
func _nuke_area(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	var line_id := ""
	var area_id := ""
	for raw: Variant in (c[WIKeys.SKILLS] as Array):
		var sk := String(raw)
		var s: Dictionary = combat.skills.get(sk, {})
		if not _castable(combat, c, s):
			continue
		var effect_type := String((s.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.TYPE, ""))
		if effect_type == "line_damage" and line_id == "":
			line_id = sk
		elif (effect_type == "blast_damage" or effect_type == "icy_floor") and area_id == "":
			area_id = sk
	if line_id != "" and WICombatAI._act_line(combat, id, c, line_id):
		return true
	if area_id != "" and WICombatAI._act_area(combat, id, c, area_id, foes):
		return true
	return false


# --- 3. ATTACK -------------------------------------------------------------

func _attack(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	if int(c[WIKeys.AP]) < WICombat.ATTACK_COST:
		return false
	for foe_v: Variant in foes:
		var foe := String(foe_v)
		if combat.in_weapon_range(id, foe):
			return combat.attack(foe)
	return false


# --- 4. POSITION -----------------------------------------------------------

## A reaching weapon steps OUT of contact before closing; a melee kit walks in
## and dashes only when the dash buys an attack this turn (`_should_dash`'s own
## contract). Both movement primitives come from `WICombatAI`.
func _position(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	var reach := maxi(1, int(c.get(WIKeys.WEAPON_RANGE, 1)))
	if reach > 1 and int(c[WIKeys.MOVE_POOL]) >= WICombat.MOVE_COST:
		for foe_v: Variant in foes:
			var foe := String(foe_v)
			if combat.is_adjacent(id, foe) and WICombatAI._step(combat, id, foe, false):
				return true
	var goal: Vector2i = combat.combatants[String(foes[0])][WIKeys.CELL]
	if int(c[WIKeys.MOVE_POOL]) >= WICombat.MOVE_COST:
		var dir := WICombatAI._path_step(combat, c[WIKeys.CELL], goal, reach)
		if dir == Vector2i.ZERO:
			return false
		return combat.move_active(dir)
	if WICombatAI._should_dash(combat, c, goal, reach, WICombat.ATTACK_COST):
		return combat.dash()
	return false


# --- shared predicates -----------------------------------------------------

## AP + MP + cooldown + once-per-fight + combat-context, all read through the
## engine's own predicates. `WICombatAI._can_afford` covers the first three;
## the last two are `use_skill`'s gates, tested here so a refusal never costs
## the turn (the GH#337 lesson: `take_turn` breaks on the first refused action).
func _castable(combat: WICombat, c: Dictionary, s: Dictionary) -> bool:
	if s.is_empty():
		return false
	if not (s.get(WIKeys.CONTEXTS, []) as Array).has("combat"):
		return false
	if int((s.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.WINDUP_ROUNDS, 0)) > 0:
		return false
	if combat.skill_spent(String(c[WIKeys.ID]), String(s.get(WIKeys.ID, ""))):
		return false
	return WICombatAI._can_afford(combat, c, s)


func _basic_attack_expected(combat: WICombat, id: String, c: Dictionary, foes: Array) -> float:
	if int(c[WIKeys.AP]) < WICombat.ATTACK_COST:
		return 0.0
	for foe_v: Variant in foes:
		var foe := String(foe_v)
		if combat.in_weapon_range(id, foe):
			return expected_damage(combat, c, combat.combatants[foe], 1.0, true)
	return 0.0


func _is_untargetable(combat: WICombat, id: String) -> bool:
	var statuses: Dictionary = combat.combatants[id].get("statuses", {})
	for status_id: String in statuses:
		if bool((statuses[status_id] as Dictionary).get("untargetable", false)):
			return true
	return false


## Mean HP a single hit removes, used ONLY to rank one action against another.
## It mirrors `WICombat._resolve_hit` -> `_deduct_hp`: hit chance, the
## str/int-halved base plus a weapon die, the melee-only damage_mod, the
## floor-at-1, then the target's flat per-hit damage_reduction. It is a
## comparison, not an effect -- no engine call is replaced by it, and
## `test_combat_policies.gd` pins it against thousands of real `_resolve_hit`
## rolls rather than against a re-reading of the formula. If it drifts, that
## test reds; do not "fix" it by copying new source in.
static func expected_damage(combat: WICombat, a: Dictionary, t: Dictionary, mult: float, melee: bool) -> float:
	var hit_chance: int = WICombat.BASE_HIT + int(a["hit_bonus"]) - int(t[WIKeys.STATS]["dex"]) / 4
	var p_hit := clampf(float(hit_chance) / 100.0, 0.0, 1.0)
	if p_hit <= 0.0:
		return 0.0
	var stat: int = int(a[WIKeys.STATS]["str"]) if melee else int(a[WIKeys.STATS]["int"])
	var die := maxi(1, int(a[WIKeys.WEAPON_DIE]))
	var reduction := int(t.get(WIKeys.DAMAGE_REDUCTION, 0))
	var total := 0.0
	# Exact over the die's faces rather than its mean: the engine truncates
	# `int((stat/2 + roll) * mult)` per face and then clamps at 1 and again
	# after DR, so averaging the faces first would misprice both floors.
	for face in range(1, die + 1):
		var base := int((stat / 2 + face) * mult)
		if melee:
			base += int(a.get(WIKeys.DAMAGE_MOD, 0))
		var damage := maxi(1, base)
		if reduction > 0:
			damage = maxi(1, damage - reduction)
		total += float(damage)
	return p_hit * total / float(die)
