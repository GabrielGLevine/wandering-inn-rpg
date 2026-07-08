extends CanvasLayer
## Renders toasts and dialogue lines from ObservableBus domain events, and
## confirms actual rendering back onto the bus (ui_toast_rendered /
## ui_dialogue_rendered) so QA scripts can assert "the player saw this".
##
## GOTCHA (shipped a dead quest chain in v2): CanvasLayer has NO `modulate`
## property. Fade/tint the child Control panels, never `self`.

const TOAST_SECONDS := 2.5
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
const DIALOGUE_SECONDS := 3.0
## Dialogue panel interior text box width -- 700 panel minus the
## MarginContainer's 22px left+right margins (see `_dialogue_panel`/
## `dialogue_margin` below). A long one-liner wraps past this panel's fixed
## height and its 2nd line got half-cut under the panel chrome; binding
## design rule: never widen the panel -- truncate with an ellipsis instead
## (_fit_dialogue_line).
const DIALOGUE_TEXT_WIDTH := 656.0
## The panel used to fit only ONE wrapped line (32px content height minus
## the margins gave `_line_capacity` exactly 1 at this label's real font
## metrics), so a real bark that wraps to 2 lines -- e.g. Lyonette's
## talk_pool line ("Yes, I work here. No, I did not always. That is the
## whole story, and you may have it for the price of a nod.") -- truncated
## mid-sentence well before its punchline. Extends the same "reserve real
## pixels measured off the font metrics" treatment `_reserve_status_label_
## height` (inventory.gd) and `_toast_panel_height_for` (this file) already
## use elsewhere: capacity is a budget in WRAPPED LINES (2), not a guessed
## pixel height. `_dialogue_text_height`/`_resize_dialogue_panel` (computed
## once in `_ready()`, from `_dialogue_label`'s real resolved font) derive
## the actual content height and grow `_dialogue_panel` upward (BOTTOM
## offset held fixed) to fit it -- this const now only names the
## WRAPPED-LINE budget, not a pixel height.
const DIALOGUE_LINE_CAPACITY := 2

## Toast panel offsets (BOTTOM_RIGHT anchor). The panel is a fixed-WIDTH
## 448 always fully on-screen; the real defect this fixed was that the
## conversation panel (dialogue_panel.gd, 720x232 CENTER_BOTTOM =>
## x[280,1000] y[470,684]) is a later sibling CanvasLayer at the same
## layer, so it draws OVER the toast's left half (x[808,1000]) and hides
## the "Got: " prefix. Fix: while a conversation is open, RAISE the toast
## to the upper-right (bottom at y456, a 14px gap above the conversation
## panel's y470 top) so it clears the panel entirely and reads in full;
## drop back to the resting bottom-right spot when the conversation ends.
## LEFT/RIGHT/BOTTOM stay fixed in both states; TOP is DERIVED from
## `_toast_panel_height` (see below) instead of a fixed constant, since the
## panel's height itself can grow.
const TOAST_LEFT := -472.0
const TOAST_RIGHT := -24.0
const TOAST_BOTTOM_DEFAULT := -34.0
const TOAST_BOTTOM_RAISED := -264.0
const TOAST_PANEL_BASE_SIZE := Vector2(448.0, 96.0)
## Toast label interior text box width -- 448 panel minus the toast
## MarginContainer's 18px left+right content margins (see `_ready()`).
const TOAST_TEXT_WIDTH := 412.0
## The toast panel never got the wrapped-line budget the feed/dialogue/
## readout panels did, so a long lore/effect toast wrapping to 3+ lines had
## its bottom line sliced by the PARCHMENT_STRIP art's decorative fold.
## Measured (pixel scan at the panel's horizontal CENTER, where centered
## toast text actually sits): clean parchment through y658 and fold
## interference from y659 on, while the panel's true bottom border sits at
## y686 -- the curled ENDS near the panel corners stay clean all the way
## down, so the fold only eats into the center column where text renders.
## Danger zone = 686-658 = 28px, measured from the panel's OWN bottom edge
## (a 9-slice-art property, independent of the MarginContainer's content
## margins). Unlike the feed (top-aligned text, single measured deficit),
## the toast label is VERTICALLY CENTERED (`_ready()`), so growing the
## panel pushes only HALF of any added headroom above the text block -- the
## other half lands below it, meaning the danger zone must be budgeted
## TWICE (`_toast_panel_height`'s derivation) to actually clear the fold
## rather than just approach it.
const TOAST_FOLD_DANGER_PX := 28.0

