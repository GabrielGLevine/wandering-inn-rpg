extends SceneTree
## Balance authority: gated cells enforce bands; measured cells only report.
## Region tiers never scale to the player. Shards preserve global cell order
## and per-cell RNG, so their concatenated output must match an unsharded run.

const RUNS_PER_CELL := 100

## THE MAIN-QUEST BAND LADDER, in stop order, at the shared t4_spellsword14
## yardstick. Riverfarm -> Invrisil -> Pallass -> the seal; a HIGHER win rate
## means an EASIER stop, so the ladder must descend.
##
## GH#337 fix round. Until this milestone the ordering was carried implicitly by
## four strictly-disjoint windows, and the ladder's own comment said so. Then
## cooldowns tied rungs 1 and 2 at 0.92, their windows had to overlap, and the
## implicit contract quietly evaporated across the whole overlap: rung 2 could
## climb to 0.98 against rung 1's floor of 0.88 -- a full Invrisil-easier-than-
## Riverfarm inversion -- with both gates still green. That is precisely the
## failure the ladder exists to catch, so the ordering is now asserted DIRECTLY
## and no longer depends on the windows staying disjoint.
##
## LADDER_TIE is the width inside which two consecutive rungs are allowed to read
## equal. Anything beyond it in the wrong direction is an inversion and reddens.
## Restoring a real step never trips this: a bigger DESCENT is always legal.
##
## v0.18 W5: 0.05 -> 0.03. The wide band was authored FOR the collapsed step --
## rungs 1 and 2 read 0.92/0.92 and needed room to read equal without reddening.
## The step is back (0.92 / 0.84 / 0.69 / 0.61, gaps 0.08 / 0.15 / 0.08), so the
## slack it was bought with is no longer owed and the contract tightens back to
## catching a smaller inversion. Every gap clears 0.03 by 0.05 or more, and this
## harness is DETERMINISTIC (seeds 1..RUNS_PER_CELL, fixed) -- the only thing
## that can move a rung is a real data change, which is precisely what the gate
## is for. If a future wave has to let two rungs share a band again, widen this
## deliberately and say why, the way GH#337 did.
##
## #396 (2026-08-05): rung 1 is now the SOLO read of the Riverfarm capstone --
## `briar_collectors_deep_t5_sw14_solo`, renamed here with the cell it names,
## because the hollow stopped fielding an ally. The deep pair's retune was sized
## to keep this ladder's statement: 0.94 / 0.84 / 0.69 / 0.61, gaps 0.10 / 0.15 /
## 0.08 -- rung 1 climbs 0.02 and every gap still clears LADDER_TIE by 0.05+.
const LADDER_RUNGS := [
	"briar_collectors_deep_t5_sw14_solo",
	"hired_blades_t5_sw14_wilovan",
	"forge_calibration_golem_t5_sw14_solo",
	"seal_warden_t5_sw14_solo",
]
const LADDER_TIE := 0.03

var _cell_idx := -1
var _range_lo := -1
var _range_hi := -1
var _ladder_rates := {}

## GH#360 (a) — THE DIFFICULTY-TIER SWEEP HOOK, and it is deliberately a hook on
## this harness rather than a second 141-cell driver. The cells, the builds, the
## rosters and the per-family setup (allies, hp mods, companion boons, bounty
## scaling) all live here already; a parallel harness would have to clone every
## one of them and would drift from this file the first time a cell moved.
##
## `WI_DIFFICULTY_MULT=<float>` sets `WICombat.difficulty_damage_taken_mult` on
## EVERY fight this run builds — the same field the composition root sets from
## `WISettings.difficulty_damage_taken_mult` (0.75 Bronze / 1.0 Silver / 1.3
## Gold). Same seed discipline as an ordinary run: the knob scales damage dealt
## to the player's side and touches no RNG draw, so a tier leg replays the
## IDENTICAL fight shape and only the cost of a hit moves.
##
## UNSET = byte-identical to before this hook existed (the field defaults to 1.0
## and `_apply_difficulty` early-returns at 1.0, so even an explicit
## `WI_DIFFICULTY_MULT=1.0` leg is numerically identical -- `difficulty_tier_
## sweep.sh` proves that by diffing the x1.0 leg against a plain run).
##
## REPORT-ONLY, and structurally so: every gated band in this file is authored
## at Silver, so asserting them at 0.75/1.3 would just red the whole matrix.
## A tier leg therefore prints its FAIL lines as the REPORT it is and exits 0;
## the plain (env-unset) run is the only one that asserts, and it is unchanged.
var _difficulty_mult := 1.0
var _tier_sweep := false

## #437 (b) — THE POLICY HOOK, the tier hook's exact twin and for the same
## reason: the cells, builds, rosters and per-family setup all live here, so a
## second driver would clone all of them and drift.
##
## `WI_POLICY=competent` swaps the PC's turn driver from today's autoplay
## (`WICombatAI`, the melee profile that never casts, never drinks and never
## uses [Second Wind]) to `qa/combat_policies.gd`'s competent policy. Enemies
## and allies are untouched in BOTH legs — the gap this measures is PC-side kit
## handling, not enemy AI.
##
## UNSET = byte-identical to before this hook existed: the default policy is
## `dumb`, and `WICombatPolicies.take_turn` on `dumb` is a straight delegation
## to `WICombatAI.take_turn`, the call that used to sit at each of these twelve
## sites. `tests/test_combat_policies.gd` pins that equivalence over seeded
## fights rather than trusting the delegation by eye.
##
## REPORT-ONLY, structurally, exactly like the tier sweep: every band in this
## file was authored against the floor policy, so asserting them against a
## policy that spends the kit would red the matrix wholesale. A competent leg
## prints its FAIL lines as the report they are and exits 0. The plain
## (env-unset) run is the only one that asserts, and it is unchanged. Balance
## AT band is proven by `tests/sim_spine_viability.gd`, not here.
##
## The matrix has no inventory model, so a competent leg here carries NO
## draughts: it measures casting, [Second Wind] and reach discipline only. The
## draught column belongs to the viability table, whose rows know what the run
## was actually holding.
var _policy: WICombatPolicies = null
var _policy_sweep := false

func _take_turn(combat: WICombat) -> void:
	if _policy == null:
		WICombatAI.take_turn(combat)
		return
	_policy.take_turn(combat)


func _cell_in_range() -> bool:
	_cell_idx += 1
	if _range_lo < 0:
		return true
	return _cell_idx >= _range_lo and _cell_idx <= _range_hi


## THE one construction site for every fight in this file, so the tier hook is
## applied once rather than at each of the eleven per-family loops.
func _new_combat(arena: Dictionary, cfgs: Array, skills_cfg: Dictionary, sink: Callable, rng_seed: int) -> WICombat:
	var combat := WICombat.new(arena, cfgs, skills_cfg, sink, rng_seed)
	combat.difficulty_damage_taken_mult = _difficulty_mult
	return combat


func _note_ladder(cell: Dictionary, win_rate: float) -> void:
	var name := String(cell["name"])
	if LADDER_RUNGS.has(name):
		_ladder_rates[name] = win_rate

