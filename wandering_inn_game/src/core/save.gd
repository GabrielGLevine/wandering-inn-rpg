class_name WISave
extends RefCounted
## Pure save serialization. NO file I/O here: the Game autoload owns disk.
## rng_state travels as a String because u64 states exceed JSON double precision.

## 2: the inn re-layout (10x6 -> 16x10, new blocked
## cells) makes v1 player_cell coordinates unsafe -- apply() rejects older
## versions rather than loading a position that may sit inside furniture or
## a wall segment (three v1-reachable cells are full softlocks).
## 3: adds `dormant_encounters` (respawning encounters beaten since
## the last sleep). v2 saves migrate transparently in _migrated() -- nothing
## could be dormant when a v2 save was written; v1 stays rejected.
## `generalist_classes` (classes that took the balanced-mage
## evolution path) is added WITHOUT a version bump -- it is optional and
## NOT in `required`; a save missing the key (any v3 save written before
## this task) restores an empty set, which is exactly correct (no class
## had gone generalist yet). T5 owns any future coordinated version bump.
## `pending_consolidation` (an offer awaiting accept/decline at the
## next sleep) is added the SAME way -- additive, optional, NOT in
## `required`, NO version bump. A save missing the key (any save written
## before this task, or simply a save with no offer pending) restores an
## empty Dictionary, which is exactly correct (no offer was pending).
## the base class id `fighter` was renamed to `warrior`; loaded saves
## are remapped in _migrated() with NO version bump (idempotent), so v3 stays
## the current VERSION.
## `used_skills` (the journal panel's first-use reveal SET)
## is added the SAME additive-optional way as `generalist_classes`/
## `pending_consolidation` above — NOT in `required`, NO version bump. A save
## missing the key (any save written before this task) restores an empty
## Array, which is exactly correct (nothing had been revealed yet).
## 4: the street relayout (10x6 ->
## 32x20, new gate district + blocked cells) makes v3 `street` player_cell
## coordinates unsafe -- same class of bug as the v1->v2 bump above (13
## old-street walkable cells are now blocked; (0,0)/(0,5) are full
## softlocks). UNLIKE v1, this is migrated rather than rejected: only the
## geometry is stale, not the state (v2->v3 precedent). A v3 save whose
## `current_map` is "street" gets `player_cell` relocated to `[1, 3]` (the
## `liscor_gate` arrival cell -- in-bounds, unblocked, unoccupied in the new
## street layout, confirmed by gate_district_walkthrough). Every
## other v3 save (any other current_map) passes through unchanged. _migrated
## composes this on top of the v2->v3 step, so a v2 `street` save chains
## through BOTH migrations in one call.
## 5 (weapons+equipment + the phase-clock fold): adds
## `inventory` (Array[String]), `equipped` ({"weapon","armor"}),
## `container_state` (Dictionary), and `actions_since_sleep` (int) to
## `required` -- these are new REQUIRED fields (not the additive-optional
## pattern used for generalist_classes/pending_consolidation/used_skills,
## which shipped WITHOUT a version bump). A v4 (or v3, or v2) save is
## migrated forward with the plan's tolerant defaults, preserving the
## "equipped items are also in inventory" invariant `equip()` maintains
## going forward: `inventory: ["rusty_sword"]`, `equipped: {"weapon":
## "rusty_sword", "armor": ""}`, `container_state: {}`,
## `actions_since_sleep: 0` -- i.e. an old save wakes up exactly as if it
## had always been carrying and wielding the starter sword (matching the
## v4-and-earlier PC's actual in-fiction state) with a freshly reset action
## clock. _migrated composes this as the fourth step on top of v2->v3->v4,
## so a v2 save chains through all three hops in one call.
## `social_talked` and `entity_first_use` (both
## Dictionaries, the per-waking talk-pool + first-use dedup state) are added
## the SAME additive-optional way as generalist_classes/pending_consolidation/
## used_skills above -- NOT in `required`, NO version bump. A save missing
## either key (any save written before this task) restores an empty Dictionary,
## which is exactly correct (a fresh waking has done no small-talk and no
## first-use bank yet); a present-but-wrong-typed value is still rejected.
## `gold` (int, the coin purse) is added the SAME
## additive-optional way as generalist_classes/pending_consolidation/
## used_skills/social_talked above -- NOT in `required`, NO version bump.
## A save missing the key (older saves) restores 0,
## which is exactly correct (currency did not exist yet, so nothing was
## earned); a present-but-wrong-typed value (not int/float) is still rejected.
## (Playtest feature 3): `light_active` (bool, the conjured [Light] orb glow) is
## added the SAME additive-optional way -- NOT in `required`, NO version bump.
## A save missing the key restores false (no orb was lit before the feature
## existed); a present-but-non-bool value is rejected.
## (character creation): `pc_name` (String), `pc_race` (String), and
## `pc_gender` (String) -- the PC's cosmetic identity -- are added the SAME
## additive-optional way as light_active/gold/used_skills above (NOT in
## `required`, NO version bump). A save missing any of them restores the
## everyman default (Human / male / "Traveler"), which is exactly correct (a
## pre-creation save was always the "Traveler" the game used to hardcode). On
## load each value is re-sanitized through WIGame's own tolerant sanitizers, so
## a corrupt string can never poison the sprite-variant key or the opener
## branch; a present-but-non-String value is rejected.
## `frozen_cells` (the frost-cast ice set, JSON form
## `{map_id: [[x,y], ...]}`) is added the SAME additive-optional way as
## light_active/gold above -- NOT in `required`, NO version bump. A save missing
## the key (any save written before the traversal seams) restores an empty set,
## exactly correct (no cell was frozen before the feature existed, and ice thaws
## every sleep anyway); a present-but-non-Dictionary value is rejected. Restored
## through WIGame.set_frozen_cells_json, which tolerantly skips malformed inner
## pairs, so a garbled cell list can never crash the load.
## `seen_statuses` (the status glossary's seen-set, Array[String])
## is added the SAME additive-optional way as `used_skills` above -- NOT in
## `required`, NO version bump. A save missing the key (any save written before
## this task) restores an empty Array, which is exactly correct (nothing had
## been encountered yet).
## (resonance-limited accessory slots): TWO additive changes,
## neither bumps VERSION (still 5):
##   1. `equipped` (already REQUIRED since v5) gains three new keys inside the
##      SAME Dictionary shape -- `accessory_1`/`accessory_2`/`accessory_3`.
##      This is NOT a new required key -- `equipped` itself is still just
##      type-checked as a Dictionary (see `required` below, unchanged). A
##      pre-G1 save's `equipped` carries only `{"weapon", "armor"}`; restore
##      reads the three accessory keys TOLERANTLY (`.get(key, "")` inside
##      WIGame, never here) so the old 2-key shape loads as if it always had
##      three empty accessory slots -- MIGRATION-FREE by tolerant read, not a
##      `_migrated()` step, because every old value the shape already carried
##      (weapon/armor) is untouched and the new keys have a safe absent
##      default. `game.equipped = equipped.duplicate(true)` (unchanged below)
##      restores whatever dict the save carries verbatim; WIGame's own
##      `equip()`/`unequip()`/`_build_player_combatant()` are what tolerate
##      the missing keys (via `.get(slot, "")`), not a save-time backfill.
##   2. `resonance_capacity` (int, the PC's magical-interference budget) is
##      added the SAME additive-optional way as `gold`/`generalist_classes`
##      above -- NOT in `required`, NO version bump. A save missing the key
##      (any save written before this task) restores 2 (the design default),
##      which is exactly correct (every PC has always had budget 2; nothing
##      before this task could have changed it). A present-but-wrong-typed
##      value (not int/float) is rejected, mirroring the gold/
##      actions_since_sleep numeric checks.
## (the sneak seam): `WIGame.sneaking` is DELIBERATELY
## NOT PERSISTED -- no key in `serialize()`/`apply()` at all, unlike every
## additive-optional flag above. A save/reload always restores false; sneaking
## honestly drops (see wi_game.gd's own doc comment on the field for the full
## break-condition list). No version bump (nothing to migrate: there was never
## a saved value to be missing).
## `hotbar_loadout` (Array[String], the player's
## ordered shared-bar assignment) follows the SAME additive-optional pattern
## as `frozen_cells`/`seen_statuses` above -- NOT in `required`, NO version
## bump. A save missing the key (any save written before this task) restores
## an empty Array (AUTO mode -- exactly today's derivation, since no one
## could have customized a loadout before this field existed); a present-but-
## non-Array value is rejected. The array is restored VERBATIM, never pruned
## here -- `WIGame.apply_loadout`'s candidate-set intersection is what
## silently drops an id that no longer resolves to a known/fielded skill (a
## future K3 rename), not this load path.
## (THE REQUEST BOARD): FOUR additive fields follow the SAME
## additive-optional pattern as gold/generalist_classes/hotbar_loadout above --
## NOT in `required`, NO version bump:
##   `times_slept` (int, default 0) -- the board's rotation clock; a save
##   written before this feature had taken 0 "board-aware" sleeps by
##   definition, so 0 is exactly correct (board_bounties() derives the SAME
##   slate a fresh run would show).
##   `accepted_bounty_id` (String, default "") -- no posting could have been
##   accepted before this feature existed.
##   `accepted_bounty_baseline` (Dictionary, default {}) -- empty is exactly
##   correct alongside an empty accepted_bounty_id.
##   `board_last_seen_times_slept` (int, default 0) -- matches times_slept's
##   own default, so a restored old save never false-positives Selys's "slate
##   rotated overnight" line on its very first post-load board visit.
## (the Runner's Guild): THREE additive fields, the SAME
## additive-optional pattern -- NOT in `required`, NO version bump:
##   `accepted_delivery_id` (String, default "") -- no slip could have been
##   held before this feature existed (accepted_bounty_id's exact twin).
##   `accepted_delivery_baseline` (Dictionary, default {}) -- empty is exactly
##   correct alongside an empty accepted_delivery_id.
##   `delivery_failed` (bool, default false) -- no run could have failed
##   before the feature existed; false means Vess's one-shot night-ledger
##   bark never false-fires on a restored old save.
## (the delivery-slate rotation signpost): ONE additive field, the
## SAME pattern as `board_last_seen_times_slept` above -- NOT in `required`,
## NO version bump:
##   `delivery_last_seen_times_slept` (int, default 0) -- matches
##   `times_slept`'s own default, so a restored old save never false-positives
##   Vess's rotation bark on its very first post-load picker open.
## `well_fed` (bool) is added
## the SAME additive-optional way as `light_active` above -- NOT in `required`,
## NO version bump. A save missing the key restores false (no meal was eaten
## before the feature existed, and the perk doesn't carry past a rest anyway);
## a present-but-non-bool value is rejected.
const VERSION := 5


