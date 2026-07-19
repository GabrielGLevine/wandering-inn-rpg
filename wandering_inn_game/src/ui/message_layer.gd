extends CanvasLayer

const TOAST_SECONDS := 3.75
## GH#170: last-N toast texts for the journal's Recent Messages section --
## the durable answer to "it went past before I could read it". Static so
## the journal (created on open) reads history it never saw live. Sleep
## does NOT clear it; it is a reading aid, not game state (unsaved).
const RECENT_MESSAGES_CAP := 30
static var recent_messages: Array[String] = []


## GH#170: shared history feed -- toasts land here via _drain_toasts, and
## combat_screen appends its composed blow-by-blow lines so the journal's
## Recent Messages answers "what just happened" after a fast fight.
static func record_message(text: String) -> void:
	recent_messages.append(text)
	while recent_messages.size() > RECENT_MESSAGES_CAP:
		recent_messages.pop_front()
## Toast hold under WINDOWED QA (TestDriver active, real DisplayServer) -- a
## 0.4s FLOOR, not zero: toast legibility in windowed screenshots is
## load-bearing for the controller-read discipline (wi-verifying-changes
## mandates verifying toast text by reading PNGs), so the toast a script
## just waited on must still be on screen when test_driver's screenshot
## fires (0.15s SCREENSHOT_SETTLE_SECONDS < 0.4s). No script waits on a
## toast's DISAPPEARANCE (no such event exists -- only ui_toast_rendered at
## display start), so the floor only delays subsequent queued renders.
const QA_TOAST_HOLD_SECONDS := 0.4
## Toast hold under HEADLESS QA -- near-zero (frame-bounded), NOT the
## windowed 0.4s floor. Headless QA SKIPS screenshots entirely
## (test_driver._screenshot early-returns for DisplayServer "headless"), so
## the windowed legibility floor above buys nothing here -- it is pure dead
## wall-clock that serializes the drain at 0.4s/toast and makes render
## TIMING machine-speed-dependent. That timing dependency previously made
## tutorial_flow's warrior-class-gain render pass locally (fast run: the
## prior "Autosaved" toast was still mid-hold, so the class toast queued
## behind it and rendered AFTER the sleep-veil's deferred emit) but stall on
## slow CI runners (the "Autosaved" toast had long since drained, so the
## class toast rendered IMMEDIATELY -- before the veil emit -- flipping the
## event order the QA cursor assumed). Collapsing headless to a
## single-frame-ish hold restores the rule that TestDriver/headless runs
## have zero delays, and makes the drain frame-bounded. tutorial_flow.json's
## `from_start` on the class-toast render wait makes that script robust to
## EITHER emission order regardless.
const QA_TOAST_HOLD_HEADLESS_SECONDS := 0.05
const TOAST_QUEUE_HOLD_CAP_SECONDS := 1.6
const DIALOGUE_SECONDS := 3.0
const DIALOGUE_SECONDS_PER_EXTRA_LINE := 1.2
const DIALOGUE_TEXT_WIDTH := 656.0
const DIALOGUE_LINE_CAPACITY := 2

const TOAST_LEFT := -472.0
const TOAST_RIGHT := -24.0
const TOAST_BOTTOM_DEFAULT := -34.0
const TOAST_BOTTOM_RAISED := -264.0
const TOAST_PANEL_BASE_SIZE := Vector2(448.0, 96.0)
const TOAST_TEXT_WIDTH := 412.0
## Danger zone = 686-658 = 28px, measured from the panel's OWN bottom edge
## (a 9-slice-art property, independent of the MarginContainer's content
## margins). Unlike the feed (top-aligned text, single measured deficit),
## the toast label is VERTICALLY CENTERED (`_ready()`), so growing the
## panel pushes only HALF of any added headroom above the text block -- the
## other half lands below it, meaning the danger zone must be budgeted
## TWICE (`_toast_panel_height`'s derivation) to actually clear the fold
## rather than just approach it.
## TRAP (v0.4.0 playtest, the Invrisil ledger toast): that 28px was measured
## at the BASE 96px panel height -- but Banner_Horizontal's fold art starts
## 29px above the texture region's bottom while STRIP_PATCH_MARGIN is only
## 20, so 9 source px of fold live in the 9-patch's STRETCHED CENTER band.
const TOAST_FOLD_DANGER_PX := 30.0
const STRIP_FOLD_PATCH_BOTTOM := 32

## Toasts use layer 12: above journal/inventory modals (10), below the sleep
## veil (30). This ordering keeps feedback visible without piercing sleep.
const TOAST_CANVAS_LAYER := 12

