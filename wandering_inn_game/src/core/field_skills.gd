class_name WIFieldSkills
extends RefCounted

## PROPERTY TABLE (issue #348 slice 1, spec §4.1/§4.3/§9). The burnable and
## freezable arms used to be two hardcoded branches here; they are now ONE
## table-lookup arm at the SAME dispatch position, fed by data/interactions.json
## (injected through scene_config, never read from disk -- core stays pure).
## Contracts:
##  * OUTCOMES is a CLOSED verb set, and each verb names a SHIPPED sim
##    behavior. A new verb is a sim arm + its own proof canonical; a new
##    ROW (or a new carrier for an existing row) is data alone -- that
##    asymmetry is the whole point of the slice.
##  * MIRROR CONTRACT: data/interactions.json's "outcomes" must equal
##    OUTCOMES exactly (proven in tests/test_interactions_table.gd, policed
##    by scripts/data_lint.py). Changing one without the other is a red gate.
##  * ROW ORDER IS THE CONTRACT: first matching row wins. The burn/freeze pair
##    leads so the pre-table precedence is reproduced, and any pair whose
##    target properties can hold on the SAME target must be ordered
##    deliberately -- a frozen water cell carries `frozen` AND `freezable`, so
##    burns x frozen (thaw) MUST precede burns x freezable (the water refusal)
##    or fire could never take ice back off the channel.
##  * A row whose guard says "already applied" (a frozen cell re-frozen)
##    does NOT match -- it falls through to field_ambient exactly as the
##    hardcoded arm did.
##  * An EMPTY table (synthetic scene_config with no "interactions" key)
##    resolves nothing and every cast falls through to ambient/refusal.
##    That is by design for hand-built unit worlds; the canonical lattice
##    is what proves the shipped table is actually wired.
const OUTCOME_REMOVE_SCORCH := "remove_scorch"
const OUTCOME_FREEZE_CELL := "freeze_cell"
const OUTCOME_THAW_CELL := "thaw_cell"
const OUTCOME_STATE_SET := "state_set"
const OUTCOME_REFUSE := "refuse"
const OUTCOMES: Array[String] = [OUTCOME_REMOVE_SCORCH, OUTCOME_FREEZE_CELL, OUTCOME_THAW_CELL, OUTCOME_STATE_SET, OUTCOME_REFUSE]
## The two shipped target-property placements (spec §4.2): a boolean flag on
## the faced ENTITY (burnable), or a map-authored CELL class (freezable).
## PLACEMENT_ANY is a VERB-side wildcard only -- never a legal placement for a
## target property, only the declaration of a verb whose body dereferences
## NEITHER shape (refuse).
const PLACEMENT_ENTITY := "entity"
const PLACEMENT_CELL := "cell"
const PLACEMENT_ANY := "any"
## The one DYNAMIC cell class: never authored on a map, it is whatever
## freeze_cell wrote into `frozen_cells` this waking. Derived HERE (dispatch
## already carries frozen_cells) so thaw_cell needs no WIGame._cell_properties
## key. Every other cell property comes from the injected map classes.
const CELL_PROPERTY_FROZEN := "frozen"
## VERB/PLACEMENT BINDING: each verb's body dereferences ONE shape --
## remove_scorch/state_set read the faced ENTITY (target[id]), freeze_cell/
## thaw_cell write the faced CELL and never read target, refuse reads neither.
## TRAP: a row pairing a verb with the other placement crashes the cast
## (remove_scorch, empty target) or silently flips an arbitrary cell's
## walkability (freeze_cell -- is_cell_blocked passes ANY frozen cell, so that
## row is a wall-phase primitive). data_lint.OUTCOME_PLACEMENT fails such a row;
## _resolve_property makes it inert here. Mirrored in data_lint, asserted in
## tests/test_interactions_table.gd.
const OUTCOME_PLACEMENT: Dictionary = {
	OUTCOME_REMOVE_SCORCH: PLACEMENT_ENTITY,
	OUTCOME_FREEZE_CELL: PLACEMENT_CELL,
	OUTCOME_THAW_CELL: PLACEMENT_CELL,
	OUTCOME_STATE_SET: PLACEMENT_ENTITY,
	OUTCOME_REFUSE: PLACEMENT_ANY,
}

