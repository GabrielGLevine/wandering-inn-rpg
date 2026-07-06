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
## possession validation; a false return (defensive only -- unreachable in
## normal play since the listed item/kind pairing is always valid and combat
## can never be active while this panel is open) surfaces a toast, the same
## pattern as pause_menu.gd's "Could not load save." notice.
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

	# Carried list below, in a ScrollContainer as the overflow safety net --
	# same idiom as journal.gd's RichTextLabel (scroll_active=true) rather
	# than the combat-feed/dialogue-panel wrapped-line eviction: item count
	# is small (spec's 8-item catalog, no stacking) and each row's prose
	# still wraps via AUTOWRAP_WORD_SMART, never truncates.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(scroll)
	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 4)
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items_box)

	# Live coin-line refresh (Economy v1 D3): the same domain_event idiom
	# field_hotbar/dialogue_panel use -- if the panel is open when gold
	# changes, re-render the line (and re-confirm) rather than only on open.
	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, _payload: Dictionary) -> void:
	if type == WIEvents.GOLD_CHANGED and open:
		_refresh_gold()
		# Re-confirm the drawn state (bus convention), carrying the live total.
		ObservableBus.emit_domain_event(WIEvents.UI_INVENTORY_SHOWN, {"items": _item_ids.size(), "gold": Game.sim.gold, "item_effect_lines": _rendered_effect_lines()})


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
	ObservableBus.emit_domain_event(WIEvents.UI_INVENTORY_SHOWN, {"items": _item_ids.size(), "gold": Game.sim.gold, "item_effect_lines": _rendered_effect_lines()})


func _close() -> void:
	open = false
	_root.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_INVENTORY_HIDDEN, {})


func _move_cursor(delta: int) -> void:
	if _item_ids.is_empty():
		return
	_cursor = wrapi(_cursor + delta, 0, _item_ids.size())
	_rebuild_items()


## Equips the selected item into its own kind's slot, or unequips it if it
## IS the item already equipped in that slot (spec §3 journal grammar).
func _confirm() -> void:
	if _item_ids.is_empty():
		return
	var item_id := String(_item_ids[_cursor])
	var rec: Dictionary = Game.sim.item(item_id)
	var kind := String(rec.get("kind", ""))
	var currently_equipped := String(Game.sim.equipped.get(kind, "")) == item_id
	var ok: bool = Game.sim.unequip(kind) if currently_equipped else Game.sim.equip(item_id)
	if not ok:
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Could not equip that."})
		return
	_refresh()


func _refresh() -> void:
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


func _refresh_gold() -> void:
	_gold_label.text = "Gold: %d" % Game.sim.gold


func _refresh_slots() -> void:
	_weapon_label.text = "Weapon: %s" % _slot_display("weapon")
	_armor_label.text = "Armor: %s" % _slot_display("armor")


func _slot_display(slot: String) -> String:
	var item_id := String(Game.sim.equipped.get(slot, ""))
	if item_id == "":
		return "—"
	return String(Game.sim.item(item_id).get("name", item_id))


## Rebuilds the carried-item rows from `Game.sim.inventory` fresh every call
## (cheap; the catalog is 8 items, no stacking) -- two Labels per item: a
## cursor/name/equipped-tag line ("Menu" variation, matches pause_menu.gd's
## row style) and a wrapped prose line (no stat words; HP/damage numbers are
## fine per the repo-wide rule -- items.json's `description` field never
## carries any).
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
	for i in _item_ids.size():
		var item_id := String(_item_ids[i])
		var rec: Dictionary = Game.sim.item(item_id)
		var name := String(rec.get("name", item_id))
		var kind := String(rec.get("kind", ""))
		var equipped_here := String(Game.sim.equipped.get(kind, "")) == item_id
		var mark := "> " if i == _cursor else "  "
		var tag := "  [Equipped]" if equipped_here else ""
		# Default dark-on-parchment Label, same reasoning as the slot rows
		# above (E4 review finding: "Menu" is a dark-panel variant). The
		# "> " cursor mark stays legible as dark text on the light parchment.
		var name_label := UIChrome.make_label("%s%s%s" % [mark, name, tag])
		_items_box.add_child(name_label)
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
		# --- Reserved lore slot (M-GEAR §1) ------------------------------------
		# M-GEAR fills a dedicated flavor-lore line HERE, between the mechanical
		# effect lines above and the existing description prose below. Kept a
		# documented insertion hook only -- renders NOTHING now (an empty Label
		# would add a blank gap), and lore stays SEPARATE from the effect fields
		# per the milestone's Global Constraints.
		# -----------------------------------------------------------------------
		# "Small" (12px, default dark color -- proven on parchment by the
		# footer hint strip) keeps the name row visually senior to its prose.
		var desc_label := UIChrome.make_label(String(rec.get("description", "")), "Small")
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_items_box.add_child(desc_label)
