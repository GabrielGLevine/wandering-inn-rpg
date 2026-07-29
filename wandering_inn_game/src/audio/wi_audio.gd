extends Node
## Presentation-side audio router. Register as autoload `WIAudio`.

const SETTINGS_PATH := "user://settings.cfg"
const BUS_NAMES: Array[String] = ["Master", "Music", "SFX", "UI", "Voice", "Ambience"]

## Music-layer constants. Two dedicated AudioStreamPlayer nodes (never drawn
## from the SFX `_players` pool) ping-pong as the active/incoming track so a
## context switch can crossfade instead of hard-cutting.
const MUSIC_CROSSFADE_SEC := 1.0
const MUSIC_SILENCE_DB := -80.0
## Music `kind`s that represent "the field the player is standing in" (as
## opposed to a transient overlay like combat or a one-shot sting). A sting
## with `return_to_field: true` resumes whichever of these last played.
const FIELD_MUSIC_KIND := "field"

## Dialogue sidechains Music + Ambience buses, independent of active players.
## Real headless: AudioServer bus volume_db is a Server-side float, the same
## "cheap op, zero ObjectDB risk" class as _setup_buses/_load_settings above
## (contrast _setup_music_players, which stays gated because IT creates
## AudioStreamPlayer objects) -- so ducking runs unconditionally, provable via
## a real AudioServer.get_bus_volume_db read in headless QA.
const MUSIC_DUCK_DB := -6.0
const MUSIC_DUCK_FADE_SEC := 0.2
const DUCKED_BUSES: Array[String] = ["Music", "Ambience"]
const DIALOGUE_BARK_DUCK_SEC := 4.2
const VOICE_BARK_DUCK_SEC := 2.0
const QA_BARK_DUCK_SEC := 0.5
const DEFAULT_FOOTSTEP_FAMILY := "stone"
const TRANSIENT_DIALOGUE_BARK := "dialogue_bark"
const TRANSIENT_VOICE_BARK := "voice_bark"

var _entries: Array[Dictionary] = []
var _last_played_ms: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _settings := ConfigFile.new()
var _observable_bus: Node = null

## Round-robin cursor for `variants`-bearing entries (footstep surfaces, PC
## hurt barks, ...), keyed by entry id. Deterministic, presentation-side only
## -- never reads from the sim's own RNG stream (see the `variants` doc
## comment on `_play_entry` for why that matters).
var _variant_index: Dictionary = {}

## Ducking re-entrancy depth: nested duck requests (e.g. dialogue opening
## twice in the same beat, defensively) share ONE duck -- only the request
## that brings the depth back to 0 actually restores the bus.
## TRAP: conversations use matched start/end edges; dialogue/Voice barks add
## timer-matched edges. A code path that opens a dialogue then omits
## DIALOGUE_ENDED would leave this stuck positive forever, parking both bed
## buses at MUSIC_DUCK_DB with no dialogue left alive to release them. Not
## reachable via any current UI path (dialogue swallows the pause key, so a
## mid-conversation GAME_LOADED/GAME_RESET can't fire today), but
## `_reset_duck()` (called from `_on_domain_event` on GAME_RESET/
## GAME_LOADED) is the belt-and-suspenders guard for the next code path that
## bypasses WIDialogue's own end sequence -- keep it wired if this field's
## write sites ever grow a new one.
var _duck_depth := 0
var _duck_tweens: Dictionary = {}
var _transient_ducks: Dictionary = {}
var _next_transient_duck_id := 0

var _music_entries: Array[Dictionary] = []
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_index := 0
var _current_music_id := ""
var _current_music_stream_path := ""
var _field_context_id := ""
## Set by a GAME_LOADED carrying reason "defeat"; cleared by the defeat veil's
## own finish (or by any other load/reset). While set, WORLD_READY does NOT
## re-sync the field bed -- the defeat presentation owns that moment. See
## finding 24's comment in `_on_domain_event`.
var _defeat_reload_pending := false
## The live crossfade Tween, if any -- killed before scheduling a new one
## (see `_crossfade_to_music`'s doc comment for the double-trigger ordering
## trap this guards).
var _music_tween: Tween

