extends CanvasLayer

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
## FALLBACK ceiling on the GH#324 capture hold (`_await_capture_release`). The
## live number comes from `TestDriver.capture_hold_ceiling_msec()`, which adds
## up the waits a capture can actually sit in -- including the web export's 10s
## browser handshake, which this hand-picked constant used to be less than half
## of (v0.17 fix wave, adversarial finding #5: a web shot slower than ~2.85s
## re-opened the exact #324 race, silently). This value survives only for a
## driver too old to answer, and hitting EITHER bound is now reported loudly.
const CAPTURE_HOLD_CEILING_SECONDS := 16.0
## HOUSEKEEPING TOASTS ONLY (v0.16.1 findings 8/16/25 + GH#325). This cap used
## to apply to EVERY queued toast, and it was the real reason transient toasts
## "vanish too fast": every beat that matters emits 2-4 toasts at once (autosave
## + quest updated + payoff; class gained + level + unlocks), so in exactly the
## moments the player most needs to read, every toast but the last flashed for
## 1.6s no matter how long its own hold was. AUTHORED toasts are no longer
## capped -- a queued authored toast keeps at least its full `_toast_seconds`
## hold. Chores stay capped: a stack of "Autosaved." must never eat reading
## time ahead of the payoff prose it was queued beside.
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

## World hint ribbon ("Esc — menu   J — journal   I — inventory"). The panel
## rect and its content margins are BOTH derived, from live font metrics plus
## the strip art's own patch geometry (`_resize_hint_panel`), never hardcoded.
## TRAP: the old fixed 400x28 clipped descenders and truncated the tail
## mid-word at Text Scale 115%/130% -- "J — journal" degraded to a bare stroke
## indistinguishable from "I — inventory". Same derive-from-metrics contract as
## `_resize_dialogue_panel`. The old 14/5 content margins are DELETED, not kept
## as named constants -- 14 is narrower than the art's end caps, and a
## plausible-looking wrong number within reach is what HINT_PAPER_SIDE_INSET
## exists to stop.
## Floor only: keeps the strip's 9-slice corners from crushing when the copy
## is short. Growth above it is metric-driven.
const HINT_PANEL_MIN_SIZE := Vector2(400.0, 28.0)
## THE VERTICAL TRAP, measured off Banner_Horizontal's own bands (source
## region y 47..169; painted paper 51..140, then the bottom rule, the fold and
## the scroll shadow). The strip is drawn as a 9-patch with STRIP_PATCH_MARGIN
## (20) top and bottom, so BELOW a 40px panel the center band never stretches
## at all and the visible paper is stuck at ~16px no matter how tall the rect
## is -- which is why the old 400x28 clipped the moment Small went 12 -> 14.
## Above 40px the paper grows at HINT_PAPER_CENTER_SHARE per extra pixel
## (73 of the center band's 83 source rows are paper; the rest is ornament).
const HINT_PAPER_TOP_INSET := 4.0
const HINT_PAPER_CENTER_SHARE := 73.0 / 83.0
const HINT_STRIP_PATCH := 20.0
## THE HORIZONTAL HALF OF THE SAME TRAP: the 9-patch's END CAPS are that same
## 20, so the art-safe band is [20, width - 20], NOT [14, width - 14]. Padding
## the width by 14 put the line 6px inside the ornament the moment the natural
## width beat the floor -- measured at 130%: panel 424 = text + 28, label rect
## to x=410 against a paper edge at 404, tail of "inventory" across the stroke.
const HINT_PAPER_SIDE_INSET := HINT_STRIP_PATCH
## Breathing room under the descenders before the bottom rule.
const HINT_PAPER_BOTTOM_PAD := 3.0
## Same at the ends. TRAP: the label is OVERRUN_TRIM_ELLIPSIS, so a rect sized
## to the measurement exactly has ZERO slack and one pixel of layout rounding
## trims to "I — inventor…". `_resize_hint_panel` also ceils the width.
const HINT_PAPER_SIDE_PAD := HINT_PAPER_BOTTOM_PAD
## The ribbon is one line by contract (three key hints, never wrapped) -- it
## may not eat the screen if a device label grows, so the derived width caps
## here and the label ellipsizes rather than running under the toast strip.
const HINT_PANEL_MAX_WIDTH := 640.0
const HINT_PANEL_LEFT := 8.0
const HINT_PANEL_BOTTOM := -8.0

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
var _hint_margin: MarginContainer
var _hint_label: Label

