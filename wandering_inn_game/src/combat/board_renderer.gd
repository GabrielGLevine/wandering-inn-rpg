class_name WICombatBoardRenderer
extends Node

const CELL := 16
const PLAYER_COLOR := Color(0.25, 0.45, 0.9)
const ENEMY_COLOR := Color(0.75, 0.25, 0.2)
const MP_COLOR := Color(0.25, 0.4, 0.85)
const ALLY_HP_COLOR := Color(0.2, 0.8, 0.2)
const ENEMY_HP_COLOR := Color(0.95, 0.45, 0.05)
const ICY_FLOOR_COLOR := Color(0.5, 0.8, 1.0, 0.35)
## Issue #82's WINDUP SIM SPEC / [Dangersense] payoff: the frozen-cell overlay
## for a declared windup, rendered ONLY for a [Dangersense] holder
## (combat_playback.gd's `_capture_event_ui` gates the `add_terrain` call
## itself -- this file draws whatever it's told, same as every other overlay
## kind). Warm red, distinct from the frost-blue `ICY_FLOOR_COLOR` and the
## amber `AIM_AOE_TINT` (that one is the PLAYER's own aim, this is an
## INCOMING threat) -- a strong enough alpha to read as "leave this cell",
## not a decorative tint. CONSTRAINT: this overlay must survive the DARKEST
## arena grade (the vault's CanvasModulate ~[0.21,0.22,0.19] multiplies it) --
## at the original (0.9,0.15,0.1,0.4) the post-grade delta over the floor was
## ~13/255, near-invisible exactly where the [Dangersense] payoff matters
## most. Bright base + high alpha is deliberate: a danger telegraph should
## be loud on every grade.
const WINDUP_DANGER_COLOR := Color(1.0, 0.25, 0.2, 0.7)
## z-index split: terrain overlays render at COMBATANT_Z - 1 so they
## always sit ABOVE the floor/decor (both default z_index 0) but BELOW every
## combatant visual, regardless of scene-tree add order -- `add_terrain` is
## called dynamically mid-combat (after `build()`'s own children are already
## in place), so relying on tree order alone would put a freshly-added
## overlay on TOP of everything.
const COMBATANT_Z := 1
const MOVE_TWEEN_SECONDS := 0.12
const BUMP_PIXELS := 3.0
const BUMP_TWEEN_SECONDS := 0.06
## Issue #75 item 1 (aim preview): board-space paint while ATTACK/SKILL_TARGET
## is armed. Renders in the SAME z_index band as terrain (0, below
## COMBATANT_Z) but added to `_board` AFTER it every `render_aim_preview()`
## call, so tree order draws it above any live terrain overlay -- same
## "z_index ties break on add order" convention `add_terrain`'s own doc
## comment relies on. RANGE tint is deliberately faint (a reach affordance,
## not a hit guarantee); the AOE tint (line/blast footprint) is brighter --
## those cells WILL be hit if confirmed; the ring is brightest, marking the
## exact currently-selected candidate.
const AIM_RANGE_TINT := Color(1.0, 1.0, 1.0, 0.10)
const AIM_AOE_TINT := Color(1.0, 0.82, 0.25, 0.32)
const AIM_RING_COLOR := Color(1.0, 0.95, 0.25, 0.95)
const AIM_RING_THICKNESS := 2.0
## Impact damage numbers (item 2) -- a floating world-space label at the
## struck cell, brief rise-fade, juice-gated like every other combat-feel
## effect (`_juice_enabled` -> `_presentation_delay`, zero under TestDriver/
## headless -- byte-identical event stream). Colors reuse the SAME
## ALLY_HP_COLOR/ENEMY_HP_COLOR hues the struck combatant's own HP bar
## already uses for "who got hit", so the player never has to learn a second
## palette. `MISS_COLOR` is neutral -- a miss must never read as "0 damage".
const DAMAGE_NUMBER_RISE_PX := 10.0
const DAMAGE_NUMBER_SECONDS := 0.6
const MISS_COLOR := Color(0.85, 0.85, 0.85, 0.95)
const LUNGE_PIXELS := 5.0
const LUNGE_TWEEN_SECONDS := 0.07
const PROJECTILE_SECONDS := 0.12
const PROJECTILE_THICKNESS := 3.0
const PROJECTILE_DEFAULT_COLOR := Color(0.92, 0.92, 0.85, 0.9)
## Status pips (item 4): a small per-status dot over a combatant's holder,
## top-right corner (HP/MP bars already own the bottom edge). DATA-DRIVEN --
## keyed by status id off STATUS_APPLIED/STATUS_EXPIRED's own payload, never
## a skill name, so a future status entry added to this map rides the same
## dispatch for free. `invisible` is deliberately absent -- it already has
## its own alpha-fade tell (`set_combatant_alpha`); a pip on top would be
## redundant.
const STATUS_PIP_COLORS := {
	"slowed": Color(0.55, 0.85, 1.0, 0.95),
	"weakened": Color(0.75, 0.55, 0.85, 0.95),
	"guarded": Color(0.85, 0.75, 0.35, 0.95),
	"rooted": Color(0.55, 0.4, 0.25, 0.95),
	"burning": Color(1.0, 0.45, 0.2, 0.95),
}
const STATUS_PIP_SIZE := Vector2(4.0, 4.0)
const ACTIVE_MARKER_COLOR := Color(1.0, 0.95, 0.3, 1.0)
const ACTIVE_MARKER_TIP_Y := -6.0
const ACTIVE_MARKER_BASE_Y := -12.0
const ACTIVE_MARKER_HALF_WIDTH := 4.0
const HIT_FLASH_COLOR := Color(2.4, 2.4, 2.4, 1.0)  # white-hot pulse on the struck sprite
const HIT_FLASH_SECONDS := 0.12
const SHAKE_SECONDS := 0.12
const SHAKE_SEGMENTS := 4
const SPARKS_TTL := 0.7  # frees the one-shot GPUParticles2D safely past its 0.4 lifetime
## Playtest fix (props-over-tiles, repo-wide user mandate — see
## wi-art-and-sprites SKILL.md): arena cover/blocked cells render as biome-
## appropriate PROP SPRITES instead of a flat recolored tile. Existing
## sprites.json entries only, per biome id (`data/biomes.json`/`arenas.json`
## `biome` tag). Pool order matters only in that it's stable input to
## `_blocked_prop_index` — do not reorder without re-screenshotting.
const BLOCKED_PROPS_BY_BIOME := {
	"street": ["crate", "barrel"],
	"cave": ["boulder", "mushroom_purple_s"],
	## witch_hollow: the exploration map's bent-tree-ring identity must
	## survive into the briar fights. `hollow_bent_tree` is the map's own
	## small-tree pick re-scaled to single-cell cover (its sprites.json
	## entry documents the scale constraint); `bush_green` is already
	## cell-sized. Both are real silhouettes, not flat recolored tiles.
	"witch_hollow": ["hollow_bent_tree", "bush_green"],
	"riverfarm_village": ["boulder", "bush_green"],
	"inn": ["crate", "barrel"],
}