var _toast_layer: CanvasLayer
var _toast_panel: Control
var _toast_label: Label
var _dialogue_panel: Control
var _dialogue_label: Label
var _dialogue_text_height := 0.0
var _hint_panel: Control
var _hint_label: Label

## Toast queue: TOAST/INTERACT_NOTHING both render onto the single
## _toast_panel/_toast_label -- a multi-class level-up beat or a dual
## evolution can emit several in one synchronous beat, and the nested-
## autosave-toast gotcha (Game's class_gained listener calls save_auto()
## synchronously, re-entering _on_domain_event for its own toast) can append
## one mid-display. `_toast_queue` holds pending toast text in emission
## order; `_toast_draining` gates a single in-flight drain coroutine so
## concurrent _queue_toast calls never start a second drain loop.
var _toast_queue: Array[String] = []
var _toast_draining := false
## Issue #62 Lane U item 6: set by `dismiss_current_toast_early()`, consumed
## by `_show()`'s interruptible hold-wait (toast panel only -- the dialogue
## bark never sets or checks this). Does NOT drop or reorder anything in
## `_toast_queue` -- it only shortens the CURRENTLY showing toast's remaining
## hold; `_drain_toasts`'s own while-loop still pops and shows every
## remaining queued toast, in order, right after.
var _toast_skip_requested := false

func _first_pickup_hint_text() -> String:
	return "Press %s — your pack." % WIInputHints.label("inventory")


## GH#171 item 7: empty interacts answer in the current biome's voice
## (biomes.json `interact_nothing`, presentation-only) instead of a flat
## "Nothing there." -- which stays as the fallback for biomes without a line.
func _interact_nothing_text() -> String:
	if Game.sim != null:
		var maps: Dictionary = WIDataRegistry.scene_config().get("maps", {})
		var map_cfg: Dictionary = maps.get(Game.sim.current_map, {})
		var biome_id := String(map_cfg.get("biome", "inn"))
		var line := String((WIDataRegistry.biomes().get(biome_id, {}) as Dictionary).get("interact_nothing", ""))
		if line != "":
			return line
	return "Nothing there."


func _first_wake_hint_text() -> String:
	return "New morning. Every key and control is listed under %s — Settings — Help." % WIInputHints.label("cancel")


func _hint_text() -> String:
	return "%s — menu (save/load)   %s — journal   %s — inventory" % [
		WIInputHints.label("cancel"), WIInputHints.label("journal"), WIInputHints.label("inventory"),
	]


var _first_pickup_hint_pending := false
## Static lifetime is intentional: UI destruction must not replay the hint.
## The script-level hook catches GAME_RESET even before an instance exists.
static var _first_pickup_hint_shown := false
## GH#171 first-waking controls pointer -- same static-lifetime contract.
static var _first_wake_hint_shown := false
## True from first-wake until the hint actually RENDERS -- toast-queue
## clears (map change, dialogue) re-queue it instead of eating it.
var _first_wake_hint_pending := false
static var _hint_reset_hooked := false

var _conversation_open := false

var _toast_panel_height := TOAST_PANEL_BASE_SIZE.y


static func _reset_first_pickup_hint(type: String, _payload: Dictionary) -> void:
	if type == WIEvents.GAME_RESET:
		_first_pickup_hint_shown = false
		_first_wake_hint_shown = false


static func reset_hints() -> void:
	_first_pickup_hint_shown = false
	_first_wake_hint_shown = false


