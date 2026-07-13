extends Node
## Autoload owning the sim instance; bridges sim domain events onto ObservableBus.

const SAVE_DIR := "user://saves"
## Issue #78: 3 manual slots (was 1). "manual" stays FIRST/index-0 on
## purpose -- it is the pre-existing slot id every fixture-driven QA script's
## `fixture_save` shorthand (a bare fixture-name string) and every hand-
## written `assert_save_exists`/`install_fixture` step already targets by
## default (qa/test_driver.gd's `_install_fixture_saves`), so keeping it as
## slot 1 means the picker's default cursor (index 0) reproduces the OLD
## single-manual-slot behavior exactly -- no test needed a slot-id rename,
## only an extra confirm to land on the now-explicit picker row.
const MANUAL_SLOTS: Array[String] = ["manual", "manual_2", "manual_3"]

## Pure simulation instance owned by the game autoload.
var sim: WIGame
var _autosave_announced := false
## Issue #88 (gap-2): true for exactly the FIRST save_auto() call after a
## New Game reset -- consumed (and cleared) there, which rotates the OLD
## "auto" slot to "auto_prev" before this run's own first autosave clobbers
## it. Danger this closes: the single shared "auto" slot silently destroyed
## a finished run's last checkpoint the moment New Game's fresh world hit
## its first MAP_CHANGED/etc. trigger -- title_screen.gd's own overwrite
## confirm (see that file) warns BEFORE reset; this is the safety net for
## the case the player confirms (or a fresh boot with no confirm needed).
var _rotate_auto_pending := false
## Issue #88 fix wave: armed by PRE_COMBAT_CHOICE (a dialogue-committed
## fight's pre-effects snapshot just wrote `auto_pre_combat`), consumed by
## the SAME dialogue_choose call's synchronous follow-up -- COMBAT_STARTED
## (skip the post-effects write, which would resurrect the choice-leak bug)
## or DIALOGUE_EFFECT_FAILED{start_combat} (disarm; no fight happened).
## Never survives across frames -- wi_events.gd's PRE_COMBAT_CHOICE doc pins
## the exactly-one-synchronous-follow-up contract this relies on.
var _choice_snapshot_armed := false


func _ready() -> void:
	_build_sim()
	ObservableBus.domain_event.connect(_on_domain_event)


## `creation` carries the character-creation choices
## ({pc_name, pc_race, pc_gender}) from the creation screen; empty on any other
## New Game path (title default-skip, code-driven reset), which lands the
## everyman defaults. Threaded to the fresh sim only -- a load never sees it
## (load_slot builds its trial sim with no creation dict and restores identity
## from the save).
func reset(creation: Dictionary = {}) -> void:
	_build_sim(creation)
	_rotate_auto_pending = true
	ObservableBus.emit_domain_event(WIEvents.GAME_RESET, {})


