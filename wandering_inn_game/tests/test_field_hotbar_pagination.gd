extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	_run.call_deferred()


func _run() -> void:
	# The field layer depends on real autoloads; --script does not instantiate them.
	var output: Array = []
	var result := OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--quit-after", "180", "res://tests/test_field_hotbar_pagination.tscn",
	], output, true)
	var transcript := "\n".join(output)
	var passed := result == 0 and transcript.contains("PASS: phone field pagination")
	for marker: String in ["ERROR:", "WARNING:", "SCRIPT ERROR:"]:
		passed = passed and not transcript.contains(marker)
	if not passed:
		printerr("Field pagination scene failed (exit %d):\n%s" % [result, transcript])
		quit(1)
		return
	print("PASS: phone field pagination reaches 37 original slots with safe 44 CSS controls at all text scales; resize preserves selection")
	quit(0)
