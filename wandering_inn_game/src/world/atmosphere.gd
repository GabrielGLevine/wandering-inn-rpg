class_name WIAtmosphere
extends CanvasModulate
## Presentation-only mood grade layer. Spawned as a direct
## child of WIWorld (the world viewport's root -- see world.gd's _ready(),
## the same spot _field_root/_camera are added) so it lives inside the 320x180
## world SubViewport and never touches the native-res UI CanvasLayers
## that hang off WIMain directly (message_layer/combat_screen/journal/
## pause_menu/inventory/consolidation_prompt -- see main.gd's
## `_spawn_ui_layers`).
##
## CanvasModulate tints the
## ENTIRE default canvas layer of the viewport it lives in, not just its own
## node subtree (Godot semantics: "only one CanvasModulate per canvas"). No
## CanvasLayer node wraps WIWorld.combat_board_root() (a plain Node2D sibling
## of _field_root under the same World node) or anything else inside
## the world SubViewport, so a single WIAtmosphere instance here ALSO grades
## the combat board for free -- arenas inherit whatever mood this node is
## currently applying unless pinned via `arena_moods` (see below).
##
## Reads data/moods.json directly with its own tiny static cache (mirrors
## WIDataRegistry's load-once pattern).
##
## Also owns the light layer's phase multiplier
## and the registry of live PointLight2Ds world.gd spawns from entity/decor
## `light` data (`register_light`/`clear_lights`/`_refresh_lights`) plus the
## flicker wobble tick (`_process`) -- see those functions' doc comments.
##
## The same registry pattern extends to
## GPUParticles2D ambience emitters (`register_emitter`/`clear_emitters`/
## `_refresh_emitters` -- toggles `.emitting`/`.visible` by phase membership,
## not a continuous multiplier like lights, since an emitter is either "on
## for this phase" or not per its data-authored `phase` list) and the
## fullrect vignette ColorRect world.gd creates once as a child of the field
## Camera2D (`vignette_node`, set by world.gd right after creating it, read
## by `apply()`/`_apply_vignette` every mood application).
##
## Cave-mouth pin: an arena normally inherits whatever mood is CURRENTLY
## applied to the field map it was entered from -- correct for
## goblin_ambush/training_yard (open-air, phase-appropriate), wrong for
## `cave_mouth` (a cave should read dark regardless of the outdoor field's
## time-of-day). `moods.json`'s `arena_moods` dict (parallel to `moods`,
## keyed by ARENA id instead of map id, same per-phase RGB + vignette shape)
## opts specific arenas OUT of field inheritance; an arena absent from
## `arena_moods` (goblin_ambush, training_yard, any future arena) keeps the
## inherit-from-field behavior unchanged -- `_on_domain_event`'s
## `COMBAT_STARTED` handler only switches to `apply_arena()` when the
## just-started combat's `arena_id` has an `arena_moods` entry; otherwise it
## does nothing at all, leaving whatever color `apply()` last set (the
## field's own grade) exactly as it was. `_in_arena_override`/
## `_active_arena_id` track which source (arena pin vs. field map) is
## CURRENTLY driving the canvas, so a `phase_changed` mid-combat (the sim can
## tick the phase clock during a fight -- PC turns count toward
## `actions_since_sleep`) re-applies the right source instead of a phase
## crossing silently clobbering an active arena pin back to the field's
## grade. `UI_COMBAT_HIDDEN` (board torn down, field shown again) restores
## the field's own mood if an override was active; a no-op otherwise (the
## field's grade was already current the whole time).

const MOODS_PATH := "res://data/moods.json"

static var _moods_cache: Dictionary = {}

## Registered {node: PointLight2D, base_energy: float} entries for
## every light currently spawned by world.gd, so a phase crossing can update
## every live light's energy in one place (`_refresh_lights`, called from
## `apply()`) instead of world.gd re-deriving the phase multiplier itself.
## `_flicker_lights` is the subset with `flicker: true` -- kept separate so
## `_process` can skip the whole per-frame loop when nothing flickers AND
## when it does have entries but the CURRENT phase's multiplier is 0 (day),
## per the plan's "zero cost at day" requirement. Both are cleared by
## world.gd's `clear_lights()` call at the top of every `_rebuild_field`
## pass, before the old map's holders (and their light children) are queued
## free, so a stale/freed node can never linger here across a map change.
var _lights: Array[Dictionary] = []
var _flicker_lights: Array[Dictionary] = []
var _flicker_time := 0.0

