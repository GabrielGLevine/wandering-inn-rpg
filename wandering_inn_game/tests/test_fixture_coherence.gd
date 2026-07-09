extends SceneTree
## Fixture coherence validator (issue #48, playtest directive item 9): a
## playtest state must be a story position a real playthrough could
## actually reach -- not merely internally consistent enough to boot. Loads
## every playtest-facing fixture through the REAL WISave.apply() path (never
## hand-reads the JSON) so it sees exactly what a title-screen Continue load
## sees, then asserts STORY-POSITION invariants over the resulting WIGame.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_fixture_coherence.gd
##
## SCOPING NOTE (read before extending): two tiers of rigor.
##   GATE_FIXTURES (the door-chain septet + near_garden + near_riverfarm +
##   garden_unlocked -- the fixtures with ledger-derived positions) get the
##   FULL invariant set: exact documented gold floors, the act-III
##   equipment-tier check, and (where the fixture's own canonical resolves a
##   fight) the tuning-band check. Every OTHER checked fixture gets the
##   GENERAL invariants only (identity, monotone chains, tutorial cleanup,
##   position plausibility, rng_state non-degeneracy, equipped-weapon-in-
##   inventory). Extending full rigor repo-wide is real future work -- see
##   docs/design/fixture-position-ledger.md's own closing note for the known
##   gold-floor gaps deliberately left open pending their own re-verification
##   passes.

const FIXTURES_DIR := "res://qa/fixtures"

## Mirrors src/ui/title_screen.gd's exclusion list (that script cannot be
## preloaded here -- it pulls the whole autoload graph in via bare global
## identifiers like WIEvents/WIDataRegistry, unresolvable under --script
## mode per CLAUDE.md's own documented gotcha). KEEP IN SYNC with
## title_screen.gd's own doc comment on PLAYTEST_FIXTURE_ORDER the same way
## qa/ci_sweep.sh's CANON array tracks qa/manifest.json.
const SKIP := {
	"v1_format": "pre-v2 save format, deliberately REJECTED by WISave.apply (test_save.gd's own migration-rejection proof) -- not a loadable story position at all",
	"v2_format": "pre-v3 migration INPUT (consumed by _migrated(), never applied verbatim) -- not itself a playtest destination",
	"dp2_fixwave_absolute_start": "a deliberately MID-ANOMALY soft-lock repro (found_spider_silk banked before its posting was ever accepted), explicitly 'NOT registered in qa/manifest.json' per its own _comment -- its incoherence IS its subject",
}

## The full-rigor set: the door-chain septet + the two Garden-access
## fixtures, each with a ledger-derived position (docs/design/
## fixture-position-ledger.md is the authoring source for these).
const GATE_FIXTURES := [
	"door_chain_talk_start", "door_chain_scout_start", "door_chain_fight_start",
	"door_awakening_start", "portal_menu_start", "near_garden", "near_riverfarm",
	"garden_unlocked",
]

## Fixtures whose OWN canonical resolves a fight to completion FROM this
## exact loaded state (not merely "carries combat classes") -- the only
## ones the combat-readiness invariant's numeric band applies to. Every
## other checked fixture either never fights, or fights via a documented
## alternate leg that bypasses combat entirely (see each fixture's own
## _comment). Value = the EXACT total held class levels of the harness
## build the fixture's fights were tuned/measured at, enforced in BOTH
## directions -- an under-leveled PC can lose a tuned-winnable fight, an
## over-leveled one silently invalidates the measured band the other way:
##   door_chain_fight_start / riverfarm_fight_start / near_invrisil_fight:
##     `warrior5_mage5` (10 total levels, split-efficiency ~0.78 --
##     sim_combat_batch.gd's tuned band for rift_vermin_leak/ruin_guardian,
##     the briar/wolf cells, and (near_invrisil_fight) the
##     `hired_blades_w10_wilovan` ally-fielded cell).
##   near_invrisil: warrior2 (the alley_footpads gated 0.75-0.98 cell was
##     measured at "warrior2 SOLO specifically" per combatants.json + the
##     fixture's own _comment -- the same lock that exempts it from the
##     post_game-backbone check, now enforced instead of prose-only).
const COMBAT_BAND_FIXTURES := {
	"door_chain_fight_start": 10,
	"riverfarm_fight_start": 10,
	"near_invrisil": 2,
	"near_invrisil_fight": 10,
}

