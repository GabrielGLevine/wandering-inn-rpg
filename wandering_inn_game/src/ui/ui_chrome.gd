class_name UIChrome
extends RefCounted

const THEME_PATH := "res://assets/ui/chrome/wi_ui_theme.tres"


static func install_touch_cancellation_bridge() -> void:
	if not OS.has_feature("web"):
		return
	# Godot 4.7 maps DOM touchcancel to touchend. Capture before that callback;
	# retain the primary contact's canceled state through its emulated release.
	JavaScriptBridge.eval("""
	if (!window.__WI_TOUCH_CANCEL_BRIDGE__) {
	 window.__WI_TOUCH_CANCEL_BRIDGE__ = true;
	 const active = new Set();
	 let primary = null;
	 window.__WI_TOUCH_CANCELED__ = new Set();
	 window.__WI_TOUCH_MOUSE_CANCELED__ = false;
	 document.addEventListener('touchstart', event => {
	  if (!active.size) {
	   primary = event.changedTouches[0].identifier;
	   window.__WI_TOUCH_CANCELED__.clear();
	   window.__WI_TOUCH_MOUSE_CANCELED__ = false;
	  }
	  for (const touch of event.changedTouches) active.add(touch.identifier);
	 }, {capture: true, passive: true});
	 for (const type of ['touchend', 'touchcancel']) {
	  document.addEventListener(type, event => {
	   for (const touch of event.changedTouches) {
	    active.delete(touch.identifier);
	    if (type === 'touchcancel') {
	     window.__WI_TOUCH_CANCELED__.add(touch.identifier);
	     if (touch.identifier === primary) window.__WI_TOUCH_MOUSE_CANCELED__ = true;
	    }
	   }
	  }, {capture: true, passive: true});
	 }
	}
	""", true)


static func pointer_canceled(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.canceled:
			return true
		return OS.has_feature("web") and not button.pressed and button.device == InputEvent.DEVICE_ID_EMULATION \
			and bool(JavaScriptBridge.eval("window.__WI_TOUCH_MOUSE_CANCELED__ === true", true))
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.canceled:
			return true
		return OS.has_feature("web") and not touch.pressed \
			and bool(JavaScriptBridge.eval("window.__WI_TOUCH_CANCELED__?.has(%d) === true" % touch.index, true))
	return false

static var THEME: Theme = _chrome_theme()
static var PARCHMENT_PANEL: Texture2D = chrome_texture("res://assets/ui/harvest/paper_panel.png")
static var PARCHMENT_STRIP: Texture2D = chrome_texture("res://assets/ui/harvest/paper_strip.png")
static var CARVED_PANEL: Texture2D = PARCHMENT_PANEL
static var BLUE_BUTTON: Texture2D = PARCHMENT_STRIP
static var BLUE_BUTTON_PRESSED: Texture2D = chrome_texture("res://assets/ui/harvest/brass_pressed.png")
static var BLUE_RIBBON: Texture2D = chrome_texture("res://assets/ui/harvest/walnut_strip.png")
static var DARK_SLOT: Texture2D = chrome_texture("res://assets/ui/harvest/dark_slot.png")

static var _chrome_placeholder_tex: Texture2D = null
static var _missing_chrome_logged: Dictionary = {}


## Runtime-load a chrome texture, or a generated placeholder if the file is
## absent (public checkout without the private bundle). Public so WIHotbar
## shares one placeholder mechanism. NOT preload -- a missing file must be a
## graceful runtime null, never a compile error.
static func chrome_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex: Texture2D = ResourceLoader.load(path)
		if tex != null:
			return tex
	_log_missing_chrome(path)
	return _chrome_fallback_texture()


static func _chrome_fallback_texture() -> Texture2D:
	if _chrome_placeholder_tex != null:
		return _chrome_placeholder_tex
	var side := 192
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.20, 0.19, 0.24, 0.88))
	var border := Color(0.44, 0.42, 0.50, 1.0)
	for x in side:
		img.set_pixel(x, 0, border)
		img.set_pixel(x, side - 1, border)
	for y in side:
		img.set_pixel(0, y, border)
		img.set_pixel(side - 1, y, border)
	_chrome_placeholder_tex = ImageTexture.create_from_image(img)
	return _chrome_placeholder_tex