## Registered {node: GPUParticles2D, phases: Array}
## entries for every ambience emitter world.gd spawns from map `ambience`
## data. Cleared by world.gd's `clear_emitters()` call at the top of every
## `_rebuild_field` pass, same lifecycle as `_lights`.
var _emitters: Array[Dictionary] = []

## The fullrect vignette ColorRect, created ONCE by
## world.gd's `_ready()` as a child of the field Camera2D (so its rect always
## tracks the current view -- see the ColorRect's own doc comment in
## world.gd) and assigned here directly (not registered via a method --
## there is only ever one). `apply()` reads moods.json's per-map `vignette`
## field and writes it into this node's ShaderMaterial every mood
## application; null-safe (a scene/test that never assigns it just skips the
## write, same as `vignette_node == null` never happening in practice since
## world.gd assigns it before the first `apply()` call can fire).
var vignette_node: ColorRect

## True iff the canvas is CURRENTLY showing an
## `arena_moods` pin rather than the field map's own mood -- set by
## `COMBAT_STARTED` (only when the started combat's arena has a pin) and
## cleared by `UI_COMBAT_HIDDEN`. `_active_arena_id` is the pinned arena's id
## while an override is active (undefined/stale otherwise -- only ever read
## when `_in_arena_override` is true).
var _in_arena_override := false
var _active_arena_id := ""


func _ready() -> void:
	# Identity default until the first apply() lands (world_ready fires
	# synchronously right after this node connects, in the same _ready()
	# call that spawned it -- see world.gd -- so this is a belt-and-braces
	# default, never the value QA actually observes).
	color = Color(1.0, 1.0, 1.0, 1.0)
	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if type == WIEvents.WORLD_READY:
		_in_arena_override = false
		apply(Game.sim.current_map, phase_now())
	elif type == WIEvents.MAP_CHANGED:
		_in_arena_override = false
		apply(String(payload.get("map", Game.sim.current_map)), phase_now())
	elif type == WIEvents.PHASE_CHANGED:
		var phase := String(payload.get("phase", phase_now()))
		if _in_arena_override:
			apply_arena(_active_arena_id, phase)
		else:
			apply(Game.sim.current_map, phase)
	elif type == WIEvents.COMBAT_STARTED:
		# Only switch to the arena-pinned mood when this arena
		# actually has an `arena_moods` entry -- an arena without one (every
		# arena except cave_mouth, today) is left entirely alone, so the
		# field's own grade keeps showing through the combat board (the
		# free inheritance described above, unchanged).
		var combat: WICombat = Game.sim.combat
		var arena_id := String(combat.arena_id) if combat != null else ""
		if _arena_moods().has(arena_id):
			_in_arena_override = true
			_active_arena_id = arena_id
			apply_arena(arena_id, phase_now())
	elif type == WIEvents.UI_COMBAT_HIDDEN:
		if _in_arena_override:
			_in_arena_override = false
			apply(Game.sim.current_map, phase_now())


## Pure passthrough to the sim's phase classifier (see
## wi_game.gd's `phase()` doc comment) -- one canonical "what phase is it
## right now" call instead of each caller reaching into Game.sim directly.
func phase_now() -> String:
	return Game.sim.phase()


## Sets this CanvasModulate's color from data/moods.json for (map_id, phase)
## and emits UI_MOOD_APPLIED {map, phase}. An unknown map or phase falls back
## to identity ([1,1,1]) instead of erroring -- every map in data/maps/**
## ships an identity entry this task, so the fallback only guards a future
## map added there before its moods.json entry lands. Also re-applies every
## registered light's energy for the (possibly new) phase -- see
## `_refresh_lights` -- so the grade and the lights always move together.
func apply(map_id: String, phase: String) -> void:
	var mood: Dictionary = (_moods_data().get("moods", {}) as Dictionary).get(map_id, {})
	var rgb: Array = mood.get(phase, [1.0, 1.0, 1.0])
	# Malformed
	# content data (wrong-length rgb) is a data-authoring bug, not a runtime
	# possibility to tolerate -- assert loudly here rather than (a) push_error
	# + a silent identity fallback, which would print on every single run
	# that ever applies this map/phase and violate the repo's zero-warning
	# rule, or (b) a fully silent fallback, which would let a data typo ship
	# invisibly forever. This mirrors WISpriteRegistry's own idiom for
	# malformed catalog data (`sprite_registry.gd`'s `assert(_catalog.has(...))`/
	# `assert(strip_size.x >= frame_size.x, ...)` -- fail fast at the point of
	# use, in debug builds, on the codebase's one existing content-validation
	# convention) rather than inventing a second one.
	assert(rgb is Array and rgb.size() == 3,
		"moods.json malformed rgb for %s/%s: %s" % [map_id, phase, str(rgb)])
	color = Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
	_refresh_lights()
	_refresh_emitters()
	_apply_vignette(mood)
	ObservableBus.emit_domain_event(WIEvents.UI_MOOD_APPLIED, {"map": map_id, "phase": phase})


