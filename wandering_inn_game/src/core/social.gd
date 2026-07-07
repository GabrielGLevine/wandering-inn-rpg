class_name WISocial
extends RefCounted
## ARCH-4: talk-pool rotation + heard_gossip banking, extracted from
## wi_game.gd. PURITY RULE: no autoload/Node/scene-tree references.
## `social_talked` itself stays a WIGame field (save.gd reads/writes it
## directly and is banned from this task's diff, and it is reassigned
## wholesale on load) -- every call takes the CURRENT dict as a parameter
## and mutates it in place (Dictionary is a reference type in GDScript, so
## the caller's own field sees the mutation with no reassignment needed).
## `entity_first_use` stays on WIGame too, deliberately NOT moved here (see
## wi_game.gd's field_skills-owned `_bank_first_use`) -- it is shared with
## the [Observe]/[Charming Smile] field-skill dedup, which is WIFieldSkills'
## territory, not this file's; a clean boundary beats a complete one.

var _event_sink: Callable
## Callable(id: String) -> int, forwards to WIGame.accomplishment_count.
var _accomplishment_count: Callable
## Callable(id: String, amount: int) -> void, forwards to
## WIGame.record_accomplishment.
var _record_accomplishment: Callable


func _init(event_sink: Callable, accomplishment_count_cb: Callable, record_accomplishment_cb: Callable) -> void:
	_event_sink = event_sink
	_accomplishment_count = accomplishment_count_cb
	_record_accomplishment = record_accomplishment_cb


## The rotating "small talk" interact path (Social Pillar S1). Plays ONE
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
	# Content Wave C4 (Q2 pool-GROWTH): an NPC may carry `talk_pool_post`, a
	# SECOND pool that REPLACES `talk_pool` once its `requires_accomplishment`
	# gate is met. Rotation below still keys on chatted_with_<id> %
	# pool.size() (zero rng), now over the grown pool.
	var post: Dictionary = target.get("talk_pool_post", {})
	if not post.is_empty() and _accomplishment_gate_met(post.get("requires_accomplishment", {})):
		pool = post["lines"]
	var counter_key := "chatted_with_%s" % id
	var idx := int(_accomplishment_count.call(counter_key)) % pool.size()
	var speaker := String(target.get(WIKeys.DISPLAY_NAME, id))
	_emit(WIEvents.DIALOGUE_LINE, {"speaker": speaker, "text": String(pool[idx])})
	_record_accomplishment.call(counter_key, 1)
	_record_accomplishment.call("heard_gossip", 1)
	social_talked[id] = true
	return {"talked": id, "index": idx}


## True when every accomplishment threshold in `req` (id -> min count) is
## met (>= semantics). An empty/absent dict reads as "always met".
## Keep in sync with WIGame._accomplishment_gate_met (deliberate tiny
## duplicate over an 8th injected Callable -- ARCH-4 review LOW note).
func _accomplishment_gate_met(req: Dictionary) -> bool:
	for key: String in req:
		if int(_accomplishment_count.call(key)) < int(req[key]):
			return false
	return true


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
