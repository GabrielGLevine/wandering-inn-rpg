class_name WIDialogue
extends RefCounted
## Pure conversation-graph walker. PURITY RULE: no autoload/Node/scene-tree
## references; context (skills/classes/accomplishments/display names) is
## injected, and chosen options' effects are RETURNED to the caller (WIGame)
## to apply -- this class never mutates game state. Constructor is silent;
## begin() starts emission (see WICombat.begin for the lesson behind this).

var finished := false
var current_id := ""

var _graph: Dictionary
var _ctx: Dictionary
var _event_sink: Callable

## [Bargain] price_mod (class-foundation pass R5, 2026-07-12): a shop price
## a [Bargain]-holding buyer pays/needs is cut by this fraction (~10%),
## floor-rounded (player-favorable). ONE constant, read from the ONE
## resolution site (_priced_gold) that the gate (_meets), the displayed
## price (current_options'/`_requirement_text`'s callers), and the actual
## gold deduction (choose()) all share -- gate/effect/display can never
## drift apart because there is only one number.
const BARGAIN_PRICE_MOD := 0.1


func _init(graph: Dictionary, ctx: Dictionary, event_sink: Callable) -> void:
	_graph = graph
	_ctx = ctx
	_event_sink = event_sink


func begin() -> void:
	_enter(String(_graph["start"]))


func current_options() -> Array:
	if finished:
		return []
	var out: Array = []
	for entry: Dictionary in _visible_options():
		var opt: Dictionary = entry["option"]
		var req: Dictionary = opt.get("requires", {})
		var locked := not _meets(req, opt)
		var row: Dictionary = {"text": _priced_text(opt, req), "locked": locked, "requirement": _requirement_text(req, opt) if locked else ""}
		# An option that grants an item (a shop buy, or Relc's
		# spear gift) carries the item's mechanical effect line(s) so the panel
		# answers "what am I buying/getting" in-place. GENERATED from the item
		# data via the shared WIEffectText formatter (never hand-composed), and
		# the "Worth N gold" value is dropped because a buy option already spells
		# the price in its text and a gift has no price to name -- only the
		# combat-relevant "what it does" lines belong on the option row. The key
		# is added ONLY for item-granting options, so a plain navigation option's
		# payload is byte-unchanged.
		var effect_lines := _item_effect_lines(opt)
		if not effect_lines.is_empty():
			row["effect_lines"] = effect_lines
		out.append(row)
	return out


## The generated, price-stripped effect line(s) for an option's granted item,
## or an empty array when the option grants no item (or the item is uncatalogued
## in the injected ctx). Pure: reads the ctx `items` catalog and the shared
## WIEffectText formatter only.
func _item_effect_lines(opt: Dictionary) -> Array:
	var items: Dictionary = _ctx.get("items", {})
	var out: Array = []
	for effect: Dictionary in opt.get("effects", []):
		if not effect.has("item"):
			continue
		var rec: Dictionary = items.get(String(effect["item"]), {})
		if rec.is_empty():
			continue
		for line: String in WIEffectText.item_effect_lines(rec):
			if not line.begins_with(WIEffectText.PRICE_LINE_PREFIX):
				out.append(line)
	return out


## Re-injects a fresh context snapshot. Called by the owner (WIGame) after
## applying a chosen option's effects so the NEXT node's gating sees them.
func set_ctx(ctx: Dictionary) -> void:
	_ctx = ctx


