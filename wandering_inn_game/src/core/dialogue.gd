class_name WIDialogue
extends RefCounted
## Pure conversation-graph walker. PURITY RULE: no autoload/Node/scene-tree
## references; context (skills/classes/accomplishments/display names) is
## injected, and chosen options' effects are RETURNED to the caller (WIGame)
## to apply -- this class never mutates game state. Constructor is silent;
## begin() starts emission (see WICombat.begin for the lesson behind this).

var finished := false
var current_id := ""

var _graph: Dictionary
var _ctx: Dictionary
var _event_sink: Callable


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
		var locked := not _meets(req)
		out.append({"text": String(opt["text"]), "locked": locked, "requirement": _requirement_text(req) if locked else ""})
	return out


## Re-injects a fresh context snapshot. Called by the owner (WIGame) after
## applying a chosen option's effects so the NEXT node's gating sees them.
func set_ctx(ctx: Dictionary) -> void:
	_ctx = ctx


## Resolves the chosen visible option WITHOUT advancing: returns
## {effects, ended, next}. The owner applies effects, refreshes ctx
## (set_ctx), then calls advance(next) -- that ordering is the whole point.
func choose(index: int) -> Dictionary:
	if finished:
		return {}
	var visible: Array = _visible_options()
	if index < 0 or index >= visible.size():
		return {}
	var opt: Dictionary = visible[index]["option"]
	if not _meets(opt.get("requires", {})):
		return {}
	var effects: Array = (opt.get("effects", []) as Array).duplicate(true)
	var ended := bool(opt.get("end", false))
	if ended:
		finished = true
		_emit(WIEvents.DIALOGUE_ENDED, {})
	return {"effects": effects, "ended": ended, "next": "" if ended else String(opt["goto"])}


## Enters the node a choose() result pointed at. No-op once finished.
func advance(next_id: String) -> void:
	if finished or next_id.is_empty():
		return
	_enter(next_id)


## True when this requires-dict gates on player PROGRESS (accomplishments):
## progress-gated options are HIDDEN until met (playtest policy, M4), while
## skill/class gates stay visible-locked as a deliberate tease.
func _progress_gated(req: Dictionary) -> bool:
	return req.has("accomplishment")


## Returns the authored options for the current node filtered down to the
## visible ones, as {authored_index, option} pairs. This is the single source
## of truth for the visible->authored index mapping: current_options() and
## choose() both build/consume this list so the index a player sees always
## lines up with the option choose() resolves.
func _visible_options() -> Array:
	var out: Array = []
	var options: Array = _node().get("options", [])
	for authored_index: int in options.size():
		var opt: Dictionary = options[authored_index]
		var hide_when: Dictionary = opt.get("hide_when", {})
		if not hide_when.is_empty() and _meets(hide_when):
			continue
		var req: Dictionary = opt.get("requires", {})
		if _progress_gated(req) and not _meets(req):
			continue
		out.append({"authored_index": authored_index, "option": opt})
	return out


func _node() -> Dictionary:
	return (_graph["nodes"] as Dictionary)[current_id]


func _enter(id: String) -> void:
	current_id = id
	var n := _node()
	var visible_options := current_options()
	_emit(WIEvents.DIALOGUE_NODE, {"speaker": String(n["speaker"]), "text": _resolved_text(n), "options": visible_options})
	# SOFTLOCK GUARD: a node with authored options that are ALL hidden by
	# hide_when leaves the player at a dead end with nothing to click -- there
	# is no way to advance or exit. This is malformed content (content
	# validation in test_content.gd is meant to make it unreachable: every
	# hub must retain at least one always-available option), but if it ever
	# slips through, fail safe by ending the dialogue instead of soft-locking
	# the player in a conversation with no choices.
	if visible_options.is_empty() and not (n.get("options", []) as Array).is_empty():
		finished = true
		_emit(WIEvents.DIALOGUE_ENDED, {})


func _resolved_text(node: Dictionary) -> String:
	var text := String(node["text"])
	for variant: Dictionary in node.get("text_variants", []):
		if _meets(variant.get("requires", {})):
			text = String(variant["text"])
	return text


func _meets(req: Dictionary) -> bool:
	if req.is_empty():
		return true
	if req.has("skill"):
		return (_ctx["skills"] as Array).has(String(req["skill"]))
	if req.has("class"):
		for id: String in req["class"]:
			if int((_ctx["classes"] as Dictionary).get(id, 0)) < int(req["class"][id]):
				return false
		return true
	if req.has("gold"):
		# Economy v1 Task D1: numeric affordability gate (a shop buy option's
		# `requires: {gold: price}`). The ONE sanctioned extension of the M4
		# greying ctx (it was skill/class/accomplishment-only). Reads the `gold`
		# key WIGame._build_dialogue_ctx now supplies (tolerant default 0). Gold
		# is NOT progress-gated (see _progress_gated -- no `accomplishment` key),
		# so an unaffordable buy stays VISIBLE-locked/greyed, never hidden:
		# window-shopping is content (spec §3).
		return int(_ctx.get("gold", 0)) >= int(req["gold"])
	if req.has("accomplishment"):
		for id: String in req["accomplishment"]:
			if int((_ctx["accomplishments"] as Dictionary).get(id, 0)) < int(req["accomplishment"][id]):
				return false
		return true
	return false


func _requirement_text(req: Dictionary) -> String:
	var names: Dictionary = _ctx.get("names", {})
	if req.has("skill"):
		return "requires %s" % String(names.get(String(req["skill"]), String(req["skill"])))
	if req.has("class"):
		for id: String in req["class"]:
			return "requires %s %d" % [String(names.get(id, id)), int(req["class"][id])]
	if req.has("gold"):
		return "costs %d gold" % int(req["gold"])
	return "requires more progress"


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
