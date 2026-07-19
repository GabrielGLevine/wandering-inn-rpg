extends SceneTree
## #111 safe project rename -- unit-pins the pure copy logic of the legacy
## user:// carry-over (WISaveMigration). Uses two throwaway temp dirs under
## user:// (the isolated QA HOME), so it is deterministic and rides the unit
## suite. The full boot-ordered flow (seed legacy -> _ready migrates ->
## Continue lights up) is the save_rename_migration canonical's job.

const LEGACY := "user://__mig_test_legacy"
const TARGET := "user://__mig_test_target"


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _cleanup() -> void:
	# Guard the trash call: move_to_trash on an absent dir prints a bare
	# `ERROR: trashItemAtURL` line, and ci_sweep's grep fails on bare ERROR:
	# (#216 review hardening) -- don't reintroduce that noise (#111 review M-1).
	for d: String in [LEGACY, TARGET]:
		var abs := ProjectSettings.globalize_path(d)
		if DirAccess.dir_exists_absolute(abs):
			OS.move_to_trash(abs)


func _init() -> void:
	var legacy_abs := ProjectSettings.globalize_path(LEGACY)
	var target_abs := ProjectSettings.globalize_path(TARGET)
	_cleanup()

	# Seed a legacy dir: two save slots + settings.cfg (+ a non-json to skip).
	_write("%s/saves/manual.json" % LEGACY, '{"version":5,"state":{"gold":42}}')
	_write("%s/saves/auto.json" % LEGACY, '{"version":5,"state":{"gold":7}}')
	_write("%s/saves/notes.txt" % LEGACY, "ignore me")
	_write("%s/settings.cfg" % LEGACY, "[audio]\nmaster=0.5\n")

	# Copy into an EMPTY target: both saves + settings carry over (txt skipped).
	var result: Dictionary = WISaveMigration.migrate_userdir(legacy_abs, target_abs)
	assert(int(result["copied"]) == 3, "copies 2 json saves + settings.cfg (skips the .txt): got %s" % [result])
	assert(int(result["failed"]) == 0, "clean pass reports zero failures: got %s" % [result])
	assert(_read("%s/saves/manual.json" % TARGET) == '{"version":5,"state":{"gold":42}}', "manual save carried byte-for-byte")
	assert(_read("%s/saves/auto.json" % TARGET) == '{"version":5,"state":{"gold":7}}', "auto save carried")
	assert(_read("%s/settings.cfg" % TARGET) == "[audio]\nmaster=0.5\n", "settings carried")
	assert(not FileAccess.file_exists("%s/saves/notes.txt" % TARGET), "non-json is NOT copied")

	# NO-CLOBBER: a target file that already exists is left untouched (a SKIP,
	# not a failure -- the retry-on-partial-copy design depends on that
	# distinction), and a fresh legacy file still copies.
	_write("%s/saves/manual.json" % TARGET, '{"MINE":true}')  # a newer target save
	_write("%s/saves/fresh.json" % LEGACY, '{"version":5}')
	var result2: Dictionary = WISaveMigration.migrate_userdir(legacy_abs, target_abs)
	assert(int(result2["copied"]) == 1, "only the one NEW legacy file copies; existing target files untouched: got %s" % [result2])
	assert(int(result2["failed"]) == 0, "no-clobber skips are NOT failures (else the marker would never write on a re-run): got %s" % [result2])
	assert(_read("%s/saves/manual.json" % TARGET) == '{"MINE":true}', "existing target save NOT clobbered")
	assert(FileAccess.file_exists("%s/saves/fresh.json" % TARGET), "the fresh legacy save did copy")

	# Empty/absent legacy -> zero copies, zero failures, no crash.
	var result3: Dictionary = WISaveMigration.migrate_userdir(ProjectSettings.globalize_path("user://__nope"), target_abs)
	assert(int(result3["copied"]) == 0 and int(result3["failed"]) == 0, "absent legacy copies nothing, fails nothing")

	# PARTIAL-FAILURE reporting (#111 review I-1): an unwritable destination
	# counts as failed, so the caller withholds the marker and retries next
	# boot. A DIRECTORY squatting on the dst file path defeats FileAccess.WRITE.
	_write("%s/saves/blocked.json/x" % TARGET, "squatter")  # dst becomes a dir
	_write("%s/saves/blocked.json" % LEGACY, '{"version":5}')
	var result4: Dictionary = WISaveMigration.migrate_userdir(legacy_abs, target_abs)
	assert(int(result4["failed"]) == 1, "unwritable dst reports failed=1 (marker must NOT be written): got %s" % [result4])

	# The sibling derivation names the pre-rename dir as a same-parent sibling.
	var legacy_path: String = WISaveMigration.legacy_userdir_path()
	assert(legacy_path.ends_with("/Wandering Inn RPG v4"), "legacy path is the v4 sibling: %s" % legacy_path)
	assert(legacy_path.get_base_dir() == ProjectSettings.globalize_path("user://").trim_suffix("/").get_base_dir(), "legacy shares user://'s parent (app_userdata)")

	_cleanup()
	print("PASS: legacy user-dir copy carries saves+settings, never clobbers, derives the sibling")
	quit(0)
