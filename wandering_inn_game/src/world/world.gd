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

## GH#335 phase 1 -- the UNIVERSAL ACTION TELL. Every explicit input must get a
## visible world response (friend notes 8/12); the field-cast and the
## interact-into-flavor paths had literally none. Amplitude and duration sit
## deliberately UNDER `_bump_player_visual`'s refusal bump (3px / 0.06s): a
## refusal has to stay the louder of the two gestures, or "I hit a wall" and
## "I did a thing" read as the same motion.
const ACTION_TELL_PIXELS := 1.5
const ACTION_TELL_TWEEN_SECONDS := 0.05
## The faced-cell pip carries no bus event -- adding one means a new WIEvents
## const and wi_events.gd is outside this lane's ownership (see .lane-progress
## SEAMS) -- so a windowed capture IS the tell's proof. #335 calls this family
## headless-invisible by construction and names windowed playtest as the gate.
## The emitter itself is pooled and one-shot (`_spawn_action_pip`), so it needs
## no lifetime timer: `restart()` is the whole per-press cost.

## GH#335 phase 1 -- the FACED-INTERACTABLE AFFORDANCE. Field name tags are
## RETIRED (R3), which left "what will this key do here?" answerable only by
## guessing from the sprite; notes 6/14's illegible-landmark class drains here
## too. Four corner ticks bracket the cell the player FACES, and only while a
## present entity actually stands in it. A SHAPE, never a tint: tint is not
## disambiguation (2026-08-02 ruling), and a bracket still reads at 16px over
## every biome the sprite families already fight for contrast against.
const AFFORDANCE_COLOR := Color(0.99, 0.93, 0.72)
const AFFORDANCE_INSET_PX := 1.0
const AFFORDANCE_TICK_PX := 4.0
const AFFORDANCE_WIDTH_PX := 1.0
const AFFORDANCE_ALPHA_MIN := 0.34
const AFFORDANCE_ALPHA_MAX := 0.86
const AFFORDANCE_PULSE_HZ := 0.85
## Every producer of a change to (player_cell, player_facing, who is present in
## the faced cell). PLAYER_BLOCKED earns its row: a blocked move TURNS without
## moving, so it is the one input that changes the faced cell with no
## PLAYER_MOVED behind it. MAP_CHANGED is deliberately ABSENT -- `_rebuild_field`
## ends with its own reconcile against the field it just built.
const AFFORDANCE_REFRESH_EVENTS: Array[StringName] = [
	WIEvents.PLAYER_MOVED,
	WIEvents.PLAYER_BLOCKED,
	WIEvents.PLAYER_TELEPORTED,
	WIEvents.ENTITY_REMOVED,
	WIEvents.PHASE_CHANGED,
	WIEvents.ACCOMPLISHMENT_RECORDED,
	WIEvents.COMPANION_CHANGED,
	WIEvents.DIALOGUE_STARTED,
	WIEvents.DIALOGUE_ENDED,
	WIEvents.UI_COMBAT_HIDDEN,
]

const LIGHT_TEXTURE := preload("res://assets/fx/light_radial.png")
const LIGHT_TEXTURE_PX := 64.0
const LIGHT_BUDGET := 8

const PC_LIGHT_COLOR := Color(1.0, 0.95, 0.8)
const PC_LIGHT_RADIUS := 32.0
const PC_LIGHT_ENERGY := 1.0

const SNEAK_ALPHA := 0.6

