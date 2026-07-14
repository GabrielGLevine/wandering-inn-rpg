extends SceneTree

const SLEEP_VEIL_PATH := "res://src/ui/sleep_veil.gd"


func _init() -> void:
	WITestWatchdog.arm(self)
	var src := FileAccess.get_file_as_string(SLEEP_VEIL_PATH)
	assert(not src.is_empty(), "sleep_veil.gd must exist")

	_check_guard_flag_lifecycle(src)
	_check_run_sequence_branches(src)
	_check_input_gate_widened(src)

	print("PASS: sleep_veil.gd's plain-sleep skip + consolidation guard are wired")
	quit(0)


func _check_guard_flag_lifecycle(src: String) -> void:
	assert(src.find("var _sleep_has_consolidation") != -1, "sleep_veil.gd must declare _sleep_has_consolidation")

	var begin_sleep_body := src.get_slice("func _begin_sleep() -> void:", 1).get_slice("func play_opener", 0)
	assert(begin_sleep_body.find("_sleep_has_consolidation = false") != -1, "_begin_sleep() must reset _sleep_has_consolidation false for every fresh sleep")

	var offered_body := src.get_slice("WIEvents.CONSOLIDATION_OFFERED:", 1).get_slice("WIEvents.ACCOMPLISHMENT_RECORDED:", 0)
	assert(offered_body.find("_sleep_has_consolidation = true") != -1, "the CONSOLIDATION_OFFERED handler must arm _sleep_has_consolidation")


func _check_run_sequence_branches(src: String) -> void:
	var run_sequence_body := src.get_slice("func _run_sequence() -> void:", 1).get_slice("func _add_line(", 0)
	assert(run_sequence_body.find("var skippable := not _sleep_has_consolidation") != -1, "_run_sequence must derive skippable from _sleep_has_consolidation")

	var loop_body := run_sequence_body.get_slice("for line: String in lines:", 1).get_slice("_emit_rendered(lines.size())", 0)
	assert(loop_body.find("if skippable:") != -1, "the per-line loop must branch on skippable")
	assert(loop_body.find("await _wait_or_advance(LINE_INTERVAL)") != -1, "the skippable branch must use _wait_or_advance for the per-line hold")
	assert(loop_body.find("await _wait(LINE_INTERVAL)") != -1, "the non-skippable (consolidation-guarded) branch must fall back to plain _wait for the per-line hold")

	var final_hold_body := run_sequence_body.get_slice("_emit_rendered(lines.size())", 2).get_slice("await _fade(_black, 0.0)", 0)
	assert(final_hold_body.find("await _wait_or_advance(final_hold)") != -1, "the skippable branch must use _wait_or_advance for the final read hold")
	assert(final_hold_body.find("await _wait(final_hold)") != -1, "the non-skippable (consolidation-guarded) branch must fall back to plain _wait for the final read hold")


func _check_input_gate_widened(src: String) -> void:
	var input_body := src.get_slice("func _unhandled_input(event: InputEvent) -> void:", 1).get_slice("func _emit_opener_rendered", 0)
	assert(input_body.find("if not (_running or _opener_running or _epilogue_running or _defeat_running):") != -1, "_unhandled_input's modal-advance gate must include _running")

	var modal_active_body := src.get_slice("func modal_active() -> bool:", 1).get_slice("func _unhandled_input", 0)
	assert(modal_active_body.find("return _running or _opener_running or _epilogue_running or _defeat_running") != -1, "modal_active() must include _running")
