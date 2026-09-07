class_name WICombatMobileLayout
extends RefCounted

const PAGE_SIZE := 4
const CELL_CSS := 44.0


static func regions(safe: Rect2, css_scale: float, line_height: float, pages: int,
		tutor_height := 0.0) -> Dictionary:
	var unit := 1.0 / maxf(css_scale, 0.01)
	var gap := 4.0 * unit
	var margin := 6.0 * unit
	var button := 44.0 * unit
	var rail_width := minf(270.0 * unit, safe.size.x * 0.48)
	var rail := Rect2(Vector2(safe.end.x - rail_width, safe.position.y), Vector2(rail_width, safe.size.y))
	var left := rail.position.x + margin
	var width := rail_width - margin * 2.0
	var slot := Vector2(60.0 * unit, maxf(72.0 * unit, line_height * 2.0 + 32.0 * unit))
	var bottom := safe.end.y - margin - button
	var page_height := button if pages > 1 else 0.0
	var pager_y := bottom - gap - page_height
	var hotbar_y := pager_y - gap - slot.y
	var active_y := safe.position.y + margin + button + gap
	var active_height := line_height * 3.0 + gap
	var context_y := active_y + active_height + gap
	var context_height := maxf(line_height, hotbar_y - gap - context_y)
	var board_right := rail.position.x - gap
	var note_height := minf(tutor_height, safe.size.y / 3.0)
	var board_top := safe.position.y + note_height + (gap if note_height > 0.0 else 0.0)
	return {
		"rail": rail,
		"board": Rect2(Vector2(safe.position.x, board_top), Vector2(board_right - safe.position.x, safe.end.y - board_top)),
		"tutor": Rect2(safe.position, Vector2(board_right - safe.position.x, note_height)),
		"details": Rect2(Vector2(left, safe.position.y + margin), Vector2(96.0 * unit, button)),
		"active": Rect2(Vector2(left, active_y), Vector2(width, active_height)),
		"context": Rect2(Vector2(left, context_y), Vector2(width, context_height)),
		"hotbar": Rect2(Vector2(left, hotbar_y), Vector2(width, slot.y)),
		"slot_size": slot,
		"page_previous": Rect2(Vector2(left, pager_y), Vector2(button, page_height)),
		"page_label": Rect2(Vector2(left + button + gap, pager_y), Vector2(width - button * 2.0 - gap * 2.0, page_height)),
		"page_next": Rect2(Vector2(left + width - button, pager_y), Vector2(button, page_height)),
		"previous": Rect2(Vector2(left, bottom), Vector2(button, button)),
		"next": Rect2(Vector2(left + button + gap, bottom), Vector2(button, button)),
		"back": Rect2(Vector2(left + button * 2.0 + gap * 2.0, bottom), Vector2(64.0 * unit, button)),
		"confirm": Rect2(Vector2(left + width - 82.0 * unit, bottom), Vector2(82.0 * unit, button)),
	}


static func pages(text: String, font: Font, font_size: int, width: float, height: float) -> Array[String]:
	var lines: Array[String] = []
	for paragraph: String in text.split("\n"):
		var line := ""
		for word: String in paragraph.split(" ", false):
			var candidate := word if line.is_empty() else line + " " + word
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= width:
				line = candidate
				continue
			if not line.is_empty():
				lines.append(line)
				line = ""
			for character: String in word:
				if font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > width and not line.is_empty():
					lines.append(line)
					line = ""
				line += character
		lines.append(line)
	var capacity := maxi(1, floori(height / font.get_height(font_size)))
	var result: Array[String] = []
	for first in range(0, lines.size(), capacity):
		result.append("\n".join(lines.slice(first, mini(first + capacity, lines.size()))))
	if result.is_empty():
		result.append("")
	return result
