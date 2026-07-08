extends CanvasLayer
## Functional-minimal combat presentation. Renders the WICombat snapshot as
## a grid of squares with HP bars and AP pips, a turn-order strip, a hotbar-
## driven action UI (arrows move the active unit directly -- M5 H2), and a
## prose event feed. HP readouts and damage numbers are player-visible; raw
## stats remain hidden by repo product constraint.
##
## GOTCHA: CanvasLayer has no `modulate`; only child Controls are styled.

## 16px grid recalibration -- see world.gd's CELL doc comment.
##
## The board (tiles/skirt/holders/flashes -- all
## world-space content) renders into `World.combat_board_root()`, a Node2D
## inside the world SubViewport, not this CanvasLayer. Combat UI (hotbar/
## readout/order/feed/banner) stays in this CanvasLayer, native resolution.
##
## Presentation is decomposed into focused components, each owned by a var
## below -- `_board_renderer`/`_view` (board+sprites), `_ai_playback` (the
## paced AI-turn queue), `_targeting`/`_hud` (aim/HUD). This
## file is the mode FSM + `_unhandled_input` dispatch + `_on_domain_event`
## bus hub + lifecycle (`_show_combat`/`_apply_turn_started`/
## `_apply_combat_finished`/`_close_banner`) + composition root (the only
## place the 4 combat commands -- attack/use_skill/dash/end_turn -- plus
## `Game.sim.resolve_combat()` are called); new presentation code goes in the
## matching component, never back into this file. A handful of small
## compat-shim methods below exist only because `tests/test_combat_visuals.gd`
## asserts their literal presence via raw-source substring or has_method --
## see each shim's doc comment for which.

## Cardinal direction tokens for line_damage targeting -- kept here (not just
## on WICombatTargeting, which carries its own duplicate copy) because
## `_skill_flash_cells` (stays screen-side -- VFX flash dispatch, not HUD's
## readout/feed/tutor domain) also needs LINE_DIR_VECTORS.
const LINE_DIR_VECTORS := {
	"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT,
}
const FROST_FLASH := Color(0.5, 0.8, 1.0)
const FLAME_FLASH := Color(1.0, 0.45, 0.15)
const SHIELD_FLASH := Color(0.4, 0.6, 1.0)
const AI_BEAT_SECONDS := 0.5
## A hit dealing at least this much damage screenshakes even when
## the PC is the attacker (a "heavy hit landed"); every hit the PC TAKES shakes
## regardless of size. Calibrated above a normal swing (pc/relc basic ~7-13) so
## only power_strike-class blows and the chieftain's big rolls trigger the
## dealt-damage shake -- routine trades stay calm. Presentation-only threshold.
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
	# TRAP comment warns about. TERRAIN_ADDED is only ever player-cast today
	# (AI never selects icy_floor -- see skill_effects.gd/wi_combat_ai.gd
	# doc comments) but is listed alongside it for symmetry and so a future
	# enemy-cast icy_floor doesn't silently reopen the same desync.
	WIEvents.TERRAIN_ADDED, WIEvents.TERRAIN_EXPIRED,
]

## SKILL_PICK is gone -- the hotbar puts combat skills directly on
## numbered slots (spec sec.3: "the hotbar replaces the MENU/SKILL_PICK
## modes' text lists"), so selecting a skill slot jumps straight to
## SKILL_TARGET instead of opening a skill sub-list first.
## The separate Move mode is gone too:
## HOTBAR is the player's resting turn state: arrows step the active unit
## directly (spending move pool, bump feedback on refusal), number keys /
## E activate slots, and Dash just refills the pool without changing mode.
## DASH_CONFIRM guards against fat-fingering AP away with a stray hotbar_2
## press (Dash used to fire instantly on selection) -- selecting it now
## behaves like an aimed slot: shows its cost/effect in the readout and ARMS
## a confirm gate (Enter executes, Esc cancels back to HOTBAR) instead of
## spending AP immediately. It is deliberately NOT folded into ATTACK/
## SKILL_TARGET's `_targeting`-driven flow — Dash has no target to cycle, so
## `_input_dash_confirm` handles it directly at the composition-root level
## (same "command surface stays on the screen" contract the targeting
## flow follows).
enum Mode { INACTIVE, HOTBAR, ATTACK, SKILL_TARGET, DASH_CONFIRM, WAIT_AI, BANNER }

