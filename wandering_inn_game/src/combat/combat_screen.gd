extends CanvasLayer
## Functional-minimal combat presentation. Renders the WICombat snapshot as
## a grid of squares with HP bars and AP pips, a turn-order strip, a hotbar-
## driven action UI (arrows move the active unit directly), and a
## prose event feed. HP readouts and damage numbers are player-visible; raw
## stats remain hidden by repo product constraint.

const CELL := 16
## The board (tiles/skirt/holders/flashes -- all
## world-space content) renders into `World.combat_board_root()`, a Node2D
## inside the world SubViewport, not this CanvasLayer. Combat UI (hotbar/
## readout/order/feed/banner) stays in this CanvasLayer, native resolution.

const LINE_DIR_VECTORS := {
	"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT,
}
const FROST_FLASH := Color(0.5, 0.8, 1.0)
const FLAME_FLASH := Color(1.0, 0.45, 0.15)
const SHIELD_FLASH := Color(0.4, 0.6, 1.0)
const AI_BEAT_SECONDS := 0.5
const HEAVY_HIT_DAMAGE := 14
## TRAP: an event that fires during an AI turn but is
## MISSING from this list falls through to the live _on_domain_event arm and
## renders IMMEDIATELY against end-of-turn state (the T10 "teleport" desync),
## silently — QA can't see it (zero-delay). Adding a combat event type? Add
## it here AND trace its capture in combat_playback.gd.
const AI_PLAYBACK_TYPES := [
	WIEvents.COMBATANT_MOVED, WIEvents.AP_CHANGED, WIEvents.COMBATANT_DOWNED,
	WIEvents.ATTACK_RESOLVED, WIEvents.SKILL_RESOLVED, WIEvents.REACTION_TRIGGERED,
	WIEvents.DASHED, WIEvents.STATUS_APPLIED, WIEvents.STATUS_EXPIRED,
	WIEvents.ACTION_REFUSED, WIEvents.TURN_STARTED, WIEvents.COMBAT_FINISHED,
	WIEvents.TURN_ENDED,
	# TERRAIN_EXPIRED fires at round rollover, which happens MID an
	# AI turn (inside _advance_turn) -- exactly the desync class this const's
	# TRAP comment warns about. TERRAIN_ADDED fires mid-AI-turn too since
	# GH#90: combat_ai.gd's area_skill arm casts icy_floor for real
	# (goblin_shaman's live kit; `shaman_zone_loop` = the canonical), so
	# this entry is load-bearing, not symmetry.
	WIEvents.TERRAIN_ADDED, WIEvents.TERRAIN_EXPIRED,
	WIEvents.WINDUP_DECLARED,
	# GH#90 [burning]: STATUS_TICKED fires at round rollover, inside
	# `_advance_turn` -- MID an AI turn whenever an AI combatant's end_turn
	# wraps the order (the TERRAIN_EXPIRED class exactly). Also reaches the
	# live arm when the PLAYER's own end_turn wraps the order instead.
	WIEvents.STATUS_TICKED,
]

## DASH_CONFIRM guards against fat-fingering AP away with a stray hotbar_2
## press (Dash used to fire instantly on selection) -- selecting it now
## behaves like an aimed slot: shows its cost/effect in the readout and ARMS
## a confirm gate (Enter executes, Esc cancels back to HOTBAR) instead of
## spending AP immediately. It is deliberately NOT folded into ATTACK/
## SKILL_TARGET's `_targeting`-driven flow — Dash has no target to cycle, so
## `_input_dash_confirm` handles it directly at the composition-root level
## (same "command surface stays on the screen" contract the targeting
## flow follows). Issue #92 R2: DASH_CONFIRM is now Dash's mode AND a
## consumable item-use's mode -- both are niladic (no target to cycle), so
## the SAME gate/enum value covers either; `_confirm_bar_action` branches on
## which one is actually armed. The enum's name stays historical (Dash was
## first) rather than a repo-wide rename for a two-command generalization.
enum Mode { INACTIVE, HOTBAR, ATTACK, SKILL_TARGET, DASH_CONFIRM, WAIT_AI, BANNER }

var _mode: int = Mode.INACTIVE
var _root: Control
var _board_renderer: Node
var _view: RefCounted
var _ai_playback: RefCounted
var _targeting: RefCounted
var _hud: RefCounted
var _bar_slots: Array = []
var _bar_index := -1
var _info_slot_index := 0
## The WIMain host, injected downward at spawn by WIMain._spawn_ui_layers
## — the route to world_labels()/world_root() instead of a
## find_child scan. Typed Node, not WIMain: this file must stay compilable as
## the autoload-stubbed in-memory copy tests/test_combat_visuals.gd builds
## under bare --script mode, and a hard WIMain annotation would pull the
## autoload-referencing main.gd into that compile.
var main_ref: Node

