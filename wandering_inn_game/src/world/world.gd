class_name WIWorld
extends Node2D
## Field name tags ("You"/"Erin"/etc.) are RETIRED -- every interactable must
## read from its sprite alone now (see `_resolve_entity_render`/
## `_refresh_entity_visual` for the `visual_states` seam that replaces the
## "state changed" affordance a label used to carry).

## The world SubViewport is 320x180 logical px, so the grid cell must match
## the tile sheets' true native size (16px -- see data/biomes.json).
const CELL := 16
const PLAYER_COLOR := Color(0.25, 0.45, 0.9)
const NPC_COLOR := Color(0.3, 0.7, 0.35)
const PROP_COLOR := Color(0.55, 0.4, 0.25)
const MOVE_TWEEN_SECONDS := 0.12
const BUMP_PIXELS := 3.0
const BUMP_TWEEN_SECONDS := 0.06

const LIGHT_TEXTURE := preload("res://assets/fx/light_radial.png")
const LIGHT_TEXTURE_PX := 64.0
const LIGHT_BUDGET := 8

const PC_LIGHT_COLOR := Color(1.0, 0.95, 0.8)
const PC_LIGHT_RADIUS := 32.0
const PC_LIGHT_ENERGY := 1.0

const SNEAK_ALPHA := 0.6

const AMBIENCE_BUDGET := 6
const SWAY_SHADER := preload("res://src/world/shaders/foliage_sway.gdshader")
const WATER_SHEET := "res://assets/tiles/free_pack/Water_tiles.png"
const WATER_SHIMMER_SHADER := preload("res://src/world/shaders/water_shimmer.gdshader")
## TRAP: do not swap this to (1,7) -- PIL alpha-scan confirms it is a
## completely flat solid-fill tile (every pixel in the 16x16 region is the
## identical (62,146,209), zero variance); a frost tint over it still reads
## as perfectly flat/invisible. (1,5) is one of the sheet's genuine
## rippled-open-water tiles (5 distinct blue shades, a real subtle wave
## pattern) -- same swap as the water-shimmer cap default just below, so a
## frozen cell reads as a distinctly textured, frost-tinted surface instead
## of a slightly-lighter flat rectangle.
const ICE_CAP_COORD := Vector2i(1, 5)
const ICE_TINT := Color(0.74, 0.86, 1.0, 0.92)
const VIGNETTE_SHADER := preload("res://src/world/shaders/vignette.gdshader")

## Must match src/world/main.gd's WORLD_VIEWPORT_SIZE
## (kept in sync by hand -- both are 320x180
## per the locked render architecture). Used to decide whether the
## camera can simply center a map/arena (content <= view) or needs
## clamped-follow (content > view -- not exercised by any current map/arena,
## but built for future maps that may need it).
const VIEW_SIZE := Vector2(320.0, 180.0)
const SKIRT_MARGIN_CELLS := 20
const FIELD_BLOCKED_PROP_BUDGET := 200

var _field_root: Node2D
## Y-sort-enabled holder for entity/player/decor visuals only (floor tile
## layers stay outside it, always drawn first) so taller sprites (character
## canvases overhang the 16px cell above, by design) overlap the cell above
## them correctly instead of a fixed draw order.
var _entities_root: Node2D
var _camera: Camera2D
var _player_visual: Node2D
var _player_sprite: AnimatedSprite2D
var _player_anim_token := 0
var _companion_visual: Node2D
var _ward_visuals: Array[Node2D] = []
var _pc_light: PointLight2D
var _sneak_tinted := false
## The id of the LAST `sneaks: true`-tagged skill whose
## deliberate toggle press turned `sneaking` ON -- presentation-only memory,
## never read by any sim file. The sim itself only tracks the single
## `sneaking` bool (see that field's own doc comment: it does not know or
## care WHICH tagged skill flipped it -- two verbs, one shared stance, by
## design). Exists purely so `_reconcile_sneak_visual` can look up THAT
## skill's own optional `sneak_visual` data (falling back to the plain
## SNEAK_ALPHA look when absent or when this is still ""), giving a skill a
## distinct render without teaching the sim anything new. Updated only in
## the SKILL_USED handler below, only on a toggle-ON press (a toggle-OFF
## press of the SAME or a DIFFERENT tagged skill leaves it alone --
## harmless, since it is only ever read while `sneaking` is true). Survives
## `_rebuild_field` (a door crossing keeps `sneaking` true, so the active
## skill's identity must persist too -- same reasoning as `_sneak_tinted`'s
## reset, just not the RESET itself).
var _sneak_active_skill := ""
var _ice_overlay: TileMapLayer
## One slot, not two -- a move and a bump landing on the player in quick
## succession must kill whichever tween is already
## running before starting the other, or both fight over `.position` for up
## to ~0.12s. See `_kill_player_tween`.
var _player_tween: Tween
var _camera_ctl: WICameraController
var _entity_visuals: Dictionary = {}
var _field_blocked_prop_plan: Dictionary = {}
var _journal: Node
var _pause_menu: Node
var _inventory: Node
var _field_hotbar: Node
var _field_slot_index := -1
## Absolute remaining cells, not directions: each step calls move_player so
## triggers/costs stay live. Keyboard/pad input, modals, refusal, and rebuilds
## clear the path; click-walking must never become a teleport or stale replay.
var _click_path: Array = []
var _main: WIMain
var _combat_board_root: Node2D
## Mood grade layer, a CanvasModulate child of this World
## node (the world viewport's root). Must be added, and connect to the bus,
## BEFORE this _ready() emits WORLD_READY below so it catches its own spawn
## event and applies the starting map/phase mood immediately (see
## atmosphere.gd's doc comment for why that ordering matters and why the
## combat board inherits the same grade).
var _atmosphere: WIAtmosphere
## Count of PointLight2Ds spawned this `_rebuild_field`
## pass, reset at the top of each pass -- backs the LIGHT_BUDGET assert and
## the `ui_lights_rendered` payload.
var _light_count := 0
var _ambience_count := 0
var _sway_material: ShaderMaterial
var _visual_factory: WIEntityVisualFactory
var _sneak_shimmer_material: ShaderMaterial
var _vignette: ColorRect


func _ready() -> void:
	_field_root = Node2D.new()
	add_child(_field_root)
	_atmosphere = WIAtmosphere.new()
	_atmosphere.name = "Atmosphere"
	add_child(_atmosphere)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera_ctl = WICameraController.new(_camera, CELL, VIEW_SIZE)
	_sway_material = ShaderMaterial.new()
	_sway_material.shader = SWAY_SHADER
	_visual_factory = WIEntityVisualFactory.new(CELL, _sway_material)
	_sneak_shimmer_material = ShaderMaterial.new()
	_sneak_shimmer_material.shader = WATER_SHIMMER_SHADER
	# Parented under `_camera` (not this World node
	# directly) so its rect tracks the camera's centered/clamped view
	# regardless of map size -- see vignette.gdshader's doc comment. Must be
	# created (and `vignette_node` assigned) BEFORE `_rebuild_field()` below,
	# which is itself before WORLD_READY emits -- the earliest any
	# `atmosphere.apply()` call can fire -- so `_apply_vignette` never sees a
	# null `vignette_node`.
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.size = VIEW_SIZE
	_vignette.position = -VIEW_SIZE * 0.5
	_vignette.z_index = 4096 # topmost regardless of sibling-order timing (combat_board_root is added lazily, sometimes after the camera)
	var vignette_mat := ShaderMaterial.new()
	vignette_mat.shader = VIGNETTE_SHADER
	_vignette.material = vignette_mat
	_camera.add_child(_vignette)
	_atmosphere.vignette_node = _vignette
	_rebuild_field()
	_wire_ui_refs()
	ObservableBus.domain_event.connect(_on_domain_event)
	ObservableBus.emit_domain_event(WIEvents.WORLD_READY, {})


func inject_ui_refs(journal: Node, pause_menu: Node, inventory: Node, main: WIMain, field_hotbar: Node = null) -> void:
	_journal = journal
	_pause_menu = pause_menu
	_inventory = inventory
	_main = main
	_field_hotbar = field_hotbar
	# See pause_menu.gd's `world_ref` doc comment -- lets its `_can_open()`
	# decline while the field hotbar's cursor is armed, so an armed Esc/
	# cancel reaches THIS file's own cancel-disarm branch below instead of
	# opening the pause menu first (it sits later in Main's child order).
	if _pause_menu != null:
		_pause_menu.world_ref = self
	if _field_hotbar != null:
		_field_hotbar.slot_activate_requested.connect(_activate_field_slot)


func _wire_ui_refs() -> void:
	if _journal == null or _pause_menu == null:
		return
	_journal.pause_menu_ref = _pause_menu
	_pause_menu.journal_ref = _journal
	if _inventory == null:
		return
	_journal.inventory_ref = _inventory
	_pause_menu.inventory_ref = _inventory
	_inventory.journal_ref = _journal
	_inventory.pause_menu_ref = _pause_menu


