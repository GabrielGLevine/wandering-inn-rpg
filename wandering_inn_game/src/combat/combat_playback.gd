class_name WICombatPlayback
extends RefCounted
## The paced AI-turn playback queue, extracted from combat_screen.gd -- enqueue-time event capture, the beat-paced drain loop,
## dequeue-time apply/highlight, and the confirm/cancel skip gate. Constructed
## once by `combat_screen.gd._ready()` (alongside `_board_renderer`):
## `_ai_playback = load("res://src/combat/combat_playback.gd").new(_board_renderer, self)`.
##
## T10 INVARIANTS (LOAD-BEARING, must survive verbatim -- see the D3 task
## report's hand-trace): every render input a beat needs is captured at
## ENQUEUE time (`capture_playback_event`, called from the screen's
## `_on_domain_event` while `is_ai_turn_active()` is true) by reading combat
## state THEN, never at dequeue; `drain()`'s dequeue path (`_apply_playback_
## event`/`_apply_captured_stats`/`_apply_combatant_moved`) only ever reads
## the captured `_ui` block already stashed on the event, never live combat
## state; `combat_screen.gd._refresh()` gates its live per-combatant refresh
## on `is_playing()` (was the bare `_playing` var, now owned here); and
## `beat_delay()` returns 0.0 whenever `TestDriver.active()` or headless, so
## QA (windowed included) can never observe real pacing.
##
## `renderer`/`screen` are both LOOSELY typed (`Node`, not `WICombatBoardRenderer`/
## the screen's own class) -- same reason `combat_screen.gd`'s own `_board_
## renderer`/`_view` vars are loosely typed (see that file's doc comments):
## `tests/test_combat_visuals.gd` (out of this task's edit scope) recompiles a
## stubbed in-memory copy of combat_screen.gd under bare `--script` mode,
## where autoload identifiers (ObservableBus/Game/TestDriver) don't resolve.
## A hard `WICombatBoardRenderer` type reference here would force that
## script's compile to also resolve board_renderer.gd's body (which DOES
## reference those autoloads directly) -- confirmed empirically the same way
## D2 confirmed it (a bare `load()` of an autoload-referencing script fails
## to compile under `--script` mode with "Identifier not found", per the
## Godot 4.7 gotcha in CLAUDE.md: `load()` returns a non-null but
## `can_instantiate() == false` script resource on a compile error).
##
## This file itself carries ZERO bare autoload identifiers (no `ObservableBus`/
## `Game`/`TestDriver` anywhere below) for the same reason: the two spots the
## original code touched an autoload directly (`_drain_playback`'s
## `ObservableBus.emit_domain_event(UI_AI_PLAYBACK_DONE, ...)` and
## `_beat_delay`'s `TestDriver.active()` check) now call back through tiny
## `screen` wrapper methods (`_emit_ai_playback_done`/`_test_driver_active`,
## both added on combat_screen.gd, which already shadows those two names
## under the test's autoload-stubbed patch) instead of touching the
## singletons here. This is what lets `tests/test_combat_visuals.gd`'s direct
## call to `screen._capture_playback_event(...)` (see that file's compat shim)
## lazily `load()`+`.new()` THIS file even inside that hostile --script-mode
## context and have it actually compile -- verified by running the test after
## this file was written (see the D3 task report).
##
## Every other autoload-safe reference (`WICombatAI`, `WIEvents`, `WICombat`)
## is a plain `class_name` script, not an autoload singleton -- those resolve
## fine under `--script` mode (same reasoning `combat_screen.gd`'s own
## top-level `AI_PLAYBACK_TYPES` const array, built from bare `WIEvents.*`
## references, already proves by compiling clean in that same stubbed test).

var _renderer: Node
var _screen: Node

## Queued AI-turn events, captured at enqueue (see `capture_playback_event`),
## drained beat-by-beat by `drain()`.
var _playback: Array = []
## True for the whole `drain()` call (paced or fast-forwarded) -- what
## `combat_screen.gd._refresh()` checks via `is_playing()` to skip the live
## per-combatant board refresh while beats are still pending.
var _playing := false
## Set by `request_skip()` (screen's `_unhandled_input`, confirm/cancel while
## `is_playing()`) to fast-forward the rest of the queue without animations.
var _skip_requested := false
## True only for the synchronous span inside `run_ai_turn()` where
## `WICombatAI.take_turn(combat)` is running -- the gate `combat_screen.gd.
## _on_domain_event` checks (via `is_ai_turn_active()`) to route an arriving
## domain event into capture instead of the live render path.
var _ai_turn_active := false