## Issue #76 remainder: per-map ambient beds (crowd murmur, drips, hum) on a
## dedicated "Ambience" bus -- a LAYOUT bus (default_bus_layout.tres, the
## web-silence lesson: a runtime AudioServer.add_bus is invisible to the web
## sample-playback path, ee5cc61), sending straight to Master, so bed volume
## is governed by the Master slider only (the settings panel's rows are
## pinned -- no per-bed slider this wave, disclosed). The machinery below is
## a deliberate MIRROR of the music layer (own entry list from audio.json's
## `ambience` array, own crossfade player pair, own current-id guard) --
## never merged into it, because the two layers PLAY SIMULTANEOUSLY (a bed
## loops under the field track) and music's first-match-wins dispatch
## `return`s after one hit per event. One asymmetry with the field-music
## layer: most maps carry NO bed, and entering one must fade the previous
## map's bed OUT (`_stop_ambience`) instead of letting it bleed -- field
## music has a row for every map, so it never needed that arm.
var _ambience_entries: Array[Dictionary] = []
var _ambience_players: Array[AudioStreamPlayer] = []
var _active_ambience_index := 0
var _current_ambience_id := ""
var _ambience_tween: Tween

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
	# Issue #77 fix: bus-graph setup + settings load are cheap Server-side data
	# ops (no AudioStreamPlayer/stream objects created) -- ZERO ObjectDB-leak
	# risk, unlike playback itself. Un-gating them from `_is_headless()` is
	# what makes the SFX-bus-ignores-slider fix (and every settings.cfg-driven
	# volume) provable headless via a real `AudioServer.get_bus_volume_db`
	# assertion (settings_loop's whole point) -- previously headless never
	# created ANY bus beyond the engine's built-in "Master", so
	# `AudioServer.get_bus_index("SFX")` was always -1 in every QA/CI run and
	# `set_bus_volume`/`get_bus_volume` silently no-op'd. `_setup_music_players()`
	# stays gated -- THAT'S the actual AudioStreamPlayer-object leak source
	# `_is_headless()` was introduced to fix (see its own doc comment).
	_setup_buses()
	_load_settings()
	if not _is_headless():
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
	# Reload-before-save: `wi_settings.gd` (WISettings autoload) persists its
	# OWN video/accessibility sections into this SAME physical file via a
	# SEPARATE ConfigFile object. Two independent ConfigFile objects targeting
	# one file would otherwise clobber each other on `.save()` (each save
	# serializes only the sections ITS OWN in-memory copy holds) -- reloading
	# from disk immediately before mutating picks up whatever the other module
	# last wrote, so this save is always a true read-modify-write union, never
	# a stale overwrite. Cheap (small file, called only on an explicit slider
	# move, never per-frame).
	_settings.load(SETTINGS_PATH)
	_settings.set_value("audio", bus, clamped)
	_settings.save(SETTINGS_PATH)


func get_bus_volume(bus: String) -> float:
	if _settings.has_section_key("audio", bus):
		return float(_settings.get_value("audio", bus, 10.0))
	return 10.0


## Raises duck depth and (on 0->1) tweens both bed buses by MUSIC_DUCK_DB.
## A second/nested duck request while one is
## already active just adds to the depth -- it does NOT stack the tween
## (would over-duck to -12dB); see `_unduck_music`'s matching edge.
func _duck_music() -> void:
	_duck_depth += 1
	if _duck_depth > 1:
		return
	for bus: String in DUCKED_BUSES:
		_tween_music_bus_to(bus, MUSIC_DUCK_DB)


## Drops duck depth and (on 1->0) restores both bed buses. A
## release while depth is already 0 (e.g. a stray DIALOGUE_ENDED with no
## matching start) is a safe no-op, not an underflow.
func _unduck_music() -> void:
	if _duck_depth <= 0:
		return
	_duck_depth -= 1
	if _duck_depth > 0:
		return
	for bus: String in DUCKED_BUSES:
		_tween_music_bus_to(bus, 0.0)


