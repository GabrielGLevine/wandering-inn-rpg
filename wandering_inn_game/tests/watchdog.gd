class_name WITestWatchdog
extends RefCounted

const TIMEOUT_SECONDS := 60.0
const TIMEOUT_MESSAGE := "WATCHDOG: test timed out (a failed assert hangs --script runs)"


static func arm(tree: SceneTree) -> void:
	tree.create_timer(TIMEOUT_SECONDS).timeout.connect(func() -> void:
		print(TIMEOUT_MESSAGE)
		tree.quit(1)
	)