static func _chrome_theme() -> Theme:
	if ResourceLoader.exists(THEME_PATH):
		var theme: Theme = ResourceLoader.load(THEME_PATH)
		if theme != null:
			return theme
	return Theme.new()


static func _log_missing_chrome(path: String) -> void:
	if _missing_chrome_logged.has(path):
		return
	_missing_chrome_logged[path] = true
	print("[fallback_art] missing sheet: %s" % path)

const PATCH_MARGIN := 12
const STRIP_PATCH_MARGIN := 5
const RIBBON_PATCH_MARGIN_X := 9
const RIBBON_PATCH_MARGIN_Y := 5

# Per-texture corners and padding: no slice may cross its flat center band.
static func _patch_margins(texture: Texture2D, fallback: int = PATCH_MARGIN) -> Vector4:
	if _is_same_art(texture, PARCHMENT_PANEL):
		return Vector4(23, 22, 23, 22)
	if _is_same_art(texture, PARCHMENT_STRIP):
		return Vector4(5, 5, 5, 5)
	if _is_same_art(texture, BLUE_RIBBON):
		return Vector4(9, 5, 9, 5)
	if _is_same_art(texture, BLUE_BUTTON_PRESSED):
		return Vector4(8, 6, 8, 6)
	if _is_same_art(texture, DARK_SLOT):
		return Vector4(5, 5, 5, 5)
	return Vector4(fallback, fallback, fallback, fallback)


static func _configure_patch(patch: NinePatchRect, texture: Texture2D, fallback: int) -> void:
	patch.texture = texture
	patch.region_rect = _auto_region(texture)
	var margins := _patch_margins(texture, fallback)
	patch.patch_margin_left = int(margins.x)
	patch.patch_margin_top = int(margins.y)
	patch.patch_margin_right = int(margins.z)
	patch.patch_margin_bottom = int(margins.w)
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var prior_inlay := patch.get_node_or_null("PressedPaperInlay")
	if prior_inlay != null:
		prior_inlay.free()
	if _is_same_art(texture, BLUE_BUTTON_PRESSED):
		var paper := ColorRect.new()
		paper.name = "PressedPaperInlay"
		paper.color = Color(240.0 / 255.0, 219.0 / 255.0, 176.0 / 255.0)
		paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		patch.add_child(paper)
		full_rect(paper)
		set_offsets(paper, margins.x, margins.y, -margins.z, -margins.w)


static func apply_theme(control: Control) -> void:
	control.theme = THEME


