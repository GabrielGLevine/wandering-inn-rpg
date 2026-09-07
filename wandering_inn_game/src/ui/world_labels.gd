class_name WIWorldLabels
extends CanvasLayer
## Field name tags ("You"/"Erin"/etc.) and combat name tags are RETIRED
## entirely (interactables must read from their sprite, not a floating
## name). This class is now COMBAT-ONLY and STATS-ONLY: board_renderer.gd's
## `_rebuild_combat_labels` is the sole remaining caller of
## `rebuild_context`, publishing one entry per combatant with no name --
## `set_stats` still drives the HP/MP numeral readout ("57/80  MP 12/20"),
## the product-mandated readout that survives label removal. world.gd no
## longer touches this class at all (field labels had their own "field"
## context, now unused). Each entry tracks a Node2D anchor and is projected
## through Main.world_to_screen every frame, so Camera2D and viewport
## scaling are composed in one place.

const PANEL_SIZE := Vector2(128.0, 14.0)
const STATS_HEIGHT := 14.0
const QA_CELL_SIZE := 64.0

## The WIMain host, injected at creation (WIMain.world_labels() is the
## single creation site). Typed Node, not WIMain: this script must stay
## loadable in bare --script mode (tests/test_combat_visuals.gd asserts
## can_instantiate), and a hard WIMain annotation would pull the
## autoload-referencing main.gd into that compile.
var main_ref: Node

var _root: Control
var _entries: Dictionary = {}
var _context_visible: Dictionary = {}
var _mobile_combat := false
var _mobile_font_size := 11
var _focus_ids: Array[String] = []
var _covered := false


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)


func rebuild_context(context: String, entries: Array) -> void:
	clear_context(context)
	_context_visible[context] = true
	for raw: Variant in entries:
		if not (raw is Dictionary):
			continue
		var entry := raw as Dictionary
		var id := String(entry.get("id", ""))
		var anchor := entry.get("anchor", null) as Node2D
		if id == "" or anchor == null:
			continue
		var panel := _make_panel(String(entry.get("stats", "")))
		_root.add_child(panel)
		_entries[id] = {
			"context": context,
			"anchor": anchor,
			"offset": entry.get("offset", Vector2.ZERO),
			"panel": panel,
			"stats": panel.get_node("Stats"),
		}
	_update_labels()


## #460: ONE entry, appended to a context that is already live. `rebuild_context`
## clears first, so using it for a mid-fight arrival would blank every existing
## readout until the next `apply_stats` pass -- visible as a flicker across the
## whole board at the moment a summon lands.
func add_to_context(context: String, entry: Dictionary) -> void:
	var id := String(entry.get("id", ""))
	var anchor := entry.get("anchor", null) as Node2D
	if id == "" or anchor == null or _entries.has(id):
		return
	var panel := _make_panel(String(entry.get("stats", "")))
	panel.visible = bool(_context_visible.get(context, true))
	_root.add_child(panel)
	_entries[id] = {
		"context": context,
		"anchor": anchor,
		"offset": entry.get("offset", Vector2.ZERO),
		"panel": panel,
		"stats": panel.get_node("Stats"),
	}
	_update_labels()


func clear_context(context: String) -> void:
	var ids: Array = []
	for id: String in _entries:
		if String((_entries[id] as Dictionary).get("context", "")) == context:
			ids.append(id)
	for id: String in ids:
		var entry: Dictionary = _entries[id]
		var panel := entry.get("panel", null) as Control
		if panel != null:
			panel.queue_free()
		_entries.erase(id)


func set_context_visible(context: String, visible: bool) -> void:
	_context_visible[context] = visible
	for id: String in _entries:
		var entry: Dictionary = _entries[id]
		if String(entry.get("context", "")) == context:
			var panel := entry.get("panel", null) as Control
			if panel != null:
				panel.visible = visible


func set_stats(id: String, text: String) -> void:
	if not _entries.has(id):
		return
	var stats_label := (_entries[id] as Dictionary).get("stats", null) as Label
	if stats_label == null:
		return
	(_entries[id] as Dictionary)["full_stats"] = text
	stats_label.text = text.get_slice("  MP", 0) if _mobile_combat else text
	stats_label.visible = text != ""


func configure_combat_readability(mobile: bool, font_size: int, focus_ids: Array[String], covered := false) -> void:
	_mobile_combat = mobile
	_mobile_font_size = font_size
	_focus_ids = focus_ids
	_covered = covered
	for id: String in _entries:
		var entry: Dictionary = _entries[id]
		var label: Label = entry["stats"]
		var text := String(entry.get("full_stats", label.text))
		label.text = text.get_slice("  MP", 0) if mobile else text
		label.add_theme_font_size_override("font_size", font_size if mobile else 11)
		var panel: Control = entry["panel"]
		var label_size := PANEL_SIZE
		if mobile:
			var font := label.get_theme_font("font")
			label_size = Vector2(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x + 8.0, font.get_height(font_size))
		panel.custom_minimum_size = label_size
		panel.size = label_size
		label.size = label_size
	_update_labels()


