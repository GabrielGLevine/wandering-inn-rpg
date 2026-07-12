class_name WICombatBoardRenderer
extends Node
## The board/sprite region, extracted from combat_screen.gd -- arena tiles/skirt/walls (via `WITileBoardBuilder`),
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
## HP bars were one green regardless of side -- with combat name tags
## retired (R3), the turn strip was the only friend/foe cue, worst in a
## multi-combatant fight (playtest evidence: arc_flow's dd_06 boss fight,
## 4 combatants, all-green bars). Side-keyed per `make_combatant_visual`'s
## `c["side"]` (already the ally/enemy source of truth used for the chip
## fallback above) -- stats stay hidden, this is presentation-only. Enemy
## hue is a red-ORANGE, not pure red: red/green is the confusable pair for
## the common (deuteranopia/protanopia) colorblind types, and orange's
## extra luminance/blue-channel separation from green survives that
## confusion where a pure red wouldn't. `_legibility_boost` (GH#28
## dark-arenas) still self-modulates both colors up to the same brightness
## floor, so the hue split holds in dark arenas too, not just bright ones.
const ALLY_HP_COLOR := Color(0.2, 0.8, 0.2)
const ENEMY_HP_COLOR := Color(0.95, 0.45, 0.05)
## Persistent frost tint for icy_floor
## overlays -- combat_screen.gd's FROST_FLASH RGB (0.5, 0.8, 1.0) at a lower
## persistent alpha (0.35 vs the transient cast-flash's 0.55, since this rect
## sits on the board every round rather than pulsing once). board_renderer.gd
## doesn't reference combat_screen.gd's consts (the screen stays the VFX-
## dispatch owner; this file owns rendering primitives), so the RGB is
## restated here verbatim -- keep in sync if FROST_FLASH ever changes.
const ICY_FLOOR_COLOR := Color(0.5, 0.8, 1.0, 0.35)
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
## Attack connection (item 3). `LUNGE_PIXELS` is deliberately bigger than
## `BUMP_PIXELS` (3px, a "your move was refused" nudge) -- this is a
## deliberate strike, not a blocked-move bump, so it reads distinctly.
## `PROJECTILE_DEFAULT_COLOR` is the neutral tint for a plain ranged Attack
## (a bow -- no element to tint by); an active skill cast passes its OWN
## element color in instead (the exact FROST_FLASH/FLAME_FLASH combat_screen.
## gd already computes for cast-flash cells).
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
}
const STATUS_PIP_SIZE := Vector2(4.0, 4.0)
## Turn clarity (item 5a): a small chevron floating just above the CURRENT
## turn's combatant's cell (a fixed cell-relative offset, not sprite-height-
## aware -- same simplification the HP/MP bars already accept). Moved on
## every TURN_STARTED via the ONE function both the live and paced-AI-
## playback paths funnel through (`combat_screen.gd._apply_turn_started`).
const ACTIVE_MARKER_COLOR := Color(1.0, 0.95, 0.3, 1.0)
const ACTIVE_MARKER_TIP_Y := -6.0
const ACTIVE_MARKER_BASE_Y := -12.0
const ACTIVE_MARKER_HALF_WIDTH := 4.0
## Combat-feel tuning (presentation-only, all QA-collapsed via
## `_juice_enabled` -> `_presentation_delay`, zero under TestDriver/headless).
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
	## witch_hollow: the exploration map's bent-tree-ring identity must
	## survive into the briar fights. `hollow_bent_tree` is the map's own
	## small-tree pick re-scaled to single-cell cover (its sprites.json
	## entry documents the scale constraint); `bush_green` is already
	## cell-sized. Both are real silhouettes, not flat recolored tiles.
	"witch_hollow": ["hollow_bent_tree", "bush_green"],
	## riverfarm_village (village_edge_night): without a pool its 2 blocked
	## cells fell to the flat blocked tile, which the deep-blue night grade
	## crushed to bare black squares (windowed 03_night_wolf_arena read).
	## Field-edge register: a rock and a bush, both single-cell-verified.
	"riverfarm_village": ["boulder", "bush_green"],
	## `inn` biome (inn_cellar/merchant_warehouse, 10 blocked cells
	## combined): every blocked cell falls to this pool rather than the flat
	## recolored tile ("props-over-tiles" is the defect this mechanism
	## exists to kill). Reuses `crate`/`barrel` (the SAME already
	## single-cell-verified sprites the `street` pool uses) rather than
	## sourcing new art -- crates and barrels are, if anything, a MORE
	## natural fit for a cellar/warehouse than a street.
	"inn": ["crate", "barrel"],
}

