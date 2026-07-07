extends CanvasLayer
## Renders toasts and dialogue lines from ObservableBus domain events, and
## confirms actual rendering back onto the bus (ui_toast_rendered /
## ui_dialogue_rendered) so QA scripts can assert "the player saw this".
##
## GOTCHA (shipped a dead quest chain in v2): CanvasLayer has NO `modulate`
## property. Fade/tint the child Control panels, never `self`.

const TOAST_SECONDS := 2.5
## Toast hold under WINDOWED QA (TestDriver active, real DisplayServer) -- a
## 0.4s FLOOR, not zero (controller decision on the toast-queue fix): toast
## legibility in windowed screenshots is load-bearing for the controller-read
## discipline (Q2/T2 verified toast text by reading PNGs; wi-verifying-changes
## mandates it), so the toast a script just waited on must still be on screen
## when test_driver's screenshot fires (0.15s SCREENSHOT_SETTLE_SECONDS < 0.4s).
## No script waits on a toast's DISAPPEARANCE (no such event exists -- only
## ui_toast_rendered at display start), so the floor only delays subsequent
## queued renders.
const QA_TOAST_HOLD_SECONDS := 0.4
## Toast hold under HEADLESS QA -- near-zero (frame-bounded), NOT the windowed
## 0.4s floor. Rationale (task-veiltoast-fix): headless QA SKIPS screenshots
## entirely (test_driver._screenshot early-returns for DisplayServer "headless"),
## so the windowed legibility floor above buys nothing here -- it is pure dead
## wall-clock that serializes the drain at 0.4s/toast and makes render TIMING
## machine-speed-dependent. That timing dependency is what made tutorial_flow's
## warrior-class-gain render pass locally (fast run: the prior "Autosaved" toast
## was still mid-hold, so the class toast queued behind it and rendered AFTER the
## sleep-veil's deferred emit) but stall on slow CI runners (the "Autosaved"
## toast had long since drained, so the class toast rendered IMMEDIATELY --
## before the veil emit -- flipping the event order the QA cursor assumed).
## Collapsing headless to a single-frame-ish hold restores the M4 T10 rule
## (TestDriver/headless = zero delays) and makes the drain frame-bounded. The
## companion tutorial_flow.json fix (from_start on the class-toast render wait)
## makes that script robust to EITHER emission order regardless.
const QA_TOAST_HOLD_HEADLESS_SECONDS := 0.05
const DIALOGUE_SECONDS := 3.0
## Dialogue panel interior text box -- 700x56 panel minus the MarginContainer's
## 22/12px margins (see `_dialogue_panel`/`dialogue_margin` below). M-FP F fix
## (docs/VISUAL-LOG.md "message panels clip the last wrapped line"): a long
## one-liner (the Liscor gate guard's) wraps past this panel's fixed height
## and its 2nd line got half-cut under the panel chrome. D2-7 #6 is binding:
## never widen the panel -- truncate with an ellipsis instead (_fit_dialogue_line).
const DIALOGUE_TEXT_WIDTH := 656.0
const DIALOGUE_TEXT_HEIGHT := 32.0

## Toast panel offsets (BOTTOM_RIGHT anchor; L,T,R,B). PF VISUAL-LOG drain (the
## "gift toast right-edge clip" item -- mis-diagnosed as an off-screen clip; the
## panel is a fixed 448x96 always fully on-screen). The REAL defect: the
## conversation panel (dialogue_panel.gd, 720x232 CENTER_BOTTOM => x[280,1000]
## y[470,684]) is a later sibling CanvasLayer at the same layer, so it draws
## OVER the toast's left half (x[808,1000]) and hides the "Got: " prefix. Fix:
## while a conversation is open, RAISE the toast to the upper-right (bottom at
## y456, a 14px gap above the conversation panel's y470 top) so it clears the
## panel entirely and reads in full; drop back to the resting bottom-right spot
## when the conversation ends. Width/height unchanged in both states, so the
## wrapped-line budget is identical -- this is a pure y-shift, never a widen.
const TOAST_OFFSETS_DEFAULT := Vector4(-472.0, -130.0, -24.0, -34.0)
const TOAST_OFFSETS_RAISED := Vector4(-472.0, -360.0, -24.0, -264.0)

