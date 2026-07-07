extends CanvasLayer
## Inventory panel — carried items + the two equip slots (weapon/armor),
## M7 Task E4. Toggled by the `inventory` action (`I`).
##
## Input arbitration (repo-wide precedence: combat > dialogue > pause >
## journal > inventory > world): inventory only opens when combat is
## inactive, no dialogue is open, no consolidation offer is pending, and
## BOTH the pause menu and the journal are closed (mirrors journal.gd's
## `_can_open` against pause_menu_ref, extended with a matching check
## against journal_ref). world.gd wires `pause_menu_ref`/`journal_ref` after
## creating all three components, same as the existing journal<->pause
## pair, so no scene-tree lookup is needed; world.gd itself gates
## movement/interact on `inventory.open`, and journal.gd/pause_menu.gd are
## each extended with the matching `inventory_ref`/`open` check so all three
## field panels stay mutually exclusive.
##
## List grammar: arrows navigate the carried list (dialogue_panel.gd's
## cursor/rebuild-rows pattern -- "> " mark, wrapi wraparound), Enter
## equips the selected item into its own kind's slot, or unequips it if it
## IS the item already equipped there. Game.sim.equip/unequip do the kind/
## possession validation. **M-GEAR Task G3 update:** a plain carryable item
## of an unequippable kind (tools: field_whetstone/fishers_handline) gets its
## own neutral toast here (Game.sim.equip() would silently refuse with no
## message of its own); every other equip()/unequip() false return is either
## a real, already-self-toasting refusal from WIGame (G1's two accessory
## refusals: slot-full, over-capacity -- mirrored into this panel's own
## `_status_label` too, since the toast layer draws BEHIND this panel, see
## below) or prevented entirely by `_equipped_slot_for` routing an
## already-equipped item to unequip() instead of a duplicate equip() call.
##
## Layer 10 -- same reasoning as journal.gd's file doc comment: WIWorldLabels
## is created lazily by world.gd AFTER Main._spawn_ui_layers() adds this
## panel, so an explicit higher layer is required to paint over world-space
## name labels regardless of add order.

const PANEL_SIZE := Vector2(640.0, 560.0)

## True while the inventory panel is visible; world.gd/journal.gd/
## pause_menu.gd gate on this.
var open := false

## Set by world.gd right after all three field-panel components are
## instantiated.
var pause_menu_ref: Node = null
var journal_ref: Node = null

var _root: Control
var _title_label: Label
var _gold_label: Label
var _weapon_label: Label
var _armor_label: Label
## M-GEAR Task G3: one row per accessory slot (index 0/1/2 -> accessory_1/2/3),
## same styling/precedent as the weapon/armor rows above.
var _accessory_labels: Array[Label] = []
## M-GEAR Task G3 refusal surfacing: mirrors the most recent TOAST while this
## panel is open (see `_on_domain_event`). Needed because the toast layer
## (message_layer.gd, default CanvasLayer `layer` 1) draws BEHIND this panel's
## `layer = 10` -- a toast fired while the panel is open partially or fully
## renders under the opaque parchment (traced empirically, see the G3 report),
## so a capacity/slot-full equip refusal needs its own in-panel copy to be
## reliably legible to the player.
var _status_label: Label
## M-GEAR Task G3: stored so `_rebuild_items` can scroll the cursor row into
## view -- the ScrollContainer's own `mouse_filter` is IGNORE (no wheel input
## wired) and there is no keyboard-scroll binding either, so without this the
## tail of a long carried list (up to 19 items today) is logically selectable
## (the cursor still moves) but never actually visible.
var _scroll: ScrollContainer
var _items_box: VBoxContainer
var _item_ids: Array[String] = []
var _cursor := 0


