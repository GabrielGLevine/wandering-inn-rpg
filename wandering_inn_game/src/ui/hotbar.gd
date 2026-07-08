class_name WIHotbar
extends Control
## bottom-center combat action bar -- replaces the old MENU/SKILL_PICK
## text lists (combat_screen.gd) with icon slots: Attack, Dash, combat
## skills (skills.json order), End Turn. Pure rendering: combat_screen.gd
## owns selection/affordability/input and calls `render(slots, selected_index)`
## every `_refresh()` (`selected_index` -1 = nothing highlighted -- the
## movement-first resting state; a slot highlights only while being aimed).
##
## Chrome per docs/superpowers/specs/2026-07-02-environment-ui-immersion-
## design.md sec.5: Tiny Swords `Carved_9Slides.png` carved-wood frame per
## slot, swapped for `Button_Blue_9Slides.png` on the selected slot (the
## doc's "pressed/hover button states from Buttons/ for the selected slot").
##
## Slot dict shape (per entry in the `slots` array passed to `render`):
##   { "type": String, "label": String, "icon": String (sprites.json id, ""
##     for a text-only slot), "key_hint": String ("1".."9"/"E"/""),
##     "ap_cost": int, "mp_cost": int, "affordable": bool,
##     "end_turn_gap": bool (extra gap before this slot -- End Turn only) }
## `icon`/`label`/`ap_cost`/`mp_cost`/`key_hint` are pure display data; this
## script never reads combat state directly (combat_screen computes
## affordability via the existing `_bar_action_affordable`/`_skill_affordable`
## gates and passes the result in).

const SLOT_SIZE := Vector2(52.0, 52.0)
const SLOT_GAP := 6.0
const END_TURN_GAP := 22.0
const BOTTOM_MARGIN := 10.0
const ICON_SIZE := Vector2(28.0, 28.0)
# R2 fallback-art: runtime-resolved (was `const preload`) so a public checkout
# missing the Tiny Swords bundle still compiles + boots -- shares UIChrome's
# placeholder mechanism. ZERO behavior change when the chrome is present.
static var FRAME_TEXTURE: Texture2D = UIChrome.chrome_texture("res://assets/ui/chrome/Carved_9Slides.png")
static var SELECTED_TEXTURE: Texture2D = UIChrome.chrome_texture("res://assets/ui/chrome/Button_Blue_9Slides.png")
## Carved_9Slides.png / Button_Blue_9Slides.png are 192x192 Tiny Swords
## 9-slice panels; the carved/painted border reads (by eye) as roughly an
## eighth of the image — which is exactly UIChrome.PATCH_MARGIN (24), so the
## slot frames share it. CONTROLLER: tune against a windowed screenshot if
## the frame looks stretched or the border reads too thin/thick.
## Greys out unaffordable slots in the spirit of the repo-wide locked/greyed
## convention (combat_screen.gd's / dialogue_panel.gd's LOCKED_COLOR), but it
## is NOT the same value or mechanism: LOCKED_COLOR is a 0.45-grey font-color
## override on text rows, while this is a lighter 0.55 whole-slot multiply
## modulate (so icons and chrome dim together without going illegibly dark).
const UNAFFORDABLE_MODULATE := Color(0.55, 0.55, 0.55, 1.0)
const AP_PIP_COLOR := Color(0.05, 0.05, 0.05)
const MP_DIAMOND_COLOR := Color(0.1, 0.2, 0.6)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIChrome.apply_theme(self)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)


## Rebuilds the bar from scratch every call -- slot counts are small (<=9)
## and combat's own `_refresh()` already rebuilds comparable amounts of UI
## state on every event (see e.g. `_rebuild_combat_labels`), so a full
## teardown/rebuild here matches the codebase's existing "cheap enough, skip
## the diffing" convention rather than introducing a second one.
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


func _make_slot(slot: Dictionary, selected: bool) -> Control:
	var root := Control.new()
	root.custom_minimum_size = SLOT_SIZE
	root.size = SLOT_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not bool(slot.get("affordable", true)):
		root.modulate = UNAFFORDABLE_MODULATE

	# Manual NinePatch (fixed-size slot square, not a full-rect panel); if a
	# slot texture ever needs an art-bbox region crop, go through UIChrome.
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
		# No icon registered for this slot (End Turn today; also the
		# controller-iteration fallback path for any future skill added
		# without an "icon" id in skills.json) -- a centered text label per
		# the design doc's "small LABELED slot" wording for End Turn.
		var text_label := UIChrome.make_label("", "Small")
		text_label.text = String(slot.get("label", ""))
		text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		# PF VISUAL-LOG drain (field-hotbar text overflow): a long bracketed
		# field-skill name ("[Basic Cleaning]") whose single word is wider than
		# the 52px slot used to spill OUTSIDE the carved frame (autowrap can't
		# break a lone word). Hard-clip to the slot rect and trim with an
		# ellipsis so an icon-less slot stays inside its frame. No effect on the
		# only live user of this fallback (combat's short "End\nTurn").
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

	# AP pips and MP diamonds stack on separate rows (rather than sharing one
	# baseline split left/right) so a skill costing both (e.g. Flame Jet:
	# 2 AP + 4 MP) never risks the two glyph runs colliding in a 52px slot.
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

	return root
