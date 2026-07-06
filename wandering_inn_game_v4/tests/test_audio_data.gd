extends SceneTree
## Validates the audio event map.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_audio_data.gd

const VALID_BUSES: Dictionary = {
	"Master": true,
	"Music": true,
	"SFX": true,
	"UI": true,
	"Voice": true,
}

const KNOWN_EVENTS: Dictionary = {
	"action_refused": true,
	"audio_played": true,
	"attack_resolved": true,
	"class_gained": true,
	"class_level_up": true,
	"combatant_downed": true,
	"combat_finished": true,
	"combat_resolved": true,
	"combat_started": true,
	"dashed": true,
	"dialogue_choice": true,
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
	"ui_dialogue_shown": true,
	"ui_pause_hidden": true,
	"ui_pause_shown": true,
	"ui_title_rendered": true,
	"ui_toast_rendered": true,
	"unit_downed": true,
}

const REQUIRED_IDS: Array[String] = [
	"menu_move",
	"menu_confirm",
	"dialogue_open",
	"dialogue_choice",
	"toast",
	"footstep",
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
]

## `context` is a human label (title / map id / combat / victory); `kind`
## drives WIAudio's runtime behavior (field-context tracking, sting
## return-to-field wiring) and must be one of these.
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
	quit(1)


func _init() -> void:
	WITestWatchdog.arm(self)
	var config := _load("res://data/audio.json")
	if not config.has("events"):
		_fail("audio.json missing events")
	if not config["events"] is Array:
		_fail("audio.json events must be an array")

	var ids := {}
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
		if not stream.begins_with("res://assets/audio/"):
			_fail("audio stream outside assets/audio: %s" % stream)
		if not (stream.ends_with(".wav") or stream.ends_with(".ogg")):
			_fail("audio stream must be WAV or OGG: %s" % stream)
		if not FileAccess.file_exists(stream):
			_fail("missing audio stream for %s: %s" % [id, stream])

		var cooldown := int(entry.get("cooldown_ms", 0))
		if cooldown < 0:
			_fail("cooldown_ms must be non-negative for %s" % id)
		var volume_db := float(entry.get("volume_db", 0.0))
		if volume_db < -80.0 or volume_db > 12.0:
			_fail("volume_db out of range for %s" % id)

	for required_id: String in REQUIRED_IDS:
		if not ids.has(required_id):
			_fail("missing required audio id: " + required_id)

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
		if not FileAccess.file_exists(stream):
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

	print("PASS: audio data is well-formed and cross-referenced")
	quit(0)