func _movement_gated() -> bool:
	if Game.sim.combat != null or Game.sim.dialogue != null:
		return true
	if not Game.sim.pending_consolidation.is_empty():
		return true
	if (_pause_menu != null and bool(_pause_menu.get("open"))) \
			or (_journal != null and bool(_journal.get("open"))) \
			or (_inventory != null and bool(_inventory.get("open"))):
		return true
	if _main != null and _main.veil_modal_active():
		return true
	if _main != null and _main.map_transition_active():
		return true
	return false


## INPUT-DISPATCH-ORDER TRAP -- read before
## reordering ANY branch below: on pad, `interact` and `confirm` BOTH bind
## to button A, so one A-press satisfies BOTH
## `is_action_pressed` checks on the same event and whichever branch is
## checked first in this if/elif chain wins. The slot-armed
## `confirm`/`cancel` branches must therefore run BEFORE the interact check
## -- with interact first, the pad slot-select+confirm idiom is silently
## dead code (A always interacts, the armed slot never fires). Safe for
## keyboard: `confirm` (Enter) and `cancel` (Esc) previously did nothing in
## the world context, both new branches are `_field_slot_index >= 0`-gated,
## and keyboard players only arm that index via the additive `[`/`]` keys.
## Issue #58 (Tab-primed select) ADDS branches (hotbar_prime, and
## `_field_slot_index >= 0`-gated move_left/move_right/move_up/move_down)
## between the interact check and the plain movement branches -- it does NOT
## reorder confirm/cancel/interact's own relative order above, which stays
## exactly as this comment describes. `move_left`/`move_right` share no
## button with anything pad-side, so no analogous trap applies to them.
func _unhandled_input(event: InputEvent) -> void:
	if not _click_path.is_empty() and event.is_pressed() and not event.is_echo() \
			and not (event is InputEventMouseButton or event is InputEventMouseMotion):
		_click_path.clear()
	if _movement_gated():
		return
	if event.is_action_pressed("confirm") and _field_slot_index >= 0:
		# Activates
		# the pad-hovered slot exactly as pressing its number key would --
		# same `use_skill_field` call, same "no field skill in that slot"
		# no-op guard. Activation DISARMS the selection (one-shot): if it
		# stayed armed, every later A-press would keep re-firing the skill
		# instead of interacting -- the exact interact/confirm-share-A trap
		# this ordering exists to manage. Re-arm is one LB/RB press away.
		if _field_hotbar != null:
			var skill_id := String(_field_hotbar.skill_for_slot(_field_slot_index + 1))
			if skill_id != "":
				Game.sim.use_skill_field(skill_id)
		_disarm_field_slot()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel") and _field_slot_index >= 0:
		_disarm_field_slot()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_notify_action_taken()
		Game.sim.interact()
		get_viewport().set_input_as_handled()
	elif InputMap.has_action("hotbar_prime") and event.is_action_pressed("hotbar_prime") and _field_slot_index >= 0:
		_disarm_field_slot()
		get_viewport().set_input_as_handled()
	elif InputMap.has_action("hotbar_prime") and event.is_action_pressed("hotbar_prime") and _field_hotbar != null and _field_hotbar.slot_count() > 0:
		_field_slot_index = 0
		_field_hotbar.set_selected(0)
		get_viewport().set_input_as_handled()
	elif _field_slot_index >= 0 and event.is_action_pressed("move_left"):
		# While primed, left/right NAVIGATE the bar instead of moving the
		# player -- must be checked BEFORE the plain move_left/move_right
		# branches below (same if/elif short-circuit this file's existing
		# branches already rely on), gated on an armed index so an unprimed
		# press falls through to those unchanged.
		_move_field_slot_cursor(-1)
		get_viewport().set_input_as_handled()
	elif _field_slot_index >= 0 and event.is_action_pressed("move_right"):
		_move_field_slot_cursor(1)
		get_viewport().set_input_as_handled()
	elif _field_slot_index >= 0 and (event.is_action_pressed("move_up") or event.is_action_pressed("move_down")):
		# Swallowed, not routed anywhere -- up/down have no meaning for a
		# 1-D slot bar. Consuming (not falling through to the plain
		# move_up/move_down branches) is the point: the player must not
		# drift while aiming the bar.
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		Game.sim.move_player(_combined_move_dir(Vector2i.UP))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		Game.sim.move_player(_combined_move_dir(Vector2i.DOWN))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		Game.sim.move_player(_combined_move_dir(Vector2i.LEFT))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		Game.sim.move_player(_combined_move_dir(Vector2i.RIGHT))
		get_viewport().set_input_as_handled()
	elif InputMap.has_action("slot_prev") and event.is_action_pressed("slot_prev"):
		_move_field_slot_cursor(-1)
		get_viewport().set_input_as_handled()
	elif InputMap.has_action("slot_next") and event.is_action_pressed("slot_next"):
		_move_field_slot_cursor(1)
		get_viewport().set_input_as_handled()
	else:
		var slot := _field_hotbar_slot_pressed(event)
		if slot > 0 and _field_hotbar != null:
			# `_activate_field_slot` is the ONE dispatch (issue #57): a slot
			# CLICK (`slot_activate_requested`, connected in `inject_ui_refs`)
			# calls the exact same helper. Read whether it WILL fire before
			# calling it, purely to preserve this branch's own
			# "mark input handled only on a real fire" contract -- a stripped/
			# empty slot must stay unhandled, same as before this refactor.
			var will_fire := String(_field_hotbar.skill_for_slot(slot)) != ""
			_activate_field_slot(slot)
			if will_fire:
				get_viewport().set_input_as_handled()


func _combined_move_dir(primary: Vector2i) -> Vector2i:
	var dx := primary.x
	var dy := primary.y
	if dx == 0:
		if Input.is_action_pressed("move_left"):
			dx = -1
		elif Input.is_action_pressed("move_right"):
			dx = 1
	if dy == 0:
		if Input.is_action_pressed("move_up"):
			dy = -1
		elif Input.is_action_pressed("move_down"):
			dy = 1
	return Vector2i(dx, dy)


func _move_field_slot_cursor(delta: int) -> void:
	if _field_hotbar == null:
		return
	var count: int = _field_hotbar.slot_count()
	if count <= 0:
		return
	if _field_slot_index < 0:
		_field_slot_index = 0
	else:
		_field_slot_index = (_field_slot_index + delta + count) % count
	_field_hotbar.set_selected(_field_slot_index)


## Clears the armed slot selection (index AND
## the rendered highlight). Called after a confirm-activation (one-shot
## semantics -- see `_unhandled_input`'s confirm branch), on a cancel press,
## and shared with the event-driven reset in `_on_domain_event` (the slot
## LIST changed, so the cursor must not point at a stale entry).
func _disarm_field_slot() -> void:
	_field_slot_index = -1
	if _field_hotbar != null:
		_field_hotbar.set_selected(-1)


func _notify_action_taken() -> void:
	if _main == null:
		return
	var ml := _main.message_layer()
	if ml != null:
		ml.dismiss_current_toast_early()


func _activate_field_slot(slot: int) -> void:
	if slot <= 0 or _field_hotbar == null:
		return
	if _movement_gated():
		return
	if _field_slot_index >= 0:
		_disarm_field_slot()
	var skill_id := String(_field_hotbar.skill_for_slot(slot))
	if skill_id != "":
		Game.sim.use_skill_field(skill_id)


func field_slot_armed() -> bool:
	return _field_slot_index >= 0


func _field_hotbar_slot_pressed(event: InputEvent) -> int:
	for n in range(1, 10):
		var action := "hotbar_%d" % n
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return n
	return -1


