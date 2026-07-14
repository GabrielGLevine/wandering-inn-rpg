extends CanvasLayer
## Functional-minimal combat presentation. Renders the WICombat snapshot as
## a grid of squares with HP bars and AP pips, a turn-order strip, a hotbar-
## driven action UI (arrows move the active unit directly), and a
## prose event feed. HP readouts and damage numbers are player-visible; raw
## stats remain hidden by repo product constraint.
##
## GOTCHA: CanvasLayer has no `modulate`; only child Controls are styled.

## 16px grid recalibration -- see world.gd's CELL doc comment.
## Own copy (issue #57's `handle_board_click`, same convention board_renderer.gd's
## own `CELL` const already follows -- this codebase duplicates the literal
## per-file rather than cross-referencing another file's const).
const CELL := 16
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
	# TRAP comment warns about. TERRAIN_ADDED fires mid-AI-turn too since
	# GH#90: combat_ai.gd's area_skill arm casts icy_floor for real
	# (goblin_shaman's live kit; `shaman_zone_loop` = the canonical), so
	# this entry is load-bearing, not symmetry.
	WIEvents.TERRAIN_ADDED, WIEvents.TERRAIN_EXPIRED,
	# Issue #82's WINDUP SIM SPEC: WINDUP_DECLARED fires mid-AI-turn (today's
	# only holder, `slam`, is enemy-only) -- exactly the class this const
	# exists to catch. Without this entry it would fall through to the live
	# `_on_domain_event` arm and render against END-of-turn state instead of
	# the moment it actually declared.
	WIEvents.WINDUP_DECLARED,
	# GH#90 [burning]: STATUS_TICKED fires at round rollover, inside
	# `_advance_turn` -- MID an AI turn whenever an AI combatant's end_turn
	# wraps the order (the TERRAIN_EXPIRED class exactly). Also reaches the
	# live arm when the PLAYER's own end_turn wraps the order instead.
	WIEvents.STATUS_TICKED,
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
## flow follows). Issue #92 R2: DASH_CONFIRM is now Dash's mode AND a
## consumable item-use's mode -- both are niladic (no target to cycle), so
## the SAME gate/enum value covers either; `_confirm_bar_action` branches on
## which one is actually armed. The enum's name stays historical (Dash was
## first) rather than a repo-wide rename for a two-command generalization.
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
## Re-armed only on GAME_RESET (fresh run deserves the hint again), same
## precedent -- see `_reset_first_combat_hint`.
static var _first_combat_hint_shown := false
static var _combat_hint_reset_hooked := false


static func _reset_first_combat_hint(type: String, _payload: Dictionary) -> void:
	if type == WIEvents.GAME_RESET:
		_first_combat_hint_shown = false


## Issue #77: settings_panel.gd's "Replay Hints" action calls this directly
## (via `WISettings.replay_hints()`'s dynamic `load(...).call("reset_hints")`
## -- see that file's doc comment), mirroring message_layer.gd's identical
## `reset_hints()` for the SAME reason: re-arm mid-sitting without a full
## GAME_RESET. Static, script-bound -- callable with zero live CombatScreen
## instance in the tree.
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
	#
	# load(...).new(...) rather than a bare WICombatHud/WICombatBoardRenderer/
	# WICombatPlayback type -- see each var's doc comment for why a bare type
	# reference here breaks tests/test_combat_visuals.gd's --script-mode
	# compile.
	_hud = load("res://src/combat/combat_hud.gd").new(_root, main_ref, self)
	_hud.build()
	# Issue #57: a hotbar slot CLICK routes through the exact same
	# `_activate_bar_slot` dispatch the numbered hotbar_N keys use.
	_hud.hotbar_node().slot_clicked.connect(_on_hotbar_slot_clicked)
	# Issue #106: the tap-confirm chip (a small always-off-board HUD widget,
	# shown whenever DASH_CONFIRM is armed or a target is actively aimed) --
	# see `_on_confirm_chip_tapped`'s own doc comment.
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
			# -- it never re-matches against live state (the playback contract).
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
	_announce_allies()
	_announce_first_combat_hint()
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


