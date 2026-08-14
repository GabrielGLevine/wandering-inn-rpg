extends SceneTree

const MESSAGE_LAYER_PATH := "res://src/ui/message_layer.gd"
const COMBAT_SCREEN_PATH := "res://src/combat/combat_screen.gd"
const SETTINGS_PATH := "user://test_settings_issue_118.cfg"


func _init() -> void:
	WITestWatchdog.arm(self)
	_reset_test_settings_file()
	_check_text_scale_math()
	_check_text_scale_drift_tripwire()
	_check_chronicle_persistence()
	_check_settings_persistence()
	_check_field_readout_persistence()
	_check_field_hotbar_layout()
	_check_combat_speed_math()
	_check_audio_bus_routing()
	_check_hint_reset_functions()
	_check_reduce_motion_gate_sites()
	_check_quest_hints_persistence()
	_check_difficulty_ladder()
	_reset_test_settings_file()
	print("PASS: settings + accessibility surface (WISettings/WIAudio/hint-replay/reduce-motion) holds")
	quit(0)


func _check_chronicle_persistence() -> void:
	var script := load("res://src/ui/wi_settings.gd")
	var empty = _settings_instance(script)
	assert((empty.latest_chronicle() as Dictionary).is_empty(),
		"latest_chronicle must return an empty dictionary before any run is recorded")
	empty.free()

	var original := {
		"schema": 1,
		"name": "Sella",
		"race": "Human",
		"classes": [{"name": "Mage", "level": 4}],
		"quests_completed": 2,
		"victories": 3,
		"sleeps": 5,
		"ending": "The seal holds.",
	}
	var expected: Dictionary = original.duplicate(true)
	var writer = _settings_instance(script)
	writer.record_chronicle(original)
	original["classes"][0]["level"] = 99
	var buffered_settings: ConfigFile = writer.get("_settings")
	var buffered: Dictionary = buffered_settings.get_value("chronicle", "latest")
	assert(buffered["classes"][0]["level"] == 4,
		"record_chronicle must deep-copy nested input before retaining it")
	var persisted := ConfigFile.new()
	assert(persisted.load(SETTINGS_PATH) == OK,
		"record_chronicle must write the isolated settings path")
	assert(persisted.has_section_key("chronicle", "latest"),
		"record_chronicle must write [chronicle] latest")
	assert(persisted.get_value("chronicle", "latest") == expected,
		"[chronicle] latest must contain the recorded facts")
	writer.free()

	var reader = _settings_instance(script)
	var loaded: Dictionary = reader.latest_chronicle()
	assert(loaded == expected,
		"a fresh settings instance must round-trip the recorded Chronicle")
	loaded["classes"][0]["level"] = 12
	assert(reader.latest_chronicle()["classes"][0]["level"] == 4,
		"latest_chronicle must isolate nested caller mutations with a deep copy")
	reader.free()

	var corrupt := ConfigFile.new()
	assert(corrupt.load(SETTINGS_PATH) == OK, "corrupt-shape setup must load isolated settings")
	corrupt.set_value("chronicle", "latest", {"schema": 1, "classes": null})
	assert(corrupt.save(SETTINGS_PATH) == OK, "corrupt-shape setup must save isolated settings")
	var corrupt_reader = _settings_instance(script)
	assert((corrupt_reader.latest_chronicle() as Dictionary).is_empty(),
		"latest_chronicle must reject a corrupt nested shape before title rendering")
	corrupt_reader.free()
	_clear_chronicle_section()


func _clear_chronicle_section() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	if not config.has_section("chronicle"):
		return
	config.erase_section("chronicle")
	assert(config.save(SETTINGS_PATH) == OK,
		"Chronicle test cleanup must preserve all non-Chronicle settings")


func _settings_instance(script: Script) -> Node:
	var instance = script.new()
	instance.set("_settings_path", SETTINGS_PATH)
	assert(instance.get("_settings_path") == SETTINGS_PATH,
		"settings tests require an injectable path before any load/write")
	instance.call("_load_settings")
	return instance


func _reset_test_settings_file() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		assert(DirAccess.remove_absolute(SETTINGS_PATH) == OK,
			"settings test must clean only its isolated file")


