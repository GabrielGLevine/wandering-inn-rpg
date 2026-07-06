class_name WIActs
extends RefCounted
## Pure act-line derivation (M-ARC Task A1). The CURRENT act is a FUNCTION of
## counters the save already holds -- never stored, so old saves land mid-act
## correctly by construction. Mirrors the WIQuests pure-function idiom.
##
## `ctx` is a plain read of current state, assembled by the caller (WIGame):
##   { "classes_count": int, "quests_completed": int, "accomplishments": Dict }
## Both `advance_when` gates and per-beat `when` clauses use one predicate shape:
##   { "min_classes": int?, "quests_completed": int?, "accomplishments": {id:int}? }
## An empty/absent clause is trivially met.


## True iff every named condition in `cond` is satisfied by `ctx`. Missing
## counters read as 0 (tolerant of old/sparse saves).
static func conditions_met(cond: Dictionary, ctx: Dictionary) -> bool:
	if cond.has("min_classes") and int(ctx.get("classes_count", 0)) < int(cond["min_classes"]):
		return false
	if cond.has("quests_completed") and int(ctx.get("quests_completed", 0)) < int(cond["quests_completed"]):
		return false
	var accs: Dictionary = ctx.get("accomplishments", {})
	for req_id: String in (cond.get("accomplishments", {}) as Dictionary):
		if int(accs.get(req_id, 0)) < int(cond["accomplishments"][req_id]):
			return false
	return true


## Index of the current act: walk the list, advancing while each act's
## `advance_when` gate is met, and cap at the final act (the last act is
## open-ended -- its gate may be defined-but-unreachable, and even once met
## there is no further act to enter). Empty catalog -> 0.
static func current_index(acts_catalog: Dictionary, ctx: Dictionary) -> int:
	var acts: Array = acts_catalog.get("acts", [])
	if acts.is_empty():
		return 0
	var idx := 0
	while idx < acts.size() - 1 and conditions_met((acts[idx] as Dictionary).get("advance_when", {}), ctx):
		idx += 1
	return idx


## The current act as a render-ready Dictionary for the journal act-line:
##   { "id", "title", "header", "index", "beats": [{ "id", "text", "achieved" }] }
## Empty catalog -> {} (journal renders no act section, degrading gracefully).
static func evaluate(acts_catalog: Dictionary, ctx: Dictionary) -> Dictionary:
	var acts: Array = acts_catalog.get("acts", [])
	if acts.is_empty():
		return {}
	var idx := current_index(acts_catalog, ctx)
	var act: Dictionary = acts[idx]
	var beats: Array = []
	for raw_beat: Variant in act.get("beats", []):
		var beat := raw_beat as Dictionary
		beats.append({
			"id": String(beat.get("id", "")),
			"text": String(beat.get("text", "")),
			"achieved": conditions_met(beat.get("when", {}), ctx),
		})
	return {
		"id": String(act.get("id", "")),
		"title": String(act.get("title", "")),
		"header": String(act.get("header", act.get("title", ""))),
		"index": idx,
		"beats": beats,
	}