var _mode: int = Mode.INACTIVE
var _root: Control
## Owns the arena board/sprite region (board_renderer.gd);
## constructed once in `_ready()`. `_view`: read facade over the live
## `WICombat` (combat_view.gd), constructed fresh per encounter in
## `_show_combat()`. `_ai_playback`: the paced AI-turn playback queue
## (combat_playback.gd), constructed once in `_ready()`. `_targeting`:
## the aim/target-filter region (targeting_controller.gd), constructed
## FRESH per combat like `_view` -- NOT a `_ready()`-time singleton, because a
## targeting object bound to a stale `_view` from a previous encounter would
## silently operate on a torn-down `WICombat`. `_hud`: the HUD panels/tutor/
## hotbar-slot-rendering region (combat_hud.gd), constructed once in
## `_ready()`. All five are loosely typed (`Node`/`RefCounted`, never their
## real `class_name`) and built via `load(path).new(...)` rather than a bare
## type: `tests/test_combat_visuals.gd` recompiles a stubbed in-memory copy
## of THIS file under `--script` mode (autoloads unresolved); a hard type
## annotation would force that compile to also resolve the referenced file's
## body, and `board_renderer.gd`/`combat_hud.gd`'s ObservableBus/TestDriver
## touches (direct or, for combat_hud.gd, via this screen's own
## `_emit_slot_info`/`_emit_tutor_rendered`/`_emit_targeting_shown_event`
## wrappers) would fail that compile. See each file's own doc comment.
var _board_renderer: Node
var _view: RefCounted
var _ai_playback: RefCounted
var _targeting: RefCounted
var _hud: RefCounted
## Ordered slot descriptors for the CURRENT player turn (rebuilt fresh by
## `WICombatHud.rebuild_slots` each `_apply_turn_started`); activated by the
## numbered hotbar_N keys / End Turn key via `_activate_bar_slot`. `_bar_index`
## highlights the slot being AIMED (-1 = HOTBAR resting state). Data
## ownership stays on the screen -- `_hud` only ever
## renders from a `_bar_slots` copy handed to it each `refresh()` call.
var _bar_slots: Array = []
var _bar_index := -1
## Which slot's name/costs/description line the readout
## strip shows (`WICombatHud._slot_info_line`). Unlike `_bar_index`, always
## points at a real slot -- reset to 0 (Attack) at turn start, updated on
## every `_activate_bar_slot` (incl. Dash/End Turn, which never aim), and
## stays put across a cancel-back-to-HOTBAR so the strip keeps explaining
## whatever the player just did until they act again.
var _info_slot_index := 0
## The WIMain host, injected downward at spawn by WIMain._spawn_ui_layers
## — the route to world_labels()/world_root() instead of a
## find_child scan. Typed Node, not WIMain: this file must stay compilable as
## the autoload-stubbed in-memory copy tests/test_combat_visuals.gd builds
## under bare --script mode, and a hard WIMain annotation would pull the
## autoload-referencing main.gd into that compile.
var main_ref: Node


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
	#
	# load(...).new(...) rather than a bare WICombatHud/WICombatBoardRenderer/
	# WICombatPlayback type -- see each var's doc comment for why a bare type
	# reference here breaks tests/test_combat_visuals.gd's --script-mode
	# compile.
	_hud = load("res://src/combat/combat_hud.gd").new(_root, main_ref, self)
	_hud.build()
	_board_renderer = load("res://src/combat/board_renderer.gd").new()
	_board_renderer.name = "BoardRenderer"
	add_child(_board_renderer)
	_ai_playback = load("res://src/combat/combat_playback.gd").new(_board_renderer, self)
	ObservableBus.domain_event.connect(_on_domain_event)


