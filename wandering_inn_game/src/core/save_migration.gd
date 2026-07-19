class_name WISaveMigration
## #111 safe project rename. PURE static file I/O -- no autoload/Node/sim
## refs, so it is unit-testable directly (test_save_rename). The Game
## autoload wires these at boot: derive the legacy sibling, copy it into a
## fresh user://, emit the event, drop the marker.
##
## `user://` derives from `application/config/name` (Godot os.cpp), so
## renaming the project ("Wandering Inn RPG v4" -> "Wandering Inn RPG")
## moves the user data dir to a new app_userdata sibling and would strand
## every existing save + settings.cfg. We COPY (never move) the legacy
## sibling across; copy-only leaves it intact as a rollback.

const LEGACY_USERDIR_NAME := "Wandering Inn RPG v4"


## Absolute path of the pre-rename user dir: the same-parent sibling of the
## current user:// named LEGACY_USERDIR_NAME (so no Godot/godot capitalization
## guesswork -- the sibling shares our casing). Works native AND web (user://
## globalizes to the real absolute path on both). "" if underivable.
static func legacy_userdir_path() -> String:
	var cur := ProjectSettings.globalize_path("user://").trim_suffix("/")
	var parent := cur.get_base_dir()
	if parent == "":
		return ""
	return "%s/%s" % [parent, LEGACY_USERDIR_NAME]


## COPY settings.cfg + saves/*.json from `legacy_abs` into `target_abs`,
## never overwriting an existing target file. Returns {copied, failed}:
## `copied` = files newly written, `failed` = files that EXIST in the legacy
## dir but could not be written (IO/permission/disk-full) -- an
## already-present target file is a no-clobber SKIP, NOT a failure. The
## caller uses `failed` to decide whether the migration is complete (#111
## review I-1: a partial copy must not be marked done).
static func migrate_userdir(legacy_abs: String, target_abs: String) -> Dictionary:
	var copied := 0
	var failed := 0
	var legacy_settings := "%s/settings.cfg" % legacy_abs
	var target_settings := "%s/settings.cfg" % target_abs
	if FileAccess.file_exists(legacy_settings) and not FileAccess.file_exists(target_settings):
		if _copy_file_abs(legacy_settings, target_settings):
			copied += 1
		else:
			failed += 1
	var legacy_saves := "%s/saves" % legacy_abs
	if DirAccess.dir_exists_absolute(legacy_saves):
		DirAccess.make_dir_recursive_absolute("%s/saves" % target_abs)
		for f: String in DirAccess.get_files_at(legacy_saves):
			if not f.ends_with(".json"):
				continue
			var dst := "%s/saves/%s" % [target_abs, f]
			if FileAccess.file_exists(dst):
				continue  # no-clobber skip -- an existing target save is preserved
			if _copy_file_abs("%s/%s" % [legacy_saves, f], dst):
				copied += 1
			else:
				failed += 1
	return {"copied": copied, "failed": failed}


static func _copy_file_abs(src: String, dst: String) -> bool:
	var f := FileAccess.open(src, FileAccess.READ)
	if f == null:
		return false
	var data := f.get_buffer(f.get_length())
	f.close()
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	var out := FileAccess.open(dst, FileAccess.WRITE)
	if out == null:
		return false
	out.store_buffer(data)
	out.close()
	return true
