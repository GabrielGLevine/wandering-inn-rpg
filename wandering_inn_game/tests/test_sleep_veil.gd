extends SceneTree

const SLEEP_VEIL_PATH := "res://src/ui/sleep_veil.gd"


func _init() -> void:
	WITestWatchdog.arm(self)
	var src := FileAccess.get_file_as_string(SLEEP_VEIL_PATH)
	assert(not src.is_empty(), "sleep_veil.gd must exist")

	_check_trigger_is_the_slept_flag(src)
	_check_guard_flag_lifecycle(src)
	_check_run_sequence_branches(src)
	_check_input_gate_widened(src)
	_check_finale_retired_the_epilogue(src)
	_check_finale_is_owed_not_armed(src)
	_check_finale_line_tables(src)
	_check_finale_act_presences(src)

	print("PASS: sleep_veil.gd's plain-sleep skip, consolidation guard, and seal_resolved finale are wired")
	quit(0)


## THE DRIFT TRIPWIRE for #359's cost. `_tick_action` emits
## phase_changed{phase:"day"} at every cycle wrap, so keying the veil on the
## phase VALUE raises a mid-field blackout on the 1800th un-slept action and
## spends the one-shot finale there. test_sim_core pins the EMIT side (sleep()
## carries `slept`, a wrap does not); this pins the READ side, which no
## behavioural test can reach without a live veil.
func _check_trigger_is_the_slept_flag(src: String) -> void:
	var phase_arm := src.get_slice("WIEvents.PHASE_CHANGED:", 1).get_slice("WIEvents.CLASS_GAINED:", 0)
	# Comments in this arm NAME the trap ("a cycle wrap emits phase \"day\"..."),
	# so the value check has to run on code lines only or it trips on its own
	# documentation.
	var code := ""
	for line: String in phase_arm.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code += line + "\n"
	assert(code.find("payload.get(\"slept\"") != -1,
		"the PHASE_CHANGED arm must trigger off the `slept` flag")
	assert(code.find("\"day\"") == -1,
		"the PHASE_CHANGED arm must NOT read the phase value -- a cycle wrap emits day with no sleep behind it")


func _check_guard_flag_lifecycle(src: String) -> void:
	assert(src.find("var _sleep_has_consolidation") != -1, "sleep_veil.gd must declare _sleep_has_consolidation")

	var begin_sleep_body := src.get_slice("func _begin_sleep() -> void:", 1).get_slice("func play_opener", 0)
	assert(begin_sleep_body.find("_sleep_has_consolidation = false") != -1, "_begin_sleep() must reset _sleep_has_consolidation false for every fresh sleep")

	assert(src.find("WIEvents.CONSOLIDATION_OFFERED") == -1, "#472: there is no offer event any more -- the veil reads the APPLIED merge")
	var merge_line_body := src.get_slice("WIEvents.CONSOLIDATION_ACCEPTED:", 1).get_slice("WIEvents.ACCOMPLISHMENT_RECORDED:", 0)
	assert(merge_line_body.find("_sleep_has_consolidation = true") != -1, "the CONSOLIDATION_ACCEPTED handler must arm _sleep_has_consolidation -- a merge the player never chose must not be skippable past")
	assert(merge_line_body.find("merge into") != -1, "the veil must speak the merge (1: veil line + journal entry)")


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
	assert(input_body.find("if not (_running or _opener_running or _finale_running or _defeat_running):") != -1, "_unhandled_input's modal-advance gate must include _running")

	var modal_active_body := src.get_slice("func modal_active() -> bool:", 1).get_slice("func _unhandled_input", 0)
	assert(modal_active_body.find("return _running or _opener_running or _finale_running or _defeat_running") != -1, "modal_active() must include _running")


