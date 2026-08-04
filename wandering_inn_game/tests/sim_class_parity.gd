extends SceneTree
## GH#360 (b) -- THE CROSS-CLASS PARITY LEG. Answers, with numbers, the question
## no other harness in this repo can: at the SAME total class level, how far
## apart are the classes?
##
## WHY THIS COULD NOT BE READ OFF sim_combat_batch.gd. That harness asserts a
## per-build win rate against a per-build ROSTER, and its own SECOND_WIND_CELLS
## comment says out loud that each L14 line needed a DIFFERENT roster to sit in
## 0.55-0.95 (swordsman fights three raskghar, sharpshooter fights two sewer
## vermin). Cell-selection tuning is the right tool for "is this fight shaped
## well", and it is exactly the wrong tool for "are these classes equal" -- it
## dissolves the spread it is meant to measure. This harness holds the roster
## fixed and lets the classes fall where they fall.
##
## MIRROR-MATCH CONTRACT (what "same except the class" means here):
##   * Same PC template, same seeds (1..RUNS_PER_CELL), same arena, same roster.
##   * Same armour (leather_jerkin) and NO accessories, on every build.
##   * Same weapon damage_mod -- 0 -- on every build. The weapon FAMILY still
##     varies, because a family is class identity, not gear: a bow line with a
##     sword has no kit at all (`WICombatBuild.weapon_gated_kit` strips it), so
##     forcing one weapon on everyone would measure the harness, not the class.
##   * SOLO. No ally, no companion, in the parity set -- an extra body is the
##     single largest confound in this sim, and the companion lines get their
##     own clearly-labelled context rows instead.
##
## WEAPON RANGE IS INERT UNDER AUTOPLAY -- MEASURED, NOT ASSUMED, AND THE FIRST
## AUTHORING OF THIS COMMENT GOT IT WRONG. `_build_pc` below threads
## `pc[WEAPON_RANGE]` because `wi_game.gd::_build_player_combatant` does
## (line 2099) and a mirror should mirror. It changes NOTHING, here or anywhere:
## every `combat.attack()` call site in `WICombatAI` is guarded by
## `combat.is_adjacent()` (combat_ai.gd:66/69/73, 106/108, 149/153), and
## `_act_ranged` never calls `attack` at all -- it only fires line/area/spell
## skills against their own effect ranges. `WICombat.in_weapon_range`
## (wi_combat.gd:179) is therefore only ever asked at adjacency, where it passes
## for every weapon. This file's own output is the proof: `archer10`
## (training_bow, range 4) and `rogue10` (rusty_sword, range 1) share
## stat_growth {dex: 1}, hold no AI-expressible skill, and print BYTE-IDENTICAL
## rows on all three rosters (0.74 / 0.34 / 0.00, mean 0.360).
##
## The version of this comment shipped on 2026-08-03 claimed the opposite --
## that threading the line was the difference between a parity read and "a lie",
## and that adding it to `sim_combat_batch.gd` would move `sharpshooter14_solo`
## and every other bow cell. Both halves were false and neither had been run.
## The line was applied to `sim_combat_batch.gd::_build_pc` in the fix round and
## moved 0 of 141 cells (full-matrix diff, byte-identical). The harnesses no
## longer diverge on this and there is no seam.
##
## SO: EVERY BOW ROW BELOW IS MEASURED WITH ARCHERY DELETED, and now says so in
## its own row with a RANGE-MUTE flag. This is the `ai_kit` confound wearing a
## second hat rather than a separate one -- both are fixed by an AI profile that
## can express bow damage, which does not exist (`_act_ranged` fires only
## int-based line/spell). Until it does, do not read a bow row as an archery
## read, and do not expect the WEAPON_RANGE field to change one.
##
## THE BIGGEST CONFOUND, MEASURED RATHER THAN HIDDEN -- `ai_kit`. Autoplay is
## `WICombatAI`, and its profiles can express only a SLICE of any kit: the melee
## profile selects exactly one named skill (`power_strike`) plus a windup, and
## the caster profile selects `line_damage`/`spell_damage`/`heal`/area. Nothing
## in either profile ever fires `sudden_strike`, `power_shot`, `called_shot`,
## `flanking_step` or any other verb, so a rogue/archer/tactician line fights as
## its bare stats no matter how large its kit is. That is a HARNESS property,
## not a class property, and reading these numbers as "class X is weak" without
## it would be wrong -- so every row prints `ai_kit=N/M`: N kit skills the AI can
## actually select, M combat-context skills the class holds. A row with N=0 is
## measuring stat growth and a basic attack, full stop.
## `_ai_expressible` MIRRORS `combat_ai.gd`'s selection arms; update it in the
## same commit that teaches a profile a new verb.
##
## REPORT-ONLY (harness-first, the #211 precedent). The only assertion is
## determinism: every fight terminates. Spread envelopes are proposed from the
## first read and ratified after the numbers are seen. `WI_PARITY_BAND=<n>`
## restricts the run to one band -- roster re-cutting is an iterative
## measurement and paying for all three bands per candidate is waste.
##
## THE STRATIFIED ENVELOPE (#384 item 2). The whole-band spread is NOT gateable
## and never was: it straddles the `ai_kit` confound above, so an envelope drawn
## over it gates AI COVERAGE, not class balance -- which is the opposite of what
## an envelope is for, and is exactly why v0.18's decline was accepted. The fix
## is to compare like with like: bucket every parity row by whether autoplay can
## fire ANY skill the class itself grants (`_ai_stratum`), and draw the envelope
## INSIDE each bucket. The bucket boundary is categorical, not a tuned threshold
## -- N=0 means the row is stat growth plus a basic attack, N>0 means the class's
## own kit is on the board at all -- so nothing here is a number somebody picked.
## A finer cut (by N/M share) was measured and rejected: it splits strata to n=1
## and n=2, where a "spread" is one build's distance to itself.
##
## `PROPOSED_ENVELOPE` is a REGRESSION FENCE, not an aspiration: each ceiling is
## the 2026-08-04 measured stratum spread plus MARGIN, so it reds when a data
## change MOVES a stratum and stays quiet when the stratum holds. Ceiling only --
## a shrinking spread is never a regression. Report-only by default (the #211/
## #360 precedent: gates propose after the numbers are seen);
## `WI_PARITY_ENVELOPE_GATE=1` makes a bust exit nonzero, which is the shape a
## merge train runs against a candidate branch.
##
## CENSORED STRATA GET NO ENVELOPE, by the same `_spread_verdict` rule the band
## line already obeys, and a stratum of fewer than two parity builds gets none
## either. Adding or removing a parity build CHANGES a stratum's membership and
## may legitimately bust its ceiling -- that is a re-read, not a bug: re-run,
## paste the numbers, and move the ceiling deliberately.
##
## WHAT THE FIRST STRATIFIED READ FOUND (2026-08-04). Splitting collapses band 10
## (0.617 -> 0.340 SPOKEN / 0.087 MUTE): at that band the whole apparent gap WAS
## the confound. It barely moves bands 14 and 18, and at band 14 the MUTE stratum
## is WIDER than the SPOKEN one -- spearmaster14 0.907 against infiltrator14 0.210,
## 0.698 apart with NEITHER class's kit on the board. Autoplay cannot explain that
## one: it is stat growth and weapon family alone, which is a real class-balance
## finding and the first this project has been able to state. Not this lane's to
## fix (that is data tuning, the split trigger), recorded so it is not re-derived.
##
## TOTAL LEVEL vs EFFECTIVE POWER: bands are TOTAL class level (the user's
## question is "Lv10 Mage vs Lv10 Warrior"), and the report prints
## `WIProgression.effective_power` beside it, because they are NOT the same
## number -- a 9/9 two-line build totals 18 and powers 14.1. The multiclass tax
## is a finding, not noise, so the generalist rows are in the parity set.