func _duck_transient(seconds: float, kind: String) -> void:
	_duck_music()
	_next_transient_duck_id += 1
	var transient_id := _next_transient_duck_id
	_transient_ducks[transient_id] = kind
	var tree := get_tree()
	if tree == null:
		_release_transient_duck(transient_id)
		return
	var hold := QA_BARK_DUCK_SEC if _is_headless() else seconds
	# CONTRACT: every transient depth increment owns exactly one timer release.
	tree.create_timer(hold).timeout.connect(_release_transient_duck.bind(transient_id), CONNECT_ONE_SHOT)


func _release_transient_duck(transient_id: int) -> void:
	if not _transient_ducks.erase(transient_id):
		return
	_unduck_music()


func _clear_transient_ducks(kind: String = "") -> void:
	var matching: Array[int] = []
	for transient_id: int in _transient_ducks:
		if kind.is_empty() or String(_transient_ducks[transient_id]) == kind:
			matching.append(transient_id)
	for transient_id: int in matching:
		_release_transient_duck(transient_id)


## Debt-sweep fix (#76 review's minor): `_duck_depth` only ever moves via
## matched DIALOGUE_STARTED/DIALOGUE_ENDED pairs (`_duck_music`/
## `_unduck_music` above) -- a teardown that skips the matching
## DIALOGUE_ENDED (a defeat mid-conversation reaching a code path that never
## closes the dialogue cleanly, or a future walker/skip mechanism that
## bypasses WIDialogue's own end path) would leave the depth counter stuck
## positive forever, with both bed buses parked at MUSIC_DUCK_DB and no live
## dialogue left to ever release it. GAME_RESET (fresh world, title New
## Game) and GAME_LOADED (Continue/pause-Load/defeat-reload) both land on a
## world that starts with no dialogue open by construction -- zero the depth
## and restore the bus unconditionally to whatever depth it was actually
## stuck at, so a fresh/loaded world can never inherit a stale duck. No-op
## (skips the bus write entirely) when depth is already 0, the overwhelming
## common case -- byte-identical for every existing canonical, none of which
## reaches this fix's own trigger condition today.
func _reset_duck() -> void:
	_transient_ducks.clear()
	if _duck_depth == 0:
		return
	_duck_depth = 0
	for bus: String in DUCKED_BUSES:
		_tween_music_bus_to(bus, 0.0)


