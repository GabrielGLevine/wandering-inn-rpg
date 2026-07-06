class_name WIGame
extends RefCounted
## Pure simulation core for the walking skeleton.
##
## PURITY RULE: this class must never reference an autoload, a Node, or the
## scene tree. All dependencies are injected (config Dictionaries, an event
## sink Callable, an RNG seed). This is what makes the sim testable headless
## and mass-simulatable later (combat balance sims, etc.).

var grid_size: Vector2i
## Current world map id bound into grid_size/entities.
var current_map: String = ""
var player_cell: Vector2i
var player_facing := Vector2i.RIGHT
var player_skills: Array[String] = []
var accomplishments: Dictionary = {}
var entities: Dictionary = {}
## Current map blocked-cell set, keyed by Vector2i with true values.
var blocked_cells: Dictionary = {}
var skills: Dictionary = {}
var classes: Dictionary = {}
var combat: WICombat = null
## Active conversation walker, or null when no dialogue is open.
var dialogue: WIDialogue = null
## Quest ids started during this run; full quest state arrives in Task 5.
var started_quests: Array[String] = []
## Entity ids removed from their owning maps during this run.
var removed_entities: Array[String] = []
## Respawning encounters beaten since the last sleep (M6 §2.2): victory over
## a `respawns: true` encounter leaves the entity on its map but dormant —
## start_combat refuses it — until the next sleep beat re-arms it.
var dormant_encounters: Array[String] = []
## Class ids that have taken the generalist evolution path (M6 T3, mage
## only today): identity-locked, never re-evolves even if later dominant.
var generalist_classes: Array[String] = []
## UI wave item 19: a SET (not a counter) of every skill id the PC has ever
## actually used/cast, once ever — gates the journal's skills-by-class panel
## (canon reveal: pre-first-use a skill shows NAME ONLY, post-first-use the
## full static description). Recorded from BOTH the exploration `use_skill`
## path (below) and combat's `use_skill` resolution — the latter is tracked
## per-encounter on `WICombat.used_skills_tally` (mirroring `action_tally`'s
## shape) and merged in here by `resolve_combat`, UNCONDITIONALLY, before the
## victory/trivial branch — a trivial fight (the Relc spar) suppresses the
## ACCOMPLISHMENT tally bank (`_bank_action_tally`) but must NOT suppress this
## set, so the merge deliberately does not share that gate. Additive save
## field (tolerant default [], see save.gd).
var used_skills: Array[String] = []
## The consolidation offer awaiting a player answer (M6 T5, spec §2.5 REV 2),
## or an empty Dictionary when nothing is pending. Set by `sleep()` when
## `WIProgression.check_consolidation` fires; cleared by whichever of
## `accept_consolidation`/`decline_consolidation` answers it. Shape:
## `{parents: [a, b], target, level}` (see WIProgression.check_consolidation).
var pending_consolidation: Dictionary = {}
## Item ids currently carried by the PC (M7 §2). No stacking (spec §6 YAGNI)
## -- an id appears at most once; `pickup` is idempotent on a repeat pickup
## of an already-carried item. Additive save field (v5, see save.gd).
var inventory: Array[String] = []
## Currently equipped items by slot, `{"weapon": id, "armor": id}` -- `""`
## means the slot is empty (M7 §2). INVARIANT: every non-empty value here is
## also present in `inventory` -- `equip()` enforces this by requiring
## possession before equipping, and nothing in this milestone ever removes
## an item from `inventory` while it is equipped, so the invariant can never
## be broken by the sim's own API surface. Additive save field (v5).
var equipped: Dictionary = {"weapon": "", "armor": ""}
## Container entity id -> true once its `contains` list has been emptied by
## an interact. M7 Task E2 declares and persists this shape only -- the
## interact-side logic that populates it is Task E3's. Additive save field (v5).
var container_state: Dictionary = {}
## M7 M-BEAUTY FOLD (controller amendment): count of player actions (a
## successful move, any interact attempt, or the PC's own combat turns)
## since the last `sleep()`. A pure clock -- consumes no rng and nothing
## renders it this milestone (a future Beauty/mood pilot is the first real
## consumer). See `_tick_action` for the single site that mutates it,
## `phase()` for the pure classifying reader, and `_combat_event_relay` for
## how a combat turn reaches this counter without touching wi_combat.gd's
## runtime code. Additive save field (v5).
var actions_since_sleep: int = 0
## Social Pillar S1: per-waking "already did small talk with this NPC this
## waking" flags, keyed by entity id -> true. Set by `_talk_pool_line` the
## first time an NPC carrying a `talk_pool` is talked to in a waking, so a
## SECOND talk that same waking falls through to the NPC's real conversation
## (or its plain gate_guard dialogue line) EXACTLY as today. Cleared every
## `sleep()`, which re-arms the rotating pool line. Additive save field
## (tolerant default {}, see save.gd) -- a save/reload mid-waking must not
## re-arm an already-spent pool line.
var social_talked: Dictionary = {}
## Social Pillar S1: the SHARED per-waking first-use dedup dict, keyed by a
## "<verb>:<entity_id>" string -> true. Any opaque social/exploration bank
## that must fire AT MOST ONCE per entity per waking routes through
## `_bank_first_use(verb, id)`: [Observe]'s `observed_things` today (resolving
## the TP-review "Observe farm" -- repeat-observing one entity to grind
## [Tactician]); S3's [Friendly Face] `befriended_moments` next, mirroring the
## exact same helper with its own verb prefix. Cleared every `sleep()`.
## Additive save field (tolerant default {}, see save.gd).
var entity_first_use: Dictionary = {}
var rng := RandomNumberGenerator.new()

var _event_sink: Callable
var _combat_config: Dictionary = {}
var _maps: Dictionary = {}
var _map_blocked: Dictionary = {}
var _pending_encounter := ""
var _quest_progress: Dictionary = {}
## data/items.json records keyed by id (M7 §1), sourced from
## `combat_config["items"]["items"]` -- the SAME injection pattern as
## `classes`/`quests`/`dialogue` above `skills`. Empty (item() always
## returns {}) for any caller that never supplies an "items" key -- a safe
## degraded mode for minimal test fixtures that don't touch equipment.
var _items: Dictionary = {}
## M7 M-BEAUTY FOLD: phase-threshold config, `{"dusk_at": int, "night_at":
## int}` -- defaults 40/90 (see `phase()`). Injected the same way as every
## other sim dependency (a config Dictionary), never hardcoded, so a later
## task can override it from `data/moods.json` meta without touching this
## file again.
var _phase_config: Dictionary = {}
## Conversation id of the currently open (or most recently open) dialogue,
## used as the `pickup()` source for a `{"item": id}` dialogue effect
## (M7 §4) -- set by `start_dialogue`, read by `dialogue_choose`.
var _dialogue_conversation_id := ""
## The construction-time rng seed (M7 Task E3, Plan-time correction 3 --
## LOOT RNG ISOLATION), stashed verbatim from `_init`'s `rng_seed` param so
## `_roll_loot` can derive a PER-ENCOUNTER RandomNumberGenerator without ever
## reading `self.rng` (whose `.state` the live combat/sim stream mutates
## continuously -- a single post-victory draw on that stream would shift
## every subsequent fight's trajectory and invalidate multi-fight canonical
## seeds, per the correction). Never mutated after construction.
var _run_seed: int = 0