func _check_text_scale_math() -> void:
	var settings_script := load("res://src/ui/wi_settings.gd")
	var expected_base := {"Label": 14, "Header": 18, "Title": 36, "Menu": 18, "MenuInk": 18, "Small": 12, "Lore": 12}

	assert(int(settings_script.call("scaled_default_font_size", 0)) == 14, "text scale step 0 must restore the exact base default_font_size (14)")
	var base_types: Dictionary = settings_script.call("scaled_type_font_sizes", 0)
	for key: String in expected_base:
		assert(int(base_types[key]) == int(expected_base[key]), "text scale step 0 type '%s' expected %d, got %s" % [key, int(expected_base[key]), str(base_types[key])])

	assert(int(settings_script.call("scaled_default_font_size", 2)) == 18, "text scale step 2 (130%%) default_font_size: round(14*1.3)=18")
	var big_types: Dictionary = settings_script.call("scaled_type_font_sizes", 2)
	for key: String in expected_base:
		assert(int(big_types[key]) > int(expected_base[key]), "text scale step 2 type '%s' (%s) must be strictly larger than base (%s)" % [key, str(big_types[key]), str(expected_base[key])])

	assert(int(settings_script.call("scaled_default_font_size", 0)) == 14, "text scale step 0, re-derived AFTER computing step 2, must still be exactly 14 -- no drift")
	var base_types_again: Dictionary = settings_script.call("scaled_type_font_sizes", 0)
	for key: String in expected_base:
		assert(int(base_types_again[key]) == int(expected_base[key]), "text scale step 0 type '%s', re-derived after step 2, drifted from base" % key)


func _check_text_scale_drift_tripwire() -> void:
	var theme_src := FileAccess.get_file_as_string("res://assets/ui/chrome/wi_ui_theme.tres")
	assert(theme_src != "", "could not read wi_ui_theme.tres")
	_assert_theme_const(theme_src, "default_font_size", 14)
	_assert_theme_const(theme_src, "Label/font_sizes/font_size", 14)
	_assert_theme_const(theme_src, "Header/font_sizes/font_size", 18)
	_assert_theme_const(theme_src, "Title/font_sizes/font_size", 36)
	_assert_theme_const(theme_src, "Menu/font_sizes/font_size", 18)
	_assert_theme_const(theme_src, "MenuInk/font_sizes/font_size", 18)
	_assert_theme_const(theme_src, "Small/font_sizes/font_size", 12)
	_assert_theme_const(theme_src, "Lore/font_sizes/font_size", 12)


## Reads `const NAME := <number>` out of GDScript SOURCE. See the note in
## `_check_field_hotbar_layout`: the UI scripts these constants live in cannot be
## `load()`ed from a `--script` run without raising autoload Compile Errors.
func _const_float(src: String, name: String) -> float:
	var re := RegEx.new()
	re.compile("const\\s+%s\\s*:=\\s*(-?[0-9]+\\.?[0-9]*)" % name)
	var m := re.search(src)
	assert(m != null, "could not find `const %s := <number>` in source" % name)
	return float(m.get_string(1))


func _assert_theme_const(src: String, key: String, expected: int) -> void:
	var re := RegEx.new()
	re.compile("%s\\s*=\\s*(\\d+)" % key.replace("/", "\\/"))
	var m := re.search(src)
	assert(m != null, "wi_ui_theme.tres: could not find `%s = ...`" % key)
	var found := int(m.get_string(1))
	assert(found == expected, "DRIFT: wi_ui_theme.tres's `%s` is %d but wi_settings.gd's BASE consts mirror %d -- update the mirrored const" % [key, found, expected])