## Serializes the full persistent WIGame state into a JSON-safe Dictionary.
static func serialize(game: WIGame) -> Dictionary:
	return {"version": VERSION, "state": {
		"current_map": game.current_map,
		"player_cell": [game.player_cell.x, game.player_cell.y],
		"player_facing": [game.player_facing.x, game.player_facing.y],
		"classes": game.classes.duplicate(true),
		"accomplishments": game.accomplishments.duplicate(true),
		"player_skills": game.player_skills.duplicate(),
		"removed_entities": game.removed_entities.duplicate(),
		"dormant_encounters": game.dormant_encounters.duplicate(),
		"generalist_classes": game.generalist_classes.duplicate(),
		"started_quests": game.started_quests.duplicate(),
		"pending_consolidation": game.pending_consolidation.duplicate(true),
		"used_skills": game.used_skills.duplicate(),
		"seen_statuses": game.seen_statuses.duplicate(),
		"inventory": game.inventory.duplicate(),
		"equipped": game.equipped.duplicate(true),
		"container_state": game.container_state.duplicate(true),
		"actions_since_sleep": game.actions_since_sleep,
		"social_talked": game.social_talked.duplicate(true),
		"entity_first_use": game.entity_first_use.duplicate(true),
		"gold": game.gold,
		"resonance_capacity": game.resonance_capacity,
		"light_active": game.light_active,
		"well_fed": game.well_fed,
		"frozen_cells": game.frozen_cells_json(),
		"hotbar_loadout": game.hotbar_loadout.duplicate(),
		"pc_name": game.pc_name,
		"pc_race": game.pc_race,
		"pc_gender": game.pc_gender,
		"rng_state": str(game.rng.state),
		"times_slept": game.times_slept,
		"accepted_bounty_id": game.accepted_bounty_id,
		"accepted_bounty_baseline": game.accepted_bounty_baseline.duplicate(true),
		"board_last_seen_times_slept": game.board_last_seen_times_slept,
		"accepted_delivery_id": game.accepted_delivery_id,
		"accepted_delivery_baseline": game.accepted_delivery_baseline.duplicate(true),
		"delivery_failed": game.delivery_failed,
		"delivery_last_seen_times_slept": game.delivery_last_seen_times_slept,
	}}