## Issue #75 item 3: which skill (if any) is CURRENTLY resolving, purely for
## the ranged/spell projectile's element tint -- ATTACK_RESOLVED itself
## carries no skill id (spell_damage/line_damage/blast_damage/damage_mult
## hits all reuse it verbatim via `_resolve_hit`, per this file's own doc
## comment above), so this is set the instant a damage-capable SKILL_RESOLVED
## is seen and consumed by that SAME cast's own ATTACK_RESOLVED hit(s) moments
## later. Reset at the START of every action: AP_CHANGED fires first for
## EVERY combat command (attack/dash/spend_skill_costs), so a plain ranged
## Attack (no skill, melee=false for a bow's own math) always renders
## TRANSPARENT (the neutral PROJECTILE_DEFAULT_COLOR) -- correct, since it
## isn't elemental. Ordering holds identically live and under paced AI
## playback: both render events in strict capture/emission order, and a
## multi-hit blast/line's own SKILL_RESOLVED always precedes every one of its
## hits with no other SKILL_RESOLVED interleaved before they're all applied.
var _acting_skill_flash_color: Color = Color.TRANSPARENT

## Issue #60 item 1: a one-time "your hotbar is class+weapon-derived" feed
## line on the FIRST combat of a sitting -- there is no loadout editor for
## combat skills, so the player just needs to be told. `static var` (not an
## instance var) for the SAME reason message_layer.gd's `_first_pickup_hint_
## shown` is static: it must survive this script's own teardown/respawn
## (main.gd's `_clear_ui_layers`/`_spawn_ui_layers` swap on every GAME_RESET/
## GAME_LOADED) rather than resetting to false on a mid-sitting reload.
static var _first_combat_hint_shown := false
static var _combat_hint_reset_hooked := false


static func _reset_first_combat_hint(type: String, _payload: Dictionary) -> void:
	if type == WIEvents.GAME_RESET:
		_first_combat_hint_shown = false


static func reset_hints() -> void:
	_first_combat_hint_shown = false


func _ready() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.hide()
	add_child(_root)
	# The arena board is NOT created here: it must live
	# inside the world SubViewport (`World.combat_board_root()`), and the
	# World node doesn't exist yet at this point in Main's boot sequence
	# (`_spawn_ui_layers()` runs before `_spawn_world()`). Resolved lazily by
	# `_board_renderer.build()`, called from `_show_combat()`.
	_hud = load("res://src/combat/combat_hud.gd").new(_root, main_ref, self)
	_hud.build()
	_hud.hotbar_node().slot_clicked.connect(_on_hotbar_slot_clicked)
	_hud.confirm_tapped.connect(_on_confirm_chip_tapped)
	_board_renderer = load("res://src/combat/board_renderer.gd").new()
	_board_renderer.name = "BoardRenderer"
	add_child(_board_renderer)
	_ai_playback = load("res://src/combat/combat_playback.gd").new(_board_renderer, self)
	ObservableBus.domain_event.connect(_on_domain_event)
	# See `_first_combat_hint_shown`'s doc comment: hooked once per process,
	# bound to the SCRIPT resource (get_script()), never to this instance --
	# same message_layer.gd precedent (a GAME_RESET fired from the title
	# screen, before any fresh CombatScreen exists, must still reach it).
	if not _combat_hint_reset_hooked:
		_combat_hint_reset_hooked = true
		ObservableBus.domain_event.connect(Callable(get_script(), "_reset_first_combat_hint"))


func _combat() -> WICombat:
	return Game.sim.combat


func _combat_or_null() -> WICombat:
	if Game == null or Game.sim == null:
		return null
	return Game.sim.combat


func _on_domain_event(type: String, payload: Dictionary) -> void:
	# match_tutor_line's doc comment for why this must be capture-time, not
	# dequeue-time. combat_started resets the per-combat tutor state FIRST
	# (reading `combat.arena_config` directly -- `_view` doesn't exist yet at
	# this point, it's built a moment later by `_show_combat()`, the SAME
	# event's own match arm below) so a fresh combat never matches against
	# the previous combat's list.
	if type == WIEvents.COMBAT_STARTED:
		var combat := _combat_or_null()
		_hud.reset_tutor_lines(combat.arena_config if combat != null else {})
	var tutor: Dictionary = _hud.match_tutor_line(type, payload)
	if _ai_playback.is_ai_turn_active() and _mode == Mode.WAIT_AI and type in AI_PLAYBACK_TYPES:
		var event: Dictionary = _ai_playback.capture_playback_event(type, payload)
		if not tutor.is_empty():
			# Stash the ALREADY-DECIDED match onto the queued event so
			# dequeue-time playback only renders it (feed push + bus confirm)
			# -- it never re-matches against live state (the playback contract).
			(event["payload"]["_ui"] as Dictionary)["tutor"] = tutor
		_ai_playback.enqueue(event)
		if type == WIEvents.COMBATANT_DOWNED:
			_board_renderer.mark_death_visible(String(payload["id"]))
		return
	match type:
		WIEvents.INPUT_DEVICE_CHANGED:
			if _mode != Mode.INACTIVE:
				_refresh()
		WIEvents.COMBAT_STARTED:
			_show_combat()
			_render_tutor_line(tutor)
		WIEvents.TURN_STARTED:
			if _mode != Mode.INACTIVE:
				_render_tutor_line(tutor)
				_apply_turn_started(String(payload["id"]))
		WIEvents.COMBAT_FINISHED:
			if _mode != Mode.INACTIVE:
				var layer_script := load("res://src/ui/message_layer.gd")
				if layer_script != null:
					layer_script.record_message("Victory — %d rounds." % int(payload.get("rounds", 0)) if bool(payload.get("victory", false)) else "Defeat — %d rounds." % int(payload.get("rounds", 0)))
				_render_tutor_line(tutor)
				_apply_combat_finished(payload)
		# TRAP (issue #82): WINDUP_DECLARED is deliberately ABSENT from this
		# live-match list -- it can only fire from inside an AI turn today
		# (`slam` is enemy-only; declares happen inside WICombatAI.take_turn,
		# always captured). A future PLAYER-castable windup skill fires it on
		# the live path where it would match nothing and render nothing --
		# wire a live arm (feed line + dangersense overlay) AND a targeting
		# tell before shipping such a skill.
		WIEvents.COMBATANT_MOVED, WIEvents.AP_CHANGED, WIEvents.COMBATANT_DOWNED, \
		WIEvents.ATTACK_RESOLVED, WIEvents.SKILL_RESOLVED, WIEvents.REACTION_TRIGGERED, \
		WIEvents.DASHED, WIEvents.STATUS_APPLIED, WIEvents.STATUS_EXPIRED, WIEvents.STATUS_TICKED, \
		WIEvents.ACTION_REFUSED, WIEvents.TERRAIN_ADDED, WIEvents.TERRAIN_EXPIRED:
			if _mode != Mode.INACTIVE:
				var event := _capture_playback_event(type, payload)
				_play_event_visual(type, event["payload"])
				_push_feed(event["payload"])
				_render_tutor_line(tutor)
				_refresh()
		WIEvents.TURN_ENDED:
			if _mode != Mode.INACTIVE:
				_render_tutor_line(tutor)
		WIEvents.UI_TARGETING_SHOWN:
			if _mode != Mode.INACTIVE:
				_render_tutor_line(tutor)


