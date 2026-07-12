extends SceneTree
## Cross-reference validation for authored content.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_content.gd

const DIALOGUE_DIR := "res://data/dialogue"

## Every data file that carries player-facing strings, for
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
	var items: Dictionary = _load_json("res://data/items.json")
	var bounties: Dictionary = _load_json("res://data/bounties.json")
	var deliveries: Dictionary = _load_json("res://data/deliveries.json")

	var skill_ids: Dictionary = _ids_from_catalog(skills, "skills")
	var class_ids: Dictionary = _ids_from_catalog(classes, "classes")
	var quest_ids: Dictionary = _ids_from_catalog(quests, "quests")
	var item_ids: Dictionary = _ids_from_catalog(items, "items")
	var entity_ids: Dictionary = _entity_ids(scene)
	var produced_accomplishments: Dictionary = {}

	_collect_scene_accomplishments(scene, produced_accomplishments)
	# Accomplishments the SIM ENGINE produces structurally off ANY faced
	# entity (WIFieldSkills.dispatch's generic [Appraise Foe]/[Charming
	# Smile] arms, keyed on the SKILL's own id, not a per-entity data field)
	# -- not traceable by scanning skeleton_scene.json's fields the way
	# on_victory/on_skill_use/on_interact_accomplishment are above, so
	# hardcoded here the same way heard_gossip/chatted_with_<id> are
	# hardcoded into _collect_scene_accomplishments (real, structural,
	# always-live producers, not a scan gap).
	produced_accomplishments["observed_things"] = true
	produced_accomplishments["befriended_moments"] = true
	_validate_conversations(scene, graphs)
	_validate_dialogue_graphs(graphs, skill_ids, class_ids, item_ids, quest_ids, entity_ids, produced_accomplishments)
	_validate_quests(quests, produced_accomplishments)
	_validate_bounties(bounties, produced_accomplishments)
	_validate_deliveries(deliveries, produced_accomplishments)
	_validate_hide_when_nodes_have_always_available_exit(graphs)
	_validate_class_gains(classes, produced_accomplishments)
	_validate_class_level_tables(classes)
	_validate_props(scene)
	_validate_talk_pool_stages_ascending(scene)
	_validate_encounter_when(scene, produced_accomplishments)
	_validate_encounter_gate_counters(scene, produced_accomplishments)
	_validate_present_when(scene, produced_accomplishments)
	_validate_visual_states_phase(scene)
	_validate_talk_pool_echo_of(scene, entity_ids)
	_validate_effect_text_opacity()
	_validate_player_string_vocab()
	_validate_once_per_waking_shape_cases()
	_validate_travel_beat_place_naming(quests, scene, graphs)
	_validate_place_naming_shape_cases()

	print("PASS: errand content is fully cross-referenced")
	quit(0)


## The FORBIDDEN-vocabulary grep over WIEffectText's output
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


## forbidden-vocab sweep over every player-string FIELD in
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
	# Issue #62 finding 12: a dev-provenance citation ("Magical Door plan Task
	# D1 (issue #8 spec §5.3)") shipped straight into a player-visible item
	# lore field (anchor_stone) undetected -- this sweep only ever checked
	# the attribute/percent vocab, never provenance leaks. Deliberately NOT
	# a bare "plan" check (too common a word -- Olesm's own hub line "down
	# there with a plan" is real, in-voice content, not a leak); scoped to
	# the two shapes that are ALWAYS a leak: "Task <letter><digits>" and
	# "issue #<digits>".
	var provenance := RegEx.new()
	provenance.compile("(?i)Task [A-Z]?\\d+|issue #\\d+")
	for path: String in PLAYER_STRING_FILES:
		_scan_player_strings(_load_json(path), path, attr, provenance)
	var dir: DirAccess = DirAccess.open(DIALOGUE_DIR)
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			var full_path := DIALOGUE_DIR.path_join(file_name)
			_scan_player_strings(_load_json(full_path), full_path, attr, provenance)


## Recurses through an arbitrary parsed-JSON value, applying the forbidden-
## attribute regex + a literal-percent check + a dev-provenance-leak check to
## every String leaf. Dictionary keys starting with "_" are skipped entirely
## (dev comments, never player-facing) -- their VALUES are never visited, so
## a `_comment` field can freely discuss STR/DEX/percentages/Task IDs as
## design notes without tripping the sweep.
func _scan_player_strings(node: Variant, path: String, attr: RegEx, provenance: RegEx) -> void:
	if node is Dictionary:
		for key: String in (node as Dictionary):
			if key.begins_with("_"):
				continue
			_scan_player_strings((node as Dictionary)[key], "%s.%s" % [path, key], attr, provenance)
	elif node is Array:
		for i: int in (node as Array).size():
			_scan_player_strings((node as Array)[i], "%s[%d]" % [path, i], attr, provenance)
	elif node is String:
		var s := node as String
		assert(attr.search(s) == null, "%s carries a forbidden attribute token: %s" % [path, s])
		assert(not s.contains("%"), "%s carries a forbidden percent-toward token: %s" % [path, s])
		assert(provenance.search(s) == null, "%s carries a dev-provenance leak (Task/issue citation): %s" % [path, s])


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
				# A `variants` entry (the cellar_door override seam,
				# WIGame._resolve_skill_use_effect) may override `accomplishment`
				# itself, not just `toast` -- a second producer for the SAME
				# prop, gated differently. No shipped on_skill_use variant does
				# this yet, but the shape is real (accomplishment is just
				# another key `_resolve_skill_use_effect` can override), so it's
				# scanned defensively alongside the plain on_interact_accomplishment
				# case below, which does have a real consumer (8d C1's
				# `seal_kept_door`).
				for variant: Dictionary in (skill_use.get("variants", []) as Array):
					if variant.has("accomplishment"):
						produced[String(variant["accomplishment"])] = true
			if entity.has("on_interact_accomplishment"):
				produced[String(entity["on_interact_accomplishment"])] = true
				# 8d C1 (issue #14): a plain on_interact_accomplishment prop may
				# ALSO carry a sibling `variants` list (WIGame's new reuse of
				# `_resolve_skill_use_effect` at this second call site) --
				# `seal_kept_door`'s real find (`seal_kept_found`) lives ONLY in
				# a variant, never the base field, so it must be scanned here
				# too or every gate reading it looks unproduced.
				for variant: Dictionary in (entity.get("variants", []) as Array):
					if variant.has("accomplishment"):
						produced[String(variant["accomplishment"])] = true
			# A container's optional
			# `on_open_accomplishment` (src/core/wi_game.gd's _interact_container)
			# is a producer too, same shape as on_interact_accomplishment above.
			if entity.has("on_open_accomplishment"):
				produced[String(entity["on_open_accomplishment"])] = true
			# A door's optional `on_enter_accomplishment`
			# (WIGame.interact()'s "door" branch) banks on every REAL door
			# transit -- re-banked each time, not a one-shot (issue #72's
			# bounty_guild_census is the first content to key on one of these;
			# added here rather than left an undiscovered scan gap).
			if entity.has("on_enter_accomplishment"):
				produced[String(entity["on_enter_accomplishment"])] = true
			# A non-empty talk_pool makes the sim's
			# _talk_pool_line bank heard_gossip (+1) and chatted_with_<id> (+1) on
			# the first talk of each waking. The bank happens in the sim, not a
			# scanned data field, so record it here as genuinely content-produced
			# -- this is what lets a [Diplomat]-style gained_by / threshold keyed on
			# heard_gossip cross-reference cleanly (see _validate_class_gains).
			if entity.has("talk_pool") and not (entity["talk_pool"] as Array).is_empty():
				produced["heard_gossip"] = true
				produced["chatted_with_%s" % String(entity["id"])] = true
			# 8b R1 (issue #10): a `board` prop's own `board_rumors` list
			# (the Guild-board rumor beat, locked shape 1) -- each entry's
			# `banks_accomplishment` is produced on every board browse
			# (WIGame._interact_board), same idiom as on_interact_accomplishment.
			for rumor: Dictionary in (entity.get("board_rumors", []) as Array):
				produced[String(rumor["banks_accomplishment"])] = true