## The toast panel's own CanvasLayer, above every other UI surface in the
## project. FULL LAYER MAP (traced across every `extends CanvasLayer`
## script in `src/`): this file's OWN outer CanvasLayer (dialogue_line bark
## panel + the hint strip, below), `dialogue_panel.gd` (conversation
## choices), `combat_screen.gd`, `consolidation_prompt.gd`, `char_creation.
## gd`, `title_screen.gd`, `field_hotbar.gd`, `pause_menu.gd` -- ALL the
## untouched default layer 1. `journal.gd`/`inventory.gd` are layer 10 (must
## paint over `WIWorldLabels`, spawned lazily by world.gd AFTER
## `Main._spawn_ui_layers` -- see their own file doc comments). `sleep_veil.
## gd` is layer 30, above literally everything (must win even over a live
## consolidation modal).
## Fixes a real bug where the toast panel sat at this file's outer layer-1
## CanvasLayer, so it drew BENEATH the layer-10 modals -- a toast firing
## while inventory/journal was open had its opening words hidden under the
## modal's own parchment border (inventory's `_status_label` echo was the
## pre-existing workaround for exactly this gap -- it stays, belt-and-
## braces, but the root cause is fixed here too). Toasts are transient,
## top-priority player feedback -- drawing OVER an open modal is correct
## UX, never the reverse. Fix: ONLY the toast panel (never `_dialogue_
## panel`/`_hint_panel` -- neither one ever competes with a layer-10 modal
## in real play) moves to its own child CanvasLayer at layer 12: above
## every layer-10 modal, below the layer-30 sleep veil (which must still
## win over a mid-display toast). `ui_toast_rendered` timing/payload are
## UNCHANGED -- this is a pure draw-order fix, QA-safe by construction.
const TOAST_CANVAS_LAYER := 12

var _toast_layer: CanvasLayer
var _toast_panel: Control
var _toast_label: Label
var _dialogue_panel: Control
var _dialogue_label: Label
## The real content-height budget for `DIALOGUE_LINE_CAPACITY` wrapped
## lines, derived once in `_ready()` from `_dialogue_label`'s resolved font
## metrics (see `DIALOGUE_LINE_CAPACITY`'s doc comment).
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

## A one-time "Press I — your pack." toast on the FIRST ITEM_GAINED, so a
## player can discover the inventory key exists. Presentation-side only --
## never persisted to save data. `_first_pickup_hint_pending` (plain
## instance var: it's set and consumed within one synchronous
## ITEM_GAINED->TOAST emission pair, so a respawn can't interleave it)
## bridges ITEM_GAINED -> the very next TOAST (pickup()'s "Got: <item>"
## toast, WIGame emits it unconditionally right after ITEM_GAINED, same
## synchronous call) so the hint enqueues AFTER the pickup toast, never
## before it.
##
## THE TRIGGER SURFACE: `_first_pickup_hint_shown` is a `static var` --
## statics live on the SCRIPT resource (preloaded once for the whole
## process by main.gd's MESSAGE_LAYER_SCRIPT const), not on the instance --
## so the shown-flag survives every MessageLayer teardown/respawn (main.gd's
## `_clear_ui_layers`/`_spawn_ui_layers` swap on every GAME_RESET/
## GAME_LOADED, plus `swap_to_title`). Net behavior:
##   - GAME_LOADED (defeat-reload, pause-menu Load, title Continue): flag
##     PERSISTS -- a player who died and reloaded in the same sitting does
##     NOT see the hint again (an instance var would be wiped by the
##     defeat-reload respawn, re-showing the hint mid-sitting).
##   - GAME_RESET (title New Game; combat defeat with no autosave yet): flag
##     RE-ARMS via `_reset_first_pickup_hint` -- a fresh run deserves the
##     hint. That reset callback is connected SCRIPT-BOUND (not instance-
##     bound) exactly once per process in `_ready()` (`_hint_reset_hooked`
##     guard): pause menu "Quit to Title" calls Main.swap_to_title() (frees
##     every UI layer, NO reset event), then title "New Game" fires
##     GAME_RESET while NO MessageLayer instance exists yet (the title
##     screen has none; main.gd only spawns UI layers in the deferred
##     swap_to_world that FOLLOWS the event), so an instance-bound listener
##     would miss that re-arm and a fresh New-Game run would silently lose
##     its hint. A Callable bound to the script resource itself stays
##     connected across every instance teardown.
##   - Fresh process boot: statics initialize false -- first run always hints.
## The hint text composes through `WIInputHints.label()` (a const can't call
## an autoload method); kb-mode output is byte-identical to the old literal
## ("Press I — your pack.").
func _first_pickup_hint_text() -> String:
	return "Press %s — your pack." % WIInputHints.label("inventory")


