class_name WICombatBoardRenderer
extends Node
## M6.5 D2 extraction: the board/sprite region MOVED verbatim out of
## combat_screen.gd -- arena tiles/skirt/walls (via `WITileBoardBuilder`),
## blocked-cell cover props, arena decor, combatant visuals (sprite or
## ColorRect chip + HP/MP bars), world-space name/stat labels, and every
## tween/anim/flash that animates a combatant's holder. `extends Node` (not
## Node2D) deliberately: this helper owns/manages a Node2D board
## (`_board`, living inside the world SubViewport -- see `build()`) but needs
## tree membership itself for `create_tween()`/`get_tree()` (`combat_screen.gd`
## adds one instance as its own child in `_ready()`); it draws nothing of its
## own.
##
## Constructed once by `combat_screen.gd` and reused across encounters (like
## the screen's own `_hotbar`); `build()` re-resolves `_board` from
## `World.combat_board_root()` fresh every call rather than trusting a cached
## reference, same reasoning as the pre-D2 `_build_board()` had (the World
## node itself is torn down/recreated on `game_reset`/`game_loaded`).
##
## Sim reads inside every moved function route through the `WICombatView`
## passed to `build()` (task mandate) -- see `combat_view.gd`'s doc comment
## for the two accessor methods added here (`visual_for`, `has_sprite`, plus
## a few small others) that exist purely to let `combat_screen.gd` keep its
## own remaining (not-yet-moved) code working against this renderer's
## now-private node bookkeeping without reaching into it directly.

const CELL := 16
const PLAYER_COLOR := Color(0.25, 0.45, 0.9)
const ENEMY_COLOR := Color(0.75, 0.25, 0.2)
const MP_COLOR := Color(0.25, 0.4, 0.85)
const MOVE_TWEEN_SECONDS := 0.12
const BUMP_PIXELS := 3.0
const BUMP_TWEEN_SECONDS := 0.06
## Playtest fix (props-over-tiles, repo-wide user mandate — see
## wi-art-and-sprites SKILL.md): arena cover/blocked cells render as biome-
## appropriate PROP SPRITES instead of a flat recolored tile. Existing
## sprites.json entries only, per biome id (`data/biomes.json`/`arenas.json`
## `biome` tag). Pool order matters only in that it's stable input to
## `_blocked_prop_index` — do not reorder without re-screenshotting.
## `mushroom_purple_l`/`_m` are excluded on purpose -- both are decor-scale
## (native frame up to 64x88, `render_scale` only 0.5) meant for the
## OUTSIDE-the-grid cave_mouth decor band; tried inside the playable grid as
## single-cell cover they rendered 2-3x a cell's footprint, floating over
## neighboring cells and the turn-order strip (windowed screenshot,
## qa_output/level_up_loop/02_second_fight.png, first attempt). `mushroom`
## (plain, unscaled 16x16) is ALSO excluded -- its `region` crop
## (data/sprites.json [32,32,16,16] on cave/Props.png) lands on a flat
## solid-purple patch of the sheet, not a recognizable mushroom silhouette;
## at single-cell scale it read as a plain purple square -- the exact "flat
## recolored tile" problem this fix exists to remove, just purple instead of
## brown. Only `boulder` (~16x20 effective, a real rock silhouette) and
## `mushroom_purple_s` (~15x18, a real small-mushroom silhouette) read as
## physical single-cell objects; verified by windowed screenshot.
const BLOCKED_PROPS_BY_BIOME := {
	"street": ["crate", "barrel"],
	"cave": ["boulder", "mushroom_purple_s"],
}

## M5 R6: the arena board itself -- a Node2D living in `World.combat_board_
## root()` (inside the SubViewport). Re-resolved (not just cached) at the top
## of every `build()` — see that function's doc comment for why a cached
## reference can't be trusted.
var _board: Node2D
var _squares: Dictionary = {}
var _hp_bars: Dictionary = {}
var _mp_bars: Dictionary = {}
## One tween slot per combatant id, not two -- a move and a blocked-move bump
## landing on the same holder in quick succession (M5 R5 review Low #2) must
## kill whichever tween is already running before starting the other. See
## `_kill_combat_tween`.
var _combat_tweens: Dictionary = {}
var _combat_anim_tokens: Dictionary = {}
## The WIMain host, stashed from `build()`'s `main_ref` param so `clear()` and
## the labels helpers below can resolve `World`/`WIWorldLabels` without the
## caller having to pass it again on every call.
var _main_ref: Node


