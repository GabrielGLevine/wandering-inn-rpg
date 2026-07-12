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
## Issue #62 Lane U item 6: world.gd reaches this (via its own `_main` ref)
## to call `dismiss_current_toast_early()` on an interact press -- the same
## injection-root idiom `world_labels()` below already follows, except this
## one is spawned eagerly in `_spawn_ui_layers()` (not lazily), so the
## accessor just returns the stored ref.
var _message_layer: Node
var _title_screen: Node
var _sleep_veil: Node
## Issue #77: spawned in BOTH `_spawn_title()` and `_spawn_ui_layers()` (a
## FRESH instance each swap, same as every other layer here) -- reachable
## from title_screen.gd's and pause_menu.gd's own "Settings" row via
## `settings_ref`, wired right after creation below.
var _settings_panel: Node
## The combat HUD/mode-FSM screen (issue #57) -- kept here so mouse clicks
## can be routed to its board click-to-target handler alongside the world's
## own click-to-walk/interact handler (`_gui_input` below calls both; each
## is independently no-op-gated by its own mode, so calling both is safe and
## keeps this file free of any `Game.sim.combat` branching of its own).
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


## Issue #62 Lane U item 6: world.gd's interact call sites read this to
## notify the toast queue of an interact press. May be null before
## `_spawn_ui_layers()` has run once (title screen) -- callers already
## null-check.
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


## Mouse click entry point (issue #57). Main sits at the root of the native-
## resolution Control tree (default `mouse_filter == STOP`), so `_gui_input`
## here only ever fires for a click that fell all the way through every
## panel/hotbar Control in front of it WITHOUT being swallowed (mouse_filter
## STOP on an open modal panel, or on a rendered hotbar slot, consumes the
## event before it reaches here -- see the mouse_filter audit: journal.gd/
## pause_menu.gd/inventory.gd/dialogue_panel.gd/consolidation_prompt.gd/
## sleep_veil.gd/message_layer.gd/hotbar.gd). Deliberately does NOT branch on
## `Game.sim.combat` itself: both the field (`_world`) and combat
## (`_combat_screen`) click handlers are called unconditionally and each is
## independently gated by its OWN mode (`_world.handle_world_click`'s
## `_movement_gated()` no-ops during combat; `_combat_screen.handle_board_click`
## no-ops outside ATTACK/SKILL_TARGET) -- so this file never needs to know
## which screen currently owns the moment.
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


## Whether the GDI
## cold-open/epilogue veil currently holds the screen. world.gd's
## `_movement_gated()` reaches this through its injected `_main` ref (the
## same injected-ref-not-tree-scan idiom the other modal gates use); the
## veil itself lives HERE (a sibling UI layer, not injected into world), so
## Main brokers the query. Null-safe: false during the title (no veil
## spawned) and across `_clear_ui_layers` teardown windows.
func veil_modal_active() -> bool:
	return _sleep_veil != null and _sleep_veil.modal_active()


## Mouse-audit finding (issue #57): the pause menu may open DURING combat
## (`combat_screen.gd`'s `is_resting()` -- only from the HOTBAR resting
## state), and combat's own hotbar does not hide for it (only for a mode
## change) -- so a hotbar slot CLICK, which arrives via a GUI-input path
## `_mode == Mode.HOTBAR` alone can't distinguish from "still resting, just
## paused", needs this extra check. Combat_screen.gd's own `main_ref` reaches
## it the same injected-ref way `veil_modal_active()` above is reached.
func pause_open() -> bool:
	return _pause_menu != null and bool(_pause_menu.get("open"))


func swap_to_title() -> void:
	_clear_world_viewport()
	_clear_ui_layers()
	_spawn_title()