## The field hint strip's text, composed through WIInputHints so it
## re-renders correctly on a device swap (`_on_domain_event`'s
## INPUT_DEVICE_CHANGED arm calls this again). kb-mode output is
## byte-identical to the old hardcoded literal.
func _hint_text() -> String:
	return "%s — menu (save/load)   %s — journal   %s — inventory" % [
		WIInputHints.label("cancel"), WIInputHints.label("journal"), WIInputHints.label("inventory"),
	]


var _first_pickup_hint_pending := false
static var _first_pickup_hint_shown := false
static var _hint_reset_hooked := false

## True while a conversation panel is open (DIALOGUE_STARTED..DIALOGUE_ENDED) --
## gates the toast's raised position so it never sits behind the conversation.
var _conversation_open := false

## Current toast panel height (grows from TOAST_PANEL_BASE_SIZE.y -- see
## `_toast_panel_height`). Tracked separately from the panel's own `.size` so
## `_apply_toast_position` (called on conversation open/close, independent of
## any in-flight toast) can re-derive TOP from whatever height the last-shown
## toast needed, rather than snapping back to the base size mid-display.
var _toast_panel_height := TOAST_PANEL_BASE_SIZE.y


static func _reset_first_pickup_hint(type: String, _payload: Dictionary) -> void:
	if type == WIEvents.GAME_RESET:
		_first_pickup_hint_shown = false


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
	_toast_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# 448 wide x 96 tall base size (fits up to ~2 wrapped lines cleanly).
	# A 3+-line toast grows the panel taller per-display
	# (`_resize_toast_panel`/`_toast_panel_height`) instead of clipping at
	# this fixed height -- always grows UPWARD (top offset), so it never
	# reaches into the centre hotbar.
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
	# Widened to fit the added "I — inventory" hint without the Label
	# overflowing the parchment strip (the wrapped-line rule still applies --
	# this is a width bump for a single-line footer, not a panel that needs
	# to grow to fit multi-line content).
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
			# Re-render the hint strip's glyphs on a device swap. Re-emits
			# UI_HINT_RENDERED (the same confirmation the initial build fires)
			# so QA could assert the swap if a future script wanted to; none
			# does today (manual-pass-only).
			_hint_label.text = _hint_text()
			ObservableBus.emit_domain_event(WIEvents.UI_HINT_RENDERED, {"text": _hint_label.text})
		WIEvents.ITEM_GAINED:
			if not _first_pickup_hint_shown:
				_first_pickup_hint_pending = true
		WIEvents.TOAST:
			_queue_toast(String(payload["text"]))
			if _first_pickup_hint_pending:
				_first_pickup_hint_pending = false
				_first_pickup_hint_shown = true
				_queue_toast(_first_pickup_hint_text())
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
			_clear_dialogue_line()
			_clear_toast()
		WIEvents.UI_COMBAT_HIDDEN:
			_hint_panel.show()
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


## Unconditionally hides the `dialogue_line` bark panel (`_dialogue_panel`/
## `_dialogue_label` -- ambient NPC one-liners from `social.gd`'s talk-pool
## rotation and `wi_game.gd`'s narrative lines, NOT `dialogue_panel.gd`'s
## separate conversation-choice UI). ROOT CAUSE: `_show()`'s own 3s
## auto-hide is a coroutine awaiting `tree.create_timer(DIALOGUE_SECONDS)`;
## the teardown-race guard (`if not is_inside_tree(): return`, see that
## guard's doc comment above `_show`) can resume from that await into a
## moment where the coroutine bails WITHOUT ever reaching its own `panel.
## hide()` -- e.g. a map/world rebuild or a combat scene swap mid-hold --
## so a bark shown once could linger, increasingly clipped by every later
## panel drawn over it, through the rest of the run. Fix: an unconditional,
## synchronous clear on the three events a stale bark could plausibly
## survive into -- DIALOGUE_STARTED (a real conversation about to own the
## screen), COMBAT_STARTED (the combat HUD about to own it), MAP_CHANGED (a
## fresh scene, no bark from the old one belongs on it) -- independent of
## whether the in-flight `_show()` coroutine ever completes its own
## hold/hide. None of the three previously cleared it (COMBAT_STARTED only
## hid the hint strip, DIALOGUE_STARTED only repositioned the toast,
## MAP_CHANGED had no message_layer handler at all). Safe for QA waits:
## every script waits on `ui_dialogue_rendered` (the bark's own render
## confirmation, fired at display start) before advancing to whatever next
## triggers one of these three events -- that confirmation already fired by
## the time this clear can run, and this clear itself emits nothing, so no
## wait is starved. The hold-TIMER behavior (3.0s real, uncollapsed under
## QA -- see DIALOGUE_SECONDS) is otherwise unchanged; this is an
## independent, belt-and-braces clear, not a replacement for it.
func _clear_dialogue_line() -> void:
	_dialogue_panel.hide()


