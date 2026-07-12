extends CanvasLayer
## Pause menu — Resume / Save / Load / Load Autosave / Music / SFX /
## Quit to Title. Toggled by `cancel` (Esc) when the field is idle.
##
## Issue #78: "Save"/"Load" now open a SUB-PICKER (see `_enter_slot_picker`)
## listing `Game.MANUAL_SLOTS` (3 slots, "manual" first) with a metadata
## summary line each, instead of acting on the single "manual" slot
## directly -- ROWS/COMBAT_ROWS/their indices are UNCHANGED (append-only-or-
## sub-menu rule), only what pressing Confirm on "Save"/"Load" DOES changed.
## "Load Autosave" stays a single direct action (only one autosave slot
## exists, nothing to pick).
##
## Input arbitration (repo-wide precedence: combat > dialogue > pause >
## journal > inventory > world): pause only toggles/consumes input when
## no dialogue is open and BOTH the journal and the inventory are closed;
## during combat it opens ONLY from the HOTBAR resting mode (see
## `_can_open`/`combat_ref`) with the reduced COMBAT_ROWS set, whose one
## extra verb is Abandon-to-last-autosave — world.gd wires `journal_ref`/
## `inventory_ref` after creating all three components so this check does
## not need a scene-tree lookup; world.gd itself checks `pause_menu.open`
## before handling movement/interact.
##
## Reaching Main: this node is instantiated as a DIRECT CHILD of the
## `Main` node itself (`main.gd`'s `_spawn_ui_layers()` calls
## `add_child(_pause_menu)` on `self`), so `get_parent()` is Main — no
## scene-tree search needed. Main isn't preloaded here (that would create a
## preload cycle: main.gd already preloads this script) so the call is
## duck-typed via `has_method()`, mirroring main.gd's own
## `world.has_method("inject_ui_refs")` pattern for the same reason.

const PANEL_SIZE := Vector2(280.0, 300.0)
## "Music"/"SFX" double as `WIAudio` bus names, so `_row_text()` and
## `_adjust_volume_row()` can use the row key directly as the bus arg.
## "Settings" is APPENDED at the end (issue #77) -- never inserted earlier --
## so every existing index-based QA reference (mouse_loop.json's
## `click_pause_row row:1` = Resume, the "move down N" navigations in
## board_loop/consolidation_reload/save_migration/save_load_roundtrip) keeps
## the exact same target row. Issue #78: those same 4 scripts' Save/Load
## steps each gained ONE extra Confirm (selecting slot "manual", the
## picker's default cursor 0) since Confirm on "Save"/"Load" now opens the
## sub-picker instead of acting immediately -- the ROW index itself never moved.
const ROWS := ["Resume", "Save", "Load", "Load Autosave", "Music", "SFX", "Quit to Title", "Settings"]
## The reduced row set while a fight is live (combat_ref.is_resting() gates
## opening at all). No Save/Load rows: combat state is never serialized, so a
## mid-fight save would silently drop the fight — Abandon is the honest verb
## (returns to the last autosave, same slot the defeat path loads). No
## Settings row either -- deliberately unreachable mid-combat (keeps
## combat_abandon.json's canonical COMBAT_ROWS shape untouched).
const COMBAT_ROWS := ["Resume", "Abandon to Last Save", "Music", "SFX", "Quit to Title"]
const VOLUME_ROWS := ["Music", "SFX"]

const CONFIRM_PANEL_SIZE := Vector2(340.0, 158.0)
const CONFIRM_TEXT := "Unsaved progress since the\nlast autosave is lost. Quit?"
const ABANDON_CONFIRM_TEXT := "Abandon the fight? You return\nto your last autosave."
## Cursor defaults to "No" (index 0) on entry — both confirmed actions are
## destructive.
const CONFIRM_ROWS := ["No", "Yes"]