const AMBIENCE_BUDGET := 6
## The phase list any SKY-BEARING map's biome default is forced to, whatever
## the biome row below says (`_biome_default_ambience`/`_map_has_sky`).
const SKY_DEFAULT_PHASES: Array = ["dusk", "night"]
## Tolerance on the day-vs-dusk grade comparison that decides "has a sky"
## (`_map_has_sky`). Well under the smallest real drop in moods.json
## (pallass_market, ~0.07) and well over float noise from JSON.
const SKY_GRADE_EPSILON := 0.01
const MOODS_PATH := "res://data/moods.json"
## Read-only mirrors of moods.json, populated once per process. `reset()` on
## WIAtmosphere/WISpriteRegistry is the live-reload seam for the real caches;
## these two hold nothing a data edit can invalidate mid-session that a map
## rebuild would not already re-read, and are static so the parse is paid once
## per process, not once per door.
static var _moods_cache: Dictionary = {}
static var _sky_cache: Dictionary = {}
## Atmosphere lever 3. Per-biome fallback for a map that declares no `ambience`
## row of its own -- see `_build_ambience`/`_biome_default_ambience` for the
## layering rule and why the phase gates are what they are. Keyed by
## biomes.json ids; a biome absent here simply has no default (silence is a
## legitimate answer, and an unlisted biome must never inherit a wrong one).
## Entries exist for biomes whose maps all currently declare rows too --
## the table is the DEFAULT for the kind of place, not a patch list.
## `phase: []` here means "as far as the BIOME is concerned, every phase" --
## a sky-bearing MAP inside such a biome (ruin_surface in `cave`,
## mercantile_alleys in `invrisil_alley`) is still forced to dusk/night by
## `_biome_default_ambience`, because daylight is a property of the room, not
## of the tileset it was built from.
const BIOME_DEFAULT_AMBIENCE := {
	"dungeon": {"preset": "dust_motes", "phase": []},
	"cave": {"preset": "dust_motes", "phase": []},
	"invrisil_alley": {"preset": "dust_motes", "phase": []},
	"brothers_parlor": {"preset": "dust_motes", "phase": []},
	"inn": {"preset": "dust_motes", "phase": ["dusk", "night"]},
	"pallass_forge": {"preset": "embers", "phase": []},
	"garden": {"preset": "fireflies", "phase": ["dusk", "night"]},
	"witch_hollow": {"preset": "fireflies", "phase": ["dusk", "night"]},
	"floodplains": {"preset": "leaves", "phase": ["dusk", "night"]},
	"riverfarm_village": {"preset": "leaves", "phase": ["dusk", "night"]},
	"street": {"preset": "dust_motes", "phase": ["dusk", "night"]},
	"invrisil_street": {"preset": "dust_motes", "phase": ["dusk", "night"]},
	"pallass_market": {"preset": "dust_motes", "phase": ["dusk", "night"]},
}
const SWAY_SHADER := preload("res://src/world/shaders/foliage_sway.gdshader")
const WATER_SHEET := "res://assets/tiles/free_pack/Water_tiles.png"
const WATER_SHIMMER_SHADER := preload("res://src/world/shaders/water_shimmer.gdshader")
## The two always-on world shaders animate off a `speed` uniform, and
## reduce-motion owns it (v0.17 fix wave, adversarial finding #10: both were
## unconditional, so a motion-sensitive player standing in the floodplains had
## foliage swaying and water rippling with the setting ON). world.gd writes the
## uniform EXPLICITLY in both directions -- the shader-file defaults are never
## relied on -- so these values cannot silently drift out of sync with the
## .gdshader sources. Zeroing the clock rather than the amplitude keeps each
## sprite's own phase offset, i.e. a still, naturally-varied field instead of a
## rank of identically-straight stalks.
const SWAY_SPEED := 1.2
const WATER_SHIMMER_SPEED := 1.0
## GH#380/#385 P1: a frozen cell is a BESPOKE ice tile, never a tinted water
## tile. The tinted-water arm shipped twice and was retracted twice -- the
## CHOICE-LOG pulled the pale-blue slab, and the standing directive is that
## tint is not disambiguation: a shade variant never reads as a different
## thing. The sheet is a single 16x16 tile, so the coord is (0,0) and the
## layer is NOT modulated (its own pixels carry the frost).
const ICE_SHEET := "res://assets/tiles/ice/ice_floor_tiles.png"
const ICE_CAP_COORD := Vector2i(0, 0)
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
## Which KIND of tween currently occupies the shared `_player_tween` slot. Only
## the move tween's `finished` signal drives held-direction auto-repeat and the
## click path, so only the move tween is un-killable by a same-frame action tell
## -- see `_move_tween_live`.
var _player_tween_is_move := false
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
## GH#335 phase 1. Built lazily on the first reconcile and freed with the rest
## of `_field_root` on every rebuild (hence the null-out beside `_player_sprite`
## in `_rebuild_field`) -- it is field furniture, not a persistent overlay.
var _affordance_cursor: Node2D
var _affordance_time := 0.0
## Last payload UI_AFFORDANCE_RENDERED announced, so the emit is a TRANSITION
## and not a per-reconcile spam (see `_emit_affordance_rendered`).
var _affordance_state: Dictionary = {}
## The single pooled action-tell emitter (see `_spawn_action_pip`). Field
## furniture like `_affordance_cursor`: nulled in `_rebuild_field`, rebuilt on
## the next press.
var _action_pip: GPUParticles2D
## Every ambient emitter this field built -- map-DECLARED rows AND biome
## defaults -- with the phase list each was registered under, so reduce-motion
## can cut all of them and re-derive the phase gate itself when it is switched
## back off (see `_apply_ambient_emitter_state`).
var _ambient_emitters: Array[Dictionary] = []
## The water overlay's own ShaderMaterial for the CURRENT map (null on maps
## with no water). Held only so reduce-motion can stop its clock live.
var _water_material: ShaderMaterial
## Last reduce-motion value pushed into the always-on motion layer. Seeded in
## `_ready` so the first `_process` tick is a no-op on a normal boot.
var _reduce_motion_applied := false


