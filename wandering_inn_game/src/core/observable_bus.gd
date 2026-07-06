extends Node
## Autoload: the single pipe for every player-visible / QA-relevant domain
## event. Logs each event as JSONL, then emits it as a signal for UI and the
## TestDriver. Never bypass this with print() for player-facing messages.

## Re-emitted domain event stream for UI and QA consumers.
signal domain_event(type: String, payload: Dictionary)

var _log: WIEventLog


func _ready() -> void:
	if not OS.has_feature("web"):
		_log = WIEventLog.new(QAPaths.out_dir().path_join("events.jsonl"))


## Logs and re-emits a domain event.
func emit_domain_event(type: String, payload: Dictionary = {}) -> void:
	if _log != null:
		_log.append(type, payload)
	domain_event.emit(type, payload)