func _ready() -> void:
	# See the file doc comment: must outrank WIWorldLabels regardless of
	# scene-tree add order.
	layer = 10
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y * 0.5, PANEL_SIZE.x * 0.5, PANEL_SIZE.y * 0.5)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.hide()
	add_child(_root)

	_root.add_child(UIChrome.make_patch(UIChrome.PARCHMENT_PANEL))

	var content := MarginContainer.new()
	UIChrome.full_rect(content)
	UIChrome.add_margins(content, 34, 36, 34, 34)
	_root.add_child(content)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	content.add_child(stack)

	var ribbon := Control.new()
	ribbon.custom_minimum_size = Vector2(220.0, 42.0)
	ribbon.add_child(UIChrome.make_horizontal_patch(UIChrome.BLUE_RIBBON, UIChrome.RIBBON_PATCH_MARGIN_X, UIChrome.RIBBON_PATCH_MARGIN_Y))
	stack.add_child(ribbon)
	_title_label = UIChrome.make_label("", "Header")
	_title_label.text = "Inventory"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIChrome.full_rect(_title_label)
	ribbon.add_child(_title_label)

	# Diegetic coin line (Economy v1 D3): the panel header, NOT an always-on
	# HUD (Global Constraint: gold shows in toasts + this panel only). Default
	# dark-on-parchment Label, same styling reasoning as the slot rows below.
	# "Gold: N" is literal text (no BBCode), so no `_bb_escape` is needed.
	_gold_label = UIChrome.make_label("")
	stack.add_child(_gold_label)

	# Two slot rows, pinned top (spec §3). Default Label styling (dark brown
	# on parchment -- journal.gd's proven body convention), NOT the "Menu"
	# variation: Menu's light-tan/outlined styling is designed for
	# pause_menu's DARK carved panel and reads nearly background-flat on
	# this parchment, inverting the reading hierarchy (E4 review finding).
	_weapon_label = UIChrome.make_label("")
	stack.add_child(_weapon_label)
	_armor_label = UIChrome.make_label("")
	stack.add_child(_armor_label)
	# M-GEAR Task G3: three accessory rows, same default dark-on-parchment
	# styling as weapon/armor above (E4 review finding still applies -- "Menu"
	# reads background-flat on this panel).
	for i in 3:
		var accessory_label := UIChrome.make_label("")
		stack.add_child(accessory_label)
		_accessory_labels.append(accessory_label)

	# M-GEAR Task G3: in-panel refusal echo (see the var's doc comment above).
	# Empty by default -- an empty Label adds no visible gap, same convention
	# as the lore-slot reasoning below.
	_status_label = UIChrome.make_label("")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_status_label)

	# Carried list below, in a ScrollContainer as the overflow safety net --
	# same idiom as journal.gd's RichTextLabel (scroll_active=true) rather
	# than the combat-feed/dialogue-panel wrapped-line eviction: item count
	# started at the spec's 8-item catalog (no stacking) and has since grown
	# to a 19-item full catalog (M-GEAR G2) -- each row's prose still wraps
	# via AUTOWRAP_WORD_SMART, never truncates, and `_rebuild_items` below
	# scrolls the cursor row into view every rebuild so the safety net stays
	# genuinely reachable by keyboard, not just non-clipping.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_scroll)
	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 4)
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_items_box)

	# Live coin-line refresh (Economy v1 D3): the same domain_event idiom
	# field_hotbar/dialogue_panel use -- if the panel is open when gold
	# changes, re-render the line (and re-confirm) rather than only on open.
	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if not open:
		return
	if type == WIEvents.GOLD_CHANGED:
		_refresh_gold()
		# Re-confirm the drawn state (bus convention), carrying the live total.
		_emit_shown()
	elif type == WIEvents.ITEM_EQUIPPED or type == WIEvents.ITEM_UNEQUIPPED:
		# M-GEAR Task G3: equip/unequip changes the slot rows AND the
		# Resonance header (neither rides on GOLD_CHANGED) -- same
		# re-confirm-on-relevant-domain-event idiom as the gold case above,
		# so a QA script can assert the post-equip resonance total without
		# having to close/reopen the panel.
		_refresh_slots()
		_emit_shown()
	elif type == WIEvents.TOAST:
		# M-GEAR Task G3 refusal surfacing: see `_status_label`'s doc comment
		# above -- this panel draws OVER the toast layer, so a refusal toast
		# fired while the panel is open (the only toast source reachable
		# while it is, since world input is gated shut) needs its own visible
		# copy in here.
		_status_label.text = String(payload.get("text", ""))


