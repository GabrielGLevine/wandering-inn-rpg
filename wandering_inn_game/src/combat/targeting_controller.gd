class_name WICombatTargeting
extends RefCounted
## The targeting-aim region, extracted from combat_screen.gd
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
## Issue #60 item 2: the line-skill direction picker's PER-COMBAT memory --
## the last direction a line skill was actually CAST (confirm()ed, not merely
## cycled to) this encounter, so re-entering line targeting (a second
## [Flame Jet] a few turns later) doesn't force the player back to "up"
## every time. Defaults to 0 ("up", LINE_DIRS' first entry) -- the pre-#60
## behavior for the FIRST line cast of a fight, unchanged. Deliberately an
## INSTANCE var, not persisted anywhere: `combat_screen.gd._show_combat()`
## constructs a brand new WICombatTargeting per encounter (this file's own
## doc comment above), so this naturally resets to 0 at combat start/a new
## encounter with zero extra reset code -- no hook needed in combat_screen.
var _last_line_dir_index := 0


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
		var skill_effect: Dictionary = skill.get("effect", {}) as Dictionary
		var effect_type := String(skill_effect.get("type", ""))
		_line_mode = effect_type == "line_damage"
		# A self-targeted active
		# move_pool_bonus cast (today only [Stealth]; MUST stay in lockstep with
		# skill_effects.gd's `resolve_active` -- same effect.type + ap_cost>0
		# pair gates its self-buff resolver there) needs no enemy at all.
		# Reuses the EXISTING `_targets`/`confirm()` plumbing verbatim (a
		# single-element list containing the actor's OWN id) instead of a new
		# targeting mode: Tab/cycle is a no-op on a 1-element list,
		# has_valid_target() reads true, and confirm() returns
		# `{"kind":"skill","target_id":me}` exactly like a real enemy pick --
		# `combat.use_skill(skill_id, me)` then dispatches into the self-buff
		# resolver, never the enemy-gated match.
		#
		# SAME plumbing, same
		# reasoning -- a heal cast needs no enemy either. SELF-ONLY tonight
		# (skill_effects.gd's `_resolve_heal` refuses any target_id other
		# than the actor's own; see its doc comment for the ally-targeting
		# follow-up this narrower gate defers) -- widen both together when
		# ally-targeting lands.
		# [Invisibility]'s combat read is
		# ALSO self-only (`_resolve_invisibility` never even looks at
		# target_id -- it is dispatched before resolve_active's target
		# lookup at all, same as move_pool_bonus), same plumbing again.
		var is_self_cast := (effect_type == "move_pool_bonus" and int(skill.get("ap_cost", 0)) > 0) \
				or effect_type == "heal" or effect_type == "invisibility"
		if not _line_mode and is_self_cast:
			_targets = [me]
			_target_index = 0
			_emit_targeting_shown(mode)
			return state()
	if _line_mode:
		# Issue #60 item 2: default to the last direction actually CAST this
		# combat (see `_last_line_dir_index`'s doc comment), not always "up".
		_line_dir_index = _last_line_dir_index
		_emit_targeting_shown(mode)
		return state()
	# Melee (Attack, skill_id == "") is filtered to adjacency first;
	# SKILL_TARGET is filtered by the skill's range (an unfiltered
	# out-of-range confirm would no-op in the sim with no event -- silent to
	# the player). The cycle then skips anyone without LoS -- if a filter
	# empties an otherwise-nonempty list, `state()`'s los_blocked/
	# out_of_range flags say which one, not just "no enemies at all".
	var effect: Dictionary = {}
	if _targeting_skill_id != "":
		effect = (_view.skill(_targeting_skill_id) as Dictionary).get("effect", {}) as Dictionary
	var spell_range := int(effect.get("range", 0))
	# A skill whose effect omits `range` entirely is a MELEE active (the
	# damage_mult techniques -- power_strike/quick_slash/flash_cut/etc; every
	# ranged type here -- spell_damage/icy_floor -- always declares `range` in
	# data/skills.json). `effect.get("range", 0)` alone can't distinguish
	# "no range field" from "explicit range: 0" (never authored, but the
	# distinction matters): check `effect.has("range")`, not just the
	# defaulted value. Without this, an out-of-adjacency damage_mult target
	# stayed in the candidate list -- skill_effects.gd's own `damage_mult` arm
	# refuses non-adjacent targets downstream (silently, no event, unlike
	# spell_damage's `no_los` refusal) -- so the UI could offer a target the
	# sim would quietly no-op on. Extends the SAME adjacency filter Attack
	# already used, rather than inventing a second gate.
	var melee := _targeting_skill_id == "" or not effect.has("range")
	# GH#70: the melee branch (Attack, or a damage_mult skill like
	# power_strike/Power Shot -- neither declares effect.range) is filtered
	# by the ACTOR own weapon range instead of bare adjacency. weapon_range
	# defaults to 1 (every pre-GH#70 weapon), so chebyshev > weapon_range is
	# byte-identical to the old not-is_adjacent check for every existing
	# build; a bow (range 4) widens the candidate list to match
	# WICombat.in_weapon_range exactly. has_los is still applied uniformly
	# below (unchanged) -- this only widens/narrows the DISTANCE half.
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