func _apply_combat_finished(payload: Dictionary) -> void:
	_mode = Mode.BANNER
	# Composed through WIInputHints
	# directly (combat_screen.gd IS the composition root, unlike combat_hud.gd/
	# targeting_controller.gd, which stay autoload-free by contract); kb-mode
	# output is byte-identical to the old literal.
	var confirm_glyph: String = WIInputHints.label("confirm")
	_hud.show_banner(("Victory! — %s" % confirm_glyph) if bool(payload["victory"]) else ("Defeat… — %s" % confirm_glyph))
	_refresh()


func _show_combat() -> void:
	_mode = Mode.WAIT_AI
	_hud.clear_feed()
	_view = load("res://src/combat/combat_view.gd").new(_combat())
	_targeting = load("res://src/combat/targeting_controller.gd").new(_view, self)
	_board_renderer.build(_view, main_ref)
	_announce_allies()
	_announce_first_combat_hint()
	_refresh()
	_root.show()
	ObservableBus.emit_domain_event(WIEvents.UI_COMBAT_SHOWN, {})
	# Do NOT call _apply_turn_started here: WICombat.begin() emits combat_started
	# then turn_started synchronously for the same first actor (in that order,
	# by contract) — the turn_started handler drives the first turn instead.


func _announce_allies() -> void:
	var names: Array[String] = []
	for id: String in _view.ids():
		if id == "pc":
			continue
		if String(_view.combatant(id).get("side", "")) == "player":
			names.append(_view.display_name(id))
	if names.is_empty():
		return
	var verb := "wades" if names.size() == 1 else "wade"
	_hud.feed_push("%s %s in beside you." % [_join_and(names), verb])


## Issue #60 item 1: pushes the one-time "combat kit is class+weapon-derived"
## feed line, gated by `_first_combat_hint_shown` -- fires at most once per
## sitting, after `_announce_allies()`'s own feed line (so a fielded-ally
## fight reads "X wades in beside you." before this, matching the existing
## call order at this call site). Composed through WIInputHints.label()
## (combat_screen.gd IS the composition root, same contract `_apply_combat_
## finished`'s confirm_glyph line already follows) so the glyph tracks the
## live input device; kb-mode text never changes across a device swap
## mid-fight because this only ever renders ONCE.
func _announce_first_combat_hint() -> void:
	if _first_combat_hint_shown:
		return
	_first_combat_hint_shown = true
	var text := "Your hotbar (%s) shows the skills your classes and weapon grant." % WIInputHints.label("hotbar")
	_hud.feed_push(text)
	ObservableBus.emit_domain_event(WIEvents.UI_COMBAT_HINT_RENDERED, {"text": text})


func _join_and(names: Array[String]) -> String:
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	return "%s, and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


