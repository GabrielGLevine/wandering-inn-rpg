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
	queue.assign(["first", "second", "third"])
	layer.call("_bank_toasts")
	assert((layer.get("_toast_queue") as Array).is_empty(),
		"combat banks the pending queue so nothing renders over the board")
	assert((layer.get("_banked_toasts") as Array) == ["first", "second", "third"],
		"banked toasts keep emission order")
	# _toast_draining gates the restore's own drain kick -- pinned true here so
	# the restore stays node-free (a real drain would touch the toast panel).
	layer.set("_toast_draining", true)
	layer.call("_restore_banked_toasts")
	assert((layer.get("_toast_queue") as Array) == ["first", "second", "third"],
		"combat end re-queues every banked toast, in order")
	assert((layer.get("_banked_toasts") as Array).is_empty(),
		"the bank empties on restore -- a second combat must not replay it")
	layer.call("_restore_banked_toasts")
	assert((layer.get("_toast_queue") as Array) == ["first", "second", "third"],
		"restoring an empty bank is a no-op")
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


func _stubbed_instance(raw: String) -> Object:
	assert(raw.begins_with("extends CanvasLayer"), "message_layer.gd must still extend CanvasLayer")
	var first_nl := raw.find("\n")
	var stub := "\n\nvar Game: Variant = null\nvar ObservableBus: Variant = null\nvar TestDriver: Variant = null\nvar WIInputHints: Variant = null\nvar WISettings: Variant = null"
	var script := GDScript.new()
	script.source_code = raw.substr(0, first_nl) + stub + raw.substr(first_nl)
	var err := script.reload()
	assert(err == OK, "message_layer.gd (autoload-stubbed copy) failed to compile: %d" % err)
	return script.new()
