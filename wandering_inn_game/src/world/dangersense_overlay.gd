class_name WIDangersenseOverlay
extends Node2D

# Night-legibility derivation (#446 gate, audited 2026-08-12): worst case is a
# black night-graded ground; night compensation (NIGHT_GRADE_RETAINED) renders
# the aura at authored colors, so the visible stack at minimum pulse (x0.94) is
# core 0.075 over haze 0.22 over band alphas below -> composite contrast ~3.7:1
# against black, vs the ~1.52:1 failure bar from #413. Re-derive against these
# constants if any alpha or the night-grade wiring changes.
# Radius-honesty tripwire: the n=3.2 superellipse reaches only ~80.5% of the
# half-extents on diagonals. At shipped radii (max 2) corner trigger cells stay
# partially tinted; an encounter with trigger radius >= 5 would leave its
# corner cells fully untinted — revisit the exponent or add a corner wash
# before shipping any such encounter.
const CORE_COLOR := Color(0.94, 0.38, 0.16, 0.075)
const AURA_EDGE_COLOR := Color(1.0, 0.75, 0.38, 0.1)
const EDGE_COLOR := Color(1.0, 0.75, 0.38, 0.34)
const EDGE_HAZE_COLOR := Color(1.0, 0.75, 0.38, 0.22)
const EDGE_WIDTH := 2.5
const EDGE_HAZE_WIDTH := 5.0
const AURA_BANDS := 7
const AURA_INNER_EXTENT := 0.18
const AURA_EXPONENT := 3.2
const AURA_SEGMENTS := 48
const PULSE_PERIOD_SECONDS := 6.4
const PULSE_ALPHA_AMPLITUDE := 0.06
const PULSE_DISTANCE_PHASE := 0.65
const NIGHT_GRADE_RETAINED := 0.0

var regions: Array[Dictionary] = []
var _cell_size := 16.0
var _pulse_elapsed := 0.0


func _init(cell_size: float = 16.0) -> void:
	_cell_size = cell_size


func _process(delta: float) -> void:
	if not visible or regions.is_empty():
		return
	_pulse_elapsed = fmod(_pulse_elapsed + delta, PULSE_PERIOD_SECONDS)
	queue_redraw()


func rebuild(encounters: Array, holder_has_skill: bool, field_mode: bool, radius_read: Callable) -> Array[Dictionary]:
	regions.clear()
	visible = holder_has_skill and field_mode
	if visible:
		for raw: Variant in encounters:
			if not (raw is Dictionary):
				continue
			var encounter := raw as Dictionary
			# #475: no `encounter_when` test -- an ambush needs no gate to
			# spring, and requiring one hid the unavoidable gate-road ambush.
			# The liveness filter is world.gd's `_live_dangersense_encounters`;
			# this layer only refuses shapes it cannot draw.
			if String(encounter.get("kind", "")) != "encounter" \
					or not encounter.has("trigger_radius"):
				continue
			var raw_cell: Variant = encounter.get("cell", [])
			var cell: Vector2i
			if raw_cell is Vector2i:
				cell = raw_cell as Vector2i
			elif raw_cell is Array and (raw_cell as Array).size() == 2:
				cell = Vector2i(int(raw_cell[0]), int(raw_cell[1]))
			else:
				continue
			var radius := maxi(0, int(radius_read.call(encounter)))
			regions.append({
				"encounter": String(encounter.get("id", "")),
				"cell": [cell.x, cell.y],
				"radius": radius,
			})
		regions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a["encounter"]) < String(b["encounter"])
		)
	queue_redraw()
	return regions.duplicate(true)


## TRAP (#413): these warnings exist to be read on dark ambush fields. Keeping
## the night grade reduced the authored edge to 1.52:1 contrast, so this custom
## drawing layer alone compensates back to its authored color; terrain keeps
## the full mood grade and day remains identity.
func apply_night_grade(compensation: Color, phase: String) -> void:
	modulate = compensation if phase == "night" else Color.WHITE


func region_rect(region: Dictionary) -> Rect2:
	var raw_cell := region.get("cell", []) as Array
	var radius := int(region.get("radius", 0))
	var origin := Vector2(int(raw_cell[0]) - radius, int(raw_cell[1]) - radius) * _cell_size
	var diameter := float(radius * 2 + 1) * _cell_size
	return Rect2(origin, Vector2(diameter, diameter))


func _draw() -> void:
	for region: Dictionary in regions:
		_draw_aura(region_rect(region))


func _draw_aura(rect: Rect2) -> void:
	var center := rect.get_center()
	var half_extents := rect.size * 0.5
	var pulse_phase := TAU * _pulse_elapsed / PULSE_PERIOD_SECONDS
	for band: int in AURA_BANDS:
		var inward := float(band) / float(AURA_BANDS - 1)
		var extent := lerpf(1.0, AURA_INNER_EXTENT, inward)
		var color := AURA_EDGE_COLOR.lerp(CORE_COLOR, inward)
		var distance_phase := pulse_phase - extent * PULSE_DISTANCE_PHASE
		color.a *= 1.0 + sin(distance_phase) * PULSE_ALPHA_AMPLITUDE
		draw_colored_polygon(_superellipse(center, half_extents * extent), color)
	var edge_pulse := 1.0 + sin(pulse_phase - PULSE_DISTANCE_PHASE) * PULSE_ALPHA_AMPLITUDE
	var edge_haze := EDGE_HAZE_COLOR
	var edge_core := EDGE_COLOR
	edge_haze.a *= edge_pulse
	edge_core.a *= edge_pulse
	# Half-width inset makes the haze's outer feather end at the trigger extent.
	var edge_points := _superellipse(
		center,
		half_extents - Vector2.ONE * EDGE_HAZE_WIDTH * 0.5,
	)
	edge_points.append(edge_points[0])
	draw_polyline(edge_points, edge_haze, EDGE_HAZE_WIDTH, true)
	draw_polyline(edge_points, edge_core, EDGE_WIDTH, true)


func _superellipse(center: Vector2, half_extents: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in AURA_SEGMENTS:
		var angle := TAU * float(i) / float(AURA_SEGMENTS)
		var cosine := cos(angle)
		var sine := sin(angle)
		var x := signf(cosine) * pow(absf(cosine), 2.0 / AURA_EXPONENT)
		var y := signf(sine) * pow(absf(sine), 2.0 / AURA_EXPONENT)
		points.append(center + Vector2(x * half_extents.x, y * half_extents.y))
	# The outer contour uses region_rect's exact half-extents: every point
	# stays inside the shared trigger rect and its cardinal points touch it.
	return points
