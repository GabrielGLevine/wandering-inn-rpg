extends SceneTree

const FIXTURES_DIR := "res://qa/fixtures"

const SKIP := {
	"v1_format": "pre-v2 save format, deliberately REJECTED by WISave.apply (test_save.gd's own migration-rejection proof) -- not a loadable story position at all",
	"v2_format": "pre-v3 migration INPUT (consumed by _migrated(), never applied verbatim) -- not itself a playtest destination",
	"dp2_fixwave_absolute_start": "a deliberately MID-ANOMALY soft-lock repro (found_spider_silk banked before its posting was ever accepted), explicitly 'NOT registered in qa/manifest.json' per its own _comment -- its incoherence IS its subject",
}

# Intentionally narrow: only late-gate fixtures receive rigorous gear/story
# posture checks; broadening this list changes the validator's contract.
const GATE_FIXTURES := [
	"door_chain_talk_start", "door_chain_scout_start", "door_chain_fight_start",
	"door_awakening_start", "portal_menu_start", "near_garden", "near_riverfarm",
	"garden_unlocked",
]

const COMBAT_BAND_FIXTURES := {
	"door_chain_fight_start": 10,
	"door_chain_sequence_break_start": 10,
	"riverfarm_fight_start": 10,
	"near_invrisil": 2,
	"near_invrisil_fight": 10,
	"delve_fight_start": 11,
}

const MAP_REQUIRES := {
	"street": ["reached_liscor"],
	"guild": ["reached_liscor"],
	"barracks": ["reached_liscor"],
	"runners_guild": ["reached_liscor"],
	"sewers": ["reached_liscor", "heard_about_cisterns"],
	"deep_tunnels": ["reached_liscor", "heard_about_cisterns", "heard_the_deep_tremor"],
	"dungeon_approach": ["horns_delve_started"],
	"trapped_halls": ["horns_delve_started"],
	"ruin_surface": ["door_chain_started"],
	"garden_sanctuary": ["garden_door_unlocked"],
	"riverfarm_village": ["door_awakened", "riverfarm_attuned"],
	"witch_hollow": ["door_awakened", "riverfarm_attuned"],
	"invrisil_boulevard": ["door_awakened", "invrisil_attuned"],
	"mercantile_alleys": ["door_awakened", "invrisil_attuned"],
	"brothers_parlor": ["door_awakened", "invrisil_attuned"],
	"pallass_market": ["door_awakened", "pallass_attuned"],
	"pallass_forge": ["door_awakened", "pallass_attuned", "elevator_pass_stamped"],
}

const POST_TUTORIAL_FLAGS := ["given_spear_by_relc", "reached_liscor", "post_game", "door_chain_started"]

const POST_GAME_BACKBONE := [
	"reached_liscor", "reached_two_classes", "met_relc", "sparred_with_relc", "given_spear_by_relc",
	"watch_runner_pointed", "heard_the_deep_tremor", "heard_olesm_briefing", "cleared_the_warren", "raskghar_sealed",
]

const POST_GAME_BACKBONE_EXEMPT := {
	"near_invrisil": "classes locked to the alley_footpads combat-tuning baseline; see const's own doc comment",
}

var _errors: Array[String] = []
var _checked := 0


func _init() -> void:
	WITestWatchdog.arm(self)
	var combat_config := _combat_config()
	var scene: Dictionary = WISceneCatalog.compose()
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
	if int(accs.get("invrisil_attuned", 0)) >= 1:
		if int(accs.get("blight_lifted", 0)) < 1:
			_fail(name, "invrisil_attuned banked without blight_lifted -- Eloise's stone (the only producer) sells from a shop node gated on it")
		if not game.inventory.has("invrisil_attunement_stone"):
			_fail(name, "invrisil_attuned banked without invrisil_attunement_stone in inventory -- the purchase grants both on one option and the stone is never removable")
	if int(accs.get("blight_lifted", 0)) >= 1 and int(accs.get("riverfarm_attuned", 0)) < 1:
		_fail(name, "blight_lifted banked without riverfarm_attuned -- every producer lives on the riverfarm-gated witch_hollow map")
	if int(accs.get("seal_kept_reported", 0)) >= 1 and int(accs.get("seal_kept_found", 0)) < 1:
		_fail(name, "seal_kept_reported banked without seal_kept_found -- Olesm's report option is gated on the find beat")
	if int(accs.get("seal_kept_found", 0)) >= 1 and int(accs.get("vault_construct_downed", 0)) < 1:
		_fail(name, "seal_kept_found banked without vault_construct_downed -- the deeper door only opens past the guardian")
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


func _check_position_plausibility(name: String, game: WIGame) -> void:
	var reqs: Array = MAP_REQUIRES.get(game.current_map, [])
	for req: String in reqs:
		if int(game.accomplishments.get(req, 0)) < 1:
			_fail(name, "standing on '%s' without %s -- that map is unreachable without it" % [game.current_map, req])


func _check_economy(name: String, game: WIGame) -> void:
	if not GATE_FIXTURES.has(name):
		return
	var act_id := String(game.act_summary().get("id", ""))
	if act_id != "act_iii":
		return
	var floor_g := _gate_gold_floor(name, game)
	if game.gold < floor_g:
		_fail(name, "gold %d below documented floor %d for this position tier" % [game.gold, floor_g])


func _gate_gold_floor(name: String, game: WIGame) -> int:
	if name == "near_garden" or name == "garden_unlocked":
		return 15
	if int(game.accomplishments.get("bought_catalyst", 0)) >= 1:
		return 5
	return 40


func _check_combat_band(name: String, game: WIGame) -> void:
	if not COMBAT_BAND_FIXTURES.has(name):
		return
	var total := 0
	for lvl: Variant in game.classes.values():
		total += int(lvl)
	var need := int(COMBAT_BAND_FIXTURES[name])
	if total != need:
		_fail(name, "total class levels %d != the %d-level tuned build its own canonical's fights were measured at (band invalid in either direction)" % [total, need])


func _check_equipment(name: String, game: WIGame) -> void:
	var weapon := String(game.equipped.get("weapon", ""))
	if weapon != "" and not game.inventory.has(weapon):
		_fail(name, "equipped weapon '%s' is not in inventory" % weapon)
	if GATE_FIXTURES.has(name) and weapon == "rusty_sword":
		_fail(name, "act-III+ gate fixture still carries the starter rusty_sword -- upgrade or document the story reason (ledger)")


const RNG_STATE_MIN_MAGNITUDE := 1_000_000

# RNG.state is internal generator state, not a seed. Small literals are a
# hand-authored-fixture trap; derive them with _derive_rng_state.gd.
func _check_rng_state(name: String, data: Dictionary) -> void:
	var raw := String((data.get("state", {}) as Dictionary).get("rng_state", ""))
	if not raw.is_valid_int():
		_fail(name, "rng_state '%s' is not an integer string" % raw)
		return
	if absi(int(raw)) < RNG_STATE_MIN_MAGNITUDE:
		_fail(name, "rng_state %s looks hand-typed (magnitude below %d) -- derive via tests/_derive_rng_state.gd" % [raw, RNG_STATE_MIN_MAGNITUDE])