const MOODS_PATH := "res://data/moods.json"
const LEGIBILITY_TARGET := 0.85
## Clamp on the computed boost so the very darkest pins (deep_tunnels/
## deep_warren, avg ~0.25) don't get blown out toward flat white.
const LEGIBILITY_MAX_BOOST := 3.0

static var _moods_cache: Dictionary = {}

var _board: Node2D
var _squares: Dictionary = {}
var _hp_bars: Dictionary = {}
var _mp_bars: Dictionary = {}
## One tween slot per combatant id, not two -- a move and a blocked-move bump
## landing on the same holder in quick succession must
## kill whichever tween is already running before starting the other. See
## `_kill_combat_tween`.
var _combat_tweens: Dictionary = {}
var _combat_anim_tokens: Dictionary = {}
var _shake_tween: Tween
var _main_ref: Node
## Persistent per-cell overlays,
## kind -> {Vector2i: ColorRect}. Unlike `flash_cells` (a transient tween
## that self-frees), these stay on the board until `expire_terrain` removes
## them or the whole board tears down (`build()`'s wholesale queue_free of
## every `_board` child already covers that -- see `add_terrain`'s doc
## comment for the z-order contract that keeps them under combatant
## visuals).
var _terrain_overlays: Dictionary = {}
var _aim_preview_nodes: Array = []
var _last_aim_preview_key := ""
var _status_pips: Dictionary = {}
var _active_marker: Node2D
var _active_marker_id := ""