## Title NEW GAME (real play, or a QA script that opts in with
## `creation_ui: true`) swaps here for race/gender/name selection. The screen
## itself fires Game.reset(creation) on confirm, whose GAME_RESET takes over the
## swap-to-world (with the GDI opener -- race-neutral since 2026-07-07); Esc on its first step calls
## swap_to_title back. No world/UI layers exist yet at this point (same clean
## slate as the title), so this only clears + spawns the one screen.
func swap_to_char_creation() -> void:
	_clear_world_viewport()
	_clear_ui_layers()
	var creation := CHAR_CREATION_SCRIPT.new()
	creation.name = "CharCreation"
	add_child(creation)


## `new_game` is true ONLY on the GAME_RESET (fresh-world) path — it drives the
## GDI cold open. Continue/load (GAME_LOADED) passes false, so a loaded
## save never replays the arrival sequence.
func swap_to_world(new_game: bool = false) -> void:
	_clear_world_viewport()
	_clear_ui_layers()
	_spawn_ui_layers()
	_spawn_world()
	# After the fresh world exists (world_ready has fired), open on black. Setting
	# the veil opaque here — synchronous with the world spawn — means the inn is
	# never drawn uncovered before the cold open takes the screen.
	if new_game and _sleep_veil != null:
		_sleep_veil.play_opener()


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
	_sleep_veil = null
	_world_labels = null
	_combat_screen = null
	_message_layer = null
	_settings_panel = null


func _spawn_title() -> void:
	_title_screen = TITLE_SCREEN_SCRIPT.new()
	_title_screen.name = "TitleScreen"
	# The title reaches back here to open character creation on New Game
	# (injection idiom, matching combat_screen.main_ref) rather than scanning.
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
	# Three-way mutual exclusion, same wiring idiom as the existing
	# journal<->pause pair: each field panel refuses to open while either of
	# the other two is open.
	_journal.pause_menu_ref = _pause_menu
	_journal.inventory_ref = _inventory
	_pause_menu.journal_ref = _journal
	_pause_menu.inventory_ref = _inventory
	_pause_menu.combat_ref = combat_screen
	_inventory.pause_menu_ref = _pause_menu
	_inventory.journal_ref = _journal
	# Consolidation prompt self-wires via ObservableBus + Game.sim; input
	# arbitration keys off Game.sim.pending_consolidation. Its ONE ref
	# (sleep_veil_ref, assigned below once the veil exists) gates the modal's
	# visibility behind the veil's sleep sequence -- the offer surfaces only
	# after the GDI reveal completes, never on top of the black.
	# Cleared with the other UI layers on world swap (_clear_ui_layers).
	var consolidation_prompt := CONSOLIDATION_PROMPT_SCRIPT.new()
	consolidation_prompt.name = "ConsolidationPrompt"
	add_child(consolidation_prompt)
	# The overworld field-skill hotbar (field-only twin of
	# combat's bar). Spawned BEFORE _spawn_world so its bus listener is connected
	# in time to catch the WORLD_READY that world.gd emits in its own _ready --
	# its first (and load/reset) render trigger. world.gd receives it via
	# inject_ui_refs so its number-key routing can query skill_for_slot.
	_field_hotbar = FIELD_HOTBAR_SCRIPT.new()
	_field_hotbar.name = "FieldHotbar"
	add_child(_field_hotbar)
	# The GDI sleep veil (fade-to-black + centered night
	# announcements). Layer 30, above every other UI so the darkness covers the
	# screen; a pure renderer keyed on the sleep phase_changed. Torn down with
	# the other UI layers on world/title swap (_clear_ui_layers).
	_sleep_veil = SLEEP_VEIL_SCRIPT.new()
	_sleep_veil.name = "SleepVeil"
	add_child(_sleep_veil)
	# The journal<->pause mutual-ref idiom: both nodes live in this same
	# spawn batch, so the assignment is safe here even though the prompt was
	# added first.
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


func _on_domain_event(type: String, _payload: Dictionary) -> void:
	if type == WIEvents.GAME_RESET or type == WIEvents.GAME_LOADED:
		WIDataRegistry.reset()
		# Only a New Game (GAME_RESET) plays the GDI cold open; a load restores
		# straight into the world.
		swap_to_world.bind(type == WIEvents.GAME_RESET).call_deferred()
