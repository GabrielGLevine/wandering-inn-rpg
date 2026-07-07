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
## M-ARC §5 character creation (COSMETIC identity, zero mechanical effect).
## Set ONCE at New Game from the creation screen (via the ctor's
## `creation_config`), never mutated after; additive save fields with tolerant
## defaults (see save.gd). NO sim rule ever branches on these.
##   pc_name   -- replaces "Traveler" on every player-facing surface (combat
##                turn strip/readout, dialogue speaker, field label). Default
##                "Traveler" (the skeleton_scene player display_name).
##   pc_race   -- "human"/"drake"/"gnoll"; branches the GDI opener copy and
##                (with pc_gender) resolves the PC sprite-variant registry key.
##   pc_gender -- "m"/"f"; sprite variant only.
const PC_RACES: Array[String] = ["human", "drake", "gnoll"]
const PC_GENDERS: Array[String] = ["m", "f"]
const PC_NAME_MAX := 16
var pc_name: String = "Traveler"
var pc_race: String = "human"
var pc_gender: String = "m"
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
## M-LEGIBILITY L4: a SET of every combat status id the player has ever
## WATCHED apply (any combatant's application counts — the PC watched it
## happen even when an enemy was the target, e.g. frost_bolt slowing a
## goblin), gating the journal's Effects glossary AND the first-encounter
## surface (see `_combat_event_relay`'s STATUS_APPLIED arm, which is the
## SINGLE site that both checks and banks this — no separate per-combat
## tally is needed: the check-and-bank happens synchronously with the
## sim-side application, in real time, so it is naturally correct both
## across separate fights AND for a second application of the same status
## within ONE fight, unlike a tally that only merges at `resolve_combat`
## (see that function's own doc comment for why a deferred merge would be
## wrong here: a script can end before a fight resolves, e.g. the
## `combat_move_input`/`relc_tutorial` mid-fight-by-design precedent, and
## `seen_statuses` must already be correct for QA to assert by then).
## Additive save field (tolerant default [], see save.gd).
var seen_statuses: Array[String] = []
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
## Currently equipped items by slot, `{"weapon": id, "armor": id,
## "accessory_1": id, "accessory_2": id, "accessory_3": id}` -- `""` means the
## slot is empty (M7 §2; M-GEAR Task G1 added the three accessory slots).
## INVARIANT: every non-empty value here is also present in `inventory` --
## `equip()` enforces this by requiring possession before equipping, and
## nothing in this milestone ever removes an item from `inventory` while it
## is equipped, so the invariant can never be broken by the sim's own API
## surface. Additive save field (v5) -- the three accessory keys are read
## TOLERANTLY (`.get(key, "")`), so a pre-G1 save/scene-config carrying only
## the original 2-key shape restores exactly as if it always had three empty
## accessory slots (no migration, no version bump; see save.gd).
var equipped: Dictionary = {WIKeys.WEAPON: "", "armor": "", "accessory_1": "", "accessory_2": "", "accessory_3": ""}
## M-GEAR Task G1: the PC's resonance budget -- a VISIBLE currency (like gold/
## HP: fine in toasts/events/copy, never a raw hidden stat) that caps how much
## combined `data/items.json` "resonance" an equipped loadout may carry across
## ALL 5 slots (weapon/armor/accessory_1-3 alike -- data decides whether a
## weapon or armor entry carries a nonzero resonance too, the sim just sums
## whatever `item()` reports). Every M7-era item is uncatalogued for
## `resonance` and counts 0 (`item(id).get(WIKeys.RESONANCE, 0)`), so this budget
## is inert today; G2 is the first task that ships items with a real nonzero
## value. Default 2. Capacity GROWTH is a later beat -- this field exists and
## round-trips (additive-optional save field, tolerant default 2, NO version
## bump -- the generalist_classes/gold precedent) but nothing in this
## milestone ever mutates it.
var resonance_capacity: int = 2
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
## Economy v1 Task D1: the PC's coin purse. DIEGETIC money (user call), not a
## hidden stat -- the opaque-until-sleep rule does NOT apply (coins are
## countable in-world objects); earn/spend TOASTS + the inventory coin line
## (D3) display it, never an always-on HUD counter. Mutated ONLY through
## `earn_gold`/`spend_gold` (both emit `gold_changed` + a toast); `spend_gold`
## REFUSES when short (no debt). Additive save field (tolerant default 0, NO
## version bump -- see save.gd, the used_skills/generalist_classes precedent).
var gold: int = 0
## M-DEPTH DP2 (THE REQUEST BOARD): a monotonic count of sleeps taken this
## run, incremented unconditionally in `sleep()` -- the rotation clock for
## `board_bounties()` (WIBounties.active_slate: `times_slept % pool.size()`,
## zero rng, the talk-pool rotation idiom applied to a pool of postings
## instead of a pool of strings) and the "slate rotated overnight" line's
## seen/unseen tracking (`board_last_seen_times_slept` below). Additive save
## field (tolerant default 0, NO version bump -- the gold/generalist_classes
## precedent).
var times_slept: int = 0
## M-DEPTH DP2: the id of the ONE bounty currently accepted, or "" when the
## player holds no posting (v1 simplification, disclosed in the DP2 report:
## Selys won't log a second job while one's outstanding -- "Take on a
## posting." hides once this is non-empty). Additive save field (tolerant
## default "", NO version bump).
var accepted_bounty_id: String = ""
## M-DEPTH DP2: the DELTA-SINCE-ACCEPT baseline for the currently accepted
## bounty's condition, `{accomplishment_id: count_at_accept}` -- snapshotted
## in `accept_bounty()`, read by `WIBounties.condition_met` (current count
## MINUS this baseline, never an absolute read; the staging doc's binding
## semantics call, guarding against a mid-game player insta-completing a
## rotating cull off counters banked before they took the posting). Empty
## when no bounty is accepted. Additive save field (tolerant default {}, NO
## version bump).
var accepted_bounty_baseline: Dictionary = {}
## M-DEPTH DP2: the `times_slept` value the player last opened the board's
## accept picker at -- lets `_open_board_picker_dialogue` show Selys's "New
## paper went up this morning" line exactly once per rotation the player
## hasn't seen yet (compares against the LIVE `times_slept`, updated to match
## every time the picker opens). Additive save field (tolerant default 0,
## matching `times_slept`'s own default so a fresh save never false-positives
## a rotation that hasn't happened yet).
var board_last_seen_times_slept: int = 0
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
## `_bank_first_use(verb, id)` (ARCH-4: now `field_skills.gd`'s helper, since
## its only two call sites, [Appraise Foe]/[Charming Smile], both live in that
## file's dispatch ladder -- the dict itself stays here, threaded in per
## call): [Appraise Foe]'s `observed_things` (resolving the TP-review "Observe
## farm" -- repeat-observing one entity to grind [Tactician]); S3's
## [Friendly Face] `befriended_moments`, mirroring the exact same helper
## with its own verb prefix. Cleared every `sleep()`. Additive save field
## (tolerant default {}, see save.gd).
var entity_first_use: Dictionary = {}
## Playtest feature 3 ([Light] glow): true while the PC carries the conjured
## [Light] orb -- set by the field-ambient cast of [Light] (see use_skill_field),
## cleared at every `sleep()` (canon: the orb winks out when you rest), and
## round-tripped through save.gd (additive-optional, default false) so a load
## restores the glow. The presentation (world.gd) reads THIS flag on every field
## rebuild to re-attach the PC-following PointLight2D -- the sim is authoritative,
## the light node is derived. Diegetically constant across day/dusk/night (it is
## magic), so it deliberately bypasses atmosphere.gd's phase multiplier.
var light_active := false
## Skills Wave Task K1 (freezable-water seam): the set of freezable water cells
## the PC has frost-cast into walkable ice this waking, keyed by map id ->
## Dictionary of Vector2i -> true. A freezable cell (declared per-map in
## `_maps[map_id]["freezable"]`, forced blocked by default at construction) is
## normally impassable water; freezing it flips `is_cell_blocked` to walkable
## until the next `sleep()` clears the whole set (canon: the ice thaws when you
## rest). MIRRORS `light_active`'s lifecycle exactly -- an additive-optional save
## field (default {}, see save.gd) so a load restores mid-waking ice; the
## presentation (world.gd) re-derives the ice overlay from THIS set on every
## field rebuild, the sim staying authoritative. Keyed by map because ice on the
## sewers channels must survive a walk up to the street and back down within a
## waking, exactly as removed_entities is cross-map.
var frozen_cells: Dictionary = {}
## Skills Wave Task K2 (the sneak seam, user-ratified stealth model): true
## while the PC is deliberately sneaking. Toggled by `_toggle_sneak` (a
## `sneaks: true`-tagged field skill's number key, K1's tag-not-id convention)
## and cleared by `_break_sneak` on ANY of: interact() reaching a non-door
## entity/prop response, a successful field-skill use on a target
## (field_ambient no-op flourishes do NOT break it), or start_combat firing
## for any reason. While true, `_check_trigger_radius` never starts combat
## for a proximity danger (the whole point -- walk PAST a proximity ambush);
## Skills Wave Task K3 added a silent `sneaked_past_danger` bank on that same
## skip, once per entity per waking (see that function's doc comment).
## DELIBERATELY NOT SAVED: no
## entry in save.gd's `serialize`/`apply` at all (see that file's comment) --
## a save/reload always restores false, honestly documented rather than
## persisted, mirroring the plan's explicit "drops on save/load" requirement.
## Presentation (world.gd) reads this flag to tint the PC translucent.
var sneaking := false
## Skills Wave Task K2b: the player's ordered hotbar loadout -- a shared list
## of KNOWN skill ids across BOTH bars (field's `field_hotbar_loadout()` and
## combat's `WICombatHud.rebuild_slots`'s 3rd param), a VIEW never a grant.
## Empty (the default) is AUTO mode: both bars derive their slot list exactly
## as they did before this task (byte-identical -- the whole existing QA
## suite passing untouched IS this parity's proof). The instant the player
## assigns/unassigns a skill via the journal (`loadout_toggle`), this becomes
## non-empty and BOTH bars switch to "loadout ∩ known/fielded, in LOADOUT
## order" (see `apply_loadout`) -- a skill known but not in this list is
## simply not shown on either bar this fight/this walk (still known, still
## grantable, just unslotted -- the plan's explicit "slots are the verb
## surface" ruling). Reorder is v1-minimal: assigning appends to the END
## (never inserts), so "assignment order IS the order" -- a dedicated reorder
## key was assessed as not cheap enough to add this task, disclosed in the
## report. Additive-optional save field (v5), NO version bump, same pattern
## as `frozen_cells`/`seen_statuses` above -- an old save missing the key
## restores `[]` (AUTO), which is exactly correct (no one could have
## customized a loadout before this field existed). Filtered against
## known/fielded skills ONLY AT READ TIME (`apply_loadout`'s candidate-set
## intersection) -- the stored array itself is never pruned, so a renamed/
## removed skill id (a future K3 rename) just silently stops contributing a
## slot rather than crashing or toasting.
var hotbar_loadout: Array[String] = []
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
## ARCH-4: the injected pure sub-sim owning gold-transition/loot-roll logic
## (see economy.gd). `gold` itself stays a WIGame field (save.gd reads/writes
## it directly and is out of this task's scope) -- every call threads the
## current value in and gets the new value back.
var _economy: WIEconomy
## ARCH-4: the injected pure sub-sim owning talk-pool rotation (see
## social.gd). `social_talked`/`entity_first_use` stay WIGame fields (see
## social.gd's own doc comment for why) -- every call threads them in.
var _social: WISocial
## ARCH-4: the injected pure sub-sim owning the `use_skill_field` dispatch
## ladder (see field_skills.gd). `sneaking`/`light_active`/`frozen_cells`/
## `entity_first_use` stay WIGame fields (see field_skills.gd's own doc
## comment for why) -- every call threads them in or a callback mutates
## them at the precise point the original code did.
var _field_skills: WIFieldSkills


