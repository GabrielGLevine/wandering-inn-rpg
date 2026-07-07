class_name WIFieldSkills
extends RefCounted
## ARCH-4: the `use_skill_field` dispatch ladder, extracted from wi_game.gd
## (Three Pillars P1/P3, Social Pillar S3, Skills Wave K1/K2). PURITY RULE:
## no autoload/Node/scene-tree references. Cross-cutting state that other
## WIGame systems also read/mutate (the `sneaking` TOGGLE, `used_skills`,
## `accomplishments`, `_maps`-derived entity removal, the `use_skill`
## prop seam, `light_active`) stays OWNED by WIGame -- this class only owns
## the DISPATCH decision; every cross-cutting mutation goes through a
## constructor-injected Callable, the same idiom as the event-sink
## injection below. `entity_first_use` stays a WIGame field too (shared
## with nothing else today, but genuinely cross-cutting in spirit -- see
## its own doc comment on wi_game.gd) and is threaded through as a
## per-call parameter (never captured) because save.gd reassigns it
## wholesale on load; capturing it at construction would go stale after a
## restore.

var _event_sink: Callable
## Immutable skill catalog (skills.json-derived), injected once -- never
## reassigned after WIGame's own `_init`, so safe to hold for this
## instance's lifetime.
var _skills: Dictionary
## Callable() -> void, forwards to WIGame._break_sneak.
var _break_sneak: Callable
## Callable(skill_id: String) -> Dictionary, forwards to WIGame._toggle_sneak.
var _toggle_sneak: Callable
## Callable(skill_id: String) -> void, forwards to WIGame._mark_skill_used.
var _mark_skill_used: Callable
## Callable(id: String, amount: int) -> void, forwards to
## WIGame.record_accomplishment.
var _record_accomplishment: Callable
## Callable(id: String) -> void, forwards to WIGame.remove_entity.
var _remove_entity: Callable
## Callable(skill_id: String, target_id: String) -> Dictionary, forwards to
## WIGame.use_skill (the requires_skill/on_skill_use prop seam).
var _use_skill: Callable
## Callable(active: bool) -> void, forwards to WIGame's `light_active` field.
var _set_light_active: Callable


func _init(event_sink: Callable, skills: Dictionary, break_sneak_cb: Callable, toggle_sneak_cb: Callable, mark_skill_used_cb: Callable, record_accomplishment_cb: Callable, remove_entity_cb: Callable, use_skill_cb: Callable, set_light_active_cb: Callable) -> void:
	_event_sink = event_sink
	_skills = skills
	_break_sneak = break_sneak_cb
	_toggle_sneak = toggle_sneak_cb
	_mark_skill_used = mark_skill_used_cb
	_record_accomplishment = record_accomplishment_cb
	_remove_entity = remove_entity_cb
	_use_skill = use_skill_cb
	_set_light_active = set_light_active_cb