func _rebuild_field() -> void:
	# A full rebuild reconstructs every visual from live sim, so it SUPERSEDES
	# any reconcile queued by the dialogue defer -- drop the latch or the next
	# DIALOGUE_ENDED emits a redundant ui_entities_rendered over fresh geometry.
	_presence_reconcile_deferred = false
	_click_path.clear()
	for child: Node in _field_root.get_children():
		child.queue_free()
	_entity_visuals.clear()
	_player_sprite = null
	_companion_visual = null
	_ward_visuals.clear()
	_pc_light = null
	# See `_sneak_tinted`'s own doc comment -- the fresh
	# `_player_sprite` built below is always untinted, so the tracker must
	# forget the old sprite's state too.
	_sneak_tinted = false
	_ice_overlay = null
	_field_blocked_prop_plan.clear()
	# Drop every light registered for the OLD map before
	# any new one is spawned below -- the old map's holders (and their light
	# children) are only queue_free()d above, not freed synchronously, so
	# atmosphere.gd's registry must be cleared explicitly rather than relying
	# on is_instance_valid() to catch up on its own.
	_atmosphere.clear_lights()
	_light_count = 0
	_atmosphere.clear_emitters()
	_ambience_count = 0
	_build_floor()
	_build_water_shimmer()
	_build_ice_overlay()
	_entities_root = Node2D.new()
	_entities_root.y_sort_enabled = true
	_field_root.add_child(_entities_root)
	_build_field_blocked_props()
	# TRAP (load-bearing ORDER): decor builds BEFORE entities so a door
	# entity sharing a cell with a facade decor tile draws OVER it -- equal
	# y-sort keys tie-break by tree order in Godot 4 (later sibling on
	# top). The street's barracks_door sits ON its facade tile relying on
	# exactly this; reordering these builds buries that door with every QA
	# gate still green (render-only).
	_build_decor(_current_map_cfg().get("decor", []))
	_build_scatter(_current_map_cfg().get("scatter", []))
	var render_counts := {"sprites": 0, "fallbacks": 0}
	_count_visual(_build_entities(), render_counts)
	_apply_field_legibility()  # a5 #205
	var player_cfg: Dictionary = WIDataRegistry.scene_config()["player"]
	var pc_sprite := _pc_variant_sprite(String(player_cfg.get("sprite", "")))
	_player_visual = _make_entity_visual(
		Game.sim.player_cell,
		pc_sprite,
		player_cfg.get("tint", []),
		PLAYER_COLOR
	)
	_player_sprite = _first_sprite_child(_player_visual)
	_play_player_anim("idle")
	_count_visual(_player_visual, render_counts)
	_reconcile_pc_light()
	_reconcile_sneak_visual()
	_reconcile_ward_visuals()
	_reconcile_companion_visual()
	render_counts["pc_sprite"] = pc_sprite
	ObservableBus.emit_domain_event(WIEvents.UI_ENTITIES_RENDERED, render_counts)
	assert(_light_count <= LIGHT_BUDGET,
		"map %s exceeds the %d-light budget (%d) -- spec §5" % [Game.sim.current_map, LIGHT_BUDGET, _light_count])
	ObservableBus.emit_domain_event(WIEvents.UI_LIGHTS_RENDERED, {"map": Game.sim.current_map, "count": _light_count})
	_build_ambience()
	_update_camera()


func _rebuild_field_after_transition() -> void:
	# TRAP (ORDER): mood BEFORE rebuild — _rebuild_field emits ui_map_rendered,
	# and scripts pin ui_mood_applied preceding it; swapping paints one frame of
	# the new field under the old map's grade. atmosphere.gd must never re-add
	# its own MAP_CHANGED listener (this call IS the map-crossing mood apply).
	_atmosphere.apply_map(Game.sim.current_map, _atmosphere.phase_now())
	_rebuild_field()


func _map_transition_stale_cover() -> bool:
	return _main != null and _main.map_transition_stale_cover()


## Floor stack: skirt -> base -> overlays -> walls -> fallback blocked tiles ->
## Y-sorted biome props/decor/entities. Segment and cover_skip cells own their
## art; generic covers must never double-draw them.
func _build_floor() -> void:
	var biome: Dictionary = _biome_for_current_map()
	var map_cfg: Dictionary = _current_map_cfg()
	var grid_size := Game.sim.grid_size
	WITileBoardBuilder.build_skirt(_field_root, grid_size, SKIRT_MARGIN_CELLS, biome, WISpriteRegistry)
	var tile_px := int(biome["tile_px"])
	var floor_layer := WITileBoardBuilder.make_tile_layer(_field_root, String(biome["sheet"]), tile_px, WISpriteRegistry)
	var floor_coord := Vector2i(int(biome["floor"][0]), int(biome["floor"][1]))
	for x in grid_size.x:
		for y in grid_size.y:
			floor_layer.set_cell(Vector2i(x, y), 0, floor_coord)
	_field_root.add_child(floor_layer)
	WITileBoardBuilder.build_floor_layers(_field_root, map_cfg.get("floor_layers", []), grid_size, biome, WISpriteRegistry)
	var segment_covered := WITileBoardBuilder.build_walls(_field_root, map_cfg.get("walls", {}), grid_size, biome, WISpriteRegistry)

	var cover_skip := {}
	for c: Array in (map_cfg.get("cover_skip", []) as Array):
		cover_skip[Vector2i(int(c[0]), int(c[1]))] = true
	var authored_covered := WITileBoardBuilder.field_authored_cover_cells(map_cfg)
	var pool: Array = biome.get("blocked_props", [])
	var render_plan := WITileBoardBuilder.field_blocked_render_plan(
		Game.sim.current_map, Game.sim.blocked_cells, segment_covered, cover_skip, authored_covered, pool
	)
	var prop_plan: Dictionary = render_plan["props"]
	var fallback_cells: Array = render_plan["fallback"]
	for raw_cell: Variant in prop_plan.keys():
		var cell := raw_cell as Vector2i
		if not WISpriteRegistry.has_sprite(String(prop_plan[cell])):
			prop_plan.erase(cell)
			fallback_cells.append(cell)
	var cover_skip_errors := WITileBoardBuilder.cover_skip_errors(
		Game.sim.blocked_cells, segment_covered, cover_skip, authored_covered, prop_plan
	)
	assert(cover_skip_errors.is_empty(),
		"map %s invalid cover_skip: %s" % [Game.sim.current_map, "; ".join(cover_skip_errors)])
	assert(prop_plan.size() <= FIELD_BLOCKED_PROP_BUDGET,
		"map %s exceeds the %d blocked-prop budget (%d)" % [Game.sim.current_map, FIELD_BLOCKED_PROP_BUDGET, prop_plan.size()])
	_field_blocked_prop_plan = prop_plan
	if not fallback_cells.is_empty():
		var blocked_sheet := String(biome.get("blocked_sheet", biome["sheet"]))
		var blocked_tile_px := int(biome.get("blocked_tile_px", tile_px))
		var blocked_layer := WITileBoardBuilder.make_tile_layer(_field_root, blocked_sheet, blocked_tile_px, WISpriteRegistry)
		var blocked_coord := Vector2i(int(biome["blocked"][0]), int(biome["blocked"][1]))
		for cell: Vector2i in fallback_cells:
			blocked_layer.set_cell(cell, 0, blocked_coord)
		_field_root.add_child(blocked_layer)
	ObservableBus.emit_domain_event(WIEvents.UI_MAP_RENDERED, {
		"map": Game.sim.current_map,
		"floor_cells": grid_size.x * grid_size.y,
		"blocked_cells": Game.sim.blocked_cells.size(),
	})


func _build_field_blocked_props() -> void:
	for cell: Vector2i in _field_blocked_prop_plan:
		var sprite_id := String(_field_blocked_prop_plan[cell])
		_entities_root.add_child(_visual_factory.make_blocked_prop(cell, sprite_id))


func _build_water_shimmer() -> void:
	var walls_cfg: Dictionary = _current_map_cfg().get("walls", {})
	var segments: Array = walls_cfg.get("segments", [])
	var overlay: TileMapLayer
	var painted := false
	for raw_seg: Variant in segments:
		if not (raw_seg is Dictionary):
			continue
		var seg := raw_seg as Dictionary
		if String(seg.get("sheet", "")) != WATER_SHEET:
			continue
		var cells: Array[Vector2i] = WIGame.segment_cells(seg)
		if cells.is_empty():
			continue
		if overlay == null:
			var tile_px := int(seg.get("tile_px", 16))
			overlay = WITileBoardBuilder.make_tile_layer(_field_root, WATER_SHEET, tile_px, WISpriteRegistry)
			var mat := ShaderMaterial.new()
			mat.shader = WATER_SHIMMER_SHADER
			overlay.material = mat
		var cap_raw: Array = seg.get("cap", [1, 5])
		var coord := Vector2i(int(cap_raw[0]), int(cap_raw[1]))
		for cell: Vector2i in cells:
			overlay.set_cell(cell, 0, coord)
		painted = true
	if overlay == null:
		return
	if painted:
		_field_root.add_child(overlay)
	else:
		overlay.queue_free()


func _build_ice_overlay() -> void:
	var frozen: Array = Game.sim.frozen_cells_json().get(Game.sim.current_map, [])
	for pair: Variant in frozen:
		if pair is Array and (pair as Array).size() == 2:
			_paint_ice_cell(Vector2i(int(pair[0]), int(pair[1])))


func _paint_ice_cell(cell: Vector2i) -> void:
	if _ice_overlay == null:
		_ice_overlay = WITileBoardBuilder.make_tile_layer(_field_root, WATER_SHEET, 16, WISpriteRegistry)
		_ice_overlay.modulate = ICE_TINT
		_ice_overlay.z_index = 1
		_field_root.add_child(_ice_overlay)
	_ice_overlay.set_cell(cell, 0, ICE_CAP_COORD)