## Region-entry gates, DERIVED from data/skeleton_scene.json's own
## door_when/on_enter_accomplishment records and data/portals.json's
## requires_accomplishment column (grepped by hand at authoring time --
## see docs/design/fixture-position-ledger.md for the derivation trace).
## A fixture standing on map M must hold EVERY accomplishment listed here
## for M (empty/absent = no gate, e.g. inn/floodplains/inn_upstairs, which
## are either the two start maps or gated by nothing but reaching their own
## already-checked neighbor). The portal-gated regions additionally require
## `door_awakened` (the portal MENU's own gate, prerequisite to reaching any
## anchor destination at all) alongside their region-specific `_attuned` flag.
const MAP_REQUIRES := {
	"street": ["reached_liscor"],
	"guild": ["reached_liscor"],
	"barracks": ["reached_liscor"],
	"runners_guild": ["reached_liscor"],
	"sewers": ["reached_liscor", "heard_about_cisterns"],
	"deep_tunnels": ["reached_liscor", "heard_about_cisterns", "heard_the_deep_tremor"],
	"ruin_surface": ["door_chain_started"],
	"garden_sanctuary": ["garden_door_unlocked"],
	"riverfarm_village": ["door_awakened", "riverfarm_attuned"],
	"witch_hollow": ["door_awakened", "riverfarm_attuned"],
	"invrisil_boulevard": ["door_awakened", "invrisil_attuned"],
	"mercantile_alleys": ["door_awakened", "invrisil_attuned"],
	"brothers_parlor": ["door_awakened", "invrisil_attuned"],
}

## Any of these present ⇒ the tutorial (spar -> sleep -> class_gained ->
## gift) has definitely already happened, per the real onboarding sequence
## (relc_tutorial/tutorial_flow's own shipped order: given_spear_by_relc
## fires only AFTER the class-granting sleep). classes == {} at that point
## is exactly the "Riverfarm with zero classes" bug class the user's
## directive named.
const POST_TUTORIAL_FLAGS := ["given_spear_by_relc", "reached_liscor", "post_game", "door_chain_started"]

## The full Act-II/III backbone `post_game` structurally implies (it is the
## Act III beat's own `seal_holds` condition, data/acts.json) -- every one of
## these must already be banked wherever `post_game` is. Documented in full
## in docs/design/fixture-position-ledger.md's "post_game backbone" section.
const POST_GAME_BACKBONE := [
	"reached_liscor", "reached_two_classes", "met_relc", "sparred_with_relc", "given_spear_by_relc",
	"watch_runner_pointed", "heard_the_deep_tremor", "heard_olesm_briefing", "cleared_the_warren", "raskghar_sealed",
]

## near_invrisil's own _comment LOCKS `classes: {warrior: 2}` to the
## alley_footpads roster's gated 0.75-0.98 win-rate baseline, "measured at
## warrior2 SOLO specifically" -- enriching it to the full post_game
## backbone (reached_two_classes needs a SECOND class) would shift that
## already-tuned sneak-negative fight's win rate off the measured band.
## CONSTRAINT: closing this exemption requires a combat-tuning pass
## (re-measure the alley_footpads band at the enriched build), never a
## bare fixture-data edit; the COMBAT_BAND_FIXTURES exact-match check below
## enforces the same lock from the other direction.
const POST_GAME_BACKBONE_EXEMPT := {
	"near_invrisil": "classes locked to the alley_footpads combat-tuning baseline; see const's own doc comment",
}

var _errors: Array[String] = []
var _checked := 0