## Toast queue: TOAST/INTERACT_NOTHING both render onto the single
## _toast_panel/_toast_label -- a multi-class level-up beat or a dual
## evolution can emit several in one synchronous beat, and the nested-
## autosave-toast gotcha (Game's class_gained listener calls save_auto()
## synchronously, re-entering _on_domain_event for its own toast) can append
## one mid-display. `_toast_queue` holds pending toast text in emission
## order; `_toast_draining` gates a single in-flight drain coroutine so
## concurrent _queue_toast calls never start a second drain loop.
## Entries are `{text, record, housekeeping}`, not bare strings: both flags have
## to survive the bank/restore round trip, and `record` used to ride a parallel
## `_transient_counts` tally keyed by TEXT (which could mis-credit an identical
## real toast queued concurrently). One dictionary per queued toast makes both
## exact.
var _toast_queue: Array[Dictionary] = []
## v0.15 A3 (GH#304): THE QUEUE IS LOSSLESS. Only `_drain_toasts` may remove a
## queued toast. Map change and dialogue used to wipe it (`_clear_toast`),
## which is what ate the arc's Watch-runner pointer (VISUAL-LOG UI/QUEST-START,
## P1) and, measured on horns_dig_flow at seed 9, left 14 of 19 emitted toast
## payloads reaching `ui_toast_rendered` (TOAST/QUEUE-DROP, P2 -- 0 unrendered
## after); they DEFER the visible toast only and the queue drains later. That
## makes GH#273's sticky re-queue and the first-wake-hint re-queue structural
## rather than per-text bookkeeping -- `sticky` survives as the SIM-side
## authored signal ("this line must not be lost", pinned in test_sim_core), and
## the renderer no longer needs to special-case it because nothing is lost.
## Combat is the one deliberate exception: it has its own feed, so
## COMBAT_STARTED BANKS the pending queue (below) and UI_COMBAT_HIDDEN
## re-queues it.
## HAZARD for QA authors: `_defer_toast_display` also calls
## `dismiss_current_toast_early()`, so a transition CUTS SHORT the showing
## toast's hold -- including the windowed QA_TOAST_HOLD_SECONDS 0.4s
## legibility floor that the screenshot discipline leans on. A script that
## needs a specific toast ON SCREEN across a map change must wait on that
## toast's OWN `ui_toast_rendered` after the transition (it re-renders on the
## far side); a bare wait plus a screenshot can catch the panel already hidden.
## Toasts parked for the duration of a fight. Bank/restore move whole entries
## between here and `_toast_queue`; nothing is ever dropped in either direction.
var _banked_toasts: Array[Dictionary] = []
## True from COMBAT_STARTED to UI_COMBAT_HIDDEN. While set, EVERY toast banks
## instead of queuing -- see `_queue_toast`. The toast strip's band
## (x[808,1256] y[590,686] at 1280x720) is bare arena, absent from the combat
## HUD's disjoint-band map, so a mid-fight toast (drinking a draught is the
## everyday case) sat on the board's lower-right rows. Closing the acknowledged
## exemption follows the v0.15 COMBAT/FEED-FOLD precedent: combat message copy
## belongs in the FEED, measured inside its own band. Relocation was rejected --
## every alternative band collides with the order strip, feed, readout or hotbar.
var _combat_active := false
## Whether the toast currently on screen is housekeeping -- read by `_show` to
## decide whether TOAST_QUEUE_HOLD_CAP_SECONDS applies.
var _showing_housekeeping := false
## GH#334 note 7: whether the toast currently on screen carries `protected` --
## read by the PLAYER_MOVED arm to leave it alone. Instance state rather than a
## queue peek, for the same reason `_showing_housekeeping` is: the entry has
## already been popped by the time it is showing.
var _showing_protected := false
var _toast_draining := false
## Open full-screen modals, keyed by their own SHOWN event id. A SET rather than
## a counter so a doubled show/hide pair cannot strand the drain paused forever
## -- the drain resumes the moment this is empty. See `_drain_toasts`.
var _open_modals: Dictionary = {}
## Issue #62 Lane U item 6: set by `dismiss_current_toast_early()`, consumed
## by `_show()`'s interruptible hold-wait (toast panel only -- the dialogue
## bark never sets or checks this). Does NOT drop or reorder anything in
## `_toast_queue` -- it only shortens the CURRENTLY showing toast's remaining
## hold; `_drain_toasts`'s own while-loop still pops and shows every
## remaining queued toast, in order, right after.
var _toast_skip_requested := false

