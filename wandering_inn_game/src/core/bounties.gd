class_name WIBounties
extends RefCounted


static func active_slate(pool: Array, times_slept: int) -> Array:
	if pool.is_empty():
		return []
	var size := mini(3, pool.size())
	var start := times_slept % pool.size()
	var out: Array = []
	for i: int in size:
		out.append(pool[(start + i) % pool.size()])
	return out


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


## Issue #163: rank-scaled postings. Base record IS bronze; `tiers.silver/.gold`
## optionally override condition/gold/copy/condition_mode. Returns a copy with
## the highest DEFINED tier not exceeding `rank` applied (monotonic fallback: a
## gold player on a silver-only posting still gets silver), stamped with the
## resolved "rank". `tiers` is dropped from the result so downstream never
## re-resolves. Pure -- the caller passes the player's rank (never read here).
const RANK_ORDER := ["bronze", "silver", "gold"]

static func resolve_tier(bounty: Dictionary, rank: String) -> Dictionary:
	var out: Dictionary = bounty.duplicate(true)
	out.erase("tiers")
	out["rank"] = "bronze"
	var tiers: Dictionary = bounty.get("tiers", {})
	var rank_idx := RANK_ORDER.find(rank)
	if rank_idx < 0:
		rank_idx = 0
	var chosen := ""
	for i: int in range(1, rank_idx + 1):
		if tiers.has(RANK_ORDER[i]):
			chosen = RANK_ORDER[i]
	if chosen == "":
		return out
	var override: Dictionary = tiers[chosen]
	out["rank"] = chosen
	for key: String in ["condition", "gold", "copy", "condition_mode"]:
		if override.has(key):
			out[key] = override[key]
	return out


static func requires_met(bounty: Dictionary, accomplishment_count_cb: Callable) -> bool:
	# Filter requires before active_slate: locked rows do not affect old windows,
	# then join and re-wrap rotation once unlocked.
	var requires: Dictionary = bounty.get("requires", {})
	for key: String in requires:
		if int(accomplishment_count_cb.call(key)) < int(requires[key]):
			return false
	return true


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


static func _accept_line(bounty_id: String) -> String:
	if bounty_id == "bounty_road_cull":
		return "Good pick, actually. The road's been bad and the Watch pays on time. Take the south path back. I didn't say that."
	return "That one? Fine. Logged. Don't die over a handful of gold. It's paperwork for me and embarrassing for you."


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


## b4 #219 review fix: a desk only settles its OWN paper. Private
## (board:false) rows belong to Grimalkin's desk; guild rows to Selys's.
## `giver` is display prose corpus-wide, so the machine key is the board
## flag itself. A mismatched desk must not consume the held posting.
static func turnin_is_foreign(row: Dictionary, voice: String) -> bool:
	var private := not bool(row.get("board", true))
	return (voice == "grimalkin") != private


static func build_turnin_graph(met: bool, voice: String = "selys", foreign: bool = false) -> Dictionary:
	# b4 #219: optional voice key; the default is byte-identical Selys for
	# every existing caller. "grimalkin" covers his private study contracts —
	# his not-done copy is deliberately honest for FOREIGN postings too
	# ("I did not assign you that errand"), so his foreign arm reuses it;
	# Selys gets her own foreign line (a met foreign posting must never
	# render her paid-out copy — review catch, met-foreign case).
	if voice == "grimalkin":
		var g_text := "Incomplete measurements are noise. I did not assign you that errand, or you have not finished mine. Either way: come back with data."
		if met and not foreign:
			g_text = "Adequate. The numbers hold, which puts you above most of my subjects. Payment as contracted — precision costs, and I pay for it."
		return {"start": "hub", "nodes": {"hub": {"speaker": "Grimalkin", "text": g_text, "options": [{"text": "Continue.", "end": true}]}}}
	if foreign:
		var f_text := "That's not Guild paper. Whoever wrote that contract pays for it — take it back to them. My ledger stays clean."
		return {"start": "hub", "nodes": {"hub": {"speaker": "Selys", "text": f_text, "options": [{"text": "Continue.", "end": true}]}}}
	var text := "The notice says proof. Bring the proof, not the story. The story's free and so is my time apparently."
	if met:
		text = "Done? …So it is. Here. Counted twice, because the last adventurer counted once, loudly, and was wrong. The Guild thanks you. I'm the Guild. So: thanks."
	return {"start": "hub", "nodes": {"hub": {"speaker": "Selys", "text": text, "options": [{"text": "Continue.", "end": true}]}}}


static func build_abandon_graph(private: bool = false) -> Dictionary:
	var text := "Hand it back? Fine. I'll cross it off: no pay, no mark against you. It goes back on the board for someone with follow-through."
	if private:
		# b4 #219 review fix: "goes back on the board" is fiction-false for
		# a board:false contract — it was never on her board.
		text = "Hand it back? Fine. That one never touched my board; private paper. Dropped. If the Magus minds, that's between you and him."
	return {"start": "hub", "nodes": {"hub": {"speaker": "Selys", "text": text, "options": [{"text": "Continue.", "end": true}]}}}


static func _delivery_issue_line(delivery: Dictionary) -> String:
	if String(delivery["id"]) == "delivery_inn_hamper":
		return "Gate, floodplains, the hill. Two legs and the road's got goblins, which is why it pays three. Runners move FAST. That's the whole trade. Fast things don't get grabbed."
	if bool(delivery.get("fragile", false)):
		return "That one's glass. GLASS. Walk like it's your grandmother's teeth. The crew counts the phials in front of you, so arrive with six."
	return "Signed, stamped, yours. That's a one-leg run, easy pace. Don't walk it TOO easy, the term's same-waking."


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


static func build_delivery_turnin_graph(met: bool) -> Dictionary:
	var text := "Slip says the mark, not the counter. I can't pay you for carrying it AROUND, that's just… walking. Go on. Daylight's a budget."
	if met:
		text = "Mark confirmed. Hah — sorry, came in at a sprint myself. Coin's counted. Nice legs on that run. Hawk started on a board like this one, you know. Well. A board LIKE it."
	return {"start": "hub", "nodes": {"hub": {"speaker": "Vess", "text": text, "options": [{"text": "Continue.", "end": true}]}}}
