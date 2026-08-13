class_name WIProgression
extends RefCounted


static func _own_grants_at_level(cls: Dictionary, held: int, out: Array) -> void:
	for lv: Dictionary in cls.get("levels", []):
		if int(lv["level"]) <= held:
			for sk: Variant in lv.get("grants", []):
				if not out.has(String(sk)):
					out.append(String(sk))


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


static func effective_power(classes: Dictionary, class_catalog: Dictionary) -> float:
	var k: float = float(class_catalog.get("meta", {}).get("power_k", 1.55))
	var sum := 0.0
	for held: Variant in classes.values():
		sum += pow(float(held), k)
	if sum <= 0.0:
		return 0.0
	return pow(sum, 1.0 / k)


static func power_multiplier(classes: Dictionary, class_catalog: Dictionary) -> float:
	var total := 0
	for held: Variant in classes.values():
		total += int(held)
	if total <= 0:
		return 1.0
	return minf(1.0, effective_power(classes, class_catalog) / float(total))


## Issue #163: player rank for scaled Guild bounties, DERIVED from
## effective_power's OWN math (never hardcoded level ints). Boundaries:
## bronze below a single L10 line's power (== 10.0 by construction), silver
## below the power of a two-L10-line build -- the spec's "14-equivalent
## consolidation" (two L10 lines merge to L14 via the consolidation formula
## max(ceil(2*(10+10)/3),10)==14; that build's UN-consolidated power is
## 10*2^(1/power_k)), gold at or above. Both edges pinned in test_progression.
static func power_rank(classes: Dictionary, class_catalog: Dictionary) -> String:
	var power := effective_power(classes, class_catalog)
	if power < silver_power_floor(class_catalog):
		return "bronze"
	if power < gold_power_floor(class_catalog):
		return "silver"
	return "gold"


static func silver_power_floor(class_catalog: Dictionary) -> float:
	return effective_power({"_l10_line": 10}, class_catalog)


static func gold_power_floor(class_catalog: Dictionary) -> float:
	return effective_power({"_l10_a": 10, "_l10_b": 10}, class_catalog)


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
			if generalist_classes.has(id):
				for sk: Variant in (cls.get("evolution", {}) as Dictionary).get("balanced_grants", []):
					var sk_id := String(sk)
					if not out.has(sk_id):
						out.append(sk_id)
	return out


static func _retired_class_ids(classes: Dictionary, class_catalog: Dictionary) -> Dictionary:
	var retired: Dictionary = {}
	for entry: Dictionary in class_catalog.get("consolidations", []):
		if not classes.has(String(entry.get("target", ""))):
			continue
		for line: Variant in entry.get("parent_lines", []):
			for id: Variant in (line as Array):
				retired[String(id)] = true
	for cls: Dictionary in class_catalog.get("classes", []):
		var targets: Dictionary = (cls.get("evolution", {}) as Dictionary).get("targets", {})
		for key: String in targets:
			if classes.has(String(targets[key])):
				retired[String(cls[WIKeys.ID])] = true
				break
	return retired


static func check_class_gains(classes: Dictionary, accomplishments: Dictionary, class_catalog: Dictionary) -> Array:
	var gains: Array = []
	var retired := _retired_class_ids(classes, class_catalog)
	for cls: Dictionary in class_catalog.get("classes", []):
		var id := String(cls[WIKeys.ID])
		if classes.has(id) or retired.has(id) or not cls.has("gained_by"):
			continue
		# #453 G2 (user ruling 2026-08-13): `accomplishment_any` is the ENTRY-side
		# twin of `_level_met`'s `requires_any`, and carries that function's exact
		# contract: ANY key clearing its threshold is enough, and an EMPTY dict is
		# never met (the free-class guard, mirroring the free-level guard). It is
		# checked FIRST and is exclusive with `accomplishment` -- a class authors
		# one or the other, never both, so no shipped `gained_by` changes meaning.
		# Shipped case: [Rogue] is earnable either by the Liscor crate job or by
		# crossing the gate-road ambush under cover in Act I.
		var any_reqs: Dictionary = (cls["gained_by"] as Dictionary).get("accomplishment_any", {})
		if not any_reqs.is_empty():
			for req_id: String in any_reqs:
				if int(accomplishments.get(req_id, 0)) >= int(any_reqs[req_id]):
					gains.append(id)
					break
			continue
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


