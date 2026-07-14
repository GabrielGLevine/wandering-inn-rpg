class_name WIBounties
extends RefCounted
## THE REQUEST BOARD's pure derivation + code-built conversation
## graphs. PURITY RULE: no autoload/Node/scene-tree references -- every method
## takes the current pool/state as parameters (or an injected Callable for the
## one read that needs live accomplishment counters) and returns a value; it
## never mutates WIGame fields directly (accept_bounty/turn_in_bounty in
## wi_game.gd own the actual state writes + gold payout + events).
##
## Two concerns live here:
##   1. Rotation + condition math (active_slate/condition_met) -- the
##      talk-pool rotation idiom (social.gd's chatted_with_<id> % pool.size(),
##      zero rng) applied at POOL-WINDOW granularity, plus the plan's binding
##      delta-since-accept semantics (docs/archive/staging/board-staging/
##      guild-bounties.json's design note): a bounty's condition is evaluated
##      as (current counter - counter AT ACCEPT) >= threshold, never an
##      absolute read, so a mid-game player can't insta-complete a rotating
##      cull off counters banked before they took the posting.
##   2. Graph construction (build_picker_graph/build_turnin_graph) -- these
##      return plain WIDialogue-shaped {start,nodes} Dictionaries, IDENTICAL in
##      shape to a data/dialogue/*.json graph, but built fresh from the CURRENT
##      active slate/accepted state instead of loaded from a static file. This
##      is "a conversation graph FED from bounty data" (the plan's own words):
##      WIDialogue itself never knows or cares whether its graph came from JSON
##      or from here, so the existing dialogue-panel UI renders it unchanged
##      (zero new UI) -- and because these graphs are never registered under
##      data/dialogue/, test_content.gd's static cross-reference sweep never
##      sees them (there is no goto-target/quest-id/produced-accomplishment
##      drift risk to check, since nothing here is hand-authored content).


## Derives the ACTIVE slate (2-3 postings) from the full pool: a window of
## size min(3, pool.size()) starting at `times_slept % pool.size()`, wrapping.
## Zero rng -- deterministic per times_slept, exactly the talk-pool rotation
## idiom (social.gd's chatted_with_<id> % pool.size()) applied to a pool of
## RECORDS instead of a pool of STRINGS. Empty pool -> empty slate (never
## divides by zero).
static func active_slate(pool: Array, times_slept: int) -> Array:
	if pool.is_empty():
		return []
	var size := mini(3, pool.size())
	var start := times_slept % pool.size()
	var out: Array = []
	for i: int in size:
		out.append(pool[(start + i) % pool.size()])
	return out


## True when every key in `condition` (an {accomplishment_id: min_delta} dict,
## the quests.json complete_when shape) clears its threshold (multi-key =
## AND, same convention as WIQuests.beat_index/quests.json). Two modes,
## selected per-bounty by `data/bounties.json`'s optional `condition_mode`
## field (default "delta" when the bounty carries none):
##   "delta" (the original DP2 semantics, still the default): current count
##     must have advanced by AT LEAST the threshold SINCE the baseline
##     snapshot taken at accept time (current - baseline >= threshold) -- the
##     right shape for a ROTATING/repeatable condition, so a mid-game player
##     can't insta-complete a bounty off counters banked before accepting.
##   "absolute" (DP2 review HIGH finding): current count alone must
##     clear the threshold, baseline ignored entirely -- the right shape for a
##     condition keyed on a ONE-SHOT accomplishment (bounty_sewer_survey/
##     bounty_silk_line/bounty_vermin_grate), where delta semantics would
##     permanently soft-lock the posting for any player who did the
##     underlying thing before ever seeing the board (work already done is
##     honest board pay; one-shot accomplishments can't be gamed into a
##     repeat payout by this).
## `accomplishment_count_cb` is `Callable(id: String) -> int`, forwarding to
## WIGame.accomplishment_count -- injected rather than read directly to keep
## this class pure.
static func condition_met(condition: Dictionary, baseline: Dictionary, accomplishment_count_cb: Callable, mode: String = "delta") -> bool:
	for key: String in condition:
		var current := int(accomplishment_count_cb.call(key))
		var threshold := int(condition[key])
		if mode == "absolute":
			if current < threshold:
				return false
		else:
			var base := int(baseline.get(key, 0))
			if current - base < threshold:
				return false
	return true