## Pushes ONE feed line naming whichever ally(s) `start_combat`'s
## `ally_requires` gate actually fielded this fight, called right after
## `_view` is built (so the line is already in the feed by this same
## `_show_combat()` call's own `_refresh()`). CONSTRAINTS: no new sim event
## -- `combatants.json` has no distinct "ally" side (a fielded ally rides
## the SAME "player" side as the PC, see that file's own records), so the
## fielded-ally set derives from `_view`'s existing per-combatant data
## (`combatant(id)["side"]`), filtering out "pc" itself. Generic for any
## current or future gated ally -- never per-character-name branching.
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


## Plain English "and"-join for a name list of any size (1: "X", 2: "X and
## Y", 3+: "X, Y, and Z") -- kept local (one call site) rather than adding a
## shared formatter dependency for a single feed line.
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
	# Issue #87 (skip affordance): mirrors `_unhandled_input`'s own
	# `_mode == Mode.WAIT_AI and _ai_playback.is_playing()` skip-consuming
	# gate exactly, so the hint is on screen precisely when (and only when)
	# confirm/cancel would actually do something.
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
		# Issue #75 item 1: aim preview tracks the SAME in_targeting gate the
		# readout/hotbar already use -- clears on every other mode (cancel/
		# confirm/mode-exit all route through this same _refresh() call).
		_board_renderer.render_aim_preview(_targeting.aim_preview())
	else:
		_board_renderer.clear_aim_preview()
	_hud.refresh(_view, bar_active, in_targeting, _mode == Mode.BANNER, targeting_state, _bar_slots, _bar_index, _info_slot_index, _mode == Mode.DASH_CONFIRM, hints, ai_skip_hint)


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
## `combat_playback.gd` carries zero bare autoload identifiers, so this
## load()+new() succeeds even under that test's --script-mode
## autoload-stubbed context.
func _capture_playback_event(type: String, payload: Dictionary) -> Dictionary:
	if _ai_playback == null:
		_ai_playback = load("res://src/combat/combat_playback.gd").new(_board_renderer, self)
	return _ai_playback.capture_playback_event(type, payload)


## Delegators to `WICombatHud`'s feed/tutor methods. `_feed_line_for_
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
	# Issue #75 item 5b: `_view` threads the per-encounter A/B/C dedup
	# (`WICombatView.display_name`) into the feed, so a duplicate-name
	# roster reads disambiguated there too, not just the turn strip/readout.
	return _hud.feed_line_for_event(type, payload, _combat_or_null(), _view)


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


