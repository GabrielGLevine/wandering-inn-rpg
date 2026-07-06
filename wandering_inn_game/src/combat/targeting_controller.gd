class_name WICombatTargeting
extends RefCounted
## M6.5 D4 extraction: the targeting-aim region MOVED out of combat_screen.gd
## -- filtering reachable targets (adjacency for Attack, range+LoS for a
## skill), the four cardinal line-skill directions, and the friendly-fire
## preview text for a line skill. Constructed FRESH per encounter by
## `combat_screen.gd._show_combat()` (`_targeting = load(...).new(_view, self)`),
## mirroring `_view`'s own per-combat lifetime -- this is NOT a `_ready()`-time
## singleton like `_board_renderer`/`_ai_playback`/`_hud`, because a target
## list is meaningless across encounters and `_view` itself is rebuilt fresh
## each combat (a targeting object bound to a stale `_view` would silently
## keep operating on a torn-down `WICombat` from a PREVIOUS fight).
##
## `enter()`/`cycle()`/`confirm()`/`cancel()`/`state()` mirror the plan's
## interface; `confirm()` RETURNS the chosen action -- the SCREEN (composition
## root) executes it on `combat` via the existing `attack()`/`use_skill()`
## calls, so the command surface stays exactly the 4 combat calls (mandate).
##
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
##
## `_view`/`_screen` are loosely typed (`RefCounted`/`Node`, not
## `WICombatView`/the screen's own class), matching the established
## `--script`-mode compile-safety idiom documented on combat_screen.gd's own
## `_board_renderer`/`_view`/`_ai_playback` vars and combat_playback.gd's doc
## comment: `tests/test_combat_visuals.gd` recompiles a stubbed in-memory copy
## of combat_screen.gd where autoload identifiers don't resolve, and a hard
## type annotation on the screen referencing this class would force that
## compile to also resolve this file's body.
##
## This file carries ZERO bare autoload identifiers (`ObservableBus`/`Game`/
## `TestDriver`/`WIAudio` -- the only 4 real autoloads in this project, per
## project.godot; `WIEvents`/`WICombat` etc. are plain `class_name` scripts
## and resolve fine anywhere) -- same reasoning as combat_playback.gd, kept
## as a future-proofing match to the established idiom even though no compat
## shim in tests/test_combat_visuals.gd currently forces a lazy load() of
## this file mid-test (grepped: no targeting function/var name appears
## anywhere in that test). The one UI_TARGETING_SHOWN emission routes through
## `_screen._emit_targeting_shown_event(...)` instead.

const LINE_DIRS := ["up", "down", "left", "right"]
const LINE_DIR_VECTORS := {
	"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT,
}
## Matches combat_screen.gd's / src/ui/dialogue_panel.gd's LOCKED_COLOR --
## duplicated locally (trivial, zero autoload dependency) purely so
## `line_target_text()`'s friendly-fire preview doesn't need a HUD reference
## just for one color format call. See combat_hud.gd's own copy.
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


func _init(view: RefCounted, screen: Node) -> void:
	_view = view
	_screen = screen


## Verbatim move of `_enter_targeting`'s target-filtering logic (the
## `mode == Mode.SKILL_TARGET`/`Mode.ATTACK` comparisons replaced by the
## skill_id-empty substitution -- see the file doc comment). Does NOT set the
## screen's mode FSM (the caller does that -- mode ownership stays on the
## screen); emits UI_TARGETING_SHOWN via the screen wrapper exactly as
## `_emit_targeting_shown` used to, then returns `state()`.
func enter(mode: int, skill_id: String = "") -> Dictionary:
	var me: String = _view.active_id()
	_targets = []
	_targets_los_blocked = false
	_line_mode = false
	_targeting_skill_id = ""
	if skill_id != "":
		_targeting_skill_id = skill_id
		var skill: Dictionary = _view.skill(_targeting_skill_id)
		_line_mode = String((skill.get("effect", {}) as Dictionary).get("type", "")) == "line_damage"
	if _line_mode:
		_line_dir_index = 0
		_emit_targeting_shown(mode)
		return state()
	# Melee (Attack, skill_id == "") is filtered to adjacency first;
	# SKILL_TARGET is filtered by the skill's range (an unfiltered
	# out-of-range confirm would no-op in the sim with no event -- silent to
	# the player). The cycle then skips anyone without LoS -- if a filter
	# empties an otherwise-nonempty list, `state()`'s los_blocked/
	# out_of_range flags say which one, not just "no enemies at all".
	var spell_range := 0
	if _targeting_skill_id != "":
		spell_range = int(((_view.skill(_targeting_skill_id) as Dictionary).get("effect", {}) as Dictionary).get("range", 0))
	var in_range: Array = []
	for foe: String in _view.alive_enemies_of(me):
		if _targeting_skill_id == "" and not _view.is_adjacent(me, foe):
			continue
		if spell_range > 0 and _view.chebyshev(me, foe) > spell_range:
			continue
		in_range.append(foe)
	for foe: String in in_range:
		if _view.has_los(me, foe):
			_targets.append(foe)
	_targets_los_blocked = not in_range.is_empty() and _targets.is_empty()
	_targets_out_of_range = in_range.is_empty() and spell_range > 0 \
			and not _view.alive_enemies_of(me).is_empty()
	_target_index = 0
	_emit_targeting_shown(mode)
	return state()


