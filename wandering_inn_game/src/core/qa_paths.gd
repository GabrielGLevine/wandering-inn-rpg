class_name QAPaths
extends RefCounted


static func parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a: String in args:
		if a.begins_with("--") and a.contains("="):
			var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
			out[kv[0]] = kv[1]
	return out


static func user_args() -> Dictionary:
	return parse_args(OS.get_cmdline_user_args())


static func out_dir() -> String:
	var args: Dictionary = user_args()
	if args.has("qa-out"):
		return String(args["qa-out"])
	return OS.get_user_data_dir().path_join("qa")