func _first_pickup_hint_text() -> String:
	return "Press %s — your pack." % WIInputHints.label("inventory")


## GH#171 item 7: empty interacts answer in the room's voice instead of a flat
## "Nothing there." (presentation-only; the flat line stays as the floor).
##
## v0.16.1 finding 4 -- WHICH TILESET IS NOT WHOSE VOICE. This used to read the
## line straight off the biome, and `biome: inn` is declared by TEN maps: the two
## real inn maps plus the Riverfarm mill and longhouse, the witch's hut, the
## Liscor barracks/guild/runners' guild, the Invrisil adventurers' rest and a
## Pallass shop. So poking empty air in a Riverfarm mill answered in Erin's
## voice, three regions away. The biome legitimately owns floor sheet, blocked
## props, skirt and footstep family -- it does not own a venue's personality.
## Resolution order, most specific first:
##   1. the MAP's own `interior_flavor` (scene_catalog._compose copies each map
##      JSON wholesale into maps[map_id], so a top-level key is visible here
##      with no plumbing at all) -- the intended home for a per-venue line;
##   2. the biome's `interior_flavor_by_map[map_id]`, which is how the inn keeps
##      its own joke while nine other rooms stop telling it;
##   3. the biome's venue-neutral `interior_flavor`;
##   4. "Nothing there."
## The biome default is "" rather than "inn": a map that forgets to declare a
## biome must fall through to the flat line, not silently inherit Erin's voice.
func _interact_nothing_text() -> String:
	if Game.sim != null:
		var maps: Dictionary = WIDataRegistry.scene_config().get("maps", {})
		var map_id := String(Game.sim.current_map)
		var map_cfg: Dictionary = maps.get(map_id, {})
		var map_line := String(map_cfg.get("interior_flavor", ""))
		if map_line != "":
			return map_line
		var biome_id := String(map_cfg.get("biome", ""))
		var biome: Dictionary = WIDataRegistry.biomes().get(biome_id, {})
		var by_map: Dictionary = biome.get("interior_flavor_by_map", {})
		var venue_line := String(by_map.get(map_id, ""))
		if venue_line != "":
			return venue_line
		var line := String(biome.get("interior_flavor", ""))
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
	_hint_margin = MarginContainer.new()
	UIChrome.full_rect(_hint_margin)
	_hint_panel.add_child(_hint_margin)
	_hint_label = UIChrome.make_label("", "Small")
	_hint_label.text = _hint_text()
	_hint_margin.add_child(_hint_label)
	root.add_child(_hint_panel)
	# Must run AFTER add_child, same theme-lookup ordering `_resize_dialogue_panel`
	# needs: `_hint_label` has to be inside the themed tree before its font
	# metrics answer.
	_resize_hint_panel()
	# Text scale mutates UIChrome.THEME in place; Theme.changed propagates to
	# every Control using it, so BOTH derived panels re-fit live instead of
	# staying frozen at the size they were built with.
	root.theme_changed.connect(_on_theme_changed)
	ObservableBus.emit_domain_event.call_deferred(WIEvents.UI_HINT_RENDERED, _hint_payload())

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
			_resize_hint_panel()
			ObservableBus.emit_domain_event(WIEvents.UI_HINT_RENDERED, _hint_payload())
		WIEvents.ITEM_GAINED:
			# pickup() emits ITEM_GAINED then TOAST synchronously; arm first so
			# the hint queues immediately after the pickup's own toast.
			if not _first_pickup_hint_shown:
				_first_pickup_hint_pending = true
		WIEvents.TOAST:
			# `housekeeping` is the emitter's own claim: save/settings chrome
			# marks itself, everything else is authored copy by default.
			# GH#334 note 7: `sticky` -- the SIM-side "this line must not be
			# lost" marker quest beats and the Watch-runner pointer already
			# carry -- now also buys exemption from the MOVEMENT dismiss. See
			# `_queue_toast`'s `protected` and the PLAYER_MOVED arm below.
			_queue_toast(String(payload["text"]), bool(payload.get("record", true)),
				bool(payload.get("housekeeping", false)),
				bool(payload.get("sticky", false)),
				bool(payload.get("modal_response", false)))
			if _first_pickup_hint_pending:
				_first_pickup_hint_pending = false
				_first_pickup_hint_shown = true
				_queue_toast(_first_pickup_hint_text())
		WIEvents.INTERACT_NOTHING:
			# GH#202: empty-interact flavor is TRANSIENT -- render the toast
			# but keep it out of Recent Messages, or idle wall-poking pushes
			# real history past the cap.
			# ...and housekeeping: idle wall-poking must never queue ahead of an
			# authored beat, nor spend the queue's reading time.
			_queue_toast(_interact_nothing_text(), false, true)
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
			_combat_active = true
			_clear_dialogue_line()
			_defer_toast_display()
			_bank_toasts()
		WIEvents.UI_COMBAT_HIDDEN:
			_hint_panel.show()
			_combat_active = false
			_restore_banked_toasts()
		WIEvents.UI_SLEEP_VEIL_FINISHED:
			# GH#171: one pointer at the full key reference, on the genuine
			# first waking only (times_slept == 1 filters loaded veteran
			# saves whose next sleep is not their first).
			if not _first_wake_hint_shown and Game.sim != null and Game.sim.times_slept == 1:
				_first_wake_hint_shown = true
				_queue_toast(_first_wake_hint_text())
		WIEvents.DIALOGUE_STARTED:
			_conversation_open = true
			_apply_toast_position()
			_clear_dialogue_line()
			_defer_toast_display()
		WIEvents.DIALOGUE_ENDED:
			_conversation_open = false
			_apply_toast_position()
		WIEvents.MAP_CHANGED:
			_clear_dialogue_line()
			_defer_toast_display()
		WIEvents.PLAYER_MOVED:
			# GH#334 note 7: a PROTECTED toast survives this. Movement is the
			# ordinary "I have read it, move on" signal for a toast about
			# somewhere the player was standing -- but the delivery arrival beat
			# is the one completion that only ever fires FROM movement, and a
			# player holding a direction (the normal way you approach an NPC)
			# took the next step ~0.12s later and cancelled the only mark the
			# moment had. The exemption is scoped to THIS dismiss: a map change,
			# a conversation and an interact all still cut a protected toast
			# short, because each of those is a new thing to read.
			if not _showing_protected:
				dismiss_current_toast_early()
		WIEvents.UI_JOURNAL_SHOWN, WIEvents.UI_INVENTORY_SHOWN, \
		WIEvents.UI_PAUSE_SHOWN, WIEvents.UI_SETTINGS_SHOWN:
			_open_modals[type] = true
			_defer_toast_display()
		WIEvents.UI_JOURNAL_HIDDEN, WIEvents.UI_INVENTORY_HIDDEN, \
		WIEvents.UI_PAUSE_HIDDEN, WIEvents.UI_SETTINGS_HIDDEN:
			_open_modals.erase(_shown_event_for(type))
			if not _toast_draining and not _toast_queue.is_empty() and _open_modals.is_empty():
				_drain_toasts()