## M5 R4 arena floor stack z-order -- same convention as world.gd's field
## (see that file's `_build_floor` doc comment): skirt -> base floor ->
## floor_layers (dressed-skirt/dirt-transition, drawn over the base floor) ->
## blocked layer (always its own TileMapLayer, drawn last among floor-ish
## layers so it can never be visually covered) -> combatant visuals -> decor
## (arena dressing sits OUTSIDE the playable grid by contract -- see
## data/arenas.json's `decor` entries -- so draw order vs. combatants doesn't
## matter for readability, but decor is added last to match the field's
## "dressing renders over the floor stack" convention).
##
## M5 R6: resolves `_board` fresh from `World.combat_board_root()` every call
## rather than trusting a cached reference -- the World node itself gets
## torn down and recreated on `game_reset`/`game_loaded` (Main.swap_to_world,
## e.g. the defeat-reload path), which would leave a cached `_board` pointing
## at a freed node. Also centers the camera on the arena and makes the board
## visible -- `clear()` is the inverse (hide + restore field camera).
func build(view: WICombatView, main_ref: Node) -> void:
	_main_ref = main_ref
	var world := _world_node()
	if world == null:
		push_error("combat_screen: World node not found; cannot mount combat board")
		return
	_board = world.combat_board_root() as Node2D
	if _board == null:
		push_error("combat_screen: World.combat_board_root() returned null")
		return
	for child in _board.get_children():
		child.queue_free()
	_squares.clear()
	_hp_bars.clear()
	_mp_bars.clear()
	_combat_anim_tokens.clear()
	_combat_tweens.clear()
	world.enter_combat_camera(view.grid_size())
	_board.visible = true
	var biome: Dictionary = _biome_for_combat(view)
	WITileBoardBuilder.build_skirt(_board, view.grid_size(), 20, biome, WISpriteRegistry)  # 20 == world.gd SKIRT_MARGIN_CELLS (single-source someday)
	var tile_px := int(biome["tile_px"])
	var floor_layer := WITileBoardBuilder.make_tile_layer(_board, String(biome["sheet"]), tile_px, WISpriteRegistry)
	var floor_coord := Vector2i(int(biome["floor"][0]), int(biome["floor"][1]))
	for x in view.grid_size().x:
		for y in view.grid_size().y:
			floor_layer.set_cell(Vector2i(x, y), 0, floor_coord)
	_board.add_child(floor_layer)
	WITileBoardBuilder.build_floor_layers(_board, view.arena_config().get("floor_layers", []), view.grid_size(), biome, WISpriteRegistry)
	WITileBoardBuilder.build_walls(_board, view.arena_config().get("walls", {}), view.grid_size(), biome, WISpriteRegistry)

	_build_arena_blocked_cover(String(view.arena_config().get("biome", "street")), biome, tile_px, view.blocked())
	ObservableBus.emit_domain_event(WIEvents.UI_ARENA_RENDERED, {
		"arena": view.arena_id(),
		"floor_cells": view.grid_size().x * view.grid_size().y,
		"blocked_cells": view.blocked().size(),
	})
	for id: String in view.ids():
		var c: Dictionary = view.combatant(id)
		var visual := make_combatant_visual(id, c)
		_board.add_child(visual)
		_squares[id] = visual
	_build_arena_decor(view.arena_config().get("decor", []))
	_rebuild_combat_labels()


## Inverse of `build()`'s show + enter_combat_camera + label publish. Guarded
## by is_instance_valid since a defeat may already have torn the whole World
## down via Game.reset()/load_slot before this runs on some paths.
func clear() -> void:
	if _board != null and is_instance_valid(_board):
		_board.visible = false
	var world := _world_node()
	if world != null:
		world.exit_combat_camera()
	_clear_combat_labels()


## Playtest fix (props-over-tiles): renders `combat.blocked` cells as biome-
## appropriate prop sprites via the same `_make_decor_visual` pathway as arena
## decor -- so anchors/render_scale apply identically -- instead of a flat
## recolored tile. Falls back to the old flat blocked-tile rendering for any
## biome not listed in `BLOCKED_PROPS_BY_BIOME` (defensive: a future biome
## added without a prop pool degrades to the pre-fix look rather than
## silently rendering nothing on top of the floor).
func _build_arena_blocked_cover(biome_id: String, biome: Dictionary, floor_tile_px: int, blocked: Dictionary) -> void:
	var pool: Array = BLOCKED_PROPS_BY_BIOME.get(biome_id, [])
	if pool.is_empty():
		_build_arena_blocked_fallback_tile(biome, floor_tile_px, blocked.keys())
		return
	for cell: Vector2i in blocked:
		var idx := _blocked_prop_index(cell, pool.size())
		var sprite_id := String(pool[idx])
		if WISpriteRegistry.has_sprite(sprite_id):
			_board.add_child(_make_decor_visual(cell, sprite_id))
		else:
			_build_arena_blocked_fallback_tile(biome, floor_tile_px, [cell])