func _combat() -> WICombat:
	return Game.sim.combat


func _combat_or_null() -> WICombat:
	if Game == null or Game.sim == null:
		return null
	return Game.sim.combat


func _on_domain_event(type: String, payload: Dictionary) -> void:
	# Tutor-line matching/counting happens HERE, once per arriving event,
	# before the AI-capture vs. live branch below -- see WICombatHud.
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
			# -- it never re-matches against live state (M4 T10 contract).
			(event["payload"]["_ui"] as Dictionary)["tutor"] = tutor
		_ai_playback.enqueue(event)
		if type == WIEvents.COMBATANT_DOWNED:
			_board_renderer.mark_death_visible(String(payload["id"]))
		return
	match type:
		WIEvents.INPUT_DEVICE_CHANGED:
			# Re-render the readout/hint strip on a
			# device swap mid-combat -- `_refresh()` recomputes `hints` fresh
			# from WIInputHints every call, so this just re-triggers it.
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
				_render_tutor_line(tutor)
				_apply_combat_finished(payload)
		WIEvents.COMBATANT_MOVED, WIEvents.AP_CHANGED, WIEvents.COMBATANT_DOWNED, \
		WIEvents.ATTACK_RESOLVED, WIEvents.SKILL_RESOLVED, WIEvents.REACTION_TRIGGERED, \
		WIEvents.DASHED, WIEvents.STATUS_APPLIED, WIEvents.STATUS_EXPIRED, WIEvents.ACTION_REFUSED, \
		WIEvents.TERRAIN_ADDED, WIEvents.TERRAIN_EXPIRED:
			if _mode != Mode.INACTIVE:
				var event := _capture_playback_event(type, payload)
				_play_event_visual(type, event["payload"])
				_push_feed(event["payload"])
				_render_tutor_line(tutor)
				_refresh()
		WIEvents.TURN_ENDED:
			# The PC's own turn_ended never went through
			# AI_PLAYBACK_TYPES (only AI-turn end_turns are queued -- see the
			# capture branch above), so it always reaches here live, during
			# the player's own input. No board state changes on end-of-turn
			# itself (the next combatant's turn_started/AI turn handles that),
			# so this arm exists purely to render an already-decided tutor
			# match (e.g. D2-4's `watch` beat) immediately.
			if _mode != Mode.INACTIVE:
				_render_tutor_line(tutor)
		WIEvents.UI_TARGETING_SHOWN:
			# combat_screen emits this event on itself
			# (see WICombatTargeting.enter/`_emit_targeting_shown_event` below)
			# while the player is aiming, so it always arrives on the live
			# path (never during AI's WAIT_AI turn) -- render immediately,
			# same as the player-turn arms above.
			if _mode != Mode.INACTIVE:
				_render_tutor_line(tutor)


## Shared combat_finished banner text + BANNER-mode transition. Used by both
## the live event path (_on_domain_event) and paced AI playback
## (_apply_playback_event) so the two can't drift out of sync with each other.
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
	_refresh()
	_root.show()
	ObservableBus.emit_domain_event(WIEvents.UI_COMBAT_SHOWN, {})
	# Do NOT call _apply_turn_started here: WICombat.begin() emits combat_started
	# then turn_started synchronously for the same first actor (in that order,
	# by contract) — the turn_started handler drives the first turn instead.
	# Calling both here would double-queue _ai_playback.run_ai_turn.call_
	# deferred() when the first actor is AI-controlled, and the stale second
	# call would fire after that turn ends, hijacking whichever combatant is
	# active by then.


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
	_hud.refresh(_view, bar_active, in_targeting, _mode == Mode.BANNER, targeting_state, _bar_slots, _bar_index, _info_slot_index, _mode == Mode.DASH_CONFIRM, hints)


