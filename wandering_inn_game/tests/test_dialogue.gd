extends SceneTree

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
	return WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)


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


# --- b4 #219 review fixes, pinned on the SHIPPED graph (not a synthetic
# one): the casting row's caster gate has a negative proof (dropping the
# requires would flip this), enrollment survives an accept-then-abandon
# (the accepted_bounty_* hide_when lockout must never return), and both
# first-completion hub variants are executable (no canonical reaches them).
func test_grimalkin_studies_gates_on_the_real_graph() -> void:
	var graph: Dictionary = _load_json("res://data/dialogue/pallass_grimalkin.json")

	var _texts := func(opts: Array) -> Array:
		return opts.map(func(o: Dictionary) -> String: return String(o["text"]))

	# Non-caster, nothing held: studies node hides the casting row.
	var ctx := {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "board_accepted": false}
	var d := WIDialogue.new(graph, ctx, Callable())
	d.begin()
	var hub_texts: Array = _texts.call(d.current_options())
	assert(hub_texts.has("About the studies."), "fresh hub offers the studies entry")
	d.choose(hub_texts.find("About the studies."))
	d.advance("studies")
	var study_texts: Array = _texts.call(d.current_options())
	assert(study_texts.has("Sign me on as a field subject. Three engagements, logged."), "field row is unconditioned")
	assert(not study_texts.has("Measure my casting. Eight witnessed, as posted."),
		"casting row HIDES for a non-caster (the row gate's negative proof)")

	# Caster who accepted then ABANDONED the field study: both rows offer again.
	var ctx2 := {"skills": [], "classes": {}, "accomplishments": {"learned_magic_from_pisces": 1, "accepted_bounty_grimalkin_study_combat": 1}, "names": {}, "board_accepted": false}
	var d2 := WIDialogue.new(graph, ctx2, Callable())
	d2.begin()
	var hub2: Array = _texts.call(d2.current_options())
	d2.choose(hub2.find("About the studies."))
	d2.advance("studies")
	var study2: Array = _texts.call(d2.current_options())
	assert(study2.has("Sign me on as a field subject. Three engagements, logged."),
		"an abandoned study re-offers (accepted_bounty_* counters never reset — hiding on them was the review's lockout)")
	assert(study2.has("Measure my casting. Eight witnessed, as posted."), "caster sees the casting row")

	# First-completion hub variants, both arms verbatim.
	_events.clear()
	var d3 := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {"completed_bounty_grimalkin_study_combat": 1}, "names": {}, "board_accepted": false}, _sink)
	d3.begin()
	assert(String(_events[0]["payload"]["text"]) == "The field subject returns. Your engagement data survived review. It is in the literature now, fourth appendix, entered under a subject number. State your business.",
		"combat-study completion variant verbatim")
	_events.clear()
	var d4 := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {"completed_bounty_grimalkin_study_casting": 1}, "names": {}, "board_accepted": false}, _sink)
	d4.begin()
	assert(String(_events[0]["payload"]["text"]) == "The casting subject. Your wind held past the eighth measure. The file has it already. Speak.",
		"casting-study completion variant verbatim")


# 2026-07-28 (#308, F1): the can-fail pair NO live script can reach. The
# betrayal branch REMOVES the rags_scouting_party entity on victory, so a
# player holding drove_off_rags can never render the settled hub at all --
# floodplains_price_gate_proof proves the exclusion by absence, and only this
# arm proves the hide_when itself both ways on the real graph.
# Every local carries the `f_` lane prefix: three sibling region lanes append
# into this same file in one wave, and a duplicate `var` in one continuous
# function scope is a PARSE error, not a shadow.
func test_rags_winter_offer_hides_for_a_betrayer() -> void:
	var f_graph: Dictionary = _load_json("res://data/dialogue/rags_meeting.json")
	var f_offer := "Winter's coming. What does the camp need?"

	var f_texts := func(opts: Array) -> Array:
		return opts.map(func(o: Dictionary) -> String: return String(o["text"]))

	# Peaceful settle: the offer row renders.
	var f_ctx := {"skills": [], "classes": {}, "names": {},
		"accomplishments": {"met_rags": 1, "rags_price_named": 1, "helped_rags_tribe": 1, "rags_meeting_settled": 1}}
	var f_hub := WIDialogue.new(f_graph, f_ctx, Callable())
	f_hub.begin()
	var f_opts: Array = f_texts.call(f_hub.current_options())
	assert(f_opts.has(f_offer), "a settled peaceful player sees the winter offer")

	# Betrayal close: rags_meeting_settled is banked by the SAME on_victory
	# array as drove_off_rags, so the requires arm alone would let it through.
	var f_ctx_betrayed := {"skills": [], "classes": {}, "names": {},
		"accomplishments": {"met_rags": 1, "rags_price_named": 1, "drove_off_rags": 1, "rags_meeting_settled": 1}}
	var f_hub_betrayed := WIDialogue.new(f_graph, f_ctx_betrayed, Callable())
	f_hub_betrayed.begin()
	var f_opts_betrayed: Array = f_texts.call(f_hub_betrayed.current_options())
	assert(not f_opts_betrayed.has(f_offer),
		"drove_off_rags hides the winter offer even though the betrayal win banks rags_meeting_settled too")


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
	var opts: Array = game.dialogue.current_options()
	assert(not bool(opts[0]["locked"]), "buy option unlocked once affordable (ctx refreshed mid-conversation)")
	game.dialogue_choose(0)  # spend 6 AND grant the sibling item
	assert(game.gold == 4, "gold effect verb spends through dialogue_choose")
	assert(game.inventory.has("leather_jerkin"), "sibling item effect still grants alongside the gold spend")


