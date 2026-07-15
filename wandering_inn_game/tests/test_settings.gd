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
	_check_combat_speed_math()
	_check_audio_bus_routing()
	_check_hint_reset_functions()
	_check_reduce_motion_gate_sites()
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
	var expected_base := {"Label": 14, "Header": 18, "Title": 36, "Menu": 18, "Small": 12, "Lore": 12}

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
	_assert_theme_const(theme_src, "Small/font_sizes/font_size", 12)
	_assert_theme_const(theme_src, "Lore/font_sizes/font_size", 12)


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
