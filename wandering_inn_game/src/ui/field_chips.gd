class_name WIFieldChips
extends CanvasLayer

const CHIP_SIZE := Vector2(84.0, 40.0)
const CHIP_GAP := 8.0
const CHIP_RIGHT_MARGIN := 10.0
const CHIP_TOP_OFFSET := 10.0

var pause_menu_ref: Node = null
## Main-scene ref for `veil_modal_active()` -- defense-in-depth so chip
## visibility never relies on the veil's own higher-CanvasLayer ColorRect
## swallowing taps (the implicit cross-file layer-ordering invariant).
var main_ref: Node = null
var combat_ref: Node = null
var journal_ref: Node = null
var inventory_ref: Node = null

var _pause_chip: Control
var _journal_chip: Control
var _inventory_chip: Control
## THE STALE-GATE TRAP (v0.17 close finding: chips absent in 5/30 captures with
## no modal on screen). `WIGame.dialogue` is ASSIGNED AFTER DIALOGUE_STARTED is
## emitted and CLEARED AFTER DIALOGUE_ENDED, so a listener reading the field
## from inside either handler reads it INVERTED: the chips stayed lit through
## the whole conversation and then went dark when it closed, and stayed dark
## until some unrelated listened event re-derived -- which is exactly the
## report's "chip-region max 53, then 255 after a pause cycle". Tracked off the
## event PAIR instead, the `_dialogue_open`/`_conversation_open` idiom
## field_hotbar.gd and message_layer.gd already carry for this same reason.
var _dialogue_open := false


func _ready() -> void:
	var host := Control.new()
	UIChrome.apply_theme(host)
	UIChrome.full_rect(host)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	_inventory_chip = _make_chip(host, "Inventory", 2)
	_journal_chip = _make_chip(host, "Journal", 1)
	_pause_chip = _make_chip(host, "Pause", 0)
	_inventory_chip.gui_input.connect(_on_inventory_chip_gui_input)
	_journal_chip.gui_input.connect(_on_journal_chip_gui_input)
	_pause_chip.gui_input.connect(_on_pause_chip_gui_input)
	ObservableBus.domain_event.connect(_on_domain_event)
	_apply_visibility()


func _make_chip(host: Control, label_text: String, slot: int) -> Control:
	var chip := UIChrome.make_texture_panel(UIChrome.BLUE_BUTTON)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.custom_minimum_size = CHIP_SIZE
	chip.size = CHIP_SIZE
	var right := -(CHIP_RIGHT_MARGIN + float(slot) * (CHIP_SIZE.x + CHIP_GAP))
	var left := right - CHIP_SIZE.x
	UIChrome.set_offsets(chip, left, CHIP_TOP_OFFSET, right, CHIP_TOP_OFFSET + CHIP_SIZE.y)
	var lbl := UIChrome.make_label(label_text, "Small")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	chip.add_child(lbl)
	host.add_child(chip)
	return chip


func _on_pause_chip_gui_input(event: InputEvent) -> void:
	if not _is_left_click(event):
		return
	if pause_menu_ref != null and pause_menu_ref.has_method("toggle_open"):
		pause_menu_ref.call("toggle_open")
		# review M3 self-heal: if the toggle was refused (e.g. a stale chip
		# during a non-resting combat mode no event re-derived), re-derive
		# now so the chip never stays a dead button past one tap.
		_apply_visibility()


func _on_journal_chip_gui_input(event: InputEvent) -> void:
	if not _is_left_click(event):
		return
	if journal_ref != null and journal_ref.has_method("toggle_open"):
		journal_ref.call("toggle_open")


func _on_inventory_chip_gui_input(event: InputEvent) -> void:
	if not _is_left_click(event):
		return
	if inventory_ref != null and inventory_ref.has_method("toggle_open"):
		inventory_ref.call("toggle_open")


static func _is_left_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	return mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed


func chip_rect(chip_name: String) -> Rect2:
	if not visible:
		return Rect2()
	var chip: Control = null
	match chip_name:
		"pause":
			chip = _pause_chip
		"journal":
			chip = _journal_chip
		"inventory":
			chip = _inventory_chip
	if chip == null or not chip.visible:
		return Rect2()
	return Rect2(chip.global_position, chip.size)


func _on_domain_event(type: String, _payload: Dictionary) -> void:
	# Order matters: latch the pair BEFORE the re-derive below reads it.
	match type:
		WIEvents.DIALOGUE_STARTED:
			_dialogue_open = true
		WIEvents.DIALOGUE_ENDED, WIEvents.WORLD_READY, WIEvents.GAME_LOADED:
			_dialogue_open = false
	match type:
		WIEvents.WORLD_READY, WIEvents.COMBAT_STARTED, WIEvents.UI_COMBAT_HIDDEN, \
		WIEvents.TURN_STARTED, WIEvents.COMBAT_RESOLVED, WIEvents.COMBAT_FINISHED, \
		WIEvents.UI_HOTBAR_RENDERED, WIEvents.UI_AI_PLAYBACK_DONE, \
		WIEvents.DIALOGUE_STARTED, WIEvents.DIALOGUE_ENDED, \
		WIEvents.UI_PAUSE_SHOWN, WIEvents.UI_PAUSE_HIDDEN, \
		WIEvents.UI_JOURNAL_SHOWN, WIEvents.UI_JOURNAL_HIDDEN, \
		WIEvents.UI_INVENTORY_SHOWN, WIEvents.UI_INVENTORY_HIDDEN, \
		WIEvents.CONSOLIDATION_OFFERED, WIEvents.UI_CONSOLIDATION_PROMPT_HIDDEN:
			_apply_visibility()


func _apply_visibility() -> void:
	# a3 #215: while combat is RESTING (the player's own turn, Mode.HOTBAR)
	# the Pause chip stays reachable — a touch player could otherwise never
	# open the combat pause (keyboard cancel was the only route). Only the
	# pause chip shows; journal/inventory stay combat-blocked.
	var combat_resting := Game.sim.combat != null and combat_ref != null and bool(combat_ref.is_resting())
	var hard_blocked := (Game.sim.combat != null and not combat_resting) or _dialogue_open \
			or not Game.sim.pending_consolidation.is_empty() \
			or (main_ref != null and bool(main_ref.veil_modal_active()))
	visible = not hard_blocked
	if hard_blocked:
		return
	if combat_resting:
		# The chip can go stale-VISIBLE when the player leaves HOTBAR without a
		# chips-listened event (into targeting/dash) — no event re-derives to
		# hide it. That is caught by the self-heal in _on_pause_chip_tapped:
		# a tap while non-resting is refused by pause_menu and immediately
		# re-derives, so the chip never survives as a dead button past one tap
		# (review M3). We deliberately do NOT listen on UI_TARGETING_SHOWN —
		# hiding on targeting-open leaves no event to re-show after the attack
		# resolves (attacking starts no new turn), which would kill the chip
		# for the rest of that turn.
		_pause_chip.visible = true
		_journal_chip.visible = false
		_inventory_chip.visible = false
		return
	var pause_open := pause_menu_ref != null and bool(pause_menu_ref.get("open"))
	var journal_open := journal_ref != null and bool(journal_ref.get("open"))
	var inventory_open := inventory_ref != null and bool(inventory_ref.get("open"))
	_pause_chip.visible = pause_open or not (journal_open or inventory_open)
	_journal_chip.visible = journal_open or not (pause_open or inventory_open)
	_inventory_chip.visible = inventory_open or not (pause_open or journal_open)
