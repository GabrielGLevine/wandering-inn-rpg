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
##
## GENERALIZED (class-foundation pass R5, 2026-07-12): this used to be
## Krshia-only -- SPEAKER/EMPTY_TEXT/HUB_TEXT/SOLD_TEXT were bare class
## consts, and WIGame._open_sell_dialogue always built the SAME
## "krshia_sell"/"krshia" conversation id/speaker-entity regardless of who
## opened it. Rather than a second graph-builder for Eloise/the Pallass
## stallkeeper (the DP2 twin-arm lesson -- one mechanism, no twins), the
## consts became a small keyed VOICES table and build_sell_graph now takes
## a `vendor_id` selecting which voice to render. Every existing caller
## (Krshia) is byte-identical (same strings, just read through the "krshia"
## key instead of bare consts).

## Per-vendor sell-picker voice bundle (RATIFIED copy per vendor). A vendor
## id absent here falls back to "krshia" (the original, always-shipped
## voice) rather than crashing on a KeyError -- defensive, since every real
## caller passes a catalogued id, but this keeps a hand-built test graph
## from needing one.
const VOICES := {
	"krshia": {
		"speaker": "Krshia",
		"empty_text": "Nothing in your pack I'd give coin for. Yet.",
		"hub_text": "Let me see what you're carrying.",
		"sold_text": "Half its worth, paid straight — I don't forget a fair trade any more than an unfair one. Sold.",
	},
	## Eloise's own register (riverfarm_witch.json's shipped voice: blunt,
	## transactional, "not everyone wants to owe me something bigger").
	"eloise": {
		"speaker": "Eloise",
		"empty_text": "Nothing there I'd give you coin for. Keep it, or don't -- not my business.",
		"hub_text": "Let's see what you're carrying, then. Coin's coin.",
		"sold_text": "Paid. Simpler than a favor, and I don't have to remember what I'm owed.",
	},
	## The Pallass market stallkeeper (pallass_market_local.json's
	## "Market-Tier Local", ORIGINAL/unnamed -- the posted-prices register,
	## docs/design/city-identity-bible.md: prices are POSTED, no haggling).
	"pallass_stallkeeper": {
		"speaker": "Market-Tier Local",
		"empty_text": "Nothing there's worth my stall space. Posted prices only, same as buying.",
		"hub_text": "Posted rate, same as everything else on this tier. Let's see it.",
		"sold_text": "Posted rate, paid. Next.",
	},
}
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
## graph (the vendor's own flavor line) -- the same zero-eligible-item
## contract as WIPortals.build_portal_graph's "Let it be." fallback, never a
## bare empty options array (WIDialogue's own softlock guard would otherwise
## end the conversation outright with nothing shown).
static func build_sell_graph(records: Array, vendor_id: String = "krshia") -> Dictionary:
	var voice: Dictionary = VOICES.get(vendor_id, VOICES["krshia"])
	var speaker := String(voice["speaker"])
	if records.is_empty():
		return {"start": "hub", "nodes": {"hub": {"speaker": speaker, "text": String(voice["empty_text"]), "options": [{"text": "Fair enough.", "end": true}]}}}
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
			"hub": {"speaker": speaker, "text": String(voice["hub_text"]), "options": options},
			"sold": {"speaker": speaker, "text": String(voice["sold_text"]), "options": [{"text": "Continue.", "end": true}]},
		},
	}