## Per-combatant board position, visibility, and HP/MP bars/labels, sourced
## from the LIVE sim (via `_view`, the per-combat read facade).
## During paced AI-turn playback the live state is already at the turn's
## final state, so `_refresh()` skips this while `_ai_playback.is_playing()`
## is true — paced dequeue-time rendering applies each combatant's
## historically-captured position/stats instead (see combat_playback.gd's
## `_apply_playback_event` / `_capture_event_ui`), and this runs once more for
## real after the queue drains to guarantee the end state matches the live
## one exactly.
func _refresh_combatants() -> void:
	if _combat_or_null() == null or _view == null:
		return
	for id: String in _view.ids():
		_board_renderer.move_visual(id, _view.cell(id), true)
		# A downed unit stays visible once its down event has been captured,
		# so earlier queued beats can still animate against its historical cell.
		_board_renderer.set_visible(id, _view.alive(id) or _board_renderer.death_visible(id))
		_board_renderer.apply_stats(id, _view.stats(id))


## M6.5 D3 delegator — NOT dead code (D3 review correction): the real
## implementation MOVED to `WICombatPlayback.capture_playback_event`
## (`combat_playback.gd`), and this wrapper has a LIVE production call site:
## `_on_domain_event`'s non-AI (player-turn) event branch calls
## `_capture_playback_event(...)` on every live combat event. Do NOT delete
## as "test-only" in future cleanup. It also lazily constructs `_ai_playback`
## if `_ready()` never ran, which is what lets
## `tests/test_combat_visuals.gd` (out of this task's edit scope) call
## `screen._capture_playback_event(...)` directly on a patched copy of this
## file instantiated via bare `GDScript.new()`/`.new()` without `_ready()`.
## `combat_playback.gd` carries zero bare autoload identifiers, so this
## load()+new() succeeds even under that test's --script-mode
## autoload-stubbed context.
func _capture_playback_event(type: String, payload: Dictionary) -> Dictionary:
	if _ai_playback == null:
		_ai_playback = load("res://src/combat/combat_playback.gd").new(_board_renderer, self)
	return _ai_playback.capture_playback_event(type, payload)


## M6.5 D4 delegators to `WICombatHud`'s feed/tutor methods. `_feed_line_for_
## event` is a REQUIRED live delegator, not a test-only shim: `combat_
## playback.gd`'s `_capture_event_ui` (out of this task's edit scope) calls
## `_screen._feed_line_for_event(...)` on EVERY captured event, real gameplay
## and `tests/test_combat_visuals.gd`'s direct `_capture_playback_event(...)`
## call alike -- it lazily constructs `_hud` if `_ready()` never ran (same
## pattern `_capture_playback_event` above uses for `_ai_playback`; a null
## `_root`/`main_ref` there is harmless since `feed_line_for_event` never
## touches them). `_push_feed`/`_render_tutor_line` are called by both
## `_on_domain_event` and `combat_playback.gd`'s `_apply_playback_event`.
func _feed_line_for_event(type: String, payload: Dictionary) -> String:
	if _hud == null:
		_hud = load("res://src/combat/combat_hud.gd").new(_root, main_ref, self)
	return _hud.feed_line_for_event(type, payload, _combat_or_null())


func _push_feed(payload: Dictionary) -> void:
	_hud.push_feed(payload)


func _render_tutor_line(tutor: Dictionary) -> void:
	_hud.render_tutor_line(tutor)