## Issue #78: the Save/Load slot-picker sub-panel. "Save"/"Load" (ROWS
## indices 1/2, UNCHANGED -- see the class doc comment's index-pin note)
## open this instead of acting directly; picking a row here is what
## actually saves/loads. "Back" is the mouse-clickable equivalent of Esc
## (the settings_panel.gd "Back" row precedent) -- every other UIChrome
## sub-panel with a Cancel affordance also offers a clickable row, not just
## a keyboard-only escape.
## Wide enough for the longest real summary line ("Slot N — <name> —
## <Class> LvNN — <Map>") at the theme's default 14px font without wrapping
## (Label rows below render with autowrap OFF, matching every other
## pause_menu row) -- verified against every shipped class/map id's
## title-cased length; re-check with a windowed screenshot if a
## dramatically longer id is ever added.
const SLOT_PICKER_PANEL_SIZE := Vector2(460.0, 210.0)
## Sane truncation budget (chars) for a rendered row -- a 16-char player-typed
## name (PC_NAME_MAX) plus the longest shipped map id ("Riverfarm Longhouse")
## can exceed the panel's real content width; `_truncate_row` below cuts at a
## word boundary, same shape as title_screen.gd's `_first_sentence` fallback.
## Deliberately generous (the common case -- short name/class/map -- never
## gets near it): a text-scale increase (WISettings, up to 130%) shrinks the
## real safety margin at a FIXED char budget, unlike this codebase's px-
## measured panels (message_layer.gd/combat_hud.gd) -- flagged as a
## follow-up to convert to a real Font.get_string_size measurement if a
## windowed check at 130% ever shows overflow.
const SLOT_ROW_CHAR_BUDGET := 50
const SLOT_PICKER_BACK := "Back"

## True while the pause panel is visible; world.gd and journal.gd gate on this.
var open := false

## Set by world.gd right after both components are instantiated.
var journal_ref: Node = null
## Set by world.gd/main.gd alongside journal_ref (three-way mutual
## exclusion -- see inventory.gd's file doc comment).
var inventory_ref: Node = null
## Set by main.gd (the combat screen instance). Gates in-combat opening to
## the HOTBAR resting mode (is_resting()) and owns the abandon teardown
## (abandon_combat()) -- the menu never touches combat internals itself.
var combat_ref: Node = null
## Set by world.gd's `inject_ui_refs` to `self` (a same-file self-ref, not a
## cross-script preload -- world.gd already owns this assignment, no new
## cycle). Lets `_can_open()` refuse to open while the field hotbar's Tab/pad
## cursor is armed (issue #58) -- this node sits LATER in Main's child order
## (see the file doc comment's arbitration note / `_can_open`'s combat
## comment for the general shape of that trap), so an armed Esc/cancel would
## otherwise open the pause menu INSTEAD of ever reaching world.gd's own
## cancel-disarm branch.
var world_ref: Node = null
## Set by main.gd alongside the other refs (issue #77) -- the shared
## settings_panel.gd instance, opened by the new "Settings" row.
var settings_ref: Node = null

var _root: Control
var _row_labels: Array[Label] = []
var _cursor := 0
var _confirm_label: Label

var _confirm_root: Control
var _confirm_option_labels: Array[Label] = []
var _confirming_quit := false
## Which destructive action the shared No/Yes panel is confirming:
## "quit" (title) or "abandon" (combat -> last autosave).
var _confirm_action := "quit"
var _confirm_cursor := 0

## Issue #78 slot-picker state. `_slot_mode` is "save" or "load" (set by
## `_enter_slot_picker`); `_slot_rows()` is `Game.MANUAL_SLOTS` + the
## trailing "Back" row, so `_slot_labels`/`_slot_cursor` always index the
## SAME list `_refresh_slots()` renders from.
var _picking_slot := false
var _slot_mode := "save"
var _slot_cursor := 0
var _slot_root: Control
var _slot_title_label: Label
var _slot_labels: Array[Label] = []


## The live row set: the reduced COMBAT_ROWS while a fight is up, the full
## set otherwise. Everything cursor/refresh/confirm reads goes through this
## so the two sets can never drift from the rendered labels.
func _active_rows() -> Array:
	return COMBAT_ROWS if Game.sim.combat != null else ROWS


