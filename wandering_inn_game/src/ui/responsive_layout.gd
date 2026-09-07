class_name WIResponsiveLayout
extends RefCounted

const MIN_TOUCH_CSS := 44.0
const MIN_TEXT_CSS := 14.0


static func uses_touch_layout() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches", true))
	return OS.has_feature("mobile")


static func css_scale(viewport: Viewport) -> float:
	var scale := viewport.get_screen_transform().get_scale().abs()
	return maxf(0.01, minf(scale.x, scale.y))


static func touch_size(viewport: Viewport, desktop_size: Vector2) -> Vector2:
	if not uses_touch_layout():
		return desktop_size
	return desktop_size.max(Vector2.ONE * ceilf(MIN_TOUCH_CSS / css_scale(viewport)))


static func readable_font_size(viewport: Viewport, desktop_size: int, text_scale := 1.0) -> int:
	if not uses_touch_layout():
		return desktop_size
	return maxi(desktop_size, int(ceil(MIN_TEXT_CSS * text_scale / css_scale(viewport))))


static func css_rect(viewport: Viewport, rect: Rect2) -> Rect2:
	return viewport.get_screen_transform() * rect


static func apply_readable_theme(control: Control, viewport: Viewport, text_scale: float) -> void:
	if not uses_touch_layout():
		control.theme = UIChrome.THEME
		return
	var theme := UIChrome.THEME.duplicate() as Theme
	var minimum := readable_font_size(viewport, theme.default_font_size, text_scale)
	theme.default_font_size = minimum
	for type_name: String in ["Label", "Header", "Title", "Menu", "MenuInk", "Small", "Lore"]:
		theme.set_font_size("font_size", type_name, maxi(minimum, theme.get_font_size("font_size", type_name)))
	for font_key: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		theme.set_font_size(font_key, "RichTextLabel", minimum)
	control.theme = theme


static func safe_rect(viewport: Viewport) -> Rect2:
	var bounds := viewport.get_visible_rect()
	if OS.has_feature("web"):
		var encoded: Variant = JavaScriptBridge.eval("""
		(() => {
		 if (!window.__wiSafeAreaProbe) {
		  const probe = document.createElement('div');
		  probe.style.cssText = 'position:fixed;visibility:hidden;pointer-events:none;padding:env(safe-area-inset-top,0px) env(safe-area-inset-right,0px) env(safe-area-inset-bottom,0px) env(safe-area-inset-left,0px)';
		  document.body.appendChild(probe);
		  window.__wiSafeAreaProbe = probe;
		 }
		 const css = getComputedStyle(window.__wiSafeAreaProbe);
		 return JSON.stringify([parseFloat(css.paddingLeft),parseFloat(css.paddingTop),innerWidth-parseFloat(css.paddingRight),innerHeight-parseFloat(css.paddingBottom)]);
		})()
		""", true)
		var edges: Variant = JSON.parse_string(String(encoded)) if encoded is String else null
		if edges is Array and edges.size() == 4:
			var origin := Vector2(float(edges[0]), float(edges[1]))
			var end := Vector2(float(edges[2]), float(edges[3]))
			var css_bounds := Rect2(origin, end - origin)
			return bounds.intersection(viewport.get_screen_transform().affine_inverse() * css_bounds)
	elif OS.has_feature("mobile") or DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN:
		return WIFieldHotbarLayout.viewport_safe_rect(bounds.size, DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size())
	return bounds


static func modal_rect(viewport: Viewport, desktop_size: Vector2) -> Rect2:
	var size := viewport.get_visible_rect().size
	if not uses_touch_layout():
		return Rect2((size - desktop_size) * 0.5, desktop_size)
	var safe := safe_rect(viewport)
	var top := touch_size(viewport, Vector2(84.0, 40.0)).y + 20.0
	return Rect2(safe.position + Vector2(24.0, top), Vector2(safe.size.x - 48.0, maxf(1.0, safe.size.y - top - 20.0)))


static func place_panel(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.custom_minimum_size = rect.size
	control.size = rect.size
	UIChrome.set_offsets(control, rect.position.x, rect.position.y, rect.end.x, rect.end.y)
