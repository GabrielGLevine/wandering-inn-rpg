extends SceneTree

## v0.15 A3 (GH#304): the toast queue is LOSSLESS. Map change and dialogue
## defer the visible toast without touching the queue (drain-after); combat
## BANKS the queue and re-queues it when the board closes. This suite proves
## both halves without a live scene: the queue helpers are node-free by
## design, and source tripwires keep any future transition from re-growing a
## drop path (the VISUAL-LOG UI/QUEST-START + TOAST/QUEUE-DROP class).

const MESSAGE_LAYER_PATH := "res://src/ui/message_layer.gd"


func _init() -> void:
	WITestWatchdog.arm(self)
	var raw := FileAccess.get_file_as_string(MESSAGE_LAYER_PATH)
	_check_no_drop_paths(raw)
	_check_combat_bank(raw)
	_check_housekeeping_class(raw)
	_check_hold_curve(raw)
	_check_movement_dismiss_protection(raw)
	_check_readable_floor(raw)
	_check_save_status_off_the_strip(raw)
	_check_line_panel_on_toast_layer(raw)
	_check_interior_flavor_rotation(raw)
	print("PASS: toast queue survives transitions (defer + combat bank)")
	quit(0)


## The whole point of A3: nothing but the drain may remove a queued toast.
func _check_no_drop_paths(raw: String) -> void:
	assert(raw.find("func _clear_toast") == -1,
		"_clear_toast (the transition queue-wipe) must be gone -- transitions defer the DISPLAY, never the queue")
	var clears := raw.count("_toast_queue.clear()")
	assert(clears == 1, "_toast_queue.clear() must survive in exactly ONE place (the combat bank), found %d" % clears)
	var bank_body := raw.get_slice("func _bank_toasts", 1).get_slice("\nfunc ", 0)
	assert(bank_body.find("_toast_queue.clear()") != -1,
		"the single _toast_queue.clear() must live inside _bank_toasts")
	var handler := raw.get_slice("func _on_domain_event", 1).get_slice("\nfunc ", 0)
	for arm_name: String in ["MAP_CHANGED", "DIALOGUE_STARTED"]:
		var arm := handler.get_slice("WIEvents.%s:" % arm_name, 1).get_slice("WIEvents.", 0)
		assert(arm.find("_defer_toast_display()") != -1,
			"the %s arm must defer the visible toast, not drop the queue" % arm_name)
		assert(arm.find("_bank_toasts()") == -1,
			"%s must NOT bank -- only combat has its own feed to defer to" % arm_name)


