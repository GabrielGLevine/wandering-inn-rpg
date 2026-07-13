extends SceneTree
## Issue #87 (gap-2, plain-sleep skip): a TRACE + PIN for sleep_veil.gd's
## consolidation guard. `_run_sequence`'s real-play reveal is human-
## playtest-gated -- it collapses to an instant coverage emit under
## `_is_qa()` (the same "FEEL is human-playtest-gated" contract every other
## veil timing carries, see that file's own header doc), so no headless QA
## script can ever exercise the REAL paced/skippable branch's timing. This
## is therefore a RAW-SOURCE structural proof (test_settings.gd's own
## `_check_reduce_motion_gate_sites` idiom) that the wiring the doc comment
## claims is actually the wiring in the file: a sleep that offered a
## consolidation stays on the plain, unskippable `_wait()` for its WHOLE
## reveal, never the skippable `_wait_or_advance()` seam every other plain
## sleep now rides.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sleep_veil.gd

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


## `_sleep_has_consolidation` is declared, reset every `_begin_sleep()` (so it
## can never leak a TRUE from a prior sleep into a later, offer-less one),
## and armed by the CONSOLIDATION_OFFERED handler.
func _check_guard_flag_lifecycle(src: String) -> void:
	assert(src.find("var _sleep_has_consolidation") != -1, "sleep_veil.gd must declare _sleep_has_consolidation")

	var begin_sleep_body := src.get_slice("func _begin_sleep() -> void:", 1).get_slice("func play_opener", 0)
	assert(begin_sleep_body.find("_sleep_has_consolidation = false") != -1, "_begin_sleep() must reset _sleep_has_consolidation false for every fresh sleep")

	var offered_body := src.get_slice("WIEvents.CONSOLIDATION_OFFERED:", 1).get_slice("WIEvents.ACCOMPLISHMENT_RECORDED:", 0)
	assert(offered_body.find("_sleep_has_consolidation = true") != -1, "the CONSOLIDATION_OFFERED handler must arm _sleep_has_consolidation")


## `_run_sequence`'s real-play branch: `skippable` derives from the guard
## flag, the per-line hold AND the final read-hold each branch on it --
## `_wait_or_advance` when skippable, plain `_wait` (no early cut) when a
## consolidation was offered this sleep. Sliced narrowly (between the
## `_is_qa()` early-return and `_add_line`) so this can never accidentally
## match some OTHER mode's own _wait/_wait_or_advance calls (opener/epilogue/
## defeat each have their own, textually elsewhere in the file).
func _check_run_sequence_branches(src: String) -> void:
	var run_sequence_body := src.get_slice("func _run_sequence() -> void:", 1).get_slice("func _add_line(", 0)
	assert(run_sequence_body.find("var skippable := not _sleep_has_consolidation") != -1, "_run_sequence must derive skippable from _sleep_has_consolidation")

	var loop_body := run_sequence_body.get_slice("for line: String in lines:", 1).get_slice("_emit_rendered(lines.size())", 0)
	assert(loop_body.find("if skippable:") != -1, "the per-line loop must branch on skippable")
	assert(loop_body.find("await _wait_or_advance(LINE_INTERVAL)") != -1, "the skippable branch must use _wait_or_advance for the per-line hold")
	assert(loop_body.find("await _wait(LINE_INTERVAL)") != -1, "the non-skippable (consolidation-guarded) branch must fall back to plain _wait for the per-line hold")

	# "_emit_rendered(lines.size())" appears TWICE in run_sequence_body (once
	# in the _is_qa() early-return, once for real after the loop) -- slice
	# index 2 is the segment AFTER the SECOND (real) occurrence.
	var final_hold_body := run_sequence_body.get_slice("_emit_rendered(lines.size())", 2).get_slice("await _fade(_black, 0.0)", 0)
	assert(final_hold_body.find("await _wait_or_advance(final_hold)") != -1, "the skippable branch must use _wait_or_advance for the final read hold")
	assert(final_hold_body.find("await _wait(final_hold)") != -1, "the non-skippable (consolidation-guarded) branch must fall back to plain _wait for the final read hold")


## `_unhandled_input`'s modal-advance gate and `modal_active()` both widened
## to include `_running` (the plain-sleep flag) alongside the pre-existing
## opener/epilogue/defeat trio -- otherwise a confirm/cancel press during a
## plain sleep would leak through to world.gd underneath instead of
## advancing (or, for a guarded sleep, being safely swallowed).
func _check_input_gate_widened(src: String) -> void:
	var input_body := src.get_slice("func _unhandled_input(event: InputEvent) -> void:", 1).get_slice("func _emit_opener_rendered", 0)
	assert(input_body.find("if not (_running or _opener_running or _epilogue_running or _defeat_running):") != -1, "_unhandled_input's modal-advance gate must include _running")

	var modal_active_body := src.get_slice("func modal_active() -> bool:", 1).get_slice("func _unhandled_input", 0)
	assert(modal_active_body.find("return _running or _opener_running or _epilogue_running or _defeat_running") != -1, "modal_active() must include _running")