const RUNS_PER_CELL := 100

## Envelope buckets. CATEGORICAL, never a tuned threshold: MUTE = autoplay fires
## none of the skills this class itself grants (the row is stat growth + a basic
## attack); SPOKEN = it fires at least one. `_ai_stratum` is the only place the
## boundary exists.
const STRATUM_SPOKEN := "SPOKEN"
const STRATUM_MUTE := "MUTE"
const STRATA := [STRATUM_SPOKEN, STRATUM_MUTE]

## Ceiling = measured stratum spread + this. 0.10 is twice the tier report's own
## single-cell NOISE constant (0.05, ~1 sigma at 100 runs) and sits inside
## sim_combat_batch.gd's shipped 0.08-0.28 window-margin practice. A tighter
## fence is a flaky gate, not a proof.
const ENVELOPE_MARGIN := 0.10

## PROPOSED, drawn 2026-08-04 (#384 item 2) from the read pasted in this lane's
## report. Key "<band>/<stratum>"; ceiling = `measured` + ENVELOPE_MARGIN,
## rounded UP to 2dp so the fence never sits inside its own margin. `measured`
## is kept beside the ceiling so a re-draw is a visible diff instead of a silent
## one -- `ENVELOPE DRIFT` fires the moment the live spread stops matching it,
## which is the early warning that some data change moved a parity row.
## STRATA WITH NO ENTRY ARE UNGATED BY DESIGN -- censored, or n<2.
const PROPOSED_ENVELOPE := {
	"10/SPOKEN": {"ceiling": 0.44, "measured": 0.3400},
	"10/MUTE": {"ceiling": 0.19, "measured": 0.0867},
	"14/SPOKEN": {"ceiling": 0.63, "measured": 0.5275},
	"14/MUTE": {"ceiling": 0.80, "measured": 0.6975},
	"18/SPOKEN": {"ceiling": 0.73, "measured": 0.6250},
	"18/MUTE": {"ceiling": 0.47, "measured": 0.3625},
}