## Render dispatcher, shared by the live event path
## (_on_domain_event) and paced AI playback (_apply_playback_event) -- stays
## on the screen (VFX-flash dispatch, not HUD's readout/feed/tutor domain),
## calling `_board_renderer`'s public animation surface instead of the
## private sprite/chip helpers that live there.
func _play_event_visual(type: String, payload: Dictionary) -> void:
	var ui: Dictionary = payload.get("_ui", {})
	match type:
		WIEvents.AP_CHANGED:
			# Issue #75 item 3: AP_CHANGED fires first for EVERY combat
			# command (attack/dash/spend_skill_costs) -- reset the
			# projectile-tint tracker at the start of every action so a
			# plain ranged Attack (no preceding SKILL_RESOLVED) never
			# inherits a PREVIOUS skill's leftover element color.
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
				_board_renderer.spawn_hit_sparks(target_cell)
				# Issue #75 item 2: the at-the-action damage read (the corner
				# feed prose stays -- that's the log). A LIVE side read is
				# safe even under paced AI playback: this dispatcher only
				# ever runs while combat is live, and side never changes
				# over a fight (only hp/position move) -- see WICombat._init's
				# own doc comment (a combatant's side is fixed at roster
				# build). Color reuses the SAME ALLY_HP_COLOR/ENEMY_HP_COLOR
				# hue the struck combatant's own HP bar already shows.
				var combat_ref := _combat_or_null()
				if combat_ref != null and combat_ref.combatants.has(target_id):
					_board_renderer.spawn_damage_number(target_cell, int(payload.get("damage", 0)), String(combat_ref.combatants[target_id].get("side", "")))
				if target_id == "pc" or int(payload.get("damage", 0)) >= HEAVY_HIT_DAMAGE:
					_board_renderer.shake_board(3.0 if target_id == "pc" else 4.0)
			else:
				# Issue #75 item 2: distinct miss feedback at the target
				# (the feed already prints "X misses Y." -- this is the
				# at-the-action read).
				_board_renderer.spawn_miss_indicator(target_cell)
		WIEvents.COMBATANT_DOWNED:
			var downed_id := String(payload["id"])
			_board_renderer.mark_death_visible(downed_id)
			if _board_renderer.has_sprite(downed_id):
				_play_combatant_anim(downed_id, "death")
			else:
				_board_renderer.fade_chip(downed_id)
			# F3 (issue #82): a downed windup-CASTER's declare never resolves,
			# so no SKILL_RESOLVED will ever clear its dangersense overlay --
			# the capture stage stashed the parked cells (`_ui.windup_cells`,
			# absent for every ordinary down; both the live path and paced
			# playback route payloads through that capture). This arm covers
			# LIVE and paced renders; the skip path is covered by
			# `combat_playback.gd`'s pre-match unconditional clear (redundant
			# double-clear on the paced path is a no-op).
			var downed_windup_cells: Array = ui.get("windup_cells", [])
			if not downed_windup_cells.is_empty():
				_board_renderer.expire_terrain("windup_danger", _ai_playback._cells_from_payload(downed_windup_cells))
		WIEvents.STATUS_APPLIED:
			# The combat twin of the field's sneak_visual translucency:
			# without this, an invisible combatant renders fully opaque and
			# the whole read lives in feed text only (the "logically correct
			# but never visible" class CLAUDE.md flags). Presentation keys on
			# the status id -- per-status visuals are presentation data, same
			# as `slowed`'s ice-cell paint. Issue #75 item 4: any OTHER
			# status_id routes to the DATA-DRIVEN pip map instead
			# (board_renderer.gd's STATUS_PIP_COLORS) -- a future status
			# entry added there gets a pip with zero new dispatch code here.
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
			# GH#90 [burning]'s at-the-action damage read -- the SAME
			# spawn_damage_number surface ATTACK_RESOLVED uses (a tick that
			# only ever appeared in feed prose would be the "logically
			# correct but never visible" class). Cell + side both come from
			# the enqueue-captured `_ui` block (combat_playback.gd's
			# STATUS_TICKED capture arm), dequeue-safe under paced playback.
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
				# _cells_from_payload lives on WICombatPlayback --
				# called cross-object since this dispatcher stays screen-side.
				_flash_cells(_ai_playback._cells_from_payload(ui.get("flash_cells", [])), color)
			# Issue #82: a windup RESOLUTION (SKILL_RESOLVED for a
			# `windup_rounds`-carrying skill) clears the dangersense overlay
			# its own WINDUP_DECLARED drew. LIVE-PATH LOAD-BEARING, not just a
			# paced-path redundancy: the resolution fires from the caster's
			# `_start_turn`, which runs synchronously inside whoever ended the
			# PREVIOUS turn -- when that was the PLAYER's own end_turn, the
			# event arrives here live, never passing through combat_playback's
			# pre-match clear at all. Static skills-catalog lookup (never
			# mutates mid-fight), so this is dequeue-safe under paced playback
			# too, where it runs redundantly (expire_terrain no-ops).
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
	# color pick need to widen. blast_damage (GH#71) shares that same "cells"
	# shape too (skill_effects.gd's `_resolve_blast_damage` emits it verbatim
	# from `_radius_area`), so it rides the identical branch.
	if not (effect_type in ["spell_damage", "line_damage", "icy_floor", "blast_damage"]):
		return Color.TRANSPARENT
	# Only two elements exist today (frost/flame); anything not frost-prefixed
	# defaults to the flame flash. Revisit this binary split when a third
	# element is added. icy_floor is ice-element but doesn't share the
	# "frost_*" id prefix (frost_bolt/frost_touch), so it's checked explicitly.
	# blast_damage's shipped skill (flame_pillar) is fire-element and DOES
	# match the flame prefix convention already ("flame_"), so it needs no
	# equivalent explicit carve-out -- falls through to FLAME_FLASH below.
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