## The toast-panel sibling of `_clear_dialogue_line()` above -- SAME three
## call sites (DIALOGUE_STARTED, COMBAT_STARTED, MAP_CHANGED), same
## rationale: a toast belongs to the beat that fired it, and a fresh
## dialogue-class panel/combat HUD/map has no business inheriting a
## leftover toast from whatever came before it. ROOT CAUSE: a toast (e.g.
## "You sleep soundly.") still mid-hold (the windowed `QA_TOAST_HOLD_
## SECONDS` 0.4s legibility floor, or the real `TOAST_SECONDS` in human
## play) when the very next script beat teleports across the map and opens
## an unrelated panel -- `_apply_toast_position()` already raises it clear
## of the WIDE center-bottom conversation panel, but the toast is still ON
## SCREEN, reading as unrelated clutter next to a brand-new, unrelated
## panel. Unlike the bark panel (single-slot, no queue), the toast panel
## batches (`_toast_queue`/`_drain_toasts`) -- hiding only the panel and
## leaving the queue intact would let the NEXT queued toast pop back up
## mid-conversation/mid-combat/on-the-new-map, reproducing the same bug one
## toast later. So this clears BOTH: the visible panel now, and any
## as-yet-undrained backlog (dropped, not deferred) -- any toast still
## queued at the exact instant one of these three events fires belongs to
## whatever action just got superseded, same as the dialogue bark. Safe for
## QA waits: by design, no script's `interact()` action fires a
## TOAST/INTERACT_NOTHING queue-append in the SAME synchronous call as a
## DIALOGUE_STARTED/COMBAT_STARTED/MAP_CHANGED emission (interact()
## dispatches to exactly one outcome branch per entity kind -- a
## toast-branch prop and a dialogue-branch NPC/door are mutually exclusive
## on a single interact), and every script that asserts `ui_toast_rendered`
## waits on it BEFORE whatever later beat triggers one of these three
## events, never after -- so no in-flight wait is starved by the drop. A
## toast fired WHILE a conversation is already open (e.g. a mid-dialogue
## gold/item reward) is unaffected: this only runs once, at the moment
## DIALOGUE_STARTED/COMBAT_STARTED/MAP_CHANGED itself fires, not as a
## continuous suppression for the rest of that state.
func _clear_toast() -> void:
	_toast_panel.hide()
	_toast_queue.clear()


## Positions the toast panel: raised upper-right while a conversation is
## open (so the wide center-bottom conversation panel can't occlude it),
## resting bottom-right otherwise. See TOAST_LEFT/TOAST_BOTTOM_*'s doc
## comment for the raise rationale. TOP is derived from
## `_toast_panel_height` (never a fixed constant) so a grown panel still
## raises/rests correctly -- growth always reads upward from whichever
## BOTTOM applies.
func _apply_toast_position() -> void:
	var bottom := TOAST_BOTTOM_RAISED if _conversation_open else TOAST_BOTTOM_DEFAULT
	UIChrome.set_offsets(_toast_panel, TOAST_LEFT, bottom - _toast_panel_height, TOAST_RIGHT, bottom)


## Computes the toast panel height needed to clear the fold for a `lines`-
## wrapped-line block (see TOAST_FOLD_DANGER_PX's doc comment for the
## measurement and the x2 rationale), floored at TOAST_PANEL_BASE_SIZE.y so a
## short 1-2 line toast is pixel-identical to before this fix.
func _toast_panel_height_for(lines: int) -> float:
	var font := _toast_label.get_theme_font("font")
	var font_size := _toast_label.get_theme_font_size("font_size")
	var line_spacing := float(_toast_label.get_theme_constant("line_spacing"))
	var pitch := font.get_height(font_size) + line_spacing
	var text_block := float(lines) * pitch - line_spacing
	return maxf(TOAST_PANEL_BASE_SIZE.y, text_block + 2.0 * TOAST_FOLD_DANGER_PX)


