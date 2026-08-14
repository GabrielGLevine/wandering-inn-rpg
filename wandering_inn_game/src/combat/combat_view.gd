class_name WICombatView
extends RefCounted
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
var _display_names: Dictionary = {}


func _init(combat: WICombat) -> void:
	_combat = combat
	_display_names = _build_display_names()


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


static func _letter(i: int) -> String:
	return String.chr(65 + i) if i < 26 else str(i + 1)


## #460: the dedup map is built ONCE at combat start, and a summon can add the
## second body of a kind mid-fight -- without this the feed reads two identical
## "Bone Thrall"s and the player cannot tell which one fell. Re-derived rather
## than patched incrementally so the A/B lettering stays exactly the sorted-id
## assignment `_build_display_names` documents.
func refresh_names() -> void:
	_display_names = _build_display_names()


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


## GH#334 ruling 14: one-line passthrough to the sim's own once-per-fight
## refusal, so `combat_hud.skill_affordable` tests the SAME condition
## `WICombat.use_skill` refuses on rather than a second copy of it.
func skill_spent(id: String, skill_id: String) -> bool:
	return _combat.skill_spent(id, skill_id)


func line_cells(origin: Vector2i, dir: Vector2i, length: int) -> Array:
	return _combat.line_cells(origin, dir, length)


func alive_enemies_of(id: String) -> Array:
	return _combat.alive_enemies_of(id)


## Class-foundation pass R1 (2026-07-12), [Soothing Presence]'s ally-cycling
## target list -- the `alive_enemies_of` wrapper's own mirror, thin pass-
## through to `WICombat.alive_allies_of` (already exists, first consumer was
## combat_ai.gd's guard/coward profiles; `id` itself is excluded, same as
## that function's own contract).
func alive_allies_of(id: String) -> Array:
	return _combat.alive_allies_of(id)


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
