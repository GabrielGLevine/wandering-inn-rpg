extends SceneTree
## Old-site save hand-off: the pure decode/plan/settings layer under hostile
## input, and real v0.20.0 web saves (tests/fixtures/v0_20_0_web, read out of
## a v0.20.0 web build's IndexedDB) loading through WISave.apply. The prompt,
## slot writes and ledger are the save_transfer_prompt canonical's job.

const SAVE := '{"version":9,"state":{}}'


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _new_game() -> WIGame:
	var config := {"dialogue": {}}
	for key: String in ["combatants", "classes", "arenas", "quests", "acts", "leads", "items", "bounties", "deliveries", "portals", "progression"]:
		config[key] = _load_json("res://data/%s.json" % key)
	config["fence"] = _load_json("res://data/fence_stock.json")
	WISceneCatalog.reset()
	return WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), func(_t: String, _p: Dictionary) -> void: pass, 1, config)


func _b64(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


func _plain(json_text: String) -> String:
	return "wi1.p." + _b64(json_text.to_utf8_buffer())


func _refused(payload: String, reason: String, label: String) -> void:
	var out := WISaveTransfer.decode(payload)
	assert(not out.ok and out.reason == reason and out.slots.is_empty(), "%s must refuse as %s, got %s" % [label, reason, out])


func _init() -> void:
	WITestWatchdog.arm(self)
	# Round trip, both codecs, byte-exact slot text and non-ASCII names.
	var text := '{"version":9,"state":{"pc_name":"Érin ✦"}}'
	for gzip: bool in [true, false]:
		var out := WISaveTransfer.decode(WISaveTransfer.encode({"manual": {"text": text, "t": 1700000000}, "auto": {"text": SAVE, "t": 5}}, "[audio]\nMaster=3.0\n", gzip))
		assert(out.ok and out.slots.manual.text == text and out.slots.manual.t == 1700000000 and out.slots.auto.text == SAVE, "round trip gzip=%s: %s" % [gzip, out])
		assert(out.settings == "[audio]\nMaster=3.0\n", "settings text carried")

	# Hostile / corrupt payloads: quiet refusal, never a partial result.
	_refused("", "format", "empty")
	_refused("!", "format", "oversize sentinel from the page script")
	_refused("wi2.p.e30", "format", "unknown envelope version")
	_refused("wi1.z.e30", "format", "unknown codec")
	_refused("wi1.p.e30.x", "format", "extra segment")
	_refused("wi1.p.ab$d", "base64", "malformed base64 (bad character)")
	_refused("wi1.p.abcde", "base64", "malformed base64 (impossible length)")
	_refused("wi1.p.e30=", "base64", "padding is not part of the alphabet")
	_refused("wi1.g." + _b64("not gzip at all, just text".to_utf8_buffer()), "compression", "bad compression (no gzip header)")
	var gz := '{"v":1,"slots":{}}'.repeat(40).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	var flipped := gz.duplicate()
	flipped[14] = flipped[14] ^ 0xff
	_refused("wi1.g." + _b64(flipped), "compression", "bad compression (corrupt stream)")
	_refused("wi1.g." + _b64(gz.slice(0, gz.size() - 5)), "compression", "bad compression (truncated)")
	var bomb := "a".repeat(WISaveTransfer.MAX_DECODED_BYTES + 1).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	_refused("wi1.g." + _b64(bomb), "compression", "oversized after decompression (zip bomb)")
	_refused("wi1.p." + "A".repeat(WISaveTransfer.MAX_PAYLOAD_CHARS), "too_large", "oversized payload")
	_refused("wi1.p." + _b64(PackedByteArray([0x7b, 0xff, 0xfe, 0x7d])), "encoding", "invalid UTF-8")
	_refused("wi1.p." + _b64(PackedByteArray([0x7b, 0x00, 0x7d])), "encoding", "NUL byte")
	_refused(_plain("[1,2,3]"), "json", "wrong top-level type")
	_refused(_plain("{not json"), "json", "not JSON")
	_refused(_plain("[".repeat(3000)), "json", "deeply nested JSON")
	_refused(_plain('{"v":2,"slots":{"manual":{"t":1,"d":"x"}}}'), "schema", "wrong schema version")
	_refused(_plain('{"v":1,"slots":{}}'), "schema", "no slots")
	_refused(_plain('{"v":1,"slots":{"manual":{"t":1,"d":"x"}},"extra":1}'), "schema", "unknown top-level key")
	_refused(_plain('{"v":1,"slots":{"manual":{"t":1,"d":"x","path":"y"}}}'), "schema", "unknown slot field")
	_refused(_plain('{"v":1,"slots":{"manual":{"t":1,"d":{"version":9}}}}'), "schema", "slot text is not a string")
	_refused(_plain('{"v":1,"slots":{"manual":{"t":"now","d":"x"}}}'), "schema", "timestamp is not a number")
	_refused(_plain('{"v":1,"slots":{"manual":{"t":1,"d":"x"}},"settings":{"a":1}}'), "schema", "settings is not a string")
	_refused(_plain('{"v":1,"slots":{"quicksave":{"t":1,"d":"x"}}}'), "slot_name", "unknown slot name")
	for name: String in ["../settings", "..\\\\x", "/etc/passwd", "manual/../../x", "manual.json", "Manual", "manual ", ""]:
		_refused(_plain(JSON.stringify({"v": 1, "slots": {name: {"t": 1, "d": "x"}}})), "slot_name", "path-traversal slot name %s" % name)

	# The allowlist IS the game's slot set (Game.MANUAL_SLOTS + the autosave writers).
	var game_source := FileAccess.get_file_as_string("res://src/core/game.gd")
	var names := {}
	var slot_re := RegEx.create_from_string('_(?:write|rotate)_slot\\("([a-z_0-9]+)"(?:, "([a-z_0-9]+)")?')
	for m: RegExMatch in slot_re.search_all(game_source):
		for g in [1, 2]:
			if not m.get_string(g).is_empty():
				names[m.get_string(g)] = true
	var manual_re := RegEx.create_from_string('MANUAL_SLOTS: Array\\[String\\] = \\[([^\\]]+)\\]')
	for part: String in manual_re.search(game_source).get_string(1).split(","):
		names[part.strip_edges().trim_prefix('"').trim_suffix('"')] = true
	var expected := names.keys()
	expected.sort()
	var allowed := WISaveTransfer.SLOTS.duplicate()
	allowed.sort()
	assert(Array(allowed) == expected, "slot allowlist %s must equal the game's slots %s" % [allowed, expected])
	assert(WISaveTransfer.SLOT_LABELS.size() == WISaveTransfer.SLOTS.size(), "every slot has a player-facing label")

	# Merge plan: never a write into an occupied slot without a conflict row.
	var incoming := {"manual": {"text": "A", "t": 1}, "manual_2": {"text": "B", "t": 2}, "auto": {"text": "C", "t": 3}, "manual_3": {"text": "D", "t": 4}, "auto_prev": {"text": "E", "t": 5}}
	var rows := WISaveTransfer.plan(incoming, {"manual": "A", "auto": "mine"}, ["D".sha256_text()], {"manual_2": true, "auto": true, "auto_prev": false})
	var status := {}
	for row: Dictionary in rows:
		status[row.slot] = row.status
	assert(status == {"auto": "conflict", "auto_prev": "unreadable", "manual": "same", "manual_2": "new", "manual_3": "seen"}, "plan statuses: %s" % [status])
	var occupied_unreadable := WISaveTransfer.plan({"auto": {"text": "bad", "t": 1}}, {"auto": "mine"}, [], {"auto": false})
	assert(occupied_unreadable[0].status == "unreadable", "an unreadable save is never offered against an existing one")

	# Settings: allowlisted scalars only, clamped; hostile lines are ignored.
	var cfg := "[audio]\nMaster=3.5\nMusic=99\nSFX=nan\nEvil=Object(Node,\"script\":null)\n[accessibility]\ntext_scale_step=2\nreduce_motion=true\n[combat]\ndifficulty_step=7\nspeed_step=abc\n[chronicle]\nlatest={\"classes\": [Object(Node)]}\n[input]\nmove_up=Object(InputEventKey)\n"
	var parsed := WISaveTransfer.parse_settings(cfg)
	assert(parsed == {"audio/Master": 3.5, "audio/Music": 10.0, "accessibility/text_scale_step": 2, "accessibility/reduce_motion": true, "combat/difficulty_step": 7}, "settings allowlist: %s" % [parsed])
	assert(WISaveTransfer.parse_settings("x".repeat(WISaveTransfer.MAX_SETTINGS_CHARS + 1)).is_empty(), "oversized settings ignored")
	assert(WISaveTransfer.display_text("Erin\n\tDROP  TABLE  ", 8) == "ErinDROP", "prompt text is one bounded printable line")

	# Real v0.20.0 web saves (version 9, no stored vitals) load on this build
	# with their state intact and derived HP/MP inside (0, max].
	for slot: String in ["auto", "auto_pre_combat"]:
		var raw := FileAccess.get_file_as_string("res://tests/fixtures/v0_20_0_web/%s.json" % slot)
		var decoded := WISaveTransfer.decode(WISaveTransfer.encode({slot: {"text": raw, "t": 1}}))
		assert(decoded.ok and decoded.slots[slot].text == raw, "v0.20.0 %s survives the payload byte-for-byte" % slot)
		var data := _load_json("res://tests/fixtures/v0_20_0_web/%s.json" % slot)
		assert(int(data.version) == 9 and not data.state.has("vitals"), "fixture is a real v0.20.0 (version 9) save")
		var game := _new_game()
		assert(WISave.apply(game, data), "v0.20.0 %s loads through WISave.apply" % slot)
		var s: Dictionary = data.state
		assert(game.current_map == String(s.current_map) and game.player_cell == Vector2i(int(s.player_cell[0]), int(s.player_cell[1])), "%s position intact" % slot)
		assert(game.player_facing == Vector2i(int(s.player_facing[0]), int(s.player_facing[1])), "%s facing intact" % slot)
		assert(game.gold == int(s.gold) and Array(game.inventory) == (s.inventory as Array), "%s gold and inventory intact" % slot)
		assert(game.equipped == s.equipped, "%s equipment intact: %s" % [slot, game.equipped])
		assert(Array(game.started_quests) == (s.started_quests as Array), "%s quests intact" % slot)
		for id: String in s.accomplishments:
			assert(game.accomplishment_count(id) >= int(s.accomplishments[id]), "%s flag %s intact" % [slot, id])
		for id: String in s.classes:
			assert(int(game.classes.get(id, 0)) == int(s.classes[id]), "%s class %s intact" % [slot, id])
		assert(Array(game.player_skills) == (s.player_skills as Array) and game.times_slept == int(s.times_slept), "%s skills and sleeps intact" % slot)
		var maxima: Dictionary = game.player_resource_maxima()
		assert(game.vitals.hp > 0 and game.vitals.hp <= int(maxima[WIKeys.MAX_HP]), "%s HP sane: %d of %s" % [slot, game.vitals.hp, maxima])
		assert(game.vitals.mp >= 0 and game.vitals.mp <= int(maxima[WIKeys.MAX_MP]) and (int(maxima[WIKeys.MAX_MP]) == 0 or game.vitals.mp > 0), "%s MP sane: %d of %s" % [slot, game.vitals.mp, maxima])
		var again := _new_game()
		assert(WISave.apply(again, JSON.parse_string(JSON.stringify(WISave.serialize(game)))), "%s re-saves as a loadable current-version save" % slot)

	# A save from a FUTURE version, and one that fails apply, are not loadable.
	var future := _load_json("res://tests/fixtures/v0_20_0_web/auto.json")
	future.version = WISave.VERSION + 1
	assert(not WISave.apply(_new_game(), future), "future-version save is rejected")
	var broken := _load_json("res://tests/fixtures/v0_20_0_web/auto.json")
	broken.state.current_map = "no_such_map"
	assert(not WISave.apply(_new_game(), broken), "save naming an unknown map is rejected")

	# The published old-site page carries the sentinel the Pages workflow requires.
	var page := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../web/pages-redirect/index.html"))
	assert(page.contains("<!-- wi-save-migration-page v1 -->"), "web/pages-redirect/index.html carries the migration-page sentinel")
	var limit := RegEx.create_from_string("MAX_URL_CHARS = (\\d+);").search(page)
	assert(limit != null and limit.get_string(1).to_int() <= WISaveTransfer.MAX_PAYLOAD_CHARS, "the page never sends more than the game accepts")
	for slot: String in WISaveTransfer.SLOTS:
		assert(page.contains('"%s"' % slot), "page reads slot %s" % slot)
	print("test_save_transfer: PASS")
	quit()