func _check_settings_persistence() -> void:
	var script := load("res://src/ui/wi_settings.gd")
	var a = _settings_instance(script)
	a.call("set_fullscreen", true)
	a.call("set_text_scale_step", 2)
	a.call("set_reduce_motion", true)
	a.call("set_combat_speed_step", 2)
	assert(bool(a.call("is_fullscreen")) == true, "set_fullscreen(true) must read back true")
	assert(int(a.call("text_scale_step")) == 2, "set_text_scale_step(2) must read back 2")
	assert(bool(a.call("reduce_motion")) == true, "set_reduce_motion(true) must read back true")
	assert(int(a.call("combat_speed_step")) == 2, "set_combat_speed_step(2) must read back 2")
	a.free()

	var b = _settings_instance(script)
	assert(bool(b.call("is_fullscreen")) == true, "a fresh instance must load the persisted fullscreen=true")
	assert(int(b.call("text_scale_step")) == 2, "a fresh instance must load the persisted text_scale_step=2")
	assert(bool(b.call("reduce_motion")) == true, "a fresh instance must load the persisted reduce_motion=true")
	assert(int(b.call("combat_speed_step")) == 2, "a fresh instance must load the persisted combat_speed_step=2")

	b.call("set_fullscreen", false)
	b.call("set_text_scale_step", 0)
	b.call("set_reduce_motion", false)
	b.call("set_combat_speed_step", 0)
	b.free()


## Issue #345 — the difficulty ladder. The load-bearing facts, in order of how
## badly each would hurt if it broke:
##   1. SILVER IS 1.0. It is the default, and it is the shipped balance. If it
##      ever stopped being exactly 1.0, every balance cell, every seeded QA
##      fight and every existing save would quietly change underneath a player
##      who never touched the row.
##   2. The names are CANON (Liscor Hunted's Bronze/Silver/Gold challenge
##      ranks, wiki-verified under the user's names-only Vol 7 exception) and
##      in ascending order, so a rename or a reorder that made "Bronze" the
##      hard one has to be deliberate.
##   3. It round-trips like every sibling knob, and out-of-range input clamps
##      rather than crashing an index.
func _check_difficulty_ladder() -> void:
	var script := load("res://src/ui/wi_settings.gd")
	var names: Array = Array(script.DIFFICULTY_LABELS)
	assert(names == ["Bronze Rank", "Silver Rank", "Gold Rank"],
		"the three difficulty names are Liscor Hunted's own challenge ranks, in ascending order, got: %s" % [names])
	assert(script.DIFFICULTY_LABELS.size() == script.DIFFICULTY_DAMAGE_TAKEN_MULTS.size(),
		"every difficulty name must have a multiplier and vice versa")
	assert(is_equal_approx(float(script.damage_taken_mult_for_step(script.DIFFICULTY_DEFAULT_STEP)), 1.0),
		"the DEFAULT rung must be exactly 1.0 -- it is the shipped balance, and every band/fixture depends on it being untouched")
	assert(String(script.DIFFICULTY_LABELS[script.DIFFICULTY_DEFAULT_STEP]) == "Silver Rank",
		"Silver Rank is the default rung (Bronze Rank softer, Gold Rank sharper)")
	var mults: Array = Array(script.DIFFICULTY_DAMAGE_TAKEN_MULTS)
	for i in mults.size() - 1:
		assert(float(mults[i]) < float(mults[i + 1]),
			"the ladder must rise: rung %d (%s) is not gentler than rung %d (%s)" % [i, mults[i], i + 1, mults[i + 1]])
	assert(is_equal_approx(float(script.damage_taken_mult_for_step(-5)), float(mults[0])) and is_equal_approx(float(script.damage_taken_mult_for_step(99)), float(mults[mults.size() - 1])),
		"an out-of-range step clamps to an end of the ladder, never indexes off it")

	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	if config.has_section_key("combat", "difficulty_step"):
		config.erase_section_key("combat", "difficulty_step")
	assert(config.save(SETTINGS_PATH) == OK, "difficulty setup must preserve other settings")

	var fresh = _settings_instance(script)
	assert(int(fresh.call("difficulty_step")) == script.DIFFICULTY_DEFAULT_STEP,
		"with no persisted key the ladder reads its default rung")
	assert(is_equal_approx(float(fresh.call("difficulty_damage_taken_mult")), 1.0),
		"...and the getter L2's apply-site reads returns the shipped 1.0 there")
	fresh.call("cycle_difficulty")
	assert(String(fresh.call("difficulty_label")) == "Gold Rank" and int(fresh.call("difficulty_step")) == 2, "cycle steps forward")
	fresh.call("cycle_difficulty")
	assert(int(fresh.call("difficulty_step")) == 0, "...and wraps around the end")
	fresh.call("set_difficulty_step", 2)
	fresh.free()

	var reloaded = _settings_instance(script)
	assert(int(reloaded.call("difficulty_step")) == 2 and String(reloaded.call("difficulty_label")) == "Gold Rank",
		"a fresh instance loads the persisted rung -- changeable ANY time means it has to survive the process, not just the panel")
	assert(float(reloaded.call("difficulty_damage_taken_mult")) > 1.0, "Gold Rank sharpens what a hit costs")
	reloaded.call("set_difficulty_step", script.DIFFICULTY_DEFAULT_STEP)
	reloaded.free()