## GH #28 DARK-ARENAS legibility fix. combat_board_root() is a bare Node2D
## living inside the world SubViewport with no CanvasLayer of its own (see
## atmosphere.gd's B1 EMPIRICAL FINDING doc comment) -- WIAtmosphere's single
## CanvasModulate grades the ENTIRE default canvas of that viewport, so it
## darkens combatant sprites/chips/HP-bars right along with the arena tiles.
## That's CORRECT for the tiles (the dark mood pin, e.g. sewers/deep_tunnels,
## is right per docs/VISUAL-LOG.md), but it also crushes small enemy/PC
## sprites toward the same near-black floor as the background -- the "small
## dark sprites hard to pick out" defect. Fixed with a uniform self_modulate
## brightness floor (`_legibility_boost`, computed once per build() from the
## resolved arena mood color via `_resolved_mood_rgb`/`_legibility_modulate`
## below) applied to every combatant's sprite/chip + HP/MP bars -- `self_
## modulate` deliberately, not `modulate`: flash_chip/impact_flash already
## own `.modulate` for hit-flash tweens (both tween back to Color.WHITE), so
## self_modulate composes independently on top without touching that code.
## Never touches moods.json or atmosphere.gd's own apply()/apply_arena() --
## this is a read-only presentation-side compensation, not a grading change.
const MOODS_PATH := "res://data/moods.json"
## Target average brightness combatant art should read at, regardless of how
## dark the arena's own mood grade is. Bright arenas (avg already >= this)
## get boost 1.0 -- byte-identical rendering to before this fix. 0.6 was
## tried first (windowed sewers_walkthrough before/after) and read as only a
## marginal, hard-to-notice nudge at natural viewing scale -- raised to 0.85
## (near-full compensation for the sewers/cave_mouth pin, ~0.36 avg) so
## combatant art reads close to its true un-graded color, a real pop against
## the still-dark board/tiles rather than a subtle shift.
const LEGIBILITY_TARGET := 0.85
## Clamp on the computed boost so the very darkest pins (deep_tunnels/
## deep_warren, avg ~0.25) don't get blown out toward flat white.
const LEGIBILITY_MAX_BOOST := 3.0

static var _moods_cache: Dictionary = {}

## The arena board itself -- a Node2D living in `World.combat_board_
## root()` (inside the SubViewport). Re-resolved (not just cached) at the top
## of every `build()` — see that function's doc comment for why a cached
## reference can't be trusted.
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
## The single active screenshake tween on `_board.position` (killed
## + restarted so overlapping heavy hits never stack an ever-growing offset).
var _shake_tween: Tween
## The WIMain host, stashed from `build()`'s `main_ref` param so `clear()` and
## the labels helpers below can resolve `World`/`WIWorldLabels` without the
## caller having to pass it again on every call.
var _main_ref: Node
## Persistent per-cell overlays,
## kind -> {Vector2i: ColorRect}. Unlike `flash_cells` (a transient tween
## that self-frees), these stay on the board until `expire_terrain` removes
## them or the whole board tears down (`build()`'s wholesale queue_free of
## every `_board` child already covers that -- see `add_terrain`'s doc
## comment for the z-order contract that keeps them under combatant
## visuals).
var _terrain_overlays: Dictionary = {}
## Issue #75 item 1: transient aim-preview paint nodes (range tint, AOE tint,
## ring), rebuilt wholesale by every `render_aim_preview()` call -- see that
## function's doc comment. `_last_aim_preview_key` dedupes the additive
## ui_aim_preview_rendered confirmation so an unchanged preview doesn't spam
## the bus every `_refresh()`.
var _aim_preview_nodes: Array = []
var _last_aim_preview_key := ""
## Issue #75 item 4: id -> {status_id: ColorRect}, mirrors `_hp_bars`'/
## `_mp_bars`' per-combatant tracking-dict shape.
var _status_pips: Dictionary = {}
## Issue #75 item 5a: the single active-unit marker (only one combatant's
## turn is ever active at a time) and the id it currently marks.
var _active_marker: Node2D
var _active_marker_id := ""