var _event_sink: Callable
var _skills: Dictionary
var _door_openable: Callable
var _break_sneak: Callable
var _toggle_sneak: Callable
var _mark_skill_used: Callable
var _record_accomplishment: Callable
## GH#387 S0.1: reads the CARRIER's own save-persisted counter. state_set's
## one-way guard cannot use entity_first_use -- wi_game.sleep() clears that
## dictionary, so the guard would only hold within a single waking.
var _accomplishment_count: Callable
var _remove_entity: Callable
var _use_skill: Callable
var _toggle_light: Callable
var _blink: Callable
var _ward: Callable
var _animate: Callable
var _property_rows: Array = []
var _target_placements: Dictionary = {}


func _init(event_sink: Callable, skills: Dictionary, break_sneak_cb: Callable, toggle_sneak_cb: Callable, mark_skill_used_cb: Callable, record_accomplishment_cb: Callable, remove_entity_cb: Callable, use_skill_cb: Callable, toggle_light_cb: Callable, blink_cb: Callable, ward_cb: Callable, animate_cb: Callable, door_openable_cb: Callable = Callable(), interaction_config: Dictionary = {}, accomplishment_count_cb: Callable = Callable()) -> void:
	_accomplishment_count = accomplishment_count_cb
	_event_sink = event_sink
	_skills = skills
	_target_placements = (interaction_config.get("target_properties", {}) as Dictionary).duplicate()
	for row: Variant in interaction_config.get("interactions", []):
		if row is Dictionary:
			_property_rows.append(row)
	_door_openable = door_openable_cb
	_break_sneak = break_sneak_cb
	_toggle_sneak = toggle_sneak_cb
	_mark_skill_used = mark_skill_used_cb
	_record_accomplishment = record_accomplishment_cb
	_remove_entity = remove_entity_cb
	_use_skill = use_skill_cb
	_toggle_light = toggle_light_cb
	_blink = blink_cb
	_ward = ward_cb
	_animate = animate_cb


