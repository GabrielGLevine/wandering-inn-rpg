extends CanvasLayer
## Conversation UI for branching dialogue graphs (WIDialogue). Renders the
## current node's speaker/text and numbered options, and forwards confirmed
## choices to the sim. Distinct from message_layer.gd's `dialogue_line`
## (the M0 one-off NPC line) — this panel only reacts to
## `dialogue_started`/`dialogue_node`/`dialogue_ended`.
##
## Input arbitration (repo-wide precedence: combat > dialogue > pause >
## journal > world): this panel only consumes input while a conversation is
## open (`Game.sim.dialogue != null`), which sits below combat_screen (combat
## always ends any dialogue first) and above pause_menu/journal/world — those
## three gate on dialogue being closed.
##
## GOTCHA: CanvasLayer has no `modulate`; only child Controls are styled.

## 232px tall: 3 option rows + ribbon + 2-line text clear the parchment
## margins without clipping (controller windowed pass at E3/H3 merge).
const PANEL_SIZE := Vector2(720.0, 232.0)
const LOCKED_COLOR := Color(0.45, 0.45, 0.45)
## Playtest fix (long-body clipping): body text longer than the fixed panel can
## show is PAGED — split into chunks of at most this many characters at word
## boundaries — instead of overflowing the parchment bottom and pushing the
## numbered options off-screen (the original bug: a first-time player saw the
## body run off the panel and no options at all). ~200 chars ≈ 2-3 wrapped
## lines at this width, which leaves headroom for up to 3 option rows + ribbon
## inside the 232px panel WITHOUT widening/growing it (repo panel discipline:
## "cut words never widen"). Non-final pages advance on the same `confirm`
## used to pick an option; the option list only appears on the LAST page.
const PAGE_CHAR_BUDGET := 200

var _root: Control
var _stack: VBoxContainer
var _options_box: VBoxContainer
var _speaker_label: Label
var _text_label: Label
var _more_hint: Label
var _option_labels: Array[Label] = []
var _options: Array = []
var _cursor := 0
var _shown := false
## Paged body text for the current node + the page currently shown. A single-
## page node behaves exactly as before (page 0 IS the last page). See
## _render_node / _confirm for the QA-safe paging contract.
var _pages: Array[String] = []
var _page_idx := 0


func _ready() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y - 18.0, PANEL_SIZE.x * 0.5, -18.0)
	_root.hide()
	add_child(_root)

	_root.add_child(UIChrome.make_patch(UIChrome.PARCHMENT_PANEL))

	var content := MarginContainer.new()
	UIChrome.full_rect(content)
	UIChrome.add_margins(content, 28, 28, 28, 24)
	_root.add_child(content)

	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 6)
	content.add_child(_stack)
	var stack := _stack

	var ribbon := Control.new()
	ribbon.custom_minimum_size = Vector2(210.0, 42.0)
	ribbon.add_child(UIChrome.make_horizontal_patch(UIChrome.BLUE_RIBBON, UIChrome.RIBBON_PATCH_MARGIN_X, UIChrome.RIBBON_PATCH_MARGIN_Y))
	stack.add_child(ribbon)
	_speaker_label = UIChrome.make_label("", "Header")
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIChrome.full_rect(_speaker_label)
	ribbon.add_child(_speaker_label)

	_text_label = UIChrome.make_label()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(PANEL_SIZE.x - 56.0, 46.0)
	stack.add_child(_text_label)

	# Continuation affordance shown only on a non-final page of a paged node —
	# it occupies the option row's space (options are hidden until the last
	# page), so it never adds a row to the last-page layout that must fit.
	_more_hint = UIChrome.make_label("▼  more — press Enter")
	_more_hint.add_theme_color_override("font_color", LOCKED_COLOR)
	_more_hint.hide()
	stack.add_child(_more_hint)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 1)
	stack.add_child(_options_box)
	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	match type:
		WIEvents.DIALOGUE_STARTED:
			_shown = false
		WIEvents.DIALOGUE_NODE:
			_render_node(payload)
			if not _shown:
				_shown = true
				_root.show()
				ObservableBus.emit_domain_event(WIEvents.UI_DIALOGUE_SHOWN, {})
		WIEvents.DIALOGUE_ENDED:
			_hide()


