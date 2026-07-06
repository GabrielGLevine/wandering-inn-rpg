class_name WIMain
extends Control
## Root render scaffold. Hosts world-space content in a fixed logical
## SubViewport while UI CanvasLayers render at native resolution beside it.
##
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
const CONSOLIDATION_PROMPT_SCRIPT := preload("res://src/ui/consolidation_prompt.gd")
const TITLE_SCREEN_SCRIPT := preload("res://src/ui/title_screen.gd")

var _container: SubViewportContainer
var _sub_viewport: SubViewport
var _world: WIWorld
var _world_labels: WIWorldLabels
var _journal: Node
var _pause_menu: Node
var _inventory: Node
var _field_hotbar: Node
var _title_screen: Node


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


## The shared native-resolution label layer (field names + combat readouts).
## Lazily created because _clear_ui_layers frees it on every title/world swap;
## consumers (world.gd / combat_screen.gd) reach it through their injected
## Main reference rather than scanning the tree, so this is the single
## creation site.
func world_labels() -> WIWorldLabels:
	if _world_labels == null:
		_world_labels = WIWorldLabels.new()
		_world_labels.name = "WorldLabels"
		_world_labels.main_ref = self
		add_child(_world_labels)
	return _world_labels


func world_to_screen(world_pos: Vector2) -> Vector2:
	var canvas_pos := _sub_viewport.canvas_transform * world_pos
	return _container.get_global_transform() * canvas_pos


func swap_to_title() -> void:
	_clear_world_viewport()
	_clear_ui_layers()
	_spawn_title()


func swap_to_world() -> void:
	_clear_world_viewport()
	_clear_ui_layers()
	_spawn_ui_layers()
	_spawn_world()


func _ensure_viewport_nodes() -> void:
	_container = get_node_or_null("WorldContainer") as SubViewportContainer
	if _container == null:
		_container = SubViewportContainer.new()
		_container.name = "WorldContainer"
		_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_container)
	# Pixel-art world content is scaled 4x by _layout_viewport_container(); force
	# nearest-neighbor sampling so upscaled pixels stay crisp instead of blurring.
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
	_title_screen = null
	_world_labels = null


func _spawn_title() -> void:
	_title_screen = TITLE_SCREEN_SCRIPT.new()
	_title_screen.name = "TitleScreen"
	add_child(_title_screen)


func _spawn_ui_layers() -> void:
	var message_layer := MESSAGE_LAYER_SCRIPT.new()
	message_layer.name = "MessageLayer"
	add_child(message_layer)
	var combat_screen := COMBAT_SCREEN_SCRIPT.new()
	combat_screen.name = "CombatScreen"
	combat_screen.main_ref = self
	add_child(combat_screen)
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
	# Three-way mutual exclusion (M7 E4), same wiring idiom as the existing
	# journal<->pause pair: each field panel refuses to open while either of
	# the other two is open.
	_journal.pause_menu_ref = _pause_menu
	_journal.inventory_ref = _inventory
	_pause_menu.journal_ref = _journal
	_pause_menu.inventory_ref = _inventory
	_inventory.pause_menu_ref = _pause_menu
	_inventory.journal_ref = _journal
	# Consolidation prompt self-wires via ObservableBus + Game.sim; input
	# arbitration keys off Game.sim.pending_consolidation, so no refs needed.
	# Cleared with the other UI layers on world swap (_clear_ui_layers).
	var consolidation_prompt := CONSOLIDATION_PROMPT_SCRIPT.new()
	consolidation_prompt.name = "ConsolidationPrompt"
	add_child(consolidation_prompt)
	# Three Pillars P2: the overworld field-skill hotbar (field-only twin of
	# combat's bar). Spawned BEFORE _spawn_world so its bus listener is connected
	# in time to catch the WORLD_READY that world.gd emits in its own _ready --
	# its first (and load/reset) render trigger. world.gd receives it via
	# inject_ui_refs so its number-key routing can query skill_for_slot.
	_field_hotbar = FIELD_HOTBAR_SCRIPT.new()
	_field_hotbar.name = "FieldHotbar"
	add_child(_field_hotbar)


func _spawn_world() -> void:
	var world := WIWorld.new()
	world.name = "World"
	world.inject_ui_refs(_journal, _pause_menu, _inventory, self, _field_hotbar)
	_sub_viewport.add_child(world)
	_world = world


func _on_domain_event(type: String, _payload: Dictionary) -> void:
	if type == WIEvents.GAME_RESET or type == WIEvents.GAME_LOADED:
		WIDataRegistry.reset()
		swap_to_world.call_deferred()