func test_well_fed_effect_verb_applies_through_dialogue_choose() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "Erin", "text": "t", "options": [
		{"text": "eat", "effects": [{"well_fed": true}], "end": true},
	]}}}
	var game := _make_game_with_dialogue(graph)
	assert(not game.well_fed, "well_fed defaults false")
	game.start_dialogue("test_conv", "erin")
	game.dialogue_choose(0)
	assert(game.well_fed, "well_fed effect verb applies through dialogue_choose")


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


func test_bargain_price_mod_haggle_optin_display_equals_charge() -> void:
	var mk_nodes := func(haggle: bool) -> Dictionary:
		var node := {"speaker": "Eloise", "text": "t", "options": [
			{"text": "The yarrow bundle. (4 gold)", "requires": {"gold": 4}, "effects": [{"gold": -4}, {"item": "dried_yarrow_bundle"}], "end": true},
			{"text": "That pinch of warding salt.", "requires": {"gold": 7}, "effects": [{"gold": -7}, {"item": "warding_salt_pinch"}], "end": true},
			{"text": "Set the board.", "requires": {"gold": 2}, "end": true},
		]}
		if haggle:
			node["haggle"] = true
		return {"start": "shop", "nodes": {"shop": node}}
	var rich_ctx := {"skills": ["bargain"], "classes": {}, "accomplishments": {}, "names": {}, "gold": 100}

	var d := WIDialogue.new(mk_nodes.call(true), rich_ctx.duplicate(true), Callable())
	d.begin()
	var rows: Array = d.current_options()
	assert(String(rows[0]["text"]) == "The yarrow bundle. (3 gold)", "haggle node + [Bargain]: baked-in price rewritten to the discounted figure")
	assert(String(rows[1]["text"]) == "That pinch of warding salt. (6 gold)", "haggle node + [Bargain]: appended price is the discounted figure")
	assert(String(rows[2]["text"]) == "Set the board.", "non-purchase gold gate never decorated with a price")
	var chosen: Dictionary = d.choose(0)
	assert(int((chosen["effects"] as Array)[0]["gold"]) == -3, "the CHARGE equals the rendered price -- the binding display==charge rule")

	var broke_ctx := {"skills": ["bargain"], "classes": {}, "accomplishments": {}, "names": {}, "gold": 3}
	var d2 := WIDialogue.new(mk_nodes.call(true), broke_ctx, Callable())
	d2.begin()
	assert(not bool(d2.current_options()[0]["locked"]), "gate unlocks at the discounted price, matching the rewritten display")
	assert(bool(d2.current_options()[1]["locked"]), "salt (discounted 6) still locked at 3 gold")
	assert(String(d2.current_options()[1]["requirement"]) == "costs 6 gold", "locked requirement text names the SAME discounted figure the display would")

	var d3 := WIDialogue.new(mk_nodes.call(false), rich_ctx.duplicate(true), Callable())
	d3.begin()
	rows = d3.current_options()
	assert(String(rows[0]["text"]) == "The yarrow bundle. (4 gold)", "default node: no discount even for a [Bargain] holder (opt-in inversion)")
	assert(String(rows[1]["text"]) == "That pinch of warding salt. (7 gold)", "default node: appended price is the authored base")
	assert(int((d3.choose(0)["effects"] as Array)[0]["gold"]) == -4, "default node charges the authored price")

	var plain_ctx := {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "gold": 100}
	var d4 := WIDialogue.new(mk_nodes.call(true), plain_ctx, Callable())
	d4.begin()
	assert(String(d4.current_options()[0]["text"]) == "The yarrow bundle. (4 gold)", "haggle node without [Bargain]: authored price, untouched")


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


func test_once_per_waking_refused_in_hide_when() -> void:
	# NEGATIVE CONTROL: feeds the guard the exact shape it refuses, so every
	# call below DELIBERATELY trips WIDialogue's push_error. Error printing is
	# muted for the block and restored in the same function -- the suite's
	# `ERROR:` grep must stay a zero-tolerance signal, and six expected lines
	# are exactly the noise a real regression hides behind (GH#343). Mute the
	# NARROWEST span that still covers every guard-tripping call; never leave
	# it false past this function.
	var printing := Engine.print_error_messages
	Engine.print_error_messages = false
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "follow_up", "hide_when": {"once_per_waking": "meal:erin"}, "end": true},
		{"text": "always", "end": true},
	]}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "entity_first_use": {}}, Callable())
	d.begin()
	var unused_size := d.current_options().size()
	var d2b := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "entity_first_use": {"meal:erin": true}}, Callable())
	d2b.begin()
	var used_size := d2b.current_options().size()
	var combo := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "retired", "hide_when": {"accomplishment": {"done": 1}, "once_per_waking": "meal:erin"}, "end": true},
		{"text": "always", "end": true},
	]}}}
	var d3 := WIDialogue.new(combo, {"skills": [], "classes": {}, "accomplishments": {"done": 1}, "names": {}, "entity_first_use": {}}, Callable())
	d3.begin()
	var combo_size := d3.current_options().size()
	Engine.print_error_messages = printing
	assert(Engine.print_error_messages, "error printing restored before any further assert can fire")
	assert(unused_size == 2, "hide_when once_per_waking refused: option visible while UNUSED (no inverted hide)")
	assert(used_size == 2, "hide_when once_per_waking refused: option visible while USED too (key ignored entirely)")
	assert(combo_size == 1, "combined hide_when: the REAL key (accomplishment, met) still hides -- only once_per_waking is stripped")