var _legibility_boost: Color = Color(1.0, 1.0, 1.0, 1.0)


## Arena floor stack z-order -- same convention as world.gd's field
## (see that file's `_build_floor` doc comment): skirt -> base floor ->
## floor_layers (dressed-skirt/dirt-transition, drawn over the base floor) ->
## blocked layer (always its own TileMapLayer, drawn last among floor-ish
## layers so it can never be visually covered) -> combatant visuals -> decor
## (arena dressing sits OUTSIDE the playable grid by contract -- see
## data/arenas.json's `decor` entries -- so draw order vs. combatants doesn't
## matter for readability, but decor is added last to match the field's
## "dressing renders over the floor stack" convention).
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
	# A screenshake left mid-tween by a previous encounter (defeat
	# reload, rapid re-entry) must never leave the reused board root offset --
	# reset it and drop any live shake tween before building the new arena.
	_stop_shake()
	_squares.clear()
	_hp_bars.clear()
	_mp_bars.clear()
	_combat_anim_tokens.clear()
	_combat_tweens.clear()
	_terrain_overlays.clear()
	_aim_preview_nodes.clear()
	_last_aim_preview_key = ""
	_status_pips.clear()
	_active_marker = null
	_active_marker_id = ""
	world.enter_combat_camera(view.grid_size())
	_board.visible = true
	_legibility_boost = _legibility_modulate(view)
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


func clear() -> void:
	_stop_shake()
	if _board != null and is_instance_valid(_board):
		_board.visible = false
	var world := _world_node()
	if world != null:
		world.exit_combat_camera()
	_clear_combat_labels()
	_terrain_overlays.clear()
	_aim_preview_nodes.clear()
	_last_aim_preview_key = ""
	_status_pips.clear()
	_active_marker = null
	_active_marker_id = ""


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


func _build_arena_blocked_fallback_tile(biome: Dictionary, floor_tile_px: int, blocked: Array) -> void:
	if blocked.is_empty():
		return
	var blocked_sheet := String(biome.get("blocked_sheet", biome["sheet"]))
	var blocked_tile_px := int(biome.get("blocked_tile_px", floor_tile_px))
	var blocked_layer := WITileBoardBuilder.make_tile_layer(_board, blocked_sheet, blocked_tile_px, WISpriteRegistry)
	var blocked_coord := Vector2i(int(biome["blocked"][0]), int(biome["blocked"][1]))
	for cell: Vector2i in blocked:
		blocked_layer.set_cell(cell, 0, blocked_coord)
	_board.add_child(blocked_layer)


static func _blocked_prop_index(cell: Vector2i, count: int) -> int:
	if count <= 1:
		return 0
	var h := hash(Vector3i(cell.x * 73856093, cell.y * 19349663, 0))
	var frac := float(h & 0xFFFFFF) / float(0x1000000)
	return int(frac * count) % count


## Renders arena `decor` entries -- unlabeled dressing sprites
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
		_board.add_child(_make_decor_visual(cell, sprite_id, entry.get("tint", [])))