## Readout/order-strip/feed/banner text — cheap, and always safe to refresh from
## the live snapshot even mid-playback (they summarize the encounter as a
## whole, not a single combatant's paced position/HP/MP — see
## _refresh_combatants for the part that ISN'T safe to refresh live here).
func _refresh() -> void:
	var combat := _combat()
	if combat == null:
		return
	if not _ai_playback.is_playing():
		_refresh_combatants()
	var bar_active := _mode in [Mode.HOTBAR, Mode.ATTACK, Mode.SKILL_TARGET, Mode.DASH_CONFIRM]
	var in_targeting := _mode in [Mode.ATTACK, Mode.SKILL_TARGET]
	var ai_skip_hint: bool = _mode == Mode.WAIT_AI and _ai_playback.is_playing()
	var targeting_state := {}
	# The composition root is the ONLY
	# place `targeting_controller.gd`/`combat_hud.gd` may be hinted with real
	# device glyphs -- both files carry ZERO bare autoload identifiers by
	# contract (test_combat_visuals.gd asserts standalone compile), so
	# WIInputHints.label() is only ever called HERE and threaded down as
	# plain strings.
	var hints := {
		"confirm": WIInputHints.label("confirm"), "cancel": WIInputHints.label("cancel"),
		"cycle": WIInputHints.label("cycle"), "move": WIInputHints.label("move"),
		"hotbar": WIInputHints.label("hotbar"), "end_turn": WIInputHints.label("end_turn"),
	}
	if in_targeting and _targeting != null:
		targeting_state = _targeting.state()
		if bool(targeting_state.get("line_mode", false)):
			targeting_state["line_text"] = _targeting.line_target_text(hints["cycle"], hints["confirm"])
		_board_renderer.render_aim_preview(_targeting.aim_preview())
	else:
		_board_renderer.clear_aim_preview()
	_hud.refresh(_view, bar_active, in_targeting, _mode == Mode.BANNER, targeting_state, _bar_slots, _bar_index, _info_slot_index, _mode == Mode.DASH_CONFIRM, hints, ai_skip_hint)


func _refresh_combatants() -> void:
	if _combat_or_null() == null or _view == null:
		return
	for id: String in _view.ids():
		_board_renderer.move_visual(id, _view.cell(id), true)
		_board_renderer.set_visible(id, _view.alive(id) or _board_renderer.death_visible(id))
		_board_renderer.apply_stats(id, _view.stats(id))


## Delegator — NOT dead code: the real
## implementation MOVED to `WICombatPlayback.capture_playback_event`
## (`combat_playback.gd`), and this wrapper has a LIVE production call site:
## `_on_domain_event`'s non-AI (player-turn) event branch calls
## `_capture_playback_event(...)` on every live combat event. Do NOT delete
## as "test-only" in future cleanup. It also lazily constructs `_ai_playback`
## if `_ready()` never ran, which is what lets
## `tests/test_combat_visuals.gd` (out of this task's edit scope) call
## `screen._capture_playback_event(...)` directly on a patched copy of this
## file instantiated via bare `GDScript.new()`/`.new()` without `_ready()`.
func _capture_playback_event(type: String, payload: Dictionary) -> Dictionary:
	if _ai_playback == null:
		_ai_playback = load("res://src/combat/combat_playback.gd").new(_board_renderer, self)
	return _ai_playback.capture_playback_event(type, payload)


## Delegators to `WICombatHud`'s feed/tutor methods. `_feed_line_for_
## event` is a REQUIRED live delegator, not a test-only shim: `combat_
## playback.gd`'s `_capture_event_ui` (out of this task's edit scope) calls
## `_screen._feed_line_for_event(...)` on EVERY captured event, real gameplay
## and `tests/test_combat_visuals.gd`'s direct `_capture_playback_event(...)`
func _feed_line_for_event(type: String, payload: Dictionary) -> String:
	if _hud == null:
		_hud = load("res://src/combat/combat_hud.gd").new(_root, main_ref, self)
	return _hud.feed_line_for_event(type, payload, _combat_or_null(), _view)


func _push_feed(payload: Dictionary) -> void:
	_hud.push_feed(payload)


func _render_tutor_line(tutor: Dictionary) -> void:
	_hud.render_tutor_line(tutor)


func _emit_slot_info(slot: int, text: String) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_SLOT_INFO_RENDERED, {"slot": slot, "text": text})


func _emit_tutor_rendered(beat_id: String) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_TUTOR_LINE_RENDERED, {"beat": beat_id})


func _emit_targeting_shown_event(mode_text: String, skill_id: String, target_count: int) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_TARGETING_SHOWN, {
		"mode": mode_text, "skill": skill_id, "targets": target_count,
	})


## Whether the PC has been granted ANY class yet -- `combat_hud.gd`'s
## `_tutor_line_text` reads this to pick between a tutor entry's
## `line`/`fallback_line` (the `requires_any_class` gate). CONSTRAINTS:
## `Game.sim.classes` is the direct sim read, deliberately NOT an
## accomplishment counter -- no counter fires unconditionally on every
## sleep the way a true "has slept, has a class" signal would need
## (`times_slept` is a bare int field, not accomplishment-tracked;
## `sparred_with_relc` banks BEFORE the sleep that actually grants the
## class, so it cannot stand in). Read-only, same as every other
## `_screen.*` wrapper on this file -- `combat_hud.gd` never touches the
## `Game` autoload directly (zero-bare-autoload-identifier contract, see
## that file's doc comment).
func _pc_has_any_class() -> bool:
	return not Game.sim.classes.is_empty()


## Read-only combat-roster query, same wrapper contract as
## `_pc_has_any_class()` above (a sim read, never a mutation) -- whether `id`
## is fielded on the PC's OWN side THIS fight (an `ally_requires`-gated
## combatant that failed its gate is never added to `combat.combatants` at
## all, see wi_game.gd's `start_combat`). Issue #88 (gap-2): lets
## combat_hud.gd's `_tutor_line_text` split a tutor line's fallback text on
## ally presence -- a line voiced as that ally speaking must not render when
## the ally structurally isn't in the fight.
func _pc_has_ally(id: String) -> bool:
	var combat := _combat()
	if combat == null:
		return false
	var c: Dictionary = combat.combatants.get(id, {})
	return not c.is_empty() and String(c.get("side", "")) == "player"


