class_name WICombatTargeting
extends RefCounted
## Deliberately does NOT branch on a raw `mode: int` compared against
## `combat_screen.gd`'s private `Mode` enum (that script has no `class_name`,
## so `Mode.ATTACK`/`Mode.SKILL_TARGET` aren't even referenceable from a
## separate file) -- every place the original `_enter_targeting`/
## `_input_target` branched on `mode == Mode.ATTACK` vs `Mode.SKILL_TARGET` is
## exactly equivalent to branching on `skill_id == ""` vs `skill_id != ""`
## (verified against both real call sites: `_activate_bar_slot` always enters
## attack-targeting with no skill id and skill-targeting with a real one) --
## a values-preserving substitution, not a behavior change. `enter()` still
## accepts `mode` (an opaque int the caller already has in scope) purely to
## thread through `_emit_targeting_shown`'s payload shape unchanged.

const LINE_DIRS := ["up", "down", "left", "right"]
const LINE_DIR_VECTORS := {
	"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT,
}
const LOCKED_COLOR := Color(0.45, 0.45, 0.45)

var _view: RefCounted
var _screen: Node

var _targets: Array = []
var _target_index := 0
var _targets_los_blocked := false
var _targets_out_of_range := false
var _targeting_skill_id := ""
var _line_mode := false
var _line_dir_index := 0
var _last_line_dir_index := 0


func _init(view: RefCounted, screen: Node) -> void:
	_view = view
	_screen = screen


func enter(mode: int, skill_id: String = "") -> Dictionary:
	var me: String = _view.active_id()
	_targets = []
	_targets_los_blocked = false
	_line_mode = false
	_targeting_skill_id = ""
	if skill_id != "":
		_targeting_skill_id = skill_id
		var skill: Dictionary = _view.skill(_targeting_skill_id)
		var skill_effect: Dictionary = skill.get("effect", {}) as Dictionary
		var effect_type := String(skill_effect.get("type", ""))
		_line_mode = effect_type == "line_damage"
		# A self-targeted active
		# active move_pool_bonus casts; MUST stay in lockstep with
		# skill_effects.gd's `resolve_active` -- same effect.type + ap_cost>0
		# pair gates its self-buff resolver there) needs no enemy at all.
		var heal_ally_target := effect_type == "heal" and bool(skill_effect.get("ally_target", false))
		var is_self_cast := (effect_type == "move_pool_bonus" and int(skill.get("ap_cost", 0)) > 0) \
				or (effect_type == "heal" and not heal_ally_target) or effect_type == "invisibility"
		if not _line_mode and is_self_cast:
			_targets = [me]
			_target_index = 0
			_emit_targeting_shown(mode)
			return state()
		if not _line_mode and heal_ally_target:
			_targets = [me] + _view.alive_allies_of(me)
			_target_index = 0
			_emit_targeting_shown(mode)
			return state()
	if _line_mode:
		_line_dir_index = _last_line_dir_index
		_emit_targeting_shown(mode)
		return state()
	var effect: Dictionary = {}
	if _targeting_skill_id != "":
		effect = (_view.skill(_targeting_skill_id) as Dictionary).get("effect", {}) as Dictionary
	var spell_range := int(effect.get("range", 0))
	var melee := _targeting_skill_id == "" or not effect.has("range")
	var weapon_range := int((_view.combatant(me) as Dictionary).get("weapon_range", 1))
	var in_range: Array = []
	for foe: String in _view.alive_enemies_of(me):
		if melee and _view.chebyshev(me, foe) > weapon_range:
			continue
		if not melee and spell_range > 0 and _view.chebyshev(me, foe) > spell_range:
			continue
		in_range.append(foe)
	for foe: String in in_range:
		if _view.has_los(me, foe):
			_targets.append(foe)
	_targets_los_blocked = not in_range.is_empty() and _targets.is_empty()
	_targets_out_of_range = in_range.is_empty() and not melee and spell_range > 0 \
			and not _view.alive_enemies_of(me).is_empty()
	_target_index = 0
	_emit_targeting_shown(mode)
	return state()


func _emit_targeting_shown(mode: int) -> void:
	_screen._emit_targeting_shown_event(
		"attack" if _targeting_skill_id == "" else "skill", _targeting_skill_id, _targets.size()
	)


func cycle(delta: int) -> void:
	if _line_mode:
		_line_dir_index = wrapi(_line_dir_index + delta, 0, LINE_DIRS.size())
	elif not _targets.is_empty():
		_target_index = wrapi(_target_index + delta, 0, _targets.size())


func has_valid_target() -> bool:
	return _line_mode or not _targets.is_empty()


func select_at_cell(cell: Vector2i) -> bool:
	if _line_mode or _targets.is_empty():
		return false
	for i in _targets.size():
		if _view.cell(String(_targets[i])) == cell:
			_target_index = i
			return true
	return false


## a4 #216 slice 3: a board TAP during targeting. In line mode it AIMS the
## line toward the tapped cell (dominant axis from the caster) — a tap must
## never cancel a line skill. In target mode it delegates to select_at_cell;
## returns false only for an empty tap in target mode, which the caller reads
## as cancel — preserving the shipped tap-empty-to-cancel behavior there.
func tap_at_cell(cell: Vector2i) -> bool:
	if _line_mode:
		var origin: Vector2i = _view.cell(_view.active_id())
		var d := cell - origin
		if d == Vector2i.ZERO:
			return true  # tap on the caster: no-op, but never cancels
		var dir_token := ("right" if d.x > 0 else "left") if abs(d.x) >= abs(d.y) else ("down" if d.y > 0 else "up")
		_line_dir_index = LINE_DIRS.find(dir_token)
		return true
	return select_at_cell(cell)