func _make_decor_visual(cell: Vector2i, sprite_id: String, tint: Variant = []) -> Node2D:
	var holder := Node2D.new()
	holder.position = Vector2(cell) * CELL
	var spr := AnimatedSprite2D.new()
	# GH#169: pixel sprites stay crisp at ANY render_scale (the 0.55 rock
	# crab blurred under the default Linear filter); UI chrome keeps Linear.
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.sprite_frames = WISpriteRegistry.frames_for(sprite_id)
	spr.centered = false
	var anim := "idle_down" if spr.sprite_frames.has_animation("idle_down") else "idle"
	spr.play(anim)
	if tint is Array and (tint as Array).size() == 3:
		var tint_values := tint as Array
		spr.modulate = Color(float(tint_values[0]), float(tint_values[1]), float(tint_values[2]))
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
	# Explicit z_index (see the COMBATANT_Z const doc comment) so a
	# terrain overlay added later at z_index 0 can never render on top of a
	# combatant, regardless of tree add order.
	holder.z_index = COMBATANT_Z
	# "shield_spider_2") does not exist in the static combatants.json catalog
	# -- any lookup that needs the catalog record (sprite, combat_scale) must
	# use TEMPLATE_ID (the pre-suffix id), never `id` itself. Falls back to
	# `id` when TEMPLATE_ID is absent (hand-built dicts in older tests).
	var template_id := String(c.get(WIKeys.TEMPLATE_ID, id))
	var sprite_id := _combatant_sprite_id(id, template_id)
	var label_top := -18.0
	if sprite_id != "" and WISpriteRegistry.has_sprite(sprite_id):
		var spr := AnimatedSprite2D.new()
		# GH#169: pixel sprites stay crisp at ANY render_scale (the 0.55 rock
		# crab blurred under the default Linear filter); UI chrome keeps Linear.
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.sprite_frames = WISpriteRegistry.frames_for(sprite_id)
		spr.centered = false
		spr.flip_h = (String(c["side"]) != "player")
		var anim := ""
		if spr.sprite_frames.has_animation("idle_side"):
			anim = "idle_side"
		elif spr.sprite_frames.has_animation("idle_down"):
			anim = "idle_down"
		elif spr.sprite_frames.has_animation("idle"):
			anim = "idle"
		if anim != "":
			spr.play(anim)
		var catalog_entry: Dictionary = WISpriteRegistry.entry_for(sprite_id)
		var scale_value := 1.0
		if catalog_entry.has("render_scale"):
			scale_value = float(catalog_entry["render_scale"])
		var combat_scale: Variant = WIDataRegistry.combatant_config(template_id).get("combat_scale")
		if combat_scale != null:
			scale_value = float(combat_scale)
		if scale_value != 1.0:
			spr.scale = Vector2(scale_value, scale_value)
		if anim != "":
			var frame_tex := spr.sprite_frames.get_frame_texture(anim, 0)
			var frame_size := frame_tex.get_size() if frame_tex != null else Vector2(CELL, CELL)
			var anchor := WISpriteRegistry.anchor_for(sprite_id)
			spr.position = Vector2(
				CELL * 0.5 - anchor.x * frame_size.x * spr.scale.x,
				CELL - anchor.y * frame_size.y * spr.scale.y
			)
			label_top = spr.position.y - 18.0
		spr.self_modulate = _legibility_boost
		holder.add_child(spr)
	else:
		var rect := ColorRect.new()
		rect.color = PLAYER_COLOR if String(c["side"]) == "player" else ENEMY_COLOR
		rect.position = Vector2(3, 3)
		rect.size = Vector2(CELL - 6, CELL - 6)
		rect.self_modulate = _legibility_boost
		holder.add_child(rect)
	holder.set_meta("label_offset", Vector2(CELL * 0.5, maxf(label_top - 12.0, 0.0)))
	var bar := ColorRect.new()
	bar.color = ALLY_HP_COLOR if String(c["side"]) == "player" else ENEMY_HP_COLOR
	bar.position = Vector2(1, CELL - 3)
	bar.size = Vector2(CELL - 2, 2)
	bar.self_modulate = _legibility_boost
	holder.add_child(bar)
	_hp_bars[id] = bar
	if int(c.get("max_mp", 0)) > 0:
		var mp_bar := ColorRect.new()
		mp_bar.color = MP_COLOR
		mp_bar.position = Vector2(1, CELL - 5)
		mp_bar.size = Vector2(CELL - 2, 1)
		mp_bar.self_modulate = _legibility_boost
		holder.add_child(mp_bar)
		_mp_bars[id] = mp_bar
	return holder


func _biome_for_combat(view: WICombatView) -> Dictionary:
	var biomes := WIDataRegistry.biomes()
	var biome_id := String(view.arena_config().get("biome", "street"))
	assert(biomes.has(biome_id), "unknown arena biome: " + biome_id)
	return biomes[biome_id]