func _reconcile_ice_overlay() -> void:
	if _ice_overlay != null:
		_ice_overlay.queue_free()
		_ice_overlay = null
	_build_ice_overlay()


func _spawn_burn_poof(cell: Vector2i) -> void:
	if _presentation_delay(1.0) <= 0.0 or _field_root == null:
		return
	var rect := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))
	var poof := WIAmbience.make("hit_sparks", rect)
	if poof == null:
		return
	poof.z_index = 30
	poof.emitting = true
	_field_root.add_child(poof)
	get_tree().create_timer(0.7).timeout.connect(poof.queue_free)


## Renders `decor` entries: unlabeled, non-blocking set-
## dressing sprites via the same sprite-registry path as entities, added to
## the Y-sorted `_entities_root` (never counted in `ui_entities_rendered` --
## that payload stays scoped to real entities per the design doc's
## "payloads unchanged" contract).
func _build_decor(decor_list: Array) -> void:
	for raw: Variant in decor_list:
		if not (raw is Dictionary):
			continue
		var entry := raw as Dictionary
		var sprite_id := String(entry.get("sprite", ""))
		if sprite_id == "" or not WISpriteRegistry.has_sprite(sprite_id):
			continue
		var cell := Vector2i(int(entry["cell"][0]), int(entry["cell"][1]))
		_make_entity_visual(cell, sprite_id, entry.get("tint", []), PROP_COLOR, "", entry.get("light", {}), bool(entry.get("sway", false)))


func _build_scatter(specs: Array) -> void:
	if specs.is_empty():
		return
	var grid_size := Game.sim.grid_size
	var occupied := {}
	for e_id: String in Game.sim.entities:
		occupied[(Game.sim.entities[e_id] as Dictionary)["cell"]] = true
	for raw: Variant in specs:
		if not (raw is Dictionary):
			continue
		var spec := raw as Dictionary
		var pool: Array = spec.get("pool", [])
		if pool.is_empty():
			continue
		var density := clampf(float(spec.get("density", 0.05)), 0.0, 1.0)
		var cluster := clampf(float(spec.get("cluster", 0.6)), 0.0, 1.0)
		var seed_v := int(spec.get("seed", 1))
		# Sway is tagged per SPEC (pool), not per sprite id
		# within the pool -- a spec whose pool mixes foliage with a
		# non-foliage prop (floodplains' grass_tuft/pebble/flower_tiny spec)
		# would need re-seeding to split cleanly, which would shift WHICH
		# cells host which prop and break the "all else identical" day-shot
		# contract; at this shader's subtle default amplitude the effect on
		# the few non-foliage instances in a mixed pool is imperceptible in
		# practice.
		var sway := bool(spec.get("sway", false))
		for x in grid_size.x:
			for y in grid_size.y:
				var cell := Vector2i(x, y)
				if Game.sim.is_cell_blocked(cell) or occupied.has(cell) or cell == Game.sim.player_cell:
					continue
				var block := Vector2i(x / 4, y / 4)
				var block_hot := _scatter_hash(seed_v, block, 101) < 0.3
				var boost := (1.0 + 2.0 * cluster) if block_hot else (1.0 - cluster)
				if _scatter_hash(seed_v, cell, 7) >= density * boost:
					continue
				var pick: Variant = pool[int(_scatter_hash(seed_v, cell, 31) * pool.size()) % pool.size()]
				var sprite_id := String(pick)
				if WISpriteRegistry.has_sprite(sprite_id):
					_make_entity_visual(cell, sprite_id, spec.get("tint", []), PROP_COLOR, "", {}, sway)


static func _scatter_hash(seed_v: int, cell: Vector2i, salt: int) -> float:
	var h := hash(Vector3i(cell.x * 73856093, cell.y * 19349663, seed_v * 83492791 + salt))
	return float(h & 0xFFFFFF) / float(0x1000000)


func _biome_for_current_map() -> Dictionary:
	var biomes := WIDataRegistry.biomes()
	var map_cfg: Dictionary = _current_map_cfg()
	var biome_id := String(map_cfg.get("biome", "inn"))
	assert(biomes.has(biome_id), "unknown map biome: " + biome_id)
	return biomes[biome_id]


func _current_map_cfg() -> Dictionary:
	var maps: Dictionary = WIDataRegistry.scene_config()["maps"]
	return maps[Game.sim.current_map]


func _update_camera() -> void:
	# Camera math + pan tween live in WICameraController (#194b seam 2);
	# wrappers keep the sim reads and QA-paced duration world-side.
	_camera_ctl.update(Game.sim.grid_size, Game.sim.player_cell)


func _pan_camera_to_player() -> void:
	_camera_ctl.pan_to(Game.sim.grid_size, Game.sim.player_cell, _presentation_delay(MOVE_TWEEN_SECONDS))


func combat_board_root() -> Node2D:
	if _combat_board_root == null:
		_combat_board_root = Node2D.new()
		_combat_board_root.name = "CombatBoardRoot"
		_combat_board_root.visible = false
		add_child(_combat_board_root)
	return _combat_board_root


func enter_combat_camera(grid_size: Vector2i) -> void:
	_camera_ctl.enter_combat(grid_size)


func exit_combat_camera() -> void:
	_update_camera()


## a5 #205: brighten field interactable sprites on dark-mood maps so
## encounters/props/NPCs stay separable from the floor before [Light] (the
## floor/mood grade is untouched — only these entity holders' self_modulate
## lifts, mirroring the combat board's own legibility floor). Boost = 1.0 is
## a no-op on bright maps, so their render is byte-identical. Re-runs on
## every UI_MOOD_APPLIED, so a dusk->night darkening re-lifts automatically.
func _apply_field_legibility() -> void:
	if _atmosphere == null:
		return
	# holder.modulate (NOT self_modulate — the holder draws nothing; modulate
	# INHERITS to the sprite/ColorRect/shadow children and composes with the
	# sprite's own tint, exactly as the combat board's leaf-node boost does).
	var boost := _atmosphere.field_entity_boost()
	var m := Color(boost, boost, boost, 1.0)
	for id: String in _entity_visuals.keys():
		var holder := _entity_visuals[id] as Node2D
		if holder != null:
			holder.modulate = m


func _build_entities() -> Array[Node2D]:
	var visuals: Array[Node2D] = []
	for ent: Dictionary in Game.sim.entities.values():
		if bool(ent.get("hide_sprite", false)):
			continue
		if not Game.sim.entity_present(ent):
			continue
		var color := NPC_COLOR if String(ent["kind"]) == "npc" else PROP_COLOR
		var render := _resolve_entity_render(ent)
		var visual := _make_entity_visual(
			ent["cell"],
			String(render["sprite"]),
			render["tint"],
			color,
			String(ent.get("facing", "")),
			render["light"],
			false,
			ent.get("field_y_sort_bias_px", null)
		)
		visual.visible = not bool(render["hidden"])
		_entity_visuals[String(ent["id"])] = visual
		visuals.append(visual)
	return visuals


## Resolves a `prop`/`npc` entity's CURRENT
## sprite/tint/light against its optional `visual_states` list -- state
## change on interaction must SHOW without a label now that field name tags
## are gone (dirty_table/inn_chest/unlit_lantern are the shipped cases; see
## `_visual_state_active`). Each `visual_states` entry is `{when: {...},
## sprite?, tint?, light?}`; entries are evaluated in list order and a LATER
## satisfied entry overrides an earlier one's fields (ascending-threshold
## authoring convention, same idiom as classes.json level tables), so a
## still-unmet entry never masks the base/earlier look. Used both by the
## initial `_build_entities()` build (a loaded save with the counter already
## past threshold must render the post-state immediately, not the base dirty
## look) and by `_refresh_entity_visual`'s live re-render on the owning
## counter's change.
func _resolve_entity_render(ent: Dictionary) -> Dictionary:
	var result := {
		"sprite": String(ent.get("sprite", "")),
		"tint": ent.get("tint", []),
		"light": ent.get("light", {}),
		"hidden": false,
	}
	for raw: Variant in ent.get("visual_states", []):
		if not (raw is Dictionary):
			continue
		var state := raw as Dictionary
		if not _visual_state_active(state.get("when", {}), String(ent.get("id", ""))):
			continue
		if state.has("sprite"):
			result["sprite"] = String(state["sprite"])
		if state.has("tint"):
			result["tint"] = state["tint"]
		if state.has("light"):
			result["light"] = state["light"]
		if state.has("hidden"):
			result["hidden"] = bool(state["hidden"])
	return result


