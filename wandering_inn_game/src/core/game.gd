extends Node
## Autoload owning the sim instance; bridges sim domain events onto ObservableBus.

const SAVE_DIR := "user://saves"

## Pure simulation instance owned by the game autoload.
var sim: WIGame
var _autosave_announced := false


func _ready() -> void:
	_build_sim()
	ObservableBus.domain_event.connect(_on_domain_event)


## `creation` (M-ARC §5) carries the character-creation choices
## ({pc_name, pc_race, pc_gender}) from the creation screen; empty on any other
## New Game path (title default-skip, code-driven reset), which lands the
## everyman defaults. Threaded to the fresh sim only -- a load never sees it
## (load_slot builds its trial sim with no creation dict and restores identity
## from the save).
func reset(creation: Dictionary = {}) -> void:
	_build_sim(creation)
	ObservableBus.emit_domain_event(WIEvents.GAME_RESET, {})


func _on_domain_event(type: String, _payload: Dictionary) -> void:
	if type in [
		WIEvents.COMBAT_RESOLVED, WIEvents.CLASS_LEVEL_UP, WIEvents.QUEST_BEAT_COMPLETED,
		WIEvents.MAP_CHANGED, WIEvents.CLASS_GAINED, WIEvents.CLASS_EVOLVED,
		WIEvents.CONSOLIDATION_ACCEPTED,
	]:
		save_auto()


## Writes the autosave slot and announces the first autosave to the player.
func save_auto() -> void:
	_write_slot("auto")
	if not _autosave_announced:
		_autosave_announced = true
		# Controller support (S3, issue #18): composed through WIInputHints;
		# kb-mode output is byte-identical to the old literal, so work_loop's
		# exact-text pin on this toast needs no re-pin.
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Autosaved. (%s — save/load anytime)" % WIInputHints.label("cancel")})


## Writes the manual save slot unless a modal simulation is active.
func save_manual() -> bool:
	if sim.combat != null or sim.dialogue != null or not sim.pending_consolidation.is_empty():
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Cannot save right now."})
		return false
	_write_slot("manual")
	ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Game saved."})
	return true


## Loads a named save slot and emits game_loaded after the sim is restored.
## The save is applied onto a TRIAL sim; the live `sim` is swapped in only once
## the save applies cleanly, so a rejected load (missing/corrupt/older version
## -- v1 is rejected by design, see save.gd) is a true no-op that leaves the
## live game untouched rather than silently discarding it for a fresh one.
## (Callers wanting a fallback -- e.g. combat_screen's defeat path -- check the
## return value and reset() themselves; callers that don't get a safe no-op.)
func load_slot(slot: String) -> bool:
	# Failure messaging is the CALLER's job (each has different UX: pause_menu
	# surfaces a notice, the combat defeat path resets silently, title Continue
	# refreshes) -- load_slot stays message-free so a single failure never
	# double-toasts.
	var path := "%s/%s.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	var trial := _make_sim()
	if not WISave.apply(trial, parsed):
		return false
	sim = trial
	ObservableBus.emit_domain_event(WIEvents.GAME_LOADED, {})
	return true


func _build_sim(creation: Dictionary = {}) -> void:
	sim = _make_sim(creation)