## goblin_ambush/training_yard/chieftains_raid inheriting whatever the
## overworld is currently showing) -- read directly from moods.json (own
## tiny cache, same load-once idiom as atmosphere.gd's `_moods_data`)
## rather than calling into WIAtmosphere: this task must not touch that
## file's grading, and a read-only duplicate lookup here can never affect
## what apply()/apply_arena() actually do. Falls back to identity [1,1,1]
## for any arena/map/phase this data doesn't cover, same fallback
## philosophy as atmosphere.gd's own apply().
static func _resolved_mood_rgb(arena_id: String, map_id: String, phase: String) -> Color:
	if _moods_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOODS_PATH))
		_moods_cache = parsed if parsed is Dictionary else {}
	var arena_moods: Dictionary = _moods_cache.get("arena_moods", {})
	var mood: Dictionary = arena_moods.get(arena_id, {})
	if mood.is_empty():
		mood = (_moods_cache.get("moods", {}) as Dictionary).get(map_id, {})
	var rgb: Array = mood.get(phase, [1.0, 1.0, 1.0])
	if not (rgb is Array) or rgb.size() != 3:
		return Color(1.0, 1.0, 1.0)
	return Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))


## GH #28 DARK-ARENAS: the self_modulate boost `make_combatant_visual`/
## `apply_stats` apply to every combatant sprite/chip/HP-bar this build() --
## identity whenever the arena's resolved mood already clears
## LEGIBILITY_TARGET (every bright arena renders byte-identical to before
## this fix), otherwise scaled up to hit the target average brightness,
## clamped so the darkest pins don't blow out toward flat white.
func _legibility_modulate(view: WICombatView) -> Color:
	var mood := _resolved_mood_rgb(view.arena_id(), String(Game.sim.current_map), Game.sim.phase())
	var avg := (mood.r + mood.g + mood.b) / 3.0
	if avg >= LEGIBILITY_TARGET:
		return Color(1.0, 1.0, 1.0, 1.0)
	var boost := clampf(LEGIBILITY_TARGET / maxf(avg, 0.05), 1.0, LEGIBILITY_MAX_BOOST)
	return Color(boost, boost, boost, 1.0)


func _combatant_sprite_id(id: String, template_id: String) -> String:
	if id == "pc":
		var key := Game.sim.pc_sprite_variant()
		if WISpriteRegistry.has_sprite(key):
			return key
	return String(WIDataRegistry.combatant_config(template_id).get("sprite", ""))


## Combat NAME tags retired (spec §8 addendum) -- entries publish
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


func set_combatant_alpha(id: String, alpha: float) -> void:
	var visual := visual_for(id)
	if visual != null:
		visual.modulate.a = alpha


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
		# Fade instead, reusing the fade_chip tween
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
	if _reduce_motion():
		return
	var chip := _chip_for(id)
	if chip == null:
		return
	chip.modulate = Color(1.7, 1.7, 1.7, 1.0)
	var tw := create_tween()
	tw.tween_property(chip, "modulate", Color.WHITE, 0.15)


## Death beat (spec item 5): a brief slow-fade of the whole combatant holder
## to a dim ghost instead of an instant pop-out -- the sprite stays VISIBLE
## (death_visible contract: earlier queued beats still animate against its
## cell). Reads only the passed id + its own holder, never live combat state,
## so it is dequeue-safe under paced AI playback. Used for chip combatants and
## for sprite sheets with no death animation (play_anim's death fallback), while
## sheets that DO have a `death_*` clip play that instead (body_a/PC).
func fade_chip(id: String) -> void:
	var holder := visual_for(id)
	if holder == null:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "modulate:a", 0.28, 0.3)


func mark_death_visible(id: String) -> void:
	var visual := visual_for(id)
	if visual != null:
		visual.set_meta("death_visible", true)


func flash_cells(cells: Array, color: Color) -> void:
	if _reduce_motion():
		return
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


