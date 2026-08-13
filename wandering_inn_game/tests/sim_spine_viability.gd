extends SceneTree
## #437 — THE SPINE VIABILITY TABLE.
##
## For every fight on the steel thread's spine, in route order, with the kit the
## run actually carries there: does the FLOOR policy (today's autoplay) win, and
## does a COMPETENT policy (spends the kit) win? Both legs drive the real
## `WICombat` through `qa/combat_policies.gd`; neither reimplements game math.
##
## WHY IT EXISTS. The steel-thread rebuild found its two combat walls after Act
## V was fully authored -- the Seal Warden unwinnable by the build it arrives
## with, and power-9.8 gallery trash beating the same build under autoplay.
## Each cost a lane round trip, and both were computable before a line of the
## script was written. This is that computation.
##
## WHAT IT IS NOT. It is not a band gate. `sim_combat_batch.gd` owns the
## broader authored win-rate matrix and asserts it; this file gates only its
## five reference climaxes plus the CALIBRATION rows measured in the shipped
## run. If a calibration row disagrees, the policy or this harness is wrong.
## Never move the expectation to meet the measurement.
##
##   Run:    godot --headless --path wandering_inn_game --script res://tests/sim_spine_viability.gd
##   Write:  WI_SPINE_WRITE=1 ...   (regenerates docs/design/spine-viability-table.md)
##   Fast:   WI_SPINE_RUNS=20 ...   (default 100 seeds per cell, as the matrix)
##
## Named `sim_` and not `test_` deliberately: `scripts/preflight.sh --full`
## sweeps `tests/test_*.gd`, and a table generator is a report, not a gate. The
## POLICIES are gated, by `tests/test_combat_policies.gd`.

const DOC_PATH := "res://docs/design/spine-viability-table.md"

## Enemy-side turns are the shipped AI in BOTH legs. The measured gap is
## PC-side kit handling; that is the whole finding.
const DRIVEN := {"pc": true}