## Presentation-only Chebyshev distance between two captured `[x,y]` cell
## arrays (issue #75 item 3's lunge-vs-projectile gate) -- pure geometry (the
## same maxi(|dx|,|dy|) shape `WICombat.chebyshev`/`is_adjacent` already
## compute off real combatant ids), not a duplicated game-rule derivation.
## Reads off the enqueue-time CAPTURED cells (`ui.attacker_cell`/
## `ui.target_cell`), never a live combat re-read, so it stays dequeue-safe
## under paced AI playback. Returns a large sentinel for a malformed/missing
## cell so the caller falls through to the projectile branch, which
## board_renderer.gd's own size<2 guards no-op either way.
func _cells_chebyshev(a: Array, b: Array) -> int:
	if a.size() < 2 or b.size() < 2:
		return 999
	return maxi(absi(int(a[0]) - int(b[0])), absi(int(a[1]) - int(b[1])))


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
## of targeting, then hand off to `_targeting.enter(...)`; Dash is
## a pure pool refill -- no mode change, arrows spend the new pool
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
		"item":
			# Issue #92 R2: a consumable is ALWAYS self-target with no
			# candidate to cycle -- Dash's own no-target confirm gate
			# (Mode.DASH_CONFIRM, generalized: see `_confirm_bar_action`/
			# `_cancel_bar_action`'s own doc comments) fits it exactly,
			# rather than wiring a whole new targeting mode for a cast that
			# never has a target to aim.
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


## Hotbar slot CLICK (issue #57): the SAME `_activate_bar_slot` dispatch a
## numbered hotbar_N key uses, gated the same way `_input_hotbar` gates its
## own numbered-key branch -- only live in the HOTBAR resting state (a click
## on a rendered-but-inactive bar during ATTACK/SKILL_TARGET/DASH_CONFIRM is
## a no-op, matching "Dash/aim confirm gates unchanged").
## Read-only accessor (issue #57): passthrough to `_hud`'s own `hotbar_node()`
## -- `qa/test_driver.gd`'s `click_slot` step looks up `CombatScreen`/
## `FieldHotbar` by the SAME method name on whichever is currently live, so
## this file needs its own copy of the accessor, not just combat_hud.gd's.
func hotbar_node() -> WIHotbar:
	return _hud.hotbar_node()


## Issue #62 Lane U item 7 (playtest: clicking slot B while slot A was
## aim-armed no-op'd until Esc): now live during ATTACK/SKILL_TARGET/
## DASH_CONFIRM too, not just resting HOTBAR -- a click in one of those
## modes routes through `_switch_bar_slot` (same cancel-then-activate
## motion Esc-then-click used to require), while a resting-HOTBAR click
## keeps the plain `_activate_bar_slot` path unchanged.
func _on_hotbar_slot_clicked(index: int) -> void:
	if _mode != Mode.HOTBAR and _mode != Mode.ATTACK and _mode != Mode.SKILL_TARGET and _mode != Mode.DASH_CONFIRM:
		return
	# Mouse-audit finding: the pause menu may be open ON TOP of a resting
	# HOTBAR turn (`is_resting()`'s own doc comment) -- `_mode` alone can't
	# tell "paused" apart from "actively resting", so check main_ref's
	# pause_open() the same way `_movement_gated()` checks it in world.gd.
	if main_ref != null and main_ref.pause_open():
		return
	if _mode == Mode.HOTBAR:
		_activate_bar_slot(index)
	else:
		_switch_bar_slot(index)
	_refresh()