var _toast_panel: Control
var _toast_label: Label
var _dialogue_panel: Control
var _dialogue_label: Label
var _hint_panel: Control
var _hint_label: Label

## Toast queue (M-FP toast-queue fix): TOAST/INTERACT_NOTHING both render onto
## the single _toast_panel/_toast_label -- a multi-class level-up beat or a
## dual evolution can emit several in one synchronous beat, and the nested-
## autosave-toast gotcha (Game's class_gained listener calls save_auto()
## synchronously, re-entering _on_domain_event for its own toast) can append
## one mid-display. `_toast_queue` holds pending toast text in emission
## order; `_toast_draining` gates a single in-flight drain coroutine so
## concurrent _queue_toast calls never start a second drain loop.
var _toast_queue: Array[String] = []
var _toast_draining := false

## Onboarding rev spec §9 ADDENDUM (interim, ships in M-BEAUTY R3): a one-time
## "Press I — your pack." toast on the FIRST ITEM_GAINED, so a player on the
## current build (full equip-flow tutorial beat is a later milestone) can at
## least discover the inventory key exists. Presentation-side only -- never
## persisted to save data. `_first_pickup_hint_pending` (plain instance var:
## it's set and consumed within one synchronous ITEM_GAINED->TOAST emission
## pair, so a respawn can't interleave it) bridges ITEM_GAINED -> the very
## next TOAST (pickup()'s "Got: <item>" toast, WIGame emits it unconditionally
## right after ITEM_GAINED, same synchronous call) so the hint enqueues AFTER
## the pickup toast, never before it.
##
## THE TRIGGER SURFACE, honestly (R3 review fix 1): `_first_pickup_hint_shown`
## is a `static var` -- statics live on the SCRIPT resource (preloaded once
## for the whole process by main.gd's MESSAGE_LAYER_SCRIPT const), not on the
## instance -- so the shown-flag survives every MessageLayer teardown/respawn
## (main.gd's `_clear_ui_layers`/`_spawn_ui_layers` swap on every GAME_RESET/
## GAME_LOADED, plus `swap_to_title`). Net behavior:
##   - GAME_LOADED (defeat-reload, pause-menu Load, title Continue): flag
##     PERSISTS -- a player who died and reloaded in the same sitting does
##     NOT see the hint again (the pre-fix instance var was wiped by the
##     defeat-reload respawn, re-showing the hint mid-sitting).
##   - GAME_RESET (title New Game; combat defeat with no autosave yet): flag
##     RE-ARMS via `_reset_first_pickup_hint` -- a fresh run deserves the
##     hint. That reset callback is connected SCRIPT-BOUND (not instance-
##     bound) exactly once per process in `_ready()` (`_hint_reset_hooked`
##     guard): traced necessity -- pause menu "Quit to Title" calls
##     Main.swap_to_title() (frees every UI layer, NO reset event), then
##     title "New Game" fires GAME_RESET while NO MessageLayer instance
##     exists yet (the title screen has none; main.gd only spawns UI layers
##     in the deferred swap_to_world that FOLLOWS the event), so an
##     instance-bound listener would miss that re-arm and a fresh New-Game
##     run would silently lose its hint. A Callable bound to the script
##     resource itself stays connected across every instance teardown.
##   - Fresh process boot: statics initialize false -- first run always hints.
const FIRST_PICKUP_HINT_TEXT := "Press I — your pack."
var _first_pickup_hint_pending := false
static var _first_pickup_hint_shown := false
static var _hint_reset_hooked := false

## True while a conversation panel is open (DIALOGUE_STARTED..DIALOGUE_ENDED) --
## gates the toast's raised position so it never sits behind the conversation.
var _conversation_open := false


