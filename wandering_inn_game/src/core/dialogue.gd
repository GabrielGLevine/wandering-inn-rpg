class_name WIDialogue
extends RefCounted

var finished := false
var current_id := ""

var _graph: Dictionary
var _ctx: Dictionary
var _event_sink: Callable

const BARGAIN_PRICE_MOD := 0.1


func _init(graph: Dictionary, ctx: Dictionary, event_sink: Callable) -> void:
	_graph = graph
	_ctx = ctx
	_event_sink = event_sink


func begin() -> void:
	_enter(String(_graph["start"]))


func current_options() -> Array:
	if finished:
		return []
	var out: Array = []
	for entry: Dictionary in _visible_options():
		var opt: Dictionary = entry["option"]
		var req: Dictionary = opt.get("requires", {})
		var locked := not _meets(req, opt)
		var row: Dictionary = {"text": _priced_text(opt, req), "locked": locked, "requirement": _requirement_text(req, opt) if locked else ""}
		var effect_lines := _item_effect_lines(opt)
		if not effect_lines.is_empty():
			row["effect_lines"] = effect_lines
		out.append(row)
	return out


func _item_effect_lines(opt: Dictionary) -> Array:
	var items: Dictionary = _ctx.get("items", {})
	var out: Array = []
	for effect: Dictionary in opt.get("effects", []):
		if not effect.has("item"):
			continue
		var rec: Dictionary = items.get(String(effect["item"]), {})
		if rec.is_empty():
			continue
		for line: String in WIEffectText.item_effect_lines(rec):
			if not line.begins_with(WIEffectText.PRICE_LINE_PREFIX):
				out.append(line)
	return out


func set_ctx(ctx: Dictionary) -> void:
	_ctx = ctx


func choose(index: int) -> Dictionary:
	# Resolution only: the owner applies effects, rebuilds ctx, then calls
	# advance(). Entering the next node here would evaluate stale state.
	if finished:
		return {}
	var visible: Array = _visible_options()
	if index < 0 or index >= visible.size():
		return {}
	var opt: Dictionary = visible[index]["option"]
	var req: Dictionary = opt.get("requires", {})
	if not _meets(req, opt):
		return {}
	var effects: Array = (opt.get("effects", []) as Array).duplicate(true)
	if req.has("gold"):
		var discounted := _priced_gold(int(req["gold"]), opt)
		for effect: Dictionary in effects:
			if effect.has("gold") and int(effect["gold"]) == -int(req["gold"]):
				effect["gold"] = -discounted
	var ended := bool(opt.get("end", false))
	if ended:
		finished = true
		_emit(WIEvents.DIALOGUE_ENDED, {})
	return {"effects": effects, "ended": ended, "next": "" if ended else String(opt["goto"])}


func advance(next_id: String) -> void:
	if finished or next_id.is_empty():
		return
	_enter(next_id)


func _progress_gated(req: Dictionary) -> bool:
	return req.has("accomplishment") or req.has("board_accepted") or req.has("delivery_accepted") or req.has("once_per_waking")


func _meets_progress(req: Dictionary) -> bool:
	if req.has("board_accepted"):
		if bool(_ctx.get("board_accepted", false)) != bool(req["board_accepted"]):
			return false
	if req.has("delivery_accepted"):
		if bool(_ctx.get("delivery_accepted", false)) != bool(req["delivery_accepted"]):
			return false
	if req.has("once_per_waking"):
		if (_ctx.get("entity_first_use", {}) as Dictionary).has(String(req["once_per_waking"])):
			return false
	if not req.has("accomplishment"):
		return true
	for id: String in req["accomplishment"]:
		if int((_ctx["accomplishments"] as Dictionary).get(id, 0)) < int(req["accomplishment"][id]):
			return false
	return true


func _visible_options() -> Array:
	# hide_when removes spent choices; unmet requires remain visible but locked.
	var out: Array = []
	var options: Array = _node().get("options", [])
	for authored_index: int in options.size():
		var opt: Dictionary = options[authored_index]
		var hide_when: Dictionary = opt.get("hide_when", {})
		if not hide_when.is_empty() and _meets_hide_when(hide_when):
			continue
		var req: Dictionary = opt.get("requires", {})
		if _progress_gated(req) and not _meets_progress(req):
			continue
		out.append({"authored_index": authored_index, "option": opt})
	return out


func _meets_hide_when(hide_when: Dictionary) -> bool:
	if not hide_when.has("once_per_waking"):
		return _meets(hide_when)
	push_error("WIDialogue: hide_when must not carry once_per_waking (requires-only gate, Issue #23) -- key ignored: %s" % str(hide_when))
	var cleaned := hide_when.duplicate()
	cleaned.erase("once_per_waking")
	return not cleaned.is_empty() and _meets(cleaned)


func _is_priced_purchase(opt: Dictionary, base: int) -> bool:
	for effect: Dictionary in opt.get("effects", []):
		if effect.has("gold") and int(effect["gold"]) == -base:
			return true
	return false


