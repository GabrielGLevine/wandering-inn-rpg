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
	# #449 [Spellspear], the EVOLVED-lineage spear spine. Through #438 this row
	# held relcs_spare_spear at all five acts, because items.json shipped three
	# spears (chipped_spear 0, solid_oak_spear 0, relcs_spare_spear +1) and the
	# best of them was the ACT I TUTORIAL GIFT: the mid-game bump every other
	# spine takes (rusty_sword -> gnollish_hunting_knife, training_bow ->
	# hunting_bow) had no spear equivalent at all. THAT GAP IS NOW CLOSED
	# (#438 equipment-gaps sketch): hedault_trued_spear at Act IV and
	# wyvernbone_lance at Act V, both +2, the first spear rungs above the
	# universal +1 ceiling. Acts I-III deliberately KEEP the gift -- neither new
	# spear is reachable before the Invrisil/sealed-area content that pays them,
	# and this spine's Act III cell is the table's standing ceiling drift (0.89),
	# which no lane may make worse by handing it earlier hardware.
	# guardsmans_pike is the spear family's T2 and is NOT in this ladder: it is
	# damage-flat against the gift by design (an acquisition path, not a power
	# rung), so it can never win a best-available slot. That flatness is
	# MEASURED, not assumed -- the #438 probe ran it at this spine's sibling Act
	# IV slot and read 0.80, byte-equal to the relcs_spare_spear baseline.
	# Report-only, like every derived spine row: no CALIBRATION row and no
	# reference window names it.
	"spellspear": ["relcs_spare_spear", "relcs_spare_spear", "relcs_spare_spear", "hedault_trued_spear", "wyvernbone_lance"],
	"innkeeper": ["rusty_sword", "rusty_sword", "gnollish_hunting_knife", "gnollish_hunting_knife", "gnollish_hunting_knife"],
	# #438 bow rungs. ashwood_warbow (+2) is the first bow above the universal
	# +1 ceiling and enters at Act IV, the act its Riverfarm drop is reachable.
	# Acts I-III are untouched: training_bow -> hunting_bow is the family's own
	# shipped T1 -> T2 step, and recurve_of_the_watch is damage-flat against
	# hunting_bow (a Watch-quest acquisition fork, not a rung), so it can never
	# win a best-available slot. READ THE NUMBERS BEFORE REACHING FOR THIS ROW:
	# the +1 rung moved `ranger` act IV by 0.00 (0.06 either way) and act V from
	# 0.33 to 0.36. The ranged spine's walls are NOT a hardware problem -- see
	# `_build_pc`'s WEAPON_RANGE comment in sim_combat_batch.gd, which measured
	# the same thing from the other side: the AI has no bow verb, so bow builds
	# fight at melee reach whatever they are holding.
	"ranger": ["training_bow", "hunting_bow", "hunting_bow", "ashwood_warbow", "ashwood_warbow"],
	"scout": ["training_bow", "hunting_bow", "hunting_bow", "ashwood_warbow", "ashwood_warbow"],
	"druid": ["rusty_sword", "rusty_sword", "gnollish_hunting_knife", "gnollish_hunting_knife", "gnollish_hunting_knife"],
	# --- #438: the three consolidation families added on 2026-08-13. The spine
	# roster DERIVES from classes.json `consolidations[]`, so each new row owes a
	# loadout in the same commit or `_derived_spines`' entry assert fires. Each
	# takes the act-appropriate progression its own weapon family actually ships,
	# which is the only honest way to read these rows:
	#   deathknight -- the SWORD track, identical to [Spellsword]'s. Its martial
	#     parent is plain [Warrior] and its own L14 grant [Grave Edge] is
	#     sword-gated exactly like [Keener Edge], so anything else would gate the
	#     class's marquee Skill out of its own measurement.
	#   skirmisher  -- the SPEAR track, identical to [Spellspear]'s, and it
	#     inherits that spine's ladder wholesale, including #438's two new
	#     Act IV/V rungs. Its own L14 grant [Steady Point] is spear-gated, so
	#     the spear is what the row must measure -- the bow half of the lineage
	#     reaches combat through inherited [Archer] grants, which
	#     `weapon_gated_kit` strips at a spear. That asymmetry is real and worth
	#     seeing in the table rather than papering over with a bow loadout.
	#   wild_sage   -- the sword track, identical to [Druid]'s: neither class
	#     gates a single grant on a weapon, so the loadout is the generic
	#     caster-with-a-sidearm progression its baseline already uses.
	# Report-only, like every derived spine row: no CALIBRATION row and no
	# reference window names any of them.
	"deathknight": ["rusty_sword", "rusty_sword", "gnollish_hunting_knife", "gnollish_hunting_knife", "gnollish_hunting_knife"],
	"skirmisher": ["relcs_spare_spear", "relcs_spare_spear", "relcs_spare_spear", "hedault_trued_spear", "wyvernbone_lance"],
	"wild_sage": ["rusty_sword", "rusty_sword", "gnollish_hunting_knife", "gnollish_hunting_knife", "gnollish_hunting_knife"],
}
const WINDOW_FLOOR := 0.55
const WINDOW_CEILING := 0.85

