class_name WIDataRegistry
extends RefCounted

const BIOMES_PATH := "res://data/biomes.json"
const COMBATANTS_PATH := "res://data/combatants.json"
const AUDIO_PATH := "res://data/audio.json"

static var _biomes: Dictionary = {}
static var _scene_config: Dictionary = {}
static var _combatant_configs: Dictionary = {}
static var _audio: Dictionary = {}
static var _audio_loaded := false


static func biomes() -> Dictionary:
	if _biomes.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BIOMES_PATH))
		assert(parsed is Dictionary, "invalid biomes.json")
		_biomes = parsed
	return _biomes


## Raw scene/map config, composed from data/maps/<region>/<map>.json +
## data/scene_root.json (issue #100) — the SAME composer the Game autoload
## calls to build the sim's own config; presentation reads the render-only
## passthrough fields (biome/floor_layers/walls/decor/player sprite) from
## here. Own cache/reset stays independent of WISceneCatalog's internal
## one (same contract as before the split — see reset() below).
static func scene_config() -> Dictionary:
	if _scene_config.is_empty():
		_scene_config = WISceneCatalog.compose()
	return _scene_config


static func combatant_config(id: String) -> Dictionary:
	if _combatant_configs.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMBATANTS_PATH))
		assert(parsed is Dictionary, "invalid combatants.json")
		for cfg: Dictionary in (parsed as Dictionary).get("combatants", []):
			_combatant_configs[String(cfg["id"])] = cfg
	return _combatant_configs.get(id, {})


static func audio_config() -> Dictionary:
	if not _audio_loaded:
		_audio_loaded = true
		if FileAccess.file_exists(AUDIO_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUDIO_PATH))
			if parsed is Dictionary:
				_audio = parsed
	return _audio


static func reset() -> void:
	_biomes = {}
	_scene_config = {}
	_combatant_configs = {}
	_audio = {}
	_audio_loaded = false