## CONTRACT (plan P1): faced entity with requires_skill==skill_id + on_skill_use
## routes via use_skill(skill_id, prop_id) — SAME seam interact() uses; emitted
## event stream BYTE-IDENTICAL to interact-with-requires_skill. Fallthrough:
## no qualifying entity -> skill's field_ambient toast; none authored -> refusal
## idiom. Unknown-skill and non-field guards are the CALLER's job
## (wi_game.use_skill_field) — never re-guard here.
func dispatch(skill_id: String, known: bool, target: Dictionary, faced_cell: Vector2i, current_map: String, frozen_cells: Dictionary, entity_first_use: Dictionary, cell_properties: Dictionary) -> Dictionary:
	# Required-skill props route through WIGame.use_skill so field and generic interaction share one effect seam.
	if not known:
		_emit(WIEvents.SKILL_UNKNOWN, {"skill": skill_id})
		_emit(WIEvents.TOAST, {"text": "You don't know how to do that yet."})
		return {}
	if not bool(_skills.get(skill_id, {}).get(WIKeys.FIELD, false)):
		_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": ""})
		_emit(WIEvents.TOAST, {"text": "That's not something you can do out here."})
		return {}
	if bool(_skills.get(skill_id, {}).get("sneaks", false)):
		return _toggle_sneak.call(skill_id)
	var skill: Dictionary = _skills.get(skill_id, {})
	if bool(skill.get("blinks", false)):
		return _blink.call(skill_id, skill)
	if bool(skill.get("wards", false)):
		_break_sneak.call()
		return _ward.call(skill_id, skill, faced_cell)
	if bool(skill.get("animates", false)) or bool(skill.get("tames", false)):
		_break_sneak.call()
		return _animate.call(skill_id, skill, target)
	if not target.is_empty() and String(target.get("requires_skill", "")) == skill_id and target.has("on_skill_use"):
		_break_sneak.call()
		return _use_skill.call(skill_id, String(target[WIKeys.ID]))
	# Pantry-door consolidation (user FEEL verdict 2026-07-19): `skill_uses`
	# = a per-skill map of on_skill_use arms, so ONE entity can answer
	# multiple Skills differently (the door: observe reads the runes,
	# detect_magic reads the wardwork) instead of clustering sibling props.
	# Routed BEFORE the generic observe arm so a mapped observe wins.
	if not target.is_empty() and (target.get("skill_uses", {}) as Dictionary).has(skill_id):
		_break_sneak.call()
		return _use_skill.call(skill_id, String(target[WIKeys.ID]))
	# GH#391: any pot is a pot. A `cookware` prop routes ANY cooking-family
	# Skill through the same use_skill seam; WIGame.use_skill picks the skill's
	# own `cookware_use` arm when the prop authored nothing for this Skill.
	if not target.is_empty() and bool(target.get("cookware", false)) and (skill.get("cookware_use", {}) as Dictionary).size() > 0:
		_break_sneak.call()
		return _use_skill.call(skill_id, String(target[WIKeys.ID]))
	if skill_id == "observe" and not target.is_empty():
		_break_sneak.call()
		var observe_line := String(target.get("observe", "You watch. Details surface."))
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": String(target[WIKeys.ID])})
		_mark_skill_used.call(skill_id)
		if _bank_first_use(entity_first_use, "observe", String(target[WIKeys.ID])):
			_record_accomplishment.call("observed_things", 1)
		_emit(WIEvents.TOAST, {"text": observe_line})
		return {"observed": String(target[WIKeys.ID])}
	if skill_id == "charming_smile" and not target.is_empty():
		_break_sneak.call()
		var friendly_line := String(target.get("friendly_line", "You offer a warm, disarming smile. It costs nothing, and it is not unwelcome."))
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": String(target[WIKeys.ID])})
		_mark_skill_used.call(skill_id)
		if _bank_first_use(entity_first_use, "friendly", String(target[WIKeys.ID])):
			_record_accomplishment.call("befriended_moments", 1)
		_emit(WIEvents.TOAST, {"text": friendly_line})
		return {"befriended": String(target[WIKeys.ID])}
	# THE PROPERTY TABLE (spec §4.3 precedence step 4). Sits BELOW the authored
	# per-entity arms and the named generic arms, ABOVE door_flavor/toggles_light
	# /field_ambient -- the position the two hardcoded arms held, kept exactly.
	var resolved := _resolve_property(skill_id, skill, target, faced_cell, current_map, frozen_cells, entity_first_use, cell_properties)
	if not resolved.is_empty():
		return resolved
	# b7 #214b: skill-authored door flavor — a data key, not an effect block
	# (test_effect_text's empty-effect-lines pin for open_doors stays
	# honest). Fires only on an OPENABLE door (review M1): a sealed
	# door_when/portal gate must not read "was not locked", and the hidden
	# garden door must not leak via toast — unmet doors fall through to
	# field_ambient like any non-door.
	var door_flavor := String(_skills.get(skill_id, {}).get("door_flavor", ""))
	if door_flavor != "" and not target.is_empty() \
			and _door_openable.is_valid() and bool(_door_openable.call(target)):
		_break_sneak.call()
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": String(target[WIKeys.ID])})
		_mark_skill_used.call(skill_id)
		_emit(WIEvents.TOAST, {"text": door_flavor})
		return {"door_flavored": String(target[WIKeys.ID])}
	# [Light]'s toggle, the `sneaks` idiom for the orb (v0.16.1 finding 5). This
	# replaced a hardcoded `if skill_id == "light"` inside the field_ambient arm
	# that only ever SET the flag, so a second cast was a no-op and only sleep()
	# put the orb out.
	# PLACEMENT IS LOAD-BEARING: this must stay BELOW the requires_skill and
	# skill_uses arms above. Lighting a light-requiring prop (the witch hollow's
	# threshold candles) faces an entity whose on_skill_use answers "light" --
	# route the toggle first and lighting the candles would snuff your own orb as
	# a side effect. Facing such a prop, the prop wins; facing anything else, the
	# orb toggles.
	if bool(_skills.get(skill_id, {}).get("toggles_light", false)):
		return _toggle_light.call(skill_id)
	var field_ambient := String(_skills.get(skill_id, {}).get("field_ambient", ""))
	if field_ambient != "":
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": ""})
		_mark_skill_used.call(skill_id)
		_emit(WIEvents.TOAST, {"text": field_ambient})
		return {"ambient": skill_id}
	_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": ""})
	_emit(WIEvents.TOAST, {"text": "Nothing here calls for that."})
	return {}