func _init(scene_config: Dictionary, skill_config: Dictionary, event_sink: Callable, rng_seed: int = 0, combat_config: Dictionary = {}, phase_config: Dictionary = {}) -> void:
	_event_sink = event_sink
	_run_seed = rng_seed
	rng.seed = rng_seed
	for s: Dictionary in skill_config.get("skills", []):
		skills[String(s["id"])] = s
	var p: Dictionary = scene_config["player"]
	player_cell = Vector2i(int(p["cell"][0]), int(p["cell"][1]))
	_combat_config = combat_config
	_phase_config = phase_config
	for it: Dictionary in (combat_config.get("items", {}) as Dictionary).get("items", []):
		_items[String(it["id"])] = it
	classes = (scene_config["player"].get("classes", {}) as Dictionary).duplicate(true)
	for sk: Variant in p.get("skills", []):
		player_skills.append(String(sk))
	for it: Variant in p.get("inventory", []):
		inventory.append(String(it))
	var eq_raw: Dictionary = p.get("equipped", {})
	equipped = {"weapon": String(eq_raw.get("weapon", "")), "armor": String(eq_raw.get("armor", ""))}
	for map_id: String in scene_config["maps"]:
		var m: Dictionary = scene_config["maps"][map_id]
		var ents := {}
		for e: Dictionary in m.get("entities", []):
			var ent: Dictionary = e.duplicate(true)
			ent["cell"] = Vector2i(int(e["cell"][0]), int(e["cell"][1]))
			ents[String(e["id"])] = ent
		var blocked := {}
		for cell: Array in m.get("blocked", []):
			blocked[Vector2i(int(cell[0]), int(cell[1]))] = true
		# walls.segments (M5 E3) are blocking scenery: their covered cells
		# join the blocked set here so map data never lists a wall twice
		# (segment_cells is the single source of truth shared with the
		# renderer, which paints wall art on exactly these cells).
		for raw_seg: Variant in (m.get("walls", {}) as Dictionary).get("segments", []):
			if raw_seg is Dictionary:
				for seg_cell: Vector2i in segment_cells(raw_seg as Dictionary):
					blocked[seg_cell] = true
		_maps[map_id] = {
			"grid": Vector2i(int(m["grid"]["width"]), int(m["grid"]["height"])),
			"entities": ents,
			"blocked": blocked,
		}
	_bind_map(String(scene_config["start_map"]))
	_emit(WIEvents.SIM_INITIALIZED, {"seed": rng_seed})


func _bind_map(map_id: String) -> void:
	current_map = map_id
	grid_size = _maps[map_id]["grid"]
	entities = _maps[map_id]["entities"]
	_map_blocked = _maps[map_id]["blocked"]
	blocked_cells = _map_blocked


## Rebinds the active map and player cell without emitting map_changed.
func bind_map_silent(map_id: String, cell: Vector2i) -> void:
	_bind_map(map_id)
	player_cell = cell


## True if map_id is a known map (loaded from scene_config at construction).
## Used by WISave.apply to reject a save whose current_map doesn't exist in
## this build's content instead of crashing on the _maps[map_id] lookup.
func has_map(map_id: String) -> bool:
	return _maps.has(map_id)


## Moves the player to another map and emits the map_changed domain event.
func transition(to_map: String, to_cell: Vector2i) -> void:
	_bind_map(to_map)
	player_cell = to_cell
	_emit(WIEvents.MAP_CHANGED, {"map": to_map, "cell": [to_cell.x, to_cell.y]})


## Finds an entity by id across every map, or returns an empty Dictionary.
func find_entity(id: String) -> Dictionary:
	for map_id: String in _maps:
		var map_entities: Dictionary = _maps[map_id]["entities"]
		if map_entities.has(id):
			return map_entities[id]
	return {}