func _init(scene_config: Dictionary, skill_config: Dictionary, event_sink: Callable, rng_seed: int = 0, combat_config: Dictionary = {}, phase_config: Dictionary = {}, creation_config: Dictionary = {}) -> void:
	_event_sink = event_sink
	_run_seed = rng_seed
	_economy = WIEconomy.new(event_sink, pickup, _set_gold)
	_social = WISocial.new(event_sink, accomplishment_count, record_accomplishment)
	_field_skills = WIFieldSkills.new(event_sink, skills, _break_sneak, _toggle_sneak, _mark_skill_used, record_accomplishment, remove_entity, use_skill, _set_light_active)
	rng.seed = rng_seed
	for s: Dictionary in skill_config.get(WIKeys.SKILLS, []):
		skills[String(s[WIKeys.ID])] = s
	var p: Dictionary = scene_config["player"]
	player_cell = Vector2i(int(p[WIKeys.CELL][0]), int(p[WIKeys.CELL][1]))
	# M-ARC §5: cosmetic identity from the creation screen, sanitized on the way
	# in (tolerant defaults, so a QA default-skip / an old load / a garbled dict
	# all fall back to Human/male/"Traveler"). The scene player's display_name is
	# the pc_name fallback so an untouched New Game reads "Traveler" as before.
	pc_name = _sanitize_pc_name(String(creation_config.get("pc_name", p.get(WIKeys.DISPLAY_NAME, "Traveler"))))
	pc_race = _sanitize_pc_race(String(creation_config.get("pc_race", "human")))
	pc_gender = _sanitize_pc_gender(String(creation_config.get("pc_gender", "m")))
	_combat_config = combat_config
	_phase_config = phase_config
	for it: Dictionary in (combat_config.get("items", {}) as Dictionary).get("items", []):
		_items[String(it[WIKeys.ID])] = it
	classes = (scene_config["player"].get("classes", {}) as Dictionary).duplicate(true)
	for sk: Variant in p.get(WIKeys.SKILLS, []):
		player_skills.append(String(sk))
	for it: Variant in p.get("inventory", []):
		inventory.append(String(it))
	var eq_raw: Dictionary = p.get("equipped", {})
	equipped = {
		WIKeys.WEAPON: String(eq_raw.get(WIKeys.WEAPON, "")),
		"armor": String(eq_raw.get("armor", "")),
		"accessory_1": String(eq_raw.get("accessory_1", "")),
		"accessory_2": String(eq_raw.get("accessory_2", "")),
		"accessory_3": String(eq_raw.get("accessory_3", "")),
	}
	for map_id: String in scene_config["maps"]:
		var m: Dictionary = scene_config["maps"][map_id]
		var ents := {}
		for e: Dictionary in m.get("entities", []):
			var ent: Dictionary = e.duplicate(true)
			ent[WIKeys.CELL] = Vector2i(int(e[WIKeys.CELL][0]), int(e[WIKeys.CELL][1]))
			ents[String(e[WIKeys.ID])] = ent
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
		# Skills Wave Task K1: `freezable` (a top-level list of [x,y] water cells
		# the frost seam can turn to ice) is recorded as its own per-map set AND
		# forced into the blocked set here -- a freezable cell is impassable water
		# by default (idempotent if it also sits under a water walls.segment, which
		# is the authored case: the freeze crossings are cells of the existing
		# channel/pond segments). `is_cell_blocked` consults `frozen_cells` to lift
		# the block once frost-cast.
		var freezable := {}
		for cell: Array in m.get("freezable", []):
			var fc := Vector2i(int(cell[0]), int(cell[1]))
			freezable[fc] = true
			blocked[fc] = true
		_maps[map_id] = {
			"grid": Vector2i(int(m["grid"]["width"]), int(m["grid"]["height"])),
			"entities": ents,
			"blocked": blocked,
			"freezable": freezable,
		}
	_bind_map(String(scene_config["start_map"]))
	_emit(WIEvents.SIM_INITIALIZED, {"seed": rng_seed})


## M-ARC §5 tolerant sanitizers for creation input. A blank/over-long/garbage
## value always resolves to the everyman default rather than erroring, so a QA
## default-skip, an old save missing the field, and a fat-fingered LineEdit all
## land on Human/male/"Traveler".
static func _sanitize_pc_name(raw: String) -> String:
	var s := raw.strip_edges()
	if s.length() > PC_NAME_MAX:
		s = s.substr(0, PC_NAME_MAX).strip_edges()
	return s if s != "" else "Traveler"


static func _sanitize_pc_race(raw: String) -> String:
	return raw if raw in PC_RACES else "human"


static func _sanitize_pc_gender(raw: String) -> String:
	return raw if raw in PC_GENDERS else "m"


## The PC sprite-variant registry key from cosmetic identity ("pc_<race>_<gender>",
## e.g. "pc_drake_f"). PURE string build -- the sim never touches WISpriteRegistry
## (purity rule); presentation resolves the key, falling back to the data sprite
## if the variant art is not registered.
func pc_sprite_variant() -> String:
	return "pc_%s_%s" % [pc_race, pc_gender]


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
	# Skills Wave Task K1: a freezable water cell that has been frost-cast into
	# ice this waking is walkable despite being in the blocked set (water). The
	# entity-occupancy check below still runs -- nothing stands on water, but a
	# frozen cell is treated exactly like any other open floor otherwise.
	if _map_blocked.has(cell) and not _is_frozen(cell):
		return true
	for ent: Dictionary in entities.values():
		if ent[WIKeys.CELL] == cell:
			return true
	return false


## Skills Wave Task K1: true if `cell` is declared freezable on the current map
## (a water cell the frost seam can turn to ice). Pure per-map data lookup.
func _is_freezable(cell: Vector2i) -> bool:
	return (_maps.get(current_map, {}).get("freezable", {}) as Dictionary).has(cell)


## Skills Wave Task K1: true if `cell` on the current map is currently frozen
## (frost-cast into walkable ice, not yet thawed by a sleep).
func _is_frozen(cell: Vector2i) -> bool:
	return (frozen_cells.get(current_map, {}) as Dictionary).has(cell)


## Skills Wave Task K1: JSON-safe view of `frozen_cells` -- `{map_id: [[x,y], ...]}`
## -- shared by save.gd's serializer and `snapshot()` so both encode the ice set
## identically. Empty maps are omitted.
func frozen_cells_json() -> Dictionary:
	var out: Dictionary = {}
	for map_id: String in frozen_cells:
		var cells: Array = []
		for cell: Vector2i in (frozen_cells[map_id] as Dictionary):
			cells.append([cell.x, cell.y])
		if not cells.is_empty():
			out[map_id] = cells
	return out