## PHASE 8 (2026-07-26 main-quest wave): the post-seal epilogue RETIRES. The
## seal is a mid-story beat now, so nothing may re-arm a closing sequence off
## `raskghar_sealed`, and `post_game` -- which banks mid-story at the seal
## sleep (sleep_beat.gd) -- must no longer be the one-shot guard.
func _check_finale_retired_the_epilogue(src: String) -> void:
	assert(src.find("_epilogue_armed") == -1, "the raskghar_sealed epilogue arm must be GONE (the seal is mid-story now)")
	assert(src.find("func _bank_post_game") == -1, "the veil must not bank post_game any more -- sleep_beat.gd owns it (Task 1.2)")

	var accomplishment_body := src.get_slice("WIEvents.ACCOMPLISHMENT_RECORDED:", 1).get_slice("WIEvents.DIALOGUE_ENDED:", 0)
	assert(accomplishment_body.find("raskghar_sealed") == -1, "no closing sequence may arm off raskghar_sealed")

	var play_body := src.get_slice("func play_finale() -> void:", 1).get_slice("func _finale_owed", 0)
	assert(play_body.find("accomplishment_count(\"post_game\")") == -1, "play_finale must not gate on post_game -- it banks mid-story and would suppress the ending")
	assert(play_body.find("if not _finale_owed():") != -1, "play_finale must gate on _finale_owed()")


## The trigger is SIM STATE, not a runtime flag: a save/quit between the
## resolution and the curtain must not be able to strand the game's one true
## ending. Two delivery moments -- the resolving conversation's own end, and
## the end of a sleep reveal (the FIGHT path resolves at a container, with no
## dialogue behind it).
func _check_finale_is_owed_not_armed(src: String) -> void:
	var owed_body := src.get_slice("func _finale_owed() -> bool:", 1).get_slice("func _finale_lines", 0)
	assert(owed_body.find("\"seal_resolved\"") != -1, "_finale_owed must read seal_resolved")
	assert(owed_body.find("\"finale_played\"") != -1, "_finale_owed must read the finale_played one-shot counter")

	var ended_body := src.get_slice("WIEvents.DIALOGUE_ENDED:", 1).get_slice("WIEvents.CONSOLIDATION_ACCEPTED", 0)
	assert(ended_body.find("play_finale()") != -1, "DIALOGUE_ENDED must play the owed finale (TALK/SKILL paths resolve mid-dialogue)")
	# FILTERED, not unconditional: on the FIGHT path (whose resolution is a
	# container open) an unfiltered hook would credit-roll the next shopkeeper.
	assert(ended_body.find("FINALE_CURTAIN_CONVERSATIONS.has(") != -1, "DIALOGUE_ENDED must gate on FINALE_CURTAIN_CONVERSATIONS -- an unrelated conversation must never draw the curtain")
	assert(src.find("WIEvents.DIALOGUE_STARTED:") != -1, "the conversation id must be captured from DIALOGUE_STARTED (DIALOGUE_ENDED's payload is empty)")
	# The slice must open at `= [`, not at the const name: `Array[String]`'s own
	# bracket would otherwise close it before the first entry.
	var curtain_body := src.get_slice("const FINALE_CURTAIN_CONVERSATIONS: Array[String] = [", 1).get_slice("]", 0)
	for conv: String in ["olesm_intro", "pisces_seal"]:
		assert(curtain_body.find(conv) != -1, "%s BANKS seal_resolved -- it must be able to draw the curtain" % conv)

	# #472 RETIRED THE RETRY ARM WITH THE MODAL IT SERVED. The merge now applies
	# INSIDE the sleep beat, before the veil sequence runs, so the bed hook has
	# one settled snapshot to recount and never stands down.
	assert(src.find("WIEvents.CONSOLIDATION_DECLINED") == -1, "#472: there is no decline event to retry an owed finale off")
	assert(src.find("play_finale.call_deferred()") == -1, "#472: the deferred consolidation retry is DELETED -- nothing resolves after the veil any more")

	var run_sequence_body := src.get_slice("func _run_sequence() -> void:", 1).get_slice("func _play_finale_off_the_bed", 0)
	assert(run_sequence_body.split("_play_finale_off_the_bed()").size() - 1 == 2, "BOTH _run_sequence branches (QA-collapsed and real) must play an owed finale off the bed -- the FIGHT path banks seal_resolved at a container, never in a dialogue")

	var off_the_bed_body := src.get_slice("func _play_finale_off_the_bed() -> void:", 1).get_slice("func _add_line(", 0)
	assert(off_the_bed_body.find("_sleep_has_consolidation") == -1, "#472: the bed hook must NOT stand down for a merge -- it already applied in-beat, so the finale rolls that same night naming the merged class")

	var bank_body := src.get_slice("func _bank_finale_played() -> void:", 1).get_slice("func _emit_finale_rendered", 0)
	assert(bank_body.find("record_accomplishment(\"finale_played\")") != -1, "the finale must bank finale_played")


