class_name WICombatPlayback
extends RefCounted
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

var _renderer: Node
var _screen: Node

var _playback: Array = []
var _playing := false
var _skip_requested := false
var _ai_turn_active := false


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


## Capture at enqueue time and deep-copy the payload: later sim mutation must
## not rewrite an earlier visual beat. The caller adds any tutor match before
## enqueueing the returned event.
func capture_playback_event(type: String, payload: Dictionary) -> Dictionary:
	var captured_payload := payload.duplicate(true)
	captured_payload["_ui"] = _capture_event_ui(type, payload)
	return {"type": type, "payload": captured_payload}


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
			var ticked_id := String(payload.get("id", ""))
			ui["target_cell"] = _cell_payload(_combatant_cell(combat, ticked_id))
			if combat != null and combat.combatants.has(ticked_id):
				ui["side"] = String(combat.combatants[ticked_id].get("side", ""))
			ui["stats"] = _capture_combatant_stats(combat, [ticked_id])
	return ui


func _pc_holds_dangersense(combat: WICombat) -> bool:
	if combat == null or not combat.combatants.has("pc"):
		return false
	return (combat.combatants["pc"].get("skills", []) as Array).has("dangersense")


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


func run_ai_turn() -> void:
	var combat := _screen._combat() as WICombat
	if combat == null or combat.finished:
		return
	var active: Dictionary = combat.combatants[combat.get_active()]
	if String(active["side"]) != "enemy" and String(active["ai"]) == "":
		return
	_ai_turn_active = true
	WICombatAI.take_turn(combat)
	_ai_turn_active = false
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


func beat_delay() -> float:
	if _screen._test_driver_active() or DisplayServer.get_name() == "headless":
		return 0.0
	return _screen._current_beat_seconds()


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
func _coalesced_delay(event: Dictionary, delay: float) -> float:
	if delay <= 0.0:
		return delay
	var type := String(event.get("type", ""))
	if type == WIEvents.AP_CHANGED or type == WIEvents.TURN_ENDED:
		return 0.0
	if type == WIEvents.COMBATANT_MOVED and not _playback.is_empty() and String((_playback[0] as Dictionary).get("type", "")) == WIEvents.COMBATANT_MOVED:
		return 0.0
	return delay


func _apply_playback_event(event: Dictionary, with_visuals: bool) -> void:
	var type := String(event["type"])
	var payload: Dictionary = event["payload"]
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
	if type == WIEvents.COMBATANT_DOWNED:
		var downed_windup_cells: Array = (payload.get("_ui", {}) as Dictionary).get("windup_cells", [])
		if not downed_windup_cells.is_empty():
			_renderer.expire_terrain("windup_danger", _cells_from_payload(downed_windup_cells))
	# v0.16.1 finding 23: the beat's AUDIO fires HERE, at dequeue, beside the
	# animation -- not seconds earlier when WICombatAI.take_turn emitted the
	# whole turn synchronously. `with_visuals` gates it for the same reason it
	# gates the animations: a skip fast-forward must not machine-gun the sounds.
	# Delegated through the screen because this file stays free of bare autoload
	# identifiers (the load()-under---script-mode contract at the top).
	if with_visuals:
		_screen.emit_combat_beat(type, payload)
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


func _apply_captured_stats(ui: Dictionary) -> void:
	var stats: Dictionary = ui.get("stats", {})
	for id: String in stats:
		_renderer.apply_stats(id, stats[id])


func _apply_combatant_moved(payload: Dictionary) -> void:
	var cell: Array = payload.get("cell", [])
	if cell.size() < 2:
		return
	_renderer.move_visual(String(payload.get("id", "")), Vector2i(int(cell[0]), int(cell[1])), true)


func _wait_for_skip(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not _skip_requested:
		await _screen.get_tree().process_frame


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
