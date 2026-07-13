extends SceneTree
## Balance harness: seeded AI-vs-AI runs across a composition x build matrix.
## Compositions: goblin_ambush (raider+shaman, arena goblin_ambush) and
## chieftains_raid (chieftain+raider+spider, arena cave_mouth). Builds: see
## BUILDS below — all granted via WIProgression.granted_skills.
## Allies: relc, in every non-solo cell. 100 seeds per cell (1800 fights).
## Asserts per GATED cell: win_rate 0.55-0.95, median rounds 3-12; measured
## cells are recorded-only (no bounds contract). relc_downed_rate is printed
## for every non-solo cell (WAVE A2 frontier metric, recorded-only).
## LOADOUT_CELLS below adds a measured-only equipment axis
## (weapon/armor from data/items.json, injected the same way wi_game.gd's
## `_build_player_combatant` does) layered onto existing composition+build
## pairings — 5 cells x 100 seeds (500 more fights), never touching the
## gated matrix's construction above.
## The LOADOUT_CELLS loop's weapon-gate filter and
## accessory-mod summation now call `WICombatBuild.weapon_gated_kit`/
## `equipment_mods` (`src/core/combat_build.gd`) -- the SAME functions
## `wi_game.gd`'s `_build_player_combatant` calls -- instead of hand-mirrored
## copies (a manual-sync drift class; keep the shared functions shared).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd
##
## REGION TIERS (issue #66, THE AUTHORITY -- docs/design/region-tiers.md is a
## content-author-facing copy of this exact table, keep both in sync). Fixed
## tiers, no scaling-to-player (canon-hostile; ratified 2026-07-11): a region's
## roster is tuned to the build a player is EXPECTED to hold at first arrival,
## never re-tuned to whatever level the player actually is. A consolidated
## build wandering back to a lower tier SHOULD trivialize it -- that is
## progression feeling real, not a balance bug. The only bug this table fixes
## is the inverse: a NEW area opened at the frontier failing to press the
## frontier build.
##   | Tier | Regions                                   | Expected build           | Notes |
##   |------|--------------------------------------------|---------------------------|-------|
##   | T1   | Inn/Liscor/floodplains (tutorial + the 3   | warrior 1-4               | existing goblin_ambush/chieftains_raid cells already band here |
##   |      | starter quests)                            |                            | |
##   | T2   | Sewers, descent, door chain                | 4-7 (first consolidation  | existing ENCOUNTER_CELLS/BOSS_CELLS/RUIN_CELLS bands roughly hold -- verified, untouched |
##   |      |                                             | possible at the tail)      | |
##   | T3   | Riverfarm + Invrisil (post-door unlocks)   | 8-10, MONO (consolidation | RE-RETUNE SET (class-foundation pass R3, 2026-07-12) -- BUILDS.t3_warrior10 is now the GATING reference (t3_spellsword9/t3_warrior9 are measured historical baselines: [Spellsword]'s new floor, 14, makes "spellsword ~9" unreachable by real play) |
##   |      |                                             | no longer reachable here) | |
##   | T4   | Dungeon (8d)                               | 10-12 + the Horns party    | bands derived WITH allies from day one; PARTY_CELLS is the first 4-ally harness. GATED vault cell stays PINNED to t4_spellsword11_party (shipped, working); t4_spellsword14_party is the R3 real-floor MEASURED companion |
##   | T5   | Pallass (8e)                               | 12-14                      | authored to table at build time, not retuned here |
## Off-tier cells (a build below or above its encounter's tier) stay
## MEASURED-only -- e.g. this file's own goblin_ambush/chieftains_raid matrix
## against pure_warrior10 is a deliberate over-tier read: a T1 comp facing a
## T3+ build is EXPECTED to read near-1.0/trivial, and that expectation is
## itself the design contract, never a gate to hit.

const RUNS_PER_CELL := 100

## Sharding hooks (scripts/harness_shard_diff.sh) -- OFF by default (both
## env vars unset), in which case every cell runs and output is
## byte-identical to before these existed. WI_CELL_COUNT_ONLY=1 prints the
## total cell count and quits before any fight runs (cheap: no data load
## needed, the CELLS consts are known at compile time). WI_CELL_RANGE=LO:HI
## (0-based, inclusive, global index across every "for cell in ..." loop IN
## RUN ORDER, including the COMPOSITIONS x BUILDS matrix) skips any cell
## outside the range -- _cell_idx always advances so shard boundaries stay
## stable regardless of which shard is asked to run. Per-cell seeds (1..
## RUNS_PER_CELL) are always LOCAL to that cell's own loop, never a shared
## stream across cells, so a skipped cell can never perturb a run cell's
## RNG -- this is what makes shard N's output byte-identical to the same
## cell's slice of an unsharded run.
var _cell_idx := -1
var _range_lo := -1
var _range_hi := -1

func _cell_in_range() -> bool:
	_cell_idx += 1
	if _range_lo < 0:
		return true
	return _cell_idx >= _range_lo and _cell_idx <= _range_hi

