class_name WIAtmosphere
extends CanvasModulate

const MOODS_PATH := "res://data/moods.json"

## a5 #205: FIELD interactable legibility. On dark-mood field maps the mood
## CanvasModulate multiplies encounters/props/NPCs down toward the floor —
## the spider in the dungeon corner, the shadowed alley NPCs. This mirrors
## the combat board's own _legibility_modulate, but with a GENTLER target
## and cap: the point is to keep the dark atmosphere while making the things
## you can ACT on separable, not to wash the map out. World applies the
## returned boost to each entity sprite's self_modulate (floor untouched).
const FIELD_LEGIBILITY_TARGET := 0.5
const FIELD_LEGIBILITY_MAX_BOOST := 1.9

static var _moods_cache: Dictionary = {}


## GH#278: live-reload seam (see WISpriteRegistry.reset()).
static func reset() -> void:
	_moods_cache = {}


var _lights: Array[Dictionary] = []
var _flicker_lights: Array[Dictionary] = []
var _flicker_time := 0.0

var _emitters: Array[Dictionary] = []

var vignette_node: ColorRect

var _in_arena_override := false
var _active_arena_id := ""


func _ready() -> void:
	color = Color(1.0, 1.0, 1.0, 1.0)
	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if type == WIEvents.WORLD_READY:
		apply_map(Game.sim.current_map, phase_now())
	elif type == WIEvents.PHASE_CHANGED:
		# Arena mood is stateful: phase changes reapply the active override.
		var phase := String(payload.get("phase", phase_now()))
		if _in_arena_override:
			apply_arena(_active_arena_id, phase)
		else:
			apply(Game.sim.current_map, phase)
	elif type == WIEvents.COMBAT_STARTED:
		var combat: WICombat = Game.sim.combat
		var arena_id := String(combat.arena_id) if combat != null else ""
		if _arena_moods().has(arena_id):
			_in_arena_override = true
			_active_arena_id = arena_id
			apply_arena(arena_id, phase_now())
	elif type == WIEvents.UI_COMBAT_HIDDEN:
		# Restore the field only when combat actually installed an override.
		if _in_arena_override:
			_in_arena_override = false
			apply(Game.sim.current_map, phase_now())


## The multiplicative boost that brings a dark field map's interactable
## sprites back to the legibility target. 1.0 (no-op) on any map whose
## current mood grade is already at/above target — bright maps render
## byte-identical. Reads this node's own live `color` (the applied grade).
func field_entity_boost() -> float:
	var avg := (color.r + color.g + color.b) / 3.0
	if avg >= FIELD_LEGIBILITY_TARGET:
		return 1.0
	return clampf(FIELD_LEGIBILITY_TARGET / maxf(avg, 0.05), 1.0, FIELD_LEGIBILITY_MAX_BOOST)


func phase_now() -> String:
	return Game.sim.phase()


func apply_map(map_id: String, phase: String) -> void:
	_in_arena_override = false
	apply(map_id, phase)


func apply(map_id: String, phase: String) -> void:
	var mood: Dictionary = (_moods_data().get("moods", {}) as Dictionary).get(map_id, {})
	var rgb: Array = mood.get(phase, [1.0, 1.0, 1.0])
	assert(rgb is Array and rgb.size() == 3,
		"moods.json malformed rgb for %s/%s: %s" % [map_id, phase, str(rgb)])
	color = Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
	_refresh_lights()
	_refresh_emitters()
	_apply_vignette(mood)
	ObservableBus.emit_domain_event(WIEvents.UI_MOOD_APPLIED, {"map": map_id, "phase": phase})


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


static func _arena_moods() -> Dictionary:
	return _moods_data().get("arena_moods", {}) as Dictionary


func light_multiplier(phase: String) -> float:
	var by_phase: Dictionary = (_moods_data().get("meta", {}) as Dictionary).get("light_energy_by_phase", {})
	return float(by_phase.get(phase, 1.0))


func clear_lights() -> void:
	_lights.clear()
	_flicker_lights.clear()


func register_light(node: PointLight2D, base_energy: float, flicker: bool) -> void:
	var entry := {"node": node, "base_energy": base_energy}
	_lights.append(entry)
	if flicker:
		entry["phase_offset"] = float(_flicker_lights.size()) * 1.7
		_flicker_lights.append(entry)
	node.energy = base_energy * light_multiplier(phase_now())


func unregister_light(node: PointLight2D) -> void:
	for i in range(_lights.size() - 1, -1, -1):
		if _lights[i]["node"] == node:
			_lights.remove_at(i)
	for i in range(_flicker_lights.size() - 1, -1, -1):
		if _flicker_lights[i]["node"] == node:
			_flicker_lights.remove_at(i)


func _refresh_lights() -> void:
	var mult := light_multiplier(phase_now())
	for entry: Dictionary in _lights:
		var node: PointLight2D = entry["node"]
		if is_instance_valid(node):
			node.energy = float(entry["base_energy"]) * mult


func register_emitter(node: GPUParticles2D, phases: Array) -> void:
	_emitters.append({"node": node, "phases": phases})
	_set_emitter_state(node, phases)


func clear_emitters() -> void:
	_emitters.clear()


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


func _apply_vignette(mood: Dictionary) -> void:
	if vignette_node == null:
		return
	var strength := float(mood.get("vignette", 0.0))
	var mat := vignette_node.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("strength", strength)


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