## Old M5 R4 flat-tile blocked rendering, kept as the fallback path for any
## biome without a defined prop pool (or a pool entry missing from the
## registry, which should never happen for the two shipped biomes).
func _build_arena_blocked_fallback_tile(biome: Dictionary, floor_tile_px: int, blocked: Array) -> void:
	if blocked.is_empty():
		return
	var blocked_sheet := String(biome.get("blocked_sheet", biome["sheet"]))
	# blocked_tile_px: the blocked sheet's own grid, which can differ from the
	# floor sheet's (e.g. street floor is a whole-image 540px dirt tile while
	# blocked cells come from the 16px Wall_Tiles) — using the floor's tile_px
	# here made blocked coords land out of atlas bounds = silent no-op walls.
	var blocked_tile_px := int(biome.get("blocked_tile_px", floor_tile_px))
	var blocked_layer := WITileBoardBuilder.make_tile_layer(_board, blocked_sheet, blocked_tile_px, WISpriteRegistry)
	var blocked_coord := Vector2i(int(biome["blocked"][0]), int(biome["blocked"][1]))
	for cell: Vector2i in blocked:
		blocked_layer.set_cell(cell, 0, blocked_coord)
	_board.add_child(blocked_layer)


## Deterministic [0, count) index for the cover prop shown at `cell` -- same
## cell always shows the same prop (stable across replays/reloads at the same
## arena), no seed dependency (blocked cells are arena-fixed layout, not a
## per-run scatter). Mirrors world.gd's `_scatter_hash` hashing shape --
## NOTE: hashing a Vector3i (not Vector2i) is load-bearing here, verified by
## hand: hashing `Vector2i(cell.x*P1, cell.y*P2)` directly for this arena's
## small blocked-cell coordinate ranges produced a near-constant low bit
## (every `goblin_ambush` blocked cell collapsed to the same pool index --
## every cover prop rendered as the same sprite); the 3-word hash spreads
## the same inputs across the full pool.
static func _blocked_prop_index(cell: Vector2i, count: int) -> int:
	if count <= 1:
		return 0
	var h := hash(Vector3i(cell.x * 73856093, cell.y * 19349663, 0))
	var frac := float(h & 0xFFFFFF) / float(0x1000000)
	return int(frac * count) % count


## Renders arena `decor` entries (M5 R4 schema) -- unlabeled dressing sprites
## positioned OUTSIDE the playable grid (data/arenas.json's contract: decor
## cells are deliberately x<0/x>=width or y<0/y>=height so dressing never
## competes with tactical-grid readability, per design doc sec.4).
func _build_arena_decor(decor_list: Array) -> void:
	for raw: Variant in decor_list:
		if not (raw is Dictionary):
			continue
		var entry := raw as Dictionary
		var sprite_id := String(entry.get("sprite", ""))
		if sprite_id == "" or not WISpriteRegistry.has_sprite(sprite_id):
			continue
		var cell := Vector2i(int(entry["cell"][0]), int(entry["cell"][1]))
		_board.add_child(_make_decor_visual(cell, sprite_id))


## Unlabeled decor visual, positioned like a combatant square (cell * CELL,
## board-local since `_board` itself is centered on screen by the camera --
## M5 R6) but without any HP/MP/name chrome -- arena counterpart of
## world.gd's decor branch inside `_make_entity_visual`.
func _make_decor_visual(cell: Vector2i, sprite_id: String) -> Node2D:
	var holder := Node2D.new()
	holder.position = Vector2(cell) * CELL
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = WISpriteRegistry.frames_for(sprite_id)
	spr.centered = false
	var anim := "idle_down" if spr.sprite_frames.has_animation("idle_down") else "idle"
	spr.play(anim)
	var catalog_entry: Dictionary = WISpriteRegistry.entry_for(sprite_id)
	if catalog_entry.has("render_scale"):
		var s := float(catalog_entry["render_scale"])
		spr.scale = Vector2(s, s)
	var frame_tex := spr.sprite_frames.get_frame_texture(anim, 0)
	var frame_size := frame_tex.get_size() if frame_tex != null else Vector2(CELL, CELL)
	var anchor := WISpriteRegistry.anchor_for(sprite_id)
	spr.position = Vector2(
		CELL * 0.5 - anchor.x * frame_size.x * spr.scale.x,
		CELL - anchor.y * frame_size.y * spr.scale.y
	)
	holder.add_child(spr)
	return holder