## M-GEAR Task G3: the `ui_inventory_shown` re-confirm payload, shared by
## `_open()` and the domain-event re-renders above so the two never drift.
func _emit_shown() -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_INVENTORY_SHOWN, {
		"items": _item_ids.size(),
		"gold": Game.sim.gold,
		"item_effect_lines": _rendered_effect_lines(),
		"resonance": {"used": Game.sim.resonance_used(), "capacity": Game.sim.resonance_capacity},
	})


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		if not event.is_action_pressed("inventory"):
			return
		if not _can_open():
			return
		_open()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("cancel"):
		_close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		_move_cursor(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_move_cursor(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_confirm()
		get_viewport().set_input_as_handled()


func _can_open() -> bool:
	if Game.sim.combat != null or Game.sim.dialogue != null:
		return false
	if not Game.sim.pending_consolidation.is_empty():
		return false
	if pause_menu_ref != null and bool(pause_menu_ref.get("open")):
		return false
	if journal_ref != null and bool(journal_ref.get("open")):
		return false
	return true


func _open() -> void:
	open = true
	_cursor = 0
	_refresh()
	_root.show()
	_emit_shown()


func _close() -> void:
	open = false
	_root.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_INVENTORY_HIDDEN, {})


func _move_cursor(delta: int) -> void:
	if _item_ids.is_empty():
		return
	_cursor = wrapi(_cursor + delta, 0, _item_ids.size())
	# GF Minor 1: a refusal echo belongs to the selection it refused --
	# clear it on navigation so it never lingers over a different item.
	_status_label.text = ""
	_rebuild_items()


## M-GEAR Task G3: returns the slot name `item_id` currently occupies
## ("weapon", "armor", or one of the three accessory slots), or "" if it
## isn't equipped anywhere. `Game.sim.equipped` keys accessories by their
## REAL slot name (`accessory_1`/`_2`/`_3`), never the generic "accessory"
## kind -- a plain `equipped.get(kind, "")` lookup (fine for weapon/armor,
## where kind IS the slot name) silently misses every equipped accessory.
## This was a real pre-G3 bug: re-confirming an already-equipped accessory
## called `equip()` again instead of `unequip()`, which G1's own duplicate-
## slot guard then silently refused (no toast) -- so the panel's "toggle
## equip/unequip on confirm" grammar (spec §3) never actually worked for
## accessories until this fix.
func _equipped_slot_for(item_id: String, kind: String) -> String:
	if kind == "accessory":
		for slot_name: String in ["accessory_1", "accessory_2", "accessory_3"]:
			if String(Game.sim.equipped.get(slot_name, "")) == item_id:
				return slot_name
		return ""
	if String(Game.sim.equipped.get(kind, "")) == item_id:
		return kind
	return ""


## Equips the selected item into its own kind's slot, or unequips it if it
## IS the item already equipped in that slot (spec §3 journal grammar).
func _confirm() -> void:
	if _item_ids.is_empty():
		return
	var item_id := String(_item_ids[_cursor])
	var rec: Dictionary = Game.sim.item(item_id)
	var kind := String(rec.get("kind", ""))
	if kind != "weapon" and kind != "armor" and kind != "accessory":
		# Carryable non-equippable kinds (M-GEAR G2's tools: field_whetstone,
		# fishers_handline) reach here -- Game.sim.equip() would silently
		# refuse (invalid kind, no toast of its own) with no player feedback
		# at all, so the panel owns this one neutral message. Every OTHER
		# equip()/unequip() false return below already carries its own
		# diegetic toast from WIGame (G1's two accessory refusals), or is
		# prevented entirely by routing an already-equipped item to unequip()
		# instead of a duplicate equip() attempt (the helper above) -- this is
		# the only reachable "no toast yet" case left.
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "That isn't something you can equip."})
		return
	var equipped_slot := _equipped_slot_for(item_id, kind)
	var ok: bool = Game.sim.unequip(equipped_slot) if equipped_slot != "" else Game.sim.equip(item_id)
	if not ok:
		# Defensive only (see above) -- a real refusal already emitted its own
		# diegetic toast (mirrored into `_status_label` by `_on_domain_event`,
		# since the toast layer draws behind this panel); nothing left to
		# surface here, and emitting a second generic toast on top would
		# double up on the sim's own message.
		return
	_refresh()


func _refresh() -> void:
	# M-GEAR Task G3: clear any lingering refusal echo -- a fresh open or a
	# just-succeeded equip/unequip both mean whatever the message was about
	# is no longer the live state.
	_status_label.text = ""
	_refresh_gold()
	_refresh_slots()
	_rebuild_items()


## M-LEGIBILITY L2: the effect lines drawn on each carried item's card, one
## entry per item in `_item_ids` order (parallel to the list the panel renders),
## carried on the `ui_inventory_shown` payload so QA can pin the exact generated
## strings the player sees. Same WIEffectText source the card rendering uses, so
## the payload can never drift from the drawn card.
func _rendered_effect_lines() -> Array:
	var out: Array = []
	for item_id: String in _item_ids:
		out.append(WIEffectText.item_effect_lines(Game.sim.item(String(item_id))))
	return out


## M-GEAR Task G3: the header now carries BOTH visible currencies on one
## line -- "Gold: N" (Economy v1 D3, unchanged) plus "Resonance N/M" (spec's
## visible-currency tier for the accessory budget). Same diegetic-panel-only
## surface as gold (Global Constraint: no always-on HUD); plain text, no
## BBCode, so no `_bb_escape` is needed here either.
func _refresh_gold() -> void:
	_gold_label.text = "Gold: %d     Resonance: %d/%d" % [Game.sim.gold, Game.sim.resonance_used(), Game.sim.resonance_capacity]


func _refresh_slots() -> void:
	_weapon_label.text = "Weapon: %s" % _slot_display("weapon")
	_armor_label.text = "Armor: %s" % _slot_display("armor")
	for i in 3:
		var slot_name := "accessory_%d" % (i + 1)
		_accessory_labels[i].text = "Accessory %d: %s" % [i + 1, _slot_display(slot_name)]


