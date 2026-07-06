class_name QAPaths
extends RefCounted
## Parses QA-related command-line user args (everything after `--`) and
## resolves the QA output directory.


## Parses `--key=value` arguments, ignoring loose args and non-user flags.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a: String in args:
		if a.begins_with("--") and a.contains("="):
			var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
			out[kv[0]] = kv[1]
	return out


## Returns parsed command-line user args from Godot.
static func user_args() -> Dictionary:
	return parse_args(OS.get_cmdline_user_args())


## Returns `--qa-out` when provided, otherwise the default user QA directory.
static func out_dir() -> String:
	var args: Dictionary = user_args()
	if args.has("qa-out"):
		return String(args["qa-out"])
	return OS.get_user_data_dir().path_join("qa")