const COMPOSITIONS := [
	{"name": "goblin_ambush", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"]},
	{"name": "chieftains_raid", "arena": "cave_mouth", "enemies": ["goblin_chieftain", "goblin_raider", "cave_spider"]},
]

const LOADOUT_CELLS := [
	{"name": "warrior2_sword", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": ""},
	{"name": "warrior2_spear", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "relcs_spare_spear", "armor": ""},
	{"name": "warrior2_sword_armored", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin"},
	{"name": "warrior1_tutorial_solo_armored", "comp": "goblin_ambush", "build": "warrior1_tutorial_solo", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin"},
	{"name": "warrior2_mage2_gambeson", "comp": "chieftains_raid", "build": "warrior2_mage2", WIKeys.WEAPON: "rusty_sword", "armor": "watch_issue_gambeson"},
	{"name": "warrior2_max_legal_kit", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin", "accessories": ["copper_luck_band", "hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "warrior1_tutorial_solo_max_legal_kit", "comp": "goblin_ambush", "build": "warrior1_tutorial_solo", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin", "accessories": ["copper_luck_band", "hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "warrior2_mage2_stonescale_dr2", "comp": "chieftains_raid", "build": "warrior2_mage2", WIKeys.WEAPON: "rusty_sword", "armor": "watch_issue_gambeson", "accessories": ["stonescale_talisman"]},
	{"name": "chieftains_hp_stack", "comp": "chieftains_raid", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["phosphor_pendant", "hedge_ward_charm"]},
	{"name": "moon_bone_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["moon_bone_amulet"]},
	{"name": "construct_core_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["construct_core_shard"]},
	{"name": "kingslayer_fang_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["kingslayer_fang"]},
	{"name": "hollow_herb_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["hollow_herb_sachet"]},
	{"name": "guardian_ward_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["guardian_ward_fragment"]},
	{"name": "moonhide_fetish_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["moonhide_fetish"]},
	# #398 P1 review M4: the pond seal was a stat-clone of warded_coil_charm, so it
	# moved onto flat damage_reduction with NO hp_mod -- the one axis the accessory
	# pool leaves open. Measured here for the same reason every other unique
	# accessory above is: a DR carrier changes outcomes when it is worn.
	{"name": "pond_seal_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["pond_survey_seal"]},
]

const ENCOUNTER_CELLS := [
	{"name": "shield_spiders_w2_relc", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": false},
	{"name": "shield_spiders_w2_klbkch", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": false, "ally": "klbkch"},
	{"name": "shield_spiders_w2_solo", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": true},
	{"name": "shield_spiders_w1_solo", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior1_tutorial", "solo": true},
	{"name": "sewer_vermin_w2_solo", "arena": "sewers_nest", "enemies": ["sewer_vermin", "sewer_vermin"], "build": "warrior2", "solo": true},
	{"name": "raskghar_scouts_w2_relc", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": false},
	{"name": "raskghar_scouts_w2_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": true},
	{"name": "raskghar_scouts_w5_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior5_mage5", "solo": true},
	# #398-p2 collapsed-gallery stop: three Shield Spiders are +4 power over
	# the shipped two-spider sewer nest. At the deep-tunnels build it measures
	# 0.61 wins / 4 median rounds, inside the standard 0.55-0.95 / 3-12 gate.
	{"name": "collapsed_gallery_nest_w10_solo", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider", "shield_spider"], "build": "warrior5_mage5", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "crate_scavengers_w1_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "warrior1_tutorial", "solo": true},
	{"name": "crate_scavengers_w1_klbkch", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "warrior1_tutorial", "solo": false, "ally": "klbkch"},
	{"name": "supplier_scavengers_w1_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "warrior1_tutorial", "solo": true},
	{"name": "rock_crab_nest_t1_relc", "arena": "boulder_flats", "enemies": ["rock_crab"], "build": "warrior2", "solo": false, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	# MEASURED-ONLY, and GH#337 moved it hard the other way: 0.18 -> 0.03. This is
	# the cell that states "do not solo a rock crab at warrior2", and the statement
	# got louder, not quieter -- but it is the clearest reading of the trade's
	# player-NEGATIVE side and belongs on the record rather than only in a log.
	# rock_crab carries damage_reduction, which `_apply_damage_reduction` subtracts
	# PER HIT, so halving power_strike's cadence makes the solo warrior pay the
	# shell twice per round instead of once (the DR-4 forge golem is the same case
	# at the top of the game). The two other double-digit measured movers are the
	# mirror image of it -- alley_footpads_w1_tutorial_solo 0.11 -> 0.22 and
	# hired_blades_t3_spellsword9_wilovan 0.63 -> 0.75, both against DR-0 rosters.
	# Left MEASURED on purpose: gating an intentional do-not-fight-this cell would
	# force it into a window that contradicts what it exists to say.
	{"name": "rock_crab_nest_t1_solo", "arena": "boulder_flats", "enemies": ["rock_crab"], "build": "warrior2", "solo": true},
	{"name": "goblin_night_patrol_t1_relc", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "build": "warrior2", "solo": false},
	{"name": "goblin_night_patrol_t1_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "build": "warrior2", "solo": true},
	# b1 #199: the betrayal close of rags_meeting — gate-era player (post-errand,
	# conduct-clean ≈ warrior2) solo vs Rags (coward, flees low) + 2 raiders.
	{"name": "rags_scouting_party_t1_solo", "arena": "goblin_ambush", "enemies": ["rags", "goblin_raider"], "build": "warrior2", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	# Necromancer dual-class cells (#131): measured 0.57 / 0.72 at authoring (100 seeds).
	# Builds are matrix:false (dual-class is the in-model shape; solo pure necro is unreachable
	# -- class requires holding [Mage]); "solo" here on the CELL strips Relc, deliberate.
	{"name": "mage3_necromancer3_goblin_ambush_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "build": "mage3_necromancer3_caster", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "mage5_necromancer7_raskghar_scouts_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "mage5_necromancer7_caster", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	# Wave-B companion cells (#132): these are the two shipped dual-necromancer
	# builds with an active Raised Skeleton. Both are GATED at 0.55-0.95 wins
	# and 3-12 median rounds. At authoring over 100 seeds they measured 0.62/4
	# and 0.92/3 (win rate/median rounds), after selecting only the encounter
	# composition; combatant stats remained fixed.
	{"name": "mage3_necromancer3_goblin_ambush_with_skeleton", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider", "goblin_shaman"], "build": "mage3_necromancer3_caster", "ally": "skeleton_ally", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "mage5_necromancer7_raskghar_scouts_with_skeleton", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "mage5_necromancer7_caster", "ally": "skeleton_ally", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	# Wave-D-2 companion cells (#156): [Beast Tamer] with the tamed wolf
	# (companion_boons mirrors the roster-inject boon path), [Beast Master]
	# with wolf + [Pack Bond], and a consolidated [Druid] dual-kit build.
	# All GATED 0.55-0.95 / 3-12 rounds; cell-selection-only tuning. Measured
	# at authoring (100 seeds): 0.87/4, 0.90/4, 0.90/4 -- the tamer cell dropped
	# the shaman (0.36 with it: bolts eat the wolf), the druid cell took a third
	# scout (1.00 at two).
	{"name": "beast_tamer5_goblin_ambush_with_wolf", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "beast_tamer5_melee", "ally": "wolf_companion", "companion_boons": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "beast_master10_raskghar_scouts_with_wolf", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "beast_master10_melee", "ally": "wolf_companion", "companion_boons": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "druid14_raskghar_scouts_with_wolf", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout", "raskghar_scout"], "build": "druid14_caster", "ally": "wolf_companion", "companion_boons": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	# v0.16 F1 (#308): the camp-ground press, the first goblin-ALLY fight.
	# The harness fields ONE ally per cell; the shipped encounter fields TWO,
	# so both cells measure a strictly HARDER field than a player ever sees.
	# Window is the shipped stop-cell precedent (0.55-0.95 + the 3-12 round
	# gate), at warrior2, the build the region's gates open at. The measured
	# medians -- not this window -- are what place these fights in the
	# Floodplains band; they are recorded in the PR body (RULING A).
	{"name": "camp_ground_press_t1_rags_ally", "arena": "boulder_flats", "enemies": ["plains_scavenger_a", "plains_scavenger_b", "plains_scavenger_lead"], "build": "warrior2", "ally": "rags_ally", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "camp_ground_press_t1_spear_ally", "arena": "boulder_flats", "enemies": ["plains_scavenger_a", "plains_scavenger_b", "plains_scavenger_lead"], "build": "warrior2", "ally": "goblin_spear_ally", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	# #398 P1 pond-island encounter cells. Both solo -- the map entity fields no
	# ally. TWO cells because a skill-gated pocket has TWO different populations
	# and only one of them can own a band (region-tiers.md "Gated vs.
	# measured-only"): the region yardstick is warrior2, but warrior2 CANNOT
	# REACH this island -- neither a freezes carrier nor [Double Step] is in its
	# kit -- so gating the yardstick cell would contract a band to a build that
	# never arrives. The yardstick cell therefore stays MEASURED, in the
	# rock_crab_nest_t1_solo shape ("do not solo this at warrior2"), and the
	# GATING AUTHORITY is the entrant build that actually crosses.
	{"name": "pond_guardian_t1_warrior2_solo", "arena": "boulder_flats", "enemies": ["pond_guardian"], "build": "warrior2", "solo": true},
	# The gate class made honest: [Double Step] arrives at Runner 5
	# (completed_delivery 10, classes.json), and a player who ran ten deliveries
	# on the Floodplains holds a combat class too -- warrior 5 is the same
	# melee_hit-18 kit both #398 P1 mode fixtures field, so this cell IS the
	# build the mode-B canonical plays. Tune combatant data only.
	{"name": "pond_guardian_t1_runner5_warrior5_solo", "arena": "boulder_flats", "enemies": ["pond_guardian"], "build": "t1_runner5_warrior5", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
]

const BOSS_CELLS := [
	# GH#337 re-author (0.62 -> 0.57, window 0.60-0.75 -> 0.50-0.66). MOVED
	# INTENTIONALLY. The Awakened carries no power_strike, so nothing on the
	# enemy side cooled -- the whole delta is the PC's own big hit dropping to
	# every-other-round against a con-30 boss whose HP pool outlasts the
	# alternation. A boss getting modestly harder is the direction this
	# milestone should push, so the window is re-centred rather than the trade
	# compensated. Width held at 0.16, margins 0.07/0.09.
	{"name": "awakened_boss_w2_relc", "arena": "deep_warren", "enemies": ["raskghar_awakened", "raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": false, "win_lo": 0.5, "win_hi": 0.66},
	{"name": "awakened_boss_w2_solo", "arena": "deep_warren", "enemies": ["raskghar_awakened", "raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": true},
]

const RUIN_CELLS := [
	{"name": "rift_vermin_leak_w8_relc", "arena": "inn_cellar", "enemies": ["rift_vermin_a", "rift_vermin_b", "rift_vermin_c"], "build": "warrior5_mage5", "solo": false, "win_lo": 0.55, "win_hi": 0.95},
	{"name": "rift_vermin_leak_w8_solo", "arena": "inn_cellar", "enemies": ["rift_vermin_a", "rift_vermin_b", "rift_vermin_c"], "build": "warrior5_mage5", "solo": true},
	{"name": "ruin_guardian_w8_relc", "arena": "ruin_court", "enemies": ["ruin_guardian", "ruin_ward_a", "ruin_ward_b"], "build": "warrior5_mage5", "solo": false, "win_lo": 0.55, "win_hi": 0.8},
	# TRAP: MEASURED-only (0.13), and NAMED in difficulty_tier_report.py's
	# EXTREME_FLIP_WHITELIST (Gold takes it to 0.00). Same rule as
	# alley_fence_t3_warrior10_solo: retune or rename moves both or the tier
	# gate reds.
	{"name": "ruin_guardian_w8_solo", "arena": "ruin_court", "enemies": ["ruin_guardian", "ruin_ward_a", "ruin_ward_b"], "build": "warrior5_mage5", "solo": true},
	# #398 P5's +3-band pocket -- BOTH modes open the same field, so both routes
	# are measured here. Review M4 reset all four numbers; the two dispositions
	# below are deliberately DIFFERENT and the reason is this file's own doctrine.
	#
	# THE WARRIOR CELL IS THE GATED ONE, because it is the only REACHABLE one.
	# `WICombatAI._act_once` defaults the PC's empty "ai" to the melee profile, so
	# a real player's PC never casts under autoplay -- the blade route is what an
	# actual run fights this pocket with. Measured 2026-08-07: 0.84 wins / median
	# 4 rounds (min 3, max 6), inside the standard 0.55-0.95 / 3-12 gate with
	# margin at BOTH ends. It was authored at 0.95 -- exactly ON the ceiling, zero
	# headroom, a red waiting for any unrelated drift -- which is what review M4
	# caught. The 0.11 of ceiling margin is the fix; the band stays the file-wide
	# standard rather than a bespoke tight one, so a sibling lane's tuning reds it
	# for a real reason and not for being 0.01 off a hand-picked number.
	#
	# WHAT MOVED to get there: both wards gained `power_strike` and NOTHING ELSE
	# (no stat, die, or arena edit). They were pure basic-attackers, so a tanky
	# warrior simply out-attritioned two big HP pools -- 0.95 was the absence of a
	# threat, not a tuned number. `_act_guard` honors power_strike natively (same
	# `_power_strike_ready` branch `_act_melee` uses) and the region's own
	# `ruin_guardian` line already fights with burst, so this is the region's
	# existing shape rather than a new mechanic. Measured sensitivity, for whoever
	# retunes next: ward DAMAGE is the wrong lever -- +1 die on both moved the
	# warrior 0.95->0.93 but the caster 0.70->0.64, and +16 con moved the warrior
	# to 0.93 while dropping the caster to 0.53. Every buff costs the fragile
	# build ~3x what it costs the durable one; only the burst branch moved the
	# warrior alone.
	{"name": "briar_arch_wards_warrior11_relc", "arena": "ruin_court", "enemies": ["briar_arch_ward_a", "briar_arch_ward_b"], "build": "p5_warrior11", "solo": false, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	# THE CASTER CELL IS MEASURED-ONLY, matching every other caster-profile build
	# in this file (`warrior2_mage2_caster`, `pure_mage10_caster`,
	# `warrior5_mage5_caster` all carry `gated: false`). The caster profile is a
	# MEASUREMENT AXIS, not a play configuration -- see the autoplay note above --
	# so a win-rate gate on it fences something no player can reach. It shipped
	# GATED, and that was the binding constraint that made the wards untunable:
	# every ward buff that moved the warrior off its ceiling pushed this cell
	# toward 0.55, so the pocket was pinned between a false floor and a real
	# ceiling. Measured 2026-08-07: 0.65 wins / median 4 (min 3, max 5) -- still
	# comfortably above the standard floor it is no longer held to.
	# The residual 19-point blade-vs-caster spread (0.84 vs 0.65) is archetype
	# variance at a fixed level, NOT a pocket defect: it is the same confound
	# sim_class_parity.gd refuses to gate whole-band spread over. Recorded, not
	# tuned to zero -- forcing them equal means tuning the wards against a build
	# no run fights them with.
	{"name": "briar_arch_wards_mage11_relc", "arena": "ruin_court", "enemies": ["briar_arch_ward_a", "briar_arch_ward_b"], "build": "p5_mage11_caster", "solo": false},
	# Review M3: the ally-less pair. briar_arch_wards carries `ally_requires:
	# {met_relc: 1}`, so a run that never met Relc fights this pocket SOLO -- a
	# real reachable configuration with no cell until now. MEASURED-UNGATED, the
	# `ruin_guardian_w8_solo` disposition for exactly the same reason: this region
	# tier is authored around the ally, and its shipped power-8 stop already
	# measures 0.13 solo. Gating these would either ratify a near-unwinnable band
	# or force the ally fight to be trivial. They exist so a future tune cannot
	# move the solo floor silently. Measured 2026-08-07: warrior 0.57 / caster
	# 0.38, both median 4. Note the warrior solo leg is genuinely WINNABLE, unlike
	# the power-8 stop's 0.13 -- but 0.57 sits 0.02 off the standard floor, which
	# is the same zero-margin mistake review M4 just fixed at the other end, so it
	# stays measured rather than ratified into a band it barely clears.
	{"name": "briar_arch_wards_warrior11_solo", "arena": "ruin_court", "enemies": ["briar_arch_ward_a", "briar_arch_ward_b"], "build": "p5_warrior11", "solo": true},
	{"name": "briar_arch_wards_mage11_solo", "arena": "ruin_court", "enemies": ["briar_arch_ward_a", "briar_arch_ward_b"], "build": "p5_mage11_caster", "solo": true},
]

const RIVERFARM_CELLS := [
	# THE HOLLOW'S BRIAR FIGHTS ARE SOLO. witch_hollow.json fields no ally for
	# briar_collectors / briar_collectors_deep, so every `_hunter` briar cell is
	# DELETED rather than re-banded: a with-ally read measures a field NO cohort
	# can bring, legacy hunter_will_come saves included (that counter fields the
	# shepherd at river_wolf_pack, in the village, only). The solo cells hold the
	# gates, and BOTH pairs were retuned to stay viable alone -- LEVERS AND
	# ARGUMENT LIVE HERE (combatants.json's `_comment`s carry a pointer + the
	# numbers only, for the data-comment census):
	#   shallow briar_collector_a/_b: con 30 -> 24 both, weapon_die untouched.
	#     t3_warrior10 solo 0.33 -> 0.69. con alone was lever enough.
	#   deep briar_collector_deep_a/_b: CUT ON BOTH AXES -- con 34/36 -> 25/27 AND
	#     weapon_die 7/6 -> 4/3. con first per the retune rule, but it is a weak
	#     lever here (-6 each bought +0.07), so weapon_die carries the rest.
	#     t3_warrior10 solo 0.22 -> 0.63, warrior5_mage5 solo 0.01 -> 0.28.
	#     NOT heirloom_fence + fence_doorman's tanky/low-per-hit shape: that pair
	#     is con 40/48 at ~5.0/7.5 mean damage a swing (str/2 + 1d(weapon_die)),
	#     this one con 25/27 at ~10.5/10.0. Shared: only a's one-big-skill.
	# power_level UNTOUCHED on all four (8.0 / 9.5): the retune moved the party
	# size these fights are authored against, not their place in the region, and
	# power_level is WICombatBanking's enemy-party XP weight for the latter.
	# The two w10 (warrior5_mage5) solo cells stay MEASURED off-build baselines,
	# per region-tiers.md's off-tier-baseline rule.
	{"name": "briar_collectors_w10_solo", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "warrior5_mage5", "solo": true},
	# The shallow briar stop at Riverfarm's own expected level (10), SOLO. Window
	# is the thicket-solo precedent (riverfarm_thicket_patch_t3_solo, 0.55-0.95)
	# which this cell now shares roster-tier, build and party shape with, and it
	# carries NO check_rounds for that cell's own documented reason: this
	# roster/build/shape lands median 2 solo, so a 3-12 bar would red on the
	# shipped numbers. Measured 0.69 after the con 30 -> 24 retune (0.33 solo
	# before it, 0.91 with the retired ally), margins 0.14/0.26.
	{"name": "briar_collectors_t3_warrior10_solo", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.95},
	{"name": "briar_collectors_deep_w10_solo", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "warrior5_mage5", "solo": true},
	# RIVERFARM'S STOP CELL (its own expected level, 10) -- SOLO, and the gate
	# blight_lifted's fight route lives or dies by. Band is the measured 0.63 +/-
	# 0.07, the retune-rule envelope worded by the #396 PLAN (Task 6 Step 3), NOT
	# by the spec. check_rounds ON: median 3 carries 60% of the histogram, so the
	# 3-12 bar is a real check here (contrast the t5 rung below).
	# The deleted with-ally twin (briar_collectors_deep_t3_warrior10_hunter,
	# 0.78-0.92) read 0.22 solo at this build, which closed the fight route and
	# fired the retune rule. Its history's still-live mechanism note:
	# GH#337 re-authored it 0.79 -> 0.85 / 0.72-0.85 -> 0.78-0.92 because 0.85 sat
	# exactly ON the old ceiling, and the mechanism was cooldowns turning
	# briar_collector_deep_a's one power_strike into two ordinary swings while the
	# PC's per-HIT damage_mod (knife +1, fang talisman +1) profits twice.
	# THE T3 STOP-PAIR DISJOINT-WINDOW CONTRACT IS RETIRED BY THIS CHANGE, not
	# broken: it paired this cell against hired_blades_t3_warrior10_wilovan to
	# order Riverfarm under Invrisil at the on-level build, and that comparison
	# assumed both stops field an ally. Riverfarm's no longer does, so the two are
	# no longer the same measurement and their windows now coincide (0.56-0.70
	# each) instead of being disjoint. Region ordering is carried where it is
	# actually asserted -- LADDER_RUNGS at the top of this file, where rung 1 (this
	# fight at t5_sw14, solo) reads 0.94 over Invrisil's 0.84.
	{"name": "briar_collectors_deep_t3_warrior10_solo", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "t3_warrior10", "solo": true, "win_lo": 0.56, "win_hi": 0.70, "check_rounds": true},
	{"name": "river_wolf_pack_t3_hunter", "arena": "village_edge_night", "enemies": ["river_wolf_a", "river_wolf_b", "river_wolf_c"], "build": "t3_warrior10", "solo": false},
	{"name": "river_wolf_pack_t3_solo", "arena": "village_edge_night", "enemies": ["river_wolf_a", "river_wolf_b", "river_wolf_c"], "build": "t3_warrior10", "solo": true},
	{"name": "riverfarm_thicket_patch_t3_solo", "arena": "witch_hollow", "enemies": ["thicket_remnant_a", "thicket_remnant_b"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.95},
	# v0.16 #305: the two new Riverfarm side-quest fights, both SOLO (neither
	# encounter fields the hunter -- the granary is inside the mill and the den
	# is the FIGHT alternative to walking the line with him). Same stats as
	# thicket_remnant and the SAME WINDOW as the stop cell above (0.55-0.95):
	# these are stop-band cells, not ladder rungs, and the rungs' narrow
	# windows exist only to keep four ordered rungs disjoint. At 100 runs per
	# cell sigma is ~0.04, so a rung-width window here would false-red on noise.
	# Region-band ORDERING is evidenced by the measured medians recorded in the
	# PR body, not by the gate. If a run lands outside 0.55-0.95, move the DATA
	# (con/weapon_die), never the window.
	# NO check_rounds, for the same reason the stop cell above carries none: this
	# roster/build/shape lands median 2 (measured, 100 runs), so the 3-12 rounds
	# bar would red on the SHIPPED numbers these rigs clone verbatim.
	# THE RULE FOR RIVERFARM_CELLS: check_rounds only where the median has clear
	# mass separation -- briar_collectors_deep_t3_warrior10_solo keeps it at 60%
	# of runs on 3. The counterexample that set the rule is
	# briar_collectors_deep_t5_sw14_solo, whose histogram {2:48, 3:50, 4:2} is a
	# two-run coin flip on the median: its bar was DROPPED rather than defended.
	# Never move data to protect a rounds bar (ruling 2).
	{"name": "granary_scavengers_t3_warrior10_solo", "arena": "inn_cellar", "enemies": ["granary_scavenger_a", "granary_scavenger_b"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.95},
	{"name": "thicket_line_den_t3_warrior10_solo", "arena": "witch_hollow", "enemies": ["line_stalker_a", "line_stalker_b"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.95},
	# MAIN-LINE BAND LADDER rung 1 of 4 (Phase 9, 2026-07-27). The four rungs
	# share ONE yardstick -- t4_spellsword14_party against the stop's AS-SHIPPED
	# roster -- so their win rates read as a single descending ladder. Riverfarm
	# is the FIRST stop and the LOWEST band. Ladder table + adjacent-pair proof:
	# docs/design/2026-07-26-main-quest-line-spec.md sec.6.
	# ORDERING IS ASSERTED DIRECTLY, by `LADDER_RUNGS`/`LADDER_TIE` at the bottom
	# of this file -- NOT, any more, by the windows happening to be disjoint. A
	# measured-only ladder could invert without reddening; the explicit gate is
	# what makes ordering itself an assertion, and it keeps holding when two rungs
	# have to share a band. That sharing is the state GH#337 (skill cooldowns) put
	# the ladder in: rungs 1 and 2 both read 0.92 afterwards and rung 2's old
	# window went red, which is the gate working.
	# v0.18 W5: THE FOURTH STEP IS RESTORED. hired_blade_leader's weapon_die went
	# 6 -> 8 (the compensation GH#337 identified but could not reach from the lane
	# that found it), Invrisil fell 0.92 -> 0.84, and the authored ladder is FOUR
	# steps again -- rung 1 .88-.98 / rung 2 .76-.90 / rung 3 .65-.76 / rung 4
	# .55-.64, measuring 0.92 > 0.84 > 0.69 > 0.61 with gaps 0.08 / 0.15 / 0.08.
	# THIS rung is unchanged by that work: Riverfarm is the first stop, its numbers
	# are the fixed reference the other three moved relative to, and the whole
	# repair was carried on Invrisil's side of the pair. Every window keeps >=0.03
	# margin on both sides of its authored value.
	# #396 (2026-08-05): THE RUNG WENT SOLO, `_hunter` -> `_solo` (and its name in
	# LADDER_RUNGS with it -- renaming a rung without that edit is its own FAIL).
	# It had to: the hollow fields no ally for any cohort now, so a with-ally rung
	# measures a fight nobody can bring, and the #396 solo retune of the deep pair
	# would have pushed the with-ally read to saturation (0.96 partway through the
	# retune, against a 0.98 ceiling) -- a false red waiting to happen. The retune
	# was SIZED so this rung's statement survives intact: solo reads 0.94 inside
	# the SAME 0.88-0.98 window (margins 0.06/0.04), the step over Invrisil's 0.84
	# widens 0.08 -> 0.10, and the ladder still descends 0.94 > 0.84 > 0.69 > 0.61.
	# NO check_rounds, dropped with the solo move: the histogram is {2:48, 3:50,
	# 4:2}, so the passing median 3 is TWO RUNS from being a 2 and the 3-12 bar
	# would red on an unrelated tune. Win rate is what this rung asserts; the
	# rounds bar in this region belongs to the stop cell above, whose median 3
	# carries 60% of its runs (see that comment for the rule).
	{"name": "briar_collectors_deep_t5_sw14_solo", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "t4_spellsword14_party", "solo": true, "win_lo": 0.88, "win_hi": 0.98},
]

const INVRISIL_CELLS := [
	# GH#337: 0.95 -> 0.96, ceiling 0.98 -> 0.99. A +0.01 move, but it landed on a
	# margin that was ALREADY only 0.03 before this milestone, so the ceiling is
	# lifted by exactly what the change consumed and no further -- the gate keeps
	# the same tolerance it was authored with rather than being widened to make
	# room. (Deliberately not re-centred: this cell's job is catching a collapse
	# of an intentionally-soft early alley fight, and its floor is what does that.)
	{"name": "alley_footpads_w2_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "warrior2", "solo": true, "win_lo": 0.75, "win_hi": 0.99},
	{"name": "alley_footpads_w1_tutorial_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "warrior1_tutorial", "solo": true},
	{"name": "alley_footpads_t3_spellsword9_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "t3_spellsword9", "solo": true},
	{"name": "alley_footpads_t3_warrior10_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "t3_warrior10", "solo": true},
	{"name": "hired_blades_w10_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "warrior5_mage5", "solo": false},
	{"name": "hired_blades_w10_solo", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "warrior5_mage5", "solo": true},
	{"name": "hired_blades_t3_spellsword9_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_spellsword9", "solo": false},
	{"name": "hired_blades_t3_warrior9_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_warrior9", "solo": false},
	# Invrisil's STOP cell (its own expected level, 10) -- the paired half of
	# Riverfarm's disjoint window; see that cell's comment.
	# GH#337 re-author (0.64 -> 0.70, window 0.57-0.71 -> 0.63-0.77). MOVED
	# INTENTIONALLY: 0.70 sat 0.01 under the old ceiling. Same mechanism as the
	# Riverfarm stop it is paired against (see that cell) plus a second term --
	# hired_blade_leader is the only enemy in the game holding BOTH power_strike
	# and counter_strike, so its cooled big hit turns into two ordinary swings
	# that each provoke the PC's own riposte.
	# v0.18 W5 RUNG-4 RESTORE (0.70 -> 0.63, window 0.63-0.77 -> 0.56-0.70).
	# MOVED INTENTIONALLY, and it is the COLLATERAL of the ladder repair rather
	# than a finding of its own: the captain's weapon_die went 6 -> 8 to give
	# rung 2 a real step back (see that cell), and this build meets the same
	# captain at its own expected level. The on-level build always pays a buff
	# harder than the over-levelled yardstick does -- it sits on the steeper
	# part of the curve -- and weapon_die was chosen over con precisely because
	# it costs this cell the LEAST per point of ladder movement (con +12 buys
	# -0.07 of rung and costs -0.14 here; weapon_die +2 buys -0.08 and costs
	# -0.07). Width held at 0.14, margins 0.07/0.07.
	# #396 (2026-08-05) UPDATE TO THIS COMMENT ONLY -- no number here moved: the
	# clause that used to sit here ("still DISJOINT AND ORDERED beneath Riverfarm's
	# own t3 pair, ceiling 0.70 < briar_collectors_deep_t3_warrior10_hunter's floor
	# 0.78") named a cell that no longer exists. Riverfarm's stop is fought SOLO
	# now, so the on-level stop-pair comparison lost its shared premise (both stops
	# fielding an ally) and is retired; the two windows coincide at 0.56-0.70
	# rather than being disjoint. The stop ORDERING is asserted where it always
	# really was, LADDER_RUNGS at the top of this file -- rung 1 (Riverfarm, solo)
	# 0.94 over rung 2 (this captain at the sw14 yardstick) 0.84.
	{"name": "hired_blades_t3_warrior10_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_warrior10", "solo": false, "win_lo": 0.56, "win_hi": 0.70, "check_rounds": true},
	{"name": "hired_blades_t3_spellsword9_solo", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_spellsword9", "solo": true},
	{"name": "hired_blades_t3_warrior10_solo", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_warrior10", "solo": true},
	{"name": "boulevard_night_footpads_t3_spellsword9_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "t3_spellsword9", "solo": true},
	{"name": "boulevard_night_footpads_t3_warrior10_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "t3_warrior10", "solo": true},
	# GH#337: 0.92 -> 0.93, ceiling 0.95 -> 0.96. Same treatment and same reason as
	# alley_footpads_w2_solo above -- a +0.01 move against a margin that was
	# already 0.03 at base, so the ceiling moves by the +0.01 the change spent and
	# nothing more. Neither knife carries power_strike, so what moved here is the
	# PC's own side of the trade, not the enemies'.
	{"name": "boulevard_duel_ring_t3_solo", "arena": "mercantile_alley", "enemies": ["hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.96},
	# MAIN-LINE BAND LADDER rung 2 of 4 (yardstick rung; see rung 1's comment for
	# the disjoint-window contract). The sw11 rung below is the SHARED-LEVEL
	# comparison against Pallass's own T4 cell (forge_calibration_golem_t4_solo)
	# -- adjacent stops are only ever compared at one build. The sw11 pair stays
	# MEASURED on purpose: the forge cell reads 0.49 there, and an under-band
	# value IS the evidence that Pallass sits a tier up. Gating it would force it
	# into 0.55-0.95 and destroy the thing it proves.
	# GH#337 re-author (0.82 -> 0.92, window 0.77-0.87 -> 0.86-0.98). THE ONE
	# STRUCTURAL FINDING OF THIS MILESTONE, and the harness caught it exactly as
	# rung 1's comment promised it would: the four-rung ladder is now THREE
	# steps, not four. Rung 1 (Riverfarm) reads 0.92 and this rung reads 0.92 --
	# statistically tied at 100 runs (sigma ~0.03). Cause is roster-shaped, not
	# authoring-shaped: hired_blade_leader holds power_strike AND counter_strike,
	# so cooling its big hit hands the sw14 party two riposte-provoking swings a
	# round instead of one, while Riverfarm's deep collectors (one power_strike,
	# no counter_strike) barely moved. Two compensations were MEASURED and both
	# rejected -- power_strike at 2 AP overshoots hard (8 gated cells red, the
	# forge rung jumps 0.69 -> 0.91) and mult 2.4 compresses rungs 3/4 into the
	# top pair instead (rung 3 0.69 -> 0.82). The step cannot be restored from
	# skills.json: the lever is hired_blade_leader's own con/weapon_die in
	# combatants.json, which this lane does not own. Logged as a SEAM. Until
	# then this window and rung 1's are deliberately the SAME BAND -- the honest
	# statement that Invrisil and Riverfarm now read equal at the yardstick.
	# THE ORDERING CONTRACT DID NOT GO WITH IT: overlapping these two windows
	# would have left rung 2 free to climb to 0.98 against rung 1's 0.88 with both
	# gates green, so `LADDER_RUNGS`/`LADDER_TIE` now assert rung-by-rung descent
	# directly (fix round). This pair is allowed to READ EQUAL inside the tie
	# band and nothing wider; {rung 1, rung 2} > rung 3 > rung 4 is asserted by
	# the same gate rather than inferred from window arithmetic.
	#
	# v0.18 W5: THE SEAM ABOVE IS NOW CLOSED AND THE FOURTH STEP IS BACK
	# (0.92 -> 0.84, window 0.86-0.98 -> 0.76-0.90). This lane owns
	# combatants.json, so the compensation GH#337 could only describe was
	# finally taken: hired_blade_leader's weapon_die 6 -> 8, con untouched. The
	# choice of lever is the whole point -- what GH#337 broke was the captain's
	# CADENCE (one big hit became two ordinary swings), so the number to move is
	# the ordinary swing, and the two rejected skills.json compensations are
	# still rejected for the same reasons recorded above. con was measured as
	# the alternative and rejected on collateral, not on feel: con +12 buys
	# -0.07 of rung and costs the on-level stop cell -0.14, while weapon_die +2
	# buys -0.08 and costs it -0.07. Ladder now reads 0.92 > 0.84 > 0.69 > 0.61,
	# four real steps of 0.08 / 0.15 / 0.08.
	# Window margins 0.08/0.06 -- deliberately NOT squeezed to 0.77-0.87 to
	# restore literal disjointness with rung 1 (0.88-0.98). A 0.03 ceiling
	# margin on a cell measuring 0.84 is a flaky gate, and disjointness is no
	# longer what carries ordering: `LADDER_RUNGS`/`LADDER_TIE` does, by
	# assertion, and that is the contract this restoration hands it back a real
	# step to defend.
	{"name": "hired_blades_t5_sw14_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t4_spellsword14_party", "solo": false, "win_lo": 0.76, "win_hi": 0.90, "check_rounds": true},
	{"name": "hired_blades_t4_sw11_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t4_spellsword11_party", "solo": false},
	# v0.16 I1 (#306). Side-quest fight at Invrisil's own expected level, SOLO
	# (Wilovan has no part in a stranger's commission). Window is the shipped
	# stop-cell precedent 0.55/0.95 (controller ruling A) -- a NARROW window is a
	# flaky gate, not a proof, so region-band ordering is evidenced by the
	# MEASURED median recorded in the PR body, not by the ceiling authored here.
	# New ids only: no shared combatant is retuned, so both hired_blades_* gates
	# and boulevard_duel_ring are untouched. Measured 0.67, median 3 (margins
	# 0.12/0.28). The pair was tuned to that number from the drafted stats: as
	# drafted they read 0.48 / median 2, so the fence trades damage for bulk
	# (str 6, weapon_die 3, con 40) and the doorman keeps the only real punch.
	# TRAP: this cell is NAMED in difficulty_tier_report.py's
	# EXTREME_FLIP_WHITELIST (Bronze saturates it to 1.00; ratified as the knob
	# working). Re-tuning or renaming it stales that entry and the tier gate goes
	# red -- move both together.
	{"name": "alley_fence_t3_warrior10_solo", "arena": "mercantile_alley", "enemies": ["heirloom_fence", "fence_doorman"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	# v0.16 I2 (#306). Interior brawl at Invrisil's expected level, SOLO. Same
	# window contract as the fence cell: the shipped stop-cell precedent
	# 0.55/0.95 (controller ruling A). Region-band ordering is evidenced by the
	# MEASURED median recorded in the PR body, not by a narrow authored ceiling.
	# Arena merchant_warehouse (biome inn) reused -- zero arenas.json edits.
	# Measured 0.78, median 3, as drafted -- no tuning needed. That sits ABOVE
	# the fence cell's 0.67 by construction: the brawl is a failure state, not a
	# target, so it is the softer of the two v0.16 Invrisil fights.
	# GH#337 re-author (0.78 -> 0.93, window 0.55-0.95 -> 0.85-0.99). MOVED
	# INTENTIONALLY, and this is the LARGEST single move in the 141-cell set
	# (+0.15), so it gets its own rationale rather than riding the milestone's
	# general note. Mechanism is the one the CHOICE-LOG names: rest_bravo_b holds
	# power_strike and carries damage_mod 0, while the t3_warrior10 build carries
	# +2 -- `_resolve_hit` adds damage_mod PER HIT, so cooling the bravo's big
	# swing into two ordinary ones is worth nothing to it and +2 a round to the
	# player. It is the cleanest case of the trade in the whole set because
	# neither bravo has counter_strike to muddy it. The window had to move too:
	# 0.93 sat 0.02 under the old ceiling, the same false-red-in-waiting the
	# Riverfarm stop was re-centred for.
	# THE DESIGN COST IS REAL AND IS NOT FIXED HERE: a failure-state brawl at the
	# player's own level is now a 93% formality, and the fence cell beside it also
	# climbed (0.67 -> 0.81, still mid-band). Restoring the brawl's teeth means
	# rest_bravo_a/b's own con/weapon_die in combatants.json, which this lane does
	# not own -- recorded as a seam, not silently absorbed. Margins 0.08/0.06.
	{"name": "rest_bravos_t3_warrior10_solo", "arena": "merchant_warehouse", "enemies": ["rest_bravo_a", "rest_bravo_b"], "build": "t3_warrior10", "solo": true, "win_lo": 0.85, "win_hi": 0.99, "check_rounds": true},
	# #398 P4 counting-room pocket. Both new combatants sit 2-3 levels above
	# Invrisil's 8-10 band; this is the shipped solo composition and arena.
	{"name": "counting_room_guard_t3_warrior10_solo", "arena": "mercantile_alley", "enemies": ["factor_enforcer", "factor_clerk_guard"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
]

const BUILDS := [
	{"name": "warrior1_tutorial", "classes": {"warrior": 1}, "gated": false},
	{"name": "warrior1_tutorial_solo", "classes": {"warrior": 1}, "gated": false, "solo": true},
	{"name": "classless_solo", "classes": {}, "gated": false, "solo": true},
	{"name": "warrior2", "classes": {"warrior": 2}, "ungated_comps": ["goblin_ambush"]},
	{"name": "warrior2_helper2", "classes": {"warrior": 2, "helper": 2}, "gated": false},
	{"name": "warrior2_mage2", "classes": {"warrior": 2, "mage": 2}, "gated": false},
	{"name": "warrior2_mage2_caster", "classes": {"warrior": 2, "mage": 2}, WIKeys.AI: "caster", "gated": false},
	{"name": "pure_warrior10", "classes": {"warrior": 10}, "gated": false},
	{"name": "pure_mage10_caster", "classes": {"mage": 10}, WIKeys.AI: "caster", "gated": false},
	{"name": "mage3_necromancer3_caster", "classes": {"mage": 3, "necromancer": 3}, WIKeys.AI: "caster", "matrix": false},
	{"name": "beast_tamer5_melee", "classes": {"beast_tamer": 5}, WIKeys.AI: "melee", "matrix": false},
	{"name": "beast_master10_melee", "classes": {"beast_master": 10}, WIKeys.AI: "melee", "matrix": false},
	{"name": "druid14_caster", "classes": {"druid": 14}, WIKeys.AI: "caster", "matrix": false},
	{"name": "mage5_necromancer7_caster", "classes": {"mage": 5, "necromancer": 7}, WIKeys.AI: "caster", "matrix": false},
	# #398 P1: the skill-gated pocket's ENTRANT build. matrix:false -- it exists
	# for the pond-island cell only, not as a new COMPOSITIONS column. Runner
	# contributes dex (stat_growth) and, at 5, [Double Step]; the fight itself is
	# carried by the warrior half, which is why this reads as a real T1-tail
	# melee build rather than a courier trying to punch a crab.
	{"name": "t1_runner5_warrior5", "classes": {"runner": 5, "warrior": 5}, "matrix": false},
	{"name": "warrior5_mage5", "classes": {"warrior": 5, "mage": 5}, "gated": false},
	{"name": "warrior5_mage5_caster", "classes": {"warrior": 5, "mage": 5}, WIKeys.AI: "caster", "gated": false},
	{"name": "t3_spellsword9", "classes": {"spellsword": 9}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "t3_warrior9", "classes": {"warrior": 9}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "t3_warrior10", "classes": {"warrior": 10}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "t4_spellsword11_party", "classes": {"spellsword": 11}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "t4_spellsword14_party", "classes": {"spellsword": 14}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "p5_mage11_caster", "classes": {"mage": 11}, WIKeys.AI: "caster", "matrix": false, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "p5_warrior11", "classes": {"warrior": 11}, WIKeys.AI: "melee", "matrix": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	# Second Wind wave (#165): terminal pure-line L14 solo builds. All
	# matrix:false (they run only in SECOND_WIND_CELLS, cell-selection-tuned --
	# never in the COMPOSITIONS matrix). Weapons gate the kit where the line is
	# weapon-based (sword/spear/bow); casters/passive lines carry none.
	{"name": "swordsman14", "classes": {"swordsman": 14}, WIKeys.AI: "melee", "matrix": false, WIKeys.WEAPON: "rusty_sword"},
	{"name": "spearmaster14", "classes": {"spearmaster": 14}, WIKeys.AI: "melee", "matrix": false, WIKeys.WEAPON: "relcs_spare_spear"},
	{"name": "ice_mage14", "classes": {"ice_mage": 14}, WIKeys.AI: "caster", "matrix": false},
	{"name": "fire_mage14", "classes": {"fire_mage": 14}, WIKeys.AI: "caster", "matrix": false},
	{"name": "sharpshooter14", "classes": {"sharpshooter": 14}, WIKeys.AI: "melee", "matrix": false, WIKeys.WEAPON: "hunting_bow"},
	{"name": "infiltrator14", "classes": {"infiltrator": 14}, WIKeys.AI: "melee", "matrix": false, WIKeys.WEAPON: "gnollish_hunting_knife"},
	{"name": "strategist14", "classes": {"strategist": 14}, WIKeys.AI: "melee", "matrix": false},
	{"name": "beast_master14", "classes": {"beast_master": 14}, WIKeys.AI: "melee", "matrix": false},
	# Issue #163: gold-rank build (spellsword16, effective_power 16.0 >= the gold
	# floor 10*2^(1/k)~=15.64). Runs ONLY in SCALED_CELLS (matrix:false). Silver
	# cells reuse t4_spellsword14_party (spellsword14, power 14.0, silver band).
	{"name": "gold_spellsword16", "classes": {"spellsword": 16}, "matrix": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	# Gold build for the T5 forge/market culls -- a gold player who reached
	# Pallass's forge tier runs deeper than the T4 gold build (both power 16.0+
	# clear the gold floor; the +50% T5 two-golem step needs the extra levels to
	# hold a 0.55-0.95 band). spellsword22 (line max), power 22.0.
	{"name": "gold_spellsword22", "classes": {"spellsword": 22}, "matrix": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
]

# Issue #163: rank-scaled cull encounters. Each scaled encounter x silver/gold
# is a GATED band against a RANK-APPROPRIATE build; enemies pass through THE one
# WIBountyScaling.scale_enemy site (proving exactly what wi_game.start_combat
# ships). Bronze cells are the pre-existing unscaled bands (BESTIARY/DUNGEON) --
# never duplicated here. `rank` = the scaling tier applied to every enemy cfg.
# SCALED SET = the two culls with no live QA loop fighting them (kingslayer_den
# / market_watchgolems were evaluated but their loops run at silver-rank
# spellsword11 fixtures that can't clear the scaled fight -- they stay unscaled
# until rank-aware loop fixtures land; see CHOICE-LOG 2026-07-18).
const SCALED_CELLS := [
	{"name": "gallery_vermin_nest_t4_silver", "arena": "trapped_halls_snare", "enemies": ["rift_vermin_a", "rift_vermin_c"], "build": "t4_spellsword14_party", "rank": "silver", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "gallery_vermin_nest_t4_gold", "arena": "trapped_halls_snare", "enemies": ["rift_vermin_a", "rift_vermin_c"], "build": "gold_spellsword16", "rank": "gold", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	# GH#337 re-author (0.56 -> 0.53, window 0.55-0.95 -> 0.45-0.85). MOVED
	# INTENTIONALLY, and this cell is the cleanest illustration of the trade's
	# ONE reliably player-negative case: forge_golem carries damage_reduction 4,
	# and `_apply_damage_reduction` subtracts it PER HIT, so replacing one x2
	# swing with two ordinary ones pays the golem's plating twice instead of
	# once. The gold sibling below (0.68 -> 0.70) is untouched -- a bigger
	# per-hit base absorbs the doubled reduction, which is exactly why only the
	# silver rank fell out. Width held at 0.40; margins 0.08/0.32.
	{"name": "forge_calibration_golem_t5_silver", "arena": "forge_hall", "enemies": ["forge_golem"], "build": "t4_spellsword14_party", "rank": "silver", "win_lo": 0.45, "win_hi": 0.85, "check_rounds": true},
	{"name": "forge_calibration_golem_t5_gold", "arena": "forge_hall", "enemies": ["forge_golem"], "build": "gold_spellsword22", "rank": "gold", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
]

const PARTY_CELLS := [
	{"name": "vault_construct_t4_party", "arena": "vault", "enemies": ["vault_construct"], "build": "t4_spellsword11_party", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "vault_construct_t4_party_guided", "arena": "vault", "enemies": ["vault_construct"], "build": "t4_spellsword11_party", "ally_hp_mods": {"ksmvr": -18}},
	{"name": "raskghar_awakened_t4_party", "arena": "deep_warren", "enemies": ["raskghar_awakened", "raskghar_scout", "raskghar_scout"], "build": "t4_spellsword11_party"},
	{"name": "vault_construct_t4_spellsword14_party", "arena": "vault", "enemies": ["vault_construct"], "build": "t4_spellsword14_party"},
]

const DUNGEON_CELLS := [
	# GH#337 re-author (0.62 -> 0.54, window 0.55-0.95 -> 0.45-0.85). MOVED
	# INTENTIONALLY: the standing 0.55-0.95 stop-cell window is a CONVENTION,
	# not a measurement, and its own rule is "move the data, never the window"
	# -- but the data here is combatants.json (snare_ward_a/b, the dedicated
	# clones that exist precisely to be tuned), which this lane does not own, so
	# the window moves and the alternative is recorded as a seam. The drop is
	# the solo half of the alternation trade: three foes with no power_strike
	# between them means nothing on the enemy side cooled, while the PC's own
	# big hit halved its cadence against a roster it has to out-focus. Width
	# held at 0.40 so the gate still catches both a collapse and a
	# trivialization; margins 0.09/0.31.
	{"name": "trapped_halls_snare_t4_solo", "arena": "trapped_halls_snare", "enemies": ["snare_ward_a", "snare_ward_b", "rift_vermin_c"], "build": "t4_spellsword11_party", "solo": true, "win_lo": 0.45, "win_hi": 0.85, "check_rounds": true},
	{"name": "gallery_vermin_nest_t4_solo", "arena": "trapped_halls_snare", "enemies": ["rift_vermin_a", "rift_vermin_c"], "build": "t4_spellsword11_party", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	# 2026-07-26 Act V: the seal's warden, the main line's top band (LADDER rung
	# 4 of 4; see RIVERFARM_CELLS' rung-1 comment). Gated at spellsword14 SOLO --
	# the fight is fought alone by design. Phase 9 (2026-07-27) re-swept every
	# band together and left the warden UNCHANGED: retuning the three stops
	# beneath it never pushed it out of 0.55-0.95, so the top band held.
	{"name": "seal_warden_t5_sw14_solo", "arena": "vault", "enemies": ["seal_warden"], "build": "t4_spellsword14_party", "solo": true, "win_lo": 0.55, "win_hi": 0.64, "check_rounds": true},
	# The warden at Pallass's T4 build: the shared-level rung proving the warden
	# sits a band ABOVE the forge golem, not merely later in the story.
	{"name": "seal_warden_t4_sw11_solo", "arena": "vault", "enemies": ["seal_warden"], "build": "t4_spellsword11_party", "solo": true},
	# --- #398-P3 pocket lane --- both disjoint access builds fight the same guard.
	# BANDS RE-MEASURED at the review (M8). The shipped pair carried the default
	# 0.55-0.95 on both cells and the swordsman measured EXACTLY 0.95: a band
	# whose upper edge IS the measurement is not an envelope, it is a red waiting
	# for the next tune. These are measured +/- 0.07 (the repo idiom), against
	# the re-tuned construct (ai melee, con 30 -- its combatants.json _comment
	# carries the four-profile measurement that forced the retune):
	#   swordsman14   win 0.93, median 3 rounds (min 2, max 4) -> 0.86-0.99
	#   infiltrator14 win 0.63, median 3 rounds (min 3, max 5) -> 0.56-0.70
	# The swordsman ceiling is clipped to 0.99 rather than 1.00 ON PURPOSE: a
	# flat 1.00 means the guard stopped being a fight, which is worth a red.
	# The ~0.30 spread between the cells is INHERENT to one shared guard fought
	# by two class-disjoint pure-L14 builds (infiltrator14's own bestiary cell is
	# two sewer_vermin; swordsman14's is three raskghar_scouts) -- the same
	# ai_kit confound this suite already refuses to gate whole-band, so the two
	# cells carry per-build envelopes rather than one common band.
	{"name": "side_vault_construct_t5_swordsman14_solo", "arena": "trapped_halls_snare", "enemies": ["side_vault_construct"], "build": "swordsman14", "solo": true, "win_lo": 0.86, "win_hi": 0.99, "check_rounds": true},
	{"name": "side_vault_construct_t5_infiltrator14_solo", "arena": "trapped_halls_snare", "enemies": ["side_vault_construct"], "build": "infiltrator14", "solo": true, "win_lo": 0.56, "win_hi": 0.70, "check_rounds": true},
]

const BESTIARY_CELLS := [
	{"name": "corusdeer_range_t1_solo", "arena": "boulder_flats", "enemies": ["corusdeer"], "build": "warrior2", "solo": true},
	{"name": "razorbeak_nest_t1_solo", "arena": "boulder_flats", "enemies": ["razorbeak_a", "razorbeak_b"], "build": "warrior2", "solo": true},
	{"name": "road_mothbears_t3_solo", "arena": "boulder_flats", "enemies": ["mothbear_a", "mothbear_b"], "build": "t3_warrior10", "solo": true},  # v0.16.1 #21: re-homed to the floodplains wagon road, so the cell now measures the arena the fight actually opens on
	{"name": "kingslayer_den_t4_solo", "arena": "spider_den", "enemies": ["kingslayer_spider"], "build": "t4_spellsword11_party", "solo": true},
	{"name": "forge_calibration_golem_t4_solo", "arena": "forge_hall", "enemies": ["forge_golem"], "build": "t4_spellsword11_party", "solo": true},
	# MAIN-LINE BAND LADDER rung 3 of 4 and Pallass's GATED stop cell (Phase 9,
	# 2026-07-27). The forge tier is where `lattice_forge_rune` banks, so the
	# forge golem -- not the market watchgolems -- is Pallass's band statement,
	# and spellsword14 is its expected level (the T5 permit tier, one tier past
	# pallass_watchgolem_loop_start's 11). The t4 cell ABOVE is the shared-level
	# rung against Invrisil's hired_blades_t4_sw11_wilovan.
	{"name": "forge_calibration_golem_t5_sw14_solo", "arena": "forge_hall", "enemies": ["forge_golem"], "build": "t4_spellsword14_party", "solo": true, "win_lo": 0.65, "win_hi": 0.76, "check_rounds": true},
	# v0.16 P1 (issue #307). Pallass's commission fight. Gated at the standing
	# 0.55-0.95 stop-cell window; the band claim -- measured strictly below the
	# shipped forge golem at the same build -- is carried by the medians
	# recorded in the PR body, not by the window.
	{"name": "forge_temper_golem_t5_sw14_solo", "arena": "forge_hall", "enemies": ["forge_temper_golem"], "build": "t4_spellsword14_party", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "market_watchgolems_t4_solo", "arena": "market_watch", "enemies": ["watchgolem_a", "watchgolem_b"], "build": "t4_spellsword11_party", "solo": true},
	{"name": "market_watchgolems_t5_sw14_solo", "arena": "market_watch", "enemies": ["watchgolem_a", "watchgolem_b"], "build": "t4_spellsword14_party", "solo": true},
]

# Second Wind wave (#165): the six combat-active pure lines at their L14 solo
# builds, GATED 0.55-0.95 / 3-12 rounds; strategist14 and beast_master14 (with
# the tamed wolf + companion boons incl. the PC-side [Sworn Fang] boon) are
# MEASURED only. Cell-selection tuning ONLY (enemy composition), never stats.
# Measured at authoring (100 seeds): swordsman 0.65/3, spearmaster 0.68/3,
# ice_mage 0.60/4, fire_mage 0.74/3, sharpshooter 0.76/4, infiltrator 0.65/4;
# strategist 0.77/3, beast_master14 0.63/5 (wolf_downed 0.45).
# AI=melee for sharpshooter14/strategist14 (NOT ranged): the sim has no dex/int
# ranged-AI damage path -- the ranged profile only fires int-based line/spell,
# never bow damage_mult, so a dex archer whiffs (0.00). melee AI mirrors how the
# PC actually autoplays. Caster builds (ice/fire mage) keep caster AI.
const SECOND_WIND_CELLS := [
	{"name": "swordsman14_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout", "raskghar_scout"], "build": "swordsman14", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "spearmaster14_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout", "goblin_raider"], "build": "spearmaster14", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "ice_mage14_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "sewer_vermin"], "build": "ice_mage14", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "fire_mage14_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "sewer_vermin"], "build": "fire_mage14", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "sharpshooter14_solo", "arena": "goblin_ambush", "enemies": ["sewer_vermin", "sewer_vermin"], "build": "sharpshooter14", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "infiltrator14_solo", "arena": "goblin_ambush", "enemies": ["sewer_vermin", "sewer_vermin"], "build": "infiltrator14", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "strategist14_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout"], "build": "strategist14"},
	{"name": "beast_master14_raskghar_scouts_with_wolf", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout", "raskghar_scout"], "build": "beast_master14", "ally": "wolf_companion", "companion_boons": true},
]


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _find_by_name(list: Array, value: String) -> Dictionary:
	for e: Dictionary in list:
		if String(e["name"]) == value:
			return e
	return {}


func _matrix_build_count() -> int:
	var count := 0
	for build: Dictionary in BUILDS:
		if bool(build.get("matrix", true)):
			count += 1
	return count


## STATIC since #437: `tests/sim_spine_viability.gd` preloads this script and
## assembles its roster's PCs through this exact function. A viability row and
## a matrix cell that name the same build must BE the same combatant, and the
## only way to guarantee that is one function. It reads no instance state.
static func _build_pc(build: Dictionary, pc_template: Dictionary, classes_catalog: Dictionary, skills_by_id: Dictionary, items_by_id: Dictionary) -> Dictionary:
	var pc: Dictionary = pc_template.duplicate(true)
	pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
	pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes_catalog)
	var kit: Array = WIProgression.granted_skills(build["classes"], classes_catalog)
	if build.has(WIKeys.WEAPON):
		var weapon: Dictionary = items_by_id.get(String(build[WIKeys.WEAPON]), {})
		var armor: Dictionary = items_by_id.get(String(build.get("armor", "")), {})
		var accessories: Array = []
		for acc_id_v: Variant in (build.get("accessories", []) as Array):
			accessories.append(items_by_id.get(String(acc_id_v), {}))
		pc[WIKeys.SKILLS] = WICombatBuild.weapon_gated_kit(kit, String(weapon.get("weapon_family", "")), skills_by_id)
		# Mirrors `wi_game.gd::_build_player_combatant` (line 2099). Threaded for
		# fidelity, and MEASURED to be inert rather than assumed to matter: the
		# full 141-cell matrix is byte-identical with and without this line
		# (2026-08-03 fix round; `sharpshooter14_solo`, this file's only bow
		# build, holds 0.76/median 4 either way). It cannot matter under
		# autoplay -- every `combat.attack()` call site in `WICombatAI` is
		# guarded by `combat.is_adjacent()` (combat_ai.gd:66/69/73, 106/108,
		# 149/153) and `_act_ranged` never calls `attack` at all, so
		# `WICombat.in_weapon_range` (wi_combat.gd:179) is only ever asked at
		# adjacency, where every weapon passes. Bow builds here fight at melee
		# reach because the AI has no bow verb, NOT because of this field --
		# do not "fix" a bow band by expecting this line to move it.
		pc[WIKeys.WEAPON_RANGE] = int(weapon.get(WIKeys.RANGE, 1))
		pc[WIKeys.SKILLS] = WICombatBuild.fold_abilities(pc[WIKeys.SKILLS] as Array, accessories)
		var mods: Dictionary = WICombatBuild.equipment_mods(weapon, armor, accessories)
		pc[WIKeys.DAMAGE_MOD] = mods[WIKeys.DAMAGE_MOD]
		pc[WIKeys.HP_MOD] = mods[WIKeys.HP_MOD]
		pc[WIKeys.DAMAGE_REDUCTION] = mods[WIKeys.DAMAGE_REDUCTION]
	else:
		pc[WIKeys.SKILLS] = kit
	return pc


func _init() -> void:
	var total_cells := COMPOSITIONS.size() * _matrix_build_count() + LOADOUT_CELLS.size() + ENCOUNTER_CELLS.size() + BOSS_CELLS.size() + RUIN_CELLS.size() + RIVERFARM_CELLS.size() + INVRISIL_CELLS.size() + PARTY_CELLS.size() + DUNGEON_CELLS.size() + BESTIARY_CELLS.size() + SECOND_WIND_CELLS.size() + SCALED_CELLS.size()
	if OS.get_environment("WI_CELL_COUNT_ONLY") != "":
		print("WI_CELL_COUNT: %d" % total_cells)
		quit(0)
		return
	var diff_env := OS.get_environment("WI_DIFFICULTY_MULT")
	if diff_env != "":
		_difficulty_mult = float(diff_env)
		assert(_difficulty_mult > 0.0, "WI_DIFFICULTY_MULT must be a positive float (0.75 Bronze / 1.0 Silver / 1.3 Gold)")
		_tier_sweep = true
		print("[tier-sweep] difficulty_damage_taken_mult=%.2f -- REPORT ONLY (every band in this file is authored at Silver 1.0)" % _difficulty_mult)

	var policy_env := OS.get_environment("WI_POLICY")
	if policy_env != "" and policy_env != WICombatPolicies.DUMB:
		assert(policy_env == WICombatPolicies.COMPETENT, "WI_POLICY must be 'dumb' or 'competent'")
		_policy = WICombatPolicies.new(policy_env)
		_policy_sweep = true
		print("[policy-sweep] pc turn driver=%s -- REPORT ONLY (every band in this file is authored against the floor policy)" % policy_env)

	var range_env := OS.get_environment("WI_CELL_RANGE")
	if range_env != "":
		var parts := range_env.split(":")
		assert(parts.size() == 2, "WI_CELL_RANGE must be LO:HI (0-based, inclusive)")
		_range_lo = int(parts[0])
		_range_hi = int(parts[1])

	WITestWatchdog.arm(self)
	var arenas_by_id := {}
	for a: Dictionary in _load("res://data/arenas.json")["arenas"]:
		arenas_by_id[String(a[WIKeys.ID])] = a
	var skills := _load("res://data/skills.json")
	var classes := _load("res://data/classes.json")
	var catalog := _load("res://data/combatants.json")
	var by_id := {}
	for c: Dictionary in catalog["combatants"]:
		by_id[String(c[WIKeys.ID])] = c
	var skills_by_id := {}
	for s: Dictionary in skills[WIKeys.SKILLS]:
		skills_by_id[String(s[WIKeys.ID])] = s
	var items_by_id := {}
	for it: Dictionary in _load("res://data/items.json")["items"]:
		items_by_id[String(it[WIKeys.ID])] = it

	var sink := func(_t: String, _p: Dictionary) -> void: pass
	var any_failed := false

	for comp: Dictionary in COMPOSITIONS:
		var arena: Dictionary = arenas_by_id[String(comp["arena"])]
		for build: Dictionary in BUILDS:
			if not bool(build.get("matrix", true)): continue
			if not _cell_in_range(): continue
			var wins := 0
			var rounds: Array[int] = []
			var relc_downed := 0
			var has_relc := not bool(build.get("solo", false))
			for seed_v in range(1, RUNS_PER_CELL + 1):
				var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
				var cfgs: Array = [pc]
				if not bool(build.get("solo", false)):
					cfgs.append((by_id["relc"] as Dictionary).duplicate(true))
				for enemy_id: String in comp["enemies"]:
					cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
				var combat := _new_combat(arena, cfgs, skills, sink, seed_v)
				combat.begin()
				var guard := 0
				while not combat.finished and guard < 2000:
					guard += 1
					_take_turn(combat)
				assert(combat.finished, "%s/%s fight %d did not terminate" % [comp["name"], build["name"], seed_v])
				if combat.outcome["victory"]:
					wins += 1
				rounds.append(int(combat.outcome["rounds"]))
				if has_relc and not bool(combat.combatants.get("relc", {}).get(WIKeys.ALIVE, true)):
					relc_downed += 1

			rounds.sort()
			var win_rate := float(wins) / float(RUNS_PER_CELL)
			var median: int = rounds[RUNS_PER_CELL / 2]
			var hist := {}
			for r: int in rounds:
				hist[r] = int(hist.get(r, 0)) + 1
			var gated := bool(build.get("gated", true)) \
					and not (build.get("ungated_comps", []) as Array).has(String(comp["name"]))
			print("[%s / %s]%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
				comp["name"], build["name"], "" if gated else " (measured)", win_rate, median, rounds[0], rounds[-1],
			])
			print("  rounds histogram: ", hist)
			if has_relc:
				print("  relc_downed_rate=%.2f (%d/%d)" % [float(relc_downed) / float(RUNS_PER_CELL), relc_downed, RUNS_PER_CELL])
			if not gated:
				continue
			if win_rate < 0.55 or win_rate > 0.95:
				any_failed = true
				printerr("FAIL [%s / %s]: win rate %.2f outside 0.55-0.95" % [comp["name"], build["name"], win_rate])
			if median < 3 or median > 12:
				any_failed = true
				printerr("FAIL [%s / %s]: median rounds %d outside 3-12" % [comp["name"], build["name"], median])

	for cell: Dictionary in LOADOUT_CELLS:
		if not _cell_in_range(): continue
		var comp: Dictionary = _find_by_name(COMPOSITIONS, String(cell["comp"]))
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(comp["arena"])]
		var weapon: Dictionary = items_by_id.get(String(cell[WIKeys.WEAPON]), {})
		var armor: Dictionary = items_by_id.get(String(cell["armor"]), {})
		var acc_ids: Array = cell.get("accessories", [])
		var accessories: Array = []
		for acc_id_v: Variant in acc_ids:
			accessories.append(items_by_id.get(String(acc_id_v), {}))
		var wins := 0
		var rounds: Array[int] = []
		var relc_downed := 0
		var has_relc := not bool(build.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
			pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes)
			var kit: Array = WIProgression.granted_skills(build["classes"], classes)
			pc[WIKeys.SKILLS] = WICombatBuild.weapon_gated_kit(kit, String(weapon.get("weapon_family", "")), skills_by_id)
			pc[WIKeys.SKILLS] = WICombatBuild.fold_abilities(pc[WIKeys.SKILLS] as Array, accessories)
			var mods: Dictionary = WICombatBuild.equipment_mods(weapon, armor, accessories)
			pc[WIKeys.DAMAGE_MOD] = mods[WIKeys.DAMAGE_MOD]
			pc[WIKeys.HP_MOD] = mods[WIKeys.HP_MOD]
			pc[WIKeys.DAMAGE_REDUCTION] = mods[WIKeys.DAMAGE_REDUCTION]
			var cfgs: Array = [pc]
			if has_relc:
				cfgs.append((by_id["relc"] as Dictionary).duplicate(true))
			for enemy_id: String in comp["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := _new_combat(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				_take_turn(combat)
			assert(combat.finished, "loadout %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_relc and not bool(combat.combatants.get("relc", {}).get(WIKeys.ALIVE, true)):
				relc_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var acc_str := "(none)" if acc_ids.is_empty() else ", ".join(acc_ids)
		var unreachable_tag := " CAPACITY-UNREACHABLE-TODAY (resonance > shipped capacity, harness bypasses equip())" if bool(cell.get("capacity_unreachable", false)) else ""
		print("[loadout / %s] comp=%s build=%s weapon=%s armor=%s accessories=%s (measured)%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], comp["name"], build["name"],
			String(cell[WIKeys.WEAPON]) if String(cell[WIKeys.WEAPON]) != "" else "(none)",
			String(cell["armor"]) if String(cell["armor"]) != "" else "(none)",
			acc_str, unreachable_tag,
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_relc:
			print("  relc_downed_rate=%.2f (%d/%d)" % [float(relc_downed) / float(RUNS_PER_CELL), relc_downed, RUNS_PER_CELL])

	for cell: Dictionary in ENCOUNTER_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var ally_downed := 0
		# Cell schema: solo defaults false; omitted ally means Relc. Win bands
		# are opt-in via win_lo/win_hi; otherwise the cell is measured only.
		var has_ally := not bool(cell.get("solo", false))
		var ally_id := String(cell.get("ally", "relc"))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
			pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes)
			pc[WIKeys.SKILLS] = WIProgression.granted_skills(build["classes"], classes)
			var cfgs: Array = [pc]
			if has_ally:
				var ally_cfg: Dictionary = (by_id[ally_id] as Dictionary).duplicate(true)
				# GH#156: mirror wi_game.start_combat's companion-boon injection
				# (basic_command_boon/pack_bond_boon keyed on the PC kit) -- the
				# harness must measure the shipped companion, boons included.
				if bool(cell.get("companion_boons", false)):
					var boons: Array = []
					if (pc[WIKeys.SKILLS] as Array).has("animals_basic_command"):
						boons.append("basic_command_boon")
					if (pc[WIKeys.SKILLS] as Array).has("pack_bond"):
						boons.append("pack_bond_boon")
					if not boons.is_empty():
						var comp_skills: Array = (ally_cfg.get(WIKeys.SKILLS, []) as Array).duplicate()
						comp_skills.append_array(boons)
						ally_cfg[WIKeys.SKILLS] = comp_skills
				cfgs.append(ally_cfg)
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := _new_combat(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				_take_turn(combat)
			assert(combat.finished, "encounter %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_ally and not bool(combat.combatants.get(ally_id, {}).get(WIKeys.ALIVE, true)):
				ally_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		print("[encounter / %s] arena=%s build=%s%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]),
			"" if has_ally else " solo", "" if gated else " (measured)", win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_ally:
			print("  %s_downed_rate=%.2f (%d/%d)" % [ally_id, float(ally_downed) / float(RUNS_PER_CELL), ally_downed, RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [encounter / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [encounter / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in BOSS_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var relc_downed := 0
		var has_relc := not bool(cell.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
			pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes)
			pc[WIKeys.SKILLS] = WIProgression.granted_skills(build["classes"], classes)
			var cfgs: Array = [pc]
			if has_relc:
				cfgs.append((by_id["relc"] as Dictionary).duplicate(true))
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := _new_combat(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				_take_turn(combat)
			assert(combat.finished, "boss %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_relc and not bool(combat.combatants.get("relc", {}).get(WIKeys.ALIVE, true)):
				relc_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		print("[boss / %s] arena=%s build=%s%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]),
			"" if has_relc else " solo", "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_relc:
			print("  relc_downed_rate=%.2f (%d/%d)" % [float(relc_downed) / float(RUNS_PER_CELL), relc_downed, RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [boss / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])

	for cell: Dictionary in RUIN_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var relc_downed := 0
		var has_relc := not bool(cell.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			var cfgs: Array = [pc]
			if has_relc:
				cfgs.append((by_id["relc"] as Dictionary).duplicate(true))
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := _new_combat(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				_take_turn(combat)
			assert(combat.finished, "ruin %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_relc and not bool(combat.combatants.get("relc", {}).get(WIKeys.ALIVE, true)):
				relc_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		print("[ruin / %s] arena=%s build=%s%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]),
			"" if has_relc else " solo", "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_relc:
			print("  relc_downed_rate=%.2f (%d/%d)" % [float(relc_downed) / float(RUNS_PER_CELL), relc_downed, RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [ruin / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [ruin / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in RIVERFARM_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var hunter_downed := 0
		var has_hunter := not bool(cell.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			var cfgs: Array = [pc]
			if has_hunter:
				cfgs.append((by_id["riverfarm_hunter"] as Dictionary).duplicate(true))
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := _new_combat(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				_take_turn(combat)
			assert(combat.finished, "riverfarm %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_hunter and not bool(combat.combatants.get("riverfarm_hunter", {}).get(WIKeys.ALIVE, true)):
				hunter_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		_note_ladder(cell, win_rate)
		print("[riverfarm / %s] arena=%s build=%s%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]),
			"" if has_hunter else " solo", "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_hunter:
			print("  hunter_downed_rate=%.2f (%d/%d)" % [float(hunter_downed) / float(RUNS_PER_CELL), hunter_downed, RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [riverfarm / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [riverfarm / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in INVRISIL_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var wilovan_downed := 0
		var has_wilovan := not bool(cell.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			var cfgs: Array = [pc]
			if has_wilovan:
				cfgs.append((by_id["wilovan"] as Dictionary).duplicate(true))
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := _new_combat(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				_take_turn(combat)
			assert(combat.finished, "invrisil %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_wilovan and not bool(combat.combatants.get("wilovan", {}).get(WIKeys.ALIVE, true)):
				wilovan_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		_note_ladder(cell, win_rate)
		print("[invrisil / %s] arena=%s build=%s%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]),
			"" if has_wilovan else " solo", "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_wilovan:
			print("  wilovan_downed_rate=%.2f (%d/%d)" % [float(wilovan_downed) / float(RUNS_PER_CELL), wilovan_downed, RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [invrisil / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [invrisil / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in PARTY_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var pc_alive_end := 0
		var ally_downed := {"ceria": 0, "yvlon": 0, "ksmvr": 0}
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			var cfgs: Array = [pc]
			for ally_id: String in ["ceria", "yvlon", "ksmvr"]:
				var ally_cfg: Dictionary = (by_id[ally_id] as Dictionary).duplicate(true)
				var hp_mods: Dictionary = cell.get("ally_hp_mods", {})
				if hp_mods.has(ally_id):
					ally_cfg[WIKeys.HP_MOD] = int(ally_cfg.get(WIKeys.HP_MOD, 0)) + int(hp_mods[ally_id])
				cfgs.append(ally_cfg)
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := _new_combat(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				_take_turn(combat)
			assert(combat.finished, "party %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
				assert(bool(combat.combatants["pc"][WIKeys.ALIVE]), "party %s fight %d: victory recorded with pc dead -- instant-defeat rule broken" % [cell["name"], seed_v])
			if bool(combat.combatants["pc"][WIKeys.ALIVE]):
				pc_alive_end += 1
			rounds.append(int(combat.outcome["rounds"]))
			for ally_id: String in ally_downed:
				if not bool(combat.combatants.get(ally_id, {}).get(WIKeys.ALIVE, true)):
					ally_downed[ally_id] = int(ally_downed[ally_id]) + 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		print("[party / %s] arena=%s build=%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]), "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		print("  pc_alive_rate=%.2f (%d/%d)" % [float(pc_alive_end) / float(RUNS_PER_CELL), pc_alive_end, RUNS_PER_CELL])
		for ally_id: String in ["ceria", "yvlon", "ksmvr"]:
			print("  %s_downed_rate=%.2f (%d/%d)" % [ally_id, float(ally_downed[ally_id]) / float(RUNS_PER_CELL), ally_downed[ally_id], RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [party / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [party / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in DUNGEON_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			var cfgs: Array = [pc]
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := _new_combat(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				_take_turn(combat)
			assert(combat.finished, "dungeon %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		_note_ladder(cell, win_rate)
		print("[dungeon / %s] arena=%s build=%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]), "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [dungeon / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [dungeon / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in BESTIARY_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var pc_alive_end := 0
		var rounds: Array[int] = []
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			var cfgs: Array = [pc]
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := _new_combat(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				_take_turn(combat)
			assert(combat.finished, "bestiary %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			if bool(combat.combatants["pc"]["alive"]):
				pc_alive_end += 1
			rounds.append(int(combat.outcome["rounds"]))

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		_note_ladder(cell, win_rate)
		print("[bestiary / %s] arena=%s build=%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]), "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		print("  pc_alive_rate=%.2f (%d/%d)" % [float(pc_alive_end) / float(RUNS_PER_CELL), pc_alive_end, RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [bestiary / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [bestiary / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in SECOND_WIND_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var ally_downed := 0
		var has_ally := cell.has("ally")
		var ally_id := String(cell.get("ally", ""))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			# GH#165: mirror wi_game.start_combat's PC-side [Sworn Fang] boon --
			# a fielded companion + the passive grant folds sworn_fang_boon into
			# the PC's own kit (the inverse of the companion boons below).
			if bool(cell.get("companion_boons", false)) and (pc[WIKeys.SKILLS] as Array).has("sworn_fang_ride_together"):
				var pcs: Array = (pc[WIKeys.SKILLS] as Array).duplicate()
				pcs.append("sworn_fang_boon")
				pc[WIKeys.SKILLS] = pcs
			var cfgs: Array = [pc]
			if has_ally:
				var ally_cfg: Dictionary = (by_id[ally_id] as Dictionary).duplicate(true)
				if bool(cell.get("companion_boons", false)):
					var boons: Array = []
					if (pc[WIKeys.SKILLS] as Array).has("animals_basic_command"):
						boons.append("basic_command_boon")
					if (pc[WIKeys.SKILLS] as Array).has("pack_bond"):
						boons.append("pack_bond_boon")
					if not boons.is_empty():
						var comp_skills: Array = (ally_cfg.get(WIKeys.SKILLS, []) as Array).duplicate()
						comp_skills.append_array(boons)
						ally_cfg[WIKeys.SKILLS] = comp_skills
				cfgs.append(ally_cfg)
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := _new_combat(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				_take_turn(combat)
			assert(combat.finished, "second_wind %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_ally and not bool(combat.combatants.get(ally_id, {}).get(WIKeys.ALIVE, true)):
				ally_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		print("[second_wind / %s] arena=%s build=%s%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]),
			"" if has_ally else " solo", "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_ally:
			print("  %s_downed_rate=%.2f (%d/%d)" % [ally_id, float(ally_downed) / float(RUNS_PER_CELL), ally_downed, RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [second_wind / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [second_wind / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in SCALED_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var rank := String(cell["rank"])
		var wins := 0
		var pc_alive_end := 0
		var rounds: Array[int] = []
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			var cfgs: Array = [pc]
			for enemy_id: String in cell["enemies"]:
				# THE one WIBountyScaling site -- mirrors wi_game.start_combat.
				cfgs.append(WIBountyScaling.scale_enemy((by_id[enemy_id] as Dictionary).duplicate(true), rank))
			var combat := _new_combat(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				_take_turn(combat)
			assert(combat.finished, "scaled %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			if bool(combat.combatants["pc"]["alive"]):
				pc_alive_end += 1
			rounds.append(int(combat.outcome["rounds"]))

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		print("[scaled / %s] arena=%s build=%s rank=%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]), rank,
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		print("  pc_alive_rate=%.2f (%d/%d)" % [float(pc_alive_end) / float(RUNS_PER_CELL), pc_alive_end, RUNS_PER_CELL])
		var lo := float(cell["win_lo"])
		var hi := float(cell["win_hi"])
		if win_rate < lo or win_rate > hi:
			any_failed = true
			printerr("FAIL [scaled / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
		if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
			any_failed = true
			printerr("FAIL [scaled / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	# THE LADDER ORDERING GATE (see LADDER_RUNGS' doc comment). Skipped entirely
	# under WI_CELL_RANGE -- a shard holds only a slice of the four rungs, and the
	# sharded runs exist to be concatenated and diffed, not to re-assert a global
	# contract. The unsharded run is the one that owns this.
	if _ladder_rates.size() == LADDER_RUNGS.size():
		var ladder_line: Array = []
		for rung_name: String in LADDER_RUNGS:
			ladder_line.append("%s %.2f" % [rung_name, float(_ladder_rates[rung_name])])
		print("[ladder] main-quest stops, descending: ", " > ".join(ladder_line))
		for i in range(LADDER_RUNGS.size() - 1):
			var upper := String(LADDER_RUNGS[i])
			var lower := String(LADDER_RUNGS[i + 1])
			var upper_rate := float(_ladder_rates[upper])
			var lower_rate := float(_ladder_rates[lower])
			if lower_rate > upper_rate + LADDER_TIE:
				any_failed = true
				printerr("FAIL [ladder]: rung %d (%s, %.2f) reads EASIER than rung %d (%s, %.2f) by more than the %.2f tie band — the main-quest stops have inverted" % [
					i + 2, lower, lower_rate, i + 1, upper, upper_rate, LADDER_TIE,
				])
	elif _range_lo < 0:
		any_failed = true
		printerr("FAIL [ladder]: an unsharded run measured %d of the %d ladder rungs — a rung was renamed or dropped without updating LADDER_RUNGS" % [
			_ladder_rates.size(), LADDER_RUNGS.size(),
		])

	# GH#360 (a). A tier leg is a READ, not a contract: the bands above are all
	# authored at Silver, so an out-of-band value at 0.75/1.3 is the measurement
	# this sweep exists to take. The FAIL lines stay printed on purpose -- they
	# are the per-cell report -- but they never fail the process, and the plain
	# (env-unset) run below is untouched and still the only asserting one.
	if _tier_sweep:
		print("[tier-sweep] mult=%.2f complete over %d cells x %d seeded runs — any FAIL lines above are the REPORT, not a regression" % [
			_difficulty_mult, total_cells, RUNS_PER_CELL,
		])
		quit(0)
		return

	# #437 (b). Same disposition, same reason: a competent leg is a READ against
	# bands that were authored for the floor policy, so its FAIL lines are the
	# per-cell report and never the process's exit code.
	if _policy_sweep:
		print("[policy-sweep] policy=%s complete over %d cells x %d seeded runs — any FAIL lines above are the REPORT, not a regression" % [
			_policy.policy, total_cells, RUNS_PER_CELL,
		])
		quit(0)
		return

	assert(not any_failed, "one or more matrix cells failed bounds — see FAIL lines above")
	if any_failed:
		quit(1)
		return
	print("PASS: balance harness terminated cleanly over %d cells x %d seeded runs" % [total_cells, RUNS_PER_CELL])
	quit(0)