## Skills Wave Task K1: rebuild `frozen_cells` from the JSON `{map_id: [[x,y],...]}`
## form (save restore). Tolerant of a malformed inner value (skips non-arrays).
func set_frozen_cells_json(data: Dictionary) -> void:
	frozen_cells.clear()
	for map_id: Variant in data:
		var raw: Variant = data[map_id]
		if not (raw is Array):
			continue
		var inner: Dictionary = {}
		for pair: Variant in (raw as Array):
			if pair is Array and (pair as Array).size() == 2:
				inner[Vector2i(int(pair[0]), int(pair[1]))] = true
		if not inner.is_empty():
			frozen_cells[String(map_id)] = inner


func entity_at(cell: Vector2i) -> Dictionary:
	for ent: Dictionary in entities.values():
		if ent[WIKeys.CELL] == cell:
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
## reads `entity[WIKeys.CONVERSATION]`) -- today only `goblin_encounter_1` (no
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
	# Skills Wave Task K2 (the sneak seam): the whole point of sneaking is
	# walking PAST a proximity danger -- no roll, no near-miss combat,
	# nothing. An interact-started encounter (the entity branch of
	# interact()) is unaffected: sneaking past ≠ immunity to walking up and
	# poking it (see interact()'s own break-on-response rule, which still
	# fires start_combat there).
	# Skills Wave Task K3 ([Rogue]'s LEVEL-UP counter, not its gained_by
	# gate -- see classes.json's rogue _comment for the circularity trace):
	# while sneaking, a danger that WOULD have triggered instead banks
	# `sneaked_past_danger` once per entity per waking (entity_first_use,
	# the [Appraise Foe]/[Friendly Face] dedup precedent -- cleared every
	# sleep()), silently (no toast -- OPACITY: sneak stays binary, no
	# detection numbers surface to the player). This is why the loop below
	# no longer short-circuits at the top on `sneaking` alone: it must still
	# inspect distance to know whether THIS danger qualifies.
	for ent: Dictionary in entities.values():
		if String(ent.get(WIKeys.KIND, "")) != "encounter":
			continue
		if not ent.has("trigger_radius"):
			continue
		var ent_cell: Vector2i = ent[WIKeys.CELL]
		var dist := maxi(absi(player_cell.x - ent_cell.x), absi(player_cell.y - ent_cell.y))
		if dist > int(ent["trigger_radius"]):
			continue
		if sneaking:
			var danger_key := "danger:%s" % String(ent[WIKeys.ID])
			if not entity_first_use.has(danger_key):
				entity_first_use[danger_key] = true
				record_accomplishment("sneaked_past_danger")
			continue
		start_combat(String(ent[WIKeys.ID]))
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
	# Skills Wave Task K2 (break condition): interact() reaching ANY
	# entity/prop response breaks sneaking -- EXCEPT a map transition
	# ("crossing a door quietly is the point"), which covers both a real
	# `door` entity and a `prop` whose `door_when` gate is currently met (the
	# same transition, just gated). Computed BEFORE the match/dispatch below
	# so the off-toast (if any) reads before whatever the interact resolves
	# to, matching `_break_sneak`'s callers in `use_skill_field`. A door
	# whose gate is UNMET falls through to the on_interact_accomplishment/
	# use_skill branches below, which DO break -- consistent with "the same
	# entity, not yet a door" reading as a real response.
	var is_door_transition := String(target[WIKeys.KIND]) == "door" \
			or (target.has("door_when") and _door_gate_met(target["door_when"] as Dictionary))
	if not is_door_transition:
		_break_sneak()
	match String(target[WIKeys.KIND]):
		"npc":
			# Social Pillar S1: an NPC carrying a non-empty `talk_pool` plays a
			# rotating small-talk line on the FIRST talk of a waking (before its
			# conversation graph); `social_talked` then routes every later talk
			# this waking to the real conversation below. An empty pool is
			# treated as no pool (never reached today -- S2 authors 2-4 lines).
			var npc_id := String(target[WIKeys.ID])
			if target.has("talk_pool") and not (target["talk_pool"] as Array).is_empty() and not bool(social_talked.get(npc_id, false)):
				return _talk_pool_line(target)
			if target.has(WIKeys.CONVERSATION):
				if start_dialogue(String(target[WIKeys.CONVERSATION]), String(target[WIKeys.ID])):
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
			# M-DEPTH DP2: THE REQUEST BOARD -- checked before every other
			# prop shape (mirrors `sleep`'s early-return position): a board
			# prop is a browse-only surface (current active slate + header/
			# footer, no accept/turn-in -- those live at Selys's desk per
			# board-copy.md sec.2's own framing), built fresh every interact
			# so rotation always reads live.
			if bool(target.get("board", false)):
				return _interact_board(target)
			# M7 Task E3: a container prop (`contains: [item_ids]`) is checked
			# BEFORE `on_interact_accomplishment`/the `use_skill` fallback --
			# no data-driven prop combines `contains` with either of those
			# (a container is its own exclusive prop shape), so branch order
			# among the three never matters in practice, but the container
			# check comes first here to keep it visually adjacent to the
			# other early-return prop shapes above it.
			if target.has("contains"):
				return _interact_container(target)
			# Content Wave C1: a prop carrying `door_when` becomes a gated door
			# once its accomplishment gate is met -- the ONE sanctioned sim seam
			# for the sewer-grate entrance (spec §4). Checked BEFORE
			# on_interact_accomplishment so a met gate transitions instead of
			# re-banking; an UNMET gate falls straight through to the existing
			# on_interact_accomplishment branch below, keeping the pre-quest
			# stream byte-identical (gate_district_walkthrough asserts it). Only
			# `prop` carries this today (a `door` entity is always open); no
			# shipped prop combines `door_when` with `contains`/`sleep`.
			if target.has("door_when") and _door_gate_met(target["door_when"] as Dictionary):
				var dw: Dictionary = target["door_when"]
				var open_toast := String(dw.get("open_toast", ""))
				if open_toast != "":
					_emit(WIEvents.TOAST, {"text": open_toast})
				transition(String(dw["to_map"]), Vector2i(int(dw["to_cell"][0]), int(dw["to_cell"][1])))
				return {"map": current_map}
			if target.has("on_interact_accomplishment"):
				var accomplishment_id := String(target["on_interact_accomplishment"])
				record_accomplishment(accomplishment_id)
				var toast_text := String(target.get("toast", ""))
				if toast_text != "":
					_emit(WIEvents.TOAST, {"text": toast_text})
				# Economy v1 Task D1: an on_interact_accomplishment prop (e.g.
				# serving_tray / patron serve) may carry a sibling optional
				# `gold: N` wage (D2 content). Absent in all D1 data -> streams
				# byte-identical; present in D2 it pays via the shared router.
				if target.has("gold"):
					_apply_gold_effect(int(target["gold"]), String(target[WIKeys.ID]))
				return {"accomplishment": accomplishment_id}
			return use_skill(String(target.get("requires_skill", "")), String(target[WIKeys.ID]))
		"encounter":
			if target.has(WIKeys.CONVERSATION):
				if start_dialogue(String(target[WIKeys.CONVERSATION]), String(target[WIKeys.ID])):
					return {"dialogue": true}
				if start_combat(String(target[WIKeys.ID])):
					return {"combat": true}
				return {}
			if start_combat(String(target[WIKeys.ID])):
				return {"combat": true}
			return {}
		"door":
			transition(String(target["to_map"]), Vector2i(int(target["to_cell"][0]), int(target["to_cell"][1])))
			# M-ARC Task A1: a door may bank an arrival flavor counter on travel
			# (data seam -- liscor_gate banks `reached_liscor`, the Act I gate's
			# street-arrival counter). Fires only here, on real door interaction:
			# QA teleport and save/load restore go through bind_map_silent and
			# never reach this branch, so a load can't spuriously advance the act.
			if target.has("on_enter_accomplishment"):
				record_accomplishment(String(target["on_enter_accomplishment"]))
			return {"map": current_map}
		_:
			_emit(WIEvents.INTERACT_UNHANDLED, {"kind": String(target[WIKeys.KIND]), "id": String(target[WIKeys.ID])})
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
	var id := String(target[WIKeys.ID])
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
	# Economy v1 Task D1: a chore/serve `on_skill_use` effect may carry an
	# optional `gold: N` wage (D2 content, e.g. dirty_table clean). Absent in
	# all D1 data, so every current stream stays byte-identical; present in D2
	# it pays through the same earn/spend router the dialogue verb uses.
	if effect.has("gold"):
		_apply_gold_effect(int(effect["gold"]), target_id)
	return effect


## Three Pillars P1: the ONE engine surface for overworld ("field") skills
## (ARCH-4: the dispatch ladder lives in `field_skills.gd`; see that file's
## doc comment for the full contract). A field-skill press is a deliberate
## action -- tick the FOLD clock once, exactly as interact() does regardless
## of how it resolves.
func use_skill_field(skill_id: String) -> Dictionary:
	_tick_action()
	var known := known_skills().has(skill_id)
	var target := entity_at(player_cell + player_facing)
	var faced_cell := player_cell + player_facing
	var is_freezable := _is_freezable(faced_cell)
	return _field_skills.dispatch(skill_id, known, target, faced_cell, current_map, frozen_cells, entity_first_use, is_freezable)


## ARCH-4: `light_active` mutator, so field_skills.gd's dispatch can flip
## the flag via an injected Callable at the exact point (BEFORE the
## synchronous SKILL_USED emit) world.gd's reconcile handler needs it set.
func _set_light_active(active: bool) -> void:
	light_active = active