## Resolves the chosen visible option WITHOUT advancing: returns
## {effects, ended, next}. The owner applies effects, refreshes ctx
## (set_ctx), then calls advance(next) -- that ordering is the whole point.
func choose(index: int) -> Dictionary:
	if finished:
		return {}
	var visible: Array = _visible_options()
	if index < 0 or index >= visible.size():
		return {}
	var opt: Dictionary = visible[index]["option"]
	var req: Dictionary = opt.get("requires", {})
	if not _meets(req, opt):
		return {}
	var effects: Array = (opt.get("effects", []) as Array).duplicate(true)
	# [Bargain] price_mod (class-foundation pass R5, 2026-07-12): the
	# ACTUAL gold deduction is price-mod'd the SAME way the gate/display
	# already were (req.gold -> _priced_gold) -- ONE resolution site, so
	# a purchase can never charge the un-discounted amount after passing
	# a discounted gate. Only touches an effect matching the EXISTING
	# authoring convention (requires{gold:N} + effects{gold:-N}, test_
	# content.gd-validated) -- a plain payout option (positive gold, no
	# matching negative effect) is never touched.
	if req.has("gold"):
		var discounted := _priced_gold(int(req["gold"]), opt)
		for effect: Dictionary in effects:
			if effect.has("gold") and int(effect["gold"]) == -int(req["gold"]):
				effect["gold"] = -discounted
	var ended := bool(opt.get("end", false))
	if ended:
		finished = true
		_emit(WIEvents.DIALOGUE_ENDED, {})
	return {"effects": effects, "ended": ended, "next": "" if ended else String(opt["goto"])}


## Enters the node a choose() result pointed at. No-op once finished.
func advance(next_id: String) -> void:
	if finished or next_id.is_empty():
		return
	_enter(next_id)


## True when this requires-dict gates on player PROGRESS (accomplishments), OR
## on the `board_accepted` ctx flag (whether a bounty posting is
## currently accepted), OR on DP5's `delivery_accepted` twin (whether a
## Runner's Guild slip is currently held), OR on Issue #23's `once_per_waking`
## twin (whether the "<verb>:<entity>" key is already banked in
## `entity_first_use` this waking) -- all "vanishing" gates (HIDDEN until met,
## not greyed), unlike skill/class/gold which stay visible-locked as a
## deliberate tease. `board_accepted`/`delivery_accepted` read the SAME
## hide-until-met contract: Selys's board pair and Vess's slip pair must not
## clutter their hubs with an unusable choice before/after a job is on hand.
## `once_per_waking` follows suit: Erin's meal option (and Relc's wager
## option) must not clutter their hubs with an already-spent-this-waking
## choice -- it comes BACK, silently, once sleep() clears entity_first_use,
## exactly like a fresh talk_pool line.
## REQUIRES-ONLY: `once_per_waking`
## is deliberately NOT a hide_when gate -- its "met" polarity ("not yet used
## this waking") is the INVERSE of every shipped hide_when key's ("the
## tracked state is now true"), so a hide_when carrying it would hide while
## UNUSED and reveal once USED, the exact opposite of the retire idiom an
## author would expect. Retire-style hide_when semantics are deferred until
## a real consumer defines the intended contract (deliberate, not
## forgotten); `_meets_hide_when` below refuses the key at runtime and
## test_content.gd rejects it at content-validation time.
func _progress_gated(req: Dictionary) -> bool:
	return req.has("accomplishment") or req.has("board_accepted") or req.has("delivery_accepted") or req.has("once_per_waking")


## Progress-only gate check used SOLELY to decide hide-until-met VISIBILITY
## (a requires dict may combine an accomplishment
## stage-gate with a gold affordability gate in one option -- e.g. Krshia's
## discount buy options, requires{accomplishment:{...}, gold:N}. The
## accomplishment leg ALONE controls whether the option is hidden or shown;
## a met stage-gate with insufficient gold must show GREYED/locked, never
## vanish -- window-shopping is content. _meets() below is the
## full compound AND used for the actual locked/choosable decision.)
func _meets_progress(req: Dictionary) -> bool:
	# The board_accepted leg is checked FIRST and independently --
	# a requires/hide_when dict combining it with accomplishment never ships in
	# authored content (each of Selys's two new hub options uses exactly one
	# gate type), but ANDing here rather than branching keeps the contract
	# honest if that ever changes.
	if req.has("board_accepted"):
		if bool(_ctx.get("board_accepted", false)) != bool(req["board_accepted"]):
			return false
	# delivery_accepted, board_accepted's exact twin.
	if req.has("delivery_accepted"):
		if bool(_ctx.get("delivery_accepted", false)) != bool(req["delivery_accepted"]):
			return false
	# once_per_waking's own leg, checked independently like the
	# two above -- met iff `entity_first_use` does NOT yet carry the
	# "<verb>:<entity>" key this waking (Erin's meal / Relc's wager both
	# combine this with an accomplishment stage-gate; each leg is ANDed).
	if req.has("once_per_waking"):
		if (_ctx.get("entity_first_use", {}) as Dictionary).has(String(req["once_per_waking"])):
			return false
	if not req.has("accomplishment"):
		return true
	for id: String in req["accomplishment"]:
		if int((_ctx["accomplishments"] as Dictionary).get(id, 0)) < int(req["accomplishment"][id]):
			return false
	return true


