class_name WIProgression
extends RefCounted
## Pure, data-driven progression checks over classes.json. No autoload/Node/
## scene-tree references. Level-ups are evaluated ONLY at the sleep beat
## (canon: characters level when they sleep) — callers enforce the when,
## this class answers the what.


## Resolves one class's own level-grants at `held` level into `out`
## (catalog order, ascending level order within the class), deduped.
static func _own_grants_at_level(cls: Dictionary, held: int, out: Array) -> void:
	for lv: Dictionary in cls.get("levels", []):
		if int(lv["level"]) <= held:
			for sk: Variant in lv.get("grants", []):
				if not out.has(String(sk)):
					out.append(String(sk))


## Folds the FULL granted kit of every ancestor named in `cls`'s `inherits`
## field (string or list) into `out`, each ancestor evaluated as if held at
## `held` (the child's own level) -- spec §2.6 ⟦B5⟧: a [Swordsman] 12 still
## carries the [Warrior] kit it grew out of. Recurses through multi-level
## inherits chains. `visited` cycle-guards a hand-built (or malformed)
## catalog where classes transitively inherit themselves -- an already-
## visited ancestor id is skipped rather than re-descended, so a cycle
## terminates with a finite (if incomplete) result instead of hanging.
static func _collect_inherited(cls: Dictionary, held: int, catalog_by_id: Dictionary, out: Array, visited: Dictionary) -> void:
	var inherits_raw: Variant = cls.get("inherits")
	if inherits_raw == null:
		return
	var parent_ids: Array = []
	if inherits_raw is Array:
		for p: Variant in inherits_raw:
			parent_ids.append(String(p))
	else:
		parent_ids.append(String(inherits_raw))
	for parent_id: String in parent_ids:
		if visited.has(parent_id):
			continue
		visited[parent_id] = true
		if not catalog_by_id.has(parent_id):
			continue
		var parent_cls: Dictionary = catalog_by_id[parent_id]
		_own_grants_at_level(parent_cls, held, out)
		_collect_inherited(parent_cls, held, catalog_by_id, out, visited)


## Non-linear multiclass scaling (spec §2.4 REV 2). A held-class level
## distribution's raw combat "power" is a generalized (Minkowski-style) power
## mean over the held levels: `(Σ_i L_i^k)^(1/k)`. For a SINGLE held class
## this collapses to exactly that class's own level (L^k)^(1/k) == L, so a
## focused build is unaffected. For a SPLIT across multiple classes it is
## strictly less than the arithmetic sum of levels (k > 1), which is what
## makes multiclassing cost something. `k` is read from
## `class_catalog.meta.power_k` (pinned in data/classes.json; default 1.55
## matches the shipped value so a hand-built test catalog omitting `meta`
## still behaves sanely). Empty `classes` -> 0.0 (no levels held, no power).
static func effective_power(classes: Dictionary, class_catalog: Dictionary) -> float:
	var k: float = float(class_catalog.get("meta", {}).get("power_k", 1.55))
	var sum := 0.0
	for held: Variant in classes.values():
		sum += pow(float(held), k)
	if sum <= 0.0:
		return 0.0
	return pow(sum, 1.0 / k)


## The SPLIT-PENALTY multiplier applied to a PC's combat-relevant stats
## (spec §2.4 REV 2): `effective_power(classes) / Σ_i L_i`. Exactly `1.0` for
## any single-class or otherwise "focused" level distribution (no penalty) —
## it only drops below 1.0 once levels are split across more than one class.
## `minf(1.0, ...)` is a safety clamp against float drift; the ratio can never
## exceed 1.0 by construction. Empty `classes` -> 1.0 (no levels, no penalty,
## and no divide-by-zero).
static func power_multiplier(classes: Dictionary, class_catalog: Dictionary) -> float:
	var total := 0
	for held: Variant in classes.values():
		total += int(held)
	if total <= 0:
		return 1.0
	return minf(1.0, effective_power(classes, class_catalog) / float(total))