## Persistent per-cell overlay --
## one semi-transparent ColorRect per cell, unlike `flash_cells`' one-shot
## tween. `z_index` defaults to 0 (the const block's COMBATANT_Z split keeps
## it under every combatant regardless of add order); it renders over the
## floor/decor simply because it's added to `_board` AFTER `build()`'s floor
## construction (both at z_index 0, so tree order alone settles floor vs.
func add_terrain(kind: String, cells: Array) -> void:
	if _board == null:
		return
	var by_kind: Dictionary = _terrain_overlays.get(kind, {})
	var color := Color(1.0, 1.0, 1.0, 0.35)
	if kind == "icy_floor":
		color = ICY_FLOOR_COLOR
	elif kind == "windup_danger":
		color = WINDUP_DANGER_COLOR
	var cells_payload: Array = []
	for cell: Vector2i in cells:
		if by_kind.has(cell):
			var stale: ColorRect = by_kind[cell]
			if is_instance_valid(stale):
				stale.queue_free()
		var rect := ColorRect.new()
		rect.name = "Terrain_%s_%d_%d" % [kind, cell.x, cell.y]
		rect.color = color
		rect.position = Vector2(cell) * CELL
		rect.size = Vector2(CELL, CELL)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.add_child(rect)
		by_kind[cell] = rect
		cells_payload.append([cell.x, cell.y])
	_terrain_overlays[kind] = by_kind
	ObservableBus.emit_domain_event(WIEvents.UI_TERRAIN_RENDERED, {"kind": kind, "cells": cells_payload})


func expire_terrain(kind: String, cells: Array) -> void:
	var by_kind: Dictionary = _terrain_overlays.get(kind, {})
	if by_kind.is_empty():
		return
	for cell: Vector2i in cells:
		if by_kind.has(cell):
			var rect: ColorRect = by_kind[cell]
			if is_instance_valid(rect):
				rect.queue_free()
			by_kind.erase(cell)
	_terrain_overlays[kind] = by_kind


## Board-space aim-preview paint (issue #75 item 1) -- `state` is
## `WICombatTargeting.aim_preview()`'s return shape (`kind`, `ring_cell`,
## `range_cells`, `line_cells`, `blast_cells`); this function only PAINTS, it
## derives nothing (see that function's own doc comment for the "cannot lie"
## derivation contract). Called every `combat_screen.gd._refresh()` while
## ATTACK/SKILL_TARGET is armed; `clear_aim_preview()` on every other mode --
## cancel/confirm/mode-exit all route through the SAME `_refresh()`
## in_targeting branch there, so no separate teardown call is needed for
## those. Deliberately NOT gated behind `_juice_enabled()` -- this is aim
## STATE, not transient combat feel, so it (and its ui_aim_preview_rendered
## confirmation) must render identically under headless QA and real play.
func render_aim_preview(state: Dictionary) -> void:
	_clear_aim_preview_nodes()
	if _board == null or state.is_empty():
		return
	var kind := String(state.get("kind", ""))
	for cell: Vector2i in (state.get("range_cells", []) as Array):
		_aim_preview_nodes.append(_add_aim_tint(cell, AIM_RANGE_TINT))
	var line_cells: Array = state.get("line_cells", [])
	var blast_cells: Array = state.get("blast_cells", [])
	var aoe_cells: Array = line_cells if not line_cells.is_empty() else blast_cells
	for cell: Vector2i in aoe_cells:
		_aim_preview_nodes.append(_add_aim_tint(cell, AIM_AOE_TINT))
	var ring_cell: Variant = state.get("ring_cell", null)
	if ring_cell is Vector2i:
		_aim_preview_nodes.append(_add_aim_ring(ring_cell as Vector2i))
	var primary_cells: Array = aoe_cells if not aoe_cells.is_empty() else ([ring_cell] if ring_cell is Vector2i else [])
	_emit_aim_preview_event(kind, primary_cells)


func clear_aim_preview() -> void:
	_clear_aim_preview_nodes()
	_last_aim_preview_key = ""


func _clear_aim_preview_nodes() -> void:
	for node: Node in _aim_preview_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_aim_preview_nodes.clear()


func _add_aim_tint(cell: Vector2i, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "AimTint"
	rect.color = color
	rect.position = Vector2(cell) * CELL
	rect.size = Vector2(CELL, CELL)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(rect)
	return rect


func _add_aim_ring(cell: Vector2i) -> Node2D:
	var holder := Node2D.new()
	holder.name = "AimRing"
	var origin := Vector2(cell) * CELL
	var t := AIM_RING_THICKNESS
	var edges: Array[Rect2] = [
		Rect2(origin, Vector2(CELL, t)),
		Rect2(origin + Vector2(0.0, CELL - t), Vector2(CELL, t)),
		Rect2(origin, Vector2(t, CELL)),
		Rect2(origin + Vector2(CELL - t, 0.0), Vector2(t, CELL)),
	]
	for edge: Rect2 in edges:
		var rect := ColorRect.new()
		rect.color = AIM_RING_COLOR
		rect.position = edge.position
		rect.size = edge.size
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rect)
	_board.add_child(holder)
	return holder


