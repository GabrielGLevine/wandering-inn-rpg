extends Node

const SAVE_DIR := "user://saves"
const MANUAL_SLOTS: Array[String] = ["manual", "manual_2", "manual_3"]

## #111 safe project rename: on first boot into a FRESH user:// we COPY (never
## move) the pre-rename sibling dir across, then drop a permanent marker so it
## is strictly one-time. Pure copy logic lives in WISaveMigration; this
## autoload owns the trigger, the event, and the marker.
const MIGRATION_MARKER := "user://migrated_from_v4"

var sim: WIGame
## a9 #246 (review F1): true only while a world session is live (set by
## Main.swap_to_world, cleared by swap_to_title). Export at TITLE must dump
## the Continue slot's bytes, never the fresh boot sim — a fresh export
## labeled like a backup, imported later, would overwrite a real save.
var world_live := false
## GH#279: overlay-display bookkeeping only (autoload state, never sim).
var last_save_slot := ""
var last_autosave_trigger := ""
var _autosave_announced := false
var _rotate_auto_pending := false
var _choice_snapshot_armed := false


func _ready() -> void:
	_migrate_legacy_userdir()
	_build_sim()
	ObservableBus.domain_event.connect(_on_domain_event)


## #111: one-time first-boot carry-over of the pre-rename user:// dir. Runs
## BEFORE anything enumerates slots (title/settings), so a migrated save is
## visible to Continue on the very first launch of the renamed build. One
## code path for native AND web: user:// globalizes to the real absolute
## path on both, and the legacy dir is its same-parent sibling (so no
## Godot/godot capitalization guesswork -- the sibling shares our casing).
func _migrate_legacy_userdir() -> void:
	if FileAccess.file_exists(MIGRATION_MARKER):
		return
	var result := _run_userdir_migration()
	# Mark done ONLY on a fully-clean pass. A partial copy (disk full, IO
	# error) leaves the marker UNWRITTEN so the next boot retries the un-copied
	# slots; the copy is no-clobber, so the retry never overwrites a file
	# already carried over. Gating on the marker (not "is user:// empty") is
	# what makes the retry reachable -- a partially-filled user:// would
	# otherwise look "established" and skip forever (#111 review I-1). The
	# no-clobber guard also makes a re-run harmless for an established player.
	if int(result.get("failed", 0)) == 0:
		_write_file_text(MIGRATION_MARKER, "1")


func _run_userdir_migration() -> Dictionary:
	var legacy := WISaveMigration.legacy_userdir_path()
	if legacy == "" or not DirAccess.dir_exists_absolute(legacy):
		return {"copied": 0, "failed": 0}
	var result := WISaveMigration.migrate_userdir(legacy, ProjectSettings.globalize_path("user://").trim_suffix("/"))
	if int(result.get("copied", 0)) > 0:
		ObservableBus.emit_domain_event(WIEvents.SAVE_MIGRATED, {"count": result["copied"]})
	return result


func _write_file_text(path: String, text: String) -> void:
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out != null:
		out.store_string(text)
		out.close()


func reset(creation: Dictionary = {}) -> void:
	_build_sim(creation)
	_rotate_auto_pending = true
	ObservableBus.emit_domain_event(WIEvents.GAME_RESET, {})


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if type == WIEvents.PRE_COMBAT_CHOICE:
		_choice_snapshot_armed = true
		_write_slot("auto_pre_combat")
	if type == WIEvents.DIALOGUE_EFFECT_FAILED and String(payload.get("effect", "")) == "start_combat":
		_choice_snapshot_armed = false
	if type == WIEvents.COMBAT_STARTED:
		if _choice_snapshot_armed:
			_choice_snapshot_armed = false
		else:
			_write_slot("auto_pre_combat")
	if type in [
		WIEvents.COMBAT_RESOLVED, WIEvents.CLASS_LEVEL_UP, WIEvents.QUEST_BEAT_COMPLETED,
		WIEvents.MAP_CHANGED, WIEvents.CLASS_GAINED, WIEvents.CLASS_EVOLVED,
		WIEvents.CONSOLIDATION_ACCEPTED,
		WIEvents.PHASE_CHANGED,
	]:
		last_autosave_trigger = type  # GH#279: overlay display only (autoload state, not sim)
		save_auto()


