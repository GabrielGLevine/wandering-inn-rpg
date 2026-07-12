class_name WICombatView
extends RefCounted
## Thin read facade bounding combat-presentation reads of a live
## `WICombat`. Constructed fresh per encounter by `combat_screen.gd`'s
## `_show_combat()` (`_view = WICombatView.new(_combat())`) and handed down to
## `WICombatBoardRenderer.build()` plus whichever of the screen's own
## refresh-path functions were trivial to route through it this task (see the
## D2 task report for the exact coverage list -- some direct
## `combat.`/`Game.sim.combat` reads remain in combat_screen.gd, left for
## D3/D4's own extractions rather than balloon this task's diff).
##
## Every getter body below is the exact direct read the call site used to
## perform inline against `WICombat`, moved here VERBATIM -- no caching, no
## derived logic, no behavior change. `combatant()`/`blocked()`/`arena_id()`
## are not in the original task-doc interface list; they were added to give
## `WICombatBoardRenderer` (which the interface DOES require to route every
## sim read through this facade) a way to reach the handful of raw fields
## (`side`, `display_name`, the blocked-cell dict, the arena id) the
## enumerated getters don't individually expose, following the identical
## one-line-passthrough pattern as every other getter here.

var _combat: WICombat
## Issue #75 item 5b: id -> presentation LABEL, computed ONCE here (per-
## encounter "build time", matching `_view`'s own per-combat lifetime) so
## every combat-presentation surface that names a combatant (turn strip, feed
## lines, readout target line, friendly-fire line-skill preview) agrees. Sim
## state (`_combat.combatants[id]["display_name"]`) is left untouched by
## design -- wi_combat.gd's own doc comment on the same-catalog-id runtime-id
## suffix ("players see [name] twice, the suffix is internal bookkeeping
## only") is about the ID collision, not display text; this is the
## presentation-side fix for the TEXT half, kept out of sim per the sim-
## purity rule.
var _display_names: Dictionary = {}


func _init(combat: WICombat) -> void:
	_combat = combat
	_display_names = _build_display_names()


## Groups combatants by their raw `display_name`, then appends " A"/" B"/...
## to every group with more than one member (deterministic order: sorted by
## combatant id, the same stable tie-break `line_target_text()` already uses
## for its own name list). A roster with no duplicate name at all yields the
## identity mapping (every existing single-of-a-kind fight renders
## byte-identical text).
func _build_display_names() -> Dictionary:
	var groups: Dictionary = {}  # raw name -> Array[id], in sorted-id order
	var ids := _combat.combatants.keys()
	ids.sort()
	for id: String in ids:
		var name := String(_combat.combatants[id]["display_name"])
		var bucket: Array = groups.get(name, [])
		bucket.append(id)
		groups[name] = bucket
	var out := {}
	for name: String in groups:
		var bucket: Array = groups[name]
		if bucket.size() <= 1:
			out[bucket[0]] = name
		else:
			for i in bucket.size():
				out[bucket[i]] = "%s %s" % [name, _letter(i)]
	return out


## A/B/C.../Z, then falls back to a plain 1-based number past 26 (no shipped
## roster fields that many same-name combatants, but this keeps the mapping
## total instead of colliding on an out-of-range chr() call).
static func _letter(i: int) -> String:
	return String.chr(65 + i) if i < 26 else str(i + 1)


## The deduped presentation label for `id` -- every combat surface that shows
## a combatant's name reads through this instead of the raw
## `combatant(id)["display_name"]`, so a duplicate-name roster (e.g. two
## "Footpad"s) can never show the ambiguous text on one surface and the
## disambiguated one on another (issue #75 item 5b).
func display_name(id: String) -> String:
	if _display_names.has(id):
		return String(_display_names[id])
	return String(_combat.combatants.get(id, {}).get("display_name", id))


func stats(id: String) -> Dictionary:
	var c: Dictionary = _combat.combatants[id]
	return {
		"hp": int(c["hp"]), "max_hp": int(c["max_hp"]),
		"mp": int(c.get("mp", 0)), "max_mp": int(c.get("max_mp", 0)),
	}


func cell(id: String) -> Vector2i:
	return _combat.combatants[id]["cell"]


func alive(id: String) -> bool:
	return bool(_combat.combatants[id]["alive"])


func ids() -> Array:
	return _combat.combatants.keys()


func order() -> Array:
	return _combat.snapshot()["order"]


func active_id() -> String:
	return _combat.get_active()


func skill(skill_id: String) -> Dictionary:
	return _combat.skills[skill_id]


func effective_ap_cost(id: String, skill_id: String) -> int:
	return _combat.effective_ap_cost(_combat.combatants[id], _combat.skills[skill_id])


func line_cells(origin: Vector2i, dir: Vector2i, length: int) -> Array:
	return _combat.line_cells(origin, dir, length)


func alive_enemies_of(id: String) -> Array:
	return _combat.alive_enemies_of(id)


func is_adjacent(a: String, b: String) -> bool:
	return _combat.is_adjacent(a, b)


func chebyshev(a: String, b: String) -> int:
	return _combat.chebyshev(a, b)


func has_los(a: String, b: String) -> bool:
	return _combat.has_los(a, b)


func grid_size() -> Vector2i:
	return _combat.grid_size


func arena_config() -> Dictionary:
	return _combat.arena_config


## Full per-combatant dict (side/display_name/hp/mp/cell/skills/...) -- the
## board renderer's combatant-visual/label builders index straight into this
## the same way combat_screen.gd used to index `combat.combatants[id]`
## directly; see this file's doc comment for why this getter exists.
func combatant(id: String) -> Dictionary:
	return _combat.combatants[id]


func blocked() -> Dictionary:
	return _combat.blocked


func arena_id() -> String:
	return _combat.arena_id


## Issue #75 item 1: passthrough to `WISkillEffects._radius_area` -- the SAME
## Chebyshev-radius/wall-exclusion derivation icy_floor/blast_damage use to
## build their real terrain/hit area, so the aim-preview's blast footprint
## (and, centered on the ACTOR's own cell instead of a target's, its faint
## range-reach tint) can never disagree with what a confirmed cast would
## actually cover. `WISkillEffects` is a plain `class_name`, autoload-free,
## same as `WICombat` itself -- safe to reference directly from this file.
func radius_area(center: Vector2i, radius: int) -> Array:
	return WISkillEffects._radius_area(_combat, center, radius)