## Gate reader for a posting's optional `requires` field (issue #91's
## post_game standing orders): every {accomplishment_id: min_count} key must
## clear. Rows without the field always pass. `accomplishment_count_cb` is
## the SAME injected Callable shape condition_met uses (purity rule).
## TRAP: this is a POOL filter (board_bounties() applies it BEFORE
## active_slate), so a `requires` row is invisible to rotation math until
## its gate banks -- pre-gate windows stay byte-identical by construction;
## post-gate the filtered pool GROWS and wrap-zone windows shift (disclosed
## per-append in data/bounties.json's own _comment).
static func requires_met(bounty: Dictionary, accomplishment_count_cb: Callable) -> bool:
	var requires: Dictionary = bounty.get("requires", {})
	for key: String in requires:
		if int(accomplishment_count_cb.call(key)) < int(requires[key]):
			return false
	return true


## Short board-title per posting id, for the picker's OPTION row (the body
## text above already carries the full numbered copy paragraph -- the option
## itself only needs a name a player can recognize at a glance, not a second
## copy of the notice). One entry per bounty currently in data/bounties.json;
## an id with no authored title still gets a readable fallback (underscores
## to spaces, title-cased) rather than silently reverting to a bare number.
## KEEP IN LOCKSTEP: src/ui/journal.gd's _POSTING_TITLES/_DELIVERY_TITLES
## duplicate these maps (the journal can't reach these private statics) --
## a new posting/delivery id added here needs its title there too, or the
## journal's Postings section silently shows the generic fallback title
## while this picker shows the authored one.
static func _posting_title(bounty_id: String) -> String:
	var titles := {
		"bounty_road_cull": "Goblin Cull, Floodplains Road",
		"bounty_settle_dispute": "Settle a Quarrel",
		"bounty_gossip_tea": "Gather Gossip for Krshia",
		"bounty_observe_survey": "District Observation Log",
		"bounty_sewer_survey": "Drainage Gallery Check",
		"bounty_silk_line": "Mark the Silk Line",
		"bounty_inn_hands": "Extra Hands at the Inn",
		"bounty_evening_stew": "Evening Stew Shift",
		"bounty_vermin_grate": "Vermin Under the Grate",
		"bounty_lamp_upkeep": "Keep the Common Room Lit",
		"bounty_tavern_tables": "Wipe the Tables Down",
		"bounty_market_watch": "Watch the Market Stalls",
		"bounty_barracks_checkin": "Check In at the Barracks",
		"bounty_charm_offensive": "A Friendly Word or Three",
		"bounty_bow_practice": "Archery Butt Practice",
		"bounty_guild_census": "Guild Headcount",
		"bounty_alley_cull": "Clear the Boulevard Alleys",
		"bounty_second_watch": "Settle Two More Quarrels",
		"bounty_pond_keepsakes": "Report the Pond Cache",
		"bounty_crab_cull": "Rock Crab Cull, East Hills",
		"bounty_standing_den_watch": "Standing Order: the Approach Den",
		"bounty_standing_lantern_line": "Standing Order: the Lantern-Line",
		"bounty_standing_road_order": "Standing Order: the Roads",
	}
	return String(titles.get(bounty_id, bounty_id.trim_prefix("bounty_").capitalize()))


## Short board-title per delivery slip id -- build_delivery_picker_graph's
## exact twin of _posting_title above, same rationale.
static func _delivery_title(delivery_id: String) -> String:
	var titles := {
		"delivery_krshia_wool": "Wool Bolt to Silverfang Stall",
		"delivery_pisces_parcel": "Ticking Parcel to the Necromancer",
		"delivery_gate_dispatch": "Dispatches to the Gate",
		"delivery_grate_phials": "Glass Phials to the Grate",
		"delivery_inn_hamper": "Fruit Hamper to the Inn",
		"delivery_barracks_gear": "Gambesons to the Barracks",
		"delivery_guild_ledger": "Sealed Ledger to the Guild Desk",
		"delivery_tactics_brief": "Tactics Brief to Olesm",
		"delivery_boulevard_letter": "Sealed Letter to the Boulevard",
		"delivery_riverfarm_seed": "Seed Grain to Riverfarm",
		"delivery_standing_dispatch_run": "The Morning Dispatch Run",
		"delivery_standing_inn_hamper": "The Inn's Standing Order",
		"delivery_standing_barracks_kit": "The Barracks Kit Rotation",
	}
	return String(titles.get(delivery_id, delivery_id.trim_prefix("delivery_").capitalize()))


## Selys's accept line (board-copy.md sec.2), road-cull steer as the ONE
## authored special case (a soft, specific nudge from the staging copy);
## every other bounty gets the generic accept line.
static func _accept_line(bounty_id: String) -> String:
	if bounty_id == "bounty_road_cull":
		return "Good pick, actually. The road's been bad and the Watch pays on time. Take the south path back. I didn't say that."
	return "That one? Fine. Logged. Don't die over a handful of gold. It's paperwork for me and embarrassing for you."