func _init() -> void:
	WITestWatchdog.arm(self)
	var combat_config := _combat_config()
	var scene: Dictionary = _load_json("res://data/skeleton_scene.json")
	var skills: Dictionary = _load_json("res://data/skills.json")

	var names := _fixture_names()
	print("test_fixture_coherence: checking %d fixtures (%d skipped)" % [names.size(), SKIP.size()])
	for name: String in names:
		_checked += 1
		var raw := FileAccess.get_file_as_string("%s/%s.json" % [FIXTURES_DIR, name])
		var data: Variant = JSON.parse_string(raw)
		if not (data is Dictionary):
			_fail(name, "fixture file is not valid JSON")
			continue
		var game := WIGame.new(scene, skills, _sink, 9, combat_config)
		if not WISave.apply(game, data as Dictionary):
			_fail(name, "WISave.apply REJECTED this fixture -- malformed save shape")
			continue
		_check_identity(name, game)
		_check_post_tutorial(name, game, data as Dictionary)
		_check_monotone_chains(name, game)
		_check_position_plausibility(name, game)
		_check_economy(name, game)
		_check_combat_band(name, game)
		_check_equipment(name, game)
		_check_rng_state(name, data as Dictionary)

	if _errors.is_empty():
		# CONTRACT: every suite's success line must start with "PASS" — CI's
		# unit gate greps ^PASS and fails the job without it (bit v0.4.0's
		# first tag: 50/50 green here, job red there).
		print("PASS: fixture coherence — %d/%d fixtures are reachable story positions" % [_checked, _checked])
	else:
		print("test_fixture_coherence: %d failures across %d fixtures:" % [_errors.size(), _checked])
		for e: String in _errors:
			print("  FIXTURE_COHERENCE_FAIL " + e)
	assert(_errors.is_empty(), "%d fixture coherence failures:\n%s" % [_errors.size(), "\n".join(_errors)])
	quit()


func _fail(name: String, msg: String) -> void:
	var line := "%s: %s" % [name, msg]
	_errors.append(line)
	print("FIXTURE_COHERENCE_FAIL " + line)


func _sink(_type: String, _payload: Dictionary) -> void:
	pass


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


## Real catalogs (not test_save.gd's minimal stand-ins) so `known_skills()`/
## `act_summary()`/`_quests_completed_count()` all resolve for real --
## this validator is asking "is this a real reachable position", which
## needs the real class/quest/act data, not a hand-built stub.
func _combat_config() -> Dictionary:
	return {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"dialogue": {},
		"quests": _load_json("res://data/quests.json"),
		"acts": _load_json("res://data/acts.json"),
		"items": _load_json("res://data/items.json"),
	}


## Every qa/fixtures/*.json basename minus SKIP, sorted -- this IS "every
## fixture named in PLAYTEST_FIXTURE_ORDER (+ near_riverfarm and any
## playtest-facing fixture)" (the title screen's raw-dirlist fallback
## surfaces every file here regardless of curation, so checking the whole
## directory minus the documented skip list is equivalent and driftproof).
func _fixture_names() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(FIXTURES_DIR)
	assert(dir != null, "qa/fixtures directory must exist")
	for f: String in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var base := f.get_basename()
		if not SKIP.has(base):
			out.append(base)
	out.sort()
	return out


## identity: pc_name/pc_race/pc_gender/pc_sprite present + consistent.
## Always true by construction (WIGame's own tolerant sanitizers + the
## pc_sprite_variant() derivation can never disagree with pc_race/pc_gender)
## -- kept as a real regression guard, not a no-op: a future sanitizer bug
## that let pc_race/pc_gender drift from PC_RACES/PC_GENDERS would show up
## here as a sprite key that doesn't match "pc_<race>_<gender>".
func _check_identity(name: String, game: WIGame) -> void:
	if game.pc_name.strip_edges() == "":
		_fail(name, "pc_name is blank")
	if game.pc_race == "":
		_fail(name, "pc_race is blank")
	if game.pc_gender == "":
		_fail(name, "pc_gender is blank")
	var expect_sprite := "pc_%s_%s" % [game.pc_race, game.pc_gender]
	if game.pc_sprite_variant() != expect_sprite:
		_fail(name, "pc_sprite_variant() %s does not match race/gender %s" % [game.pc_sprite_variant(), expect_sprite])