func _visual_state_active(when: Dictionary, entity_id: String) -> bool:
	if when.has("counter"):
		return Game.sim.accomplishment_count(String(when["counter"])) >= int(when.get("at", 1))
	if when.has("container_opened"):
		return bool(Game.sim.container_state.get(entity_id, false))
	if when.has("dormant"):
		return Game.sim.dormant_encounters.has(entity_id) == bool(when["dormant"])
	if when.has("phase"):
		return (when["phase"] as Array).has(Game.sim.phase())
	return false


func _refresh_entity_visual(id: String) -> void:
	if not Game.sim.entities.has(id):
		return
	var ent: Dictionary = Game.sim.entities[id]
	if (ent.get("visual_states", []) as Array).is_empty():
		return
	var old_visual: Node2D = _entity_visuals.get(id, null)
	if old_visual == null or not is_instance_valid(old_visual):
		return
	var cell := Vector2i(int(ent["cell"][0]), int(ent["cell"][1]))
	var color := NPC_COLOR if String(ent["kind"]) == "npc" else PROP_COLOR
	var render := _resolve_entity_render(ent)
	for child: Node in old_visual.get_children():
		if child is PointLight2D:
			_atmosphere.unregister_light(child as PointLight2D)
			_light_count -= 1
	old_visual.queue_free()
	var new_visual := _make_entity_visual(cell, String(render["sprite"]), render["tint"], color, String(ent.get("facing", "")), render["light"], false, ent.get("field_y_sort_bias_px", null))
	new_visual.visible = not bool(render["hidden"])
	_entity_visuals[id] = new_visual
	assert(_light_count <= LIGHT_BUDGET,
		"map %s exceeds the %d-light budget (%d) after a visual_states refresh -- spec §5" % [Game.sim.current_map, LIGHT_BUDGET, _light_count])


func _refresh_entities_watching_counter(counter_name: String) -> void:
	if counter_name == "":
		return
	for id: String in _entity_visuals.keys():
		var raw_ent: Variant = Game.sim.entities.get(id, null)
		if raw_ent == null:
			continue
		var ent := raw_ent as Dictionary
		for raw_state: Variant in ent.get("visual_states", []):
			if raw_state is Dictionary and String((raw_state as Dictionary).get("when", {}).get("counter", "")) == counter_name:
				_refresh_entity_visual(id)
				break


func _refresh_entities_watching_phase() -> void:
	for id: String in _entity_visuals.keys():
		var raw_ent: Variant = Game.sim.entities.get(id, null)
		if raw_ent == null:
			continue
		for raw_state: Variant in (raw_ent as Dictionary).get("visual_states", []):
			if raw_state is Dictionary and (raw_state as Dictionary).get("when", {}).has("phase"):
				_refresh_entity_visual(id)
				break


## v0.15 T4.3 round 2 — THE DIALOGUE DEFER, and the reason the whole Horns
## bilocation split became possible. `_reconcile_entity_presence` runs on every
## ACCOMPLISHMENT_RECORDED, so a counter banked by a dialogue OPTION used to free
## presence-gated visuals mid-conversation: the speaker, or anyone standing
## beside her, popping off-screen between two lines (VISUAL-LOG RUIN/CAMP-DOUBLE,
## photographed P1). v0.14 worked around it by moving every affected gate onto a
## LATER counter, which bought the pop off at the price of a three-copies window.
## The rebuild is now QUEUED while a conversation is open and flushed once at
## DIALOGUE_ENDED, so gates may key on whatever the fiction wants.
##  * ONE flag: "is a dialogue open" is read straight off the sim
##    (`Game.sim.dialogue`), never mirrored here, so the two can't drift.
##  * EXACTLY ONCE: a conversation banking six counters queues one rebuild,
##    not six -- the flag is a latch, not a counter.
##  * EVENT-ORDER, load-bearing: `dialogue_choose` nulls `dialogue` BEFORE
##    applying an `end: true` option's effects (wi_game.gd), so a closing
##    option's banks arrive with the latch down and reconcile immediately.
##    That is correct -- the conversation is already over.
##  * PHASE_CHANGED's own reconcile is deliberately NOT deferred: `_tick_action`
##    fires only from move/interact/use_skill_field, never from dialogue_choose,
##    so a phase crossing cannot happen inside a conversation.
##  * A full `_rebuild_field` supersedes any queued reconcile and drops the
##    latch, so a map crossing mid-conversation can't emit a stray second
##    ui_entities_rendered afterwards.
var _presence_reconcile_deferred := false


## `finished` is load-bearing, not belt-and-braces: WIDialogue sets it on the
## terminal node and `dialogue_choose` only NULLS the walker on an `end: true`
## option. A graph that runs out of options any other way leaves a finished
## walker parked on `Game.sim.dialogue`, and a bare null check would defer every
## reconcile after it FOREVER (nothing else flushes the latch until a rebuild).
func _dialogue_is_open() -> bool:
	return Game.sim != null and Game.sim.dialogue != null and not Game.sim.dialogue.finished


func _reconcile_entity_presence_or_defer() -> void:
	if _dialogue_is_open():
		_presence_reconcile_deferred = true
		return
	_reconcile_entity_presence()


func _flush_deferred_presence_reconcile() -> void:
	if not _presence_reconcile_deferred:
		return
	# The #119 stale-cover contract the ACCOMPLISHMENT_RECORDED arm already
	# carries: reconciling against geometry the cover is about to replace is
	# pointless. Leave the latch UP -- `_rebuild_field` drops it after
	# reconstructing every visual from live sim, so nothing is lost. Reachable
	# once a dialogue option can travel (a `travel_to` close would end the
	# conversation and start a transition in the same frame).
	if _map_transition_stale_cover():
		return
	_presence_reconcile_deferred = false
	_reconcile_entity_presence()


func _reconcile_entity_presence() -> void:
	var changed := false
	for id: String in Game.sim.entities.keys():
		var ent: Dictionary = Game.sim.entities[id]
		# hide_sprite guard matches _build_entities': a visual-less entity
		# must never gain a phantom twin on a phase flip.
		if not ent.has("present_when") or bool(ent.get("hide_sprite", false)):
			continue
		var present := Game.sim.entity_present(ent)
		if present == _entity_visuals.has(id):
			continue
		changed = true
		if present:
			var color := NPC_COLOR if String(ent["kind"]) == "npc" else PROP_COLOR
			var render := _resolve_entity_render(ent)
			var visual := _make_entity_visual(ent["cell"], String(render["sprite"]), render["tint"], color, String(ent.get("facing", "")), render["light"], false, ent.get("field_y_sort_bias_px", null))
			visual.visible = not bool(render["hidden"])
			_entity_visuals[id] = visual
		else:
			var old_visual := _entity_visuals[id] as Node2D
			for child: Node in old_visual.get_children():
				if child is PointLight2D:
					_atmosphere.unregister_light(child as PointLight2D)
					_light_count -= 1
			old_visual.queue_free()
			_entity_visuals.erase(id)
	if changed:
		_apply_field_legibility()  # a5 #205: lift any newly-present interactable
		assert(_light_count <= LIGHT_BUDGET,
			"map %s exceeds the %d-light budget (%d) after a presence reconcile -- spec §5" % [Game.sim.current_map, LIGHT_BUDGET, _light_count])
		var render_counts := {"sprites": 0, "fallbacks": 0}
		_count_visual(_entity_visuals.values(), render_counts)
		_count_visual(_player_visual, render_counts)
		ObservableBus.emit_domain_event(WIEvents.UI_ENTITIES_RENDERED, render_counts)


## After combat ends and the field re-shows (UI_COMBAT_HIDDEN,
## which does NOT rebuild the map), re-render any on-map entity whose
## `visual_states` watch the `dormant` flag -- a just-defeated `respawns: true`
## encounter must switch to its "resting/cleared" look without waiting for a
## map change. The re-arm at the sleep beat needs no hook here: sleep clears
## `dormant_encounters` on a different map (the inn bed), and the encounter's
## map is rebuilt by `_rebuild_field` on the next MAP_CHANGED, which re-resolves
## the (now live) look.
func _refresh_entities_watching_dormant() -> void:
	for id: String in _entity_visuals.keys():
		var raw_ent: Variant = Game.sim.entities.get(id, null)
		if raw_ent == null:
			continue
		for raw_state: Variant in (raw_ent as Dictionary).get("visual_states", []):
			if raw_state is Dictionary and (raw_state as Dictionary).get("when", {}).has("dormant"):
				_refresh_entity_visual(id)
				break


func _pc_variant_sprite(default_id: String) -> String:
	var key := Game.sim.pc_sprite_variant()
	return key if WISpriteRegistry.has_sprite(key) else default_id