func _ready() -> void:
	# GH#345 boot push: core is pure (WIGame never reads WISettings), so the
	# scene layer hands the sim instance the persisted difficulty at world
	# start; the GAME_LOADED/MAP_CHANGED arm below re-pushes after every sim
	# swap, and the settings row / creation prompt push on change.
	Game.sim.difficulty_damage_taken_mult = WISettings.difficulty_damage_taken_mult()
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
	# Seed the always-on motion layer from the live setting before the first
	# field is built, so a player who booted with reduce-motion ON never sees a
	# frame of sway/shimmer (and `_process`'s first tick is a no-op).
	_reduce_motion_applied = WISettings.reduce_motion()
	_apply_motion_settings()
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
		# GH#334 note 8 piece 1: a field cast is an ACTION, and `interact` below
		# has always cleared the strip before speaking. Without the same call the
		# skill's own toast queued BEHIND whatever was still showing -- up to
		# 10.5s of apparently nothing happening after a deliberate press, on the
		# one input path that has no animation, no target mark and no world
		# change to fall back on.
		_notify_action_taken()
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


## THE universal explicit-action hook. Already the one place every deliberate
## world action funnels through (pad-confirm cast, number-key cast, interact
## press, click-walk's arrival interact), which is exactly why GH#335's action
## tell hangs here rather than off four separate call sites -- a fifth action
## path added later gets the tell for free, the way it already gets the toast
## dismiss.
func _notify_action_taken() -> void:
	_play_action_tell()
	if _main == null:
		return
	var ml := _main.message_layer()
	if ml != null:
		ml.dismiss_current_toast_early()


## GH#335 phase 1. Fires BEFORE the sim call it precedes, so `player_facing` is
## still the direction the player aimed at when they pressed -- that is the
## cell the tell must mark, whatever the sim then decides happened there.
## Deliberately fires on a NULL result too (interact into empty air, a cast
## with no target): the tell answers "the game heard you", which is precisely
## the input the old silence left unanswered.
func _play_action_tell() -> void:
	if _player_visual == null:
		return
	# reduce-motion trades the tell for the persistent affordance below plus
	# the new audio rows (item_used/player_blocked/skill_no_effect, data/
	# audio.json) -- the non-motion feedback channels of this same wave. Same
	# shared-gate shape as board_renderer.gd's juice family.
	if WISettings.reduce_motion():
		return
	_spawn_action_pip(Game.sim.player_cell + Game.sim.player_facing)
	# INVARIANT (v0.17 fix wave, adversarial finding C1): the tell NEVER touches
	# `_player_visual.position` while a real move is animating. It used to
	# `_kill_player_tween()` unconditionally, and `Tween.kill()` does not emit
	# `finished` -- which is the ONE driver of held-direction auto-repeat
	# (`_on_move_tween_finished` is where `_held_move_direction` is read). An
	# interact/cast pressed mid-step therefore stopped a held walk dead AND
	# snapped the sprite a whole cell to its destination, and no QA gate could
	# ever see it (`_presentation_delay` collapses this whole function to the
	# pip under any TestDriver). A press during a step still gets the pip and
	# the audio row; it just does not fight the step for `.position`.
	if _move_tween_live():
		return
	var duration := _presentation_delay(ACTION_TELL_TWEEN_SECONDS)
	if duration <= 0.0:
		return
	_kill_player_tween()
	var home := Vector2(Game.sim.player_cell) * CELL
	_player_visual.position = home
	_player_tween = create_tween()
	_player_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_player_tween.tween_property(_player_visual, "position", home + Vector2(Game.sim.player_facing) * ACTION_TELL_PIXELS, duration)
	_player_tween.tween_property(_player_visual, "position", home, duration)
	_player_tween_is_move = false


