extends SceneTree
## Headless test for WIEventLog and QAPaths (pure classes, no autoloads).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_event_log.gd


func _init() -> void:
	WITestWatchdog.arm(self)
	# QAPaths.parse_args
	var args := QAPaths.parse_args(PackedStringArray(["--qa-script=res://qa/x.json", "--seed=42", "loose"]))
	assert(args["qa-script"] == "res://qa/x.json", "parses --key=value")
	assert(args["seed"] == "42", "parses numeric value as string")
	assert(not args.has("loose"), "ignores args without --key= form")

	# WIEventLog round-trip
	var path := OS.get_user_data_dir().path_join("test_qa/events.jsonl")
	var log := WIEventLog.new(path)
	log.append("toast", {"text": "hello"})
	log.append("skill_used", {"skill": "basic_cleaning"})
	log.close()

	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	assert(lines.size() == 2, "two JSONL lines written")
	var first: Variant = JSON.parse_string(lines[0])
	assert(first is Dictionary, "line 0 is valid JSON")
	assert(first["type"] == "toast", "type field round-trips")
	assert(first["payload"]["text"] == "hello", "payload round-trips")
	assert(first.has("t"), "timestamp present")

	print("PASS: event log and QA paths behave correctly")
	quit(0)