## Additive per-class stat growth, scaled by split-efficiency (spec §2.4
## REVISION 2026-07-03: leveling a class grows THAT class's relevant combat
## stats, with `power_multiplier` acting as friction on split builds rather
## than a blanket scalar). For each held class, `stat_growth[S] * L_c` is
## summed per stat S across ALL held classes, THEN multiplied once by
## `efficiency` (`power_multiplier`, unchanged from T4) and rounded ONCE per
## stat -- efficiency sits OUTSIDE the per-class sum, never applied per-class.
## A focused build (efficiency == 1.0) yields the full undiminished bonus. A
## class missing `stat_growth` (or an empty catalog) contributes zero growth,
## never a crash. Empty `classes` -> every stat 0.
static func derived_stat_bonuses(classes: Dictionary, class_catalog: Dictionary) -> Dictionary:
	var raw: Dictionary = {"str": 0.0, "dex": 0.0, "con": 0.0, "int": 0.0}
	for cls: Dictionary in class_catalog.get("classes", []):
		var id := String(cls[WIKeys.ID])
		var held := int(classes.get(id, 0))
		if held <= 0:
			continue
		var growth: Dictionary = cls.get("stat_growth", {})
		for stat_key: String in growth:
			raw[stat_key] = float(raw.get(stat_key, 0.0)) + float(growth[stat_key]) * float(held)
	var efficiency := power_multiplier(classes, class_catalog)
	var out: Dictionary = {}
	for stat_key: String in raw:
		out[stat_key] = int(round(raw[stat_key] * efficiency))
	return out


## Shared application path (T4b): adds `derived_stat_bonuses(classes, ...)` to
## `base_stats`, returning a NEW dictionary (the input is never mutated).
## `wi_game.gd`'s `_build_player_combatant` and `tests/sim_combat_batch.gd`'s
## harness both call this so PC combat stats are built by exactly one code
## path, never a copy-paste mirror (T4's review flag).
static func apply_stat_bonuses(base_stats: Dictionary, classes: Dictionary, class_catalog: Dictionary) -> Dictionary:
	var bonuses := derived_stat_bonuses(classes, class_catalog)
	var out: Dictionary = base_stats.duplicate()
	for stat_key: String in bonuses:
		out[stat_key] = int(out.get(stat_key, 0)) + int(bonuses[stat_key])
	return out


static func granted_skills(classes: Dictionary, class_catalog: Dictionary, generalist_classes: Array = []) -> Array:
	var out: Array = []
	var catalog_by_id: Dictionary = {}
	for cls: Dictionary in class_catalog.get("classes", []):
		catalog_by_id[String(cls[WIKeys.ID])] = cls
	for cls: Dictionary in class_catalog.get("classes", []):
		var id := String(cls[WIKeys.ID])
		var held := int(classes.get(id, 0))
		_own_grants_at_level(cls, held, out)
		if held > 0:
			_collect_inherited(cls, held, catalog_by_id, out, {id: true})
			# Generalist evolution: a class that took the balanced-mastery path
			# fields its `evolution.balanced_grants`. The combat kit is built
			# ONLY from granted_skills, so these flow through HERE (the single
			# kit source) rather than player_skills -- mirroring how the
			# Replacement path relies on the new class's own grants.
			if generalist_classes.has(id):
				for sk: Variant in (cls.get("evolution", {}) as Dictionary).get("balanced_grants", []):
					var sk_id := String(sk)
					if not out.has(sk_id):
						out.append(sk_id)
	return out


## Returns ids of classes whose gained_by condition is met and which are not
## already held. Classes with no gained_by field are never returned here --
## earning them requires already holding them (see check_level_ups instead).
static func check_class_gains(classes: Dictionary, accomplishments: Dictionary, class_catalog: Dictionary) -> Array:
	var gains: Array = []
	for cls: Dictionary in class_catalog.get("classes", []):
		var id := String(cls[WIKeys.ID])
		if classes.has(id) or not cls.has("gained_by"):
			continue
		# A gained_by with no accomplishment requirements would otherwise be
		# vacuously met and granted to everyone at the first sleep beat.
		var reqs: Dictionary = (cls["gained_by"] as Dictionary).get("accomplishment", {})
		if reqs.is_empty():
			continue
		var met := true
		for req_id: String in reqs:
			if int(accomplishments.get(req_id, 0)) < int(cls["gained_by"]["accomplishment"][req_id]):
				met = false
				break
		if met:
			gains.append(id)
	return gains