## any post-tutorial accomplishment ⇒ classes non-empty AND the tutorial's
## own map entities are in the state a real playthrough leaves them in.
## `relc_spar` is `persistent: true` (wi_game.gd's remove_entity is never
## called on it by design -- Relc's spar re-offers forever) and
## `goblin_encounter_1` `respawns: true` (dormant-until-next-sleep, never
## permanently removed) -- so the ONLY correct state for either, at ANY
## story position, is "not in removed_entities". This also catches the
## user's literal "Riverfarm with zero classes" example: door_awakening/
## portal_menu/near_riverfarm's ORIGINAL fixtures carried post_game/
## door_chain_started with classes == {} and no tutorial banked at all.
func _check_post_tutorial(name: String, game: WIGame, data: Dictionary) -> void:
	var accs: Dictionary = game.accomplishments
	var past_tutorial := false
	for flag: String in POST_TUTORIAL_FLAGS:
		if int(accs.get(flag, 0)) >= 1:
			past_tutorial = true
			break
	for acc_id: String in accs:
		if acc_id.ends_with("_attuned") and int(accs[acc_id]) >= 1:
			past_tutorial = true
	if past_tutorial and game.classes.is_empty():
		_fail(name, "post-tutorial accomplishment present but classes == {} -- no player reaches this story position with zero classes")
	if game.removed_entities.has("relc_spar"):
		_fail(name, "relc_spar (persistent: true, re-offers forever) is in removed_entities -- never removable by design")
	var raw_state: Dictionary = data.get("state", {})
	if past_tutorial and not (raw_state.get("accomplishments", {}) as Dictionary).has("met_relc"):
		_fail(name, "post-tutorial accomplishment present but met_relc absent -- the tutorial that grants classes cannot have run without it")


## Monotone chains: a downstream flag can never be banked without its
## upstream producers already banked (door_that_goes_elsewhere's own
## quest-beat structure, data/quests.json's own _comment) -- and any
## region's `_attuned` flag implies the portal network was already
## awakened (`door_awakened`, the shared beat-4 flag every anchor gates
## behind, per data/portals.json's own top _comment). garden_door_unlocked
## implies its exact K-of-4 earn gate (`_garden_earn_met`, wi_game.gd).
func _check_monotone_chains(name: String, game: WIGame) -> void:
	var accs: Dictionary = game.accomplishments
	if int(accs.get("door_awakened", 0)) >= 1:
		for req: String in ["door_understood", "recovered_anchor_stone", "bought_catalyst"]:
			if int(accs.get(req, 0)) < 1:
				_fail(name, "door_awakened banked without %s -- the awakening chain skips a beat" % req)
		if int(accs.get("door_study_sleeps", 0)) != 3:
			_fail(name, "door_awakened banked but door_study_sleeps != 3 (got %d)" % int(accs.get("door_study_sleeps", 0)))
	for acc_id: String in accs:
		if acc_id.ends_with("_attuned") and int(accs[acc_id]) >= 1 and int(accs.get("door_awakened", 0)) < 1:
			_fail(name, "%s banked without door_awakened -- no anchor destination is reachable before the portal network wakes" % acc_id)
	if int(accs.get("garden_door_unlocked", 0)) >= 1:
		if int(accs.get("reached_two_classes", 0)) < 1:
			_fail(name, "garden_door_unlocked banked without reached_two_classes -- _garden_earn_met() requires Act III")
		if game._quests_completed_count() < 3:
			_fail(name, "garden_door_unlocked banked with fewer than 3 completed quests -- _garden_earn_met() requires Act III")
		var legs := ["cleaned_the_inn", "goblins_spared", "sign_defended", "resolved_wrong_order"]
		var met := 0
		for leg: String in legs:
			if int(accs.get(leg, 0)) >= 1:
				met += 1
		if met < 2:
			_fail(name, "garden_door_unlocked banked with fewer than 2 of the 4 ratified legs (got %d)" % met)
	if int(accs.get("post_game", 0)) >= 1 and not POST_GAME_BACKBONE_EXEMPT.has(name):
		for req: String in POST_GAME_BACKBONE:
			if int(accs.get(req, 0)) < 1:
				_fail(name, "post_game banked without %s -- Act III's seal_holds beat requires the full backbone (see acts.json)" % req)
		if game._quests_completed_count() < 3:
			_fail(name, "post_game banked with fewer than 3 completed quests")


## position plausibility: current_map's implied position ⇒ the
## accomplishments that gate reaching it (MAP_REQUIRES, derived from data).
func _check_position_plausibility(name: String, game: WIGame) -> void:
	var reqs: Array = MAP_REQUIRES.get(game.current_map, [])
	for req: String in reqs:
		if int(game.accomplishments.get(req, 0)) < 1:
			_fail(name, "standing on '%s' without %s -- that map is unreachable without it" % [game.current_map, req])