## Three Pillars P1: the ONE engine surface for overworld ("field") skills.
## No target arg -- the FACED cell IS the target (`target`/`faced_cell` are
## already resolved by the caller exactly as interact() resolves its own).
## Dispatch order:
##   1. A faced entity whose `requires_skill` == this skill AND that carries
##      an `on_skill_use` responds via `use_skill(skill_id, prop_id)` -- the
##      SAME seam interact() uses. CONTRACT (plan P1): the emitted event
##      stream is BYTE-IDENTICAL to today's interact-with-requires_skill on
##      that prop.
##   2. No qualifying faced entity -> the skill's own `field_ambient` flavor
##      toast (a no-target "you did the thing" line; marks the skill used).
##   3. No `field_ambient` authored -> the established refusal toast idiom.
## Guards (already run by the caller before this method): a skill the PC
## doesn't know, and a known but non-`field` skill, are both refused before
## `dispatch` is ever called -- see wi_game.gd's `use_skill_field` wrapper.
## Precedence note vs interact()'s prop branch: interact() checks
## sleep/contains/on_interact_accomplishment BEFORE its `use_skill`
## fallback; this surface keys purely on `requires_skill` + `on_skill_use`,
## so a prop (none ships today) that combined `requires_skill` with one of
## those other shapes would diverge here -- documented, not a live
## regression.
func dispatch(skill_id: String, known: bool, target: Dictionary, faced_cell: Vector2i, current_map: String, frozen_cells: Dictionary, entity_first_use: Dictionary, is_freezable: bool) -> Dictionary:
	if not known:
		_emit(WIEvents.SKILL_UNKNOWN, {"skill": skill_id})
		_emit(WIEvents.TOAST, {"text": "You don't know how to do that yet."})
		return {}
	if not bool(_skills.get(skill_id, {}).get(WIKeys.FIELD, false)):
		_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": ""})
		_emit(WIEvents.TOAST, {"text": "That's not something you can do out here."})
		return {}
	# Skills Wave Task K2 (the sneak seam): the field toggle keys on a
	# `sneaks: true` data TAG (K1's tag-not-id convention), not this skill's
	# id. Checked BEFORE the faced-cell branches below -- the toggle doesn't
	# care what the PC is facing. Never falls through to the
	# requires_skill/observe/charm/burn/freeze/field_ambient dispatch below.
	if bool(_skills.get(skill_id, {}).get("sneaks", false)):
		return _toggle_sneak.call(skill_id)
	if not target.is_empty() and String(target.get("requires_skill", "")) == skill_id and target.has("on_skill_use"):
		# Skills Wave Task K2 (break condition): a successful field-skill use
		# ON A TARGET breaks sneaking -- broken BEFORE the skill's own
		# use_skill() emits, so the off-toast reads first.
		_break_sneak.call()
		return _use_skill.call(skill_id, String(target[WIKeys.ID]))
	# Three Pillars P3: [Appraise Foe] reads a DIFFERENT field than the
	# requires_skill/on_skill_use seam above -- ANY faced entity responds
	# with its own `observe` flavor string (generic fallback), banking
	# observed_things (opaque; feeds [Tactician]'s levels). Empty faced cell
	# falls through to the skill's field_ambient below. Flavor only.
	if skill_id == "observe" and not target.is_empty():
		_break_sneak.call()
		var observe_line := String(target.get("observe", "You watch. Details surface."))
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": String(target[WIKeys.ID])})
		_mark_skill_used.call(skill_id)
		# Social Pillar S1: bank observed_things only on the FIRST observe of
		# this entity this waking (shared per-waking dedup dict), so
		# repeat-observing one NPC can no longer farm [Tactician].
		if _bank_first_use(entity_first_use, "observe", String(target[WIKeys.ID])):
			_record_accomplishment.call("observed_things", 1)
		_emit(WIEvents.TOAST, {"text": observe_line})
		return {"observed": String(target[WIKeys.ID])}
	# Social Pillar S3: [Charming Smile] MIRRORS the [Appraise Foe] seam above --
	# ANY faced entity responds with its own `friendly_line` (generic
	# fallback), banking `befriended_moments` only on the FIRST charm of
	# this entity this waking, under a DISTINCT verb ("friendly") so charm
	# and observe dedup INDEPENDENTLY on the same entity in the same
	# waking. Empty faced cell falls through to field_ambient.
	if skill_id == "charming_smile" and not target.is_empty():
		_break_sneak.call()
		var friendly_line := String(target.get("friendly_line", "You offer a warm, disarming smile. It costs nothing, and it is not unwelcome."))
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": String(target[WIKeys.ID])})
		_mark_skill_used.call(skill_id)
		if _bank_first_use(entity_first_use, "friendly", String(target[WIKeys.ID])):
			_record_accomplishment.call("befriended_moments", 1)
		_emit(WIEvents.TOAST, {"text": friendly_line})
		return {"befriended": String(target[WIKeys.ID])}
	# Skills Wave Task K1 (burnable-prop seam): a fire field skill
	# (skills.json `burns: true`) faced at a blocking prop tagged
	# `burnable: true` removes the prop PERMANENTLY (removed_entities is a
	# saved set, so the clearing survives reload), banks an opaque
	# `burned_the_debris` counter, and emits TERRAIN_CHANGED{to:"scorched"}.
	# Only props that OPT IN via `burnable: true` can be burned.
	if not target.is_empty() and bool(target.get("burnable", false)) and bool(_skills.get(skill_id, {}).get("burns", false)):
		_break_sneak.call()
		var burned_id := String(target[WIKeys.ID])
		var burned_cell: Vector2i = target[WIKeys.CELL]
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": burned_id})
		_mark_skill_used.call(skill_id)
		_record_accomplishment.call("burned_the_debris", 1)
		var burn_toast := String(target.get("burn_toast", "Flame takes the debris. It crackles, collapses to ash, and the way is clear."))
		_remove_entity.call(burned_id)
		_emit(WIEvents.TERRAIN_CHANGED, {"map": current_map, "cell": [burned_cell.x, burned_cell.y], "to": "scorched"})
		_emit(WIEvents.TOAST, {"text": burn_toast})
		return {"burned": burned_id}
	# Skills Wave Task K1 (freezable-water seam): a frost field skill
	# (skills.json `freezes: true`) faced at a freezable water CELL (no
	# entity there) turns it into walkable ice until the next sleep. The
	# frozen set is additive (never a second-freeze re-emit), keyed by map.
	# `is_cell_blocked` already reads the set, so the crossing is walkable
	# the instant this returns.
	# MAP-AUTHORING EDGES (safe in all shipped data, keep them true): (1)
	# freezing doesn't check entity occupancy -- an entity ON a freezable
	# cell still blocks crossing via is_cell_blocked's occupancy check, so
	# never author an entity onto a freezable cell. (2) sleep() thaws
	# frozen_cells unconditionally -- never author a bed reachable ONLY
	# across ice.
	var is_frozen := (frozen_cells.get(current_map, {}) as Dictionary).has(faced_cell)
	if bool(_skills.get(skill_id, {}).get("freezes", false)) and is_freezable and not is_frozen:
		_break_sneak.call()
		if not frozen_cells.has(current_map):
			frozen_cells[current_map] = {}
		(frozen_cells[current_map] as Dictionary)[faced_cell] = true
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": ""})
		_mark_skill_used.call(skill_id)
		_emit(WIEvents.TERRAIN_CHANGED, {"map": current_map, "cell": [faced_cell.x, faced_cell.y], "to": "ice"})
		var freeze_toast := String(_skills.get(skill_id, {}).get("freeze_toast", "Frost races across the water and locks it solid. You can cross now — until it thaws."))
		_emit(WIEvents.TOAST, {"text": freeze_toast})
		return {"frozen": [faced_cell.x, faced_cell.y]}
	var field_ambient := String(_skills.get(skill_id, {}).get("field_ambient", ""))
	if field_ambient != "":
		# Playtest feature 3: the ambient (no-qualifying-prop) cast of
		# [Light] conjures a steady orb that FOLLOWS the PC until sleep --
		# flip the sim flag BEFORE the synchronous SKILL_USED emit so
		# world.gd's handler sees the up-to-date value on a live cast.
		# Idempotent: a re-cast while already lit re-fires the ambient
		# toast but leaves the flag true. Prop-targeted [Light] (the
		# lantern/cellar seam above) never reaches here.
		if skill_id == "light":
			_set_light_active.call(true)
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": ""})
		_mark_skill_used.call(skill_id)
		_emit(WIEvents.TOAST, {"text": field_ambient})
		return {"ambient": skill_id}
	_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": ""})
	_emit(WIEvents.TOAST, {"text": "Nothing here calls for that."})
	return {}


## Social Pillar S1: the SHARED per-waking first-use gate (moved here
## because its only two call sites, [Appraise Foe]/[Charming Smile], both live
## in this dispatch ladder -- `entity_first_use` itself stays on WIGame,
## see this file's own doc comment). Returns true the FIRST time
## `(verb, entity_id)` is seen since the last `sleep()` (and records it),
## false on every later call this waking.
func _bank_first_use(entity_first_use: Dictionary, verb: String, entity_id: String) -> bool:
	var key := "%s:%s" % [verb, entity_id]
	if entity_first_use.has(key):
		return false
	entity_first_use[key] = true
	return true


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
