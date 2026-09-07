extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	_run.call_deferred()


func _run() -> void:
	# The creation layer depends on real autoloads; --script does not instantiate them.
	var output: Array = []
	var result := OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--quit-after", "180", "res://tests/creation_back_scene.tscn",
	], output, true)
	var transcript := "\n".join(output)
	var passed := result == 0 and transcript.contains("PASS: creation Back")
	for marker: String in ["ERROR:", "WARNING:", "SCRIPT ERROR:"]:
		passed = passed and not transcript.contains(marker)
	if not passed:
		printerr("Creation Back scene failed (exit %d):\n%s" % [result, transcript])
		quit(1)
		return
	print("PASS: creation Back reaches every preceding step and title with safe 44 CSS controls")
	quit(0)
