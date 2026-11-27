class_name WISaveTransfer
extends RefCounted
## Cross-origin save hand-off (old Pages site -> new site). The payload comes
## from a URL fragment, so every byte is ATTACKER-CONTROLLED: anyone can craft
## a link. Everything here is pure, bounded and quiet -- no engine decoder
## that prints on bad input (base64, zlib, UTF-8, ConfigFile) ever sees it.
##
## Payload: `wi1.<g|p>.<base64url>` -- gzip or plain UTF-8 JSON
## `{"v":1,"slots":{"<slot>":{"t":<unix seconds>,"d":"<save file text>"}},"settings":"<cfg text>"}`.

const PREFIX := "wi1"
const MAX_PAYLOAD_CHARS := 64000
const MAX_DECODED_BYTES := 512 * 1024
const MAX_SLOT_CHARS := 200 * 1024
const MAX_SETTINGS_CHARS := 16 * 1024
## The game's real slot names; test_save_transfer pins this against Game.
const SLOTS: Array[String] = ["auto", "auto_prev", "auto_pre_combat", "manual", "manual_2", "manual_3"]
const SLOT_LABELS := {
	"auto": "Autosave", "auto_prev": "Earlier autosave", "auto_pre_combat": "Before last fight",
	"manual": "Save 1", "manual_2": "Save 2", "manual_3": "Save 3",
}
const _B64 := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
## settings.cfg keys that may cross, as section/key -> kind. Everything else
## (key bindings, chronicle, hint state) stays behind: those are ConfigFile
## Variants, and ConfigFile builds arbitrary Objects from hostile text.
const SETTINGS_KEYS := {
	"audio/Master": "volume", "audio/Music": "volume", "audio/SFX": "volume", "audio/UI": "volume", "audio/Voice": "volume", "audio/Ambience": "volume",
	"accessibility/text_scale_step": "int", "accessibility/reduce_motion": "bool",
	"combat/speed_step": "int", "combat/difficulty_step": "int",
	"field_hud/show_quest_thread": "bool", "journal/quest_hints": "bool",
}


## `{ok, reason, slots: {slot: {text, t}}, settings: String}`. `reason` is a
## QA/diagnostic code, never shown to the player.
static func decode(payload: String) -> Dictionary:
	if payload.length() > MAX_PAYLOAD_CHARS:
		return _refuse("too_large")
	var parts := payload.split(".")
	if parts.size() != 3 or parts[0] != PREFIX or not (parts[1] in ["g", "p"]) or parts[2].is_empty():
		return _refuse("format")
	var raw := _base64url(parts[2])
	if raw.is_empty():
		return _refuse("base64")
	if parts[1] == "g":
		var unzipped := WIInflate.gunzip(raw, MAX_DECODED_BYTES)
		if not unzipped.ok:
			return _refuse("compression")
		raw = unzipped.data
	if raw.size() > MAX_DECODED_BYTES or not _valid_utf8(raw):
		return _refuse("encoding")
	var parser := JSON.new()
	if parser.parse(raw.get_string_from_utf8()) != OK or not (parser.data is Dictionary):
		return _refuse("json")
	return _validated(parser.data)


static func _validated(data: Dictionary) -> Dictionary:
	for key: Variant in data:
		if not (key in ["v", "slots", "settings"]):
			return _refuse("schema")
	if not (data.get("v") is float or data.get("v") is int) or float(data["v"]) != 1.0 or not (data.get("slots") is Dictionary):
		return _refuse("schema")
	var settings: Variant = data.get("settings", "")
	if not (settings is String) or (settings as String).length() > MAX_SETTINGS_CHARS:
		return _refuse("schema")
	var raw_slots: Dictionary = data["slots"]
	if raw_slots.is_empty() or raw_slots.size() > SLOTS.size():
		return _refuse("schema")
	var slots := {}
	for name: Variant in raw_slots:
		# Allowlist by exact match: a slot name never reaches a path otherwise.
		if not (name is String) or not SLOTS.has(name):
			return _refuse("slot_name")
		var row: Variant = raw_slots[name]
		if not (row is Dictionary) or (row as Dictionary).size() != 2:
			return _refuse("schema")
		var text: Variant = (row as Dictionary).get("d")
		var stamp: Variant = (row as Dictionary).get("t")
		if not (text is String) or (text as String).is_empty() or (text as String).length() > MAX_SLOT_CHARS:
			return _refuse("schema")
		if not (stamp is float or stamp is int) or not is_finite(float(stamp)) or float(stamp) < 0.0 or float(stamp) > 4.0e9:
			return _refuse("schema")
		slots[name] = {"text": text, "t": int(stamp)}
	return {"ok": true, "reason": "", "slots": slots, "settings": settings}


static func _refuse(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "slots": {}, "settings": ""}


