class_name WIQuests
extends RefCounted
## Pure quest-beat derivation. Quest progress is a FUNCTION of accomplishment
## counters — never stored (the v2 dead-quest-chain lesson, structural form).


static func beat_index(quest: Dictionary, accomplishments: Dictionary) -> int:
	var beats: Array = quest.get("beats", [])
	for i in beats.size():
		for req_id: String in beats[i].get("complete_when", {}):
			if int(accomplishments.get(req_id, 0)) < int(beats[i]["complete_when"][req_id]):
				return i
	return beats.size()


static func evaluate(quest_catalog: Dictionary, started: Array, accomplishments: Dictionary) -> Dictionary:
	var out := {}
	for quest: Dictionary in quest_catalog.get("quests", []):
		var id := String(quest[WIKeys.ID])
		if not started.has(id):
			continue
		var idx := beat_index(quest, accomplishments)
		var beats: Array = quest.get("beats", [])
		var completed := idx >= beats.size()
		out[id] = {
			"beat_index": idx,
			"completed": completed,
			"beat_description": String(beats[idx]["description"]) if idx < beats.size() else "",
			# Optional signposting suffix (issue #74) -- empty string for a
			# quest with no "region" field (every Liscor-local quest today).
			# journal.gd's quest_summary line is the ONLY consumer; toasts
			# (_start_quest/_check_quests) deliberately stay title-only.
			"region": String(quest.get("region", "")),
			# Issue #79 (journal history): the chosen-path HISTORY line for a
			# COMPLETED quest -- see resolution_path_text's own doc comment.
			# Computed only once completed (an unresolved fork flag can be
			# banked mid-quest, e.g. a path-specific producer firing before a
			# later report beat closes the quest -- gating on `completed`
			# keeps this a RESULT, never a mid-quest tell).
			"path": resolution_path_text(quest, accomplishments) if completed else "",
		}
	return out


## The chosen-path HISTORY line for one quest, derived from its own
## `resolution_paths` catalog entries (data/quests.json, this task's own
## addition -- each `{accomplishment, text}` pair, checked in array order;
## an empty `accomplishment` string always matches, the documented FALLBACK
## shape for a path with no distinct producer of its own — see each quest's
## own `_resolution_paths_comment`). Pure data lookup, no new sim state:
## every accomplishment counter it reads is one a real dialogue/on_victory/
## on_skill_use effect already banks. Returns "" for a quest with no
## `resolution_paths` entry (degrades gracefully — the journal falls back to
## a bare "Complete." line) or when none of its entries match (can't happen
## for a real completion once a quest's own catalog carries a fallback
## entry, but never asserts).
static func resolution_path_text(quest: Dictionary, accomplishments: Dictionary) -> String:
	for entry: Variant in quest.get("resolution_paths", []):
		var req := String((entry as Dictionary).get("accomplishment", ""))
		if req == "" or int(accomplishments.get(req, 0)) >= 1:
			return String((entry as Dictionary).get("text", ""))
	return ""