static func _reset_first_pickup_hint(type: String, _payload: Dictionary) -> void:
	if type == WIEvents.GAME_RESET:
		_first_pickup_hint_shown = false


func _ready() -> void:
	var root := Control.new()
	UIChrome.apply_theme(root)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_toast_panel = UIChrome.make_chrome_panel(UIChrome.PARCHMENT_STRIP, UIChrome.STRIP_PATCH_MARGIN)
	_toast_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# 448 wide x 96 tall (up to 3 wrapped lines). M6 added the longest live
	# toasts -- the generalist "[Mage] settles into a balanced mastery --
	# unlocked [Ice Shard], [Flare Burst]" and the consolidation merge line --
	# which wrapped past 2 lines and clipped at the old 64px height (caught in
	# the M6 F1 polish pass, windowed-verified). Grows UPWARD (top offset), so
	# it never reaches into the centre hotbar.
	_toast_panel.custom_minimum_size = Vector2(448, 96)
	_toast_panel.size = Vector2(448, 96)
	_apply_toast_position()
	_toast_panel.hide()
	var toast_margin := MarginContainer.new()
	UIChrome.full_rect(toast_margin)
	UIChrome.add_margins(toast_margin, 18, 8, 18, 8)
	_toast_panel.add_child(toast_margin)
	_toast_label = UIChrome.make_label()
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_margin.add_child(_toast_label)
	root.add_child(_toast_panel)

	_dialogue_panel = UIChrome.make_chrome_panel(UIChrome.PARCHMENT_STRIP, UIChrome.STRIP_PATCH_MARGIN)
	_dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_dialogue_panel.custom_minimum_size = Vector2(700, 56)
	_dialogue_panel.size = Vector2(700, 56)
	UIChrome.set_offsets(_dialogue_panel, 36.0, -220.0, 736.0, -164.0)
	_dialogue_panel.hide()
	var dialogue_margin := MarginContainer.new()
	UIChrome.full_rect(dialogue_margin)
	UIChrome.add_margins(dialogue_margin, 22, 12, 22, 12)
	_dialogue_panel.add_child(dialogue_margin)
	_dialogue_label = UIChrome.make_label()
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_margin.add_child(_dialogue_label)
	root.add_child(_dialogue_panel)

	_hint_panel = UIChrome.make_chrome_panel(UIChrome.PARCHMENT_STRIP, UIChrome.STRIP_PATCH_MARGIN)
	_hint_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	# Widened 270->400 (M7 E4) to fit the added "I — inventory" hint without
	# the Label overflowing the parchment strip (D2-7 #6 wrapped-line rule
	# still applies -- this is a width bump for a single-line footer, not a
	# panel that needs to grow to fit multi-line content).
	_hint_panel.custom_minimum_size = Vector2(400, 28)
	_hint_panel.size = Vector2(400, 28)
	UIChrome.set_offsets(_hint_panel, 8.0, -36.0, 408.0, -8.0)
	var hint_margin := MarginContainer.new()
	UIChrome.full_rect(hint_margin)
	UIChrome.add_margins(hint_margin, 14, 5, 14, 5)
	_hint_panel.add_child(hint_margin)
	_hint_label = UIChrome.make_label("", "Small")
	_hint_label.text = "Esc — menu (save/load)   J — journal   I — inventory"
	hint_margin.add_child(_hint_label)
	root.add_child(_hint_panel)
	ObservableBus.emit_domain_event.call_deferred(WIEvents.UI_HINT_RENDERED, {"text": _hint_label.text})

	ObservableBus.domain_event.connect(_on_domain_event)
	# See _first_pickup_hint_shown's doc comment: hooked once per process,
	# bound to the SCRIPT resource (get_script()), never to this instance --
	# it must outlive every MessageLayer teardown to catch a GAME_RESET fired
	# from the title screen (no MessageLayer alive at that moment).
	if not _hint_reset_hooked:
		_hint_reset_hooked = true
		ObservableBus.domain_event.connect(Callable(get_script(), "_reset_first_pickup_hint"))