## GH #28 DARK-ARENAS: this build()'s combatant-legibility self_modulate
## floor (see the const block above) -- (1,1,1,1) identity for any arena
## whose resolved mood already clears LEGIBILITY_TARGET (every bright arena,
## unchanged from pre-fix rendering).
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
##
## Resolves `_board` fresh from `World.combat_board_root()` every call
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
	# A screenshake left mid-tween by a previous encounter (defeat
	# reload, rapid re-entry) must never leave the reused board root offset --
	# reset it and drop any live shake tween before building the new arena.
	_stop_shake()
	_squares.clear()
	_hp_bars.clear()
	_mp_bars.clear()
	_combat_anim_tokens.clear()
	_combat_tweens.clear()
	# The wholesale queue_free loop above already frees every previous
	# encounter's terrain overlay nodes (they're `_board` children); this just
	# drops the now-stale tracking dict so a fresh combat starts with none.
	_terrain_overlays.clear()
	# Same reasoning for issue #75's new per-encounter trackers: the wholesale
	# free above already frees the aim-preview/status-pip/active-marker nodes
	# (children of `_board` or of a combatant holder under it) -- this just
	# drops the now-stale references/dedup key so a fresh combat starts clean.
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


## Inverse of `build()`'s show + enter_combat_camera + label publish. Guarded
## by is_instance_valid since a defeat may already have torn the whole World
## down via Game.reset()/load_slot before this runs on some paths.
func clear() -> void:
	_stop_shake()
	if _board != null and is_instance_valid(_board):
		_board.visible = false
	var world := _world_node()
	if world != null:
		world.exit_combat_camera()
	_clear_combat_labels()
	# Drop the tracking dict defensively (see build()'s matching
	# comment) -- the next build() frees the actual overlay nodes wholesale.
	_terrain_overlays.clear()
	_aim_preview_nodes.clear()
	_last_aim_preview_key = ""
	_status_pips.clear()
	_active_marker = null
	_active_marker_id = ""


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


## Old flat-tile blocked rendering, kept as the fallback path for any
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