## True only while `_move_player_visual`'s tween -- the one whose `finished`
## signal drives held-direction auto-repeat and click-path advance -- is still
## running. A finished or killed Tween reports neither valid nor running, so
## this needs no teardown hook; `_player_tween_is_move` only disambiguates the
## shared `_player_tween` slot (a bump/tell tween must not read as a move).
func _move_tween_live() -> bool:
	return _player_tween_is_move and _player_tween != null \
			and _player_tween.is_valid() and _player_tween.is_running()


## Unlike `_spawn_burn_poof`, this does NOT collapse under an active TestDriver
## -- a windowed capture is the tell's only proof, so collapsing it there would
## delete the evidence for the one feature that has no bus event. It still
## skips HEADLESS entirely (no renderer, and every headless canonical stays
## byte-identical: no node churn, no timer).
## POOLED, exactly ONE emitter per field (v0.17 fix wave, adversarial finding
## #7): the first version built a fresh GPUParticles2D + ParticleProcessMaterial
## + CanvasItemMaterial + GradientTexture1D and a SceneTreeTimer on every single
## press, uncapped -- ten presses a second on a wasm build meant ~8 live emitters
## and ~32 freshly allocated resources in flight. A one-shot emitter is
## `restart()`-able, so a mash now costs one reposition and one restart, and the
## node is freed with `_field_root` like the affordance bracket beside it.
func _spawn_action_pip(cell: Vector2i) -> void:
	if _field_root == null or DisplayServer.get_name() == "headless":
		return
	if _action_pip == null or not is_instance_valid(_action_pip):
		_action_pip = WIAmbience.make("action_pip", Rect2(Vector2.ZERO, Vector2(CELL, CELL)))
		if _action_pip == null:
			return
		_action_pip.z_index = 30
		_action_pip.emitting = false
		_field_root.add_child(_action_pip)
	# `_base` centres the emitter on its rect, so the pool node carries the
	# half-cell offset and only the cell origin moves per press.
	_action_pip.position = Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5
	_action_pip.restart()
	_action_pip.emitting = true


## GH#335 phase 1. Shown only when the faced cell actually holds a PRESENT
## entity, so the bracket never promises an interaction that is not there --
## `entity_at` already applies the `present_when` gate, which is what keeps
## this honest across the phase clock (a night-absent flavor NPC takes its
## bracket with it, same beat its sprite goes).
func _reconcile_faced_affordance(trigger: StringName = &"") -> void:
	if _field_root == null or Game.sim == null:
		return
	if _affordance_cursor == null or not is_instance_valid(_affordance_cursor):
		_affordance_cursor = _make_affordance_cursor()
		_field_root.add_child(_affordance_cursor)
	var cell: Vector2i = Game.sim.player_cell + Game.sim.player_facing
	# A conversation owns the screen; a bracket under an open dialogue panel is
	# noise pointing at the thing you are already talking to. Combat is covered
	# by `_field_root.visible = false` and needs no arm of its own.
	#
	# EMIT-ORDER TRAP (v0.19 L5 reviewer lens A, proven off the new
	# UI_AFFORDANCE_RENDERED log): `Game.sim.dialogue` is the WRONG answer on
	# exactly the two frames this reconcile is driven by the dialogue events
	# themselves, and it is wrong in both directions.
	#  * `start_dialogue` emits DIALOGUE_STARTED BEFORE assigning `dialogue`
	#    (wi_game.gd:1270), so the sim still reads null and the bracket turned
	#    ON at the instant a conversation opened -- the exact noise the
	#    paragraph above forbids -- and stayed on until some unrelated event
	#    happened to re-reconcile.
	#  * `WIDialogue.choose` emits DIALOGUE_ENDED from inside the walker
	#    (dialogue.gd:80), i.e. BEFORE `dialogue_choose` clears the handle
	#    (wi_game.gd), so the sim still reads non-null and the bracket turned
	#    OFF at the instant the panel closed.
	# Corrected from the trigger, not from a mirrored flag: a latch that misses
	# one edge would strand the bracket hidden forever, while this stays a pure
	# read of live sim on every other path.
	var dialogue_open := Game.sim.dialogue != null
	if trigger == WIEvents.DIALOGUE_STARTED:
		dialogue_open = true
	elif trigger == WIEvents.DIALOGUE_ENDED:
		dialogue_open = false
	var faced: Dictionary = Game.sim.entity_at(cell)
	var showing := not dialogue_open and not faced.is_empty()
	_affordance_cursor.visible = showing
	_emit_affordance_rendered(showing, cell, String(faced.get("id", "")) if showing else "")
	if not showing:
		return
	_affordance_cursor.position = Vector2(cell) * CELL
	if not _affordance_pulsing():
		_affordance_cursor.modulate.a = AFFORDANCE_ALPHA_MAX


