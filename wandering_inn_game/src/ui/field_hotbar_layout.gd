class_name WIFieldHotbarLayout
extends RefCounted

const OUTER_MARGIN := 10.0


static func fallback_label(display_name: String, skill_id: String) -> String:
	var clean := display_name.trim_prefix("[").trim_suffix("]").strip_edges()
	if clean == "":
		clean = skill_id.replace("_", " ").strip_edges()
	var words := clean.split(" ", false)
	if words.size() > 1:
		var initials := ""
		for word: String in words:
			initials += word.left(1).to_upper()
			if initials.length() == 3:
				break
		return initials if initials != "" else "?"
	return clean.left(3).to_upper() if clean != "" else "?"


## Converts physical display safe-area insets into viewport-space bounds.
## CONTRACT: invalid/headless display geometry means the full viewport.
static func viewport_safe_rect(viewport_size: Vector2, display_safe: Rect2i, display_size: Vector2i) -> Rect2:
	var full := Rect2(Vector2.ZERO, viewport_size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	if display_size.x <= 0 or display_size.y <= 0 or display_safe.size.x <= 0 or display_safe.size.y <= 0:
		return full
	var left := clampf(float(display_safe.position.x) / float(display_size.x) * viewport_size.x, 0.0, viewport_size.x)
	var top := clampf(float(display_safe.position.y) / float(display_size.y) * viewport_size.y, 0.0, viewport_size.y)
	var right := clampf(float(display_size.x - display_safe.end.x) / float(display_size.x) * viewport_size.x, 0.0, viewport_size.x)
	var bottom := clampf(float(display_size.y - display_safe.end.y) / float(display_size.y) * viewport_size.y, 0.0, viewport_size.y)
	var size := Vector2(maxf(0.0, viewport_size.x - left - right), maxf(0.0, viewport_size.y - top - bottom))
	return Rect2(Vector2(left, top), size) if size.x > 0.0 and size.y > 0.0 else full


## Clamps the detail panel above bottom controls; overflow stays scrollable.
##
## `right_limit` is the HORIZONTAL half of the same exclusion `reserved_bottom`
## does vertically -- the x the panel's right edge may not pass, which the caller
## derives from the toast strip's own live left edge. The vertical reserve alone
## could never close the overdraw: it clears the toast plate at its BASE height,
## and a toast is as tall as its copy wraps (a 4-line one tops out ~38px above
## that band and painted through the legend's last row, on a HIGHER CanvasLayer,
## clipping it mid-word). Height-independent by construction: two rects that do
## not share an x range cannot overdraw at ANY height. Centring yields, because
## centring is cosmetic and the copy is information -- the same trade
## `field_hotbar.gd`'s hint-band clamp already makes on the slot row.
## INF (the default) = no horizontal limit, the pre-exclusion behaviour.
static func readout_rect(safe_rect: Rect2, max_width: float, desired_height: float, reserved_bottom: float, right_limit := INF) -> Rect2:
	var width := minf(max_width, maxf(1.0, safe_rect.size.x - OUTER_MARGIN * 2.0))
	var height := minf(desired_height, maxf(1.0, safe_rect.size.y - reserved_bottom - OUTER_MARGIN * 2.0))
	var x := safe_rect.position.x + (safe_rect.size.x - width) * 0.5
	# Shift left only, then floor at the safe-area margin: a viewport too narrow
	# to hold both keeps today's behaviour rather than sliding off its own edge.
	x = maxf(minf(x, right_limit - width), safe_rect.position.x + OUTER_MARGIN)
	var y := safe_rect.end.y - reserved_bottom - OUTER_MARGIN - height
	return Rect2(Vector2(x, maxf(y, safe_rect.position.y + OUTER_MARGIN)), Vector2(width, height))


static func style_frame_size(style: StyleBox) -> Vector2:
	return Vector2(
		style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT),
		style.get_content_margin(SIDE_TOP) + style.get_content_margin(SIDE_BOTTOM),
	)


static func style_content_rect(panel_rect: Rect2, style: StyleBox) -> Rect2:
	var left := style.get_content_margin(SIDE_LEFT)
	var top := style.get_content_margin(SIDE_TOP)
	var frame_size := style_frame_size(style)
	return Rect2(panel_rect.position + Vector2(left, top), (panel_rect.size - frame_size).max(Vector2.ZERO))
