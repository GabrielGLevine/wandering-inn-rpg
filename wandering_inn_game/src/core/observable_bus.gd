extends Node

signal domain_event(type: String, payload: Dictionary)

var _log: WIEventLog


func _ready() -> void:
	if not OS.has_feature("web"):
		_log = WIEventLog.new(QAPaths.out_dir().path_join("events.jsonl"))


func emit_domain_event(type: String, payload: Dictionary = {}) -> void:
	if _log != null:
		_log.append(type, payload)
	domain_event.emit(type, payload)
