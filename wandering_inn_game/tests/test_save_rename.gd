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
	for d: String in [LEGACY, TARGET]:
		OS.move_to_trash(ProjectSettings.globalize_path(d))  # best-effort; harmless if absent


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
	var copied: int = WISaveMigration.migrate_userdir(legacy_abs, target_abs)
	assert(copied == 3, "copies 2 json saves + settings.cfg (skips the .txt): got %d" % copied)
	assert(_read("%s/saves/manual.json" % TARGET) == '{"version":5,"state":{"gold":42}}', "manual save carried byte-for-byte")
	assert(_read("%s/saves/auto.json" % TARGET) == '{"version":5,"state":{"gold":7}}', "auto save carried")
	assert(_read("%s/settings.cfg" % TARGET) == "[audio]\nmaster=0.5\n", "settings carried")
	assert(not FileAccess.file_exists("%s/saves/notes.txt" % TARGET), "non-json is NOT copied")

	# NO-CLOBBER: a target file that already exists is left untouched, and a
	# fresh legacy file still copies -- the count reflects only new copies.
	_write("%s/saves/manual.json" % TARGET, '{"MINE":true}')  # a newer target save
	_write("%s/saves/fresh.json" % LEGACY, '{"version":5}')
	var copied2: int = WISaveMigration.migrate_userdir(legacy_abs, target_abs)
	assert(copied2 == 1, "only the one NEW legacy file copies; existing target files untouched: got %d" % copied2)
	assert(_read("%s/saves/manual.json" % TARGET) == '{"MINE":true}', "existing target save NOT clobbered")
	assert(FileAccess.file_exists("%s/saves/fresh.json" % TARGET), "the fresh legacy save did copy")

	# Empty/absent legacy -> zero copies, no crash.
	assert(WISaveMigration.migrate_userdir(ProjectSettings.globalize_path("user://__nope"), target_abs) == 0, "absent legacy copies nothing")

	# The sibling derivation names the pre-rename dir as a same-parent sibling.
	var legacy_path: String = WISaveMigration.legacy_userdir_path()
	assert(legacy_path.ends_with("/Wandering Inn RPG v4"), "legacy path is the v4 sibling: %s" % legacy_path)
	assert(legacy_path.get_base_dir() == ProjectSettings.globalize_path("user://").trim_suffix("/").get_base_dir(), "legacy shares user://'s parent (app_userdata)")

	_cleanup()
	print("PASS: legacy user-dir copy carries saves+settings, never clobbers, derives the sibling")
	quit(0)