func _priced_gold(base: int, opt: Dictionary = {}) -> int:
	if not _is_priced_purchase(opt, base):
		return base
	if not bool(_node().get("haggle", false)):
		return base
	if not (_ctx.get(WIKeys.SKILLS, []) as Array).has("bargain"):
		return base
	return int(floor(float(base) * (1.0 - BARGAIN_PRICE_MOD)))


func _priced_text(opt: Dictionary, req: Dictionary) -> String:
	# Rewrite the catalog price token; never bake a second numeric price into dialogue copy.
	var text := String(opt["text"])
	if not req.has("gold"):
		return text
	var base := int(req["gold"])
	if not _is_priced_purchase(opt, base):
		return text
	var priced := _priced_gold(base, opt)
	if text.contains("gold)"):
		if priced == base:
			return text
		return text.replace("(%d gold)" % base, "(%d gold)" % priced)
	return "%s (%d gold)" % [text, priced]


func _node() -> Dictionary:
	return (_graph["nodes"] as Dictionary)[current_id]


func _enter(id: String) -> void:
	current_id = id
	var n := _node()
	var visible_options := current_options()
	_emit(WIEvents.DIALOGUE_NODE, {"speaker": String(n["speaker"]), "text": _resolved_text(n), "options": visible_options})
	if visible_options.is_empty() and not (n.get("options", []) as Array).is_empty():
		finished = true
		_emit(WIEvents.DIALOGUE_ENDED, {})


func _resolved_text(node: Dictionary) -> String:
	var text := String(node["text"])
	for variant: Dictionary in node.get("text_variants", []):
		if _meets(variant.get("requires", {})):
			text = String(variant["text"])
	return text


func _meets(req: Dictionary, opt: Dictionary = {}) -> bool:
	if req.is_empty():
		return true
	var recognized := false
	if req.has("skill"):
		recognized = true
		if not (_ctx[WIKeys.SKILLS] as Array).has(String(req["skill"])):
			return false
	if req.has("class"):
		recognized = true
		for id: String in req["class"]:
			if int((_ctx["classes"] as Dictionary).get(id, 0)) < int(req["class"][id]):
				return false
	if req.has("gold"):
		recognized = true
		if int(_ctx.get("gold", 0)) < _priced_gold(int(req["gold"]), opt):
			return false
	if req.has("accomplishment"):
		recognized = true
		for id: String in req["accomplishment"]:
			if int((_ctx["accomplishments"] as Dictionary).get(id, 0)) < int(req["accomplishment"][id]):
				return false
	if req.has("board_accepted"):
		recognized = true
		if bool(_ctx.get("board_accepted", false)) != bool(req["board_accepted"]):
			return false
	if req.has("delivery_accepted"):
		recognized = true
		if bool(_ctx.get("delivery_accepted", false)) != bool(req["delivery_accepted"]):
			return false
	if req.has("once_per_waking"):
		recognized = true
		if (_ctx.get("entity_first_use", {}) as Dictionary).has(String(req["once_per_waking"])):
			return false
	if req.has("item"):
		recognized = true
		if not (_ctx.get("inventory", []) as Array).has(String(req["item"])):
			return false
	if req.has("race"):
		recognized = true
		if String(_ctx.get("pc_race", "")) != String(req["race"]):
			return false
	if req.has("phase"):
		recognized = true
		if not (req["phase"] as Array).has(String(_ctx.get("phase", ""))):
			return false
	return recognized


func _requirement_text(req: Dictionary, opt: Dictionary = {}) -> String:
	var names: Dictionary = _ctx.get("names", {})
	if req.has("skill"):
		return "requires %s" % String(names.get(String(req["skill"]), String(req["skill"])))
	if req.has("class"):
		for id: String in req["class"]:
			return "requires %s %d" % [String(names.get(id, id)), int(req["class"][id])]
	if req.has("gold"):
		return "costs %d gold" % _priced_gold(int(req["gold"]), opt)
	if req.has("item"):
		# GH#378 arm 1: an item-level `source_hint` (items.json) rides the
		# requirement suffix so a locked option says where the thing comes from,
		# not just that it is missing. ONE seam covers every item gate in the
		# game -- the 21 hot_meal-gated Serve options that motivated it are data,
		# not 21 rewordings. Absent key = the pre-#378 suffix, byte-identical.
		var items: Dictionary = _ctx.get("items", {})
		var rec: Dictionary = items.get(String(req["item"]), {})
		var item_label := String(rec.get("name", String(req["item"])))
		var source_hint := String(rec.get("source_hint", ""))
		if source_hint != "":
			return "requires %s — %s" % [item_label, source_hint]
		return "requires %s" % item_label
	if req.has("race"):
		return "requires being %s" % String(req["race"])
	if req.has("phase"):
		return "requires the right time of day"
	return "requires more progress"


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