## QA-visible confirmation that targeting opened (moved verbatim from
## `_emit_targeting_shown`; the "attack"/"skill" text used to compare against
## `Mode.ATTACK` directly -- now the skill_id-empty substitution, see the file
## doc comment). Routed through `_screen`'s wrapper so this file can stay free
## of a bare `ObservableBus` reference.
func _emit_targeting_shown(mode: int) -> void:
	_screen._emit_targeting_shown_event(
		"attack" if _targeting_skill_id == "" else "skill", _targeting_skill_id, _targets.size()
	)


## Cycles the aimed target (or line direction, while `_line_mode`) by `delta`
## -- the screen's Tab handler always passes `1`; `wrapi` generalizes the
## original's unconditional `% size` (identical result for delta == 1, safe
## for any delta).
func cycle(delta: int) -> void:
	if _line_mode:
		_line_dir_index = wrapi(_line_dir_index + delta, 0, LINE_DIRS.size())
	elif not _targets.is_empty():
		_target_index = wrapi(_target_index + delta, 0, _targets.size())


## Whether Tab/Enter currently have a valid target to act on -- the exact
## gate `_input_target` used inline: `(_line_mode or not _targets.is_empty())`.
func has_valid_target() -> bool:
	return _line_mode or not _targets.is_empty()


## Returns the action for the SCREEN to execute on `combat` (command surface
## stays at the composition root, per the plan). `kind` is "attack" (no
## skill_id -- the `_targeting_skill_id == ""` substitution again),
## "line_skill" (skill_id + a cardinal direction token), or "skill" (skill_id
## + a target id) -- exactly the three branches `_input_target`'s confirm arm
## used to dispatch inline.
func confirm() -> Dictionary:
	if _targeting_skill_id == "":
		return {"kind": "attack", "target_id": String(_targets[_target_index])}
	if _line_mode:
		return {"kind": "line_skill", "skill_id": _targeting_skill_id, "direction": String(LINE_DIRS[_line_dir_index])}
	return {"kind": "skill", "skill_id": _targeting_skill_id, "target_id": String(_targets[_target_index])}


## The original `_input_target`'s cancel branch never touched any targeting
## var (only the screen's `_mode`/`_bar_index`) -- `enter()` fully
## re-initializes every var below on the next aim anyway, so clearing here is
## pure hygiene, not a behavior requirement.
func cancel() -> void:
	_targets = []
	_target_index = 0
	_targets_los_blocked = false
	_targets_out_of_range = false
	_line_mode = false
	_targeting_skill_id = ""


## `{targets, index, line_mode, line_dir, skill_id, los_blocked,
## out_of_range}` -- the HUD's readout renders from this (plus a `line_text`
## key the screen stashes on top via `line_target_text()` when `line_mode` is
## true -- see combat_screen.gd's `_refresh()`).
func state() -> Dictionary:
	return {
		"targets": _targets, "index": _target_index, "line_mode": _line_mode,
		"line_dir": _line_dir_index, "skill_id": _targeting_skill_id,
		"los_blocked": _targets_los_blocked, "out_of_range": _targets_out_of_range,
	}


## Verbatim move of `_line_target_text`, reading through `_view` instead of a
## raw `WICombat` param; `_bb_escape`/`_grey` are duplicated locally (see the
## file doc comment) rather than reaching into `WICombatHud` for them.
func line_target_text() -> String:
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
				var nm := _bb_escape(String(occ["display_name"]))
				if String(occ["side"]) == my_side:
					nm = _grey(nm)
				names.append(nm)
	var hits_text := ", ".join(names) if not names.is_empty() else "(none)"
	return "Direction: %s (Tab cycles, Enter confirms)\nHits: %s" % [dir_token.capitalize(), hits_text]


## BBCode-escapes literal `[`/`]`. MUST route through placeholder chars: the
## naive two-step `.replace("[", "[lb]").replace("]", "[rb]")` chain is
## self-colliding — the first replace's own output ("[lb]") contains a "]"
## the second replace then re-matches, garbling any bracketed name (UI wave
## review fix; latent here today — no combatant display_name carries
## brackets — but real the moment one does). Identical fixed copy in
## journal.gd / combat_hud.gd — tiny pure helper, deliberately duplicated
## per file (M6.5 idiom: keeps each component's zero-cross-dependency
## load() story); keep all three in sync.
func _bb_escape(s: String) -> String:
	var placeholder_open := char(1)
	var placeholder_close := char(2)
	return s.replace("[", placeholder_open).replace("]", placeholder_close) \
			.replace(placeholder_open, "[lb]").replace(placeholder_close, "[rb]")


func _grey(text: String) -> String:
	return "[color=#%s]%s[/color]" % [LOCKED_COLOR.to_html(false), text]
