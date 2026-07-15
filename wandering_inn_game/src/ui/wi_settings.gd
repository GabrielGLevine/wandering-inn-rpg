extends Node
## AUTOLOAD-FREE BY DESIGN: this file references no other autoload
## (ObservableBus/Game/WIAudio/WIInputHints) as a bare identifier -- only
## engine singletons/classes (ConfigFile, DisplayServer) and `UIChrome` (a
## plain `class_name`, not an autoload). That keeps it directly
## `load()`+`.new()`-able under bare `--script` mode (the same
## "autoloads don't resolve as bare identifiers" gotcha test_input_hints.gd/
## test_combat_visuals.gd already work around by PATCHING their target's
## source -- this file needs no such patch), so tests/test_settings.gd can
## exercise the real class directly. Audio (Master/Music/SFX volume) stays
## entirely owned by `WIAudio` (src/audio/wi_audio.gd) -- this file never
## touches AudioServer.

const SETTINGS_PATH := "user://settings.cfg"

const TEXT_SCALE_STEPS: Array[float] = [1.0, 1.15, 1.30]
const TEXT_SCALE_LABELS: Array[String] = ["100%", "115%", "130%"]

## Combat speed steps (issue #87, gap-2): index -> AI-beat-pacing multiplier /
## display label. Applied to `combat_screen.gd`'s `AI_BEAT_SECONDS` const by
## `combat_playback.gd`'s `beat_delay()` (via a `_screen` wrapper -- that file
## stays autoload-reference-free, see its own doc comment); Instant (0.0)
## collapses AI pacing to the SAME zero-delay QA already exercises via
## `TestDriver.active()`/headless, so a player who picks it gets a real, already
## fully-proven-safe code path, not a new one. Purely a presentation pacing
## knob -- never touches WICombat/the sim's own turn order or RNG draws.
const COMBAT_SPEED_STEPS: Array[float] = [1.0, 0.5, 0.0]
const COMBAT_SPEED_LABELS: Array[String] = ["Normal", "Fast", "Instant"]

## Base (100%) font sizes -- MUST mirror assets/ui/chrome/wi_ui_theme.tres
## exactly (tests/test_settings.gd drift-tripwires these against the real
## .tres, same discipline test_copy_fit.gd's own mirrored consts use).
const BASE_DEFAULT_FONT_SIZE := 14
const BASE_TYPE_FONT_SIZES := {
	"Label": 14, "Header": 18, "Title": 36, "Menu": 18, "Small": 12, "Lore": 12,
}

var _settings := ConfigFile.new()
# CONTRACT: tests override before first load; production stays on SETTINGS_PATH.
var _settings_path: String = SETTINGS_PATH
var _fullscreen := false
var _text_scale_step := 0
var _reduce_motion := false
var _combat_speed_step := 0


func _ready() -> void:
	_load_settings()
	_apply_text_scale()
	_apply_fullscreen()


func _load_settings() -> void:
	_settings.load(_settings_path)
	_fullscreen = bool(_settings.get_value("video", "fullscreen", false))
	_text_scale_step = clampi(int(_settings.get_value("accessibility", "text_scale_step", 0)), 0, TEXT_SCALE_STEPS.size() - 1)
	_reduce_motion = bool(_settings.get_value("accessibility", "reduce_motion", false))
	_combat_speed_step = clampi(int(_settings.get_value("combat", "speed_step", 0)), 0, COMBAT_SPEED_STEPS.size() - 1)


func _persist(section: String, key: String, value: Variant) -> void:
	_settings.load(_settings_path)
	_settings.set_value(section, key, value)
	_settings.save(_settings_path)


func record_chronicle(facts: Dictionary) -> void:
	var stored: Dictionary = facts.duplicate(true)
	_persist("chronicle", "latest", stored)


func latest_chronicle() -> Dictionary:
	_settings.load(_settings_path)
	if not _settings.has_section_key("chronicle", "latest"):
		return {}
	var stored: Variant = _settings.get_value("chronicle", "latest")
	if not stored is Dictionary:
		return {}
	if not _valid_chronicle_shape(stored as Dictionary):
		return {}
	return (stored as Dictionary).duplicate(true)


static func _valid_chronicle_shape(stored: Dictionary) -> bool:
	# CONTRACT: title iterates classes and casts each row; reject the whole corrupt record here.
	var classes_value: Variant = stored.get("classes")
	if not classes_value is Array:
		return false
	for raw_class: Variant in classes_value:
		if not raw_class is Dictionary:
			return false
		var class_facts := raw_class as Dictionary
		if not class_facts.get("name") is String or typeof(class_facts.get("level")) != TYPE_INT:
			return false
	for key: String in ["name", "race", "ending"]:
		if not stored.get(key) is String:
			return false
	for key: String in ["schema", "quests_completed", "victories", "sleeps"]:
		if typeof(stored.get(key)) != TYPE_INT:
			return false
	return true



func is_fullscreen() -> bool:
	return _fullscreen