func test_erin_meal_seat_is_requires_seated_and_holds_one_per_waking() -> void:
	# GH#343 repro attempt, inverted into a permanent proof: the report claimed
	# erin_errand's meal seat carried once_per_waking in hide_when (ignored ->
	# takeable twice a waking). It does not, and the seat DOES hold. Guards
	# both halves: the SHAPE (no hide_when in the shipped file may carry the
	# key) and the BEHAVIOUR (second take same waking is refused, sleep frees).
	const ERIN_ERRAND := "res://data/dialogue/erin_errand.json"
	var graph := _load_json(ERIN_ERRAND)
	var seat_gates := 0
	for node_id: String in (graph["nodes"] as Dictionary):
		for option: Dictionary in (graph["nodes"][node_id] as Dictionary).get("options", []):
			assert(not (option.get("hide_when", {}) as Dictionary).has("once_per_waking"), "erin_errand %s: once_per_waking must never sit in hide_when (guard ignores it there)" % node_id)
			if (option.get("requires", {}) as Dictionary).get("once_per_waking", "") == "meal:erin":
				seat_gates += 1
	assert(seat_gates == 1, "exactly one erin_errand option is the meal seat, gated in requires")

	var combat_config := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"dialogue": {"erin_errand": graph},
	}
	var game := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	game.record_accomplishment("resolved_wrong_order")
	for _i: int in 4:
		game.record_accomplishment("chatted_with_erin")

	var seat_text := func() -> int:
		var n := 0
		for opt: Dictionary in game.dialogue.current_options():
			if String(opt["text"]).begins_with("(Take the seat."):
				n += 1
		return n

	game.start_dialogue("erin_errand", "erin")
	assert(seat_text.call() == 1, "seat offered once the meal window is open")
	assert(not game.well_fed, "no meal eaten yet")
	var seat_index := -1
	for i: int in game.dialogue.current_options().size():
		if String(game.dialogue.current_options()[i]["text"]).begins_with("(Take the seat."):
			seat_index = i
	game.dialogue_choose(seat_index)
	assert(game.well_fed, "taking the seat banks the meal")
	assert(game.entity_first_use.has("meal:erin"), "bank_first_use wrote the per-waking key")

	game.start_dialogue("erin_errand", "erin")
	assert(seat_text.call() == 0, "SAME waking: the seat is gone -- it cannot be taken twice")
	game.dialogue = null
	game.sleep()
	assert(not game.entity_first_use.has("meal:erin"), "sleep clears the per-waking bank")
	game.start_dialogue("erin_errand", "erin")
	assert(seat_text.call() == 1, "after sleep: the seat is offered again")


func test_picker_presenter_derives_scanable_rows_without_mutating_payload() -> void:
	const PRESENTER_PATH := "res://src/ui/picker_presenter.gd"
	assert(FileAccess.file_exists(PRESENTER_PATH), "picker presenter must exist")
	var presenter_script: Script = load(PRESENTER_PATH)
	var body := "Which one looks worth doing?\n\n1. Cull two rock crabs near the east hills.\n\n2. Carry a watch report to the northern gate."
	var options := [
		{"text": "Take: Rock Crab Cull, East Hills. (5 gold)", "locked": false, "requirement": ""},
		{"text": "Take: Northern Gate Watch. (3 gold)", "locked": false, "requirement": ""},
		{"text": "Never mind.", "locked": false, "requirement": ""},
	]
	var payload: Dictionary = presenter_script.call("derive", body, options)
	assert(String(payload["prompt"]) == "Which one looks worth doing?", "picker prompt stays the authored first line")
	var rows: Array = payload["rows"]
	assert(rows.size() == 3, "every selectable option becomes one visible card")
	assert(rows[0] == {
		"title": "Rock Crab Cull, East Hills",
		"reward": "5 gold",
		"detail": "Cull two rock crabs near the east hills.",
		"locked": false,
		"requirement": "",
		"cancel": false,
	}, "posting card separates title, reward, and target copy")
	assert(rows[1]["detail"] == "Carry a watch report to the northern gate.", "row order remains payload order")
	assert(rows[2]["cancel"] and rows[2]["title"] == "Never mind.", "final cancel option stays selectable and ordered")
	assert(body.contains("1. Cull two rock crabs"), "source body remains byte-identical after derivation")
	assert(options[0]["text"] == "Take: Rock Crab Cull, East Hills. (5 gold)", "source options remain byte-identical after derivation")
	assert(not presenter_script.call("is_picker_payload", "That one? Fine. Logged.", [{"text": "Continue."}]), "same-conversation confirmation node is ordinary dialogue, not a one-row picker")


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


func test_compound_once_per_waking_item_gate() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "Patron", "text": "t", "options": [
		{"text": "serve", "requires": {"once_per_waking": "serve:test_patron", "item": "dish"}, "effects": [{"bank_first_use": "serve:test_patron"}, {"accomplishment": "served"}, {"remove_item": "dish"}], "end": true},
		{"text": "leave", "end": true},
	]}}}
	var game := _make_game_with_dialogue(graph)
	game.start_dialogue("test_conv", "patron")
	var opts: Array = game.dialogue.current_options()
	assert(opts.size() == 2, "unused this waking, item leg unmet: option stays VISIBLE (item is not progress-gated)")
	assert(bool(opts[0]["locked"]), "empty-handed: greyed, not hidden")
	game.dialogue_choose(1)  # leave
	game.pickup("dish", "test")
	game.start_dialogue("test_conv", "patron")
	opts = game.dialogue.current_options()
	assert(not bool(opts[0]["locked"]), "dish in hand: option unlocks")
	game.dialogue_choose(0)  # serve -- consumes the dish, banks once_per_waking
	assert(not (game.inventory as Array).has("dish"), "remove_item effect consumed the dish")
	game.start_dialogue("test_conv", "patron")
	opts = game.dialogue.current_options()
	assert(opts.size() == 1, "served this waking: once_per_waking leg HIDES the option (empty-handed too, both reasons)")
	game.dialogue_choose(0)  # leave (only visible option)
	game.pickup("dish", "test")
	game.start_dialogue("test_conv", "patron")
	opts = game.dialogue.current_options()
	assert(opts.size() == 1, "fresh dish held, same waking: option STAYS hidden (once_per_waking, not item, is the blocker now)")
	game.dialogue_choose(0)  # leave
	game.sleep()
	game.start_dialogue("test_conv", "patron")
	opts = game.dialogue.current_options()
	assert(opts.size() == 2, "after sleep: option is back")
	assert(not bool(opts[0]["locked"]), "the leftover dish from the second cook is still held -- fully unlocked, not just visible")


