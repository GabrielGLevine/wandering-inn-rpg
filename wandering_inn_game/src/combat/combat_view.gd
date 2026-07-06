class_name WICombatView
extends RefCounted
## M6.5 D2: thin read facade bounding combat-presentation reads of a live
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


func _init(combat: WICombat) -> void:
	_combat = combat


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