func _play_event_visual(type: String, payload: Dictionary) -> void:
	var ui: Dictionary = payload.get("_ui", {})
	match type:
		WIEvents.AP_CHANGED:
			_acting_skill_flash_color = Color.TRANSPARENT
		WIEvents.ATTACK_RESOLVED:
			var attacker_id := String(payload["attacker"])
			var target_id := String(payload["target"])
			# spell_damage/line_damage casts route through the sim's
			# _resolve_hit with melee=false and reuse ATTACK_RESOLVED, so a
			# ranged cast (frost_bolt/flame_jet) must play the cast/gesture
			# animation, NOT the sword swing (VISUAL-LOG common-sense fix).
			var attack_anim := "slice" if bool(payload.get("melee", true)) else "cast"
			_play_combatant_anim(attacker_id, attack_anim, ui.get("attacker_flip_h", null))
			var attacker_cell: Array = ui.get("attacker_cell", [])
			var target_cell: Array = ui.get("target_cell", [])
			# Issue #75 item 3: attack connection, gated on SPATIAL adjacency
			# from the captured cells -- NOT the `melee` payload flag, which
			# means STR-vs-INT damage math (wi_combat.gd's own doc comment),
			# not physical reach: a bow's basic Attack passes melee=true for
			# its damage math while the attacker stands several cells away,
			# and lunging the holder that far would be a visible glitch, not
			# a swing. Plays regardless of hit/miss -- a swing still swings,
			# a shot still travels, even when it doesn't land.
			if _cells_chebyshev(attacker_cell, target_cell) <= 1:
				_board_renderer.micro_lunge(attacker_id, target_cell)
			else:
				_board_renderer.spawn_projectile(attacker_cell, target_cell, _acting_skill_flash_color)
			if bool(payload.get("hit", false)):
				if _board_renderer.has_sprite(target_id):
					_play_combatant_anim(target_id, "hit", ui.get("target_flip_h", null))
					_board_renderer.impact_flash(target_id)
				else:
					_board_renderer.flash_chip(target_id)
				_board_renderer.spawn_hit_sparks(target_cell)
				var combat_ref := _combat_or_null()
				if combat_ref != null and combat_ref.combatants.has(target_id):
					_board_renderer.spawn_damage_number(target_cell, int(payload.get("damage", 0)), String(combat_ref.combatants[target_id].get("side", "")))
				if target_id == "pc" or int(payload.get("damage", 0)) >= HEAVY_HIT_DAMAGE:
					_board_renderer.shake_board(3.0 if target_id == "pc" else 4.0)
			else:
				_board_renderer.spawn_miss_indicator(target_cell)
		WIEvents.COMBATANT_DOWNED:
			var downed_id := String(payload["id"])
			_board_renderer.mark_death_visible(downed_id)
			if _board_renderer.has_sprite(downed_id):
				_play_combatant_anim(downed_id, "death")
			else:
				_board_renderer.fade_chip(downed_id)
			var downed_windup_cells: Array = ui.get("windup_cells", [])
			if not downed_windup_cells.is_empty():
				_board_renderer.expire_terrain("windup_danger", _ai_playback._cells_from_payload(downed_windup_cells))
		WIEvents.STATUS_APPLIED:
			var applied_status := String(payload.get("status", ""))
			if applied_status == "invisible":
				_board_renderer.set_combatant_alpha(String(payload["id"]), 0.35)
			else:
				_board_renderer.set_status_pip(String(payload["id"]), applied_status, true)
		WIEvents.STATUS_EXPIRED:
			var expired_status := String(payload.get("status", ""))
			if expired_status == "invisible":
				_board_renderer.set_combatant_alpha(String(payload["id"]), 1.0)
			else:
				_board_renderer.set_status_pip(String(payload["id"]), expired_status, false)
		WIEvents.STATUS_TICKED:
			var ticked_cell: Array = ui.get("target_cell", [])
			var ticked_damage := int(payload.get("damage", 0))
			if not ticked_cell.is_empty() and ticked_damage > 0:
				_board_renderer.spawn_damage_number(ticked_cell, ticked_damage, String(ui.get("side", "")))
		WIEvents.SKILL_RESOLVED:
			var color: Color = ui.get("flash_color", Color.TRANSPARENT)
			# Issue #75 item 3: stashed for this SAME cast's own
			# ATTACK_RESOLVED hit(s), moments later -- see
			# `_acting_skill_flash_color`'s own doc comment for the full
			# ordering contract. Set unconditionally (even TRANSPARENT for a
			# non-damage skill like Dash/Stealth) so a stale color from an
			# EARLIER cast this same turn can never leak into a later
			# non-elemental action.
			_acting_skill_flash_color = color
			if color.a > 0.0:
				_flash_cells(_ai_playback._cells_from_payload(ui.get("flash_cells", [])), color)
			var resolved_combat := _combat_or_null()
			if resolved_combat != null:
				var resolved_skill: Dictionary = resolved_combat.skills.get(String(payload.get("skill", "")), {})
				if int((resolved_skill.get("effect", {}) as Dictionary).get("windup_rounds", 0)) > 0:
					_board_renderer.expire_terrain("windup_danger", _ai_playback._cells_from_payload(payload.get("cells", [])))
		WIEvents.REACTION_TRIGGERED:
			if String(payload.get("skill", "")) == "mana_shield":
				_flash_cells(_ai_playback._cells_from_payload(ui.get("flash_cells", [])), SHIELD_FLASH)
		WIEvents.TERRAIN_ADDED:
			# No enqueue-time `_ui` capture needed -- `cells`/`kind` are
			# already the full render input straight off the domain payload
			# (same reasoning line_damage's SKILL_RESOLVED cells need none).
			_board_renderer.add_terrain(String(payload.get("kind", "")), _ai_playback._cells_from_payload(payload.get("cells", [])))
		WIEvents.TERRAIN_EXPIRED:
			_board_renderer.expire_terrain(String(payload.get("kind", "")), _ai_playback._cells_from_payload(payload.get("cells", [])))


