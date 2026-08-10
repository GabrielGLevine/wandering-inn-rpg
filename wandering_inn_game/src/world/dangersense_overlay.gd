class_name WIDangersenseOverlay
extends Node2D

const FILL_COLOR := Color(1.0, 0.25, 0.2, 0.34)
const EDGE_COLOR := Color(1.0, 0.5, 0.34, 0.92)
const EDGE_WIDTH := 1.0
const CORNER_TICK := 5.0
const NIGHT_GRADE_RETAINED := 0.0

var regions: Array[Dictionary] = []
var _cell_size := 16.0


func _init(cell_size: float = 16.0) -> void:
	_cell_size = cell_size


func rebuild(encounters: Array, holder_has_skill: bool, field_mode: bool, radius_read: Callable) -> Array[Dictionary]:
	regions.clear()
	visible = holder_has_skill and field_mode
	if visible:
		for raw: Variant in encounters:
			if not (raw is Dictionary):
				continue
			var encounter := raw as Dictionary
			if String(encounter.get("kind", "")) != "encounter" \
					or not encounter.has("encounter_when") \
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
		var rect := region_rect(region)
		draw_rect(rect, FILL_COLOR, true)
		var edge := Rect2(rect.position + Vector2(0.5, 0.5), rect.size - Vector2.ONE)
		draw_rect(edge, EDGE_COLOR, false, EDGE_WIDTH)
		_draw_corner_ticks(edge)


func _draw_corner_ticks(rect: Rect2) -> void:
	var left := rect.position.x
	var right := rect.end.x
	var top := rect.position.y
	var bottom := rect.end.y
	for corner: Vector2 in [Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)]:
		var horizontal := CORNER_TICK if corner.x == left else -CORNER_TICK
		var vertical := CORNER_TICK if corner.y == top else -CORNER_TICK
		draw_line(corner, corner + Vector2(horizontal, 0), EDGE_COLOR, EDGE_WIDTH)
		draw_line(corner, corner + Vector2(0, vertical), EDGE_COLOR, EDGE_WIDTH)
