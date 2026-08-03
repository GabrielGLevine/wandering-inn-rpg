extends SceneTree

const VALID_BUSES: Dictionary = {
	"Master": true,
	"Music": true,
	"SFX": true,
	"UI": true,
	"Voice": true,
	"Ambience": true,
}

## Whitelist of bus events an `audio.json` row may key on. Extending it is part
## of the SAME edit unit as adding the row it legalises -- a row for an event
## missing here fails this gate, so the table can never drift ahead of the
## catalog. The four v0.17 L3 entries below (GH#335 phase 1, item 4) close the
## "explicit input, zero response" gaps: item_used / player_blocked /
## skill_no_effect, plus class_evolved, the largest completion in the game and
## the only progression beat with no sound at all.
const KNOWN_EVENTS: Dictionary = {
	"action_refused": true,
	"audio_played": true,
	"attack_resolved": true,
	"class_evolved": true,  # v0.17 L3 (GH#335)
	"class_gained": true,
	"class_level_up": true,
	"item_used": true,  # v0.17 L3 (GH#335)
	"player_blocked": true,  # v0.17 L3 (GH#335)
	"skill_no_effect": true,  # v0.17 L3 (GH#335)
	"combatant_downed": true,
	"combat_finished": true,
	"combat_resolved": true,
	"combat_started": true,
	"dashed": true,
	"dialogue_choice": true,
	"dialogue_ended": true,
	"dialogue_started": true,
	"game_loaded": true,
	"game_reset": true,
	"item_equipped": true,
	"item_gained": true,
	"map_changed": true,
	"player_moved": true,
	"ui_inventory_hidden": true,
	"ui_inventory_shown": true,
	"quest_beat_completed": true,
	"quest_completed": true,
	"quest_started": true,
	"reaction_triggered": true,
	"save_completed": true,
	"skill_resolved": true,
	"skill_used": true,
	"toast": true,
	"ui_combat_beat": true,
	"ui_dialogue_shown": true,
	"ui_dialogue_line_hidden": true,
	"ui_pause_hidden": true,
	"ui_pause_shown": true,
	"ui_sleep_veil_rendered": true,
	"ui_title_rendered": true,
	"ui_toast_rendered": true,
	"unit_downed": true,
	"windup_declared": true,
}

const REQUIRED_IDS: Array[String] = [
	"menu_move",
	"menu_confirm",
	"dialogue_open",
	"dialogue_choice",
	"toast",
	"footstep_wood",
	"footstep_stone",
	"footstep_earth",
	"attack_hit",
	"attack_miss",
	"skill_cast_physical",
	"skill_cast_fire",
	"skill_cast_frost",
	"skill_cast_arcane",
	"dash",
	"downed",
	"victory",
	"defeat",
	"level_up",
	"class_gained",
	"quest_chime",
	"save_chime",
	"door_transition",
	"item_pickup",
	"item_equip",
	"ui_open",
	"ui_close",
	"skill_windup_tell",
	"field_skill_used",
	"pc_hurt",
	"pc_death",
]

const VALID_FOOTSTEP_FAMILIES: Dictionary = {
	"wood": true,
	"stone": true,
	"earth": true,
}

const VALID_MUSIC_KINDS: Dictionary = {
	"title": true,
	"field": true,
	"combat": true,
	"sting": true,
}

const REQUIRED_MUSIC_IDS: Array[String] = [
	"music_title",
	"music_inn",
	"music_street",
	"music_combat",
	"music_victory",
	"music_combat_vault",
	"music_defeat",
	"music_sleep_beat",
]

const REQUIRED_AMBIENCE_IDS: Array[String] = [
	"ambience_inn",
	"ambience_street",
	"ambience_floodplains",
	"ambience_sewers",
	"ambience_trapped_halls",
]


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("missing file: " + path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_fail("invalid JSON: " + path)
	return parsed


func _fail(message: String) -> void:
	push_error(message)
	assert(false, message)


var _manifest_paths := {}


func _stream_ok(stream: String) -> bool:
	if FileAccess.file_exists(stream):
		return true
	if _manifest_paths.is_empty() and FileAccess.file_exists("res://assets_manifest.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets_manifest.json"))
		var entries: Variant = parsed.get("assets", parsed) if parsed is Dictionary else parsed
		if entries is Array:
			for e: Variant in entries:
				var path := String(e["path"]) if e is Dictionary else String(e)
				_manifest_paths[path] = true
	return _manifest_paths.has(stream.trim_prefix("res://"))