func _render_node(payload: Dictionary) -> void:
	_speaker_label.text = String(payload["speaker"])
	_options = payload.get("options", [])
	_cursor = 0
	_pages = _paginate(String(payload["text"]))
	# QA (headless/TestDriver) jumps straight to the last page so a single
	# `confirm` still selects an option exactly as before this fix — the paged
	# flow is a windowed human-play affordance and must not change the injected
	# key count the 41-script sweep drives dialogue with (same _is_qa collapse
	# idiom sleep_veil/combat pacing use).
	_page_idx = (_pages.size() - 1) if _is_qa() else 0
	_render_page()


## Splits body text into word-boundary pages of at most PAGE_CHAR_BUDGET chars
## so no single page can overflow the fixed panel. A short body yields one page
## (identical to the pre-fix single-render behaviour).
func _paginate(text: String) -> Array[String]:
	var pages: Array[String] = []
	var cur := ""
	for word: String in text.split(" ", false):
		var candidate := word if cur == "" else cur + " " + word
		if candidate.length() > PAGE_CHAR_BUDGET and cur != "":
			pages.append(cur)
			cur = word
		else:
			cur = candidate
	if cur != "":
		pages.append(cur)
	if pages.is_empty():
		pages.append("")
	return pages


## Renders the current page's body text; the option list (and its input) is
## live only on the LAST page, with the "▼ more" hint standing in its place on
## earlier pages.
func _render_page() -> void:
	_text_label.text = _pages[_page_idx]
	var on_last := _on_last_page()
	_more_hint.visible = not on_last
	_options_box.visible = on_last
	if on_last:
		_rebuild_options()
	else:
		# Clear every box child (rows + L2 sub-rows) on a non-final page.
		for child: Node in _options_box.get_children():
			_options_box.remove_child(child)
			child.queue_free()
		_option_labels.clear()
	# M-LEGIBILITY L2: the option list can now carry per-option effect sub-rows
	# (shop buys / gifts), which can push a many-option node (Krshia's 5-option
	# stall) past the fixed panel height and clip options off the bottom. Rather
	# than branch the QA vs human render path (option paging would, and can't be
	# screenshot-verified), the panel GROWS to fit its content — width stays
	# fixed (repo "never widen" discipline preserved), only the height flexes
	# upward from the bottom anchor. Deferred so the Labels have computed their
	# wrapped minimum sizes for this page's content first.
	_fit_panel_height.call_deferred()


func _on_last_page() -> bool:
	return _page_idx >= _pages.size() - 1


## Sizes the panel to its current content: PANEL_SIZE.y is the floor (short
## nodes are unchanged), taller content (a many-option stall + effect sub-rows)
## grows the panel upward from its bottom anchor. Width is never touched. The
## 52 = 28 top + 24 bottom content margins (add_margins above).
func _fit_panel_height() -> void:
	if not is_instance_valid(_stack):
		return
	var needed := _stack.get_combined_minimum_size().y + 52.0
	var h := maxf(PANEL_SIZE.y, needed)
	_root.custom_minimum_size = Vector2(PANEL_SIZE.x, h)
	_root.size = Vector2(PANEL_SIZE.x, h)
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -h - 18.0, PANEL_SIZE.x * 0.5, -18.0)


func _is_qa() -> bool:
	return (TestDriver != null and TestDriver.active()) or DisplayServer.get_name() == "headless"