## Returns every level-up earned by the held classes, in resolution order:
## catalog class order, then ascending level. Requirements are cumulative
## accomplishment-counter thresholds evaluated by _level_met, and the walk is
## consecutive per class — one sleep resolves ALL earned levels (spec §2.2
## REV 2 multi-level sleeps), but an unmet level blocks everything above it
## (no level skipping). Each entry is {class, level, grants}.
static func check_level_ups(classes: Dictionary, accomplishments: Dictionary, class_catalog: Dictionary) -> Array:
	var gains: Array = []
	for cls: Dictionary in class_catalog.get("classes", []):
		var id := String(cls[WIKeys.ID])
		if not classes.has(id):
			continue
		var by_level: Dictionary = {}
		for lv: Dictionary in cls.get("levels", []):
			by_level[int(lv["level"])] = lv
		var next := int(classes[id]) + 1
		while by_level.has(next) and _level_met(by_level[next], accomplishments):
			var lv: Dictionary = by_level[next]
			gains.append({"class": id, "level": next, "grants": (lv.get("grants", []) as Array).duplicate()})
			next += 1
	return gains


## Evaluates one level entry's requirement block against the accomplishment
## counters. `requires` needs ALL keyed counters at threshold; `requires_any`
## needs ANY one (either-parent leveling — spellsword's canon rule, spec
## §2.5). Both styles coexist in classes.json until T9 unifies content. A
## level carrying neither key (or an empty `requires`) is unconditionally
## met, matching the pre-M6 convention for level-1 entries; an empty
## `requires_any` is NOT met (an OR over nothing is false — this is the
## guard against the free-level hazard T6 flagged).
static func _level_met(lv: Dictionary, accomplishments: Dictionary) -> bool:
	if lv.has("requires_any"):
		var any_reqs: Dictionary = lv["requires_any"]
		for req_id: String in any_reqs:
			if int(accomplishments.get(req_id, 0)) >= int(any_reqs[req_id]):
				return true
		return false
	var reqs: Dictionary = lv.get("requires", {})
	for req_id: String in reqs:
		if int(accomplishments.get(req_id, 0)) < int(reqs[req_id]):
			return false
	return true


## Returns the evolution OUTCOMES to apply this sleep beat, in catalog class
## order (spec §2.3 REV 2). Evaluated per held class that carries an
## `evolution` block; evolved/inherited classes (ice_mage, swordsman, ...)
## have no such block and are never considered here -- they are naturally
## capped by content, not by this function. Three outcome shapes:
##   Replacement:       {class, to, level, off_interval}
##   Generalist grant:  {class, generalist: true, grants}
##   At-cap / waiting:  {class, waiting: true}
## A class already in `generalist_classes` is skipped entirely (no outcome
## at all) -- taking the generalist path locks that class's identity for
## good, so there is nothing left to decide for it, ever again.
static func check_evolutions(classes: Dictionary, accomplishments: Dictionary, class_catalog: Dictionary, generalist_classes: Array) -> Array:
	var out: Array = []
	for cls: Dictionary in class_catalog.get("classes", []):
		var id := String(cls[WIKeys.ID])
		if not classes.has(id) or not cls.has("evolution"):
			continue
		if generalist_classes.has(id):
			continue
		var held := int(classes[id])
		var evo: Dictionary = cls["evolution"]
		if held < int(evo.get("at_level", 0)):
			continue
		var targets: Dictionary = evo.get("targets", {})
		var target_keys: Array = targets.keys()
		target_keys.sort()
		var counts: Dictionary = {}
		var total := 0
		for key: String in target_keys:
			var c := int(accomplishments.get(key, 0))
			counts[key] = c
			total += c
		if total < int(evo.get("min_uses", 0)):
			out.append({"class": id, "waiting": true})
			continue
		var top_key := ""
		var top_count := -1
		var tie := false
		for key: String in target_keys:
			var c: int = counts[key]
			if c > top_count:
				top_count = c
				top_key = key
				tie = false
			elif c == top_count:
				tie = true
		var share := float(top_count) / float(total) if total > 0 else 0.0
		if not tie and share >= float(evo.get("dominance_share", 1.0)):
			out.append({"class": id, "to": String(targets[top_key]), "level": held, "off_interval": held >= 12})
		elif evo.has("balanced_grants"):
			out.append({"class": id, "generalist": true, "grants": (evo["balanced_grants"] as Array).duplicate()})
		else:
			out.append({"class": id, "waiting": true})
	return out