func _process(_delta: float) -> void:
	_update_labels()


func _make_panel(stats_text: String) -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = PANEL_SIZE
	panel.custom_minimum_size = PANEL_SIZE
	var stats_label := _make_label("Stats", Vector2.ZERO, Vector2(PANEL_SIZE.x, STATS_HEIGHT))
	stats_label.text = stats_text
	stats_label.visible = stats_text != ""
	stats_label.add_theme_font_size_override("font_size", 11)
	panel.add_child(stats_label)
	return panel


func _make_label(node_name: String, pos: Vector2, size: Vector2) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = pos
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _update_labels() -> void:
	var main := _main()
	if main == null or not main.has_method("world_to_screen"):
		return
	var ids: Array = _entries.keys()
	if _mobile_combat:
		for i in range(_focus_ids.size() - 1, -1, -1):
			if ids.has(_focus_ids[i]):
				ids.erase(_focus_ids[i])
				ids.push_front(_focus_ids[i])
	var occupied: Array[Rect2] = []
	for id: String in ids:
		var entry: Dictionary = _entries[id]
		var raw_panel: Variant = entry.get("panel", null)
		if raw_panel == null or not is_instance_valid(raw_panel):
			continue
		var panel := raw_panel as Control
		var raw_anchor: Variant = entry.get("anchor", null)
		if raw_anchor == null or not is_instance_valid(raw_anchor):
			panel.visible = false
			continue
		var anchor := raw_anchor as Node2D
		if anchor == null:
			panel.visible = false
			continue
		var context := String(entry.get("context", ""))
		panel.visible = bool(_context_visible.get(context, true))
		if _mobile_combat:
			panel.visible = panel.visible and not _covered and _focus_ids.has(id)
		if not panel.visible:
			continue
		var offset: Vector2 = entry.get("offset", Vector2.ZERO)
		var world_pos := anchor.global_position + offset
		var screen_pos: Vector2 = main.world_to_screen(world_pos)
		panel.position = screen_pos - Vector2(panel.size.x * 0.5, 0.0)
		if _mobile_combat and main.has_method("world_view_rect"):
			var board: Rect2 = main.world_view_rect()
			if not board.has_point(screen_pos):
				panel.hide()
				continue
			panel.position.x = clampf(panel.position.x, board.position.x, board.end.x - panel.size.x)
			panel.position.y = clampf(panel.position.y, board.position.y, board.end.y - panel.size.y)
			var rect := panel.get_global_rect()
			if occupied.any(func(other: Rect2): return other.intersects(rect)):
				panel.hide()
			else:
				occupied.append(rect)


func _main() -> Node:
	if main_ref != null:
		return main_ref
	return get_parent()


func panel_projections(context: String) -> Array:
	_update_labels()
	var main := _main()
	if main == null or not main.has_method("world_to_screen"):
		return []
	var out: Array = []
	for id: String in _entries:
		var entry: Dictionary = _entries[id]
		if String(entry.get("context", "")) != context:
			continue
		var raw_panel: Variant = entry.get("panel", null)
		var raw_anchor: Variant = entry.get("anchor", null)
		if raw_panel == null or raw_anchor == null:
			continue
		if not is_instance_valid(raw_panel) or not is_instance_valid(raw_anchor):
			continue
		var panel := raw_panel as Control
		var anchor := raw_anchor as Node2D
		if panel == null or anchor == null or not panel.visible:
			continue
		var cell_a: Vector2 = main.world_to_screen(anchor.global_position)
		var cell_b: Vector2 = main.world_to_screen(anchor.global_position + Vector2(QA_CELL_SIZE, QA_CELL_SIZE))
		out.append({
			"id": id,
			"font_css": float((entry["stats"] as Label).get_theme_font_size("font_size")) * WIResponsiveLayout.css_scale(get_viewport()),
			"panel_position": panel.position,
			"panel_size": panel.size,
			"cell_min": Vector2(minf(cell_a.x, cell_b.x), minf(cell_a.y, cell_b.y)),
			"cell_max": Vector2(maxf(cell_a.x, cell_b.x), maxf(cell_a.y, cell_b.y)),
			"cell_size": Vector2(absf(cell_b.x - cell_a.x), absf(cell_b.y - cell_a.y)),
		})
	return out