## ARCH-4 opus review fix-first: WIEconomy sets the field through this BEFORE
## its synchronous GOLD_CHANGED emit, preserving the pre-extraction invariant
## "when GOLD_CHANGED fires, Game.sim.gold already equals total" (inventory's
## same-frame _refresh_gold depends on it). The wrappers' post-return
## reassignment is then a harmless same-value write.
func _set_gold(new_gold: int) -> void:
	gold = new_gold


## Skills Wave Task K2: the sneak field toggle (see `use_skill_field`'s
## `sneaks: true` tag dispatch). Flips `sneaking`, marks the skill used, and
## emits the matching state event + the on/off toast -- both voice-lint
## clean per the plan ("You soften your step." / "You straighten up.", the
## SAME off-toast `_break_sneak` uses, so an automatic break and a deliberate
## re-press read identically to the player). Never refuses (both guards
## already passed in the caller) and never touches a faced target -- the
## toggle is unconditional on the PC's own state alone.
func _toggle_sneak(skill_id: String) -> Dictionary:
	sneaking = not sneaking
	_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": ""})
	_mark_skill_used(skill_id)
	if sneaking:
		_emit(WIEvents.SNEAK_STARTED, {})
		_emit(WIEvents.TOAST, {"text": "You soften your step."})
	else:
		_emit(WIEvents.SNEAK_ENDED, {})
		_emit(WIEvents.TOAST, {"text": "You straighten up."})
	return {"sneaking": sneaking}


## Skills Wave Task K2: the ONE choke point that clears `sneaking` on any of
## the plan's break conditions (interact()'s non-door dispatch, a successful
## field-skill use on a target, start_combat firing for any cause). A no-op
## (no emit) when not currently sneaking, so every call site can call this
## UNCONDITIONALLY without checking `sneaking` first -- idempotent exactly
## like `_reconcile_pc_light`'s want==have guard, just on the sim side. Fires
## the SAME off-toast `_toggle_sneak` uses on a deliberate re-press, so the
## player sees one consistent line regardless of whether they chose to stop
## or the world chose for them.
func _break_sneak() -> void:
	if not sneaking:
		return
	sneaking = false
	_emit(WIEvents.SNEAK_ENDED, {})
	_emit(WIEvents.TOAST, {"text": "You straighten up."})


## Social Pillar S1: the rotating "small talk" interact path (ARCH-4: logic
## lives in `social.gd`; `social_talked` stays a WIGame field so save.gd's
## direct reads/writes are untouched).
func _talk_pool_line(target: Dictionary) -> Dictionary:
	return _social.talk_pool_line(target, social_talked)


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


## Adds `amount` coins to the purse (ARCH-4: logic lives in `economy.gd`,
## `gold` stays a WIGame field so save.gd's direct reads/writes are
## untouched). `source` is free-form provenance, carried in the event for QA.
func earn_gold(amount: int, source: String) -> void:
	gold = _economy.earn(gold, amount, source)


## Removes `amount` coins IF the purse can cover it (ARCH-4: see economy.gd).
## REFUSES when short (spec §4, no debt), returning false so a caller (a
## dialogue shop buy) can branch on affordability.
func spend_gold(amount: int, source: String) -> bool:
	var result := _economy.spend(gold, amount, source)
	gold = int(result["gold"])
	return bool(result["ok"])


## The single `gold: +/-N` effect-verb router shared by the dialogue effect
## applier (`dialogue_choose`) and chore/serve prop effects (ARCH-4: see
## economy.gd). NOTE: a `gold: -N` spend inside an effect list applies
## UNCONDITIONALLY of any sibling `item:` grant, so a shop buy option MUST
## carry a `requires: {gold: price}` affordability gate -- the gate is what
## guarantees the spend can't refuse while the item is still granted.
func _apply_gold_effect(amount: int, source: String) -> void:
	gold = _economy.apply_gold_effect(gold, amount, source)


## Content Wave C1: true when every accomplishment threshold in a `door_when`
## gate's `requires` dict is met (same >= semantics as ally_requires). An
## empty/absent `requires` reads as "always open". Pure reader -- no state
## change, no events.
func _door_gate_met(door_when: Dictionary) -> bool:
	return _accomplishment_gate_met(door_when.get("requires", {}))


## True when every accomplishment threshold in `req` (id -> min count) is met
## (>= semantics, same as ally_requires / door_when). An empty/absent dict reads
## as "always met". Pure reader -- no state change, no events. Shared by the
## sewer-grate door gate (C1) and the talk_pool_post growth gate (C4).
func _accomplishment_gate_met(req: Dictionary) -> bool:
	for key: String in req:
		if accomplishment_count(key) < int(req[key]):
			return false
	return true


## Returns innate exploration skills plus class-granted skills, deduplicated.
func known_skills() -> Array:
	var out: Array = player_skills.duplicate()
	if not _combat_config.is_empty() and _combat_config.has("classes"):
		for sk: Variant in WIProgression.granted_skills(classes, _combat_config["classes"], generalist_classes):
			if not out.has(String(sk)):
				out.append(String(sk))
	return out


## Skills Wave Task K2b: the ONE pure filter shared by BOTH hotbars (field
## calls this via `field_hotbar_loadout()` below; combat's
## `WICombatHud.rebuild_slots` calls it directly as a static, since it's a
## plain `class_name` -- not an autoload -- so it resolves fine from that
## zero-bare-autoload-identifier file). AUTO mode (`loadout.is_empty()`)
## returns `candidates` UNCHANGED -- the exact byte-parity contract. A
## non-empty loadout returns the ordered subset of `loadout` that also
## appears in `candidates` -- LOADOUT order wins (that's the player's chosen
## order), never `candidates`' own order; a loadout id no longer present in
## `candidates` (unslotted-by-being-unfielded, or a K3 rename) is silently
## dropped, not an error. Pure: no autoload/Node references, safe from sim
## code, UI code, and bare --script tests alike.
static func apply_loadout(candidates: Array, loadout: Array) -> Array:
	if loadout.is_empty():
		return candidates.duplicate()
	var candidate_set: Dictionary = {}
	for raw: Variant in candidates:
		candidate_set[String(raw)] = true
	var out: Array = []
	for raw: Variant in loadout:
		var id := String(raw)
		if candidate_set.has(id):
			out.append(id)
	return out


## Skills Wave Task K2b: the field hotbar's loadout-aware slot list -- the
## SAME `known_skills()`-filtered-by-`field:true` candidate order
## `field_hotbar.gd` used to compute inline (moved here so the sim, not the
## UI, owns the filter, per the plan's "sim owns state + filters" rule),
## passed through `apply_loadout` against the shared `hotbar_loadout`. AUTO
## when the loadout is empty -- byte-identical to the pre-K2b order.
func field_hotbar_loadout() -> Array:
	var candidates: Array = []
	for raw: Variant in known_skills():
		var id := String(raw)
		if bool((skills.get(id, {}) as Dictionary).get("field", false)):
			candidates.append(id)
	return WIGame.apply_loadout(candidates, hotbar_loadout)


## Skills Wave Task K2b: assigns `skill_id` onto the shared loadout if it
## isn't already there, or unassigns it if it is -- the journal's toggle key
## calls this directly (the only real call site; the id it passes is always
## a currently-known skill from `skills_journal()`'s own rows, but this
## method itself does NOT gate on `known_skills()` -- an id that later drops
## out of "known" just stops contributing a slot via `apply_loadout`'s
## candidate-set intersection, never crashes here). Reorder is v1-minimal:
## assigning always APPENDS to the end (never re-inserts at an old
## position), so "assignment order IS the order." Emits `LOADOUT_CHANGED`
## `{skill, assigned, loadout}` on every real mutation (this method is never
## a no-op -- toggle always either appends or erases exactly one entry).
func loadout_toggle(skill_id: String) -> void:
	var already := hotbar_loadout.has(skill_id)
	if already:
		hotbar_loadout.erase(skill_id)
		# KF hardening (opus wave-review seam a): unslotting the skill whose
		# tag currently holds sneak active removes the player's only obvious
		# off-switch (the number key) -- the re-slot recovery is non-obvious,
		# so break sneak honestly at the moment the verb leaves the bar.
		if sneaking and bool(skills.get(skill_id, {}).get("sneaks", false)):
			_break_sneak()
	else:
		hotbar_loadout.append(skill_id)
	_emit(WIEvents.LOADOUT_CHANGED, {"skill": skill_id, "assigned": not already, "loadout": hotbar_loadout.duplicate()})


## Snapshot of everything dialogue gating can see. Rebuilt per node advance
## (M4): effects applied mid-conversation re-gate the same conversation.
func _build_dialogue_ctx() -> Dictionary:
	var names: Dictionary = {}
	for sk_id: String in skills:
		names[sk_id] = String(skills[sk_id].get(WIKeys.DISPLAY_NAME, sk_id))
	if not _combat_config.is_empty() and _combat_config.has("classes"):
		for cls: Dictionary in _combat_config["classes"]["classes"]:
			names[String(cls[WIKeys.ID])] = String(cls[WIKeys.DISPLAY_NAME])
	# Economy v1 Task D1: `gold` rides the ctx so a shop option's affordability
	# `requires: {gold: price}` greys through the SHIPPED M4 mechanism
	# (WIDialogue._meets) -- the ONE sanctioned extension of that ctx (it was
	# skill/class/accomplishment-only; a numeric gold compare is new). Rebuilt
	# per node advance like everything else, so a mid-conversation gold spend
	# re-greys the same node's remaining buy options.
	# M-LEGIBILITY L2: the immutable item catalog rides the ctx (shared by
	# reference, read-only) so the pure WIDialogue walker can format an
	# item-granting option's effect_lines via WIEffectText without an autoload
	# or file read.
	# M-DEPTH DP2: `board_accepted` is the SECOND sanctioned non-accomplishment
	# ctx extension (after `gold` above) -- a plain bool a `requires`/
	# `hide_when` dict can gate on (WIDialogue._meets/_progress_gated), so
	# Selys's "Take on a posting."/"Turn in my posting." hub options can hide/
	# show without a new dialogue.gd concept per feature.
	return {WIKeys.SKILLS: known_skills(), "classes": classes.duplicate(true), "accomplishments": accomplishments.duplicate(true), "names": names, "gold": gold, "items": _items, "board_accepted": accepted_bounty_id != ""}


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


