class_name WICombatBuild
extends RefCounted
## Pure combat-BUILD construction helpers (M-ARCH Task ARCH-2): the ONE
## shared home for math that `wi_game.gd`'s `_build_player_combatant` and
## `tests/sim_combat_batch.gd`'s balance harness both need at combatant-build
## time, previously hand-copied between the two (documented manual-sync
## mirrors since M7 Task E6 / M-GEAR Task G4 -- a consultant review flagged
## this drift class as the scariest kind: the harness silently measuring a
## different game than shipped). Deliberately NOT on `wi_combat.gd` -- that
## class is the fight-resolution CONSUMER of a finished combatant dict, not
## the BUILDER; this file's functions run once, before a `WICombat` even
## exists. No autoloads, no instance state reads -- kit/records in, filtered
## kit or summed mods out.


## Filters a class kit down to what's fieldable with `weapon_family` equipped
## (M7 §2 weapon gate, reusing the M6 T1 `weapon` tag): a skill carrying
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
		if not rec.has("weapon") or String(rec["weapon"]) == weapon_family:
			out.append(sk_id)
	return out


## Sums the combat-build fields (`damage_mod`/`hp_mod`/`damage_reduction`) a
## weapon, an armor, and any number of accessories contribute (M-GEAR Task
## G1/G4: the three equipped accessory slots fold into the SAME three fields
## the weapon/armor already populate -- no new combat field, `wi_combat.gd`
## is untouched, it just reads whatever these end up being on the combatant
## dict). Every record is read tolerantly (`.get`, default 0) so an item
## missing one of these keys (every M7-era item, and every accessory until
## G2 ships real values) contributes 0 -- behaviorally inert until real data
## lands. `weapon`/`armor` may be `{}` (empty/unequipped slot); `accessories`
## may be an empty Array (no accessories equipped, or a caller that predates
## the accessory axis).
static func equipment_mods(weapon: Dictionary, armor: Dictionary, accessories: Array) -> Dictionary:
	var dmg_mod := int(weapon.get("damage_mod", 0))
	var hp_mod := int(armor.get("hp_mod", 0))
	var dmg_reduction := int(armor.get("damage_reduction", 0))
	for acc: Dictionary in accessories:
		dmg_mod += int(acc.get("damage_mod", 0))
		hp_mod += int(acc.get("hp_mod", 0))
		dmg_reduction += int(acc.get("damage_reduction", 0))
	return {"damage_mod": dmg_mod, "hp_mod": hp_mod, "damage_reduction": dmg_reduction}