## v0.15 A5: Acts I-III get a presence in the ending. Per-counter like the
## region recap (NOT last-match-wins -- a finale player holds all three and the
## recap is supposed to walk the whole story), and emitted between the class
## recount and the region recap so the sequence reads chronologically.
func _check_finale_act_presences(src: String) -> void:
	var act_body := src.get_slice("const FINALE_ACT_LINES", 1).get_slice("const FINALE_REGION_LINES", 0)
	for counter: String in ["reached_liscor", "post_game", "raskghar_sealed"]:
		assert(act_body.find(counter) != -1, "the act recap must carry a %s presence line" % counter)
	assert(act_body.find("last-match") == -1 and act_body.find("LAST MATCH") == -1, "the act table is per-counter, not a precedence ladder -- all three render together")

	var lines_body := src.get_slice("func _finale_lines() -> Array[String]:", 1).get_slice("func _run_finale", 0)
	var recount_at := lines_body.find("Game.sim.snapshot()")
	var act_at := lines_body.find("FINALE_ACT_LINES")
	var region_at := lines_body.find("FINALE_REGION_LINES")
	assert(act_at != -1, "_finale_lines must emit the act presences")
	assert(recount_at < act_at and act_at < region_at,
		"act presences sit between the class recount and the region recap -- who you became, what the city did about it, then where the Door took you")


## Region recap is per-counter; the path close is LAST-MATCH-WINS, so the
## table order IS the precedence rule (a player can hold seal_opened AND a
## later resolution counter -- the deliberate no-dead-end hatch).
func _check_finale_line_tables(src: String) -> void:
	var region_body := src.get_slice("const FINALE_REGION_LINES", 1).get_slice("const FINALE_CLOSE_LINES", 0)
	for counter: String in ["lattice_witch_lore", "lattice_hedault_reading", "lattice_forge_rune"]:
		assert(region_body.find(counter) != -1, "the region recap must carry a %s line" % counter)

	var close_body := src.get_slice("const FINALE_CLOSE_LINES", 1).get_slice("const FINALE_LINK_LINE", 0)
	var opened_at := close_body.find("seal_opened")
	var fed_at := close_body.find("seal_kept_fed")
	var rewarded_at := close_body.find("seal_rewarded")
	assert(opened_at != -1 and fed_at != -1 and rewarded_at != -1, "all three path closes must be present")
	assert(opened_at < fed_at and fed_at < rewarded_at, "last-match-wins: seal_opened must sit FIRST so a later resolution counter outranks it")

	var lines_body := src.get_slice("func _finale_lines() -> Array[String]:", 1).get_slice("func _run_finale", 0)
	var open_at := lines_body.find("FINALE_LINES_OPEN")
	var recount_at := lines_body.find("Game.sim.snapshot()")
	var region_at := lines_body.find("FINALE_REGION_LINES")
	var close_at := lines_body.find("FINALE_CLOSE_LINES")
	var link_at := lines_body.find("FINALE_LINK_LINE")
	assert(open_at < recount_at and recount_at < region_at and region_at < close_at and close_at < link_at,
		"finale order is open -> class recount -> region recap -> one path close -> the wanderinginn.com curtain")