## Pure lookup over the injected table: no RNG, no Node refs, no disk. Returns
## the dispatch result of the FIRST row whose skill property, target property
## and outcome guard all hold; {} means "no row applies" and the caller keeps
## falling through. `cell_properties` is the faced cell's MAP-AUTHORED class
## membership ({freezable: bool} today) -- the cell-placement mirror of the
## entity flags; dynamic classes are derived in `_cell_carries`.
func _resolve_property(skill_id: String, skill: Dictionary, target: Dictionary, faced_cell: Vector2i, current_map: String, frozen_cells: Dictionary, entity_first_use: Dictionary, cell_properties: Dictionary) -> Dictionary:
	for row: Dictionary in _property_rows:
		var skill_prop := String(row.get("skill_property", ""))
		if skill_prop == "" or not bool(skill.get(skill_prop, false)):
			continue
		var target_prop := String(row.get("target_property", ""))
		var placement := String(_target_placements.get(target_prop, ""))
		var outcome := String(row.get("outcome", ""))
		var wants := String(OUTCOME_PLACEMENT.get(outcome, ""))
		# Binding guard, BEFORE any placement test: unregistered target property
		# (placement ""), unknown verb (wants "") or verb/placement mismatch ->
		# row is inert, cast falls through to ambient. Shipped rows satisfy it,
		# so the stream is unchanged.
		if placement == "" or wants == "" or (wants != PLACEMENT_ANY and wants != placement):
			continue
		match placement:
			PLACEMENT_ENTITY:
				if target.is_empty() or not bool(target.get(target_prop, false)):
					continue
			PLACEMENT_CELL:
				if not _cell_carries(target_prop, faced_cell, current_map, frozen_cells, cell_properties):
					continue
			_:
				# TOTALITY GUARD (hostile-row lens). A placement that is neither
				# shipped shape -- a typo, a half-merge, the ANY wildcard leaked
				# into the target vocabulary -- reaches here ONLY under a
				# wildcard verb, because every other verb's `wants` check above
				# already rejected it. Without this arm the row would skip the
				# membership test ENTIRELY and fire on every cast: one wrong
				# character in interactions.json's `target_properties` would turn
				# every carrier of the skill property into a blanket refusal,
				# with a nonsense line as the only tell. data_lint's PLACEMENTS
				# check is the first layer; this is the engine mirror that makes
				# the "makes such a row inert here" contract above actually true.
				continue
		match outcome:
			OUTCOME_REMOVE_SCORCH:
				return _outcome_remove_scorch(skill_id, row, target, current_map)
			OUTCOME_FREEZE_CELL:
				# Already-applied guard: a re-freeze is a fallthrough, never a
				# second freeze (no duplicate terrain_changed).
				if (frozen_cells.get(current_map, {}) as Dictionary).has(faced_cell):
					continue
				return _outcome_freeze_cell(skill_id, skill, row, faced_cell, current_map, frozen_cells)
			OUTCOME_THAW_CELL:
				return _outcome_thaw_cell(skill_id, skill, row, faced_cell, current_map, frozen_cells)
			OUTCOME_STATE_SET:
				# The counter is authored ON THE CARRIER (`counter_key` names the
				# field), never on the row: one row serves many props and a
				# shared counter would flip every sibling's visual_states the
				# first time ANY of them is set. A carrier missing the field
				# leaves the row inert rather than emitting a hollow toast.
				var set_counter := String(target.get(String(row.get("counter_key", "")), ""))
				if set_counter == "":
					continue
				# ONE-WAY, so a repeat is a fallthrough, not a second set (the
				# freeze_cell already-applied precedent). The guard reads the
				# CARRIER'S OWN save-persisted counter, never entity_first_use:
				# that dictionary is WAKING-scoped (wi_game.sleep clears it), so
				# guarding on it let an already-lit hearth replay its first-time
				# toast and re-bank the monotone counter once per sleep, forever.
				# Measured in phase-0 review; "permanent" is a persistence class
				# data_lint enforces, so the code has to actually mean it.
				if _state_already_set(set_counter):
					continue
				return _outcome_state_set(skill_id, row, target, set_counter)
			OUTCOME_REFUSE:
				return _outcome_refuse(skill_id, row, target, skill)
	return {}


