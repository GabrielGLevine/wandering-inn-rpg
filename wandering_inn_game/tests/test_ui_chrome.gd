extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	for texture: Texture2D in [UIChrome.PARCHMENT_PANEL, UIChrome.PARCHMENT_STRIP,
			UIChrome.CARVED_PANEL, UIChrome.BLUE_BUTTON, UIChrome.BLUE_BUTTON_PRESSED,
			UIChrome.BLUE_RIBBON, UIChrome.DARK_SLOT]:
		var patch := UIChrome.make_texture_patch(texture)
		assert(patch.region_rect.size.x <= texture.get_width() and patch.region_rect.size.y <= texture.get_height(),
			"chrome crop must remain inside the owned texture")
		assert(patch.patch_margin_left + patch.patch_margin_right < patch.region_rect.size.x,
			"horizontal slices need a real center band")
		assert(patch.patch_margin_top + patch.patch_margin_bottom < patch.region_rect.size.y,
			"vertical slices need a real center band")
		var image := texture.get_image()
		assert(image.get_pixel(image.get_width() / 2, image.get_height() / 2).a == 1.0,
			"text-bearing paper and wood must have opaque centers")
		patch.free()
	var button := UIChrome.make_patch(UIChrome.BLUE_BUTTON)
	assert(button.patch_margin_top == 5 and button.region_rect.size == Vector2(53, 20))
	UIChrome.set_patch_texture(button, UIChrome.BLUE_BUTTON_PRESSED)
	assert(button.patch_margin_top == 6 and button.region_rect.size == Vector2(61, 24),
		"pressed swaps must update both crop and texture-specific corners")
	assert(button.has_node("PressedPaperInlay"), "selected paper keeps brass on the rim, even on large cards")
	UIChrome.set_patch_texture(button, UIChrome.BLUE_BUTTON)
	assert(not button.has_node("PressedPaperInlay"), "normal swap removes the selected paper inlay")
	assert(button.patch_margin_top == 5 and button.region_rect.size == Vector2(53, 20))
	button.free()
	var panel := UIChrome.make_chrome_panel_container(UIChrome.CARVED_PANEL)
	var style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	assert(style.get_content_margin(SIDE_LEFT) > style.texture_margin_left
		and style.get_content_margin(SIDE_TOP) > style.texture_margin_top,
		"paper content must sit inside its border instead of on the ornament")
	panel.free()
	print("PASS: owned chrome crops, opaque centers, distinct slice margins and swap geometry hold")
	quit(0)
