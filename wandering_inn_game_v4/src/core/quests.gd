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
		var id := String(quest["id"])
		if not started.has(id):
			continue
		var idx := beat_index(quest, accomplishments)
		var beats: Array = quest.get("beats", [])
		out[id] = {
			"beat_index": idx,
			"completed": idx >= beats.size(),
			"beat_description": String(beats[idx]["description"]) if idx < beats.size() else "",
		}
	return out