## Cell-class membership for the CELL placement. `frozen` is derived live from
## frozen_cells; everything else reads the injected map-authored classes.
func _cell_carries(target_prop: String, faced_cell: Vector2i, current_map: String, frozen_cells: Dictionary, cell_properties: Dictionary) -> bool:
	if target_prop == CELL_PROPERTY_FROZEN:
		return (frozen_cells.get(current_map, {}) as Dictionary).has(faced_cell)
	return bool(cell_properties.get(target_prop, false))


## `remove_scorch` -- the burn shape: permanent removal (removed_entities) +
## TERRAIN_CHANGED + an optional monotone counter. Emission order is the
## byte-identity contract with the pre-table arm.
func _outcome_remove_scorch(skill_id: String, row: Dictionary, target: Dictionary, current_map: String) -> Dictionary:
	_break_sneak.call()
	var burned_id := String(target[WIKeys.ID])
	var burned_cell: Vector2i = target[WIKeys.CELL]
	_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": burned_id})
	_mark_skill_used.call(skill_id)
	var counter := _row_counter(row, target)
	if counter != "":
		_record_accomplishment.call(counter, 1)
	var burn_toast := _row_toast(row, target, {})
	_remove_entity.call(burned_id)
	_emit(WIEvents.TERRAIN_CHANGED, {"map": current_map, "cell": [burned_cell.x, burned_cell.y], "to": String(row.get("terrain", ""))})
	_emit(WIEvents.TOAST, {"text": burn_toast})
	return {"burned": burned_id}


## `freeze_cell` -- the until-sleep walkability flip over `frozen_cells`
## (sleep() clears it; WISave round-trips it). Cell-shaped, so SKILL_USED
## carries an empty target and no counter banks.
func _outcome_freeze_cell(skill_id: String, skill: Dictionary, row: Dictionary, faced_cell: Vector2i, current_map: String, frozen_cells: Dictionary) -> Dictionary:
	_break_sneak.call()
	if not frozen_cells.has(current_map):
		frozen_cells[current_map] = {}
	(frozen_cells[current_map] as Dictionary)[faced_cell] = true
	_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": ""})
	_mark_skill_used.call(skill_id)
	_emit(WIEvents.TERRAIN_CHANGED, {"map": current_map, "cell": [faced_cell.x, faced_cell.y], "to": String(row.get("terrain", ""))})
	_emit(WIEvents.TOAST, {"text": _row_toast(row, {}, skill)})
	return {"frozen": [faced_cell.x, faced_cell.y]}


## `thaw_cell` -- freeze_cell's inverse over the SAME store: drop the
## frozen_cells entry and the map's own blocked set applies again. Creates no
## timed state of its own (a thawed cell is simply not frozen), so nothing
## persists past the erase. Empty inner map keys are dropped so
## `frozen_cells.is_empty()` stays an honest "nothing is frozen anywhere".
func _outcome_thaw_cell(skill_id: String, skill: Dictionary, row: Dictionary, faced_cell: Vector2i, current_map: String, frozen_cells: Dictionary) -> Dictionary:
	_break_sneak.call()
	var cells: Dictionary = frozen_cells.get(current_map, {})
	cells.erase(faced_cell)
	if cells.is_empty():
		frozen_cells.erase(current_map)
	_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": ""})
	_mark_skill_used.call(skill_id)
	_emit(WIEvents.TERRAIN_CHANGED, {"map": current_map, "cell": [faced_cell.x, faced_cell.y], "to": String(row.get("terrain", ""))})
	_emit(WIEvents.TOAST, {"text": _row_toast(row, {}, skill)})
	return {"thawed": [faced_cell.x, faced_cell.y]}


