class_name WIShop
extends RefCounted

const VOICES := {
	"krshia": {
		"speaker": "Krshia",
		"empty_text": "Nothing in your pack I'd give coin for. Yet.",
		"hub_text": "Let me see what you're carrying.",
		"sold_text": "Half its worth, paid straight — I don't forget a fair trade any more than an unfair one. Sold.",
	},
	"eloise": {
		"speaker": "Eloise",
		"empty_text": "Nothing there I'd give you coin for. Keep it, or don't -- not my business.",
		"hub_text": "Let's see what you're carrying, then. Coin's coin.",
		"sold_text": "Paid. Simpler than a favor, and I don't have to remember what I'm owed.",
	},
	"pallass_stallkeeper": {
		"speaker": "Market-Tier Local",
		"empty_text": "Nothing there's worth my stall space. Posted prices only, same as buying.",
		"hub_text": "Posted rate, same as everything else on this tier. Let's see it.",
		"sold_text": "Posted rate, paid. Next.",
	},
}
const NEVER_MIND := "Never mind."


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