func _play_combatant_anim(id: String, prefix: String, flip_h: Variant = null) -> void:
	_board_renderer.play_anim(id, prefix, flip_h)


func _skill_flash_color(skill_id: String) -> Color:
	var combat := _combat_or_null()
	if combat == null or not combat.skills.has(skill_id):
		return Color.TRANSPARENT
	var skill: Dictionary = combat.skills[skill_id]
	var effect_type := String((skill.get("effect", {}) as Dictionary).get("type", ""))
	# icy_floor's SKILL_RESOLVED carries the same "cells" payload shape
	# as line_damage, so it rides the exact same _skill_flash_cells payload.has("cells")
	# branch below with zero changes there -- only the eligible-type gate and
	# color pick need to widen. blast_damage (GH#71) shares that same "cells"
	# shape too (skill_effects.gd's `_resolve_blast_damage` emits it verbatim
	# from `_radius_area`), so it rides the identical branch.
	if not (effect_type in ["spell_damage", "line_damage", "icy_floor", "blast_damage"]):
		return Color.TRANSPARENT
	if skill_id.begins_with("frost") or effect_type == "icy_floor":
		return FROST_FLASH
	return FLAME_FLASH


func _skill_flash_cells(payload: Dictionary, allow_live_fallback: bool = false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if payload.has("cells"):
		for raw_cell: Variant in payload["cells"]:
			if raw_cell is Vector2i:
				out.append(raw_cell)
			elif raw_cell is Array and (raw_cell as Array).size() >= 2:
				var raw_array := raw_cell as Array
				out.append(Vector2i(int(raw_array[0]), int(raw_array[1])))
		return out
	if not allow_live_fallback:
		return out
	var combat := _combat_or_null()
	if combat == null:
		return out
	var skill_id := String(payload.get("skill", ""))
	var skill: Dictionary = combat.skills.get(skill_id, {})
	var effect: Dictionary = skill.get("effect", {})
	if String(effect.get("type", "")) == "line_damage":
		var actor_id := String(payload.get("actor", ""))
		var target_token := String(payload.get("target", ""))
		if combat.combatants.has(actor_id) and LINE_DIR_VECTORS.has(target_token):
			var origin: Vector2i = combat.combatants[actor_id]["cell"]
			var length := int(effect.get("length", 1))
			out.assign(combat.line_cells(origin, LINE_DIR_VECTORS[target_token], length))
	elif payload.has("target"):
		var target_id := String(payload["target"])
		if combat.combatants.has(target_id):
			out.append(combat.combatants[target_id]["cell"])
	return out


func _flash_cells(cells: Array[Vector2i], color: Color) -> void:
	_board_renderer.flash_cells(cells, color)


func _cells_chebyshev(a: Array, b: Array) -> int:
	if a.size() < 2 or b.size() < 2:
		return 999
	return maxi(absi(int(a[0]) - int(b[0])), absi(int(a[1]) - int(b[1])))


func _active_combatant() -> Dictionary:
	var combat := _combat()
	return combat.combatants[combat.get_active()]


func _bar_slot_index_of(type: String) -> int:
	for i in _bar_slots.size():
		if String((_bar_slots[i] as Dictionary).get("type", "")) == type:
			return i
	return -1


## Bar index for a pressed `hotbar_N` action (numbers 1-9 activate slots per
## spec sec.3), or -1 if no numbered slot matches. `InputMap.has_action` guards
## against these actions not existing yet -- the input actions are drafted for
## the controller to add to project.godot at merge (see report), not added by
## this task, so this must degrade to inert rather than erroring on every
## input event in the meantime.
func _numbered_slot_pressed(event: InputEvent) -> int:
	for n in range(1, 10):
		var action := "hotbar_%d" % n
		if InputMap.has_action(action) and event.is_action_pressed(action):
			for i in _bar_slots.size():
				if String((_bar_slots[i] as Dictionary).get("key_hint", "")) == str(n):
					return i
			return -1
	return -1


func _activate_bar_slot(index: int) -> void:
	if index < 0 or index >= _bar_slots.size():
		return
	var slot: Dictionary = _bar_slots[index]
	var c := _active_combatant()
	match String(slot["type"]):
		"attack":
			if _hud.bar_action_affordable("Attack", c):
				_bar_index = index
				_info_slot_index = index
				_mode = Mode.ATTACK
				_targeting.enter(Mode.ATTACK)
		"dash":
			if _hud.bar_action_affordable("Dash", c):
				_bar_index = index
				_info_slot_index = index
				_mode = Mode.DASH_CONFIRM
		"item":
			if int(c["ap"]) >= WIItems.FLAT_AP_COST:
				_bar_index = index
				_info_slot_index = index
				_mode = Mode.DASH_CONFIRM
		"skill":
			var skill_id := String(slot["id"])
			if _hud.skill_affordable(c, skill_id, _view):
				_bar_index = index
				_info_slot_index = index
				_mode = Mode.SKILL_TARGET
				_targeting.enter(Mode.SKILL_TARGET, skill_id)
		"end_turn":
			_info_slot_index = index
			_combat().end_turn()


func hotbar_node() -> WIHotbar:
	return _hud.hotbar_node()


func _on_hotbar_slot_clicked(index: int) -> void:
	if _mode != Mode.HOTBAR and _mode != Mode.ATTACK and _mode != Mode.SKILL_TARGET and _mode != Mode.DASH_CONFIRM:
		return
	if main_ref != null and main_ref.pause_open():
		return
	if _mode == Mode.HOTBAR:
		_activate_bar_slot(index)
	else:
		_switch_bar_slot(index)
	_refresh()


func _switch_bar_slot(index: int) -> void:
	if _mode == Mode.ATTACK or _mode == Mode.SKILL_TARGET:
		_targeting.cancel()
	_mode = Mode.HOTBAR
	_bar_index = -1
	_activate_bar_slot(index)


func handle_board_click(world_pos: Vector2) -> void:
	var cell := Vector2i(floori(world_pos.x / CELL), floori(world_pos.y / CELL))
	match _mode:
		Mode.HOTBAR:
			_tap_move(cell)
		Mode.ATTACK, Mode.SKILL_TARGET:
			if not _targeting.select_at_cell(cell):
				_cancel_targeting()
		Mode.DASH_CONFIRM:
			_cancel_bar_action()
		_:
			return
	_refresh()


func _tap_move(cell: Vector2i) -> void:
	var active_cell: Vector2i = _combat().combatants[_combat().get_active()]["cell"]
	var delta := cell - active_cell
	if delta != Vector2i.UP and delta != Vector2i.DOWN and delta != Vector2i.LEFT and delta != Vector2i.RIGHT:
		return
	_move_active_or_bump(delta)


func _on_confirm_chip_tapped() -> void:
	if main_ref != null and main_ref.pause_open():
		return
	match _mode:
		Mode.DASH_CONFIRM:
			_confirm_bar_action()
		Mode.ATTACK, Mode.SKILL_TARGET:
			if _targeting.has_valid_target():
				_confirm_targeted_action()
		_:
			return
	_refresh()


func confirm_chip_rect() -> Rect2:
	return _hud.confirm_chip_rect()


func _apply_turn_started(id: String) -> void:
	var combat := _combat()
	_board_renderer.set_active_marker(id)
	var c: Dictionary = combat.combatants[id]
	if String(c["side"]) == "enemy" or String(c["ai"]) != "":
		_mode = Mode.WAIT_AI
		_refresh()
		_ai_playback.run_ai_turn.call_deferred()
	else:
		_mode = Mode.HOTBAR
		# No QA script drives the hotbar by fixed slot index (combat_autoplay
		# calls WICombatAI.take_turn directly, bypassing this UI entirely), so
		# the bar's order is free to pick for readability rather than being
		# pinned by test coupling.
		_bar_slots = _hud.rebuild_slots(_view, id, Game.sim.hotbar_loadout, _usable_combat_items())
		_bar_index = -1
		_info_slot_index = 0  # Attack, per the "slot 1's info at turn start" playtest fix
		ObservableBus.emit_domain_event(WIEvents.UI_HOTBAR_RENDERED, {"slots": _bar_slots.size()})
		_refresh()


## Issue #92 R2: the PC's currently-carried combat-usable consumable
## records (a `use_effect.heal` shape only -- a `next_fight` meal never
## belongs on this bar, see `rebuild_slots`' own doc comment) -- threaded
## into `_hud.rebuild_slots` above the SAME way `Game.sim.hotbar_loadout`
## already is (this file freely references `Game.sim`; combat_hud.gd itself
## stays autoload-free). Recomputed fresh every turn start, matching
## `hotbar_loadout` itself never being cached either.
func _usable_combat_items() -> Array:
	var out: Array = []
	for raw_id: Variant in Game.sim.inventory:
		var id := String(raw_id)
		var rec: Dictionary = Game.sim.item(id)
		if (rec.get("use_effect", {}) as Dictionary).has("heal"):
			out.append(rec)
	return out


func _test_driver_active() -> bool:
	return TestDriver != null and TestDriver.active()


func _current_beat_seconds() -> float:
	if WISettings == null:
		return AI_BEAT_SECONDS
	return WISettings.beat_seconds_for_step(WISettings.combat_speed_step(), AI_BEAT_SECONDS)


func _emit_ai_playback_done(beats: int) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_AI_PLAYBACK_DONE, {"beats": beats})