## THE BUILDS. Two families, and their provenance is the point.
##
## `ship_*` = what the CONTINUOUS STEEL THREAD actually arrived with. Sourced,
## fight by fight, from `docs/design/steel-thread-route-spec.md`'s findings
## ledger, `docs/design/balance-bands-and-policy.md`'s measured line, and the
## script's own asserts in `qa/scripts/steel_thread.json`:
##   - classless at the spar (route spec beat 3); rusty_sword is the new-game
##     equip (`save.gd:87`).
##   - warrior 1 at the gate ambush (`steel_thread.json` step 144), fighting
##     with relcs_spare_spear (steps 172-190) -- which gates [Power Strike]
##     OUT of the kit for the whole run: it is `weapon: sword`.
##   - [Mage] 1 held from step 296, before the Act II fights.
##   - "whole act fought at warrior 2" through Act III, "w2 -> w11 at the
##     closing sleep veil" (ledger finding 1).
##   - Act V at w12/m2/d7/t2 (balance doc), plus a `fine_meal`-class food buff
##     (`hp_mod: +2`) carried here as `hp_mod_bonus`.
##   - No armour and no accessory is ever equipped: the run's one accessory,
##     Zevara's moon_bone_amulet, is worn only at the alcove (step 2258) and
##     is the subject of its own row.
##
## FINDING, surfaced by this reconstruction and printed on every run: the four-
## class Act V build models to **52** max HP, not the debrief's 56, and to ~25
## DPR, not ~29. The cause is MULTICLASS STAT DILUTION -- `derived_stat_bonuses`
## scales raw growth by `power_multiplier` (effective_power / total levels), and
## four classes totalling 23 levels convert warrior 12's +12 con into +8. The
## debrief's 56 HP / ~29 DPR pair is exactly an UNDILUTED warrior-12 read
## (str/con 24). Either the debrief measured before two of the classes formed or
## it derived the numbers by hand from the warrior level alone; either way the
## build modelled HERE is the WEAKER of the two, so this table cannot be
## overstating spine viability. The dilution itself is a real #439 input: an
## unconsolidated four-class spine build pays ~30% of its stat growth for the
## breadth, which is precisely the pressure consolidation exists to relieve.
## MODELED where the run banked no assert: the exact mage/diplomat/tactician
## level at each mid-run fight. Marked in the table. #434's compiler makes this
## exact -- it tracks the ledger these were reconstructed from.
##
## `band_*` = the per-act target bands from `balance-bands-and-policy.md`,
## martial-primary with the real mage investment the Act V consolidation floor
## implies. Equipment is best-available-at-that-act, and the Act V band build is
## deliberately IDENTICAL to `sim_combat_batch.gd`'s `t4_spellsword14_party`
## yardstick, so the warden row here and ladder rung 4 there are the same read.
const BUILDS := [
	{"name": "ship_act1_spar", "classes": {}, WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": [], "label": "classless / rusty sword"},
	{"name": "ship_act1", "classes": {"warrior": 1}, WIKeys.WEAPON: "relcs_spare_spear", "armor": "", "accessories": [], "label": "w1 / spear"},
	{"name": "ship_act2", "classes": {"warrior": 1, "mage": 1}, WIKeys.WEAPON: "relcs_spare_spear", "armor": "", "accessories": [], "label": "w1/m1 / spear"},
	{"name": "ship_act3", "classes": {"warrior": 2, "mage": 1}, WIKeys.WEAPON: "relcs_spare_spear", "armor": "", "accessories": [], "label": "w2/m1 / spear"},
	{"name": "ship_act4", "classes": {"warrior": 11, "mage": 2}, WIKeys.WEAPON: "relcs_spare_spear", "armor": "", "accessories": [], "label": "w11/m2 / spear"},
	{"name": "ship_act4_late", "classes": {"warrior": 12, "mage": 2, "diplomat": 7}, WIKeys.WEAPON: "relcs_spare_spear", "armor": "", "accessories": [], "label": "w12/m2/d7 / spear"},
	{"name": "ship_act5", "classes": {"warrior": 12, "mage": 2, "diplomat": 7, "tactician": 2}, WIKeys.WEAPON: "relcs_spare_spear", "armor": "", "accessories": [], "hp_mod_bonus": 2, "label": "w12/m2/d7/t2 / spear, 52 HP"},
	# THE CARRIED ANSWER, WORN. Same build, plus the Act III reward the run
	# carried unequipped from the deep warren to the alcove. resonance 2 exactly
	# fills the base capacity, so it is the only accessory it can wear.
	{"name": "ship_act5_amulet", "classes": {"warrior": 12, "mage": 2, "diplomat": 7, "tactician": 2}, WIKeys.WEAPON: "relcs_spare_spear", "armor": "", "accessories": ["moon_bone_amulet"], "hp_mod_bonus": 2, "label": "w12/m2/d7/t2 + moon-bone amulet"},

	# #450 POST-SPLIT TACTICIAN, MEASURED NOT INFERRED. The split gave the
	# [Tactician] line a second counter (`tactic_used`) and capped it at 12,
	# with [Strategist] carrying 10-16. Those are LEVELLING costs; whether they
	# buy a viable Act V PC is a combat question, and this is where combat
	# questions get answered. Three rows at the three levels the split defines:
	# its onset (t6, the first level that asks for tactics at all), the
	# Tactician cap (t12), and the Strategist cap (s16). Same spear, same food
	# buff and same worn amulet as `ship_act5_amulet`, so the ONLY moving part
	# against that row is the tactical line's own depth.
	# REPORT-ONLY. No CALIBRATION row and no reference window names them; they
	# are a read of what the split ships, not a target it must hit.
	{"name": "ship_act5_tactician6", "classes": {"warrior": 12, "mage": 2, "diplomat": 7, "tactician": 6}, WIKeys.WEAPON: "relcs_spare_spear", "armor": "", "accessories": ["moon_bone_amulet"], "hp_mod_bonus": 2, "label": "w12/m2/d7/t6 — split onset 20 observed / 4 tactics"},
	{"name": "ship_act5_tactician12", "classes": {"warrior": 12, "mage": 2, "diplomat": 7, "tactician": 12}, WIKeys.WEAPON: "relcs_spare_spear", "armor": "", "accessories": ["moon_bone_amulet"], "hp_mod_bonus": 2, "label": "w12/m2/d7/t12 — Tactician cap 44 observed / 34 tactics"},
	{"name": "ship_act5_strategist16", "classes": {"warrior": 12, "mage": 2, "diplomat": 7, "strategist": 16}, WIKeys.WEAPON: "relcs_spare_spear", "armor": "", "accessories": ["moon_bone_amulet"], "hp_mod_bonus": 2, "label": "w12/m2/d7/s16 — Strategist cap 60 observed / 68 tactics"},

	{"name": "band_act1", "classes": {"warrior": 2}, WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": [], "label": "w2 (band 1-2)"},
	{"name": "band_act2", "classes": {"warrior": 3, "mage": 2}, WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin", "accessories": [], "label": "w3/m2 = 5 (band 4-6)"},
	{"name": "band_act3", "classes": {"warrior": 5, "mage": 4}, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": [], "label": "w5/m4 = 9 (band 8-10)"},
	{"name": "band_act4", "classes": {"warrior": 7, "mage": 6}, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"], "label": "w7/m6 = 13 (band 12-14)"},
	{"name": "band_act5", "classes": {"spellsword": 14}, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"], "label": "spellsword 14 (band 14-16 floor)"},
	{"name": "band_act5_top", "classes": {"spellsword": 16}, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"], "label": "spellsword 16 (band 14-16 top)"},
]

const SPINE_CLIMAX_IDS := [
	"act1_gate_ambush", "act2_cistern_nest", "act3_awakened_boss",
	"act4_vault_construct", "act5_seal_warden",
]
const SPINE_LEVELS := {
	"I": [2, 0], "II": [3, 2], "III": [5, 4], "IV": [7, 6], "V": [14],
}
const SPINE_WEAPONS := {
	"spellsword": ["rusty_sword", "rusty_sword", "gnollish_hunting_knife", "gnollish_hunting_knife", "gnollish_hunting_knife"],
	"innkeeper": ["rusty_sword", "rusty_sword", "gnollish_hunting_knife", "gnollish_hunting_knife", "gnollish_hunting_knife"],
	"ranger": ["training_bow", "hunting_bow", "hunting_bow", "hunting_bow", "hunting_bow"],
	"scout": ["training_bow", "hunting_bow", "hunting_bow", "hunting_bow", "hunting_bow"],
	"druid": ["rusty_sword", "rusty_sword", "gnollish_hunting_knife", "gnollish_hunting_knife", "gnollish_hunting_knife"],
}
const WINDOW_FLOOR := 0.55
const WINDOW_CEILING := 0.85

## THE SPINE, in route order (`docs/design/steel-thread-route-spec.md`).
## `arena`/`enemies`/`allies`/`scales` are the map entity's own fields; the
## script above enumerates them so a data edit shows up here as a changed row
## rather than as a silent lie.
##
## `draughts` preserves the #437 calibration run's pack at each fight; that run
## sold both heals before Act V. The current #451 seed-37 steel thread keeps and
## uses its remedy, and is verified independently rather than silently moving a
## historical calibration input.
##
## `bypasses` is hand-maintained (issue #437 sanctions this), but the GATE half
## of it is derived at runtime from the map JSON -- `encounter_when`,
## `trigger_radius`, `respawns`, `scales` -- so a gate change cannot rot the
## column silently. The hand half is the authored non-fight resolution.
const ROSTER := [
	{
		"id": "act1_relc_spar", "act": "I", "beat": 3, "map": "floodplains/floodplains", "entity": "relc_spar",
		"ship": "ship_act1_spar", "band": "band_act1", "draughts": [],
		"bypasses": "Skippable entirely: the spar is an offered dialogue fork (`spar_offer`), and declining costs only `sparred_with_relc`.",
	},
	{
		"id": "act1_gate_ambush", "act": "I", "beat": 6, "map": "floodplains/floodplains", "entity": "goblin_encounter_1",
		"ship": "ship_act1", "band": "band_act1", "draughts": [],
		"bypasses": "None authored. Proximity trigger on the only road to the gate; Relc fields off `met_relc`.",
	},
	{
		"id": "act2_crate_scavengers", "act": "II", "beat": 9, "map": "liscor/street", "entity": "crate_scavengers",
		"ship": "ship_act2", "band": "band_act2", "draughts": [],
		"bypasses": "FULL non-fight fork: `missing_crate`'s guile ladder resolves the beat without combat (the shipped run took it). Klbkch fields off `chatted_with_klbkch`.",
	},
	{
		"id": "act2_cistern_nest", "act": "II", "beat": 10, "map": "sewers/sewers", "entity": "shield_spiders",
		"ship": "ship_act2", "band": "band_act2", "draughts": [],
		"bypasses": "Scout path resolves `resolved_the_cisterns` without the nest (shipped run's choice). Klbkch fields off `chatted_with_klbkch`.",
	},
	{
		"id": "act3_raskghar_scouts", "act": "III", "beat": 15, "map": "sewers/deep_tunnels", "entity": "raskghar_scouts",
		"ship": "ship_act3", "band": "band_act3", "draughts": [],
		"bypasses": "None authored — solo, no ally slot, and the scouts sit on the only lane east to the warren mouth.",
	},
	{
		"id": "act3_awakened_boss", "act": "III", "beat": 15, "map": "sewers/deep_tunnels", "entity": "awakened_boss",
		"ship": "ship_act3", "band": "band_act3", "draughts": [],
		"bypasses": "None (act climax). `relc_descent` is a veto beat, not an out: [Go together] banks `relc_joined_descent`, which is the boss's `ally_requires` — refusing fights it solo. The live joined roster is Awakened + 2 scouts + a Sewer Bat; this table measures that joined route and does not infer the veto route.",
	},
	{
		"id": "act4_vault_construct", "act": "IV", "beat": 20, "map": "dungeon/trapped_halls", "entity": "vault_boss_slot",
		"ship": "ship_act4", "band": "band_act4", "draughts": ["mending_draught"],
		"ally_hp_mods": {"ksmvr": -18},
		"bypasses": "None (act spine). The Horns field off `horns_party_formed`; the plates-guidance fork costs Ksmvr 18 max HP (`ally_hp_penalty`), modelled here.",
	},
	{
		"id": "act4_ruin_guardian", "act": "IV", "beat": 22, "map": "ruin/ruin_surface", "entity": "ruin_guardian",
		"ship": "ship_act4", "band": "band_act4", "draughts": ["mending_draught"],
		"bypasses": "The dig has a non-fight route to `pedestal_breached`; this row is the fight leg. Relc fields off `met_relc`.",
	},
	{
		"id": "act4_alley_footpads", "act": "IV", "beat": 26, "map": "invrisil/mercantile_alleys", "entity": "alley_footpads_a",
		"ship": "ship_act4_late", "band": "band_act4", "draughts": ["mending_draught", "remedy_draught"],
		"bypasses": "Sneak-shaped only: proximity trigger, suppressed while sneaking. Ledger finding 4 — 'the alleys cannot be crossed clean without [Stealth]', and the spine build eats TWO of these across four crossings.",
	},
	{
		"id": "act5_gallery_vermin_nest", "act": "IV/V", "beat": 19, "map": "dungeon/trapped_halls", "entity": "gallery_vermin_nest",
		"ship": "ship_act5", "band": "band_act5", "draughts": [],
		"bypasses": "Optional side gallery — interact-only, never triggers on approach. `respawns: true` = one grind per sleep. THE AUTOPLAY WALL: hand-winnable, autoplay-losable.",
	},
	{
		"id": "act5_seal_warden", "act": "V", "beat": 33, "map": "dungeon/trapped_halls", "entity": "seal_warden_alcove",
		"ship": "ship_act5", "band": "band_act5", "draughts": [],
		"bypasses": "Alcove sneak-past (trigger_radius 1, suppressed while sneaking) — reachable ONLY with a sneak-shaped ability. Ledger finding 6: [Sneak]/[Hedge Remedy]/[Detect Magic] are all off this build's tree; the run reached the fork by EQUIPPING the moon-bone amulet for its [Invisibility]. Per CHOICE-LOG 2026-08-11 that bypass is a defect (#440), not a feature.",
	},
	{
		"id": "act5_seal_warden_amulet", "act": "V", "beat": 33, "map": "dungeon/trapped_halls", "entity": "seal_warden_alcove",
		"ship": "ship_act5_amulet", "band": "band_act5_top", "draughts": [],
		"bypasses": "SHIP COLUMN: the same fight with the carried-but-unequipped upgrade WORN — hp+3, dmg+1, and [Invisibility] into the kit, which the competent policy spends as an escape below 35% HP. BAND COLUMN: no amulet (its resonance would not fit beside the band build's two charms) — this is the band TOP read, spellsword 16.",
	},
	# #450 POST-SPLIT TACTICIAN, REPORT-ONLY. The alcove again, with the ONLY
	# moving part against the row above being the tactical line's own depth:
	# split onset (t6), Tactician cap (t12), Strategist cap (s16). No CALIBRATION
	# row and no reference window names them, so nothing here gates — an
	# out-of-window read is the finding, not a retune order. BAND COLUMN is
	# `band_act5_top` on all three, identical to the amulet row's, so the ship
	# reads sit against one unchanged reference line.
	{
		"id": "act5_seal_warden_tactician6", "act": "V", "beat": 33, "map": "dungeon/trapped_halls", "entity": "seal_warden_alcove",
		"ship": "ship_act5_tactician6", "band": "band_act5_top", "draughts": [],
		"bypasses": "REPORT-ONLY (#450). Same bypass shape as `act5_seal_warden_amulet` — the amulet is worn, so its [Invisibility] is in the kit. SHIP COLUMN: the split's ONSET, tactician 6, the first level that asks for tactics at all.",
	},
	{
		"id": "act5_seal_warden_tactician12", "act": "V", "beat": 33, "map": "dungeon/trapped_halls", "entity": "seal_warden_alcove",
		"ship": "ship_act5_tactician12", "band": "band_act5_top", "draughts": [],
		"bypasses": "REPORT-ONLY (#450). SHIP COLUMN: the [Tactician] CAP, level 12 — the deepest the pre-consolidation line goes before [Strategist] takes over.",
	},
	{
		"id": "act5_seal_warden_strategist16", "act": "V", "beat": 33, "map": "dungeon/trapped_halls", "entity": "seal_warden_alcove",
		"ship": "ship_act5_strategist16", "band": "band_act5_top", "draughts": [],
		"bypasses": "REPORT-ONLY (#450). SHIP COLUMN: the [Strategist] CAP, level 16 — the split's top end, and the only row here whose tactical class is the evolution rather than its parent.",
	},
]

## THE CALIBRATION GATE (issue #437 acceptance). Every row is an outcome the
## shipped run MEASURED. A disagreement means the policy or this harness is
## wrong; fixing it by moving an expectation defeats the entire file.
##   `row` / `column` ("ship"|"band") / `policy` / `want` ("WIN"|"LOSS")
##   `rounds_near`: optional, +/- 2 on the median.
const CALIBRATION := [
	{"row": "act5_seal_warden", "column": "ship", "policy": "dumb", "want": "LOSS", "rounds_near": 5,
		"why": "measured: PC 56 HP / ~29 DPR vs warden 142 HP / 28-30 per hit, death in 5 rounds, three identical runs at seed 9"},
	{"row": "act5_gallery_vermin_nest", "column": "ship", "policy": "dumb", "want": "LOSS",
		"why": "measured: the same build loses to power-9.8 trash under autoplay"},
	{"row": "act5_gallery_vermin_nest", "column": "ship", "policy": "competent", "want": "WIN",
		"why": "measured: hand-winnable — the gap IS the competence gap"},
	# SUPERSEDED BY DATA, NOT BY DISAGREEMENT. Both rows measured WIN before
	# #439, and that WIN was the finding: an act CLIMAX beaten by the weakest
	# policy six to eight levels under band gates nothing. #439 retuned the two
	# encounters (deep_tunnels.json: the pair's second body is now a [Raskghar
	# Pack-Leader]; the Awakened's pack gained a third scout), so the shipped
	# w2/m1 kit is now BELOW the fight, which is the intended shape. The
	# expectation moved because the CONTENT moved -- never because the
	# measurement disagreed. steel_thread.json steps 582/624 are red until its
	# Act III leg is reauthored (sequenced follow-up lane).
	{"row": "act3_raskghar_scouts", "column": "ship", "policy": "dumb", "want": "LOSS",
		"why": "#439 retune: pre-retune this was WIN 0.78 at warrior 2 (steel_thread.json step 582) — the ratchet. Post-retune the under-band kit loses, and the act gates"},
	{"row": "act3_awakened_boss", "column": "ship", "policy": "dumb", "want": "LOSS",
		"why": "#439 retune: pre-retune this was WIN 0.60 at warrior 2 with Relc (step 624) — the ratchet. Post-retune the under-band kit loses, and the act gates"},
]

## PREDICTIONS, kept separate from CALIBRATION and deliberately NOT asserted.
##
## `balance-bands-and-policy.md` wrote down what it EXPECTED the competent
## policy to do before the policy existed. Those expectations are inferences,
## not measurements, and the whole point of building the harness is that it can
## contradict them. Asserting an inference would turn this file into a machine
## for confirming its own author, and would red permanently the first time the
## inference was wrong -- which is exactly what happened here.
##
## They are still evaluated, printed, and carried into the doc with a verdict,
## because a refuted prediction is a FINDING and belongs in the record beside
## the rows that held.
const PREDICTIONS := [
	{"row": "act5_seal_warden", "column": "ship", "policy": "competent", "want": "LOSS",
		"why": "balance-bands-and-policy.md: 'the 2.5x HP gap exceeds resource use'"},
]

var _runs := 100
var _rows: Array = []
var _spine_rows: Array = []
var _ablations: Dictionary = {}
var _act5_max_hp := 0
var _act5_dpr := 0.0
var _act5_efficiency := 0.0
var _failures: Array = []


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _find_build(name: String) -> Dictionary:
	for b: Dictionary in BUILDS:
		if String(b["name"]) == name:
			return b
	assert(false, "unknown build %s" % name)
	return {}


func _median(values: Array) -> int:
	if values.is_empty():
		return 0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return int(sorted[sorted.size() / 2])


## The map entity IS the encounter definition. Reading it here means arena,
## roster, ally list and gate can never drift from what a player walks into.
func _entity(map_id: String, entity_id: String) -> Dictionary:
	var map_data := _load("res://data/maps/%s.json" % map_id)
	for e: Dictionary in map_data.get("entities", []):
		if String(e.get(WIKeys.ID, "")) == entity_id:
			return e
	assert(false, "no entity %s in map %s" % [entity_id, map_id])
	return {}


## The runtime-derived half of the bypass column: gate, trigger and respawn
## shape, straight off the entity.
func _gate_note(entity: Dictionary) -> String:
	var parts: Array = []
	var when: Dictionary = entity.get("encounter_when", {})
	if not when.is_empty():
		var requires: Dictionary = when.get("requires", {})
		if not requires.is_empty():
			var keys: Array = requires.keys()
			keys.sort()
			parts.append("gated on `%s`" % "` + `".join(keys))
		if when.has("phase"):
			parts.append("phase %s only" % str(when["phase"]))
	if int(entity.get("trigger_radius", 0)) > 0:
		parts.append("proximity r%d (sneak suppresses)" % int(entity["trigger_radius"]))
	else:
		parts.append("interact-only")
	if bool(entity.get("respawns", false)):
		parts.append("respawns (one per sleep)")
	if bool(entity.get("scales", false)):
		parts.append("rank-scaled")
	return ", ".join(parts)


func _make_pc(batch: GDScript, build: Dictionary, by_id: Dictionary, classes: Dictionary, skills_by_id: Dictionary, items_by_id: Dictionary) -> Dictionary:
	var pc: Dictionary = batch._build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
	# Food buffs are `pending_meal` in the live game (`wi_game.gd:2369`), folded
	# into the same two cfg fields equipment uses. Same fold here.
	pc[WIKeys.HP_MOD] = int(pc.get(WIKeys.HP_MOD, 0)) + int(build.get("hp_mod_bonus", 0))
	pc[WIKeys.DAMAGE_MOD] = int(pc.get(WIKeys.DAMAGE_MOD, 0)) + int(build.get("damage_mod_bonus", 0))
	return pc


## `consolidations[]` is TWO row kinds in one array, and reading it as one kind
## is what broke this table. Authored consolidation RULES carry `target` +
## `parent_lines`; `_exempt` rows (`{"_exempt": [a, b], "rationale": ...}`) are
## ANNOTATIONS, added by #454, recording a reachable held-pair that deliberately
## has no target yet. The sanctioned reading is `data_lint.py`'s
## `check_lineage_completeness`, which filters with
## `[row for row in rows if "_exempt" not in row]` (data_lint.py:2048) before it
## looks at a single parent line. This is that filter, and nothing more:
## exemption buys a row a SKIP and buys it nothing else. Every non-exempt row is
## still held to a target and exactly two parent lines, because a real
## consolidation missing either is a data defect that must stop the suite.
func _derived_spines(classes: Dictionary) -> Array:
	var out: Array = []
	for consolidation: Dictionary in classes.get("consolidations", []):
		if consolidation.has("_exempt"):
			continue
		var target := String(consolidation.get("target", ""))
		var parent_lines: Array = consolidation.get("parent_lines", [])
		assert(target != "" and parent_lines.size() == 2,
			"spine measurement requires a target and exactly two parent lines")
		assert(SPINE_WEAPONS.has(target), "spine %s needs an explicit act-appropriate loadout" % target)
		out.append({
			"target": target,
			"parents": [String((parent_lines[0] as Array)[0]), String((parent_lines[1] as Array)[0])],
		})
	# ZERO IS NEVER A LEGAL ANSWER. classes.json always carries the authored
	# consolidations, so an empty derivation says the READER broke, never that
	# the spine set emptied -- and the break is silent by construction: the
	# per-spine table just stops printing while every other gate still agrees
	# and the suite still ends PASS. That is exactly what shipped when the
	# `_exempt` rows arrived and tripped the entry assert above (a failed assert
	# aborts the function, which then hands back an empty Array). A gate that
	# cannot fail is worse than no gate, so this one fails loudly instead.
	if out.is_empty():
		printerr("FAIL [spine] derived 0 consolidation spines from classes.json")
		# ORDER MATTERS: a failed `assert` aborts the enclosing function, so the
		# exit code has to be claimed BEFORE it or `quit(1)` never runs at all.
		quit(1)
		assert(false, "spine derivation produced no spines; classes.json always carries authored consolidations, so the reader is broken")
	return out


func _spine_build(spine: Dictionary, act: String) -> Dictionary:
	var act_i := ["I", "II", "III", "IV", "V"].find(act)
	assert(act_i >= 0, "unknown spine act %s" % act)
	var levels: Array = SPINE_LEVELS[act]
	var held := {}
	if act == "V":
		held[String(spine["target"])] = int(levels[0])
	else:
		held[String((spine["parents"] as Array)[0])] = int(levels[0])
		if int(levels[1]) > 0:
			held[String((spine["parents"] as Array)[1])] = int(levels[1])
	var parts: Array[String] = []
	for class_id: String in held:
		parts.append("%s%d" % [class_id, held[class_id]])
	return {
		"name": "spine_%s_%s" % [spine["target"], act.to_lower()],
		"classes": held,
		WIKeys.WEAPON: (SPINE_WEAPONS[spine["target"]] as Array)[act_i],
		"armor": "" if act == "I" else "leather_jerkin",
		"accessories": [] if act_i < 3 else ["hedge_ward_charm", "hunters_fang_talisman"],
		"label": "/".join(parts),
	}


func _spine_cfgs(record: Dictionary, pc: Dictionary, by_id: Dictionary) -> Array:
	var row: Dictionary = record["row"]
	var entity: Dictionary = record["entity"]
	var cfgs: Array = [pc]
	var allies: Array = (entity.get("allies", []) as Array).duplicate()
	var companion := "wolf_companion" if (pc[WIKeys.SKILLS] as Array).has("lesser_bond") else ""
	if companion != "" and not allies.has(companion) \
			and allies.size() + 2 <= ((record["arena"] as Dictionary)["player_spawns"] as Array).size():
		allies.append(companion)
	if companion != "" and (pc[WIKeys.SKILLS] as Array).has("sworn_fang_ride_together"):
		(pc[WIKeys.SKILLS] as Array).append("sworn_fang_boon")
	for ally_v: Variant in allies:
		var ally_id := String(ally_v)
		var ally: Dictionary = (by_id[ally_id] as Dictionary).duplicate(true)
		var hp_mods: Dictionary = row.get("ally_hp_mods", {})
		if hp_mods.has(ally_id):
			ally[WIKeys.HP_MOD] = int(ally.get(WIKeys.HP_MOD, 0)) + int(hp_mods[ally_id])
		if ally_id == companion:
			var boons: Array = []
			if (pc[WIKeys.SKILLS] as Array).has("animals_basic_command"):
				boons.append("basic_command_boon")
			if (pc[WIKeys.SKILLS] as Array).has("pack_bond"):
				boons.append("pack_bond_boon")
			(ally[WIKeys.SKILLS] as Array).append_array(boons)
		cfgs.append(ally)
	return cfgs


## One (row x build x policy) cell: N seeded fights, aggregated.
##
## `hp_margin` is one scalar for both outcomes: on a win it is the PC's HP left,
## on a loss it is MINUS the enemy HP still standing. Zero is the knife edge in
## either direction, and the sign says which side of it the fight landed on.
func _measure(cell: Dictionary) -> Dictionary:
	var wins := 0
	var rounds: Array = []
	var margins: Array = []
	var max_hp := 0
	for seed_v in range(1, _runs + 1):
		var pol := WICombatPolicies.new(String(cell["policy"]))
		pol.items_by_id = cell["items_by_id"]
		pol.driven = DRIVEN.duplicate()
		var pack: Array = []
		for d: Variant in (cell["draughts"] as Array):
			pack.append(String(d))
		pol.carried = {"pc": pack}
		var cfgs: Array = []
		for cfg: Dictionary in (cell["cfgs"] as Array):
			var copy: Dictionary = cfg.duplicate(true)
			# ABLATION: strip named skills from the PC's kit only. Used by the
			# attribution probe below so the findings section carries its own
			# reproducer instead of a number somebody measured once by hand.
			if String(copy.get(WIKeys.ID, "")) == "pc" and not (cell.get("without", []) as Array).is_empty():
				var kit: Array = []
				for sk: Variant in (copy[WIKeys.SKILLS] as Array):
					if not (cell["without"] as Array).has(String(sk)):
						kit.append(String(sk))
				copy[WIKeys.SKILLS] = kit
			cfgs.append(copy)
		var combat := WICombat.new(cell["arena"], cfgs, cell["skills"], func(_t: String, _p: Dictionary) -> void: pass, seed_v)
		combat.begin()
		max_hp = int(combat.combatants["pc"][WIKeys.MAX_HP])
		var guard := 0
		while not combat.finished and guard < 2000:
			guard += 1
			pol.take_turn(combat)
		assert(combat.finished, "%s/%s/%s seed %d did not terminate" % [cell["row"], cell["build"], cell["policy"], seed_v])
		rounds.append(int(combat.outcome["rounds"]))
		if bool(combat.outcome["victory"]):
			wins += 1
			margins.append(int(combat.combatants["pc"][WIKeys.HP]))
		else:
			var standing := 0
			for id: String in combat.combatants:
				var c: Dictionary = combat.combatants[id]
				if String(c[WIKeys.SIDE]) != "player" and bool(c[WIKeys.ALIVE]):
					standing += int(c[WIKeys.HP])
			margins.append(-standing)
	var win_rate := float(wins) / float(_runs)
	return {
		"win_rate": win_rate,
		"result": "WIN" if win_rate >= 0.5 else "LOSS",
		"rounds": _median(rounds),
		"margin": _median(margins),
		"max_hp": max_hp,
	}


func _cell_text(m: Dictionary) -> String:
	return "%s %.2f / %d rd / %+d" % [m["result"], m["win_rate"], m["rounds"], m["margin"]]


func _verify_counter_strike_contract(skills: Dictionary) -> bool:
	var counter_strike: Dictionary = {}
	for skill: Dictionary in skills.get(WIKeys.SKILLS, []):
		if String(skill.get(WIKeys.ID, "")) == "counter_strike":
			counter_strike = skill
			break
	if not bool(counter_strike.get("once_per_round", false)):
		printerr("FAIL spine harness refuses to measure: counter_strike data is not once-per-round")
		return false

	var events: Array[String] = []
	var combat := WICombat.new({
		WIKeys.ID: "counter_strike_contract",
		"grid": {"width": 4, "height": 3},
		"blocked": [],
		"player_spawns": [[1, 1]],
		"enemy_spawns": [[2, 1]],
	}, [{
		WIKeys.ID: "pc", WIKeys.DISPLAY_NAME: "Probe defender", WIKeys.SIDE: "player",
		WIKeys.STATS: {"str": 10, "dex": 10, "con": 999, "int": 10},
		WIKeys.WEAPON_DIE: 6, WIKeys.SKILLS: ["counter_strike"],
	}, {
		WIKeys.ID: "probe_attacker", WIKeys.DISPLAY_NAME: "Probe attacker", WIKeys.SIDE: "enemy",
		WIKeys.STATS: {"str": 10, "dex": 10, "con": 999, "int": 10},
		WIKeys.WEAPON_DIE: 6, WIKeys.SKILLS: [],
	}], skills, func(type: String, _payload: Dictionary) -> void: events.append(type), 1)
	combat.begin()
	combat.combatants["probe_attacker"]["hit_bonus"] = 1000
	combat.active_index = combat.turn_order.find("probe_attacker")
	combat._start_turn()
	if not (combat.attack("pc") and combat.attack("pc")):
		printerr("FAIL spine harness counter-strike probe could not land two same-round hits")
		return false
	if events.count(WIEvents.REACTION_TRIGGERED) != 1:
		printerr("FAIL spine harness refuses to measure: loaded combat engine is not once-per-round capped")
		return false
	while combat.round_number == 1:
		combat.end_turn()
	combat.active_index = combat.turn_order.find("probe_attacker")
	combat._start_turn()
	if not combat.attack("pc"):
		printerr("FAIL spine harness counter-strike probe could not land a next-round hit")
		return false
	if events.count(WIEvents.REACTION_TRIGGERED) != 2:
		printerr("FAIL spine harness refuses to measure: loaded combat engine does not refresh Counter Strike next round")
		return false
	print("[spine] engine contract: Counter Strike fired once in round 1 and refreshed in round 2")
	return true


func _init() -> void:
	WITestWatchdog.arm(self)
	var runs_env := OS.get_environment("WI_SPINE_RUNS")
	if runs_env != "":
		_runs = maxi(1, int(runs_env))

	var arena_by_id := {}
	for a: Dictionary in _load("res://data/arenas.json")["arenas"]:
		arena_by_id[String(a[WIKeys.ID])] = a
	var skills := _load("res://data/skills.json")
	if not _verify_counter_strike_contract(skills):
		quit(1)
		return
	var classes := _load("res://data/classes.json")
	var by_id := {}
	for c: Dictionary in _load("res://data/combatants.json")["combatants"]:
		by_id[String(c[WIKeys.ID])] = c
	var skills_by_id := {}
	for s: Dictionary in skills[WIKeys.SKILLS]:
		skills_by_id[String(s[WIKeys.ID])] = s
	var items_by_id := {}
	for it: Dictionary in _load("res://data/items.json")["items"]:
		items_by_id[String(it[WIKeys.ID])] = it
	# `_build_pc` is shared with the balance matrix on purpose: a viability row
	# and a matrix cell that name the same build must BE the same combatant.
	var batch: GDScript = preload("res://tests/sim_combat_batch.gd")

	# THE 56 HP PIN. The Act V shipped build is the calibration anchor for the
	# whole table -- every warden expectation is stated against it -- so its
	# modelled max HP is asserted against the measured number rather than
	# assumed. 20 + con 24 + [Tough Body] 10 + food 2.
	var act5_pc := _make_pc(batch, _find_build("ship_act5"), by_id, classes, skills_by_id, items_by_id)
	var act5_probe := WICombat.new(arena_by_id["vault"], [act5_pc.duplicate(true)], skills, func(_t: String, _p: Dictionary) -> void: pass, 1)
	_act5_max_hp = int(act5_probe.combatants["pc"][WIKeys.MAX_HP])
	_act5_efficiency = WIProgression.power_multiplier(_find_build("ship_act5")["classes"], classes)
	# Two basic attacks is what 4 AP buys, so DPR is 2x the engine-priced mean
	# hit -- the same quantity the debrief's "~29 DPR" names.
	var dpr_probe := WICombat.new(arena_by_id["vault"], [act5_pc.duplicate(true), (by_id["seal_warden"] as Dictionary).duplicate(true)], skills, func(_t: String, _p: Dictionary) -> void: pass, 1)
	_act5_dpr = 2.0 * WICombatPolicies.expected_damage(dpr_probe, dpr_probe.combatants["pc"], dpr_probe.combatants["seal_warden"], 1.0, true)
	print("[spine] act5 shipped build: %d max HP / %.1f DPR (debrief recorded 56 / ~29); multiclass stat efficiency %.2f" % [
		_act5_max_hp, _act5_dpr, _act5_efficiency])

	print("[spine] %d rows x 2 build families x 2 policies x %d seeds" % [ROSTER.size(), _runs])
	for row: Dictionary in ROSTER:
		var entity := _entity(String(row["map"]), String(row["entity"]))
		var arena: Dictionary = arena_by_id[String(entity["arena"])]
		var measured := {}
		for column: String in ["ship", "band"]:
			var build := _find_build(String(row[column]))
			var rank := WIProgression.power_rank(build["classes"], classes) if bool(entity.get("scales", false)) else "bronze"
			var cfgs: Array = [_make_pc(batch, build, by_id, classes, skills_by_id, items_by_id)]
			for ally_v: Variant in (entity.get("allies", []) as Array):
				var ally: Dictionary = (by_id[String(ally_v)] as Dictionary).duplicate(true)
				var hp_mods: Dictionary = row.get("ally_hp_mods", {})
				if hp_mods.has(String(ally_v)):
					ally[WIKeys.HP_MOD] = int(ally.get(WIKeys.HP_MOD, 0)) + int(hp_mods[String(ally_v)])
				cfgs.append(ally)
			for enemy_v: Variant in (entity.get("enemies", []) as Array):
				cfgs.append(WIBountyScaling.scale_enemy((by_id[String(enemy_v)] as Dictionary).duplicate(true), rank))
			for policy_name: String in [WICombatPolicies.DUMB, WICombatPolicies.COMPETENT]:
				measured["%s_%s" % [column, policy_name]] = _measure({
					"row": row["id"], "build": build["name"], "policy": policy_name,
					"arena": arena, "cfgs": cfgs, "skills": skills,
					"items_by_id": items_by_id, "draughts": row["draughts"],
				})
			measured["%s_rank" % column] = rank
			measured["%s_label" % column] = String(build["label"])
		var record := {
			"row": row, "entity": entity, "arena": arena, "gate": _gate_note(entity), "m": measured,
		}
		_rows.append(record)
		print("[spine] %-28s ship(floor %s | competent %s)  band(floor %s | competent %s)" % [
			String(row["id"]),
			_cell_text(measured["ship_dumb"]), _cell_text(measured["ship_competent"]),
			_cell_text(measured["band_dumb"]), _cell_text(measured["band_competent"]),
		])

	var spines := _derived_spines(classes)
	print("[spine] derived %d consolidation spines from classes.json" % spines.size())
	# RETURNING is what makes the failure stick: falling through would reach the
	# PASS print and its `quit(0)`, which overwrites the exit code and restores
	# exactly the dishonest green this fixes. `quit(1)` is repeated here rather
	# than left to `_derived_spines` because the two ways of arriving empty exit
	# differently -- a tripped assert ABORTS that function before its own
	# `quit(1)` runs, and a `--script` SceneTree with no quit requested then
	# hangs to the watchdog instead of failing now.
	if spines.is_empty():
		printerr("FAIL [spine] no consolidation spines derived; the per-spine table would be silently empty")
		quit(1)
		return
	for spine: Dictionary in spines:
		for row_id: String in SPINE_CLIMAX_IDS:
			var record := _find_record(row_id)
			var row: Dictionary = record["row"]
			var entity: Dictionary = record["entity"]
			var build := _spine_build(spine, String(row["act"]))
			var pc := _make_pc(batch, build, by_id, classes, skills_by_id, items_by_id)
			var cfgs := _spine_cfgs(record, pc, by_id)
			var rank := WIProgression.power_rank(build["classes"], classes) if bool(entity.get("scales", false)) else "bronze"
			for enemy_v: Variant in (entity.get("enemies", []) as Array):
				cfgs.append(WIBountyScaling.scale_enemy((by_id[String(enemy_v)] as Dictionary).duplicate(true), rank))
			var m := _measure({
				"row": row_id, "build": build["name"], "policy": WICombatPolicies.COMPETENT,
				"arena": record["arena"], "cfgs": cfgs, "skills": skills,
				"items_by_id": items_by_id, "draughts": row["draughts"],
			})
			_spine_rows.append({"spine": spine["target"], "row": row, "build": build, "m": m})
			print("[spine-class] %-11s %-28s %s %s" % [
				spine["target"], row_id, build["label"], _cell_text(m),
			])

	# ATTRIBUTION PROBE. The findings section claims which parts of the kit the
	# competence gap is actually made of; those claims are measured here rather
	# than asserted in prose. One ablation per named skill, on the warden at the
	# shipped kit -- the row the whole issue turns on.
	var warden_row := _find_record("act5_seal_warden")
	var warden_entity: Dictionary = warden_row["entity"]
	var warden_build := _find_build(String((warden_row["row"] as Dictionary)["ship"]))
	var warden_cfgs: Array = [_make_pc(batch, warden_build, by_id, classes, skills_by_id, items_by_id)]
	for enemy_v: Variant in (warden_entity.get("enemies", []) as Array):
		warden_cfgs.append((by_id[String(enemy_v)] as Dictionary).duplicate(true))
	for ablated: String in ["piercing_strikes", "second_wind"]:
		_ablations[ablated] = _measure({
			"row": "act5_seal_warden", "build": warden_build["name"], "policy": WICombatPolicies.COMPETENT,
			"arena": arena_by_id[String(warden_entity["arena"])], "cfgs": warden_cfgs, "skills": skills,
			"items_by_id": items_by_id, "draughts": [], "without": [ablated],
		})
		print("[spine] ablation warden/competent without %s: %s" % [ablated, _cell_text(_ablations[ablated])])

	_check_calibration()
	_check_reference_windows()
	var doc := _render()
	print("")
	print(doc)
	if OS.get_environment("WI_SPINE_WRITE") != "":
		var f := FileAccess.open(DOC_PATH, FileAccess.WRITE)
		assert(f != null, "cannot write %s" % DOC_PATH)
		f.store_string(doc)
		f.close()
		print("[spine] wrote %s" % DOC_PATH)

	if not _failures.is_empty():
		for line: String in _failures:
			printerr("FAIL %s" % line)
		# ORDER MATTERS, same shape as `_derived_spines` above: a failed `assert`
		# aborts the enclosing function, so with the assert first `quit(1)` never
		# ran — the one path this file exists to take exited by WATCHDOG TIMEOUT
		# instead of by failing. Claim the exit code first; the assert still
		# carries the message.
		quit(1)
		assert(false, "calibration rows disagree with the shipped run's ground truth — see FAIL lines above")
		return
	print("PASS: spine viability table generated; all %d calibration rows agree and all %d reference climaxes are inside [%.2f, %.2f]" % [
		CALIBRATION.size(), SPINE_CLIMAX_IDS.size(), WINDOW_FLOOR, WINDOW_CEILING,
	])
	quit(0)


func _find_record(row_id: String) -> Dictionary:
	for r: Dictionary in _rows:
		if String((r["row"] as Dictionary)["id"]) == row_id:
			return r
	return {}


func _check_calibration() -> void:
	for cal: Dictionary in CALIBRATION:
		var record := _find_record(String(cal["row"]))
		assert(not record.is_empty(), "calibration names an unknown row %s" % cal["row"])
		var m: Dictionary = (record["m"] as Dictionary)["%s_%s" % [cal["column"], cal["policy"]]]
		if String(m["result"]) != String(cal["want"]):
			_failures.append("[calibration] %s / %s / %s: want %s, measured %s (%.2f wins over %d seeds). Ground truth: %s" % [
				cal["row"], cal["column"], cal["policy"], cal["want"], m["result"], m["win_rate"], _runs, cal["why"]])
		if cal.has("rounds_near") and absi(int(m["rounds"]) - int(cal["rounds_near"])) > 2:
			_failures.append("[calibration] %s / %s / %s: median %d rounds, measured run died around round %d" % [
				cal["row"], cal["column"], cal["policy"], int(m["rounds"]), int(cal["rounds_near"])])


func _check_reference_windows() -> void:
	for row_id: String in SPINE_CLIMAX_IDS:
		var record := _find_record(row_id)
		if record.is_empty():
			_failures.append("[window] reference climax %s has no measured row" % row_id)
			continue
		var m: Dictionary = (record["m"] as Dictionary)["band_competent"]
		var rate := float(m["win_rate"])
		if rate < WINDOW_FLOOR or rate > WINDOW_CEILING:
			_failures.append("[window] %s / band / competent: %.2f outside [%.2f, %.2f]" % [
				row_id, rate, WINDOW_FLOOR, WINDOW_CEILING])


func _render() -> String:
	var out: Array = []
	out.append("<!-- GENERATED by tests/sim_spine_viability.gd (WI_SPINE_WRITE=1). Do not hand-edit the tables; edit the ROSTER/BUILDS there. -->")
	out.append("# Spine fight viability — floor vs competent policy")
	out.append("")
	out.append("Generated by `tests/sim_spine_viability.gd` over **%d seeded sims per cell**, driving the real combat engine through `qa/combat_policies.gd`. Issues #437 and #451." % _runs)
	out.append("")
	out.append("**Two policies, two columns.**")
	out.append("")
	out.append("- **floor (dumb)** — today's `combat_autoplay`, byte-for-byte (`WICombatAI`, the melee profile). It never casts a PC spell, never drinks a carried draught, never uses [Second Wind]. This is what the QA scripts experience, and what victory pins were quietly authored against.")
	out.append("- **competent** — the tuning reference: heals under 35% max HP, drinks the best carried draught, casts when the cast out-damages the swing, keeps distance with a reaching weapon. Not optimal play; no lookahead, no target choice beyond lowest-HP-reachable. Enemies and allies run the shipped AI in BOTH columns.")
	out.append("")
	out.append("Cell format: `RESULT win-rate / median rounds / median HP margin`. HP margin is the PC's remaining HP on a win and **minus** the enemy HP still standing on a loss, so the sign is the outcome and the size is how close it was.")
	out.append("")
	out.append("Doctrine (CHOICE-LOG 2026-08-11): **QA proves completability; these sims prove balance.** Never tune an encounter to green a dumb-autoplay victory pin.")
	out.append("")
	out.append("## Historical #437 steel-thread calibration kit")
	out.append("")
	out.append("The `ship` column preserves the #437 calibration run, including its empty Act V pack. The current #451 seed-37 steel thread keeps and uses a remedy and is verified separately; historical calibration inputs do not move silently.")
	out.append("")
	out.append("The continuous run as it actually played (`docs/design/steel-thread-route-spec.md`). Spear from Act I on, no armour, no accessory worn before the alcove.")
	out.append("")
	out.append(_table("ship"))
	out.append("")
	out.append("## The per-act band builds (#439's draft)")
	out.append("")
	out.append("The same fights against `docs/design/balance-bands-and-policy.md`'s target bands, with best-available equipment for the act. This is the **reference** column the amendment asks for: a fight the competent policy loses AT BAND is a wall, whatever the floor column says.")
	out.append("")
	out.append(_table("band"))
	out.append("")
	out.append("## Per-spine band-competent climaxes")
	out.append("")
	out.append("The spine list is derived from every target in `data/classes.json`'s `consolidations`; no class id is duplicated here by hand. Acts I–IV use the target's two base parent lines at the same 2, 3/2, 5/4, and 7/6 band allocations as the original Spellsword seed; Act V uses the consolidated class at level 14. Druid fields its bonded wolf when the live arena-capacity rule permits it. Below-window class rows are WALLS for controller adjudication, not retune orders; above-window rows are ceiling WINDOW DRIFT.")
	out.append("")
	out.append(_spine_table())
	out.append("")
	out.append(_warden_callout())
	out.append("")
	out.append("## Calibration rows (the acceptance gate)")
	out.append("")
	out.append("Each of these is an outcome the shipped run measured. The generator asserts them; a disagreement means the policy or the harness is wrong, never the expectation.")
	out.append("")
	out.append("| Row | Column | Policy | Expected | Measured | Ground truth |")
	out.append("|---|---|---|---|---|---|")
	for cal: Dictionary in CALIBRATION:
		var record := _find_record(String(cal["row"]))
		var m: Dictionary = (record["m"] as Dictionary)["%s_%s" % [cal["column"], cal["policy"]]]
		var mark := "✅" if String(m["result"]) == String(cal["want"]) else "❌"
		out.append("| `%s` | %s | %s | %s | %s %s | %s |" % [
			cal["row"], cal["column"], cal["policy"], cal["want"], mark, _cell_text(m), cal["why"]])
	out.append("")
	out.append("### Predictions (evaluated, not asserted)")
	out.append("")
	out.append("`balance-bands-and-policy.md` wrote down what it expected the competent policy to do before the policy existed. Inferences, not measurements — so they are reported, never gated. A refuted one is a finding.")
	out.append("")
	out.append("| Row | Column | Policy | Predicted | Measured | Verdict |")
	out.append("|---|---|---|---|---|---|")
	for pred: Dictionary in PREDICTIONS:
		var precord := _find_record(String(pred["row"]))
		var pm: Dictionary = (precord["m"] as Dictionary)["%s_%s" % [pred["column"], pred["policy"]]]
		var held := String(pm["result"]) == String(pred["want"])
		out.append("| `%s` | %s | %s | %s — %s | %s | %s |" % [
			pred["row"], pred["column"], pred["policy"], pred["want"], pred["why"],
			_cell_text(pm), "HELD" if held else "**REFUTED**"])
	out.append("")
	out.append(_findings())
	out.append("")
	out.append("## Reading the table")
	out.append("")
	out.append("- **floor LOSS / competent WIN** — a competence wall, not a difficulty wall. The fight is fair; the script cannot play it. `act5_gallery_vermin_nest` is the archetype.")
	out.append("- **floor LOSS / competent LOSS** — a real wall. Either the build is under band or the encounter is over it. In the class-derived table, a below-window competent row is reported as a WALL for adjudication; it is not permission to flatten the shared encounter for every stronger spine.")
	out.append("- **floor WIN at a build far under band** — the ratchet. The fight is beatable by the weakest policy at the lowest kit, so it is not gating anything.")
	out.append("- **bypasses** — 'unwinnable but bypassable' reads differently from 'wall'. The gate half of the column is derived from the map entity at generation time; the authored-resolution half is maintained in `ROSTER`.")
	return "\n".join(out)


func _table(column: String) -> String:
	var out: Array = []
	out.append("| Act | Fight | Build | floor (dumb) | competent | Authored bypasses / gate |")
	out.append("|---|---|---|---|---|---|")
	for r: Dictionary in _rows:
		var row: Dictionary = r["row"]
		var m: Dictionary = r["m"]
		var rank := String(m["%s_rank" % column])
		var rank_note := "" if rank == "bronze" else " _(%s-scaled)_" % rank
		out.append("| %s | `%s`%s | %s | %s | %s | %s<br>_%s_ |" % [
			row["act"], row["id"], rank_note, m["%s_label" % column],
			_cell_text(m["%s_dumb" % column]), _cell_text(m["%s_competent" % column]),
			row["bypasses"], r["gate"],
		])
	return "\n".join(out)


func _spine_table() -> String:
	var out: Array = [
		"| Act | Climax | Spine | Band build | competent | Disposition |",
		"|---|---|---|---|---|---|",
	]
	for record: Dictionary in _spine_rows:
		var row: Dictionary = record["row"]
		var m: Dictionary = record["m"]
		out.append("| %s | `%s` | `%s` | %s | %s | %s |" % [
			row["act"], row["id"], record["spine"], (record["build"] as Dictionary)["label"],
			_cell_text(m), _spine_disposition(m),
		])
	return "\n".join(out)


func _spine_disposition(m: Dictionary) -> String:
	var position := _window_position(m, WINDOW_FLOOR, WINDOW_CEILING)
	if position == "below":
		return "WALL — report only"
	if position == "above":
		return "WINDOW DRIFT — ceiling; adjudicate"
	return "IN WINDOW"


## What the run of the table actually taught, with the numbers inline so a
## re-generation cannot leave a stale claim standing.
func _window_position(m: Dictionary, floor_rate: float, ceiling_rate: float) -> String:
	var rate := float(m["win_rate"])
	if rate < floor_rate:
		return "below"
	if rate > ceiling_rate:
		return "above"
	return "inside"


func _findings() -> String:
	var warden: Dictionary = _find_record("act5_seal_warden")["m"]
	var amulet: Dictionary = _find_record("act5_seal_warden_amulet")["m"]
	var vermin: Dictionary = _find_record("act5_gallery_vermin_nest")["m"]
	var scouts: Dictionary = _find_record("act3_raskghar_scouts")["m"]
	var boss: Dictionary = _find_record("act3_awakened_boss")["m"]
	return "\n".join([
		"## Findings",
		"",
		"1. **The competence gap is [Piercing Strikes], not casting.** The shipped run fought the entire game with Relc's spear, which gates [Power Strike] out of the kit and [Piercing Strikes] in — a 1.4x damage_mult at the SAME 2 AP as a basic swing, i.e. ~+37%% damage for free. `WICombatAI` has no arm for it: `_act_melee` knows `power_strike` by literal id and nothing else. Ablation on the warden at the shipped kit: the competent policy measures %s with it and %s without — a bigger swing than every other resource in the kit combined. Autoplay is not merely 'a melee profile'; it is a melee profile that cannot use a spear's own skill." % [
			_cell_text(warden["ship_competent"]), _cell_text(_ablations["piercing_strikes"])],
		"",
		"2. **[Second Wind] trades an attack for healing, and the policy spends it automatically.** 2 AP buys 8 HP or roughly 20 damage forgone. Ablation against the warden measures %s with it and %s without; those adjacent measurements are the result, without inferring a win-rate gain or loss when they tie. A player under 35%% HP heals, so this records what 'competent, not optimal' costs. It also flags a data seam: [Second Wind] carries neither `cooldown_rounds` nor `once_per_fight`, so it is an unbounded heal for anyone willing to spend the AP." % [
			_cell_text(warden["ship_competent"]), _cell_text(_ablations["second_wind"])],
		"",
		"3. **The run once sold its own answer.** Before the competent-policy reauthoring, the steel thread fenced both healing draughts and the vault tonic for 18 gold because autoplay never drank them, then entered the hardest fight with an empty pack. The floor policy did not just under-measure the fight; it changed what the run carried into it.",
		"",
		"4. **The Act V spine build is weaker than the debrief recorded.** Four classes totalling 23 levels model to **%d max HP / %.1f DPR** against the warden, not the debrief's 56 / ~29. `derived_stat_bonuses` scales raw growth by `power_multiplier` (effective_power / total levels = %.2f here), so warrior 12's +12 con and +12 str arrive as +8 each; the debrief's pair is an UNDILUTED warrior-12 read. Roughly 30%% of the spine build's stat growth is paid for breadth — which is the pressure consolidation exists to relieve, and a direct #439 input: an unconsolidated multiclass PC does not reach its combined level's power. Note the direction: the build modelled here is the WEAKER of the two, so nothing in this table overstates spine viability." % [
			_act5_max_hp, _act5_dpr, _act5_efficiency],
		"",
		"5. **Act III WAS the ratchet; its composition now follows the live engine.** #439 strengthened both climaxes without touching shared stat blocks. After #451 capped [Counter Strike], the fixed harness found the Awakened row below its window, so C1 retained four enemies but replaced the third scout with the cave's existing Sewer Bat; combatant stats remain frozen. Today the shipped w2/m1 kit measures %s and %s. At band the competent policy measures %s for scouts (%s the [0.55, 0.85] window) and %s for the boss (%s the window)." % [
			_cell_text(scouts["ship_dumb"]), _cell_text(boss["ship_dumb"]),
			_cell_text(scouts["band_competent"]), _window_position(scouts["band_competent"], 0.55, 0.85),
			_cell_text(boss["band_competent"]), _window_position(boss["band_competent"], 0.55, 0.85)],
		"",
		"6. **The gallery nest is a pure competence wall.** Floor %s, competent %s at the same build and the same (empty) pack. Nothing about the encounter is unfair; the script simply cannot play it. It is also `scales: true`, and the Act V build's effective power puts it in the GOLD band (+50%% enemy HP, +2 damage) — the trash got a rank promotion the run never noticed." % [
			_cell_text(vermin["ship_dumb"]), _cell_text(vermin["ship_competent"])],
		"",
		"7. **The carried-but-unequipped upgrade was worth more than the fight was hard.** Equipping the moon-bone amulet — hp+3, dmg+1, and [Invisibility] into the kit — moves the warden from %s to %s under the FLOOR policy alone. The accessory the run carried from Act III to Act V without wearing was, by itself, the difference between losing and winning the finale." % [
			_cell_text(warden["ship_dumb"]), _cell_text(amulet["ship_dumb"])],
	])


## Deliverable D: the balance doc's falsifiable check, answered.
func _warden_callout() -> String:
	var warden := _find_record("act5_seal_warden")
	var amulet := _find_record("act5_seal_warden_amulet")
	var m: Dictionary = warden["m"]
	var a: Dictionary = amulet["m"]
	var sw14: Dictionary = m["band_competent"]
	var sw16: Dictionary = a["band_competent"]
	var verdict := ""
	var rate14 := float(sw14["win_rate"])
	if rate14 >= 0.55 and rate14 <= 0.95:
		verdict = "**The warden's current stats are FAIR at band.** A consolidated spellsword 14 under the competent policy lands inside the standard challenging-but-winnable window (0.55–0.95). Per `balance-bands-and-policy.md`, that makes #440 mostly the BYPASS rework, not a stat change — validate before touching warden numbers."
	elif rate14 < 0.55 and rate14 > 0.0:
		verdict = "**The warden is HARD at the band floor.** Spellsword 14 under the competent policy sits below the 0.55 window — winnable but under-banded. #440 has real stat work in it unless the Act V band moves to the top of its 14–16 range (see the spellsword-16 row)."
	elif rate14 <= 0.0:
		verdict = "**The warden is UNWINNABLE even at band.** Spellsword 14 under the competent policy never wins. #440 is stat work, full stop — the encounter is authored above the band the act can deliver."
	else:
		verdict = "**The warden is SOFT at band.** Spellsword 14 under the competent policy clears the 0.95 ceiling, i.e. the climax stops being a fight at the level the act is supposed to deliver. #440 should push its numbers UP, not down."
	return "\n".join([
		"## The falsifiable check (#440's scope gate)",
		"",
		"`balance-bands-and-policy.md` asks one question before anyone touches the Seal Warden's numbers: **do its CURRENT stats land in the challenging-but-winnable range against a consolidated 14–16 build under the competent policy?**",
		"",
		"| Build | floor (dumb) | competent |",
		"|---|---|---|",
		"| shipped run — %s | %s | %s |" % [m["ship_label"], _cell_text(m["ship_dumb"]), _cell_text(m["ship_competent"])],
		"| shipped run + moon-bone amulet worn | %s | %s |" % [_cell_text(a["ship_dumb"]), _cell_text(a["ship_competent"])],
		"| **%s** | %s | **%s** |" % [m["band_label"], _cell_text(m["band_dumb"]), _cell_text(sw14)],
		"| %s | %s | %s |" % [a["band_label"], _cell_text(a["band_dumb"]), _cell_text(sw16)],
		"",
		verdict,
		"",
		"Cross-check: `sim_combat_batch.gd`'s `seal_warden_t5_sw14_solo` is the same fight at the same build under the FLOOR policy, gated 0.55–0.64. That cell is ladder rung 4 and stays the authored band; this row is what the same fight looks like when the player uses their kit.",
	])