## GH#338 — "Quest Hints" is the FIRST knob in this file that defaults to ON,
## which makes its absent-key behaviour load-bearing in a way none of its
## siblings' is: a `get_value(..., false)` typo would silently ship the feature
## switched off for every existing player and no other test would notice.
## Also pinned: its own section, so it cannot collide with the field-HUD
## "Quest Thread" knob it is deliberately independent of.
func _check_quest_hints_persistence() -> void:
	var script := load("res://src/ui/wi_settings.gd")
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	if config.has_section("journal"):
		config.erase_section("journal")
	assert(config.save(SETTINGS_PATH) == OK, "quest-hints setup must preserve other settings")

	var fresh = _settings_instance(script)
	assert(bool(fresh.call("show_quest_hints")) == true,
		"with NO persisted key, Quest Hints must read ON -- clarity-by-default is the whole ruling")
	assert(bool(fresh.call("show_quest_thread")) == false,
		"...and the field-HUD Quest Thread knob stays default-OFF beside it, untouched")
	fresh.call("toggle_show_quest_hints")
	assert(bool(fresh.call("show_quest_hints")) == false, "the toggle turns it off")
	fresh.free()

	var reloaded = _settings_instance(script)
	assert(bool(reloaded.call("show_quest_hints")) == false,
		"a fresh instance loads the persisted OFF -- a default-ON knob must still be able to persist false")
	reloaded.call("set_show_quest_hints", true)
	reloaded.free()

	var restored = _settings_instance(script)
	assert(bool(restored.call("show_quest_hints")) == true, "and back ON round-trips too")
	restored.free()

	var stored := ConfigFile.new()
	stored.load(SETTINGS_PATH)
	assert(stored.has_section_key("journal", "quest_hints"),
		"the knob persists under its own [journal] section, not on top of [field_hud]")


func _check_field_readout_persistence() -> void:
	var source := FileAccess.get_file_as_string("res://src/ui/wi_settings.gd")
	assert(source.find("func field_readout_expanded() -> bool:") != -1,
		"WISettings must own the persisted field-readout preference")
	var script := load("res://src/ui/wi_settings.gd")
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	if config.has_section("field_hud"):
		config.erase_section("field_hud")
	assert(config.save(SETTINGS_PATH) == OK, "field-readout setup must preserve other settings")

	# TRAP (#118/#119 merge lesson): every instance goes through
	# _settings_instance — a bare script.new() reads AND WRITES the real
	# user://settings.cfg (the exact stomping #118 outlawed), and passes or
	# fails depending on what the developer's own cfg happens to contain.
	var missing = _settings_instance(script)
	assert(bool(missing.call("field_readout_expanded")), "missing field-readout key must expose names/mechanics")
	assert(not bool(missing.call("has_field_readout_choice")), "missing field-readout key is not an explicit player choice")
	missing.call("set_field_readout_expanded", false)
	missing.free()

	var persisted = _settings_instance(script)
	assert(not bool(persisted.call("field_readout_expanded")), "collapsed field readout must round-trip through settings.cfg")
	assert(bool(persisted.call("has_field_readout_choice")), "a persisted bool is an explicit player choice")
	persisted.free()

	config.load(SETTINGS_PATH)
	config.set_value("field_hud", "readout_expanded", "corrupt")
	assert(config.save(SETTINGS_PATH) == OK, "field-readout corrupt-key setup must save")
	var corrupt = _settings_instance(script)
	assert(bool(corrupt.call("field_readout_expanded")), "wrong-typed field-readout key must fall back expanded")
	assert(not bool(corrupt.call("has_field_readout_choice")), "wrong-typed field-readout key must not become a player choice")
	corrupt.free()

	config.load(SETTINGS_PATH)
	config.erase_section("field_hud")
	assert(config.save(SETTINGS_PATH) == OK, "field-readout cleanup must preserve other settings")