## Unlabeled decor visual, positioned like a combatant square (cell * CELL,
## board-local since `_board` itself is centered on screen by the camera)
## but without any HP/MP/name chrome -- arena counterpart of
## world.gd's decor branch inside `_make_entity_visual`. `tint` is the decor
## entry's optional [r,g,b] multiplier (same shape as the field path).
func _make_decor_visual(cell: Vector2i, sprite_id: String, tint: Variant = []) -> Node2D:
	var holder := Node2D.new()
	holder.position = Vector2(cell) * CELL
	var spr := AnimatedSprite2D.new()
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
	# Same-id roster fix: a dedup-suffixed runtime id (e.g.
	# "shield_spider_2") does not exist in the static combatants.json catalog
	# -- any lookup that needs the catalog record (sprite, combat_scale) must
	# use TEMPLATE_ID (the pre-suffix id), never `id` itself. Falls back to
	# `id` when TEMPLATE_ID is absent (hand-built dicts in older tests).
	var template_id := String(c.get(WIKeys.TEMPLATE_ID, id))
	var sprite_id := _combatant_sprite_id(id, template_id)
	# Labels stack above the cell; the sprite branch below moves this up
	# further once the sprite's actual (possibly overhanging) top edge is
	# known, same convention as world.gd's field entities.
	var label_top := -18.0
	if sprite_id != "" and WISpriteRegistry.has_sprite(sprite_id):
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = WISpriteRegistry.frames_for(sprite_id)
		spr.centered = false
		# Initial facing: the unflipped sheet row faces right
		# (see _flip_toward's convention -- flip_h true means "facing left").
		# Player-side combatants spawn at low-x and face the enemy side (right,
		# unflipped); enemy-side combatants spawn at high-x and face the player
		# side (left, flipped) until the first attack/hit event re-derives flip
		# from actual cell positions.
		spr.flip_h = (String(c["side"]) != "player")
		# Issue #62 addendum (finding 11): a NON-directional sprite (e.g.
		# `training_dummy`, ruin_guardian's combat sprite) registers its sole
		# animation as the bare "idle" (WISpriteRegistry._facings(false) ->
		# facing "" -> full_name = anim_name unsuffixed, no "_side"/"_down").
		# Neither literal check above ever matched it, so `anim` stayed ""
		# and BOTH `spr.play` and the feet-anchor block below (`if anim !=
		# ""`) were skipped outright -- the sprite kept Node2D's default
		# (0,0) position (holder-origin/top-left) instead of being
		# feet-anchored bottom-center, then never even played its idle
		# frame. `_make_decor_visual` already carries the equivalent
		# "idle"-literal fallback (this file, `_make_decor_visual`'s own
		# `anim` line) -- this mirrors it. The resulting top-left offset is
		# small for a modest render_scale (river_wolf/briar_collector*) but
		# large for `ruin_guardian`, whose `combat_scale: 1.15` REPLACES (not
		# multiplies) training_dummy's own 0.5 scale -- at 1.15x a 64px
		# frame, the un-anchored sprite renders visibly down-and-right of its
		# own cell, reading as "the hitbox sits up-left of the sprite".
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
		# Combat-specific scale override (combatants.json `combat_scale`): a
		# sprite sized canon-tall on the FIELD (Relc's bespoke full-frame Drake
		# spearmaster renders ~2.8 cells at his field render_scale) overhangs
		# multiple cells in the tight tactical grid and covers neighbours'
		# HP/MP bars + sprites. A per-combatant combat_scale contains him
		# (feet-anchored, so the trimmed height comes off the TOP into empty
		# air) WITHOUT touching the field render_scale. Only combatants that
		# declare it are affected; everyone else keeps the sprite catalog scale.
		var combat_scale: Variant = WIDataRegistry.combatant_config(template_id).get("combat_scale")
		if combat_scale != null:
			scale_value = float(combat_scale)
		if scale_value != 1.0:
			spr.scale = Vector2(scale_value, scale_value)
		# Anchor feet/base to the cell's bottom-center, matching
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
		# GH #28 DARK-ARENAS: self_modulate (not modulate -- flash_chip/
		# impact_flash already own `.modulate` for hit-flash tweens and both
		# tween back to Color.WHITE) so the legibility floor composes
		# independently underneath any juice effect. Identity in every bright
		# arena; see `_legibility_modulate`'s doc comment.
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
	# HP/MP bars are 1-2px-tall in-viewport pixel bars hugging the cell's
	# bottom edge -- numerals move to a native-res
	# overlay in R5; this bar is the part that stays in-viewport permanently.
	var bar := ColorRect.new()
	bar.color = ALLY_HP_COLOR if String(c["side"]) == "player" else ENEMY_HP_COLOR
	bar.position = Vector2(1, CELL - 3)
	bar.size = Vector2(CELL - 2, 2)
	bar.self_modulate = _legibility_boost
	holder.add_child(bar)
	_hp_bars[id] = bar
	# MP bar sits directly above the HP bar, only for combatants with a
	# pool (max_mp > 0 — non-casters get no bar at all, not an empty one).
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


## GH #28 DARK-ARENAS: the CURRENTLY-EFFECTIVE mood color for this combat's
## arena, mirroring atmosphere.gd's own arena-vs-map fallback (an
## `arena_moods` pin if this arena has one, e.g. sewers_nest/deep_warren/
## cave_mouth; otherwise the field map's own mood at the same phase, e.g.
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
	# Variant-key indirection (presentation-only): the PC's combat chip
	# uses the sim's chosen race/gender sprite variant ("pc_<race>_<gender>"),
	# degrading to the combatants.json default ("body_a") when that variant art
	# is not registered. Every other combatant reads its static sprite unchanged
	# -- keyed off template_id, not id, since a same-catalog-id
	# roster's second+ combatant carries a dedup-suffixed id that does not
	# exist in the static catalog.
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


