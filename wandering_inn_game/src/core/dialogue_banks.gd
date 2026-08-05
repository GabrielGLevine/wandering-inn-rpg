class_name WIDialogueBanks
## Dialogue line banks (user directive 2026-08-05). 62 slots across 29
## conversation graphs were copy-paste -- the same line duplicated so it
## could appear under several conditions, plus five option verbs ("Bring him
## a bowl from the kitchen. (Serve)" x10) that MUST stay uniform across
## files. A graph may declare file-local `text_banks` and any text /
## text_variants / options[].text slot may be the ref string "@<name>";
## cross-file lines live once in data/dialogue/_shared_lines.json. Local
## banks shadow nothing (data_lint forbids name collisions with shared).
## Expansion happens at LOAD -- game.gd for the runtime, test_copy_fit for
## measurements, wi_data_lib for tooling -- so the sim, every pin and every
## panel measurement sees only resolved lines. An unresolvable ref is a
## hard assert: a shipped "@foo" string is a content bug, never a degrade.

const SHARED_PATH := "res://data/dialogue/_shared_lines.json"


static func load_shared() -> Dictionary:
	if not FileAccess.file_exists(SHARED_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHARED_PATH))
	return (parsed as Dictionary).get("banks", {}) if parsed is Dictionary else {}


static func expand(graph: Dictionary, shared: Dictionary) -> Dictionary:
	var local: Dictionary = graph.get("text_banks", {})
	for node: Variant in (graph.get("nodes", {}) as Dictionary).values():
		if not (node is Dictionary):
			continue
		var n := node as Dictionary
		if n.get("text") is String:
			n["text"] = _resolve(n["text"], local, shared)
		if n.get("text_variants") is Array:
			var tv: Array = n["text_variants"]
			for i in tv.size():
				if tv[i] is String:
					tv[i] = _resolve(tv[i], local, shared)
				elif tv[i] is Dictionary and (tv[i] as Dictionary).get("text") is String:
					(tv[i] as Dictionary)["text"] = _resolve((tv[i] as Dictionary)["text"], local, shared)
		for o: Variant in n.get("options", []):
			if o is Dictionary and (o as Dictionary).get("text") is String:
				(o as Dictionary)["text"] = _resolve((o as Dictionary)["text"], local, shared)
	return graph


static func _resolve(t: String, local: Dictionary, shared: Dictionary) -> String:
	if not t.begins_with("@"):
		return t
	var name := t.substr(1)
	if local.has(name):
		return String(local[name])
	assert(shared.has(name), "dialogue ref '@%s' does not resolve" % name)
	return String(shared[name])