func _on_domain_event(type: String, payload: Dictionary) -> void:
	match type:
		WIEvents.ITEM_GAINED:
			if not _first_pickup_hint_shown:
				_first_pickup_hint_pending = true
		WIEvents.TOAST:
			_queue_toast(String(payload["text"]))
			if _first_pickup_hint_pending:
				_first_pickup_hint_pending = false
				_first_pickup_hint_shown = true
				_queue_toast(FIRST_PICKUP_HINT_TEXT)
		WIEvents.INTERACT_NOTHING:
			# An empty interact used to be completely SILENT -- during the M6
			# playtest the user pressed interact near (but not exactly facing)
			# the tiny inn door and got nothing, reading it as "the door is
			# broken". Any explicit player action needs visible feedback.
			_queue_toast("Nothing there.")
		WIEvents.DIALOGUE_LINE:
			var text := "%s: %s" % [String(payload["speaker"]), String(payload["text"])]
			# The bus confirmation carries the FULL semantic line (QA asserts
			# exact text on `ui_dialogue_rendered`, e.g. gate_district_walkthrough's
			# Watch Guard beat) -- only the on-screen Label is shortened to
			# what the fixed-height panel can actually show.
			_show(_dialogue_panel, _dialogue_label, text, DIALOGUE_SECONDS, WIEvents.UI_DIALOGUE_RENDERED, _fit_dialogue_line(text))
		WIEvents.COMBAT_STARTED:
			_hint_panel.hide()
		WIEvents.UI_COMBAT_HIDDEN:
			_hint_panel.show()
		WIEvents.DIALOGUE_STARTED:
			_conversation_open = true
			_apply_toast_position()
		WIEvents.DIALOGUE_ENDED:
			_conversation_open = false
			_apply_toast_position()


## Positions the toast panel: raised upper-right while a conversation is open
## (so the wide center-bottom conversation panel can't occlude it), resting
## bottom-right otherwise. See TOAST_OFFSETS_* for the full rationale.
func _apply_toast_position() -> void:
	var o := TOAST_OFFSETS_RAISED if _conversation_open else TOAST_OFFSETS_DEFAULT
	UIChrome.set_offsets(_toast_panel, o.x, o.y, o.z, o.w)


## Appends to the toast queue and (if no drain is already in flight) starts
## one. Safe to call re-entrantly -- see `_toast_queue`'s doc comment above.
func _queue_toast(text: String) -> void:
	_toast_queue.append(text)
	if not _toast_draining:
		_drain_toasts()


## Displays queued toasts ONE AT A TIME, in emission order. A toast queued
## while this loop is mid-`await` (re-entrant emit, or simply a second toast
## landing in the same beat) is just appended to `_toast_queue` and picked up
## by the next `while` check -- never dropped, never reordered.
func _drain_toasts() -> void:
	_toast_draining = true
	while not _toast_queue.is_empty():
		var text: String = _toast_queue.pop_front()
		await _show(_toast_panel, _toast_label, text, TOAST_SECONDS, WIEvents.UI_TOAST_RENDERED, "", true)
	_toast_draining = false


## Collapses a presentation hold under QA (M4 T10 paced-AI-playback precedent --
## same TestDriver.active()/headless detection as combat_screen.gd's
## `_beat_delay`/`_presentation_delay` and world.gd's `_presentation_delay`) so a
## queue of several toasts drains fast instead of piling up 2.5s of real
## wall-clock per toast and stalling a QA script. HEADLESS collapses to a
## near-zero, frame-bounded hold (screenshots are skipped -- see
## QA_TOAST_HOLD_HEADLESS_SECONDS); WINDOWED QA keeps the 0.4s floor so a toast a
## script just waited on is still on screen when the (windowed-only) screenshot
## fires (see QA_TOAST_HOLD_SECONDS). Scoped to the toast queue only
## (`collapse_under_qa` in `_show`) -- the dialogue panel keeps its original
## always-real hold; it was never queued/batched and nothing needs its timing
## changed.
func _hold_seconds(seconds: float) -> float:
	if DisplayServer.get_name() == "headless":
		return minf(seconds, QA_TOAST_HOLD_HEADLESS_SECONDS)
	if TestDriver != null and TestDriver.active():
		return minf(seconds, QA_TOAST_HOLD_SECONDS)
	return seconds