## The three emit wrappers below exist so `combat_hud.gd`/`targeting_
## controller.gd` never touch the ObservableBus autoload directly (keeps
## both files load()-able under `tests/test_combat_visuals.gd`'s `--script`-
## mode compile -- see `_test_driver_active`'s doc comment for the same
## reasoning D3 established). `_emit_targeting_shown_event` is the QA-visible
## confirmation that targeting opened (H1 review: the numbered hotbar keys
## had no bus-observable effect otherwise -- combat_walkthrough presses
## hotbar_1 and asserts this).
func _emit_slot_info(slot: int, text: String) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_SLOT_INFO_RENDERED, {"slot": slot, "text": text})


func _emit_tutor_rendered(beat_id: String) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_TUTOR_LINE_RENDERED, {"beat": beat_id})


func _emit_targeting_shown_event(mode_text: String, skill_id: String, target_count: int) -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_TARGETING_SHOWN, {
		"mode": mode_text, "skill": skill_id, "targets": target_count,
	})


## M4 T10/M5 E2 render dispatcher, shared by the live event path
## (_on_domain_event) and paced AI playback (_apply_playback_event) -- stays
## on the screen (VFX-flash dispatch, not HUD's readout/feed/tutor domain),
## calling `_board_renderer`'s public animation surface instead of the
## private sprite/chip helpers that live there.
func _play_event_visual(type: String, payload: Dictionary) -> void:
	var ui: Dictionary = payload.get("_ui", {})
	match type:
		WIEvents.ATTACK_RESOLVED:
			var attacker_id := String(payload["attacker"])
			var target_id := String(payload["target"])
			# spell_damage/line_damage casts route through the sim's
			# _resolve_hit with melee=false and reuse ATTACK_RESOLVED, so a
			# ranged cast (frost_bolt/flame_jet) must play the cast/gesture
			# animation, NOT the sword swing (VISUAL-LOG common-sense fix).
			var attack_anim := "slice" if bool(payload.get("melee", true)) else "cast"
			_play_combatant_anim(attacker_id, attack_anim, ui.get("attacker_flip_h", null))
			if bool(payload.get("hit", false)):
				# Combat feel (all no-ops under QA/headless via the
				# renderer's `_juice_enabled` gate). The struck-combatant reaction
				# differs by kind: a sprited combatant plays its "hit" frame AND
				# takes a white impact pulse on the sprite itself (`impact_flash`
				# needs a sprite child, so it stays in this branch); a chip
				# combatant gets the brightness flash. The spark burst + board
				# screenshake are HOISTED out of the branch so they fire for EVERY
				# hit regardless of sprite/chip -- every shipped combatant is
				# sprited, so nesting these in the chip-only `else` made them dead
				# code (EF review I1). `spawn_hit_sparks` reads the enqueue-captured
				# `target_cell` and `shake_board` the captured `damage`/`target_id`,
				# so both stay dequeue-safe under paced AI playback (no live read).
				if _board_renderer.has_sprite(target_id):
					_play_combatant_anim(target_id, "hit", ui.get("target_flip_h", null))
					_board_renderer.impact_flash(target_id)
				else:
					_board_renderer.flash_chip(target_id)
				_board_renderer.spawn_hit_sparks(ui.get("target_cell", []))
				if target_id == "pc" or int(payload.get("damage", 0)) >= HEAVY_HIT_DAMAGE:
					_board_renderer.shake_board(3.0 if target_id == "pc" else 4.0)
		WIEvents.COMBATANT_DOWNED:
			var downed_id := String(payload["id"])
			_board_renderer.mark_death_visible(downed_id)
			if _board_renderer.has_sprite(downed_id):
				_play_combatant_anim(downed_id, "death")
			else:
				_board_renderer.fade_chip(downed_id)
		WIEvents.SKILL_RESOLVED:
			var color: Color = ui.get("flash_color", Color.TRANSPARENT)
			if color.a > 0.0:
				# _cells_from_payload lives on WICombatPlayback --
				# called cross-object since this dispatcher stays screen-side.
				_flash_cells(_ai_playback._cells_from_payload(ui.get("flash_cells", [])), color)
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