## M-DEPTH DP2: starts a dialogue from a freshly-BUILT (not file-loaded) graph
## Dictionary -- the mechanism behind THE REQUEST BOARD's browse view and
## Selys's bounty accept-picker/turn-in result (see bounties.gd's doc comment
## for the full rationale). Same guard/emit/begin shape as `start_dialogue`
## above, so the dialogue panel UI and every QA wait_for_event idiom
## (dialogue_started/dialogue_node/dialogue_choice/dialogue_ended) need no new
## code path -- only the graph's PROVENANCE differs (code, not
## `_combat_config["dialogue"]`), which is exactly why test_content.gd's
## static-file cross-reference sweep never needs to know these graphs exist.
func _begin_code_dialogue(graph: Dictionary, conversation_label: String, source_entity_id: String) -> bool:
	if dialogue != null or combat != null:
		return false
	_dialogue_conversation_id = conversation_label
	_emit(WIEvents.DIALOGUE_STARTED, {"conversation": conversation_label, "entity": source_entity_id})
	dialogue = WIDialogue.new(graph, _build_dialogue_ctx(), _event_sink)
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
	var pending_board_action := ""
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
		elif effect.has("gold"):
			# Economy v1 Task D1: the `gold: +/-N` dialogue effect verb, beside
			# item/accomplishment. Source/sink = the conversation id (Krshia's
			# shop), same provenance shape pickup uses. A shop buy pairs this
			# `gold: -price` with an `item:` grant AND a `requires: {gold: price}`
			# gate (see _apply_gold_effect's contract note).
			_apply_gold_effect(int(effect["gold"]), _dialogue_conversation_id)
		elif effect.has("start_combat"):
			pending_combat = String(effect["start_combat"])
		elif effect.has("accept_bounty"):
			# M-DEPTH DP2: fired from WITHIN the board picker's own options
			# (see bounties.gd's build_picker_graph) -- a SECOND
			# dialogue_choose call, distinct from the one that opened the
			# picker via open_board_picker below.
			accept_bounty(String(effect["accept_bounty"]))
		elif effect.has("open_board_picker"):
			# M-DEPTH DP2: fired from Selys's static hub option "Take on a
			# posting." (selys_delivery.json). Deferred like start_combat's
			# pending_combat above -- applied AFTER the effects loop, once
			# dialogue is already null (this option always ends the hub
			# conversation), so the swap to the code-built picker graph
			# never collides with walker.advance below.
			pending_board_action = "picker"
		elif effect.has("open_board_turnin"):
			# M-DEPTH DP2: fired from Selys's static hub option "Turn in my
			# posting." (only visible once board_accepted is true). Same
			# deferred-swap shape as open_board_picker above.
			pending_board_action = "turnin"
		elif effect.has("open_board_abandon"):
			# FIX WAVE (DP2 review HIGH finding, second half): fired from
			# Selys's "Hand the posting back." hub option (only visible once
			# board_accepted is true, same requires gate as open_board_turnin
			# above). Same deferred-swap shape -- the hub option ends this
			# conversation first, then _open_board_abandon_dialogue below
			# clears the accepted slip and shows Selys's one line.
			pending_board_action = "abandon"
	if not bool(result["ended"]):
		walker.set_ctx(_build_dialogue_ctx())
		walker.advance(String(result["next"]))
	if pending_combat != "":
		if not start_combat(pending_combat):
			_emit(WIEvents.DIALOGUE_EFFECT_FAILED, {"effect": "start_combat", "id": pending_combat})
	if pending_board_action == "picker":
		_open_board_picker_dialogue()
	elif pending_board_action == "turnin":
		_open_board_turnin_dialogue()
	elif pending_board_action == "abandon":
		_open_board_abandon_dialogue()
	return true


## M-DEPTH DP2 (THE REQUEST BOARD): the full posting pool, injected the same
## way as every other catalog (`_combat_config`). Empty when unconfigured
## (bare `--script` unit tests) -- every caller below already tolerates an
## empty pool/slate.
func _bounty_pool() -> Array:
	return (_combat_config.get("bounties", {}) as Dictionary).get("bounties", [])


func _bounty_by_id(id: String) -> Dictionary:
	for bounty: Dictionary in _bounty_pool():
		if String(bounty["id"]) == id:
			return bounty
	return {}


## The board's CURRENT active slate (2-3 postings), derived fresh every call
## from `times_slept` -- never stored, exactly the WIQuests/progression
## "derived, not stored" convention (see quests.gd's own doc comment).
func board_bounties() -> Array:
	return WIBounties.active_slate(_bounty_pool(), times_slept)


## Accepts a posting from the CURRENT active slate. A no-op if the player
## already holds one (v1 simplification: one job at a time, matching Selys's
## hub option being hidden whenever `accepted_bounty_id` is non-empty -- this
## guard is a defensive second line, not the primary gate) or if `id` doesn't
## resolve (can't happen from the real picker, which only ever offers ids
## straight from `_bounty_pool()`). Snapshots a DELTA-SINCE-ACCEPT baseline
## for every counter the condition reads (the staging doc's binding
## semantics) and banks `accepted_bounty_<id>` (a real accomplishment counter,
## per the plan's "ride existing machinery" scope) for QA/future-content
## visibility. FIX WAVE (DP2 review HIGH finding): a bounty carrying
## `condition_mode: "absolute"` (the three one-shot-keyed postings --
## bounty_sewer_survey/bounty_silk_line/bounty_vermin_grate) needs NO
## baseline at all (condition_met reads the counter directly) -- skip the
## snapshot entirely rather than compute one nothing will ever read, so an
## absolute bounty's `accepted_bounty_baseline` stays the empty-dict default.
func accept_bounty(id: String) -> void:
	if accepted_bounty_id != "":
		return
	var bounty := _bounty_by_id(id)
	if bounty.is_empty():
		return
	accepted_bounty_id = id
	if String(bounty.get("condition_mode", "delta")) == "absolute":
		accepted_bounty_baseline = {}
	else:
		var baseline: Dictionary = {}
		for key: String in (bounty.get("condition", {}) as Dictionary):
			baseline[key] = accomplishment_count(key)
		accepted_bounty_baseline = baseline
	record_accomplishment("accepted_bounty_%s" % id)


## Pure condition check for the currently accepted bounty (false when none is
## accepted). Forwards `accomplishment_count` as a Callable so
## WIBounties.condition_met stays a pure reader, and forwards the bounty's
## own `condition_mode` (default "delta") so FIX-WAVE absolute-mode bounties
## read the counter directly instead of against the (deliberately unsnapshotted)
## baseline.
func _bounty_condition_met() -> bool:
	if accepted_bounty_id == "":
		return false
	var bounty := _bounty_by_id(accepted_bounty_id)
	if bounty.is_empty():
		return false
	return WIBounties.condition_met(bounty.get("condition", {}), accepted_bounty_baseline, Callable(self, "accomplishment_count"), String(bounty.get("condition_mode", "delta")))


## Abandons the currently accepted bounty (FIX WAVE, DP2 review HIGH finding,
## second half): clears `accepted_bounty_id`/`accepted_bounty_baseline` with
## NO gold and NO accomplishment banked either way -- Selys's own line
## (WIBounties.build_abandon_graph) is explicit that this is a clean no-fault
## hand-back, not a partial credit or a penalty. A no-op if nothing is
## accepted (defensive second line, mirrors accept_bounty's own guard shape --
## can't happen from the real hub option, which is `requires`-gated on
## `board_accepted`). Fixes the one-shot soft-lock's SECOND half: without
## this, a bounty a player can never complete (see condition_mode above, pre-
## fix) left `accepted_bounty_id` permanently non-empty with no way to clear
## it -- the board itself never soft-locks again even for a future bounty
## that turns out unfulfillable, because the player always has an exit.
func abandon_bounty() -> void:
	if accepted_bounty_id == "":
		return
	accepted_bounty_id = ""
	accepted_bounty_baseline = {}


## Resolves a turn-in attempt against the currently accepted bounty: pays
## gold + banks `completed_bounty_<id>` + clears the slip on a MET condition
## (through the shared `earn_gold` router -- the same gold_changed/toast
## machinery every other reward uses), leaves all state untouched on an unmet
## condition (opaque-safe: no partial credit, no progress readout). Returns
## whether it paid out, so the caller (`_open_board_turnin_dialogue`) knows
## which of Selys's two board-copy.md lines to show.
func turn_in_bounty() -> bool:
	if accepted_bounty_id == "" or not _bounty_condition_met():
		return false
	var bounty := _bounty_by_id(accepted_bounty_id)
	var id := accepted_bounty_id
	earn_gold(int(bounty.get("gold", 0)), "bounty_%s" % id)
	record_accomplishment("completed_bounty_%s" % id)
	accepted_bounty_id = ""
	accepted_bounty_baseline = {}
	return true


