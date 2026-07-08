class_name WIWorld
extends Node2D
## Presentation layer for the walking skeleton. Renders the sim's grid and
## entities as sprites where available, forwards input intents to the sim,
## and repositions the player on bus events.
##
## M-BEAUTY R3 (spec §8 addendum): field name tags ("You"/"Erin"/etc.) are
## RETIRED -- every interactable must read from its sprite alone now (see
## `_resolve_entity_render`/`_refresh_entity_visual` for the `visual_states`
## seam that replaces "state changed" affordance a label used to carry).
##
## All UI/visuals are built in code — no hand-authored scenes (repo principle:
## content is data + code).

## M5 R3 16px recalibration: the world SubViewport is 320x180 logical px, so
## the grid cell must match the tile sheets' true native size (16px -- see
## data/biomes.json / .superpowers/sdd/m5-r3-report.md audit; M4 wrongly
## assumed 32px for the free-pack floor/wall sheets).
const CELL := 16
const PLAYER_COLOR := Color(0.25, 0.45, 0.9)
const NPC_COLOR := Color(0.3, 0.7, 0.35)
const PROP_COLOR := Color(0.55, 0.4, 0.25)
const MOVE_TWEEN_SECONDS := 0.12
const BUMP_PIXELS := 3.0
const BUMP_TWEEN_SECONDS := 0.06

## M-BEAUTY Task B2: soft radial white gradient (generated via a small PIL
## script, not sourced from any asset pack -- the generation script is
## preserved verbatim in task-b2-report.md for provenance/regen), used as
## the `texture` for every PointLight2D spawned from entity/decor `light`
## data. `LIGHT_TEXTURE_PX` is its native size -- `texture_scale` is derived
## from a light's data-authored `radius` against this so the same 64px
## texture can express any anchor's glow size.
const LIGHT_TEXTURE := preload("res://assets/fx/light_radial.png")
const LIGHT_TEXTURE_PX := 64.0
## Spec §5 budget: ≤8 lights/map. Asserted (not push_error'd -- see
## atmosphere.gd's `apply()` doc comment for why this codebase fails loud on
## malformed/over-budget content data instead of warning) once per
## `_rebuild_field` pass, after every decor/entity light has been counted.
const LIGHT_BUDGET := 8

## Playtest feature 3 ([Light] glow on the PC): the conjured arcane orb the PC
## carries while `Game.sim.light_active`. A warm-white, campfire-CLASS radius,
## STEADY (no flicker -- it reads as arcane, not fire) PointLight2D attached to
## the player visual. Deliberately NOT registered with `_atmosphere` (never
## routed through `_spawn_light`/`register_light`), so the phase multiplier
## never touches it: it stays lit at day too (day's 0.0 multiplier would make a
## registered light invisible). Diegetically constant -- it is magic. Excluded
## from LIGHT_BUDGET for the same reason (it is not map content).
const PC_LIGHT_COLOR := Color(1.0, 0.95, 0.8)
const PC_LIGHT_RADIUS := 32.0
const PC_LIGHT_ENERGY := 1.0

## Skills Wave Task K2 (the sneak seam): the PC sprite's alpha while
## `Game.sim.sneaking` -- the plan's "PC translucency" presentation, the SAME
## tint machinery (`modulate`) `_make_entity_visual`'s tint arg already uses,
## just touching alpha only (RGB untouched, so a future PC tint variant would
## still compose correctly -- no shipped variant carries one today).
const SNEAK_ALPHA := 0.6

## M-BEAUTY Task B3: ambience presets (fireflies/dust_motes/leaves/
## pond_glints/embers -- see ambience.gd) spawned from map `ambience` data.
## Spec §5 budget: ≤6 emitters/map, asserted the same way as LIGHT_BUDGET.
const AMBIENCE_BUDGET := 6
## Shared (not per-sprite) ShaderMaterial for every decor/scatter entry
## tagged `sway: true` -- one instance, created once in `_ready()`; per-sprite
## phase variance comes from the shader itself reading each sprite's own
## world position (MODEL_MATRIX), not a per-instance uniform, so sharing one
## material across every swaying sprite is both correct and free (see
## foliage_sway.gdshader's doc comment).
const SWAY_SHADER := preload("res://src/world/shaders/foliage_sway.gdshader")
## The floodplains pond's wall-segment sheet (data/skeleton_scene.json's
## `walls.segments`, cap-only water entries) -- `_build_water_shimmer`
## matches segments by this sheet path to re-derive which cells need the
## shimmer overlay (see water_shimmer.gdshader's doc comment for why an
## overlay, not a material on the original layer).
const WATER_SHEET := "res://assets/tiles/free_pack/Water_tiles.png"
const WATER_SHIMMER_SHADER := preload("res://src/world/shaders/water_shimmer.gdshader")
## Skills Wave Task K1: the frost-cast ice overlay reuses the water sheet's
## still-water cap tile (same [1,7] pick the shimmer overlay paints) tinted a
## pale, frosted blue and drawn ON TOP of the shimmer layer, so a frozen channel
## cell reads as grey-white ice over the water it replaced. Cool, near-white,
## slightly translucent so a hint of the water below still shows.
const ICE_CAP_COORD := Vector2i(1, 7)
const ICE_TINT := Color(0.74, 0.86, 1.0, 0.92)
const VIGNETTE_SHADER := preload("res://src/world/shaders/vignette.gdshader")
## VIEW_SIZE is declared further down this file; the vignette ColorRect is
## sized/positioned from it in `_ready()`, both declared as consts in this
## same class so no ordering issue exists between them.