func test_item_requires_stays_visible_locked() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "give bowl", "requires": {"item": "stew_bowl"}, "end": true},
		{"text": "leave", "end": true},
	]}}}
	var catalog := {"stew_bowl": {"name": "Bowl of Stew"}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "items": catalog, "inventory": []}, Callable())
	d.begin()
	assert(d.current_options().size() == 2, "item gate stays VISIBLE when unmet (matches gold's precedent, not hidden)")
	assert(bool(d.current_options()[0]["locked"]), "unheld item is locked/greyed")
	assert(String(d.current_options()[0]["requirement"]) == "requires Bowl of Stew", "greyed item option names the missing item")

	var d2 := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "items": catalog, "inventory": ["stew_bowl"]}, Callable())
	d2.begin()
	assert(not bool(d2.current_options()[0]["locked"]), "held item unlocks the option")
	assert(not d2.choose(0).is_empty(), "choose() resolves once the item gate is met")


## GH#378 arm 1: the requirement suffix learns an item-level `source_hint`.
## Eleven dialogue files carry 21 hot_meal-gated Serve options and a combat PC
## can never satisfy the gate -- the ruling keeps cooking as the gate but makes
## it LEGIBLE, and one engine seam covers all 21 instances plus every future
## item gate. Three legs: it renders, its absence is inert, and it never leaks
## into an option that is actually unlocked.
func test_item_requires_source_hint_renders_and_absence_is_inert() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "Serve them.", "requires": {"item": "hot_meal"}, "end": true},
		{"text": "give bowl", "requires": {"item": "stew_bowl"}, "end": true},
		{"text": "leave", "end": true},
	]}}}
	var catalog := {
		"hot_meal": {"name": "Hot Meal", "source_hint": "the inn's stew pot, if you know a pot"},
		"stew_bowl": {"name": "Bowl of Stew"},
	}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "items": catalog, "inventory": []}, Callable())
	d.begin()
	var opts := d.current_options()
	assert(String(opts[0]["requirement"]) == "requires Hot Meal — the inn's stew pot, if you know a pot",
		"a source_hint renders as the suffix's second clause, after the item name")
	assert(String(opts[1]["requirement"]) == "requires Bowl of Stew",
		"an item WITHOUT the key keeps the pre-#378 suffix byte-identical -- absence is inert")
	assert(String(opts[2]["requirement"]) == "", "an ungated option carries no requirement at all")

	var d2 := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "items": catalog, "inventory": ["hot_meal"]}, Callable())
	d2.begin()
	assert(not bool(d2.current_options()[0]["locked"]) and String(d2.current_options()[0]["requirement"]) == "",
		"a MET item gate renders no suffix, so the hint can never nag someone already holding the thing")


func test_item_requires_falls_back_to_raw_id_when_uncatalogued() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "give bowl", "requires": {"item": "stew_bowl"}, "end": true},
	]}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "inventory": []}, Callable())
	d.begin()
	assert(bool(d.current_options()[0]["locked"]), "uncatalogued item still locked when unheld")
	assert(String(d.current_options()[0]["requirement"]) == "requires stew_bowl", "uncatalogued item falls back to raw id in requirement text")


func test_item_requires_unlocks_after_real_pickup() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "Krshia", "text": "t", "options": [
		{"text": "hand over the marker", "requires": {"item": "brothers_marker"}, "end": true},
		{"text": "leave", "end": true},
	]}}}
	var game := _make_game_with_dialogue(graph)
	game.start_dialogue("test_conv", "krshia")
	assert(bool(game.dialogue.current_options()[0]["locked"]), "not yet carried -- locked")
	game.dialogue_choose(1)  # leave
	game.pickup("brothers_marker", "test")
	game.start_dialogue("test_conv", "krshia")
	assert(not bool(game.dialogue.current_options()[0]["locked"]), "real pickup() unlocks the item gate")


func test_unrecognized_requires_key_stays_visible_and_locked() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "mystery", "requires": {"nonsense_key": true}, "end": true},
		{"text": "leave", "end": true},
	]}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "inventory": []}, Callable())
	d.begin()
	assert(d.current_options().size() == 2, "unrecognized-only requires key does not hide the option")
	assert(bool(d.current_options()[0]["locked"]), "unrecognized-only requires key fails closed (locked)")
	assert(d.choose(0).is_empty(), "locked-via-unrecognized-key choose still refused")


func test_race_requires_gates_text_variants_both_ways() -> void:
	_events.clear()
	var graph := {"start": "hub", "nodes": {"hub": {
		"speaker": "S",
		"text": "base text",
		"text_variants": [
			{"requires": {"race": "human"}, "text": "human variant"},
			{"requires": {"race": "drake"}, "text": "drake variant"},
		],
		"options": [{"text": "leave", "end": true}],
	}}}
	var human := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "pc_race": "human"}, _sink)
	human.begin()
	assert(String(_events[0]["payload"]["text"]) == "human variant", "requires:{race:human} renders for a Human pc_race")

	_events.clear()
	var drake := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "pc_race": "drake"}, _sink)
	drake.begin()
	assert(String(_events[0]["payload"]["text"]) == "drake variant", "requires:{race:drake} renders for a Drake pc_race -- the OTHER variant never leaks")

	_events.clear()
	var gnoll := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "pc_race": "gnoll"}, _sink)
	gnoll.begin()
	assert(String(_events[0]["payload"]["text"]) == "base text", "an untargeted race (gnoll) falls back to base text -- neither variant matches")