## Every held id that can stand for `line`, level-DESC (ties keep authored
## order). Index 0 is the old `_held_line_candidate` answer, so any row whose
## two lists disagree at index 0 resolves byte-identically to the pre-#472
## reader; the tail exists only for the one case that reader could not express
## -- both lines wanting the SAME held class.
static func _line_candidates(classes: Dictionary, line: Array, class_catalog: Dictionary) -> Array:
	var found: Array = []
	for id: Variant in line:
		var id_str := String(id)
		if classes.has(id_str) and not found.has(id_str):
			found.append(id_str)
	for proxy_id: String in _lineage_proxies(classes, line, class_catalog):
		if not found.has(proxy_id):
			found.append(proxy_id)
	found.sort_custom(func(a: String, b: String) -> bool: return int(classes[a]) > int(classes[b]))
	return found


## #472 LINEAGE PROXY. A held consolidated class stands in for either parent
## line its OWN row consumed, AT ITS CURRENT LEVEL (the class kept climbing, so
## the lineage climbed with it) -- so [Spellsword] 16 + ice_mage 10 clears a
## warrior-line x ice_mage row.
## CONTAINMENT DIRECTION IS LOAD-BEARING: the proxy's own line must be a SUBSET
## of the line being asked for, never the reverse. [Spellspear] (own line
## `[spearmaster]`) satisfies a broad warrior line that lists spearmaster;
## a [Spellsword] built off plain [Warrior] must NOT satisfy [Spellspear]'s
## narrower `[spearmaster]` line. Reversing it hands spear-less builds the
## evolved-lineage targets, which is exactly the orphaning #449 closed.
static func _lineage_proxies(classes: Dictionary, line: Array, class_catalog: Dictionary) -> Array:
	var asked: Dictionary = {}
	for id: Variant in line:
		asked[String(id)] = true
	var out: Array = []
	for entry: Dictionary in class_catalog.get("consolidations", []):
		var target := String(entry.get("target", ""))
		if target == "" or not classes.has(target):
			continue
		var lines: Array = entry.get("parent_lines", [])
		if lines.size() != 2:
			continue
		for side: Variant in lines:
			var covered := true
			for id: Variant in (side as Array):
				if not asked.has(String(id)):
					covered = false
					break
			if covered and not out.has(target):
				out.append(target)
	return out


## Optional `upgrades: {old_skill_id: new_skill_id}` on a consolidations row --
## the no-Skill-loss escape hatch for a parent grant the target replaces with a
## strictly better [Skill] instead of re-granting verbatim. data_lint's coverage
## arm validates every pair is cost/effect-dominant; this is the runtime half
## that rewrites what the player already holds.
static func consolidation_upgrades(target_id: String, class_catalog: Dictionary) -> Dictionary:
	for entry: Dictionary in class_catalog.get("consolidations", []):
		if String(entry.get("target", "")) != target_id:
			continue
		var raw: Variant = entry.get("upgrades", {})
		if raw is Dictionary:
			return (raw as Dictionary).duplicate(true)
	return {}


static func _consolidation_merged_level(level_a: int, level_b: int) -> int:
	var sum := level_a + level_b
	var two_thirds := (2 * sum + 2) / 3  # integer ceil(2*sum/3)
	return maxi(two_thirds, maxi(level_a, level_b))


static func check_consolidation(classes: Dictionary, class_catalog: Dictionary) -> Dictionary:
	for entry: Dictionary in class_catalog.get("consolidations", []):
		var lines: Array = entry.get("parent_lines", [])
		if lines.size() != 2:
			continue
		var min_parent_level := int(entry.get("min_parent_level", 0))
		var min_combined_level := int(entry.get("min_combined_level", 0))
		if classes.has(String(entry.get("target", ""))):
			continue
		var cands_a := _line_candidates(classes, lines[0], class_catalog)
		var cands_b := _line_candidates(classes, lines[1], class_catalog)
		# ONE held class can proxy BOTH sides of its own row ([Spellsword]
		# covers the warrior line and the mage line alike), which would read as
		# a class merging with itself. First distinct pair, both lists already
		# level-DESC, so shipped single-candidate rows resolve exactly as before.
		var id_a := ""
		var id_b := ""
		for a: String in cands_a:
			for b: String in cands_b:
				if a == b:
					continue
				id_a = a
				id_b = b
				break
			if id_a != "":
				break
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