func _slot_display(slot: String) -> String:
	var item_id := String(Game.sim.equipped.get(slot, ""))
	if item_id == "":
		return "—"
	return String(Game.sim.item(item_id).get("name", item_id))


## Rebuilds the carried-item rows from `Game.sim.inventory` fresh every call
## (cheap; the catalog has grown to 19 items (M-GEAR G2), no stacking) --
## per item: a cursor/name/equipped-tag line ("Menu" variation, matches
## pause_menu.gd's row style), the mechanical effect lines, a lore line
## (M-GEAR G3), and a wrapped description prose line. After rebuilding,
## scrolls the cursor's row into view (see `_scroll`'s doc comment).
func _rebuild_items() -> void:
	for child: Node in _items_box.get_children():
		_items_box.remove_child(child)
		child.queue_free()
	_item_ids = Game.sim.inventory.duplicate()
	if _cursor >= _item_ids.size():
		_cursor = max(_item_ids.size() - 1, 0)
	if _item_ids.is_empty():
		_items_box.add_child(UIChrome.make_label("Nothing carried."))
		return
	var cursor_row: Control = null
	for i in _item_ids.size():
		var item_id := String(_item_ids[i])
		var rec: Dictionary = Game.sim.item(item_id)
		var name := String(rec.get("name", item_id))
		var kind := String(rec.get("kind", ""))
		# M-GEAR Task G3: was `String(Game.sim.equipped.get(kind, "")) ==
		# item_id`, which only ever matched weapon/armor (kind IS the slot
		# name for those two) -- an equipped ACCESSORY never tagged
		# "[Equipped]" since `equipped` has no "accessory" key at all, only
		# accessory_1/_2/_3. `_equipped_slot_for` checks the real slot set.
		var equipped_here := _equipped_slot_for(item_id, kind) != ""
		var mark := "> " if i == _cursor else "  "
		var tag := "  [Equipped]" if equipped_here else ""
		# Default dark-on-parchment Label, same reasoning as the slot rows
		# above (E4 review finding: "Menu" is a dark-panel variant). The
		# "> " cursor mark stays legible as dark text on the light parchment.
		var name_label := UIChrome.make_label("%s%s%s" % [mark, name, tag])
		_items_box.add_child(name_label)
		if i == _cursor:
			cursor_row = name_label
		# M-LEGIBILITY L2: the mechanical effect lines, GENERATED from the item's
		# data via the shared WIEffectText formatter (never hand-composed here --
		# that drift is the defect this milestone kills). item_effect_lines already
		# ends with the "Worth N gold" value where the item is priced, so this one
		# call covers both "effect lines" and "gold value where priced" in the plan
		# card spec. A plain item (no mods, no price) yields an empty array -> no
		# effect rows, exactly as before this task. Rendered default dark-on-
		# parchment (senior to the Small flavor prose) with a two-space indent so
		# the lines read as sub-info under the name row.
		for effect_line: String in WIEffectText.item_effect_lines(rec):
			_items_box.add_child(UIChrome.make_label("  %s" % effect_line))
		# M-GEAR Task G3: the lore line, between the mechanical effect lines
		# above and the description prose below (the reserved hook this
		# milestone's §1 left here). "Small" (same style as the description
		# right below it) keeps this cheap -- no new Theme type variation for
		# one milestone -- while the "Lore — " prefix is what actually reads
		# as a distinct register from the plain description line, and it can
		# never be mistaken for a mechanical effect line (those never carry
		# a text prefix). Never mixed into `item_effect_lines`'s own array
		# (Global Constraint) -- this is a separate Label, not appended there.
		var lore := String(rec.get("lore", ""))
		if lore != "":
			var lore_label := UIChrome.make_label("  Lore — %s" % lore, "Small")
			lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_items_box.add_child(lore_label)
		# "Small" (12px, default dark color -- proven on parchment by the
		# footer hint strip) keeps the name row visually senior to its prose.
		var desc_label := UIChrome.make_label(String(rec.get("description", "")), "Small")
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_items_box.add_child(desc_label)
	if cursor_row != null:
		# A FRESH rebuild (every child freed and recreated above) needs the
		# VBoxContainer's own queued sort to actually run before its rows'
		# rects are trustworthy -- a single `call_deferred` hop can still race
		# that queued sort (confirmed empirically: after a full rebuild, one
		# hop left the view scrolled to wherever it was BEFORE the rebuild,
		# not at the cursor's fresh row). Deferring the deferred call gives it
		# a second idle-time hop, past the container's own layout pass.
		var row := cursor_row
		(func() -> void: _scroll.ensure_control_visible.call_deferred(row)).call_deferred()