func _ready() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y * 0.5, PANEL_SIZE.x * 0.5, PANEL_SIZE.y * 0.5)
	# STOP (mouse-filter audit, issue #57): see journal.gd's identical fix's
	# doc comment -- swallows a click on the open panel instead of leaking to
	# the world/board underneath. `.hide()`/`.show()` gate visibility.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.hide()
	add_child(_root)
	_root.add_child(UIChrome.make_patch(UIChrome.CARVED_PANEL))
	var menu_margin := MarginContainer.new()
	UIChrome.full_rect(menu_margin)
	UIChrome.add_margins(menu_margin, 30, 28, 30, 28)
	_root.add_child(menu_margin)
	var menu_stack := VBoxContainer.new()
	menu_stack.add_theme_constant_override("separation", 6)
	menu_margin.add_child(menu_stack)
	for i in ROWS.size():
		var row := UIChrome.make_label("", "Menu")
		row.custom_minimum_size = Vector2(220.0, 24.0)
		menu_stack.add_child(row)
		_row_labels.append(row)
	# Issue #84: ONE hover/click handler on the shared row container (mirrors
	# WIHotbar's per-bar-not-per-slot idiom via UIChrome.control_index_at),
	# not one filter per row -- a row Label stays default IGNORE. Hover moves
	# `_cursor` (the SAME field `_refresh()`'s "> " mark already reads, so
	# hover highlight and keyboard selection are ONE state, never a second
	# highlight system); a click sets `_cursor` then calls `_confirm()`, the
	# exact function Enter calls -- one dispatch path either way.
	menu_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_stack.gui_input.connect(_on_menu_gui_input)

	_confirm_root = Control.new()
	UIChrome.apply_theme(_confirm_root)
	_confirm_root.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_root.custom_minimum_size = CONFIRM_PANEL_SIZE
	_confirm_root.size = CONFIRM_PANEL_SIZE
	UIChrome.set_offsets(_confirm_root, -CONFIRM_PANEL_SIZE.x * 0.5, -CONFIRM_PANEL_SIZE.y * 0.5, CONFIRM_PANEL_SIZE.x * 0.5, CONFIRM_PANEL_SIZE.y * 0.5)
	# STOP (mouse-filter audit, issue #57): same fix as `_root` above.
	_confirm_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_root.hide()
	add_child(_confirm_root)
	_confirm_root.add_child(UIChrome.make_patch(UIChrome.PARCHMENT_PANEL))
	var confirm_margin := MarginContainer.new()
	UIChrome.full_rect(confirm_margin)
	UIChrome.add_margins(confirm_margin, 28, 26, 28, 24)
	_confirm_root.add_child(confirm_margin)
	var confirm_stack := VBoxContainer.new()
	confirm_stack.add_theme_constant_override("separation", 8)
	confirm_margin.add_child(confirm_stack)
	_confirm_label = UIChrome.make_label()
	_confirm_label.text = CONFIRM_TEXT
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_stack.add_child(_confirm_label)
	for i in CONFIRM_ROWS.size():
		var row := UIChrome.make_label("", "Menu")
		confirm_stack.add_child(row)
		_confirm_option_labels.append(row)
	# Issue #84: same one-handler-on-the-container idiom as `menu_stack` above,
	# for the No/Yes confirm rows (the abandon-combat confirm is explicitly
	# in scope per the issue's constraints).
	confirm_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_stack.gui_input.connect(_on_confirm_gui_input)

	# Issue #78: the Save/Load slot picker -- same chrome idiom as
	# `_confirm_root` above (a plain Label list on a carved panel), sized for
	# MANUAL_SLOTS.size() rows + the trailing "Back" row.
	_slot_root = Control.new()
	UIChrome.apply_theme(_slot_root)
	_slot_root.set_anchors_preset(Control.PRESET_CENTER)
	_slot_root.custom_minimum_size = SLOT_PICKER_PANEL_SIZE
	_slot_root.size = SLOT_PICKER_PANEL_SIZE
	UIChrome.set_offsets(_slot_root, -SLOT_PICKER_PANEL_SIZE.x * 0.5, -SLOT_PICKER_PANEL_SIZE.y * 0.5, SLOT_PICKER_PANEL_SIZE.x * 0.5, SLOT_PICKER_PANEL_SIZE.y * 0.5)
	_slot_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_slot_root.hide()
	add_child(_slot_root)
	_slot_root.add_child(UIChrome.make_patch(UIChrome.CARVED_PANEL))
	var slot_margin := MarginContainer.new()
	UIChrome.full_rect(slot_margin)
	UIChrome.add_margins(slot_margin, 24, 20, 24, 20)
	_slot_root.add_child(slot_margin)
	var slot_stack := VBoxContainer.new()
	slot_stack.add_theme_constant_override("separation", 6)
	slot_margin.add_child(slot_stack)
	_slot_title_label = UIChrome.make_label("", "Menu")
	slot_stack.add_child(_slot_title_label)
	var slot_spacer := Control.new()
	slot_spacer.custom_minimum_size = Vector2(0.0, 4.0)
	slot_stack.add_child(slot_spacer)
	for i in _slot_rows().size():
		var row := UIChrome.make_label("", "Menu")
		row.custom_minimum_size = Vector2(412.0, 22.0)
		slot_stack.add_child(row)
		_slot_labels.append(row)
	# Issue #84: same one-handler-on-the-container idiom as `menu_stack`/
	# `confirm_stack` above.
	slot_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	slot_stack.gui_input.connect(_on_slot_gui_input)


