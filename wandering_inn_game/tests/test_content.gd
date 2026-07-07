extends SceneTree
## Cross-reference validation for authored content.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_content.gd

const DIALOGUE_DIR := "res://data/dialogue"

## M-LEGIBILITY L5: every data file that carries player-facing strings, for
## `_validate_player_string_vocab`'s recursive sweep (dialogue/*.json is
## walked separately below, via the same DIALOGUE_DIR enumeration
## `_load_dialogue_graphs` uses). Deliberately excludes files with NO player
## text (biomes/moods/audio/sprites.json -- asset paths + dev `_comment`s
## only, confirmed by hand before this list was written).
const PLAYER_STRING_FILES := [
	"res://data/items.json",
	"res://data/skills.json",
	"res://data/quests.json",
	"res://data/acts.json",
	"res://data/classes.json",
	"res://data/skeleton_scene.json",
	"res://data/combatants.json",
	"res://data/arenas.json",
	"res://data/bounties.json",
	"res://data/deliveries.json",
]


func _init() -> void:
	WITestWatchdog.arm(self)
	var graphs: Dictionary = _load_dialogue_graphs()
	var quests: Dictionary = _load_json("res://data/quests.json")
	var scene: Dictionary = _load_json("res://data/skeleton_scene.json")
	var skills: Dictionary = _load_json("res://data/skills.json")
	var classes: Dictionary = _load_json("res://data/classes.json")

	var skill_ids: Dictionary = _ids_from_catalog(skills, "skills")
	var class_ids: Dictionary = _ids_from_catalog(classes, "classes")
	var quest_ids: Dictionary = _ids_from_catalog(quests, "quests")
	var entity_ids: Dictionary = _entity_ids(scene)
	var produced_accomplishments: Dictionary = {}

	_collect_scene_accomplishments(scene, produced_accomplishments)
	_validate_conversations(scene, graphs)
	_validate_dialogue_graphs(graphs, skill_ids, class_ids, quest_ids, entity_ids, produced_accomplishments)
	_validate_quests(quests, produced_accomplishments)
	_validate_hide_when_nodes_have_always_available_exit(graphs)
	_validate_class_gains(classes, produced_accomplishments)
	_validate_props(scene)
	_validate_talk_pool_stages_ascending(scene)
	_validate_effect_text_opacity()
	_validate_player_string_vocab()
	_validate_once_per_waking_shape_cases()

	print("PASS: errand content is fully cross-referenced")
	quit(0)


## M-LEGIBILITY L1: the FORBIDDEN-vocabulary grep over WIEffectText's output
## across the FULL item + Skill + status catalogs. No generated player line may
## carry a raw attribute (STR/DEX/CON/INT/WIS/CHA as a whole word) or a
## percentage-toward ('%'). This runs the real formatter over the shipped data,
## so it also catches a new item/skill whose fields would render a forbidden
## token. (Exact-string coverage + drift tripwires live in test_effect_text.gd.)
func _validate_effect_text_opacity() -> void:
	var attr := RegEx.new()
	attr.compile("(?i)\\b(str|dex|con|int|wis|cha)\\b")
	var lines: Array[String] = []
	for item: Dictionary in _load_json("res://data/items.json").get("items", []):
		lines.append_array(WIEffectText.item_effect_lines(item))
	for skill: Dictionary in _load_json("res://data/skills.json").get("skills", []):
		lines.append_array(WIEffectText.skill_effect_lines(skill))
	# Every status a shipped Skill can apply, glossary-rendered.
	var status_ids: Dictionary = {}
	for skill: Dictionary in _load_json("res://data/skills.json").get("skills", []):
		var applies: Dictionary = (skill.get("effect", {}) as Dictionary).get("applies", {})
		for status_id: String in applies:
			status_ids[status_id] = true
	for status_id: String in status_ids:
		lines.append(WIEffectText.status_line(status_id))
	for line: String in lines:
		assert(attr.search(line) == null, "effect_text emits a forbidden attribute token: " + line)
		assert(not line.contains("%"), "effect_text emits a forbidden percent-toward token: " + line)