## M-LEGIBILITY L5 fix wave, Item 5: teardown-race guard. `await get_tree().
## process_frame`/`await get_tree().create_timer(...).timeout` can resume
## AFTER this node has left the tree (a world/combat swap or GAME_RESET
## freeing MessageLayer mid-toast) -- `get_tree()` returns null once outside
## the tree, so a naive resume crashes with "Invalid access to property or
## key 'process_frame'/'create_timer' on a base object of type 'null
## instance'" (hit once, not reproducible, by L5's first sweep). Fix: capture
## the tree ref BEFORE each await (never call `get_tree()` again after
## resuming without re-checking), and after EVERY await bail early if
## `not is_inside_tree()` -- before touching `get_tree()` again or doing any
## further UI access (`ObservableBus.emit_domain_event`, `panel.hide()`).
## Guards only: the live (still-in-tree) path's timing/behavior is unchanged.
## Distinct from the veiltoast ORDER race (task-veiltoast-fix-report.md) --
## does not touch that fix's logic.
func _show(panel: Control, label: Label, text: String, seconds: float, rendered_event: String, display_text: String = "", collapse_under_qa: bool = false) -> void:
	label.text = display_text if display_text != "" else text
	panel.show()
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_inside_tree():
		return
	ObservableBus.emit_domain_event(rendered_event, {"text": text})
	var hold := _hold_seconds(seconds) if collapse_under_qa else seconds
	if hold > 0.0:
		tree = get_tree()
		if tree == null:
			return
		await tree.create_timer(hold).timeout
		if not is_inside_tree():
			return
	panel.hide()


## Wrapped-line count for `text` at `width` using `label`'s resolved theme
## font/size -- the same TextServer word-wrap layout Label uses under the
## hood (`Font.get_multiline_string_size`), not a guessed character count.
func _wrapped_line_count(label: Label, text: String, width: float) -> int:
	if text == "":
		return 0
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	var line_height := font.get_height(font_size)
	if line_height <= 0.0:
		return 1
	return max(int(round(size.y / line_height)), 1)


## How many wrapped lines `label` actually fits at `height`, from real font
## metrics (never a hardcoded guess -- font/theme changes stay self-correcting).
## Uses the FULL line pitch (font height + the theme's `line_spacing`
## constant) -- `Font.get_multiline_string_size` (used by
## `_wrapped_line_count`) reports pure font-height*lines with no spacing, but
## the real rendered Label adds `line_spacing` between every line (see
## combat_screen.gd's `_line_capacity`, same fix, for the measured regression
## that motivated this).
func _line_capacity(label: Label, height: float) -> int:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var line_height := font.get_height(font_size)
	if line_height <= 0.0:
		return 1
	var line_spacing := float(label.get_theme_constant("line_spacing"))
	var pitch := line_height + line_spacing
	return max(int((height + line_spacing) / pitch), 1)


## Cuts whole words (design D2-7 #6: cut words, never widen the UI) and
## appends an ellipsis until `text` fits the dialogue panel's real wrapped-
## line capacity. Returns `text` unchanged if it already fits.
func _fit_dialogue_line(text: String) -> String:
	var capacity := _line_capacity(_dialogue_label, DIALOGUE_TEXT_HEIGHT)
	if _wrapped_line_count(_dialogue_label, text, DIALOGUE_TEXT_WIDTH) <= capacity:
		return text
	var words := text.split(" ")
	while words.size() > 1:
		words.remove_at(words.size() - 1)
		var candidate := " ".join(words) + "…"
		if _wrapped_line_count(_dialogue_label, candidate, DIALOGUE_TEXT_WIDTH) <= capacity:
			return candidate
	return (words[0] + "…") if words.size() > 0 else text