## Builds the "Take on a posting." conversation. WINDOWED-SCREENSHOT FINDING
## (this task): an early version put each bounty's full copy paragraph
## directly on an OPTION row -- `dialogue_panel.gd`'s option Labels have NO
## `autowrap_mode` set (only the paged BODY label does), so a paragraph-long
## option ran off the panel's right edge, unwrapped, stretching the speaker
## ribbon with it. Fixed by moving the full copy into the HUB NODE's own body
## text instead (numbered "1./2./3.", the SAME paginate-safe surface
## `_interact_board`'s browse view already uses) and keeping every OPTION a
## one-line "Take: <title>. (G gold)" label (a bare "Take posting N." numeral
## reads as unrecognizable at the option row -- a player picking blind by
## index, not by what the posting actually is; `_posting_title` supplies the
## name) + a final "Never mind.". CONSTRAINT: option Labels still have no
## autowrap, so every composed title must stay one line -- the longest
## current composition is ~50 chars, far under the paragraph case that
## caused the original bug, but unverified against the panel edge in a
## windowed read; re-measure windowed if a longer title is ever added.
## Selecting a posting accepts it via the `accept_bounty`
## dialogue effect and lands on a per-bounty confirmation node reading Selys's
## accept line (short, single-line, safe as an option/body either way).
static func build_picker_graph(slate: Array) -> Dictionary:
	var nodes: Dictionary = {}
	var options: Array = []
	var body_lines: Array[String] = ["Which one looks worth doing?", ""]
	for i: int in slate.size():
		var bounty: Dictionary = slate[i]
		var id := String(bounty["id"])
		var n := i + 1
		body_lines.append("%d. %s" % [n, String(bounty["copy"])])
		body_lines.append("")
		options.append({
			"text": "Take: %s. (%d gold)" % [_posting_title(id), int(bounty["gold"])],
			"effects": [{"accept_bounty": id}],
			"goto": "confirm_%s" % id,
		})
		nodes["confirm_%s" % id] = {
			"speaker": "Selys",
			"text": _accept_line(id),
			"options": [{"text": "Continue.", "end": true}],
		}
	options.append({"text": "Never mind.", "end": true})
	body_lines.remove_at(body_lines.size() - 1)
	nodes["hub"] = {"speaker": "Selys", "text": "\n".join(body_lines), "options": options}
	return {"start": "hub", "nodes": nodes}


## Builds the "Turn in my posting." result conversation. The RESOLUTION
## (condition check + gold payout + clearing the accepted slip) already
## happened in WIGame.turn_in_bounty() before this is called -- `met` just
## picks which of Selys's two board-copy.md lines to show (opaque-safe: the
## unmet line names no numbers, per the staging doc's own contract).
static func build_turnin_graph(met: bool) -> Dictionary:
	var text := "The notice says proof. Bring the proof, not the story. The story's free and so is my time apparently."
	if met:
		text = "Done? …So it is. Here. Counted twice, because the last adventurer counted once, loudly, and was wrong. The Guild thanks you. I'm the Guild. So: thanks."
	return {"start": "hub", "nodes": {"hub": {"speaker": "Selys", "text": text, "options": [{"text": "Continue.", "end": true}]}}}


## Builds the "Hand the posting back." result conversation (FIX WAVE, DP2
## review HIGH finding, second half). The RESOLUTION (clearing
## accepted_bounty_id/accepted_bounty_baseline, no gold, no accomplishment)
## already happened in WIGame.abandon_bounty() before this is called -- this
## just shows Selys's one line, same shape as build_turnin_graph's single
## fixed node (no condition to branch on, so no `met`-style parameter).
## Matches the "accept" surface's own home for its line (bounties.gd's
## _accept_line, shown inside a code-built graph) rather than the data
## graph -- the abandon HUB OPTION itself still lives in
## data/dialogue/selys_delivery.json (selys_delivery.json's "Take on a
## posting."/"Turn in my posting." precedent: the entry point is data, the
## deferred code-built graph is where Selys's reaction line lives).
static func build_abandon_graph() -> Dictionary:
	var text := "Hand it back? Fine. I'll cross it off: no pay, no mark against you. It goes back on the board for someone with follow-through."
	return {"start": "hub", "nodes": {"hub": {"speaker": "Selys", "text": text, "options": [{"text": "Continue.", "end": true}]}}}


