extends SceneTree
## Pure dialogue-graph tests.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_dialogue.gd

var _events: Array = []


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


func _count(type: String) -> int:
	var n := 0
	for e: Dictionary in _events:
		if e["type"] == type:
			n += 1
	return n


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _make_game_with_dialogue(graph: Dictionary) -> WIGame:
	var combat_config := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"dialogue": {"test_conv": graph},
	}
	return WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, combat_config)


func test_accomplishment_requires_hides_until_met() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "secret", "requires": {"accomplishment": {"deed": 1}}, "end": true},
		{"text": "always", "end": true},
	]}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}}, Callable())
	d.begin()
	assert(d.current_options().size() == 1, "accomplishment-gated option hidden when unmet")
	assert(String(d.current_options()[0]["text"]) == "always", "only the ungated option shows")
	var d2 := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {"deed": 1}, "names": {}}, Callable())
	d2.begin()
	assert(d2.current_options().size() == 2, "accomplishment-gated option visible once met")


func test_skill_and_class_requires_stay_visible_locked() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "skillful", "requires": {"skill": "basic_cleaning"}, "end": true},
		{"text": "classy", "requires": {"class": {"warrior": 2}}, "end": true},
		{"text": "leave", "end": true},
	]}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {"warrior": 1}, "accomplishments": {}, "names": {}}, Callable())
	d.begin()
	assert(d.current_options().size() == 3, "skill/class gates remain visible")
	assert(bool(d.current_options()[0]["locked"]), "unmet skill gate locked")
	assert(bool(d.current_options()[1]["locked"]), "unmet class gate locked")


func test_ctx_refresh_regates_mid_conversation() -> void:
	var graph := {"start": "hub", "nodes": {
		"hub": {"speaker": "S", "text": "t", "options": [
			{"text": "do deed", "hide_when": {"accomplishment": {"deed": 1}}, "effects": [{"accomplishment": "deed"}], "goto": "mid"},
			{"text": "report deed", "requires": {"accomplishment": {"deed": 1}}, "end": true},
			{"text": "leave", "end": true},
		]},
		"mid": {"speaker": "S", "text": "done", "options": [{"text": "back", "goto": "hub"}]},
	}}
	var game := _make_game_with_dialogue(graph)
	game.start_dialogue("test_conv", "npc_x")
	assert(game.dialogue.current_options().size() == 2, "report hidden, do-deed + leave visible")
	game.dialogue_choose(0)
	game.dialogue_choose(0)
	var texts: Array = []
	for o: Dictionary in game.dialogue.current_options():
		texts.append(String(o["text"]))
	assert(texts.has("report deed"), "refresh made accomplishment-gated option visible mid-conversation")
	assert(not texts.has("do deed"), "hide_when now hides the consumed option")


func test_node_text_variants_fall_back_to_base_text_when_unmet() -> void:
	_events.clear()
	var graph := {"start": "hub", "nodes": {"hub": {
		"speaker": "S",
		"text": "base text",
		"text_variants": [
			{"requires": {"accomplishment": {"deed": 1}}, "text": "variant text"},
		],
		"options": [{"text": "leave", "end": true}],
	}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}}, _sink)
	d.begin()
	assert(String(_events[0]["payload"]["text"]) == "base text", "unmet text_variants fall back to base text")


func test_node_text_variants_use_met_requires() -> void:
	_events.clear()
	var graph := {"start": "hub", "nodes": {"hub": {
		"speaker": "S",
		"text": "base text",
		"text_variants": [
			{"requires": {"accomplishment": {"deed": 1}}, "text": "variant text"},
		],
		"options": [{"text": "leave", "end": true}],
	}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {"deed": 1}, "names": {}}, _sink)
	d.begin()
	assert(String(_events[0]["payload"]["text"]) == "variant text", "met text_variant replaces base node text")


func test_node_text_variants_last_match_wins() -> void:
	_events.clear()
	var graph := {"start": "hub", "nodes": {"hub": {
		"speaker": "S",
		"text": "base text",
		"text_variants": [
			{"requires": {"accomplishment": {"deed": 1}}, "text": "first variant"},
			{"requires": {"accomplishment": {"deed": 1}}, "text": "last variant"},
		],
		"options": [{"text": "leave", "end": true}],
	}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {"deed": 1}, "names": {}}, _sink)
	d.begin()
	assert(String(_events[0]["payload"]["text"]) == "last variant", "last matching text_variant wins")