## Same job as `apply()` but reads moods.json's
## `arena_moods` dict (keyed by ARENA id, not map id) instead of `moods`.
## Kept as a thin sibling rather than folding a second lookup table into
## `apply()` itself -- the two dicts share a schema but never the same key
## namespace (arena ids like "cave_mouth" vs. map ids like "inn"), and
## `apply()`'s fallback-to-identity philosophy/doc contract stays untouched
## for the (still far more common) map-id path. Only ever called for an
## arena already confirmed present in `_arena_moods()` (see
## `_on_domain_event`'s `COMBAT_STARTED`/`PHASE_CHANGED` arms), so the
## identity fallback below only guards a same-frame data-cache race, never a
## real missing-entry case.
func apply_arena(arena_id: String, phase: String) -> void:
	var mood: Dictionary = _arena_moods().get(arena_id, {})
	var rgb: Array = mood.get(phase, [1.0, 1.0, 1.0])
	assert(rgb is Array and rgb.size() == 3,
		"moods.json malformed arena rgb for %s/%s: %s" % [arena_id, phase, str(rgb)])
	color = Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
	_refresh_lights()
	_refresh_emitters()
	_apply_vignette(mood)
	ObservableBus.emit_domain_event(WIEvents.UI_MOOD_APPLIED, {"map": arena_id, "phase": phase})


## moods.json's `arena_moods` dict, or `{}` if the file
## predates this schema addition (never true in practice -- kept only
## so `.has()`/`.get()` on the return value can never fail on an unexpected
## dict shape).
static func _arena_moods() -> Dictionary:
	return _moods_data().get("arena_moods", {}) as Dictionary


## Per-phase light-intensity multiplier from moods.json meta
## (`light_energy_by_phase`) -- day's 0.0 keeps every PointLight2D invisible
## at day BY CONSTRUCTION (today's look preserved with no identity hack
## needed on the light data itself). Unknown phase falls back to 1.0 (full
## intensity), matching `apply()`'s identity-first fallback philosophy --
## every phase in use (day/dusk/night) has an explicit moods.json entry.
func light_multiplier(phase: String) -> float:
	var by_phase: Dictionary = (_moods_data().get("meta", {}) as Dictionary).get("light_energy_by_phase", {})
	return float(by_phase.get(phase, 1.0))


## Drops every registered light (world.gd calls this at the top of each
## `_rebuild_field` pass, before the old map's holders are queued free).
func clear_lights() -> void:
	_lights.clear()
	_flicker_lights.clear()


## Registers a PointLight2D spawned by world.gd from entity/decor `light`
## data and immediately sets its energy for the CURRENT phase, so a light
## spawned mid-dusk (e.g. right after a map change) does not sit dark until
## the next `phase_changed`. `base_energy` is the light's data-authored
## value (the map's own `light.energy` in data/maps/**); the live `.energy` is
## always `base_energy * light_multiplier(phase)` (times a flicker wobble
## for flicker lights -- see `_process`).
func register_light(node: PointLight2D, base_energy: float, flicker: bool) -> void:
	var entry := {"node": node, "base_energy": base_energy}
	_lights.append(entry)
	if flicker:
		entry["phase_offset"] = float(_flicker_lights.size()) * 1.7
		_flicker_lights.append(entry)
	node.energy = base_energy * light_multiplier(phase_now())


## Removes a single
## light node's registration from BOTH `_lights` and `_flicker_lights` --
## the surgical single-node counterpart `clear_lights()` (a whole-map wipe,
## scoped to `_rebuild_field`) doesn't cover. `world.gd`'s
## `_refresh_entity_visual` (the live in-place re-render for a `visual_states`
## transition, e.g. `unlit_lantern` gaining a light on interact) calls this
## for every `PointLight2D` child of the OLD holder BEFORE `queue_free()`ing
## it -- without this, a node that's about to be freed stays registered
## forever (only skipped via `is_instance_valid()` in `_refresh_lights`/
## `_process`, never actually removed), and a re-render that happens more
## than once for the same entity would leak one stale array entry per call.
## No-op if the node was never registered (never happens in practice --
## only ever called on an actual `PointLight2D` a prior `_spawn_light` call
## created).
func unregister_light(node: PointLight2D) -> void:
	for i in range(_lights.size() - 1, -1, -1):
		if _lights[i]["node"] == node:
			_lights.remove_at(i)
	for i in range(_flicker_lights.size() - 1, -1, -1):
		if _flicker_lights[i]["node"] == node:
			_flicker_lights.remove_at(i)