## Behavioural half: bank/restore are node-free so they can be exercised on an
## autoload-stubbed copy (the test_settings/_check_static_flag_reset idiom).
func _check_combat_bank(raw: String) -> void:
	var layer := _stubbed_instance(raw)
	var queue: Array = layer.get("_toast_queue")
	queue.assign([_entry("first"), _entry("second"), _entry("third")])
	layer.call("_bank_toasts")
	assert((layer.get("_toast_queue") as Array).is_empty(),
		"combat banks the pending queue so nothing renders over the board")
	assert(_texts(layer.get("_banked_toasts")) == ["first", "second", "third"],
		"banked toasts keep emission order")
	# _toast_draining gates the restore's own drain kick -- pinned true here so
	# the restore stays node-free (a real drain would touch the toast panel).
	layer.set("_toast_draining", true)
	layer.call("_restore_banked_toasts")
	assert(_texts(layer.get("_toast_queue")) == ["first", "second", "third"],
		"combat end re-queues every banked toast, in order")
	assert((layer.get("_banked_toasts") as Array).is_empty(),
		"the bank empties on restore -- a second combat must not replay it")
	layer.call("_restore_banked_toasts")
	assert(_texts(layer.get("_toast_queue")) == ["first", "second", "third"],
		"restoring an empty bank is a no-op")

	# v0.16.1 finding 16: a toast emitted DURING the fight banks too. The strip's
	# band is bare arena in the combat HUD's map, so the exemption that let it
	# render over the board is closed; combat_screen mirrors the text into the
	# feed, which is also what records it, so the banked copy carries record=false.
	(layer.get("_toast_queue") as Array).clear()
	(layer.get("_banked_toasts") as Array).clear()
	layer.set("_combat_active", true)
	layer.call("_queue_toast", "Used: Mending Draught. Healed 8 HP.")
	assert((layer.get("_toast_queue") as Array).is_empty(),
		"a mid-fight toast must not reach the queue -- the strip stays off the board")
	var banked: Array = layer.get("_banked_toasts")
	assert(_texts(banked) == ["Used: Mending Draught. Healed 8 HP."],
		"a mid-fight toast banks instead, so nothing is lost")
	assert(bool((banked[0] as Dictionary)["record"]) == false,
		"the banked mid-fight toast must not record -- combat's feed_push already did")
	# ...but a HOUSEKEEPING toast is never mirrored into the combat feed
	# ("Autosaved." has no place in a blow-by-blow), so its only route into
	# Recent Messages is the post-fight drain and it MUST keep record=true.
	layer.call("_queue_toast", "Autosaved. (Esc — save/load anytime)", true, true)
	assert(_texts(banked) == ["Used: Mending Draught. Healed 8 HP.", "Autosaved. (Esc — save/load anytime)"],
		"a mid-fight housekeeping toast banks too")
	assert(bool((banked[1] as Dictionary)["record"]) == true,
		"a banked housekeeping toast keeps record=true -- the feed never took it")
	layer.set("_combat_active", false)
	layer.free()
	# The OTHER branch -- _toast_draining false, so the restore must kick a
	# drain itself -- cannot run here: _drain_toasts() reaches _show(), which
	# measures the real toast panel/label, and this instance has neither (it is
	# never added to a tree, which is exactly what keeps the suite node-free).
	# It is pinned two ways instead: the source tripwire below, and a LIVE
	# proof in qa/scripts/sewers_walkthrough.json -- two [Skill] narrations
	# banked at combat_started and delivered after ui_combat_hidden, by which
	# point the drain coroutine has exited and only the kick can move them.
	var restore := raw.get_slice("func _restore_banked_toasts", 1).get_slice("\nfunc ", 0)
	assert(restore.find("if not _toast_draining:") != -1 and restore.find("_drain_toasts()") != -1,
		"_restore_banked_toasts must kick a drain when none is in flight -- the queue can otherwise sit full and idle after a fight")


## v0.16.1 finding 8 + GH#325: authored toasts outrank housekeeping chores in the
## queue, and only chores are clipped by the hold cap.
func _check_housekeeping_class(raw: String) -> void:
	var layer := _stubbed_instance(raw)
	layer.set("_toast_draining", true)  # keep the drain (which needs a real panel) out of it
	layer.call("_queue_toast", "Autosaved. (Esc — save/load anytime)", true, true)
	layer.call("_queue_toast", "Quest updated: Something Beneath")
	layer.call("_queue_toast", "A Watch runner is looking for you.")
	layer.call("_queue_toast", "Game saved.", true, true)
	assert(_texts(layer.get("_toast_queue")) == [
			"Quest updated: Something Beneath",
			"A Watch runner is looking for you.",
			"Autosaved. (Esc — save/load anytime)",
			"Game saved.",
		],
		"authored toasts insert ahead of trailing housekeeping, and each class stays FIFO within itself -- got %s" % [_texts(layer.get("_toast_queue"))])
	layer.free()

	var show := raw.get_slice("func _show(", 1).get_slice("\nfunc ", 0)
	assert(show.find("var chore := panel == _toast_panel and _showing_housekeeping") != -1
			and show.find("if chore and not _toast_queue.is_empty():") != -1,
		"the queue hold cap must be gated on _showing_housekeeping -- capping authored toasts at 1.6s is the defect finding 8 named")
	# GH#325's own sequence queues the chore FIRST, so the queue is EMPTY when
	# "Autosaved." starts displaying and a one-shot cap check never fires: the
	# chore then held its FULL 6.0s (1.5x curve, 36 chars) with the payoff behind
	# it -- longer than main's uncapped 4.06s. The cap must be re-checked inside
	# the hold loop, or finding 8's headline repro comes out worse than it went in.
	assert(show.find("deadline_msec = mini(deadline_msec, started_msec + int(chore_cap * 1000.0))") != -1,
		"the hold cap must be RE-CHECKED during the hold -- a chore that starts alone must still yield when an authored toast joins the queue")
	# VISUAL-LOG "Authored payoff prose queues behind housekeeping toasts": the
	# re-checked CAP was still 1.6s of the moment spent on "Autosaved." -- and
	# under the windowed QA hold (0.4s) the cap never binds at all, so every
	# capture of that beat photographed the chore. Measured on invrisil_hat_quiet
	# at seed 37: "Autosaved." was the ONLY one of the beat's three toasts that
	# ever reached ui_toast_rendered. A chore now yields OUTRIGHT (cap 0.0) the
	# moment authored copy is waiting; chore-behind-chore keeps the 1.6s cap.
	assert(show.find("var chore_cap := 0.0 if _queue_has_authored() else TOAST_QUEUE_HOLD_CAP_SECONDS") != -1,
		"a chore holding the strip must yield it outright to waiting AUTHORED copy, not merely cap at TOAST_QUEUE_HOLD_CAP_SECONDS")

	var yielder := _stubbed_instance(raw)
	yielder.set("_toast_draining", true)
	assert(not bool(yielder.call("_queue_has_authored")),
		"an empty queue holds nothing authored -- a lone chore must keep its own hold")
	yielder.call("_queue_toast", "Autosaved. (Esc — save/load anytime)", true, true)
	assert(not bool(yielder.call("_queue_has_authored")),
		"a queue of pure chores must not make the showing chore yield -- that is the 1.6s cap's own case")
	yielder.call("_queue_toast", "Your coat goes over the chair back with the package folded into it.")
	assert(bool(yielder.call("_queue_has_authored")),
		"authored prose waiting behind a chore must be visible to the hold loop -- got %s" % [_texts(yielder.get("_toast_queue"))])
	yielder.free()