func test_race_requires_on_option_stays_visible_locked() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "drakes only", "requires": {"race": "drake"}, "end": true},
		{"text": "leave", "end": true},
	]}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "pc_race": "human"}, Callable())
	d.begin()
	assert(d.current_options().size() == 2, "race-gated option stays VISIBLE when unmet (not hidden -- race is cosmetic, not progress)")
	assert(bool(d.current_options()[0]["locked"]), "unmet race gate locked")
	assert(d.choose(0).is_empty(), "locked-via-race choose refused")

	var d2 := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "pc_race": "drake"}, Callable())
	d2.begin()
	assert(not bool(d2.current_options()[0]["locked"]), "met race gate unlocked")
	assert(not d2.choose(0).is_empty(), "met race gate choosable")


func test_phase_requires_gates_text_variants_both_ways() -> void:
	_events.clear()
	var graph := {"start": "hub", "nodes": {"hub": {
		"speaker": "S",
		"text": "base text",
		"text_variants": [
			{"requires": {"phase": ["dusk", "night"]}, "text": "dusk-or-night variant"},
			{"requires": {"phase": ["night"]}, "text": "night-only variant"},
		],
		"options": [{"text": "leave", "end": true}],
	}}}
	var day := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "phase": "day"}, _sink)
	day.begin()
	assert(String(_events[0]["payload"]["text"]) == "base text", "an untargeted phase (day) falls back to base text -- neither variant matches")

	_events.clear()
	var dusk := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "phase": "dusk"}, _sink)
	dusk.begin()
	assert(String(_events[0]["payload"]["text"]) == "dusk-or-night variant", "requires:{phase:[dusk,night]} renders at dusk -- the multi-phase set matches")

	_events.clear()
	var night := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "phase": "night"}, _sink)
	night.begin()
	assert(String(_events[0]["payload"]["text"]) == "night-only variant", "at night the LATER-authored night-only variant wins over the earlier dusk-or-night variant (last match wins)")


func test_phase_requires_on_option_stays_visible_locked() -> void:
	var graph := {"start": "hub", "nodes": {"hub": {"speaker": "S", "text": "t", "options": [
		{"text": "night only", "requires": {"phase": ["night"]}, "end": true},
		{"text": "leave", "end": true},
	]}}}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "phase": "day"}, Callable())
	d.begin()
	assert(d.current_options().size() == 2, "phase-gated option stays VISIBLE when unmet (not hidden -- phase is derived state, not progress)")
	assert(bool(d.current_options()[0]["locked"]), "unmet phase gate locked")
	assert(d.choose(0).is_empty(), "locked-via-phase choose refused")

	var d2 := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}, "phase": "night"}, Callable())
	d2.begin()
	assert(not bool(d2.current_options()[0]["locked"]), "met phase gate unlocked")
	assert(not d2.choose(0).is_empty(), "met phase gate choosable")


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


func test_talk_pool_post_grows_pool_after_gate() -> void:
	_events.clear()
	var game := _make_game_with_dialogue({})
	var scene := WISceneCatalog.compose()
	var lyo := _find_entity(scene, "inn", "lyonette")
	var base_pool: Array = lyo["talk_pool"]
	var post_lines: Array = ((lyo["talk_pool_stages"] as Array)[0] as Dictionary)["lines"]
	game.player_cell = Vector2i(8, 5)
	game.player_facing = Vector2i(1, 0)
	game.interact()
	var before := _last_line_text()
	assert(base_pool.has(before), "pre-resolution talk draws from the BASE talk_pool")
	assert(not post_lines.has(before), "pre-resolution talk is NOT a grown line")
	game.record_accomplishment("resolved_wrong_order")
	game.sleep()
	_events.clear()
	game.player_cell = Vector2i(8, 5)
	game.player_facing = Vector2i(1, 0)
	game.interact()
	var after := _last_line_text()
	assert(post_lines.has(after), "post-resolution talk draws from the GROWN talk_pool_post")
	assert(not base_pool.has(after), "post-resolution talk REPLACED the base pool, not merged it")