func _make_entity_visual(
	cell: Vector2i,
	sprite_id: String,
	tint: Variant,
	fallback_color: Color = PROP_COLOR,
	facing: String = "",
	light: Dictionary = {},
	sway: bool = false,
	field_y_sort_bias_override: Variant = null,
) -> Node2D:
	# Construction lives in WIEntityVisualFactory (#194b seam 1); this wrapper
	# owns what needs World state: light spawning (_atmosphere/_light_count)
	# and the attach into _entities_root. Call sites unchanged.
	var holder := _visual_factory.make(cell, sprite_id, tint, fallback_color, facing, sway, field_y_sort_bias_override)
	if not light.is_empty():
		_spawn_light(holder, light)
	_entities_root.add_child(holder)
	return holder


func _spawn_light(holder: Node2D, light: Dictionary) -> void:
	var color_arr: Variant = light.get("color", [1.0, 1.0, 1.0])
	assert(color_arr is Array and (color_arr as Array).size() == 3,
		"light entry needs a 3-component color: " + str(light))
	var energy := float(light.get("energy", 1.0))
	var radius := int(light.get("radius", 32))
	var flicker := bool(light.get("flicker", false))
	var pl := PointLight2D.new()
	pl.texture = LIGHT_TEXTURE
	pl.color = Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]))
	pl.texture_scale = (radius * 2.0) / LIGHT_TEXTURE_PX
	pl.position = Vector2(CELL, CELL) * 0.5
	holder.add_child(pl)
	_atmosphere.register_light(pl, energy, flicker)
	_light_count += 1


func _reconcile_pc_light() -> void:
	var want := Game.sim.light_active
	var have := is_instance_valid(_pc_light)
	if want == have:
		return
	if want:
		_attach_pc_light()
	else:
		_detach_pc_light()
	ObservableBus.emit_domain_event(WIEvents.UI_PC_LIGHT_RENDERED, {"active": want})


## Brings the PC sprite's alpha into agreement with the
## sim's authoritative `sneaking` flag -- the SAME want/have reconcile idiom
## as `_reconcile_pc_light` just above (`_sneak_tinted` standing in for
## `is_instance_valid(_pc_light)`, since translucency has no child node to
## test). No-ops (no re-tint, no re-emit) once they already match, so a
## dusk/night PHASE_CHANGED crossing while not sneaking is silent. Called
## from three places, mirroring `_reconcile_pc_light`'s three call sites:
## `_rebuild_field` (a door crossing KEEPS `sneaking` true per the plan, so
## the translucency must survive the new map's fresh `_player_sprite` --
## `_sneak_tinted` is reset false there for exactly this reason), the
## SNEAK_STARTED/SNEAK_ENDED hook (every toggle and every automatic break),
## and PHASE_CHANGED (sleep silently clears `sneaking`, same as light_active/
## frozen_cells -- no dedicated toast/event, just the flag drop -- so this is
## the only hook that catches the sleep-clear). Alpha/shimmer come from the
## active sneak skill's own `sneak_visual` data (`_sneak_active_skill`, see
## that var's doc comment), defaulting to SNEAK_ALPHA/no-shimmer.
func _reconcile_sneak_visual() -> void:
	if _player_sprite == null:
		return
	var want := Game.sim.sneaking
	if want == _sneak_tinted:
		return
	var visual: Dictionary = Game.sim.skills.get(_sneak_active_skill, {}).get("sneak_visual", {}) if want else {}
	var alpha: float = float(visual.get("alpha", SNEAK_ALPHA)) if want else 1.0
	var shimmer: bool = want and bool(visual.get("shimmer", false))
	_player_sprite.modulate.a = alpha
	_player_sprite.material = _sneak_shimmer_material if shimmer else null
	_sneak_tinted = want
	ObservableBus.emit_domain_event(WIEvents.UI_SNEAK_RENDERED, {"active": want, "alpha": alpha, "shimmer": shimmer})


func _attach_pc_light() -> void:
	if _player_visual == null:
		return
	var pl := PointLight2D.new()
	pl.texture = LIGHT_TEXTURE
	pl.color = PC_LIGHT_COLOR
	pl.energy = PC_LIGHT_ENERGY
	pl.texture_scale = (PC_LIGHT_RADIUS * 2.0) / LIGHT_TEXTURE_PX
	pl.position = Vector2(CELL, CELL) * 0.5
	_player_visual.add_child(pl)
	_pc_light = pl


func _detach_pc_light() -> void:
	if is_instance_valid(_pc_light):
		_pc_light.queue_free()
	_pc_light = null


func _build_ambience() -> void:
	for raw: Variant in _current_map_cfg().get("ambience", []):
		if not (raw is Dictionary):
			continue
		var spec := raw as Dictionary
		var preset := String(spec.get("preset", ""))
		if preset == "":
			continue
		var rect := _resolve_ambience_rect(spec.get("rect", "all"))
		var node := WIAmbience.make(preset, rect)
		_field_root.add_child(node)
		_atmosphere.register_emitter(node, spec.get("phase", []))
		_ambience_count += 1
	assert(_ambience_count <= AMBIENCE_BUDGET,
		"map %s exceeds the %d-emitter budget (%d) -- spec §5" % [Game.sim.current_map, AMBIENCE_BUDGET, _ambience_count])
	ObservableBus.emit_domain_event(WIEvents.UI_AMBIENCE_RENDERED, {"map": Game.sim.current_map, "emitters": _ambience_count})


func _resolve_ambience_rect(rect_spec: Variant) -> Rect2:
	if rect_spec is String and rect_spec == "all":
		return Rect2(Vector2.ZERO, Vector2(Game.sim.grid_size) * CELL)
	var r: Array = rect_spec
	return Rect2(Vector2(int(r[0]), int(r[1])) * CELL, Vector2(int(r[2]), int(r[3])) * CELL)


func _count_visual(visual: Variant, render_counts: Dictionary) -> void:
	if visual is Array:
		for child_visual: Node2D in visual:
			_count_visual(child_visual, render_counts)
		return
	var holder := visual as Node2D
	if holder == null:
		return
	var key := "sprites" if bool(holder.get_meta("uses_sprite", false)) else "fallbacks"
	render_counts[key] = int(render_counts[key]) + 1


func _first_sprite_child(holder: Node2D) -> AnimatedSprite2D:
	for child: Node in holder.get_children():
		if child is AnimatedSprite2D:
			return child as AnimatedSprite2D
	return null


func _play_player_anim(prefix: String) -> void:
	if _player_sprite == null or _player_sprite.sprite_frames == null:
		return
	var facing := Game.sim.player_facing
	var suffix := "down"
	if facing == Vector2i.UP:
		suffix = "up"
	elif facing == Vector2i.LEFT or facing == Vector2i.RIGHT:
		suffix = "side"
	_player_sprite.flip_h = facing == Vector2i.LEFT
	var anim := "%s_%s" % [prefix, suffix]
	if not _player_sprite.sprite_frames.has_animation(anim):
		anim = prefix if _player_sprite.sprite_frames.has_animation(prefix) else "idle"
	if _player_sprite.sprite_frames.has_animation(anim):
		_player_sprite.play(anim)