func _init() -> void:
	WITestWatchdog.arm(self)
	var config := _load("res://data/audio.json")
	if not config.has("events"):
		_fail("audio.json missing events")
	if not config["events"] is Array:
		_fail("audio.json events must be an array")
	var biomes := _load("res://data/biomes.json")
	for biome_id: String in biomes:
		var biome: Dictionary = biomes[biome_id]
		var family := String(biome.get("footstep_family", ""))
		if not VALID_FOOTSTEP_FAMILIES.has(family):
			_fail("biome %s has invalid/missing footstep_family: %s" % [biome_id, family])

	var ids := {}
	var footstep_families := {}
	for entry: Dictionary in config["events"]:
		for key: String in ["id", "event", "stream", "bus"]:
			if not entry.has(key):
				_fail("audio entry missing %s: %s" % [key, JSON.stringify(entry)])

		var id := String(entry["id"])
		var event_type := String(entry["event"])
		var stream := String(entry["stream"])
		var bus := String(entry["bus"])
		if ids.has(id):
			_fail("duplicate audio id: " + id)
		ids[id] = true

		if not KNOWN_EVENTS.has(event_type):
			_fail("unknown audio event type: %s for %s" % [event_type, id])
		if not VALID_BUSES.has(bus):
			_fail("invalid audio bus: %s for %s" % [bus, id])
		if id in ["pc_hurt", "pc_death"] and bus != "Voice":
			_fail("combat bark must ride Voice bus: " + id)
		if not stream.begins_with("res://assets/audio/"):
			_fail("audio stream outside assets/audio: %s" % stream)
		if not (stream.ends_with(".wav") or stream.ends_with(".ogg")):
			_fail("audio stream must be WAV or OGG: %s" % stream)
		# GH#277: `pending: true` marks a slot merged ahead of its file --
		# existence is waived HERE only; ship_asset_scan.py FAILS the
		# release cut on any pending row, so a pending slot can live on
		# main but can never reach itch. Every other shape rule still
		# applies (prefix, extension, bus).
		if entry.has("pending") and typeof(entry["pending"]) != TYPE_BOOL:
			_fail("pending must be a bool: %s" % id)
		if not bool(entry.get("pending", false)) and not _stream_ok(stream):
			_fail("missing audio stream for %s: %s" % [id, stream])
		# v0.16.1 finding 23: combat-beat SFX must ride the PLAYBACK clock, not
		# the sim clock -- an AI turn is emitted synchronously while its visuals
		# unspool one beat_delay() apart, so a raw-event row is heard seconds
		# before its animation. These four types are therefore forbidden as raw
		# event keys; they key off `ui_combat_beat` and name themselves in
		# `beat_type`. (`dashed`/`combat_finished` stay raw -- scope is this set.)
		if event_type in ["attack_resolved", "combatant_downed", "skill_resolved", "reaction_triggered"]:
			_fail("combat-beat audio must key off ui_combat_beat + payload.beat_type, not the raw %s event: %s" % [event_type, id])
		if event_type == "ui_combat_beat":
			var beat_payload: Dictionary = entry.get("payload", {})
			var beat_type := String(beat_payload.get("beat_type", ""))
			if not beat_type in ["attack_resolved", "combatant_downed", "skill_resolved", "reaction_triggered"]:
				_fail("ui_combat_beat row %s has invalid/missing payload.beat_type: %s" % [id, beat_type])

		if event_type == "player_moved":
			var payload: Dictionary = entry.get("payload", {})
			var family := String(payload.get("floor_family", ""))
			if not VALID_FOOTSTEP_FAMILIES.has(family):
				_fail("movement audio %s has invalid/missing floor_family: %s" % [id, family])
			if id != "footstep_" + family:
				_fail("movement audio id/family drift: %s vs %s" % [id, family])
			footstep_families[family] = true

		if entry.has("variants"):
			var variants_variant: Variant = entry["variants"]
			if not variants_variant is Array:
				_fail("variants must be an array for %s" % id)
			var variant_list: Array = variants_variant
			if variant_list.size() < 2:
				_fail("variants must have at least 2 entries for %s" % id)
			if String(variant_list[0]) != stream:
				_fail("stream must equal variants[0] for %s (drift tripwire)" % id)
			for variant: Variant in variant_list:
				var variant_path := String(variant)
				if not variant_path.begins_with("res://assets/audio/"):
					_fail("audio variant stream outside assets/audio: %s" % variant_path)
				if not (variant_path.ends_with(".wav") or variant_path.ends_with(".ogg")):
					_fail("audio variant stream must be WAV or OGG: %s" % variant_path)
				if not _stream_ok(variant_path):
					_fail("missing audio variant stream for %s: %s" % [id, variant_path])
		if entry.has("pitch_variants"):
			if not entry["pitch_variants"] is Array:
				_fail("pitch_variants must be an array for %s" % id)
			var pitch_variants: Array = entry["pitch_variants"]
			var stream_variants: Array = entry.get("variants", [])
			if pitch_variants.size() != stream_variants.size():
				_fail("pitch_variants/variants size drift for %s" % id)
			for pitch: Variant in pitch_variants:
				if float(pitch) < 0.5 or float(pitch) > 2.0:
					_fail("pitch variant out of range for %s: %s" % [id, pitch])

		var cooldown := int(entry.get("cooldown_ms", 0))
		if cooldown < 0:
			_fail("cooldown_ms must be non-negative for %s" % id)
		var volume_db := float(entry.get("volume_db", 0.0))
		if volume_db < -80.0 or volume_db > 12.0:
			_fail("volume_db out of range for %s" % id)

	for required_id: String in REQUIRED_IDS:
		if not ids.has(required_id):
			_fail("missing required audio id: " + required_id)
	for family: String in VALID_FOOTSTEP_FAMILIES:
		if not footstep_families.has(family):
			_fail("missing movement audio for footstep family: " + family)
	var audio_source := FileAccess.get_file_as_string("res://src/audio/wi_audio.gd")
	# CONTRACT: presentation round-robin may read current_map, never gameplay RNG state.
	for forbidden: String in ["game.sim._rng", "Game.sim._rng", "game.sim.rng", "Game.sim.rng"]:
		if audio_source.contains(forbidden):
			_fail("WIAudio must not consume gameplay RNG: " + forbidden)
	var play_start := audio_source.find("func _play_entry")
	var play_end := audio_source.find("func _player_for", play_start)
	var play_source := audio_source.substr(play_start, play_end - play_start)
	if play_source.contains("rand") or not play_source.contains("_variant_index[id] = (variant_idx + 1)"):
		_fail("WIAudio variants must use the deterministic round-robin cursor")
	for required_source: String in [
		"get_bus_volume(bus)",
		"base_db + offset_db",
		"player.pitch_scale = pitch_scale",
		"_duck_transient(DIALOGUE_BARK_DUCK_SEC, TRANSIENT_DIALOGUE_BARK)",
		"if bus == \"Voice\":",
		"type == WIEvents.COMBAT_STARTED or type == WIEvents.MAP_CHANGED",
		"type == WIEvents.UI_DIALOGUE_LINE_HIDDEN"
	]:
		if not audio_source.contains(required_source):
			_fail("WIAudio contract source missing: " + required_source)

	if not config.has("music"):
		_fail("audio.json missing music")
	if not config["music"] is Array:
		_fail("audio.json music must be an array")

	for entry: Dictionary in config["music"]:
		for key: String in ["id", "kind", "context", "event", "stream", "bus"]:
			if not entry.has(key):
				_fail("music entry missing %s: %s" % [key, JSON.stringify(entry)])

		var id := String(entry["id"])
		var kind := String(entry["kind"])
		var event_type := String(entry["event"])
		var stream := String(entry["stream"])
		var bus := String(entry["bus"])
		if ids.has(id):
			_fail("duplicate audio id: " + id)
		ids[id] = true

		if not VALID_MUSIC_KINDS.has(kind):
			_fail("unknown music kind: %s for %s" % [kind, id])
		if not KNOWN_EVENTS.has(event_type):
			_fail("unknown audio event type: %s for %s" % [event_type, id])
		if bus != "Music":
			_fail("music entry must ride the Music bus: %s for %s" % [bus, id])
		if not stream.begins_with("res://assets/audio/music/"):
			_fail("music stream outside assets/audio/music: %s" % stream)
		if not stream.ends_with(".ogg"):
			_fail("music stream must be OGG: %s" % stream)
		if entry.has("pending") and typeof(entry["pending"]) != TYPE_BOOL:
			_fail("pending must be a bool: %s" % id)
		if not bool(entry.get("pending", false)) and not _stream_ok(stream):
			_fail("missing music stream for %s: %s" % [id, stream])

		var volume_db := float(entry.get("volume_db", 0.0))
		if volume_db < -80.0 or volume_db > 12.0:
			_fail("volume_db out of range for %s" % id)

		if entry.has("loop") and typeof(entry["loop"]) != TYPE_BOOL:
			_fail("music loop must be a bool for %s" % id)
		if entry.has("loop_offset_sec"):
			_fail("music loop_offset_sec is forbidden for curated Loopable OGG tracks: %s" % id)
		if entry.has("return_to_field") and typeof(entry["return_to_field"]) != TYPE_BOOL:
			_fail("music return_to_field must be a bool for %s" % id)

	for required_id: String in REQUIRED_MUSIC_IDS:
		if not ids.has(required_id):
			_fail("missing required music id: " + required_id)

	if not config.has("ambience"):
		_fail("audio.json missing ambience")
	if not config["ambience"] is Array:
		_fail("audio.json ambience must be an array")

	for entry: Dictionary in config["ambience"]:
		for key: String in ["id", "kind", "context", "event", "payload", "stream", "bus"]:
			if not entry.has(key):
				_fail("ambience entry missing %s: %s" % [key, JSON.stringify(entry)])

		var id := String(entry["id"])
		var kind := String(entry["kind"])
		var event_type := String(entry["event"])
		var stream := String(entry["stream"])
		var bus := String(entry["bus"])
		if ids.has(id):
			_fail("duplicate audio id: " + id)
		ids[id] = true

		if kind != "ambience":
			_fail("ambience entry kind must be 'ambience': %s for %s" % [kind, id])
		if event_type != "map_changed":
			_fail("ambience entry must be map_changed-keyed: %s for %s" % [event_type, id])
		if bus != "Ambience":
			_fail("ambience entry must ride the Ambience bus: %s for %s" % [bus, id])
		if not entry["payload"] is Dictionary:
			_fail("ambience payload must be a dict for %s" % id)
		var ambience_payload: Dictionary = entry["payload"]
		if String(ambience_payload.get("map", "")) != String(entry["context"]):
			_fail("ambience payload.map must equal context (drift tripwire) for %s" % id)
		if not stream.begins_with("res://assets/audio/ambience/"):
			_fail("ambience stream outside assets/audio/ambience: %s" % stream)
		if not stream.ends_with(".ogg"):
			_fail("ambience stream must be OGG: %s" % stream)
		if entry.has("pending") and typeof(entry["pending"]) != TYPE_BOOL:
			_fail("pending must be a bool: %s" % id)
		if not bool(entry.get("pending", false)) and not FileAccess.file_exists(stream):
			_fail("missing ambience stream for %s: %s (CC0/public tier -- the manifest relaxation does NOT apply)" % [id, stream])

		var ambience_volume_db := float(entry.get("volume_db", 0.0))
		if ambience_volume_db < -80.0 or ambience_volume_db > 12.0:
			_fail("volume_db out of range for %s" % id)
		if entry.has("loop") and typeof(entry["loop"]) != TYPE_BOOL:
			_fail("ambience loop must be a bool for %s" % id)
		if entry.has("return_to_field"):
			_fail("ambience entries never return_to_field (beds are loops, not stings): %s" % id)

	for required_id: String in REQUIRED_AMBIENCE_IDS:
		if not ids.has(required_id):
			_fail("missing required ambience id: " + required_id)

	print("PASS: audio data is well-formed and cross-referenced")
	quit(0)