func _ready() -> void:
	var root := Control.new()
	UIChrome.apply_theme(root)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# The toast panel lives on its OWN child CanvasLayer (layer 12) -- see
	# TOAST_CANVAS_LAYER's doc comment above for the full layer map and
	# rationale. A CanvasLayer's `layer` applies independently of its Node
	# parent chain, so nesting this one under the outer MessageLayer
	# CanvasLayer (rather than adding it as a sibling under Main) is just
	# scene-tree bookkeeping -- draw order is still purely a function of
	# `layer`, not tree depth.
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = TOAST_CANVAS_LAYER
	add_child(_toast_layer)
	var toast_root := Control.new()
	UIChrome.apply_theme(toast_root)
	toast_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(toast_root)

	_toast_panel = UIChrome.make_chrome_panel(UIChrome.PARCHMENT_STRIP, UIChrome.STRIP_PATCH_MARGIN)
	# STOP (mouse-filter audit, issue #57): overrides `make_chrome_panel`'s own
	# IGNORE default -- a click on the toast strip while it is showing must
	# not leak through to a world click-to-walk/interact underneath it.
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	(_toast_panel.get_child(0) as NinePatchRect).patch_margin_bottom = STRIP_FOLD_PATCH_BOTTOM
	_toast_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_toast_panel.custom_minimum_size = TOAST_PANEL_BASE_SIZE
	_toast_panel.size = TOAST_PANEL_BASE_SIZE
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
	toast_root.add_child(_toast_panel)

	_dialogue_panel = UIChrome.make_chrome_panel(UIChrome.PARCHMENT_STRIP, UIChrome.STRIP_PATCH_MARGIN)
	_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	(_dialogue_panel.get_child(0) as NinePatchRect).patch_margin_bottom = STRIP_FOLD_PATCH_BOTTOM
	_dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_dialogue_panel.hide()
	var dialogue_margin := MarginContainer.new()
	UIChrome.full_rect(dialogue_margin)
	UIChrome.add_margins(dialogue_margin, 22, 12, 22, 12)
	_dialogue_panel.add_child(dialogue_margin)
	_dialogue_label = UIChrome.make_label()
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_margin.add_child(_dialogue_label)
	root.add_child(_dialogue_panel)
	# Must run AFTER add_child (theme lookups need `_dialogue_label` already
	# inside the themed tree, same ordering requirement as inventory.gd's
	# `_reserve_status_label_height`) -- derives the panel's real size from
	# `DIALOGUE_LINE_CAPACITY` wrapped lines of `_dialogue_label`'s actual
	# font metrics, replacing the old hardcoded 700x56/DIALOGUE_TEXT_HEIGHT=32
	# (1-line) constants.
	_resize_dialogue_panel()

	_hint_panel = UIChrome.make_chrome_panel(UIChrome.PARCHMENT_STRIP, UIChrome.STRIP_PATCH_MARGIN)
	_hint_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_panel.custom_minimum_size = Vector2(400, 28)
	_hint_panel.size = Vector2(400, 28)
	UIChrome.set_offsets(_hint_panel, 8.0, -36.0, 408.0, -8.0)
	var hint_margin := MarginContainer.new()
	UIChrome.full_rect(hint_margin)
	UIChrome.add_margins(hint_margin, 14, 5, 14, 5)
	_hint_panel.add_child(hint_margin)
	_hint_label = UIChrome.make_label("", "Small")
	_hint_label.text = _hint_text()
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
		WIEvents.INPUT_DEVICE_CHANGED:
			_hint_label.text = _hint_text()
			ObservableBus.emit_domain_event(WIEvents.UI_HINT_RENDERED, {"text": _hint_label.text})
		WIEvents.ITEM_GAINED:
			# pickup() emits ITEM_GAINED then TOAST synchronously; arm first so
			# the hint queues immediately after the pickup's own toast.
			if not _first_pickup_hint_shown:
				_first_pickup_hint_pending = true
		WIEvents.TOAST:
			_queue_toast(String(payload["text"]))
			if _first_pickup_hint_pending:
				_first_pickup_hint_pending = false
				_first_pickup_hint_shown = true
				_queue_toast(_first_pickup_hint_text())
		WIEvents.INTERACT_NOTHING:
			_queue_toast(_interact_nothing_text())
		WIEvents.DIALOGUE_LINE:
			# An empty speaker (ambient/narration lines, e.g. the Invrisil
			# crowd extras) must not render a bare leading ": " -- prefix
			# only when someone is actually speaking. The bus confirmation
			# below carries whatever composed string renders, so QA text
			# pins stay exact either way.
			var speaker := String(payload["speaker"])
			var text := "%s: %s" % [speaker, String(payload["text"])] if speaker != "" else String(payload["text"])
			var fitted := _fit_dialogue_line(text)
			_show_dialogue_line(text, fitted)
		WIEvents.COMBAT_STARTED:
			_hint_panel.hide()
			_clear_dialogue_line()
			_clear_toast()
		WIEvents.UI_COMBAT_HIDDEN:
			_hint_panel.show()
		WIEvents.UI_SLEEP_VEIL_FINISHED:
			# GH#171: one pointer at the full key reference, on the genuine
			# first waking only (times_slept == 1 filters loaded veteran
			# saves whose next sleep is not their first).
			if not _first_wake_hint_shown and Game.sim != null and Game.sim.times_slept == 1:
				_first_wake_hint_shown = true
				_first_wake_hint_pending = true
				_queue_toast(_first_wake_hint_text())
		WIEvents.DIALOGUE_STARTED:
			_conversation_open = true
			_apply_toast_position()
			_clear_dialogue_line()
			_clear_toast()
		WIEvents.DIALOGUE_ENDED:
			_conversation_open = false
			_apply_toast_position()
		WIEvents.MAP_CHANGED:
			_clear_dialogue_line()
			_clear_toast()
		WIEvents.PLAYER_MOVED:
			dismiss_current_toast_early()