func _queue_player_idle() -> void:
	_player_anim_token += 1
	var token := _player_anim_token
	get_tree().create_timer(0.18).timeout.connect(func() -> void:
		if token == _player_anim_token:
			_play_player_anim("idle")
	)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if type == WIEvents.PLAYER_MOVED:
		var cell := Vector2i(int(payload["cell"][0]), int(payload["cell"][1]))
		_move_companion_visual(_player_visual.position)
		_move_player_visual(Vector2(cell) * CELL)
		_play_player_anim("walk")
		_queue_player_idle()
		_pan_camera_to_player()
	elif type == WIEvents.PLAYER_BLOCKED:
		_bump_player_visual()
	elif type == WIEvents.PLAYER_TELEPORTED:
		var from_cell := Vector2i(int(payload["from"][0]), int(payload["from"][1]))
		var to_cell := Vector2i(int(payload["to"][0]), int(payload["to"][1]))
		_move_companion_visual(Vector2(from_cell) * CELL)
		_kill_player_tween()
		_player_visual.position = Vector2(to_cell) * CELL
		_render_blink_afterimage(from_cell, to_cell)
		_play_player_anim("idle")
		_pan_camera_to_player()
	elif type == WIEvents.MAP_CHANGED:
		if _main != null:
			_main.transition_map(_rebuild_field_after_transition)
		else:
			_rebuild_field_after_transition()
	elif type == WIEvents.ENTITY_REMOVED:
		if _map_transition_stale_cover():
			return
		var visual: Node2D = _entity_visuals.get(String(payload["id"]))
		if visual != null:
			visual.queue_free()
			_entity_visuals.erase(String(payload["id"]))
	elif type == WIEvents.COMBAT_STARTED:
		_field_root.visible = false
	elif type == WIEvents.UI_COMBAT_HIDDEN:
		_field_root.visible = true
		_refresh_entities_watching_dormant()
	elif type == WIEvents.ACCOMPLISHMENT_RECORDED:
		# CONTRACT (#119, stale-cover guard — stated once here, shared by the
		# ENTITY_REMOVED/ITEM_GAINED/PHASE_CHANGED arms): while the transition
		# cover hides a STALE field (pre-rebuild), skipping is drop-free — the
		# imminent rebuild reconstructs every visual from live sim. Post-rebuild
		# events reconcile normally against the new field. Guarding the WHOLE
		# transition (the old shape) silently dropped post-rebuild refreshes.
		if _map_transition_stale_cover():
			return
		_refresh_entities_watching_counter(String(payload.get("id", "")))
		_reconcile_entity_presence_or_defer()
	elif type == WIEvents.DIALOGUE_ENDED:
		# The defer's flush point -- see _presence_reconcile_deferred's contract.
		_flush_deferred_presence_reconcile()
	elif type == WIEvents.ITEM_GAINED:
		if _map_transition_stale_cover():
			return
		var source_id := String(payload.get("source", ""))
		if source_id != "":
			call_deferred("_refresh_entity_visual", source_id)
	elif type == WIEvents.SKILL_USED:
		var used_skill := String(payload.get("skill", ""))
		if used_skill == "light":
			_reconcile_pc_light()
		# Remember WHICH `sneaks: true`-tagged skill just
		# toggled `sneaking` ON, for `_reconcile_sneak_visual`'s data-driven
		# look-up below -- presentation-only memory, see
		# `_sneak_active_skill`'s own doc comment. ORDER TRAP: `_toggle_sneak`
		# flips `sneaking` BEFORE emitting skill_used (then
		# sneak_started/ended right after), so `Game.sim.sneaking` here
		# already carries the POST-toggle value -- true only on a toggle-ON
		# press (a toggle-OFF press of ANY tagged skill leaves the last-ON
		# skill's id in place, harmlessly unread while not sneaking).
		if Game.sim.sneaking and bool(Game.sim.skills.get(used_skill, {}).get("sneaks", false)):
			_sneak_active_skill = used_skill
	elif type == WIEvents.SNEAK_STARTED or type == WIEvents.SNEAK_ENDED:
		_reconcile_sneak_visual()
	elif type == WIEvents.WARD_PLACED:
		_reconcile_ward_visuals()
	elif type == WIEvents.COMPANION_CHANGED:
		_reconcile_companion_visual()
	elif type == WIEvents.UI_MOOD_APPLIED:
		# Mood grade just landed (fresh map or a phase crossing) — re-lift the
		# field interactables against the new darkness (a5 #205). Skip while a
		# map transition still covers stale geometry, and while combat holds
		# an arena override (those field entities are hidden — the
		# UI_COMBAT_HIDDEN re-show re-applies).
		if not _map_transition_stale_cover() and Game.sim.combat == null:
			_apply_field_legibility()
	elif type == WIEvents.PHASE_CHANGED:
		if _map_transition_stale_cover():
			return
		_reconcile_pc_light()
		_reconcile_sneak_visual()
		_reconcile_ice_overlay()
		_reconcile_ward_visuals()
		_reconcile_companion_visual()
		# 8b R1 (issue #10): the witch's two-form visual_states swap tracks
		# atmosphere.gd's own phase clock live -- this fires on every
		# crossing AND the sleep-to-day reset, so the elder/young read is
		# never stale after a map reload OR mid-waking (danger list: "must
		# not fight atmosphere.gd's phase clock").
		_refresh_entities_watching_phase()
		# GH#104: the EXISTENCE half of the same reconciliation --
		# free/build present_when-gated visuals whose gate just
		# flipped, same-map, no MAP_CHANGED required (the ghost
		# `entity_present`'s doc comment used to disclose).
		_reconcile_entity_presence()
	elif type == WIEvents.TERRAIN_CHANGED:
		if String(payload.get("map", "")) == Game.sim.current_map:
			var tc_cell := Vector2i(int(payload["cell"][0]), int(payload["cell"][1]))
			match String(payload.get("to", "")):
				"ice":
					_paint_ice_cell(tc_cell)
				"scorched":
					_spawn_burn_poof(tc_cell)
	elif type in [WIEvents.WORLD_READY, WIEvents.CLASS_GAINED, WIEvents.CLASS_LEVEL_UP, WIEvents.CLASS_EVOLVED, WIEvents.LOADOUT_CHANGED, WIEvents.COMBAT_STARTED, WIEvents.DIALOGUE_STARTED]:
		# The first five are exactly the events
		# `field_hotbar.gd`'s `_render()` re-derives the slot LIST on -- the
		# pad cursor here must reset alongside it (a stale index could point
		# past a shrunk list, or at a now-different skill on a same-size one).
		_disarm_field_slot()


func _move_player_visual(target: Vector2) -> void:
	_kill_player_tween()
	var duration := _presentation_delay(MOVE_TWEEN_SECONDS)
	if duration <= 0.0:
		_player_visual.position = target
		return
	_player_tween = create_tween()
	_player_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_player_tween.tween_property(_player_visual, "position", target, duration)
	_player_tween.finished.connect(_on_move_tween_finished)


func _move_companion_visual(target: Vector2) -> void:
	if _companion_visual == null or not is_instance_valid(_companion_visual):
		return
	var duration := _presentation_delay(MOVE_TWEEN_SECONDS)
	if duration <= 0.0 or WISettings.reduce_motion():
		_companion_visual.position = target
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_companion_visual, "position", target, duration)