## Public (not just the interface-required surface) so combat_screen.gd's
## `_make_combatant_visual` compat shim (kept solely for
## `tests/test_combat_visuals.gd`'s raw-source coupling -- see the D2 report)
## can call the one real implementation instead of duplicating it.
func make_combatant_visual(id: String, c: Dictionary) -> Node2D:
	var holder := Node2D.new()
	holder.set_meta("death_visible", false)
	var sprite_id := _combatant_sprite_id(id)
	# Labels stack above the cell; the sprite branch below moves this up
	# further once the sprite's actual (possibly overhanging) top edge is
	# known, same convention as world.gd's field entities.
	var label_top := -18.0
	if sprite_id != "" and WISpriteRegistry.has_sprite(sprite_id):
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = WISpriteRegistry.frames_for(sprite_id)
		spr.centered = false
		# Initial facing (M5 E2 fix wave): the unflipped sheet row faces right
		# (see _flip_toward's convention -- flip_h true means "facing left").
		# Player-side combatants spawn at low-x and face the enemy side (right,
		# unflipped); enemy-side combatants spawn at high-x and face the player
		# side (left, flipped) until the first attack/hit event re-derives flip
		# from actual cell positions.
		spr.flip_h = (String(c["side"]) != "player")
		var anim := ""
		if spr.sprite_frames.has_animation("idle_side"):
			anim = "idle_side"
		elif spr.sprite_frames.has_animation("idle_down"):
			anim = "idle_down"
		if anim != "":
			spr.play(anim)
		var catalog_entry: Dictionary = WISpriteRegistry.entry_for(sprite_id)
		if catalog_entry.has("render_scale"):
			var scale_value := float(catalog_entry["render_scale"])
			spr.scale = Vector2(scale_value, scale_value)
		# Anchor feet/base to the cell's bottom-center (M5 R3), matching
		# world.gd's field entities so a shared combatant sprite looks
		# consistent between field and combat.
		if anim != "":
			var frame_tex := spr.sprite_frames.get_frame_texture(anim, 0)
			var frame_size := frame_tex.get_size() if frame_tex != null else Vector2(CELL, CELL)
			var anchor := WISpriteRegistry.anchor_for(sprite_id)
			spr.position = Vector2(
				CELL * 0.5 - anchor.x * frame_size.x * spr.scale.x,
				CELL - anchor.y * frame_size.y * spr.scale.y
			)
			label_top = spr.position.y - 18.0
		holder.add_child(spr)
	else:
		var rect := ColorRect.new()
		rect.color = PLAYER_COLOR if String(c["side"]) == "player" else ENEMY_COLOR
		rect.position = Vector2(3, 3)
		rect.size = Vector2(CELL - 6, CELL - 6)
		holder.add_child(rect)
	holder.set_meta("label_offset", Vector2(CELL * 0.5, maxf(label_top - 12.0, 0.0)))
	# HP/MP bars are 1-2px-tall in-viewport pixel bars hugging the cell's
	# bottom edge (M5 R3 spec §1 B3 split) -- numerals move to a native-res
	# overlay in R5; this bar is the part that stays in-viewport permanently.
	var bar := ColorRect.new()
	bar.color = Color(0.2, 0.8, 0.2)
	bar.position = Vector2(1, CELL - 3)
	bar.size = Vector2(CELL - 2, 2)
	holder.add_child(bar)
	_hp_bars[id] = bar
	# MP bar sits directly above the HP bar, only for combatants with a
	# pool (max_mp > 0 — non-casters get no bar at all, not an empty one).
	if int(c.get("max_mp", 0)) > 0:
		var mp_bar := ColorRect.new()
		mp_bar.color = MP_COLOR
		mp_bar.position = Vector2(1, CELL - 5)
		mp_bar.size = Vector2(CELL - 2, 1)
		holder.add_child(mp_bar)
		_mp_bars[id] = mp_bar
	return holder