func _check_field_hotbar_layout() -> void:
	const LAYOUT_PATH := "res://src/ui/field_hotbar_layout.gd"
	assert(FileAccess.file_exists(LAYOUT_PATH), "field hotbar needs a pure safe-area layout seam")
	var hotbar_source := FileAccess.get_file_as_string("res://src/ui/field_hotbar.gd")
	assert(hotbar_source.contains("vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO"),
		"overflowing field mechanics must remain available through scrolling")
	var layout := load(LAYOUT_PATH)
	assert(String(layout.call("fallback_label", "[Basic Cleaning]", "basic_cleaning")) == "BC",
		"multi-word missing icons need a readable initials fallback")
	assert(String(layout.call("fallback_label", "[Invisibility]", "invisibility")) == "INV",
		"single-word missing icons need a readable three-letter fallback")
	var mapped_safe: Rect2 = layout.call("viewport_safe_rect", Vector2(844, 390), Rect2i(18, 16, 808, 356), Vector2i(844, 390))
	assert(mapped_safe == Rect2(18, 16, 808, 356), "display safe-area insets must map into viewport space")

	assert(hotbar_source.contains("make_chrome_panel_container") and hotbar_source.contains("get_theme_stylebox(\"panel\")"),
		"field readout content and sizing must derive from its panel StyleBox")
	assert(hotbar_source.contains("_readout_scroll.clip_contents = true"),
		"overflow rows must clip at the StyleBox-managed scroll viewport")
	assert(not hotbar_source.contains("set_offsets(_readout_scroll"),
		"field readout scroll clipping must not use a manual inset inside the ornament")
	var chrome := load("res://src/ui/ui_chrome.gd")
	var panel: PanelContainer = chrome.call("make_chrome_panel_container", chrome.get("PARCHMENT_PANEL"), chrome.get("PATCH_MARGIN"))
	var style := panel.get_theme_stylebox("panel")
	var frame_size: Vector2 = layout.call("style_frame_size", style)
	assert(frame_size == Vector2(48, 48), "parchment content margins must match its 24px border ornament")
	panel.free()

	var viewports := [Vector2(1280, 720), Vector2(960, 540), Vector2(844, 390)]
	for step in 3:
		var font_size: int = int(load("res://src/ui/wi_settings.gd").call("scaled_default_font_size", step))
		for viewport: Vector2 in viewports:
			var safe := Rect2(Vector2(18, 16), viewport - Vector2(36, 34))
			for row_count in range(1, 10):
				var rows_height := float(row_count * (font_size + 4))
				var desired_height := rows_height + frame_size.y
				var rect: Rect2 = layout.call("readout_rect", safe, 720.0, desired_height, 104.0)
				var content_rect: Rect2 = layout.call("style_content_rect", rect, style)
				var rows_rect := Rect2(content_rect.position, Vector2(content_rect.size.x, rows_height))
				var visible_rows := rows_rect.intersection(content_rect)
				assert(safe.encloses(rect), "field readout must stay inside viewport/safe-area at text step %d, %s" % [step, str(viewport)])
				assert(content_rect.encloses(visible_rows), "row clipping must stay inside StyleBox content at %d rows, text step %d, %s" % [row_count, step, str(viewport)])
				if is_equal_approx(rect.size.y, desired_height):
					assert(content_rect.encloses(rows_rect), "all rows must clear both border ornaments at %d rows, text step %d, %s" % [row_count, step, str(viewport)])
				else:
					assert(is_equal_approx(visible_rows.end.y, content_rect.end.y), "overflow must clip cleanly at the content bottom at %d rows, text step %d, %s" % [row_count, step, str(viewport)])

	# VISUAL-LOG "Legend <-> toast mutual overdraw still LOSES COPY at length":
	# the toast strip draws on a HIGHER CanvasLayer than the readout, so wherever
	# the two rects share an x range the plate paints straight through the legend
	# -- and the vertical reserve cannot close it, because it is measured at the
	# strip's BASE height while a toast is as tall as its own copy wraps. The
	# exclusion is therefore HORIZONTAL and height-independent: the readout's
	# right edge must never reach the strip's live left edge. Derived here from
	# the same two message_layer constants field_hotbar.gd reads, so a retune of
	# the strip's own offsets moves the guard with it instead of stranding it.
	# SOURCE-parsed, never `load()`ed: message_layer.gd and field_hotbar.gd both
	# reference autoloads (ObservableBus, WIInputHints) that a `--script` run has
	# never registered, so loading either here raises a Compile Error the
	# preflight `unit` grep counts as a FAILURE even though the suite prints PASS.
	# The tripwire discipline `_check_text_scale_drift_tripwire` already uses.
	var message_source := FileAccess.get_file_as_string(MESSAGE_LAYER_PATH)
	var toast_left_offset := _const_float(message_source, "TOAST_LEFT")
	var toast_right_offset := _const_float(message_source, "TOAST_RIGHT")
	assert(toast_left_offset < 0.0 and toast_right_offset < 0.0,
		"the toast strip must stay bottom-RIGHT anchored for this exclusion to be derivable")
	var clearance := _const_float(hotbar_source, "TOAST_BAND_CLEARANCE")
	assert(clearance > 0.0, "the readout must keep a real gap from the toast band, not merely abut it")
	# The pure function below can only be trusted if the layer actually FEEDS it
	# the strip's live left edge -- derived from the viewport, never copied.
	assert(hotbar_source.contains("var toast_band_left: float = viewport_size.x + MESSAGE_LAYER_SCRIPT.TOAST_LEFT")
			and hotbar_source.contains("toast_band_left - TOAST_BAND_CLEARANCE"),
		"the field readout must pass the toast strip's LIVE left edge into readout_rect, not a copied constant")
	var outer_margin := float(layout.get("OUTER_MARGIN"))
	for viewport: Vector2 in viewports:
		var safe := Rect2(Vector2(18, 16), viewport - Vector2(36, 34))
		var band_left := viewport.x + toast_left_offset
		for row_count in range(1, 10):
			var desired_height := float(row_count * 24) + 48.0
			var rect: Rect2 = layout.call("readout_rect", safe, 720.0, desired_height, 104.0,
				band_left - clearance)
			assert(safe.encloses(rect),
				"the toast-band exclusion must not push the readout off its own safe area at %d rows, %s" % [row_count, str(viewport)])
			var left_stop := safe.position.x + outer_margin
			if left_stop + rect.size.x <= band_left - clearance:
				# The shipped 1280x720 case: the panel FITS beside the strip, so
				# the two rects must not share a single column of x.
				assert(rect.end.x <= band_left,
					"field readout must stay clear of the toast strip's x band at %d rows, %s (readout ends %f, band starts %f)"
						% [row_count, str(viewport), rect.end.x, band_left])
			else:
				# Narrower than the pair can hold (canvas_items stretch means the
				# shipped game never gets here; the mobile safe-area rows do).
				# Degrade to "as far left as the safe area allows" -- strictly less
				# overlap than centring, never a slide off the panel's own edge.
				assert(is_equal_approx(rect.position.x, left_stop),
					"a viewport too narrow for the exclusion must still push the readout hard left at %d rows, %s" % [row_count, str(viewport)])
			var centred := safe.position.x + (safe.size.x - rect.size.x) * 0.5
			assert(rect.position.x <= centred + 0.5,
				"the toast-band exclusion must only ever move the readout LEFT of centre at %d rows, %s" % [row_count, str(viewport)])