## Shared cancel-then-activate motion for a slot press (mouse click or
## numbered key) that arrives while ATTACK/SKILL_TARGET/DASH_CONFIRM is
## already armed -- issue #62 Lane U item 7. Tears down the current aim via
## the EXACT SAME path Esc uses (`_targeting.cancel()` only for the two
## targeting modes; DASH_CONFIRM has no targeting object to cancel), resets
## the mode FSM back to HOTBAR, then activates the newly pressed slot via
## the ordinary `_activate_bar_slot` -- one motion, no new activation logic.
## An unaffordable new slot leaves the screen sitting in HOTBAR (the aim was
## already torn down, `_activate_bar_slot` itself no-ops on unaffordable),
## matching the existing "unaffordable slots refuse silently" convention.
func _switch_bar_slot(index: int) -> void:
	if _mode == Mode.ATTACK or _mode == Mode.SKILL_TARGET:
		_targeting.cancel()
	_mode = Mode.HOTBAR
	_bar_index = -1
	_activate_bar_slot(index)


## Board tap dispatch (issue #57's click-to-select-target, widened by issue
## #106 for full combat touch). `world_pos` is world/pixel space (Main.gd's
## `_gui_input` already ran it through `screen_to_world` -- the arena renders
## into the SAME SubViewport/camera as the field, so the identical transform
## applies). Per-mode:
## - HOTBAR: `_tap_move` -- an orthogonally-adjacent-cell tap is the arrow-key
##   move equivalent (issue #106 item 1's "tap-a-cell to move"); anything else
##   is a silent no-op (HOTBAR is the resting state, nothing to cancel).
## - ATTACK/SKILL_TARGET: a tap on a currently-selectable candidate cell
##   re-points the aim (`select_at_cell`, unchanged since #57 -- movement
##   stays keys/taps-only, a tap here never confirms by itself); a tap that
##   MISSES every candidate is "elsewhere" -- cancels exactly like Esc
##   (`_cancel_targeting`). Re-tapping the SAME already-aimed candidate is
##   just another `select_at_cell` hit (index unchanged, `_refresh()` still
##   runs) -- the actual "confirm" gesture is the confirm chip
##   (`combat_hud.gd`'s tappable widget, shown once `has_valid_target()`),
##   not a second tap on the board -- see that file's doc comment for why the
##   confirm affordance had to move off the board entirely (the readout/feed
##   HUD panels are click-transparent and visually overlap the board's lower
##   rows, so a board-space "tap the ring to confirm" gesture would silently
##   swallow taps on whichever candidate cells happen to sit behind that
##   chrome).
## - DASH_CONFIRM: no board cell has any meaning (Dash has no target) -- ANY
##   board tap while armed is "elsewhere" (`_cancel_bar_action`); the confirm chip
##   is the only way to confirm.
## - WAIT_AI/BANNER/INACTIVE: unchanged no-op.
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


## Issue #106 item 1: tap an orthogonally-adjacent cell to the active
## combatant = the arrow-key move equivalent for that direction -- calls the
## EXACT SAME `_move_active_or_bump` `_input_hotbar`'s arrow branches call,
## so a tap produces a byte-identical COMBATANT_MOVED/AP_CHANGED/bump stream
## to the keyboard press it mirrors. Diagonal-adjacent cells (both dx and dy
## nonzero) and any non-adjacent cell are a silent no-op: combat movement has
## no diagonal (`move_active` only accepts the 4 cardinal `Vector2i`
## directions, unlike world.gd's field click-to-walk, which BFS-paths and is
## cardinal-only for a different reason -- see that file's own doc comment);
## a far cell within the move pool deliberately does NOT auto-path here
## (the plan's own "simplest honest mapping" ruling -- adjacent-tap only,
## not a second pathing system layered on top of the sim's per-step economy).
func _tap_move(cell: Vector2i) -> void:
	var active_cell: Vector2i = _combat().combatants[_combat().get_active()]["cell"]
	var delta := cell - active_cell
	if delta != Vector2i.UP and delta != Vector2i.DOWN and delta != Vector2i.LEFT and delta != Vector2i.RIGHT:
		return
	_move_active_or_bump(delta)