## Returns the authored options for the current node filtered down to the
## visible ones, as {authored_index, option} pairs. This is the single source
## of truth for the visible->authored index mapping: current_options() and
## choose() both build/consume this list so the index a player sees always
## lines up with the option choose() resolves.
func _visible_options() -> Array:
	var out: Array = []
	var options: Array = _node().get("options", [])
	for authored_index: int in options.size():
		var opt: Dictionary = options[authored_index]
		var hide_when: Dictionary = opt.get("hide_when", {})
		if not hide_when.is_empty() and _meets_hide_when(hide_when):
			continue
		var req: Dictionary = opt.get("requires", {})
		if _progress_gated(req) and not _meets_progress(req):
			continue
		out.append({"authored_index": authored_index, "option": opt})
	return out


## The hide_when-side gate check.
## `once_per_waking` is a REQUIRES-ONLY gate (see _progress_gated's doc
## comment for the polarity-inversion rationale); a hide_when carrying it is
## malformed content that test_content.gd's validator rejects at content
## time, and this runtime guard makes sure it can never SILENTLY half-work
## if it slips through anyway: the key is refused loudly (push_error) and
## ignored entirely, failing OPEN (the option stays visible unless the
## REMAINING recognized keys hide it) -- never the inverted hide a naive
## shared-_meets evaluation would produce. Fail-open matches _meets's own
## treatment of an unrecognized-keys-only dict (recognized == false -> not
## met -> visible): a malformed gate must never hide content.
func _meets_hide_when(hide_when: Dictionary) -> bool:
	if not hide_when.has("once_per_waking"):
		return _meets(hide_when)
	push_error("WIDialogue: hide_when must not carry once_per_waking (requires-only gate, Issue #23) -- key ignored: %s" % str(hide_when))
	var cleaned := hide_when.duplicate()
	cleaned.erase("once_per_waking")
	return not cleaned.is_empty() and _meets(cleaned)


## GH#98-followup (found live during the R1-R5 sweep, class-foundation pass):
## [Bargain] must only touch genuine PURCHASE options -- ones that actually
## spend gold via a matching `effects{gold: -requires.gold}` pair (the same
## shape test_content.gd's validator checks). A `requires.gold` gate can also
## exist WITHOUT a purchase (Olesm's chess wager: `requires.gold` is a pure
## solvency check -- "you must be able to cover a hypothetical loss" -- with
## no `effects` at all; the actual gold only ever moves on the win node).
## Un-scoped, `_priced_gold`/`_priced_text` discounted/decorated that wager
## too, appending a spurious "(2 gold)" onto "Set the board, Olesm." for
## EVERY player (not just [Bargain] holders -- the append was unconditional
## on the option's OWN text, not on holding the skill), breaking the
## authored copy. `opt` defaults to `{}` for callers with no option context
## (hide_when/text_variant `_meets` checks) -- an empty opt never matches a
## purchase, so those paths stay fully unaffected (raw, undiscounted gold).
func _is_priced_purchase(opt: Dictionary, base: int) -> bool:
	for effect: Dictionary in opt.get("effects", []):
		if effect.has("gold") and int(effect["gold"]) == -base:
			return true
	return false