func _unhandled_input(event: InputEvent) -> void:
	if not open and not (event.is_action_pressed("cancel") and _can_open()):
		return
	# Captured before acting: "Load" in _confirm() can trigger a
	# game_loaded event, which Main._on_domain_event() handles via
	# Main.swap_to_world.call_deferred() (src/world/main.gd) -- deferred, so
	# this node isn't freed inside this callback, but grab the viewport
	# reference up front anyway so the post-action set_input_as_handled()
	# call doesn't depend on this node still being in the tree by the time
	# it runs. Same applies to "Quit to Title" -> Main.swap_to_title().
	var vp := get_viewport()
	if not open:
		_open()
		vp.set_input_as_handled()
		return
	if _confirming_quit:
		_handle_confirm_input(event, vp)
		return
	if _picking_slot:
		_handle_slot_input(event, vp)
		return
	if event.is_action_pressed("cancel"):
		_close()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		_cursor = wrapi(_cursor - 1, 0, _active_rows().size())
		_refresh()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_cursor = wrapi(_cursor + 1, 0, _active_rows().size())
		_refresh()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		_adjust_volume_row(-1)
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_adjust_volume_row(1)
		vp.set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_confirm()
		vp.set_input_as_handled()


func _handle_confirm_input(event: InputEvent, vp: Viewport) -> void:
	if event.is_action_pressed("cancel"):
		_exit_confirm_quit()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		_confirm_cursor = wrapi(_confirm_cursor + 1, 0, CONFIRM_ROWS.size())
		_refresh_confirm()
		vp.set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_select_confirm_choice()
		vp.set_input_as_handled()


## The confirm-panel's own "activate the cursored row" dispatch -- factored
## out of `_handle_confirm_input`'s keyboard `confirm` branch (issue #84) so
## `_on_confirm_gui_input`'s mouse click routes through this SAME function,
## never a parallel activation.
func _select_confirm_choice() -> void:
	var choice := String(CONFIRM_ROWS[_confirm_cursor])
	if choice == "Yes":
		var action := _confirm_action
		_close()
		if action == "abandon":
			if combat_ref != null and combat_ref.has_method("abandon_combat"):
				combat_ref.call("abandon_combat")
		else:
			_quit_to_title()
	else:
		_exit_confirm_quit()


## Issue #84: hover highlights a main-menu row (sets `_cursor`, same field
## `_refresh()`'s "> " mark reads -- one selection state, not a second
## highlight), a left-click activates it through `_confirm()`, the exact
## function Enter calls. No-op while the confirm sub-panel is up (that has
## its own handler below) or the panel isn't open (menu_stack has no rect to
## hit anyway once hidden, but `_active_rows()` would be meaningless mid-close).
func _on_menu_gui_input(event: InputEvent) -> void:
	if not open or _confirming_quit:
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_row_labels, (event as InputEventMouseMotion).position)
		if idx >= 0 and idx < _active_rows().size() and idx != _cursor:
			_cursor = idx
			_refresh()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(_row_labels, mb.position)
	if idx >= 0 and idx < _active_rows().size():
		_cursor = idx
		_confirm()


## Issue #84: the confirm sub-panel's own hover/click, mirroring
## `_on_menu_gui_input` -- hover sets `_confirm_cursor` (the same field
## `_refresh_confirm()`'s mark reads), click routes through
## `_select_confirm_choice()`, the SAME function Enter calls.
func _on_confirm_gui_input(event: InputEvent) -> void:
	if not _confirming_quit:
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_confirm_option_labels, (event as InputEventMouseMotion).position)
		if idx >= 0 and idx != _confirm_cursor:
			_confirm_cursor = idx
			_refresh_confirm()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(_confirm_option_labels, mb.position)
	if idx >= 0:
		_confirm_cursor = idx
		_select_confirm_choice()