## Economy v1 Task D1: the `gold: +/-N` effect verb applied through a REAL
## dialogue_choose (not a direct earn/spend call) -- the earn beat, then a shop
## buy that spends AND grants a sibling item in one option, proving the verb
## lives beside item/accomplishment in the applier.
func test_gold_effect_verb_applies_through_dialogue_choose() -> void:
	_events.clear()
	var graph := {"start": "hub", "nodes": {
		"hub": {"speaker": "Krshia", "text": "t", "options": [
			{"text": "take coin", "effects": [{"gold": 10}], "goto": "shop"},
		]},
		"shop": {"speaker": "Krshia", "text": "buy?", "options": [
			{"text": "buy", "requires": {"gold": 6}, "effects": [{"gold": -6}, {"item": "leather_jerkin"}], "end": true},
			{"text": "leave", "end": true},
		]},
	}}
	var game := _make_game_with_dialogue(graph)
	game.start_dialogue("test_conv", "krshia")
	game.dialogue_choose(0)  # earn 10 via the gold verb, advance to shop
	assert(game.gold == 10, "gold effect verb earns through dialogue_choose")
	# ctx rebuilt after the earn -> the requires:{gold:6} buy now reads affordable.
	var opts: Array = game.dialogue.current_options()
	assert(not bool(opts[0]["locked"]), "buy option unlocked once affordable (ctx refreshed mid-conversation)")
	game.dialogue_choose(0)  # spend 6 AND grant the sibling item
	assert(game.gold == 4, "gold effect verb spends through dialogue_choose")
	assert(game.inventory.has("leather_jerkin"), "sibling item effect still grants alongside the gold spend")


## Issue #23: the well_fed effect verb (Erin's meal perk), the dialogue-side
## twin of the gold effect verb test above -- applied through the real
## WIGame.dialogue_choose effect router, not set directly on the field.
func test_well_fed_effect_verb_applies_through_dialogue_choose() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "Erin", "text": "t", "options": [
		{"text": "eat", "effects": [{"well_fed": true}], "end": true},
	]}}}
	var game := _make_game_with_dialogue(graph)
	assert(not game.well_fed, "well_fed defaults false")
	game.start_dialogue("test_conv", "erin")
	game.dialogue_choose(0)
	assert(game.well_fed, "well_fed effect verb applies through dialogue_choose")


## Economy v1 Task D1: an unaffordable buy stays VISIBLE-locked (greyed), never
## hidden -- window-shopping is content (spec §3). Uses the SHIPPED M4 greying
## mechanism, now reading the numeric gold ctx key.
func test_gold_affordability_greys_when_broke() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "Krshia", "text": "t", "options": [
		{"text": "buy", "requires": {"gold": 50}, "effects": [{"gold": -50}], "end": true},
		{"text": "leave", "end": true},
	]}}}
	var game := _make_game_with_dialogue(graph)  # fresh purse: 0 gold
	game.start_dialogue("test_conv", "krshia")
	var opts: Array = game.dialogue.current_options()
	assert(opts.size() == 2, "unaffordable buy stays VISIBLE (greyed, never hidden)")
	assert(bool(opts[0]["locked"]), "unaffordable buy is locked/greyed")
	assert(String(opts[0]["requirement"]) == "costs 50 gold", "greyed buy shows its cost requirement text")


## Social Pillar II review finding 2: the ONE sanctioned compound gate
## ({gold, accomplishment}) unit-covered at the pure-walker level: the
## accomplishment leg HIDES until met; once met, the gold leg greys-visible;
## with both met the option unlocks. Mirrors the single-key tests above.
func test_compound_gold_accomplishment_gate() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "Krshia", "text": "t", "options": [
		{"text": "discount buy", "requires": {"gold": 10, "accomplishment": {"stage3": 1}}, "effects": [{"gold": -10}], "end": true},
		{"text": "leave", "end": true},
	]}}}
	var game := _make_game_with_dialogue(graph)  # fresh: 0 gold, no accomplishments
	game.start_dialogue("test_conv", "krshia")
	var opts: Array = game.dialogue.current_options()
	assert(opts.size() == 1, "compound gate: accomplishment leg unmet -> option HIDDEN (progress never leaks)")
	game.dialogue_choose(0)  # leave
	game.record_accomplishment("stage3")
	game.start_dialogue("test_conv", "krshia")
	opts = game.dialogue.current_options()
	assert(opts.size() == 2, "accomplishment met -> option visible")
	assert(bool(opts[0]["locked"]), "gold leg unmet -> greyed, not hidden")
	assert(String(opts[0]["requirement"]) == "costs 10 gold", "compound lock shows ONLY the gold reason")
	game.dialogue_choose(1)  # leave
	game.earn_gold(10, "test")
	game.start_dialogue("test_conv", "krshia")
	opts = game.dialogue.current_options()
	assert(not bool(opts[0]["locked"]), "both legs met -> unlocked")