func _on_domain_event(type: String, payload: Dictionary) -> void:
	# Issue #88 fix wave: a DIALOGUE-COMMITTED fight's snapshot fires here,
	# BEFORE the chosen option's effects apply (wi_game.gd emits
	# PRE_COMBAT_CHOICE ahead of its effects loop) -- so the committing
	# choice's own accomplishments land INSIDE the rewind (relc_descent:
	# lose [Go together.] -> reload -> relc_joined_descent is GONE, a
	# re-choice of [I go alone.] can't produce the #89-lane contradiction
	# "went_alone banked but Relc fielded anyway"). rng_state here is
	# PRE-DRAW (start_combat's combat-seed randi hasn't run yet), so an
	# identical re-choice replays the SAME fight seed -- chosen behavior;
	# contrast the COMBAT_STARTED arm below.
	if type == WIEvents.PRE_COMBAT_CHOICE:
		_choice_snapshot_armed = true
		_write_slot("auto_pre_combat")
	# The deferred start_combat was refused (no fight) -- disarm so the next
	# NON-dialogue fight's COMBAT_STARTED write isn't wrongly skipped.
	if type == WIEvents.DIALOGUE_EFFECT_FAILED and String(payload.get("effect", "")) == "start_combat":
		_choice_snapshot_armed = false
	# Issue #88 (gap-2): a pre-combat snapshot, written the instant a fight
	# begins -- WISave never serializes `combat` (save.gd), so writing here
	# (COMBAT_STARTED fires from WICombat.begin(), AFTER `sim.combat` is
	# already assigned but before anything else could possibly mutate)
	# captures exactly the pre-fight world state, equivalent in every
	# observable way to a snapshot taken strictly before `sim.combat` was
	# built -- EXCEPT rng_state, which is ONE DRAW PAST pre-combat
	# (start_combat's own combat-seed `rng.randi()` already consumed):
	# a defeat-reload retry that re-triggers the same encounter draws a
	# FRESH combat seed, REROLLING the fight rather than replaying the
	# identical loss. CHOSEN behavior (a retry shouldn't be doomed to the
	# same beats), asymmetric with the pre-draw PRE_COMBAT_CHOICE snapshot
	# above by construction (the draw happens between the two).
	# Dedicated slot, NEVER "auto" itself: Abandon/"Load Autosave"
	# (pause_menu.gd) must keep reading the general last-checkpoint
	# semantics unchanged (combat_abandon.json's own pin on landing back at
	# the last ordinary autosave, not the fight's own entry cell) -- only
	# the DEFEAT path (combat_screen.gd's `_close_banner`) reads this slot.
	# A dialogue-committed fight SKIPS this write: its PRE_COMBAT_CHOICE
	# snapshot (pre-effects) already holds the honest rewind point, and a
	# post-effects overwrite here would resurrect the exact leak.
	if type == WIEvents.COMBAT_STARTED:
		if _choice_snapshot_armed:
			_choice_snapshot_armed = false
		else:
			_write_slot("auto_pre_combat")
	if type in [
		WIEvents.COMBAT_RESOLVED, WIEvents.CLASS_LEVEL_UP, WIEvents.QUEST_BEAT_COMPLETED,
		WIEvents.MAP_CHANGED, WIEvents.CLASS_GAINED, WIEvents.CLASS_EVOLVED,
		WIEvents.CONSOLIDATION_ACCEPTED,
		# Issue #88 (gap-2): PHASE_CHANGED fires unconditionally on EVERY
		# sleep (wi_game.gd's sleep()), even a grant-less one -- closes the
		# "slept, banked nothing level-shaped, then died and lost the whole
		# waking" gap the old trigger list left open. It ALSO fires on an
		# ordinary day/dusk/night crossing mid-exploration (wi_game.gd's
		# _tick_action) -- harmless (a strictly fresher checkpoint), not
		# worth gating out.
		WIEvents.PHASE_CHANGED,
	]:
		save_auto()


## Writes the autosave slot and announces the first autosave to the player.
func save_auto() -> void:
	if _rotate_auto_pending:
		_rotate_auto_pending = false
		_rotate_slot("auto", "auto_prev")
	_write_slot("auto")
	if not _autosave_announced:
		_autosave_announced = true
		# Composed through WIInputHints;
		# kb-mode output is byte-identical to the old literal, so work_loop's
		# exact-text pin on this toast needs no re-pin.
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Autosaved. (%s — save/load anytime)" % WIInputHints.label("cancel")})


## Writes a manual save slot (default "manual", slot 1 -- see MANUAL_SLOTS)
## unless a modal simulation is active. `slot` is caller-supplied (the pause
## menu's slot picker, issue #78) so any of MANUAL_SLOTS can be targeted, not
## just slot 1.
func save_manual(slot: String = "manual") -> bool:
	if sim.combat != null or sim.dialogue != null or not sim.pending_consolidation.is_empty():
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Cannot save right now."})
		return false
	_write_slot(slot)
	ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Game saved."})
	return true


## Loads a named save slot and emits game_loaded after the sim is restored.
## The save is applied onto a TRIAL sim; the live `sim` is swapped in only once
## the save applies cleanly, so a rejected load (missing/corrupt/older version
## -- v1 is rejected by design, see save.gd) is a true no-op that leaves the
## live game untouched rather than silently discarding it for a fresh one.
## (Callers wanting a fallback -- e.g. combat_screen's defeat path -- check the
## return value and reset() themselves; callers that don't get a safe no-op.)
## `reason` (issue #78) rides GAME_LOADED's payload verbatim -- purely
## informational, no branching here. Every pre-existing caller (pause Load/
## Load Autosave, title Continue) omits it (default ""), so their emitted
## payload is byte-identical in every OTHER key to before this task (only the
## new "reason" key is additive -- payload_contains subset-matches, so no
## existing `wait_for_event game_loaded` pin needs re-pinning). Only
## combat_screen.gd's TRUE-DEFEAT branch of `_close_banner` passes "defeat"
## -- the abandon path (`abandon_combat`) deliberately does NOT, since
## Abandon already runs its own explicit Yes/No confirm and needs no further
## orientation screen. Main._on_domain_event reads this to decide whether
## swap_to_world plays the defeat interstitial (sleep_veil.gd's
## play_defeat()) -- see that file.
func load_slot(slot: String, reason: String = "") -> bool:
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
	ObservableBus.emit_domain_event(WIEvents.GAME_LOADED, {"reason": reason})
	return true