## Read-only rect accessor (issue #84, `WIHotbar.slot_rect`'s established
## pattern) -- the on-screen rect of main-menu row `i` as of the last
## `_refresh()`, for QA's `click_pause_row` step. Empty Rect2 when the panel
## is closed, the row is out of range, or the row isn't part of the CURRENT
## active set (`_active_rows()` -- COMBAT_ROWS mid-fight has fewer rows than
## the full label array; a label beyond that count is hidden by `_refresh()`).
func row_rect(i: int) -> Rect2:
	if not open or i < 0 or i >= _row_labels.size():
		return Rect2()
	var label := _row_labels[i]
	if label == null or not label.visible:
		return Rect2()
	return Rect2(label.global_position, label.size)


func _can_open() -> bool:
	if Game.sim.dialogue != null:
		return false
	# Mid-combat opening is allowed ONLY in the HOTBAR resting mode (your
	# turn, no targeting/dash/banner sub-mode in flight) -- combat_ref owns
	# that answer. Combat's own _unhandled_input never consumes `cancel` in
	# HOTBAR mode, and this node sits LATER in Main's child order, so it
	# sees the un-consumed Esc first on the way back.
	if Game.sim.combat != null:
		if combat_ref == null or not combat_ref.has_method("is_resting") or not bool(combat_ref.call("is_resting")):
			return false
	if not Game.sim.pending_consolidation.is_empty():
		return false
	if journal_ref != null and bool(journal_ref.get("open")):
		return false
	if inventory_ref != null and bool(inventory_ref.get("open")):
		return false
	# See `world_ref`'s own doc comment -- an armed field-hotbar cursor wants
	# THIS cancel press for itself (disarm), not a pause-menu open.
	if world_ref != null and world_ref.has_method("field_slot_armed") and bool(world_ref.call("field_slot_armed")):
		return false
	return true


func _open() -> void:
	open = true
	_cursor = 0
	_confirming_quit = false
	_picking_slot = false
	_confirm_root.hide()
	_slot_root.hide()
	_refresh()
	_root.show()
	ObservableBus.emit_domain_event(WIEvents.UI_PAUSE_SHOWN, {})


func _close() -> void:
	open = false
	_confirming_quit = false
	_picking_slot = false
	_root.hide()
	_confirm_root.hide()
	_slot_root.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_PAUSE_HIDDEN, {})


## settings_panel.gd's `on_close` callback (issue #77) -- re-shows this
## panel's own root once Settings closes back out. `open`/`_cursor` were
## never touched while Settings was up, so the row list re-appears exactly
## where the player left it (no `_open()` re-call -- that would reset the
## cursor to 0 and re-fire ui_pause_shown, which this is NOT: it's a resume,
## not a fresh open).
func _reopen_after_settings() -> void:
	if open:
		_root.show()


func _enter_confirm(action: String) -> void:
	_confirming_quit = true
	_confirm_action = action
	_confirm_label.text = ABANDON_CONFIRM_TEXT if action == "abandon" else CONFIRM_TEXT
	_confirm_cursor = 0
	_root.hide()
	_confirm_root.show()
	_refresh_confirm()


func _exit_confirm_quit() -> void:
	_confirming_quit = false
	_confirm_root.hide()
	_root.show()
	_refresh()


## Issue #78: opens the Save/Load slot picker. Cursor DEFAULTS TO 0 (slot
## "manual", the pre-existing single-slot id) so every pre-existing "Save"/
## "Load" flow (a fixture_save's default slot, every hand-written
## assert_save_exists) reaches the SAME slot as before this task with
## exactly ONE extra Confirm press to land on the now-explicit row. `mode`
## is "save" or "load" -- purely presentational (the title text + which
## Game.* call `_select_slot` makes), never gates row selectability: an
## empty slot is still pickable in LOAD mode and just fails gracefully with
## the pre-existing "Could not load save." toast, the SAME tolerant-failure
## contract a missing "manual"/"auto" file already had.
func _enter_slot_picker(mode: String) -> void:
	_slot_mode = mode
	_picking_slot = true
	_slot_cursor = 0
	_slot_title_label.text = "Save to which slot?" if mode == "save" else "Load which slot?"
	_root.hide()
	_refresh_slots()
	_slot_root.show()
	ObservableBus.emit_domain_event(WIEvents.UI_SLOT_PICKER_RENDERED, {"mode": mode, "slots": _slot_summaries()})


## Esc/cancel or the "Back" row -- returns to the main pause list WITHOUT
## saving/loading anything (`open` stays true throughout, the Settings-panel
## "stays logically open" precedent).
func _exit_slot_picker() -> void:
	_picking_slot = false
	_slot_root.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_SLOT_PICKER_HIDDEN, {})
	_root.show()
	_refresh()