## Inverse of decode, for tests and QA seeding (the shipped encoder is the
## JavaScript in web/pages-redirect/index.html).
static func encode(slots: Dictionary, settings: String = "", gzip: bool = true) -> String:
	var body := {"v": 1, "slots": {}}
	for name: String in slots:
		body["slots"][name] = {"t": int(slots[name].get("t", 0)), "d": String(slots[name]["text"])}
	if not settings.is_empty():
		body["settings"] = settings
	var bytes := JSON.stringify(body).to_utf8_buffer()
	if gzip:
		bytes = bytes.compress(FileAccess.COMPRESSION_GZIP)
	return "%s.%s.%s" % [PREFIX, "g" if gzip else "p", Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")]


static func _base64url(text: String) -> PackedByteArray:
	var out := PackedByteArray()
	if text.length() % 4 == 1:
		return out
	var lookup := {}
	for i in _B64.length():
		lookup[_B64.unicode_at(i)] = i
	var buffer := 0
	var bits := 0
	for i in text.length():
		var value: int = lookup.get(text.unicode_at(i), -1)
		if value < 0:
			return PackedByteArray()
		buffer = ((buffer << 6) | value) & 0xffffff
		bits += 6
		if bits >= 8:
			bits -= 8
			out.append((buffer >> bits) & 0xff)
	return out


## Strict UTF-8 (no NUL, overlongs, surrogates or >U+10FFFF), because
## get_string_from_utf8 prints an engine error on anything else.
static func _valid_utf8(bytes: PackedByteArray) -> bool:
	var i := 0
	var n := bytes.size()
	while i < n:
		var b := bytes[i]
		var extra := 0
		var low := 0x80
		var high := 0xbf
		if b == 0:
			return false
		elif b < 0x80:
			i += 1
			continue
		elif b >= 0xc2 and b <= 0xdf:
			extra = 1
		elif b >= 0xe0 and b <= 0xef:
			extra = 2
			if b == 0xe0:
				low = 0xa0
			elif b == 0xed:
				high = 0x9f
		elif b >= 0xf0 and b <= 0xf4:
			extra = 3
			if b == 0xf0:
				low = 0x90
			elif b == 0xf4:
				high = 0x8f
		else:
			return false
		if i + extra >= n:
			return false
		for k in range(1, extra + 1):
			var c := bytes[i + k]
			if c < (low if k == 1 else 0x80) or c > (high if k == 1 else 0xbf):
				return false
		i += extra + 1
	return true


## What importing would do to each incoming slot, without touching anything.
## `existing` is slot -> current file text; `seen` holds hashes already settled.
## Status: same (identical bytes already there), seen (settled on an earlier
## visit), unreadable (failed the trial load), new (slot is empty), conflict.
static func plan(incoming: Dictionary, existing: Dictionary, seen: Array, readable: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for slot: String in SLOTS:
		if not incoming.has(slot):
			continue
		var text := String(incoming[slot]["text"])
		var sha := text.sha256_text()
		var status := "new"
		if existing.has(slot) and String(existing[slot]) == text:
			status = "same"
		elif seen.has(sha):
			status = "seen"
		elif not bool(readable.get(slot, false)):
			status = "unreadable"
		elif existing.has(slot):
			status = "conflict"
		rows.append({"slot": slot, "status": status, "sha": sha, "t": int(incoming[slot]["t"])})
	return rows


## Allowlisted scalar settings out of settings.cfg text, as "section/key" ->
## bool/int/float. Never ConfigFile: see SETTINGS_KEYS.
static func parse_settings(text: String) -> Dictionary:
	var out := {}
	if text.length() > MAX_SETTINGS_CHARS:
		return out
	var section := ""
	for raw_line: String in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2)
			continue
		var eq := line.find("=")
		if eq <= 0:
			continue
		var kind := String(SETTINGS_KEYS.get("%s/%s" % [section, line.substr(0, eq)], ""))
		var value := line.substr(eq + 1)
		if kind == "bool" and value in ["true", "false"]:
			out["%s/%s" % [section, line.substr(0, eq)]] = value == "true"
		elif kind == "int" and value.is_valid_int() and value.length() <= 3:
			out["%s/%s" % [section, line.substr(0, eq)]] = value.to_int()
		elif kind == "volume" and value.is_valid_float() and value.length() <= 8 and is_finite(value.to_float()):
			out["%s/%s" % [section, line.substr(0, eq)]] = clampf(value.to_float(), 0.0, 10.0)
	return out


## One printable line for a prompt: attacker text never brings its own layout.
static func display_text(raw: String, limit: int = 24) -> String:
	var out := ""
	for i in raw.length():
		var code := raw.unicode_at(i)
		if code >= 0x20 and code != 0x7f and not (code >= 0x80 and code < 0xa0) and code != 0x2028 and code != 0x2029:
			out += raw[i]
	out = out.strip_edges()
	return out.substr(0, limit) if out.length() > limit else out