## The bracket's ONLY headless-visible trace (v0.19 L5, GH#335 item 2's QA-first
## bar). Emitted on TRANSITIONS only: `_reconcile_faced_affordance` runs on ten
## event types plus every field rebuild and most of those leave the answer
## byte-identical, so a per-call emit would bury the real changes under a wall
## and make `assert_event_count` useless. `_affordance_state` is presentation
## memory, reset with the rest of the field furniture in `_rebuild_field` so a
## map crossing re-announces rather than deduping against the old map's cell.
func _emit_affordance_rendered(showing: bool, cell: Vector2i, entity_id: String) -> void:
	var state := {"showing": showing, "cell": [cell.x, cell.y], "entity": entity_id}
	if state == _affordance_state:
		return
	_affordance_state = state
	ObservableBus.emit_domain_event(WIEvents.UI_AFFORDANCE_RENDERED, state.duplicate(true))


## Pulse is suppressed under reduce-motion AND under any driven run
## (`_presentation_delay`'s QA/headless collapse) -- the second half matters as
## much as the first: an oscillating alpha would make every windowed screenshot
## of a bracketed prop a different brightness, so evidence would never compare.
func _affordance_pulsing() -> bool:
	return _presentation_delay(1.0) > 0.0 and not WISettings.reduce_motion()


func _make_affordance_cursor() -> Node2D:
	var root := Node2D.new()
	root.name = "FacedAffordance"
	root.z_index = 25
	root.visible = false
	root.modulate.a = AFFORDANCE_ALPHA_MAX
	var near := AFFORDANCE_INSET_PX
	var far := float(CELL) - AFFORDANCE_INSET_PX
	var tick := AFFORDANCE_TICK_PX
	# One L per corner, drawn as a 3-point polyline so the corner pixel is
	# shared rather than double-struck (a doubled pixel reads as a blob at 16px).
	var corners := [
		[Vector2(near, near + tick), Vector2(near, near), Vector2(near + tick, near)],
		[Vector2(far - tick, near), Vector2(far, near), Vector2(far, near + tick)],
		[Vector2(far, far - tick), Vector2(far, far), Vector2(far - tick, far)],
		[Vector2(near + tick, far), Vector2(near, far), Vector2(near, far - tick)],
	]
	for pts: Array in corners:
		var line := Line2D.new()
		line.width = AFFORDANCE_WIDTH_PX
		line.default_color = AFFORDANCE_COLOR
		line.joint_mode = Line2D.LINE_JOINT_SHARP
		line.begin_cap_mode = Line2D.LINE_CAP_NONE
		line.end_cap_mode = Line2D.LINE_CAP_NONE
		line.antialiased = false
		for p: Vector2 in pts:
			line.add_point(p)
		root.add_child(line)
	return root


## Pulse driven from `_process`, never a Tween -- GH#324 measured what a live
## tween costs: `test_driver`'s capture settle drains `get_processed_tweens()`
## before every screenshot, so ONE looping tween anywhere would add the full
## 3s drain cap to every windowed shot in the whole suite. atmosphere.gd's
## flicker clock is the same call, for the same reason.
## This tick is ALSO where reduce-motion is observed (v0.17 fix wave,
## adversarial finding #3/#10): WISettings is a plain config-backed autoload
## with no change signal, so the only way for the world's always-on motion --
## foliage sway, water shimmer, ambient emitters -- to answer the toggle at the
## moment it is flipped (rather than at the next door crossing) is to read the
## bool where motion is already driven. Every other reduce-motion gate in the
## repo is evaluated at the moment of motion; these three are the exception
## only because their motion is continuous, so this tick IS that moment.
func _process(delta: float) -> void:
	_tick_motion_settings()
	if _affordance_cursor == null or not is_instance_valid(_affordance_cursor) \
			or not _affordance_cursor.visible or not _affordance_pulsing():
		return
	_affordance_time += delta
	var wave := 0.5 + 0.5 * sin(TAU * AFFORDANCE_PULSE_HZ * _affordance_time)
	_affordance_cursor.modulate.a = lerpf(AFFORDANCE_ALPHA_MIN, AFFORDANCE_ALPHA_MAX, wave)