func _rebuild_options() -> void:
	# Free EVERY child (option rows AND their L2 effect sub-rows, which are box
	# children not tracked in `_option_labels`) so nothing accumulates on rebuild.
	for child: Node in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()
	_option_labels.clear()
	for i in _options.size():
		var opt: Dictionary = _options[i]
		var locked := bool(opt.get("locked", false))
		var mark := "> " if i == _cursor else "  "
		var text: String
		if locked:
			var opt_text := String(opt["text"])
			var suffix := _requirement_suffix(opt_text, String(opt.get("requirement", "")))
			text = "%s%d. %s%s" % [mark, i + 1, opt_text, suffix]
		else:
			text = "%s%d. %s" % [mark, i + 1, String(opt["text"])]
		var l := UIChrome.make_label()
		l.text = text
		if locked:
			l.add_theme_color_override("font_color", LOCKED_COLOR)
		_options_box.add_child(l)
		_option_labels.append(l)
		# M-LEGIBILITY L2: an item-granting option (shop buy / gift) carries
		# generated effect line(s) -- render each as an indented "Small" sub-row
		# beneath the option so "what am I buying/getting" is answered in-panel.
		# Sub-rows are extra children of the options box only; they are NOT tracked
		# in `_option_labels`, so the cursor/selection index model (one entry per
		# option) is untouched. Small font + word-wrap keeps a long effect line
		# WRAPPING inside the fixed panel width rather than widening it (repo panel
		# discipline). Follows the locked greying so a greyed buy reads uniformly.
		for effect_line: String in opt.get("effect_lines", []):
			var sub := UIChrome.make_label("      %s" % effect_line, "Small")
			sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if locked:
				sub.add_theme_color_override("font_color", LOCKED_COLOR)
			_options_box.add_child(sub)


## Authored option text sometimes already spells out the requirement inline
## (e.g. "Go on. (Warrior 2)" or "...([Basic Cleaning])"), which would double
## up with the auto-generated "(requires X)" suffix. Strip the "requires "
## lead-in and skip the suffix entirely when what's left is already present
## in the option text.
func _requirement_suffix(option_text: String, requirement: String) -> String:
	if requirement.is_empty():
		return ""
	var core := requirement.trim_prefix("requires ")
	if option_text.contains(core):
		return ""
	return "  (%s)" % requirement


func _refresh_cursor() -> void:
	for i in _options.size():
		var opt: Dictionary = _options[i]
		var mark := "> " if i == _cursor else "  "
		if bool(opt.get("locked", false)):
			var opt_text := String(opt["text"])
			var suffix := _requirement_suffix(opt_text, String(opt.get("requirement", "")))
			(_option_labels[i] as Label).text = "%s%d. %s%s" % [mark, i + 1, opt_text, suffix]
		else:
			(_option_labels[i] as Label).text = "%s%d. %s" % [mark, i + 1, String(opt["text"])]


func _hide() -> void:
	_shown = false
	_root.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_DIALOGUE_HIDDEN, {})


func _unhandled_input(event: InputEvent) -> void:
	if Game.sim.dialogue == null:
		return
	if event.is_action_pressed("confirm"):
		_confirm()
		get_viewport().set_input_as_handled()
	elif _on_last_page() and event.is_action_pressed("move_up"):
		# Option cursor is meaningful only on the last page (where the list is
		# shown); earlier pages swallow nothing but confirm (page advance).
		_move_cursor(-1)
		get_viewport().set_input_as_handled()
	elif _on_last_page() and event.is_action_pressed("move_down"):
		_move_cursor(1)
		get_viewport().set_input_as_handled()


func _move_cursor(delta: int) -> void:
	if _options.is_empty():
		return
	_cursor = wrapi(_cursor + delta, 0, _options.size())
	_refresh_cursor()


func _confirm() -> void:
	# On an earlier page, confirm turns the page instead of selecting.
	if not _on_last_page():
		_page_idx += 1
		_render_page()
		return
	if _options.is_empty():
		return
	if bool((_options[_cursor] as Dictionary).get("locked", false)):
		return
	Game.sim.dialogue_choose(_cursor)