## Compatibility shim: the real implementation lives in
## `WICombatBoardRenderer.play_anim`. Kept here, still used by
## `_play_event_visual` just above, and asserted by
## `tests/test_combat_visuals.gd`'s `has_method` check.
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
	# color pick need to widen.
	if not (effect_type in ["spell_damage", "line_damage", "icy_floor"]):
		return Color.TRANSPARENT
	# Only two elements exist today (frost/flame); anything not frost-prefixed
	# defaults to the flame flash. Revisit this binary split when a third
	# element is added. icy_floor is ice-element but doesn't share the
	# "frost_*" id prefix (frost_bolt/frost_touch), so it's checked explicitly.
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


## Compatibility shim: the real implementation lives in
## `WICombatBoardRenderer.flash_cells` (which owns `_board`). Kept here,
## still used by `_play_event_visual` above, and asserted by
## `tests/test_combat_visuals.gd`'s `has_method` check.
func _flash_cells(cells: Array[Vector2i], color: Color) -> void:
	_board_renderer.flash_cells(cells, color)


func _active_combatant() -> Dictionary:
	var combat := _combat()
	return combat.combatants[combat.get_active()]


## Index of the bar slot with the given `type` (there is at most one
## "dash"/"end_turn" slot; used by the dedicated End Turn key). Returns -1
## if no such slot exists on the current bar.
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


## Activates the bar slot at `index` (reached via the numbered hotbar_N keys
## or the dedicated End Turn key), one match arm per slot type. Unaffordable
## slots refuse silently (no mode change), same convention as the pre-hotbar
## menu/skill-pick confirm handlers. Targeting slots set the mode FSM and
## record `_bar_index` so the aimed slot stays highlighted for the duration
## of targeting, then hand off to `_targeting.enter(...)` (M6.5 D4); Dash is
## a pure pool refill (M5 H2) -- no mode change, arrows spend the new pool
## directly from the HOTBAR resting state.
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


func _apply_turn_started(id: String) -> void:
	var combat := _combat()
	var c: Dictionary = combat.combatants[id]
	if String(c["side"]) == "enemy" or String(c["ai"]) != "":
		_mode = Mode.WAIT_AI
		_refresh()
		# AI-turn execution + the paced playback queue live on
		# WICombatPlayback -- this file keeps only the mode-FSM transition.
		_ai_playback.run_ai_turn.call_deferred()
	else:
		_mode = Mode.HOTBAR
		# No QA script drives the hotbar by fixed slot index (combat_autoplay
		# calls WICombatAI.take_turn directly, bypassing this UI entirely), so
		# the bar's order is free to pick for readability rather than being
		# pinned by test coupling.
		# Threads the PC's shared loadout in (see rebuild_slots' own doc comment).
		_bar_slots = _hud.rebuild_slots(_view, id, Game.sim.hotbar_loadout)
		_bar_index = -1
		_info_slot_index = 0  # Attack, per the "slot 1's info at turn start" playtest fix
		ObservableBus.emit_domain_event(WIEvents.UI_HOTBAR_RENDERED, {"slots": _bar_slots.size()})
		_refresh()


## `WICombatPlayback` calls these instead of touching `TestDriver`/
## `ObservableBus` directly, keeping it free of bare autoload identifiers
## (see that file's doc comment).
func _test_driver_active() -> bool:
	return TestDriver != null and TestDriver.active()


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
		## _close_banner can trigger scene reload on defeat, so mark input first
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
	_mode = Mode.INACTIVE
	_root.hide()
	# Hide the board and hand the camera back to the field --
	# the inverse of `_board_renderer.build()`'s show + enter_combat_camera.
	# `clear()` internally guards is_instance_valid, since a defeat below may
	# already have torn the whole World down via Game.reset()/load_slot before
	# this runs on some paths.
	_board_renderer.clear()
	ObservableBus.emit_domain_event(WIEvents.UI_COMBAT_HIDDEN, {})
	if not was_victory:
		# Defeat returns the player to their last autosave (sleep/quest/map
		# beats), not to a fresh game. Reset only when no autosave exists yet.
		if not Game.load_slot("auto"):
			Game.reset()