## Issue #106: the tap-confirm chip (`combat_hud.gd`'s small always-off-board
## widget) -- routes through the EXACT SAME helpers Enter calls
## (`_confirm_bar_action`/`_confirm_targeted_action`), guaranteeing event
## parity between a tap and a keypress. The chip is only ever VISIBLE during
## DASH_CONFIRM or a targeting mode with a valid target (`combat_hud.gd`'s own
## `_confirm_armed` gate, mirrored here defensively) -- and `is_resting()`
## (pause_menu.gd's own open-gate) only allows pause during HOTBAR, so the
## chip can structurally never be visible while paused; the `pause_open()`
## check below is defensive parity with `_on_hotbar_slot_clicked`'s identical
## check, not a reachable path today.
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


## Read-only accessor (issue #106, the `click_slot`/`click_pause_row` idiom):
## passthrough to `_hud`'s own `confirm_chip_rect()` for `qa/test_driver.gd`'s
## `click_confirm_chip` step -- never a hardcoded pixel offset.
func confirm_chip_rect() -> Rect2:
	return _hud.confirm_chip_rect()


func _apply_turn_started(id: String) -> void:
	var combat := _combat()
	# Issue #75 item 5a: the ONE call site both the live path
	# (_on_domain_event's TURN_STARTED arm) and paced AI playback
	# (combat_playback.gd's TURN_STARTED dequeue arm) funnel through, so a
	# single call here moves the marker correctly on both paths.
	_board_renderer.set_active_marker(id)
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


## `WICombatPlayback` calls these instead of touching `TestDriver`/
## `ObservableBus` directly, keeping it free of bare autoload identifiers
## (see that file's doc comment).
func _test_driver_active() -> bool:
	return TestDriver != null and TestDriver.active()


## Issue #87 (Combat speed setting): `AI_BEAT_SECONDS` scaled by the player's
## WISettings combat-speed pick (Normal/Fast/Instant) -- reached through this
## wrapper, not a bare `WISettings` reference in combat_playback.gd itself,
## for the SAME "stay free of bare autoload identifiers" reason
## `_test_driver_active()` above exists (see that file's own doc comment).
## `WISettings != null` guards the same autoload-stubbed --script-mode
## compile context `_test_driver_active()`'s `TestDriver != null` guards --
## never false during a real game boot.
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
	_teardown_board()
	if not was_victory:
		# Issue #88 (gap-2): defeat returns the player to the PRE-COMBAT
		# snapshot (game.gd writes "auto_pre_combat" the instant THIS fight
		# began, COMBAT_STARTED), not the general "auto" checkpoint -- makes
		# "the fight undone" (sleep_veil.gd's defeat copy) literally true
		# instead of rewinding to whatever unrelated map-change/sleep/etc.
		# last hit "auto". Reset only when no pre-combat snapshot exists,
		# which cannot happen on any real defeat (a fight can only resolve
		# after start_combat fired, which always writes this slot first) --
		# the no-snapshot Game.reset() fallback is UNCHANGED (its own GDI
		# cold open already orients a true from-zero restart; see that
		# function's doc comment for why this near-impossible edge isn't
		# also wired).
		if not Game.load_slot("auto_pre_combat", "defeat"):
			Game.reset()


## Hides the board and hands the camera back to the field --
## the inverse of `_board_renderer.build()`'s show + enter_combat_camera.
## `clear()` internally guards is_instance_valid, since a defeat may
## already have torn the whole World down via Game.reset()/load_slot before
## this runs on some paths.
func _teardown_board() -> void:
	_mode = Mode.INACTIVE
	_root.hide()
	_board_renderer.clear()
	ObservableBus.emit_domain_event(WIEvents.UI_COMBAT_HIDDEN, {})


## True in the HOTBAR resting state (the player's own turn, no targeting/
## dash/banner sub-mode in flight) -- the only combat moment the pause menu
## may open from (pause_menu.gd's `_can_open`). Esc is unbound in HOTBAR
## mode, so the un-consumed press reaches the pause layer cleanly.
func is_resting() -> bool:
	return _mode == Mode.HOTBAR


