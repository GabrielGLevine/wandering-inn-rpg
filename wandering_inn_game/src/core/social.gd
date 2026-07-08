class_name WISocial
extends RefCounted
## talk-pool rotation + heard_gossip banking, extracted from
## wi_game.gd. PURITY RULE: no autoload/Node/scene-tree references.
## `social_talked` itself stays a WIGame field (save.gd reads/writes it
## directly and is banned from this task's diff, and it is reassigned
## wholesale on load) -- every call takes the CURRENT dict as a parameter
## and mutates it in place (Dictionary is a reference type in GDScript, so
## the caller's own field sees the mutation with no reassignment needed).
## `entity_first_use` stays on WIGame too, deliberately NOT moved here (see
## wi_game.gd's field_skills-owned `_bank_first_use`) -- it is shared with
## the [Appraise Foe]/[Charming Smile] field-skill dedup, which is WIFieldSkills'
## territory, not this file's; a clean boundary beats a complete one.

var _event_sink: Callable
## Callable(id: String) -> int, forwards to WIGame.accomplishment_count.
var _accomplishment_count: Callable
## Callable(id: String, amount: int) -> void, forwards to
## WIGame.record_accomplishment.
var _record_accomplishment: Callable
## Callable(id: String) -> Dictionary, forwards to WIGame.find_entity
## (searches every map, not just the current one -- the echo_of case below
## resolves an entity on a DIFFERENT map than the talker's own, e.g. the
## charmed villager in riverfarm_village echoing the witch in witch_hollow).
var _find_entity: Callable


func _init(event_sink: Callable, accomplishment_count_cb: Callable, record_accomplishment_cb: Callable, find_entity_cb: Callable) -> void:
	_event_sink = event_sink
	_accomplishment_count = accomplishment_count_cb
	_record_accomplishment = record_accomplishment_cb
	_find_entity = find_entity_cb


## The rotating "small talk" interact path. Plays ONE
## pooled line from the faced NPC's `talk_pool` (an array of canon-voiced
## strings), chosen by `chatted_with_<id> % pool_size` so the line ROTATES
## deterministically across wakings with ZERO rng (no canonical-seed risk).
## The line rides the SAME plain DIALOGUE_LINE surface a graph-less NPC
## uses. Banks `chatted_with_<id>` (the rotation counter, also a
## [Diplomat] feed) + `heard_gossip` (both opaque social counters), and
## sets `social_talked[<id>]` so a SECOND talk this waking falls through to
## the NPC's real conversation. `sleep()` clears `social_talked`, re-arming
## the pool next waking. The index is read BEFORE the counter bank, so the
## FIRST talk is index 0, the next index 1, ... wrapping at `pool_size`.
func talk_pool_line(target: Dictionary, social_talked: Dictionary) -> Dictionary:
	var id := String(target[WIKeys.ID])
	var pool: Array = target["talk_pool"]
	# Generalizing the one-shot talk_pool_post
	# growth: an NPC may carry `talk_pool_stages`, an ORDERED array of
	# {id, requires_accomplishment, lines}. Walk it in AUTHORED order and let
	# the LAST entry whose gate is met win (ascending authoring -- the same
	# convention as visual_states/classes.json level tables); an empty/absent
	# array leaves `pool` at the base talk_pool, unchanged. Rotation below
	# still keys on chatted_with_<id> % pool.size() (zero rng), now over
	# whichever stage's pool won.
	for stage: Dictionary in target.get("talk_pool_stages", []):
		if _accomplishment_gate_met(stage.get("requires_accomplishment", {})):
			pool = stage["lines"]
	var counter_key := "chatted_with_%s" % id
	var idx := int(_accomplishment_count.call(counter_key)) % pool.size()
	var speaker := String(target.get(WIKeys.DISPLAY_NAME, id))
	_emit(WIEvents.DIALOGUE_LINE, {"speaker": speaker, "text": _resolve_pool_line(pool[idx])})
	_record_accomplishment.call(counter_key, 1)
	_record_accomplishment.call("heard_gossip", 1)
	social_talked[id] = true
	return {"talked": id, "index": idx}


## 8b R1 (issue #10), locked shape 3 -- the charmed-villager tell. A
## `talk_pool` entry is normally a plain String; an entry shaped
## `{"echo_of": entity_id}` resolves instead to THAT entity's own CURRENT
## pool line, verbatim -- found via `_find_entity` (searches every map) and
## re-derived through the SAME rotation math (that entity's OWN
## `chatted_with_<id>` counter over its OWN talk_pool/talk_pool_stages
## resolution), never a separately duplicated copy. This is what makes the
## echo un-driftable: it is not a second string that happens to start equal,
## it is the identical lookup the echoed entity's own talk_pool_line call
## would perform right now. Recurses ONE level only (an echo target's own
## pool is assumed to hold plain strings, per the shipped content) -- the
## echoed entity's talk_pool_stages ARE still honored (a witch line that
## grows a stage still echoes correctly), just not a second echo_of chain.
func _resolve_pool_line(raw: Variant) -> String:
	if not (raw is Dictionary):
		return String(raw)
	var echo_id := String((raw as Dictionary)["echo_of"])
	var echo_target: Dictionary = _find_entity.call(echo_id)
	if echo_target.is_empty() or not echo_target.has("talk_pool"):
		return ""
	var echo_pool: Array = echo_target["talk_pool"]
	for stage: Dictionary in echo_target.get("talk_pool_stages", []):
		if _accomplishment_gate_met(stage.get("requires_accomplishment", {})):
			echo_pool = stage["lines"]
	var echo_idx := int(_accomplishment_count.call("chatted_with_%s" % echo_id)) % echo_pool.size()
	return String(echo_pool[echo_idx])


## True when every accomplishment threshold in `req` (id -> min count) is
## met (>= semantics). An empty/absent dict reads as "always met".
## Keep in sync with WIGame._accomplishment_gate_met (deliberate tiny
## duplicate, deliberately preferred over an 8th injected Callable).
func _accomplishment_gate_met(req: Dictionary) -> bool:
	for key: String in req:
		if int(_accomplishment_count.call(key)) < int(req[key]):
			return false
	return true


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