func _clear_dialogue_line() -> void:
	_dialogue_panel.hide()


func _show_dialogue_line(text: String, fitted: String) -> void:
	await _show(_dialogue_panel, _dialogue_label, text, _dialogue_hold_seconds(fitted), WIEvents.UI_DIALOGUE_RENDERED, fitted, true)
	# CONTRACT: audio releases standalone-line duck on the renderer's actual close.
	ObservableBus.emit_domain_event(WIEvents.UI_DIALOGUE_LINE_HIDDEN, {})


func _clear_toast() -> void:
	_toast_panel.hide()
	_toast_queue.clear()
	if _first_wake_hint_pending:
		_toast_queue.append(_first_wake_hint_text())



func _apply_toast_position() -> void:
	var bottom := TOAST_BOTTOM_RAISED if _conversation_open else TOAST_BOTTOM_DEFAULT
	UIChrome.set_offsets(_toast_panel, TOAST_LEFT, bottom - _toast_panel_height, TOAST_RIGHT, bottom)


func _toast_panel_height_for(lines: int) -> float:
	var font := _toast_label.get_theme_font("font")
	var font_size := _toast_label.get_theme_font_size("font_size")
	var line_spacing := float(_toast_label.get_theme_constant("line_spacing"))
	var pitch := font.get_height(font_size) + line_spacing
	var text_block := float(lines) * pitch - line_spacing
	return maxf(TOAST_PANEL_BASE_SIZE.y, text_block + 2.0 * TOAST_FOLD_DANGER_PX)


func _resize_toast_panel(text: String) -> void:
	var lines := _wrapped_line_count(_toast_label, text, TOAST_TEXT_WIDTH)
	_toast_panel_height = _toast_panel_height_for(lines)
	_toast_panel.custom_minimum_size = Vector2(TOAST_PANEL_BASE_SIZE.x, _toast_panel_height)
	_toast_panel.size = Vector2(TOAST_PANEL_BASE_SIZE.x, _toast_panel_height)
	_apply_toast_position()


## FOLD FIX (2026-07-08 hotfix wave): the old exact-fit `text_height + 24.0`
## (12+12 margin, no slack) put a real 2nd-line bark flush against the
## panel's bottom margin -- exactly where the PARCHMENT_STRIP art's
## decorative fold band sits, sliced clean through line 2 (playtest
## evidence: garden_walkthrough's Erin reveal line, gate_district_
## walkthrough's Watch Guard bark). `_dialogue_panel` uses the SAME chrome
## texture + STRIP_PATCH_MARGIN as `_toast_panel` (see `_ready()`), so the
## fold's measured pixel depth from the panel's own bottom edge
## (TOAST_FOLD_DANGER_PX) transfers directly -- no independent re-measure
## needed. `_dialogue_label` is VERTICALLY CENTERED (UIChrome.make_label's
## default), so any panel growth beyond the exact text fit splits equally
## above/below the text block -- same "budget the danger zone TWICE" rule
## as `_toast_panel_height_for` (only half of `2.0 * TOAST_FOLD_DANGER_PX`
## actually lands below the text, which is the half that needs to clear the
## fold). `_dialogue_text_height` itself stays the raw 2-line text-block
## height -- `_fit_dialogue_line`'s wrap-capacity math must keep measuring
## against exactly 2 lines of TEXT, not the padded panel height.
func _resize_dialogue_panel() -> void:
	var font := _dialogue_label.get_theme_font("font")
	var font_size := _dialogue_label.get_theme_font_size("font_size")
	var line_spacing := float(_dialogue_label.get_theme_constant("line_spacing"))
	var pitch := font.get_height(font_size) + line_spacing
	_dialogue_text_height = DIALOGUE_LINE_CAPACITY * pitch - line_spacing
	var panel_height := maxf(_dialogue_text_height + 24.0, _dialogue_text_height + 2.0 * TOAST_FOLD_DANGER_PX)
	_dialogue_panel.custom_minimum_size = Vector2(700.0, panel_height)
	_dialogue_panel.size = Vector2(700.0, panel_height)
	const DIALOGUE_BOTTOM := -164.0
	UIChrome.set_offsets(_dialogue_panel, 36.0, DIALOGUE_BOTTOM - panel_height, 736.0, DIALOGUE_BOTTOM)


func _queue_toast(text: String) -> void:
	_toast_queue.append(text)
	if not _toast_draining:
		_drain_toasts()