## `state_set` -- the counter-backed visual_states swap (the unlit_lantern
## shape, expressed as a row). ONE-WAY BY SUBSTRATE: counters are monotone and
## no decrement API exists, so there is no douse/re-dirty row in v1 (spec §4.1).
## DANGER: the bank is permanent and save-persisted -- a wrong row is durable
## world state in a player's save, not a toast. Emission order mirrors
## remove_scorch (skill_used -> accomplishment_recorded -> toast).
func _outcome_state_set(skill_id: String, row: Dictionary, target: Dictionary, counter: String) -> Dictionary:
	_break_sneak.call()
	var prop_id := String(target[WIKeys.ID])
	_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": prop_id})
	_mark_skill_used.call(skill_id)
	_record_accomplishment.call(counter, 1)
	_emit(WIEvents.TOAST, {"text": _row_toast(row, target, {})})
	return {"state_set": prop_id}


## `refuse` -- an AUTHORED refusal: the ambient/no-effect shape with the row's
## own copy instead of the skill's generic line. Banks nothing, marks no use,
## breaks no sneak -- structurally identical to the shipped "Nothing here calls
## for that." fallthrough, so a refusal can never become a progress path. These
## rows are the vocabulary teachers (frost at a person, fire at water): the
## player learns the closed properties from the lines that say no.
func _outcome_refuse(skill_id: String, row: Dictionary, target: Dictionary, skill: Dictionary) -> Dictionary:
	var refused_id := "" if target.is_empty() else String(target[WIKeys.ID])
	_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": refused_id})
	_emit(WIEvents.TOAST, {"text": _row_toast(row, target, skill)})
	return {"refused": skill_id}


## Row COUNTER resolution -- `_row_toast`'s mirror, one shape for both sides of
## the sentence. `counter_from: "target"` says the CARRIER names the
## accomplishment (`counter_key` is the field to read, exactly as `toast_key`
## names the field the carrier's line lives in); anything else means the row's
## own `counter` is the id, which is the pre-#398 behavior. The row `counter`
## stays the FALLBACK for a carrier that authors no override, so one row can
## serve a generic blocker AND a pocket that must bank its own id.
## WHY IT EXISTS (#398-p2 review HIGH-1): burns x burnable is ONE row over every
## burnable in the game, so a single row-level id made every burn line in every
## region the same world event -- burning the sewers debris opened a strongbox
## two maps down, and vice versa. A per-carrier id is the only fix that keeps
## "a new carrier is data alone" true.
## NOT USED BY state_set: its counter is carrier-sourced BY SUBSTRATE (spec §4.1
## -- a shared id would flip every sibling's visual_states), so it has no row
## default to fall back to and reads `counter_key` unconditionally. Same key
## name, same meaning: the field on the carrier that names its counter.
func _row_counter(row: Dictionary, target: Dictionary) -> String:
	var fallback := String(row.get("counter", ""))
	if String(row.get("counter_from", "")) != "target":
		return fallback
	return String(target.get(String(row.get("counter_key", "")), fallback))


## Row copy resolution: `toast_from` picks WHICH side authors the line --
## "target" (the prop's own burn_toast), "skill" (the caster's freeze_toast), or
## "row" (the pair itself owns the copy, which is what a refusal cell is) -- and
## `toast_default` is the shipped fallback when the chosen side authored none.
func _row_toast(row: Dictionary, target: Dictionary, skill: Dictionary) -> String:
	var key := String(row.get("toast_key", ""))
	var fallback := String(row.get("toast_default", ""))
	match String(row.get("toast_from", "")):
		"target":
			return String(target.get(key, fallback))
		"skill":
			return String(skill.get(key, fallback))
	return fallback


## GH#387 S0.1. True once the carrier's own counter has been banked, i.e. the
## one-way state is already set. Without an injected reader the row stays
## castable rather than silently jamming shut -- a missing callable is a wiring
## bug, and a permanently-inert row hides it better than a repeatable one.
func _state_already_set(counter_key: String) -> bool:
	if not _accomplishment_count.is_valid():
		return false
	return int(_accomplishment_count.call(counter_key)) > 0


func _bank_first_use(entity_first_use: Dictionary, verb: String, entity_id: String) -> bool:
	var key := "%s:%s" % [verb, entity_id]
	if entity_first_use.has(key):
		return false
	entity_first_use[key] = true
	return true


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