## Resolves a walls segment ({"from":[x,y], "to":[x,y], ...}) to the cells it
## covers: the inclusive rect spanned by from/to. Segments are straight runs
## in practice (one axis varies); the rect reading also permits thick walls.
static func segment_cells(seg: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var from_raw: Array = seg.get("from", [])
	var to_raw: Array = seg.get("to", from_raw)
	if from_raw.size() < 2 or to_raw.size() < 2:
		return out
	var lo_x := mini(int(from_raw[0]), int(to_raw[0]))
	var hi_x := maxi(int(from_raw[0]), int(to_raw[0]))
	var lo_y := mini(int(from_raw[1]), int(to_raw[1]))
	var hi_y := maxi(int(from_raw[1]), int(to_raw[1]))
	for x in range(lo_x, hi_x + 1):
		for y in range(lo_y, hi_y + 1):
			out.append(Vector2i(x, y))
	return out


func is_cell_blocked(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return true
	if _map_blocked.has(cell):
		return true
	for ent: Dictionary in entities.values():
		if ent["cell"] == cell:
			return true
	return false


func entity_at(cell: Vector2i) -> Dictionary:
	for ent: Dictionary in entities.values():
		if ent["cell"] == cell:
			return ent
	return {}


func move_player(dir: Vector2i) -> bool:
	if dialogue != null:
		return false
	player_facing = dir
	var target := player_cell + dir
	if is_cell_blocked(target):
		_emit(WIEvents.PLAYER_BLOCKED, {"cell": [target.x, target.y]})
		return false
	player_cell = target
	_emit(WIEvents.PLAYER_MOVED, {"cell": [target.x, target.y]})
	_tick_action()
	_check_trigger_radius()
	return true


## Onboarding rev Task O2 (spec §3): proximity ambush. Any `encounter`
## entity on the CURRENT map carrying a `trigger_radius: N` fires
## `start_combat` the moment a successful move lands the player within N
## cells of it (Chebyshev/king-move distance -- symmetric on this
## 4-directional grid, no axis bias). This is a pure alternate CALL SITE
## into `start_combat`, not a parallel rule: the dormant-respawner refusal
## and the `ally_requires` roster gate both live inside `start_combat`
## itself, so "no trigger while dormant" and "ally fields per met_relc"
## fall out for free, unchanged. A trigger fires start_combat DIRECTLY,
## skipping any `conversation` the entity might carry (the trigger never
## reads `entity["conversation"]`) -- today only `goblin_encounter_1` (no
## conversation) carries `trigger_radius`; `goblin_encounter_2` keeps its
## `goblin_parley` interact-only (no trigger_radius), so no shipped
## encounter actually loses its parley to this precedence today, but a
## FUTURE encounter that combines both fields would skip its parley --
## documented here as the precedence a content author must know.
## Runs ONLY from `move_player` -- `transition()`/`bind_map_silent()`
## (door travel, teleport, save/load restore) never call this helper, so a
## QA `teleport` step or a load-slot restore can never ambush the player
## (see `qa/test_driver.gd`'s `teleport` step, which calls
## `Game.sim.transition` directly and never touches `move_player`).
func _check_trigger_radius() -> void:
	if combat != null or dialogue != null:
		return
	for ent: Dictionary in entities.values():
		if String(ent.get("kind", "")) != "encounter":
			continue
		if not ent.has("trigger_radius"):
			continue
		var ent_cell: Vector2i = ent["cell"]
		var dist := maxi(absi(player_cell.x - ent_cell.x), absi(player_cell.y - ent_cell.y))
		if dist <= int(ent["trigger_radius"]):
			start_combat(String(ent["id"]))
			return


func interact() -> Dictionary:
	# Every interact ATTEMPT counts as one action for the M-BEAUTY FOLD clock
	# (M7), regardless of what it resolves to (a blocked/refused move does
	# NOT tick -- see move_player -- but an interact is a deliberate action
	# the moment it's pressed).
	_tick_action()
	var target := entity_at(player_cell + player_facing)
	if target.is_empty():
		_emit(WIEvents.INTERACT_NOTHING, {})
		return {}
	match String(target["kind"]):
		"npc":
			# Social Pillar S1: an NPC carrying a non-empty `talk_pool` plays a
			# rotating small-talk line on the FIRST talk of a waking (before its
			# conversation graph); `social_talked` then routes every later talk
			# this waking to the real conversation below. An empty pool is
			# treated as no pool (never reached today -- S2 authors 2-4 lines).
			var npc_id := String(target["id"])
			if target.has("talk_pool") and not (target["talk_pool"] as Array).is_empty() and not bool(social_talked.get(npc_id, false)):
				return _talk_pool_line(target)
			if target.has("conversation"):
				if start_dialogue(String(target["conversation"]), String(target["id"])):
					return {"dialogue": true}
				var line: Dictionary = target["dialogue"][0]
				_emit(WIEvents.DIALOGUE_LINE, line)
				return line
			var line: Dictionary = target["dialogue"][0]
			_emit(WIEvents.DIALOGUE_LINE, line)
			return line
		"prop":
			if bool(target.get("sleep", false)):
				sleep()
				return {"slept": true}
			# M7 Task E3: a container prop (`contains: [item_ids]`) is checked
			# BEFORE `on_interact_accomplishment`/the `use_skill` fallback --
			# no data-driven prop combines `contains` with either of those
			# (a container is its own exclusive prop shape), so branch order
			# among the three never matters in practice, but the container
			# check comes first here to keep it visually adjacent to the
			# other early-return prop shapes above it.
			if target.has("contains"):
				return _interact_container(target)
			if target.has("on_interact_accomplishment"):
				var accomplishment_id := String(target["on_interact_accomplishment"])
				record_accomplishment(accomplishment_id)
				var toast_text := String(target.get("toast", ""))
				if toast_text != "":
					_emit(WIEvents.TOAST, {"text": toast_text})
				return {"accomplishment": accomplishment_id}
			return use_skill(String(target.get("requires_skill", "")), String(target["id"]))
		"encounter":
			if target.has("conversation"):
				if start_dialogue(String(target["conversation"]), String(target["id"])):
					return {"dialogue": true}
				if start_combat(String(target["id"])):
					return {"combat": true}
				return {}
			if start_combat(String(target["id"])):
				return {"combat": true}
			return {}
		"door":
			transition(String(target["to_map"]), Vector2i(int(target["to_cell"][0]), int(target["to_cell"][1])))
			return {"map": current_map}
		_:
			_emit(WIEvents.INTERACT_UNHANDLED, {"kind": String(target["kind"]), "id": String(target["id"])})
			return {}


## Container prop interact (M7 Task E3): a `prop` entity carrying `contains:
## [item_ids]` grants every listed item via `pickup()` (source = the
## container's OWN entity id) on first interact, then marks
## `container_state[id] = true` -- persisted (see save.gd), so a re-interact
## after emptying (including one restored from a save taken post-empty)
## always takes the early-return "Empty." toast branch below and never
## re-grants. Items already carried (e.g. a container holding an item the
## player separately already has) are silently skipped by `pickup`'s own
## idempotency -- the container still marks itself emptied either way.
func _interact_container(target: Dictionary) -> Dictionary:
	var id := String(target["id"])
	if bool(container_state.get(id, false)):
		_emit(WIEvents.TOAST, {"text": "Empty."})
		return {"container": id, "empty": true}
	var granted: Array[String] = []
	for raw: Variant in target["contains"]:
		var item_id := String(raw)
		if pickup(item_id, id):
			granted.append(item_id)
	container_state[id] = true
	return {"container": id, "items": granted}


func use_skill(skill_id: String, target_id: String) -> Dictionary:
	# Gate on the FULL known set (innate + class-granted), not just innate
	# player_skills: class-granted exploration skills ([Light], mage L1)
	# must fire prop on_skill_use chains too (M6 T2, closing the T6 gap).
	var target: Dictionary = entities.get(target_id, {})
	if not known_skills().has(skill_id):
		_emit(WIEvents.SKILL_UNKNOWN, {"skill": skill_id})
		# Hotfix wave A (2/18 blocker): a locked prop used to fail SILENTLY --
		# no toast -- which read as "the prop is dead" (it also masked ALL
		# Helper-line visibility). A prop may carry a bespoke `locked_toast`
		# (tease-flavored, may name the required skill/action); absent that,
		# fall back to a generic line that does NOT name the required skill
		# (no progress-toward/skill-name leak on props without authored copy).
		var locked_toast := String(target.get("locked_toast", ""))
		if locked_toast == "":
			locked_toast = "You don't know how to do that yet."
		_emit(WIEvents.TOAST, {"text": locked_toast})
		return {}
	if target.is_empty() or not target.has("on_skill_use"):
		_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": target_id})
		return {}
	var effect: Dictionary = target["on_skill_use"]
	_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": target_id})
	_mark_skill_used(skill_id)
	record_accomplishment(String(effect["accomplishment"]))
	_emit(WIEvents.TOAST, {"text": String(effect["toast"])})
	return effect


## Three Pillars P1: the ONE new engine surface for overworld ("field") skills.
## No target arg -- the FACED cell IS the target, resolved exactly as interact()
## resolves its own (`entity_at(player_cell + player_facing)`). Dispatch order:
##   1. A faced entity whose `requires_skill` == this skill AND that carries an
##      `on_skill_use` responds via `use_skill(skill_id, prop_id)` -- the SAME
##      seam interact() uses, a new trigger. CONTRACT (plan P1, core promise):
##      the emitted event stream is BYTE-IDENTICAL to today's
##      interact-with-requires_skill on that prop -- both tick one action then
##      call `use_skill(skill_id, id)` (interact passes the prop's
##      `requires_skill`, which we have just proven equals `skill_id`).
##   2. No qualifying faced entity -> the skill's own `field_ambient` flavor
##      toast from skills.json (a no-target "you did the thing" line; marks the
##      skill used so the journal reveals it, same as any exploration use).
##   3. No `field_ambient` authored -> the established refusal toast idiom.
## Guards run BEFORE dispatch:
##   - A skill the PC doesn't know (innate + class-granted) is refused exactly
##     as `use_skill()` refuses it: SKILL_UNKNOWN + the generic locked line (no
##     faced prop here, so there is no bespoke `locked_toast` to honor).
##   - A known but non-`field` skill (a combat/table skill with no overworld
##     verb) is refused BEFORE the faced-cell lookup, so it can never trip a
##     prop it happens to be standing in front of.
## Precedence note vs interact()'s prop branch: interact() checks
## sleep/contains/on_interact_accomplishment BEFORE its `use_skill` fallback;
## this surface keys purely on `requires_skill` + `on_skill_use`, so a prop
## (none ships today) that combined `requires_skill` with one of those other
## shapes would diverge here -- a documented field-skill precedence, not a live
## regression.
func use_skill_field(skill_id: String) -> Dictionary:
	# A field-skill press is a deliberate action -- tick the FOLD clock once,
	# exactly as interact() does regardless of how it resolves (so the matched
	# path stays byte-same with interact, and a refused press still costs a beat
	# just as a refused/inert interact does).
	_tick_action()
	if not known_skills().has(skill_id):
		_emit(WIEvents.SKILL_UNKNOWN, {"skill": skill_id})
		_emit(WIEvents.TOAST, {"text": "You don't know how to do that yet."})
		return {}
	if not bool(skills.get(skill_id, {}).get("field", false)):
		_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": ""})
		_emit(WIEvents.TOAST, {"text": "That's not something you can do out here."})
		return {}
	var target := entity_at(player_cell + player_facing)
	if not target.is_empty() and String(target.get("requires_skill", "")) == skill_id and target.has("on_skill_use"):
		return use_skill(skill_id, String(target["id"]))
	# Three Pillars P3: [Observe] reads a DIFFERENT field than the requires_skill/
	# on_skill_use seam above -- ANY faced entity responds with its own `observe`
	# flavor string (generic fallback when it carries none), banking observed_things
	# (opaque; feeds [Tactician]'s levels). An empty faced cell falls through to the
	# skill's field_ambient below. Flavor only -- never numbers/stats/progress.
	if skill_id == "observe" and not target.is_empty():
		var observe_line := String(target.get("observe", "You watch. Details surface."))
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": String(target["id"])})
		_mark_skill_used(skill_id)
		# Social Pillar S1: bank observed_things only on the FIRST observe of
		# this entity this waking (through the shared per-waking dedup dict), so
		# repeat-observing one NPC can no longer farm [Tactician]. The flavor
		# line, skill_used, and journal reveal still fire every time -- only the
		# opaque counter is deduped.
		if _bank_first_use("observe", String(target["id"])):
			record_accomplishment("observed_things")
		_emit(WIEvents.TOAST, {"text": observe_line})
		return {"observed": String(target["id"])}
	# Social Pillar S3: [Charming Smile] (the [Diplomat] kit's field skill) MIRRORS
	# the [Observe] seam above -- ANY faced entity responds with its own
	# `friendly_line` (a warmer per-NPC reaction; generic fallback when it carries
	# none), banking `befriended_moments` (opaque; feeds [Diplomat]'s levels) only
	# on the FIRST charm of this entity this waking, through the SHARED per-waking
	# dedup dict under a DISTINCT verb ("friendly") so charm and observe dedup
	# INDEPENDENTLY on the same entity in the same waking (composite key by design).
	# The flavor line, skill_used, and journal reveal fire every call; only the
	# opaque counter is deduped. Empty faced cell falls through to field_ambient.
	if skill_id == "charming_smile" and not target.is_empty():
		var friendly_line := String(target.get("friendly_line", "You offer a warm, disarming smile. It costs nothing, and it is not unwelcome."))
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": String(target["id"])})
		_mark_skill_used(skill_id)
		if _bank_first_use("friendly", String(target["id"])):
			record_accomplishment("befriended_moments")
		_emit(WIEvents.TOAST, {"text": friendly_line})
		return {"befriended": String(target["id"])}
	var field_ambient := String(skills.get(skill_id, {}).get("field_ambient", ""))
	if field_ambient != "":
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": ""})
		_mark_skill_used(skill_id)
		_emit(WIEvents.TOAST, {"text": field_ambient})
		return {"ambient": skill_id}
	_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": ""})
	_emit(WIEvents.TOAST, {"text": "Nothing here calls for that."})
	return {}


## Social Pillar S1: the rotating "small talk" interact path. Plays ONE pooled
## line from the faced NPC's `talk_pool` (an array of canon-voiced strings),
## chosen by `chatted_with_<id> % pool_size` so the line ROTATES deterministically
## across wakings with ZERO rng (no canonical-seed risk). The line rides the SAME
## plain DIALOGUE_LINE surface a graph-less NPC uses -- the gate_guard idiom:
## `_emit(DIALOGUE_LINE, {"speaker", "text"})`, which message_layer renders. Banks
## `chatted_with_<id>` (the rotation counter, also a [Diplomat] feed) + `heard_gossip`
## (both opaque social counters), and sets `social_talked[<id>]` so a SECOND talk this
## waking falls through to the NPC's real conversation. `sleep()` clears
## `social_talked`, re-arming the pool next waking. The index is read BEFORE the
## counter bank, so the FIRST talk is index 0, the next index 1, ... wrapping at
## `pool_size`.
func _talk_pool_line(target: Dictionary) -> Dictionary:
	var id := String(target["id"])
	var pool: Array = target["talk_pool"]
	var counter_key := "chatted_with_%s" % id
	var idx := accomplishment_count(counter_key) % pool.size()
	var speaker := String(target.get("display_name", id))
	_emit(WIEvents.DIALOGUE_LINE, {"speaker": speaker, "text": String(pool[idx])})
	record_accomplishment(counter_key)
	record_accomplishment("heard_gossip")
	social_talked[id] = true
	return {"talked": id, "index": idx}


## Social Pillar S1: the SHARED per-waking first-use gate. Returns true the FIRST
## time `(verb, entity_id)` is seen since the last `sleep()` (and records it), false
## on every later call this waking. One dict (`entity_first_use`), one clear site
## (sleep), keyed by a `"<verb>:<entity_id>"` string so each verb dedups its own
## bank per entity independently -- [Observe] uses verb "observe" today; S3's
## [Friendly Face] mirrors this with its own verb prefix.
func _bank_first_use(verb: String, entity_id: String) -> bool:
	var key := "%s:%s" % [verb, entity_id]
	if entity_first_use.has(key):
		return false
	entity_first_use[key] = true
	return true


## Records `skill_id` into the `used_skills` SET once, ever — a no-op on a
## repeat use or an empty id. See `used_skills`'s own doc comment for the two
## call sites (exploration, just above; combat, merged in `resolve_combat`).
func _mark_skill_used(skill_id: String) -> void:
	if skill_id == "" or used_skills.has(skill_id):
		return
	used_skills.append(skill_id)


## Adds `amount` to an accomplishment counter (default 1). One event and one
## quest re-check per call regardless of amount, so bulk banks (combat tallies)
## stay one increment per counter instead of N unit records.
func record_accomplishment(id: String, amount: int = 1) -> void:
	accomplishments[id] = int(accomplishments.get(id, 0)) + amount
	_emit(WIEvents.ACCOMPLISHMENT_RECORDED, {"id": id, "count": accomplishments[id]})
	_check_quests()


func accomplishment_count(id: String) -> int:
	return int(accomplishments.get(id, 0))


## Returns innate exploration skills plus class-granted skills, deduplicated.
func known_skills() -> Array:
	var out: Array = player_skills.duplicate()
	if not _combat_config.is_empty() and _combat_config.has("classes"):
		for sk: Variant in WIProgression.granted_skills(classes, _combat_config["classes"], generalist_classes):
			if not out.has(String(sk)):
				out.append(String(sk))
	return out


## Snapshot of everything dialogue gating can see. Rebuilt per node advance
## (M4): effects applied mid-conversation re-gate the same conversation.
func _build_dialogue_ctx() -> Dictionary:
	var names: Dictionary = {}
	for sk_id: String in skills:
		names[sk_id] = String(skills[sk_id].get("display_name", sk_id))
	if not _combat_config.is_empty() and _combat_config.has("classes"):
		for cls: Dictionary in _combat_config["classes"]["classes"]:
			names[String(cls["id"])] = String(cls["display_name"])
	return {"skills": known_skills(), "classes": classes.duplicate(true), "accomplishments": accomplishments.duplicate(true), "names": names}


## Starts a conversation graph if no other modal sim is active.
## Dialogue context is rebuilt after each non-ending option so mid-conversation
## effects can affect the next node's gating.
func start_dialogue(conversation_id: String, source_entity_id: String) -> bool:
	if dialogue != null or combat != null:
		return false
	var graphs: Dictionary = _combat_config.get("dialogue", {})
	if not graphs.has(conversation_id):
		return false
	_dialogue_conversation_id = conversation_id
	_emit(WIEvents.DIALOGUE_STARTED, {"conversation": conversation_id, "entity": source_entity_id})
	dialogue = WIDialogue.new(graphs[conversation_id], _build_dialogue_ctx(), _event_sink)
	dialogue.begin()
	return true


## Applies the selected option's effects, refreshes the dialogue ctx, then
## advances -- so the next node's gating sees this choice's effects (M4).
## start_combat effects still only fire on conversation-ending options.
func dialogue_choose(index: int) -> bool:
	if dialogue == null:
		return false
	var result: Dictionary = dialogue.choose(index)
	if result.is_empty():
		return false
	_emit(WIEvents.DIALOGUE_CHOICE, {"index": index})
	var walker := dialogue
	if bool(result["ended"]):
		dialogue = null
	var pending_combat := ""
	for effect: Dictionary in result["effects"]:
		if effect.has("accomplishment"):
			record_accomplishment(String(effect["accomplishment"]))
		elif effect.has("quest"):
			start_quest(String(effect["quest"]))
		elif effect.has("remove_entity"):
			remove_entity(String(effect["remove_entity"]))
		elif effect.has("item"):
			# M7 Task E2 (spec §4): a dialogue-granted item (e.g. Relc's gift)
			# is a plain pickup with the CONVERSATION id as provenance -- Task
			# E3 wires this into the real relc_intro graph as an
			# effects-array addition; this task only implements the mechanism.
			pickup(String(effect["item"]), _dialogue_conversation_id)
		elif effect.has("start_combat"):
			pending_combat = String(effect["start_combat"])
	if not bool(result["ended"]):
		walker.set_ctx(_build_dialogue_ctx())
		walker.advance(String(result["next"]))
	if pending_combat != "":
		if not start_combat(pending_combat):
			_emit(WIEvents.DIALOGUE_EFFECT_FAILED, {"effect": "start_combat", "id": pending_combat})
	return true


## Starts a quest idempotently and emits a quest_started domain event.
func start_quest(id: String) -> void:
	if started_quests.has(id):
		return
	started_quests.append(id)
	_emit(WIEvents.QUEST_STARTED, {"id": id})
	var catalog: Dictionary = _combat_config.get("quests", {})
	if not catalog.is_empty():
		var now := WIQuests.evaluate(catalog, started_quests, accomplishments)
		if now.has(id):
			_quest_progress[id] = now[id]
	_emit(WIEvents.TOAST, {"text": "New quest: %s" % _quest_title(id)})


func _check_quests() -> void:
	var catalog: Dictionary = _combat_config.get("quests", {})
	if catalog.is_empty() or started_quests.is_empty():
		return
	var now := WIQuests.evaluate(catalog, started_quests, accomplishments)
	for id: String in now:
		var prev: Dictionary = _quest_progress.get(id, {"beat_index": 0, "completed": false})
		if int(now[id]["beat_index"]) > int(prev["beat_index"]) and not bool(now[id]["completed"]):
			_emit(WIEvents.QUEST_BEAT_COMPLETED, {"id": id, "beat": now[id]["beat_index"]})
			_emit(WIEvents.TOAST, {"text": "Quest updated: %s" % String(now[id]["beat_description"])})
		if bool(now[id]["completed"]) and not bool(prev["completed"]):
			_emit(WIEvents.QUEST_BEAT_COMPLETED, {"id": id, "beat": now[id]["beat_index"]})
			_emit(WIEvents.QUEST_COMPLETED, {"id": id})
			_emit(WIEvents.TOAST, {"text": "Quest complete: %s" % _quest_title(id)})
	_quest_progress = now


## Recomputes cached quest progress without emitting quest or toast events.
func reprime_quests() -> void:
	var catalog: Dictionary = _combat_config.get("quests", {})
	if catalog.is_empty() or started_quests.is_empty():
		_quest_progress = {}
		return
	_quest_progress = WIQuests.evaluate(catalog, started_quests, accomplishments)


## Renders started-quest progress as player-facing lines for the journal UI
## (keeps the journal out of sim internals — UI only renders strings).
func quest_summary() -> Array:
	var catalog: Dictionary = _combat_config.get("quests", {})
	var out: Array = []
	var ev := WIQuests.evaluate(catalog, started_quests, accomplishments)
	for id: String in started_quests:
		if not ev.has(id):
			continue
		var title := _quest_title(id)
		out.append("%s — %s" % [title, "Complete" if bool(ev[id]["completed"]) else String(ev[id]["beat_description"])])
	return out


func _quest_title(id: String) -> String:
	var catalog: Dictionary = _combat_config.get("quests", {})
	for quest: Dictionary in catalog.get("quests", []):
		if String(quest["id"]) == id:
			return String(quest.get("title", id))
	return id


## UI wave item 19: journal skills-by-class panel data (UI only renders,
## same "sim builds the strings" convention as `quest_summary` above). One
## group per heading, "Innate" first (player_skills — skills the PC started
## with, not gained from any class) then one group per CURRENTLY HELD class
## in classes.json catalog order. Each group's skill list is that class's own
## cumulative `levels[].grants` at its held level, PLUS (mirroring
## `WIProgression.granted_skills`'s combat-kit build, spec §2.6 ⟦B5⟧) every
## ancestor class named in its `inherits` chain — an evolved class like
## [Swordsman] still shows the [Warrior] kit it grew out of, folded into the
## evolved class's own heading rather than a separate "Warrior" group (the
## ancestor id is no longer HELD once evolution replaces it, so it would
## never get its own group otherwise). NOTE: this duplicates
## `WIProgression._own_grants_at_level`/`_collect_inherited`'s logic locally
## rather than calling those (`progression.gd` is out of this task's edit
## scope) — a values-preserving read of the same public JSON structure
## `_class_display_name` above already reads directly.
func skills_journal() -> Array:
	var groups: Array = []
	if not player_skills.is_empty():
		groups.append({"heading": "Innate", "skills": _skill_entries(player_skills)})
	if not _combat_config.is_empty() and _combat_config.has("classes"):
		var catalog: Array = _combat_config["classes"]["classes"]
		var catalog_by_id: Dictionary = {}
		for cls: Dictionary in catalog:
			catalog_by_id[String(cls["id"])] = cls
		for cls: Dictionary in catalog:
			var id := String(cls["id"])
			if not classes.has(id):
				continue
			var grants: Array = []
			_collect_class_grants(cls, int(classes[id]), catalog_by_id, grants, {id: true})
			if grants.is_empty():
				continue
			groups.append({"heading": String(cls.get("display_name", id)), "skills": _skill_entries(grants)})
	return groups


## `cls`'s own cumulative grants at `held`, PLUS every ancestor named in its
## `inherits` field (string or list), recursively — `visited` cycle-guards a
## malformed catalog. Appends into `out`, deduped.
func _collect_class_grants(cls: Dictionary, held: int, catalog_by_id: Dictionary, out: Array, visited: Dictionary) -> void:
	for lv: Dictionary in cls.get("levels", []):
		if int(lv["level"]) <= held:
			for sk: Variant in lv.get("grants", []):
				if not out.has(String(sk)):
					out.append(String(sk))
	var inherits_raw: Variant = cls.get("inherits")
	if inherits_raw == null:
		return
	var parent_ids: Array = inherits_raw if inherits_raw is Array else [inherits_raw]
	for parent: Variant in parent_ids:
		var parent_id := String(parent)
		if visited.has(parent_id) or not catalog_by_id.has(parent_id):
			continue
		visited[parent_id] = true
		_collect_class_grants(catalog_by_id[parent_id], held, catalog_by_id, out, visited)


## Builds one journal row per skill id: pre-first-use (not in `used_skills`)
## `text` is NAME ONLY; after first use it's "NAME — description" (opacity
## rule: static text from skills.json, never a number or progress-toward).
func _skill_entries(ids: Array) -> Array:
	var out: Array = []
	for raw: Variant in ids:
		var id := String(raw)
		var sk: Dictionary = skills.get(id, {})
		var display := String(sk.get("display_name", id))
		var revealed := used_skills.has(id)
		var text := display
		if revealed:
			var desc := String(sk.get("description", ""))
			if desc != "":
				text = "%s — %s" % [display, desc]
		out.append({"id": id, "display_name": display, "revealed": revealed, "text": text})
	return out


## Starts a tactical combat for an encounter entity.
func start_combat(entity_id: String) -> bool:
	if dialogue != null or combat != null or _combat_config.is_empty():
		return false
	var entity: Dictionary = find_entity(entity_id)
	if entity.is_empty() or String(entity["kind"]) != "encounter":
		return false
	if dormant_encounters.has(entity_id):
		return false
	var by_id := {}
	for c: Dictionary in _combat_config["combatants"]["combatants"]:
		by_id[String(c["id"])] = c
	var cfgs: Array = [_build_player_combatant(by_id["pc"])]
	var allies: Array = entity.get("allies", [])
	var ally_req: Dictionary = entity.get("ally_requires", {})
	for key: String in ally_req:
		if accomplishment_count(key) < int(ally_req[key]):
			allies = []
			break
	for ally: Variant in allies:
		cfgs.append((by_id[String(ally)] as Dictionary).duplicate(true))
	for enemy: Variant in entity.get("enemies", []):
		cfgs.append((by_id[String(enemy)] as Dictionary).duplicate(true))
	var arena: Dictionary = {}
	for a: Dictionary in _combat_config["arenas"]["arenas"]:
		if String(a["id"]) == String(entity["arena"]):
			arena = a
	if arena.is_empty():
		return false
	_pending_encounter = entity_id
	# M7 Task E2 (M-BEAUTY FOLD): route combat's events through
	# _combat_event_relay instead of _event_sink directly -- it forwards
	# everything unchanged but ALSO ticks actions_since_sleep once per the
	# PC's own turn_started. This is a WIGame-side wiring choice only
	# (which Callable gets handed to the constructor); wi_combat.gd's own
	# runtime code is untouched by it.
	combat = WICombat.new(arena, cfgs, skills_config_raw(), _combat_event_relay, rng.randi())
	combat.begin()
	return true


func _build_player_combatant(template: Dictionary) -> Dictionary:
	var pc: Dictionary = template.duplicate(true)
	# Additive per-class stat growth, scaled by split-efficiency (spec §2.4
	# REVISION 2026-07-03): leveling a class grows THAT class's relevant
	# combat stats (magnitude), scaled by the split-efficiency multiplier
	# (unchanged from T4) -- ADDED to the base template stats, never
	# multiplied. Focused/single-class builds hit efficiency exactly 1.0, so
	# they get the full undiminished bonus; split builds get a fraction of
	# each class's bonus, spread across more stat domains.
	pc["stats"] = WIProgression.apply_stat_bonuses(pc["stats"], classes, _combat_config["classes"])
	# M7 §2 combat build injection, read ONCE here (never live during a fight):
	# the class kit is filtered down to what the equipped weapon fields
	# (_weapon_gated_kit); the weapon's flat damage_mod and the armor's
	# hp_mod/damage_reduction ride along on the combatant dict as build-time
	# fields wi_combat.gd's constructor/hit-resolution reads (see that file's
	# _init/_resolve_hit/_deduct_hp). `known_skills()`/`skills_journal()`
	# deliberately do NOT apply this filter -- knowledge is not fieldability.
	var kit: Array = WIProgression.granted_skills(classes, _combat_config["classes"], generalist_classes)
	var weapon := item(String(equipped.get("weapon", "")))
	pc["skills"] = _weapon_gated_kit(kit, String(weapon.get("weapon_family", "")))
	pc["damage_mod"] = int(weapon.get("damage_mod", 0))
	var armor := item(String(equipped.get("armor", "")))
	pc["hp_mod"] = int(armor.get("hp_mod", 0))
	pc["damage_reduction"] = int(armor.get("damage_reduction", 0))
	return pc


## Filters a class kit down to what's fieldable with `weapon_family` equipped
## (M7 §2 weapon gate, reusing the M6 T1 `weapon` tag): a skill carrying
## skills.json's `weapon` key (today: `sword`/`spear`) requires an EXACT
## family match against the currently equipped weapon; a skill with no
## `weapon` key (every spell, every passive) always passes, equipped or
## unarmed alike. `weapon_family` is `""` both when nothing is equipped
## (deliberate unequip) and when an unknown/uncatalogued item id is
## equipped -- either way, no tagged skill can match an empty family, so
## unarmed correctly fields base attack + untagged skills only.
func _weapon_gated_kit(kit: Array, weapon_family: String) -> Array:
	var out: Array = []
	for raw: Variant in kit:
		var sk_id := String(raw)
		var rec: Dictionary = skills.get(sk_id, {})
		if not rec.has("weapon") or String(rec["weapon"]) == weapon_family:
			out.append(sk_id)
	return out


## Returns the data/items.json record for `item_id`, or {} if unknown/
## uncatalogued (no "items" key in combat_config -- a safe degraded mode for
## minimal test fixtures that never touch equipment) or for `item_id == ""`
## (the empty-slot sentinel).
func item(item_id: String) -> Dictionary:
	return _items.get(item_id, {})


## Adds `item_id` to the inventory and emits ITEM_GAINED + a "Got: <name>"
## TOAST (M7 Task E3, spec §3: "Pickups toast via the existing parchment
## toast" -- every pickup call site, container/loot/dialogue-gift alike,
## rides this ONE toast instead of each call site authoring its own copy;
## `message_layer.gd` already renders any TOAST generically, so no UI change
## is needed for this to appear). Idempotent: a repeat pickup of an
## already-carried item (no stacking, spec §6 YAGNI) is a harmless no-op
## that emits nothing and returns false. `source_id` is free-form provenance
## (a container/entity id, a conversation id for a dialogue gift, or a
## loot-roll's encounter id) -- carried in the event payload for QA, never
## branched on here.
func pickup(item_id: String, source_id: String) -> bool:
	if inventory.has(item_id):
		return false
	inventory.append(item_id)
	_emit(WIEvents.ITEM_GAINED, {"item": item_id, "source": source_id})
	var display := String(item(item_id).get("name", item_id))
	_emit(WIEvents.TOAST, {"text": "Got: %s" % display})
	return true


## Equips a carried item into its own kind's slot ("weapon" or "armor"),
## validating kind and possession. Field-only (spec §2: "no mid-combat
## swaps") -- refuses while a fight is active; the combat build reads
## equipment once at start_combat, so a live fight is never retroactively
## affected either way, but refusing keeps the sim from silently accepting
## an action the spec declares unavailable. Maintains the `equipped` ⊆
## `inventory` invariant by construction (possession is required first).
func equip(item_id: String) -> bool:
	if combat != null:
		return false
	if not inventory.has(item_id):
		return false
	var rec := item(item_id)
	if rec.is_empty():
		return false
	var kind := String(rec.get("kind", ""))
	if kind != "weapon" and kind != "armor":
		return false
	equipped[kind] = item_id
	_emit(WIEvents.ITEM_EQUIPPED, {"item": item_id, "slot": kind})
	return true


## Clears a slot ("weapon" or "armor") back to "" -- unequipping the weapon
## is the deliberate-unarmed path (spec §2: base attack + untagged skills
## only at the next combat build). Field-only, same guard as equip(). A safe
## no-op (returns false, emits nothing) on an unknown slot name or a slot
## that's already empty.
func unequip(slot: String) -> bool:
	if combat != null:
		return false
	if slot != "weapon" and slot != "armor":
		return false
	if String(equipped.get(slot, "")) == "":
		return false
	equipped[slot] = ""
	_emit(WIEvents.ITEM_UNEQUIPPED, {"slot": slot})
	return true


## Resolves a finished combat back into world-sim state.
func resolve_combat() -> void:
	if combat == null or not combat.finished:
		return
	# UI wave item 19: merge the PC's cast-skill set (recorded unconditionally
	# by WICombat.spend_skill_costs, regardless of trivial/victory) into the
	# persistent `used_skills` SET here, BEFORE the victory/trivial branch
	# below and BEFORE _bank_action_tally's `trivial` gate — proof that the
	# journal reveal isn't suppressed by the same flag that suppresses the
	# accomplishment tally (the tutorial spar is `trivial: true` but must
	# still reveal a skill's description after its first real use).
	for skill_id: String in (combat.used_skills_tally.get("pc", {}) as Dictionary):
		_mark_skill_used(skill_id)
	var entity: Dictionary = find_entity(_pending_encounter)
	if combat.outcome["victory"]:
		var victories: Variant = entity.get("on_victory", "won_combat")
		for vid: Variant in (victories if victories is Array else [victories]):
			record_accomplishment(String(vid))
		_bank_action_tally(entity)
		_roll_loot(entity)
		# `respawns: true` encounters (M6 §2.2 repeatable skirmishes) stay on
		# the map but go dormant until the next sleep re-arms them; everything
		# else is removed for good.
		if bool(entity.get("respawns", false)):
			if not dormant_encounters.has(_pending_encounter):
				dormant_encounters.append(_pending_encounter)
		elif not bool(entity.get("persistent", false)):
			remove_entity(_pending_encounter)
		# persistent && !respawns -> stays live, immediately re-fightable (the spar)
		_emit(WIEvents.COMBAT_RESOLVED, {"victory": true})
	else:
		_emit(WIEvents.GAME_OVER, {})
	combat = null
	_pending_encounter = ""


## Banks the PC's per-fight deed tally into accomplishments (M6 §2.1 REV 2).
## VICTORY-only by construction (called from resolve_combat's victory branch;
## defeat banks nothing — defeat reloads the autosave, so lost tallies are
## consistent with the reload). Liveness is the `trivial: true` DATA flag on
## the encounter entity or arena, and nothing else: a trivial fight banks
## nothing, silently — there is no round-count or damage-dealt heuristic.
func _bank_action_tally(entity: Dictionary) -> void:
	if bool(entity.get("trivial", false)) or bool(combat.arena_config.get("trivial", false)):
		return
	var tally: Dictionary = combat.action_tally.get("pc", {})
	var counters: Array = tally.keys()
	counters.sort()
	for counter: String in counters:
		record_accomplishment(counter, int(tally[counter]))


## Rolls an encounter's `loot: [{item, chance}]` table on victory (M7 Task
## E3, Plan-time correction 3 -- LOOT RNG ISOLATION). Uses a BRAND NEW
## `RandomNumberGenerator` seeded from a deterministic derivation of
## `_run_seed` + the encounter's own id -- NEVER `self.rng` (the live sim/
## combat stream) -- so a post-victory loot draw can never shift any other
## fight's trajectory, and a canonical multi-fight seed stays byte-identical
## whether or not a drop rolls. Deterministic per (run seed, encounter id)
## pair: the same run seed always rolls the same drops for a given encounter,
## and two different encounter ids draw from independent streams (each seeds
## its own fresh generator, so encounter A's rolls never consume encounter
## B's numbers or vice versa). A no-op (no event) for an entity with no
## `loot` field or an empty table -- the common case for most encounters.
## Emits `LOOT_DROPPED {items}` once for the whole table (not per item) if
## anything actually dropped, then `pickup()`s each dropped item with the
## encounter id as provenance -- `pickup`'s own "Got: <name>" toast (see its
## doc comment) is what the player sees, timed by `combat_screen.gd`'s
## `_close_banner`: `resolve_combat` (and therefore this roll) runs AFTER
## the victory banner's confirm press, in the same synchronous call that
## then hides the combat screen, so any loot toast is queued to render only
## once the banner is already gone -- no redesign needed, see the E3 report.
func _roll_loot(entity: Dictionary) -> void:
	var loot_table: Array = entity.get("loot", [])
	if loot_table.is_empty():
		return
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = hash("%d:%s" % [_run_seed, String(entity.get("id", ""))])
	var dropped: Array[String] = []
	for drop: Dictionary in loot_table:
		var item_id := String(drop["item"])
		var chance := float(drop.get("chance", 0.0))
		if loot_rng.randf() < chance:
			dropped.append(item_id)
	if dropped.is_empty():
		return
	_emit(WIEvents.LOOT_DROPPED, {"items": dropped.duplicate()})
	for item_id: String in dropped:
		pickup(item_id, String(entity.get("id", "")))


## Removes an entity from its owning map and records the removal.
func remove_entity(id: String) -> void:
	for map_id: String in _maps:
		var map_entities: Dictionary = _maps[map_id]["entities"]
		if map_entities.has(id):
			map_entities.erase(id)
			if not removed_entities.has(id):
				removed_entities.append(id)
			_emit(WIEvents.ENTITY_REMOVED, {"id": id})
			return


## Erases an entity from its owning map without emitting or recording removal.
func erase_entity_silent(id: String) -> void:
	for map_id: String in _maps:
		var map_entities: Dictionary = _maps[map_id]["entities"]
		if map_entities.has(id):
			map_entities.erase(id)
			return


## At-cap "waiting" toast copy per class id (M6 T3 §2.3 REV 2) — fires once
## per sleep when a class has reached its evolution `at_level` but this
## sleep's accomplishment volume/dominance neither replaces it nor (mage
## only) grants the generalist kit. Exact canon-voice strings, no numbers
## or percentages (opacity rule). Only classes with an `evolution` block in
## classes.json need an entry here (today: warrior, mage).
const _EVOLUTION_WAITING_TOASTS := {
	"warrior": "Your hands haven't chosen sword or spear yet.",
	"mage": "Your focus wavers between frost and flame.",
}


## Runs the sleep beat (M6 §2.3/§2.5 order: gains -> level-ups -> consolidation
## OFFER -> evolutions). Earned classes are gained (at level 1) BEFORE
## level-ups are evaluated, so a just-gained class can also level up in the
## same sleep if its thresholds are already met. One sleep resolves ALL
## earned level-ups in order (spec §2.2 REV 2 multi-level sleeps), announced
## as ONE batched toast per class — results only, never progress-toward
## (opaque-until-sleep is user-locked). If a consolidation offer fires (spec
## §2.5 REV 2), the sleep beat DEFERS: it emits `consolidation_offered`,
## stores the pending offer, and STOPS before the evolution stage — a player
## who could consolidate this sleep must be offered the choice before an
## evolution outcome locks a class's identity out from under them. The
## deferred beat is completed by exactly one of `accept_consolidation` /
## `decline_consolidation`. Evolutions and the at-cap "waiting" toast are
## ALWAYS checked after level-ups on a non-offering sleep, even with zero
## gains/level-ups (a class already at cap can cross its dominance/volume
## threshold on activity alone) — do not early-return before this stage.
## The sleep beat also re-arms dormant respawning encounters.
func sleep() -> void:
	dormant_encounters.clear()
	# Social Pillar S1: the per-waking social dedup dicts reset every sleep,
	# re-arming each NPC's rotating talk-pool line (social_talked) and the
	# shared first-use-per-entity bank guard (entity_first_use -- [Observe]
	# today, S3's [Friendly Face] next). Cleared here alongside
	# dormant_encounters; neither clear emits, so the existing sleep-beat
	# emission order (phase_changed first, then the progression toasts) is
	# unchanged.
	social_talked.clear()
	entity_first_use.clear()
	# M7 M-BEAUTY FOLD: the day/night clock resets UNCONDITIONALLY at every
	# sleep, and phase_changed fires every time too (even a "day"->"day"
	# no-op reset) -- distinct from _tick_action's crossing-only emits during
	# the day, so a future renderer can rely on "phase_changed after sleep"
	# unconditionally. Runs before the early-return below: the clock is
	# orthogonal to whether progression config exists.
	actions_since_sleep = 0
	_emit(WIEvents.PHASE_CHANGED, {"phase": phase()})
	if _combat_config.is_empty():
		_emit(WIEvents.TOAST, {"text": "You sleep soundly."})
		return
	var anything_happened := false
	var gained_classes := WIProgression.check_class_gains(classes, accomplishments, _combat_config["classes"])
	for class_id: String in gained_classes:
		classes[class_id] = 1
		anything_happened = true
		_emit(WIEvents.CLASS_GAINED, {"class": class_id})
		_emit(WIEvents.TOAST, {"text": _class_gained_toast(class_id)})
	var gains := WIProgression.check_level_ups(classes, accomplishments, _combat_config["classes"])
	if not gains.is_empty():
		anything_happened = true
		# Apply every earned level in order (class_level_up + skill_unlocked
		# fire per level for QA/autosave), batching the announcement per class.
		var order: Array[String] = []
		var summaries: Dictionary = {}
		for gain: Dictionary in gains:
			var class_id := String(gain["class"])
			if not summaries.has(class_id):
				order.append(class_id)
				summaries[class_id] = {"from": int(classes[class_id]), "to": 0, "names": []}
			classes[class_id] = int(gain["level"])
			(summaries[class_id] as Dictionary)["to"] = int(gain["level"])
			_emit(WIEvents.CLASS_LEVEL_UP, {"class": class_id, "level": gain["level"]})
			for sk: Variant in gain["grants"]:
				_emit(WIEvents.SKILL_UNLOCKED, {"skill": String(sk)})
				((summaries[class_id] as Dictionary)["names"] as Array).append(String(skills.get(String(sk), {}).get("display_name", String(sk))))
		for class_id: String in order:
			var summary: Dictionary = summaries[class_id]
			var cls_name := String(_class_display_name(class_id))
			var text := "[%s Level %d]" % [cls_name, int(summary["to"])]
			if int(summary["to"]) > int(summary["from"]) + 1:
				text = "[%s Level %d → %d]" % [cls_name, int(summary["from"]), int(summary["to"])]
			var names: Array = summary["names"]
			if not names.is_empty():
				text += " — unlocked %s" % ", ".join(names)
			_emit(WIEvents.TOAST, {"text": text})

	# --- M6 T5: consolidation OFFER, before evolutions resolve (spec §2.5
	# REV 2) — a player who could consolidate this sleep must be offered the
	# choice before an evolution outcome locks a class's identity. Firing an
	# offer DEFERS the rest of this sleep beat entirely: no evolution check,
	# no "You sleep soundly." fallback (the offer itself is "something
	# happened"). The deferred beat resumes on accept/decline.
	var offer := WIProgression.check_consolidation(classes, _combat_config["classes"])
	if not offer.is_empty():
		pending_consolidation = offer
		_emit(WIEvents.CONSOLIDATION_OFFERED, _enriched_offer(offer))
		return

	if _resolve_evolutions():
		anything_happened = true

	if not anything_happened:
		_emit(WIEvents.TOAST, {"text": "You sleep soundly."})


## Adds display names to a consolidation offer so the UI prompt can render class
## labels without reaching into the class catalog (WIGame owns display strings).
## Shared by the sleep-beat emit and pending_offer_display (the load re-render
## path). `pending_consolidation` itself stays the UNENRICHED offer.
func _enriched_offer(offer: Dictionary) -> Dictionary:
	var enriched := offer.duplicate(true)
	var parent_ids: Array = offer["parents"]
	enriched["parents_display"] = [_class_display_name(String(parent_ids[0])), _class_display_name(String(parent_ids[1]))]
	enriched["target_display"] = _class_display_name(String(offer["target"]))
	return enriched


## The enriched pending consolidation offer, or {} if none is pending. The
## offer event only fires live at the sleep beat; a load restores
## `pending_consolidation` but re-emits nothing, so the UI prompt reconstructs
## itself from this on world spawn (else a save taken mid-offer would load into
## a modal-but-invisible lockout).
func pending_offer_display() -> Dictionary:
	if pending_consolidation.is_empty():
		return {}
	return _enriched_offer(pending_consolidation)


## Applies every outcome of `WIProgression.check_evolutions` against the
## CURRENT `classes`/`accomplishments` (never stashed/derived state — spec
## §2.5 REV 2 "recompute at answer time"). Shared by the non-offering sleep()
## path and `decline_consolidation` (spec: decline runs the evolution stage
## "exactly as an un-offered sleep would"). Returns true if any evolution/
## generalist/waiting outcome fired, so callers can fold it into their own
## "anything happened" bookkeeping for the soundly-sleep fallback.
func _resolve_evolutions() -> bool:
	var anything_happened := false
	var evolutions := WIProgression.check_evolutions(classes, accomplishments, _combat_config["classes"], generalist_classes)
	for outcome: Dictionary in evolutions:
		var class_id := String(outcome["class"])
		if outcome.has("to"):
			var new_id := String(outcome["to"])
			var level := int(outcome["level"])
			var old_name := String(_class_display_name(class_id))
			var new_name := String(_class_display_name(new_id))
			classes[new_id] = level
			classes.erase(class_id)
			anything_happened = true
			_emit(WIEvents.CLASS_EVOLVED, {"from": class_id, "to": new_id, "level": level})
			var text := "[%s] has become [%s]!" % [old_name, new_name]
			if bool(outcome.get("off_interval", false)):
				text += " The change came later than most — but it holds all the same."
			_emit(WIEvents.TOAST, {"text": text})
		elif bool(outcome.get("generalist", false)):
			var grant_names: Array = []
			for sk: Variant in outcome.get("grants", []):
				var sk_id := String(sk)
				# Grants reach combat via granted_skills(generalist_classes) -- the
				# single kit source; no player_skills append (combat spells, and the
				# combat kit never reads player_skills; generalist_classes routes them).
				_emit(WIEvents.SKILL_UNLOCKED, {"skill": sk_id})
				grant_names.append(String(skills.get(sk_id, {}).get("display_name", sk_id)))
			if not generalist_classes.has(class_id):
				generalist_classes.append(class_id)
			anything_happened = true
			var cls_name := String(_class_display_name(class_id))
			var text := "[%s] settles into a balanced mastery" % cls_name
			if not grant_names.is_empty():
				text += " — unlocked %s" % ", ".join(grant_names)
			_emit(WIEvents.TOAST, {"text": text})
		elif bool(outcome.get("waiting", false)) and _EVOLUTION_WAITING_TOASTS.has(class_id):
			anything_happened = true
			_emit(WIEvents.TOAST, {"text": String(_EVOLUTION_WAITING_TOASTS[class_id])})
	return anything_happened


## Answers a pending consolidation offer (M6 T5, spec §2.5 REV 2) by
## accepting it: both parent classes are consumed into the target class at
## the previously-computed merged level, and NO evolution check runs this
## sleep (accepting IS this sleep's identity choice). A safe no-op when
## nothing is pending (double-answering or answering a stale/absent offer
## can never resolve twice or drop the beat). Skills fold automatically via
## the existing `inherits` resolution in `WIProgression.granted_skills` — the
## target class's own `inherits` entry (e.g. spellsword inherits both
## parents) is what keeps both parents' kits fielded, nothing bespoke here.
func accept_consolidation() -> void:
	if pending_consolidation.is_empty():
		return
	var offer := pending_consolidation
	pending_consolidation = {}
	var parents: Array = offer["parents"]
	var target := String(offer["target"])
	var level := int(offer["level"])
	var parent_names: Array = []
	for parent_id: Variant in parents:
		var pid := String(parent_id)
		parent_names.append(String(_class_display_name(pid)))
		classes.erase(pid)
	classes[target] = level
	_emit(WIEvents.CONSOLIDATION_ACCEPTED, offer.duplicate(true))
	var target_name := String(_class_display_name(target))
	_emit(WIEvents.TOAST, {"text": "[%s] and [%s] merge into [%s]!" % [parent_names[0], parent_names[1], target_name]})


## Answers a pending consolidation offer by declining it: the parents are
## untouched, and this sleep's evolution stage runs EXACTLY as an un-offered
## sleep would — recomputed from the CURRENT accomplishment counters at
## answer time (never the stashed offer's derived results; counters, and
## therefore evolution dominance, can change between offer and answer only
## in the sense that nothing else advances the sim in between today, but the
## recompute is the correct/future-proof reading regardless — spec §2.5
## "recompute at answer time"). A safe no-op when nothing is pending.
func decline_consolidation() -> void:
	if pending_consolidation.is_empty():
		return
	pending_consolidation = {}
	_emit(WIEvents.CONSOLIDATION_DECLINED, {})
	if not _resolve_evolutions():
		_emit(WIEvents.TOAST, {"text": "You sleep soundly."})


func _class_display_name(id: String) -> String:
	for cls: Dictionary in _combat_config["classes"]["classes"]:
		if String(cls["id"]) == id:
			return String(cls["display_name"])
	return id


## Onboarding rev O4 (spec §4/§9): a class-gained toast LISTS the skills the
## class grants at level 1 -- e.g. "[Mage] class gained! — [Frost Bolt],
## [Quick Cast], [Light]" -- so the player can INFER what the new class unlocks
## (and, per §5, that a [Light]-wanting cellar is now within reach) with no
## numbers-toward. Derived from the class's own level-1 grants at the gain
## moment (classes[id] was just set to 1); display names come from skills.json,
## which already carries the bracketed "[Name]" form -- the same source and
## bracket style the class_level_up "— unlocked …" toast below already uses, so
## the two announcements read consistently. A class with no level-1 grants
## falls back to the bare "[X] class gained!" (no dash).
func _class_gained_toast(class_id: String) -> String:
	var base := "[%s] class gained!" % _class_display_name(class_id)
	var names: Array[String] = []
	for cls: Dictionary in _combat_config["classes"]["classes"]:
		if String(cls["id"]) == class_id:
			for lv: Dictionary in cls.get("levels", []):
				if int(lv.get("level", 0)) == 1:
					for sk: Variant in lv.get("grants", []):
						names.append(String(skills.get(String(sk), {}).get("display_name", String(sk))))
			break
	if names.is_empty():
		return base
	return "%s — %s" % [base, ", ".join(names)]


## Returns the raw skill config shape consumed by WICombat.
func skills_config_raw() -> Dictionary:
	return {"skills": skills.values()}


func snapshot() -> Dictionary:
	return {
		"current_map": current_map,
		"player_cell": [player_cell.x, player_cell.y],
		"player_facing": [player_facing.x, player_facing.y],
		"player_skills": player_skills.duplicate(),
		"accomplishments": accomplishments.duplicate(true),
		"classes": classes.duplicate(true),
		"removed_entities": removed_entities.duplicate(),
		"dormant_encounters": dormant_encounters.duplicate(),
		"generalist_classes": generalist_classes.duplicate(),
		"started_quests": started_quests.duplicate(),
		"pending_consolidation": pending_consolidation.duplicate(true),
		"used_skills": used_skills.duplicate(),
		"inventory": inventory.duplicate(),
		"equipped": equipped.duplicate(true),
		"container_state": container_state.duplicate(true),
		"actions_since_sleep": actions_since_sleep,
		"phase": phase(),
	}


## M7 M-BEAUTY FOLD: pure reader classifying `actions_since_sleep` against
## `_phase_config`'s thresholds (defaults dusk_at 40, night_at 90 -- data-
## overridable later via a moods.json-sourced config, never hardcoded twice).
## No rng, no side effects, no emit -- callers that need the crossing event
## go through `_tick_action`/`sleep`.
func phase() -> String:
	var dusk_at := int(_phase_config.get("dusk_at", 40))
	var night_at := int(_phase_config.get("night_at", 90))
	if actions_since_sleep >= night_at:
		return "night"
	if actions_since_sleep >= dusk_at:
		return "dusk"
	return "day"


## The SINGLE site that mutates `actions_since_sleep` and checks for a
## phase-threshold crossing (M7 M-BEAUTY FOLD) -- called from move_player
## (on a successful step only), interact (unconditionally, any attempt), and
## _combat_event_relay (once per the PC's own turn_started). Keeping the
## increment + crossing-check + emit logic in exactly one place means every
## call site behaves identically regardless of which action surface
## triggered it. Consumes NO rng.
func _tick_action() -> void:
	var before := phase()
	actions_since_sleep += 1
	var after := phase()
	if after != before:
		_emit(WIEvents.PHASE_CHANGED, {"phase": after})


## Relays every WICombat-emitted event straight to the real sink unchanged
## -- combat behaves identically whether or not this milestone's clock
## exists -- and additionally ticks actions_since_sleep once per the PC's
## own turn_started (M7 M-BEAUTY FOLD). wi_combat.gd's own runtime code is
## untouched: this is purely a WIGame-side choice of which Callable gets
## passed to WICombat's constructor (see start_combat).
func _combat_event_relay(type: String, payload: Dictionary) -> void:
	if type == WIEvents.TURN_STARTED and String(payload.get("id", "")) == "pc":
		_tick_action()
	_emit(type, payload)


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