func save_auto() -> void:
	if _rotate_auto_pending:
		_rotate_auto_pending = false
		_rotate_slot("auto", "auto_prev")
	_write_slot("auto")
	# GH#325: `housekeeping` demotes this line in the toast queue. This listener
	# runs from inside QUEST_BEAT_COMPLETED/CLASS_* -- i.e. BEFORE the sim's own
	# quest and payoff toasts reach the bus -- so without the flag "Autosaved."
	# took slot 1 and the authored payoff took slot 3, then flashed past behind
	# it. Marked toasts sort behind authored ones and are the only ones the
	# queue's hold cap still clips.
	if not _autosave_announced:
		_autosave_announced = true
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Autosaved. (%s — save/load anytime)" % WIInputHints.label("cancel"), "housekeeping": true})


func save_manual(slot: String = "manual") -> bool:
	if sim.combat != null or sim.dialogue != null:
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Cannot save right now.", "housekeeping": true})
		return false
	_write_slot(slot)
	ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Game saved.", "housekeeping": true})
	return true


## GH#374: `grace_encounter` is the id of the encounter the player just LOST to,
## threaded here by combat_screen.gd's true-defeat branch (the only caller that
## ever passes it, alongside reason:"defeat"). It is armed on the freshly-loaded
## sim, BEFORE GAME_LOADED, so every listener that rebuilds from that event
## (world.gd's ward marker among them) already sees final state. The sim is
## never asked to write this itself -- the grace is a consequence of reloading,
## and WIGame holds no reference to the thing that reloaded it.
func load_slot(slot: String, reason: String = "", grace_encounter: String = "") -> bool:
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
	if grace_encounter != "":
		sim.arm_exit_grace(grace_encounter)
	ObservableBus.emit_domain_event(WIEvents.GAME_LOADED, {"reason": reason})
	return true


## a9 #246: the import/export seam. Export serializes the LIVE sim (what a
## manual save would write) under save_manual's own blocked-state guard;
## empty string = "cannot export right now". Import runs load_slot's exact
## trial-sim pattern on caller-supplied TEXT — a rejected file leaves the
## running game AND every slot byte-identical (the non-destructive
## contract); an accepted one becomes the live sim and persists to the
## Continue slot.
func export_save_text() -> String:
	if not world_live:
		var slot_path := "%s/manual.json" % SAVE_DIR
		if not FileAccess.file_exists(slot_path):
			return ""
		return FileAccess.get_file_as_string(slot_path)
	if sim.combat != null or sim.dialogue != null:
		return ""
	return JSON.stringify(WISave.serialize(sim))


func import_save_text(text: String) -> bool:
	# review F4: JSON.new().parse refuses SILENTLY — parse_string would spray
	# an engine ERROR for every non-JSON file a player picks (zero-noise bar).
	var parser := JSON.new()
	if parser.parse(text) != OK or not (parser.data is Dictionary):
		return false
	var parsed: Variant = parser.data
	var trial := _make_sim()
	if not WISave.apply(trial, parsed):
		return false
	sim = trial
	_write_slot("manual")
	ObservableBus.emit_domain_event(WIEvents.GAME_LOADED, {"reason": "import"})
	return true


