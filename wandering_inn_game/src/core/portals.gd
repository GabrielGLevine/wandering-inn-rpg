class_name WIPortals
extends RefCounted

# Neutral location label: the door prop never speaks.
const SPEAKER := "The Magical Door"
const HUB_TEXT := "The frame stands open on somewhere else. The attunement holds steady."
const NEVER_MIND := "Let it be."


static func attuned_destinations(rows: Array, accomplishment_count_cb: Callable, has_map_cb: Callable = Callable()) -> Array:
	var out: Array = []
	for row: Dictionary in rows:
		if has_map_cb.is_valid() and not bool(has_map_cb.call(String(row.get("map", "")))):
			continue
		var req := String(row.get("requires_accomplishment", ""))
		if req == "" or int(accomplishment_count_cb.call(req)) >= 1:
			out.append(row)
	return out


static func build_portal_graph(destinations: Array, current_map: String) -> Dictionary:
	# Exclude current_map; portal travel is transition-only and must not synthesize movement.
	var options: Array = []
	for dest: Dictionary in destinations:
		if String(dest.get("map", "")) == current_map:
			continue
		options.append({
			"text": String(dest["display_name"]),
			"effects": [{"travel_to": String(dest["id"])}],
			"end": true,
		})
	options.append({"text": NEVER_MIND, "end": true})
	return {"start": "hub", "nodes": {"hub": {"speaker": SPEAKER, "text": HUB_TEXT, "options": options}}}


static func destination_by_id(rows: Array, id: String) -> Dictionary:
	for row: Dictionary in rows:
		if String(row.get("id", "")) == id:
			return row
	return {}