## The user directive for finding 8: the whole hold curve is the old one x1.5.
func _check_hold_curve(raw: String) -> void:
	var body := raw.get_slice("func _toast_seconds", 1).get_slice("\nfunc ", 0)
	assert(body.find("clampf(4.2 + 0.05 * float(text.length()), 5.1, 10.5)") != -1,
		"_toast_seconds must be the 1.5x curve (was clampf(2.8 + 0.035*len, 3.4, 7.0))")


func _entry(text: String) -> Dictionary:
	return {"text": text, "record": true, "housekeeping": false}


func _texts(entries: Variant) -> Array:
	var out: Array = []
	for e: Dictionary in (entries as Array):
		out.append(String(e["text"]))
	return out


## #509 acceptance 2: a step before the readable floor retires the toast AT
## the floor, never before; a step after it retires now; the floor never
## extends a toast past its own hold. Pure rule, so it is tested at REAL
## timings (1.2s floor) rather than the collapsed QA ones.
func _check_readable_floor(raw: String) -> void:
	assert(raw.find("const TOAST_MIN_READ_SECONDS := 1.2") != -1, "the readable floor is 1.2s")
	var layer := _stubbed_instance(raw)
	var floor_msec := 1200
	assert(int(layer.call("early_dismiss_deadline", 10000, 15000, floor_msec)) == 11200,
		"an early step retires the toast at the floor (started + 1.2s), not now")
	assert(int(layer.call("early_dismiss_deadline", 10000, 10500, floor_msec)) == 10500,
		"the floor never extends a toast past its own hold")
	assert(int(layer.call("early_dismiss_deadline", 10000, 15000, 0)) == 10000,
		"under QA the floor is 0: the step retires it at once (canonical timing untouched)")
	# The dismiss entry point routes an early step to the floor flag, never to
	# the skip flag -- source tripwire, since the panel needs a scene to be visible.
	var dismiss := raw.get_slice("func dismiss_current_toast_early", 1).get_slice("\nfunc ", 0)
	assert(dismiss.find("_dismiss_at_min_read = true") != -1, "an early step sets _dismiss_at_min_read")
	assert(dismiss.find("_min_read_msec()") != -1, "the dismiss compares against the readable floor")
	var loop := raw.get_slice("if _dismiss_at_min_read:", 1).get_slice("\n", 1)
	assert(loop.find("early_dismiss_deadline(") != -1, "the hold loop honours the floor via the pure rule")
	layer.free()


