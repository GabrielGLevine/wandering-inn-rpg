class_name WICombatBuild
extends RefCounted
## Pure combat-BUILD construction helpers: the ONE
## shared home for math that `wi_game.gd`'s `_build_player_combatant` and
## `tests/sim_combat_batch.gd`'s balance harness both need at combatant-build
## time. TRAP: hand-copying this math between the two is the scariest
## drift class -- the harness silently measuring a different game than
## shipped; keep it here, shared. Deliberately NOT on `wi_combat.gd` -- that
## class is the fight-resolution CONSUMER of a finished combatant dict, not
## the BUILDER; this file's functions run once, before a `WICombat` even
## exists. No autoloads, no instance state reads -- kit/records in, filtered
## kit or summed mods out.


## Filters a class kit down to what's fieldable with `weapon_family` equipped
## (the weapon gate, reusing the `weapon` tag): a skill carrying
## skills.json's `weapon` key requires an EXACT family match against the
## equipped weapon; a skill with no `weapon` key (every spell, every
## passive) always passes. `weapon_family` "" (no weapon item, or an
## uncatalogued item id) correctly fields untagged skills only -- unarmed
## fields base attack + untagged skills, never a weapon-tagged one.
## `skills_by_id` is the id-keyed skills.json lookup (`wi_game.gd`'s own
## `skills` instance dict, or the harness's equivalent id-keyed mirror).
static func weapon_gated_kit(kit: Array, weapon_family: String, skills_by_id: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in kit:
		var sk_id := String(raw)
		var rec: Dictionary = skills_by_id.get(sk_id, {})
		if not rec.has(WIKeys.WEAPON) or String(rec[WIKeys.WEAPON]) == weapon_family:
			out.append(sk_id)
	return out


## Sums the combat-build fields (`damage_mod`/`hp_mod`/`damage_reduction`) a
## weapon, an armor, and any number of accessories contribute (the three
## equipped accessory slots fold into the SAME three fields
## the weapon/armor already populate -- no new combat field, `wi_combat.gd`
## is untouched, it just reads whatever these end up being on the combatant
## dict). Every record is read tolerantly (`.get`, default 0) so an item
## missing one of these keys (every M7-era item, and every accessory until
## G2 ships real values) contributes 0 -- behaviorally inert until real data
## lands. `weapon`/`armor` may be `{}` (empty/unequipped slot); `accessories`
## may be an empty Array (no accessories equipped, or a caller that predates
## the accessory axis).
static func equipment_mods(weapon: Dictionary, armor: Dictionary, accessories: Array) -> Dictionary:
	var dmg_mod := int(weapon.get(WIKeys.DAMAGE_MOD, 0))
	var hp_mod := int(armor.get(WIKeys.HP_MOD, 0))
	var dmg_reduction := int(armor.get(WIKeys.DAMAGE_REDUCTION, 0))
	for acc: Dictionary in accessories:
		dmg_mod += int(acc.get(WIKeys.DAMAGE_MOD, 0))
		hp_mod += int(acc.get(WIKeys.HP_MOD, 0))
		dmg_reduction += int(acc.get(WIKeys.DAMAGE_REDUCTION, 0))
	return {WIKeys.DAMAGE_MOD: dmg_mod, WIKeys.HP_MOD: hp_mod, WIKeys.DAMAGE_REDUCTION: dmg_reduction}


## Issue #92 R3: folds every equipped accessory's `abilities` (a relic's
## combat-only skill grant, `[skill_id, ...]`) onto the ALREADY-weapon-gated
## kit -- called AFTER `weapon_gated_kit` above, never before (a granted
## ability is never itself weapon-gate-filtered; a relic's grant is
## unconditional on what's in the other hand). Deduped against the kit a
## relic re-grants a skill the wearer already knows is a harmless no-op, not
## a double entry. Combat-ONLY by construction: this never touches
## `player_skills`/`known_skills()` (both stay build-injection-blind, exactly
## like `weapon_gated_kit`/`equipment_mods` above) -- the grant lives and
## dies with the single `WICombat` instance this kit gets built for, so it
## can never leak into field skill availability, the journal's skills-by-
## class panel, or a save file (nothing here is a WIGame field). Every item
## missing `abilities` (every pre-#92 item) contributes nothing -- inert
## until a relic ships one.
static func fold_abilities(kit: Array, accessories: Array) -> Array:
	var out: Array = kit.duplicate()
	for acc: Dictionary in accessories:
		for raw: Variant in (acc.get(WIKeys.ABILITIES, []) as Array):
			var ability_id := String(raw)
			if not out.has(ability_id):
				out.append(ability_id)
	return out