## The live half of the reduce-motion contract. On a FLIP it repaints both
## shader clocks and every ambient emitter; while reduce-motion is ON it also
## re-asserts the emitter cut every tick, because atmosphere.gd's
## `_refresh_emitters` (phase crossings, arena enter/exit) re-derives
## `emitting`/`visible` from the phase alone and would otherwise switch a
## suppressed field back on behind our back. `_set_emitter_state` taking the
## gate itself is the right long-term home -- atmosphere.gd is outside this
## lane's ownership, see .lane-progress SEAMS.
func _tick_motion_settings() -> void:
	var reduced := WISettings.reduce_motion()
	if reduced != _reduce_motion_applied:
		_reduce_motion_applied = reduced
		_apply_motion_settings()
	elif reduced:
		_apply_ambient_emitter_state()


## Shader clocks first (one shared material each, so this is two
## RenderingServer parameter writes, not one per sprite), then the emitters.
func _apply_motion_settings() -> void:
	var reduced := WISettings.reduce_motion()
	if _sway_material != null:
		_sway_material.set_shader_parameter("speed", 0.0 if reduced else SWAY_SPEED)
	if _water_material != null:
		_water_material.set_shader_parameter("speed", 0.0 if reduced else WATER_SHIMMER_SPEED)
	_apply_ambient_emitter_state()


## Mirrors atmosphere.gd's `_set_emitter_state` (phase gate, both `.emitting`
## and `.visible` so no straggler survives the cut) and ANDs reduce-motion on
## top. Covers map-DECLARED rows as well as the new biome defaults -- 17 of the
## 29 maps declare their own ambience, and before this they kept drifting with
## reduce-motion on.
## Returns how many emitters are left actually moving -- `_build_ambience`
## publishes that number so the day-identity contract is machine-checkable.
func _apply_ambient_emitter_state() -> int:
	if _ambient_emitters.is_empty():
		return 0
	var reduced := WISettings.reduce_motion()
	var phase := _atmosphere.phase_now() if _atmosphere != null else ""
	var active := 0
	for entry: Dictionary in _ambient_emitters:
		var node: GPUParticles2D = entry["node"]
		if not is_instance_valid(node):
			continue
		var phases: Array = entry["phases"]
		var should_emit: bool = (phases.is_empty() or phase in phases) and not reduced
		node.emitting = should_emit
		node.visible = should_emit
		if should_emit:
			active += 1
	return active


func _activate_field_slot(slot: int) -> void:
	if slot <= 0 or _field_hotbar == null:
		return
	if _movement_gated():
		return
	# GH#334 note 8 piece 1 -- the number-key twin of the pad confirm branch
	# above. Cleared here rather than inside the `skill_id != ""` arm on purpose:
	# a press on an empty slot is still a press the player made, and the strip
	# should not sit on stale copy through it.
	_notify_action_taken()
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
	# GH#335: field furniture, freed with everything else above -- the
	# end-of-rebuild reconcile rebuilds it against the new map.
	_affordance_cursor = null
	# ...and its announced state with it: the same faced cell on a DIFFERENT map
	# is a different answer, so the dedup memory must not survive the crossing.
	_affordance_state = {}
	# Same discipline for the pooled action pip and the water overlay's
	# material: both hang off `_field_root`'s children, which were just queued
	# for free, so the references must not outlive them.
	_action_pip = null
	_water_material = null
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
	_ambient_emitters.clear()
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
	# GH#335: after every visual exists, so `entity_at`'s answer and the built
	# geometry can never disagree about what the bracket is pointing at.
	_reconcile_faced_affordance()
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
			# Held so reduce-motion can stop (and restart) this clock without a
			# map rebuild; the assignment below applies the CURRENT setting to
			# the freshly built overlay.
			_water_material = mat
			_apply_motion_settings()
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
		_water_material = null
		overlay.queue_free()


func _build_ice_overlay() -> void:
	var frozen: Array = Game.sim.frozen_cells_json().get(Game.sim.current_map, [])
	for pair: Variant in frozen:
		if pair is Array and (pair as Array).size() == 2:
			_paint_ice_cell(Vector2i(int(pair[0]), int(pair[1])))


func _paint_ice_cell(cell: Vector2i) -> void:
	if _ice_overlay == null:
		_ice_overlay = WITileBoardBuilder.make_tile_layer(_field_root, ICE_SHEET, 16, WISpriteRegistry)
		_ice_overlay.z_index = 1
		_field_root.add_child(_ice_overlay)
	_ice_overlay.set_cell(cell, 0, ICE_CAP_COORD)