## Grows (never shrinks below the base size) the toast panel to fit `text`'s
## own wrapped-line count, then repositions it (height feeds directly into
## `_apply_toast_position`'s TOP derivation). Called once per toast, right
## before it's shown -- see `_show`.
func _resize_toast_panel(text: String) -> void:
	var lines := _wrapped_line_count(_toast_label, text, TOAST_TEXT_WIDTH)
	_toast_panel_height = _toast_panel_height_for(lines)
	_toast_panel.custom_minimum_size = Vector2(TOAST_PANEL_BASE_SIZE.x, _toast_panel_height)
	_toast_panel.size = Vector2(TOAST_PANEL_BASE_SIZE.x, _toast_panel_height)
	_apply_toast_position()


## Sizes `_dialogue_panel` ONCE (at `_ready()` time, not per-message like
## the toast panel above -- the bark budget is a FIXED 2-line cap, not a
## per-text grow) to fit `DIALOGUE_LINE_CAPACITY` wrapped lines of
## `_dialogue_label`'s real font metrics, then repositions the panel so its
## BOTTOM edge stays exactly where it always was (-164.0, same as the
## pre-fix hardcoded offset) -- the panel grows UPWARD only, identical to
## how the toast panel grows (see `_apply_toast_position`'s doc comment),
## so nothing below it (the hint strip, the field hotbar) is encroached on.
func _resize_dialogue_panel() -> void:
	var font := _dialogue_label.get_theme_font("font")
	var font_size := _dialogue_label.get_theme_font_size("font_size")
	var line_spacing := float(_dialogue_label.get_theme_constant("line_spacing"))
	var pitch := font.get_height(font_size) + line_spacing
	_dialogue_text_height = DIALOGUE_LINE_CAPACITY * pitch - line_spacing
	# 12 + 12 = the dialogue_margin's own top+bottom content margins (see
	# `_ready()`'s `UIChrome.add_margins(dialogue_margin, 22, 12, 22, 12)`).
	var panel_height := _dialogue_text_height + 24.0
	_dialogue_panel.custom_minimum_size = Vector2(700.0, panel_height)
	_dialogue_panel.size = Vector2(700.0, panel_height)
	const DIALOGUE_BOTTOM := -164.0
	UIChrome.set_offsets(_dialogue_panel, 36.0, DIALOGUE_BOTTOM - panel_height, 736.0, DIALOGUE_BOTTOM)


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


## Collapses a presentation hold under QA (same TestDriver.active()/headless
## detection as combat_screen.gd's `_beat_delay`/`_presentation_delay` and
## world.gd's `_presentation_delay`) so a queue of several toasts drains
## fast instead of piling up 2.5s of real wall-clock per toast and stalling
## a QA script. HEADLESS collapses to a near-zero, frame-bounded hold
## (screenshots are skipped -- see QA_TOAST_HOLD_HEADLESS_SECONDS);
## WINDOWED QA keeps the 0.4s floor so a toast a script just waited on is
## still on screen when the (windowed-only) screenshot fires (see
## QA_TOAST_HOLD_SECONDS). Scoped to the toast queue only
## (`collapse_under_qa` in `_show`) -- the dialogue panel keeps its
## original always-real hold; it was never queued/batched and nothing
## needs its timing changed.
func _hold_seconds(seconds: float) -> float:
	if DisplayServer.get_name() == "headless":
		return minf(seconds, QA_TOAST_HOLD_HEADLESS_SECONDS)
	if TestDriver != null and TestDriver.active():
		return minf(seconds, QA_TOAST_HOLD_SECONDS)
	return seconds


## Teardown-race guard. `await get_tree().process_frame`/`await get_tree().
## create_timer(...).timeout` can resume AFTER this node has left the tree
## (a world/combat swap or GAME_RESET freeing MessageLayer mid-toast) --
## `get_tree()` returns null once outside the tree, so a naive resume
## crashes with "Invalid access to property or key 'process_frame'/
## 'create_timer' on a base object of type 'null instance'" (hit once, not
## reproducible). Fix: capture the tree ref BEFORE each await (never call
## `get_tree()` again after resuming without re-checking), and after EVERY
## await bail early if `not is_inside_tree()` -- before touching
## `get_tree()` again or doing any further UI access
## (`ObservableBus.emit_domain_event`, `panel.hide()`). Guards only: the
## live (still-in-tree) path's timing/behavior is unchanged.
func _show(panel: Control, label: Label, text: String, seconds: float, rendered_event: String, display_text: String = "", collapse_under_qa: bool = false) -> void:
	# Only the toast panel grows -- feed/dialogue/readout already have their
	# own fixed-panel wrapped-line budgets, so this is scoped to
	# `panel == _toast_panel` only.
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


## Cuts whole words (design rule: cut words, never widen the UI) and
## appends an ellipsis until `text` fits the dialogue panel's real wrapped-
## line capacity. Returns `text` unchanged if it already fits.
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