func _check_combat_speed_math() -> void:
	var settings_script := load("res://src/ui/wi_settings.gd")
	var base := 0.5
	assert(is_equal_approx(float(settings_script.call("beat_seconds_for_step", 0, base)), base), "combat speed step 0 (Normal) must leave AI_BEAT_SECONDS unchanged")
	assert(is_equal_approx(float(settings_script.call("beat_seconds_for_step", 1, base)), base * 0.5), "combat speed step 1 (Fast) must halve AI_BEAT_SECONDS")
	assert(is_equal_approx(float(settings_script.call("beat_seconds_for_step", 2, base)), 0.0), "combat speed step 2 (Instant) must zero AI_BEAT_SECONDS")


func _check_audio_bus_routing() -> void:
	var script := load("res://src/audio/wi_audio.gd")
	var inst = script.new()
	inst.call("_setup_buses")
	var ui_idx := AudioServer.get_bus_index("UI")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var music_idx := AudioServer.get_bus_index("Music")
	var voice_idx := AudioServer.get_bus_index("Voice")
	assert(ui_idx != -1, "UI bus must exist after _setup_buses")
	assert(AudioServer.get_bus_send(ui_idx) == "SFX", "issue #77 fix: UI bus must send to SFX (was Master -- the confirmed SFX-slider-ignores-UI bug)")
	assert(sfx_idx != -1 and AudioServer.get_bus_send(sfx_idx) == "Master", "SFX bus must still send straight to Master (unaffected by the fix)")
	assert(music_idx != -1 and AudioServer.get_bus_send(music_idx) == "Master", "Music bus must still send straight to Master")
	assert(voice_idx != -1 and AudioServer.get_bus_send(voice_idx) == "Master", "Voice bus must still send straight to Master")
	var ambience_idx := AudioServer.get_bus_index("Ambience")
	assert(ambience_idx != -1 and AudioServer.get_bus_send(ambience_idx) == "Master", "Ambience bus (issue #76 beds) must send straight to Master -- bed volume rides the Master slider only (no settings row)")
	inst.free()