func dismiss_current_toast_early() -> void:
	if _toast_panel.visible:
		_toast_skip_requested = true


## Displays queued toasts ONE AT A TIME, in emission order. A toast queued
## while this loop is mid-`await` (re-entrant emit, or simply a second toast
## landing in the same beat) is just appended to `_toast_queue` and picked up
## by the next `while` check -- never dropped, never reordered.
func _drain_toasts() -> void:
	_toast_draining = true
	while not _toast_queue.is_empty():
		var text: String = _toast_queue.pop_front()
		if _first_wake_hint_pending and text == _first_wake_hint_text():
			_first_wake_hint_pending = false
		record_message(text)
		await _show(_toast_panel, _toast_label, text, _toast_seconds(text), WIEvents.UI_TOAST_RENDERED, "", true, true)
	_toast_draining = false


## GH#170 (friend playtest x3 + #167): reading time scales with text.
## ~median 30-char toast keeps today's 3.75s feel; long lore toasts hold
## up to 7s. QA/headless holds are untouched (_hold_seconds still floors
## them), so canonical timing is byte-identical.
func _toast_seconds(text: String) -> float:
	return clampf(2.8 + 0.035 * float(text.length()), 3.4, 7.0)


func _is_gold_toast(text: String) -> bool:
	return text.begins_with("Earned ") or text.begins_with("Paid ")


func _fold_gold_toast(text: String) -> String:
	var merged := text
	while not _toast_queue.is_empty() and _is_gold_toast(_toast_queue[0]):
		merged += " " + _toast_queue.pop_front()
	return merged


func _hold_seconds(seconds: float) -> float:
	if DisplayServer.get_name() == "headless":
		return minf(seconds, QA_TOAST_HOLD_HEADLESS_SECONDS)
	if TestDriver != null and TestDriver.active():
		return minf(seconds, QA_TOAST_HOLD_SECONDS)
	return seconds


func _show(panel: Control, label: Label, text: String, seconds: float, rendered_event: String, display_text: String = "", collapse_under_qa: bool = false, interruptible: bool = false) -> void:
	if panel == _toast_panel:
		_resize_toast_panel(text)
	label.text = display_text if display_text != "" else text
	panel.show()
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_inside_tree():
		return
	if panel == _toast_panel:
		var folded := _fold_gold_toast(text)
		if folded != text:
			text = folded
			label.text = text
			_resize_toast_panel(text)
	ObservableBus.emit_domain_event(rendered_event, {"text": text})
	var hold := _hold_seconds(seconds) if collapse_under_qa else seconds
	if panel == _toast_panel and not _toast_queue.is_empty():
		hold = minf(hold, TOAST_QUEUE_HOLD_CAP_SECONDS)
	if hold > 0.0:
		if interruptible:
			_toast_skip_requested = false
			var deadline_msec := Time.get_ticks_msec() + int(hold * 1000.0)
			while Time.get_ticks_msec() < deadline_msec and not _toast_skip_requested:
				tree = get_tree()
				if tree == null:
					return
				await tree.process_frame
				if not is_inside_tree():
					return
			_toast_skip_requested = false
		else:
			tree = get_tree()
			if tree == null:
				return
			await tree.create_timer(hold).timeout
			if not is_inside_tree():
				return
	panel.hide()


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


func _line_capacity(label: Label, height: float) -> int:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var line_height := font.get_height(font_size)
	if line_height <= 0.0:
		return 1
	var line_spacing := float(label.get_theme_constant("line_spacing"))
	var pitch := line_height + line_spacing
	return max(int((height + line_spacing) / pitch), 1)


func _dialogue_hold_seconds(display_text: String) -> float:
	var lines := _wrapped_line_count(_dialogue_label, display_text, DIALOGUE_TEXT_WIDTH)
	var extra_lines := maxi(lines - 1, 0)
	return DIALOGUE_SECONDS + float(extra_lines) * DIALOGUE_SECONDS_PER_EXTRA_LINE


func _fit_dialogue_line(text: String) -> String:
	var capacity := _line_capacity(_dialogue_label, _dialogue_text_height)
	if _wrapped_line_count(_dialogue_label, text, DIALOGUE_TEXT_WIDTH) <= capacity:
		return text
	var words := text.split(" ")
	while words.size() > 1:
		words.remove_at(words.size() - 1)
		var candidate := " ".join(words) + "…"
		if _wrapped_line_count(_dialogue_label, candidate, DIALOGUE_TEXT_WIDTH) <= capacity:
			return candidate
	return (words[0] + "…") if words.size() > 0 else text