## Finds the BEST held class id that satisfies `line` (a parent-line Array of
## ids from `consolidations[].parent_lines`, base id first then evolution
## targets in canon order) -- spec §2.5 ⟦I7⟧: evolved classes remain valid
## parents, so [Swordsman] (an evolution target of the warrior line) still
## counts as the warrior parent. "Best" means highest held level: normal play
## never holds two ids from the same line at once (evolution erases the base
## id when it replaces it), but picking the max rather than the first-listed
## id keeps this pure function correct and deterministic even against a
## hand-built or corrupted `classes` dict that does hold more than one.
## Returns "" if none of that line's ids are held.
static func _held_line_candidate(classes: Dictionary, line: Array) -> String:
	var best_id := ""
	var best_level := -1
	for id: Variant in line:
		var id_str := String(id)
		if classes.has(id_str) and int(classes[id_str]) > best_level:
			best_id = id_str
			best_level = int(classes[id_str])
	return best_id


## The merge math (spec §2.5 REV 2, INTEGER arithmetic only -- never a 0.67
## float ceil, which the REV 1 pinned test got arithmetically wrong):
## `max(ceil(2*(L_a+L_b)/3), max(L_a, L_b))`. The max() clamp guarantees the
## merged level never drops below the higher parent (20+8 would otherwise
## floor to 19, worse than staying pure-20).
static func _consolidation_merged_level(level_a: int, level_b: int) -> int:
	var sum := level_a + level_b
	var two_thirds := (2 * sum + 2) / 3  # integer ceil(2*sum/3)
	return maxi(two_thirds, maxi(level_a, level_b))


## Returns the consolidation OFFER for the held `classes`, or an empty
## Dictionary when none qualifies (spec §2.5 REV 2). Reads
## `class_catalog.consolidations` (CONTENT-owned data; entries carry
## `parent_lines`: two Arrays of class ids, each line's base id followed by
## its evolution targets in canon order -- ⟦I7⟧ lineage). Each line's
## qualifying candidate is whichever of its ids is held (see
## `_held_line_candidate`); the offer fires only when BOTH lines have a
## candidate AND that candidate's level is >= `min_parent_level` for both AND
## their combined level >= `min_combined_level` (all thresholds data-tunable,
## never sim literals). `parents` in the returned Dictionary carries the
## actually-HELD ids (which may be evolved targets, not the line's base id)
## so the caller can erase exactly what the player holds. Pure function of
## `classes` -- does not care whether the target class is already held or
## whatever else is going on; the sleep beat is responsible for not
## re-offering once accept_consolidation has fired.
static func check_consolidation(classes: Dictionary, class_catalog: Dictionary) -> Dictionary:
	for entry: Dictionary in class_catalog.get("consolidations", []):
		var lines: Array = entry.get("parent_lines", [])
		if lines.size() != 2:
			continue
		var min_parent_level := int(entry.get("min_parent_level", 0))
		var min_combined_level := int(entry.get("min_combined_level", 0))
		var id_a := _held_line_candidate(classes, lines[0])
		var id_b := _held_line_candidate(classes, lines[1])
		if id_a == "" or id_b == "":
			continue
		var level_a := int(classes[id_a])
		var level_b := int(classes[id_b])
		if level_a < min_parent_level or level_b < min_parent_level:
			continue
		if level_a + level_b < min_combined_level:
			continue
		return {
			"parents": [id_a, id_b],
			"target": String(entry["target"]),
			"level": _consolidation_merged_level(level_a, level_b),
		}
	return {}