## Hit-stop: a melee connect beat holds this long before the next
## beat plays -- a 60ms freeze inside the 40-80ms design band. Only ever added
## on top of a non-zero `beat_delay()` (see `drain()`), so it is QA-collapsed
## to zero under TestDriver/headless exactly like the AI pacing it rides on.
const HIT_STOP_SECONDS := 0.06


func _init(renderer: Node, screen: Node) -> void:
	_renderer = renderer
	_screen = screen


func is_playing() -> bool:
	return _playing


func is_ai_turn_active() -> bool:
	return _ai_turn_active


func request_skip() -> void:
	_skip_requested = true


func enqueue(event: Dictionary) -> void:
	_playback.append(event)


## Enqueue-time snapshot builder (verbatim move of the old `combat_screen.gd.
## _capture_playback_event`) -- called from the screen's `_on_domain_event`
## while `is_ai_turn_active()` is true. Returns the captured event; the caller
## stashes any already-decided tutor-line match onto `payload["_ui"]["tutor"]`
## BEFORE calling `enqueue()` (tutor matching itself stays screen-side --
## `_match_tutor_line` is called once per arriving event regardless of
## capture-vs-live routing, per its own doc comment).
func capture_playback_event(type: String, payload: Dictionary) -> Dictionary:
	var captured_payload := payload.duplicate(true)
	captured_payload["_ui"] = _capture_event_ui(type, payload)
	return {"type": type, "payload": captured_payload}


## Builds the `_ui` block stashed onto a queued playback event at ENQUEUE
## time -- every render input a dequeue-time `_apply_playback_event` needs,
## read from live combat state NOW rather than recomputed later once the live
## sim has moved on to the turn's end state. `_feed_line_for_event`/
## `_skill_flash_color`/`_skill_flash_cells` stay screen-side (HUD/feed
## territory, not this task's move list -- see the D3 task report), called
## back through `_screen`.
func _capture_event_ui(type: String, payload: Dictionary) -> Dictionary:
	var combat := _screen._combat_or_null() as WICombat
	var ui := {
		"actor_id": _actor_id_for_event(type, payload),
		"feed_line": _screen._feed_line_for_event(type, payload),
	}
	match type:
		WIEvents.ATTACK_RESOLVED:
			var attacker_id := String(payload["attacker"])
			var target_id := String(payload["target"])
			var attacker_cell: Variant = _combatant_cell(combat, attacker_id)
			var target_cell: Variant = _combatant_cell(combat, target_id)
			ui["attacker_cell"] = _cell_payload(attacker_cell)
			ui["target_cell"] = _cell_payload(target_cell)
			ui["attacker_flip_h"] = _flip_toward(attacker_cell, target_cell)
			ui["target_flip_h"] = _flip_toward(target_cell, attacker_cell)
			ui["stats"] = _capture_combatant_stats(combat, [attacker_id, target_id])
		WIEvents.SKILL_RESOLVED:
			ui["flash_color"] = _screen._skill_flash_color(String(payload["skill"]))
			ui["flash_cells"] = _cells_payload(_screen._skill_flash_cells(payload, true))
			ui["stats"] = _capture_combatant_stats(combat, [String(payload.get("actor", ""))])
		WIEvents.REACTION_TRIGGERED:
			ui["stats"] = _capture_combatant_stats(combat, [String(payload.get("id", ""))])
			if String(payload.get("skill", "")) == "mana_shield":
				var reactor_cell: Variant = _combatant_cell(combat, String(payload["id"]))
				ui["flash_cells"] = _cells_payload([reactor_cell] if reactor_cell is Vector2i else [])
				ui["flash_color"] = _screen.SHIELD_FLASH
		WIEvents.COMBATANT_DOWNED:
			ui["stats"] = _capture_combatant_stats(combat, [String(payload.get("id", ""))])
			# F3 (issue #82): a downed windup-CASTER's pending declare never
			# resolves (the sim's downed-clears contract), so nothing would
			# ever expire its dangersense overlay -- capture the parked cells
			# NOW (the sim leaves `combat.windups` populated for a dead
			# caster; enqueue-time read, this function's whole contract) so
			# the dequeue/live render path can clear the overlay at the down
			# beat. Absent/empty for every non-caster down -- a no-op key.
			var downed_id := String(payload.get("id", ""))
			if combat != null and combat.windups.has(downed_id):
				ui["windup_cells"] = _cells_payload(combat.windups[downed_id]["cells"])
		WIEvents.WINDUP_DECLARED:
			# Issue #82's WINDUP SIM SPEC / [Dangersense] payoff: captured at
			# ENQUEUE time (this function's whole contract -- read live combat
			# state NOW, never at dequeue), so a PC that gains/loses the skill
			# mid-fight (impossible today, no skill is ever un-granted
			# mid-combat, but the read stays honest regardless) can't leak a
			# stale verdict into a beat captured before the change.
			ui["dangersense"] = _pc_holds_dangersense(combat)
		WIEvents.STATUS_TICKED:
			# GH#90 [burning]: the tick's own beat needs the holder's cell
			# (damage number placement), side (numeral hue), and post-tick
			# HP (bar drop paced to the tick, not the turn's end state).
			var ticked_id := String(payload.get("id", ""))
			ui["target_cell"] = _cell_payload(_combatant_cell(combat, ticked_id))
			if combat != null and combat.combatants.has(ticked_id):
				ui["side"] = String(combat.combatants[ticked_id].get("side", ""))
			ui["stats"] = _capture_combatant_stats(combat, [ticked_id])
	return ui


