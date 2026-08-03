class_name WIHotbar
extends Control
## bottom-center combat action bar -- replaces the old MENU/SKILL_PICK
## text lists (combat_screen.gd) with icon slots: Attack, Dash, combat
## skills (skills.json order), End Turn. Pure rendering: combat_screen.gd
## owns selection/affordability/input and calls `render(slots, selected_index)`
## every `_refresh()` (`selected_index` -1 = nothing highlighted -- the
## movement-first resting state; a slot highlights only while being aimed).

const SLOT_SIZE := Vector2(52.0, 52.0)
const SLOT_GAP := 6.0
const END_TURN_GAP := 22.0
const BOTTOM_MARGIN := 10.0
const ICON_SIZE := Vector2(28.0, 28.0)
static var FRAME_TEXTURE: Texture2D = UIChrome.chrome_texture("res://assets/ui/chrome/Carved_9Slides.png")
static var SELECTED_TEXTURE: Texture2D = UIChrome.chrome_texture("res://assets/ui/chrome/Button_Blue_9Slides.png")
const UNAFFORDABLE_MODULATE := Color(0.55, 0.55, 0.55, 1.0)
const AP_PIP_COLOR := Color(0.05, 0.05, 0.05)
const MP_DIAMOND_COLOR := Color(0.1, 0.2, 0.6)
const COOLDOWN_BADGE_COLOR := Color(0.55, 0.12, 0.08)

## Issue #57: a left-click on a rendered slot activates it EXACTLY as its
## number key -- callers (field_hotbar.gd/combat_screen.gd, via combat_hud.gd)
## connect this and route it into the SAME dispatch a number-key press
## already uses (`use_skill_field`/`_activate_bar_slot`), so there is only
## ever one activation path, click or key. `index` is 0-based, matching
## `render()`'s child order (and `slot_rect`'s existing convention).
signal slot_clicked(index: int)


func _ready() -> void:
	# STOP (not the repo-wide panel-chrome IGNORE default): this bar is now a
	# real clickable widget, and its own rect must swallow a click over ANY
	# slot OR the gaps between them -- a click landing in a gap must not leak
	# through to a world/board click underneath the bar's footprint (mouse_filter
	# audit, issue #57). Every child slot Control stays IGNORE (see `_make_slot`)
	# so a click always bottoms out here rather than being claimed by chrome.
	mouse_filter = Control.MOUSE_FILTER_STOP
	UIChrome.apply_theme(self)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := _slot_index_at(mb.position)
	if idx >= 0:
		slot_clicked.emit(idx)
	accept_event()


## Which child slot (0-based) contains `local_pos`, or -1 -- children are
## added in `render()`'s slot order, matching `slot_rect`'s own indexing.
func _slot_index_at(local_pos: Vector2) -> int:
	for i in get_child_count():
		var child := get_child(i) as Control
		if child != null and Rect2(child.position, child.size).has_point(local_pos):
			return i
	return -1


func render(slots: Array, selected_index: int) -> void:
	for child: Node in get_children():
		child.queue_free()
	var total_width := 0.0
	for i in slots.size():
		if i > 0:
			total_width += END_TURN_GAP if bool((slots[i] as Dictionary).get("end_turn_gap", false)) else SLOT_GAP
		total_width += SLOT_SIZE.x
	custom_minimum_size = Vector2(total_width, SLOT_SIZE.y)
	size = custom_minimum_size
	offset_left = -total_width * 0.5
	offset_right = total_width * 0.5
	offset_top = -SLOT_SIZE.y - BOTTOM_MARGIN
	offset_bottom = -BOTTOM_MARGIN
	var x := 0.0
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if i > 0:
			x += END_TURN_GAP if bool(slot.get("end_turn_gap", false)) else SLOT_GAP
		var node := _make_slot(slot, i == selected_index)
		node.position = Vector2(x, 0.0)
		add_child(node)
		x += SLOT_SIZE.x


func slot_rect(index: int) -> Rect2:
	if index < 0 or index >= get_child_count():
		return Rect2()
	var slot_node := get_child(index) as Control
	if slot_node == null:
		return Rect2()
	return Rect2(slot_node.global_position, slot_node.size)


func _make_slot(slot: Dictionary, selected: bool) -> Control:
	var root := Control.new()
	root.custom_minimum_size = SLOT_SIZE
	root.size = SLOT_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not bool(slot.get("affordable", true)):
		root.modulate = UNAFFORDABLE_MODULATE

	var frame := NinePatchRect.new()
	frame.texture = SELECTED_TEXTURE if selected else FRAME_TEXTURE
	frame.patch_margin_left = UIChrome.PATCH_MARGIN
	frame.patch_margin_right = UIChrome.PATCH_MARGIN
	frame.patch_margin_top = UIChrome.PATCH_MARGIN
	frame.patch_margin_bottom = UIChrome.PATCH_MARGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(frame)

	var icon_id := String(slot.get("icon", ""))
	if icon_id != "" and WISpriteRegistry.has_sprite(icon_id):
		var tex_rect := TextureRect.new()
		var frames := WISpriteRegistry.frames_for(icon_id)
		tex_rect.texture = frames.get_frame_texture("idle", 0)
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.size = ICON_SIZE
		tex_rect.position = (SLOT_SIZE - ICON_SIZE) * 0.5
		root.add_child(tex_rect)
	else:
		var text_label := UIChrome.make_label("", "Small")
		text_label.text = String(slot.get("fallback_label", slot.get("label", "")))
		text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		text_label.clip_text = true
		text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(text_label)

	var key_hint := String(slot.get("key_hint", ""))
	if key_hint != "":
		var key_label := UIChrome.make_label("", "Small")
		key_label.text = key_hint
		key_label.position = Vector2(4, 1)
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(key_label)

	var ap_cost := int(slot.get("ap_cost", 0))
	if ap_cost > 0:
		var ap_label := Label.new()
		ap_label.text = "●".repeat(ap_cost)  # ●
		ap_label.position = Vector2(2, SLOT_SIZE.y - 26)
		ap_label.size = Vector2(SLOT_SIZE.x - 4, 13)
		ap_label.add_theme_font_size_override("font_size", 10)
		ap_label.add_theme_color_override("font_color", AP_PIP_COLOR)
		ap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ap_label)

	var mp_cost := int(slot.get("mp_cost", 0))
	if mp_cost > 0:
		var mp_label := Label.new()
		mp_label.text = "◆".repeat(mp_cost)  # ◆
		mp_label.position = Vector2(2, SLOT_SIZE.y - 14)
		mp_label.size = Vector2(SLOT_SIZE.x - 4, 13)
		mp_label.add_theme_font_size_override("font_size", 10)
		mp_label.add_theme_color_override("font_color", MP_DIAMOND_COLOR)
		mp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(mp_label)

	var cd_left := int(slot.get("cooldown_remaining", 0))
	if cd_left > 0:
		var cd_label := Label.new()
		cd_label.text = str(cd_left)
		cd_label.position = Vector2(SLOT_SIZE.x - 14, 1)
		cd_label.add_theme_font_size_override("font_size", 10)
		cd_label.add_theme_color_override("font_color", COOLDOWN_BADGE_COLOR)
		cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(cd_label)

	return root