## GH#278: dev/QA live data reload -- rebuild the sim from the CURRENT
## disk JSON through the save round-trip (serialize live sim -> fresh
## _make_sim -> WISave.apply), then let the GAME_LOADED handler rebuild
## the view + reset the view-side caches. Refuses in exactly the states
## save_manual refuses (combat/dialogue) -- save_auto and
## load_slot carry NO guard, so this check must live here, not be
## "composed" from them. Content-mismatch after id renames is out of
## scope: WISave.apply carries stale ids unchecked -- value-tuning tool,
## not a migration tool.
func reload_data() -> bool:
	if not world_live:
		return false  # title-screen boot sim: reloading it would swap_to_world uninvited (export_save_text parity)
	if sim.combat != null or sim.dialogue != null:
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Cannot reload data right now.", "housekeeping": true})
		return false
	# String round-trip so applied state has passed the same JSON typing a
	# disk save would (ints arrive as floats etc.), keeping this path
	# byte-equivalent to save->Load.
	var parsed: Variant = JSON.parse_string(JSON.stringify(WISave.serialize(sim)))
	if not (parsed is Dictionary):
		return false
	var trial := _make_sim()
	if not WISave.apply(trial, parsed):
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Reload refused: state no longer applies to the edited data.", "housekeeping": true})
		return false
	sim = trial
	ObservableBus.emit_domain_event(WIEvents.GAME_LOADED, {"reason": "reload_data"})
	return true


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


func _make_sim(creation: Dictionary = {}) -> WIGame:
	# GH#278 (D1 ordering): reset BEFORE compose, never in the GAME_LOADED
	# handler -- the handler fires after this consumed the catalog, which
	# would leave the sim one load stale on maps while the rebuilt view
	# reads fresh (sim blocking diverging from rendered map).
	WISceneCatalog.reset()
	var scene_config: Dictionary = WISceneCatalog.compose()
	var skill_config: Dictionary = _load_json("res://data/skills.json")
	var combat_config := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
	}
	combat_config["quests"] = _load_json("res://data/quests.json")
	combat_config["acts"] = _load_json("res://data/acts.json")
	combat_config["leads"] = _load_json("res://data/leads.json")
	combat_config["items"] = _load_json("res://data/items.json")
	combat_config["bounties"] = _load_json("res://data/bounties.json")
	combat_config["deliveries"] = _load_json("res://data/deliveries.json")
	combat_config["portals"] = _load_json("res://data/portals.json")
	combat_config["progression"] = _load_json("res://data/progression.json")
	combat_config["fence"] = _load_json("res://data/fence_stock.json")
	var dialogue_graphs: Dictionary = {}
	var shared_banks := WIDialogueBanks.load_shared()
	var dir: DirAccess = DirAccess.open("res://data/dialogue")
	if dir != null:
		for f: String in dir.get_files():
			# Underscore files are banks/config, never conversations.
			if f.ends_with(".json") and not f.begins_with("_"):
				dialogue_graphs[f.get_basename()] = WIDialogueBanks.expand(_load_json("res://data/dialogue/" + f), shared_banks)
	combat_config["dialogue"] = dialogue_graphs
	var seed_str := String(QAPaths.user_args().get("seed", ""))
	if seed_str.is_empty() and OS.has_feature("web"):
		var js_seed: Variant = JavaScriptBridge.eval("window.__WI_QA__ ? String(window.__WI_QA__.seed ?? '') : ''", true)
		seed_str = String(js_seed) if js_seed != null else ""
	var rng_seed: int = int(seed_str) if not seed_str.is_empty() else 0
	var phase_thresholds: Dictionary = (_load_json("res://data/moods.json").get("meta", {}) as Dictionary).get("phase_thresholds", {})
	var phase_config := {
		"dusk_at": int(phase_thresholds.get("dusk", 40)),
		"night_at": int(phase_thresholds.get("night", 90)),
	}
	return WIGame.new(scene_config, skill_config, ObservableBus.emit_domain_event, rng_seed, combat_config, phase_config, creation)


func _write_slot(slot: String) -> void:
	last_save_slot = slot
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open("%s/%s.json" % [SAVE_DIR, slot], FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(WISave.serialize(sim)))
	file.close()
	ObservableBus.emit_domain_event(WIEvents.GAME_SAVED, {"slot": slot})


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