## Re-applies every registered light's base energy at the current phase
## multiplier. Called from `apply()` so a phase_changed/map_changed pass
## updates the grade color and the lights in the same place. Flicker lights
## get overwritten again on the very next frame by `_process` if the phase
## multiplier is > 0 -- this call's value for them is just the correct
## resting point should `_process` be skipped that frame (multiplier == 0).
func _refresh_lights() -> void:
	var mult := light_multiplier(phase_now())
	for entry: Dictionary in _lights:
		var node: PointLight2D = entry["node"]
		if is_instance_valid(node):
			node.energy = float(entry["base_energy"]) * mult


## Registers a GPUParticles2D spawned by world.gd from map
## `ambience` data and immediately sets its on/off state for the CURRENT
## phase (mirrors `register_light`'s immediate-apply so an emitter spawned
## mid-dusk, e.g. right after a map change, is never dark/hidden until the
## next `phase_changed`). An empty `phases` list means "always on" (no
## shipped preset uses this yet -- every current data entry authors an
## explicit phase list -- but it is the natural default for a future
## always-visible preset, same fallback philosophy as `apply()`'s
## identity-color default).
func register_emitter(node: GPUParticles2D, phases: Array) -> void:
	_emitters.append({"node": node, "phases": phases})
	_set_emitter_state(node, phases)


## Drops every registered emitter (world.gd calls this at the top of each
## `_rebuild_field` pass, alongside `clear_lights()`, before the old map's
## holders are queued free).
func clear_emitters() -> void:
	_emitters.clear()


## Re-applies every registered emitter's on/off state for the (possibly new)
## current phase. Called from `apply()` so a phase_changed/map_changed pass
## updates the grade color, the lights, and the ambience emitters together.
func _refresh_emitters() -> void:
	for entry: Dictionary in _emitters:
		var node: GPUParticles2D = entry["node"]
		if is_instance_valid(node):
			_set_emitter_state(node, entry["phases"])


## Both `.emitting` (stops new particle spawn) and `.visible` (hard cuts any
## still-alive particles from the previous phase instantly) are set together
## -- `.emitting` alone would let a handful of particles fade out naturally
## over their remaining lifetime after a phase crossing, which is a nicer
## transition during real play but makes a windowed screenshot's "day is
## fully identity" claim time-dependent/non-deterministic (a shot taken a
## few frames after crossing back to day could still show stragglers). The
## hard visibility cut keeps every day-phase QA shot deterministic, matching
## the ship-neutral-first day-identity contract already established.
func _set_emitter_state(node: GPUParticles2D, phases: Array) -> void:
	var should_emit: bool = phases.is_empty() or (phase_now() in phases)
	node.emitting = should_emit
	node.visible = should_emit


## Writes moods.json's per-map `vignette` field (a
## flat 0..1 float, not phase-keyed) into the
## vignette ColorRect's ShaderMaterial `strength` uniform. No-ops if
## world.gd hasn't assigned `vignette_node` yet (never happens in practice --
## world.gd assigns it before `_rebuild_field()`/`WORLD_READY`, i.e. before
## any `apply()` call can fire -- but this keeps `apply()` safe to call from
## a future test harness that constructs a bare WIAtmosphere).
func _apply_vignette(mood: Dictionary) -> void:
	if vignette_node == null:
		return
	var strength := float(mood.get("vignette", 0.0))
	var mat := vignette_node.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("strength", strength)


## Subtle sine wobble on flicker-tagged lights (campfires/torches), ticked
## ONLY when there is at least one flicker light registered AND the current
## phase's multiplier is > 0 -- at day (multiplier 0.0) every light is
## invisible regardless of wobble, so this returns immediately with zero
## per-light work, per the plan's "zero cost at day" requirement.
func _process(delta: float) -> void:
	if _flicker_lights.is_empty():
		return
	var mult := light_multiplier(phase_now())
	if mult <= 0.0:
		return
	_flicker_time += delta
	for entry: Dictionary in _flicker_lights:
		var node: PointLight2D = entry["node"]
		if not is_instance_valid(node):
			continue
		var wobble := 1.0 + 0.08 * sin(_flicker_time * 6.0 + float(entry["phase_offset"]))
		node.energy = float(entry["base_energy"]) * mult * wobble


static func _moods_data() -> Dictionary:
	if _moods_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOODS_PATH))
		assert(parsed is Dictionary, "invalid moods.json")
		_moods_cache = parsed
	return _moods_cache
