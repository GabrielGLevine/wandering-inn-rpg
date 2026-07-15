class_name UIChrome
extends RefCounted

## Fallback-art contract (UI chrome half). These were `const
## preload(...)` -- but preload is COMPILE-TIME, so a public checkout missing
## the Tiny Swords bundle (see assets_manifest.json) failed to compile
## UIChrome, cascading a parse error through EVERY UI script and preventing
## boot entirely. They are now `static var`s resolved at RUNTIME via
## `chrome_texture()`, which returns the real texture when present (ZERO
## behavior change) or a generated NinePatch-safe placeholder when the file is
## absent. External call sites (`UIChrome.PARCHMENT_PANEL`, etc.) are
## unchanged -- static-var access reads identically to the old const access.
const THEME_PATH := "res://assets/ui/chrome/wi_ui_theme.tres"

static var THEME: Theme = _chrome_theme()
static var PARCHMENT_PANEL: Texture2D = chrome_texture("res://assets/ui/chrome/Banner_Vertical.png")
static var PARCHMENT_STRIP: Texture2D = chrome_texture("res://assets/ui/chrome/Banner_Horizontal.png")
static var CARVED_PANEL: Texture2D = chrome_texture("res://assets/ui/chrome/Carved_9Slides.png")
static var BLUE_BUTTON: Texture2D = chrome_texture("res://assets/ui/chrome/Button_Blue_9Slides.png")
static var BLUE_BUTTON_PRESSED: Texture2D = chrome_texture("res://assets/ui/chrome/Button_Blue_9Slides_Pressed.png")
static var BLUE_RIBBON: Texture2D = chrome_texture("res://assets/ui/chrome/Ribbon_Blue_3Slides.png")

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

const PATCH_MARGIN := 24
const STRIP_PATCH_MARGIN := 20
const RIBBON_PATCH_MARGIN_X := 36
const RIBBON_PATCH_MARGIN_Y := 16

const PARCHMENT_REGION := Rect2(36, 31, 120, 131)
const BANNER_H_REGION := Rect2(33, 47, 126, 123)
## Without the crop, PATCH_MARGIN's 24px corner bands rendered those empty
## rows 1:1 into the control rect (~8px dead space at a 44px row's bottom),
## so a rect-centered label sat ~4px LOW against the VISIBLE pill band on
## unpressed rows -- while the pressed art's split 4-top/8-bottom emptiness
## roughly halved the error and masked it on the selected row (exactly the
## user-reported title-menu read: "New Game" centered, "Continue"/"Quit"
## riding the pill's bottom edge). With the region crop the pill fills the
## whole control rect, so label centering is honest in BOTH states wherever
## these buttons are used (title_screen.gd, char_creation.gd). Texture
## SWAPS on cursor move must go through `set_patch_texture` (below) so the
## region follows the texture -- the two bboxes differ.
const BLUE_BUTTON_REGION := Rect2(7, 0, 178, 184)
const BLUE_BUTTON_PRESSED_REGION := Rect2(5, 4, 182, 180)


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


## Full-rect NinePatchRect with SYMMETRIC patch margins on all four sides —
## the default for square-ish chrome (parchment panels, carved wood, blue
## buttons). Region contract: an explicit `region` always wins; otherwise
## known floating-art textures get their measured art bbox via _auto_region;
## anything else 9-slices the full texture.
static func make_patch(texture: Texture2D, margin: int = PATCH_MARGIN, region: Rect2 = Rect2()) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = texture
	var art_region := region if region.size != Vector2.ZERO else _auto_region(texture)
	if art_region.size != Vector2.ZERO:
		patch.region_rect = art_region
	patch.patch_margin_left = margin
	patch.patch_margin_right = margin
	patch.patch_margin_top = margin
	patch.patch_margin_bottom = margin
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(patch)
	return patch


## Full-rect NinePatchRect with ASYMMETRIC margins — wide left/right, short
## top/bottom — for landscape chrome whose flourishes live on its ends (the
## blue ribbon's tails). Same auto-region contract as make_patch (no explicit
## `region` override — none of the ribbon-shaped chrome floats in a canvas).
static func make_horizontal_patch(texture: Texture2D, margin_x: int, margin_y: int) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = texture
	var art_region := _auto_region(texture)
	if art_region.size != Vector2.ZERO:
		patch.region_rect = art_region
	patch.patch_margin_left = margin_x
	patch.patch_margin_right = margin_x
	patch.patch_margin_top = margin_y
	patch.patch_margin_bottom = margin_y
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(patch)
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
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, margin)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		return PARCHMENT_REGION
	if _is_same_art(texture, PARCHMENT_STRIP):
		return BANNER_H_REGION
	if _is_same_art(texture, BLUE_BUTTON):
		return BLUE_BUTTON_REGION
	if _is_same_art(texture, BLUE_BUTTON_PRESSED):
		return BLUE_BUTTON_PRESSED_REGION
	return Rect2()


## Every texture swap on a chrome patch must route through here.
static func set_patch_texture(patch: NinePatchRect, texture: Texture2D) -> void:
	patch.texture = texture
	patch.region_rect = _auto_region(texture)


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
