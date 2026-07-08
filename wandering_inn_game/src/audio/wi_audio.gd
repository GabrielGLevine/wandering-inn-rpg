extends Node
## Presentation-side audio router. Register as autoload `WIAudio`.

const SETTINGS_PATH := "user://settings.cfg"
const BUS_NAMES: Array[String] = ["Master", "Music", "SFX", "UI", "Voice"]

## Music-layer constants. Two dedicated AudioStreamPlayer nodes (never drawn
## from the SFX `_players` pool) ping-pong as the active/incoming track so a
## context switch can crossfade instead of hard-cutting.
const MUSIC_CROSSFADE_SEC := 1.0
const MUSIC_SILENCE_DB := -80.0
## Music `kind`s that represent "the field the player is standing in" (as
## opposed to a transient overlay like combat or a one-shot sting). A sting
## with `return_to_field: true` resumes whichever of these last played.
const FIELD_MUSIC_KIND := "field"

var _entries: Array[Dictionary] = []
var _last_played_ms: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _settings := ConfigFile.new()
var _observable_bus: Node = null

var _music_entries: Array[Dictionary] = []
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_index := 0
var _current_music_id := ""
var _field_context_id := ""

## Fallback-art contract (audio half). A PUBLIC checkout is
## missing the protected music/SFX packs (see assets_manifest.json). A stream
## whose id is mapped in data/audio.json but whose FILE is absent is a silent
## no-op: we skip all AudioServer/stream work but STILL emit `audio_played`
## (same "mapping validated, would have played" semantic the headless path
## already uses -- QA scripts wait on these events, so suppressing them would
## hang the fallback boot check) and log ONE `[fallback_art]` line per unique
## missing path per run. ZERO behavior change when the files are present. An
## EMPTY stream mapping (id with no `stream`) stays a push_warning -- that is
## malformed catalog data, not a missing file.
var _missing_stream_paths: Dictionary = {}


func _ready() -> void:
	if not _is_headless():
		_setup_buses()
		_load_settings()
		_setup_music_players()
	_load_audio_map()
	_observable_bus = get_node_or_null("/root/ObservableBus")
	if _observable_bus != null:
		_observable_bus.domain_event.connect(_on_domain_event)


## Bug fix: `OS.has_feature("headless")` only reflects a dedicated
## headless *export template* build -- it returns false for the regular
## editor/debug binary even when launched with the `--headless` CLI flag,
## which is how every QA script in this repo runs. Every prior `OS.has_
## feature("headless")` check in this file (both A1's SFX gate and A2's
## first-draft music gate) was therefore silently dead code: "headless" QA
## runs were actually creating buses/players and loading+playing real audio
## streams the whole time. `DisplayServer.get_name() == "headless"` is the
## correct check -- it's already the established idiom elsewhere in this
## repo (see src/combat/combat_screen.gd's AI-beat pacing gate) and was
## confirmed here by A/B testing: a tiny probe script printed `false` for
## `OS.has_feature("headless")` and `"headless"` for `DisplayServer.get_
## name()` under an identical `--headless` invocation. This also explains
## the cross-lane-tracked "N ObjectDB instances leaked at exit" / "resources
## still in use" warning (progress.md: "suspect audio autoload") --
## AudioStreamOggVorbis playback objects were being created and never
## properly torn down because there is no real audio device in this
## environment even though the flag was accepted.
func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _exit_tree() -> void:
	if _observable_bus != null and _observable_bus.domain_event.is_connected(_on_domain_event):
		_observable_bus.domain_event.disconnect(_on_domain_event)