## [Dangersense] payoff (issue #82): true iff the PC's own combatant record
## currently knows the skill. Reads the LIVE "pc" combatant off `combat`
## directly (own-knowledge is a party-wide read for a party-wide payoff --
## unlike an ally's kit, which never varies run-to-run, the PC's known skills
## are genuinely player-chosen) rather than any static catalog -- a PC that
## never leveled to [Dangersense] (Warrior L5) sees the feed line/caster flash
## only, same as everyone else.
func _pc_holds_dangersense(combat: WICombat) -> bool:
	if combat == null or not combat.combatants.has("pc"):
		return false
	return (combat.combatants["pc"].get("skills", []) as Array).has("dangersense")


## Snapshots hp/max_hp/mp/max_mp for each given combatant id, read from live
## `combat` state — the enqueue-time capture that `_apply_captured_stats`
## later applies at dequeue. Skips ids that are blank or no longer known to
## combat.
func _capture_combatant_stats(combat: WICombat, ids: Array) -> Dictionary:
	var out := {}
	for id: String in ids:
		if id != "" and combat != null and combat.combatants.has(id):
			var c: Dictionary = combat.combatants[id]
			out[id] = {
				"hp": int(c["hp"]), "max_hp": int(c["max_hp"]),
				"mp": int(c.get("mp", 0)), "max_mp": int(c.get("max_mp", 0)),
			}
	return out


func _actor_id_for_event(type: String, payload: Dictionary) -> String:
	match type:
		WIEvents.ATTACK_RESOLVED:
			return String(payload.get("attacker", ""))
		WIEvents.SKILL_RESOLVED, WIEvents.ACTION_REFUSED:
			return String(payload.get("actor", ""))
		_:
			return String(payload.get("id", ""))


func _combatant_cell(combat: WICombat, id: String) -> Variant:
	if combat != null and combat.combatants.has(id):
		return combat.combatants[id]["cell"]
	return null


func _cell_payload(cell: Variant) -> Array:
	if cell is Vector2i:
		var v := cell as Vector2i
		return [v.x, v.y]
	return []


func _cells_payload(cells: Array) -> Array:
	var out: Array = []
	for cell: Variant in cells:
		if cell is Vector2i:
			out.append(_cell_payload(cell))
	return out