## M5 R4: must match src/world/main.gd's WORLD_VIEWPORT_SIZE (main.gd is off-
## limits to this task's file list; kept in sync by hand -- both are 320x180
## per the M5 spec's locked render architecture). Used to decide whether the
## camera can simply center a map/arena (content <= view) or needs
## clamped-follow (content > view -- not exercised by any current map/arena,
## but built now per the R4 brief).
const VIEW_SIZE := Vector2(320.0, 180.0)
## Skirt fill extends this many cells past the grid edge on every side --
## comfortably more than VIEW_SIZE/CELL (20x11.25) on both axes so the
## camera can never show a grey void regardless of where within the map it
## ends up centered/clamped.
const SKIRT_MARGIN_CELLS := 20

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
## Playtest feature 3: the PC-following [Light] glow node (a child of
## `_player_visual`, so it tweens with the PC for free). Null when unlit.
## Freed with its holder on every `_rebuild_field` (see the null-out there);
## re-attached from `Game.sim.light_active` by `_reconcile_pc_light`.
var _pc_light: PointLight2D
## Skills Wave Task K2: the "have" half of `_reconcile_sneak_visual`'s
## want/have guard -- unlike `_pc_light`'s node-presence check, translucency
## has no child node to test `is_instance_valid` against, so this bool tracks
## whether the CURRENT `_player_sprite` is actually tinted. Reset to false on
## every `_rebuild_field` (alongside `_pc_light = null` below) because that
## function always builds a FRESH, untinted `_player_sprite` -- without the
## reset, a sneaking PC crossing a door (which KEEPS `sneaking` true) would
## read want==have as already-satisfied and skip re-tinting the new sprite.
var _sneak_tinted := false
## Skills Wave Task K1: the frost-cast ice overlay TileMapLayer for the current
## map (null when no cell is frozen). Rebuilt from `Game.sim.frozen_cells` on
## every `_rebuild_field` (so ice survives a map re-entry / load while frozen)
## and appended to live by the TERRAIN_CHANGED{to:"ice"} handler. Freed with its
## siblings on rebuild -- the reference is nulled there like `_pc_light`.
var _ice_overlay: TileMapLayer
## One slot, not two -- a move and a bump landing on the player in quick
## succession (M5 R5 review Low #2) must kill whichever tween is already
## running before starting the other, or both fight over `.position` for up
## to ~0.12s. See `_kill_player_tween`.
var _player_tween: Tween
## Issue #41 (camera jitter fix): mirrors `_player_tween`'s one-slot-not-two
## idiom, just for `_camera.position` instead of the player sprite's. See
## `_pan_camera_to_player`'s doc comment for why this exists as a SEPARATE
## tween from `_player_tween` rather than one tween driving both properties.
var _camera_tween: Tween
var _entity_visuals: Dictionary = {}
var _journal: Node
var _pause_menu: Node
var _inventory: Node
## Three Pillars P2: the overworld field-skill hotbar. Injected at spawn (like
## the panel refs above) so `_unhandled_input`'s number-key routing can ask it
## which field skill occupies a pressed slot -- the hotbar owns the slot list,
## keeping the key->skill mapping single-sourced with what the bar renders.
var _field_hotbar: Node
## Controller support (S1, issue #18): the field hotbar's pad-cursor index,
## mirroring combat's `_bar_index` idiom (combat_screen.gd) -- `-1` = nothing
## highlighted (v1's direct-fire resting state), `>= 0` = a slot the player
## is hovering via `slot_prev`/`slot_next`, activated by `confirm`. Owned
## here (not on `_field_hotbar`) for the same "screen owns selection, hotbar
## only renders" split combat's `_bar_index` already follows.
var _field_slot_index := -1
## The WIMain host, injected downward at spawn (M5 arch finding 3). M-BEAUTY
## R3: world.gd no longer calls `world_labels()` itself (field labels
## retired) -- kept for architectural symmetry with the other injected UI
## refs and as the typed route to Main should a future field-side native-res
## overlay need it again.
var _main: WIMain
## M5 R6: the combat board (arena tiles/skirt, combatant holders, cast
## flashes) lives here -- a sibling of `_field_root` inside this SubViewport-
## hosted world -- instead of a native-res CanvasLayer, so Camera2D and the
## SubViewportContainer's 4x upscale both apply to it and `world_to_screen`
## anchoring is correct for combat labels too. Lazily created by
## `combat_board_root()` the first time combat_screen needs it (combat_screen
## may ask before this World node even exists yet during Main's boot
## sequence -- see combat_screen.gd's `_world_node()`).
var _combat_board_root: Node2D
## M-BEAUTY Task B1: mood grade layer, a CanvasModulate child of this World
## node (the world viewport's root). Must be added, and connect to the bus,
## BEFORE this _ready() emits WORLD_READY below so it catches its own spawn
## event and applies the starting map/phase mood immediately (see
## atmosphere.gd's doc comment for why that ordering matters and the
## combat-board-inherits-the-grade finding).
var _atmosphere: WIAtmosphere
## M-BEAUTY Task B2: count of PointLight2Ds spawned this `_rebuild_field`
## pass, reset at the top of each pass -- backs the LIGHT_BUDGET assert and
## the `ui_lights_rendered` payload.
var _light_count := 0
## M-BEAUTY Task B3: count of ambience emitters spawned this `_rebuild_field`
## pass -- backs AMBIENCE_BUDGET and `ui_ambience_rendered`.
var _ambience_count := 0
## M-BEAUTY Task B3: the one shared sway ShaderMaterial (see SWAY_SHADER's
## doc comment) -- created once in `_ready()`, assigned as `.material` on
## every AnimatedSprite2D whose decor/scatter record carries `sway: true`.
var _sway_material: ShaderMaterial
## M-BEAUTY Task B3: the fullrect vignette ColorRect -- created once in
## `_ready()` as a child of `_camera` (see the ColorRect's own doc comment
## for why it's parented there) and handed to `_atmosphere.vignette_node` so
## atmosphere.gd can drive its shader `strength` from moods.json.
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
	_sway_material = ShaderMaterial.new()
	_sway_material.shader = SWAY_SHADER
	# M-BEAUTY Task B3: parented under `_camera` (not this World node
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


## Input arbitration (repo-wide precedence: combat > dialogue > pause >
## journal > inventory > world): world only handles movement/interact once
## combat, dialogue, the pause menu, the journal, and the inventory (M7 E4)
## have all declined the input. Shared with `_on_move_tween_finished` (FIELD
## HELD-KEY MOVEMENT, 2026-07-05 playtest directive) below -- the held-repeat
## re-checks this SAME gate on every step, not just the first press, since a
## panel/dialogue/combat can open in the tens of ms between one step's tween
## finishing and the next.
func _movement_gated() -> bool:
	if Game.sim.combat != null or Game.sim.dialogue != null:
		return true
	# A pending consolidation offer is modal: the prompt owns the keyboard until
	# answered (spec §2.5 REV 2 -- the sleep beat is deferred on it).
	if not Game.sim.pending_consolidation.is_empty():
		return true
	if (_pause_menu != null and bool(_pause_menu.get("open"))) \
			or (_journal != null and bool(_journal.get("open"))) \
			or (_inventory != null and bool(_inventory.get("open"))):
		return true
	# Controller support fix-wave (issue #18 review Finding B): the GDI
	# cold-open/epilogue veil is modal too. sleep_veil.gd's own
	# `_unhandled_input` treats confirm/cancel as "advance the line" while
	# either runs -- and on pad, `interact` shares button A with `confirm`, so
	# without this gate a pad player advancing the opener text would ALSO fire
	# world `interact()`s at whatever the PC faces under the black. Never true
	# under QA (the veil collapses to an instant coverage emit before ever
	# setting its running flags -- see sleep_veil.gd's `modal_active()` doc
	# comment), so no canonical's input timing changes.
	if _main != null and _main.veil_modal_active():
		return true
	return false