## #509 acceptance 1: the arrival line must not be parented under the base
## canvas (FieldHotbar's readout is drawn there, later, and covered 81% of the
## line panel). The driver's assert_dialogue_displayed probe measures the
## overlap live; this tripwire keeps the parent from drifting back.
func _check_line_panel_on_toast_layer(raw: String) -> void:
	assert(raw.find("toast_root.add_child(_dialogue_panel)") != -1,
		"the dialogue line panel must be a child of the toast layer's root (layer TOAST_CANVAS_LAYER)")
	assert(raw.find("root.add_child(_dialogue_panel)") == -1 or raw.find("toast_root.add_child(_dialogue_panel)") != -1,
		"the line panel must not also sit on the base canvas")


## #509: the save status is a PILL on the hint ribbon, never a toast -- so it
## can neither delay authored copy nor be dismissed by a step.
func _check_save_status_off_the_strip(raw: String) -> void:
	var arm := raw.get_slice("WIEvents.GAME_SAVED:", 1).get_slice("WIEvents.", 0)
	assert(arm.find("_show_save_status(") != -1, "GAME_SAVED renders the save status")
	assert(arm.find("_queue_toast(") == -1, "GAME_SAVED must not queue a toast")
	var body := raw.get_slice("func _show_save_status", 1).get_slice("\nfunc ", 0)
	assert(body.find("_hint_label.text") != -1 and body.find("UI_SAVE_STATUS_RENDERED") != -1,
		"the pill rides the hint ribbon and confirms with ui_save_status_rendered")
	assert(body.find("_toast_queue") == -1, "the pill never touches the toast queue")


func _stubbed_instance(raw: String) -> Object:
	assert(raw.begins_with("extends CanvasLayer"), "message_layer.gd must still extend CanvasLayer")
	var first_nl := raw.find("\n")
	var stub := "\n\nvar Game: Variant = null\nvar ObservableBus: Variant = null\nvar TestDriver: Variant = null\nvar WIInputHints: Variant = null\nvar WISettings: Variant = null"
	var script := GDScript.new()
	script.source_code = raw.substr(0, first_nl) + stub + raw.substr(first_nl)
	var err := script.reload()
	assert(err == OK, "message_layer.gd (autoload-stubbed copy) failed to compile: %d" % err)
	return script.new()


## GH#334 note 7: a PROTECTED toast keeps its full hold across PLAYER_MOVED.
## Delivery arrival is the one completion beat in the game that can only fire
## FROM movement, so the movement dismiss killed the only mark the moment had --
## a player holding a direction took the next step ~0.12s later and cancelled it.
func _check_movement_dismiss_protection(raw: String) -> void:
	var layer := _stubbed_instance(raw)
	layer.set("_toast_draining", true)
	layer.call("_queue_toast", "Delivered: Sealed Letter.", true, false, true)
	layer.call("_queue_toast", "Nothing there.")
	var queue: Array = layer.get("_toast_queue")
	assert(bool((queue[0] as Dictionary).get("protected", false)),
		"the protected claim rides the queue entry beside record/housekeeping")
	assert(not bool((queue[1] as Dictionary).get("protected", false)),
		"and every ordinary toast is unprotected by default -- movement still clears the strip")

	# Protection changes NOTHING about ordering or class: a protected authored
	# toast is still an authored toast, still FIFO within its class.
	layer.call("_queue_toast", "Autosaved. (Esc — save/load anytime)", true, true)
	layer.call("_queue_toast", "Quest complete: The Errand", true, false, true)
	assert(_texts(layer.get("_toast_queue")) == [
			"Delivered: Sealed Letter.",
			"Nothing there.",
			"Quest complete: The Errand",
			"Autosaved. (Esc — save/load anytime)",
		],
		"protection must not disturb the authored-ahead-of-housekeeping order -- got %s" % [_texts(layer.get("_toast_queue"))])
	layer.free()

	# Source tripwires: the exemption must live on the MOVEMENT arm only, and the
	# showing-entry flag must be lit from the drain. Both are the kind of wiring a
	# refactor drops silently -- a headless run can never see a hold expire.
	var handler := raw.get_slice("func _on_domain_event", 1).get_slice("\nfunc ", 0)
	var moved := handler.get_slice("WIEvents.PLAYER_MOVED:", 1).get_slice("WIEvents.", 0)
	assert(moved.find("if not _showing_protected:") != -1 and moved.find("dismiss_current_toast_early()") != -1,
		"the PLAYER_MOVED dismiss must be gated on _showing_protected")
	var drain := raw.get_slice("func _drain_toasts", 1).get_slice("\nfunc ", 0)
	assert(drain.find("_showing_protected = bool(entry.get(\"protected\", false))") != -1,
		"the drain must light _showing_protected from the entry it is about to show")
	# ...and ONLY the movement arm: a map change, a conversation and an interact
	# each replace what the player is reading, so they must still cut it short.
	for other_arm: String in ["MAP_CHANGED", "DIALOGUE_STARTED"]:
		var arm := handler.get_slice("WIEvents.%s:" % other_arm, 1).get_slice("WIEvents.", 0)
		assert(arm.find("_showing_protected") == -1,
			"%s must NOT consult _showing_protected -- the exemption is scoped to movement" % other_arm)


