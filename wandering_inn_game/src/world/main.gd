class_name WIMain
extends Control
## M5 arch (finding 3): Main owns the boot order, so it is the injection
## root — the spawned world and combat screen receive typed references
## downward from here (inject_ui_refs / main_ref) instead of scanning the
## tree with find_child at use time.

const WORLD_VIEWPORT_SIZE := Vector2(320.0, 180.0)
const WORLD_SCALE := 4.0
const MESSAGE_LAYER_SCRIPT := preload("res://src/ui/message_layer.gd")
const COMBAT_SCREEN_SCRIPT := preload("res://src/combat/combat_screen.gd")
const DIALOGUE_PANEL_SCRIPT := preload("res://src/ui/dialogue_panel.gd")
const JOURNAL_SCRIPT := preload("res://src/ui/journal.gd")
const PAUSE_MENU_SCRIPT := preload("res://src/ui/pause_menu.gd")
const INVENTORY_SCRIPT := preload("res://src/ui/inventory.gd")
const FIELD_HOTBAR_SCRIPT := preload("res://src/ui/field_hotbar.gd")
const FIELD_CHIPS_SCRIPT := preload("res://src/ui/field_chips.gd")
const CONSOLIDATION_PROMPT_SCRIPT := preload("res://src/ui/consolidation_prompt.gd")
const SLEEP_VEIL_SCRIPT := preload("res://src/ui/sleep_veil.gd")
const TITLE_SCREEN_SCRIPT := preload("res://src/ui/title_screen.gd")
const CHAR_CREATION_SCRIPT := preload("res://src/ui/char_creation.gd")
const SETTINGS_PANEL_SCRIPT := preload("res://src/ui/settings_panel.gd")

var _container: SubViewportContainer
var _sub_viewport: SubViewport
var _world: WIWorld
var _world_labels: WIWorldLabels
var _journal: Node
var _pause_menu: Node
var _inventory: Node
var _field_hotbar: Node
var _field_chips: Node
var _message_layer: Node
var _title_screen: Node
var _sleep_veil: Node
var _settings_panel: Node
var _combat_screen: Node


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ensure_viewport_nodes()
	get_viewport().size_changed.connect(_layout_viewport_container)
	_layout_viewport_container()
	ObservableBus.domain_event.connect(_on_domain_event)
	swap_to_title()


func world_root() -> WIWorld:
	return _world


func ui_root() -> Node:
	return self


func world_labels() -> WIWorldLabels:
	if _world_labels == null:
		_world_labels = WIWorldLabels.new()
		_world_labels.name = "WorldLabels"
		_world_labels.main_ref = self
		add_child(_world_labels)
	return _world_labels


func message_layer() -> Node:
	return _message_layer


func world_to_screen(world_pos: Vector2) -> Vector2:
	var canvas_pos := _sub_viewport.canvas_transform * world_pos
	return _container.get_global_transform() * canvas_pos


## The exact inverse of `world_to_screen` (issue #57's screen->cell trap):
## un-does the SubViewportContainer's global transform (its centering
## position + the 4x WORLD_SCALE), THEN the SubViewport's own `canvas_transform`
## (the Camera2D's pan) -- both via `Transform2D.affine_inverse()`, never a
## hardcoded /4.0. `qa/test_driver.gd`'s `click` step composes the FORWARD
## direction (`world_to_screen`, already used by its own camera-aware probe)
## to know where on screen to inject a synthetic click, so a real player
## click and a driver-injected one are proven by the SAME two transforms,
## just walked in opposite directions -- one source of truth either way.
func screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas_pos := _container.get_global_transform().affine_inverse() * screen_pos
	return _sub_viewport.canvas_transform.affine_inverse() * canvas_pos


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var world_pos := screen_to_world(mb.position)
	if _world != null:
		_world.handle_world_click(world_pos)
	if _combat_screen != null:
		_combat_screen.handle_board_click(world_pos)
	accept_event()


func veil_modal_active() -> bool:
	return _sleep_veil != null and _sleep_veil.modal_active()


func pause_open() -> bool:
	return _pause_menu != null and bool(_pause_menu.get("open"))


func swap_to_title() -> void:
	_record_current_chronicle()
	_clear_world_viewport()
	_clear_ui_layers()
	_spawn_title()


func _record_current_chronicle() -> void:
	if Game.sim != null and Game.sim.accomplishment_count("post_game") > 0:
		WISettings.record_chronicle(Game.sim.chronicle_facts())


func swap_to_char_creation() -> void:
	_clear_world_viewport()
	_clear_ui_layers()
	var creation := CHAR_CREATION_SCRIPT.new()
	creation.name = "CharCreation"
	add_child(creation)


func swap_to_world(new_game: bool = false, defeat_reload: bool = false) -> void:
	_clear_world_viewport()
	_clear_ui_layers()
	# ORDER: FieldHotbar must exist before World emits WORLD_READY
	# synchronously; initial boot and load both render from that event.
	_spawn_ui_layers()
	_spawn_world()
	if new_game and _sleep_veil != null:
		_sleep_veil.play_opener()
	elif defeat_reload and _sleep_veil != null:
		_sleep_veil.play_defeat()


func _ensure_viewport_nodes() -> void:
	_container = get_node_or_null("WorldContainer") as SubViewportContainer
	if _container == null:
		_container = SubViewportContainer.new()
		_container.name = "WorldContainer"
		_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_container)
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sub_viewport = _container.get_node_or_null("WorldViewport") as SubViewport
	if _sub_viewport == null:
		_sub_viewport = SubViewport.new()
		_sub_viewport.name = "WorldViewport"
		_sub_viewport.size = Vector2i(int(WORLD_VIEWPORT_SIZE.x), int(WORLD_VIEWPORT_SIZE.y))
		_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_container.add_child(_sub_viewport)