static func full_rect(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


static func set_offsets(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom


static func add_margins(container: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_bottom", bottom)


# Explicit regions override the measured alpha crop; owned chrome uses its own slices.
static func make_patch(texture: Texture2D, margin: int = PATCH_MARGIN, region: Rect2 = Rect2()) -> NinePatchRect:
	var patch := NinePatchRect.new()
	_configure_patch(patch, texture, margin)
	if region.size != Vector2.ZERO:
		patch.region_rect = region
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(patch)
	return patch


static func make_horizontal_patch(texture: Texture2D, margin_x: int, margin_y: int) -> NinePatchRect:
	var patch := make_patch(texture, margin_x)
	if _auto_region(texture).size == Vector2.ZERO:
		patch.patch_margin_top = margin_y
		patch.patch_margin_bottom = margin_y
	return patch


static func make_texture_patch(texture: Texture2D) -> NinePatchRect:
	if _is_same_art(texture, BLUE_RIBBON):
		return make_horizontal_patch(texture, RIBBON_PATCH_MARGIN_X, RIBBON_PATCH_MARGIN_Y)
	if _is_same_art(texture, PARCHMENT_STRIP):
		return make_patch(texture, STRIP_PATCH_MARGIN)
	return make_patch(texture, PATCH_MARGIN)


static func make_chrome_panel(texture: Texture2D = PARCHMENT_PANEL, margin: int = PATCH_MARGIN) -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(make_patch(texture, margin))
	return panel


static func make_chrome_panel_container(texture: Texture2D = PARCHMENT_PANEL, margin: int = PATCH_MARGIN) -> PanelContainer:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = _auto_region(texture)
	var margins := _patch_margins(texture, margin)
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	style.set_content_margin(SIDE_LEFT, margins.x + 5)
	style.set_content_margin(SIDE_TOP, margins.y + 4)
	style.set_content_margin(SIDE_RIGHT, margins.z + 5)
	style.set_content_margin(SIDE_BOTTOM, margins.w + 4)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_theme_stylebox_override("panel", style)
	return panel


static func make_texture_panel(texture: Texture2D = PARCHMENT_PANEL) -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(make_texture_patch(texture))
	return panel


static func make_label(text: String = "", type_variation: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if type_variation != "":
		label.theme_type_variation = type_variation
	return label


## Thin RichTextLabel constructor; styling via Theme type variations
## ("CombatReadout"), same contract as make_label.
static func make_rich_label(type_variation: String = "") -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.fit_content = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if type_variation != "":
		label.theme_type_variation = type_variation
	return label


static func _is_same_art(texture: Texture2D, reference: Texture2D) -> bool:
	return texture != null and texture.resource_path == reference.resource_path


static func _auto_region(texture: Texture2D) -> Rect2:
	if _is_same_art(texture, PARCHMENT_PANEL):
		return Rect2(0, 0, 80, 60)
	if _is_same_art(texture, PARCHMENT_STRIP):
		return Rect2(0, 0, 53, 20)
	if _is_same_art(texture, BLUE_RIBBON):
		return Rect2(0, 0, 72, 17)
	if _is_same_art(texture, BLUE_BUTTON_PRESSED):
		return Rect2(0, 0, 61, 24)
	if _is_same_art(texture, DARK_SLOT):
		return Rect2(0, 0, 37, 32)
	return Rect2()


# Texture changes also replace crop and slice geometry (normal and pressed differ).
static func set_patch_texture(patch: NinePatchRect, texture: Texture2D) -> void:
	_configure_patch(patch, texture, PATCH_MARGIN)


## Which entry in `controls` (Control nodes -- an Array[Label]/Array[Control],
## untyped param so either passes straight through) contains `local_pos` -- the
## caller's own `gui_input`/`mouse_entered` handler supplies `local_pos`
## already relative to the SAME parent every entry's own `position` is
## relative to (the exact Control whose `gui_input` fired), mirroring
## WIHotbar._slot_index_at's rect-scan idiom (issue #57) one level generic: a
## single filter+handler on the shared CONTAINER, not one filter per row (the
## STOP-vs-wheel-scroll trap a per-row filter would risk inside a
## ScrollContainer -- see inventory.gd's own item-row wiring). Skips a hidden
## (`!visible`) entry -- a hidden row can never be clicked, same discipline
## Godot's own input picking already applies on-screen. Returns -1 for no
## match. Promoted here once issue #84 needed the SAME scan in four panels
## (pause_menu.gd/dialogue_panel.gd/title_screen.gd/inventory.gd) --
## WIHotbar's own original stays a per-file copy (untouched, zero regression
## risk to the shipped #57 plumbing).
static func control_index_at(controls: Array, local_pos: Vector2) -> int:
	for i in controls.size():
		var c := controls[i] as Control
		if c == null or not c.visible:
			continue
		if Rect2(c.position, c.size).has_point(local_pos):
			return i
	return -1


## BBCode-escapes literal `[`/`]` (e.g. skill/combatant display names like
## "[Power Strike]") so they render as literal text instead of parsing as
## BBCode tags. MUST route through placeholder chars: the naive two-step
## `.replace("[", "[lb]").replace("]", "[rb]")` chain is self-colliding — the
## first replace's own output ("[lb]") contains a "]" the second replace then
## re-matches, garbling every bracketed name ("[Power Strike]" ->
## "[lb[rb]Power Strike[rb]" -- was user-visible on the
## combat slot-info line). Promoted from three per-file
## copies (journal.gd/combat_hud.gd/targeting_controller.gd -- the M6.5
## zero-cross-dependency idiom, amended for this one case: all three already
## reference UIChrome, a plain class_name script, not an autoload, so routing
## through here adds no new dependency for any of them) to this ONE shared
## home. Keep the PLACEHOLDER form byte-identical if this is ever touched
## again -- `combat_move_input` pins the escaped `[Power Strike]` slot-info
## text as the regression tooth.
static func bb_escape(s: String) -> String:
	var placeholder_open := char(1)
	var placeholder_close := char(2)
	return s.replace("[", placeholder_open).replace("]", placeholder_close) \
			.replace(placeholder_open, "[lb]").replace(placeholder_close, "[rb]")
