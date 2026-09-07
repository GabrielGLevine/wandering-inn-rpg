extends SceneTree

const TEST_DIR := "res://qa_output/title_recovery_unit"

class GameStub:
	const MANUAL_SLOTS: Array[String] = ["manual", "manual_2", "manual_3"]
	func _make_sim() -> WIGame:
		return WIGame.new(WISceneCatalog.compose(), {}, func(_type: String, _payload: Dictionary): pass, 9)

func _init() -> void:
	WITestWatchdog.arm(self)
	var raw := FileAccess.get_file_as_string("res://src/ui/title_screen.gd")
	var body := raw.get_slice("func _newest_save_slot()", 1).get_slice("\n\nfunc _refresh_continue_caption", 0)
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nvar Game: Variant\nvar _unreadable_save_found := false\nfunc _newest_save_slot()" + body.replace("user://saves", TEST_DIR)
	assert(script.reload() == OK)
	var selector: RefCounted = script.new()
	selector.set("Game", GameStub.new())
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	for slot: String in ["auto", "manual", "manual_2", "manual_3"]:
		DirAccess.remove_absolute("%s/%s.json" % [TEST_DIR, slot])
	var valid := FileAccess.get_file_as_string("res://qa/fixtures/post_tutorial.json")
	_write("manual", valid)
	# Equal mtimes deliberately prefer auto in production; a newer auto does too.
	_write("auto", "{interrupted-looking fixture, not evidence of interruption corruption")
	assert(selector.call("_newest_save_slot") == "manual", "malformed newest auto must not hide the valid manual save")
	assert(FileAccess.get_file_as_string(TEST_DIR + "/manual.json") == valid, "selection preserves valid bytes")
	assert(bool(selector.get("_unreadable_save_found")))
	_write("auto", '{"version":9,"state":{}}')
	assert(selector.call("_newest_save_slot") == "manual", "metadata-shaped but unloadable save is skipped")
	_write("auto", '{"version":1,"state":{}}')
	assert(selector.call("_newest_save_slot") == "manual", "unsupported save is skipped")
	DirAccess.remove_absolute(TEST_DIR + "/manual.json")
	assert(selector.call("_newest_save_slot") == "", "no readable slot disables Continue")
	_write("auto", valid)
	assert(selector.call("_newest_save_slot") == "auto")
	assert(not bool(selector.get("_unreadable_save_found")), "refresh clears stale recovery state")
	DirAccess.remove_absolute(TEST_DIR + "/auto.json")
	DirAccess.remove_absolute(TEST_DIR)
	print("PASS: Continue skips unreadable saves and preserves the latest readable slot")
	quit(0)

func _write(slot: String, content: String) -> void:
	var file := FileAccess.open("%s/%s.json" % [TEST_DIR, slot], FileAccess.WRITE)
	file.store_string(content)
	file.close()
