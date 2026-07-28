class_name WIAddress
extends RefCounted

## How a shipped line addresses the PC, resolved at EMIT so one authored
## sentence serves both genders: `{addr}` -> "sir"/"miss", `{Addr}` -> the
## sentence-head capital. AUTHORING RULE: PC-DIRECTED address only -- an
## NPC naming another NPC ("Mister Farley", "Master Coyle") stays literal.
## Unknown/absent gender falls back to the "m" term, matching
## WIGame._sanitize_pc_gender's own default. Braces, not percent-signs:
## test_content's opacity tripwire bans `%` from every player string.

const TOKEN := "{addr}"
const TOKEN_CAP := "{Addr}"
const TERMS := {"m": "sir", "f": "miss"}


static func term(gender: String) -> String:
	return String(TERMS.get(gender, TERMS["m"]))


static func has_token(text: String) -> bool:
	return text.contains(TOKEN) or text.contains(TOKEN_CAP)


static func resolve(text: String, gender: String) -> String:
	if not has_token(text):
		return text
	var word := term(gender)
	return text.replace(TOKEN, word).replace(TOKEN_CAP, word.capitalize())


## The ONE seam: WIGame routes every emitted payload through this, so a token
## resolves wherever it is authored (node text, text_variants, talk_pool line,
## static entity `dialogue`, toast, and a dialogue option row). TRAP: a payload
## is frequently the shipped catalog's OWN dict (interactions.gd hands
## `target["dialogue"][0]` straight through), so copy on a hit and never write
## in place -- in-place would bake one gender into loaded data for the process.
static func resolve_payload(payload: Dictionary, gender: String) -> Dictionary:
	var text_raw := String(payload.get("text", ""))
	var options: Variant = payload.get("options", null)
	var rows: Array = options if options is Array else []
	var hit := has_token(text_raw)
	if not hit:
		for row: Variant in rows:
			if row is Dictionary and has_token(String((row as Dictionary).get("text", ""))):
				hit = true
				break
	if not hit:
		return payload
	var out: Dictionary = payload.duplicate()
	if payload.has("text"):
		out["text"] = resolve(text_raw, gender)
	if rows.is_empty():
		return out
	var fixed: Array = []
	for row: Variant in rows:
		if not (row is Dictionary):
			fixed.append(row)
			continue
		var copy: Dictionary = (row as Dictionary).duplicate()
		copy["text"] = resolve(String(copy.get("text", "")), gender)
		fixed.append(copy)
	out["options"] = fixed
	return out