## [Bargain] price_mod's one resolution function (class-foundation pass R5;
## haggle-carrier polarity INVERTED by controller ruling, review wave
## 2026-07-12). `base` is the AUTHORED price (a `requires.gold` value, never
## touched at rest in data). Haggling is OPT-IN: the discount only ever
## applies on a node that carries `haggle: true` (the vendor visibly
## entertains it) -- the DEFAULT for every node in the game is NO discount,
## so new civic/shop content can never silently discount by omission
## (docs/design/city-identity-bible.md's posted-prices register is the
## default posture, haggling the authored exception). v1 carriers: Eloise's
## shop node only (riverfarm_witch.json) -- Krshia's own line says "no
## discounts, no haggling" (honored everywhere including her charms node,
## now by default), Pallass civic fees never haggle, and #92's vendor wave
## expands the carrier list. A buyer whose known skills include "bargain"
## pays `floor(base * (1 - BARGAIN_PRICE_MOD))` on a haggle node; every
## OTHER caller (no skill, a default node, or a non-purchase gold gate with
## no matching spend effect) reads `base` back unchanged.
func _priced_gold(base: int, opt: Dictionary = {}) -> int:
	if not _is_priced_purchase(opt, base):
		return base
	if not bool(_node().get("haggle", false)):
		return base
	if not (_ctx.get(WIKeys.SKILLS, []) as Array).has("bargain"):
		return base
	return int(floor(float(base) * (1.0 - BARGAIN_PRICE_MOD)))


## The DISPLAYED option text, price-mod-aware (class-foundation pass R5;
## display-rewrite fix, review wave 2026-07-12). THE BINDING RULE: the
## rendered price and the charged price are the SAME number, always --
## both come from `_priced_gold`, the one resolution site. Two authoring
## shapes exist: (a) a baked-in price in the authored `text` ("The yarrow
## bundle. (4 gold)") -- when a discount applies, the baked "(4 gold)"
## substring is REWRITTEN in-place to the discounted figure (the original
## early-return-on-"gold)" shape showed the authored price while gate/
## charge used the discounted one, a real display!=charge lie the review
## caught live: yarrow displayed 4g and charged 3g); when NO discount
## applies (no [Bargain], a default non-haggle node, or a non-purchase
## gate) the text is returned byte-identical, so every pre-existing pin
## outside a haggle node still holds. test_content.gd validates that a
## baked price always spells exactly "(requires.gold gold)", so the
## rewrite's substring match cannot silently miss. (b) NO baked number --
## the discounted-or-base price is APPENDED live, same source. The locked-
## case suffix agrees for free: dialogue_panel.gd's `_requirement_suffix`
## dedups against `_requirement_text`'s "costs N gold", and both N's are
## `_priced_gold`'s -- the "(4 gold) (costs 3 gold)" contradiction is
## structurally impossible once display and gate share the one function.
func _priced_text(opt: Dictionary, req: Dictionary) -> String:
	var text := String(opt["text"])
	if not req.has("gold"):
		return text
	var base := int(req["gold"])
	if not _is_priced_purchase(opt, base):
		return text
	var priced := _priced_gold(base, opt)
	if text.contains("gold)"):
		if priced == base:
			return text
		return text.replace("(%d gold)" % base, "(%d gold)" % priced)
	return "%s (%d gold)" % [text, priced]


func _node() -> Dictionary:
	return (_graph["nodes"] as Dictionary)[current_id]


func _enter(id: String) -> void:
	current_id = id
	var n := _node()
	var visible_options := current_options()
	_emit(WIEvents.DIALOGUE_NODE, {"speaker": String(n["speaker"]), "text": _resolved_text(n), "options": visible_options})
	# SOFTLOCK GUARD: a node with authored options that are ALL hidden by
	# hide_when leaves the player at a dead end with nothing to click -- there
	# is no way to advance or exit. This is malformed content (content
	# validation in test_content.gd is meant to make it unreachable: every
	# hub must retain at least one always-available option), but if it ever
	# slips through, fail safe by ending the dialogue instead of soft-locking
	# the player in a conversation with no choices.
	if visible_options.is_empty() and not (n.get("options", []) as Array).is_empty():
		finished = true
		_emit(WIEvents.DIALOGUE_ENDED, {})


