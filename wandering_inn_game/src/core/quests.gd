class_name WIQuests
extends RefCounted


static func beat_index(quest: Dictionary, accomplishments: Dictionary) -> int:
	var beats: Array = quest.get("beats", [])
	for i in beats.size():
		if not _beat_met(beats[i] as Dictionary, accomplishments):
			return i
	return beats.size()


## `complete_when` is an AND of counters; `complete_when_any` is an OR beside
## it, and the beat closes when EITHER side is satisfied. Additive: a beat with
## no `complete_when_any` behaves exactly as before.
##
## v0.15 A5, THE OR-PRODUCER IDIOM. Two shipped postings advertised routes their
## beats could not see. `cisterns`' resolve beat waits on `resolved_the_cisterns`,
## which the nest fight and the Watch sweep bank at the moment of resolution --
## but the SCOUT route ([Appraise Foe] on the overlook ledge) banks only
## `scouted_the_nest`, and picks up `resolved_the_cisterns` later, from Olesm's
## report option. Same shape in `wrong_order`: the kitchen route banks
## `stretched_the_order` at the pot and `resolved_wrong_order` only when
## Lyonette is told. So the non-combat player did the thing, and the journal
## went on telling them to go do it. The alternatives name the route counters
## that ALREADY EXIST -- no new producers, no re-semanticised ids.
static func _beat_met(beat: Dictionary, accomplishments: Dictionary) -> bool:
	var any: Dictionary = beat.get("complete_when_any", {})
	for req_id: String in any:
		if int(accomplishments.get(req_id, 0)) >= int(any[req_id]):
			return true
	var all: Dictionary = beat.get("complete_when", {})
	if all.is_empty():
		return any.is_empty()
	for req_id: String in all:
		if int(accomplishments.get(req_id, 0)) < int(all[req_id]):
			return false
	return true


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
##
## AUTHORING CONVENTION, binding on every `resolution_paths` array: order the
## real entries WEAKEST CLAIM FIRST, so the strongest thing the player actually
## did is what last-match records (cleared beats scouted; fought beats read;
## a later resolution beats the door merely being opened). Any quest whose
## counters can co-bank must carry a `_resolution_order` note saying which way
## its ladder runs — test_quests pins the co-banked states for all three.
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