func _check_hint_reset_functions() -> void:
	_check_static_flag_reset(MESSAGE_LAYER_PATH, "extends CanvasLayer", "_first_pickup_hint_shown")
	_check_static_flag_reset(COMBAT_SCREEN_PATH, "extends CanvasLayer", "_first_combat_hint_shown")


func _check_static_flag_reset(path: String, extends_line: String, flag_name: String) -> void:
	var raw := FileAccess.get_file_as_string(path)
	assert(raw.begins_with(extends_line), "%s: expected first line '%s'" % [path, extends_line])
	var first_nl := raw.find("\n")
	var stub := "\n\nvar Game: Variant = null\nvar ObservableBus: Variant = null\nvar TestDriver: Variant = null\nvar WIInputHints: Variant = null\nvar WISettings: Variant = null"
	var patched := raw.substr(0, first_nl) + stub + raw.substr(first_nl)
	var script := GDScript.new()
	script.source_code = patched
	var err := script.reload()
	assert(err == OK, "%s (autoload-stubbed copy) failed to compile: %d" % [path, err])
	script.set(flag_name, true)
	assert(bool(script.get(flag_name)) == true, "%s: setup could not set %s true" % [path, flag_name])
	script.call("reset_hints")
	assert(bool(script.get(flag_name)) == false, "%s: reset_hints() must clear %s" % [path, flag_name])


func _check_reduce_motion_gate_sites() -> void:
	var src := FileAccess.get_file_as_string("res://src/combat/board_renderer.gd")
	assert(src.find("func _reduce_motion() -> bool:") != -1, "board_renderer.gd must define the ONE shared _reduce_motion() gate")
	assert(src.find("WISettings.reduce_motion()") != -1, "_reduce_motion() must read WISettings.reduce_motion()")

	var juice_body := src.get_slice("func _juice_enabled() -> bool:", 1).get_slice("func impact_flash", 0)
	assert(juice_body.find("_reduce_motion()") != -1, "_juice_enabled() must check _reduce_motion() -- covers shake_board/impact_flash")

	var flash_chip_body := src.get_slice("func flash_chip(id: String) -> void:", 1).get_slice("func fade_chip", 0)
	assert(flash_chip_body.find("_reduce_motion()") != -1, "flash_chip() must check _reduce_motion() directly (not covered by _juice_enabled())")

	var flash_cells_body := src.get_slice("func flash_cells(cells: Array, color: Color) -> void:", 1)
	assert(flash_cells_body.find("_reduce_motion()") != -1, "flash_cells() must check _reduce_motion() directly (not covered by _juice_enabled())")
