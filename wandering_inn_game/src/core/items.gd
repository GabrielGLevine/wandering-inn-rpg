class_name WIItems
extends RefCounted
## Issue #92 R1: the ONE consumable-use resolver. Maps an item's
## data/items.json `use_effect` field onto the EXISTING sim/combat resolver
## arms -- never a new effect-execution system of its own. Two use_effect
## shapes are sanctioned (the validator arm in tests/test_items.gd rejects
## anything else reaching a shipped item, and `resolve_use` itself simply
## refuses an unrecognized/context-mismatched shape rather than crashing):
##
##   {"heal": N} -- combat-ONLY (draughts). Resolves via
##   WISkillEffects' EXISTING "heal" arm (the second_wind/soothing_presence
##   precedent), self-targeted (a consumable is never an ally-heal today --
##   no shipped item needs it, and the synthetic skill dict below omits
##   `ally_target` on purpose), through a synthetic skill-shaped dict so the
##   real resolver never has to know its caller was an item rather than a
##   Skill. Flat 1 AP regardless of the item's own fields (there are none to
##   read -- items carry no ap_cost) -- `WICombat.use_skill`'s exact AP-spend
##   point, generalized. No MP, so quick_cast's discount never applies.
##
##   {"next_fight": {damage_mod/hp_mod/damage_reduction}} -- field-ONLY
##   (a cooked meal). No combat mutation at all: the buff dict rides straight
##   back to the caller, which is WIGame.use_item's job to stash on
##   `pending_meal` -- consumed at the VERY NEXT `start_combat` build
##   (`_build_player_combatant`'s existing equipment-mods merge point, the
##   `well_fed` +2 hp_mod precedent generalized from one hardcoded bonus to
##   any of the three build-injected mod keys, and ONE-SHOT instead of
##   persisting until sleep -- see that field's own doc comment on WIGame).
##
## PURITY: no autoload/Node reference. `combat` is the live WICombat
## instance (null when called from the field) -- the one piece of context
## this needs, injected exactly like WISkillEffects.resolve_active's own
## first param. Inventory consumption (`inventory.erase`), the ITEM_USED
## emission, and the visible toast/card stay OWNED by the caller
## (WIGame.use_item / WIGame.combat_use_item) -- this class only ever
## answers "did the effect resolve, and what happened."

## The flat AP cost every combat item-use spends, regardless of the item's
## own (nonexistent) ap_cost field -- see this file's doc comment above.
const FLAT_AP_COST := 1


## Resolves `item`'s use_effect against `combat` (null = field context).
## Returns {"ok": false} for any unresolved/mismatched/unaffordable attempt,
## or {"ok": true, ...} with a shape-specific extra key: "healed" (int, the
## REAL clamped HP delta) for a heal, "pending_meal" (Dictionary, the
## next_fight buff verbatim) for a meal. Callers never need to branch on
## use_effect's own keys themselves -- this is the one place that knows the
## mapping.
static func resolve_use(item: Dictionary, combat: WICombat) -> Dictionary:
	var effect: Dictionary = item.get(WIKeys.USE_EFFECT, {})
	if effect.has("heal"):
		return _resolve_heal_use(item, combat, effect)
	if effect.has("next_fight"):
		return _resolve_meal_use(combat, effect)
	return {"ok": false}


## Draughts: combat-only, self-targeted, flat FLAT_AP_COST AP -- reuses
## WISkillEffects' own "heal" resolver arm via a synthetic skill-shaped dict
## (the exact shape a real data/skills.json heal entry takes: id/ap_cost/
## mp_cost/effect). The synthetic id is the ITEM's id -- SKILL_RESOLVED fires
## with that id (an id `combat.skills` doesn't recognize), which every
## existing presentation consumer already treats as a safe no-flash/no-feed-
## line no-op (`combat.skills.has(...)` guards throughout combat_hud.gd/
## combat_screen.gd) -- the HP bar still updates live (`_capture_combatant_
## stats` reads combatants generically, not skill-keyed), and the caller's
## own ITEM_USED + toast is the real "you used X" surface (R1's mandated
## visible card).
static func _resolve_heal_use(item: Dictionary, combat: WICombat, effect: Dictionary) -> Dictionary:
	if combat == null or combat.finished:
		return {"ok": false}
	var actor_id := combat.get_active()
	if not bool(combat.combatants.get(actor_id, {}).get(WIKeys.ALIVE, false)):
		return {"ok": false}
	var a: Dictionary = combat.combatants[actor_id]
	if int(a.get(WIKeys.AP, 0)) < FLAT_AP_COST:
		return {"ok": false}
	var synthetic_skill := {
		WIKeys.ID: String(item.get(WIKeys.ID, "")),
		WIKeys.AP_COST: FLAT_AP_COST,
		WIKeys.MP_COST: 0,
		WIKeys.EFFECT: {WIKeys.TYPE: "heal", WIKeys.AMOUNT: int(effect["heal"])},
	}
	var before := int(a[WIKeys.HP])
	if not WISkillEffects.resolve_active(combat, actor_id, actor_id, synthetic_skill):
		return {"ok": false}
	var healed := int(combat.combatants[actor_id][WIKeys.HP]) - before
	return {"ok": true, "healed": healed}


## Cooking meals: field-only -- a live fight's combatant kit is already
## built (there is no "next fight" to bank one for mid-fight, and no
## standalone field HP to fold a bonus onto either). No combat mutation at
## all: the buff dict rides straight back to the caller verbatim.
static func _resolve_meal_use(combat: WICombat, effect: Dictionary) -> Dictionary:
	if combat != null:
		return {"ok": false}
	return {"ok": true, "pending_meal": (effect["next_fight"] as Dictionary).duplicate(true)}