func _handle_slot_input(event: InputEvent, vp: Viewport) -> void:
	if event.is_action_pressed("cancel"):
		_exit_slot_picker()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		_slot_cursor = wrapi(_slot_cursor - 1, 0, _slot_rows().size())
		_refresh_slots()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_slot_cursor = wrapi(_slot_cursor + 1, 0, _slot_rows().size())
		_refresh_slots()
		vp.set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_select_slot()
		vp.set_input_as_handled()


## The picker's row list: MANUAL_SLOTS in order, then the trailing "Back"
## row -- the SAME order `_ready()` built `_slot_labels` in, so index i
## always means the same thing everywhere in this file.
func _slot_rows() -> Array[String]:
	var rows: Array[String] = []
	rows.append_array(Game.MANUAL_SLOTS)
	rows.append(SLOT_PICKER_BACK)
	return rows


## The cursored row's activation -- "Back" behaves exactly like Esc; any
## other row saves (mode "save") or loads (mode "load") that slot, then
## closes the WHOLE pause menu (matching the old direct Save/Load's own
## close-then-act behavior, not just the sub-picker).
func _select_slot() -> void:
	var rows := _slot_rows()
	var choice := String(rows[_slot_cursor])
	if choice == SLOT_PICKER_BACK:
		_exit_slot_picker()
		return
	var mode := _slot_mode
	ObservableBus.emit_domain_event(WIEvents.UI_SLOT_PICKER_HIDDEN, {})
	_close()
	if mode == "save":
		Game.save_manual(choice)
	else:
		if not Game.load_slot(choice):
			ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Could not load save."})


func _refresh_slots() -> void:
	var rows := _slot_rows()
	for i in rows.size():
		var label := _slot_labels[i] as Label
		var mark := "> " if i == _slot_cursor else "  "
		label.text = mark + _slot_row_text(String(rows[i]), i)


func _slot_row_text(row_id: String, i: int) -> String:
	if row_id == SLOT_PICKER_BACK:
		return SLOT_PICKER_BACK
	var meta := Game.slot_metadata(row_id)
	var summary := "Empty" if meta.is_empty() else _format_slot_summary(meta)
	return _truncate_row("Slot %d — %s" % [i + 1, summary])


## Word-boundary ellipsis truncation (D2-7 #6: "cut words, never widen UI")
## for a player-typed name (up to PC_NAME_MAX=16) plus the longest shipped
## map id could exceed the picker's real row width -- this is the ON-SCREEN
## cut only, mirroring the ambient-bark/dialogue-panel precedent elsewhere
## (message_layer.gd): `UI_SLOT_PICKER_RENDERED`'s own `summary` payload
## (built by `_format_slot_summary` directly, never through this function)
## always carries the FULL untruncated line. Same fallback shape as
## title_screen.gd's `_first_sentence` budget cut, sized for this picker's
## real content width (SLOT_PICKER_PANEL_SIZE minus its own margins).
func _truncate_row(line: String) -> String:
	if line.length() <= SLOT_ROW_CHAR_BUDGET:
		return line
	var budgeted := line.substr(0, SLOT_ROW_CHAR_BUDGET)
	var last_space := budgeted.rfind(" ")
	if last_space > 0:
		budgeted = budgeted.substr(0, last_space)
	return budgeted.strip_edges() + "…"


## "<name> — <TopClass> LvN — <Map>" (class/map segments omitted when a save
## predates any class / carries no map, though every real save always has a
## map). Names/levels are exactly what the journal already shows (product
## rule: race/class/level/skills/HP/MP/gear are player-visible, raw stats
## never are -- this line carries none).
func _format_slot_summary(meta: Dictionary) -> String:
	var parts: Array[String] = [String(meta.get("pc_name", "Traveler"))]
	var top_class := String(meta.get("top_class", ""))
	if not top_class.is_empty():
		parts.append("%s Lv%d" % [_title_case(top_class), int(meta.get("top_level", 0))])
	var map_id := String(meta.get("map", ""))
	if not map_id.is_empty():
		parts.append(_title_case(map_id))
	return " — ".join(parts)


## Underscore-id -> "Title Case With Spaces" (matches every class id's real
## classes.json display_name AND title_screen.gd's fixture-name display
## convention exactly -- verified against every shipped class id).
func _title_case(id: String) -> String:
	var words := id.split("_")
	for i in words.size():
		var w: String = words[i]
		if not w.is_empty():
			words[i] = w[0].to_upper() + w.substr(1)
	return " ".join(words)