## Click-to-select (issue #57, controller ruling): re-points `_target_index`
## at whichever CURRENT candidate occupies `cell`, if any -- returns whether
## it found one (the caller only re-`_refresh()`es on a real change).
## Movement stays keys-only; this NEVER confirms the attack/skill itself,
## Tab/Enter still own cycling/confirming exactly as before. No-op (false)
## during line-mode (a direction, not a combatant, is being aimed) or an
## empty target list -- both already have nothing a click could select.
func select_at_cell(cell: Vector2i) -> bool:
	if _line_mode or _targets.is_empty():
		return false
	for i in _targets.size():
		if _view.cell(String(_targets[i])) == cell:
			_target_index = i
			return true
	return false


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
		# Bank the cast direction as this combat's new default (see
		# `_last_line_dir_index`'s doc comment) -- only on an actual confirm,
		# never on a bare cycle()/cancel(), so aiming around without firing
		# doesn't move the remembered direction.
		_last_line_dir_index = _line_dir_index
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
## raw `WICombat` param; `_grey` stays duplicated locally (see the file doc
## comment) but the BBCode escape calls `UIChrome.bb_escape` (promoted off
## a per-file copy here/journal.gd/combat_hud.gd -- the
## zero-cross-dependency idiom, amended for this one case: `UIChrome` is
## a plain `class_name` script, not one of this file's forbidden bare
## autoload identifiers, so this is not a new dependency risk for the
## --script-mode compile safety this file otherwise guards -- verified by
## running test_combat_visuals.gd, which load()s+instantiates this file
## directly).
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


## Board-space aim-preview derivation (issue #75 item 1) -- every cell
## returned here traces to a real sim read, so the paint `board_renderer.gd`
## draws from it can never lie:
##  - `line_cells`: `_view.line_cells()` verbatim, the exact cells a confirmed
##    line-skill cast will walk.
##  - `blast_cells`: `_view.radius_area()` (a passthrough to
##    `WISkillEffects._radius_area`), centered on the CURRENTLY SELECTED
##    candidate's cell -- the SAME function icy_floor/blast_damage use to
##    build their real area.
##  - `ring_cell`: the currently selected candidate's cell, drawn ONLY from
##    `_targets` -- a list `enter()` already filtered through
##    `_view.chebyshev`/weapon_range/`_view.has_los` above, so the ring can
##    never mark a cell the sim itself wouldn't also honor as a legal target.
##  - `range_cells`: the one approximate piece -- also `_view.radius_area()`,
##    but around the ACTOR's own cell at the actor's weapon/skill range. Like
##    every other `_radius_area` caller (icy_floor/blast_damage's own hit
##    area), this is a flat Chebyshev clip, not per-empty-cell wall
##    shadow-casting -- it can never disagree with the sim about REACH
##    (distance + blocked-cell exclusion), only about whether one specific
##    far cell is independently walled off, the same disclosed limitation
##    `_radius_area`'s own doc comment already carries. Excluded for a
##    self-only cast (heal/invisibility/sneak-class skills): there is nothing
##    to "reach", the target is fixed to the caster.
## Called every `combat_screen.gd._refresh()` while ATTACK/SKILL_TARGET is
## armed; callers clear the paint (`board_renderer.clear_aim_preview()`)
## whenever this isn't -- see that file's own doc comment.
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
