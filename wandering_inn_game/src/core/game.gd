extends Node

const SAVE_DIR := "user://saves"
const MANUAL_SLOTS: Array[String] = ["manual", "manual_2", "manual_3"]

var sim: WIGame
var _autosave_announced := false
var _rotate_auto_pending := false
var _choice_snapshot_armed := false


func _ready() -> void:
	_build_sim()
	ObservableBus.domain_event.connect(_on_domain_event)


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
		save_auto()


func save_auto() -> void:
	if _rotate_auto_pending:
		_rotate_auto_pending = false
		_rotate_slot("auto", "auto_prev")
	_write_slot("auto")
	if not _autosave_announced:
		_autosave_announced = true
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Autosaved. (%s — save/load anytime)" % WIInputHints.label("cancel")})


func save_manual(slot: String = "manual") -> bool:
	if sim.combat != null or sim.dialogue != null or not sim.pending_consolidation.is_empty():
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Cannot save right now."})
		return false
	_write_slot(slot)
	ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Game saved."})
	return true


func load_slot(slot: String, reason: String = "") -> bool:
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
	var scene_config: Dictionary = WISceneCatalog.compose()
	var skill_config: Dictionary = _load_json("res://data/skills.json")
	var combat_config := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
	}
	combat_config["quests"] = _load_json("res://data/quests.json")
	combat_config["acts"] = _load_json("res://data/acts.json")
	combat_config["items"] = _load_json("res://data/items.json")
	combat_config["bounties"] = _load_json("res://data/bounties.json")
	combat_config["deliveries"] = _load_json("res://data/deliveries.json")
	combat_config["portals"] = _load_json("res://data/portals.json")
	combat_config["progression"] = _load_json("res://data/progression.json")
	combat_config["fence"] = _load_json("res://data/fence_stock.json")
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