## RULED MULTICLASSING (user ruling 2026-08-13, `docs/CHOICE-LOG.md`). A civil
## spine is EXPECTED to carry a martial line to clear the combat chokepoints, so
## its below-window climax cells at a civil-only band build are DESIGN, not
## defects — and the civil pace overshoot (#453 G6) is that multiclass level
## budget rather than a slope error.
##
## THE ANNOTATION MOVES NO GATE. `SPINE_CLIMAX_IDS` gates the five reference
## climaxes in the `band` column and nothing else; not one per-spine cell has
## ever been asserted, before the ruling or after it. What changes is what the
## row TELLS a reader: "WALL — report only" named an open design question, and
## the ruling closed it.
##
## WHY THESE THREE. [Innkeeper] (helper x diplomat) and [Scout] (rogue x archer)
## are the civil spines the ruling names. [Druid] (beast_tamer x mage) joins for
## its walled cells, per #453 C3's PACE-vs-KIT table (PR #471): 15 of that
## table's 17 walls are KIT — the spine over-levels its band and loses anyway —
## and the druid's sit in that 15. Note WHY a wall in THIS table can only be a
## KIT read: every cell here is measured AT the act's band allocation, imposed
## rather than earned, so pace cannot reach it at all. PACE is
## `tests/sim_progression_pace.gd`'s question, and C3's one structural-PACE
## finding (scout held NO class in Act I) was answered by G2 — `rogue`'s
## `gained_by` now takes `crossed_under_cover`, so even that cell is a kit read
## today.
##
## The martial spines are deliberately absent. A below-window `ranger`,
## `spellsword` or `spellspear` cell stays a bare WALL: no ruling says a martial
## spine needs a SECOND line to clear its own climaxes, so that row is still an
## open question and must keep reading like one.
const RULED_MULTICLASS_SPINES := ["innkeeper", "scout", "druid"]
const RULED_MULTICLASS_NOTE := "RULED: multiclass-expected (2026-08-13)"

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
		"bypasses": "None (act climax). `relc_descent` is a veto beat, not an out: [Go together] banks `relc_joined_descent`, which is the boss's `ally_requires`. This is the JOIN route — Awakened + 2 scouts + a Sewer Bat, with Relc — and the veto route is no longer inferred from it: it is measured, one row down, off the entity's own `solo_enemies`.",
	},
	# #448 THE VETO BRANCH, MEASURED. Same entity, same beat, the OTHER answer at
	# the fork. It exists because the #439 retune quietly turned a hard-mode
	# choice into a trap: the join pack fought with the ally slot empty read 0.04
	# competent-at-band, so refusing Relc was a refusal to win the act. The user
	# ruling (CHOICE-LOG 2026-08-12) is that the veto branches to a DIFFERENT
	# FIGHT in [0.35, 0.45], not to a wall and not to a free skip, and that
	# fixing it must not touch the join route — so `solo: true` here reads the
	# entity's `solo_enemies` and fields NO ally, exactly as `start_combat` does
	# when `ally_requires` goes unmet, and the row above is left alone.
	{
		"id": "act3_awakened_boss_solo", "act": "III", "beat": 15, "map": "sewers/deep_tunnels", "entity": "awakened_boss",
		"ship": "ship_act3", "band": "band_act3", "draughts": [], "solo": true,
		"bypasses": "None (act climax), and no ally: this is the [I go alone.] branch. RULED WINDOW, not the reference window — the fight is DESIGNED to sit under 0.5, so the five-climax [0.55, 0.85] band would be the wrong gate and `SPINE_CLIMAX_IDS` deliberately omits it. The floor column is expected LOSS-heavy and is report-only; competent-at-band is the contract.",
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
	# #460 THE CRYPT LICH, the summoner archetype's own optional pocket. Measured
	# beside `act4_ruin_guardian` because it shares that row's map and band, and
	# because the pair is the honest comparison: the act's set-piece against the
	# side fight that must sit under it.
	#
	# THIS ROW IS THE SEC.3 GUARDRAIL. The competent-at-band read is gated through
	# RULED_WINDOWS at the reference window's own edges -- the fight has to be
	# winnable by a player who spends their kit AND unwinnable by one who does not
	# bother, with the summons AND the death magic priced in. The FLOOR column is
	# report-only, as the spec asks.
	{
		"id": "act4_crypt_lich", "act": "IV", "beat": 22, "map": "ruin/ruin_surface", "entity": "crypt_lich_mouth",
		"ship": "ship_act4", "band": "band_act4", "draughts": ["mending_draught"],
		"bypasses": "FULLY OPTIONAL: interact-only (no trigger_radius), on no route and on no existing pin, so declining it costs nothing but the levels it pays. It does not respawn -- one raising of this crypt per save.",
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
	#
	# #438 (2026-08-13) THE CAPSTONE/WARDEN REBALANCE, and the three rows it could
	# not reach. The 2026-08-13 ruling authorised capstone stat-growth trims AND
	# warden-side movement (a sanctioned frozen-block exception), under a
	# NO-AUTO-WIN principle: no build may beat the Warden 100/100, and one that
	# cannot be brought down is a red flag to SURFACE, not to tune around.
	#
	# WHAT SHIPPED. classes.json's flat-growth rule (no class grows >1 point per
	# level into one stat — see its `meta._comment_stat_growth`), and seal_warden
	# con 112 -> 134. Both are documented where the data lives. After them, every
	# AT-BAND row at this fight is inside [0.55, 0.85] for the first time:
	# spellsword14 0.78 -> 0.70, spellsword16 0.86 -> 0.77, the steel thread's own
	# worn-amulet build 0.89 -> 0.76, spellspear14 0.73 -> 0.60, druid14
	# 0.97 -> 0.82, and deathknight14 0.58 -> 0.41 -> 0.66 after its kit relief.
	#
	# WHAT IT COULD NOT REACH, and WHY — this is the finding, not an excuse:
	#   t6 0.88, t12 0.93, s16 0.98. These three are NOT a capstone-power problem.
	#     They are LEVEL BUDGET. `WIProgression.effective_power` puts them at 17.8,
	#     21.7 and 24.7 against an act whose authored band is 14-16, and win rate
	#     tracks that budget smoothly across the whole column (14 -> 0.70,
	#     16 -> 0.77, 17.8 -> 0.88, 21.7 -> 0.93, 24.7 -> 0.98). A fight authored
	#     for 14-16 SHOULD be won by a 24.7 build; the row is reading an over-band
	#     PC, and no warden that leaves the band build winnable can catch it.
	#   wild_sage14 0.98 at effective power 14 — the band FLOOR. This one is not a
	#     level read at all, and it is the sharpest finding in the lane: it is the
	#     BONDED WOLF. Measured with `tests/_warden_probe.gd`, same build, same
	#     warden, companion withheld: wild_sage14 and druid14 both read 0.19
	#     competent / 0.04 floor. The second body is worth +0.79. That dwarfs every
	#     stat, Skill and item in this table combined, and it is REAL rather than a
	#     harness artefact — `wi_game.gd:2352` fields the companion whenever the
	#     arena has a free player spawn, and `vault` has four.
	#
	# #438 KIT GAP, THE SECOND HELPING (2026-08-13, user ruling: "Skirmisher walls
	# are a kit/Skill gap — fill the kit"). skirmisher14 read 0.26 here, the
	# lowest martial cell in the table. SCOPE OF THE FINDING, stated as measured
	# rather than as a universal: among the FIVE spines whose Act V build stands
	# at 48 max HP — spellsword, spellspear, deathknight, ranger, and skirmisher
	# before this lane — the ones that clear this fight are exactly the ones
	# carrying an effective-HP buffer ON TOP of that 48. [Spellsword]/
	# [Spellspear]/[Deathknight] hold [Mana Shield] over a 19-point MP pool
	# (67 EHP; 0.70/0.60/0.66); the two with no buffer are skirmisher 0.26 and
	# ranger 0.33, precisely the two that wall. The other four derived spines are
	# NOT at 48 and are not part of this read (measured, `_kit_probe.gd`, Act V:
	# innkeeper 52, wild_sage 52, druid 52, scout 38 — and the last three carry a
	# second body or a civil ruling of their own). So for the 48-HP family the
	# buffer, not the damage, is what this row has been measuring, and [Ranger] is
	# the same finding still open — see the reachability note below before
	# assuming its remedy is free.
	#   WHY A NEW SKILL AND NOT THE DEATHKNIGHT RE-GRANT: [Mana Shield] is INERT
	#   on this lineage. `_new_combatant` sets `max_mp` only when the kit holds a
	#   skill carrying `mp_cost`, and spearmaster x archer ships none at any
	#   level — measured with `tests/_kit_probe.gd`, granting it reads 0.26 ->
	#   0.26 at mp 0. [Give Ground] (hp_bonus 10, [Tough Body]'s block verbatim)
	#   is the shape that works without mana: 0.26 -> 0.61, and the A/B that
	#   sized it (+4 0.45, +8 0.56, +12 0.68) is in the skill's own record.
	#   THE MECHANISM IS A STEP, NOT A SLOPE, and it is worth knowing for every
	#   future row here: `WICombatPolicies._survive`'s hit floor is 1.5x the
	#   biggest hit a living foe could land, which against this warden is
	#   1.5 * int((17/2 + 8) * 2.0) == 48.0 — EQUAL to the 48 max HP the family
	#   above carries. `hp <= hit_floor` is therefore true at FULL HEALTH, so the
	#   competent policy opens the fight by healing for 0 and burning [Second
	#   Wind]'s `once_per_fight`.
	#   WHAT THE TEN HP ACTUALLY BUY, and the numbers belong to named builds
	#   because they disagree with each other (100 seeds, competent, this row):
	#     skirmisher14 PRE-lane, 48 HP (reproduce with WI_KIT_ABLATE=give_ground):
	#       0.26 / 3 rd with [Second Wind], 0.26 / 3 rd without. Worth 0.00 and
	#       zero rounds — it is spent at full health every time.
	#     skirmisher14 SHIPPED, 58 HP: 0.61 / 5 rd with, 0.43 / 5 rd without.
	#       Worth +0.18. The HP did not merely add HP; it lifted the build out of
	#       the permanent death band and SWITCHED ON a Skill the class already had.
	#     ship_act5 (the steel thread's own w12/m2/d7/t2, 52 HP) — this is the
	#       build the ablation probe below prints, and it is a THIRD answer:
	#       0.62 / 5 rd with, 0.64 / 4 rd without. Worth -0.02 and one round
	#       SHORTER. Do not read that line as a statement about any other build.
	#   ACTS I-IV ARE REACHABLE — the earlier draft of this comment said they were
	#   not, and that was wrong. `_spine_build` holds the two PARENT lines below
	#   Act V, so nothing on the skirmisher TABLE reaches them; but a grant placed
	#   on `archer` at L<=2 does, and it need not disturb a sibling: [Keen Eye] is
	#   an [Archer] L1 grant with NO `weapon` key and is in this spine's measured
	#   act2 kit AT A SPEAR, so the gate is a choice rather than a law, and
	#   data_lint.py contains zero occurrences of "weapon" — nothing forbids it.
	#   A spear-gated archer grant is stripped from `ranger` and `scout`, the only
	#   other spines inheriting [Archer], because SPINE_WEAPONS gives both a bow at
	#   all five acts.
	#   THE REAL REASON act2 STAYS OPEN IS OVERSHOOT ON THIS SPINE'S OWN CELLS.
	#   Measured, `_kit_probe.gd` WI_KIT_ADD=give_ground, the same +10 HP reaching
	#   each cell: act2 0.40 -> 0.67 (in window) and act4 0.80 -> 0.83 (in window),
	#   but act3 0.72 -> 0.88 — ABOVE the 0.85 ceiling. Carried on the spearmaster
	#   side instead it also takes act1 0.79 -> 0.96. So the cheapest reaching edit
	#   fixes one cell and breaks another on the same spine, and act2 needs its own
	#   ruling with a differently-sized or differently-shaped grant, NOT a claim
	#   that it cannot be reached. It is UNCHANGED by this lane, as is every other
	#   cell in the table.
	#
	# WHY NO FURTHER WARDEN MOVEMENT. Sized by its cost, A/B at 100 seeds
	# (`_warden_probe.gd`), band build vs the ceiling row it was aimed at:
	#   str 17 -> 26        spellsword14 0.78 -> 0.45   s16 1.00 -> 0.97
	#   weapon_die 8 -> 14  spellsword14 0.78 -> 0.52   s16 1.00 -> 0.98
	#   con 112 -> 140      spellsword14 0.78 -> 0.64   s16 1.00 -> 1.00
	# Every lever taxes the band build 3-10x harder than the row it is aimed at,
	# because the over-band rows win the damage race in 2-3 rounds and never eat
	# the extra dice. con was chosen as the least-bad of the three and sized to the
	# largest value that keeps the at-band span in window. Pushing further buys
	# 0.01 a step off the ceiling rows and spends 0.05 a step off the floor.
	#
	# CAPSTONE GROWTH IS NOT THE MECHANISM, MEASURED. `strategist.stat_growth.int`
	# 2 -> 1 (the trim that shipped) moves s16 1.00 -> 0.99; 2 -> 0 reaches only
	# 0.92. The trim is right on its own terms — it is a uniform data rule and it
	# retired a convention that had spread to seven classes — but it is NOT what
	# was trivializing this fight, and the record should not pretend otherwise.
	# Neutering the tactic Skills is likewise near-inert here (#450's own probe:
	# the high rungs move s16 by 0.00), and the whole family is out of scope.
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
		"why": "measured: PC 56 HP / ~29 DPR vs warden 142 HP / 28-30 per hit, death in 5 rounds, three identical runs at seed 9. THE WARDEN IS 164 HP AFTER #438 (con 112 -> 134) and this row is UNCHANGED — deliberately: what it asserts is the CATEGORICAL (the shipped kit loses under autoplay) plus the 5-round median, and both still hold at 0.34/5rd. The 142 is the provenance of the original measurement and stays as written; a ground-truth row records what was observed, not what is current"},
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

## THE RULED WINDOWS (#448). A per-row band, for a fight whose target is a USER
## RULING rather than the five-climax policy window.
##
## Why this is not a CALIBRATION row: `CALIBRATION` gates a CATEGORICAL
## (WIN/LOSS at 0.5), and the whole defect #448 names is a row that was already
## on the correct side of that line. The veto branch read LOSS 0.04 and a
## `want: LOSS` row would have passed it green. A ruled band needs both edges
## asserted or it does not gate the thing it was written for.
##
## Why not `WINDOW_FLOOR`/`WINDOW_CEILING`: those are the five reference
## climaxes' shared policy window, [0.55, 0.85], and they encode "hard enough to
## gate the act, winnable by a player who spends their kit". A hard-mode OPT-IN
## is a different contract and belongs under 0.5 by construction, so it takes
## its own window instead of widening everyone else's.
##
##   `row` / `column` ("ship"|"band") / `policy` / `lo` / `hi`
const RULED_WINDOWS := [
	# #460 THE SUMMONER GUARDRAIL (spec sec.3.2, RATIFIED 2026-08-13). The numbers
	# are `WINDOW_FLOOR`/`WINDOW_CEILING` themselves, referenced rather than
	# copied, because the spec asks this optional pocket to hold the SAME
	# competent-at-band contract the five reference climaxes hold. It rides
	# RULED_WINDOWS instead of `SPINE_CLIMAX_IDS` for the reason that list exists:
	# it enumerates the five ACT CLIMAXES, and this is not one -- it is a fight a
	# player may decline. What it is not allowed to be is unwinnable for a player
	# who spends their kit, or free for one who does not.
	{"row": "act4_crypt_lich", "column": "band", "policy": "competent", "lo": WINDOW_FLOOR, "hi": WINDOW_CEILING,
		"why": "spec sec.3.2 (#460, RATIFIED): the summoner encounter lands competent-at-band inside [0.55, 0.85] with the summons AND the death magic priced in. Measured 0.76 / 4 rd at the landing commit, with the fight_limit allowance EXHAUSTED in 100/100 seeds -- so this row is also the sec.3.3 limit-ceiling read, and `tests/sim_summon_ceiling.gd` re-derives that (plus the 0.74 pre-placed counterfactual) on demand. Composition-only tuning if it moves (count/fight_limit/cooldown/placement and the NEW crypt_lich/bone_thrall rows); a policy change is a STOP-and-report, never a silent edit"},
	{"row": "act3_awakened_boss_solo", "column": "band", "policy": "competent", "lo": 0.35, "hi": 0.45,
		"why": "user ruling 2026-08-12 (#448, CHOICE-LOG): Relc's veto branches to a hard solo fight, not a wall. 0.35-0.45 competent-at-band, with the pre-#439 solo read of 0.37 named as the reference feel"},
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


## #448 THE TWO BRANCHES OF AN ALLY-GATED FIGHT, read the way the game reads
## them. A row marked `solo` is the veto branch: no ally, and the roster is the
## entity's `solo_enemies` — the SAME field `wi_game.start_combat` swaps in when
## `ally_requires` goes unmet. Static so `test_spine_calibration.gd` builds its
## cells through these too; a table row and a CI gate row naming the same fight
## must BE the same fight, and this is the one place that is decided.
##
## The `solo_enemies` assert is the point of the helper, not an afterthought:
## silently falling back to `enemies` would measure the JOIN pack, report it as
## the veto branch, and hand back exactly the 0.04-shaped lie #448 exists to
## kill — green, and wrong.
static func row_enemies(row: Dictionary, entity: Dictionary) -> Array:
	if not bool(row.get("solo", false)):
		return entity.get("enemies", []) as Array
	assert(entity.has("solo_enemies"),
		"row %s is the veto branch but entity %s authors no solo_enemies" % [row["id"], entity.get(WIKeys.ID, "?")])
	return entity.get("solo_enemies", []) as Array


static func row_allies(row: Dictionary, entity: Dictionary) -> Array:
	return [] if bool(row.get("solo", false)) else (entity.get("allies", []) as Array)


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
	var allies: Array = row_allies(row, entity).duplicate()
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
		combat.summon_catalog = cell.get("summon_catalog", {})
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
			for ally_v: Variant in row_allies(row, entity):
				var ally: Dictionary = (by_id[String(ally_v)] as Dictionary).duplicate(true)
				var hp_mods: Dictionary = row.get("ally_hp_mods", {})
				if hp_mods.has(String(ally_v)):
					ally[WIKeys.HP_MOD] = int(ally.get(WIKeys.HP_MOD, 0)) + int(hp_mods[String(ally_v)])
				cfgs.append(ally)
			for enemy_v: Variant in row_enemies(row, entity):
				cfgs.append(WIBountyScaling.scale_enemy((by_id[String(enemy_v)] as Dictionary).duplicate(true), rank))
			for policy_name: String in [WICombatPolicies.DUMB, WICombatPolicies.COMPETENT]:
				measured["%s_%s" % [column, policy_name]] = _measure({
					"row": row["id"], "build": build["name"], "policy": policy_name,
					"arena": arena, "cfgs": cfgs, "skills": skills,
					"items_by_id": items_by_id, "draughts": row["draughts"],
					# #460: the roster a `summon` Skill reaches for. Threaded the same way
					# `wi_game.start_combat` injects it, so a summoner row measures the
					# fight a player actually gets; an unwired harness would push_error and
					# then measure a Lich that never raises anything.
					"summon_catalog": by_id,
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
			for enemy_v: Variant in row_enemies(row, entity):
				cfgs.append(WIBountyScaling.scale_enemy((by_id[String(enemy_v)] as Dictionary).duplicate(true), rank))
			var m := _measure({
				"row": row_id, "build": build["name"], "policy": WICombatPolicies.COMPETENT,
				"arena": record["arena"], "cfgs": cfgs, "skills": skills,
				"items_by_id": items_by_id, "draughts": row["draughts"],
			})
			_spine_rows.append({"spine": spine["target"], "row": row, "build": build, "m": m})
			# The disposition prints on the RUN LINE, not only in the written doc:
			# a table nobody regenerates is where a ruling goes to rot, and the
			# console read is the one every gate operator actually sees.
			print("[spine-class] %-11s %-28s %-22s %-24s %s" % [
				spine["target"], row_id, build["label"], _cell_text(m),
				_spine_disposition(m, String(spine["target"])),
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
	_check_ruled_windows()
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
	print("PASS: spine viability table generated; all %d calibration rows agree, all %d reference climaxes are inside [%.2f, %.2f], and all %d ruled band(s) hold" % [
		CALIBRATION.size(), SPINE_CLIMAX_IDS.size(), WINDOW_FLOOR, WINDOW_CEILING, RULED_WINDOWS.size(),
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


## #448. BOTH EDGES ARE THE GATE. Below `lo` the fight is the wall the ruling
## forbids; above `hi` it is the free skip the ruling also forbids. A
## categorical would catch neither.
func _check_ruled_windows() -> void:
	for ruled: Dictionary in RULED_WINDOWS:
		var record := _find_record(String(ruled["row"]))
		if record.is_empty():
			_failures.append("[ruled] window names an unknown row %s" % ruled["row"])
			continue
		var m: Dictionary = (record["m"] as Dictionary)["%s_%s" % [ruled["column"], ruled["policy"]]]
		var rate := float(m["win_rate"])
		if rate < float(ruled["lo"]) or rate > float(ruled["hi"]):
			_failures.append("[ruled] %s / %s / %s: %.2f outside the RULED band [%.2f, %.2f] over %d seeds. This band is a user ruling, not a policy default — move the composition, never the window. Ruling: %s" % [
				ruled["row"], ruled["column"], ruled["policy"], rate,
				float(ruled["lo"]), float(ruled["hi"]), _runs, ruled["why"]])


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
	out.append("The spine list is derived from every target in `data/classes.json`'s `consolidations`; no class id is duplicated here by hand. Acts I–IV use the target's two base parent lines at the same 2, 3/2, 5/4, and 7/6 band allocations as the original Spellsword seed; Act V uses the consolidated class at level 14. Druid fields its bonded wolf when the live arena-capacity rule permits it. Below-window class rows on the MARTIAL spines are WALLS for controller adjudication, not retune orders; above-window rows are ceiling WINDOW DRIFT.")
	out.append("")
	out.append("**RULED MULTICLASSING (user ruling 2026-08-13, `docs/CHOICE-LOG.md`).** A civil spine is expected to carry a martial line to clear the combat chokepoints, so a below-window climax cell on `%s` is **design, not a defect** — it is marked `%s` rather than WALL, and the civil pace overshoot (#453 G6) is that multiclass level budget, not a slope error. Nothing about the gate moved: no per-spine cell has ever been asserted, before the ruling or after it. What the ruling settles is what the row MEANS. [Druid] is included for its walled cells per #453 C3's PACE-vs-KIT table (PR #471), which classified 15 of 17 walls as KIT — the spine over-levels its band and loses anyway — and every cell in this table is measured AT the act's band allocation, so a wall here can only be a kit read; pace is `tests/sim_progression_pace.gd`'s question. Martial spines are excluded: their below-window cells stay bare WALLs, because no ruling says a martial spine needs a second line to clear its own climaxes." % [
		"`, `".join(RULED_MULTICLASS_SPINES), RULED_MULTICLASS_NOTE])
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
	out.append("### Ruled windows (bands set by a user ruling, both edges asserted)")
	out.append("")
	out.append("A calibration row gates a categorical at 0.5; these gate a BAND. They exist for fights whose target came from a ruling rather than from the five-climax policy window, and where being on the right side of 0.5 is not the contract. Move the composition to meet the window, never the window to meet the measurement.")
	out.append("")
	out.append("| Row | Column | Policy | Ruled band | Measured | Ruling |")
	out.append("|---|---|---|---|---|---|")
	for ruled: Dictionary in RULED_WINDOWS:
		var rrecord := _find_record(String(ruled["row"]))
		var rm: Dictionary = (rrecord["m"] as Dictionary)["%s_%s" % [ruled["column"], ruled["policy"]]]
		var inside := _window_position(rm, float(ruled["lo"]), float(ruled["hi"])) == "inside"
		out.append("| `%s` | %s | %s | [%.2f, %.2f] | %s %s | %s |" % [
			ruled["row"], ruled["column"], ruled["policy"], float(ruled["lo"]), float(ruled["hi"]),
			"✅" if inside else "❌", _cell_text(rm), ruled["why"]])
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
	out.append("- **floor LOSS / competent LOSS** — a real wall. Either the build is under band or the encounter is over it. In the class-derived table, a below-window competent row on a martial spine is reported as a WALL for adjudication; it is not permission to flatten the shared encounter for every stronger spine. On the ruled civil spines the same cell reads `%s` instead — the ruling above answered it." % RULED_MULTICLASS_NOTE)
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
			_cell_text(m), _spine_disposition(m, String(record["spine"])),
		])
	return "\n".join(out)


func _spine_disposition(m: Dictionary, spine: String) -> String:
	var position := _window_position(m, WINDOW_FLOOR, WINDOW_CEILING)
	if position == "below":
		# The 2026-08-13 ruling, applied where the row is read rather than in a
		# hand-maintained note: a civil spine's walled cell is the multiclass
		# expectation, not an unanswered balance question.
		if RULED_MULTICLASS_SPINES.has(spine):
			return RULED_MULTICLASS_NOTE
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


## The per-spine half of `_find_record`. Findings that compare spines need the
## class table's cells, not the ship/band ones.
func _spine_cell(spine: String, row_id: String) -> Dictionary:
	for record: Dictionary in _spine_rows:
		if String(record["spine"]) == spine and String((record["row"] as Dictionary)["id"]) == row_id:
			return record["m"]
	return {}


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
		"2. **[Second Wind] trades an attack for healing, and the policy spends it automatically.** 2 AP buys 8 HP or roughly 20 damage forgone. Ablation against the warden measures %s with it and %s without; those adjacent measurements are the result, without inferring a win-rate gain or loss when they tie. A player under 35%% HP heals, so this records what 'competent, not optimal' costs. THE DATA SHAPE, corrected: [Second Wind] carries `once_per_fight: true` and no `cooldown_rounds` (data/skills.json; the bound landed in 0f5225d3, the #454 lineage-completeness commit). An earlier version of this line said it carried NEITHER and flagged an unbounded-heal data seam -- that was false, and there is no seam: it is the tightest-bounded resource in the kit, exactly one use per fight. The bound has its own consequence, which is worth pricing in its place: `_survive` fires on a hit-floor term as well as the 35%% one -- 1.5x the biggest hit any living foe could land -- so a build whose max HP sits at or under that floor spends its ONE heal at FULL health, for 0, on round one. That is not hypothetical: at 48 max HP against this warden the floor is exactly 48.0, and ablating [Second Wind] from the pre-#438 skirmisher14 build moved it by 0.00 (0.26 / 3 rd either way), against +0.18 on the same class once ten points of max HP lifted it clear of the floor." % [
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
		"",
		"8. **THE SECOND BODY IS THE BIGGEST NUMBER IN THIS TABLE (#438).** At the Act V climax the two bonded spines measure %s (`wild_sage14`) and %s (`druid14`), against %s for `spellsword14` — the SAME band allocation, the same effective power of 14, the same act. The gap is not stats and not the kit: it is the wolf. Withhold the companion and hold everything else fixed (`tests/_warden_probe.gd`, `WI_PROBE_NO_COMPANION=1`, 100 seeds) and both rows read **0.19 competent / 0.04 floor** — byte-identical to each other, because their stat growth and their re-flavored grants are identical too. **The bonded companion is worth about +0.79 win rate at this fight**, more than every stat, Skill, weapon and accessory in this table combined. It is not a harness artefact: `wi_game.gd:2352` fields the companion whenever the arena has a spare player spawn and `vault` has four, so a druid really does fight the solo finale two-on-one. That is the finding the #438 lane surfaces rather than tunes: no warden stat reaches it (at con 140 `wild_sage14` still reads 0.96 while the band build falls to 0.64), because the lever that shortens a 2v1 is composition, not HP. Whether a climax authored SOLO should field a companion at all is a design question for the encounter, and it is now on the record with a number attached." % [
			_cell_text(_spine_cell("wild_sage", "act5_seal_warden")),
			_cell_text(_spine_cell("druid", "act5_seal_warden")),
			_cell_text(_spine_cell("spellsword", "act5_seal_warden"))],
		"",
		"9. **The capstone growth trim was right, and it was not the mechanism (#438).** classes.json's flat-growth rule retired an 'evolution bump' convention that had spread to seven classes one citation at a time. It is a real correction — the band yardstick grows 1+1 and nothing should out-stat it 2:1 — and `data_lint.py::check_stat_growth_flat` now keeps it from creeping back. But measured against the fight it was reached for, `strategist.stat_growth.int` 2 → 1 moves the strategist-16 row 1.00 → 0.99. The rows that were over the ceiling were over it for TWO other reasons: an over-band level budget (finding above) and the wolf. Trimming class data was the first lever the ruling named and the smallest one that was actually there; recording that honestly is worth more than a tidy causal story.",
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
