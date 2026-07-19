class_name WIFence
extends RefCounted

## b2 #218: Ratici's rotating fence — pure static derivation + code-built
## graph (the WIBounties board-picker / WIPortals precedent; no WIGame state).
## Stock rotates on times_slept via WIBounties.active_slate (2/waking, zero
## rng). Prices ride `requires {gold}` so _priced_text auto-appends the
## "(N gold)" token — never bake a second number into the copy (#217 LOW).
## Buy options hide_when the item is already held: pickup() no-ops held
## duplicates, so a visible re-buy would charge gold for nothing.

const SPEAKER := "Ratici"
const HUB_TEXT := "Go on an' look, then. Things fall off carts, sir. These fell careful."
const SLOTS_PER_WAKING := 2


static func active_stock(pool: Array, times_slept: int) -> Array:
	var slate := WIBounties.active_slate(pool, times_slept)
	return slate.slice(0, SLOTS_PER_WAKING)


static func build_fence_graph(slate: Array) -> Dictionary:
	var options: Array = []
	for rec: Dictionary in slate:
		options.append({
			"text": String(rec["patter"]),
			"requires": {"gold": int(rec["price"])},
			"hide_when": {"item": String(rec["item"])},
			"effects": [{"gold": -int(rec["price"])}, {"item": String(rec["item"])}],
			"end": true,
		})
	options.append({"text": "Another day, then.", "end": true})
	return {"start": "hub", "nodes": {"hub": {"speaker": SPEAKER, "text": HUB_TEXT, "options": options}}}