## Migrates a loaded save forward, COMPOSING each version step in turn (not a
## switch-case of single hops) so a v2 save chains through BOTH v2->v3 AND
## v3->v4 in one call:
##   v2 -> v3: adds the dormant_encounters list (always empty: a v2 save
##             predates respawning encounters).
##   v3 -> v4: relocates player_cell to the liscor_gate arrival cell [1, 3]
##             IF AND ONLY IF current_map is "street" (W1 relayout fallout --
##             see the VERSION 4 note above); every other v3 save passes
##             through unchanged.
## ON TOP of the version chain, the fighter->warrior class rename is
## applied to any v2/v3/v4 save WITHOUT a version bump -- the base class id
## changed from `fighter` to `warrior`, so a save written before the rename
## carries `fighter` in its classes dict and is remapped here; the remap is
## idempotent (a `warrior`-only save is untouched).
## Returns a migrated COPY for v2/v3/v4 input and the input untouched
## otherwise (v1 and unknown versions still fail apply's version gate).
static func _migrated(data: Dictionary) -> Dictionary:
	if not (data.get("state") is Dictionary):
		return data
	var version := int(data.get("version", -1))
	if version != 2 and version != 3 and version != 4 and version != VERSION:
		return data
	var out: Dictionary = data.duplicate(true)
	var state: Dictionary = out["state"]
	if version == 2:
		state["dormant_encounters"] = []
		version = 3
	if version == 3:
		if String(state.get("current_map", "")) == "street":
			state["player_cell"] = [1, 3]
		version = 4
	if version == 4:
		# An old save wakes up carrying and wielding the starter
		# sword exactly as if it always had (the invariant equip() maintains
		# going forward: equipped items are always also in inventory), with
		# an empty container_state and a freshly reset action clock.
		state["inventory"] = ["rusty_sword"]
		state["equipped"] = {WIKeys.WEAPON: "rusty_sword", "armor": ""}
		state["container_state"] = {}
		state["actions_since_sleep"] = 0
		version = VERSION
	out["version"] = version
	# Typed-assignment guard: a malformed save can carry a non-Dictionary
	# "classes" (apply() rejects it later) -- fetching it into a typed var
	# here threw a SCRIPT ERROR before rejection.
	var cls_raw: Variant = state.get("classes", {})
	if cls_raw is Dictionary:
		var cls: Dictionary = cls_raw
		if cls.has("fighter"):
			cls["warrior"] = maxi(int(cls.get("warrior", 0)), int(cls["fighter"]))
			cls.erase("fighter")
	return out


## Applies a save Dictionary onto a freshly constructed WIGame. Returns false without mutation on invalid version or malformed state.
static func apply(game: WIGame, data: Dictionary) -> bool:
	data = _migrated(data)
	if int(data.get("version", -1)) != VERSION:
		return false
	var raw_state: Variant = data.get("state")
	if not (raw_state is Dictionary):
		return false
	var s: Dictionary = raw_state
	var required := ["current_map", "player_cell", "player_facing", "classes", "accomplishments", "player_skills", "removed_entities", "dormant_encounters", "started_quests", "rng_state", "inventory", "equipped", "container_state", "actions_since_sleep"]
	for key: String in required:
		if not s.has(key):
			return false
	if not (s["player_cell"] is Array) or (s["player_cell"] as Array).size() != 2:
		return false
	if not (s["player_facing"] is Array) or (s["player_facing"] as Array).size() != 2:
		return false
	if not (s["classes"] is Dictionary) or not (s["accomplishments"] is Dictionary):
		return false
	if not (s["player_skills"] is Array) or not (s["removed_entities"] is Array) or not (s["started_quests"] is Array):
		return false
	if not (s["dormant_encounters"] is Array):
		return false
	# generalist_classes is intentionally NOT in `required`: it is an
	# additive optional field with a safe default. A present-but-wrong-typed
	# value is still malformed and rejected.
	if s.has("generalist_classes") and not (s["generalist_classes"] is Array):
		return false
	# pending_consolidation follows the SAME additive-optional pattern.
	if s.has("pending_consolidation") and not (s["pending_consolidation"] is Dictionary):
		return false
	# used_skills follows the SAME additive-optional pattern.
	if s.has("used_skills") and not (s["used_skills"] is Array):
		return false
	# seen_statuses follows the SAME additive-optional pattern.
	if s.has("seen_statuses") and not (s["seen_statuses"] is Array):
		return false
	# social_talked / entity_first_use follow the SAME
	# additive-optional pattern -- default {} when absent, rejected if mistyped.
	if s.has("social_talked") and not (s["social_talked"] is Dictionary):
		return false
	if s.has("entity_first_use") and not (s["entity_first_use"] is Dictionary):
		return false
	# gold follows the SAME additive-optional pattern --
	# default 0 when absent, rejected if present-but-non-numeric (JSON restores
	# whole numbers as float, so int OR float is accepted, mirroring the
	# actions_since_sleep check).
	if s.has("gold") and not (s["gold"] is int or s["gold"] is float):
		return false
	# resonance_capacity follows the SAME additive-optional
	# pattern as gold -- default 2 when absent, rejected if present-but-non-
	# numeric (JSON restores whole numbers as float, so int OR float accepted).
	if s.has("resonance_capacity") and not (s["resonance_capacity"] is int or s["resonance_capacity"] is float):
		return false
	# light_active (Playtest feature 3, the [Light] PC glow) follows the SAME
	# additive-optional pattern -- default false when absent (any save written
	# before this feature had no orb lit), rejected if present-but-non-bool. No
	# version bump.
	if s.has("light_active") and not (s["light_active"] is bool):
		return false
	# well_fed (Erin's daily meal) follows the SAME additive-optional
	# pattern as light_active above -- default false when absent, rejected if
	# present-but-non-bool. No version bump.
	if s.has("well_fed") and not (s["well_fed"] is bool):
		return false
	# frozen_cells follows the SAME additive-optional
	# pattern -- default {} when absent (no ice before the feature), rejected if
	# present-but-non-Dictionary; malformed inner cell lists are skipped on
	# restore (set_frozen_cells_json), never rejected.
	if s.has("frozen_cells") and not (s["frozen_cells"] is Dictionary):
		return false
	# hotbar_loadout follows the SAME additive-optional
	# pattern -- default [] (AUTO) when absent, rejected if present-but-non-Array.
	if s.has("hotbar_loadout") and not (s["hotbar_loadout"] is Array):
		return false
	# pc_name/pc_race/pc_gender follow the SAME additive-optional
	# pattern -- default to the everyman identity when absent, rejected if
	# present-but-non-String; the values themselves are re-sanitized on restore.
	for pc_key: String in ["pc_name", "pc_race", "pc_gender"]:
		if s.has(pc_key) and not (s[pc_key] is String):
			return false
	# times_slept/board_last_seen_times_slept follow the SAME
	# additive-optional pattern as actions_since_sleep's numeric check above --
	# default 0 when absent, rejected if present-but-non-numeric.
	if s.has("times_slept") and not (s["times_slept"] is int or s["times_slept"] is float):
		return false
	if s.has("board_last_seen_times_slept") and not (s["board_last_seen_times_slept"] is int or s["board_last_seen_times_slept"] is float):
		return false
	# accepted_bounty_id follows the SAME additive-optional
	# pattern -- default "" when absent, rejected if present-but-non-String.
	if s.has("accepted_bounty_id") and not (s["accepted_bounty_id"] is String):
		return false
	# accepted_bounty_baseline follows the SAME additive-optional
	# pattern -- default {} when absent, rejected if present-but-non-Dictionary.
	if s.has("accepted_bounty_baseline") and not (s["accepted_bounty_baseline"] is Dictionary):
		return false
	# accepted_delivery_id/accepted_delivery_baseline/delivery_failed follow
	# the SAME additive-optional pattern -- the bounty trio's
	# exact twins plus a bool (light_active's check shape).
	if s.has("accepted_delivery_id") and not (s["accepted_delivery_id"] is String):
		return false
	if s.has("accepted_delivery_baseline") and not (s["accepted_delivery_baseline"] is Dictionary):
		return false
	if s.has("delivery_failed") and not (s["delivery_failed"] is bool):
		return false
	# delivery_last_seen_times_slept follows the SAME additive-optional
	# pattern as board_last_seen_times_slept above -- default 0 when absent,
	# rejected if present-but-non-numeric.
	if s.has("delivery_last_seen_times_slept") and not (s["delivery_last_seen_times_slept"] is int or s["delivery_last_seen_times_slept"] is float):
		return false
	# inventory/equipped/container_state/actions_since_sleep ARE
	# in `required` above (this is a version-bumped addition, not the
	# additive-optional pattern) -- still type-checked here like every other
	# required field.
	if not (s["inventory"] is Array):
		return false
	if not (s["equipped"] is Dictionary):
		return false
	if not (s["container_state"] is Dictionary):
		return false
	if not (s["actions_since_sleep"] is int or s["actions_since_sleep"] is float):
		return false
	if not game.has_map(String(s["current_map"])):
		return false

	var player_cell: Array = s["player_cell"]
	var player_facing: Array = s["player_facing"]
	var removed_entities: Array = s["removed_entities"]
	var player_skills: Array = s["player_skills"]
	var started_quests: Array = s["started_quests"]
	var dormant_encounters: Array = s["dormant_encounters"]
	var generalist_classes: Array = s.get("generalist_classes", [])
	var pending_consolidation: Dictionary = s.get("pending_consolidation", {})
	var used_skills: Array = s.get("used_skills", [])
	var seen_statuses: Array = s.get("seen_statuses", [])
	var inventory: Array = s["inventory"]
	var equipped: Dictionary = s["equipped"]
	var container_state: Dictionary = s["container_state"]
	var social_talked: Dictionary = s.get("social_talked", {})
	var entity_first_use: Dictionary = s.get("entity_first_use", {})

	game.bind_map_silent(String(s["current_map"]), Vector2i(int(player_cell[0]), int(player_cell[1])))
	game.player_facing = Vector2i(int(player_facing[0]), int(player_facing[1]))
	game.classes = (s["classes"] as Dictionary).duplicate(true)
	game.accomplishments = (s["accomplishments"] as Dictionary).duplicate(true)
	# Derive the monotonic `reached_two_classes` flag for saves
	# written before it existed. A save holding two classes (or an already-merged
	# consolidated class, itself proof two lines existed) has completed the Act II
	# milestone; without the flag its Act II->III gate + tremor pointer would
	# regress on load now that both read the flag instead of the live class count.
	# Set DIRECTLY (not via record_accomplishment) -- the load path must emit no
	# gameplay events. Additive, idempotent, NO version bump (a save already
	# carrying the flag keeps it; a genuine <2-class save gets nothing).
	if int(game.accomplishments.get("reached_two_classes", 0)) < 1 \
			and (game.classes.size() >= 2 or game._holds_consolidated_class()):
		game.accomplishments["reached_two_classes"] = 1
	game.player_skills.clear()
	game.player_skills.assign(player_skills)
	game.removed_entities.clear()
	for id: Variant in removed_entities:
		var entity_id := String(id)
		game.erase_entity_silent(entity_id)
		game.removed_entities.append(entity_id)
	game.started_quests.clear()
	game.started_quests.assign(started_quests)
	game.dormant_encounters.clear()
	game.dormant_encounters.assign(dormant_encounters)
	game.generalist_classes.clear()
	game.generalist_classes.assign(generalist_classes)
	game.pending_consolidation = pending_consolidation.duplicate(true)
	game.used_skills.clear()
	game.used_skills.assign(used_skills)
	game.seen_statuses.clear()
	game.seen_statuses.assign(seen_statuses)
	game.inventory.clear()
	game.inventory.assign(inventory)
	game.equipped = equipped.duplicate(true)
	game.container_state = container_state.duplicate(true)
	game.actions_since_sleep = int(s["actions_since_sleep"])
	game.social_talked = social_talked.duplicate(true)
	game.entity_first_use = entity_first_use.duplicate(true)
	game.gold = int(s.get("gold", 0))
	game.resonance_capacity = int(s.get("resonance_capacity", 2))
	game.light_active = bool(s.get("light_active", false))
	game.well_fed = bool(s.get("well_fed", false))
	game.set_frozen_cells_json(s.get("frozen_cells", {}))
	game.hotbar_loadout.clear()
	game.hotbar_loadout.assign(s.get("hotbar_loadout", []))
	# Restore cosmetic identity through WIGame's tolerant sanitizers
	# (absent -> everyman default; garbage -> default), so the sprite-variant key
	# and opener branch are always well-formed regardless of the save's contents.
	game.pc_name = WIGame._sanitize_pc_name(String(s.get("pc_name", "Traveler")))
	game.pc_race = WIGame._sanitize_pc_race(String(s.get("pc_race", "human")))
	game.pc_gender = WIGame._sanitize_pc_gender(String(s.get("pc_gender", "m")))
	game.rng.state = int(String(s["rng_state"]))
	game.times_slept = int(s.get("times_slept", 0))
	game.accepted_bounty_id = String(s.get("accepted_bounty_id", ""))
	game.accepted_bounty_baseline = (s.get("accepted_bounty_baseline", {}) as Dictionary).duplicate(true)
	game.board_last_seen_times_slept = int(s.get("board_last_seen_times_slept", 0))
	game.accepted_delivery_id = String(s.get("accepted_delivery_id", ""))
	game.accepted_delivery_baseline = (s.get("accepted_delivery_baseline", {}) as Dictionary).duplicate(true)
	game.delivery_failed = bool(s.get("delivery_failed", false))
	game.delivery_last_seen_times_slept = int(s.get("delivery_last_seen_times_slept", 0))
	game.reprime_quests()
	return true