## THE REQUEST BOARD's browse surface (a `prop` carrying `board: true`, e.g.
## `guild_board`): assembles the header (the entity's own `toast` when no
## bounty is accepted, or its `second_visit_toast` variant when one is
## outstanding -- board-copy.md sec.1's two header lines), the CURRENT active
## slate's copy, and the footer (the entity's `observe` text, reused verbatim
## -- no duplication needed), then opens it as a one-option (`Step back from
## the board.`) code-built dialogue. Read-only: no effects, no accept/turn-in
## (those are Selys's, per the copy's own framing). Banks `read_the_board`
## every time, same accomplishment id DP1 shipped.
func _interact_board(target: Dictionary) -> Dictionary:
	record_accomplishment("read_the_board")
	var header := String(target["toast"])
	if accepted_bounty_id != "" and target.has("second_visit_toast"):
		header = String(target["second_visit_toast"])
	var lines: Array[String] = [header, ""]
	for bounty: Dictionary in board_bounties():
		lines.append(String(bounty["copy"]))
		lines.append("")
	lines.append(String(target.get("observe", "")))
	var graph := {
		"start": "hub",
		"nodes": {
			"hub": {
				"speaker": String(target.get(WIKeys.DISPLAY_NAME, "The Request Board")),
				"text": "\n".join(lines),
				"options": [{"text": "Step back from the board.", "end": true}],
			},
		},
	}
	_begin_code_dialogue(graph, "the_request_board", String(target[WIKeys.ID]))
	return {"dialogue": true}


## Opens Selys's bounty accept-picker (fired by her hub's "Take on a
## posting." option). Fires board-copy.md's "slate rotated overnight" line as
## a plain one-shot DIALOGUE_LINE (the SAME bark surface Renn/Ilvo/Yelra's
## talk_pool lines use) the FIRST time the picker opens after `times_slept`
## advanced past what it last opened at -- shown at most once per rotation, as
## its own short exact bark rather than a prefix folded into the picker's
## (already paginated, longer) body text.
func _open_board_picker_dialogue() -> void:
	var slate := board_bounties()
	if times_slept != board_last_seen_times_slept:
		_emit(WIEvents.DIALOGUE_LINE, {"speaker": "Selys", "text": "New paper went up this morning. Old postings come down whether they're done or not — ink's cheap, wall space isn't."})
	board_last_seen_times_slept = times_slept
	_begin_code_dialogue(WIBounties.build_picker_graph(slate), "board_picker", "selys")


## Opens Selys's turn-in result (fired by her hub's "Turn in my posting."
## option). The resolution (gold payout + clearing the slip on a met
## condition) already happened in `turn_in_bounty()` -- this only picks which
## of her two lines to show.
func _open_board_turnin_dialogue() -> void:
	var met := turn_in_bounty()
	_begin_code_dialogue(WIBounties.build_turnin_graph(met), "board_turnin", "selys")


## FIX WAVE (DP2 review HIGH finding, second half): opens Selys's abandon
## result (fired by her hub's "Hand the posting back." option). Same shape
## as _open_board_turnin_dialogue above -- the resolution (clearing the
## accepted slip, no gold, no accomplishment) happens in abandon_bounty()
## first, then the fixed one-node result graph shows Selys's line.
func _open_board_abandon_dialogue() -> void:
	abandon_bounty()
	_begin_code_dialogue(WIBounties.build_abandon_graph(), "board_abandon", "selys")


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


## Count of COMPLETED started quests (pure read via WIQuests) -- the Act II
## gate's "3 of the 4 quests" breadth bar.
func _quests_completed_count() -> int:
	var catalog: Dictionary = _combat_config.get("quests", {})
	if catalog.is_empty() or started_quests.is_empty():
		return 0
	var ev := WIQuests.evaluate(catalog, started_quests, accomplishments)
	var n := 0
	for id: String in ev:
		if bool(ev[id]["completed"]):
			n += 1
	return n


## M-ARC Task A1: the journal act-line data (current act header + milestone
## beats), the same "sim builds the render-ready structure, UI only renders it"
## convention as quest_summary/skills_journal. Counter-derived (WIActs), never
## stored -- old saves land in the correct act by construction. Empty catalog
## -> {} (journal shows no act section).
func act_summary() -> Dictionary:
	var catalog: Dictionary = _combat_config.get("acts", {})
	if catalog.is_empty():
		return {}
	var ctx := {
		"classes_count": classes.size(),
		"quests_completed": _quests_completed_count(),
		"accomplishments": accomplishments,
	}
	return WIActs.evaluate(catalog, ctx)


func _quest_title(id: String) -> String:
	var catalog: Dictionary = _combat_config.get("quests", {})
	for quest: Dictionary in catalog.get("quests", []):
		if String(quest[WIKeys.ID]) == id:
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
			catalog_by_id[String(cls[WIKeys.ID])] = cls
		for cls: Dictionary in catalog:
			var id := String(cls[WIKeys.ID])
			if not classes.has(id):
				continue
			var grants: Array = []
			_collect_class_grants(cls, int(classes[id]), catalog_by_id, grants, {id: true})
			if grants.is_empty():
				continue
			groups.append({"heading": String(cls.get(WIKeys.DISPLAY_NAME, id)), "skills": _skill_entries(grants)})
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
		var display := String(sk.get(WIKeys.DISPLAY_NAME, id))
		var revealed := used_skills.has(id)
		var text := display
		if revealed:
			var desc := String(sk.get("description", ""))
			if desc != "":
				text = "%s — %s" % [display, desc]
		out.append({WIKeys.ID: id, WIKeys.DISPLAY_NAME: display, "revealed": revealed, "text": text})
	return out


## Starts a tactical combat for an encounter entity.
func start_combat(entity_id: String) -> bool:
	if dialogue != null or combat != null or _combat_config.is_empty():
		return false
	var entity: Dictionary = find_entity(entity_id)
	if entity.is_empty() or String(entity[WIKeys.KIND]) != "encounter":
		return false
	if dormant_encounters.has(entity_id):
		return false
	var by_id := {}
	for c: Dictionary in _combat_config["combatants"]["combatants"]:
		by_id[String(c[WIKeys.ID])] = c
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
		if String(a[WIKeys.ID]) == String(entity["arena"]):
			arena = a
	if arena.is_empty():
		return false
	# Skills Wave Task K2 (break condition): start_combat firing for ANY
	# cause clears sneaking -- placed here, the single choke point past every
	# early-return above, so only a fight that is ACTUALLY about to begin
	# breaks it (a refused start_combat attempt costs nothing, matching every
	# other break condition's "only a genuine success counts" rule).
	# _check_trigger_radius never calls start_combat for a proximity danger
	# while sneaking (so it can never reach here sneaking), but a
	# dialogue-effect or an interact-started encounter's own start_combat
	# call both route through this one site too.
	_break_sneak()
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
	# M-ARC §5: the PC's combat turn-strip/readout name follows the chosen
	# identity (cosmetic; stats/skills below untouched). The combat sprite chip
	# is resolved presentation-side in board_renderer (`_combatant_sprite_id`),
	# not here -- board_renderer re-reads the static combatant config, so this
	# runtime dict's `sprite` would never reach the renderer anyway.
	pc[WIKeys.DISPLAY_NAME] = pc_name
	# Additive per-class stat growth, scaled by split-efficiency (spec §2.4
	# REVISION 2026-07-03): leveling a class grows THAT class's relevant
	# combat stats (magnitude), scaled by the split-efficiency multiplier
	# (unchanged from T4) -- ADDED to the base template stats, never
	# multiplied. Focused/single-class builds hit efficiency exactly 1.0, so
	# they get the full undiminished bonus; split builds get a fraction of
	# each class's bonus, spread across more stat domains.
	pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], classes, _combat_config["classes"])
	# M7 §2 combat build injection, read ONCE here (never live during a fight):
	# the class kit is filtered down to what the equipped weapon fields
	# (WICombatBuild.weapon_gated_kit); the weapon's flat damage_mod and the
	# armor's hp_mod/damage_reduction ride along on the combatant dict as
	# build-time fields wi_combat.gd's constructor/hit-resolution reads (see
	# that file's _init/_resolve_hit/_deduct_hp). `known_skills()`/
	# `skills_journal()` deliberately do NOT apply this filter -- knowledge is
	# not fieldability.
	# M-GEAR Task G1: the three equipped accessories fold their own
	# hp_mod/damage_mod/damage_reduction into these SAME three fields (summed
	# alongside the weapon/armor contribution) -- NO new combat field, no
	# change to wi_combat.gd's read side; an item without one of these keys
	# (every M7-era item, and every accessory until G2 ships real values)
	# contributes 0, so this is behaviorally inert until G2 lands.
	# M-ARCH Task ARCH-2: both the weapon-gate filter and the mod summation
	# moved to the shared pure home `src/core/combat_build.gd` (`WICombatBuild`)
	# -- `tests/sim_combat_batch.gd`'s balance harness calls the SAME two
	# functions instead of hand-mirroring them (consultant-flagged drift
	# class). No behavior change: same reads, same math, same fields.
	var kit: Array = WIProgression.granted_skills(classes, _combat_config["classes"], generalist_classes)
	var weapon := item(String(equipped.get(WIKeys.WEAPON, "")))
	pc[WIKeys.SKILLS] = WICombatBuild.weapon_gated_kit(kit, String(weapon.get("weapon_family", "")), skills)
	var armor := item(String(equipped.get("armor", "")))
	var accessories: Array = []
	for slot_name: String in ["accessory_1", "accessory_2", "accessory_3"]:
		accessories.append(item(String(equipped.get(slot_name, ""))))
	var mods: Dictionary = WICombatBuild.equipment_mods(weapon, armor, accessories)
	pc[WIKeys.DAMAGE_MOD] = mods[WIKeys.DAMAGE_MOD]
	pc[WIKeys.HP_MOD] = mods[WIKeys.HP_MOD]
	pc[WIKeys.DAMAGE_REDUCTION] = mods[WIKeys.DAMAGE_REDUCTION]
	return pc


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