## Constructs a fresh WIGame from the data files + current seed WITHOUT
## assigning it to `sim`, so load_slot can trial-apply a save before committing
## the swap (see load_slot). `creation` (M-ARC §5) is the character-creation
## dict for a New Game; empty ({}) for a load trial and every cold boot, which
## lands WIGame's tolerant identity defaults.
func _make_sim(creation: Dictionary = {}) -> WIGame:
	var scene_config: Dictionary = _load_json("res://data/skeleton_scene.json")
	var skill_config: Dictionary = _load_json("res://data/skills.json")
	var combat_config := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
	}
	combat_config["quests"] = _load_json("res://data/quests.json")
	# M-ARC Task A1: acts.json is the counter-derived act-line catalog consumed
	# by WIActs (via WIGame.act_summary()) -- same injection lane as quests.
	combat_config["acts"] = _load_json("res://data/acts.json")
	# M7 Task E2: items.json feeds WIGame.item()/the combat-build weapon gate.
	# Without this the real game's `equipped.weapon` (default "rusty_sword")
	# would resolve to {} at every combat build, defaulting weapon_family to
	# "" and filtering OUT every weapon-tagged skill (including the intended
	# sword-tagged power_strike) -- a real regression, not just an untested
	# path, so this line is required for the feature to work at all in play.
	combat_config["items"] = _load_json("res://data/items.json")
	# M-DEPTH DP2: THE REQUEST BOARD's posting pool -- same injection lane as
	# quests/items. WIGame.board_bounties()/accept_bounty()/turn_in_bounty()
	# read it via `_combat_config.get("bounties", {})`.
	combat_config["bounties"] = _load_json("res://data/bounties.json")
	# M-DEPTH DP5: THE DELIVERY BOARD's pool (the Runner's Guild) -- same
	# injection lane. WIGame.delivery_board_deliveries()/accept_delivery()/
	# turn_in_delivery() read it via `_combat_config.get("deliveries", {})`.
	combat_config["deliveries"] = _load_json("res://data/deliveries.json")
	# Magical Door plan Task D4: the portal-menu's destination catalog --
	# same injection lane. WIGame.attuned_destinations()/_travel_to_portal()
	# read it via `_combat_config.get("portals", {})`.
	combat_config["portals"] = _load_json("res://data/portals.json")
	var dialogue_graphs: Dictionary = {}
	var dir: DirAccess = DirAccess.open("res://data/dialogue")
	if dir != null:
		for f: String in dir.get_files():
			if f.ends_with(".json"):
				dialogue_graphs[f.get_basename()] = _load_json("res://data/dialogue/" + f)
	combat_config["dialogue"] = dialogue_graphs
	var seed_str := String(QAPaths.user_args().get("seed", ""))
	if seed_str.is_empty() and OS.has_feature("web"):
		var js_seed: Variant = JavaScriptBridge.eval("window.__WI_QA__ ? String(window.__WI_QA__.seed ?? '') : ''", true)
		seed_str = String(js_seed) if js_seed != null else ""
	var rng_seed: int = int(seed_str) if not seed_str.is_empty() else 0
	# M-BEAUTY RF fix wave (final-review Fix 3): moods.json's
	# `meta.phase_thresholds` is the sim's phase-clock config now, not just
	# documentation of it -- WIGame's ctor already accepted a phase_config
	# dict (M7 M-BEAUTY fold), but this call never passed one, so
	# WIGame._phase_config silently fell back to its own hardcoded
	# dusk_at/night_at 40/90 defaults every run. The shipped moods.json
	# values EQUAL those defaults today, so this wiring is behavior-neutral
	# (zero seed shift -- verified: atmosphere_check + 2 pinned-seed combat
	# QA scripts unchanged). moods.json keys are "dusk"/"night" (the
	# per-map mood dicts' own phase keys); WIGame's ctor keys are
	# "dusk_at"/"night_at" -- translate here, wi_game.gd stays untouched.
	var phase_thresholds: Dictionary = (_load_json("res://data/moods.json").get("meta", {}) as Dictionary).get("phase_thresholds", {})
	var phase_config := {
		"dusk_at": int(phase_thresholds.get("dusk", 40)),
		"night_at": int(phase_thresholds.get("night", 90)),
	}
	return WIGame.new(scene_config, skill_config, ObservableBus.emit_domain_event, rng_seed, combat_config, phase_config, creation)


func _write_slot(slot: String) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open("%s/%s.json" % [SAVE_DIR, slot], FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(WISave.serialize(sim)))
	file.close()


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed
