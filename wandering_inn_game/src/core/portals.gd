class_name WIPortals
extends RefCounted
## Magical Door plan Task D4 (issue #8, milestone 8a spec §5.5 the
## anchor-stone-per-region idiom): the portal-menu's pure derivation +
## code-built conversation graph, riding the EXACT WIBounties idiom
## (bounties.gd's build_picker_graph) -- static-only, no instance, no
## injected-Callable constructor. This class owns NO WIGame state to
## mutate (unlike WIEconomy/WISocial/WIFieldSkills, which own a live field
## each and are therefore instantiated per-game with injected setter
## Callables) -- attuned_destinations/build_portal_graph are pure reads
## over a catalog + the current map, so the WIBounties static-function
## shape is the correct precedent to follow, not the instantiated ARCH-4
## sub-sim shape. PURITY RULE: no autoload/Node/scene-tree references --
## every method takes the current portal catalog / an injected
## accomplishment-count Callable and returns a value; wi_game.gd's own
## `_travel_to_portal` owns the actual `transition()` call + arrival toast
## (the O2 rule: portal travel goes through `transition()` ONLY, never
## `move_player`/`_check_trigger_radius` -- see that function's own doc
## comment).
##
## data/portals.json schema (the #10/#12/#16 contract -- every future
## region milestone appends a ROW here, zero code):
##   {"id": str, "display_name": str, "map": str, "cell": [x, y],
##    "requires_accomplishment": str, "arrival_toast": str (optional)}
## `requires_accomplishment` is a SINGLE accomplishment id gated at >= 1
## (the door_when/contains_when >= semantics every other gate in this
## codebase uses). v1 ships BOTH Liscor rows keyed on the SAME
## `door_awakened` (the pair attunes together, since both live in the
## home region the chain itself unlocks); a future region's row keys on
## ITS OWN attunement accomplishment instead -- the anchor-stone-per-region
## idiom's whole point is that each destination's gate is wholly
## independent, never a shared one, so #10/#12/#16 never touch this file.

## The menu's speaker label everywhere it opens -- the SAME name whichever
## physical anchor the player interacts with (the door in the inn, the
## marker stone in the street), because it is the SAME network. Global
## Constraint: "the door prop NEVER speaks" -- this is a NEUTRAL location
## label in the WIBounties board-header idiom (`_interact_board`'s
## `target.get(DISPLAY_NAME, "The Request Board")`), never a character
## line attributed to the door as a speaking entity. The Board precedent's
## OTHER half binds the body copy too (D4 review MEDIUM): the boards' body
## text is strict THIRD-PERSON notice register -- it describes the state of
## the surface, it never addresses the player in the surface's own voice --
## so HUB_TEXT below is a plain description of what the frame shows, not a
## rhetorical question the door could be "asking". The door's only
## milestone voice stays the GDI's (sleep_veil.gd's awakening line).
const SPEAKER := "The Magical Door"
const HUB_TEXT := "The frame stands open on somewhere else. The attunement holds steady."
const NEVER_MIND := "Let it be."


## The PC's currently ATTUNED destinations: every portals.json row whose
## `requires_accomplishment` is met (>= 1), regardless of the player's
## CURRENT map -- callers (build_portal_graph) are what exclude "the
## destination I'm already standing at" from the menu, not this reader (so
## a future caller wanting the full attuned SET -- a journal panel, say --
## can reuse this unfiltered). An empty/absent `requires_accomplishment`
## reads as always-attuned (defensive; every shipped row carries one).
## `accomplishment_count_cb` is Callable(id: String) -> int, forwarding to
## WIGame.accomplishment_count -- injected rather than read directly,
## keeping this class pure (the WIBounties.condition_met precedent).
static func attuned_destinations(rows: Array, accomplishment_count_cb: Callable) -> Array:
	var out: Array = []
	for row: Dictionary in rows:
		var req := String(row.get("requires_accomplishment", ""))
		if req == "" or int(accomplishment_count_cb.call(req)) >= 1:
			out.append(row)
	return out


## Builds the destination-picker conversation for the anchor at
## `current_map` -- lists every ATTUNED destination whose own `map` is NOT
## `current_map` (you cannot travel to where you are already standing),
## each option applying a `{"travel_to": id}` effect on a CONVERSATION-
## ENDING option (wi_game.gd's `dialogue_choose` resolves it via
## `transition()` ONLY -- the O2 rule). Destination labels are short (a
## region name, "Liscor — the Gate District") so -- unlike WIBounties'
## paragraph-copy postings -- they need no paginated-body trick; every
## option IS its own destination, direct, exactly like a plain nav choice.
## Zero eligible destinations elsewhere still returns a valid one-option
## ("Let it be.") graph, never an empty options array (WIDialogue's
## softlock guard would end the conversation outright if it ever were).
static func build_portal_graph(destinations: Array, current_map: String) -> Dictionary:
	var options: Array = []
	for dest: Dictionary in destinations:
		if String(dest.get("map", "")) == current_map:
			continue
		options.append({
			"text": String(dest["display_name"]),
			"effects": [{"travel_to": String(dest["id"])}],
			"end": true,
		})
	options.append({"text": NEVER_MIND, "end": true})
	return {"start": "hub", "nodes": {"hub": {"speaker": SPEAKER, "text": HUB_TEXT, "options": options}}}


## Looks up one portals.json row by id, or {} if unknown -- wi_game.gd's
## `_travel_to_portal` reader (the destination the player just picked off
## the `travel_to` dialogue effect).
static func destination_by_id(rows: Array, id: String) -> Dictionary:
	for row: Dictionary in rows:
		if String(row.get("id", "")) == id:
			return row
	return {}
