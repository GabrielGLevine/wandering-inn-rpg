class_name WIDataRegistry
extends RefCounted
## Static loader+cache for the JSON data catalogs presentation used to load
## ad hoc (M5 arch finding 7) — biomes.json / scene config (formerly
## static vars in world.gd AND combat_screen.gd), combatants.json (formerly
## parsed inside combat_screen.gd), audio.json (formerly parsed by wi_audio).
## Mirrors WISpriteRegistry's static-cache pattern.
##
## Presentation-side only (uses res:// file reads at render time) — never
## referenced from src/core; the sim gets its configs INJECTED by the Game
## autoload (game.gd's _make_sim), which stays independent of this cache.
## Both sides call WISceneCatalog.compose() for the scene/map config —
## see scene_config() below.
##
## reset() is called by WIMain wherever game_reset/game_loaded flows, so a
## rebuilt run rereads from disk instead of trusting a stale cache.

const BIOMES_PATH := "res://data/biomes.json"
const COMBATANTS_PATH := "res://data/combatants.json"
const AUDIO_PATH := "res://data/audio.json"

static var _biomes: Dictionary = {}
static var _scene_config: Dictionary = {}
static var _combatant_configs: Dictionary = {}
static var _audio: Dictionary = {}
static var _audio_loaded := false


## Biome catalog (data/biomes.json): biome id -> tile sheet/coord config.
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


## One combatant config (data/combatants.json) by id, or {} if unknown.
static func combatant_config(id: String) -> Dictionary:
	if _combatant_configs.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMBATANTS_PATH))
		assert(parsed is Dictionary, "invalid combatants.json")
		for cfg: Dictionary in (parsed as Dictionary).get("combatants", []):
			_combatant_configs[String(cfg["id"])] = cfg
	return _combatant_configs.get(id, {})


## Raw audio event/music map (data/audio.json). A missing or unparseable file
## is NOT an error here ({} — audio is optional content), matching WIAudio's
## original graceful load; `_audio_loaded` (not emptiness) marks the attempt
## so a legitimately absent map isn't re-read on every call.
static func audio_config() -> Dictionary:
	if not _audio_loaded:
		_audio_loaded = true
		if FileAccess.file_exists(AUDIO_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUDIO_PATH))
			if parsed is Dictionary:
				_audio = parsed
	return _audio


## Drops every cached catalog so the next accessor call rereads from disk.
## Called from WIMain._on_domain_event on game_reset/game_loaded — the same
## flow that tears down and respawns the world presentation.
static func reset() -> void:
	_biomes = {}
	_scene_config = {}
	_combatant_configs = {}
	_audio = {}
	_audio_loaded = false
