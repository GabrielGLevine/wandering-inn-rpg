extends Node
## Presentation-side settings router: fullscreen, text scale, reduce-motion,
## and the tutorial-hint replay action (issue #77). Register as autoload
## `WISettings`.
##
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
##
## PERSISTENCE: `user://settings.cfg` via ConfigFile -- the SAME physical
## file WIAudio's own `SETTINGS_PATH` targets (a duplicated literal
## constant, not a cross-autoload reference, precisely so this file stays
## standalone-loadable -- see the file doc comment above). Different
## ConfigFile sections ("video"/"accessibility" here, "audio" there); see
## `_persist`'s doc comment for why every write reloads from disk first.
## Config-file idiom, NOT save data: never read/written by WISave, never
## touched by New Game / defeat-reload / a save's own load_slot -- settings
## survive all three by simply never being wired to them.

const SETTINGS_PATH := "user://settings.cfg"

## Text-scale steps: index -> multiplier / display label. 3-step UI ladder
## (issue #77 spec): 100% (default) / 115% / 130%.
const TEXT_SCALE_STEPS: Array[float] = [1.0, 1.15, 1.30]
const TEXT_SCALE_LABELS: Array[String] = ["100%", "115%", "130%"]

## Base (100%) font sizes -- MUST mirror assets/ui/chrome/wi_ui_theme.tres
## exactly (tests/test_settings.gd drift-tripwires these against the real
## .tres, same discipline test_copy_fit.gd's own mirrored consts use).
## `default_font_size` is the Theme-wide fallback (covers Button, and
## RichTextLabel/CombatReadout, which carry no explicit font_sizes override
## of their own); `BASE_TYPE_FONT_SIZES` are the type-variation overrides
## test_copy_fit.gd's corpus renders through (bare "Label" plus every named
## variation).
const BASE_DEFAULT_FONT_SIZE := 14
const BASE_TYPE_FONT_SIZES := {
	"Label": 14, "Header": 18, "Title": 36, "Menu": 18, "Small": 12, "Lore": 12,
}

var _settings := ConfigFile.new()
var _fullscreen := false
var _text_scale_step := 0
var _reduce_motion := false


func _ready() -> void:
	_load_settings()
	_apply_text_scale()
	_apply_fullscreen()


## Loaded once at boot, before title (autoloads' `_ready()` runs before
## Main's, which is what spawns the title screen -- see main.gd). Idempotent:
## safe to call again (e.g. from a future settings-reset action) since it
## always re-derives from whatever is currently on disk.
func _load_settings() -> void:
	_settings.load(SETTINGS_PATH)
	_fullscreen = bool(_settings.get_value("video", "fullscreen", false))
	_text_scale_step = clampi(int(_settings.get_value("accessibility", "text_scale_step", 0)), 0, TEXT_SCALE_STEPS.size() - 1)
	_reduce_motion = bool(_settings.get_value("accessibility", "reduce_motion", false))


## Read-modify-write: `wi_audio.gd`'s own ConfigFile targets this SAME
## physical file under a different section ("audio") via a SEPARATE
## ConfigFile object -- reloading from disk immediately before mutating
## picks up whatever it last wrote, so this save can never clobber it (and
## `wi_audio.gd`'s own `set_bus_volume` does the identical reload before its
## own save, for the same reason in the other direction).
func _persist(section: String, key: String, value: Variant) -> void:
	_settings.load(SETTINGS_PATH)
	_settings.set_value(section, key, value)
	_settings.save(SETTINGS_PATH)


# --- Fullscreen --------------------------------------------------------------

func is_fullscreen() -> bool:
	return _fullscreen


func set_fullscreen(value: bool) -> void:
	_fullscreen = value
	_persist("video", "fullscreen", value)
	_apply_fullscreen()


func toggle_fullscreen() -> void:
	set_fullscreen(not _fullscreen)


## Godot's headless DisplayServer accepts `window_set_mode` as a harmless
## no-op (probed empirically: no error/warning, mode just doesn't visibly
## change) -- safe to call unconditionally, so headless QA never needs a
## guard here; the REAL windowed apply is what a human playtest verifies.
func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


# --- Text scale ---------------------------------------------------------------

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


## Pure: the scaled `default_font_size` for `step`, always derived from
## BASE_DEFAULT_FONT_SIZE (never the theme's current, possibly-already-scaled
## value) so repeated scale-up/scale-down cycles can never drift via rounding
## -- 100% always restores the EXACT base int test_copy_fit.gd pins.
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


# --- Reduce motion -------------------------------------------------------------

func reduce_motion() -> bool:
	return _reduce_motion


func set_reduce_motion(value: bool) -> void:
	_reduce_motion = value
	_persist("accessibility", "reduce_motion", value)


func toggle_reduce_motion() -> void:
	set_reduce_motion(not _reduce_motion)


# --- Tutorial hints (replay) ---------------------------------------------------

## Re-arms the two process-lifetime one-shot hints (message_layer.gd's first-
## pickup toast, combat_screen.gd's first-combat-kit feed line) by calling
## each file's own `reset_hints()` static function through a dynamic
## `load()` (never a `preload`/compile-time reference -- both target files
## reference ObservableBus/Game as bare autoload identifiers, which would
## fail to COMPILE this file under bare `--script` mode; `load()` is a
## runtime call, so it only ever resolves during a REAL game boot, keeping
## this file itself autoload-reference-free -- see the file doc comment).
## NOT accomplishment-gated: both hints are pure presentation static vars,
## already re-armed on GAME_RESET by their own existing precedent (see each
## file's doc comment) -- this reuses the SAME flag, so a replay can never
## touch (or be entangled with) any progression counter.
func replay_hints() -> void:
	load("res://src/ui/message_layer.gd").call("reset_hints")
	load("res://src/combat/combat_screen.gd").call("reset_hints")
