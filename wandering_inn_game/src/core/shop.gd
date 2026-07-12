class_name WIShop
extends RefCounted
## Krshia's buyback picker: pure derivation + code-built conversation graph,
## riding the WIBounties/WIPortals idiom (static-only, no instance -- this
## class owns no WIGame state to mutate, same rationale as WIPortals' own
## doc comment). PURITY RULE: no autoload/Node/scene-tree references --
## build_sell_graph takes plain {id, name, price} records (already resolved
## by WIGame.sellable_items()/sell_price()/sell_item() -- the worth math,
## the equipped/unsellable/unpriced filtering, and the actual gold+removal
## resolution ALL already happened, or happen via the `sell_item` effect
## verb the option applies) and returns a plain WIDialogue-shaped graph.
##
## Deliberately its OWN sibling file rather than folded into bounties.gd:
## that file's own doc comment scopes it to "THE REQUEST BOARD"'s two
## concerns (bounty rotation math + bounty-specific graphs) -- grafting an
## unrelated Krshia-sell builder in would widen that scope for no shared
## benefit. WIPortals is the closer precedent instead (a single
## prop/NPC-adjacent code-built picker, one static graph-builder function,
## no injected-Callable constructor, no rotation math of its own).

const SPEAKER := "Krshia"
## Krshia-flavored empty-sellables line (RATIFIED copy) -- the hub option
## itself carries no requires/hide_when (always visible, window-shopping is
## content, same idiom as her "What's on the stall today?" nav), so a
## player with nothing sellable still gets a real reaction, never a bare
## "Never mind." with nothing to explain it.
const EMPTY_TEXT := "Nothing in your pack I'd give coin for. Yet."
const HUB_TEXT := "Let me see what you're carrying."
## Krshia's sell reaction (Silverfang trader register -- she "remembers
## debts", per her own krshia_fair_weight talk_pool_stages line in
## skeleton_scene.json: "I remember this the way I remember debts. Better,
## even."). ONE shared reaction node regardless of which item sold -- unlike
## WIBounties' per-posting confirm nodes (Selys's road-cull steer is the
## one bounty with a distinct accept line), nothing about a sale's flavor
## varies by item, so a second authored line would be pure duplication.
const SOLD_TEXT := "Half its worth, paid straight — I don't forget a fair trade any more than an unfair one. Sold."
const NEVER_MIND := "Never mind."


## Builds the sell conversation from the CURRENT sellable inventory.
## `records` is already-priced, already-filtered [{id, name, price}] in
## inventory order (WIGame.sellable_items() excludes anything unpriced,
## `unsellable`-flagged, or currently equipped -- nothing here re-checks any
## of that). Every option reads "Sell: <name>. (+N gold)" -- the POSTED
## price, matching the board/delivery pickers' own "(N gold)" idiom
## (bounties.gd's build_picker_graph/build_delivery_picker_graph) -- and
## applies a `{"sell_item": id}` effect on a goto (not end) into the ONE
## shared "sold" node. Zero sellable items still returns a valid one-option
## graph (Krshia's own flavor line) -- the same zero-eligible-item contract
## as WIPortals.build_portal_graph's "Let it be." fallback, never a bare
## empty options array (WIDialogue's own softlock guard would otherwise end
## the conversation outright with nothing shown).
static func build_sell_graph(records: Array) -> Dictionary:
	if records.is_empty():
		return {"start": "hub", "nodes": {"hub": {"speaker": SPEAKER, "text": EMPTY_TEXT, "options": [{"text": "Fair enough.", "end": true}]}}}
	var options: Array = []
	for rec: Dictionary in records:
		options.append({
			"text": "Sell: %s. (+%d gold)" % [String(rec["name"]), int(rec["price"])],
			"effects": [{"sell_item": String(rec["id"])}],
			"goto": "sold",
		})
	options.append({"text": NEVER_MIND, "end": true})
	return {
		"start": "hub",
		"nodes": {
			"hub": {"speaker": SPEAKER, "text": HUB_TEXT, "options": options},
			"sold": {"speaker": SPEAKER, "text": SOLD_TEXT, "options": [{"text": "Continue.", "end": true}]},
		},
	}