## damage_mod 0 in every family (items.json): the mirror-match's whole point.
const WEAPON_SWORD := "rusty_sword"
const WEAPON_SPEAR := "chipped_spear"
const WEAPON_BOW := "training_bow"
const PARITY_ARMOR := "leather_jerkin"

## Fixed per band, never per build. Chosen from SHIPPED rosters. Each band needs
## RESOLUTION at both ends: both saturations destroy the measurement -- a roster
## everyone wins flatters the weak lines to zero spread, and a roster everyone
## loses pins the table at 0.00 and reports a spread that is really just a floor.
##
## THAT RULE IS NOW MACHINE-CHECKED (`_spread_verdict`), because prose stating it
## did not stop two consecutive authorings from breaking it:
##   authoring 1  -- pinned 8 of 14 parity builds at exactly 0.000. Discarded.
##   authoring 2  (2026-08-03) -- re-cut easy/medium/hard, and STILL shipped
##     `scout18` at 0.00 / 0.00 / 0.00. Band 18's headline "spread 0.847" was
##     therefore the distance to a pinned floor, not a measured range: weakening
##     scout further could not have moved it, and re-cutting the roster would
##     have "improved" it with no class changing. Band 14's floor
##     (`infiltrator14`, 0.08 / 0.01 / 0.00) was saturated on two rosters of
##     three. The comment claimed the calibration was done; the numbers it
##     shipped with said otherwise.
##   authoring 3  (fix round) -- bands 14 and 18 gain a FLOOR-RESOLUTION roster
##     chosen so the WEAKEST parity line still has somewhere to be measured
##     (band 14 `sewer_vermin_pair`, band 18 `raider_vermin`), and the recap now
##     labels every band MEASURED or CENSORED from its own numbers. A CENSORED
##     band is not a balance finding and must never be quoted as one.
##     Effect, measured: band 14 floor `infiltrator14` 0.030 -> 0.210 (spread
##     0.960 -> 0.782), band 18 floor `scout18` 0.000 -> 0.070 (spread 0.847 ->
##     0.815). BOTH headline numbers SHRANK because the old ones were partly
##     roster, which is the whole point. Band 10 was left at three rosters: its
##     floor (`tactician10` 0.273, resolved at 0.82 on sewer_vermin_pair) always
##     satisfied the rule, so re-cutting it would only have moved a number that
##     was already measuring the classes.
##
## Verdict rule (`_spread_verdict`): a band is MEASURED only if BOTH endpoint
## builds respond to a change in their own class -- mean strictly inside (0,1)
## AND at least one roster strictly inside (0,1). An endpoint sitting on a rail
## is a censored statistic no matter how large the arithmetic difference is.
const BANDS := [
	{
		"band": 10,
		"rosters": [
			{"name": "sewer_vermin_pair", "arena": "goblin_ambush", "enemies": ["sewer_vermin", "sewer_vermin"]},
			{"name": "goblin_ambush", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"]},
			{"name": "chieftains_raid", "arena": "cave_mouth", "enemies": ["goblin_chieftain", "goblin_raider", "cave_spider"]},
		],
		"builds": [
			{"name": "warrior10", "classes": {"warrior": 10}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "mage10", "classes": {"mage": 10}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "rogue10", "classes": {"rogue": 10}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "archer10", "classes": {"archer": 10}, "ai": "melee", "weapon": WEAPON_BOW},
			{"name": "necromancer10", "classes": {"necromancer": 10}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "hedge_witch10", "classes": {"hedge_witch": 10}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "tactician10", "classes": {"tactician": 10}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "warrior5_mage5", "classes": {"warrior": 5, "mage": 5}, "ai": "melee", "weapon": WEAPON_SWORD},
			# CONTEXT ROWS (not in the spread). Non-combat lines and the
			# companion reads -- see `parity: false`'s own note in the report.
			{"name": "beast_tamer10", "classes": {"beast_tamer": 10}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
			{"name": "beast_tamer10_wolf", "classes": {"beast_tamer": 10}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false, "companion": "wolf_companion"},
			{"name": "helper10", "classes": {"helper": 10}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
			{"name": "mixer10", "classes": {"mixer": 10}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
			{"name": "classless", "classes": {}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
		],
	},
	{
		"band": 14,
		"rosters": [
			{"name": "sewer_vermin_pair", "arena": "goblin_ambush", "enemies": ["sewer_vermin", "sewer_vermin"]},
			{"name": "raider_vermin", "arena": "goblin_ambush", "enemies": ["goblin_raider", "sewer_vermin"]},
			{"name": "raskghar_pair", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"]},
			{"name": "raskghar_scouts", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout", "raskghar_scout"]},
		],
		"builds": [
			{"name": "swordsman14", "classes": {"swordsman": 14}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "spearmaster14", "classes": {"spearmaster": 14}, "ai": "melee", "weapon": WEAPON_SPEAR},
			{"name": "ice_mage14", "classes": {"ice_mage": 14}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "fire_mage14", "classes": {"fire_mage": 14}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "sharpshooter14", "classes": {"sharpshooter": 14}, "ai": "melee", "weapon": WEAPON_BOW},
			{"name": "infiltrator14", "classes": {"infiltrator": 14}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "witch14", "classes": {"witch": 14}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "strategist14", "classes": {"strategist": 14}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "spellsword14", "classes": {"spellsword": 14}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "ranger14", "classes": {"ranger": 14}, "ai": "melee", "weapon": WEAPON_BOW},
			{"name": "scout14", "classes": {"scout": 14}, "ai": "melee", "weapon": WEAPON_BOW},
			{"name": "druid14", "classes": {"druid": 14}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "necromancer12_mage2", "classes": {"necromancer": 12, "mage": 2}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "warrior7_mage7", "classes": {"warrior": 7, "mage": 7}, "ai": "melee", "weapon": WEAPON_SWORD},
			# CONTEXT ROWS
			{"name": "beast_master14", "classes": {"beast_master": 14}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
			{"name": "beast_master14_wolf", "classes": {"beast_master": 14}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false, "companion": "wolf_companion"},
			{"name": "druid14_wolf", "classes": {"druid": 14}, "ai": "caster", "weapon": WEAPON_SWORD, "parity": false, "companion": "wolf_companion"},
			{"name": "alchemist14", "classes": {"alchemist": 14}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
			{"name": "innkeeper14", "classes": {"innkeeper": 14}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
			{"name": "courier14", "classes": {"courier": 14}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
		],
	},
	{
		"band": 18,
		"rosters": [
			{"name": "raider_vermin", "arena": "goblin_ambush", "enemies": ["goblin_raider", "sewer_vermin"]},
			{"name": "raskghar_scouts", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout", "raskghar_scout"]},
			{"name": "briar_collectors", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"]},
			{"name": "forge_golem", "arena": "forge_hall", "enemies": ["forge_golem"]},
		],
		"builds": [
			{"name": "spellsword18", "classes": {"spellsword": 18}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "ranger18", "classes": {"ranger": 18}, "ai": "melee", "weapon": WEAPON_BOW},
			{"name": "scout18", "classes": {"scout": 18}, "ai": "melee", "weapon": WEAPON_BOW},
			{"name": "druid18", "classes": {"druid": 18}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "ice_mage16_warrior2", "classes": {"ice_mage": 16, "warrior": 2}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "swordsman16_mage2", "classes": {"swordsman": 16, "mage": 2}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "warrior9_mage9", "classes": {"warrior": 9, "mage": 9}, "ai": "melee", "weapon": WEAPON_SWORD},
			# CONTEXT ROWS
			{"name": "druid18_wolf", "classes": {"druid": 18}, "ai": "caster", "weapon": WEAPON_SWORD, "parity": false, "companion": "wolf_companion"},
			{"name": "beast_master16_mage2", "classes": {"beast_master": 16, "mage": 2}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
		],
	},
]


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Mirrors `wi_game.gd::_build_player_combatant` (NOT sim_combat_batch.gd's
## `_build_pc`, which omits WEAPON_RANGE -- see the head comment).
func _build_pc(build: Dictionary, pc_template: Dictionary, classes_catalog: Dictionary,
		skills_by_id: Dictionary, items_by_id: Dictionary) -> Dictionary:
	var pc: Dictionary = pc_template.duplicate(true)
	pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
	pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes_catalog)
	var kit: Array = WIProgression.granted_skills(build["classes"], classes_catalog)
	var weapon: Dictionary = items_by_id.get(String(build[WIKeys.WEAPON]), {})
	var armor: Dictionary = items_by_id.get(PARITY_ARMOR, {})
	pc[WIKeys.SKILLS] = WICombatBuild.weapon_gated_kit(kit, String(weapon.get("weapon_family", "")), skills_by_id)
	pc[WIKeys.WEAPON_RANGE] = int(weapon.get(WIKeys.RANGE, 1))
	# GH#165 mirror: a fielded companion + the passive folds the PC-side boon in.
	if String(build.get("companion", "")) != "" and (pc[WIKeys.SKILLS] as Array).has("sworn_fang_ride_together"):
		var pcs: Array = (pc[WIKeys.SKILLS] as Array).duplicate()
		pcs.append("sworn_fang_boon")
		pc[WIKeys.SKILLS] = pcs
	var mods: Dictionary = WICombatBuild.equipment_mods(weapon, armor, [])
	pc[WIKeys.DAMAGE_MOD] = mods[WIKeys.DAMAGE_MOD]
	pc[WIKeys.HP_MOD] = mods[WIKeys.HP_MOD]
	pc[WIKeys.DAMAGE_REDUCTION] = mods[WIKeys.DAMAGE_REDUCTION]
	return pc


func _companion_cfg(build: Dictionary, by_id: Dictionary, pc_skills: Array) -> Dictionary:
	var cfg: Dictionary = (by_id[String(build["companion"])] as Dictionary).duplicate(true)
	var boons: Array = []
	if pc_skills.has("animals_basic_command"):
		boons.append("basic_command_boon")
	if pc_skills.has("pack_bond"):
		boons.append("pack_bond_boon")
	if not boons.is_empty():
		var comp_skills: Array = (cfg.get(WIKeys.SKILLS, []) as Array).duplicate()
		comp_skills.append_array(boons)
		cfg[WIKeys.SKILLS] = comp_skills
	return cfg


## MIRROR CONTRACT with `combat_ai.gd`. Returns [expressible, combat_context]:
## how many of this build's skills autoplay can actually SELECT, and how many
## combat-context skills it holds at all. Keep in step with the profiles:
##   melee/skirmisher/guard/coward -> `power_strike` by literal id, plus a
##     `windup_cadence` holder (`_windup_skill_id`).
##   caster/ranged -> the first `line_damage` and the first `spell_damage`,
##     the area arm (`icy_floor`/`blast_damage`), and a `heal`.
## Nothing else in either profile fires a skill, which is why a kit full of
## `damage_mult`/`sneak`/positioning verbs reads as bare stats here.
func _ai_expressible(kit: Array, ai: String, skills_by_id: Dictionary) -> Array:
	var caster := ai == "caster" or ai == "ranged"
	var expressible := {}
	var combat_ctx := 0
	for raw: Variant in kit:
		var sk_id := String(raw)
		var s: Dictionary = skills_by_id.get(sk_id, {})
		if (s.get("contexts", []) as Array).has("combat"):
			combat_ctx += 1
		var effect_type := String((s.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.TYPE, ""))
		if not caster:
			if sk_id == "power_strike" or s.has("windup_cadence"):
				expressible[sk_id] = true
		else:
			if effect_type in ["line_damage", "spell_damage", "heal", "icy_floor", "blast_damage"]:
				expressible[sk_id] = true
	return [expressible.size(), combat_ctx]


func _total_level(classes: Dictionary) -> int:
	var total := 0
	for held: Variant in classes.values():
		total += int(held)
	return total


## How many of this build's rosters sat on a rail (exactly 0.00 or exactly
## 1.00). A rail cell cannot report a change in the class that fought it, so a
## row's `sat` count is how much of its mean is unmeasured.
func _sat_count(per_roster: Array) -> int:
	var n := 0
	for v: float in per_roster:
		if v <= 0.0 or v >= 1.0:
			n += 1
	return n


## The CENSORING CHECK the recap line is not allowed to skip. `stats` maps a
## build name to [mean, per_roster]. A spread is only a spread if BOTH of its
## endpoints would move when their class moves; an endpoint whose mean is on a
## rail, or whose every roster is on a rail, is measuring the roster instead.
## Returns [is_measured, reason].
func _spread_verdict(stats: Dictionary, lo_name: String, hi_name: String) -> Array:
	var reasons: Array = []
	for pair: Array in [[lo_name, "floor"], [hi_name, "ceiling"]]:
		var nm := String(pair[0])
		var role := String(pair[1])
		if not stats.has(nm):
			continue
		var mean: float = (stats[nm] as Array)[0]
		var per_roster: Array = (stats[nm] as Array)[1]
		var sat := _sat_count(per_roster)
		if mean <= 0.0 or mean >= 1.0:
			reasons.append("%s %s pinned at %.3f (%d/%d rosters on a rail)" % [
				role, nm, mean, sat, per_roster.size(),
			])
		elif sat >= per_roster.size():
			reasons.append("%s %s has no unsaturated roster (%d/%d on a rail)" % [
				role, nm, sat, per_roster.size(),
			])
	return [reasons.is_empty(), ", ".join(reasons)]


## The envelope's ONLY bucket boundary. `n` is `_ai_expressible`'s first element.
func _ai_stratum(n_expressible: int) -> String:
	return STRATUM_SPOKEN if n_expressible > 0 else STRATUM_MUTE


## One stratum's spread, censoring rule included. `stats` maps build name ->
## [mean, per_roster] and `members` is the subset of names in this bucket.
## Returns [n, spread, lo_name, lo, hi_name, hi, measured, reason].
## n < 2 is NOT a spread and is reported as such -- one build's distance to
## itself is zero and would ratify a ceiling that can never fire.
func _stratum_spread(stats: Dictionary, members: Array) -> Array:
	if members.size() < 2:
		return [members.size(), 0.0, "", 0.0, "", 0.0, false, "n<2 -- not a spread"]
	var lo := 2.0
	var hi := -1.0
	var lo_name := ""
	var hi_name := ""
	var subset := {}
	for nm: String in members:
		var v: float = (stats[nm] as Array)[0]
		subset[nm] = stats[nm]
		if v < lo:
			lo = v
			lo_name = nm
		if v > hi:
			hi = v
			hi_name = nm
	var verdict: Array = _spread_verdict(subset, lo_name, hi_name)
	return [members.size(), hi - lo, lo_name, lo, hi_name, hi, bool(verdict[0]), String(verdict[1])]


func _init() -> void:
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
	var total_cells := 0
	var band_spreads: Array = []
	var band_ai_split: Array = []
	var envelope_rows: Array = []

	print("=".repeat(78))
	print("GH#360 (b) CROSS-CLASS PARITY -- fixed rosters, mirror-matched gear, %d seeded runs/cell" % RUNS_PER_CELL)
	print("gear held constant: armour %s, no accessories, weapon damage_mod 0 in every family" % PARITY_ARMOR)
	print("=".repeat(78))

	# Roster re-cutting is iterative; paying for all three bands per candidate is
	# waste. Unset = every band, which is the only shape CI/AGENTS.md ever runs.
	var band_env := OS.get_environment("WI_PARITY_BAND")
	var only_band := int(band_env) if band_env != "" else -1

	for band_cfg: Dictionary in BANDS:
		var band := int(band_cfg["band"])
		if only_band >= 0 and band != only_band:
			continue
		var rosters: Array = band_cfg["rosters"]
		var builds: Array = band_cfg["builds"]
		var roster_names: Array = []
		for r: Dictionary in rosters:
			roster_names.append(String(r["name"]))
		print("")
		print("-".repeat(78))
		print("BAND %d  (total class level %d)   rosters: %s" % [band, band, ", ".join(roster_names)])
		print("-".repeat(78))

		var parity_means := {}
		var all_means := {}
		var parity_stats := {}
		var stratum_of := {}
		var expressive_means: Array = []
		var mute_means: Array = []
		for build: Dictionary in builds:
			var per_roster: Array = []
			var per_roster_median: Array = []
			for roster: Dictionary in rosters:
				var arena: Dictionary = arenas_by_id[String(roster["arena"])]
				var wins := 0
				var rounds: Array[int] = []
				for seed_v in range(1, RUNS_PER_CELL + 1):
					var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
					var cfgs: Array = [pc]
					if String(build.get("companion", "")) != "":
						cfgs.append(_companion_cfg(build, by_id, pc[WIKeys.SKILLS] as Array))
					for enemy_id: String in roster["enemies"]:
						cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
					var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
					combat.begin()
					var guard := 0
					while not combat.finished and guard < 2000:
						guard += 1
						WICombatAI.take_turn(combat)
					assert(combat.finished, "parity %s/%s/%s fight %d did not terminate" % [
						band, build["name"], roster["name"], seed_v,
					])
					if combat.outcome["victory"]:
						wins += 1
					rounds.append(int(combat.outcome["rounds"]))
				rounds.sort()
				per_roster.append(float(wins) / float(RUNS_PER_CELL))
				per_roster_median.append(rounds[RUNS_PER_CELL / 2])
				total_cells += 1

			var mean := 0.0
			for v: float in per_roster:
				mean += v
			mean /= float(per_roster.size())
			var is_parity := bool(build.get("parity", true))
			var classes_dict: Dictionary = build["classes"]
			var power: float = WIProgression.effective_power(classes_dict, classes)
			all_means[String(build["name"])] = mean
			if is_parity:
				parity_means[String(build["name"])] = mean
				parity_stats[String(build["name"])] = [mean, per_roster]
			var cells: Array = []
			for i in range(per_roster.size()):
				cells.append("%s %.2f[%d]" % [String((rosters[i] as Dictionary)["name"]), per_roster[i], int(per_roster_median[i])])
			var probe_pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			var ai_kit: Array = _ai_expressible(probe_pc[WIKeys.SKILLS] as Array, String(probe_pc[WIKeys.AI]), skills_by_id)
			if is_parity:
				stratum_of[String(build["name"])] = _ai_stratum(int(ai_kit[0]))
				if int(ai_kit[0]) > 0:
					expressive_means.append(mean)
				else:
					mute_means.append(mean)
			# RANGE-MUTE: this build carries a reach weapon and autoplay will
			# never use the reach (see the head comment's proof). The row is a
			# melee read of a ranged class, and must not be quoted otherwise.
			var row_weapon: Dictionary = items_by_id.get(String(build[WIKeys.WEAPON]), {})
			var range_mute := int(row_weapon.get(WIKeys.RANGE, 1)) > 1
			print("  %s %-22s lv%2d pow%5.1f ai_kit%2d/%-2d sat%d/%-2d %s mean %.3f   %s" % [
				" " if is_parity else "~", String(build["name"]), _total_level(classes_dict), power,
				int(ai_kit[0]), int(ai_kit[1]), _sat_count(per_roster), per_roster.size(),
				"RANGE-MUTE" if range_mute else "          ", mean, "  ".join(cells),
			])

		var lo := 2.0
		var hi := -1.0
		var lo_name := ""
		var hi_name := ""
		for name: String in parity_means:
			var v: float = parity_means[name]
			if v < lo:
				lo = v
				lo_name = name
			if v > hi:
				hi = v
				hi_name = name
		var exp_mean := 0.0
		for v: float in expressive_means:
			exp_mean += v
		exp_mean /= maxf(1.0, float(expressive_means.size()))
		var mute_mean := 0.0
		for v: float in mute_means:
			mute_mean += v
		mute_mean /= maxf(1.0, float(mute_means.size()))
		var verdict: Array = _spread_verdict(parity_stats, lo_name, hi_name)
		var measured := bool(verdict[0])
		band_spreads.append([band, hi - lo, lo_name, lo, hi_name, hi, parity_means.size(), measured, String(verdict[1])])
		band_ai_split.append([band, expressive_means.size(), exp_mean, mute_means.size(), mute_mean])
		print("  ---")
		print("  PARITY SPREAD band %d: %.3f  (%s %.3f  ...  %s %.3f) over %d parity builds" % [
			band, hi - lo, lo_name, lo, hi_name, hi, parity_means.size(),
		])
		if measured:
			print("  SPREAD VERDICT band %d: MEASURED -- both endpoints respond to their own class." % band)
		else:
			print("  SPREAD VERDICT band %d: CENSORED -- %s." % [band, String(verdict[1])])
			print("  The number above is a distance to a rail, NOT a class-balance delta. Do not")
			print("  quote it, and do not gate on it: re-cutting the roster would move it with no")
			print("  class changing. Give the endpoint a roster it can be measured on first.")
		print("  AI-EXPRESSIBLE SPLIT band %d: ai_kit>0 n=%d mean %.3f   |   ai_kit=0 n=%d mean %.3f" % [
			band, expressive_means.size(), exp_mean, mute_means.size(), mute_mean,
		])
		print("  (rows marked ~ are CONTEXT: non-combat lines, or a fielded companion adding a body")
		print("   no other row has. They are printed, never counted in the spread.)")
		print("  (ai_kit N/M: N skills autoplay can select of M combat-context skills held. N=0")
		print("   means the row measures stat growth + a basic attack, not the class's design.)")
		print("  (sat K/N: rosters where this row sat on a rail -- exactly 0.00 or 1.00. A rail")
		print("   cell reports the roster, not the class. RANGE-MUTE: reach weapon, unusable AI.)")

		# #384 item 2 -- the SAME spread arithmetic, inside each ai_kit bucket.
		# This is the only number on this page that is a class-balance read: the
		# band line above it straddles the confound and never was one.
		print("  --- STRATIFIED ENVELOPE (#384 item 2): the spread with the ai_kit confound held fixed")
		for stratum: String in STRATA:
			var members: Array = []
			for nm: String in parity_means:
				if String(stratum_of[nm]) == stratum:
					members.append(nm)
			var st: Array = _stratum_spread(parity_stats, members)
			var key := "%d/%s" % [band, stratum]
			if not bool(st[6]):
				print("    %-6s n=%-2d NO ENVELOPE -- %s" % [stratum, int(st[0]), String(st[7])])
				envelope_rows.append([band, stratum, int(st[0]), float(st[1]), false, false, "", ""])
				continue
			print("    %-6s n=%-2d spread %.3f  MEASURED   floor %s %.3f  ...  ceiling %s %.3f" % [
				stratum, int(st[0]), float(st[1]), String(st[2]), float(st[3]), String(st[4]), float(st[5]),
			])
			if not PROPOSED_ENVELOPE.has(key):
				print("           no proposed ceiling for %s -- this stratum is new or was censored when the envelope was drawn; re-draw it deliberately" % key)
				envelope_rows.append([band, stratum, int(st[0]), float(st[1]), true, false, "", ""])
				continue
			var entry: Dictionary = PROPOSED_ENVELOPE[key]
			var ceiling: float = float(entry["ceiling"])
			var drawn_from: float = float(entry["measured"])
			var busted := float(st[1]) > ceiling
			print("           envelope ceiling %.2f (drawn from %.3f + margin %.2f) -> %s by %.3f" % [
				ceiling, drawn_from, ENVELOPE_MARGIN,
				"OVER" if busted else "WITHIN", absf(ceiling - float(st[1])),
			])
			if absf(float(st[1]) - drawn_from) > 0.0005:
				print("           ENVELOPE DRIFT: live spread %.3f != the %.3f this ceiling was drawn from." % [float(st[1]), drawn_from])
				print("           Something moved a parity row. Read WHAT moved before re-drawing the ceiling.")
			envelope_rows.append([band, stratum, int(st[0]), float(st[1]), true, true, ceiling, drawn_from])
		print("    (bucket = does autoplay fire ANY skill this class grants. SPOKEN yes, MUTE no.")
		print("     Comparing a MUTE row to a SPOKEN one measures the harness; comparing two rows")
		print("     inside one bucket measures the classes. That is the whole point of the split.)")

	print("")
	print("=".repeat(78))
	print("RECAP -- max spread per band (this is the number #360 asks to gate)")
	var censored := 0
	for row: Array in band_spreads:
		print("  band %2d  spread %.3f  %s   floor %s %.3f   ceiling %s %.3f   (n=%d)" % [
			int(row[0]), float(row[1]), "MEASURED" if bool(row[7]) else "CENSORED",
			String(row[2]), float(row[3]), String(row[4]), float(row[5]), int(row[6]),
		])
		if not bool(row[7]):
			censored += 1
			print("            ^ CENSORED: %s -- not a balance finding, not gateable." % String(row[8]))
	if censored > 0:
		print("  %d of %d bands are CENSORED. A censored spread is an artifact of its roster;" % [censored, band_spreads.size()])
		print("  fix the roster before anyone ratifies an envelope off this table.")
	print("")
	print("RECAP -- the confound, quantified: does autoplay speak the class's kit?")
	for row: Array in band_ai_split:
		print("  band %2d  ai_kit>0: n=%d mean %.3f   |   ai_kit=0: n=%d mean %.3f   gap %+.3f" % [
			int(row[0]), int(row[1]), float(row[2]), int(row[3]), float(row[4]), float(row[2]) - float(row[4]),
		])
	print("")
	print("RECAP -- THE STRATIFIED ENVELOPE (#384 item 2): the project's class-balance gate")
	var gate_on := OS.get_environment("WI_PARITY_ENVELOPE_GATE") == "1"
	var busts: Array = []
	var ungated := 0
	for row: Array in envelope_rows:
		if not bool(row[5]):
			ungated += 1
			print("  band %2d %-6s n=%-2d spread %.3f   UNGATED (%s)" % [
				int(row[0]), String(row[1]), int(row[2]), float(row[3]),
				"measured, no ceiling drawn yet" if bool(row[4]) else "censored or n<2",
			])
			continue
		var over: bool = float(row[3]) > float(row[6])
		if over:
			busts.append(row)
		print("  band %2d %-6s n=%-2d spread %.3f   ceiling %.2f   %s" % [
			int(row[0]), String(row[1]), int(row[2]), float(row[3]), float(row[6]),
			"OVER  <-- BUST" if over else "WITHIN",
		])
	if ungated > 0:
		print("  %d stratum row(s) carry no ceiling. An UNGATED stratum is not covered by anything;" % ungated)
		print("  it is not a pass. Censored strata need a floor-resolution roster before they can be.")
	print("")
	if busts.is_empty():
		print("ENVELOPE: every gateable stratum is inside its ceiling.")
	else:
		print("ENVELOPE: %d stratum row(s) BUST their ceiling." % busts.size())
		for row: Array in busts:
			print("  band %d %s: spread %.3f > ceiling %.2f (drawn from %.3f). Read what moved --" % [
				int(row[0]), String(row[1]), float(row[3]), float(row[6]), float(row[7]),
			])
			print("  a bust is a class getting further from its stratum-mates, not a harness fault.")
	if gate_on:
		if busts.is_empty():
			print("PASS: class-parity harness terminated cleanly over %d cells x %d seeded runs; envelope GATE ON, no busts" % [total_cells, RUNS_PER_CELL])
			quit(0)
		else:
			print("FAIL: WI_PARITY_ENVELOPE_GATE=1 and %d stratum row(s) are over ceiling" % busts.size())
			quit(1)
		return
	print("REPORT-ONLY by default (#360/#211 harness-first): the envelope above PROPOSES, it does")
	print("not fail the run. WI_PARITY_ENVELOPE_GATE=1 makes a bust exit nonzero -- that is the")
	print("shape a merge train runs against a candidate branch.")
	print("PASS: class-parity harness terminated cleanly over %d cells x %d seeded runs" % [total_cells, RUNS_PER_CELL])
	quit(0)