## `talk_pool_stages` authoring must be ASCENDING
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


## The set of phase() ever returns (wi_game.gd's phase()) -- the shared
## vocabulary both `encounter_when` and `visual_states`' `phase` shape are
## checked against below (locked shape 2/4, ONE design, two consumers).
const VALID_PHASES := ["day", "dusk", "night"]


## 8b R1 (issue #10), locked shape 2 -- `encounter_when` validator arm. Only
## `kind: "encounter"` entities may carry it (the gate lives in
## WIGame._encounter_gate_met, read from interact()'s encounter branch and
## _check_trigger_radius, both `kind == "encounter"`-scoped). Two shapes
## sanctioned: `{"phase": [...]}`, every listed value a real phase string
## (locked shape 2's own original), and `{"requires": {...}}` (8d C1, issue
## #14 -- the accomplishment-gate shape, same `requires` key name/semantics
## as door_when/contains_when). Every `requires` counter id is
## EXISTENCE-CHECKED against produced accomplishments (the requires.skill
## existence idiom) -- a typo'd/unproduced id would make the encounter
## permanently inert, silently.
func _validate_encounter_when(scene: Dictionary, produced_accomplishments: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			if not entity.has("encounter_when"):
				continue
			var entity_id: String = String(entity["id"])
			assert(String(entity.get("kind", "")) == "encounter", "entity %s carries encounter_when but is not kind:encounter" % entity_id)
			var when: Dictionary = entity["encounter_when"]
			assert(when.has("phase") or when.has("requires"), "entity %s encounter_when has no recognized shape (only 'phase'/'requires' are sanctioned)" % entity_id)
			if when.has("phase"):
				for p: Variant in when["phase"]:
					assert(VALID_PHASES.has(String(p)), "entity %s encounter_when references unknown phase: %s" % [entity_id, p])
			if when.has("requires"):
				assert(when["requires"] is Dictionary, "entity %s encounter_when.requires must be a Dictionary" % entity_id)
				for acc_id: String in (when["requires"] as Dictionary):
					assert(
						produced_accomplishments.has(acc_id),
						"entity %s encounter_when.requires waits on unproduced accomplishment: %s" % [entity_id, acc_id]
					)


## 8d C1 review tooth: an encounter entity's OTHER two accomplishment-keyed
## gates -- `ally_requires` (start_combat's roster gate, shipped since M-ARC)
## and `ally_hp_penalty.<ally>.when` (the 8d C4 pre-damaged-ally arm) -- get
## the SAME existence check as encounter_when.requires above. A typo'd id in
## ally_requires silently fields NO ally forever; in ally_hp_penalty.when it
## silently never applies the cost. Both are `_accomplishment_gate_met`
## readers, so the produced-set is the right existence universe.
func _validate_encounter_gate_counters(scene: Dictionary, produced_accomplishments: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var entity_id: String = String(entity.get("id", "?"))
			for acc_id: String in (entity.get("ally_requires", {}) as Dictionary):
				assert(
					produced_accomplishments.has(acc_id),
					"entity %s ally_requires waits on unproduced accomplishment: %s" % [entity_id, acc_id]
				)
			var penalties: Dictionary = entity.get("ally_hp_penalty", {})
			for ally_id: String in penalties:
				var arm: Dictionary = penalties[ally_id]
				assert(arm.has("hp_mod"), "entity %s ally_hp_penalty.%s missing hp_mod" % [entity_id, ally_id])
				for acc_id: String in (arm.get("when", {}) as Dictionary):
					assert(
						produced_accomplishments.has(acc_id),
						"entity %s ally_hp_penalty.%s.when waits on unproduced accomplishment: %s" % [entity_id, ally_id, acc_id]
					)


## 8d D2 (issue #14/#15) -- `present_when` validator arm, the door_when-
## family extension for STRUCTURAL entity presence (WIGame.entity_present):
## unlike `encounter_when` (interact/trigger reachability only, kind:
## encounter-scoped), `present_when` gates the entity's very existence --
## occupancy (`is_cell_blocked`), lookup (`entity_at`), and render/count
## (`_build_entities`) -- for ANY entity kind. Only shape sanctioned:
## `{"requires": {...}}` (the door_when/contains_when shape, reused verbatim
## via `_door_gate_met`). Every `requires` counter id is EXISTENCE-CHECKED
## against produced accomplishments, same as encounter_when.requires above --
## a typo'd/unproduced id would make the entity permanently absent, silently.
func _validate_present_when(scene: Dictionary, produced_accomplishments: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			if not entity.has("present_when"):
				continue
			var entity_id: String = String(entity["id"])
			var when: Dictionary = entity["present_when"]
			assert(when.has("requires"), "entity %s present_when has no recognized shape (only 'requires' is sanctioned)" % entity_id)
			assert(when["requires"] is Dictionary, "entity %s present_when.requires must be a Dictionary" % entity_id)
			for acc_id: String in (when["requires"] as Dictionary):
				assert(
					produced_accomplishments.has(acc_id),
					"entity %s present_when.requires waits on unproduced accomplishment: %s" % [entity_id, acc_id]
				)


## 8b R1 (issue #10), locked shape 4 -- `visual_states`' new `phase` `when`
## shape gets the SAME phase-vocabulary check as encounter_when above (shared
## design). Every visual_states entry across every entity is scanned, not
## just encounters -- the witch (an npc) is this shape's first live consumer.
func _validate_visual_states_phase(scene: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			for state: Variant in (entity.get("visual_states", []) as Array):
				if not (state is Dictionary):
					continue
				var when: Dictionary = (state as Dictionary).get("when", {})
				if not when.has("phase"):
					continue
				for p: Variant in when["phase"]:
					assert(VALID_PHASES.has(String(p)), "entity %s visual_states references unknown phase: %s" % [String(entity["id"]), p])


## 8b R1 (issue #10), locked shape 3 -- `echo_of` validator arm. A `talk_pool`
## entry shaped `{"echo_of": id}` must reference a REAL entity id that itself
## carries a non-empty talk_pool of PLAIN STRINGS (social.gd's
## `_resolve_pool_line` recurses one level only, per its own doc comment --
## an echo-of-an-echo would silently resolve to an empty string at runtime).
func _validate_talk_pool_echo_of(scene: Dictionary, entity_ids: Dictionary) -> void:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			for raw: Variant in (entity.get("talk_pool", []) as Array):
				if not (raw is Dictionary):
					continue
				var entry := raw as Dictionary
				assert(entry.has("echo_of") and entry.size() == 1, "entity %s talk_pool carries a Dictionary entry with an unrecognized shape (only {echo_of: id} is sanctioned): %s" % [String(entity["id"]), entry])
				var echo_id: String = String(entry["echo_of"])
				assert(entity_ids.has(echo_id), "entity %s echo_of references unknown entity: %s" % [String(entity["id"]), echo_id])
				var echo_target: Dictionary = _find_entity_by_id(scene, echo_id)
				var echo_pool: Array = echo_target.get("talk_pool", [])
				assert(not echo_pool.is_empty(), "entity %s echo_of target %s has no talk_pool to echo" % [String(entity["id"]), echo_id])
				for echo_line: Variant in echo_pool:
					assert(echo_line is String, "entity %s echo_of target %s's talk_pool contains a non-string entry (echo_of does not chain -- social.gd resolves one level only)" % [String(entity["id"]), echo_id])


func _find_entity_by_id(scene: Dictionary, id: String) -> Dictionary:
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			if String(entity["id"]) == id:
				return entity
	return {}


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
	item_ids: Dictionary,
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
			_validate_node(graph_id, node_id, node, skill_ids, class_ids, item_ids)
			for option_index: int in (node.get("options", []) as Array).size():
				var option: Dictionary = (node.get("options", []) as Array)[option_index]
				_validate_option(graph_id, node_id, option_index, option, nodes, skill_ids, class_ids, item_ids, quest_ids, entity_ids, produced_accomplishments)


func _validate_node(graph_id: String, node_id: String, node: Dictionary, skill_ids: Dictionary, class_ids: Dictionary, item_ids: Dictionary) -> void:
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
			_validate_requires(variant_label, variant["requires"], skill_ids, class_ids, item_ids)


func _validate_option(
	graph_id: String,
	node_id: String,
	option_index: int,
	option: Dictionary,
	nodes: Dictionary,
	skill_ids: Dictionary,
	class_ids: Dictionary,
	item_ids: Dictionary,
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
		_validate_requires(label, option["requires"], skill_ids, class_ids, item_ids)
	if option.has("hide_when"):
		# once_per_waking is a
		# REQUIRES-ONLY gate -- its "met" polarity ("not yet used this
		# waking") is inverted relative to every shipped hide_when key's
		# ("the tracked state is now true"), so a hide_when carrying it is a
		# content ERROR rejected loudly here, not just a runtime refusal
		# (WIDialogue._meets_hide_when is the belt-and-suspenders half).
		assert(_hide_when_gate_keys_allowed(option["hide_when"]), label + " hide_when must not carry once_per_waking (requires-only gate, Issue #23)")
		_validate_requires(label + " hide_when", option["hide_when"], skill_ids, class_ids, item_ids)
	for effect: Dictionary in option.get("effects", []):
		_validate_effect(label, effect, quest_ids, class_ids, entity_ids, produced_accomplishments)


## Shared by both "requires" and "hide_when" -- both use the same condition
## forms ({skill}|{class: {id: min}}|{accomplishment: {id: min}}), so both are
## validated against the same known-id catalogs. Accomplishment ids are not
## checked against a catalog here (they're free-form, cross-referenced instead
## via produced_accomplishments in _validate_quests). EXCEPTION (Issue #23 fix
## `once_per_waking` is requires-only -- _validate_option rejects it in
## a hide_when dict BEFORE this shared body runs (see
## _hide_when_gate_keys_allowed).
func _validate_requires(label: String, requires: Dictionary, skill_ids: Dictionary, class_ids: Dictionary, item_ids: Dictionary) -> void:
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
		# The THIRD sanctioned single-key gate (after
		# accomplishment/gold) -- WIDialogue._meets/_progress_gated's
		# board_accepted ctx-flag check (Selys's "Take on a posting."/"Turn in
		# my posting." hub options, selys_delivery.json). Bool value only; it
		# is never combined with another gate type in authored content.
		gate_keys += 1
		assert(requires["board_accepted"] is bool, label + " board_accepted must be a bool")
	if requires.has("delivery_accepted"):
		# The FOURTH sanctioned single-key gate --
		# board_accepted's exact twin for the Runner's Guild slip (Vess's
		# "Take a slip."/"Turn in a slip." hub options, vess_counter.json).
		gate_keys += 1
		assert(requires["delivery_accepted"] is bool, label + " delivery_accepted must be a bool")
	if requires.has("gold"):
		# The affordability gate (Krshia's shop buy options).
		# `requires: {gold: price}` is the D1-sanctioned numeric extension of the
		# M4 greying ctx (skill/class/accomplishment were the only prior gate
		# types). It greys a buy option VISIBLE when broke (never hidden --
		# gold is not progress-gated), so it is a valid single gate type here.
		gate_keys += 1
		assert(int(requires["gold"]) > 0, label + " gold requirement must be a positive price")
	if requires.has("once_per_waking"):
		# The FIFTH sanctioned single-key gate -- its OWN validator
		# arm, not a silent reuse of any other key's shape.
		# WIDialogue._meets/_progress_gated's once_per_waking check against
		# the shared `entity_first_use` dict (Erin's meal / Relc's wager hub
		# options). Value must be a "<verb>:<entity>" string with both
		# segments non-empty -- see _is_valid_verb_entity_key (shared with
		# the `bank_first_use` effect shape below, same string contract).
		gate_keys += 1
		assert(_is_valid_verb_entity_key(requires["once_per_waking"]), label + " once_per_waking must be a \"<verb>:<entity>\" string with both segments non-empty")
	if requires.has("item"):
		# The SIXTH sanctioned single-key gate -- possession
		# (WIDialogue._meets's `item` check against the ctx's `inventory`,
		# distinct from the read-only `items` catalog key). Mirrors gold's
		# visible-locked precedent, not accomplishment's: NOT progress-gated
		# (_progress_gated deliberately omits it), so an option gated on an
		# unheld item stays visible/greyed rather than vanishing.
		gate_keys += 1
		var item_id: String = String(requires["item"])
		assert(item_ids.has(item_id), label + " requires unknown item: " + item_id)
	# The FIRST sanctioned COMPOUND exception --
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
		# adds a THIRD sanctioned compound -- {accomplishment, class}
		# together (a persuade-fork resolution that is BOTH progress-gated on
		# the quest having been opened AND locked behind a class -- the
		# goblin_parley-style in-fiction class-gate exception, SKILL.md's
		# "unrelated class gate reads as arbitrary" carve-out, composed with a
		# stage gate). GH#64 re-gated its 3 prior live examples (watch_crate's
		# "asked_about_crate"+"diplomat", krshia_crate's "heard_wrong_order"+
		# "diplomat", invrisil_fixer's "returned_cups_debt"+"diplomat") to the
		# FIFTH compound below -- this shape currently has no live user, kept
		# sanctioned for a future genuine class-only exception (no shipped
		# Skill fitting the social intent), same rationale as goblin_parley's
		# single-key class survivor. Same mechanism as the gold compound:
		# _meets_progress() reads ONLY the accomplishment leg for
		# hide-until-met visibility, so the option stays fully hidden before
		# the quest stage, then shows VISIBLE-LOCKED (never vanished) once the
		# stage is reached but the class isn't held.
		# Issue #59 adds a FOURTH sanctioned compound --
		# {once_per_waking, item} together (the hungry patron's Serve option,
		# patron_serving.json): possession-gated AND per-waking-gated in the
		# same requires dict, the dish-fetch seam's own compound. Same GATING
		# SPLIT as the {accomplishment, once_per_waking} compound above, with
		# `item` standing in for `accomplishment`: dialogue.gd's _meets() ANDs
		# both legs for the lock/choose decision; _meets_progress() reads ONLY
		# the once_per_waking leg for hide-until-met visibility (item is NOT
		# progress-gated -- an unheld dish greys the option, never hides it,
		# same as gold's precedent) -- so a fresh dish cooked AFTER the
		# option's already retired this waking still can't bring it back;
		# only sleep does.
		# GH#64 adds a FIFTH sanctioned compound -- {accomplishment, skill}
		# together, the skill-gate twin of the THIRD compound above (a
		# persuade-fork resolution progress-gated on the quest stage AND
		# locked behind a Skill instead of a class -- watch_crate's
		# "asked_about_crate"+"charming_smile", krshia_crate's
		# "heard_wrong_order"+"charming_smile", invrisil_fixer's
		# "returned_cups_debt"+"charming_smile"). Same mechanism: skill is
		# not in _progress_gated, so _meets_progress() reads ONLY the
		# accomplishment leg for hide-until-met visibility -- fully hidden
		# before the stage, VISIBLE-LOCKED once the stage is reached but the
		# Skill isn't known.
		# Every OTHER combination (skill+class, class+gold, gold+once_per_waking,
		# gold+item, three-or-more keys, etc.) is still rejected -- these are
		# narrow, disclosed carve-outs, not a general compound-gate license.
		var sanctioned_gold_accomplishment := requires.has("gold") and requires.has("accomplishment")
		var sanctioned_stage_once := requires.has("accomplishment") and requires.has("once_per_waking")
		var sanctioned_stage_class := requires.has("accomplishment") and requires.has("class")
		var sanctioned_once_item := requires.has("once_per_waking") and requires.has("item")
		var sanctioned_stage_skill := requires.has("accomplishment") and requires.has("skill")
		assert(sanctioned_gold_accomplishment or sanctioned_stage_once or sanctioned_stage_class or sanctioned_once_item or sanctioned_stage_skill, label + " the only sanctioned compound requires are {gold, accomplishment}, {accomplishment, once_per_waking}, {accomplishment, class}, {once_per_waking, item}, and {accomplishment, skill}")
		return
	assert(gate_keys == 1, label + " requires must use exactly one gate type")


## The shared "<verb>:<entity>" shape check for BOTH the
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


## True iff this hide_when dict is
## free of requires-only gate keys. `once_per_waking` may never appear in a
## hide_when: its "met" polarity ("not yet used this waking") is the inverse
## of every shipped hide_when key's, so the retire idiom an author would
## expect ("hide once used") is exactly what a shared-_meets evaluation would
## NOT deliver. Pure (no assert), so the rejection case is unit-testable --
## see _validate_once_per_waking_shape_cases.
func _hide_when_gate_keys_allowed(hide_when: Dictionary) -> bool:
	return not hide_when.has("once_per_waking")


## Acceptance + rejection coverage for _is_valid_verb_entity_key,
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
	# once_per_waking is requires-only
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
		# The effect-side twin of the once_per_waking requires
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
				# board_accepted is the SECOND recognized progress-gate
				# key (see WIDialogue._progress_gated) -- included here so a future
				# board_accepted-only node (none ship today; the hub already has an
				# always-available exit regardless) gets the same softlock check.
				# delivery_accepted, its twin (vess_counter.json's hub
				# -- which does carry an ungated "Just passing through." exit).
				# once_per_waking, the FIFTH -- Erin's "Sit, eat.
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


## GH#54 sparse-level-table convention. A class reached ONLY through an
## evolution Replacement (`evolution.targets` values) or a consolidation
## (`consolidations[].target`) is never assigned a level via check_level_ups
## counting up from 1 -- `_resolve_evolutions`/`accept_consolidation`
## (wi_game.gd) both write `classes[target] = level` directly, carrying the
## PARENT's held level (Replacement) or the merged level (consolidation)
## straight in. So such a class has a real FLOOR below which it can never be
## held, and any `levels` entry below that floor is dead, easily-regressed
## padding (see the class's own `_comment` for the derivation, but this
## validator re-derives it independently from the SAME evolution/
## consolidation data every real code path reads -- never a hardcoded class
## list, so a new evolution-only class added later is covered automatically
## without a second place to update). Normally-gained classes (gained_by, or
## simply never targeted by any evolution/consolidation) keep the old
## expectation: contiguous from level 1.
##
## Three rules enforced per class:
##   (a) no levels entry authored below the derived floor (padding regression
##       guard -- a sub-floor entry can never be read at runtime, so its
##       presence only invites bit rot / accidental re-padding);
##   (b) entries are CONTIGUOUS from the floor up to the class's own max level
##       (no holes -- check_level_ups' by_level.has(next) walk would silently
##       stop at a hole, capping the class short of its authored ceiling);
##   (c) an evolution-only class's minimum authored level is EXACTLY its
##       derived floor (not just >= it -- catches an author leaving a gap
##       between the true floor and the first entry, which (a)+(b) alone
##       would not catch since there'd be no entry AT the floor to be "below").
##   (d) TOP-END (GH#61): for every consolidation target, the table's own MAX
##       level is >= the merge formula's LARGEST possible output -- derived
##       the same data-driven way as the floor, but from the OTHER end: both
##       parent lines pushed to their own table max (never a literal), fed
##       through the same WIProgression._consolidation_merged_level pinned
##       formula the floor derivation and the real sim both use. A player who
##       levels both parent lines to their real ceiling before consolidating
##       is assigned the merged level directly (accept_consolidation, no
##       counting-up walk to stop short at) -- if that level has no table
##       entry, HP/MP growth and grants silently stop (GH#61's exact,
##       non-crashing bug). Replacement targets have no such gap: a held
##       level over `evolution.at_level` just carries straight across, and
##       (b)'s contiguity rule already forces the target's table to cover
##       every level up through the SOURCE class's own max (see e.g.
##       swordsman/ice_mage's floor comments, "12, matching warrior's/mage's
##       own max"). Consolidation is the only shape where TWO independent
##       source ceilings compress through a formula that can overshoot both.
func _validate_class_level_tables(classes: Dictionary) -> void:
	var catalog_list: Array = classes.get("classes", [])

	# id -> Array[int]: every floor this id could be assigned at, read from
	# the same fields check_evolutions/check_consolidation read (at_level for
	# Replacement targets, the merge-math boundary for consolidation targets).
	# More than one candidate is possible in principle (two different source
	# classes both targeting the same id); the true floor is the MINIMUM
	# across all reachable paths.
	var floor_candidates: Dictionary = {}

	for cls: Dictionary in catalog_list:
		var evo: Dictionary = cls.get("evolution", {})
		var targets: Dictionary = evo.get("targets", {})
		if targets.is_empty():
			continue
		var at_level := int(evo.get("at_level", 0))
		for key: String in targets:
			var target_id := String(targets[key])
			if not floor_candidates.has(target_id):
				floor_candidates[target_id] = []
			(floor_candidates[target_id] as Array).append(at_level)

	for entry: Dictionary in classes.get("consolidations", []):
		var target_id := String(entry.get("target", ""))
		var min_parent_level := int(entry.get("min_parent_level", 0))
		var min_combined_level := int(entry.get("min_combined_level", 0))
		# Minimum sum honoring BOTH gates (check_consolidation's trigger: both
		# parents >= min_parent_level AND combined >= min_combined_level).
		var s_min := maxi(min_combined_level, 2 * min_parent_level)
		# For a fixed sum, the merge formula's max(La,Lb) term is minimized by
		# the most-balanced split -- so the floor is reached there.
		var level_a := s_min / 2
		var level_b := s_min - level_a
		var merged := WIProgression._consolidation_merged_level(level_a, level_b)
		if not floor_candidates.has(target_id):
			floor_candidates[target_id] = []
		(floor_candidates[target_id] as Array).append(merged)

	# id -> that class's OWN table max level (rule (d) reads this to derive
	# each consolidation parent line's real ceiling below -- same
	# never-hardcoded spirit as floor_candidates above).
	var class_table_max: Dictionary = {}

	for cls: Dictionary in catalog_list:
		var id := String(cls["id"])
		var levels: Array = cls.get("levels", [])
		assert(not levels.is_empty(), "class %s has no levels entries" % id)

		var level_set: Dictionary = {}
		var max_level := 0
		var min_level := 999999
		for lv: Dictionary in levels:
			var l := int(lv["level"])
			level_set[l] = true
			max_level = maxi(max_level, l)
			min_level = mini(min_level, l)
		class_table_max[id] = max_level

		var reqs: Dictionary = (cls.get("gained_by", {}) as Dictionary).get("accomplishment", {})
		var has_gained_by := not reqs.is_empty()

		var floor_level := 1
		var is_evolution_only := false
		if not has_gained_by and floor_candidates.has(id):
			is_evolution_only = true
			floor_level = 999999
			for f: Variant in (floor_candidates[id] as Array):
				floor_level = mini(floor_level, int(f))

		assert(min_level >= floor_level, "class %s has a levels entry (level %d) below its derived floor %d -- sub-floor entries are unreachable padding (GH#54 sparse-table convention)" % [id, min_level, floor_level])

		for l in range(floor_level, max_level + 1):
			assert(level_set.has(l), "class %s is missing a levels entry at %d (floor %d, max %d) -- the level-up/evolution walk could arrive at an uncovered level" % [id, l, floor_level, max_level])

		if is_evolution_only:
			assert(min_level == floor_level, "class %s (evolution-only, reachable only via Replacement/consolidation) must start EXACTLY at its derived floor %d, found its lowest authored entry at %d" % [id, floor_level, min_level])

	# Rule (d), TOP-END reachability (GH#61): for each consolidation entry,
	# the gate-legal maximum is BOTH parent lines held at their own table
	# max (the same "push every knob to its ceiling" reading the floor
	# derivation above uses at the OTHER end, min_parent_level/
	# min_combined_level pushed to their minimum). A parent LINE's own
	# ceiling is the highest table max across every id in that line (a
	# player can hold any one of them -- base or evolved -- see
	# `_held_line_candidate`'s own doc comment for why evolved ids remain
	# valid parents).
	for entry: Dictionary in classes.get("consolidations", []):
		var target_id := String(entry.get("target", ""))
		var lines: Array = entry.get("parent_lines", [])
		if lines.size() != 2:
			continue
		var line_ceilings: Array = []
		for line: Variant in lines:
			var line_max := 0
			for line_id: Variant in (line as Array):
				line_max = maxi(line_max, int(class_table_max.get(String(line_id), 0)))
			line_ceilings.append(line_max)
		var merged_ceiling := WIProgression._consolidation_merged_level(int(line_ceilings[0]), int(line_ceilings[1]))
		var target_max := int(class_table_max.get(target_id, 0))
		assert(
			target_max >= merged_ceiling,
			"consolidation target %s table max %d cannot hold the merge formula's top-end %d (parent lines' own table maxes: %d, %d) -- a player who levels both parent lines to their real ceiling before consolidating is assigned a held level with no levels entry (HP/MP growth and grants silently stop, GH#61)" % [target_id, target_max, merged_ceiling, line_ceilings[0], line_ceilings[1]]
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


## Issue #74 (travel signposting). Colloquial landmark words a player would
## recognize for each map id, lowercase, substring-matched against a beat's
## `description`. Deliberately loose (a handful of synonyms per map, not an
## exhaustive gazetteer) -- the check only needs ONE hit to pass. A map with
## no entry here can never satisfy `_beat_needs_place_name` for a beat that
## requires one (see the assert in `_validate_travel_beat_place_naming`),
## which is the intended fail-loud behavior for a new travel destination that
## forgot to register its landmark words, not a silent pass.
const LANDMARK_TOKENS := {
	"inn": ["inn"],
	"inn_upstairs": ["upstairs"],
	"street": ["market", "square"],
	"floodplains": ["floodplains"],
	"sewers": ["sewer", "cistern"],
	"deep_tunnels": ["deep tunnels", "tunnels"],
	"guild": ["guild"],
	"barracks": ["barracks"],
	"runners_guild": ["runner"],
	# "ruin" alone is deliberately NOT a token here: the pre-fix beat text
	# already said "the ruin" and a real user still hard-stalled on it (issue
	# #74) -- naming the THING isn't signposting, naming WHERE it is, is.
	"ruin_surface": ["floodplains"],
	"garden_sanctuary": ["garden"],
	"riverfarm_village": ["riverfarm"],
	"riverfarm_longhouse": ["longhouse"],
	"witch_hollow": ["hollow"],
	"invrisil_boulevard": ["boulevard", "invrisil"],
	"mercantile_alleys": ["alleys", "counting house"],
	"brothers_parlor": ["parlor"],
	"dungeon_approach": ["dungeon"],
	"trapped_halls": ["trapped halls", "halls"],
}


## conversation graph id -> the set of map ids that own an entity carrying
## that `conversation` field. Almost always exactly one map (an entity is
## placed on one map); kept as a set rather than a single String so a
## conversation reachable from two placed entities (none ship today) degrades
## to "any of its maps counts as reachable", never a crash.
func _conversation_maps(scene: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			if entity.has("conversation"):
				var conv_id: String = String(entity["conversation"])
				if not out.has(conv_id):
					out[conv_id] = {}
				out[conv_id][map_id] = true
	return out


## accomplishment id -> the set of map ids where it can be PRODUCED (an effect
## grants it), merging two source shapes: (1) scene-direct producers
## (on_victory, on_skill_use.accomplishment, on_interact_accomplishment,
## on_open_accomplishment -- the same fields `_collect_scene_accomplishments`
## already reads, re-walked here to attach a map id instead of a bare bool);
## (2) dialogue-option effects (`{"accomplishment": id}`), attributed to
## every map in `conversation_maps[graph_id]`. An accomplishment produced by
## more than one route (e.g. a 3-path quest convergence counter) carries the
## UNION of every route's map -- this is what lets a beat resolvable via a
## same-map route skip the place-naming requirement below, even when an
## ALTERNATE route requires travel.
func _accomplishment_producer_maps(scene: Dictionary, graphs: Dictionary, conversation_maps: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			var victory: Variant = entity.get("on_victory", [])
			var victory_ids: Array = victory if victory is Array else [victory] if victory is String else []
			for id: Variant in victory_ids:
				_mark_producer(out, String(id), map_id)
			if entity.has("on_skill_use") and (entity["on_skill_use"] as Dictionary).has("accomplishment"):
				_mark_producer(out, String((entity["on_skill_use"] as Dictionary)["accomplishment"]), map_id)
			for su_variant: Dictionary in ((entity.get("on_skill_use", {}) as Dictionary).get("variants", []) as Array):
				if su_variant.has("accomplishment"):
					_mark_producer(out, String(su_variant["accomplishment"]), map_id)
			if entity.has("on_interact_accomplishment"):
				_mark_producer(out, String(entity["on_interact_accomplishment"]), map_id)
			# 8d C1 (issue #14): a plain on_interact_accomplishment prop's
			# sibling `variants` override (same reuse as _collect_scene_
			# accomplishments above) -- `seal_kept_found` (`seal_kept_door`)
			# is produced on trapped_halls, not the base flavor id's map alone.
			for variant: Dictionary in (entity.get("variants", []) as Array):
				if variant.has("accomplishment"):
					_mark_producer(out, String(variant["accomplishment"]), map_id)
			if entity.has("on_open_accomplishment"):
				_mark_producer(out, String(entity["on_open_accomplishment"]), map_id)
			for rumor: Dictionary in (entity.get("board_rumors", []) as Array):
				_mark_producer(out, String(rumor["banks_accomplishment"]), map_id)
	for graph_id: String in graphs:
		var maps_for_graph: Dictionary = conversation_maps.get(graph_id, {})
		if maps_for_graph.is_empty():
			continue
		var nodes: Dictionary = graphs[graph_id]["nodes"]
		for node_id: String in nodes:
			for option: Dictionary in (nodes[node_id].get("options", []) as Array):
				for effect: Dictionary in (option.get("effects", []) as Array):
					if effect.has("accomplishment"):
						for map_id: String in maps_for_graph:
							_mark_producer(out, String(effect["accomplishment"]), map_id)
	return out


func _mark_producer(producer_maps: Dictionary, accomplishment_id: String, map_id: String) -> void:
	if not producer_maps.has(accomplishment_id):
		producer_maps[accomplishment_id] = {}
	producer_maps[accomplishment_id][map_id] = true


## quest id -> the set of map ids where an `{"effects": [{"quest": id}]}`
## dialogue option lives -- "where the player STANDS when this quest starts",
## i.e. the quest-giver's own map (Erin/inn, Krshia/street, the headman/
## riverfarm_village, etc.). A quest with no such option anywhere (content
## bug -- WIGame can never start it) yields an empty set, which
## `_beat_needs_place_name` treats as "cannot confirm same-map, so require
## naming" (fail loud, never silently skip the quest's beats).
func _quest_giver_maps(graphs: Dictionary, conversation_maps: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for graph_id: String in graphs:
		var maps_for_graph: Dictionary = conversation_maps.get(graph_id, {})
		if maps_for_graph.is_empty():
			continue
		var nodes: Dictionary = graphs[graph_id]["nodes"]
		for node_id: String in nodes:
			for option: Dictionary in (nodes[node_id].get("options", []) as Array):
				for effect: Dictionary in (option.get("effects", []) as Array):
					if effect.has("quest"):
						var quest_id: String = String(effect["quest"])
						if not out.has(quest_id):
							out[quest_id] = {}
						for map_id: String in maps_for_graph:
							out[quest_id][map_id] = true
	return out


## TRUE iff `beat_maps` (every map that could produce this beat's
## complete_when counters) shares NO map with `giver_maps` (the quest-giver's
## own map) -- i.e. every route to this beat requires leaving wherever the
## quest was handed out, so the description must name a landmark. A beat with
## even ONE same-map route (a non-Diplomat SKILL/TALK leg that never leaves
## the giver's own map, e.g. wrong_order's kitchen-stretch leg) does NOT need
## naming -- the player is never FORCED to travel to finish it. Empty
## `beat_maps` (defensive; `_validate_quests` already asserts every
## complete_when id is produced somewhere) is treated as "not required" --
## nothing to cross-check.
func _beat_needs_place_name(beat_maps: Dictionary, giver_maps: Dictionary) -> bool:
	if beat_maps.is_empty():
		return false
	for map_id: String in beat_maps:
		if giver_maps.has(map_id):
			return false
	return true


## Case-insensitive substring match: does `description` mention ANY of
## `tokens`? Pure (no assert) so both accept and reject cases are directly
## unit-testable -- see `_validate_place_naming_shape_cases`.
func _description_names_place(description: String, tokens: Array) -> bool:
	var lower := description.to_lower()
	for token: String in tokens:
		if lower.contains(String(token).to_lower()):
			return true
	return false


## Issue #74: every quest beat whose completion counters ALL require leaving
## the quest-giver's own map must name a landmark in its `description` (the
## door-chain 'recover' beat -- "the ruin" with no location -- was the
## confirmed real-user hard-stall this rule exists to catch structurally,
## not just by one-off audit). Walks every beat independently against its
## OWN quest's giver map -- deliberately NOT chain-aware across a quest's own
## prior beats (a later beat converging back on the SAME foreign map a prior
## beat already named still needs its own mention; repeating a short landmark
## clause is cheap and the audit fix for `a_gentlemans_disagreement`'s
## `resolve` beat leans on exactly this).
func _validate_travel_beat_place_naming(quests: Dictionary, scene: Dictionary, graphs: Dictionary) -> void:
	var conversation_maps: Dictionary = _conversation_maps(scene)
	var producer_maps: Dictionary = _accomplishment_producer_maps(scene, graphs, conversation_maps)
	var giver_maps: Dictionary = _quest_giver_maps(graphs, conversation_maps)
	for quest: Dictionary in quests.get("quests", []):
		var quest_id := String(quest["id"])
		var quest_giver_maps: Dictionary = giver_maps.get(quest_id, {})
		for beat: Dictionary in quest.get("beats", []):
			var complete_when: Dictionary = beat.get("complete_when", {})
			var beat_maps: Dictionary = {}
			for accomplishment_id: String in complete_when:
				for map_id: String in (producer_maps.get(accomplishment_id, {}) as Dictionary):
					beat_maps[map_id] = true
			if not _beat_needs_place_name(beat_maps, quest_giver_maps):
				continue
			var tokens: Array = []
			for map_id: String in beat_maps:
				assert(LANDMARK_TOKENS.has(map_id), "quest %s beat %s needs a travel landmark on map %s, which has no LANDMARK_TOKENS entry" % [quest_id, String(beat["id"]), map_id])
				tokens.append_array(LANDMARK_TOKENS[map_id])
			var description := String(beat.get("description", ""))
			assert(
				_description_names_place(description, tokens),
				"quest %s beat %s is a travel-only beat (giver map(s) %s, producer map(s) %s) but its description names no landmark from %s: %s" % [quest_id, String(beat["id"]), quest_giver_maps.keys(), beat_maps.keys(), tokens, description]
			)


## Acceptance + rejection coverage for `_beat_needs_place_name` and
## `_description_names_place`, mirroring `_validate_once_per_waking_shape_
## cases`'s idiom. The rejection cases are literally the PRE-FIX quests.json
## sentences (the door-chain 'recover' beat, the_errand's 'decide' beat,
## a_gentlemans_disagreement's 'scout'/'resolve' beats) -- proof the fixed
## validator would have caught every one of them, not just that the current
## (already-fixed) text happens to pass.
func _validate_place_naming_shape_cases() -> void:
	assert(not _beat_needs_place_name({"inn": true}, {"inn": true}), "same-map beat needs no landmark")
	assert(_beat_needs_place_name({"guild": true}, {"inn": true}), "guild-only beat, inn-given quest, needs a landmark")
	assert(not _beat_needs_place_name({"inn": true, "street": true}, {"inn": true}), "a beat with ANY same-map route needs no landmark, even with a foreign alternate route")
	assert(not _beat_needs_place_name({}, {"inn": true}), "no known producer map -- nothing to cross-check, not this check's business")
	assert(_beat_needs_place_name({"guild": true}, {}), "an unresolvable quest-giver map (empty set) can share no map with anything -- fails loud (requires naming) rather than silently skipping the beat")

	var ruin_tokens: Array = LANDMARK_TOKENS["ruin_surface"] + LANDMARK_TOKENS["street"]
	assert(_description_names_place("Recover the anchor stone from the ruin east past the gate road, on the floodplains, and buy Krshia's catalyst to attune it.", ruin_tokens), "fixed recover beat names the ruin/floodplains")
	assert(not _description_names_place("Recover the anchor stone from the ruin and buy Krshia's catalyst to attune it.", ruin_tokens), "NEGATIVE CONTROL: the pre-fix recover beat names no landmark")

	var guild_tokens: Array = LANDMARK_TOKENS["guild"]
	assert(_description_names_place("Decide what to do with Selys's reward, there at the Guild.", guild_tokens), "fixed decide beat names the Guild")
	assert(not _description_names_place("Decide what to do with Selys's reward.", guild_tokens), "NEGATIVE CONTROL: the pre-fix decide beat names no landmark")

	var boulevard_tokens: Array = LANDMARK_TOKENS["invrisil_boulevard"]
	assert(_description_names_place("Find out exactly where Coyle's operation actually runs, along the boulevard, before you make a move on him.", boulevard_tokens), "fixed scout beat names the boulevard")
	assert(not _description_names_place("Find out exactly where Coyle's operation actually runs, before you make a move on him.", boulevard_tokens), "NEGATIVE CONTROL: the pre-fix scout beat names no landmark")
	assert(_description_names_place("Clear Farley's name — corner Master Coyle, back on the boulevard, however you see fit.", boulevard_tokens), "fixed resolve beat names the boulevard")
	assert(not _description_names_place("Clear Farley's name — corner Master Coyle however you see fit.", boulevard_tokens), "NEGATIVE CONTROL: the pre-fix resolve beat names no landmark")

## Issue #72 (the posting generator, "Validation is the product"): every
## bounty's `condition` key must be a REAL, traced producer -- mirrors
## _validate_quests/_validate_class_gains above (this cross-reference did
## NOT exist before this task; data/bounties.json's condition keys were
## never checked against produced_accomplishments at all). `condition_mode`
## (delta vs absolute) doesn't matter here -- both read the SAME underlying
## counter, this only checks the counter is ever banked by something.
func _validate_bounties(bounties: Dictionary, produced_accomplishments: Dictionary) -> void:
	for bounty: Dictionary in bounties.get("bounties", []):
		var condition: Dictionary = bounty.get("condition", {})
		for accomplishment_id: String in condition:
			assert(
				produced_accomplishments.has(accomplishment_id),
				"bounty %s condition waits on unproduced accomplishment: %s" % [String(bounty["id"]), accomplishment_id]
			)


## `_validate_bounties`'s delivery twin. Every delivery in the pool
## structurally produces `delivered_<its own id>` via
## WIGame._check_delivery_arrival (keyed generically off whichever id is
## currently accepted, not scannable from skeleton_scene.json/dialogue like
## every other producer this file traces -- see that function's own doc
## comment) -- seeded here, scoped to a LOCAL copy of
## produced_accomplishments (never mutating the shared dict other
## validators read), before checking each delivery's `condition` keys
## resolve. This proves the real structural guarantee rather than false-
## failing on every shipped slip; it would still catch a genuine typo (a
## condition key that doesn't match its own delivery's id).
func _validate_deliveries(deliveries: Dictionary, produced_accomplishments: Dictionary) -> void:
	var produced := produced_accomplishments.duplicate()
	for delivery: Dictionary in deliveries.get("deliveries", []):
		produced["delivered_%s" % String(delivery["id"])] = true
	for delivery: Dictionary in deliveries.get("deliveries", []):
		var condition: Dictionary = delivery.get("condition", {})
		for accomplishment_id: String in condition:
			assert(
				produced.has(accomplishment_id),
				"delivery %s condition waits on unproduced accomplishment: %s" % [String(delivery["id"]), accomplishment_id]
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
