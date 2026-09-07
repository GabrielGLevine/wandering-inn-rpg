extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	_run.call_deferred()


func _run() -> void:
	var font := ThemeDB.get_fallback_font()
	for css_height: float in [390.0, 412.0, 360.0]:
		var scale := css_height / 720.0
		for text_scale: float in [1.0, 1.15, 1.3]:
			var font_size := ceili(14.0 * text_scale / scale)
			var line_height := font.get_height(font_size)
			for pages: int in [1, 3, 9]:
				var safe := Rect2(12.0, 0.0, 1256.0, 720.0)
				var layout := WICombatMobileLayout.regions(safe, scale, line_height, pages, 110.0 / scale)
				var controls: Array[Rect2] = []
				for key: String in ["details", "page_previous", "page_next", "previous", "next", "back", "confirm"]:
					var rect: Rect2 = layout[key]
					if not rect.has_area():
						continue
					assert(safe.encloses(rect), "control must remain in the safe area: " + key)
					assert(rect.size.x * scale >= 43.99 and rect.size.y * scale >= 43.99, "44 CSS minimum: " + key)
					for other: Rect2 in controls:
						assert(not rect.intersects(other), "interactive regions cannot intersect")
					controls.append(rect)
				assert(not (layout["board"] as Rect2).intersects(layout["rail"]), "HUD cannot cover actionable board")
				assert((layout["board"] as Rect2).size.y * scale >= 44.0, "note must leave a usable board aperture")
				assert((layout["active"] as Rect2).end.y <= (layout["context"] as Rect2).position.y)
				assert((layout["context"] as Rect2).end.y <= (layout["hotbar"] as Rect2).position.y)
				var slots_width: float = layout["slot_size"].x * 4.0 + layout["slot_size"].x / 15.0 * 3.0
				assert(slots_width <= (layout["hotbar"] as Rect2).size.x, "uncapped actions page into a fitting row")
	var copy := "Full turn order and every cost remain accessible.\n\n[Power Strike] costs 2 AP. " + "LongName".repeat(12)
	var pages := WICombatMobileLayout.pages(copy, font, 28, 280.0, 100.0)
	assert(pages.size() > 2, "long detail copy must paginate")
	var retained := "".join(pages).replace(" ", "").replace("\n", "")
	assert(retained == copy.replace(" ", "").replace("\n", ""), "pagination must not lose or duplicate content")
	for page: String in pages:
		assert((page.count("\n") + 1) * font.get_height(28) <= 100.01)
		for line: String in page.split("\n"):
			assert(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28).x <= 280.01)
	_check_uncapped_bar()
	var focus := WICameraController.combat_focus(Vector2i(12, 8), Vector2(152, 128), 16.0, [Vector2i(2, 3), Vector2i(9, 4)])
	var view := Rect2(focus - Vector2(76, 64), Vector2(152, 128))
	assert(view.has_point(Vector2(2.5, 3.5) * 16.0) and view.has_point(Vector2(9.5, 4.5) * 16.0), "active and nearby target share the reserved board view")
	var left := WICameraController.combat_focus(Vector2i(20, 8), Vector2(152, 128), 16.0, [Vector2i(0, 0)])
	assert(left == Vector2(76, 64), "focus clamps at arena edge without hiding the actor")
	print("PASS: combat controls fit phone safe areas; overflow actions and paged details retain every entry")
	quit(0)


func _check_uncapped_bar() -> void:
	var bar := WIHotbar.new()
	root.add_child(bar)
	var received: Array[int] = []
	bar.slot_clicked.connect(func(index: int): received.append(index))
	var slots: Array = []
	for index in 37:
		slots.append({"label": "Action %d" % index, "ap_cost": index % 4, "mp_cost": index % 3})
	for page in WIHotbar.page_count(slots.size(), 4):
		bar.render_page(slots, -1, Vector2(100, 128), page, 4, 24)
		for child: Control in bar.get_children():
			var index := int(child.get_meta("slot_index"))
			assert(bar.slot_rect(index).has_area())
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			event.position = child.position + child.size * 0.5
			bar._gui_input(event)
	assert(received.size() == 37)
	for index in 37:
		assert(received[index] == index, "pages must dispatch the original uncapped slot index exactly once")
	bar.render(slots.slice(0, 3), -1)
	assert(bar.get_child_count() == 3 and bar.slot_rect(2).has_area(), "desktop row still renders normally after a touch page")
	bar.free()