## GH#323 per-line proof. The three ORIGINAL Horns inn rows live in exactly one
## window -- seal_kept_reported banked, horns_dig_started not yet -- and their
## settled stages used to gate on door_awakened, which sits far past the closing
## counter. Nine lines that could never render. This walks each stage LIVE
## inside that window and pins every line, so re-gating either arm behind an
## out-of-window counter reds immediately. The `_returned` twins keep
## door_awakened; their own window opens at door_mounted (asserted here too, so
## the two arms can never be collapsed by accident).
func test_horns_inn_settled_stages_serve_inside_their_own_window() -> void:
	var scene := WISceneCatalog.compose()
	for row: Array in [["ceria_inn", Vector2i(8, 6)], ["yvlon_inn", Vector2i(2, 3)], ["ksmvr_inn", Vector2i(14, 7)]]:
		var id := String(row[0])
		var cell: Vector2i = row[1]
		var ent := _find_entity(scene, "inn", id)
		assert(not ent.is_empty(), "inn carries %s" % id)
		var base_pool: Array = ent["talk_pool"]
		var stage: Dictionary = (ent["talk_pool_stages"] as Array)[0]
		var settled: Array = stage["lines"]
		assert(settled.size() == 3, "%s settled stage carries three lines" % id)

		var game := _make_game_with_dialogue({})
		assert(not game.entity_present(ent), "%s is absent before seal_kept_reported" % id)
		game.record_accomplishment("seal_kept_reported")
		assert(game.entity_present(ent), "%s stands in the inn once the seal is reported" % id)
		var twin := _find_entity(scene, "inn", id + "_returned")
		assert(not game.entity_present(twin), "%s_returned stays away -- the twin's window opens at door_mounted" % id)

		# One pool line per waking (social_talked clears at sleep). Chats 1-3
		# spend the base pool and carry the counter to the stage threshold;
		# chats 4-6 must serve settled lines 0, 1, 2 in order.
		var served: Array = []
		for chat: int in 6:
			_events.clear()
			game.player_cell = cell - Vector2i(0, 1)
			game.player_facing = Vector2i(0, 1)
			game.interact()
			served.append(_last_line_text())
			game.sleep()
			assert(game.accomplishment_count("horns_dig_started") == 0, "%s: the window never closed under us" % id)
			assert(game.accomplishment_count("door_awakened") == 0, "%s: door_awakened stays unheld all window long -- the old gate's exact problem" % id)
		for i: int in 3:
			assert(served[i] == String(base_pool[i]), "%s chat %d serves base pool line %d" % [id, i + 1, i])
		for i: int in 3:
			assert(served[i + 3] == String(settled[i]), "%s chat %d serves SETTLED line %d (dead before GH#323)" % [id, i + 4, i])
		assert(game.entity_present(ent), "%s is still standing there after six wakings -- the window never needed the dig" % id)


## GH#349, review-wave repair. Pisces's inn greet grew a residence arm that
## seats his team "in the corner by the fire". `text_variants` has no hide_when
## (dialogue.gd `_resolved_text` reads `requires` only, LAST MATCH WINS), so a
## single seal_kept_reported arm kept describing an occupied corner right
## through the dig window -- horns_dig_started retires all three original Horns
## rows and the `_returned` twins do not arm until door_mounted, so for that
## whole stretch no Horn is on the inn map at all. The contract this pins is
## not "which text" but the INVARIANT: the greet may only claim the corner in
## states where the scene catalog actually stands a Horn in the inn.
func test_pisces_inn_greet_never_seats_the_horns_in_an_empty_corner() -> void:
	var scene := WISceneCatalog.compose()
	var graph := _load_json("res://data/dialogue/pisces_inn.json")
	var horn_rows: Array = []
	for id: String in ["ceria_inn", "yvlon_inn", "ksmvr_inn", "ceria_inn_returned", "yvlon_inn_returned", "ksmvr_inn_returned"]:
		var ent := _find_entity(scene, "inn", id)
		assert(not ent.is_empty(), "inn carries %s" % id)
		horn_rows.append(ent)

	# Every state the guest row can be interacted in, walked in arc order.
	var states: Array = [
		{},
		{"seal_kept_reported": 1},
		{"seal_kept_reported": 1, "horns_dig_started": 1},
		{"seal_kept_reported": 1, "horns_dig_started": 1, "horns_dig_joined": 1},
		{"seal_kept_reported": 1, "horns_dig_started": 1, "door_retrieved": 1},
		{"seal_kept_reported": 1, "horns_dig_started": 1, "door_retrieved": 1, "door_mounted": 1},
	]
	var claimed_at_least_once := false
	var declined_at_least_once := false
	for banked: Dictionary in states:
		var game := _make_game_with_dialogue({})
		for id: String in banked:
			for _i: int in int(banked[id]):
				game.record_accomplishment(id)
		var a_horn_is_here := false
		for ent: Dictionary in horn_rows:
			if game.entity_present(ent):
				a_horn_is_here = true
		_events.clear()
		var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": banked, "names": {}}, _sink)
		d.begin()
		var text := String(_events[0]["payload"]["text"]).to_lower()
		var claims_the_corner := text.contains("annexed the corner") or text.contains("reclaimed the corner")
		if claims_the_corner:
			claimed_at_least_once = true
			assert(a_horn_is_here, "pisces_inn greet claims the corner at %s, and no Horns inn row is present there" % [banked])
		else:
			declined_at_least_once = true
		if a_horn_is_here:
			assert(claims_the_corner, "a Horn IS in the inn at %s and the greet has dropped the residence reading" % [banked])
		else:
			assert(not text.contains("annexed the corner"), "the empty-corner window must not serve the occupied-corner line")
	assert(claimed_at_least_once, "the residence arm is reachable in at least one shipped state")
	assert(declined_at_least_once, "at least one shipped state serves a non-corner greet -- otherwise the arm is unconditional")