## Issue #23: the once_per_waking gate at the pure-walker level, mirroring
## test_accomplishment_requires_hides_until_met above -- HIDDEN (vanishing),
## not greyed, keyed off the ctx's `entity_first_use` dict rather than
## `accomplishments`.
func test_once_per_waking_requires_hides_until_used() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "meal", "requires": {"once_per_waking": "meal:erin"}, "end": true},
		{"text": "always", "end": true},
	]}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "entity_first_use": {}}, Callable())
	d.begin()
	assert(d.current_options().size() == 2, "once_per_waking gate visible when not yet used this waking")
	var d2 := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "entity_first_use": {"meal:erin": true}}, Callable())
	d2.begin()
	assert(d2.current_options().size() == 1, "once_per_waking gate hidden once used this waking")
	assert(String(d2.current_options()[0]["text"]) == "always", "only the unused/ungated option shows")


## Issue #23: the full per-waking dialogue gate lifecycle through the REAL
## WIGame path (start_dialogue/dialogue_choose/sleep), the issue's named
## unmet -> used -> gone-this-waking -> back-after-sleep sequence. Uses the
## SAME synthetic-graph harness as the gold-effect tests above (a real
## WIGame, not a bare WIDialogue) because bank_first_use is applied by
## WIGame.dialogue_choose's effect router, and "back after sleep" requires
## WIGame.sleep() to clear entity_first_use -- neither is reachable at the
## pure-walker level test_once_per_waking_requires_hides_until_used covers.
func test_once_per_waking_gate_lifecycle_through_bank_first_use() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "Erin", "text": "t", "options": [
		{"text": "meal", "requires": {"once_per_waking": "meal:erin"}, "effects": [{"bank_first_use": "meal:erin"}], "end": true},
		{"text": "leave", "end": true},
	]}}}
	var game := _make_game_with_dialogue(graph)
	game.start_dialogue("test_conv", "erin")
	var opts: Array = game.dialogue.current_options()
	assert(opts.size() == 2, "unused this waking: both options visible")
	assert(not game.entity_first_use.has("meal:erin"), "not yet banked")
	game.dialogue_choose(0)  # eat the meal
	assert(game.entity_first_use.has("meal:erin"), "bank_first_use effect wrote the key")
	game.start_dialogue("test_conv", "erin")
	opts = game.dialogue.current_options()
	assert(opts.size() == 1, "used this waking: the gated option vanishes")
	assert(String(opts[0]["text"]) == "leave", "only the ungated option remains")
	game.dialogue_choose(0)  # leave
	game.sleep()
	assert(not game.entity_first_use.has("meal:erin"), "sleep() clears the per-waking bank")
	game.start_dialogue("test_conv", "erin")
	opts = game.dialogue.current_options()
	assert(opts.size() == 2, "after sleep: the option is back")


## Issue #23: the SECOND sanctioned compound gate ({accomplishment,
## once_per_waking}) at the real-WIGame level, mirroring
## test_compound_gold_accomplishment_gate above. Unlike the gold compound,
## once_per_waking is itself a vanishing gate -- once BOTH legs are met, using
## the option hides it again (no greyed "come back later" state to preserve).
func test_compound_accomplishment_once_per_waking_gate() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "Erin", "text": "t", "options": [
		{"text": "meal", "requires": {"accomplishment": {"stage3": 1}, "once_per_waking": "meal:erin"}, "effects": [{"bank_first_use": "meal:erin"}], "end": true},
		{"text": "leave", "end": true},
	]}}}
	var game := _make_game_with_dialogue(graph)
	game.start_dialogue("test_conv", "erin")
	var opts: Array = game.dialogue.current_options()
	assert(opts.size() == 1, "compound gate: accomplishment leg unmet -> option HIDDEN (progress never leaks)")
	game.dialogue_choose(0)  # leave
	game.record_accomplishment("stage3")
	game.start_dialogue("test_conv", "erin")
	opts = game.dialogue.current_options()
	assert(opts.size() == 2, "accomplishment met, not yet used this waking -> option visible")
	game.dialogue_choose(0)  # eat
	game.start_dialogue("test_conv", "erin")
	opts = game.dialogue.current_options()
	assert(opts.size() == 1, "accomplishment met but used this waking -> once_per_waking leg hides it too")
	game.dialogue_choose(0)  # leave
	game.sleep()
	game.start_dialogue("test_conv", "erin")
	opts = game.dialogue.current_options()
	assert(opts.size() == 2, "after sleep, with the accomplishment still held: the option is back")