## The pause menu's Abandon verb: tear the fight's UI down WITHOUT resolving
## the combat, then return to the last autosave -- byte-identical recovery
## path to the defeat branch of `_close_banner` (load `auto`, reset only if
## no autosave exists). No `resolve_combat()`: the loaded save replaces the
## whole sim, so resolving the doomed fight first would only fire spurious
## outcome events into the log.
func abandon_combat() -> void:
	_teardown_board()
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


## The mode-FSM/input-dispatch shell of the old `_input_target` --
## Tab/Enter/Esc map to `_targeting`'s `cycle()`/`confirm()`/`cancel()`, and
## `confirm()`'s returned action is executed HERE (command surface stays at
## the composition root, per the plan): `combat.attack()`/`combat.use_skill()`
## are the only two command calls this function issues.
## Issue #106: the confirm/cancel BODIES are extracted to
## `_confirm_targeted_action`/`_cancel_targeting` so `handle_board_click`'s
## tap-confirm/tap-cancel legs (a candidate re-tap and a miss-tap,
## respectively) and the confirm-chip tap (`_on_confirm_chip_tapped`) call the
## EXACT SAME code Enter/Esc do here -- one implementation, never a parallel
## one, so a tap and a keypress produce a byte-identical event stream (the
## #84 event-parity discipline this whole file already follows).
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
		# Issue #62 Lane U item 7, keyboard/pad half: a numbered hotbar_N
		# press mid-aim used to fall through this match unhandled (no case
		# existed for it) -- number keys and mouse clicks now have parity,
		# both route a mid-aim slot press through `_switch_bar_slot`.
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
	# The sim call can synchronously advance the turn or finish combat
	# (dead-active auto-advance); _on_domain_event may already have moved
	# _mode to WAIT_AI/BANNER — only fall back to HOTBAR if it didn't.
	if _mode in [Mode.ATTACK, Mode.SKILL_TARGET]:
		_mode = Mode.HOTBAR
		_bar_index = -1


## Verbatim body of the old `_input_target` cancel branch, extracted (issue
## #106) so a board tap that misses every candidate cell (`handle_board_click`
## -- "tap elsewhere" per the plan) cancels through the exact same path Esc
## does.
func _cancel_targeting() -> void:
	_targeting.cancel()
	_mode = Mode.HOTBAR
	_bar_index = -1


## DASH_CONFIRM's no-target confirm gate -- Dash's own original purpose,
## widened (issue #92 R2) to also arm a consumable's item-use confirm (the
## SAME mode: an item, like Dash, has no candidate to cycle -- Tab is inert
## here, unlike ATTACK/SKILL_TARGET). Enter fires the armed slot's command
## via `_confirm_bar_action` (`combat.dash()` or `Game.sim.combat_use_item`,
## branching on `_bar_slots[_bar_index]`'s own "type"), Esc cancels back to
## HOTBAR with no sim call at all (arming either costs nothing until
## confirmed). Issue #106: bodies extracted to `_confirm_bar_action`/
## `_cancel_bar_action`, same reasoning as `_input_target`'s own doc comment
## above (DASH_CONFIRM has no board target at all, so EVERY board tap while
## armed is "elsewhere" -- `handle_board_click` routes it straight to
## `_cancel_bar_action`, the confirm chip to `_confirm_bar_action`).
func _input_dash_confirm(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		_cancel_bar_action()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_confirm_bar_action()
		get_viewport().set_input_as_handled()
	else:
		# Issue #62 Lane U item 7, keyboard/pad parity -- see `_input_target`'s
		# identical else-arm doc comment; DASH_CONFIRM has no targeting
		# object to cancel, `_switch_bar_slot` already skips that call for it.
		var numbered := _numbered_slot_pressed(event)
		if numbered >= 0:
			_switch_bar_slot(numbered)
			get_viewport().set_input_as_handled()
	_refresh()


## Issue #92 R2: generalized from a Dash-only body to branch on the armed
## slot's own "type" -- Dash and an item-use are the two (today, only two)
## commands DASH_CONFIRM ever arms, both niladic (no target to thread
## through). `_bar_index` still points at the armed slot exactly as it did
## before this widening.
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