## M-LEGIBILITY L5: forbidden-vocab sweep over every player-string FIELD in
## content data, not just WIEffectText's GENERATED lines (that narrower sweep
## is `_validate_effect_text_opacity`, above, which exercises the formatter
## itself and stays separate). BEFORE this task the grep only ever reached
## effect_text's output; AFTER, it recurses through every raw string value in
## PLAYER_STRING_FILES (item/skill names+descriptions+field_ambient+
## freeze_toast, quest/act titles+beat text, class aspiration text,
## skeleton_scene toasts/talk_pools/talk_pool_post/dialogue/friendly_line/
## observed_line, combatant display_names, arena tutor_lines) plus every
## dialogue graph (node/option text, text_variants) in DIALOGUE_DIR -- the
## full candidate list the task brief named. Recursion (not a hand-enumerated
## field list) means a NEW field added anywhere in these files is covered
## automatically, with no second place to keep in sync. Dict keys prefixed
## "_" (the "_comment"/"_comment_pool" dev-annotation convention used
## throughout data/*.json) are skipped -- they are never rendered to a
## player. Verified empirically before wiring this in: a dry-run scan (skip
## "_"-prefixed keys) over every listed file found zero forbidden tokens
## today, so this sweep starts green, not red.
func _validate_player_string_vocab() -> void:
	var attr := RegEx.new()
	attr.compile("(?i)\\b(str|dex|con|int|wis|cha)\\b")
	for path: String in PLAYER_STRING_FILES:
		_scan_player_strings(_load_json(path), path, attr)
	var dir: DirAccess = DirAccess.open(DIALOGUE_DIR)
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			var full_path := DIALOGUE_DIR.path_join(file_name)
			_scan_player_strings(_load_json(full_path), full_path, attr)


## Recurses through an arbitrary parsed-JSON value, applying the forbidden-
## attribute regex + a literal-percent check to every String leaf. Dictionary
## keys starting with "_" are skipped entirely (dev comments, never player-
## facing) -- their VALUES are never visited, so a `_comment` field can freely
## discuss STR/DEX/percentages as design notes without tripping the sweep.
func _scan_player_strings(node: Variant, path: String, attr: RegEx) -> void:
	if node is Dictionary:
		for key: String in (node as Dictionary):
			if key.begins_with("_"):
				continue
			_scan_player_strings((node as Dictionary)[key], "%s.%s" % [path, key], attr)
	elif node is Array:
		for i: int in (node as Array).size():
			_scan_player_strings((node as Array)[i], "%s[%d]" % [path, i], attr)
	elif node is String:
		var s := node as String
		assert(attr.search(s) == null, "%s carries a forbidden attribute token: %s" % [path, s])
		assert(not s.contains("%"), "%s carries a forbidden percent-toward token: %s" % [path, s])


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _load_dialogue_graphs() -> Dictionary:
	var graphs: Dictionary = {}
	var dir: DirAccess = DirAccess.open(DIALOGUE_DIR)
	assert(dir != null, "missing dialogue directory")
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			graphs[file_name.get_basename()] = _load_json(DIALOGUE_DIR.path_join(file_name))
	assert(not graphs.is_empty(), "no dialogue graphs found")
	return graphs


func _ids_from_catalog(catalog: Dictionary, key: String) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in catalog.get(key, []):
		out[String(entry["id"])] = true
	return out