func _render_blink_afterimage(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var reduced := WISettings.reduce_motion()
	ObservableBus.emit_domain_event(WIEvents.UI_TELEPORT_RENDERED, {
		"from": [from_cell.x, from_cell.y],
		"to": [to_cell.x, to_cell.y],
		"reduced_motion": reduced,
	})
	if reduced:
		return
	var streak := Line2D.new()
	streak.width = 3.0
	streak.default_color = Color(0.62, 0.82, 1.0, 0.72)
	var from_pos := Vector2(from_cell) * CELL + Vector2(CELL, CELL) * 0.5
	var to_pos := Vector2(to_cell) * CELL + Vector2(CELL, CELL) * 0.5
	streak.position = from_pos
	streak.points = PackedVector2Array([
		Vector2.ZERO,
		to_pos - from_pos,
	])
	_entities_root.add_child(streak)
	var qa_visual_hold: bool = DisplayServer.get_name() != "headless" \
		and TestDriver != null and TestDriver.active() \
		and QAPaths.user_args().get("blink-visual", "") == "1"
	if qa_visual_hold:
		# Freeze opt-in evidence; screenshot settling outlives transient cleanup.
		# Scene teardown owns this QA-only streak. Gameplay still fades below.
		return
	if _presentation_delay(0.18) <= 0.0:
		streak.call_deferred("queue_free")
		return
	var tween := create_tween()
	tween.tween_property(streak, "modulate:a", 0.0, _presentation_delay(0.18))
	tween.finished.connect(streak.queue_free)


func _reconcile_ward_visuals() -> void:
	for visual: Node2D in _ward_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	_ward_visuals.clear()
	if _entities_root == null or Game.sim == null:
		return
	for encounter_id: String in Game.sim.warded_encounters:
		var ward: Dictionary = Game.sim.warded_encounters[encounter_id]
		if String(ward.get("map", "")) != Game.sim.current_map:
			continue
		var raw_cell: Array = ward.get("cell", [])
		if raw_cell.size() != 2:
			continue
		var cell := Vector2i(int(raw_cell[0]), int(raw_cell[1]))
		var holder := _make_entity_visual(
			cell, "icon_hearthward_charm", [], Color(0.96, 0.65, 0.25, 0.9)
		)
		var ring := Line2D.new()
		ring.width = 1.0
		ring.default_color = Color(1.0, 0.78, 0.35, 0.34)
		ring.closed = true
		var ring_points := PackedVector2Array()
		for point_index: int in 12:
			var angle := TAU * float(point_index) / 12.0
			ring_points.append(Vector2(8, 8) + Vector2(cos(angle), sin(angle)) * 7.0)
		ring.points = ring_points
		holder.add_child(ring)
		_ward_visuals.append(holder)
	ObservableBus.emit_domain_event(WIEvents.UI_WARD_RENDERED, {
		"map": Game.sim.current_map,
		"count": _ward_visuals.size(),
	})


func _reconcile_companion_visual() -> void:
	if _companion_visual != null and is_instance_valid(_companion_visual):
		_companion_visual.queue_free()
	_companion_visual = null
	if _entities_root == null or Game.sim == null or Game.sim.companion == "":
		ObservableBus.emit_domain_event(WIEvents.UI_COMPANION_RENDERED, {"active": false})
		return
	var trail_cell: Vector2i = Game.sim.player_cell - Game.sim.player_facing
	if trail_cell.x < 0 or trail_cell.y < 0 \
			or trail_cell.x >= Game.sim.grid_size.x or trail_cell.y >= Game.sim.grid_size.y:
		trail_cell = Game.sim.player_cell
	_companion_visual = _make_entity_visual(
		trail_cell, Game.sim.companion, [], Color(0.72, 0.76, 0.7)
	)
	ObservableBus.emit_domain_event(WIEvents.UI_COMPANION_RENDERED, {
		"active": true,
		"companion": Game.sim.companion,
	})


func _bump_player_visual() -> void:
	if _player_visual == null:
		return
	_play_player_anim("idle")
	var duration := _presentation_delay(BUMP_TWEEN_SECONDS)
	if duration <= 0.0:
		return
	_kill_player_tween()
	var home := Vector2(Game.sim.player_cell) * CELL
	_player_visual.position = home
	_player_tween = create_tween()
	_player_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_player_tween.tween_property(_player_visual, "position", home + Vector2(Game.sim.player_facing) * BUMP_PIXELS, duration)
	_player_tween.tween_property(_player_visual, "position", home, duration)


func _kill_player_tween() -> void:
	if _player_tween != null and _player_tween.is_valid():
		_player_tween.kill()


func _presentation_delay(seconds: float) -> float:
	if (TestDriver != null and TestDriver.active()) or DisplayServer.get_name() == "headless":
		return 0.0
	return seconds


func _held_move_direction() -> Vector2i:
	var facing := Game.sim.player_facing
	var dx := _held_axis("move_left", -1, "move_right", 1, facing.x)
	var dy := _held_axis("move_up", -1, "move_down", 1, facing.y)
	return Vector2i(dx, dy)


func _held_axis(neg_action: String, neg_val: int, pos_action: String, pos_val: int, facing_component: int) -> int:
	var neg_held := Input.is_action_pressed(neg_action)
	var pos_held := Input.is_action_pressed(pos_action)
	if neg_held and pos_held:
		return pos_val if facing_component == pos_val else neg_val
	if neg_held:
		return neg_val
	if pos_held:
		return pos_val
	return 0


## FIELD HELD-KEY MOVEMENT: fires once per
## real move-tween completion (see `_move_player_visual`'s `finished` connect
## just above it -- the QA/headless zero-duration branch never reaches that
## connect at all, so this callback structurally cannot fire during a
## TestDriver-driven run). The `TestDriver.active()` check below is
## belt-and-braces documentation of that same invariant, not the only thing
## preventing it: test_driver.gd's `_inject_action` parses a press THEN a
## release synchronously in the same call with no frame in between, so even
## if a tween somehow existed, `Input.is_action_pressed` would already read
## false for injected input by the time any real tween's duration (120ms)
## could elapse. Re-checks the exact same gate `_unhandled_input` uses
## (`_movement_gated`) so a panel/dialogue/combat opening mid-hold stops the
## repeat immediately rather than only at the next fresh keypress.
func _on_move_tween_finished() -> void:
	if _movement_gated():
		_click_path.clear()
		return
	if not _click_path.is_empty():
		_advance_click_path()
		return
	if TestDriver != null and TestDriver.active():
		return
	var dir := _held_move_direction()
	if dir == Vector2i.ZERO:
		return
	Game.sim.move_player(dir)


func handle_world_click(world_pos: Vector2) -> void:
	if _movement_gated():
		return
	var cell := Vector2i(floori(world_pos.x / CELL), floori(world_pos.y / CELL))
	var grid_size := Game.sim.grid_size
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return
	var target: Dictionary = Game.sim.entity_at(cell)
	if not target.is_empty():
		if _is_cardinal_adjacent(Game.sim.player_cell, cell):
			_click_path.clear()
			_face_cell(cell)
			_notify_action_taken()
			Game.sim.interact()
		else:
			_start_click_path_to_adjacent(cell)
		return
	if Game.sim.is_cell_blocked(cell):
		return
	_start_click_path(cell)


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _is_cardinal_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var delta := b - a
	return (absi(delta.x) == 1 and delta.y == 0) or (absi(delta.y) == 1 and delta.x == 0)


static func _facing_from_delta(delta: Vector2i) -> Vector2i:
	if delta == Vector2i.ZERO:
		return Vector2i.DOWN
	if absi(delta.x) >= absi(delta.y):
		return Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y > 0 else Vector2i.UP


func _face_cell(cell: Vector2i) -> void:
	Game.sim.player_facing = _facing_from_delta(cell - Game.sim.player_cell)
	_play_player_anim("idle")


## Every entity's occupied cell on the current map -- the pathfinder's
## "don't route through/onto an NPC or prop" set (mirrors `is_cell_blocked`'s
## own wall/terrain gate, which this is layered on top of, never a
## replacement for). A `present_when`-gated entity whose gate is unmet
## (8d D2) is skipped, matching `is_cell_blocked`/`entity_at` -- its cell
## reads as open floor, not a phantom click-to-walk obstacle.
func _occupied_cells() -> Dictionary:
	var occ := {}
	for ent: Dictionary in Game.sim.entities.values():
		if Game.sim.entity_present(ent):
			occ[ent["cell"] as Vector2i] = true
	return occ


func _bfs_from(start: Vector2i) -> Dictionary:
	var occupied := _occupied_cells()
	var grid_size := Game.sim.grid_size
	var came_from := {start: start}
	var frontier: Array[Vector2i] = [start]
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for cur: Vector2i in frontier:
			for d: Vector2i in dirs:
				var n := cur + d
				if came_from.has(n):
					continue
				if n.x < 0 or n.y < 0 or n.x >= grid_size.x or n.y >= grid_size.y:
					continue
				if Game.sim.is_cell_blocked(n) or occupied.has(n):
					continue
				came_from[n] = cur
				next_frontier.append(n)
		frontier = next_frontier
	return came_from


static func _reconstruct_path(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array:
	var path: Array = []
	var cur := goal
	while cur != start:
		path.append(cur)
		cur = came_from[cur]
	path.reverse()
	return path


func _start_click_path(cell: Vector2i) -> void:
	var came_from := _bfs_from(Game.sim.player_cell)
	if not came_from.has(cell):
		return
	_begin_click_path(_reconstruct_path(came_from, Game.sim.player_cell, cell))


## Click-to-walk to the NEAREST open CARDINAL approach cell of an entity
## (`handle_world_click`'s non-cardinal-adjacent branch -- covers both a
## genuinely distant click and issue #109's diagonally-adjacent one -- the
## "walk up, then stop, never auto-interact" ruling). Tries only the 4
## CARDINAL neighbors of the entity's cell (issue #109: used to try all 8,
## including diagonals -- but a diagonal approach cell can never actually
## interact, see `_is_cardinal_adjacent`'s doc comment, so offering one as a
## "reached" destination was itself doomed), keeping the reachable one whose
## BFS path is shortest; a tie keeps whichever neighbor was tried first
## (UP/DOWN/LEFT/RIGHT order, matching `_bfs_from`'s own `dirs`). No-op
## (empty path, `_begin_click_path` swallows it) if every cardinal neighbor
## is blocked/occupied/unreachable.
func _start_click_path_to_adjacent(entity_cell: Vector2i) -> void:
	var came_from := _bfs_from(Game.sim.player_cell)
	var occupied := _occupied_cells()
	var grid_size := Game.sim.grid_size
	var best_path: Array = []
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for d: Vector2i in dirs:
		var cand := entity_cell + d
		if cand.x < 0 or cand.y < 0 or cand.x >= grid_size.x or cand.y >= grid_size.y:
			continue
		if Game.sim.is_cell_blocked(cand) or occupied.has(cand):
			continue
		if not came_from.has(cand):
			continue
		var path := _reconstruct_path(came_from, Game.sim.player_cell, cand)
		if best_path.is_empty() or path.size() < best_path.size():
			best_path = path
	_begin_click_path(best_path)


func _begin_click_path(path: Array) -> void:
	if path.is_empty():
		return
	_click_path = path
	_advance_click_path()


func _advance_click_path() -> void:
	if _click_path.is_empty():
		return
	if _movement_gated():
		_click_path.clear()
		return
	var next_cell: Vector2i = _click_path[0]
	var dir := next_cell - Game.sim.player_cell
	var moved := Game.sim.move_player(dir)
	_click_path.remove_at(0)
	if not moved:
		_click_path.clear()
		return
	if _click_path.is_empty():
		return
	if _movement_gated():
		_click_path.clear()
		return
	# Windowed continuation comes from the movement tween's finished signal.
	# With collapsed presentation delay no tween/signal exists, so await one
	# real process frame; call_deferred can drain the whole path in one frame.
	if _presentation_delay(MOVE_TWEEN_SECONDS) <= 0.0:
		await get_tree().process_frame
		_advance_click_path()