## The World node living inside the SubViewport (`Main.world_root()`).
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


## Shared by both `move_visual` and `bump` -- one active
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


## Whole-visual translucency (the combat twin of the field's sneak_visual
## alpha) -- applied to the HOLDER's modulate, deliberately not the sprite's:
## hit-flash tweens own `spr.modulate` (they tween back to opaque WHITE and
## would silently erase a sprite-level alpha) and the legibility boost owns
## `spr.self_modulate`; the holder layer composes above both untouched.
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
		# No death animation on this sheet (e.g. goblins) -- resolving to an
		# idle* fallback would loop forever on a "downed" combatant.
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


## Persistent per-cell overlay --
## one semi-transparent ColorRect per cell, unlike `flash_cells`' one-shot
## tween. `z_index` defaults to 0 (the const block's COMBATANT_Z split keeps
## it under every combatant regardless of add order); it renders over the
## floor/decor simply because it's added to `_board` AFTER `build()`'s floor
## construction (both at z_index 0, so tree order alone settles floor vs.
## overlay). Re-adding at an already-registered cell (a re-cast) frees the
## stale rect first (`combat.terrain`'s own flat-refresh idiom mirrored
## here, so the visual never doubles up). No-op before `build()` has run
## (`_board == null`).
func add_terrain(kind: String, cells: Array) -> void:
	if _board == null:
		return
	var by_kind: Dictionary = _terrain_overlays.get(kind, {})
	var color := ICY_FLOOR_COLOR if kind == "icy_floor" else Color(1.0, 1.0, 1.0, 0.35)
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


## Inverse of `add_terrain` -- frees and untracks the overlay at each given
## cell for `kind`. No UI confirmation event on expiry (only the add side
## rides the ui_*_rendered idiom, by design); the domain-level
## TERRAIN_EXPIRED is the QA-visible signal for this half.
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


## Clears the aim-preview paint -- called whenever targeting is NOT active
## (combat_screen.gd's `_refresh()`), and defensively from `build()`/`clear()`
## at encounter boundaries (see those functions' own doc comments).
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


## Hollow border (4 thin ColorRects forming a square outline) rather than a
## filled square -- reads as a RING distinct from the filled AOE/range tints
## painted underneath it.
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


## Additive QA confirmation (issue #75 item 1) -- deduped so an unchanged
## preview (e.g. a `_refresh()` triggered by something unrelated while still
## aiming the same candidate) doesn't spam the bus; a genuinely new kind or
## cell set always fires.
func _emit_aim_preview_event(kind: String, cells: Array) -> void:
	var cells_payload: Array = []
	for cell: Vector2i in cells:
		cells_payload.append([cell.x, cell.y])
	var key := "%s:%s" % [kind, str(cells_payload)]
	if key == _last_aim_preview_key:
		return
	_last_aim_preview_key = key
	ObservableBus.emit_domain_event(WIEvents.UI_AIM_PREVIEW_RENDERED, {"kind": kind, "cells": cells_payload})


## Floating damage numeral at the struck cell (issue #75 item 2) -- brief
## rise-fade, juice-gated (no-op headless/TestDriver -- byte-identical event
## stream). `side` picks the SAME ALLY_HP_COLOR/ENEMY_HP_COLOR hue the struck
## combatant's own HP bar already uses for "who got hit".
func spawn_damage_number(cell_xy: Array, amount: int, side: String) -> void:
	if not _juice_enabled() or _board == null or cell_xy.size() < 2:
		return
	var color := ALLY_HP_COLOR if side == "player" else ENEMY_HP_COLOR
	_spawn_floating_text(cell_xy, str(amount), color)