## In the HOTBAR resting state the
## arrows step the active unit DIRECTLY (spending move pool; a refused step
## — empty pool, blocked/occupied/off-grid cell — bumps the sprite as
## feedback, exactly the old Move mode's behavior). Slots are activated by
## the numbered hotbar_N keys and the dedicated End Turn key only (spec
## sec.3: "Number keys 1-9 activate slots", "no bar arrow-navigation") —
## there is no Enter-confirms-a-highlight flow anymore. InputMap.has_action
## guards kept for the slot actions so a stripped-down input map degrades to
## inert instead of erroring.
##
## Number keys have no pad equivalent, so
## `slot_prev`/`slot_next` (LB/RB) move a visible cursor over `_bar_index`
## (reusing the same field the ATTACK/SKILL_TARGET aim-highlight already
## drives -- HOTBAR's resting `_bar_index == -1` just means "nothing
## highlighted yet", so parking the cursor there while still in HOTBAR mode
## is a safe, additive use of the same var) and `confirm` (A on pad, Enter on
## keyboard) activates whatever slot is currently highlighted, exactly as a
## numbered press would. Keyboard-only play never presses slot_prev/next/
## confirm from this mode (Enter has no prior HOTBAR-mode meaning), so this
## is purely additive.
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


## Controller support (S1): moves the HOTBAR-resting cursor by `delta` slots,
## wrapping. A first press from the resting `-1` state lands on slot 0
## (Attack) rather than wrapping past the end, matching how a fresh look at
## the bar would start left-to-right. Mirrors `_activate_bar_slot`'s own
## convention of keeping `_info_slot_index` in lockstep so the readout strip
## explains whatever slot the cursor currently sits on.
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


## M6.5 D4: the mode-FSM/input-dispatch shell of the old `_input_target` --
## Tab/Enter/Esc map to `_targeting`'s `cycle()`/`confirm()`/`cancel()`, and
## `confirm()`'s returned action is executed HERE (command surface stays at
## the composition root, per the plan): `combat.attack()`/`combat.use_skill()`
## are the only two command calls this function issues.
func _input_target(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		_targeting.cancel()
		_mode = Mode.HOTBAR
		_bar_index = -1
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle") and _targeting.has_valid_target():
		_targeting.cycle(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm") and _targeting.has_valid_target():
		var action: Dictionary = _targeting.confirm()
		var combat := _combat()
		match String(action["kind"]):
			"attack":
				combat.attack(String(action["target_id"]))
			"line_skill":
				combat.use_skill(String(action["skill_id"]), String(action["direction"]))
			"skill":
				combat.use_skill(String(action["skill_id"]), String(action["target_id"]))
		# The sim call can synchronously advance the turn or finish combat
		# (dead-active auto-advance); _on_domain_event may already have moved
		# _mode to WAIT_AI/BANNER — only fall back to HOTBAR if it didn't.
		if _mode in [Mode.ATTACK, Mode.SKILL_TARGET]:
			_mode = Mode.HOTBAR
			_bar_index = -1
		get_viewport().set_input_as_handled()
	_refresh()


## Dash's confirm gate. No target to cycle (Tab is inert
## here, unlike ATTACK/SKILL_TARGET) — Enter spends the AP via `combat.dash()`
## (the only new command-surface call this mode issues; still one of the 4
## sanctioned combat commands), Esc cancels back to HOTBAR with no sim call
## at all (selecting Dash costs nothing until confirmed).
func _input_dash_confirm(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		_mode = Mode.HOTBAR
		_bar_index = -1
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_mode = Mode.HOTBAR
		_bar_index = -1
		get_viewport().set_input_as_handled()
		_combat().dash()
	_refresh()