func _layout_viewport_container() -> void:
	var scaled_size := WORLD_VIEWPORT_SIZE * WORLD_SCALE
	_container.size = WORLD_VIEWPORT_SIZE
	_container.scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	_container.position = (get_viewport_rect().size - scaled_size) * 0.5


func _clear_world_viewport() -> void:
	for child: Node in _sub_viewport.get_children():
		_sub_viewport.remove_child(child)
		child.queue_free()
	_world = null


func _clear_ui_layers() -> void:
	for child: Node in get_children():
		if child != _container:
			remove_child(child)
			child.queue_free()
	_journal = null
	_pause_menu = null
	_inventory = null
	_field_hotbar = null
	_field_chips = null
	_title_screen = null
	_sleep_veil = null
	_world_labels = null
	_combat_screen = null
	_message_layer = null
	_settings_panel = null


func _spawn_title() -> void:
	_title_screen = TITLE_SCREEN_SCRIPT.new()
	_title_screen.name = "TitleScreen"
	_title_screen.main_ref = self
	add_child(_title_screen)
	# Issue #77: added AFTER TitleScreen so it sits LATER in Main's child
	# order -- the SAME "later child gets first refusal of unhandled_input"
	# precedent pause_menu.gd's own file doc comment documents (world_ref) --
	# so while settings_panel.gd's `open` is true, it consumes Cancel/Confirm/
	# move before TitleScreen's own `_unhandled_input` ever sees them. No
	# arbitration guard needed in title_screen.gd for the same reason
	# pause_menu.gd needs none against journal/inventory's LATER siblings.
	_settings_panel = SETTINGS_PANEL_SCRIPT.new()
	_settings_panel.name = "SettingsPanel"
	add_child(_settings_panel)
	_title_screen.settings_ref = _settings_panel


func _spawn_ui_layers() -> void:
	var message_layer := MESSAGE_LAYER_SCRIPT.new()
	message_layer.name = "MessageLayer"
	add_child(message_layer)
	_message_layer = message_layer
	var combat_screen := COMBAT_SCREEN_SCRIPT.new()
	combat_screen.name = "CombatScreen"
	combat_screen.main_ref = self
	add_child(combat_screen)
	_combat_screen = combat_screen
	var dialogue_panel := DIALOGUE_PANEL_SCRIPT.new()
	dialogue_panel.name = "DialoguePanel"
	add_child(dialogue_panel)
	_journal = JOURNAL_SCRIPT.new()
	_journal.name = "Journal"
	_pause_menu = PAUSE_MENU_SCRIPT.new()
	_pause_menu.name = "PauseMenu"
	_inventory = INVENTORY_SCRIPT.new()
	_inventory.name = "Inventory"
	add_child(_journal)
	add_child(_pause_menu)
	add_child(_inventory)
	_journal.pause_menu_ref = _pause_menu
	_journal.inventory_ref = _inventory
	_pause_menu.journal_ref = _journal
	_pause_menu.inventory_ref = _inventory
	_pause_menu.combat_ref = combat_screen
	_inventory.pause_menu_ref = _pause_menu
	_inventory.journal_ref = _journal
	var consolidation_prompt := CONSOLIDATION_PROMPT_SCRIPT.new()
	consolidation_prompt.name = "ConsolidationPrompt"
	add_child(consolidation_prompt)
	_field_hotbar = FIELD_HOTBAR_SCRIPT.new()
	_field_hotbar.name = "FieldHotbar"
	add_child(_field_hotbar)
	# Issue #109: the field-mode HUD launcher chips (pause/journal/inventory) --
	# spawned right after the three panels above so their refs are already
	# live to wire in. Add-order here only needs to be AFTER those three (so
	# this layer's own _apply_visibility() first-call reads real ref state,
	# not nulls); it does not need to precede/follow field_hotbar.
	_field_chips = FIELD_CHIPS_SCRIPT.new()
	_field_chips.name = "FieldChips"
	_field_chips.pause_menu_ref = _pause_menu
	_field_chips.journal_ref = _journal
	_field_chips.inventory_ref = _inventory
	_field_chips.main_ref = self
	add_child(_field_chips)
	_sleep_veil = SLEEP_VEIL_SCRIPT.new()
	_sleep_veil.name = "SleepVeil"
	add_child(_sleep_veil)
	consolidation_prompt.sleep_veil_ref = _sleep_veil
	# Issue #77: added LAST (after pause_menu/sleep_veil/everything else) so
	# it sits latest in Main's child order -- see `_spawn_title()`'s matching
	# comment for the "later child processes unhandled_input first" mechanism
	# this relies on for pause_menu.gd's own "Settings" row to work without a
	# new arbitration guard in pause_menu.gd.
	_settings_panel = SETTINGS_PANEL_SCRIPT.new()
	_settings_panel.name = "SettingsPanel"
	add_child(_settings_panel)
	_pause_menu.settings_ref = _settings_panel


func _spawn_world() -> void:
	var world := WIWorld.new()
	world.name = "World"
	world.inject_ui_refs(_journal, _pause_menu, _inventory, self, _field_hotbar)
	_sub_viewport.add_child(world)
	_world = world


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if type == WIEvents.GAME_RESET or type == WIEvents.GAME_LOADED:
		WIDataRegistry.reset()
		var is_defeat := String(payload.get("reason", "")) == "defeat"
		swap_to_world.bind(type == WIEvents.GAME_RESET, is_defeat).call_deferred()
	elif type == WIEvents.ACCOMPLISHMENT_RECORDED and String(payload.get("id", "")) == "post_game":
		_record_current_chronicle()