## GH#332. Both tame props are consumed permanently and a downed companion was
## gone for good, so one bad fight could exhaust taming forever. Three halves,
## all pinned here, and two of them are review-wave repairs:
##  1. Only a TAMED death banks `companion_lost`. A swap and a sleep expiry
##     were always excluded; an ANIMATED summon going down in a fight is the
##     one the first cut missed, and `_combat_event_relay` routes EVERY downed
##     companion through `_clear_companion("downed")`, so a necromancer with
##     three bone piles and no [Lesser Bond] used to burn the whole ladder.
##  2. A rung NEVER closes on the counter. The first cut gave rungs 1 and 2 an
##     `absent` arm one count above their own, so a player who lost a bond in
##     the floodplains and the next one in a dungeon came back to a rung
##     erased unclaimed. Rungs accumulate; being TAKEN is what retires them.
##  3. No rung is offered while a bond already rides.
## Lives in this file because it is a content-gate proof and this is one of the
## two test files the content lane owns; the sim-side clear is called at its
## own seam.
func test_companion_loss_reopens_a_den_one_rung_at_a_time() -> void:
	var scene := WISceneCatalog.compose()
	var rungs := {
		"wolf_den_spring": _find_entity(scene, "floodplains", "wolf_den_spring"),
		"razorbeak_chick_fledgling": _find_entity(scene, "floodplains", "razorbeak_chick_fledgling"),
		"wolf_den_late_litter": _find_entity(scene, "floodplains", "wolf_den_late_litter"),
	}
	for id: String in rungs:
		assert(not (rungs[id] as Dictionary).is_empty(), "floodplains carries the spring-litter rung %s" % id)

	# Rungs coexist now, so two of them may never sit on the same cell.
	var seen_cells: Array = []
	for id: String in rungs:
		var cell: Array = (rungs[id] as Dictionary)["cell"]
		assert(not seen_cells.has(cell), "spring-litter rung %s shares a cell with an earlier rung; they can be live together" % id)
		seen_cells.append(cell)

	var live := func(game: WIGame) -> Array:
		var out: Array = []
		for id: String in ["wolf_den_spring", "razorbeak_chick_fledgling", "wolf_den_late_litter"]:
			if game.entity_present(rungs[id] as Dictionary):
				out.append(id)
		return out

	var game := _make_game_with_dialogue({})
	assert(game.entity_present(_find_entity(scene, "floodplains", "wolf_den")), "the original den still stands on a fresh save")
	assert(live.call(game).is_empty(), "no spring rung is offered before any bond is lost")

	# Only a TAMED death banks. A swap, a sleep expiry, and an animated summon
	# going down in a fight must not.
	game.companion = "wolf_companion"
	game.companion_source = "tamed"
	game._clear_companion("released")
	assert(game.accomplishment_count("companion_lost") == 0, "swapping bonds is a choice, not a loss")
	game.companion = "skeleton_ally"
	game.companion_source = "animated"
	game._clear_companion("sleep")
	assert(game.accomplishment_count("companion_lost") == 0, "an animated follower expiring at sleep is not a loss")
	game.companion = "skeleton_ally"
	game.companion_source = "animated"
	game._clear_companion("downed")
	assert(game.accomplishment_count("companion_lost") == 0, "a DOWNED ANIMATED summon is a spent working, not a lost bond -- it may not burn a ladder rung")
	assert(live.call(game).is_empty(), "no rung opens for a skeleton the player could never have bonded")

	game.companion = "wolf_companion"
	game.companion_source = "tamed"
	game._clear_companion("downed")
	assert(game.accomplishment_count("companion_lost") == 1, "a DOWNED TAMED companion banks the loss")
	assert(game.companion == "", "the bond slot is empty after the clear")
	assert(live.call(game) == ["wolf_den_spring"], "first loss opens rung 1 and only rung 1")

	# The wild does not offer while a bond already walks with you.
	game.companion = "razorbeak_companion"
	assert(live.call(game).is_empty(), "no rung is offered while a companion rides")
	game.companion = ""

	# An UNCLAIMED rung survives the next loss. This is the review-wave repro:
	# lose a bond in the floodplains, lose the next one somewhere else, come
	# back -- rung 1 must still be standing, because the player was never
	# offered it.
	game.record_accomplishment("companion_lost")
	assert(live.call(game) == ["wolf_den_spring", "razorbeak_chick_fledgling"], "a second loss opens rung 2 WITHOUT erasing the rung 1 the player never walked back to")
	game.record_accomplishment("companion_lost")
	assert(live.call(game) == ["wolf_den_spring", "razorbeak_chick_fledgling", "wolf_den_late_litter"], "three losses stand three unclaimed rungs -- the ladder's advertised depth")
	game.record_accomplishment("companion_lost")
	assert(live.call(game).size() == 3, "no rung carries an `absent`, so none closes past its own count")

	# TAKEN is what retires a rung: `remove_entity` appends to the persisted
	# `removed_entities`, which is why the counter-based `absent` arms were
	# both unnecessary and destructive.
	game.remove_entity("wolf_den_spring")
	assert(game.removed_entities.has("wolf_den_spring"), "bonding a rung removes it for good, and the removal persists")


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



## v0.15 T4.3 round 3: THE FINISHED-BUT-NOT-NULLED WALKER, the case world.gd's
## `_dialogue_is_open()` guards. `WIGame.dialogue_choose` nulls `Game.sim.dialogue`
## only when `choose()` returns `ended: true`; `_enter`'s softlock fail-safe sets
## `finished` from INSIDE `advance()` instead, on a goto whose target node has
## every option gated shut. That leaves a live, finished walker parked on the sim
## -- so a bare `dialogue != null` check would defer presence reconciles forever.
func test_finished_walker_survives_a_goto_into_an_all_hidden_node() -> void:
	_events.clear()
	var graph := {
		"start": "hub",
		"nodes": {
			"hub": {"speaker": "A", "text": "hub", "options": [{"text": "on", "goto": "shut"}]},
			# Every option requires a counter the ctx does not carry, so
			# `_visible_options()` comes back empty on a node that HAS options.
			"shut": {"speaker": "A", "text": "shut", "options": [
				{"text": "locked", "requires": {"accomplishment": {"never_banked": 1}}, "end": true},
			]},
		},
	}
	var d := WIDialogue.new(graph, {"skills": [], "classes": {}, "accomplishments": {}, "names": {}}, _sink)
	d.begin()
	var r := d.choose(0)
	assert(r["ended"] == false, "a goto option reports ended:false -- which is what leaves the walker non-null in WIGame")
	d.advance(String(r["next"]))
	assert(d.current_id == "shut", "advanced into the all-hidden node")
	assert(d.current_options().is_empty(), "the node's only option is requires-hidden")
	assert(d.finished, "_enter's softlock fail-safe finished the walker without choose() ever returning ended:true")
	assert(_count("dialogue_ended") == 1, "DIALOGUE_ENDED still fires exactly once from the fail-safe")