## Vess's issue line for a just-accepted
## slip -- board-copy.md sec.3's three "Issue" variants, keyed the way the
## staged copy itself keys them: the cross-map run (the inn hamper) and the
## fragile run (the phials crate, `fragile: true` in data) each get their
## authored specific line; every other slip gets the standard one. The
## fragile check reads the DATA FLAG, not the id, so a future second
## fragile delivery inherits its line for free (v1 flavor-only, per the
## staging doc: the flag rides the data, the copy carries the stakes).
static func _delivery_issue_line(delivery: Dictionary) -> String:
	if String(delivery["id"]) == "delivery_inn_hamper":
		return "Gate, floodplains, the hill. Two legs and the road's got goblins, which is why it pays three. Runners move FAST. That's the whole trade. Fast things don't get grabbed."
	if bool(delivery.get("fragile", false)):
		return "That one's glass. GLASS. Walk like it's your grandmother's teeth. The crew counts the phials in front of you, so arrive with six."
	return "Signed, stamped, yours. That's a one-leg run, easy pace. Don't walk it TOO easy, the term's same-waking."


## Builds Vess's "Take a slip." conversation -- build_picker_graph's exact
## twin (and its hard-won layout lesson applies verbatim: full slip copy
## lives in the HUB NODE's paginated body, numbered; every OPTION stays a
## one-line "Take: <title>. (G gold)" label (`_delivery_title` names the
## slip, `_posting_title`'s twin). CONSTRAINT: dialogue_panel option Labels
## have no autowrap -- composed titles (~50 chars max today) are unverified
## against the panel edge in a windowed read; re-measure windowed if a
## longer title is ever added. Selecting a slip accepts it via the
## `accept_delivery` dialogue effect (which also grants the parcel item)
## and lands on a per-slip confirmation node reading Vess's issue line.
## Zero eligible slips (every delivery in the pool retired -- see
## WIGame.delivery_board_deliveries()'s own doc comment, item D fix) still
## returns a valid one-option graph: Vess's own flavor line, never the bare
## "Slips on the board right now." header with nothing under it (the
## pre-fix render for this state) -- same zero-eligible-item contract as
## WIShop.build_sell_graph's empty-sellables branch / WIPortals.
## build_portal_graph's "Let it be." fallback.
static func build_delivery_picker_graph(slate: Array) -> Dictionary:
	if slate.is_empty():
		return {"start": "hub", "nodes": {"hub": {"speaker": "Vess", "text": "Nothing needs running today. Board's clear -- every leg's paid out and closed. Come back when something new goes up.", "options": [{"text": "Fair enough.", "end": true}]}}}
	var nodes: Dictionary = {}
	var options: Array = []
	var body_lines: Array[String] = ["Slips on the board right now. Pick your leg:", ""]
	for i: int in slate.size():
		var delivery: Dictionary = slate[i]
		var id := String(delivery["id"])
		var n := i + 1
		body_lines.append("%d. %s" % [n, String(delivery["slip_copy"])])
		body_lines.append("")
		options.append({
			"text": "Take: %s. (%d gold)" % [_delivery_title(id), int(delivery["gold"])],
			"effects": [{"accept_delivery": id}],
			"goto": "confirm_%s" % id,
		})
		nodes["confirm_%s" % id] = {
			"speaker": "Vess",
			"text": _delivery_issue_line(delivery),
			"options": [{"text": "Continue.", "end": true}],
		}
	options.append({"text": "Never mind.", "end": true})
	body_lines.remove_at(body_lines.size() - 1)
	nodes["hub"] = {"speaker": "Vess", "text": "\n".join(body_lines), "options": options}
	return {"start": "hub", "nodes": nodes}


## Builds Vess's "Turn in a slip." result -- build_turnin_graph's exact
## twin. The RESOLUTION already happened in WIGame.turn_in_delivery();
## `met` picks between board-copy.md sec.3's two lines (mark confirmed vs.
## slip-says-the-mark refusal -- opaque-safe, no numbers either way).
static func build_delivery_turnin_graph(met: bool) -> Dictionary:
	var text := "Slip says the mark, not the counter. I can't pay you for carrying it AROUND, that's just… walking. Go on. Daylight's a budget."
	if met:
		text = "Mark confirmed. Hah — sorry, came in at a sprint myself. Coin's counted. Nice legs on that run. Hawk started on a board like this one, you know. Well. A board LIKE it."
	return {"start": "hub", "nodes": {"hub": {"speaker": "Vess", "text": text, "options": [{"text": "Continue.", "end": true}]}}}
