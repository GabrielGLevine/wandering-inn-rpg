class_name WIFieldChips
extends CanvasLayer
## Field-mode HUD launcher chips (issue #109): three small tappable panels
## that open the pause menu / journal / inventory on a tap -- the mobile/
## mouse-only gap the issue's own playtest found (no keyboard means no way
## to reach Esc/J/I at all). Settings needs no chip of its own: pause's
## "Settings" row is already clickable (issue #84's `_on_menu_gui_input`),
## reachable via the pause chip below.
##
## SHARED, NOT DUPLICATED: each chip calls the target panel's own
## `toggle_open()` -- a small public entry point added to journal.gd/
## inventory.gd/pause_menu.gd this same task, wrapping the EXACT open/close/
## `_can_open()` gate branch each panel's `_unhandled_input` already runs for
## its keyboard toggle (journal/inventory/cancel). This file never reaches
## into any panel's internals or duplicates that gate logic -- a tap and a
## keypress are one dispatch path, not two.
##
## CHROME: reuses the #106 confirm-chip idiom verbatim (combat_hud.gd's
## `_confirm_chip` -- `UIChrome.make_texture_panel` + `MOUSE_FILTER_STOP` +
## a `gui_input` handler + a read-only `Rect2` accessor for QA's
## `click_field_chip` step). Each chip consumes ONLY its own rect
## (MOUSE_FILTER_STOP on the chip itself; the host Control and this layer's
## other Controls stay at the IGNORE default) -- never a full-screen Control
## eating world clicks underneath.
##
## VISIBILITY: the WHOLE layer hides during combat, an open dialogue, or a
## pending consolidation offer -- no exceptions (matches field_hotbar.gd's
## own blanket combat/dialogue hide). Per-chip, on top of that: the three
## panels are mutually exclusive (each panel's own `_can_open()` already
## refuses while either of the other two is open), so at most one is ever
## open at a time -- that ONE panel's own chip STAYS visible/tappable (a
## second tap closes it via the same `toggle_open()` -- the ONLY close
## affordance a keyboard-less mobile session has, since there is no Esc/J/I
## to fall back on), while the other two chips hide (tapping them would
## just no-op through that panel's own mutual-exclusion refusal).
## `_apply_visibility()` is a pure read of live sim/ref state (no
## locally-cached open/closed flags to fall out of sync, unlike
## field_hotbar.gd's `_combat_hidden`/`_dialogue_open` bools) -- mirrors the
## exact gate shape pause_menu.gd/journal.gd/inventory.gd's own
## `_can_open()` methods already check, so this can never drift from what a
## tap would actually be allowed to do.

## Hit target >=36px tall (issue #106 mobile audit floor); wide enough for
## "Journal"/"Inventory" at the theme's default "Small" font without wrap.
const CHIP_SIZE := Vector2(84.0, 40.0)
const CHIP_GAP := 8.0
## Top-right stack -- clear of the field hotbar (bottom-center),
## message_layer's toast (bottom-right) and hint/dialogue bark (bottom-left)
## panels, and combat_hud.gd's OWN confirm chip (same corner, but the two
## never coexist -- this layer hides outright the instant combat starts).
const CHIP_RIGHT_MARGIN := 10.0
const CHIP_TOP_OFFSET := 10.0

## Set by main.gd right after all three panels are instantiated (the same
## post-construction cross-wiring idiom `_spawn_ui_layers` already uses for
## journal_ref/pause_menu_ref/inventory_ref between those three files).
var pause_menu_ref: Node = null
## Main-scene ref for `veil_modal_active()` -- defense-in-depth so chip
## visibility never relies on the veil's own higher-CanvasLayer ColorRect
## swallowing taps (the implicit cross-file layer-ordering invariant).
var main_ref: Node = null
var journal_ref: Node = null
var inventory_ref: Node = null

var _pause_chip: Control
var _journal_chip: Control
var _inventory_chip: Control


func _ready() -> void:
	var host := Control.new()
	UIChrome.apply_theme(host)
	UIChrome.full_rect(host)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	# Left-to-right on screen: Inventory, Journal, Pause (Pause nearest the
	# corner -- the common "hamburger in the corner" convention); slot 0 is
	# the RIGHTMOST chip, so building right-to-left keeps the offset math
	# below a single formula (`slot` counts outward from the corner).
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


## Read-only rect accessor (the `row_rect`/`confirm_chip_rect` idiom) for
## `qa/test_driver.gd`'s `click_field_chip` step. Empty `Rect2` for an
## unknown name, a hidden layer, or a chip somehow not built yet.
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
	match type:
		WIEvents.WORLD_READY, WIEvents.COMBAT_STARTED, WIEvents.UI_COMBAT_HIDDEN, \
		WIEvents.DIALOGUE_STARTED, WIEvents.DIALOGUE_ENDED, \
		WIEvents.UI_PAUSE_SHOWN, WIEvents.UI_PAUSE_HIDDEN, \
		WIEvents.UI_JOURNAL_SHOWN, WIEvents.UI_JOURNAL_HIDDEN, \
		WIEvents.UI_INVENTORY_SHOWN, WIEvents.UI_INVENTORY_HIDDEN, \
		WIEvents.CONSOLIDATION_OFFERED, WIEvents.UI_CONSOLIDATION_PROMPT_HIDDEN:
			_apply_visibility()


## Single write site for `visible` -- a pure derivation of live sim/ref
## state (see the class doc comment), never a cached flag that could go
## stale. Mirrors pause_menu.gd/journal.gd/inventory.gd's own `_can_open()`
## gate shape, plus "is THIS panel already open" for all three (the part
## specific to this row of launchers).
func _apply_visibility() -> void:
	# HARD block: combat, an open dialogue, or a pending consolidation offer
	# -- no exceptions, hides the whole layer (matches field_hotbar.gd's
	# blanket combat/dialogue hide).
	var hard_blocked := Game.sim.combat != null or Game.sim.dialogue != null \
			or not Game.sim.pending_consolidation.is_empty() \
			or (main_ref != null and bool(main_ref.veil_modal_active()))
	visible = not hard_blocked
	if hard_blocked:
		return
	var pause_open := pause_menu_ref != null and bool(pause_menu_ref.get("open"))
	var journal_open := journal_ref != null and bool(journal_ref.get("open"))
	var inventory_open := inventory_ref != null and bool(inventory_ref.get("open"))
	# Per-chip: mutual exclusion means at most one of the three is ever open
	# at once. The OPEN one's own chip stays visible/tappable -- a second
	# tap is the ONLY close affordance a keyboard-less mobile session has
	# (no Esc/J/I) -- while the other two hide (tapping them would just
	# no-op via that panel's own `_can_open()` mutual-exclusion refusal).
	_pause_chip.visible = pause_open or not (journal_open or inventory_open)
	_journal_chip.visible = journal_open or not (pause_open or inventory_open)
	_inventory_chip.visible = inventory_open or not (pause_open or journal_open)