## Public API for settings UIs. `value_0_to_10` is clamped and persisted.
func set_bus_volume(bus: String, value_0_to_10: float) -> void:
	if not BUS_NAMES.has(bus):
		return
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	var clamped := clampf(value_0_to_10, 0.0, 10.0)
	var linear := clamped / 10.0
	AudioServer.set_bus_mute(index, linear <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	_settings.set_value("audio", bus, clamped)
	_settings.save(SETTINGS_PATH)


func get_bus_volume(bus: String) -> float:
	if _settings.has_section_key("audio", bus):
		return float(_settings.get_value("audio", bus, 10.0))
	return 10.0


func _setup_buses() -> void:
	for bus: String in BUS_NAMES:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus(AudioServer.get_bus_count())
		var index := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(index, bus)
		if bus != "Master":
			AudioServer.set_bus_send(index, "Master")


## Two persistent Music-bus players used as crossfade partners. Never headless
## (guarded by the `_ready` caller) -- there is no AudioServer/device work to
## do without a real audio backend.
func _setup_music_players() -> void:
	for _i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = MUSIC_SILENCE_DB
		add_child(player)
		_music_players.append(player)


func _load_settings() -> void:
	_settings.load(SETTINGS_PATH)
	for bus: String in BUS_NAMES:
		set_bus_volume(bus, float(_settings.get_value("audio", bus, 10.0)))


## Consumes the shared WIDataRegistry cache (M5 arch finding 7) — a missing/
## invalid data/audio.json is an empty Dictionary there, preserving this
## file's original graceful no-audio-map behavior.
func _load_audio_map() -> void:
	var parsed := WIDataRegistry.audio_config()
	var raw_entries: Variant = parsed.get("events", [])
	if raw_entries is Array:
		for raw_entry: Variant in raw_entries:
			if raw_entry is Dictionary:
				_entries.append(raw_entry)

	var raw_music: Variant = parsed.get("music", [])
	if raw_music is Array:
		for raw_entry: Variant in raw_music:
			if raw_entry is Dictionary:
				_music_entries.append(raw_entry)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if type == WIEvents.AUDIO_PLAYED:
		return  # re-entrancy guard: never let our own emission trigger another lookup
	for entry: Dictionary in _entries:
		if String(entry.get("event", "")) != type:
			continue
		if not _payload_matches(payload, entry.get("payload", {})):
			continue
		_play_entry(entry)
	_dispatch_music_event(type, payload)


func _payload_matches(payload: Dictionary, expected_variant: Variant) -> bool:
	if not expected_variant is Dictionary:
		return true
	var expected: Dictionary = expected_variant
	for key: Variant in expected.keys():
		if not payload.has(key):
			return false
		if payload[key] != expected[key]:
			return false
	return true


func _play_entry(entry: Dictionary) -> void:
	var id := String(entry.get("id", ""))
	if id.is_empty():
		return
	var now_ms := Time.get_ticks_msec()
	var cooldown_ms := int(entry.get("cooldown_ms", 0))
	if cooldown_ms > 0 and _last_played_ms.has(id) and now_ms - int(_last_played_ms[id]) < cooldown_ms:
		return
	_last_played_ms[id] = now_ms

	var stream_path := String(entry.get("stream", ""))
	if stream_path.is_empty():
		push_warning("WIAudio: bad/missing stream for id '%s': %s" % [id, stream_path])
		return
	var missing := not ResourceLoader.exists(stream_path)
	if missing:
		_log_missing_stream(stream_path)
	var bus := String(entry.get("bus", "SFX"))
	if not BUS_NAMES.has(bus):
		push_warning("WIAudio: unknown bus '%s' for id '%s'" % [bus, id])
		return

	## Headless: `audio_played` means "mapping validated + would have played",
	## NOT "sound rendered" — no AudioServer/stream/player work happens below
	## this point, since there is no audio device to render to in this mode.
	## `missing` (R2 fallback) joins this short-circuit: silent no-op, event
	## still emitted so QA scripts waiting on `audio_played` don't hang.
	if missing or _is_headless():
		_emit_audio_played(id, bus)
		return

	if AudioServer.get_bus_index(bus) == -1:
		push_warning("WIAudio: bus '%s' not present on AudioServer for id '%s'" % [bus, id])
		return

	var stream := load(stream_path) as AudioStream
	if stream == null:
		push_warning("WIAudio: failed to load stream for id '%s': %s" % [id, stream_path])
		return
	var player := _player_for(stream.get_length())
	player.stream = stream
	player.bus = bus
	player.volume_db = float(entry.get("volume_db", 0.0))
	player.play()
	_emit_audio_played(id, bus)


func _player_for(length_sec: float) -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			return player
	var player := AudioStreamPlayer.new()
	player.max_polyphony = 4
	add_child(player)
	_players.append(player)
	if length_sec > 0.0:
		var cleanup_delay := maxf(length_sec + 0.25, 0.5)
		get_tree().create_timer(cleanup_delay).timeout.connect(_trim_idle_players)
	return player


func _trim_idle_players() -> void:
	var kept: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in _players:
		if player.playing:
			kept.append(player)
			continue
		player.queue_free()
	_players = kept


func _emit_audio_played(id: String, bus: String) -> void:
	if _observable_bus != null:
		_observable_bus.emit_domain_event(WIEvents.AUDIO_PLAYED, {"id": id, "bus": bus})


## One `[fallback_art]` line per unique missing stream per run. A plain print
## (NOT push_warning) so the grep discipline (SCRIPT ERROR|Parse Error|WARNING)
## is not tripped; check_fallback_boot.sh additionally expects these lines.
func _log_missing_stream(path: String) -> void:
	if _missing_stream_paths.has(path):
		return
	_missing_stream_paths[path] = true
	print("[fallback_art] missing audio: %s" % path)


## `world_ready` carries no map payload (see world.gd), so the boot/post-load
## field context is resolved by reading `Game.sim.current_map` directly
## rather than via a data-driven event+payload match. Every other music
## context switch is fully data-driven from `data/audio.json`'s `music` list.
func _dispatch_music_event(type: String, payload: Dictionary) -> void:
	if type == WIEvents.WORLD_READY:
		_sync_field_music_to_current_map()
		return
	for entry: Dictionary in _music_entries:
		if String(entry.get("event", "")) != type:
			continue
		if not _payload_matches(payload, entry.get("payload", {})):
			continue
		_play_music_entry(entry)
		return


func _sync_field_music_to_current_map() -> void:
	var game := get_node_or_null("/root/Game")
	if game == null or not ("sim" in game) or game.sim == null:
		return
	var map_id := String(game.sim.current_map)
	for entry: Dictionary in _music_entries:
		if String(entry.get("kind", "")) != FIELD_MUSIC_KIND:
			continue
		if String(entry.get("context", "")) != map_id:
			continue
		_play_music_entry(entry)
		return


func _play_music_entry(entry: Dictionary) -> void:
	var id := String(entry.get("id", ""))
	if id.is_empty() or id == _current_music_id:
		return
	var stream_path := String(entry.get("stream", ""))
	if stream_path.is_empty():
		push_warning("WIAudio: bad/missing music stream for id '%s': %s" % [id, stream_path])
		return
	var missing := not ResourceLoader.exists(stream_path)
	if missing:
		_log_missing_stream(stream_path)
	var bus := String(entry.get("bus", "Music"))
	if not BUS_NAMES.has(bus):
		push_warning("WIAudio: unknown music bus '%s' for id '%s'" % [bus, id])
		return

	if String(entry.get("kind", "")) == FIELD_MUSIC_KIND:
		_field_context_id = id
	_current_music_id = id

	## Headless: same "mapping validated + would have played" semantics as
	## SFX (`_play_entry`) -- no AudioServer/stream/crossfade work happens
	## below this point, and no wall-clock waiting for a sting to "finish" is
	## ever introduced into a headless run. `missing` (R2 fallback) joins this
	## short-circuit: silent no-op with the event still emitted.
	if missing or _is_headless():
		_emit_audio_played(id, bus)
		return

	if AudioServer.get_bus_index(bus) == -1:
		push_warning("WIAudio: bus '%s' not present on AudioServer for id '%s'" % [bus, id])
		return
	var stream := load(stream_path) as AudioStream
	if stream == null:
		push_warning("WIAudio: failed to load music stream for id '%s': %s" % [id, stream_path])
		return

	## Godot 4.7 does not auto-detect the LOOPSTART/LOOPLENGTH Vorbis comments
	## some packs (xDeviruchi) embed -- confirmed against the class docs for
	## AudioStreamOggVorbis / ResourceImporterOggVorbis. `loop`/`loop_offset`
	## are set directly on the loaded resource instance instead; both are
	## documented as settable from code, and this avoids depending on
	## hand-edited/regenerable `.import` overrides.
	if stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop = bool(entry.get("loop", true))
		if entry.has("loop_offset_sec"):
			ogg.loop_offset = float(entry["loop_offset_sec"])

	_crossfade_to_music(stream, bus, float(entry.get("volume_db", -6.0)), bool(entry.get("return_to_field", false)))
	_emit_audio_played(id, bus)


func _crossfade_to_music(stream: AudioStream, bus: String, target_db: float, return_to_field: bool) -> void:
	if _music_players.size() < 2:
		return
	var old_player := _music_players[_active_music_index]
	var new_index := 1 - _active_music_index
	var new_player := _music_players[new_index]

	if new_player.finished.is_connected(_on_music_sting_finished):
		new_player.finished.disconnect(_on_music_sting_finished)

	new_player.stream = stream
	new_player.bus = bus
	new_player.volume_db = MUSIC_SILENCE_DB
	new_player.play()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(new_player, "volume_db", target_db, MUSIC_CROSSFADE_SEC)
	if old_player != new_player and old_player.playing:
		tween.tween_property(old_player, "volume_db", MUSIC_SILENCE_DB, MUSIC_CROSSFADE_SEC)
	tween.chain().tween_callback(func() -> void:
		if old_player != new_player and old_player.playing:
			old_player.stop()
	)

	_active_music_index = new_index
	## Non-looping "sting" contexts (e.g. victory) resume the last field
	## track once playback naturally ends -- `finished` never fires for a
	## looping stream, so this is inert for every other context.
	if return_to_field:
		new_player.finished.connect(_on_music_sting_finished, CONNECT_ONE_SHOT)


func _on_music_sting_finished() -> void:
	for entry: Dictionary in _music_entries:
		if String(entry.get("id", "")) == _field_context_id:
			_play_music_entry(entry)
			return