## economy: gold >= the documented floor for the position tier. SCOPED TO
## GATE_FIXTURES ONLY (see the file header's two-tier note): the general
## rule ("a position past Act II with gold==0 is incoherent") also holds
## for near_act3/climax_surface_start/climax_sealed_start/
## deep_descent_start/near_ruin (all gold==0 at an Act-III-or-later
## position), but each of those is the fixture for a LONG whole-arc
## canonical (arc_flow/climax_chain/climax_seal/deep_descent) whose gold
## change needs its own dedicated re-verification pass -- see the ledger's
## "known gaps" section. Until that pass lands, only GATE_FIXTURES carry
## the ledger's exact derived floors (docs/design/fixture-position-ledger.md).
func _check_economy(name: String, game: WIGame) -> void:
	if not GATE_FIXTURES.has(name):
		return
	var act_id := String(game.act_summary().get("id", ""))
	if act_id != "act_iii":
		return
	var floor_g := _gate_gold_floor(name, game)
	if game.gold < floor_g:
		_fail(name, "gold %d below documented floor %d for this position tier" % [game.gold, floor_g])


## The ledger's exact per-fixture floors (docs/design/fixture-position-ledger.md):
## 40g honest Act III/post_game income pre-catalyst-spend (Tier A -- must
## clear Krshia's 35g resonant_catalyst with headroom); 5g after that
## mandatory purchase (Tier B). near_garden/garden_unlocked reach Act III
## via a cheaper leg set (no warren bounty, no door-chain spend) -- their
## floor is 15g per the ledger's Tier-3 math.
func _gate_gold_floor(name: String, game: WIGame) -> int:
	if name == "near_garden" or name == "garden_unlocked":
		return 15
	if int(game.accomplishments.get("bought_catalyst", 0)) >= 1:
		return 5
	return 40


## combat readiness: only the fixtures COMBAT_BAND_FIXTURES names (see that
## const's own doc comment for the exact-match, both-directions rationale).
func _check_combat_band(name: String, game: WIGame) -> void:
	if not COMBAT_BAND_FIXTURES.has(name):
		return
	var total := 0
	for lvl: Variant in game.classes.values():
		total += int(lvl)
	var need := int(COMBAT_BAND_FIXTURES[name])
	if total != need:
		_fail(name, "total class levels %d != the %d-level tuned build its own canonical's fights were measured at (band invalid in either direction)" % [total, need])


## equipment: equipped weapon (if any) must exist in inventory (the
## `equip()` invariant every load-bearing save already maintains); act-III+
## GATE_FIXTURES carry better than rusty_sword (documented per-fixture in
## the ledger) unless the position's story says otherwise.
func _check_equipment(name: String, game: WIGame) -> void:
	var weapon := String(game.equipped.get("weapon", ""))
	if weapon != "" and not game.inventory.has(weapon):
		_fail(name, "equipped weapon '%s' is not in inventory" % weapon)
	if GATE_FIXTURES.has(name) and weapon == "rusty_sword":
		_fail(name, "act-III+ gate fixture still carries the starter rusty_sword -- upgrade or document the story reason (ledger)")


## rng_state: string form (guaranteed by JSON's own dict shape --
## WISave.apply already rejected anything else above) and non-degenerate.
## TRAP: WISave restores `.state` directly, never `.seed` -- a properly
## derived `.state` (RandomNumberGenerator.seed = N, then read `.state`,
## tests/_derive_rng_state.gd) is a full-range signed 64-bit value, while a
## hand-typed small int (the literal seed number, or "12345") collapses the
## first randi() draw to the same degenerate output regardless of which
## small int was picked. This threshold is comfortably below every real
## derived state in the repo (smallest magnitude seen: ~2.9e16) and
## comfortably above any plausible hand-typed seed literal.
const RNG_STATE_MIN_MAGNITUDE := 1_000_000


func _check_rng_state(name: String, data: Dictionary) -> void:
	var raw := String((data.get("state", {}) as Dictionary).get("rng_state", ""))
	if not raw.is_valid_int():
		_fail(name, "rng_state '%s' is not an integer string" % raw)
		return
	if absi(int(raw)) < RNG_STATE_MIN_MAGNITUDE:
		_fail(name, "rng_state %s looks hand-typed (magnitude below %d) -- derive via tests/_derive_rng_state.gd" % [raw, RNG_STATE_MIN_MAGNITUDE])
