class_name WIEventLog
extends RefCounted
## Append-only JSONL event log. Pure class - path is injected; no autoload use.


var _file: FileAccess


func _init(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_file = FileAccess.open(path, FileAccess.WRITE)


## Appends one typed domain event and payload as a JSONL row.
func append(type: String, payload: Dictionary) -> void:
	if _file == null:
		return
	_file.store_line(JSON.stringify({"t": Time.get_ticks_msec(), "type": type, "payload": payload}))
	_file.flush()


## Closes the underlying file handle.
func close() -> void:
	if _file != null:
		_file.close()
		_file = null