func _unhandled_input(event: InputEvent) -> void:
	if _mode == Mode.INACTIVE or (Game.sim.combat == null and _mode != Mode.BANNER):
		return
	if _mode == Mode.WAIT_AI and _ai_playback.is_playing() and (event.is_action_pressed("confirm") or event.is_action_pressed("cancel")):
		_ai_playback.request_skip()
		get_viewport().set_input_as_handled()
		return
	if _mode == Mode.BANNER and event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		_close_banner()
		return
	match _mode:
		Mode.HOTBAR:
			_input_hotbar(event)
		Mode.ATTACK, Mode.SKILL_TARGET:
			_input_target(event)
		Mode.DASH_CONFIRM:
			_input_dash_confirm(event)


func _close_banner() -> void:
	var was_victory: bool = _combat() != null and _combat().outcome.get("victory", false)
	Game.sim.resolve_combat()
	_teardown_board()
	if not was_victory:
		if not Game.load_slot("auto_pre_combat", "defeat"):
			Game.reset()


func _teardown_board() -> void:
	_mode = Mode.INACTIVE
	_root.hide()
	_board_renderer.clear()
	ObservableBus.emit_domain_event(WIEvents.UI_COMBAT_HIDDEN, {})


func is_resting() -> bool:
	return _mode == Mode.HOTBAR