const COMPOSITIONS := [
	{"name": "goblin_ambush", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"]},
	{"name": "chieftains_raid", "arena": "cave_mouth", "enemies": ["goblin_chieftain", "goblin_raider", "cave_spider"]},
]

## `ai` selects the PC's WICombatAI profile (default "melee"). `gated` builds
## assert the win-rate/median bounds; ungated builds are RECORDED-only — a
## measurement axis, not a contract. The caster build exists because the
## melee-profile PC NEVER casts (documented autoplay gotcha), so the mage
## build's whole win-rate edge reads as passive [Mana Shield]; the "caster"
## profile leads with spells then falls through to melee when mana-dry, which
## is the only way this harness measures a mage kit's ACTIVE spell
## contribution (the spec §2.4 dual-kit confound).
##
## Additive per-class stat_growth,
## scaled by the split-efficiency multiplier (kept from T4), ADDED to base
## template stats (see WIProgression.derived_stat_bonuses / apply_stat_bonuses
## / _build_player_combatant). Unlike T4's multiply-only reading, FOCUSED
## builds now also move (they gain the full class stat bonus at efficiency
## 1.0) -- so `warrior2`'s gated win-rate bounds reflect this task's baseline,
## not pre-T4b behavior. `warrior2_mage2` is a split -- under active
## split-efficiency friction its win rate is recorded, not gated, same as its
## caster sibling. The `pure_warrior10`/`pure_mage10_caster`/`warrior5_mage5`/
## `warrior5_mage5_caster` axes are the §2.4 power-axis matrix: a focused
## level-10 build vs. its 5/5 split counterpart, melee and caster profile.
## The harness builds combatants DIRECTLY from
## combatants.json, bypassing WIGame/`_build_player_combatant` entirely --
## so equipment would be invisible to this harness without this section.
## Each cell below layers a weapon/armor pair (data/items.json ids, "" = none
## equipped) onto an EXISTING composition+build pairing (looked up by name
## below, never redefined) and runs its own 100-seed series. Deliberately
## NOT a full cross-product -- 5 design-relevant cells per plan §5:
## (a) the shipped-default control (sword, rusty_sword's mods are 0, should
## match the plain `warrior2`/`goblin_ambush` cell above within noise),
## (b) the spear identity fork (Relc's gift, +1 damage_mod, gates OUT
## power_strike/IN piercing_strikes -- but combat_ai.gd's `_act_melee` only
## ever calls power_strike BY NAME (see inventory_loop's documented finding),
## so this measures the flat damage_mod alone, not a piercing_strikes proc),
## (c) sword + leather_jerkin armored (the inn_chest starter piece),
## (d) the tutorial SOLO bar with the same early armor (does it trivialize
## the "not trivially easy" bar WAVE A/A2 established?),
## (e) the hardest composition's split build with the gambeson's flat
## damage_reduction. ALL measured (no bounds contract) -- the existing gated
## cells above stay gated AND UNCHANGED in construction (no equipment), which
## is what pins the pre-M7 canonical seeds.
const LOADOUT_CELLS := [
	{"name": "warrior2_sword", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": ""},
	{"name": "warrior2_spear", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "relcs_spare_spear", "armor": ""},
	{"name": "warrior2_sword_armored", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin"},
	{"name": "warrior1_tutorial_solo_armored", "comp": "goblin_ambush", "build": "warrior1_tutorial_solo", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin"},
	{"name": "warrior2_mage2_gambeson", "comp": "chieftains_raid", "build": "warrior2_mage2", WIKeys.WEAPON: "rusty_sword", "armor": "watch_issue_gambeson"},
	## Accessory cells (measured-only, same convention as the
	## 5 weapon/armor cells above). Each cell's optional `accessories` key is
	## a list of `data/items.json` accessory ids whose damage_mod/hp_mod/
	## damage_reduction are SUMMED onto the same three fields alongside the
	## weapon/armor contribution -- a harness-local mirror of `wi_game.gd`'s
	## `_build_player_combatant` loop over `["accessory_1","accessory_2",
	## "accessory_3"]`. A cell omitting `accessories` behaves
	## exactly as before (empty list, zero contribution) -- the 5 cells above
	## are UNTOUCHED in both data and construction.
	## (1) `warrior2_max_legal_kit` / (2) its SOLO tutorial twin: the
	## realistic "chased every accessory legally obtainable at capacity 2"
	## kit -- copper_luck_band (res 0) + hedge_ward_charm (res 1) +
	## hunters_fang_talisman (res 1) = resonance 2, exactly at the shipped
	## capacity, so this is the actual best-case early loadout a real player
	## could equip today.
	## (3) `warrior2_mage2_stonescale_dr2`: stonescale_talisman (dr 1, res 2)
	## stacked with watch_issue_gambeson (dr 1) = dr 2 total, on the
	## chieftains_raid/warrior2_mage2 pairing the `warrior2_mage2_gambeson`
	## cell above already established -- the first dr-2 read in the M7
	## floor>=1 chain.
	## (4) `chieftains_hp_stack`: phosphor_pendant (hp+3) + hedge_ward_charm
	## (hp+2) = hp+5, resonance 1+1=2, on chieftains_raid/warrior2. Carries
	## rusty_sword (0 mods) so `WICombatBuild.weapon_gated_kit` still fields power_strike --
	## an empty weapon string would filter the kit down to untagged-only
	## skills (weapon_family "" only matches untagged), conflating "no
	## weapon equipped" with the accessory hp-stack read this cell wants
	## isolated. No armor, so hp+5 is entirely the accessories' contribution.
	## (5) `moon_bone_solo`: moon_bone_amulet's resonance was lowered so the
	## resonance 3 -> 2 (it was unequippable the moment it was awarded --
	## resonance_capacity never grows past its default 2 anywhere in this
	## codebase). Equal to capacity is legal (`equip()` refuses only
	## STRICTLY over capacity), so this is now a REAL fieldable solo kit, not
	## the capacity-unreachable measured-only curiosity it used to be --
	## renamed from `moon_bone_capacity_unreachable` and the `capacity_unreachable`
	## print-label flag dropped accordingly.
	{"name": "warrior2_max_legal_kit", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin", "accessories": ["copper_luck_band", "hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "warrior1_tutorial_solo_max_legal_kit", "comp": "goblin_ambush", "build": "warrior1_tutorial_solo", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin", "accessories": ["copper_luck_band", "hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "warrior2_mage2_stonescale_dr2", "comp": "chieftains_raid", "build": "warrior2_mage2", WIKeys.WEAPON: "rusty_sword", "armor": "watch_issue_gambeson", "accessories": ["stonescale_talisman"]},
	{"name": "chieftains_hp_stack", "comp": "chieftains_raid", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["phosphor_pendant", "hedge_ward_charm"]},
	{"name": "moon_bone_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["moon_bone_amulet"]},
]

## MEASURED-only cells for the two sewers encounters
## (shield_spider nest + sewer_vermin trash). Self-contained -- each carries
## its own arena/enemies/build (never touching COMPOSITIONS/BUILDS or the
## gated matrix above), so a new content encounter can never redden a balance
## gate. `build` names a BUILDS entry (resolved for its `classes`); `solo`
## drops the ally entirely; an optional per-cell `ally` string (issue #69,
## Klbkch's own alternation) names WHICH combatants.json ally id to field
## when `solo` is false -- defaults to "relc" so every pre-#69 cell's
## construction and print output are byte-identical. warrior2 is the
## representative level a player enters the sewers at. Numbers are recorded
## to the report, not bounded (a nest fight's difficulty is content, not a
## win-rate contract).
const ENCOUNTER_CELLS := [
	## shield_spiders_w2_relc is a legacy MEASURED hypothetical -- the real
	## `shield_spiders` encounter (skeleton_scene.json) never actually fielded
	## Relc (its own `allies` was `[]`); issue #69 wires that entity's real
	## `ally_requires` to Klbkch instead (`shield_spiders_w2_klbkch` below is
	## the cell that now matches live content). Kept for the historical
	## with-Relc read, no longer content-representative.
	{"name": "shield_spiders_w2_relc", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": false},
	{"name": "shield_spiders_w2_klbkch", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": false, "ally": "klbkch"},
	{"name": "shield_spiders_w2_solo", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": true},
	{"name": "shield_spiders_w1_solo", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior1_tutorial", "solo": true},
	{"name": "sewer_vermin_w2_solo", "arena": "sewers_nest", "enemies": ["sewer_vermin", "sewer_vermin"], "build": "warrior2", "solo": true},
	## The deep_tunnels Raskghar scout route-fight (bruiser pair,
	## fought in cave_mouth). MEASURED-only -- the scouts are content, not a
	## win-rate contract; deep_descent proves the fight clears via a pinned
	## fixture rng. Recorded with + without Relc so the report shows the
	## solo-difficulty frontier (the deep_descent fixture fields no ally).
	{"name": "raskghar_scouts_w2_relc", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": false},
	{"name": "raskghar_scouts_w2_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": true},
	{"name": "raskghar_scouts_w5_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior5_mage5", "solo": true},
	## The street "Missing Crate"/"Wrong Order" scavenger encounters
	## (crate_scavengers/supplier_scavengers, skeleton_scene.json -- both 2x
	## goblin_raider on arena goblin_ambush). Issue #69 wired crate_scavengers'
	## real `ally_requires` to Klbkch (`crate_scavengers_w1_klbkch` below
	## matches live content now); supplier_scavengers is untouched, still
	## `allies: []`, never any ally. MEASURED-only, same rationale as the
	## raskghar_scouts route-fight cells above: crate_fight/wrong_order_fight
	## already prove each one clears via its own pinned fixture rng_state (a
	## real content proof); a win-rate CONTRACT would risk CI churn on
	## balance-neutral changes elsewhere for solo/allied warrior1-vs-2-raider
	## street fights without changing anything a player experiences.
	## warrior1_tutorial is the honest representative build for both.
	{"name": "crate_scavengers_w1_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "warrior1_tutorial", "solo": true},
	{"name": "crate_scavengers_w1_klbkch", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "warrior1_tutorial", "solo": false, "ally": "klbkch"},
	{"name": "supplier_scavengers_w1_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "warrior1_tutorial", "solo": true},
	## Issue #24 (HR-II forward-ref): the Rock Crab cull, floodplains'
	## own renewable T1 fight (region-tiers.md: floodplains is T1, expected
	## build warrior1-4). GATED to the generic band (0.55-0.95 win rate,
	## `check_rounds` true for 3-12 median) at `warrior2` + relc -- the SAME
	## "representative early level" build convention this file's own
	## shield_spiders/awakened_boss/raskghar_scouts cells already use, not a
	## new build. Solo (no ally yet) is recorded measured-only, the same
	## hard-mode-frontier convention as every other solo cell in this file.
	## relc_downed CONSTRAINT (review-wave L1, measured across ~30 stat
	## combos at this exact gate): win<=0.95 AND relc_downed<=0.5 are jointly
	## INFEASIBLE for any single-melee-enemy roster vs warrior2+relc -- the
	## melee AI always focuses relc (lowest hp, 40 < pc's 44) and pc death is
	## the only defeat, so in-band lethality REQUIRES chewing through relc
	## first. Shipped compromise reads win=0.93/relc_downed=0.62 (down from
	## the first-landed 0.83); the full frontier + the structural escape
	## routes live in rock_crab's own combatants.json _comment.
	{"name": "rock_crab_nest_t1_relc", "arena": "boulder_flats", "enemies": ["rock_crab"], "build": "warrior2", "solo": false, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "rock_crab_nest_t1_solo", "arena": "boulder_flats", "enemies": ["rock_crab"], "build": "warrior2", "solo": true},
	## Issue #80 (world reactivity wave, item 4): `goblin_night_patrol`,
	## floodplains' own night-only encounter slot (skeleton_scene.json --
	## the river_wolf_pack precedent applied to Liscor's own approach road).
	## STAYS MEASURED-ONLY, same design note as river_wolf_pack itself: it's a
	## NIGHT AMBUSH by design, not a win-rate contract, and no
	## ambush/surprise mechanic exists in the sim to gate against. Same
	## roster/arena/ally as goblin_encounter_2 (warrior2 + relc, floodplains'
	## own T1 representative build) -- this is the SAME matchup at a
	## different hour, not a new difficulty tier.
	{"name": "goblin_night_patrol_t1_relc", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "build": "warrior2", "solo": false},
	{"name": "goblin_night_patrol_t1_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "build": "warrior2", "solo": true},
]

## The Awakened Raskghar BOSS band (spec §2 / plan A2 item 4). Unlike
## every other new-content cell (all measured), the Relc-fielded boss cell is
## GATED to an EXPLICIT 0.6-0.75 win band (per-cell `win_lo`/`win_hi`, NOT the
## generic 0.55-0.95) -- the design contract "beatable-but-threatening with
## Relc". The solo (decline-veto) cell is measured-only (the hard-mode frontier,
## reported honestly, never gated). Boss + 2 scout adds in the deep_warren
## positioning arena. Tune DATA (combatants.json con/die, skills.json maul die/
## ap_cost) to hold the band; escalate if unreachable, never silently re-gate.
const BOSS_CELLS := [
	{"name": "awakened_boss_w2_relc", "arena": "deep_warren", "enemies": ["raskghar_awakened", "raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": false, "win_lo": 0.6, "win_hi": 0.75},
	{"name": "awakened_boss_w2_solo", "arena": "deep_warren", "enemies": ["raskghar_awakened", "raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": true},
]

## The ruin encounter axis -- rift_vermin_leak
## (beat-2 inn-cellar leak fight) and ruin_guardian (beat-3 Albez-flavored
## construct guarding the anchor-stone pedestal; D1/D3 wire the real encounter
## entities into skeleton_scene.json separately -- this file only proves the
## combat DATA these locked ids/arena resolve to is in-band). Same per-cell
## win_lo/win_hi gating shape as BOSS_CELLS (a cell without them is
## measured-only, printed with the "(measured)" tag). Every cell uses
## `warrior5_mage5` (10 total levels, split-efficiency ~0.78) as the
## representative "~L8-12 kit" build the plan brief calls out.
## rift_vermin_leak is GATED to the GENERIC 0.55-0.95 band per the plan's
## explicit directive ("gated band 0.55-0.95 at the expected player level
## ~L8-12 kit") -- a trash-swarm leak fight, not a boss, so the generic bound
## applies directly; distinct enemy ids (rift_vermin_a/b/c) avoid the
## same-id WICombat collision documented on those combatants (see
## data/combatants.json). ruin_guardian is adjudicated like deep_descent's
## raskghar_awakened / this file's own BOSS_CELLS: the Relc-escorted cell
## gets an EXPLICIT win_lo/win_hi ("beatable-but-threatening", the recovery
## run is meant to matter, mirrors BOSS_CELLS' 0.6-0.75 shape at a slightly
## easier band since the guardian is "mid-weight", not a capstone boss); the
## solo cell (no ally assumed on the pedestal approach) is measured-only, the
## hard-mode frontier, same convention as awakened_boss_w2_solo.
## ISSUE #83 ADOPTION (new AI profiles beyond the melee dogpile): rift_vermin_a/b
## -> `coward` (flees under 30% hp, rallies toward its nest-mates -- the direct
## read for scattering vermin), ruin_ward_a/b -> `guard` (body-blocks for
## whichever of its side is hurt worst, the direct read for an "escort ward").
## rift_vermin_leak_w8_relc re-measured 0.74 -> 0.81 win_rate, comfortably
## inside its wide generic 0.55-0.95 band (rift_vermin_leak_w8_solo, measured,
## moved 0.09 -> 0.16 alongside it). ruin_guardian_w8_relc dropped 0.69 -> 0.54,
## just BELOW its tighter 0.55-0.8 floor (the wards clustering near their
## wounded side instead of rushing individually reads as a harder fight) --
## restored to 0.59 by nerfing `ruin_guardian`'s OWN con (28 -> 24, see its
## combatants.json _comment), never the wards. The `guard` wards serve ONLY
## this roster now: the trapped_halls snare originally shared ruin_ward_a/b
## by id and inherited the guard profile with them, which eroded ITS gated
## cell the opposite way -- fixed by splitting that roster onto the melee-ai
## `snare_ward_a/b` clones (see DUNGEON_CELLS' own doc comment).
const RUIN_CELLS := [
	{"name": "rift_vermin_leak_w8_relc", "arena": "inn_cellar", "enemies": ["rift_vermin_a", "rift_vermin_b", "rift_vermin_c"], "build": "warrior5_mage5", "solo": false, "win_lo": 0.55, "win_hi": 0.95},
	{"name": "rift_vermin_leak_w8_solo", "arena": "inn_cellar", "enemies": ["rift_vermin_a", "rift_vermin_b", "rift_vermin_c"], "build": "warrior5_mage5", "solo": true},
	{"name": "ruin_guardian_w8_relc", "arena": "ruin_court", "enemies": ["ruin_guardian", "ruin_ward_a", "ruin_ward_b"], "build": "warrior5_mage5", "solo": false, "win_lo": 0.55, "win_hi": 0.8},
	{"name": "ruin_guardian_w8_solo", "arena": "ruin_court", "enemies": ["ruin_guardian", "ruin_ward_a", "ruin_ward_b"], "build": "warrior5_mage5", "solo": true},
]

## The Riverfarm encounter axis (briar collectors, both waves, arena
## `witch_hollow`; the night wolf ambush, arena `village_edge_night`). Same
## per-cell win_lo/win_hi gating shape as RUIN_CELLS -- a cell without them is
## measured-only.
## ISSUE #66 RETUNE: `briar_collectors`/`briar_collectors_deep` are Riverfarm's
## real quest-completion fights (`riverfarm_fight`'s ONLY combats), so they
## get the FULL tier treatment -- the GATING AUTHORITY moves from the old
## `_w10_hunter` cells (`warrior5_mage5`, ungeared -- pre-dates the region-tier
## table, no longer the T3 reference build) to the new `_t3_spellsword9_
## hunter` cells (GEARED, `check_rounds: true`), which is why the `_w10_`
## cells below lost their `win_lo`/`win_hi` and are now printed "(measured)":
## an off-tier build vs. an on-tier roster, kept purely as the pre-retune
## historical baseline (compare the printed win_rate before/after this task
## in the harness log). `briar_collectors` keeps the generic 0.55-0.95 band
## (a two-enemy trash/escalation pair, not a boss); `briar_collectors_deep`
## keeps its own slightly tighter 0.55-0.85 band (its `power_strike`-bearing
## striker on top of the shallow wave's plain pair). combatants.json's
## `briar_collector_a/b`/`briar_collector_deep_a/b` con/str were raised to
## hold these bands against t3_spellsword9's much higher str (see those
## records' own `_comment` for the exact before/after). `t3_warrior9_hunter`
## siblings are measured comparison points (the non-consolidated alternative
## build), same convention as the BUILDS row itself.
## `river_wolf_pack` STAYS MEASURED-ONLY (issue #56's own solo-danger design,
## re-affirmed here, not re-opened): it's a NIGHT AMBUSH by design (spec
## sec.5) -- the point is that a 3-wolf pack caught at a bad moment is
## genuinely dangerous, not that it clears a win-rate band. No ambush/
## surprise mechanic exists in the sim today (no first-strike/stealth-
## detection seam for a night spawn to hook), so the numbers below are the
## fight's raw difficulty with no mechanical ambush bonus applied -- reported
## honestly rather than gated to a band that would misrepresent what
## "ambush" currently means here. Its cells were swapped from `warrior5_
## mage5` to `t3_spellsword9` in place (never gated either way, so no
## before/after baseline needs preserving).
## ISSUE #83 ADOPTION: river_wolf_a/b (the two flankers, NOT the alpha
## river_wolf_c) carry the new `skirmisher` profile -- a fast pack hunter
## nipping in then darting clear before retaliation, extending this const's
## own pre-existing "closes quickly" flavor text to the retreat half. No gate
## to hold (measured-only, per the design note above), so this is a
## re-measurement, not a re-band: win_rate rose 0.95 -> 0.99 (hunter) and
## 0.30 -> 0.48 (solo) -- a skirmisher spends part of its turn disengaging
## instead of standing in melee range attacking every turn, which is real
## reduced enemy DPS pressure over a multi-round fight, so the pack reading
## SAFER (never more dangerous) is the expected direction, not a red flag.
## The ally here is `riverfarm_hunter`, NOT `relc` (Riverfarm is a solo Door
## arrival with no fictional basis for Liscor's Watch to be present --
## combatants.json's riverfarm_hunter is an EXACT stat/weapon_die/ai/skills
## clone of relc, so these bands stay numerically valid under the new id).
const RIVERFARM_CELLS := [
	{"name": "briar_collectors_w10_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "warrior5_mage5", "solo": false},
	{"name": "briar_collectors_w10_solo", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "warrior5_mage5", "solo": true},
	## R3: GATING AUTHORITY moved to t3_warrior10 (below) -- t3_spellsword9 is
	## now structurally unreachable (see that BUILD row's own comment). This
	## cell stays, gate stripped, a measured historical baseline.
	{"name": "briar_collectors_t3_spellsword9_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "t3_spellsword9", "solo": false},
	{"name": "briar_collectors_t3_warrior9_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "t3_warrior9", "solo": false},
	{"name": "briar_collectors_t3_warrior10_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "t3_warrior10", "solo": false, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "briar_collectors_deep_w10_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "warrior5_mage5", "solo": false},
	{"name": "briar_collectors_deep_w10_solo", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "warrior5_mage5", "solo": true},
	## R3: gate stripped, same reasoning as briar_collectors_t3_spellsword9_hunter above.
	{"name": "briar_collectors_deep_t3_spellsword9_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "t3_spellsword9", "solo": false},
	{"name": "briar_collectors_deep_t3_warrior9_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "t3_warrior9", "solo": false},
	{"name": "briar_collectors_deep_t3_warrior10_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "t3_warrior10", "solo": false, "win_lo": 0.55, "win_hi": 0.85, "check_rounds": true},
	## R3: river_wolf_pack stays measured-only by design (a night ambush, not
	## a win-rate contract -- see this const's own header doc) but its BUILD
	## reference moves to the new T3 reference (t3_warrior10) so the printed
	## numbers reflect what a real player actually holds at Riverfarm arrival.
	{"name": "river_wolf_pack_t3_hunter", "arena": "village_edge_night", "enemies": ["river_wolf_a", "river_wolf_b", "river_wolf_c"], "build": "t3_warrior10", "solo": false},
	{"name": "river_wolf_pack_t3_solo", "arena": "village_edge_night", "enemies": ["river_wolf_a", "river_wolf_b", "river_wolf_c"], "build": "t3_warrior10", "solo": true},
]

## Invrisil 8c Task C2 (issues #12/#13) axis. The alley footpads
## (shared `mercantile_alley` arena, lane alpha's two encounter placements
## both resolve to this same pair) are SNEAK TARGETS, deliberately tuned
## LOW-lethality (design contract: a player who fails the K2 [Stealth]
## check and gets ambushed must not be walled by the fight) -- gated to an
## EXPLICIT band favoring the floor (0.75-0.98, well above the generic
## 0.55 floor) rather than the generic 0.55-0.95 band, at `warrior2` (the
## same early/low representative build goblin_ambush uses) SOLO -- no ally
## is structurally present when sneaking the alleys alone. A
## `warrior1_tutorial`-tier read is recorded (measured-only) to show even a
## fresh warrior1 isn't walled.
## ISSUE #66 RETUNE DECISION: footpads keep their EXISTING `warrior2` gate
## UNCHANGED -- this is NOT an off-tier baseline to retire, it's the
## load-bearing design contract (protect a player who fails the stealth
## check regardless of what level they actually are when it happens; low
## lethality is the promise, not a function of tier). `alley_footpads_t3_
## spellsword9_solo` is a NEW measured-only cell recording the T3-build read
## -- footpads trivializing against a consolidated spellsword9 (see the
## harness log) is the "over-tier trivial is INTENDED" case from this file's
## own header table, not a retune target: nobody expects a generic street
## thug to threaten a Riverfarm/Invrisil-tier PC, and gating that expectation
## would fight the design instead of confirming it. No combatants.json
## changes for `footpad_lookout`/`footpad_bruiser`.
## `hired_blades` (the LOCKED `merchant_warehouse` arena, the first
## all-human combatant family) IS the real T3 treatment, same shape as
## `briar_collectors` above: the gating authority moves from `hired_blades_
## w10_wilovan` (now measured, the pre-tier `warrior5_mage5` baseline) to
## `hired_blades_t3_spellsword9_wilovan` (GEARED, `check_rounds: true`,
## SAME 0.6-0.8 band -- the deep_descent/ruin_guardian gated-ally-band
## precedent). combatants.json's `hired_blade_leader`/`hired_blade_knife_a/b`
## con/str were raised to hold the band against t3_spellsword9's higher str
## (see those records' own `_comment`). `hired_blades_t3_warrior9_wilovan` is
## the measured comparison build. The solo cells (the come-along beat
## declined) stay measured-only, the hard-mode frontier, same convention as
## awakened_boss_w2_solo/ruin_guardian_w8_solo.
const INVRISIL_CELLS := [
	{"name": "alley_footpads_w2_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "warrior2", "solo": true, "win_lo": 0.75, "win_hi": 0.98},
	{"name": "alley_footpads_w1_tutorial_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "warrior1_tutorial", "solo": true},
	{"name": "alley_footpads_t3_spellsword9_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "t3_spellsword9", "solo": true},
	## R3: the same over-tier-trivial confirmation, at the NEW real T3
	## reference build.
	{"name": "alley_footpads_t3_warrior10_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "t3_warrior10", "solo": true},
	{"name": "hired_blades_w10_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "warrior5_mage5", "solo": false},
	{"name": "hired_blades_w10_solo", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "warrior5_mage5", "solo": true},
	## R3: GATING AUTHORITY moved to hired_blades_t3_warrior10_wilovan below --
	## gate stripped, measured historical baseline (same reasoning as the
	## briar_collectors_t3_spellsword9_hunter cells above).
	{"name": "hired_blades_t3_spellsword9_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_spellsword9", "solo": false},
	{"name": "hired_blades_t3_warrior9_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_warrior9", "solo": false},
	{"name": "hired_blades_t3_warrior10_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_warrior10", "solo": false, "win_lo": 0.6, "win_hi": 0.8, "check_rounds": true},
	{"name": "hired_blades_t3_spellsword9_solo", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_spellsword9", "solo": true},
	{"name": "hired_blades_t3_warrior10_solo", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_warrior10", "solo": true},
	## Issue #80 (world reactivity wave, item 4): `boulevard_night_footpads`,
	## Invrisil's own night-only slot (skeleton_scene.json, invrisil_boulevard --
	## the river_wolf_pack precedent's second application). STAYS
	## MEASURED-ONLY (same rationale as river_wolf_pack/goblin_night_patrol
	## above -- a night ambush, not a win-rate contract). Same
	## footpad_lookout/footpad_bruiser roster as alley_footpads_a/b, but at
	## the region's real T3 build (GEARED) rather than the
	## deliberately-low-lethality warrior2 those two are pinned to -- this is
	## a genuine night danger on open ground, not a failed-stealth safety
	## net, so it reads at Invrisil's own tier like hired_blades does. No
	## ally (matches alley_footpads_a/b's own solo convention -- nobody's
	## fielded on the boulevard at night). R3: build reference moved to
	## t3_warrior10 (the old t3_spellsword9 cell stays below as a baseline).
	{"name": "boulevard_night_footpads_t3_spellsword9_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "t3_spellsword9", "solo": true},
	{"name": "boulevard_night_footpads_t3_warrior10_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "t3_warrior10", "solo": true},
]

const BUILDS := [
	## The TUTORIAL profile: the player's actual first fight (street
	## goblin_encounter_2 -> arena goblin_ambush) is fought at warrior 1 --
	## no counter_strike/battle_momentum yet. M6-playtest directive: the
	## tutorial fight must be winnable on the first attempt, so this cell is
	## measured to keep the matchup visible whenever combat data moves.
	{"name": "warrior1_tutorial", "classes": {"warrior": 1}, "gated": false},
	## The ABOVE cell always fields relc as an
	## ally, but ally_requires{met_relc:1} means a naive player who dashes
	## straight at goblin_encounter_2 WITHOUT first talking to Relc fights this
	## exact matchup SOLO. That's the scenario the playtest flagged as "must
	## survive the opening exchanges" -- measuring it here (never gated; the
	## bar is "not trivially easy, wants Relc's advice", not a win-rate
	## contract) keeps the real risk visible whenever goblin_ambush data moves.
	{"name": "warrior1_tutorial_solo", "classes": {"warrior": 1}, "gated": false, "solo": true},
	## goblin_ambush/warrior2
	## is UN-GATED (per-cell, via `ungated_comps` -- the build stays gated for
	## chieftains_raid). Relc is a high-level [Spearmaster] (canon) escorting
	## the tutorial fight: a near-1.0 win rate on this ALLY-CARRIED cell is
	## CORRECT DESIGN, not a balance failure; the 0.55-0.95 gate is a generic
	## bound predating the mentor-carried-tutorial concept. The design-relevant
	## gates for this fight are now the warrior1_tutorial_solo measured cell
	## (target ~0.4-0.5 win) and relc_downed_rate (target <= ~0.15).
	{"name": "warrior2", "classes": {"warrior": 2}, "ungated_comps": ["goblin_ambush"]},
	## The martial+service hybrid. [Helper] contributes only
	## con stat_growth (+1/level) and non-combat/exploration grants ([Basic
	## Cooking] at L1; no combat skill until [Quick Movement] at L5) -- so at
	## helper 2 this build is `warrior2`'s exact combat kit plus +2 con (a
	## little more HP), no fielded combat benefit. MEASURED-only (same
	## convention as warrior2_mage2 and WAVE A2): a service multiclass is a
	## content/identity axis, not a balance contract. Target expectation: tracks
	## `warrior2` closely -- near-1.0 on the Relc-carried goblin_ambush cell,
	## and a hair above bare `warrior2` on chieftains_raid from the extra con.
	{"name": "warrior2_helper2", "classes": {"warrior": 2, "helper": 2}, "gated": false},
	{"name": "warrior2_mage2", "classes": {"warrior": 2, "mage": 2}, "gated": false},
	{"name": "warrior2_mage2_caster", "classes": {"warrior": 2, "mage": 2}, WIKeys.AI: "caster", "gated": false},
	{"name": "pure_warrior10", "classes": {"warrior": 10}, "gated": false},
	{"name": "pure_mage10_caster", "classes": {"mage": 10}, WIKeys.AI: "caster", "gated": false},
	{"name": "warrior5_mage5", "classes": {"warrior": 5, "mage": 5}, "gated": false},
	{"name": "warrior5_mage5_caster", "classes": {"warrior": 5, "mage": 5}, WIKeys.AI: "caster", "gated": false},
	## T3 reference builds (issue #66's retune set) -- gear included per the
	## controller spec ("tier expectation covers equipment, not just levels"),
	## carried directly on the ROW via optional `WIKeys.WEAPON`/"armor"/
	## "accessories" keys (an opt-in extension: `_build_pc` below applies gear
	## ONLY when a build carries `WIKeys.WEAPON`, so every row ABOVE this
	## comment -- and every existing LOADOUT_CELLS/ENCOUNTER_CELLS/BOSS_CELLS/
	## RUIN_CELLS cell -- stays byte-identical, ungeared). Gear basis (traced
	## against what a player can actually own by Riverfarm/Invrisil arrival):
	## `gnollish_hunting_knife` (15g, Krshia's stall, sword family -- keeps
	## `power_strike` weapon-gated IN; a spear would gate it OUT in favor of
	## `piercing_strikes`, which `combat_ai.gd`'s `_act_melee` never calls by
	## name, a silent DPS trap) + `leather_jerkin` (24g, Krshia's stall, the
	## mundane-armor-tier ceiling -- `watch_issue_gambeson`'s dr+1 is the
	## flat-damage-reduction alternative at the same price band, not modeled
	## here so the two T3 builds below stay directly comparable on identical
	## gear) + `hedge_ward_charm` + `hunters_fang_talisman` (9g+14g, resonance
	## 1+1 = the shipped capacity-2 ceiling exactly -- the SAME "actual
	## best-case early loadout" combo LOADOUT_CELLS' own `warrior2_max_legal_
	## kit` already established; Riverfarm's own post-quest vendor stocks
	## `witch_wardstone_bead`, an equal-value resonance-1 alternative, not
	## additional headroom). Combined: damage_mod +2, hp_mod +6,
	## damage_reduction +0.
	{"name": "t3_spellsword9", "classes": {"spellsword": 9}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	## Non-consolidated T3 alternative -- same total level (9) and the SAME
	## gear basis as t3_spellsword9 above (directly comparable), for the
	## player who never accepted (or was never offered) the [Spellsword]
	## consolidation: a plain warrior kit, no mage skills/MP/`mana_shield`
	## passive. Per WIProgression.derived_stat_bonuses a single held class
	## always applies at full efficiency (no split penalty) -- warrior9 gets
	## str+9/con+9 (vs spellsword9's str+9/int+9), trading `mana_shield`'s
	## passive damage absorption for a bigger hp pool. MEASURED, not gated --
	## the retune targets t3_spellsword9 (the spec's own primary reference);
	## this build is the comparison point, recorded so a retune never
	## secretly depends on the mage-shield passive to clear.
	{"name": "t3_warrior9", "classes": {"warrior": 9}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	## CLASS-FOUNDATION PASS R3 (2026-07-12): THE NEW T3 GATING-AUTHORITY
	## REFERENCE, replacing t3_spellsword9 above. The consolidation retune
	## (min_parent_level 6->10, min_combined_level 13->21 -- data/classes.json's
	## `consolidations[0]`) moves [Spellsword]'s earliest reachable level to 14
	## (the merge formula's floor at the new thresholds, WIProgression.
	## _consolidation_merged_level(10,11)=14) -- "spellsword ~9" (the OLD
	## ratified T3 reference, docs/design/evolution-reachability.md's own
	## rejected-then-executed recommendation) is now STRUCTURALLY UNREACHABLE
	## by real play: no player can hold [Spellsword] below level 14 anymore.
	## The new T3 "expected build" is a MONO warrior at level 10 (T3's own
	## tier ceiling, region-tiers.md's "8-10" band's top end, AND warrior's own
	## `evolution.at_level` -- a real narrative beat, "just hit 10") on the
	## SAME gear basis as t3_warrior9/t3_spellsword9 above (directly
	## comparable). t3_spellsword9's own cells below are NOT deleted -- they
	## lose their win_lo/win_hi and become measured historical baselines (the
	## "Off-tier baselines" convention, docs/design/region-tiers.md) so the
	## before/after delta from this retune stays visible in this file rather
	## than lost to git blame.
	{"name": "t3_warrior10", "classes": {"warrior": 10}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	## T4 reference build (the dungeon) -- spellsword 11 on the SAME T3 gear
	## basis (no higher-tier gear exists in data/items.json yet; a real T4
	## shop ceiling is a separate content pass). Consumed by PARTY_CELLS below
	## -- see that constant's own doc comment for why neither T4 cell is
	## gated yet (a boss-stat seed awaiting its own tuning pass, and an
	## over-tier calibration cross-check that is EXPECTED to read trivial).
	## R3 NOTE: spellsword 11 is now BELOW the new consolidation floor (14) --
	## same unreachability the T3 build faced -- but the plan's own ruling
	## keeps this SHIPPED GATED cell pinned to its current build (it still
	## measures a real, meaningful roster difficulty; only the fictional "how
	## would a player get here" story changed, not the combat data under
	## test). A real-floor companion (`t4_spellsword14_party`, MEASURED-only)
	## is added below instead of replacing this one.
	{"name": "t4_spellsword11_party", "classes": {"spellsword": 11}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	## R3: the genuinely-reachable T4 companion -- spellsword AT its new real
	## floor (14), same T3 gear basis (no T4-specific shop ceiling exists
	## yet, same disclosed gap t4_spellsword11_party's own comment already
	## carries). MEASURED-only (PARTY_CELLS' vault cell stays gated on the
	## pinned t4_spellsword11_party build per the ruling above; this is the
	## added real-floor data point, not a replacement gate).
	{"name": "t4_spellsword14_party", "classes": {"spellsword": 14}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
]

## The T4 dungeon party axis -- the FIRST 4-ally harness cells:
## `t4_spellsword11_party` + all three Horns (ceria/yvlon/ksmvr,
## combatants.json) fielded TOGETHER, matching the real delve roster shape
## (three allies at once, not the one-ally pattern every other axis in this
## file uses). `ally_requires` wiring for the real delve encounter is a
## separate task -- this file only proves the combat DATA those ids resolve
## to holds a sane, honestly-reported band.
## Two rosters:
##  (a) `vault_construct_t4_party` -- 8d C3 (issue #82): the windup MECHANISM
##      + FINAL TUNING landed (data/combatants.json's own `_comment`), so this
##      cell is no longer a placeholder seed. `arena` switched from the
##      deep_warren stand-in to the REAL `vault` arena this lane also shipped
##      (data/arenas.json). GATED per-cell (`win_lo`/`win_hi` 0.55-0.95,
##      `check_rounds` true for the 3-12 median band) -- the SAME `gated :=
##      cell.has("win_lo")` idiom BOSS_CELLS/RUIN_CELLS/RIVERFARM_CELLS/
##      INVRISIL_CELLS already use, extended to this loop below (previously
##      every PARTY_CELLS row was hardcoded measured-only).
##  (b) `raskghar_awakened_t4_party` -- the existing T2 boss (this file's own
##      BOSS_CELLS 0.6-0.75-vs-warrior2+relc cell) as a CALIBRATION
##      CROSS-CHECK: the SAME roster, now faced by a full T4 party instead of
##      a T2 build + 1 ally. UNCHANGED, still `arena: deep_warren`, still
##      MEASURED-only, by the SAME "over-tier trivial is intended" convention
##      this file's own header table states outright (a T2 boss vs. a T4
##      party is EXPECTED to read near-1.0, same as goblin_ambush vs.
##      pure_warrior10) -- if it reads otherwise, the PARTY MATH itself is
##      off, not just vault_construct's tuning. NOT part of this lane's
##      re-tune (byte-identical construction; only its printed win_rate can
##      shift, and shouldn't, since vault_construct's data changes don't touch
##      raskghar_awakened's own stats).
## PC-DEATH-INSTANT-DEFEAT RE-CHECK (CLAUDE.md's own standing rule):
## `_check_end` checks pc.alive FIRST, unconditionally, regardless of ally
## count -- a 4-body party (3 living allies) cannot produce an "ally-carried
## win" any more than the 1-ally case could, since a victory can only ever
## be reached through the branch that requires pc alive. Asserted directly
## in the loop below (never just trusted) since this is the first cell to
## field 3 allies at once; `pc_alive_rate` is printed alongside each ally's
## own downed rate (same convention as relc_downed_rate elsewhere in this
## file) -- by construction pc_alive_rate must equal win_rate exactly, and
## printing both is the re-check itself (a future divergence would mean the
## instant-defeat rule broke). RE-VERIFIED for `vault_construct_t4_party`
## specifically: `slam`'s windup resolution can down a combatant via the SAME
## `_resolve_hit`/`_post_damage`/`_check_end` chain a basic Attack does (a
## multi-target blast is just more chances to trigger it), so this is not a
## new failure mode, only a new, more frequent path to the same rule.
const PARTY_CELLS := [
	{"name": "vault_construct_t4_party", "arena": "vault", "enemies": ["vault_construct"], "build": "t4_spellsword11_party", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	## The TALK-route (guided-plates) variant: the SAME vault roster with
	## ksmvr entering at the ally_hp_penalty the live encounter applies
	## (`ally_hp_mods`, an optional per-cell dict the loop below folds onto
	## the named ally's cfg exactly like start_combat's own arm -- hp_mod
	## -18, max_hp 35 -> 17). MEASURED-only: the gated contract is the
	## unpenalized cell above; this row documents what the TALK route's
	## cost actually does to the band, never gates it.
	{"name": "vault_construct_t4_party_guided", "arena": "vault", "enemies": ["vault_construct"], "build": "t4_spellsword11_party", "ally_hp_mods": {"ksmvr": -18}},
	{"name": "raskghar_awakened_t4_party", "arena": "deep_warren", "enemies": ["raskghar_awakened", "raskghar_scout", "raskghar_scout"], "build": "t4_spellsword11_party"},
	## R3: the real-floor companion cell (t4_spellsword14_party's own BUILDS
	## comment) -- MEASURED-only, the vault gate stays pinned to the SHIPPED
	## t4_spellsword11_party build above per the ruling (don't re-tune a
	## working boss over a reachability-only floor change).
	{"name": "vault_construct_t4_spellsword14_party", "arena": "vault", "enemies": ["vault_construct"], "build": "t4_spellsword14_party"},
]

## The dungeon FIGHT-route axis (8d C1, issue #14): trapped_halls' promoted
## `snare_nest_slot` fights in the NEW `trapped_halls_snare` arena, solo
## (the FIGHT route is paid BEFORE the party forms at dungeon_approach).
## Gear-aware `t4_spellsword11_party` build (the SAME T4 reference
## PARTY_CELLS' own vault cell uses). ROSTER derivation (8d C1 review,
## FIGHT-route-cost ruling -- fix by roster only, no stat changes to any
## shipped combatant): the original 2-ward roster measured 0.99/2r
## (illusory cost); candidates measured at this exact build/arena:
##   wards2+ruin_guardian 0.38/3r (too hard), wards3 0.96/3r (over band),
##   wards2+rift_vermin_a 0.88/3r (in band), wards2+raskghar_scout 0.93/2r
##   (median under floor), wards2+rift_vermin_c 0.69/3r (PICKED -- mid-band
##   with margin both directions, and the ember-touched caster adds a
##   ranged threat to an otherwise pure melee rush).
## rift_vermin_c ('Ember-Touched Vermin', combatants.json) is
## canon-plausible here: Magical Rats are drawn to leaking ambient magic
## (that combatant's own wiki cite), and an ancient sealed dungeon full of
## wardwork is exactly that draw -- vermin nesting behind a snare matches
## the entity's own 'something in the dark past it' flavor. GATED to the
## generic 0.55-0.95 band + 3-12 median (a skirmish contract, not a boss
## capstone). TRAP fixed en route: trapped_halls_snare originally authored
## only 2 enemy_spawns -- the 3rd enemy index-overflowed WICombat._init
## (the SAME spawn-ceiling trap the vault's own C2 review named,
## enemy-side); the arena now carries 4.
## ISSUE #83 FIX (the FIGHT-route-cost erosion, second occurrence): when
## ruin_ward_a/b first adopted the `guard` profile, THIS roster inherited it
## by id-sharing -- and with no boss to escort here (just each other + the
## ranged rift_vermin_c) the guard wards clustered instead of engaging,
## eroding the skirmish to 0.94 win_rate: technically still inside the
## 0.55-0.95 ceiling, but the exact illusory-cost failure the 8d C1
## roster-only ruling above fixed once already. No per-encounter AI override
## exists, so the fix is the SAME roster-only pattern: the roster now fields
## `snare_ward_a`/`snare_ward_b` (combatants.json), stat CLONES of
## ruin_ward_a/b with plain melee ai -- a distinct id IS the override.
## Behaviorally identical to the pre-#83 wards in this arena (same stats,
## same profile, same relative id sort order), so the cell re-derives to its
## pre-adoption 0.69/3r; RUIN_CELLS' ruin_guardian_w8_relc keeps its
## guard-ward roster (and its own #83 con retune) untouched -- the two gated
## cells no longer pull in opposite directions off one shared combatant.
## Re-verified via delve_fight (the live QA canonical for this exact fight).
const DUNGEON_CELLS := [
	{"name": "trapped_halls_snare_t4_solo", "arena": "trapped_halls_snare", "enemies": ["snare_ward_a", "snare_ward_b", "rift_vermin_c"], "build": "t4_spellsword11_party", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
]


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Returns the first entry of `list` whose `key` field equals `value`, or {}.
## Used to resolve a LOADOUT_CELLS cell's "comp"/"build" name back to the
## COMPOSITIONS/BUILDS entry it references, so a loadout cell never redefines
## a composition or build -- only the equipment on top of it.
func _find_by_name(list: Array, value: String) -> Dictionary:
	for e: Dictionary in list:
		if String(e["name"]) == value:
			return e
	return {}


## Builds ONE fresh pc combatant dict from a BUILDS row: classes -> stats/kit
## via the shared WIProgression path (identical to every call site before
## this task), THEN, only when the row carries `WIKeys.WEAPON` (the T3 rows'
## opt-in gear extension -- see their own doc comment), layers weapon/armor/
## accessory mods via the SAME `WICombatBuild.weapon_gated_kit`/
## `equipment_mods` LOADOUT_CELLS and `wi_game.gd`'s `_build_player_combatant`
## already use. A build with no `WIKeys.WEAPON` key takes the untouched
## pre-gear path -- every pre-existing BUILDS row (and therefore every loop
## below that resolves a "build" name through this function) is byte-
## identical to before this task. Centralized here (T0's own "hand-mirrored
## copies are the scariest drift class" lesson) instead of repeating the
## same 3-4 lines across the six loops that build a pc from a named build.
func _build_pc(build: Dictionary, pc_template: Dictionary, classes_catalog: Dictionary, skills_by_id: Dictionary, items_by_id: Dictionary) -> Dictionary:
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
		var mods: Dictionary = WICombatBuild.equipment_mods(weapon, armor, accessories)
		pc[WIKeys.DAMAGE_MOD] = mods[WIKeys.DAMAGE_MOD]
		pc[WIKeys.HP_MOD] = mods[WIKeys.HP_MOD]
		pc[WIKeys.DAMAGE_REDUCTION] = mods[WIKeys.DAMAGE_REDUCTION]
	else:
		pc[WIKeys.SKILLS] = kit
	return pc


func _init() -> void:
	var total_cells := COMPOSITIONS.size() * BUILDS.size() + LOADOUT_CELLS.size() + ENCOUNTER_CELLS.size() + BOSS_CELLS.size() + RUIN_CELLS.size() + RIVERFARM_CELLS.size() + INVRISIL_CELLS.size() + PARTY_CELLS.size() + DUNGEON_CELLS.size()
	if OS.get_environment("WI_CELL_COUNT_ONLY") != "":
		print("WI_CELL_COUNT: %d" % total_cells)
		quit(0)
		return
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
	# id-keyed mirrors for the loadout axis only -- the id-keyed
	# form matches wi_game.gd's `skills`/`_items` instance dicts (WICombat's
	# own constructor keys its internal `skills` the same way from the raw
	# array form the main loop below already passes it).
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
			if not _cell_in_range(): continue
			var wins := 0
			var rounds: Array[int] = []
			var relc_downed := 0
			var has_relc := not bool(build.get("solo", false))
			for seed_v in range(1, RUNS_PER_CELL + 1):
				# _build_pc: SAME shared application path as
				# WIGame._build_player_combatant (WIProgression.
				# apply_stat_bonuses/granted_skills), so the harness measures the
				# exact stats a real PC combatant would carry for this class
				# distribution (plus gear, for the opt-in T3 rows).
				var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
				var cfgs: Array = [pc]
				if not bool(build.get("solo", false)):
					cfgs.append((by_id["relc"] as Dictionary).duplicate(true))
				for enemy_id: String in comp["enemies"]:
					cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
				var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
				combat.begin()
				var guard := 0
				while not combat.finished and guard < 2000:
					guard += 1
					WICombatAI.take_turn(combat)
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
			## Per-cell gating: a build is gated by default; `gated: false` un-gates
			## it everywhere, `ungated_comps` un-gates it for the named
			## compositions only (WAVE A2 -- see the warrior2 build comment).
			var gated := bool(build.get("gated", true)) \
					and not (build.get("ungated_comps", []) as Array).has(String(comp["name"]))
			print("[%s / %s]%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
				comp["name"], build["name"], "" if gated else " (measured)", win_rate, median, rounds[0], rounds[-1],
			])
			print("  rounds histogram: ", hist)
			if has_relc:
				# Hotfix WAVE A2 (playtest 8+9 frontier metric): how often relc goes
				# down mid-fight, invisible to win-rate gates because the pc usually
				# finishes the fight alone. Recorded-only -- no bounds contract.
				print("  relc_downed_rate=%.2f (%d/%d)" % [float(relc_downed) / float(RUNS_PER_CELL), relc_downed, RUNS_PER_CELL])
			if not gated:
				# Recorded-only measurement axis — no bounds contract yet (T0 §2.4).
				continue
			if win_rate < 0.55 or win_rate > 0.95:
				any_failed = true
				printerr("FAIL [%s / %s]: win rate %.2f outside 0.55-0.95" % [comp["name"], build["name"], win_rate])
			if median < 3 or median > 12:
				any_failed = true
				printerr("FAIL [%s / %s]: median rounds %d outside 3-12" % [comp["name"], build["name"], median])

	## Loadout axis. Every cell is measured-only (equipment is a
	## new design axis, not yet subject to the generic 0.55-0.95/3-12 gate --
	## same convention WAVE A2 established for the mentor-carried tutorial
	## cell) -- resolves each cell's named composition/build back to the
	## tables above so classes/ai/solo never drift from the cell they
	## reference, then injects equipment via the SAME shared pure functions
	## `wi_game.gd`'s `_build_player_combatant` calls (`WICombatBuild.
	## weapon_gated_kit`/`equipment_mods`, `src/core/combat_build.gd` --
	## promoted off two hand-mirrored copies) before
	## constructing the SAME WICombat class the main loop above uses.
	for cell: Dictionary in LOADOUT_CELLS:
		if not _cell_in_range(): continue
		var comp: Dictionary = _find_by_name(COMPOSITIONS, String(cell["comp"]))
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(comp["arena"])]
		var weapon: Dictionary = items_by_id.get(String(cell[WIKeys.WEAPON]), {})
		var armor: Dictionary = items_by_id.get(String(cell["armor"]), {})
		# Resolve the cell's optional accessory ids ONCE (same
		# lifetime as weapon/armor above) -- a cell with no "accessories" key
		# gets an empty list, matching the pre-G4 5 cells exactly.
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
			# Calls the SAME shared function wi_game.gd's
			# `_build_player_combatant` calls -- weapon/armor contribute first,
			# then each equipped accessory's own damage_mod/hp_mod/
			# damage_reduction is SUMMED onto the same three fields (default 0
			# each, same tolerant .get reads); no more hand-mirrored math here.
			var mods: Dictionary = WICombatBuild.equipment_mods(weapon, armor, accessories)
			pc[WIKeys.DAMAGE_MOD] = mods[WIKeys.DAMAGE_MOD]
			pc[WIKeys.HP_MOD] = mods[WIKeys.HP_MOD]
			pc[WIKeys.DAMAGE_REDUCTION] = mods[WIKeys.DAMAGE_REDUCTION]
			var cfgs: Array = [pc]
			if has_relc:
				cfgs.append((by_id["relc"] as Dictionary).duplicate(true))
			for enemy_id: String in comp["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
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

	## Sewers encounter axis. Mirrors the main loop's construction
	## (build pc from the named BUILDS entry's classes, an optional ally,
	## enemies) with the cell's own inline arena/enemies. `ally_id` (issue
	## #69) defaults to "relc" so every pre-#69 cell's construction and print
	## label are byte-identical to before. GATING (issue #24): a cell carrying
	## `win_lo`/`win_hi` is bounded to that band (+ optional `check_rounds`,
	## the SAME per-cell opt-in shape BOSS_CELLS/RUIN_CELLS/RIVERFARM_CELLS
	## already use) -- every cell predating this task lacks those keys, so
	## `gated` is false for all of them and both the printed "(measured)" tag
	## and the loop's pass/fail behavior stay byte-identical.
	for cell: Dictionary in ENCOUNTER_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var ally_downed := 0
		var has_ally := not bool(cell.get("solo", false))
		var ally_id := String(cell.get("ally", "relc"))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
			pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes)
			pc[WIKeys.SKILLS] = WIProgression.granted_skills(build["classes"], classes)
			var cfgs: Array = [pc]
			if has_ally:
				cfgs.append((by_id[ally_id] as Dictionary).duplicate(true))
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
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

	## The Awakened Raskghar boss axis. Same construction as the
	## ENCOUNTER loop (build pc from the named BUILDS entry, optional Relc, the
	## boss + scout adds) but with a PER-CELL win band: a cell carrying
	## `win_lo`/`win_hi` is GATED to THAT band (the 0.6-0.75 Relc contract);
	## a cell without them is measured-only (the solo veto frontier). This is the
	## only gate in the file with a non-default band, by design.
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
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
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

	## The ruin axis. Same construction/gating shape as
	## the BOSS_CELLS loop directly above (per-cell win_lo/win_hi, absent means
	## measured-only) -- see RUIN_CELLS' own doc comment for the per-cell band
	## rationale.
	for cell: Dictionary in RUIN_CELLS:
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
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
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

	## The Riverfarm axis. Same construction/gating shape as the
	## RUIN_CELLS loop directly above (per-cell win_lo/win_hi, absent means
	## measured-only) -- see RIVERFARM_CELLS' own doc comment for the
	## per-cell band rationale (the wolf pack is deliberately ungated) and
	## for why the ally combatant is `riverfarm_hunter`, not `relc`.
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
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
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
			# Opt-in rounds gate (issue #66's T3 cells only -- every pre-existing
			# gated cell in this loop predates the requirement and stays
			# win-rate-only, unchanged): median rounds 3-12, the SAME bound the
			# main COMPOSITIONS x BUILDS loop enforces unconditionally.
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [riverfarm / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	## The Invrisil axis. Same construction/gating shape as the
	## RIVERFARM_CELLS loop directly above (per-cell win_lo/win_hi, absent
	## means measured-only) -- see INVRISIL_CELLS' own doc comment for the
	## per-cell band rationale (footpads favor the floor; hired_blades mirrors
	## the gated-ally-band precedent) and for why the ally combatant is
	## `wilovan`, not `relc`/`riverfarm_hunter`.
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
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
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
			# Opt-in rounds gate -- see RIVERFARM_CELLS' own identical block
			# directly above for the full rationale (issue #66's T3 cells only).
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [invrisil / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	## The T4 party axis. Same shared _build_pc path as the main
	## COMPOSITIONS loop/RIVERFARM_CELLS/INVRISIL_CELLS (gear-aware, T3/T4
	## rows only), but fields THREE named allies (ceria/yvlon/ksmvr) instead
	## of one -- the first multi-ally construction in this file. Per-cell
	## gating (`gated := cell.has("win_lo")`, the BOSS_CELLS/RUIN_CELLS/
	## RIVERFARM_CELLS/INVRISIL_CELLS idiom) -- see PARTY_CELLS' own doc
	## comment for which roster is gated and why the other stays measured.
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
				# Optional per-cell ally_hp_mods (the guided-plates cell):
				# folds hp_mod onto the named ally's cfg, the exact
				# start_combat ally_hp_penalty arm this file mirrors.
				var hp_mods: Dictionary = cell.get("ally_hp_mods", {})
				if hp_mods.has(ally_id):
					ally_cfg[WIKeys.HP_MOD] = int(ally_cfg.get(WIKeys.HP_MOD, 0)) + int(hp_mods[ally_id])
				cfgs.append(ally_cfg)
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
			assert(combat.finished, "party %s fight %d did not terminate" % [cell["name"], seed_v])
			# PC-death-instant-defeat re-check: wi_combat.gd's _check_end
			# checks pc.alive FIRST, unconditionally, so a victory can never
			# coincide with a dead pc -- asserted directly (not just assumed)
			# since this is the first cell fielding 3 allies at once.
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
		# pc_alive_rate must equal win_rate exactly by construction (see this
		# loop's own doc comment) -- printed as the re-check itself.
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

	## The dungeon axis. Same gear-aware _build_pc path as RIVERFARM_CELLS/
	## INVRISIL_CELLS/PARTY_CELLS above -- every DUNGEON_CELLS row is solo
	## (the FIGHT route's own skirmish, no ally), so this loop skips the
	## has-ally branch those loops carry.
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
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
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

	assert(not any_failed, "one or more matrix cells failed bounds — see FAIL lines above")
	if any_failed:
		# Asserts are stripped in release templates; keep the exit code honest there too.
		quit(1)
		return
	print("PASS: balance harness terminated cleanly over %d cells x %d seeded runs" % [total_cells, RUNS_PER_CELL])
	quit(0)