func _last_line_text() -> String:
	for i in range(_events.size() - 1, -1, -1):
		if String(_events[i]["type"]) == "dialogue_line":
			return String(_events[i]["payload"]["text"])
	return ""


func _find_entity(scene: Dictionary, map_id: String, id: String) -> Dictionary:
	for e: Dictionary in scene["maps"][map_id]["entities"]:
		if String(e["id"]) == id:
			return e
	return {}


## Social Pillar II Phase A: the talk_pool_stages GROWTH seam (generalizes
## Content Wave C4's one-shot talk_pool_post -- Lyonette's shipped
## talk_pool_post migrated to a one-entry talk_pool_stages array, RENAME not
## rewrite). Before the gate (resolved_wrong_order) is banked, Lyonette's
## rotating small-talk draws from her BASE talk_pool; after it, the same
## first-talk-of-waking path draws from the GROWN stage-2 pool (a
## replacement, not a merge). Drives the real WIGame interact path against
## the shipped Lyonette entity.
func test_talk_pool_post_grows_pool_after_gate() -> void:
	_events.clear()
	var game := _make_game_with_dialogue({})
	var scene := _load_json("res://data/skeleton_scene.json")
	var lyo := _find_entity(scene, "inn", "lyonette")
	var base_pool: Array = lyo["talk_pool"]
	var post_lines: Array = ((lyo["talk_pool_stages"] as Array)[0] as Dictionary)["lines"]
	# Gate UNMET: first talk of the waking plays a BASE pool line.
	game.player_cell = Vector2i(8, 5)
	game.player_facing = Vector2i(1, 0)
	game.interact()
	var before := _last_line_text()
	assert(base_pool.has(before), "pre-resolution talk draws from the BASE talk_pool")
	assert(not post_lines.has(before), "pre-resolution talk is NOT a grown line")
	# Bank the gate + sleep to re-arm the pool (sleep clears social_talked).
	game.record_accomplishment("resolved_wrong_order")
	game.sleep()
	_events.clear()
	game.player_cell = Vector2i(8, 5)
	game.player_facing = Vector2i(1, 0)
	game.interact()
	var after := _last_line_text()
	assert(post_lines.has(after), "post-resolution talk draws from the GROWN talk_pool_post")
	assert(not base_pool.has(after), "post-resolution talk REPLACED the base pool, not merged it")


const GRAPH := {
	"start": "hub",
	"nodes": {
		"hub": {"speaker": "Erin", "text": "Need anything?", "options": [
			{"text": "Just chatting.", "goto": "chat"},
			{"text": "Let me clean that.", "requires": {"skill": "basic_cleaning"}, "effects": [{"accomplishment": "cleaned_the_inn"}], "goto": "thanks"},
			{"text": "Show me the drills.", "requires": {"class": {"warrior": 2}}, "goto": "thanks"},
			{"text": "About that goblin...", "requires": {"accomplishment": {"street_cleared": 1}}, "goto": "thanks"},
			{"text": "Bye.", "end": true},
			{"text": "Spent option.", "hide_when": {"accomplishment": {"used_it": 1}}, "goto": "chat"},
		]},
		"chat": {"speaker": "Erin", "text": "Chat away!", "options": [{"text": "Back.", "goto": "hub"}]},
		"thanks": {"speaker": "Erin", "text": "Thanks!", "options": [{"text": "Bye.", "end": true, "effects": [{"quest": "the_errand"}]}]},
	},
}