## Tweens one bed bus to `offset_db` relative to its settings source of truth.
## NEVER relative to whatever the bus currently reads, so repeated duck/
## unduck cycles can't drift: the un-ducked target is always re-derived from
## the same base a fresh `set_bus_volume` call would produce. Kills that
## bus's in-flight duck tween first, so a rapid edge always
## resolves to whichever call happened last, not a race between two tweens
## animating the same bus.
## Headless: sets the target dB DIRECTLY, no Tween -- headless frame deltas
## are not wall-clock-paced (a `wait_frames` loop can burn hundreds of frames
## in a fraction of MUSIC_DUCK_FADE_SEC), so a real Tween would settle at an
## unpredictable partial value depending on how many frames a QA script
## happens to wait, not a timing bug this file should paper over with a
## longer fixed wait. The FINAL value is what QA asserts either way
## (assert_audio_bus_volume_db) -- only the client-side smoothing is skipped.
func _tween_music_bus_to(bus: String, offset_db: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	var prior: Tween = _duck_tweens.get(bus)
	if prior != null and prior.is_valid():
		prior.kill()
	var linear := clampf(get_bus_volume(bus), 0.0, 10.0) / 10.0
	var base_db := linear_to_db(maxf(linear, 0.0001))
	var target_db := base_db + offset_db
	if _is_headless():
		_set_music_bus_db(target_db, bus)
		return
	var start_db := AudioServer.get_bus_volume_db(index)
	var tween := create_tween()
	# CONTRACT: each bus owns its tween; rapid edges kill only that bus's writer.
	tween.tween_method(_set_music_bus_db.bind(bus), start_db, target_db, MUSIC_DUCK_FADE_SEC)
	_duck_tweens[bus] = tween


func _set_music_bus_db(db: float, bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index != -1:
		AudioServer.set_bus_volume_db(index, db)


## Issue #77 CONFIRMED-BUG fix: every non-Master bus used to send straight to
## Master, including "UI" -- so the UI bus's own output was mixed into Master
## UNATTENUATED by anything except the Master fader itself, and the SFX
## slider (which only touches the "SFX" bus's own `volume_db`) had NO effect
## on UI sound at all (a click/menu chime stayed at full volume no matter how
## far down SFX was dragged -- the confirmed playtest bug). Fix: "UI" sends to
## "SFX" instead, making it a CHILD bus in the mix graph -- Godot audio buses
## attenuate their OWN signal via `volume_db` and then forward the RESULT to
## their send target, so SFX's fader now attenuates UI's signal too (on top
## of UI's own, still-independent fader), before the combined signal reaches
## Master. `data/audio.json` carries 11 `"bus": "UI"` events (menu/hotbar/
## dialogue chimes) that are the actual beneficiaries. Every other bus keeps
## sending straight to Master, unchanged. Provable headless (no audio device
## needed): `AudioServer.get_bus_send(AudioServer.get_bus_index("UI")) ==
## "SFX"` -- settings_loop's own bus-routing assertion, not "by ear".
func _setup_buses() -> void:
	for bus: String in BUS_NAMES:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus(AudioServer.get_bus_count())
		var index := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(index, bus)
		if bus == "UI":
			AudioServer.set_bus_send(index, "SFX")
		elif bus != "Master":
			AudioServer.set_bus_send(index, "Master")


## Two persistent Music-bus players used as crossfade partners. Never headless
## (guarded by the `_ready` caller) -- there is no AudioServer/device work to
## do without a real audio backend. The Ambience pair mirrors them exactly
## (see the `_ambience_*` field block's doc comment).
func _setup_music_players() -> void:
	for _i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = MUSIC_SILENCE_DB
		add_child(player)
		_music_players.append(player)
	for _i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Ambience"
		player.volume_db = MUSIC_SILENCE_DB
		add_child(player)
		_ambience_players.append(player)


func _load_settings() -> void:
	_settings.load(SETTINGS_PATH)
	for bus: String in BUS_NAMES:
		set_bus_volume(bus, float(_settings.get_value("audio", bus, 10.0)))


## Consumes the shared WIDataRegistry cache (M5 arch finding 7) — a missing/
## invalid data/audio.json is an empty Dictionary there, preserving this
## file's original graceful no-audio-map behavior.
func _reload_audio_map() -> void:
	_entries.clear()
	_music_entries.clear()
	_ambience_entries.clear()
	_load_audio_map()


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

	var raw_ambience: Variant = parsed.get("ambience", [])
	if raw_ambience is Array:
		for raw_entry: Variant in raw_ambience:
			if raw_entry is Dictionary:
				_ambience_entries.append(raw_entry)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if type == WIEvents.AUDIO_PLAYED:
		return  # re-entrancy guard: never let our own emission trigger another lookup
	if type == WIEvents.GAME_RESET or type == WIEvents.GAME_LOADED:
		_reset_duck()
		# v0.16.1 finding 24. A defeat reload rebuilds the world, and the
		# WORLD_READY that falls out of it used to crossfade the restored map's
		# bed back in IMMEDIATELY -- before the black had even started, and the
		# defeat sequence then holds that black until the player chooses. So the
		# boulevard's bazaar looped happily under "[Defeat.]". Latch the reason
		# here (main.gd reads the same key to decide swap_to_world's defeat path)
		# and let the defeat presentation say when the world may sing again.
		# GAME_RESET and any non-defeat load CLEAR it: a latch that could strand
		# would leave a whole session mute.
		_defeat_reload_pending = type == WIEvents.GAME_LOADED and String(payload.get("reason", "")) == "defeat"
		# GH#278 (review find): audio.json was a FIFTH stale cache -- these
		# instance lists loaded once at _ready and never re-read. DEFERRED
		# because this arm connects before Main's handler (autoloads ready
		# first): a synchronous re-read would consume the registry cache
		# Main has not reset yet -- the same one-load-stale class as D1.
		_reload_audio_map.call_deferred()
	elif type == WIEvents.DIALOGUE_STARTED:
		# Message layer clears standalone bark on conversation open; release its timer edge first.
		_clear_transient_ducks(TRANSIENT_DIALOGUE_BARK)
		_duck_music()
	elif type == WIEvents.DIALOGUE_ENDED:
		_unduck_music()
	elif type == WIEvents.DIALOGUE_LINE:
		_duck_transient(DIALOGUE_BARK_DUCK_SEC, TRANSIENT_DIALOGUE_BARK)
	elif type == WIEvents.COMBAT_STARTED or type == WIEvents.MAP_CHANGED:
		# Message layer clears standalone bark on both edges; cancel its duck too.
		_clear_transient_ducks(TRANSIENT_DIALOGUE_BARK)
	elif type == WIEvents.UI_DIALOGUE_LINE_HIDDEN:
		_clear_transient_ducks(TRANSIENT_DIALOGUE_BARK)
	var match_payload := _audio_match_payload(type, payload)
	for entry: Dictionary in _entries:
		if String(entry.get("event", "")) != type:
			continue
		if not _payload_matches(match_payload, entry.get("payload", {})):
			continue
		_play_entry(entry)
	_dispatch_music_event(type, payload)
	_dispatch_ambience_event(type, payload)


func _audio_match_payload(type: String, payload: Dictionary) -> Dictionary:
	if type != WIEvents.PLAYER_MOVED:
		return payload
	var enriched := payload.duplicate()
	enriched["floor_family"] = _current_floor_family()
	return enriched


func _current_floor_family() -> String:
	var game := get_node_or_null("/root/Game")
	if game == null or not ("sim" in game) or game.sim == null:
		return DEFAULT_FOOTSTEP_FAMILY
	var maps: Dictionary = WIDataRegistry.scene_config().get("maps", {})
	var map_cfg: Dictionary = maps.get(String(game.sim.current_map), {})
	var biome_cfg: Dictionary = WIDataRegistry.biomes().get(String(map_cfg.get("biome", "")), {})
	# TRAP: fallback preserves movement SFX; test_audio_data rejects missing authored families.
	return String(biome_cfg.get("footstep_family", DEFAULT_FOOTSTEP_FAMILY))


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

	## Issue #76: `variants` (footstep surfaces, PC hurt barks, ...) rotates
	## through a fixed list one entry per play -- a presentation-side counter
	## (`_variant_index`, keyed by id), deterministic and RNG-free by design:
	## the sim stream's own seeded RNG must stay reproducible for QA/balance
	## purposes, and audio variety is not gameplay, so it gets its own
	## independent, order-only cursor instead of borrowing the sim's rolls.
	## Falls back to plain `stream` when absent (every pre-#76 entry).
	var stream_path := String(entry.get("stream", ""))
	var variants: Variant = entry.get("variants", null)
	var variant_idx := 0
	if variants is Array and not (variants as Array).is_empty():
		var variant_list: Array = variants
		variant_idx = int(_variant_index.get(id, 0)) % variant_list.size()
		stream_path = String(variant_list[variant_idx])
		_variant_index[id] = (variant_idx + 1) % variant_list.size()
	var pitch_scale := float(entry.get("pitch_scale", 1.0))
	var pitch_variants: Variant = entry.get("pitch_variants", null)
	if pitch_variants is Array and not (pitch_variants as Array).is_empty():
		pitch_scale = float((pitch_variants as Array)[variant_idx % (pitch_variants as Array).size()])
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
	if bus == "Voice":
		_duck_transient(VOICE_BARK_DUCK_SEC, TRANSIENT_VOICE_BARK)

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
	# Pooled players retain pitch; every play must overwrite it, including non-footsteps.
	player.pitch_scale = pitch_scale
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
		# See the defeat latch in `_on_domain_event`: this WORLD_READY is the
		# defeat reload's own, and the veil that will cover it has not started.
		if _defeat_reload_pending:
			return
		_sync_field_music_to_current_map()
		return
	if type == WIEvents.UI_DEFEAT_VEIL_FINISHED:
		if _defeat_reload_pending:
			_defeat_reload_pending = false
			if bool(payload.get("continue", true)):
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
	if id.is_empty():
		return
	var stream_path := String(entry.get("stream", ""))
	if stream_path.is_empty():
		push_warning("WIAudio: bad/missing music stream for id '%s': %s" % [id, stream_path])
		return
	var bus := String(entry.get("bus", "Music"))
	if not BUS_NAMES.has(bus):
		push_warning("WIAudio: unknown music bus '%s' for id '%s'" % [bus, id])
		return

	var kind := String(entry.get("kind", ""))
	# TRAP (#129): compare resolved stream paths, never event ids; shared-track
	# contexts must preserve the live player/tween/volume while updating context.
	if stream_path == _current_music_stream_path:
		# Review hardening (#129): the guard only holds while the shared track is
		# actually LIVE -- a stopped/finished player (sting interruption) must fall
		# through to a full restart, and the same-stream pair's differing
		# volume_db still applies (inn -6 vs upstairs -8: retarget, don't skip).
		var _same_live := _is_headless() or (_music_players.size() >= 2 and _music_players[_active_music_index].playing)
		if _same_live:
			if kind == FIELD_MUSIC_KIND:
				_field_context_id = id
			_current_music_id = id
			if not _is_headless():
				_music_players[_active_music_index].volume_db = float(entry.get("volume_db", -6.0))
			return
		_current_music_stream_path = ""

	var missing := not ResourceLoader.exists(stream_path)
	if missing:
		_log_missing_stream(stream_path)
	if kind == FIELD_MUSIC_KIND:
		_field_context_id = id
	_current_music_id = id
	_current_music_stream_path = stream_path

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


## TRAP (double-trigger ordering): two music context switches can land in
## the SAME synchronous beat -- e.g. a map edge cell that also sits inside a
## proximity encounter's `trigger_radius` fires `map_changed` (field-music
## crossfade) immediately followed by `combat_started` (combat-music
## crossfade). Without the `_music_tween` kill below, both Tweens animate
## `volume_db` on the SAME two players in opposite directions each frame
## (whichever tween steps later that frame wins), audible as a stutter/
## restart at the transition. Killing the in-flight crossfade first makes
## the LATER transition win outright: a Tween captures its start value when
## it begins running, so the new fade picks up cleanly from whatever volume
## the kill left each player at. In the double-trigger case the interrupted
## crossfade's `new_player` (still silent -- its fade-in never ran) becomes
## this call's `old_player` and fades out from silence (harmless no-op),
## while its `old_player` (still at the prior track's volume) becomes this
## call's `new_player` and fades cleanly into the new track -- the
## intermediate track is never audibly played.
func _crossfade_to_music(stream: AudioStream, bus: String, target_db: float, return_to_field: bool) -> void:
	if _music_players.size() < 2:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
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
	_music_tween = tween

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


## Ambience dispatch (issue #76 remainder). Mirror of `_dispatch_music_event`
## with the one honest asymmetry: a MAP_CHANGED that matches NO bed row fades
## the current bed out (`_stop_ambience`) -- most maps have no bed, and the
## previous map's crowd murmur bleeding into a silent map would be a bug, not
## atmosphere. Only WORLD_READY and MAP_CHANGED are context re-evaluations;
## every other event type is ignored (a bed never reacts to combat/sting
## events -- the field bed keeps looping under a fight entered from its map,
## the same free inheritance the mood grade uses).
func _dispatch_ambience_event(type: String, payload: Dictionary) -> void:
	if type == WIEvents.WORLD_READY:
		_sync_ambience_to_current_map()
		return
	if type != WIEvents.MAP_CHANGED:
		return
	for entry: Dictionary in _ambience_entries:
		if String(entry.get("event", "")) != type:
			continue
		if not _payload_matches(payload, entry.get("payload", {})):
			continue
		_play_ambience_entry(entry)
		return
	_stop_ambience()


## Boot/post-load bed resolution -- the same "world_ready carries no map
## payload" seam `_sync_field_music_to_current_map` documents, read from
## `Game.sim.current_map` directly. A current map with no bed row stops any
## bed a previous world/save might have left running.
func _sync_ambience_to_current_map() -> void:
	var game := get_node_or_null("/root/Game")
	if game == null or not ("sim" in game) or game.sim == null:
		return
	var map_id := String(game.sim.current_map)
	for entry: Dictionary in _ambience_entries:
		if String(entry.get("context", "")) != map_id:
			continue
		_play_ambience_entry(entry)
		return
	_stop_ambience()


## Mirror of `_play_music_entry` for the bed layer: same id guard, same
## missing-file fallback contract (silent no-op that STILL emits
## `audio_played`), same headless "mapping validated + would have played"
## short-circuit, same runtime `loop` application for OGG streams.
func _play_ambience_entry(entry: Dictionary) -> void:
	var id := String(entry.get("id", ""))
	if id.is_empty() or id == _current_ambience_id:
		return
	var stream_path := String(entry.get("stream", ""))
	if stream_path.is_empty():
		push_warning("WIAudio: bad/missing ambience stream for id '%s': %s" % [id, stream_path])
		return
	var missing := not ResourceLoader.exists(stream_path)
	if missing:
		_log_missing_stream(stream_path)
	var bus := String(entry.get("bus", "Ambience"))
	if not BUS_NAMES.has(bus):
		push_warning("WIAudio: unknown ambience bus '%s' for id '%s'" % [bus, id])
		return

	_current_ambience_id = id

	if missing or _is_headless():
		_emit_audio_played(id, bus)
		return

	if AudioServer.get_bus_index(bus) == -1:
		push_warning("WIAudio: bus '%s' not present on AudioServer for id '%s'" % [bus, id])
		return
	var stream := load(stream_path) as AudioStream
	if stream == null:
		push_warning("WIAudio: failed to load ambience stream for id '%s': %s" % [id, stream_path])
		return

	if stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop = bool(entry.get("loop", true))

	_crossfade_to_ambience(stream, bus, float(entry.get("volume_db", -10.0)))
	_emit_audio_played(id, bus)


## Fades the current bed to silence (entering a bed-less map). Clears the
## current-id guard FIRST so re-entering the bed's map restarts it even if
## the fade is still running. Headless: state-clear only -- no players exist.
## No `audio_played` is emitted (mirror: the music layer has no stop event
## either), so a bed STOP is not headless-observable -- disclosed in the
## audio block's doc rather than papered over with a fake "silence" id.
func _stop_ambience() -> void:
	if _current_ambience_id.is_empty():
		return
	_current_ambience_id = ""
	if _is_headless() or _ambience_players.size() < 2:
		return
	if _ambience_tween != null and _ambience_tween.is_valid():
		_ambience_tween.kill()
	var tween := create_tween()
	tween.set_parallel(true)
	for player: AudioStreamPlayer in _ambience_players:
		if player.playing:
			tween.tween_property(player, "volume_db", MUSIC_SILENCE_DB, MUSIC_CROSSFADE_SEC)
	tween.chain().tween_callback(func() -> void:
		for player: AudioStreamPlayer in _ambience_players:
			if player.playing:
				player.stop()
	)
	_ambience_tween = tween


## Verbatim shape of `_crossfade_to_music` (same kill-the-in-flight-tween
## double-trigger guard, same ping-pong pair) minus the sting/return-to-field
## arm -- beds are always loops, never one-shots.
func _crossfade_to_ambience(stream: AudioStream, bus: String, target_db: float) -> void:
	if _ambience_players.size() < 2:
		return
	if _ambience_tween != null and _ambience_tween.is_valid():
		_ambience_tween.kill()
	var old_player := _ambience_players[_active_ambience_index]
	var new_index := 1 - _active_ambience_index
	var new_player := _ambience_players[new_index]

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
	_ambience_tween = tween
	_active_ambience_index = new_index