func _unpaint_ice_cell(cell: Vector2i) -> void:
	if _ice_overlay != null:
		_ice_overlay.erase_cell(cell)


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


## Atmosphere lever 3 (the motion layer's ambient-particle half): 12 of the 29
## shipped maps declare no `ambience` row at all, so nothing in them moves. The
## fallback lives in the BIOME rather than in twelve new hand-authored map rows
## because that is the honest layer for it -- "what drifts in the air of an
## indoor room" is a property of the kind of place, not of each room that
## happens to be one. A map declaring even ONE row keeps exactly what it
## declares (no merge with the default), so every hand-tuned scene is
## byte-identical and the fallback only ever fills a vacuum.
func _build_ambience() -> void:
	var rows: Array = _current_map_cfg().get("ambience", [])
	if rows.is_empty():
		rows = _biome_default_ambience()
	for raw: Variant in rows:
		if not (raw is Dictionary):
			continue
		var spec := raw as Dictionary
		var preset := String(spec.get("preset", ""))
		if preset == "":
			continue
		var rect := _resolve_ambience_rect(spec.get("rect", "all"))
		var node := WIAmbience.make(preset, rect)
		_field_root.add_child(node)
		var phases: Array = spec.get("phase", [])
		_atmosphere.register_emitter(node, phases)
		_ambient_emitters.append({"node": node, "phases": phases})
		_ambience_count += 1
	assert(_ambience_count <= AMBIENCE_BUDGET,
		"map %s exceeds the %d-emitter budget (%d) -- spec §5" % [Game.sim.current_map, AMBIENCE_BUDGET, _ambience_count])
	# Reduce-motion is applied AFTER registration, never by refusing to build:
	# an emitter that exists but is cut can be switched back on the instant the
	# setting flips, which is what makes the toggle live (finding #3). Same
	# emitter-always-exists / state-toggled shape the phase gate already uses.
	# `emitting` is the count actually MOVING at build time -- `emitters` alone
	# could never distinguish "a dusk/night emitter parked at day" from "indoor
	# motes drifting through a noon frame", which is exactly the confusion that
	# let two sky-bearing exteriors break the day-identity contract unnoticed
	# (finding #2/#9). Payload matching is subset-based, so this is additive.
	ObservableBus.emit_domain_event(WIEvents.UI_AMBIENCE_RENDERED, {
		"map": Game.sim.current_map,
		"emitters": _ambience_count,
		"emitting": _apply_ambient_emitter_state(),
	})


## One row max, `rect: "all"` implied. Phase gating is the load-bearing half:
## anything with a SKY is dusk/night only, so the ship-neutral "day is fully
## identity" contract every windowed day shot pins stays exactly true; sealed
## interiors and underground have no sky and read at every phase.
## THE GATE IS PER-MAP, NOT PER-BIOME (v0.17 fix wave, adversarial finding
## #2/#9). Keying it on the biome alone was simply wrong: `ruin_surface` is
## biome `cave` and `mercantile_alleys` is biome `invrisil_alley`, and both are
## sky-bearing exteriors with a full day/night grade -- they were emitting
## indoor dust motes at noon, on the two maps the day-identity claim is loudest
## about. Sky-vs-no-sky is a property of the ROOM, so it is read off the room:
## see `_map_has_sky`. Reduce-motion is NOT handled here -- the rows are always
## built and the emitters cut in `_apply_ambient_emitter_state`, so the setting
## answers live instead of at the next door crossing.
func _biome_default_ambience() -> Array:
	var biome_id := String(_current_map_cfg().get("biome", ""))
	var row: Variant = BIOME_DEFAULT_AMBIENCE.get(biome_id)
	if row == null:
		return []
	var spec: Dictionary = (row as Dictionary).duplicate()
	if _map_has_sky(Game.sim.current_map):
		spec["phase"] = SKY_DEFAULT_PHASES.duplicate()
	return [spec]