## Sums `item(id).resonance` (default 0 -- every M7-era item, uncatalogued
## until G2) across all 5 currently equipped slots (M-GEAR Task G1). Pure
## reader, no rng, no emit -- `equip()`'s capacity gate is the only caller.
func _equipped_resonance_total() -> int:
	var total := 0
	for slot_name: String in equipped:
		total += int(item(String(equipped[slot_name])).get(WIKeys.RESONANCE, 0))
	return total


## M-GEAR Task G3: public read-only mirror of the private sum above, for the
## inventory panel's "Resonance N/M" header. `_equipped_resonance_total()`
## stays private/internal to `equip()`'s own capacity math (G1) -- this is a
## pure one-liner so the UI never re-derives the sum itself (the exact
## duplication risk the brief flagged). No rng, no emit, no state change.
func resonance_used() -> int:
	return _equipped_resonance_total()


## Refusal copy. `_ACCESSORY_SLOTS_FULL_TOAST` is G1's plain-practical
## placeholder, kept per the RESOLVED ruling (2026-07-07 HANDOFF item 1) unless
## a better line falls out naturally. `_CAPACITY_REFUSAL_TOAST` is the
## RATIFIED line (same ruling, candidate 4 from docs/design/gear-staging/
## item-lore-and-accessory-roster.md §C) -- canon-truest: Dissonance's warning
## sign is artifacts SHAKING, so the refusal moment itself is a vibration line.
## Both stay voice-lint clean and diegetic, no "capacity"/"slot" vocabulary, no
## raw stats -- resonance itself is a visible currency like gold/HP, fine to
## reference, but the arithmetic stays off-screen.
const _CAPACITY_REFUSAL_TOAST := "It buzzes once against the others, like a wasp against glass, and will not settle."
const _ACCESSORY_SLOTS_FULL_TOAST := "No room left for another charm — something has to come off first."


## Equips a carried item into its own kind's slot ("weapon", "armor", or --
## M-GEAR Task G1 -- the first EMPTY "accessory_1"/"accessory_2"/"accessory_3"),
## validating kind and possession. Field-only (spec §2: "no mid-combat
## swaps") -- refuses while a fight is active; the combat build reads
## equipment once at start_combat, so a live fight is never retroactively
## affected either way, but refusing keeps the sim from silently accepting
## an action the spec declares unavailable. Maintains the `equipped` ⊆
## `inventory` invariant by construction (possession is required first).
## G1 adds two NEW diegetic refusals (each a distinct toast, both leave
## `equipped`/`inventory` untouched and emit no `item_equipped`): equipping a
## 4th accessory when all three slots are full ("no free slot" --
## `_ACCESSORY_SLOTS_FULL_TOAST`, checked FIRST for accessory kind, before
## resonance is even considered), and equipping into a free/replaceable slot
## whose resulting total resonance (every equipped item's `resonance`, summed
## across all 5 slots, replacing whatever currently occupies the target slot)
## would exceed `resonance_capacity` (the vibration-refusal line --
## `_CAPACITY_REFUSAL_TOAST`). Unequipping frees the departing item's
## resonance back into the budget (see `unequip`).
## G3 CONTRACT: `inventory.gd`'s equip UI has NO generic fallback toast --
## it relies on every player-reachable refusal branch in equip()/unequip()
## emitting its OWN toast. Any NEW refusal added here must self-toast (or
## the panel silently dead-presses, the exact pre-G3 bug).
func equip(item_id: String) -> bool:
	if combat != null:
		return false
	if not inventory.has(item_id):
		return false
	var rec := item(item_id)
	if rec.is_empty():
		return false
	var kind := String(rec.get(WIKeys.KIND, ""))
	if kind != "weapon" and kind != "armor" and kind != "accessory":
		return false
	var target_slot := kind
	if kind == "accessory":
		# G1 review fix: an item already worn in ANY accessory slot must not
		# equip AGAIN into a second empty one -- the resonance sum and the
		# combat-build fold both iterate all three slots, so a duplicate id
		# would double that item's contribution. Silent false, same idiom as
		# the possession/kind guards above (G3's UI greys equipped entries).
		for slot_name: String in ["accessory_1", "accessory_2", "accessory_3"]:
			if String(equipped.get(slot_name, "")) == item_id:
				return false
		target_slot = ""
		for slot_name: String in ["accessory_1", "accessory_2", "accessory_3"]:
			if String(equipped.get(slot_name, "")) == "":
				target_slot = slot_name
				break
		if target_slot == "":
			_emit(WIEvents.TOAST, {"text": _ACCESSORY_SLOTS_FULL_TOAST})
			return false
	var displaced_resonance := int(item(String(equipped.get(target_slot, ""))).get(WIKeys.RESONANCE, 0))
	var would_be_total := _equipped_resonance_total() - displaced_resonance + int(rec.get(WIKeys.RESONANCE, 0))
	if would_be_total > resonance_capacity:
		_emit(WIEvents.TOAST, {"text": _CAPACITY_REFUSAL_TOAST})
		return false
	equipped[target_slot] = item_id
	_emit(WIEvents.ITEM_EQUIPPED, {"item": item_id, "slot": target_slot})
	return true


## Clears a slot ("weapon", "armor", or one of the three M-GEAR Task G1
## accessory slots) back to "" -- unequipping the weapon is the deliberate-
## unarmed path (spec §2: base attack + untagged skills only at the next
## combat build); unequipping an accessory frees its resonance back into the
## budget for the NEXT equip() call (the sum is always recomputed live from
## whatever `equipped` currently holds, so freeing needs no bookkeeping of
## its own). Field-only, same guard as equip(). A safe no-op (returns false,
## emits nothing) on an unknown slot name or a slot that's already empty --
## `equipped.has(slot)` is the validity check since `equipped`'s key set IS
## exactly the five valid slot names, always.
func unequip(slot: String) -> bool:
	if combat != null:
		return false
	if not equipped.has(slot):
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
	# M-LEGIBILITY L4: `seen_statuses` deliberately has NO merge step here,
	# unlike `used_skills` just above — it is banked in real time by
	# `_combat_event_relay` as each STATUS_APPLIED passes through mid-fight
	# (see that function's doc comment), not deferred to a per-fight tally.
	# A deferred merge would be wrong here: this function only ever runs on
	# a FINISHED combat, but the first-encounter surface must already be
	# correct for a script that ends mid-fight by design.
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


## Rolls an encounter's loot table on victory (ARCH-4: the isolated
## hash-derived RNG and drop math live in `economy.gd`, moved INTACT --
## its determinism pins every loot assert). `combat_screen.gd`'s
## `_close_banner` times `resolve_combat` (and therefore this roll) AFTER the
## victory banner's confirm press, so any loot toast queues to render only
## once the banner is already gone.
func _roll_loot(entity: Dictionary) -> void:
	gold = _economy.roll_loot(gold, _run_seed, entity)


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
	# shared first-use-per-entity bank guard (entity_first_use -- [Appraise Foe]
	# today, S3's [Friendly Face] next). Cleared here alongside
	# dormant_encounters; neither clear emits, so the existing sleep-beat
	# emission order (phase_changed first, then the progression toasts) is
	# unchanged.
	social_talked.clear()
	entity_first_use.clear()
	# Playtest feature 3: the conjured [Light] orb winks out when the PC rests.
	# Cleared BEFORE the unconditional PHASE_CHANGED emit below so world.gd's
	# reconcile (which also fires on PHASE_CHANGED -- sleep's guaranteed signal)
	# reads false and detaches the PC glow in the same beat. Runs before the
	# _combat_config early-return so a config-less sim (unit tests) clears too.
	light_active = false
	# Skills Wave Task K1: all frost-cast ice thaws when the PC rests (mirrors the
	# light_active clear above -- an opaque-until-sleep traversal aid, not a
	# permanent map change). Cleared before the unconditional PHASE_CHANGED emit so
	# world.gd's field reconcile drops the ice overlay on the same beat, and before
	# the _combat_config early-return so a config-less sim (unit tests) thaws too.
	frozen_cells.clear()
	# Skills Wave Task K2: sleep clears sneaking too, "with everything else"
	# per the plan -- a SILENT clear (no SNEAK_ENDED, no off-toast), the SAME
	# convention as light_active/frozen_cells just above (sleep already has
	# its own presentation for this beat; a second toast would be noise).
	# world.gd's PHASE_CHANGED hook (fired unconditionally below) is the one
	# that catches this and restores the PC's opacity, exactly like it
	# catches the light/ice clears.
	sneaking = false
	# M7 M-BEAUTY FOLD: the day/night clock resets UNCONDITIONALLY at every
	# sleep, and phase_changed fires every time too (even a "day"->"day"
	# no-op reset) -- distinct from _tick_action's crossing-only emits during
	# the day, so a future renderer can rely on "phase_changed after sleep"
	# unconditionally. Runs before the early-return below: the clock is
	# orthogonal to whether progression config exists.
	actions_since_sleep = 0
	# M-DEPTH DP2: the board's rotation clock. Unconditional (runs even in the
	# config-less unit-test early-return path below, matching light_active/
	# frozen_cells/sneaking just above) -- board_bounties() must advance on
	# every real sleep, combat-config or not.
	times_slept += 1
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
				((summaries[class_id] as Dictionary)["names"] as Array).append(String(skills.get(String(sk), {}).get(WIKeys.DISPLAY_NAME, String(sk))))
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

	# M-ARC AF I1: bank the monotonic "ever reached two classes" flag the moment
	# the PC first holds two classes -- BEFORE the consolidation offer's early
	# return below, so a Warrior/Mage who consolidates (2 classes -> 1) at the
	# Act II threshold has already banked it and can never lose the Act III gate
	# nor walk the journal act-line backward. Silent bookkeeping (no toast); the
	# just-gained class already flagged anything_happened, so this never masks
	# the "You sleep soundly." fallback on its own.
	_bank_reached_two_classes_if_earned()

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

	# M-ARC Task A3: the tremor beat. Once Act II is complete (Act III's entry
	# gate -- a second class + 3 landmark quests, exactly acts.json act_ii's
	# advance_when), the FIRST sleep points the player at the Watch. One-shot,
	# guarded by `watch_runner_pointed`; firing it flags anything_happened so the
	# "You sleep soundly." fallback doesn't double-fire. Talking to Zevara then
	# opens her `summons` node, which banks `heard_the_deep_tremor` (opens the
	# sewers deep_fissure). A consolidation offer this sleep returns early above,
	# deferring the pointer to the next sleep (the flag stays 0) -- an honest
	# one-sleep delay, never a loss.
	if _maybe_fire_tremor_pointer():
		anything_happened = true

	if not anything_happened:
		_emit(WIEvents.TOAST, {"text": "You sleep soundly."})