func _biome_for_combat(view: WICombatView) -> Dictionary:
	var biomes := WIDataRegistry.biomes()
	var biome_id := String(view.arena_config().get("biome", "street"))
	assert(biomes.has(biome_id), "unknown arena biome: " + biome_id)
	return biomes[biome_id]


func _combatant_sprite_id(id: String) -> String:
	return String(WIDataRegistry.combatant_config(id).get("sprite", ""))


## M-BEAUTY R3: combat NAME tags retired (spec §8 addendum) -- entries publish
## id/anchor/offset only, no `name`. HP/MP bars (`_hp_bars`/`_mp_bars`, plain
## ColorRects on the board itself) are untouched by this change; the numeral
## readout ("57/80  MP 12/20") still rides through WIWorldLabels' `stats`
## line via `apply_stats`/`set_stats` below -- that's the sanctioned readout,
## not a tag (spec §8 pt.3). The turn-order strip (combat_hud.gd) already
## names every active/queued combatant -- that's the sanctioned name surface
## this task's spec calls out as replacing the floating tags.
func _rebuild_combat_labels() -> void:
	var labels := _world_labels()
	if labels == null:
		return
	var entries: Array = []
	for id: String in _squares:
		var visual := visual_for(id)
		if visual == null:
			continue
		entries.append({
			"id": _label_id(id),
			"anchor": visual,
			"offset": visual.get_meta("label_offset", Vector2.ZERO),
		})
	labels.rebuild_context("combat", entries)


func _label_id(id: String) -> String:
	return "combat:" + id


func _world_labels() -> WIWorldLabels:
	if _main_ref == null:
		return null
	return _main_ref.world_labels() as WIWorldLabels


## M5 R6: the World node living inside the SubViewport (`Main.world_root()`).
## Board content (`build()`) and camera centering (`enter_combat_camera`/
## `exit_combat_camera`) both go through it. Main may exist before World does
## (early in boot) or World may have just been torn down and not yet recreated
## (mid `game_reset`/`game_loaded` swap), so callers must handle a null return
## instead of caching this across calls.
func _world_node() -> Node:
	if _main_ref == null:
		return null
	return _main_ref.world_root() as Node


func _clear_combat_labels() -> void:
	var labels := _world_labels()
	if labels != null:
		labels.clear_context("combat")


func move_visual(id: String, cell: Vector2i, tween: bool) -> void:
	var visual := visual_for(id)
	if visual == null:
		return
	var target := Vector2(cell) * CELL
	var current := visual.position
	if current.is_equal_approx(target):
		return
	_kill_combat_tween(id)
	if not tween:
		visual.position = target
		return
	var duration := _presentation_delay(MOVE_TWEEN_SECONDS)
	if duration <= 0.0:
		visual.position = target
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "position", target, duration)
	_combat_tweens[id] = tw


func bump(id: String, dir: Vector2i) -> void:
	var visual := visual_for(id)
	if visual == null:
		return
	var duration := _presentation_delay(BUMP_TWEEN_SECONDS)
	if duration <= 0.0:
		return
	_kill_combat_tween(id)
	var home := visual.position
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "position", home + Vector2(dir) * BUMP_PIXELS, duration)
	tw.tween_property(visual, "position", home, duration)
	_combat_tweens[id] = tw


## Shared by both `move_visual` and `bump` (M5 R5 review Low #2) -- one active
## positional tween per holder id, regardless of which of the two started it.
func _kill_combat_tween(id: String) -> void:
	var existing := _combat_tweens.get(id, null) as Tween
	if existing != null and existing.is_valid():
		existing.kill()


func _presentation_delay(seconds: float) -> float:
	if (TestDriver != null and TestDriver.active()) or DisplayServer.get_name() == "headless":
		return 0.0
	return seconds


func visual_for(id: String) -> Node2D:
	return _squares.get(id) as Node2D


func _sprite_for(id: String) -> AnimatedSprite2D:
	var holder := visual_for(id)
	if holder == null:
		return null
	for child: Node in holder.get_children():
		if child is AnimatedSprite2D:
			return child as AnimatedSprite2D
	return null


## Bridges combat_screen.gd's `_play_event_visual` (which still lives in the
## screen -- it's shared between the live and paced-AI-playback render paths,
## neither of which is this task's move list) past the fact that `_sprite_for`
## itself is now private to this renderer.
func has_sprite(id: String) -> bool:
	return _sprite_for(id) != null


func _chip_for(id: String) -> ColorRect:
	var holder := visual_for(id)
	if holder == null:
		return null
	for child: Node in holder.get_children():
		if child is ColorRect:
			return child as ColorRect
	return null