func set_fullscreen(value: bool) -> void:
	_fullscreen = value
	_persist("video", "fullscreen", value)
	_apply_fullscreen()


func toggle_fullscreen() -> void:
	set_fullscreen(not _fullscreen)


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)



func text_scale_step() -> int:
	return _text_scale_step


func text_scale_label() -> String:
	return TEXT_SCALE_LABELS[_text_scale_step]


func set_text_scale_step(step: int) -> void:
	_text_scale_step = clampi(step, 0, TEXT_SCALE_STEPS.size() - 1)
	_persist("accessibility", "text_scale_step", _text_scale_step)
	_apply_text_scale()


func cycle_text_scale() -> void:
	set_text_scale_step(wrapi(_text_scale_step + 1, 0, TEXT_SCALE_STEPS.size()))


static func scaled_default_font_size(step: int) -> int:
	var mult: float = TEXT_SCALE_STEPS[clampi(step, 0, TEXT_SCALE_STEPS.size() - 1)]
	return int(round(float(BASE_DEFAULT_FONT_SIZE) * mult))


## Pure: `{type_variation_name: scaled_font_size}` for `step`, same
## always-from-BASE contract as `scaled_default_font_size`.
static func scaled_type_font_sizes(step: int) -> Dictionary:
	var mult: float = TEXT_SCALE_STEPS[clampi(step, 0, TEXT_SCALE_STEPS.size() - 1)]
	var out := {}
	for type_name: String in BASE_TYPE_FONT_SIZES:
		out[type_name] = int(round(float(BASE_TYPE_FONT_SIZES[type_name]) * mult))
	return out


## Mutates the SHARED `UIChrome.THEME` static Theme resource -- every panel
## built via `UIChrome.apply_theme`/`make_label`/`make_rich_label` reads
## through it, and message_layer.gd/combat_hud.gd's own wrapped-line budget
## math (`_wrapped_line_count`/`_rtl_wrapped_line_count` etc.) measures via
## `label.get_theme_font_size(...)` AT RENDER TIME -- never a cached value --
## so those budgets recompute correctly the instant this runs, no separate
## wiring needed in either file. SAFE-BY-CONSTRUCTION for test_copy_fit.gd:
## that suite is a bare `--script` SceneTree test, and autoloads (this one
## included) are NEVER instantiated under `--script` mode (confirmed
## empirically -- see CLAUDE.md's "--script-mode... doesn't resolve
## autoloads" gotcha), so `_apply_text_scale` can only ever run inside a REAL
## game boot (main.tscn), never inside test_copy_fit.gd's process. The panel
## WIDTH/HEIGHT pixel budgets (TOAST_TEXT_WIDTH, FEED_TEXT_WIDTH,
## READOUT_TEXT_WIDTH/HEIGHT, etc.) are deliberately left UNTOUCHED here --
## they represent the REAL fixed on-screen panel rects (verified against
## each panel's own build code), which do not resize with text scale; the
## dynamic part (how many wrapped lines of the NOW-BIGGER font fit inside
## that fixed rect) already recomputes correctly from live font metrics, and
## every one of those panels already truncates (ellipsis) or grows
## (toast/dialogue/feed) to stay inside its budget -- rescaling the
## pixel constants alongside the font would tell the wrap math there is MORE
## room than the fixed panel actually has, which would UNDERSHOOT truncation
## and cause the exact overflow this feature must avoid. tests/test_settings.gd
## proves this holds at the largest step.
func _apply_text_scale() -> void:
	UIChrome.THEME.default_font_size = scaled_default_font_size(_text_scale_step)
	var sizes := scaled_type_font_sizes(_text_scale_step)
	for type_name: String in sizes:
		UIChrome.THEME.set_font_size("font_size", type_name, int(sizes[type_name]))



func reduce_motion() -> bool:
	return _reduce_motion


func set_reduce_motion(value: bool) -> void:
	_reduce_motion = value
	_persist("accessibility", "reduce_motion", value)


func toggle_reduce_motion() -> void:
	set_reduce_motion(not _reduce_motion)



func combat_speed_step() -> int:
	return _combat_speed_step


func combat_speed_label() -> String:
	return COMBAT_SPEED_LABELS[_combat_speed_step]


func set_combat_speed_step(step: int) -> void:
	_combat_speed_step = clampi(step, 0, COMBAT_SPEED_STEPS.size() - 1)
	_persist("combat", "speed_step", _combat_speed_step)


func cycle_combat_speed() -> void:
	set_combat_speed_step(wrapi(_combat_speed_step + 1, 0, COMBAT_SPEED_STEPS.size()))


static func beat_seconds_for_step(step: int, base: float) -> float:
	return base * COMBAT_SPEED_STEPS[clampi(step, 0, COMBAT_SPEED_STEPS.size() - 1)]



func replay_hints() -> void:
	load("res://src/ui/message_layer.gd").call("reset_hints")
	load("res://src/combat/combat_screen.gd").call("reset_hints")