## `_open_modals` is keyed by SHOWN id; the HIDDEN handler has only its own id.
## Derived by suffix swap rather than by a second const table, so a new modal
## pair needs one match arm, not two lookups.
func _shown_event_for(hidden_event: String) -> String:
	return hidden_event.trim_suffix("_hidden") + "_shown"


func _clear_dialogue_line() -> void:
	_dialogue_panel.hide()


## DISPLAY PROOF (GH#324). `ui_dialogue_rendered` fires ONE process frame after
## `panel.show()` and says nothing about whether the panel is still on screen
## when evidence is captured -- that gap is the whole substance of GH#324, where
## a bark's own hold expired before the windowed screenshot fired and every
## capture showed an empty line slot while the bus reported the full string.
## This reports the line panel's LIVE state (visibility through the entire
## CanvasLayer chain, the composed text as the label actually holds it, and the
## panel's on-screen rect) so a QA capture can assert what a PLAYER would see.
## Read-only: never mutates panel state, so probing can't perturb a run.
func dialogue_display_state() -> Dictionary:
	var rect := _dialogue_panel.get_global_rect()
	var view := get_viewport().get_visible_rect()
	return {
		"visible": _dialogue_panel.is_visible_in_tree(),
		"text": _dialogue_label.text,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"on_screen": view.intersects(rect),
	}