func _entity_ids(scene: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			out[String(entity["id"])] = true
	return out


func _collect_scene_accomplishments(scene: Dictionary, produced: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var victory: Variant = entity.get("on_victory", [])
			if victory is Array:
				for id: Variant in victory:
					produced[String(id)] = true
			elif victory is String:
				produced[String(victory)] = true
			if entity.has("on_skill_use"):
				var skill_use: Dictionary = entity["on_skill_use"]
				if skill_use.has("accomplishment"):
					produced[String(skill_use["accomplishment"])] = true
			if entity.has("on_interact_accomplishment"):
				produced[String(entity["on_interact_accomplishment"])] = true
			# Magical Door plan Task D3: a container's optional
			# `on_open_accomplishment` (src/core/wi_game.gd's _interact_container)
			# is a producer too, same shape as on_interact_accomplishment above.
			if entity.has("on_open_accomplishment"):
				produced[String(entity["on_open_accomplishment"])] = true
			# Social Pillar S1/S3: a non-empty talk_pool makes the sim's
			# _talk_pool_line bank heard_gossip (+1) and chatted_with_<id> (+1) on
			# the first talk of each waking. The bank happens in the sim, not a
			# scanned data field, so record it here as genuinely content-produced
			# -- this is what lets a [Diplomat]-style gained_by / threshold keyed on
			# heard_gossip cross-reference cleanly (see _validate_class_gains).
			if entity.has("talk_pool") and not (entity["talk_pool"] as Array).is_empty():
				produced["heard_gossip"] = true
				produced["chatted_with_%s" % String(entity["id"])] = true


## Social Pillar II Phase A: `talk_pool_stages` authoring must be ASCENDING
## (the visual_states/classes.json level-table convention social.gd's
## talk_pool_line relies on -- it walks the array in AUTHORED order and lets
## the LAST entry whose gate is met win; it does NOT sort by difficulty).
## Misordered content would silently behave as "whichever stage is authored
## LAST", not "whichever stage's condition is hardest" -- REJECTED here at
## content-validation time rather than tolerated at runtime, per the design's
## "rejected or normalized (disclose which)" unit requirement. Ascending is
## checked per shared accomplishment key: for every key that appears in more
## than one stage's requires_accomplishment, its threshold must never
## DECREASE from one stage to the next.
func _validate_talk_pool_stages_ascending(scene: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var stages: Array = entity.get("talk_pool_stages", [])
			if stages.size() < 2:
				continue
			var seen: Dictionary = {}
			for stage: Dictionary in stages:
				var req: Dictionary = stage.get("requires_accomplishment", {})
				for key: String in req:
					var threshold := int(req[key])
					if seen.has(key):
						assert(threshold >= int(seen[key]), "entity %s talk_pool_stages authored OUT OF ORDER: stage %s's %s threshold (%d) is lower than an earlier stage's (%d)" % [String(entity["id"]), String(stage.get("id", "?")), key, threshold, int(seen[key])])
					seen[key] = threshold


func _validate_conversations(scene: Dictionary, graphs: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			if entity.has("conversation"):
				var conversation_id: String = String(entity["conversation"])
				assert(graphs.has(conversation_id), "entity %s conversation has no graph: %s" % [String(entity["id"]), conversation_id])


func _validate_dialogue_graphs(
	graphs: Dictionary,
	skill_ids: Dictionary,
	class_ids: Dictionary,
	quest_ids: Dictionary,
	entity_ids: Dictionary,
	produced_accomplishments: Dictionary
) -> void:
	for graph_id: String in graphs:
		var graph: Dictionary = graphs[graph_id]
		var nodes: Dictionary = graph["nodes"]
		assert(nodes.has(String(graph["start"])), "%s start node missing: %s" % [graph_id, String(graph["start"])])
		for node_id: String in nodes:
			var node: Dictionary = nodes[node_id]
			_validate_node(graph_id, node_id, node, skill_ids, class_ids)
			for option_index: int in (node.get("options", []) as Array).size():
				var option: Dictionary = (node.get("options", []) as Array)[option_index]
				_validate_option(graph_id, node_id, option_index, option, nodes, skill_ids, class_ids, quest_ids, entity_ids, produced_accomplishments)


func _validate_node(graph_id: String, node_id: String, node: Dictionary, skill_ids: Dictionary, class_ids: Dictionary) -> void:
	var label: String = "%s.%s" % [graph_id, node_id]
	assert(node.has("speaker"), label + " missing speaker")
	assert(node.has("text"), label + " missing text")
	if node.has("text_variants"):
		assert(node["text_variants"] is Array, label + " text_variants must be an array")
		for variant_index: int in (node["text_variants"] as Array).size():
			var variant: Dictionary = (node["text_variants"] as Array)[variant_index]
			var variant_label: String = "%s text_variants[%d]" % [label, variant_index]
			assert(variant.has("text"), variant_label + " missing text")
			assert(variant.has("requires"), variant_label + " missing requires")
			assert(variant["requires"] is Dictionary, variant_label + " requires must be a dictionary")
			_validate_requires(variant_label, variant["requires"], skill_ids, class_ids)


func _validate_option(
	graph_id: String,
	node_id: String,
	option_index: int,
	option: Dictionary,
	nodes: Dictionary,
	skill_ids: Dictionary,
	class_ids: Dictionary,
	quest_ids: Dictionary,
	entity_ids: Dictionary,
	produced_accomplishments: Dictionary
) -> void:
	var label: String = "%s.%s[%d]" % [graph_id, node_id, option_index]
	var has_goto: bool = option.has("goto")
	var has_end: bool = option.has("end")
	assert(has_goto != has_end, label + " must have exactly one of goto/end")
	if has_goto:
		assert(nodes.has(String(option["goto"])), label + " goto target missing: " + String(option["goto"]))
	if has_end:
		assert(bool(option["end"]), label + " end must be true")
	if option.has("requires"):
		_validate_requires(label, option["requires"], skill_ids, class_ids)
	if option.has("hide_when"):
		# Issue #23 fix wave (review finding 1): once_per_waking is a
		# REQUIRES-ONLY gate -- its "met" polarity ("not yet used this
		# waking") is inverted relative to every shipped hide_when key's
		# ("the tracked state is now true"), so a hide_when carrying it is a
		# content ERROR rejected loudly here, not just a runtime refusal
		# (WIDialogue._meets_hide_when is the belt-and-suspenders half).
		assert(_hide_when_gate_keys_allowed(option["hide_when"]), label + " hide_when must not carry once_per_waking (requires-only gate, Issue #23)")
		_validate_requires(label + " hide_when", option["hide_when"], skill_ids, class_ids)
	for effect: Dictionary in option.get("effects", []):
		_validate_effect(label, effect, quest_ids, class_ids, entity_ids, produced_accomplishments)


## Shared by both "requires" and "hide_when" -- both use the same condition
## forms ({skill}|{class: {id: min}}|{accomplishment: {id: min}}), so both are
## validated against the same known-id catalogs. Accomplishment ids are not
## checked against a catalog here (they're free-form, cross-referenced instead
## via produced_accomplishments in _validate_quests). EXCEPTION (Issue #23 fix
## wave): `once_per_waking` is requires-only -- _validate_option rejects it in
## a hide_when dict BEFORE this shared body runs (see
## _hide_when_gate_keys_allowed).
func _validate_requires(label: String, requires: Dictionary, skill_ids: Dictionary, class_ids: Dictionary) -> void:
	var gate_keys := 0
	if requires.has("skill"):
		gate_keys += 1
		var skill_id: String = String(requires["skill"])
		assert(skill_ids.has(skill_id), label + " requires unknown skill: " + skill_id)
	if requires.has("class"):
		gate_keys += 1
		var classes_required: Dictionary = requires["class"]
		for class_id: String in classes_required:
			assert(class_ids.has(class_id), label + " requires unknown class: " + class_id)
	if requires.has("accomplishment"):
		gate_keys += 1
	if requires.has("board_accepted"):
		# M-DEPTH DP2: the THIRD sanctioned single-key gate (after
		# accomplishment/gold) -- WIDialogue._meets/_progress_gated's
		# board_accepted ctx-flag check (Selys's "Take on a posting."/"Turn in
		# my posting." hub options, selys_delivery.json). Bool value only; it
		# is never combined with another gate type in authored content.
		gate_keys += 1
		assert(requires["board_accepted"] is bool, label + " board_accepted must be a bool")
	if requires.has("delivery_accepted"):
		# M-DEPTH DP5: the FOURTH sanctioned single-key gate --
		# board_accepted's exact twin for the Runner's Guild slip (Vess's
		# "Take a slip."/"Turn in a slip." hub options, vess_counter.json).
		gate_keys += 1
		assert(requires["delivery_accepted"] is bool, label + " delivery_accepted must be a bool")
	if requires.has("gold"):
		# Economy v1 D2: the affordability gate (Krshia's shop buy options).
		# `requires: {gold: price}` is the D1-sanctioned numeric extension of the
		# M4 greying ctx (skill/class/accomplishment were the only prior gate
		# types). It greys a buy option VISIBLE when broke (never hidden --
		# gold is not progress-gated), so it is a valid single gate type here.
		gate_keys += 1
		assert(int(requires["gold"]) > 0, label + " gold requirement must be a positive price")
	if requires.has("once_per_waking"):
		# Issue #23: the FIFTH sanctioned single-key gate -- its OWN validator
		# arm, not a silent reuse of any other key's shape.
		# WIDialogue._meets/_progress_gated's once_per_waking check against
		# the shared `entity_first_use` dict (Erin's meal / Relc's wager hub
		# options). Value must be a "<verb>:<entity>" string with both
		# segments non-empty -- see _is_valid_verb_entity_key (shared with
		# the `bank_first_use` effect shape below, same string contract).
		gate_keys += 1
		assert(_is_valid_verb_entity_key(requires["once_per_waking"]), label + " once_per_waking must be a \"<verb>:<entity>\" string with both segments non-empty")
	# Social Pillar II Phase B: the FIRST sanctioned COMPOUND exception --
	# {gold, accomplishment} together (a stage-gated discount buy option,
	# Krshia's `krshia_friend_of_the_silverfangs` perk). dialogue.gd's _meets()
	# ANDs both legs; _meets_progress() reads ONLY the accomplishment leg for
	# hide-until-met visibility, so a met stage-gate with insufficient gold
	# shows GREYED, never vanished (window-shopping is content).
	if gate_keys == 2:
		# Issue #23 adds a SECOND sanctioned compound -- {accomplishment,
		# once_per_waking} together (Erin's meal / Relc's wager, both
		# stage-gated AND per-waking-gated in the same requires dict). Its own
		# check, not a silent fold into the {gold, accomplishment} case above:
		# dialogue.gd's _meets() ANDs both legs here too; _meets_progress()
		# reads BOTH legs (accomplishment AND once_per_waking) for
		# hide-until-met visibility -- unlike the gold compound, once_per_waking
		# is itself a vanishing gate, so there is no "greyed" state to preserve.
		# Every OTHER combination (skill+class, class+gold, gold+once_per_waking,
		# three-or-more keys, etc.) is still rejected -- these are narrow,
		# disclosed carve-outs, not a general compound-gate license.
		var sanctioned_gold_accomplishment := requires.has("gold") and requires.has("accomplishment")
		var sanctioned_stage_once := requires.has("accomplishment") and requires.has("once_per_waking")
		assert(sanctioned_gold_accomplishment or sanctioned_stage_once, label + " the only sanctioned compound requires are {gold, accomplishment} and {accomplishment, once_per_waking}")
		return
	assert(gate_keys == 1, label + " requires must use exactly one gate type")


## Issue #23: the shared "<verb>:<entity>" shape check for BOTH the
## `once_per_waking` requires gate value (requires-ONLY -- see
## _hide_when_gate_keys_allowed below) and the `bank_first_use` effect value
## (same contract on both sides of the seam, see dialogue.gd's
## _meets/_progress_gated and WIGame.dialogue_choose's effect router). Pure
## (no assert) so it is unit-testable for acceptance AND rejection without
## crashing this SceneTree script on the rejection case -- see
## _validate_once_per_waking_shape_cases below.
func _is_valid_verb_entity_key(value: Variant) -> bool:
	if not (value is String):
		return false
	var parts: PackedStringArray = String(value).split(":", true, 1)
	return parts.size() == 2 and not parts[0].is_empty() and not parts[1].is_empty()


## Issue #23 fix wave (review finding 1): true iff this hide_when dict is
## free of requires-only gate keys. `once_per_waking` may never appear in a
## hide_when: its "met" polarity ("not yet used this waking") is the inverse
## of every shipped hide_when key's, so the retire idiom an author would
## expect ("hide once used") is exactly what a shared-_meets evaluation would
## NOT deliver. Pure (no assert), so the rejection case is unit-testable --
## see _validate_once_per_waking_shape_cases.
func _hide_when_gate_keys_allowed(hide_when: Dictionary) -> bool:
	return not hide_when.has("once_per_waking")


## Issue #23: acceptance + rejection coverage for _is_valid_verb_entity_key,
## called directly (not through the assert-based validators above, which
## would abort this SceneTree script on a deliberately-malformed shape).
func _validate_once_per_waking_shape_cases() -> void:
	assert(_is_valid_verb_entity_key("meal:erin"), "verb:entity accepted (Erin's meal)")
	assert(_is_valid_verb_entity_key("wager:relc"), "verb:entity accepted (Relc's wager)")
	assert(_is_valid_verb_entity_key("observe:gossip_npc"), "verb:entity accepted (existing entity_first_use shape)")
	assert(not _is_valid_verb_entity_key("meal"), "missing colon rejected")
	assert(not _is_valid_verb_entity_key(":erin"), "empty verb segment rejected")
	assert(not _is_valid_verb_entity_key("meal:"), "empty entity segment rejected")
	assert(not _is_valid_verb_entity_key(""), "empty string rejected")
	assert(not _is_valid_verb_entity_key(true), "non-string bool value rejected")
	assert(not _is_valid_verb_entity_key(5), "non-string numeric value rejected")
	assert(not _is_valid_verb_entity_key(["meal", "erin"]), "non-string array value rejected")
	# A value with more than one colon keeps only the FIRST split (entity ids
	# never carry colons in this codebase, but the shape check must not choke
	# on one) -- "meal:erin:extra" is still two non-empty segments post-split.
	assert(_is_valid_verb_entity_key("meal:erin:extra"), "extra colon still splits into two non-empty segments")
	# Issue #23 fix wave (review finding 1): once_per_waking is requires-only
	# -- a hide_when dict carrying it is a content ERROR (rejection case), any
	# other hide_when key set stays valid (acceptance cases).
	assert(not _hide_when_gate_keys_allowed({"once_per_waking": "meal:erin"}), "hide_when carrying once_per_waking rejected (requires-only gate)")
	assert(not _hide_when_gate_keys_allowed({"accomplishment": {"x": 1}, "once_per_waking": "meal:erin"}), "hide_when carrying once_per_waking alongside another key still rejected")
	assert(_hide_when_gate_keys_allowed({"accomplishment": {"has_package": 1}}), "accomplishment hide_when still accepted")
	assert(_hide_when_gate_keys_allowed({"board_accepted": true}), "board_accepted hide_when still accepted")
	assert(_hide_when_gate_keys_allowed({}), "empty hide_when accepted (never authored, but not this rule's business)")


func _validate_effect(
	label: String,
	effect: Dictionary,
	quest_ids: Dictionary,
	class_ids: Dictionary,
	entity_ids: Dictionary,
	produced_accomplishments: Dictionary
) -> void:
	if effect.has("accomplishment"):
		produced_accomplishments[String(effect["accomplishment"])] = true
	if effect.has("quest"):
		var quest_id: String = String(effect["quest"])
		assert(quest_ids.has(quest_id), label + " starts unknown quest: " + quest_id)
	if effect.has("remove_entity"):
		var remove_id: String = String(effect["remove_entity"])
		assert(entity_ids.has(remove_id), label + " removes unknown entity: " + remove_id)
	if effect.has("start_combat"):
		var combat_id: String = String(effect["start_combat"])
		assert(entity_ids.has(combat_id), label + " starts combat for unknown entity: " + combat_id)
	if effect.has("class"):
		var class_id: String = String(effect["class"])
		assert(class_ids.has(class_id), label + " references unknown class: " + class_id)
	if effect.has("bank_first_use"):
		# Issue #23: the effect-side twin of the once_per_waking requires
		# shape check above -- same "<verb>:<entity>" contract, its OWN
		# validator arm (not a silent fall-through), shared helper.
		assert(_is_valid_verb_entity_key(effect["bank_first_use"]), label + " bank_first_use must be a \"<verb>:<entity>\" string with both segments non-empty")


## Reachability sanity check for this bug class: a node whose every option
## carries a requires and/or hide_when can end up with zero visible options
## for some reachable state (the softlock this fix exists to prevent, see the
## amendment). Generalized over every dialogue node in every graph that has
## at least one hide_when option OR at least one accomplishment-gated
## (progress-gated) requires option -- not just the selys hub this check
## originated on. Both are "vanishing" mechanisms that can empty a node out
## over time (M4: progress-gated requires.accomplishment options are HIDDEN,
## not greyed, exactly like hide_when -- see WIDialogue._progress_gated), so
## any node using either needs an always-available exit: an option that is
## completely ungated (fully usable in all states), with NO requires key and
## NO hide_when key. Options with any requires (even skill/class only) are
## locked-but-visible and not exits, so they cannot prevent softlock.
func _validate_hide_when_nodes_have_always_available_exit(graphs: Dictionary) -> void:
	for graph_id: String in graphs:
		var nodes: Dictionary = graphs[graph_id]["nodes"]
		for node_id: String in nodes:
			var node: Dictionary = nodes[node_id]
			var options: Array = node.get("options", [])
			var has_vanishing_option := false
			for option: Dictionary in options:
				# M-DEPTH DP2: board_accepted is the SECOND recognized progress-gate
				# key (see WIDialogue._progress_gated) -- included here so a future
				# board_accepted-only node (none ship today; the hub already has an
				# always-available exit regardless) gets the same softlock check.
				# M-DEPTH DP5: delivery_accepted, its twin (vess_counter.json's hub
				# -- which does carry an ungated "Just passing through." exit).
				# Issue #23: once_per_waking, the FIFTH -- Erin's "Sit, eat.
				# Cook's orders." and Relc's wager option both already sit in
				# hubs with an ungated exit, but this check must catch a future
				# once_per_waking-only node the same way.
				var opt_requires: Dictionary = option.get("requires", {})
				if option.has("hide_when") or opt_requires.has("accomplishment") or opt_requires.has("board_accepted") or opt_requires.has("delivery_accepted") or opt_requires.has("once_per_waking"):
					has_vanishing_option = true
					break
			if not has_vanishing_option:
				continue
			var has_always_available := false
			for option: Dictionary in options:
				if not option.has("hide_when") and not option.has("requires"):
					has_always_available = true
					break
			assert(has_always_available, "%s.%s has hide_when/progress-gated options but no always-available option -- risk of softlock" % [graph_id, node_id])


## Every accomplishment a class's gained_by condition waits on must actually
## be produced somewhere in content (mirrors _validate_quests below).
func _validate_class_gains(classes: Dictionary, produced_accomplishments: Dictionary) -> void:
	for cls: Dictionary in classes.get("classes", []):
		if not cls.has("gained_by"):
			continue
		var condition: Dictionary = (cls["gained_by"] as Dictionary).get("accomplishment", {})
		for accomplishment_id: String in condition:
			assert(
				produced_accomplishments.has(accomplishment_id),
				"class %s gained_by waits on unproduced accomplishment: %s" % [String(cls["id"]), accomplishment_id]
			)


func _validate_quests(quests: Dictionary, produced_accomplishments: Dictionary) -> void:
	for quest: Dictionary in quests.get("quests", []):
		for beat: Dictionary in quest.get("beats", []):
			var complete_when: Dictionary = beat.get("complete_when", {})
			for accomplishment_id: String in complete_when:
				assert(
					produced_accomplishments.has(accomplishment_id),
					"quest %s beat %s waits on unproduced accomplishment: %s" % [String(quest["id"]), String(beat["id"]), accomplishment_id]
				)


func _validate_props(scene: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var entity_id: String = String(entity["id"])
			# Every entity with on_interact_accomplishment must have a non-empty toast
			if entity.has("on_interact_accomplishment"):
				var toast: String = String(entity.get("toast", ""))
				assert(
					not toast.is_empty(),
					"entity %s has on_interact_accomplishment but empty or missing toast" % entity_id
				)
			# No prop can combine sleep with on_interact_accomplishment
			if String(entity.get("kind", "")) == "prop":
				var has_sleep: bool = bool(entity.get("sleep", false))
				var has_accomplishment: bool = entity.has("on_interact_accomplishment")
				assert(
					not (has_sleep and has_accomplishment),
					"prop %s cannot combine sleep with on_interact_accomplishment" % entity_id
				)