func _emit_aim_preview_event(kind: String, cells: Array) -> void:
	var cells_payload: Array = []
	for cell: Vector2i in cells:
		cells_payload.append([cell.x, cell.y])
	var key := "%s:%s" % [kind, str(cells_payload)]
	if key == _last_aim_preview_key:
		return
	_last_aim_preview_key = key
	ObservableBus.emit_domain_event(WIEvents.UI_AIM_PREVIEW_RENDERED, {"kind": kind, "cells": cells_payload})


func spawn_damage_number(cell_xy: Array, amount: int, side: String) -> void:
	if not _juice_enabled() or _board == null or cell_xy.size() < 2:
		return
	var color := ALLY_HP_COLOR if side == "player" else ENEMY_HP_COLOR
	_spawn_floating_text(cell_xy, str(amount), color)


func spawn_miss_indicator(cell_xy: Array) -> void:
	if not _juice_enabled() or _board == null or cell_xy.size() < 2:
		return
	_spawn_floating_text(cell_xy, "Miss", MISS_COLOR)


func _spawn_floating_text(cell_xy: Array, text: String, color: Color) -> void:
	var label := UIChrome.make_label(text, "Small")
	label.theme = UIChrome.THEME
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 25
	label.custom_minimum_size = Vector2(CELL * 2.0, 14.0)
	label.size = label.custom_minimum_size
	var origin := Vector2(int(cell_xy[0]), int(cell_xy[1])) * CELL
	label.position = origin + Vector2(CELL * 0.5 - label.custom_minimum_size.x * 0.5, -label.custom_minimum_size.y)
	_board.add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - DAMAGE_NUMBER_RISE_PX, DAMAGE_NUMBER_SECONDS)
	tw.tween_property(label, "modulate:a", 0.0, DAMAGE_NUMBER_SECONDS)
	tw.set_parallel(false)
	tw.tween_callback(label.queue_free)


func micro_lunge(id: String, target_cell: Array) -> void:
	if not _juice_enabled() or target_cell.size() < 2:
		return
	var visual := visual_for(id)
	if visual == null:
		return
	var to := Vector2(int(target_cell[0]), int(target_cell[1])) * CELL
	var dir := to - visual.position
	if dir == Vector2.ZERO:
		return
	dir = dir.normalized()
	_kill_combat_tween(id)
	var home := visual.position
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "position", home + dir * LUNGE_PIXELS, LUNGE_TWEEN_SECONDS)
	tw.tween_property(visual, "position", home, LUNGE_TWEEN_SECONDS)
	_combat_tweens[id] = tw


func spawn_projectile(from_cell: Array, to_cell: Array, color: Color) -> void:
	if not _juice_enabled() or _board == null or from_cell.size() < 2 or to_cell.size() < 2:
		return
	var half_cell := Vector2(CELL, CELL) * 0.5
	var from := Vector2(int(from_cell[0]), int(from_cell[1])) * CELL + half_cell
	var to := Vector2(int(to_cell[0]), int(to_cell[1])) * CELL + half_cell
	if from.is_equal_approx(to):
		return
	var streak := Line2D.new()
	streak.name = "ProjectileStreak"
	streak.width = PROJECTILE_THICKNESS
	streak.default_color = color if color.a > 0.0 else PROJECTILE_DEFAULT_COLOR
	streak.z_index = 22
	streak.add_point(from)
	streak.add_point(to)
	_board.add_child(streak)
	var tw := create_tween()
	tw.tween_property(streak, "modulate:a", 0.0, PROJECTILE_SECONDS)
	tw.tween_callback(streak.queue_free)