## M-ARC Task A3: fires the "A Watch runner is looking for you." pointer toast
## ONCE, at the first sleep after Act II completes and before the tremor summons
## has been heard. Returns true iff it fired (so sleep() can mark the beat as
## "something happened"). Pure counter reads -- no rng, no world state beyond
## accomplishments/classes/started_quests.
func _maybe_fire_tremor_pointer() -> bool:
	if accomplishment_count("watch_runner_pointed") >= 1:
		return false
	if accomplishment_count("heard_the_deep_tremor") >= 1:
		return false
	# M-ARC AF I1: read the MONOTONIC reached_two_classes flag, never the live
	# classes.size() -- a Spellsword consolidation drops the count to 1 but must
	# not un-fire the tremor pointer (the Act III entry). The flag is banked at
	# the sleep beat two classes were first held, at consolidation-accept, and
	# derived on load for old saves (see _bank_reached_two_classes_if_earned).
	if accomplishment_count("reached_two_classes") < 1 or _quests_completed_count() < 3:
		return false
	record_accomplishment("watch_runner_pointed")
	_emit(WIEvents.TOAST, {"text": "A Watch runner is looking for you."})
	return true


## M-ARC AF I1: banks the MONOTONIC `reached_two_classes` accomplishment ONCE,
## the first time the PC holds two classes -- or holds an already-merged
## consolidated class, which is itself proof two lines existed. The Act II->III
## advance gate + the tremor pointer read THIS instead of the live
## `classes.size()`, so a Spellsword consolidation (2 classes -> 1) can never
## silently lock Act III or walk the journal act-line backward. Idempotent
## (guards on the count) and SILENT (no toast) -- pure bookkeeping folded into
## sleep() and accept_consolidation(); the load path derives it separately and
## silently (save.gd apply). Uses record_accomplishment so its emission is
## honest at the live sleep/accept beat (an already-derived save no-ops here).
func _bank_reached_two_classes_if_earned() -> void:
	if accomplishment_count("reached_two_classes") >= 1:
		return
	if classes.size() >= 2 or _holds_consolidated_class():
		record_accomplishment("reached_two_classes")


## True iff any held class is a consolidation TARGET (e.g. [Spellsword]). A save
## already merged before the reached_two_classes flag existed still proves two
## lines once existed, so it earns the flag on load. Pure read of classes.json's
## `consolidations`; empty/config-less -> false (safe for bare unit games).
func _holds_consolidated_class() -> bool:
	var cfg: Dictionary = _combat_config.get("classes", {})
	for cons: Dictionary in cfg.get("consolidations", []):
		if classes.has(String((cons as Dictionary).get("target", ""))):
			return true
	return false


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
				grant_names.append(String(skills.get(sk_id, {}).get(WIKeys.DISPLAY_NAME, sk_id)))
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
	# M-ARC AF I1: the merge itself proves two class lines existed -- bank the
	# monotonic flag now so a consolidation that happens BEFORE the reached_two
	# _classes sleep-banking ever ran (or on a save that predates the flag)
	# still holds the Act III gate. No-op if already banked (the usual case:
	# the qualifying sleep banked it first). Placed after the emits above so the
	# accepted->merge-toast event order QA asserts on is undisturbed.
	_bank_reached_two_classes_if_earned()


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
		if String(cls[WIKeys.ID]) == id:
			return String(cls[WIKeys.DISPLAY_NAME])
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
		if String(cls[WIKeys.ID]) == class_id:
			for lv: Dictionary in cls.get("levels", []):
				if int(lv.get("level", 0)) == 1:
					for sk: Variant in lv.get("grants", []):
						names.append(String(skills.get(String(sk), {}).get(WIKeys.DISPLAY_NAME, String(sk))))
			break
	if names.is_empty():
		return base
	return "%s — %s" % [base, ", ".join(names)]


## Returns the raw skill config shape consumed by WICombat.
func skills_config_raw() -> Dictionary:
	return {WIKeys.SKILLS: skills.values()}


func snapshot() -> Dictionary:
	return {
		"current_map": current_map,
		"player_cell": [player_cell.x, player_cell.y],
		"player_facing": [player_facing.x, player_facing.y],
		"pc_name": pc_name,
		"pc_race": pc_race,
		"pc_gender": pc_gender,
		"pc_sprite": pc_sprite_variant(),
		"player_skills": player_skills.duplicate(),
		"accomplishments": accomplishments.duplicate(true),
		"classes": classes.duplicate(true),
		"removed_entities": removed_entities.duplicate(),
		"dormant_encounters": dormant_encounters.duplicate(),
		"generalist_classes": generalist_classes.duplicate(),
		"started_quests": started_quests.duplicate(),
		"pending_consolidation": pending_consolidation.duplicate(true),
		"used_skills": used_skills.duplicate(),
		"seen_statuses": seen_statuses.duplicate(),
		"inventory": inventory.duplicate(),
		"equipped": equipped.duplicate(true),
		"container_state": container_state.duplicate(true),
		"actions_since_sleep": actions_since_sleep,
		"light_active": light_active,
		"frozen_cells": frozen_cells_json(),
		"phase": phase(),
		"sneaking": sneaking,
		"hotbar_loadout": hotbar_loadout.duplicate(),
		"gold": gold,
		"times_slept": times_slept,
		"accepted_bounty_id": accepted_bounty_id,
		"board_active_bounties": board_bounties().map(func(b: Dictionary) -> String: return String(b["id"])),
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
## own turn_started (M7 M-BEAUTY FOLD), and (M-LEGIBILITY L4) enriches a
## STATUS_APPLIED event with `first_seen`/`status_text` the moment it passes
## through, banking the id into `seen_statuses` in the SAME breath. This is
## a WIGame-side wiring choice only, same idiom as the phase-clock tick:
## wi_combat.gd's own runtime code (skill_effects.gd's `_apply_status_from_
## effect`) is untouched and keeps emitting the bare `{id, status}` payload
## it always has; every existing consumer (test_combat_sim.gd's unit tests,
## combat_hud.gd's short "X is slowed!" feed line) reads it exactly as
## before via `.get()`, unaffected by the two new keys.
func _combat_event_relay(type: String, payload: Dictionary) -> void:
	if type == WIEvents.TURN_STARTED and String(payload.get(WIKeys.ID, "")) == "pc":
		_tick_action()
	if type == WIEvents.STATUS_APPLIED:
		payload = _enrich_status_applied(payload)
	_emit(type, payload)


## Checks+banks `payload["status"]` into `seen_statuses` (first time ever,
## across every past and current fight) and returns a COPY of `payload` with
## `first_seen` (bool) always set, plus `status_text` (the L1-generated
## `WIEffectText.status_line` glossary sentence) when first_seen is true —
## "" otherwise, so a repeat application never pays the formatting cost.
## Duplicating the payload is safe/necessary: skill_effects.gd's `_apply_
## status_from_effect` constructs a fresh Dictionary literal per call (no
## other holder), but mutating a Dictionary passed in by reference would be
## a foot-gun for any future caller that DOES keep a reference.
func _enrich_status_applied(payload: Dictionary) -> Dictionary:
	var out := payload.duplicate()
	var status_id := String(out.get("status", ""))
	var first_seen := status_id != "" and not seen_statuses.has(status_id)
	if first_seen:
		seen_statuses.append(status_id)
	out["first_seen"] = first_seen
	out["status_text"] = WIEffectText.status_line(status_id, skills.values()) if first_seen else ""
	return out


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