## Called cross-object by `combat_screen.gd._play_event_visual` (which stays
## screen-side -- not this task's move list) for its two flash-cell sites; not
## underscore-shy about that the way the internal-only helpers above are --
## kept the original name since it reads the same either way.
func _cells_from_payload(cells: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not (cells is Array):
		return out
	for raw_cell: Variant in cells:
		if raw_cell is Vector2i:
			out.append(raw_cell)
		elif raw_cell is Array and (raw_cell as Array).size() >= 2:
			var raw_array := raw_cell as Array
			out.append(Vector2i(int(raw_array[0]), int(raw_array[1])))
	return out


func _flip_toward(from_cell: Variant, to_cell: Variant) -> Variant:
	if from_cell is Vector2i and to_cell is Vector2i:
		var from_v := from_cell as Vector2i
		var to_v := to_cell as Vector2i
		if to_v.x != from_v.x:
			return to_v.x < from_v.x
	return null


## Deferred-called from `combat_screen.gd._apply_turn_started` for an
## AI-controlled active combatant (`_ai_playback.run_ai_turn.call_deferred()`).
## Runs the WHOLE AI turn synchronously via `WICombatAI.take_turn` (a plain
## `class_name`, not an autoload -- safe to reference directly), then awaits
## `drain()` to pace the queued beats it generated via capture.
func run_ai_turn() -> void:
	var combat := _screen._combat() as WICombat
	if combat == null or combat.finished:
		return
	# Guard against a stale deferred call from a superseded turn: only act if
	# the CURRENTLY active combatant is actually AI-controlled.
	var active: Dictionary = combat.combatants[combat.get_active()]
	if String(active["side"]) != "enemy" and String(active["ai"]) == "":
		return
	_ai_turn_active = true
	WICombatAI.take_turn(combat)
	_ai_turn_active = false
	# No screen._refresh() here: the sim already ran the WHOLE turn
	# synchronously above, so the live snapshot is already at the turn's
	# final state. Refreshing now (before a single paced beat has played)
	# would be the exact "teleport to the end" bug drain() exists to avoid --
	# it does its own final refresh once the queued beats are fully applied.
	await drain()


## Returns the extra hold a just-applied beat earns (spec item 1): a melee
## ATTACK_RESOLVED that CONNECTED (hit) gets HIT_STOP_SECONDS; everything else
## (misses, ranged casts, moves, downs) zero. Reads only the beat's own
## captured payload, never live combat state. WIEvents is a plain class_name
## const table (autoload-safe), so this keeps combat_playback.gd free of bare
## autoload identifiers -- the load()-under-`--script`-mode contract this file
## documents at the top.
func _hit_stop_hold(event: Dictionary) -> float:
	if String(event.get("type", "")) != WIEvents.ATTACK_RESOLVED:
		return 0.0
	var p: Dictionary = event.get("payload", {})
	if bool(p.get("hit", false)) and bool(p.get("melee", true)):
		return HIT_STOP_SECONDS
	return 0.0


## Issue #87: the AI-pacing seconds, scaled by the player's Combat Speed pick
## via `_screen._current_beat_seconds()` -- a THIRD `_screen` wrapper (the
## SAME "no bare autoload identifiers in this file" reason `_test_driver_
## active()`/`_emit_ai_playback_done()` exist, see the file doc comment
## above). Zero-delay QA/headless is checked FIRST and unconditionally, so
## Instant speed (multiplier 0.0) never opens a new code path -- it lands on
## the exact same already-proven-safe zero-delay branch.
func beat_delay() -> float:
	if _screen._test_driver_active() or DisplayServer.get_name() == "headless":
		return 0.0
	return _screen._current_beat_seconds()


## Pops and applies one queued AI-turn event per beat, pacing by beat_delay()
## between them (zero in QA/headless, so the whole queue drains synchronously
## in one go). Confirm/cancel during the wait sets `_skip_requested` (via
## `request_skip()`), which fast-forwards the rest of the queue without
## animations. Either way, `_playing` is what `combat_screen.gd._refresh()`
## checks (via `is_playing()`) to skip the live per-combatant block while
## beats are still pending -- set for the full drain and cleared before the
## guaranteed final refresh below, so both the paced and the skipped path
## always end with the board showing the exact live end state.
func drain() -> void:
	if _playing:
		return
	_playing = true
	var beats := 0
	while not _playback.is_empty():
		var event: Dictionary = _playback.pop_front()
		_apply_playback_event(event, true)
		beats += 1
		var delay := _coalesced_delay(event, beat_delay())
		if delay > 0.0:
			delay += _hit_stop_hold(event)
		if delay > 0.0 and not _playback.is_empty():
			await _wait_for_skip(delay)
			if _skip_requested:
				_skip_requested = false
				while not _playback.is_empty():
					var rest: Dictionary = _playback.pop_front()
					_apply_playback_event(rest, false)
					beats += 1
	_playing = false
	_screen._refresh()
	_screen._emit_ai_playback_done(beats)


## Issue #87 (beat coalescing): AP_CHANGED and TURN_ENDED carry no
## hold-worthy visual of their own -- AP_CHANGED's own `_play_event_visual`
## arm only resets the projectile-tint tracker (a bookkeeping side effect,
## never a rendered change); TURN_ENDED renders nothing but an already-
## decided tutor-line check (`_apply_playback_event`'s default `_:` branch,
## whose only OTHER visible effect is `_highlight_actor`'s brief flash, which
## fires synchronously before this function ever runs and keeps playing
## regardless of whether the beat holds afterward). Pacing a full
## `beat_delay()` after either type just adds dead air around the beats that
## DO matter, so both collapse to zero delay unconditionally, folding into
## whichever beat follows.
##
## A run of consecutive COMBATANT_MOVED beats (a multi-cell walk, one event
## per step -- `board_renderer.move_visual`'s own MOVE_TWEEN_SECONDS=0.12s
## tween paces the visual slide) also collapses to zero delay between STEPS:
## peeks `_playback[0]` (never pops it -- the queue's actual event order and
## every event still gets applied via `drain()`'s own pop/apply loop) to
## check whether the NEXT queued beat is ALSO a move, and if so skips the
## pacing gap so the walk reads as one continuous glide instead of a
## stutter-step. Only the LAST COMBATANT_MOVED in a run (next queued event is
## something else, or the queue drains) keeps the real `beat_delay()`, same
## pacing as before between the walk and whatever follows it.
##
## Zero-delay QA/headless/Instant speed is a strict no-op either way: `delay
## <= 0.0` short-circuits before any type check runs, so this can never OPEN
## a new delay where `beat_delay()` itself already collapsed to zero -- see
## that function's own "checked first, unconditionally" doc comment.
func _coalesced_delay(event: Dictionary, delay: float) -> float:
	if delay <= 0.0:
		return delay
	var type := String(event.get("type", ""))
	if type == WIEvents.AP_CHANGED or type == WIEvents.TURN_ENDED:
		return 0.0
	if type == WIEvents.COMBATANT_MOVED and not _playback.is_empty() and String((_playback[0] as Dictionary).get("type", "")) == WIEvents.COMBATANT_MOVED:
		return 0.0
	return delay


## Renders one dequeued playback event. `with_visuals` gates only the cosmetic
## flourishes (actor highlight tween, hit/cast animations) — feed text and the
## affected combatant's position/HP/MP bars always apply, paced or
## fast-forwarded, so state stays consistent beat-to-beat regardless of skip.
## `combatant_moved` moves only that one combatant's holder to its captured
## cell; attack/skill/reaction/downed events apply that beat's
## enqueue-time-captured hp/mp (`_capture_event_ui`) to the affected
## combatant(s) instead of the blanket, already-turn-final screen refresh.
## `_apply_turn_started`/`_apply_combat_finished`/`_play_event_visual`/
## `_push_feed`/`_render_tutor_line`/`_refresh` all stay screen-side (mode FSM
## + HUD/feed territory) -- called back through `_screen`.
func _apply_playback_event(event: Dictionary, with_visuals: bool) -> void:
	var type := String(event["type"])
	var payload: Dictionary = event["payload"]
	# Renders the match `_on_domain_event` already decided at enqueue time --
	# dequeue never re-matches against live state, only replays the stashed
	# `{}`-or-`{id,line}` verdict.
	var tutor: Dictionary = (payload.get("_ui", {}) as Dictionary).get("tutor", {})
	# Issue #82's WINDUP SIM SPEC: a SKILL_RESOLVED for a `windup_rounds`-
	# carrying skill is a windup RESOLVING (WICombat._resolve_windup emits
	# this exact shape) -- clear the "windup_danger" overlay WINDUP_DECLARED
	# may have drawn, for the SAME reason TERRAIN_ADDED/EXPIRED route outside
	# `with_visuals` below: persistent renderer state has no post-drain resync,
	# so a skip must still clear it. Checked BEFORE the match (not a dedicated
	# case) so SKILL_RESOLVED's own existing dispatch (default branch below,
	# same as every other skill) is otherwise untouched -- this only adds a
	# side-effect, never changes SKILL_RESOLVED's own render path.
	if type == WIEvents.SKILL_RESOLVED:
		var resolved_combat := _screen._combat_or_null() as WICombat
		var resolved_skill: Dictionary = resolved_combat.skills.get(String(payload.get("skill", "")), {}) if resolved_combat != null else {}
		if int((resolved_skill.get("effect", {}) as Dictionary).get("windup_rounds", 0)) > 0:
			_renderer.expire_terrain("windup_danger", _cells_from_payload(payload.get("cells", [])))
	# F3 (issue #82): the OTHER way a declared windup ends -- its caster goes
	# down before resolving (no posthumous resolution, so no SKILL_RESOLVED
	# will ever fire to clear the overlay). `_capture_event_ui` stashed the
	# dead caster's parked cells at enqueue time (`_ui.windup_cells`, absent
	# for every ordinary down); same pre-match/unconditional placement as the
	# SKILL_RESOLVED clear above, for the same skip-path reason. NOTE both
	# clears also run redundantly from `_play_event_visual`'s own arms on the
	# paced/live paths -- expire_terrain no-ops on already-cleared cells, and
	# the redundancy is what covers the LIVE path (a resolution/down arriving
	# outside AI playback never passes through this function at all).
	if type == WIEvents.COMBATANT_DOWNED:
		var downed_windup_cells: Array = (payload.get("_ui", {}) as Dictionary).get("windup_cells", [])
		if not downed_windup_cells.is_empty():
			_renderer.expire_terrain("windup_danger", _cells_from_payload(downed_windup_cells))
	match type:
		WIEvents.TURN_STARTED:
			_screen._render_tutor_line(tutor)
			_screen._apply_turn_started(String(payload["id"]))
		WIEvents.COMBAT_FINISHED:
			_screen._render_tutor_line(tutor)
			_screen._apply_combat_finished(payload)
		WIEvents.COMBATANT_MOVED:
			_apply_combatant_moved(payload)
			if with_visuals:
				_highlight_actor(event)
			_screen._push_feed(payload)
			_screen._render_tutor_line(tutor)
			_screen._refresh()
		WIEvents.TERRAIN_ADDED, WIEvents.TERRAIN_EXPIRED:
			# Terrain overlays are BOARD STATE,
			# not transient juice -- `_play_event_visual`'s TERRAIN arms are the
			# ONLY code that mutates board_renderer's persistent overlay tree,
			# and unlike combatant position/HP/MP there is no post-drain resync
			# to recover a skipped mutation (`_refresh_combatants` re-syncs
			# combatants from the live snapshot after every drain; nothing does
			# that for terrain). So these route to the renderer UNCONDITIONALLY,
			# outside the `with_visuals` gate -- the exact COMBATANT_MOVED idiom
			# above (state applies whether paced or skip-fast-forwarded; only
			# the highlight tween is gated). Without this arm, a player pressing
			# skip mid-AI-turn at the beat the ice expires kept a permanently
			# stale icy overlay for the rest of the fight -- invisible to every
			# QA layer by construction (beat_delay() is 0 under TestDriver, so
			# the skip path never executes under QA). FUTURE terrain-like events
			# (anything whose _play_event_visual arm mutates persistent renderer
			# state rather than firing a self-freeing effect) MUST be matched
			# here too, not left to the `_:` default -- this is the same trap
			# class as combat_screen.gd's AI_PLAYBACK_TYPES TRAP comment.
			_screen._play_event_visual(type, payload)
			if with_visuals:
				_highlight_actor(event)
			_screen._push_feed(payload)
			_screen._render_tutor_line(tutor)
			_screen._refresh()
		WIEvents.WINDUP_DECLARED:
			# Issue #82's WINDUP SIM SPEC / [Dangersense] payoff: the cell
			# overlay ("windup_danger", board_renderer.gd's `add_terrain`
			# reused under a new kind -- pure rendering, no coupling to the
			# SIM's own `WICombat.terrain` dict) is PERSISTENT renderer state,
			# the SAME trap class as TERRAIN_ADDED/EXPIRED just above -- applied
			# UNCONDITIONALLY, outside `with_visuals`, gated only on whether the
			# PC holds [Dangersense] (`_capture_event_ui`'s enqueue-time read).
			# The universal tell (feed line + caster flash) stays
			# `with_visuals`-gated like every other transient beat --
			# `_highlight_actor` below already IS the caster flash (a brief
			# bright pulse on the caster's own holder, `ui.actor_id` resolves to
			# the caster via `_actor_id_for_event`'s default `payload["id"]`
			# fallback), reused for free -- no new flash mechanism needed.
			var windup_ui: Dictionary = payload.get("_ui", {})
			if bool(windup_ui.get("dangersense", false)):
				_renderer.add_terrain("windup_danger", _cells_from_payload(payload.get("cells", [])))
			if with_visuals:
				_highlight_actor(event)
			_screen._push_feed(payload)
			_screen._render_tutor_line(tutor)
			_screen._refresh()
		_:
			var ui: Dictionary = payload.get("_ui", {})
			_apply_captured_stats(ui)
			if with_visuals:
				_highlight_actor(event)
				_screen._play_event_visual(type, payload)
			_screen._push_feed(payload)
			_screen._render_tutor_line(tutor)
			_screen._refresh()


## Applies each id's captured stats (see `_capture_combatant_stats`) from a
## playback event's `_ui.stats` block — the dequeue-time counterpart that
## keeps HP/MP bars paced to their own beat instead of the live end state.
func _apply_captured_stats(ui: Dictionary) -> void:
	var stats: Dictionary = ui.get("stats", {})
	for id: String in stats:
		_renderer.apply_stats(id, stats[id])


## Moves one combatant's holder to a captured historical cell (used by paced
## AI playback's combatant_moved case). Bypasses `combat_screen.gd._refresh_
## combatants` entirely so a single queued move beat renders exactly the cell
## that event recorded, not wherever the sim has since moved on to.
func _apply_combatant_moved(payload: Dictionary) -> void:
	var cell: Array = payload.get("cell", [])
	if cell.size() < 2:
		return
	_renderer.move_visual(String(payload.get("id", "")), Vector2i(int(cell[0]), int(cell[1])), true)


## Polls once per frame (rather than a single `await get_tree().create_timer`)
## specifically so `_skip_requested` — set by `request_skip()` while
## `is_playing()` — can cut the wait short mid-beat instead of only being
## checked at the next beat boundary. `_screen.get_tree()` since this is a
## RefCounted, not a Node (`_screen` is the CanvasLayer that has one).
func _wait_for_skip(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not _skip_requested:
		await _screen.get_tree().process_frame


## Brief modulate flash on the acting combatant's holder — actor id comes from
## the event's captured `_ui.actor_id` (`_capture_event_ui`), not recomputed,
## so it still names the right combatant if the sim has moved on by dequeue.
## `_screen.create_tween()` since this is a RefCounted, not a Node.
##
## TRAP (dead-actor re-flash): `_actor_id_for_event` has no dedicated case
## for COMBATANT_DOWNED, so it falls to the default branch and names the
## DOWNED combatant itself as "actor" -- and a combatant that dies MID-TURN
## (to a reaction/counter-strike) still emits its own turn_ended, riding the
## SAME AI-turn playback batch as its downed beat and resolving to the same
## id via the same default-branch fallback. Without the `death_visible`
## guard below, that trailing event re-runs this flash on a holder whose
## death fade (fade_chip, fired for the downed beat moments earlier) is
## already in flight -- both tweens write the same node's `modulate`, and
## this one ends at opaque WHITE, undoing the fade. CONSTRAINT: a combatant
## marked `death_visible` (set at COMBATANT_DOWNED capture AND render time,
## see combat_screen.gd/board_renderer.gd) must never be re-flashed,
## regardless of which later event in the same batch names it.
func _highlight_actor(event: Dictionary) -> void:
	var payload: Dictionary = event["payload"]
	var ui: Dictionary = payload.get("_ui", {})
	var actor_id := String(ui.get("actor_id", ""))
	if actor_id == "":
		return
	var visual: Node2D = _renderer.visual_for(actor_id)
	if visual == null:
		return
	if _renderer.death_visible(actor_id):
		return
	visual.modulate = Color(1.25, 1.25, 1.25, 1.0)
	var tw: Tween = _screen.create_tween()
	tw.tween_property(visual, "modulate", Color.WHITE, 0.18)