## v0.15 T5 (folded engine fix, filed off P4's re-review): the arm above proves
## WIDialogue finishes ITSELF; this one proves WIGame does not leave the corpse
## parked. Every consumer gate in the game is a bare `Game.sim.dialogue != null`
## (movement/interact in wi_game, inventory, journal, pause, field chips, and
## `start_dialogue`'s own re-entry guard), so a finished-but-live walker is a
## whole SOFTLOCK CLASS, not one bug: nothing would ever clear it. world.gd's
## `_dialogue_is_open()` defends one gate with `not finished`; the sim clears the
## walker for all of them. No shipped graph reaches the fail-safe (every node
## keeps an ungated exit) -- the class dies here anyway.
func _all_hidden_after_goto_graph() -> Dictionary:
	return {
		"start": "hub",
		"nodes": {
			"hub": {"speaker": "A", "text": "hub", "options": [{"text": "on", "goto": "shut"}]},
			"shut": {"speaker": "A", "text": "shut", "options": [
				{"text": "locked", "requires": {"accomplishment": {"never_banked": 1}}, "end": true},
			]},
		},
	}


func test_wigame_nulls_the_walker_the_fail_safe_finished() -> void:
	_events.clear()
	var game := _make_game_with_dialogue(_all_hidden_after_goto_graph())
	assert(game.start_dialogue("test_conv", "npc_x"), "conversation opens on the hub")
	assert(game.dialogue != null, "walker parked while the hub is live")
	assert(game.dialogue_choose(0), "the goto option resolves (choose() reports ended:false)")
	assert(game.dialogue == null, "the fail-safe's finish NULLS the sim walker -- the softlock class")
	assert(_count("dialogue_ended") == 1, "DIALOGUE_ENDED still fires exactly once, from the fail-safe")

	# The gate that proves it: a second conversation must be able to open.
	# `start_dialogue` refuses while `dialogue != null`, so this is the whole
	# softlock in one assert.
	assert(game.start_dialogue("test_conv", "npc_x"), "a NEW dialogue starts after the fail-safe close")
	assert(game.dialogue != null and not game.dialogue.finished, "the new walker is live, not the old corpse")


## Same class through `begin()`: a graph whose START node has every option gated
## shut finishes inside `start_dialogue` itself, before any choose() runs.
func test_wigame_nulls_a_walker_the_fail_safe_finished_at_begin() -> void:
	_events.clear()
	var graph := {"start": "shut", "nodes": {"shut": {"speaker": "A", "text": "shut", "options": [
		{"text": "locked", "requires": {"accomplishment": {"never_banked": 1}}, "end": true},
	]}}}
	var game := _make_game_with_dialogue(graph)
	assert(game.start_dialogue("test_conv", "npc_x"), "the line still renders (DIALOGUE_NODE emitted) before it closes")
	assert(_count("dialogue_started") == 1 and _count("dialogue_ended") == 1, "open/close pair stays balanced for the UI listeners")
	assert(game.dialogue == null, "a walker the fail-safe finished at begin() is never parked either")
	assert(game.start_dialogue("test_conv", "npc_x"), "and the next conversation still opens")


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

	var d2 := WIDialogue.new(GRAPH, ctx, _sink)
	d2.begin()
	var d2_chat := d2.choose(0)
	d2.advance(String(d2_chat["next"]))
	assert(d2.current_id == "chat", "goto chat")
	var d2_hub := d2.choose(0)
	d2.advance(String(d2_hub["next"]))
	assert(d2.current_id == "hub", "hub loop-back works")

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
	test_horns_inn_settled_stages_serve_inside_their_own_window()
	test_pisces_inn_greet_never_seats_the_horns_in_an_empty_corner()
	test_companion_loss_reopens_a_den_one_rung_at_a_time()
	test_gold_effect_verb_applies_through_dialogue_choose()
	test_well_fed_effect_verb_applies_through_dialogue_choose()
	test_gold_affordability_greys_when_broke()
	test_compound_gold_accomplishment_gate()
	test_bargain_price_mod_haggle_optin_display_equals_charge()
	test_once_per_waking_requires_hides_until_used()
	test_once_per_waking_refused_in_hide_when()
	test_erin_meal_seat_is_requires_seated_and_holds_one_per_waking()
	test_picker_presenter_derives_scanable_rows_without_mutating_payload()
	test_once_per_waking_gate_lifecycle_through_bank_first_use()
	test_compound_accomplishment_once_per_waking_gate()
	test_compound_once_per_waking_item_gate()
	test_item_requires_stays_visible_locked()
	test_item_requires_source_hint_renders_and_absence_is_inert()
	test_item_requires_falls_back_to_raw_id_when_uncatalogued()
	test_item_requires_unlocks_after_real_pickup()
	test_unrecognized_requires_key_stays_visible_and_locked()
	test_race_requires_gates_text_variants_both_ways()
	test_race_requires_on_option_stays_visible_locked()
	test_phase_requires_gates_text_variants_both_ways()
	test_phase_requires_on_option_stays_visible_locked()
	test_grimalkin_studies_gates_on_the_real_graph()
	test_rags_winter_offer_hides_for_a_betrayer()
	test_finished_walker_survives_a_goto_into_an_all_hidden_node()
	test_wigame_nulls_the_walker_the_fail_safe_finished()
	test_wigame_nulls_a_walker_the_fail_safe_finished_at_begin()

	print("PASS: dialogue graphs walk, gate, hide, and end correctly")
	quit(0)
