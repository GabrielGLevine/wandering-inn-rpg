extends SceneTree
## GH#211 progression-pace harness (design:
## docs/design/2026-07-19-211-challenge-weighted-leveling.md §6), extended by
## #453 C3 into the PER-SPINE pace instrument.
## Scripted Act I->V traces: REAL fights (WICombat, driven by either the shipped
## autoplay or `qa/combat_policies.gd`'s competent policy) resolved through the
## REAL banking seam (a locally-wired WICombatBanking — the exact deposit path
## #211's challenge weight / repetition decay wraps), then the WIProgression
## sleep sequence. Reports per-act total-level bands per archetype against
## `docs/design/balance-bands-and-policy.md`'s table. The flag ships ON (step 5);
## WI_PACE_WEIGHTED=0 force-disables it to prove the legacy path still
## reproduces the pre-#211 baseline bands (warrior 6/14/16, caster 7/15/16,
## helper 10/21/26 p50 — recorded 2026-07-19); WI_PACE_WEIGHTED=1 force-enables
## regardless of data (symmetric probe). The determinism leg asserts
## same-seed runs reproduce counters exactly under whichever arm ran.
##
##   Run:      godot --headless --path wandering_inn_game --script res://tests/sim_progression_pace.gd
##   Competent: WI_PACE_POLICY=competent ...   (see THE POLICY ARM below)
##   Fast:     WI_PACE_RUNS=8 ...              (default 40 runs per archetype)
##
## MIRROR CONTRACT: _sleep_resolve() reproduces WIGame.sleep()'s progression
## order EXACTLY (gains -> level-ups -> consolidation offer preempts ->
## evolutions) — the sim_class_paths contract, same lockstep rule.
##
## Defeats bank NOTHING (WICombatBanking's victory branch — mirrors real
## play where a game-over reloads); the trace simply moves on, so a losing
## streak slows pace exactly as it does live.
##
## THE POLICY ARM (#453 C3). The band table this harness reports against is
## defined AT THE COMPETENT POLICY (`docs/design/balance-bands-and-policy.md`;
## `tests/sim_spine_viability.gd` measures every climax there). Pace measured
## under the FLOOR policy therefore answers a different question: a spine whose
## kit autoplay cannot spend loses its fights, banks nothing, and reads as a
## PACE failure when the real defect is KIT. Both arms exist so the two can be
## told apart, and the FLOOR arm stays the default so the recorded baselines
## above keep reproducing byte-for-byte. `dumb` calls `WICombatAI.take_turn`
## directly rather than routing through WICombatPolicies' identical delegation,
## so the default arm cannot drift even if that delegation does.
##
## HOW A SPINE'S DIET IS AUTHORED (#453 C3, the honesty rule). `chores` are the
## AMBIENT, repeatable-per-waking producers reachable on that act's route, at a
## rate well under the shipped pool (a diligent player, never a completionist);
## `quest_grants` are copied from `data/quests.json`'s own
## `resolution_paths[].grant` for the fork that spine would take, never invented;
## `entry` fires at the waking the class's `gained_by` producer first becomes
## reachable per `docs/design/steel-thread-route-spec.md`. The census behind the
## rates (2026-08-13, #453 C3):
##   heard_gossip        55 `talk_pool` NPCs, 1 each per waking (inn 8,
##                       floodplains 2, liscor 13, invrisil 21, pallass 4,
##                       riverfarm 5, ruin 2) -> Act I reach is 10.
##   befriended_moments  [Charming Smile], once per entity per waking over 91
##                       npc entities; needs [Diplomat] 1 first.
##   observed_things     [Observe], once per npc/encounter entity per waking
##                       over a 137-entity pool; needs [Tactician] 1 (or
##                       [Diplomat] 5).
##   sneaked_past_danger once per PROXIMITY encounter per waking, and the whole
##                       game ships NINE of them (floodplains 3, invrisil 4,
##                       riverfarm 1, dungeon 1); needs [Sneak] ([Rogue] 1).
##   tended_beasts       floodplains `wounded_corusdeer` (once per waking, and
##                       it LEAVES at 10), `corusdeer_range` and
##                       `razorbeak_nest` talk-downs (respawn each sleep),
##                       riverfarm `hunters_lamb_pen` (once per waking) — four
##                       props total, two of them Act IV regions.
##   ranged_hit          exactly ONE non-combat producer, liscor
##                       `archery_butt`, `once_per_waking` and bow-gated; no
##                       quest grant anywhere banks it.
##   death_cast          ZERO producers outside combat, and only two inside it:
##                       it tallies off `element: "death"`
##                       (`wi_combat.gd:983`) and the game ships exactly two
##                       death skills, [Bone Dart] and [Deathbolt], both
##                       `contexts: ["combat"]`. No prop, conversation or quest
##                       grant banks it (2026-08-13 census).
##   melee_hit/spell_cast/won_combat/tactic_used  the combat action tally.
## Every rate below cites which of those it draws on.

const RUNS_PER_ARCHETYPE := 40
## Act boundaries in wakings — the trace positions where bands are read.
## Acts I-III are the shipped #211 boundaries, untouched. Acts IV and V are
## #453 C3's extension, sized on the SAME cadence those three encode:
## `docs/design/steel-thread-route-spec.md` gives Acts I-V 6/5/6/12/6 beats and
## this file already spends 10/12/14 wakings on the first three (~2 per beat),
## so Act IV gets 24 and Act V 12. Acts I-III reads are unchanged by the
## extension — the per-waking fight seed is `hash(name) + run*1000 + waking`,
## so wakings 1..36 replay identically whatever follows them.
const ACT_ENDS := [10, 22, 36, 60, 72]
## `docs/design/balance-bands-and-policy.md`'s per-act target bands (combined
## class levels at the act's CLIMAX). REPORT-ONLY: this file prints
## BELOW/IN/ABOVE per act and never gates on them — band NUMBERS ratify through
## CHOICE-LOG, not through a sim.
const ACT_BANDS := [[1, 2], [4, 6], [8, 10], [12, 14], [14, 16]]