func _show_dialogue_line(text: String, fitted: String) -> void:
	await _show(_dialogue_panel, _dialogue_label, text, _dialogue_hold_seconds(fitted), WIEvents.UI_DIALOGUE_RENDERED, fitted, true)
	# CONTRACT: audio releases standalone-line duck on the renderer's actual close.
	ObservableBus.emit_domain_event(WIEvents.UI_DIALOGUE_LINE_HIDDEN, {})


## A transition retires the toast that ALREADY RENDERED (it is about the side
## the player just left, and dialogue needs the raised slot clear) and cuts its
## remaining hold short so the survivors drain immediately on the far side. The
## queue itself is untouched -- see `_toast_queue`'s contract.
func _defer_toast_display() -> void:
	dismiss_current_toast_early()
	_toast_panel.hide()


## Combat's own feed replaces the toast strip for the fight's duration, so the
## pending queue waits it out rather than rendering over the board. Toasts
## emitted DURING the fight now wait it out too (`_combat_active` in
## `_queue_toast`) -- the exemption that let them render over the arena is
## closed; combat_screen mirrors their text into the feed so nothing is lost
## in the moment either.
func _bank_toasts() -> void:
	for entry: Dictionary in _toast_queue:
		_banked_toasts.append(entry)
	_toast_queue.clear()


func _restore_banked_toasts() -> void:
	if _banked_toasts.is_empty():
		return
	for entry: Dictionary in _banked_toasts:
		_toast_queue.append(entry)
	_banked_toasts.clear()
	# Unlike `_queue_toast`, this can run with no drain in flight (the drain
	# loop exited while the queue sat banked), so it must kick one itself.
	if not _toast_draining:
		_drain_toasts()


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