## Read-only slot preview for the title/pause slot pickers (issue #78) --
## parses the file directly and NEVER applies it (WISave.metadata is pure and
## tolerant of version drift, same contract load_slot's own trial-apply
## follows for the real load). {} when the slot has no readable save, so
## callers can treat a missing file and an unreadable one identically ("Empty").
func slot_metadata(slot: String) -> Dictionary:
	var path := "%s/%s.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	var meta := WISave.metadata(parsed)
	if meta.is_empty():
		return {}
	meta["mtime"] = FileAccess.get_modified_time(path)
	return meta


## Copies a
## `qa/fixtures/<fixture>.json` file into `user://saves/<slot>.json` verbatim,
## so the EXISTING slot-generic `load_slot` can boot it (the picker passes a
## dedicated "playtest" slot -- never "manual", the user's own save) --
## the exact same copy the QA harness's own `fixture_save` affordance performs
## (qa/test_driver.gd's `_install_fixture_saves`), just triggered from the
## title UI instead of a script's top-level field. Returns false (no-op) if
## the named fixture doesn't exist or the slot file couldn't be written; the
## caller (title_screen.gd) surfaces that as a notice, same as a rejected
## `load_slot`.
func install_fixture_save(fixture: String, slot: String) -> bool:
	var src_path := "res://qa/fixtures/%s.json" % fixture
	if not FileAccess.file_exists(src_path):
		return false
	var contents := FileAccess.get_file_as_string(src_path)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dst := FileAccess.open("%s/%s.json" % [SAVE_DIR, slot], FileAccess.WRITE)
	if dst == null:
		return false
	dst.store_string(contents)
	dst.close()
	return true


func _build_sim(creation: Dictionary = {}) -> void:
	sim = _make_sim(creation)


## Constructs a fresh WIGame from the data files + current seed WITHOUT
## assigning it to `sim`, so load_slot can trial-apply a save before committing
## the swap (see load_slot). `creation` is the character-creation
## dict for a New Game; empty ({}) for a load trial and every cold boot, which
## lands WIGame's tolerant identity defaults.
func _make_sim(creation: Dictionary = {}) -> WIGame:
	var scene_config: Dictionary = WISceneCatalog.compose()
	var skill_config: Dictionary = _load_json("res://data/skills.json")
	var combat_config := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
	}
	combat_config["quests"] = _load_json("res://data/quests.json")
	# acts.json is the counter-derived act-line catalog consumed
	# by WIActs (via WIGame.act_summary()) -- same injection lane as quests.
	combat_config["acts"] = _load_json("res://data/acts.json")
	# items.json feeds WIGame.item()/the combat-build weapon gate.
	# Without this the real game's `equipped.weapon` (default "rusty_sword")
	# would resolve to {} at every combat build, defaulting weapon_family to
	# "" and filtering OUT every weapon-tagged skill (including the intended
	# sword-tagged power_strike) -- a real regression, not just an untested
	# path, so this line is required for the feature to work at all in play.
	combat_config["items"] = _load_json("res://data/items.json")
	# THE REQUEST BOARD's posting pool -- same injection lane as
	# quests/items. WIGame.board_bounties()/accept_bounty()/turn_in_bounty()
	# read it via `_combat_config.get("bounties", {})`.
	combat_config["bounties"] = _load_json("res://data/bounties.json")
	# THE DELIVERY BOARD's pool (the Runner's Guild) -- same
	# injection lane. WIGame.delivery_board_deliveries()/accept_delivery()/
	# turn_in_delivery() read it via `_combat_config.get("deliveries", {})`.
	combat_config["deliveries"] = _load_json("res://data/deliveries.json")
	# The portal-menu's destination catalog --
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
	# moods.json's `meta.phase_thresholds` is the sim's phase-clock config,
	# not just documentation of it -- WIGame's ctor accepts a phase_config
	# dict, and if this call ever stops passing one,
	# WIGame._phase_config silently falls back to its own hardcoded
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


## Byte-copies `<from>.json` to `<to>.json` (the `install_fixture_save` copy
## shape) -- a silent no-op when `from` has never been written (e.g. this
## process's very first save_auto ever, cold boot with no prior "auto").
## Neither slot is ever offered by `_newest_save_slot`/pause's slot picker
## (the "playtest" slot's own precedent, title_screen.gd) -- "auto_prev" is
## a pure safety-net copy, not a player-facing save.
func _rotate_slot(from: String, to: String) -> void:
	var src_path := "%s/%s.json" % [SAVE_DIR, from]
	if not FileAccess.file_exists(src_path):
		return
	var contents := FileAccess.get_file_as_string(src_path)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dst := FileAccess.open("%s/%s.json" % [SAVE_DIR, to], FileAccess.WRITE)
	if dst == null:
		return
	dst.store_string(contents)
	dst.close()


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed
