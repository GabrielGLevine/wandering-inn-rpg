class_name WIQuests
extends RefCounted


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
			"region": String(quest.get("region", "")),
			"path": resolution_path_text(quest, accomplishments) if completed else "",
		}
	return out


static func resolution_path_text(quest: Dictionary, accomplishments: Dictionary) -> String:
	for entry: Variant in quest.get("resolution_paths", []):
		var req := String((entry as Dictionary).get("accomplishment", ""))
		if req == "" or int(accomplishments.get(req, 0)) >= 1:
			return String((entry as Dictionary).get("text", ""))
	return ""