## Fits the hint ribbon to ONE line of `_hint_label`'s LIVE font metrics plus
## its MarginContainer's own content margins, floored at HINT_PANEL_MIN_SIZE
## and capped at HINT_PANEL_MAX_WIDTH. Above the cap the label ellipsizes
## (`TextServer.OVERRUN_TRIM_ELLIPSIS`) instead of the panel widening under
## the toast strip -- design rule D2-7 #6: cut words, never widen UI.
## CONSTRAINT: `ui_hint_rendered` keeps carrying the WHOLE string, so QA text
## pins are unaffected by any trim (the `_fit_dialogue_line` contract).
func _resize_hint_panel() -> void:
	var font := _hint_label.get_theme_font("font")
	var font_size := _hint_label.get_theme_font_size("font_size")
	var text_size := font.get_string_size(_hint_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	# HINT_PAPER_SIDE_INSET, not the old 14px content margin: the width has to
	# clear the 9-patch's END CAPS, which are 20 wide, or the string sits inside
	# the ornament the moment the natural width beats the floor. See the const.
	var side := HINT_PAPER_SIDE_INSET + HINT_PAPER_SIDE_PAD
	var width := clampf(ceilf(text_size.x + 2.0 * side), HINT_PANEL_MIN_SIZE.x, HINT_PANEL_MAX_WIDTH)
	var text_h := font.get_height(font_size)
	var size := Vector2(width, _hint_panel_height_for(text_h))
	_hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint_panel.custom_minimum_size = size
	_hint_panel.size = size
	UIChrome.set_offsets(
		_hint_panel, HINT_PANEL_LEFT, HINT_PANEL_BOTTOM - size.y,
		HINT_PANEL_LEFT + size.x, HINT_PANEL_BOTTOM)
	# Centre the line in the PAPER, not in the panel rect: the rect's bottom
	# ~40% is rule/fold/shadow/transparency, so panel-centred (the Label
	# default) is paper-LOW and walks into the ornament as the font grows.
	# Driving it from the container's own margins rather than from
	# `vertical_alignment` keeps the placement exact and alignment-independent.
	var top := int(round(HINT_PAPER_TOP_INSET + (_hint_paper_height(size.y) - text_h) * 0.5))
	var bottom := maxi(0, int(round(size.y)) - top - int(ceilf(text_h)))
	var side_px := int(round(side))
	UIChrome.add_margins(_hint_margin, side_px, top, side_px, bottom)


## Painted-paper height inside a panel `height` px tall -- see
## HINT_PAPER_TOP_INSET's block for the band arithmetic.
func _hint_paper_height(height: float) -> float:
	return HINT_STRIP_PATCH + HINT_PAPER_CENTER_SHARE * (height - 2.0 * HINT_STRIP_PATCH) - HINT_PAPER_TOP_INSET


## Smallest panel height whose PAINTED PAPER holds one line of `text_h` with
## HINT_PAPER_BOTTOM_PAD clear above and below it. Below 2*HINT_STRIP_PATCH the
## strip's center band never stretches at all, so growing the rect buys no
## paper -- which is exactly the regime the old 400x28 was stuck in.
func _hint_panel_height_for(text_h: float) -> float:
	var needed_paper := text_h + 2.0 * HINT_PAPER_BOTTOM_PAD
	var height := 2.0 * HINT_STRIP_PATCH \
		+ (needed_paper + HINT_PAPER_TOP_INSET - HINT_STRIP_PATCH) / HINT_PAPER_CENTER_SHARE
	return maxf(HINT_PANEL_MIN_SIZE.y, ceilf(height))


## Text Scale rewrites UIChrome.THEME's font sizes in place. Both derived
## panels re-fit here; nothing else in this layer caches a font metric (the
## toast/feed budgets all read `get_theme_font_size` at render time).
func _on_theme_changed() -> void:
	if _dialogue_label == null or _hint_label == null:
		return
	_resize_dialogue_panel()
	_resize_hint_panel()
	ObservableBus.emit_domain_event(WIEvents.UI_HINT_RENDERED, _hint_payload())


## `text` stays the WHOLE authored string (never the trimmed render) so every
## existing text pin holds. The three geometry keys are what makes the
## overflow machine-detectable: `fits` is false exactly when one line of the
## live font no longer clears the panel's inner width, which is the state the
## hardcoded 400x28 shipped in at 115%/130%.
## NOT A TAUTOLOGY, deliberately: `inner` is read back off the margins the
## container was ACTUALLY given, and those margins are checked against the
## art-safe band, so an inset regression flips `fits` false and settings_loop
## catches it headlessly. Deriving `inner` from a constant while the width was
## derived from that same constant is what made it unfalsifiable below the cap.
func _hint_payload() -> Dictionary:
	var font := _hint_label.get_theme_font("font")
	var font_size := _hint_label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(_hint_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var left := float(_hint_margin.get_theme_constant("margin_left"))
	var right := float(_hint_margin.get_theme_constant("margin_right"))
	var on_paper := left >= HINT_PAPER_SIDE_INSET - 0.5 and right >= HINT_PAPER_SIDE_INSET - 0.5
	var inner := _hint_panel.size.x - left - right
	return {
		"text": _hint_label.text,
		"width": int(round(_hint_panel.size.x)),
		"height": int(round(_hint_panel.size.y)),
		"fits": on_paper and text_width <= inner + 0.5,
	}


## `housekeeping` = save/settings chrome and idle-poke flavor: real, worth
## seeing, but never the thing the player was waiting for. Two rules follow.
## (1) ORDER: an authored toast INSERTS ahead of any trailing housekeeping
## entries instead of appending. That is GH#325's whole fix -- game.gd autosaves
## from inside its own QUEST_BEAT_COMPLETED/CLASS_* listener, which runs BEFORE
## the sim's own quest/payoff toasts reach the bus, so "Autosaved." took slot 1
## and the authored payoff took slot 3. It fixes the order without introducing a
## toast-ORDER pin (banned since the v0.15 fold): the queue is still strictly
## FIFO within each class.
## (2) HOLD: only housekeeping entries are clipped by
## TOAST_QUEUE_HOLD_CAP_SECONDS while others wait.
## (3) MOVEMENT DISMISS: `protected` entries (GH#334 note 7 -- the sim's own
## `sticky` marker) keep their full hold across PLAYER_MOVED. Nothing else about
## them differs: ordering, recording and the hold cap are untouched.
## (4) MODAL RESPONSE: a `modal_response` entry is the ONE class of toast that
## may render while a modal is open -- it is the direct answer to a key the
## player just pressed INSIDE that modal (the journal's passive-row refusal is
## the first), and holding it until the panel closes turns a principled refusal
## back into the dropped keypress it must not look like. Scoped hard: the
## overlap the modal pause exists to prevent is a 3-line toast reaching a
## journal body row, so a modal-response line is one short line by contract.
## Nothing else about it differs -- lossless queue, ordering within its class,
## the hold cap.
func _queue_toast(text: String, record := true, housekeeping := false, protected := false, modal_response := false) -> void:
	var entry := {
		"text": text, "record": record, "housekeeping": housekeeping,
		"protected": protected, "modal_response": modal_response,
	}
	if _combat_active:
		# The board is up: the feed speaks for the fight (combat_screen mirrors
		# authored text into it, which is also what puts it in Recent Messages),
		# so the strip stays silent and the toast waits in the bank. `record` is
		# dropped for exactly those toasts, because the feed already recorded
		# them -- otherwise the post-fight drain would double-enter them.
		# HOUSEKEEPING keeps its record flag: chrome is not mirrored into the
		# combat feed, so its only entry into Recent Messages is that drain.
		if not housekeeping:
			entry["record"] = false
		_banked_toasts.append(entry)
		return
	if housekeeping:
		_toast_queue.append(entry)
	else:
		_toast_queue.insert(_authored_insert_index(), entry)
	if not _toast_draining:
		_drain_toasts()


## Which queued toast may show right now: the head (plain FIFO) with no modal
## open, otherwise the first `modal_response` entry, otherwise -1 = "nothing may
## show, leave the queue untouched" (the lossless-queue contract -- the modal's
## own HIDDEN event kicks the drain again).
func _next_toast_index() -> int:
	if _toast_queue.is_empty():
		return -1
	if _open_modals.is_empty():
		return 0
	for i in _toast_queue.size():
		if bool((_toast_queue[i] as Dictionary).get("modal_response", false)):
			return i
	return -1


## Index of the first entry in the trailing run of housekeeping toasts (== the
## queue size when the tail is authored). Authored toasts land there, so chores
## already waiting are pushed behind them without disturbing anything earlier.
func _authored_insert_index() -> int:
	var at := _toast_queue.size()
	while at > 0 and bool(_toast_queue[at - 1].get("housekeeping", false)):
		at -= 1
	return at


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
		# VISUAL-LOG TOAST/MODAL-OVERLAP (P2), v0.15 A4. Toasts draw at layer 12,
		# above the journal's 10 (deliberate: feedback clears modals, never the
		# sleep veil). Measured in the Phase-1 close-out: a 1-line toast overlaps
		# only blank parchment margin, but a 3-line toast is 122px tall, tops out
		# at y~564, and reaches the journal's last body rows -- seal_fed/04b clips
		# Recent Messages mid-word ("...Find ou|"). The Leads rows are the longest
		# lines the panel draws, so it worsens as leads accumulate. PAUSE, never
		# drop: `break` leaves the queue untouched (the lossless-queue contract) and
		# the modal's own HIDDEN event kicks the drain again, so the player reads
		# the toast the moment the panel closes.
		# ...with ONE exemption: a `modal_response` entry (see `_queue_toast`
		# note 4). `_next_toast_index` returns -1 when a modal is open and the
		# queue holds no such entry, which is the original `break`.
		var at := _next_toast_index()
		if at < 0:
			break
		var entry: Dictionary = _toast_queue.pop_at(at)
		var text := String(entry["text"])
		_showing_housekeeping = bool(entry.get("housekeeping", false))
		_showing_protected = bool(entry.get("protected", false))
		if bool(entry.get("record", true)):
			record_message(text)
		await _show(_toast_panel, _toast_label, text, _toast_seconds(text), WIEvents.UI_TOAST_RENDERED, "", true, true)
		_showing_protected = false
	_toast_draining = false


## GH#170 (friend playtest x3 + #167): reading time scales with text.
## v0.16.1 finding 8, per user directive: the whole curve is the old one x1.5 --
## `clampf(2.8 + 0.035*len, 3.4, 7.0)` became `clampf(4.2 + 0.05*len, 5.1,
## 10.5)`, so a transient toast hangs about half again as long as it used to.
## The base duration was never the worst of it (the queue cap was), but at 3.4s
## a short toast really did outrun a reader who had just looked at the board.
## QA/headless holds are untouched (`_hold_seconds` still floors them to
## 0.05s/0.4s), so canonical timing is byte-identical.
func _toast_seconds(text: String) -> float:
	return clampf(4.2 + 0.05 * float(text.length()), 5.1, 10.5)


func _is_gold_toast(text: String) -> bool:
	return text.begins_with("Earned ") or text.begins_with("Paid ")


func _fold_gold_toast(text: String) -> String:
	var merged := text
	while not _toast_queue.is_empty() and _is_gold_toast(String(_toast_queue[0]["text"])):
		merged += " " + String((_toast_queue.pop_front() as Dictionary)["text"])
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
	# Only CHORES yield their reading time to the queue -- see the constant.
	var chore := panel == _toast_panel and _showing_housekeeping
	if chore and not _toast_queue.is_empty():
		hold = minf(hold, TOAST_QUEUE_HOLD_CAP_SECONDS)
	if hold > 0.0:
		if interruptible:
			_toast_skip_requested = false
			var started_msec := Time.get_ticks_msec()
			var deadline_msec := started_msec + int(hold * 1000.0)
			while Time.get_ticks_msec() < deadline_msec and not _toast_skip_requested:
				# RE-CHECKED EVERY FRAME, not once at display time -- GH#325's own
				# sequence queues the chore FIRST (game.gd autosaves from inside
				# its QUEST_BEAT_COMPLETED listener, before the sim's payoff toast
				# reaches the bus), so the queue is still EMPTY when "Autosaved."
				# starts and a one-shot check leaves it holding its full duration
				# with the payoff waiting behind it. Authored toasts are never
				# clamped here; QA holds (0.05s/0.4s) are already under the cap, so
				# canonical timing is untouched.
				if chore and not _toast_queue.is_empty():
					deadline_msec = mini(deadline_msec, started_msec + int(TOAST_QUEUE_HOLD_CAP_SECONDS * 1000.0))
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
	await _await_capture_release()
	if not is_inside_tree():
		return
	panel.hide()


## GH#324, the verification-boundary half. The QA hold above is a wall-clock
## floor (`QA_TOAST_HOLD_SECONDS`) picked so a panel would outlive
## `SCREENSHOT_SETTLE_SECONDS` -- arithmetic that #119's tween drain
## invalidated: a capture now settles 0.15s PLUS up to 3s of live-tween drain,
## and the boot music crossfade (1.0s) or a bark's own music duck (0.2s) pushed
## the capture past the floor. The panel had already retired, so every windowed
## shot of a line served near `world_ready` caught an empty slot while
## `ui_dialogue_rendered` reported the full string. A bigger floor is the same
## arithmetic one round later; instead the panel now simply does not retire
## while the driver has evidence capture in flight, which makes
## "capture never races a transient panel's retirement" structural.
## Bounded (a wedged capture cannot strand a panel on screen forever) and
## QA-only by construction: `_capture_depth` is never raised in headless (both
## capture paths return first) and there is no TestDriver in a real session, so
## unattended play and every headless canonical are byte-identical to before.
## The bound is ASKED FOR, not assumed (finding #5): the driver derives it from
## the waits a capture can really sit in, which on the web path is ~13.2s -- a
## shorter bound would hand the race back with no signal. Expiring it is
## therefore never routine, so it fails loud (`push_error` prints an `ERROR:`
## line, which every run's grep discipline treats as a failure).
func _await_capture_release() -> void:
	if TestDriver == null or not TestDriver.active():
		return
	var ceiling_msec := int(CAPTURE_HOLD_CEILING_SECONDS * 1000.0)
	if TestDriver.has_method("capture_hold_ceiling_msec"):
		ceiling_msec = int(TestDriver.capture_hold_ceiling_msec())
	var deadline_msec := Time.get_ticks_msec() + ceiling_msec
	while TestDriver.capture_in_flight() and Time.get_ticks_msec() < deadline_msec:
		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame
		if not is_inside_tree():
			return
	if TestDriver.capture_in_flight():
		push_error("GH#324: capture-hold ceiling (%d ms) expired with a capture still in flight -- a transient panel just retired mid-capture; the evidence race is OPEN for this shot" % ceiling_msec)


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
