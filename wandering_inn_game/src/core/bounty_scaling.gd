class_name WIBountyScaling
extends RefCounted

## Issue #163: rank-scaled repeatable cull encounters. THE one site for the
## bounded per-rank enemy steps -- WIGame.start_combat AND sim_combat_batch
## both route enemy cfgs through scale_enemy(), so the balance harness proves
## exactly what ships. Steps are FIXED by spec (a design constant, not a tuning
## knob -- cells are tuned by rank-appropriate BUILD pick, never by these).
## bronze = identity (the base combatant record); only silver/gold step up.
const STEPS := {
	"silver": {"hp_pct": 0.25, "damage_mod": 1},
	"gold": {"hp_pct": 0.50, "damage_mod": 2},
}


## Returns a rank-stepped copy of an enemy cfg. HP step = pct of the enemy's
## OWN base max_hp (20 + con + base hp_mod -- MIRROR of WICombat's max_hp
## formula; drift there needs this updated) folded back into hp_mod (the only
## additive cfg knob combat reads); damage step is flat. Bronze/unknown rank
## returns the cfg untouched. Mutates+returns the passed dict (call on a
## duplicate).
static func scale_enemy(cfg: Dictionary, rank: String) -> Dictionary:
	if not STEPS.has(rank):
		return cfg
	var step: Dictionary = STEPS[rank]
	var con := int((cfg.get(WIKeys.STATS, {}) as Dictionary).get("con", 0))
	var base_hp := 20 + con + int(cfg.get(WIKeys.HP_MOD, 0))
	cfg[WIKeys.HP_MOD] = int(cfg.get(WIKeys.HP_MOD, 0)) + int(round(float(base_hp) * float(step["hp_pct"])))
	cfg[WIKeys.DAMAGE_MOD] = int(cfg.get(WIKeys.DAMAGE_MOD, 0)) + int(step["damage_mod"])
	return cfg