## Distinct miss feedback at the target cell (issue #75 item 2) -- same
## floating-text primitive as the damage numeral, neutral grey so a miss
## never reads as "0 damage dealt".
func spawn_miss_indicator(cell_xy: Array) -> void:
	if not _juice_enabled() or _board == null or cell_xy.size() < 2:
		return
	_spawn_floating_text(cell_xy, "Miss", MISS_COLOR)


func _spawn_floating_text(cell_xy: Array, text: String, color: Color) -> void:
	var label := UIChrome.make_label(text, "Small")
	# `_board` lives inside the world SubViewport, outside any themed Control
	# ancestor (the HUD's own theme lives on combat_screen.gd's separate
	# CanvasLayer `_root`) -- set the theme directly on this instance so the
	# numeral still renders in the game's real font/size instead of falling
	# back to the engine default.
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


## Melee "attack connection" (issue #75 item 3) -- the SAME bump-tween
## primitive `bump()` uses for blocked-move feedback, pointed at the TARGET's
## cell instead of an input direction: a brief lunge toward it then back.
## Juice-gated -- headless/QA never observes the holder's position move even
## transiently.
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


## Ranged/spell "attack connection" (issue #75 item 3) -- a fast streak
## (fade in, hold, fade out over one short tween) from the attacker's cell
## center to the target's, tinted by `color` (the caster's element --
## FROST_FLASH/FLAME_FLASH, passed in by combat_screen.gd) or, when `color`
## is transparent (a plain non-elemental ranged Attack -- a bow, no skill
## cast), the neutral PROJECTILE_DEFAULT_COLOR resolved HERE so callers never
## need this file's own const. Juice-gated.
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


## Per-status pip over a combatant's holder (issue #75 item 4) -- DATA-DRIVEN
## off `STATUS_PIP_COLORS`: an unlisted status_id (including "invisible",
## which already has its own alpha tell) is a silent no-op, so a future
## status entry added to that map gets a pip for free with zero new dispatch
## code at the call site.
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


## Persistent active-unit marker (issue #75 item 5a) -- a small chevron just
## above the CURRENT turn's combatant's cell, moved on every TURN_STARTED via
## the ONE function both the live and paced-AI-playback paths funnel through
## (combat_screen.gd's `_apply_turn_started`). Fixed cell-relative offset,
## not sprite-height-aware -- the same simplification the HP/MP bars already
## accept (see their own `position` literals).
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


## Defensive teardown -- not on the encounter's hot path (build()/clear()
## already reset the tracking var, see those functions' own doc comments),
## kept for symmetry with `clear_aim_preview()`.
func clear_active_marker() -> void:
	if _active_marker != null and is_instance_valid(_active_marker):
		_active_marker.queue_free()
	_active_marker = null
	_active_marker_id = ""


## Juice gate: true only in real play (windowed non-QA / native). Reuses
## `_presentation_delay`'s exact TestDriver/headless collapse so every combat-
## feel effect is a strict no-op under QA -- byte-identical event streams, no
## board offset left mid-screenshot, no wasted particle nodes headless. Same
## discipline as the paced-playback / cast-flash precedents.
func _juice_enabled() -> bool:
	return _presentation_delay(1.0) > 0.0


## White modulate pulse on the STRUCK combatant's sprite (cast-flash
## precedent). Pulses the AnimatedSprite2D child only -- the holder's own
## modulate is reserved for death fade / actor highlight, so a struck-then-
## downed combatant never gets two tweens fighting over the same property.
## Chip-only combatants keep their existing `flash_chip` pulse; this is additive
## on top of the "hit" frame animation for sprite combatants.
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


## Kills any live shake tween and snaps the board root back to origin -- called
## on build()/clear() (encounter boundaries) and before starting a fresh shake.
func _stop_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	if _board != null and is_instance_valid(_board):
		_board.position = Vector2.ZERO


## One-shot `hit_sparks` WIAmbience burst (<=8 particles, wasm-safe)
## at a struck combatant's cell. `cell_xy` is the enqueue-time-captured
## `_ui.target_cell` ([x,y] or []) -- never a live combat read, so paced AI
## playback sparks land on the historical cell of the beat, not wherever the sim
## has since moved. Self-frees past its lifetime; QA-collapsed (no particle node
## spawned headless).
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
