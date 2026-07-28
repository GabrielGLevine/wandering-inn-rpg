class_name WIQuests
extends RefCounted


static func beat_index(quest: Dictionary, accomplishments: Dictionary) -> int:
	var beats: Array = quest.get("beats", [])
	for i in beats.size():
		for req_id: String in beats[i].get("complete_when", {}):
			if int(accomplishments.get(req_id, 0)) < int(beats[i]["complete_when"][req_id]):
				return i
	return beats.size()


static func quest_by_id(quest_catalog: Dictionary, id: String) -> Dictionary:
	for quest: Dictionary in quest_catalog.get("quests", []):
		if String(quest.get("id", "")) == id:
			return quest
	return {}


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
			"region": String(quest.get("region", "")),
			"path": resolution_path_text(quest, accomplishments) if completed else "",
		}
	return out


static func resolution_path_text(quest: Dictionary, accomplishments: Dictionary) -> String:
	return String(resolved_path(quest, accomplishments).get("text", ""))


## The full resolved-path ENTRY — the journal's history line and the grant hook
## both read off this. LAST MATCH WINS among entries carrying a real
## accomplishment, the same convention sleep_veil.gd's FINALE_CLOSE_LINES uses,
## so the ending text and the ending grant can never disagree. It was
## first-match, and a bounce-hatch state (what_the_seal_was_feeding: seal_opened
## banked, then seal_kept_fed or seal_rewarded) recorded the FIGHT ending and
## paid the FIGHT grant while the finale's own last-match close line called it
## the resolution the player actually chose. An ""-req entry is the authored
## FALLBACK, not a match: it wins only when no real counter banked, wherever it
## sits in the array.
static func resolved_path(quest: Dictionary, accomplishments: Dictionary) -> Dictionary:
	var fallback: Dictionary = {}
	var matched: Dictionary = {}
	for entry: Variant in quest.get("resolution_paths", []):
		var row: Dictionary = entry
		var req := String(row.get("accomplishment", ""))
		if req == "":
			if fallback.is_empty():
				fallback = row
			continue
		if int(accomplishments.get(req, 0)) >= 1:
			matched = row
	return matched if not matched.is_empty() else fallback