## Per-archetype act schedules. fights: rotation of composition indexes into
## COMPS, one fight per waking (rotation wraps; -1 is a fightless waking).
## chores: flat per-waking civil banks. Rosters are REAL shipped cells
## (sim_combat_batch names) and are kept in lockstep with the map entities they
## mirror — #439's Act I/II/III climax retune moved three of them (goblin_ambush
## +1 raider, shield_spiders +matriarch, raskghar_scouts scout + pack-leader),
## because an XP-budget model fed pre-retune rosters answers a question about
## content that no longer ships. The docstring's legacy-arm baseline above
## (warrior 6/14/16, caster 7/15/16, helper 10/21/26) predates that move.
##
## ALLY LOCKSTEP (#453 C3 fix). `allies` is now the map entity's OWN ally list,
## not a hand-picked stand-in: three cells had drifted (`crate_scavengers` and
## `shield_spiders` field Klbkch live, not nobody and not Relc;
## `goblin_night_patrol` fields Relc live and had none here). The same argument
## the retune comment makes about enemy rosters applies to the ally slot — an
## XP-budget model fought without the ally the player actually gets answers a
## question about content that does not ship. Deltas from the fix are recorded
## in the #453 C3 report.
## on_victory MIRRORS the in-game encounter's field (several Act-I fights
## bank won_combat explicitly — warrior/mage L2 gate on it).
const COMPS := [
	# --- Acts I-III (shipped since #211) ---
	{"name": "crate_scavengers", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "on_victory": ["recovered_crate_force", "found_the_crate"], "allies": ["klbkch"]},
	{"name": "goblin_ambush", "arena": "goblin_ambush_tutorial", "enemies": ["goblin_raider", "goblin_raider", "goblin_shaman"], "on_victory": ["won_combat", "sign_defended"], "allies": ["relc"]},
	{"name": "rock_crab_nest", "arena": "boulder_flats", "enemies": ["rock_crab"], "on_victory": ["rock_crabs_culled"], "allies": ["relc"]},
	{"name": "sewer_vermin", "arena": "sewers_nest", "enemies": ["sewer_vermin", "sewer_vermin"], "on_victory": ["cleared_sewer_vermin"], "allies": []},
	{"name": "shield_spiders", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider", "shield_spider_matriarch"], "on_victory": ["cleared_the_nest", "resolved_the_cisterns"], "allies": ["klbkch"]},
	{"name": "chieftains_raid", "arena": "cave_mouth", "enemies": ["goblin_chieftain", "goblin_raider", "cave_spider"], "on_victory": ["won_combat"], "allies": ["relc"]},
	{"name": "raskghar_scouts", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_pack_leader"], "on_victory": ["cleared_raskghar_scouts"], "allies": []},
	{"name": "goblin_night_patrol", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "on_victory": ["won_combat"], "allies": ["relc"]},
	# --- Acts IV-V (#453 C3), same rule: the live map entity's own fields ---
	{"name": "awakened_boss", "arena": "deep_warren", "enemies": ["raskghar_awakened", "raskghar_scout", "raskghar_scout", "sewer_vermin"], "on_victory": ["cleared_the_warren"], "allies": ["relc"]},
	{"name": "ruin_guardian", "arena": "ruin_court", "enemies": ["ruin_guardian", "ruin_ward_a", "ruin_ward_b"], "on_victory": ["cleared_ruin_guardian", "pedestal_unsealed"], "allies": ["relc"]},
	{"name": "alley_footpads", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "on_victory": ["cleared_footpads_a"], "allies": []},
	{"name": "vault_construct", "arena": "vault", "enemies": ["vault_construct"], "on_victory": ["vault_construct_downed"], "allies": ["ceria", "yvlon", "ksmvr"]},
	{"name": "river_wolf_pack", "arena": "village_edge_night", "enemies": ["river_wolf_a", "river_wolf_b", "river_wolf_c"], "on_victory": ["survived_wolf_night"], "allies": ["riverfarm_hunter"]},
	{"name": "forge_calibration_golem", "arena": "forge_hall", "enemies": ["forge_golem"], "on_victory": ["forge_golems_culled"], "allies": []},
	{"name": "boulevard_night_footpads", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "on_victory": ["won_combat"], "allies": []},
	{"name": "gallery_vermin_nest", "arena": "trapped_halls_snare", "enemies": ["rift_vermin_a", "rift_vermin_c"], "on_victory": ["gallery_vermin_culled"], "allies": []},
	{"name": "seal_warden", "arena": "vault", "enemies": ["seal_warden"], "on_victory": ["seal_warden_downed", "won_combat"], "allies": []},
	# --- beast cells: the two respawning floodplains fights a tamer-leaning
	# route meets whether or not it talks them down (razorbeaks are also a
	# standing cull bounty), so a druid trace that never fights them would be
	# modelling a player who avoids its own region.
	{"name": "corusdeer_range", "arena": "boulder_flats", "enemies": ["corusdeer"], "on_victory": ["corusdeer_culled"], "allies": []},
	{"name": "razorbeak_nest", "arena": "boulder_flats", "enemies": ["razorbeak_a", "razorbeak_b"], "on_victory": ["razorbeaks_culled"], "allies": []},
]

const COMP_CRATE := 0
const COMP_GATE := 1
const COMP_ROCK_CRAB := 2
const COMP_SEWER_VERMIN := 3
const COMP_SHIELD_SPIDERS := 4
const COMP_CHIEFTAIN := 5
const COMP_RASKGHAR := 6
const COMP_NIGHT_PATROL := 7
const COMP_AWAKENED := 8
const COMP_RUIN_GUARDIAN := 9
const COMP_ALLEY := 10
const COMP_VAULT := 11
const COMP_WOLVES := 12
const COMP_FORGE_GOLEM := 13
const COMP_BOULEVARD := 14
const COMP_GALLERY := 15
const COMP_WARDEN := 16
const COMP_CORUSDEER := 17
const COMP_RAZORBEAK := 18

## Per-act loadouts for the SPINE archetypes (index = act - 1). The three legacy
## #211 archetypes deliberately carry NONE and keep the unequipped path they
## were recorded on — they are the regression anchor, not a band read.
##
## WHY THE SPINES MUST BE EQUIPPED, and why it is a correctness fix rather than a
## taste one: `wi_combat.gd:630-632` tallies `melee_hit` only when
## `weapon_range <= 1` and `ranged_hit` only when `weapon_range > 1`. An
## unequipped pc row has no `weapon_range`, so it defaults to 1 and a bow spine
## banks ZERO `ranged_hit` no matter how many arrows it lands — and `ranged_hit`
## is [Archer]'s `gained_by`, every [Archer]/[Sharpshooter] rung, and half of
## both [Ranger] 14 and [Scout] 14. The instrument could not measure those two
## spines at all without this. Equipment is best-available-at-that-act, the same
## rule `sim_spine_viability.gd`'s band builds use, with ONE route correction:
## no bow exists anywhere in Act I (peddler 8 gold and Krshia 18 gold are both
## Liscor), so the bow spines open on the new-game `rusty_sword`.
const MARTIAL_LOADOUT := [
	{"weapon": "rusty_sword", "armor": "", "accessories": []},
	{"weapon": "rusty_sword", "armor": "leather_jerkin", "accessories": []},
	{"weapon": "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": []},
	{"weapon": "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	{"weapon": "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
]
const BOW_LOADOUT := [
	{"weapon": "rusty_sword", "armor": "", "accessories": []},
	{"weapon": "training_bow", "armor": "leather_jerkin", "accessories": []},
	{"weapon": "hunting_bow", "armor": "leather_jerkin", "accessories": []},
	{"weapon": "hunting_bow", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	{"weapon": "hunting_bow", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
]

## quest_grants: waking -> authored grant deposits (mirrors the quests.json
## resolution_grant data for the path this archetype would take; applied via
## the REAL WICombatBanking.grant seam at that waking, pre-sleep — the §5
## "quest closes are the big movers" leg of the combined system).
##
## `target` names the consolidation this spine climbs toward, so the trace can
## report the waking the merge actually fires (or that it never does) — the Act
## V band is stated in CONSOLIDATED levels, so "does the spine consolidate at
## all" is the band question, not a detail. `classless_until` is the waking by
## which a class must exist; it is the ROUTE's answer, not a constant, because
## several parents' `gained_by` producers only exist in Liscor and later.
var ARCHETYPES := [
	# ---------------------------------------------------------------- legacy
	# The three #211 archetypes, kept verbatim through Act III so the recorded
	# baselines stay reproducible, and continued into Acts IV-V on the same
	# shapes. They are NOT spines (no consolidation target); they are the
	# regression anchor.
	{"name": "warrior_line", "ai": "melee", "classless_until": 6,
		"entry": {1: {"sparred_with_relc": 1}},
		"quest_grants": {10: {"melee_hit": 6, "won_combat": 1}, 22: {"melee_hit": 10, "won_combat": 2}, 36: {"melee_hit": 12, "won_combat": 2}, 48: {"melee_hit": 8, "won_combat": 2}, 60: {"melee_hit": 8, "won_combat": 1}, 72: {"melee_hit": 10, "won_combat": 2}},
		"acts": [
			{"fights": [0, 1, 2, 1], "chores": {}},
			{"fights": [3, 4, 7, 1], "chores": {}},
			{"fights": [5, 6, 7, 4], "chores": {}},
			{"fights": [9, 10, 11, 12, 13, -1], "chores": {}},
			{"fights": [15, 16, -1, 14], "chores": {}},
		]},
	{"name": "caster_line", "ai": "caster", "classless_until": 6,
		"entry": {1: {"learned_magic_from_pisces": 1}},
		"quest_grants": {10: {"sneaked_past_danger": 2, "heard_gossip": 3}, 22: {"spell_cast": 8}, 36: {"persuaded_someone": 5, "heard_gossip": 8}, 48: {"spell_cast": 8}, 60: {"persuaded_someone": 3, "heard_gossip": 4}, 72: {"spell_cast": 10, "warded_danger": 3}},
		"acts": [
			{"fights": [0, 1, 2, 1], "chores": {}},
			{"fights": [3, 4, 7, 1], "chores": {}},
			{"fights": [5, 6, 7, 4], "chores": {}},
			{"fights": [9, 10, 11, 12, 13, -1], "chores": {}},
			{"fights": [15, 16, -1, 14], "chores": {}},
		]},
	{"name": "helper_social", "ai": "melee", "classless_until": 6,
		"_comment": "fights every fourth waking; chores carry the pace — the non-combat pillar CONTROL (raw counting in v1, per directive)",
		"entry": {1: {"sparred_with_relc": 1, "cleaned_the_inn": 1}},
		"quest_grants": {10: {"cooked_meal": 4, "served_customer": 4}, 22: {"persuaded_someone": 3, "heard_gossip": 6}, 36: {"persuaded_someone": 5, "heard_gossip": 8}, 48: {"persuaded_someone": 3, "befriended_moments": 5, "heard_gossip": 3}, 60: {"persuaded_someone": 4, "heard_gossip": 5}, 72: {"persuaded_someone": 6, "heard_gossip": 8}},
		"acts": [
			{"fights": [1, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "heard_gossip": 2}},
			{"fights": [3, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "persuaded_someone": 1}},
			{"fights": [7, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "befriended_moments": 1}},
			{"fights": [10, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "befriended_moments": 1}},
			{"fights": [15, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "befriended_moments": 1}},
		]},

	# ---------------------------------------------------------------- spines
	# One per non-exempt `consolidations` row in data/classes.json, plus two
	# lines that have no consolidation row to derive from: the post-split
	# tactical line (#450), which is an EVOLUTION line, and [Necromancer]
	# (2026-08-13), which is neither — its evolution is the roster's one parked
	# exception, so it is a base class that ends where it starts.

	# [Spellsword] = warrior + mage. The reference spine: the whole band table
	# was authored against it. `caster` profile because the class casts AND
	# swings — `_act_caster` falls through to `_act_melee`, so one trace banks
	# both `spell_cast` and `melee_hit`, which is exactly what its two parents
	# need. Mage entry at waking 11: `learned_magic_from_pisces` is a Liscor
	# street conversation (route beat 8, Act II).
	{"name": "spellsword_spine", "ai": "caster", "target": "spellsword", "classless_until": 6, "loadout": MARTIAL_LOADOUT,
		"watch": ["melee_hit", "spell_cast", "won_combat"],
		"entry": {1: {"sparred_with_relc": 1}, 11: {"learned_magic_from_pisces": 1}},
		"quest_grants": {10: {"melee_hit": 6, "won_combat": 1}, 22: {"melee_hit": 10, "won_combat": 2}, 48: {"spell_cast": 8}, 52: {"melee_hit": 12, "won_combat": 2}, 60: {"melee_hit": 6, "won_combat": 1}, 72: {"melee_hit": 10, "won_combat": 2}},
		"acts": [
			{"fights": [COMP_GATE, COMP_ROCK_CRAB, -1, COMP_GATE], "chores": {}},
			{"fights": [COMP_CRATE, COMP_SEWER_VERMIN, COMP_SHIELD_SPIDERS, -1], "chores": {}},
			{"fights": [COMP_RASKGHAR, COMP_CHIEFTAIN, COMP_AWAKENED, COMP_NIGHT_PATROL], "chores": {}},
			{"fights": [COMP_RUIN_GUARDIAN, COMP_ALLEY, COMP_VAULT, COMP_WOLVES, COMP_FORGE_GOLEM, -1], "chores": {}},
			{"fights": [COMP_GALLERY, COMP_WARDEN, -1, COMP_BOULEVARD], "chores": {}},
		]},

	# [Innkeeper] = helper + diplomat. The non-combat spine. Fights once every
	# fourth waking (the inn is not a dungeon). Chores: `cleaned_the_inn` and
	# `cooked_meal` off the inn's three cookware props and the dirty table,
	# `served_customer` off the inn conversation rows, `delivered_item` off the
	# serving tray (once_per_waking, hence 1), `heard_gossip` off talk_pool
	# NPCs (10 reachable in Act I, 23 by Act II, 55 by Act IV — 3/waking is
	# well under all three). [Diplomat] can only form once BOTH its counters
	# exist, and `persuaded_someone`'s producers are all Liscor and later, so
	# its entry is waking 12.
	{"name": "innkeeper_spine", "ai": "melee", "target": "innkeeper", "classless_until": 6, "loadout": MARTIAL_LOADOUT,
		"watch": ["cleaned_the_inn", "served_customer", "delivered_item", "cooked_meal", "heard_gossip", "befriended_moments"],
		"entry": {1: {"cleaned_the_inn": 1}, 12: {"persuaded_someone": 1}},
		"quest_grants": {10: {"cooked_meal": 4, "served_customer": 4}, 22: {"persuaded_someone": 2, "befriended_moments": 3, "heard_gossip": 3}, 40: {"persuaded_someone": 3, "heard_gossip": 4}, 48: {"persuaded_someone": 3, "befriended_moments": 5, "sneaked_past_danger": 3}, 56: {"persuaded_someone": 5, "heard_gossip": 8}, 60: {"persuaded_someone": 4, "heard_gossip": 5}, 72: {"persuaded_someone": 6, "heard_gossip": 8}},
		"acts": [
			{"fights": [COMP_GATE, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "delivered_item": 1, "cooked_meal": 2, "heard_gossip": 3}},
			{"fights": [COMP_SEWER_VERMIN, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "delivered_item": 1, "cooked_meal": 2, "heard_gossip": 3, "befriended_moments": 2}},
			{"fights": [COMP_NIGHT_PATROL, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "delivered_item": 1, "cooked_meal": 2, "heard_gossip": 3, "befriended_moments": 2}},
			{"fights": [COMP_ALLEY, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "delivered_item": 1, "cooked_meal": 2, "heard_gossip": 3, "befriended_moments": 2}},
			{"fights": [COMP_GALLERY, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "delivered_item": 1, "cooked_meal": 2, "heard_gossip": 3, "befriended_moments": 2}},
		]},

	# [Ranger] = warrior + archer. `ranged` profile from Act II on — but the
	# harness has ONE profile per trace, and a bow-carrying warrior is what the
	# spine is, so `ranged` it is; `_act_ranged` falls through to melee when it
	# cannot keep distance, which is also what the shipped autoplay does.
	# [Archer]'s `gained_by` is `ranged_hit: 3` and the earliest bow is the
	# Liscor peddler (8 gold) or Krshia (18) — no bow exists in Act I at all,
	# so the entry cannot fire before waking 11. `archery_butt` (liscor
	# barracks, once_per_waking, bow-gated) is the ONLY non-combat ranged_hit
	# producer in the game, hence the flat 1/waking from Act II on.
	{"name": "ranger_spine", "ai": "melee", "target": "ranger", "classless_until": 6, "loadout": BOW_LOADOUT,
		"watch": ["melee_hit", "ranged_hit", "won_combat"],
		"entry": {1: {"sparred_with_relc": 1}, 11: {"ranged_hit": 3}},
		# #453 G4 (user ruling 2026-08-13): the waking-60 row is `chieftains_price`
		# .drove_off_rags -- its {melee_hit 8, won_combat 1} matches that fork's
		# grant exactly -- and that fork now pays `ranged_hit` at the same rate as
		# melee. This is the fight fork, so a bow spine that drove Rags off banks
		# its own axis for the first time; before G4 not one quest grant in the
		# game paid `ranged_hit` at all.
		"quest_grants": {10: {"melee_hit": 6, "won_combat": 1}, 22: {"melee_hit": 10, "won_combat": 2}, 48: {"melee_hit": 12, "won_combat": 2}, 56: {"melee_hit": 6, "won_combat": 1}, 60: {"melee_hit": 8, "ranged_hit": 8, "won_combat": 1}, 72: {"melee_hit": 10, "won_combat": 2}},
		"acts": [
			{"fights": [COMP_GATE, COMP_ROCK_CRAB, -1, COMP_GATE], "chores": {}},
			{"fights": [COMP_CRATE, COMP_SEWER_VERMIN, COMP_SHIELD_SPIDERS, -1], "chores": {"ranged_hit": 1}},
			{"fights": [COMP_RASKGHAR, COMP_CHIEFTAIN, COMP_AWAKENED, COMP_NIGHT_PATROL], "chores": {"ranged_hit": 1}},
			{"fights": [COMP_RUIN_GUARDIAN, COMP_ALLEY, COMP_VAULT, COMP_WOLVES, COMP_FORGE_GOLEM, -1], "chores": {"ranged_hit": 1}},
			{"fights": [COMP_GALLERY, COMP_WARDEN, -1, COMP_BOULEVARD], "chores": {"ranged_hit": 1}},
		]},

	# [Scout] = rogue + archer. THIS SPINE'S DIET MOVED WITH #453 G2/G4 (user
	# ruling 2026-08-13) -- the C3 measurement that produced those gaps read this
	# spine as the one STRUCTURAL PACE wall in the roster, and the shipped answer
	# has to be re-authored here or the instrument keeps reporting a game that no
	# longer exists (the honesty rule at the top of this file).
	#   G2: [Rogue]'s entry is now `accomplishment_any` over the crate job OR
	#   `crossed_under_cover`, banked by crossing the floodplains gate-road ambush
	#   after going down into the drainage cut. That crossing is Act I road content
	#   -- this diet already asserts the ambush is reachable at waking 1 by fighting
	#   COMP_GATE there -- so the entry moves 11 -> 1 and `classless_until` 14 -> 2.
	#   The `fights` rotation is DELIBERATELY UNCHANGED: the cover arm buys one
	#   crossing per waking and the ambush re-arms at every sleep, so a spine that
	#   crosses under cover on waking 1 and fights the same ambush on wakings 5 and
	#   9 is the literal shipped behaviour, not an approximation. Act I chores gain
	#   the sneak line for the first time: pre-G2 this spine could not sneak in Act
	#   I because [Stealth] is a [Rogue] L1 grant and [Rogue] was unreachable.
	#   G4: `ranged_hit: 4` joins the waking-72 row. That row is `the_hat_stays_on`
	#   .handoff_quiet -- its OTHER two counters match that fork's grant exactly
	#   ({sneaked_past_danger 2, observed_things 2}) and it is the quiet fork a
	#   scout takes. `chieftains_price.drove_off_rags` (the other G4 fork) is NOT
	#   added here: it is the draw-steel fork, and every row in this diet carries
	#   zero melee_hit -- this spine does not take it. See ranger_spine for that one.
	# Chores: `sneaked_past_danger` at 1/waking — the game ships 9 proximity
	# encounters total and only 3 are reachable before Act IV, and each credits
	# once per waking.
	{"name": "scout_spine", "ai": "melee", "target": "scout", "classless_until": 2, "loadout": BOW_LOADOUT,
		"watch": ["sneaked_past_danger", "ranged_hit", "observed_things", "won_combat"],
		"entry": {1: {"crossed_under_cover": 1}, 13: {"ranged_hit": 3}},
		"quest_grants": {12: {"sneaked_past_danger": 2, "observed_things": 2}, 22: {"sneaked_past_danger": 4, "observed_things": 4}, 44: {"sneaked_past_danger": 3, "observed_things": 2}, 52: {"sneaked_past_danger": 6, "persuaded_someone": 2}, 60: {"sneaked_past_danger": 3, "heard_gossip": 4}, 72: {"sneaked_past_danger": 2, "observed_things": 2, "ranged_hit": 4}},
		"acts": [
			{"fights": [COMP_GATE, -1, -1, -1], "chores": {"sneaked_past_danger": 1}},
			{"fights": [COMP_CRATE, COMP_SEWER_VERMIN, -1, -1], "chores": {"sneaked_past_danger": 1, "ranged_hit": 1}},
			{"fights": [COMP_RASKGHAR, -1, COMP_NIGHT_PATROL, -1], "chores": {"sneaked_past_danger": 1, "ranged_hit": 1}},
			{"fights": [COMP_ALLEY, -1, COMP_BOULEVARD, -1, COMP_WOLVES, -1], "chores": {"sneaked_past_danger": 3, "ranged_hit": 1}},
			{"fights": [COMP_GALLERY, -1, COMP_WARDEN, -1], "chores": {"sneaked_past_danger": 3, "ranged_hit": 1}},
		]},

	# [Druid] = beast_tamer + mage. `soothed_a_beast` (the tamer entry) is the
	# floodplains `wounded_corusdeer`, reachable on the Act I road, so this is
	# the one non-martial spine that can hold a class in Act I. Chores:
	# `tended_beasts` at 2/waking through Acts I-III (the corusdeer prop until
	# it heals at 10, plus the two respawning talk-downs), 3/waking from Act IV
	# (riverfarm's lamb pen joins). No quest grant in the entire game banks
	# `tended_beasts`, so the ONLY grants here are the spell-cast forks.
	{"name": "druid_spine", "ai": "caster", "target": "druid", "classless_until": 6, "loadout": MARTIAL_LOADOUT,
		"watch": ["tended_beasts", "spell_cast", "soothed_a_beast", "won_combat"],
		"entry": {1: {"soothed_a_beast": 1}, 11: {"learned_magic_from_pisces": 1}},
		"quest_grants": {22: {"spell_cast": 8}, 48: {"spell_cast": 8}, 72: {"spell_cast": 10, "warded_danger": 3}},
		"acts": [
			{"fights": [COMP_CORUSDEER, -1, COMP_RAZORBEAK, -1], "chores": {"tended_beasts": 2}},
			{"fights": [COMP_CORUSDEER, COMP_SEWER_VERMIN, COMP_RAZORBEAK, -1], "chores": {"tended_beasts": 2}},
			{"fights": [COMP_RASKGHAR, COMP_CORUSDEER, COMP_AWAKENED, COMP_RAZORBEAK], "chores": {"tended_beasts": 2}},
			{"fights": [COMP_RUIN_GUARDIAN, COMP_WOLVES, COMP_VAULT, COMP_CORUSDEER, COMP_FORGE_GOLEM, -1], "chores": {"tended_beasts": 3}},
			{"fights": [COMP_GALLERY, COMP_WARDEN, COMP_RAZORBEAK, -1], "chores": {"tended_beasts": 3}},
		]},

	# [Necromancer] (user ruling 2026-08-13). NOT a spine and NOT an evolution
	# line: `consolidations` has no row for it and its evolution is the roster's
	# one deliberate PARKED exception (classes.json's own comment — no attested
	# <=Vol-7 necromancer evolution exists), so it carries no `target` at all and
	# nothing here reports a merge. That is the measurement: a class that ends
	# where it starts, against a band table stated in consolidated levels.
	#
	# ENTRY, waking 12 — the route's answer, not a round number. `studied_
	# necromancy` has exactly one producer, Pisces' `necro_teach` node
	# (`data/dialogue/pisces_magic.json`), and that node is TWO VISITS deep by
	# authored design: the file's own comment reads "Two-visit deflect->teach per
	# spec §5" — the first ask banks `asked_about_necromancy` and hides itself,
	# and the second hub entry reveals the teach. Pisces stands on the Liscor
	# Guild steps, the same Act II street beat this file already dates at waking
	# 11 for `learned_magic_from_pisces`, so the earliest honest entry is the
	# NEXT waking. `classless_until` 12 says exactly that, and (12 > ACT_ENDS[0])
	# the Act I nonzero gate correctly exempts this line, as it does the
	# tactician's.
	#
	# THE DIET IS ALL FIGHT. The census result for this line is a single sentence:
	# `death_cast` has NO producer outside combat. It banks in `wi_combat.gd:983`,
	# which tallies `<element>_cast` when a cast lands, and the whole game ships
	# two death-element skills — [Bone Dart] (necromancer L1) and [Deathbolt]
	# (L3), both `contexts: ["combat"]`. No prop, no conversation and no quest
	# grant banks it anywhere — every `death_cast` in the repo is either the
	# ladder in classes.json, its id registration in shipped_ids.json, or the two
	# QA assets that hand-bank it (`qa/fixtures/near_necromancer.json`,
	# `qa/scripts/necromancer_loop.json`). So `chores` is EMPTY on purpose — a
	# chore row here would be invented content — and the L3-L12 ladder is
	# measured through the fights or not at all. Same single-source shape #453 G4
	# found for `ranged_hit`, one axis over.
	#
	# QUEST GRANTS, both of them. `quests.json` carries exactly TWO `spell_cast`
	# grants in the entire file, and this line takes both: `door_that_goes_
	# elsewhere`.read_the_door_runes {spell_cast 8} at waking 48 (route beat 23,
	# Act IV, the read-the-wardwork fork a spellcaster takes — the same fork and
	# the same waking `spellsword_spine` reads it at) and `what_the_seal_was_
	# feeding`.seal_rewarded {spell_cast 10, warded_danger 3} at 72. Neither pays
	# `death_cast`; see above.
	#
	# ROTATION is `spellsword_spine`'s verbatim. The necromancer's producer is a
	# Liscor street conversation one beat off [Mage]'s, so it walks the same
	# main-quest route, and holding the fights fixed makes the CLASS the only
	# moving part between the two traces. `caster` profile for the same reason
	# spellsword uses it: `_act_caster` falls through to `_act_melee`, so one
	# trace banks casts and swings the way the class actually plays.
	#
	# CANON NOTE, deliberately not modelled: Pisces holds [Necromancer] BESIDE
	# [Mage] (classes.json). This trace holds the line ALONE, because the question
	# it exists to answer is whether the death-cast curve carries its own band —
	# and a mage riding along would answer a different one.
	{"name": "necromancer_line", "ai": "caster", "classless_until": 12, "loadout": MARTIAL_LOADOUT,
		"watch": ["death_cast", "spell_cast", "won_combat"],
		"entry": {12: {"studied_necromancy": 1}},
		"quest_grants": {48: {"spell_cast": 8}, 72: {"spell_cast": 10, "warded_danger": 3}},
		"acts": [
			{"fights": [COMP_GATE, COMP_ROCK_CRAB, -1, COMP_GATE], "chores": {}},
			{"fights": [COMP_CRATE, COMP_SEWER_VERMIN, COMP_SHIELD_SPIDERS, -1], "chores": {}},
			{"fights": [COMP_RASKGHAR, COMP_CHIEFTAIN, COMP_AWAKENED, COMP_NIGHT_PATROL], "chores": {}},
			{"fights": [COMP_RUIN_GUARDIAN, COMP_ALLEY, COMP_VAULT, COMP_WOLVES, COMP_FORGE_GOLEM, -1], "chores": {}},
			{"fights": [COMP_GALLERY, COMP_WARDEN, -1, COMP_BOULEVARD], "chores": {}},
		]},

	# [Tactician] -> [Strategist] (#450). NOT a consolidation — an evolution
	# line, so it has no `consolidations` row and `target` names the evolution
	# instead. `chess_with_olesm` is a Liscor street conversation, so the entry
	# is Act II. `observed_things` comes from [Observe] (a Tactician L1 grant)
	# over the 137-entity npc/encounter pool, once each per waking; 3/waking is
	# conservative. `tactic_used` is NOT a chore — it banks only in combat, once
	# per tactic Skill per fight, and the line ships five of them, so the
	# post-split rungs are measured through the fights, never hand-fed.
	{"name": "tactician_line", "ai": "melee", "target": "strategist", "classless_until": 14, "loadout": MARTIAL_LOADOUT,
		"watch": ["observed_things", "tactic_used", "won_combat"],
		"entry": {11: {"chess_with_olesm": 1}},
		"quest_grants": {22: {"observed_things": 4}, 40: {"observed_things": 4, "deliberate_commerce": 2}, 48: {"observed_things": 5, "deliberate_commerce": 2}, 56: {"observed_things": 3, "befriended_moments": 2}, 60: {"observed_things": 2, "heard_gossip": 2}, 72: {"observed_things": 2}},
		"acts": [
			{"fights": [COMP_GATE, -1, COMP_ROCK_CRAB, -1], "chores": {}},
			{"fights": [COMP_CRATE, COMP_SEWER_VERMIN, COMP_SHIELD_SPIDERS, -1], "chores": {"observed_things": 3}},
			{"fights": [COMP_RASKGHAR, COMP_CHIEFTAIN, COMP_AWAKENED, COMP_NIGHT_PATROL], "chores": {"observed_things": 3}},
			{"fights": [COMP_RUIN_GUARDIAN, COMP_ALLEY, COMP_VAULT, COMP_WOLVES, COMP_FORGE_GOLEM, -1], "chores": {"observed_things": 3}},
			{"fights": [COMP_GALLERY, COMP_WARDEN, -1, COMP_BOULEVARD], "chores": {"observed_things": 3}},
		]},
]

var _acc: Dictionary = {}
var _used_skills: Array[String] = []
var _entity: Dictionary = {}
var _banking: WICombatBanking = null
var _frac: Dictionary = {}
var _policy := WICombatPolicies.DUMB
var _items_by_id: Dictionary = {}
var _skills_by_id: Dictionary = {}
var _batch: GDScript = preload("res://tests/sim_combat_batch.gd")
var _runs := RUNS_PER_ARCHETYPE
## Collected failures. A bare `assert` does NOT stop a `--script` run (it prints
## `SCRIPT ERROR: Assertion failed` and execution continues to the final PASS
## line with rc=0) — the dishonest-green family this wave has already fixed
## three times. Every gate below routes here instead, and `_init` claims the
## exit code BEFORE any assert so a tripped one cannot abort the function ahead
## of its own `quit(1)`.
var _fails: Array[String] = []


func _fail(msg: String) -> void:
	_fails.append(msg)
	printerr("FAIL [pace] %s" % msg)


func _init() -> void:
	WITestWatchdog.arm(self)
	var catalog: Dictionary = _load_json("res://data/classes.json")
	var skills: Dictionary = _load_json("res://data/skills.json")
	var arenas_by_id := {}
	for a: Dictionary in _load_json("res://data/arenas.json")["arenas"]:
		arenas_by_id[String(a[WIKeys.ID])] = a
	var combatants_by_id := {}
	for c: Dictionary in _load_json("res://data/combatants.json")["combatants"]:
		combatants_by_id[String(c[WIKeys.ID])] = c
	for it: Dictionary in _load_json("res://data/items.json")["items"]:
		_items_by_id[String(it[WIKeys.ID])] = it
	for sk: Dictionary in skills[WIKeys.SKILLS]:
		_skills_by_id[String(sk[WIKeys.ID])] = sk
	var sink := func(_t: String, _p: Dictionary) -> void: pass
	# WI_PACE_WEIGHTED forces the flag either way (data ships enabled:true):
	# "0" = legacy-path regression arm (must reproduce the pre-#211 baseline
	# bands), "1" = force-on (symmetric; redundant while data is true).
	var challenge: Dictionary = (_load_json("res://data/progression.json").get("challenge", {}) as Dictionary).duplicate(true)
	if OS.get_environment("WI_PACE_WEIGHTED") == "1":
		challenge["enabled"] = true
		print("(WI_PACE_WEIGHTED probe: challenge weighting FORCED ON)")
	elif OS.get_environment("WI_PACE_WEIGHTED") == "0":
		challenge["enabled"] = false
		print("(WI_PACE_WEIGHTED=0: challenge weighting FORCED OFF — legacy regression arm)")
	var policy_env := OS.get_environment("WI_PACE_POLICY")
	if policy_env == WICombatPolicies.COMPETENT:
		_policy = WICombatPolicies.COMPETENT
	elif policy_env != "" and policy_env != WICombatPolicies.DUMB:
		_fail("WI_PACE_POLICY=%s is not a policy; use %s or %s" % [policy_env, WICombatPolicies.DUMB, WICombatPolicies.COMPETENT])
	var runs_env := OS.get_environment("WI_PACE_RUNS")
	if runs_env != "":
		_runs = maxi(1, int(runs_env))
	var combatants_raw: Array = _load_json("res://data/combatants.json")["combatants"]
	_banking = WICombatBanking.new(sink, _mark_skill_used, _find_entity, _record, _count, _roll_loot_noop, _remove_noop, challenge, catalog, combatants_raw)

	print("progression pace: %d archetypes x %d runs, act ends %s, policy %s" % [
		ARCHETYPES.size(), _runs, str(ACT_ENDS), _policy])
	print("bands (balance-bands-and-policy.md): %s" % str(ACT_BANDS))
	var repeat_check := {}
	for arch: Dictionary in ARCHETYPES:
		# act -> Array of total-level samples
		var act_levels: Dictionary = {}
		var act_win_counts: Dictionary = {}
		var act_counters: Dictionary = {}
		var act_builds: Dictionary = {}
		var consolidated_at: Array = []
		## One classless report per archetype: the gate is a drift detector, not
		## a per-waking log, and an entry-id drift would otherwise print
		## RUNS x WAKINGS identical lines and bury every other finding.
		var classless_reported := false
		for act_idx: int in ACT_ENDS.size():
			act_levels[act_idx] = []
			act_win_counts[act_idx] = []
			act_counters[act_idx] = []
			act_builds[act_idx] = []
		for run: int in _runs:
			var classes: Dictionary = {}
			var generalists: Array = []
			var wins := 0
			var merged_at := 0
			_acc = {}
			_frac = {}
			_used_skills = []
			var act_idx := 0
			for waking: int in range(1, ACT_ENDS[-1] + 1):
				var entry: Dictionary = arch.get("entry", {})
				if entry.has(waking):
					for k: String in entry[waking]:
						_acc[k] = int(_acc.get(k, 0)) + int(entry[waking][k])
				var act: Dictionary = arch["acts"][act_idx]
				var rotation: Array = act["fights"]
				var comp_idx := int(rotation[(waking - 1) % rotation.size()])
				if comp_idx >= 0:
					var comp: Dictionary = COMPS[comp_idx]
					var fight_seed: int = hash(String(arch["name"])) + run * 1000 + waking
					if _run_fight(comp, classes, catalog, skills, arenas_by_id, combatants_by_id, String(arch["ai"]), fight_seed, _act_loadout(arch, act_idx)):
						wins += 1
				for k: String in act["chores"]:
					_acc[k] = int(_acc.get(k, 0)) + int(act["chores"][k])
				var qg: Dictionary = arch.get("quest_grants", {})
				if qg.has(waking):
					_banking.grant(qg[waking] as Dictionary, _frac)
				_sleep_resolve(classes, _acc, catalog, generalists, true)
				var target := String(arch.get("target", ""))
				if merged_at == 0 and target != "" and classes.has(target):
					merged_at = waking
				if waking >= int(arch.get("classless_until", 6)) and classes.is_empty() and not classless_reported:
					classless_reported = true
					_fail("%s classless at waking %d — entry ids drifted from classes.json gained_by" % [arch["name"], waking])
				if waking == ACT_ENDS[act_idx]:
					(act_levels[act_idx] as Array).append(_total_levels(classes))
					(act_win_counts[act_idx] as Array).append(wins)
					(act_counters[act_idx] as Array).append(_acc.duplicate())
					(act_builds[act_idx] as Array).append(_build_label(classes))
					act_idx = mini(act_idx + 1, ACT_ENDS.size() - 1)
			consolidated_at.append(merged_at)
			if run == 0:
				repeat_check[String(arch["name"])] = _acc.duplicate(true)
		print("\n[%s]%s" % [arch["name"], "" if not arch.has("target") else "  (target: %s)" % arch["target"]])
		for act_idx: int in ACT_ENDS.size():
			var samples: Array = act_levels[act_idx]
			samples.sort()
			var p50 := int(samples[samples.size() / 2])
			var band: Array = ACT_BANDS[act_idx]
			var verdict := "IN BAND"
			if p50 < int(band[0]):
				verdict = "BELOW BAND"
			elif p50 > int(band[1]):
				verdict = "ABOVE BAND"
			print("  act %d (waking %2d): total-level p10=%2d p50=%2d p90=%2d  band %d-%d  %-10s  (fights won p50=%d)  build %s" % [
				act_idx + 1, ACT_ENDS[act_idx],
				samples[samples.size() / 10], p50, samples[samples.size() * 9 / 10],
				int(band[0]), int(band[1]), verdict,
				_median(act_win_counts[act_idx]),
				_modal_build(act_builds[act_idx]),
			])
			var watch: Array = arch.get("watch", [])
			if not watch.is_empty():
				var parts: Array[String] = []
				for counter: String in watch:
					parts.append("%s=%d" % [counter, _median_counter(act_counters[act_idx], counter)])
				print("        counters p50: %s" % ", ".join(parts))
		if arch.has("target"):
			var merged := _median(consolidated_at)
			var never := 0
			for w: Variant in consolidated_at:
				if int(w) == 0:
					never += 1
			print("  %s reached: p50 waking %s (%d/%d runs never reach it)" % [
				arch["target"], "never" if merged == 0 else str(merged), never, consolidated_at.size()])
		# Sanity gate: pace must be monotone and nonzero per act (band NUMBERS
		# are report-only until ratified via CHOICE-LOG; these structural
		# gates hold regardless of tuning).
		var p50s: Array = []
		for act_idx: int in ACT_ENDS.size():
			var s: Array = act_levels[act_idx]
			p50s.append(int(s[s.size() / 2]))
		# A spine whose parents' `gained_by` producers are ALL Liscor-or-later
		# (scout: `recovered_crate_watch` is an Act II quest close; archer needs a
		# bow nobody sells in Act I) is legitimately classless at the Act I
		# boundary. `classless_until` is that route fact, so the nonzero gate only
		# applies to archetypes the route says should already hold a class there.
		if int(arch.get("classless_until", 6)) <= int(ACT_ENDS[0]) and int(p50s[0]) < 1:
			_fail("%s: Act I median total level %d < 1 — trace banks nothing at all" % [arch["name"], p50s[0]])
		if int(p50s[-1]) <= int(p50s[0]):
			_fail("%s: no growth across acts (p50 %s)" % [arch["name"], str(p50s)])

	# Determinism / regression leg: the same seeded run must reproduce the
	# counter dictionary EXACTLY (the weight-off reproduction proof rides
	# this — after #211 lands, weight-off config re-runs must match too).
	for arch: Dictionary in ARCHETYPES:
		var classes: Dictionary = {}
		var generalists: Array = []
		_acc = {}
		_frac = {}
		_used_skills = []
		var act_idx := 0
		for waking: int in range(1, ACT_ENDS[-1] + 1):
			var entry: Dictionary = arch.get("entry", {})
			if entry.has(waking):
				for k: String in entry[waking]:
					_acc[k] = int(_acc.get(k, 0)) + int(entry[waking][k])
			var act: Dictionary = arch["acts"][act_idx]
			var rotation: Array = act["fights"]
			var comp_idx := int(rotation[(waking - 1) % rotation.size()])
			if comp_idx >= 0:
				var comp: Dictionary = COMPS[comp_idx]
				var fight_seed: int = hash(String(arch["name"])) + 0 * 1000 + waking
				var catalog2: Dictionary = catalog
				_run_fight(comp, classes, catalog2, skills, arenas_by_id, combatants_by_id, String(arch["ai"]), fight_seed, _act_loadout(arch, act_idx))
			for k: String in act["chores"]:
				_acc[k] = int(_acc.get(k, 0)) + int(act["chores"][k])
			var qg: Dictionary = arch.get("quest_grants", {})
			if qg.has(waking):
				_banking.grant(qg[waking] as Dictionary, _frac)
			_sleep_resolve(classes, _acc, catalog, generalists, true)
			if waking == ACT_ENDS[act_idx]:
				act_idx = mini(act_idx + 1, ACT_ENDS.size() - 1)
		var first: Dictionary = repeat_check[String(arch["name"])]
		if JSON.stringify(_sorted(_acc)) != JSON.stringify(_sorted(first)):
			_fail("%s: repeat run diverged from run 0 — banking path is not deterministic" % arch["name"])

	if not _fails.is_empty():
		# ORDER MATTERS (sim_spine_viability's shape): a failed `assert` ABORTS
		# the enclosing function, so with the assert first `quit(1)` would never
		# run and the file would exit by watchdog timeout instead of by failing.
		printerr("progression pace: %d failures" % _fails.size())
		quit(1)
		return
	print("\nPASS: progression-pace harness — bands reported (ratify via CHOICE-LOG), determinism leg green")
	quit(0)


## One autoplay fight with the pc built from CURRENT classes; banks through
## the REAL WICombatBanking on victory. Returns victory.
##
## The DUMB arm calls `WICombatAI.take_turn` directly — not
## `WICombatPolicies.new(DUMB).take_turn`, which delegates to the same function
## — so the default arm's recorded baselines cannot move if that delegation ever
## drifts. The COMPETENT arm drives only the pc (`driven`); allies and enemies
## keep their shipped profiles in both arms.
func _run_fight(comp: Dictionary, classes: Dictionary, catalog: Dictionary, skills: Dictionary, arenas_by_id: Dictionary, combatants_by_id: Dictionary, ai: String, fight_seed: int, loadout: Dictionary = {}) -> bool:
	# `_build_pc` is shared with the balance matrix and the spine table on
	# purpose: a pace trace and a viability row that name the same build must BE
	# the same combatant. With no `weapon` key it falls to the bare
	# granted-skills path, which is exactly the unequipped shape the three legacy
	# archetypes were recorded on.
	var build := {"classes": classes, WIKeys.AI: ai}
	if not loadout.is_empty():
		build[WIKeys.WEAPON] = String(loadout["weapon"])
		build["armor"] = String(loadout["armor"])
		build["accessories"] = loadout["accessories"]
	var pc: Dictionary = _batch._build_pc(build, combatants_by_id["pc"], catalog, _skills_by_id, _items_by_id)
	var cfgs: Array = [pc]
	var arena: Dictionary = arenas_by_id[String(comp["arena"])]
	var allies: Array = (comp.get("allies", []) as Array).duplicate()
	# COMPANION RULE, mirrored from sim_spine_viability._spine_cfgs: a bonded
	# wolf fields when [Lesser Bond] is in the kit and the arena has a spawn
	# left for it. A druid trace measured without its companion is measuring a
	# different class.
	if (pc[WIKeys.SKILLS] as Array).has("lesser_bond") and not allies.has("wolf_companion") \
			and allies.size() + 2 <= (arena["player_spawns"] as Array).size():
		allies.append("wolf_companion")
	for ally_id: String in allies:
		var ally: Dictionary = (combatants_by_id[ally_id] as Dictionary).duplicate(true)
		if ally_id == "wolf_companion":
			var boons: Array = []
			if (pc[WIKeys.SKILLS] as Array).has("animals_basic_command"):
				boons.append("basic_command_boon")
			if (pc[WIKeys.SKILLS] as Array).has("pack_bond"):
				boons.append("pack_bond_boon")
			(ally[WIKeys.SKILLS] as Array).append_array(boons)
		cfgs.append(ally)
	for enemy_id: String in comp["enemies"]:
		cfgs.append((combatants_by_id[enemy_id] as Dictionary).duplicate(true))
	var sink := func(_t: String, _p: Dictionary) -> void: pass
	var combat := WICombat.new(arena, cfgs, skills, sink, fight_seed)
	combat.begin()
	var guard := 0
	if _policy == WICombatPolicies.DUMB:
		while not combat.finished and guard < 2000:
			guard += 1
			WICombatAI.take_turn(combat)
	else:
		var pol := WICombatPolicies.new(_policy)
		pol.items_by_id = _items_by_id
		pol.driven = {"pc": true}
		pol.carried = {"pc": []}
		while not combat.finished and guard < 2000:
			guard += 1
			pol.take_turn(combat)
	if not combat.finished:
		_fail("%s fight (seed %d) did not terminate" % [comp["name"], fight_seed])
		return false
	_entity = {"on_victory": comp["on_victory"]}
	var dormant: Array[String] = []
	_banking.resolve(combat, String(comp["name"]), dormant, classes, _frac)
	return bool(combat.outcome["victory"])


## --- WICombatBanking callable targets (local state) ---

func _mark_skill_used(skill_id: String) -> void:
	if skill_id == "" or _used_skills.has(skill_id):
		return
	_used_skills.append(skill_id)


func _find_entity(_id: String) -> Dictionary:
	return _entity


func _record(id: String, amount: int = 1) -> void:
	_acc[id] = int(_acc.get(id, 0)) + amount


func _count(id: String) -> int:
	return int(_acc.get(id, 0))


func _roll_loot_noop(_entity_arg: Dictionary) -> void:
	pass


func _remove_noop(_id: String) -> void:
	pass


## Mirror of WIGame.sleep()'s progression segment (see MIRROR CONTRACT).
func _sleep_resolve(classes: Dictionary, acc: Dictionary, catalog: Dictionary, generalists: Array, accept_policy: bool) -> void:
	for gained: Variant in WIProgression.check_class_gains(classes, acc, catalog):
		classes[String(gained)] = 1
	for up: Dictionary in WIProgression.check_level_ups(classes, acc, catalog):
		classes[String(up["class"])] = int(up["level"])
	var offer := WIProgression.check_consolidation(classes, catalog)
	if not offer.is_empty():
		if accept_policy:
			for parent: Variant in offer["parents"]:
				classes.erase(String(parent))
			classes[String(offer["target"])] = int(offer["level"])
		return
	for outcome: Dictionary in WIProgression.check_evolutions(classes, acc, catalog, generalists):
		if outcome.has("to"):
			classes[String(outcome["to"])] = int(outcome["level"])
			classes.erase(String(outcome["class"]))
		elif bool(outcome.get("generalist", false)):
			if not generalists.has(String(outcome["class"])):
				generalists.append(String(outcome["class"]))


func _total_levels(classes: Dictionary) -> int:
	var total := 0
	for held: Variant in classes.values():
		total += int(held)
	return total


## The act's authored loadout, or {} for the unequipped legacy archetypes.
func _act_loadout(arch: Dictionary, act_idx: int) -> Dictionary:
	var loadouts: Array = arch.get("loadout", [])
	if loadouts.is_empty():
		return {}
	return loadouts[mini(act_idx, loadouts.size() - 1)]


## "warrior5/mage4" — sorted so the same held set always prints the same label
## and the modal build is a real mode, not a Dictionary-order artefact.
func _build_label(classes: Dictionary) -> String:
	var ids: Array = classes.keys()
	ids.sort()
	var parts: Array[String] = []
	for id: Variant in ids:
		parts.append("%s%d" % [String(id), int(classes[id])])
	return "/".join(parts) if not parts.is_empty() else "(classless)"


func _modal_build(labels: Array) -> String:
	var counts := {}
	var best := ""
	var best_n := -1
	for l: Variant in labels:
		var key := String(l)
		counts[key] = int(counts.get(key, 0)) + 1
		if int(counts[key]) > best_n:
			best_n = int(counts[key])
			best = key
	return best


func _median_counter(snapshots: Array, counter: String) -> int:
	var vals: Array = []
	for s: Variant in snapshots:
		vals.append(int((s as Dictionary).get(counter, 0)))
	return _median(vals)


func _median(samples: Array) -> int:
	var s := samples.duplicate()
	s.sort()
	return int(s[s.size() / 2])


func _sorted(d: Dictionary) -> Dictionary:
	var out := {}
	var keys := d.keys()
	keys.sort()
	for k: Variant in keys:
		out[k] = d[k]
	return out


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())