func set_status_pip(id: String, status_id: String, active: bool) -> void:
	if not STATUS_PIP_COLORS.has(status_id):
		return
	var visual := visual_for(id)
	if visual == null:
		return
	var pips: Dictionary = _status_pips.get(id, {})
	if active:
		var existing: Variant = pips.get(status_id)
		if existing != null and is_instance_valid(existing):
			return
		var dot := ColorRect.new()
		dot.name = "StatusPip_%s" % status_id
		dot.color = STATUS_PIP_COLORS[status_id]
		dot.size = STATUS_PIP_SIZE
		dot.position = Vector2(CELL - STATUS_PIP_SIZE.x - 1.0, 1.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.add_child(dot)
		pips[status_id] = dot
	else:
		var dot: Variant = pips.get(status_id)
		if dot != null and is_instance_valid(dot):
			(dot as Node).queue_free()
		pips.erase(status_id)
	_status_pips[id] = pips


func set_active_marker(id: String) -> void:
	if _active_marker != null and is_instance_valid(_active_marker):
		_active_marker.queue_free()
	_active_marker = null
	_active_marker_id = id
	var visual := visual_for(id)
	if visual == null:
		return
	var marker := Polygon2D.new()
	marker.name = "ActiveMarker"
	marker.color = ACTIVE_MARKER_COLOR
	marker.polygon = PackedVector2Array([
		Vector2(CELL * 0.5 - ACTIVE_MARKER_HALF_WIDTH, ACTIVE_MARKER_BASE_Y),
		Vector2(CELL * 0.5 + ACTIVE_MARKER_HALF_WIDTH, ACTIVE_MARKER_BASE_Y),
		Vector2(CELL * 0.5, ACTIVE_MARKER_TIP_Y),
	])
	visual.add_child(marker)
	_active_marker = marker


func clear_active_marker() -> void:
	if _active_marker != null and is_instance_valid(_active_marker):
		_active_marker.queue_free()
	_active_marker = null
	_active_marker_id = ""


## board_renderer.gd already references autoloads directly (ObservableBus/
## Game/TestDriver -- unlike combat_hud.gd/targeting_controller.gd's
## autoload-free contract), so a bare `WISettings` reference here is
## consistent with the existing pattern, not a new one.
func _reduce_motion() -> bool:
	return WISettings.reduce_motion()


func _juice_enabled() -> bool:
	if _reduce_motion():
		return false
	return _presentation_delay(1.0) > 0.0


func impact_flash(id: String) -> void:
	if not _juice_enabled():
		return
	var spr := _sprite_for(id)
	if spr == null:
		return
	spr.modulate = HIT_FLASH_COLOR
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color.WHITE, HIT_FLASH_SECONDS)


## Brief screenshake on the combat BOARD ROOT (`_board.position`) --
## the world-space Node2D that holds every combatant/tile, NOT the UI
## CanvasLayer (which must never jitter). `intensity` is 2-4px; a decaying
## multi-step tween that always lands back on Vector2.ZERO. QA-collapsed
## (no-op) so a headless/TestDriver screenshot can never catch a shifted board.
func shake_board(intensity: float) -> void:
	if not _juice_enabled() or _board == null:
		return
	_stop_shake()
	var tw := create_tween()
	var seg := SHAKE_SECONDS / float(SHAKE_SEGMENTS + 1)
	for i in SHAKE_SEGMENTS:
		var decay := 1.0 - float(i) / float(SHAKE_SEGMENTS)
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var offset := dir.normalized() * intensity * decay
		tw.tween_property(_board, "position", offset, seg)
	tw.tween_property(_board, "position", Vector2.ZERO, seg)
	_shake_tween = tw


func _stop_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	if _board != null and is_instance_valid(_board):
		_board.position = Vector2.ZERO


func spawn_hit_sparks(cell_xy: Array) -> void:
	if not _juice_enabled() or _board == null or cell_xy.size() < 2:
		return
	var origin := Vector2(int(cell_xy[0]), int(cell_xy[1])) * CELL
	var rect := Rect2(origin, Vector2(CELL, CELL))
	var sparks := WIAmbience.make("hit_sparks", rect)
	if sparks == null:
		return
	sparks.z_index = 30
	sparks.emitting = true
	_board.add_child(sparks)
	get_tree().create_timer(SPARKS_TTL).timeout.connect(sparks.queue_free)


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