func confirm() -> Dictionary:
	if _targeting_skill_id == "":
		return {"kind": "attack", "target_id": String(_targets[_target_index])}
	if _line_mode:
		_last_line_dir_index = _line_dir_index
		return {"kind": "line_skill", "skill_id": _targeting_skill_id, "direction": String(LINE_DIRS[_line_dir_index])}
	return {"kind": "skill", "skill_id": _targeting_skill_id, "target_id": String(_targets[_target_index])}


func cancel() -> void:
	_targets = []
	_target_index = 0
	_targets_los_blocked = false
	_targets_out_of_range = false
	_line_mode = false
	_targeting_skill_id = ""


func state() -> Dictionary:
	return {
		"targets": _targets, "index": _target_index, "line_mode": _line_mode,
		"line_dir": _line_dir_index, "skill_id": _targeting_skill_id,
		"los_blocked": _targets_los_blocked, "out_of_range": _targets_out_of_range,
	}


## `cycle_glyph`/`confirm_glyph`: the
## device-correct keycap text, byte-identical defaults to the old hardcoded
## literals ("Tab"/"Enter") -- this file carries ZERO bare autoload
## identifiers by contract (`tests/test_combat_visuals.gd` asserts it
## compiles standalone), so the REAL glyphs come from `WIInputHints.label()`
## at the composition root (combat_screen.gd), passed in as plain strings.
func line_target_text(cycle_glyph: String = "Tab", confirm_glyph: String = "Enter") -> String:
	var me: String = _view.active_id()
	var dir_token := String(LINE_DIRS[_line_dir_index])
	var dir_vec: Vector2i = LINE_DIR_VECTORS[dir_token]
	var skill: Dictionary = _view.skill(_targeting_skill_id)
	var length := int((skill.get("effect", {}) as Dictionary).get("length", 1))
	var origin: Vector2i = _view.cell(me)
	var cells: Array = _view.line_cells(origin, dir_vec, length)
	var ids: Array = _view.ids()
	ids.sort()
	var my_side := String(_view.combatant(me)["side"])
	var names: Array = []
	for cell: Vector2i in cells:
		for id: String in ids:
			var occ: Dictionary = _view.combatant(id)
			if bool(occ["alive"]) and (occ["cell"] as Vector2i) == cell:
				var nm := UIChrome.bb_escape(_view.display_name(id))
				if String(occ["side"]) == my_side:
					nm = _grey(nm)
				names.append(nm)
	var hits_text := ", ".join(names) if not names.is_empty() else "(none)"
	return "Direction: %s (%s cycles, %s confirms)\nHits: %s" % [dir_token.capitalize(), cycle_glyph, confirm_glyph, hits_text]


func _grey(text: String) -> String:
	return "[color=#%s]%s[/color]" % [LOCKED_COLOR.to_html(false), text]


func aim_preview() -> Dictionary:
	var me: String = _view.active_id()
	var origin: Vector2i = _view.cell(me)
	if _line_mode:
		var dir_token := String(LINE_DIRS[_line_dir_index])
		var dir_vec: Vector2i = LINE_DIR_VECTORS[dir_token]
		var skill: Dictionary = _view.skill(_targeting_skill_id)
		var length := int((skill.get("effect", {}) as Dictionary).get("length", 1))
		return {
			"kind": "line", "ring_cell": null, "range_cells": [],
			"line_cells": _view.line_cells(origin, dir_vec, length), "blast_cells": [],
		}
	var is_self_cast := _targeting_skill_id != "" and _targets.size() == 1 and String(_targets[0]) == me
	var kind := "attack" if _targeting_skill_id == "" else "skill"
	var ring_cell: Variant = null
	var blast_cells: Array = []
	if not _targets.is_empty():
		var target_id := String(_targets[_target_index])
		ring_cell = _view.cell(target_id)
		if _targeting_skill_id != "":
			var skill: Dictionary = _view.skill(_targeting_skill_id)
			var effect: Dictionary = skill.get("effect", {})
			var effect_type := String(effect.get("type", ""))
			if effect_type in ["icy_floor", "blast_damage"]:
				kind = "blast"
				blast_cells = _view.radius_area(ring_cell, int(effect.get("radius", 0)))
	var range_cells: Array = []
	if not is_self_cast:
		var effect2: Dictionary = {}
		if _targeting_skill_id != "":
			effect2 = (_view.skill(_targeting_skill_id) as Dictionary).get("effect", {}) as Dictionary
		var melee := _targeting_skill_id == "" or not effect2.has("range")
		var range_n := int((_view.combatant(me) as Dictionary).get("weapon_range", 1)) if melee else int(effect2.get("range", 0))
		if range_n > 0:
			range_cells = _view.radius_area(origin, range_n)
			range_cells.erase(origin)
	return {"kind": kind, "ring_cell": ring_cell, "range_cells": range_cells, "line_cells": [], "blast_cells": blast_cells}