## The picker's slots payload for UI_SLOT_PICKER_RENDERED -- one entry per
## MANUAL_SLOTS id (never includes the "Back" row, which isn't a slot).
func _slot_summaries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: String in Game.MANUAL_SLOTS:
		var meta := Game.slot_metadata(slot)
		out.append({"slot": slot, "exists": not meta.is_empty(), "summary": "Empty" if meta.is_empty() else _format_slot_summary(meta)})
	return out


## Issue #84: hover/click over the slot picker's rows, mirroring
## `_on_menu_gui_input`/`_on_confirm_gui_input` -- hover sets `_slot_cursor`
## (the SAME field `_refresh_slots()`'s mark reads), a click routes through
## `_select_slot()`, the exact function Enter calls.
func _on_slot_gui_input(event: InputEvent) -> void:
	if not _picking_slot:
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_slot_labels, (event as InputEventMouseMotion).position)
		if idx >= 0 and idx != _slot_cursor:
			_slot_cursor = idx
			_refresh_slots()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(_slot_labels, mb.position)
	if idx >= 0:
		_slot_cursor = idx
		_select_slot()


## Read-only rect accessor (the `row_rect`/`slot_row_rect` idiom), for QA's
## `click_pause_slot_row` step. Empty Rect2 when the picker isn't open or
## the row is out of range.
func slot_row_rect(i: int) -> Rect2:
	if not _picking_slot or i < 0 or i >= _slot_labels.size():
		return Rect2()
	var label := _slot_labels[i]
	if label == null or not label.visible:
		return Rect2()
	return Rect2(label.global_position, label.size)


## Duck-typed reach to Main — see the class doc comment above for why this
## isn't a typed reference. No autosave here by design (spec: explicit
## testing surface) — Main.swap_to_title() only tears down/rebuilds the UI
## and world layers, it never touches save files. Deferred for the same
## reason Main._on_domain_event() defers swap_to_world() on game_loaded/
## game_reset (see the comment in _unhandled_input): this call happens from
## inside this node's own input-handling stack, and swap_to_title() would
## otherwise remove/queue_free this node (and its CanvasLayer siblings)
## before that stack unwinds.
func _quit_to_title() -> void:
	var main := get_parent()
	if main != null and main.has_method("swap_to_title"):
		main.call_deferred("swap_to_title")


func _refresh() -> void:
	var rows := _active_rows()
	for i in _row_labels.size():
		var label := _row_labels[i] as Label
		label.visible = i < rows.size()
		if i < rows.size():
			var mark := "> " if i == _cursor else "  "
			label.text = mark + _row_text(i)


func _row_text(i: int) -> String:
	var key := String(_active_rows()[i])
	if VOLUME_ROWS.has(key):
		return "%s volume: %d" % [key, int(WIAudio.get_bus_volume(key))]
	return key


func _refresh_confirm() -> void:
	for i in CONFIRM_ROWS.size():
		var mark := "> " if i == _confirm_cursor else "  "
		(_confirm_option_labels[i] as Label).text = mark + String(CONFIRM_ROWS[i])


## Only Music/SFX rows respond; harmless no-op otherwise.
func _adjust_volume_row(delta: int) -> void:
	var key := String(_active_rows()[_cursor])
	if not VOLUME_ROWS.has(key):
		return
	WIAudio.set_bus_volume(key, WIAudio.get_bus_volume(key) + float(delta))
	_refresh()


func _confirm() -> void:
	match String(_active_rows()[_cursor]):
		"Resume":
			_close()
		"Abandon to Last Save":
			_enter_confirm("abandon")
		"Save":
			_enter_slot_picker("save")
		"Load":
			_enter_slot_picker("load")
		"Load Autosave":
			_close()
			if not Game.load_slot("auto"):
				ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Could not load save."})
		"Quit to Title":
			_enter_confirm("quit")
		"Settings":
			# Hides this panel (stays logically `open` throughout -- see
			# `_reopen_after_settings`) and hands settings_panel.gd a callback
			# to re-show it on Back/Cancel. Never reachable mid-combat
			# (COMBAT_ROWS has no "Settings" row).
			if settings_ref != null:
				_root.hide()
				settings_ref.call("open", Callable(self, "_reopen_after_settings"))