func death_visible(id: String) -> bool:
	var visual := visual_for(id)
	return visual != null and bool(visual.get_meta("death_visible", false))


func set_visible(id: String, value: bool) -> void:
	var visual := visual_for(id)
	if visual != null:
		visual.visible = value


func play_anim(id: String, prefix: String, flip_h: Variant = null) -> void:
	var spr := _sprite_for(id)
	if spr == null or spr.sprite_frames == null:
		return
	if flip_h is bool:
		spr.flip_h = bool(flip_h)
	var anim := "%s_side" % prefix
	if not spr.sprite_frames.has_animation(anim):
		anim = prefix if spr.sprite_frames.has_animation(prefix) else "idle_side"
	if prefix == "death" and not anim.begins_with("death"):
		# No death animation on this sheet (e.g. goblins) -- resolving to an
		# idle* fallback would loop forever on a "downed" combatant (M5 E2
		# fix wave finding 1). Fade instead, reusing the fade_chip tween
		# pattern; death_visible was already set by mark_death_visible
		# before this call, so the sprite stays visible per the T9/T10
		# death_visible contract, just dimmed like the chip fallback.
		fade_chip(id)
		return
	if spr.sprite_frames.has_animation(anim):
		spr.play(anim)
	if prefix != "death":
		queue_idle(id)


func queue_idle(id: String) -> void:
	_combat_anim_tokens[id] = int(_combat_anim_tokens.get(id, 0)) + 1
	var token := int(_combat_anim_tokens[id])
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if int(_combat_anim_tokens.get(id, 0)) != token:
			return
		var holder := visual_for(id)
		if holder == null or bool(holder.get_meta("death_visible", false)):
			return
		var spr := _sprite_for(id)
		if spr != null and spr.sprite_frames != null and spr.sprite_frames.has_animation("idle_side"):
			spr.play("idle_side")
	)


func flash_chip(id: String) -> void:
	var chip := _chip_for(id)
	if chip == null:
		return
	chip.modulate = Color(1.7, 1.7, 1.7, 1.0)
	var tw := create_tween()
	tw.tween_property(chip, "modulate", Color.WHITE, 0.15)


func fade_chip(id: String) -> void:
	var holder := visual_for(id)
	if holder == null:
		return
	var tw := create_tween()
	tw.tween_property(holder, "modulate:a", 0.3, 0.2)


func mark_death_visible(id: String) -> void:
	var visual := visual_for(id)
	if visual != null:
		visual.set_meta("death_visible", true)


## Cheap cast readability: tween a translucent colored rect over each cell.
func flash_cells(cells: Array, color: Color) -> void:
	for cell: Vector2i in cells:
		var f := ColorRect.new()
		f.name = "CastFlash"
		f.color = Color(color.r, color.g, color.b, 0.55)
		f.position = Vector2(cell) * CELL
		f.size = Vector2(CELL, CELL)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.z_index = 20
		_board.add_child(f)
		var tw := create_tween()
		tw.tween_property(f, "modulate:a", 0.0, 0.35)
		tw.tween_callback(f.queue_free)


## Applies an hp/max_hp/mp/max_mp dict to one combatant's bars/labels. Shared
## by the live per-combatant refresh (combat_screen.gd's `_refresh_combatants`,
## fed the view's current `stats(id)`) and paced AI playback
## (`_apply_captured_stats`, fed the enqueue-time snapshot `_capture_event_ui`
## recorded for that beat) so both paths format the HP/MP readout identically.
func apply_stats(id: String, stats: Dictionary) -> void:
	if stats.is_empty():
		return
	if _hp_bars.has(id):
		var max_hp := int(stats.get("max_hp", 0))
		(_hp_bars[id] as ColorRect).size.x = (CELL - 2) * float(stats.get("hp", 0)) / float(max_hp) if max_hp > 0 else 0.0
	var hp_text := "%d/%d" % [int(stats.get("hp", 0)), int(stats.get("max_hp", 0))]
	if _mp_bars.has(id):
		var max_mp := int(stats.get("max_mp", 0))
		(_mp_bars[id] as ColorRect).size.x = (CELL - 2) * float(stats.get("mp", 0)) / float(max_mp) if max_mp > 0 else 0.0
		hp_text += "  MP %d/%d" % [int(stats.get("mp", 0)), max_mp]
	var labels := _world_labels()
	if labels != null:
		labels.set_stats(_label_id(id), hp_text)