## GH#335 item 6: `interior_flavor` is now String OR Array, at all three levels
## of the resolution chain (map -> biome-by-map -> biome default). One line
## repeated at every empty poke is what makes a room feel switched off, so a
## list rotates -- NON-REPEATING by construction, since the cursor advances one
## entry per use. Exercised on the autoload-stubbed instance: `_pick_flavor_line`
## is deliberately pure (no Game, no WIDataRegistry), which is what lets the
## generalization be proven here instead of only through a live map.
func _check_interior_flavor_rotation(raw: String) -> void:
	var layer := _stubbed_instance(raw)

	# A plain String is untouched and never consumes a cursor slot -- every
	# single-line map behaves exactly as it did before the generalization.
	for _i in 3:
		assert(String(layer.call("_pick_flavor_line", "map:inn", "The common room is warm.")) == "The common room is warm.",
			"a String source returns itself, every time")
	assert((layer.get("_flavor_index") as Dictionary).is_empty(),
		"a String source never touches the round-robin cursor")

	var lines := ["one", "two", "three"]
	var picked: Array[String] = []
	for _i in 7:
		picked.append(String(layer.call("_pick_flavor_line", "map:room", lines)))
	assert(picked == ["one", "two", "three", "one", "two", "three", "one"],
		"a list rotates in authored order and wraps -- got %s" % [picked])
	for i in picked.size() - 1:
		assert(picked[i] != picked[i + 1], "NON-REPEATING: no poke ever answers with the line the last one did")

	# Per-source cursors: the three levels of the fallback chain each keep their
	# own place, so a biome default rotating cannot desync a map's own list.
	assert(String(layer.call("_pick_flavor_line", "biome:inn", lines)) == "one",
		"a different source key starts its own cursor at the top")
	assert(String(layer.call("_pick_flavor_line", "map:room", lines)) == "two",
		"...and does not disturb the first source's position")

	# Degenerate shapes stay harmless: an empty list reads as "nothing authored"
	# (the caller falls through to the next chain level), a single-entry list
	# repeats without ever going out of range.
	assert(String(layer.call("_pick_flavor_line", "map:empty", [])) == "",
		"an empty list is treated as absent, so the fallback chain continues")
	assert(String(layer.call("_pick_flavor_line", "map:solo", ["only"])) == "only"
			and String(layer.call("_pick_flavor_line", "map:solo", ["only"])) == "only",
		"a one-entry list is stable and never indexes past its end")
	layer.free()

	# Source tripwire: the cursor must stay a presentation-side counter. Reaching
	# for the sim's seeded RNG here would make every QA/balance seed depend on how
	# often a player pokes walls (the wi_audio.gd `_variant_index` rationale).
	var picker := raw.get_slice("func _pick_flavor_line", 1).get_slice("\nfunc ", 0)
	assert(picker.find("rng") == -1 and picker.find("rand") == -1,
		"_pick_flavor_line must never draw from the sim RNG -- flavor variety is not gameplay")