func _init() -> void:
	WITestWatchdog.arm(self)
	var ctx := {
		"skills": ["basic_cleaning"], "classes": {"warrior": 1},
		"accomplishments": {}, "names": {"basic_cleaning": "[Basic Cleaning]", "warrior": "Warrior"},
	}
	var d := WIDialogue.new(GRAPH, ctx, _sink)
	assert(_events.is_empty(), "constructor is silent")
	d.begin()
	assert(_count("dialogue_node") == 1, "begin emits first node")
	assert(d.current_id == "hub", "starts at start node")

	var opts := d.current_options()
	assert(opts.size() == 5, "skill/class gates visible; unmet progress gate hidden")
	assert(not opts[0]["locked"] and not opts[1]["locked"], "no-req and skill-possessed unlocked")
	assert(opts[2]["locked"] and opts[2]["requirement"] == "requires Warrior 2", "class-gated locked with name")

	assert(d.choose(2).is_empty(), "locked choose refused")
	assert(d.current_id == "hub", "refusal does not advance")
	assert(d.choose(99).is_empty(), "out-of-range refused")

	# Visible index 4 is the "Spent option." -- with accomplishments: {} its
	# hide_when is not met, so it stays visible and choosing it by its
	# VISIBLE index resolves back to the correct authored option (goto "chat").
	var r_spent := d.choose(4)
	assert(r_spent["ended"] == false, "spent option chosen while still visible")
	d.advance(String(r_spent["next"]))
	assert(d.current_id == "chat", "spent option's goto resolved correctly via visible index")
	var r_back := d.choose(0)
	d.advance(String(r_back["next"]))
	assert(d.current_id == "hub", "back to hub for the rest of the walk")

	var r := d.choose(1)
	assert(r["ended"] == false and (r["effects"] as Array).size() == 1, "effects returned to caller")
	d.advance(String(r["next"]))
	assert(d.current_id == "thanks" and _count("dialogue_node") == 4, "advanced with node event")

	var r2 := d.choose(0)
	assert(r2["ended"] == true and String((r2["effects"] as Array)[0]["quest"]) == "the_errand", "end option carries effects")
	assert(d.finished and _count("dialogue_ended") == 1, "ended emits and finishes")
	assert(d.choose(0).is_empty(), "finished dialogue refuses input")

	# Loop-back navigation
	var d2 := WIDialogue.new(GRAPH, ctx, _sink)
	d2.begin()
	var d2_chat := d2.choose(0)
	d2.advance(String(d2_chat["next"]))
	assert(d2.current_id == "chat", "goto chat")
	var d2_hub := d2.choose(0)
	d2.advance(String(d2_hub["next"]))
	assert(d2.current_id == "hub", "hub loop-back works")

	# hide_when: with the accomplishment met, "Spent option." is omitted entirely
	# from the visible list, and the unmet accomplishment-gated option is also
	# hidden. VISIBLE indices must still map back to the correct authored option.
	var ctx_spent := {
		"skills": ["basic_cleaning"], "classes": {"warrior": 1},
		"accomplishments": {"used_it": 1}, "names": {"basic_cleaning": "[Basic Cleaning]", "warrior": "Warrior"},
	}
	var d3 := WIDialogue.new(GRAPH, ctx_spent, _sink)
	d3.begin()
	var last_node_event: Dictionary = _events[_events.size() - 1]
	var opts3: Array = d3.current_options()
	assert(opts3.size() == 4, "spent and unmet progress options hidden")
	assert((last_node_event["payload"]["options"] as Array).size() == 4, "dialogue_node payload matches visible list")
	assert(String(opts3[3]["text"]) == "Bye.", "farewell option now at visible index 3")

	var r3 := d3.choose(3)
	assert(r3["ended"] == true, "farewell chosen via its new visible index still ends the dialogue")
	assert(d3.finished, "dialogue ended correctly after hide_when shifted indices")

	test_accomplishment_requires_hides_until_met()
	test_skill_and_class_requires_stay_visible_locked()
	test_ctx_refresh_regates_mid_conversation()
	test_node_text_variants_fall_back_to_base_text_when_unmet()
	test_node_text_variants_use_met_requires()
	test_node_text_variants_last_match_wins()
	test_talk_pool_post_grows_pool_after_gate()
	test_gold_effect_verb_applies_through_dialogue_choose()
	test_well_fed_effect_verb_applies_through_dialogue_choose()
	test_gold_affordability_greys_when_broke()
	test_compound_gold_accomplishment_gate()
	test_once_per_waking_requires_hides_until_used()
	test_once_per_waking_gate_lifecycle_through_bank_first_use()
	test_compound_accomplishment_once_per_waking_gate()

	print("PASS: dialogue graphs walk, gate, hide, and end correctly")
	quit(0)
