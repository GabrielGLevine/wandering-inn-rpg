extends SceneTree
## Issue #77 coverage: WISettings' pure text-scale math + persistence,
## WIAudio's UI-bus-routing fix (a real AudioServer.get_bus_send probe,
## not by ear), the two hint-replay reset_hints() static functions, and a
## raw-source check that board_renderer.gd's reduce-motion gate covers
## every shake/flash juice call site.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_settings.gd
##
## `wi_audio.gd` and `wi_settings.gd` reach autoloads only via
## `get_node_or_null("/root/...")` (a STRING lookup, not a bare identifier),
## so both compile and instantiate cleanly under bare --script mode with NO
## source patching -- confirmed empirically, unlike message_layer.gd/
## combat_screen.gd (bare `ObservableBus`/`Game`/`TestDriver`/`WIInputHints`
## identifiers throughout), which need the same patched-source stub
## tests/test_input_hints.gd/tests/test_combat_visuals.gd already established.
## `.free()` every bare Node instance before quit() -- an unfree'd instance
## leaks ObjectDB and prints a WARNING at exit, tripping the project's grep
## discipline (confirmed empirically).

const MESSAGE_LAYER_PATH := "res://src/ui/message_layer.gd"
const COMBAT_SCREEN_PATH := "res://src/combat/combat_screen.gd"


func _init() -> void:
	WITestWatchdog.arm(self)
	_check_text_scale_math()
	_check_text_scale_drift_tripwire()
	_check_settings_persistence()
	_check_audio_bus_routing()
	_check_hint_reset_functions()
	_check_reduce_motion_gate_sites()
	print("PASS: settings + accessibility surface (WISettings/WIAudio/hint-replay/reduce-motion) holds")
	quit(0)


## Pure math: `scaled_default_font_size`/`scaled_type_font_sizes` at step 0
## (must be the EXACT base ints -- what test_copy_fit.gd's own font-size==14
## settle depends on staying true whenever this feature's autoload ever
## does run) and step 2 (130%, the largest step -- every scaled size must be
## STRICTLY LARGER than base, and step 0 called AGAIN afterward must still
## be the exact original ints, proving no rounding drift accumulates across
## repeated scale-up/scale-down cycles -- both always derive from the BASE
## consts, never the theme's current value).
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


## Drift tripwire (test_copy_fit.gd's own discipline): the mirrored BASE
## consts in wi_settings.gd must still match wi_ui_theme.tres's real values,
## or this test (and the whole text-scale feature) silently scales from the
## WRONG starting point.
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


## Persistence round trip via `user://settings.cfg` (the real ConfigFile
## path -- --script mode's user:// resolves the same as any other run on
## this machine, so this explicitly resets back to defaults at the end,
## leaving no stray non-default file for a later real boot to inherit).
func _check_settings_persistence() -> void:
	var script := load("res://src/ui/wi_settings.gd")
	var a = script.new()
	a.call("_load_settings")
	a.call("set_fullscreen", true)
	a.call("set_text_scale_step", 2)
	a.call("set_reduce_motion", true)
	assert(bool(a.call("is_fullscreen")) == true, "set_fullscreen(true) must read back true")
	assert(int(a.call("text_scale_step")) == 2, "set_text_scale_step(2) must read back 2")
	assert(bool(a.call("reduce_motion")) == true, "set_reduce_motion(true) must read back true")
	a.free()

	# A FRESH instance loading from disk must see the SAME persisted values --
	# proves the ConfigFile file round-trip, not just the in-memory setter.
	var b = script.new()
	b.call("_load_settings")
	assert(bool(b.call("is_fullscreen")) == true, "a fresh instance must load the persisted fullscreen=true")
	assert(int(b.call("text_scale_step")) == 2, "a fresh instance must load the persisted text_scale_step=2")
	assert(bool(b.call("reduce_motion")) == true, "a fresh instance must load the persisted reduce_motion=true")

	# Reset to defaults -- idempotent across repeated test runs.
	b.call("set_fullscreen", false)
	b.call("set_text_scale_step", 0)
	b.call("set_reduce_motion", false)
	b.free()


## THE bus-routing bug fix, proven directly: a real `_setup_buses()` call
## against the real AudioServer, then `AudioServer.get_bus_send` (Server-side
## graph metadata, real headless -- no audio device needed) -- not by ear.
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


## Compiles an autoload-stubbed copy of `path` (same technique as
## tests/test_input_hints.gd/tests/test_combat_visuals.gd) and proves
## `reset_hints()` clears `flag_name` -- the mechanism settings_panel.gd's
## "Replay Hints" action drives via WISettings.replay_hints(). Inserted after
## the TRUE first line only (`raw.substr`/`find("\n")`, never a
## `String.replace` on "extends CanvasLayer") -- both files' own header
## comments mention "extends CanvasLayer" too (message_layer.gd's FULL LAYER
## MAP doc comment), and a naive whole-file replace would inject a SECOND
## stub declaration there, colliding with the first ("Variable ... has the
## same name as a previously declared variable") -- confirmed empirically.
func _check_static_flag_reset(path: String, extends_line: String, flag_name: String) -> void:
	var raw := FileAccess.get_file_as_string(path)
	assert(raw.begins_with(extends_line), "%s: expected first line '%s'" % [path, extends_line])
	var first_nl := raw.find("\n")
	var stub := "\n\nvar Game: Variant = null\nvar ObservableBus: Variant = null\nvar TestDriver: Variant = null\nvar WIInputHints: Variant = null"
	var patched := raw.substr(0, first_nl) + stub + raw.substr(first_nl)
	var script := GDScript.new()
	script.source_code = patched
	var err := script.reload()
	assert(err == OK, "%s (autoload-stubbed copy) failed to compile: %d" % [path, err])
	script.set(flag_name, true)
	assert(bool(script.get(flag_name)) == true, "%s: setup could not set %s true" % [path, flag_name])
	script.call("reset_hints")
	assert(bool(script.get(flag_name)) == false, "%s: reset_hints() must clear %s" % [path, flag_name])


## board_renderer.gd references ObservableBus/Game/TestDriver directly (same
## as combat_screen.gd), so it's raw-source-checked -- tests/test_combat_
## visuals.gd's own established idiom for this exact file, not load()+
## instantiate. Proves the ONE shared `_reduce_motion()` gate exists and
## that every juice call site (shake_board/impact_flash/flash_chip/
## flash_cells) routes through it -- shake_board/impact_flash via the
## existing `_juice_enabled()` gate, flash_chip/flash_cells via a direct
## early-return (they carried no gate at all before this issue).
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