## INPUT-DISPATCH-ORDER TRAP (issue #18 review Finding A -- read before
## reordering ANY branch below): on pad, `interact` and `confirm` BOTH bind
## to button A (S1's locked table), so one A-press satisfies BOTH
## `is_action_pressed` checks on the same event and whichever branch is
## checked first in this if/elif chain wins. The slot-armed
## `confirm`/`cancel` branches must therefore run BEFORE the interact check
## -- with interact first, the pad slot-select+confirm idiom is silently
## dead code (A always interacts, the armed slot never fires). Safe for
## keyboard: `confirm` (Enter) and `cancel` (Esc) previously did nothing in
## the world context, both new branches are `_field_slot_index >= 0`-gated,
## and keyboard players only arm that index via the additive `[`/`]` keys.
func _unhandled_input(event: InputEvent) -> void:
	if _movement_gated():
		return
	if event.is_action_pressed("confirm") and _field_slot_index >= 0:
		# Controller support (S1, reordered by the Finding A fix): activates
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
		# Controller support fix-wave: B/Esc disarms an armed slot selection
		# without firing anything -- the mirror of combat's cancel-back-to-
		# resting idiom. Gated on an armed index, so an unarmed cancel still
		# falls through to whoever owns Esc next (the pause menu).
		_disarm_field_slot()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		Game.sim.interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		Game.sim.move_player(Vector2i.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		Game.sim.move_player(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		Game.sim.move_player(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		Game.sim.move_player(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
	elif InputMap.has_action("slot_prev") and event.is_action_pressed("slot_prev"):
		_move_field_slot_cursor(-1)
		get_viewport().set_input_as_handled()
	elif InputMap.has_action("slot_next") and event.is_action_pressed("slot_next"):
		_move_field_slot_cursor(1)
		get_viewport().set_input_as_handled()
	else:
		# Three Pillars P2: field-skill hotbar direct-fire. Reuses combat's
		# `hotbar_1..9` input actions; the pressed number maps through the field
		# hotbar's own slot list (single source of truth) to a KNOWN field skill,
		# then fires P1's `use_skill_field`. Gated by `_movement_gated()` above
		# exactly like movement/interact, so a number key is inert while any
		# panel/dialogue is open or during combat (combat_screen owns its own
		# hotbar there). A number with no field skill in that slot is left
		# unhandled (harmless), never swallowed.
		var slot := _field_hotbar_slot_pressed(event)
		if slot > 0 and _field_hotbar != null:
			var skill_id := String(_field_hotbar.skill_for_slot(slot))
			if skill_id != "":
				Game.sim.use_skill_field(skill_id)
				get_viewport().set_input_as_handled()


## Controller support (S1): moves the field hotbar's pad cursor by `delta`
## slots, wrapping (mirrors combat's `_move_bar_cursor`). A first press from
## the resting `-1` state lands on slot 0. No-ops when the bar is empty
## (classless cold start -- `_field_hotbar.slot_count() == 0`) or the hotbar
## ref hasn't been injected yet.
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


## Controller support fix-wave: clears the armed slot selection (index AND
## the rendered highlight). Called after a confirm-activation (one-shot
## semantics -- see `_unhandled_input`'s confirm branch), on a cancel press,
## and shared with the event-driven reset in `_on_domain_event` (the slot
## LIST changed, so the cursor must not point at a stale entry).
func _disarm_field_slot() -> void:
	_field_slot_index = -1
	if _field_hotbar != null:
		_field_hotbar.set_selected(-1)


## Which `hotbar_N` action (1..9) this event pressed, or -1 for none -- the same
## action set combat_screen.gd's `_numbered_slot_pressed` reads (guarded by
## `InputMap.has_action` so a stripped input map degrades to inert, not error).
func _field_hotbar_slot_pressed(event: InputEvent) -> int:
	for n in range(1, 10):
		var action := "hotbar_%d" % n
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return n
	return -1


func _rebuild_field() -> void:
	for child: Node in _field_root.get_children():
		child.queue_free()
	_entity_visuals.clear()
	_player_sprite = null
	# Playtest feature 3: the PC glow is a child of the old _player_visual, which
	# the queue_free() above will free -- drop our dangling reference so
	# _reconcile_pc_light re-attaches a fresh node to the NEW holder below if
	# Game.sim.light_active is still set (map change / load while lit).
	_pc_light = null
	# Skills Wave Task K2: see `_sneak_tinted`'s own doc comment -- the fresh
	# `_player_sprite` built below is always untinted, so the tracker must
	# forget the old sprite's state too.
	_sneak_tinted = false
	# Skills Wave Task K1: the ice overlay is a child of _field_root (freed by the
	# loop above) -- drop the dangling reference so _build_ice_overlay re-derives a
	# fresh layer from Game.sim.frozen_cells for the new/reloaded map.
	_ice_overlay = null
	# M-BEAUTY Task B2: drop every light registered for the OLD map before
	# any new one is spawned below -- the old map's holders (and their light
	# children) are only queue_free()d above, not freed synchronously, so
	# atmosphere.gd's registry must be cleared explicitly rather than relying
	# on is_instance_valid() to catch up on its own.
	_atmosphere.clear_lights()
	_light_count = 0
	# M-BEAUTY Task B3: same lifecycle as clear_lights() -- drop every
	# registered ambience emitter for the OLD map before any new one spawns.
	_atmosphere.clear_emitters()
	_ambience_count = 0
	_build_floor()
	_build_water_shimmer()
	_build_ice_overlay()
	_entities_root = Node2D.new()
	_entities_root.y_sort_enabled = true
	_field_root.add_child(_entities_root)
	_build_decor(_current_map_cfg().get("decor", []))
	_build_scatter(_current_map_cfg().get("scatter", []))
	var render_counts := {"sprites": 0, "fallbacks": 0}
	_count_visual(_build_entities(), render_counts)
	var player_cfg: Dictionary = WIDataRegistry.scene_config()["player"]
	# M-ARC §5 variant-key indirection (presentation-only): the PC visual uses
	# the sim's chosen race/gender sprite variant ("pc_<race>_<gender>"), falling
	# back to the data default ("body_a") when that variant art is not registered.
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
	# Playtest feature 3: re-attach the PC [Light] glow if the sim says it is lit
	# (a map change or a load restored `light_active`). Done here, after the new
	# _player_visual exists, so the glow survives every rebuild.
	_reconcile_pc_light()
	# Skills Wave Task K2: same reasoning as the light re-attach just above --
	# a map change (door crossing, which KEEPS `sneaking` per the plan) or a
	# load restored a fresh `_player_sprite` with no memory of the old alpha.
	_reconcile_sneak_visual()
	render_counts["pc_sprite"] = pc_sprite
	ObservableBus.emit_domain_event(WIEvents.UI_ENTITIES_RENDERED, render_counts)
	assert(_light_count <= LIGHT_BUDGET,
		"map %s exceeds the %d-light budget (%d) -- spec §5" % [Game.sim.current_map, LIGHT_BUDGET, _light_count])
	ObservableBus.emit_domain_event(WIEvents.UI_LIGHTS_RENDERED, {"map": Game.sim.current_map, "count": _light_count})
	_build_ambience()
	_update_camera()


## M5 R4 floor stack z-order (back to front): skirt -> base floor (every grid
## cell) -> floor_layers (position-hashed variants / rug patches, drawn OVER
## the base floor) -> blocked layer (drawn LAST among floor-ish layers, in
## its own always-separate TileMapLayer (added AFTER the wall band, though they
## never spatially overlap: walls paint only the y<0 margin) so a pick can never
## visually cover a wall/obstacle tile -- cells it doesn't touch stay
## transparent, letting the layers below show through) -> wall band (drawn
## in the skirt margin above row 0, never touches a playable cell) ->
## entities_root (decor + npcs/props/player, Y-sorted).
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

	var blocked_sheet := String(biome.get("blocked_sheet", biome["sheet"]))
	# blocked_tile_px: the blocked sheet's own grid, which can differ from the
	# floor sheet's (e.g. street floor is a whole-image 540px dirt tile while
	# blocked cells come from the 16px Wall_Tiles) — using the floor's tile_px
	# here made blocked coords land out of atlas bounds = silent no-op walls.
	var blocked_tile_px := int(biome.get("blocked_tile_px", tile_px))
	var blocked_layer := WITileBoardBuilder.make_tile_layer(_field_root, blocked_sheet, blocked_tile_px, WISpriteRegistry)
	var blocked_coord := Vector2i(int(biome["blocked"][0]), int(biome["blocked"][1]))
	for cell: Vector2i in Game.sim.blocked_cells.keys():
		# Cells covered by a walls segment already carry that segment's wall
		# art; painting the generic blocked tile here would overdraw it (this
		# layer is added after the walls layers).
		if segment_covered.has(cell):
			continue
		blocked_layer.set_cell(cell, 0, blocked_coord)
	_field_root.add_child(blocked_layer)
	ObservableBus.emit_domain_event(WIEvents.UI_MAP_RENDERED, {
		"map": Game.sim.current_map,
		"floor_cells": grid_size.x * grid_size.y,
		"blocked_cells": Game.sim.blocked_cells.size(),
	})


## M-BEAUTY Task B3: overlay TileMapLayer for the pond's water tiles (see
## water_shimmer.gdshader's doc comment for why this is an overlay rather
## than a material on the layer `WITileBoardBuilder.build_walls` (called by
## `_build_floor` above) already painted). Re-derives the exact same cells
## from the SAME source data (`walls.segments` matched by `sheet ==
## WATER_SHEET`) via the same public `WIGame.segment_cells` helper
## `build_walls` itself uses, then paints an identical cap-only tile at those
## cells into a fresh TileMapLayer added right after (so it draws on top of,
## and fully covers) the flat one underneath. A no-op (frees the unused
## layer) on any map with no water segments -- today that's every map except
## floodplains.
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
		var cap_raw: Array = seg.get("cap", [1, 7])
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


## Skills Wave Task K1: rebuild the frost-cast ice overlay for the current map
## from the sim's authoritative `frozen_cells` set (the water-shimmer overlay
## precedent -- a fresh TileMapLayer of the SAME water sheet's cap tile, tinted
## frost, drawn on top of the shimmer so a frozen cell reads as ice). A no-op
## (no layer created) when nothing on this map is frozen -- the common case, and
## every map before the seam ever fires. Called after `_build_water_shimmer` on
## every field rebuild so ice survives a map change / a load while frozen.
func _build_ice_overlay() -> void:
	var frozen: Array = Game.sim.frozen_cells_json().get(Game.sim.current_map, [])
	for pair: Variant in frozen:
		if pair is Array and (pair as Array).size() == 2:
			_paint_ice_cell(Vector2i(int(pair[0]), int(pair[1])))


## Skills Wave Task K1: paint one frozen cell into the ice overlay, creating the
## overlay TileMapLayer on first use (lazily, so an unfrozen map spawns nothing).
## Shared by the rebuild path (`_build_ice_overlay`) and the live freeze handler
## (TERRAIN_CHANGED{to:"ice"}), so a fresh freeze and a reload paint identically.
func _paint_ice_cell(cell: Vector2i) -> void:
	if _ice_overlay == null:
		_ice_overlay = WITileBoardBuilder.make_tile_layer(_field_root, WATER_SHEET, 16, WISpriteRegistry)
		_ice_overlay.modulate = ICE_TINT
		# Above the shimmer overlay (added just before), below the Y-sorted
		# entities/player, so the PC visual walks over the ice, not under it.
		_ice_overlay.z_index = 1
		_field_root.add_child(_ice_overlay)
	_ice_overlay.set_cell(cell, 0, ICE_CAP_COORD)


## Skills Wave Task K1: a one-shot burn poof at a scorched (burned-away) cell,
## reusing combat's `hit_sparks` WIAmbience preset (board_renderer.spawn_hit_sparks
## precedent). Self-frees past its lifetime; QA/headless-collapsed (no particle
## node spawned when presentation is disabled) exactly like every other juice.
## Skills Wave Task K1: free any existing ice overlay and repaint it from the
## sim's current `frozen_cells` -- used on PHASE_CHANGED (the sleep-thaw beat has
## no field rebuild of its own). Frees to nothing when the set is empty (thaw).
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


## Renders `decor` entries (M5 R4 schema): unlabeled, non-blocking set-
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
		_make_entity_visual(cell, sprite_id, [], PROP_COLOR, "", entry.get("light", {}), bool(entry.get("sway", false)))


## Renders `scatter` entries (M5 E3, scene-assembly-guide P3): seeded
## deterministic micro-detail clusters — same JSON in, same scene out, so QA
## screenshots stay comparable. Each spec: {"pool": [sprite_ids], "density":
## 0..1, "cluster": 0..1, "seed": int}. A cell hosts a scatter sprite when
## its presence hash falls under density boosted (or damped) by its 4x4
## block's cluster hash — detail clumps instead of uniform noise. Skips
## blocked cells (incl. wall segments), entity cells, and the player cell.
## Non-blocking, unlabeled, Y-sorted like decor.
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
		# M-BEAUTY Task B3: sway is tagged per SPEC (pool), not per sprite id
		# within the pool -- a spec whose pool mixes foliage with a
		# non-foliage prop (floodplains' grass_tuft/pebble/flower_tiny spec)
		# would need re-seeding to split cleanly, which would shift WHICH
		# cells host which prop and break the "all else identical" day-shot
		# contract; at this shader's subtle default amplitude the effect on
		# the few non-foliage instances in a mixed pool is imperceptible in
		# practice (documented in task-b3-report.md).
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
					_make_entity_visual(cell, sprite_id, [], PROP_COLOR, "", {}, sway)


## Deterministic [0,1) hash for scatter decisions — stable per (seed, cell,
## salt) so identical map JSON always renders identical scatter.
static func _scatter_hash(seed_v: int, cell: Vector2i, salt: int) -> float:
	var h := hash(Vector3i(cell.x * 73856093, cell.y * 19349663, seed_v * 83492791 + salt))
	return float(h & 0xFFFFFF) / float(0x1000000)


func _biome_for_current_map() -> Dictionary:
	var biomes := WIDataRegistry.biomes()
	var map_cfg: Dictionary = _current_map_cfg()
	var biome_id := String(map_cfg.get("biome", "inn"))
	assert(biomes.has(biome_id), "unknown map biome: " + biome_id)
	return biomes[biome_id]


## Raw current-map config from skeleton_scene.json (the same source
## `_biome_for_current_map` reads its biome id from) -- used to read the
## M5 R4 passthrough fields (`floor_layers`/`walls`/`decor`) that `WIGame`
## never touches.
func _current_map_cfg() -> Dictionary:
	var maps: Dictionary = WIDataRegistry.scene_config()["maps"]
	return maps[Game.sim.current_map]


## Camera2D positioning (M5 R4): centers a map/arena smaller than the
## 320x180 view; clamped-follow (never shows past the content edge) for a
## map/arena larger than the view. STALE CLAIM CORRECTED (issue #41): this
## comment used to say no current map/arena exceeds VIEW_SIZE and the
## clamped-follow branch was unexercised -- that stopped being true well
## before #41 (street/floodplains/sewers/guild/ruin_surface/garden_sanctuary
## are all bigger than 320x180 today), and the follow branch running live on
## those maps is exactly what made the field-walk camera jitter visible.
## `_update_camera` itself is still an instant snap on purpose -- used by map
## rebuild and combat enter/exit, where a hard cut is correct. The
## PLAYER_MOVED-driven walk uses `_pan_camera_to_player` instead (see its doc
## comment) precisely so a real cell-to-cell walk animates rather than snaps.
func _update_camera() -> void:
	var grid_size := Game.sim.grid_size
	var content_size := Vector2(grid_size) * CELL
	var focus := Vector2(Game.sim.player_cell) * CELL + Vector2(CELL, CELL) * 0.5
	_camera.position = Vector2(
		_camera_axis(content_size.x, VIEW_SIZE.x, focus.x),
		_camera_axis(content_size.y, VIEW_SIZE.y, focus.y)
	)


static func _camera_axis(content: float, view: float, focus: float) -> float:
	if content <= view:
		return content * 0.5
	return clampf(focus, view * 0.5, content - view * 0.5)


## Issue #41 (camera jitter root cause + fix): `_update_camera()` above always
## SNAPPED `_camera.position` to the destination the instant it was called --
## fine for a map rebuild or a combat-camera swap (an instant cut IS correct
## there), but the `PLAYER_MOVED` handler called it too, synchronously with
## `_move_player_visual` starting a ~120ms CUBIC/EASE_OUT tween of the PLAYER
## SPRITE toward that same point. Net effect on any map wider/taller than the
## 320x180 view (clamped-follow branch of `_camera_axis` -- contra this file's
## stale M5 R4 comment claiming no current map exceeds VIEW_SIZE: street/
## floodplains/sewers/guild/ruin_surface/garden_sanctuary all do): the camera
## HARD-JUMPED a full cell in a single frame, then sat perfectly still for the
## remaining ~117ms while only the small player sprite eased into place --
## measured directly off `_camera`/`_player_visual` (`camera_x` flat for 6+
## consecutive cell-steps while `player_visual_x` swept continuously, then an
## 8-16px jump in one process frame; see the #41 report). That is the
## "continuous motion then alternating static/jump frames" the user's
## recording showed. This variant re-derives the SAME `_camera_axis` target
## (byte-identical math to `_update_camera`) but glides there over the exact
## same duration/easing as `_move_player_visual`'s own tween instead of
## snapping, so camera and sprite move in lockstep every frame -- both tweens
## are pure functions of elapsed-time-since-start with the same trans/ease, so
## two independently-created Tweens started in the same call stay in sync with
## no cross-wiring needed. Falls back to the instant `_update_camera()` snap
## whenever `_presentation_delay` collapses to zero (TestDriver-driven or
## headless), which is the SAME collapse `_move_player_visual` already relies
## on -- a QA script or headless run sees byte-identical camera placement to
## before this fix, every canonical included. Only the `PLAYER_MOVED` handler
## calls this; map rebuild (`_rebuild_field`) and combat enter/exit still use
## the instant `_update_camera()` snap on purpose -- a fresh scene or mode
## swap should never animate into place.
func _pan_camera_to_player() -> void:
	var duration := _presentation_delay(MOVE_TWEEN_SECONDS)
	if duration <= 0.0:
		_update_camera()
		return
	var grid_size := Game.sim.grid_size
	var content_size := Vector2(grid_size) * CELL
	var focus := Vector2(Game.sim.player_cell) * CELL + Vector2(CELL, CELL) * 0.5
	var target := Vector2(
		_camera_axis(content_size.x, VIEW_SIZE.x, focus.x),
		_camera_axis(content_size.y, VIEW_SIZE.y, focus.y)
	)
	_kill_camera_tween()
	_camera_tween = create_tween()
	_camera_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(_camera, "position", target, duration)


## Mirrors `_kill_player_tween` (M5 R5 review Low #2's one-slot-not-two idiom)
## for the camera pan tween -- a move landing while the previous step's pan is
## still finishing must kill it first, or two tweens fight over
## `_camera.position` for up to ~0.12s.
func _kill_camera_tween() -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()


## M5 R6 (I6 board extraction): the Node2D combat_screen.gd renders the arena
## board into. A sibling of `_field_root`, not a child of it, so field
## rebuild/clear logic (`_rebuild_field`) never touches combat content and
## vice versa. Starts hidden; combat_screen owns showing/hiding it around
## each encounter (see combat_screen.gd's `_build_board`/`_close_banner`).
func combat_board_root() -> Node2D:
	if _combat_board_root == null:
		_combat_board_root = Node2D.new()
		_combat_board_root.name = "CombatBoardRoot"
		_combat_board_root.visible = false
		add_child(_combat_board_root)
	return _combat_board_root


## Centers the shared field Camera2D on a `grid_size` (CELL=16, same scale as
## the field) combat arena -- same content<=view/clamped-follow split as
## `_update_camera`, but "follows" the arena's own center since an arena has
## no player-cell equivalent. Every current arena (largest: 12x8 = 192x128)
## is smaller than the 320x180 view, so this always centers today; the
## clamped-follow branch is future-proofing, same as `_update_camera`'s.
func enter_combat_camera(grid_size: Vector2i) -> void:
	var content_size := Vector2(grid_size) * CELL
	_camera.position = Vector2(
		_camera_axis(content_size.x, VIEW_SIZE.x, content_size.x * 0.5),
		_camera_axis(content_size.y, VIEW_SIZE.y, content_size.y * 0.5)
	)


## Restores the field camera position once combat ends. Recomputed fresh from
## the live player cell/grid rather than a cached pre-combat value -- the
## field's own state never changes while combat owns the screen, so this is
## exactly equivalent and reuses the one camera-placement formula.
func exit_combat_camera() -> void:
	_update_camera()


func _build_entities() -> Array[Node2D]:
	var visuals: Array[Node2D] = []
	for ent: Dictionary in Game.sim.entities.values():
		var color := NPC_COLOR if String(ent["kind"]) == "npc" else PROP_COLOR
		var render := _resolve_entity_render(ent)
		var visual := _make_entity_visual(
			ent["cell"],
			String(render["sprite"]),
			render["tint"],
			color,
			String(ent.get("facing", "")),
			render["light"]
		)
		_entity_visuals[String(ent["id"])] = visual
		visuals.append(visual)
	return visuals


## M-BEAUTY R3 (spec §8 pt.2): resolves a `prop`/`npc` entity's CURRENT
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
	return result


## Three `when` shapes:
## `{"counter": id, "at": n}` -- true once `Game.sim.accomplishment_count(id)
## >= n` (the dirty_table/unlit_lantern case, driven by ACCOMPLISHMENT_RECORDED
## below); `{"container_opened": true}` -- true once `Game.sim.container_state`
## marks `entity_id` emptied (the inn_chest case, driven by ITEM_GAINED's
## `source` field below -- see that handler's doc comment for the deferral
## this needs); `{"dormant": true}` -- true while this encounter id sits in
## `Game.sim.dormant_encounters` (Track B2 item 6: a `respawns: true` encounter
## defeated this waking should read "cleared/resting", not identical to a live
## one -- VISUAL-LOG). Presentation-only: it merely READS the sim's existing
## dormant set (set on victory, cleared at the sleep beat); driven by the
## UI_COMBAT_HIDDEN refresh below (post-combat, no map change) and by the
## MAP_CHANGED rebuild (re-arm shows on the next visit after sleep).
func _visual_state_active(when: Dictionary, entity_id: String) -> bool:
	if when.has("counter"):
		return Game.sim.accomplishment_count(String(when["counter"])) >= int(when.get("at", 1))
	if when.has("container_opened"):
		return bool(Game.sim.container_state.get(entity_id, false))
	if when.has("dormant"):
		return Game.sim.dormant_encounters.has(entity_id) == bool(when["dormant"])
	return false


## Re-renders ONE entity's visual in place (spec §8 pt.2: "re-render that prop
## only", never a full `_rebuild_field()`). No-op for an entity without
## `visual_states` (the overwhelming majority) or one not currently tracked
## (e.g. a different map's prop while ACCOMPLISHMENT_RECORDED is global).
## M-BEAUTY RF fix wave (final-review Fix 1): a `visual_states` transition
## can add a `light` (the `unlit_lantern` case) -- before freeing the OLD
## holder, unregister any `PointLight2D` child from `_atmosphere` AND
## decrement `_light_count` to match (mirrors `_spawn_light`'s own
## increment), so a light-bearing entity refreshed more than once can never
## leak a stale array entry or drift `_light_count` away from the true live
## count. The budget assert below is `_rebuild_field`'s own assert repeated
## here -- that one only re-checks at the next full map rebuild (which
## resets `_light_count` to 0 first, silently masking any drift that
## happened via refreshes in between), so a refresh that pushes a map over
## LIGHT_BUDGET needs its own immediate check.
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
	var new_visual := _make_entity_visual(cell, String(render["sprite"]), render["tint"], color, String(ent.get("facing", "")), render["light"])
	_entity_visuals[id] = new_visual
	assert(_light_count <= LIGHT_BUDGET,
		"map %s exceeds the %d-light budget (%d) after a visual_states refresh -- spec §5" % [Game.sim.current_map, LIGHT_BUDGET, _light_count])


## ACCOMPLISHMENT_RECORDED fires for every counter in the game (combat tallies
## included), so this scans only entities already on the current map (via
## `_entity_visuals`) and only re-renders one whose `visual_states` actually
## watches the counter that just changed -- cheap (a handful of props per
## map) and never touches an entity with no visual_states at all.
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


## Track B2 item 6: after combat ends and the field re-shows (UI_COMBAT_HIDDEN,
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


## M-ARC §5: resolve the PC's chosen race/gender sprite variant, degrading to
## the data default when that variant art is not registered (so a partially
## generated variant set, or the classic body_a base, still renders the PC).
func _pc_variant_sprite(default_id: String) -> String:
	var key := Game.sim.pc_sprite_variant()
	return key if WISpriteRegistry.has_sprite(key) else default_id


func _make_entity_visual(cell: Vector2i, sprite_id: String, tint: Variant, fallback_color: Color = PROP_COLOR, facing: String = "", light: Dictionary = {}, sway: bool = false) -> Node2D:
	var holder := Node2D.new()
	holder.position = Vector2(cell) * CELL
	var uses_sprite := false
	if sprite_id != "" and WISpriteRegistry.has_sprite(sprite_id):
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = WISpriteRegistry.frames_for(sprite_id)
		spr.centered = false
		# facing (M5 E3, guide P8): map JSON can aim an NPC at its work
		# station ("up"/"down"/"left"/"right"); left mirrors the side sheet.
		var facing_anim := "idle_side" if facing in ["left", "right"] else "idle_%s" % facing
		var anim := "idle_down" if spr.sprite_frames.has_animation("idle_down") else "idle"
		if facing != "" and spr.sprite_frames.has_animation(facing_anim):
			anim = facing_anim
			spr.flip_h = facing == "left"
		spr.play(anim)
		if tint is Array and (tint as Array).size() == 3:
			var tint_values := tint as Array
			spr.modulate = Color(float(tint_values[0]), float(tint_values[1]), float(tint_values[2]))
		if sway:
			spr.material = _sway_material
		var catalog_entry: Dictionary = WISpriteRegistry.entry_for(sprite_id)
		if catalog_entry.has("render_scale"):
			var s := float(catalog_entry["render_scale"])
			spr.scale = Vector2(s, s)
		# Anchor the sprite's feet/base to the cell's bottom-center (M5 R3):
		# taller canvases (e.g. Body_A's 64px character canvas) correctly
		# overhang the cell above instead of being top-left-aligned to it.
		var frame_tex := spr.sprite_frames.get_frame_texture(anim, 0)
		var frame_size := frame_tex.get_size() if frame_tex != null else Vector2(CELL, CELL)
		var anchor := WISpriteRegistry.anchor_for(sprite_id)
		spr.position = Vector2(
			CELL * 0.5 - anchor.x * frame_size.x * spr.scale.x,
			CELL - anchor.y * frame_size.y * spr.scale.y
		)
		# Contact shadow (M5 E3, guide P5): added before the sprite so it
		# draws beneath; width tracks the rendered sprite footprint.
		if bool(catalog_entry.get("shadow", false)):
			var shadow := Sprite2D.new()
			shadow.texture = WISpriteRegistry.shadow_texture()
			shadow.position = Vector2(CELL * 0.5, CELL - 2.0)
			var shadow_w := clampf(frame_size.x * spr.scale.x / 24.0, 0.6, 2.5)
			shadow.scale = Vector2(shadow_w, shadow_w * 0.8)
			holder.add_child(shadow)
		holder.add_child(spr)
		uses_sprite = true
	else:
		var rect := ColorRect.new()
		rect.color = fallback_color
		rect.size = Vector2(CELL - 8, CELL - 8)
		rect.position = Vector2(4, 4)
		holder.add_child(rect)
	holder.set_meta("uses_sprite", uses_sprite)
	if not light.is_empty():
		_spawn_light(holder, light)
	_entities_root.add_child(holder)
	return holder


## M-BEAUTY Task B2: spawns a PointLight2D from an entity/decor `light`
## record (`{color:[r,g,b], energy:float, radius:int, flicker:bool}`) as a
## child of the visual `holder` returned by `_make_entity_visual`, and
## registers it with `_atmosphere` so phase crossings drive its energy (day
## multiplier 0.0 makes it invisible without any per-anchor identity hack --
## see atmosphere.gd's `light_multiplier`). Positioned at the cell's center
## rather than the sprite's own anchor point -- a soft radial glow at the
## radii this data uses (20-48px) reads the same either way, and centering
## keeps this function independent of any given sprite's feet-anchor math.
func _spawn_light(holder: Node2D, light: Dictionary) -> void:
	var color_arr: Variant = light.get("color", [1.0, 1.0, 1.0])
	# Same fail-loud idiom as atmosphere.gd's rgb bounds-check on apply() --
	# malformed light data is an authoring bug, not a runtime possibility.
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


## Playtest feature 3: brings the PC-following [Light] glow into agreement with
## the sim's authoritative `light_active` flag. Attaches a fresh glow if lit and
## missing; removes it if unlit and present; no-ops (and emits nothing) when the
## visual already matches the flag -- so a re-cast while already lit, or a
## dusk/night phase crossing, does not double the light or re-fire the event.
## Called from three places: `_rebuild_field` (map change / load re-attach), the
## SKILL_USED{light} hook (live cast), and the PHASE_CHANGED hook (sleep clear).
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


## Skills Wave Task K2: brings the PC sprite's alpha into agreement with the
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
## the only hook that catches the sleep-clear).
func _reconcile_sneak_visual() -> void:
	if _player_sprite == null:
		return
	var want := Game.sim.sneaking
	if want == _sneak_tinted:
		return
	_player_sprite.modulate.a = SNEAK_ALPHA if want else 1.0
	_sneak_tinted = want
	ObservableBus.emit_domain_event(WIEvents.UI_SNEAK_RENDERED, {"active": want})


## Playtest feature 3: builds the PC glow PointLight2D as a child of
## `_player_visual`, centered on the PC's cell (so it tweens with the PC for
## free), reusing the same soft radial texture the map lights use. Steady (no
## flicker), warm-white, campfire-class radius. NOT registered with
## `_atmosphere` -- that is the whole point (see PC_LIGHT_* consts): the phase
## multiplier never touches it, so it stays lit at day too.
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


## Playtest feature 3: removes the PC glow node (sleep clear). No atmosphere
## unregister needed -- the glow was never registered.
func _detach_pc_light() -> void:
	if is_instance_valid(_pc_light):
		_pc_light.queue_free()
	_pc_light = null


## M-BEAUTY Task B3: reads the current map's `ambience` list (M5 R4-style
## passthrough field, same idiom as `decor`/`scatter`) and spawns one
## GPUParticles2D per entry via `WIAmbience.make`, registering each with
## `_atmosphere` for phase gating. Added directly to `_field_root` (a sibling
## of `_entities_root`, not a child of it) AFTER entities/decor/scatter are
## built, so ambience always draws in front of the field's sprites -- fits
## every preset here (drifting motes/glints/fireflies reading in front of
## trees/the player is the intended look, not a bug).
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


## Resolves an `ambience` entry's `rect` field ("all" | [x,y,w,h] in CELL
## units) into a world-pixel Rect2 -- the space `WIAmbience.make`'s emission
## box needs (native res, same CELL scale as everything else world.gd
## renders).
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
		_move_player_visual(Vector2(cell) * CELL)
		_play_player_anim("walk")
		_queue_player_idle()
		# Issue #41: was `_update_camera()` (an instant snap) -- see
		# `_pan_camera_to_player`'s doc comment for the jitter this caused on
		# any map with clamped-follow (wider/taller than the 320x180 view).
		_pan_camera_to_player()
	elif type == WIEvents.PLAYER_BLOCKED:
		_bump_player_visual()
	elif type == WIEvents.MAP_CHANGED:
		_rebuild_field()
	elif type == WIEvents.ENTITY_REMOVED:
		var visual: Node2D = _entity_visuals.get(String(payload["id"]))
		if visual != null:
			visual.queue_free()
			_entity_visuals.erase(String(payload["id"]))
	elif type == WIEvents.COMBAT_STARTED:
		_field_root.visible = false
	elif type == WIEvents.UI_COMBAT_HIDDEN:
		_field_root.visible = true
		# Track B2 item 6: a just-defeated respawns:true encounter is now dormant
		# -- swap it to its "resting/cleared" look (field re-shows without a rebuild).
		_refresh_entities_watching_dormant()
	elif type == WIEvents.ACCOMPLISHMENT_RECORDED:
		# M-BEAUTY R3 (spec §8 pt.2): the dirty_table/unlit_lantern visual_states
		# seam. accomplishments update synchronously before this fires (see
		# WIGame.record_accomplishment), so no deferral needed here.
		_refresh_entities_watching_counter(String(payload.get("id", "")))
	elif type == WIEvents.ITEM_GAINED:
		# M-BEAUTY R3: the inn_chest/container visual_states case. `source` is
		# the container's own entity id (WIGame._interact_container), but
		# `container_state[id] = true` is only set AFTER every contained
		# item's pickup() call (and its ITEM_GAINED emission) returns -- this
		# event can fire before that flag flips. `call_deferred` re-checks
		# `_refresh_entity_visual` on the next idle frame, by which point the
		# whole synchronous interact() call (container_state included) has
		# completed -- one frame's delay is imperceptible for a one-shot
		# container-opened swap.
		var source_id := String(payload.get("source", ""))
		if source_id != "":
			call_deferred("_refresh_entity_visual", source_id)
	elif type == WIEvents.SKILL_USED:
		# Playtest feature 3: a live [Light] cast (prop OR ambient path both emit
		# skill_used{skill:"light"}). Reconcile against Game.sim.light_active --
		# the ambient cast set it true (attach the PC glow); the prop-targeted
		# lantern/cellar cast leaves it false (no-op here, prop light unchanged).
		if String(payload.get("skill", "")) == "light":
			_reconcile_pc_light()
	elif type == WIEvents.SNEAK_STARTED or type == WIEvents.SNEAK_ENDED:
		# Skills Wave Task K2: every deliberate toggle and every automatic
		# break fires one of these -- reconcile the PC's translucency to match.
		_reconcile_sneak_visual()
	elif type == WIEvents.PHASE_CHANGED:
		# Playtest feature 3: sleep() clears light_active and fires PHASE_CHANGED
		# unconditionally -- reconcile detaches the PC glow on that beat. Harmless
		# on a dusk/night crossing while lit (the flag is still true, reconcile is
		# a no-op then), so this single hook covers the sleep-clear cleanly.
		_reconcile_pc_light()
		# Skills Wave Task K2: sleep() ALSO silently clears `sneaking` (no
		# SNEAK_ENDED event -- see that clear's own comment), so this is the
		# only hook that catches a sneaking-into-sleep PC's opacity reset.
		# Harmless no-op on a dusk/night crossing while not sneaking.
		_reconcile_sneak_visual()
		# Skills Wave Task K1: sleep() thaws all ice (clears frozen_cells) and fires
		# PHASE_CHANGED unconditionally, but PHASE_CHANGED does NOT rebuild the field
		# -- so reconcile the ice overlay against the sim here too. On the sleep beat
		# the set is empty, so this frees the lingering overlay; on a mid-waking
		# dusk/night crossing (ice still frozen) it repaints the same cells (cheap).
		_reconcile_ice_overlay()
	elif type == WIEvents.TERRAIN_CHANGED:
		# Skills Wave Task K1: a cell changed its traversable look. Only act on the
		# CURRENT map (a stale cross-map event can't happen today -- both seams emit
		# for the map the PC stands on -- but guard anyway). "ice" paints the frost
		# overlay tile; "scorched" drops the burn poof (the burnable prop's own
		# visual is already gone via ENTITY_REMOVED). sleep()'s thaw does NOT emit
		# this -- the ice overlay clears on the PHASE_CHANGED-driven rebuild path
		# instead (frozen_cells is empty by then, so _build_ice_overlay repaints
		# nothing); no per-cell thaw event is needed.
		if String(payload.get("map", "")) == Game.sim.current_map:
			var tc_cell := Vector2i(int(payload["cell"][0]), int(payload["cell"][1]))
			match String(payload.get("to", "")):
				"ice":
					_paint_ice_cell(tc_cell)
				"scorched":
					_spawn_burn_poof(tc_cell)
	elif type in [WIEvents.WORLD_READY, WIEvents.CLASS_GAINED, WIEvents.CLASS_LEVEL_UP, WIEvents.CLASS_EVOLVED, WIEvents.LOADOUT_CHANGED]:
		# Controller support (S1): these are exactly the events
		# `field_hotbar.gd`'s `_render()` re-derives the slot LIST on -- the
		# pad cursor here must reset alongside it (a stale index could point
		# past a shrunk list, or at a now-different skill on a same-size one).
		# (The hotbar's own `_render()` already drew with -1, so the helper's
		# `set_selected(-1)` is an idempotent no-op redraw here.)
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
	# FIELD HELD-KEY MOVEMENT (2026-07-05 playtest directive): only the REAL
	# tween branch above ever connects this -- the zero-duration branch just
	# above (TestDriver/headless, per `_presentation_delay`) returns before
	# reaching here, so no `finished` signal (hence no repeat) can ever fire
	# for an injected/headless run. Combat is untouched: combat_screen.gd
	# drives its own board and never calls this method.
	_player_tween.finished.connect(_on_move_tween_finished)


func _bump_player_visual() -> void:
	if _player_visual == null:
		return
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


## Shared by both `_move_player_visual` and `_bump_player_visual` (M5 R5
## review Low #2) -- one active positional tween per holder, regardless of
## which of the two started it.
func _kill_player_tween() -> void:
	if _player_tween != null and _player_tween.is_valid():
		_player_tween.kill()


func _presentation_delay(seconds: float) -> float:
	if (TestDriver != null and TestDriver.active()) or DisplayServer.get_name() == "headless":
		return 0.0
	return seconds


## FIELD HELD-KEY MOVEMENT (2026-07-05 playtest directive): the four movement
## actions keyed to their sim direction, used by `_held_move_direction` below.
const MOVE_ACTIONS := {
	"move_up": Vector2i.UP,
	"move_down": Vector2i.DOWN,
	"move_left": Vector2i.LEFT,
	"move_right": Vector2i.RIGHT,
}


## Polls (not event-based -- OS key-repeat/"echo" events are filtered out of
## `is_action_pressed` by default, which is exactly why a held arrow currently
## only steps once) whether any movement action is still down, for the
## held-repeat check on move-tween completion. Prefers continuing in the
## player's CURRENT facing (a straight-line hold reads as one continuous walk
## rather than re-resolving priority every step); falls back to whichever
## other movement action is held, so a direction change mid-hold (still
## holding one key, pressing a second) also continues stepping without a
## release/re-press. Returns Vector2i.ZERO (not a valid direction any action
## maps to) as the "nothing held" sentinel.
func _held_move_direction() -> Vector2i:
	var facing := Game.sim.player_facing
	for action_name: String in MOVE_ACTIONS:
		if (MOVE_ACTIONS[action_name] as Vector2i) == facing and Input.is_action_pressed(action_name):
			return facing
	for action_name: String in MOVE_ACTIONS:
		if Input.is_action_pressed(action_name):
			return MOVE_ACTIONS[action_name]
	return Vector2i.ZERO


## FIELD HELD-KEY MOVEMENT (2026-07-05 playtest directive): fires once per
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
	if TestDriver != null and TestDriver.active():
		return
	if _movement_gated():
		return
	var dir := _held_move_direction()
	if dir == Vector2i.ZERO:
		return
	Game.sim.move_player(dir)