func abandon_combat() -> void:
	_teardown_board()
	if not Game.load_slot("auto"):
		Game.reset()


func _input_hotbar(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_move_active_or_bump(Vector2i.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_move_active_or_bump(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		_move_active_or_bump(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_move_active_or_bump(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
	elif InputMap.has_action("end_turn") and event.is_action_pressed("end_turn"):
		_activate_bar_slot(_bar_slot_index_of("end_turn"))
		get_viewport().set_input_as_handled()
	elif InputMap.has_action("slot_prev") and event.is_action_pressed("slot_prev"):
		_move_bar_cursor(-1)
		get_viewport().set_input_as_handled()
	elif InputMap.has_action("slot_next") and event.is_action_pressed("slot_next"):
		_move_bar_cursor(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm") and _bar_index >= 0:
		_activate_bar_slot(_bar_index)
		get_viewport().set_input_as_handled()
	else:
		var numbered := _numbered_slot_pressed(event)
		if numbered >= 0:
			_activate_bar_slot(numbered)
			get_viewport().set_input_as_handled()
	_refresh()


func _move_bar_cursor(delta: int) -> void:
	if _bar_slots.is_empty():
		return
	if _bar_index < 0:
		_bar_index = 0
	else:
		_bar_index = (_bar_index + delta + _bar_slots.size()) % _bar_slots.size()
	_info_slot_index = _bar_index


func _move_active_or_bump(dir: Vector2i) -> void:
	var active_id := String(_combat().get_active())
	if not _combat().move_active(dir):
		_board_renderer.bump(active_id, dir)


func _input_target(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		_cancel_targeting()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle") and _targeting.has_valid_target():
		_targeting.cycle(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm") and _targeting.has_valid_target():
		_confirm_targeted_action()
		get_viewport().set_input_as_handled()
	else:
		var numbered := _numbered_slot_pressed(event)
		if numbered >= 0:
			_switch_bar_slot(numbered)
			get_viewport().set_input_as_handled()
	_refresh()


## Executes `_targeting.confirm()`'s returned action -- verbatim body of the
## old `_input_target` confirm branch, extracted (issue #106) so a tap on the
## confirm chip / a re-tap of the already-aimed candidate cell can call it
## too. Caller must already know `_targeting.has_valid_target()` is true.
func _confirm_targeted_action() -> void:
	var action: Dictionary = _targeting.confirm()
	var combat := _combat()
	match String(action["kind"]):
		"attack":
			combat.attack(String(action["target_id"]))
		"line_skill":
			combat.use_skill(String(action["skill_id"]), String(action["direction"]))
		"skill":
			combat.use_skill(String(action["skill_id"]), String(action["target_id"]))
	if _mode in [Mode.ATTACK, Mode.SKILL_TARGET]:
		_mode = Mode.HOTBAR
		_bar_index = -1


func _cancel_targeting() -> void:
	_targeting.cancel()
	_mode = Mode.HOTBAR
	_bar_index = -1


func _input_dash_confirm(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		_cancel_bar_action()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_confirm_bar_action()
		get_viewport().set_input_as_handled()
	else:
		var numbered := _numbered_slot_pressed(event)
		if numbered >= 0:
			_switch_bar_slot(numbered)
			get_viewport().set_input_as_handled()
	_refresh()


func _confirm_bar_action() -> void:
	var slot: Dictionary = _bar_slots[_bar_index] if _bar_index >= 0 and _bar_index < _bar_slots.size() else {}
	_mode = Mode.HOTBAR
	_bar_index = -1
	match String(slot.get("type", "dash")):
		"item":
			Game.sim.combat_use_item(String(slot.get("id", "")))
		_:
			_combat().dash()


func _cancel_bar_action() -> void:
	_mode = Mode.HOTBAR
	_bar_index = -1