## Does this map answer to the SUN? Read from the map's own mood card rather
## than from any new flag: a room with a sky is graded down at DUSK, and a
## sealed one is not -- `dungeon_approach`/`trapped_halls`/`seal_vault`/
## `brothers_parlor` all pin day and dusk to the identical triple, while every
## exterior (street, the boulevard, the alleys, ruin_surface, witch_hollow's
## canopy) drops hard at sunset. Night is deliberately NOT part of the test:
## the dungeon dims after dark too, which is authorial mood, not daylight.
## A map with no mood row at all falls to TRUE -- the conservative direction,
## since a false negative would put drifting particles in a day-identity frame.
## Read-only duplicate of moods.json, same load-once idiom (and same reason)
## as board_renderer.gd's `_resolved_mood_rgb`: this must not reach into
## atmosphere.gd, which is outside this lane's ownership. Long-term home is a
## `WIAtmosphere.map_has_sky()` -- see .lane-progress SEAMS.
static func _map_has_sky(map_id: String) -> bool:
	if _sky_cache.has(map_id):
		return bool(_sky_cache[map_id])
	if _moods_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOODS_PATH))
		_moods_cache = parsed if parsed is Dictionary else {}
	var mood: Dictionary = (_moods_cache.get("moods", {}) as Dictionary).get(map_id, {})
	var day: Variant = mood.get("day")
	var dusk: Variant = mood.get("dusk")
	var has_sky := true
	if day is Array and dusk is Array and (day as Array).size() == 3 and (dusk as Array).size() == 3:
		has_sky = false
		for i in range(3):
			if absf(float(day[i]) - float(dusk[i])) > SKY_GRADE_EPSILON:
				has_sky = true
				break
	_sky_cache[map_id] = has_sky
	return has_sky


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
	# GH#335: the faced cell (and therefore the affordance bracket) is a pure
	# function of player_cell + player_facing + who is present there, so one
	# membership list catches every producer of a change to any of the three --
	# a move, a blocked bump (which turns without moving), a blink, a presence
	# flip, a conversation opening or closing. Reconciling here rather than in
	# each arm keeps the arms about their own subject; MAP_CHANGED is absent on
	# purpose (`_rebuild_field` ends with its own reconcile against the built
	# field, and reconciling against stale geometry mid-transition is exactly
	# the class of bug the stale-cover guard exists for).
	if type in AFFORDANCE_REFRESH_EVENTS and not _map_transition_stale_cover():
		_reconcile_faced_affordance(type)
	if type == WIEvents.GAME_LOADED or type == WIEvents.MAP_CHANGED:
		# GH#345: a sim swap (load/import/new game) builds a fresh WIGame with
		# the field at its 1.0 default -- re-push the persisted difficulty.
		Game.sim.difficulty_damage_taken_mult = WISettings.difficulty_damage_taken_mult()
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
		# GH#330 R4: the EXISTENCE half, same shape as the PHASE_CHANGED arm
		# below -- `present_when.companion` rows flip the instant the bond
		# does, so the wolf's caches must build/free on the same beat the
		# follower sprite appears (a tame is same-map by construction).
		if not _map_transition_stale_cover():
			_reconcile_entity_presence()
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
				"water":
					# GH#387 thaw_cell's inverse. Without this the cap stays
					# painted until the next PHASE_CHANGED or map rebuild (the
					# overlay's only other removals, :1712 and :778), so the
					# player is shown ice on a cell the sim has already made
					# open water -- reads as "walk here", refuses, tells them
					# nothing. Caught by phase-0 review, both lenses.
					_unpaint_ice_cell(tc_cell)
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
	# Marks the slot as THE walk tween: `_play_action_tell` refuses to kill it,
	# because killing it would swallow the `finished` above and with it the
	# held-key repeat / click-path advance.
	_player_tween_is_move = true


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
		# GH#374: skip the invisible defeat grace. It shares this dictionary with
		# real charms but the player never cast it, so drawing a hearthward charm
		# for it would be a lie about what they can do. Explicit rather than
		# leaning on its missing `cell` key below -- the intent has to be legible
		# to whoever next adds a suppression shape here.
		if bool(ward.get("until_exit", false)):
			continue
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
	_player_tween_is_move = false


func _kill_player_tween() -> void:
	if _player_tween != null and _player_tween.is_valid():
		_player_tween.kill()
	_player_tween_is_move = false


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
	# v0.19 L5 reviewer lens A: this is the ONE facing change in the game that
	# passes through no sim event at all (it writes `player_facing` directly),
	# so the bracket -- and now UI_AFFORDANCE_RENDERED with it -- stayed pinned
	# to the cell the player was facing BEFORE the click. Mouse/touch players
	# clicking an adjacent prop that only toasts got no bracket on the thing
	# they were plainly facing until their next step. Reconcile here rather
	# than teaching every caller: `handle_world_click` is the sole call site
	# today and a future one gets the answer for free.
	_reconcile_faced_affordance()


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