func _resolved_text(node: Dictionary) -> String:
	var text := String(node["text"])
	for variant: Dictionary in node.get("text_variants", []):
		if _meets(variant.get("requires", {})):
			text = String(variant["text"])
	return text


## Generalized from a first-match-wins chain (each key
## checked in isolation, only one recognized per call) to a full COMPOUND AND
## across every recognized key present -- needed for Krshia's discount buy
## options, whose requires combines an accomplishment stage-gate with a gold
## affordability check (requires{accomplishment:{...}, gold:N}). Every key
## already worked exactly this way in isolation, so single-key requires
## dicts (100% of pre-existing content) are BYTE-IDENTICAL in behavior; only
## a NEW multi-key dict changes meaning (now AND, where before only the
## first-checked key's branch ever ran). `recognized` preserves the old
## fallback: a requires dict carrying none of the four known keys still
## refuses (same as the old trailing `return false`).
func _meets(req: Dictionary, opt: Dictionary = {}) -> bool:
	if req.is_empty():
		return true
	var recognized := false
	if req.has("skill"):
		recognized = true
		if not (_ctx[WIKeys.SKILLS] as Array).has(String(req["skill"])):
			return false
	if req.has("class"):
		recognized = true
		for id: String in req["class"]:
			if int((_ctx["classes"] as Dictionary).get(id, 0)) < int(req["class"][id]):
				return false
	if req.has("gold"):
		# Numeric affordability gate (a shop buy option's
		# `requires: {gold: price}`). The ONE sanctioned extension of the M4
		# greying ctx (it was skill/class/accomplishment-only). Reads the `gold`
		# key WIGame._build_dialogue_ctx now supplies (tolerant default 0). Gold
		# is NOT progress-gated on its own (see _progress_gated -- no
		# `accomplishment` key), so an unaffordable buy stays VISIBLE-locked/
		# greyed, never hidden: window-shopping is content (spec §3).
		recognized = true
		if int(_ctx.get("gold", 0)) < _priced_gold(int(req["gold"]), opt):
			return false
	if req.has("accomplishment"):
		recognized = true
		for id: String in req["accomplishment"]:
			if int((_ctx["accomplishments"] as Dictionary).get(id, 0)) < int(req["accomplishment"][id]):
				return false
	if req.has("board_accepted"):
		# The THIRD sanctioned non-accomplishment gate type (after
		# gold) -- a plain bool ctx flag (WIGame._build_dialogue_ctx's
		# `board_accepted`, true iff a bounty posting is currently accepted).
		# Equality, not >=/<= (this is a state flag, not a threshold).
		recognized = true
		if bool(_ctx.get("board_accepted", false)) != bool(req["board_accepted"]):
			return false
	if req.has("delivery_accepted"):
		# The FOURTH sanctioned gate type -- board_accepted's
		# exact twin for the Runner's Guild slip (WIGame._build_dialogue_ctx's
		# `delivery_accepted`, true iff a delivery slip is currently held).
		recognized = true
		if bool(_ctx.get("delivery_accepted", false)) != bool(req["delivery_accepted"]):
			return false
	if req.has("once_per_waking"):
		# The FIFTH sanctioned non-accomplishment gate type --
		# board_accepted/delivery_accepted's twin, checked against the shared
		# `entity_first_use` per-waking dedup dict (WIGame ctx) the SAME way
		# _meets_progress checks it above; recognized here too so a full
		# choose()/current_options() lock/unlock decision (not just
		# hide-until-met visibility) sees this key. REQUIRES-ONLY: the
		# hide_when path never reaches this arm (_meets_hide_when refuses the
		# key before delegating here -- see _progress_gated's doc comment).
		recognized = true
		if (_ctx.get("entity_first_use", {}) as Dictionary).has(String(req["once_per_waking"])):
			return false
	if req.has("item"):
		# The SIXTH sanctioned gate type -- possession, not
		# progress. Checks the ctx's `inventory` (the player's actually-HELD
		# item ids; NOT the `items` key above, which is the read-only item
		# CATALOG used only for effect-line text -- a catalog-membership
		# check would be meaningless, every item id is always "in" the
		# catalog). Mirrors `gold`'s precedent, not `accomplishment`'s: NOT
		# in _progress_gated below, so an option gated on an unheld item
		# stays VISIBLE-LOCKED (greyed, names what's missing), never
		# vanishes -- "you need to bring X" is a visible tease, same as an
		# unaffordable price.
		recognized = true
		if not (_ctx.get("inventory", []) as Array).has(String(req["item"])):
			return false
	if req.has("race"):
		# The SEVENTH sanctioned gate type -- read-only COSMETIC
		# state (pc_race, set once at char-creation, additive save field
		# already shipped), not progress. 8e Phase C (issue #16), the ONE
		# sanctioned sim addition for the Pallass milestone. Powers
		# text_variants ONLY in shipped content today (a node's greeting
		# reading differently for a Human vs a Drake PC, the
		# "friction / assumed-local" register the city-identity bible
		# calls for) -- _resolved_text already routes every text_variants
		# entry through this same _meets, so no separate mechanism was
		# needed. Deliberately NOT added to _progress_gated: a race-gated
		# OPTION (unshipped today) stays VISIBLE-LOCKED like skill/class,
		# never hidden -- there is no "progress" a player can make toward
		# a different race, so hiding would read as a content bug, not a
		# tease. `talk_pool` entries do NOT read this key -- WISocial's
		# pool rotation is a separate mechanism from this walker's
		# _meets, and extending it would touch social.gd + wi_game.gd's
		# ctx-threading beyond this function (outside the sanctioned
		# "~5 lines" scope); every shipped race-variant line rides
		# text_variants instead.
		recognized = true
		if String(_ctx.get("pc_race", "")) != String(req["race"]):
			return false
	if req.has("phase"):
		# The EIGHTH sanctioned gate type -- read-only DERIVED
		# state (WIGame.phase(), the same day/dusk/night clock
		# encounter_when/visual_states already gate on), not progress. Issue
		# #80 (world reactivity wave). Value shape mirrors
		# encounter_when/visual_states' own `{"phase": [<phase strings>]}`
		# array-membership convention (a variant author can gate on "dusk or
		# night" in one entry), NOT race's single-string equality -- one
		# shape for the phase family across the whole codebase. Deliberately
		# NOT added to _progress_gated: a phase-gated OPTION stays
		# VISIBLE-LOCKED like skill/class/race, never hidden -- there is no
		# "progress" toward a later hour, so hiding would read as a content
		# bug, not a tease. Shipped only on text_variants today (majors'
		# dusk/night line pass); an OPTION gated on phase would work
		# identically through this same arm if content ever needs one.
		recognized = true
		if not (req["phase"] as Array).has(String(_ctx.get("phase", ""))):
			return false
	return recognized


func _requirement_text(req: Dictionary, opt: Dictionary = {}) -> String:
	var names: Dictionary = _ctx.get("names", {})
	if req.has("skill"):
		return "requires %s" % String(names.get(String(req["skill"]), String(req["skill"])))
	if req.has("class"):
		for id: String in req["class"]:
			return "requires %s %d" % [String(names.get(id, id)), int(req["class"][id])]
	if req.has("gold"):
		return "costs %d gold" % _priced_gold(int(req["gold"]), opt)
	if req.has("item"):
		var items: Dictionary = _ctx.get("items", {})
		return "requires %s" % String(items.get(String(req["item"]), {}).get("name", String(req["item"])))
	if req.has("race"):
		return "requires being %s" % String(req["race"])
	if req.has("phase"):
		return "requires the right time of day"
	return "requires more progress"


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
