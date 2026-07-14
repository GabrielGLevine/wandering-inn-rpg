extends SceneTree

var _frames := 0
var _player: AudioStreamPlayer

func _init() -> void:
	var stream: AudioStream = load("res://assets/audio/music/definitely_our_town.ogg")
	if stream == null:
		print("PROBE: stream load FAILED")
		quit(1)
		return
	print("PROBE: stream loaded, length=", stream.get_length())
	_player = AudioStreamPlayer.new()
	root.add_child(_player)
	_player.stream = stream
	_player.volume_db = 0.0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_player.play()
		print("PROBE: play() called in tree, playing=", _player.playing)
	if _frames % 30 == 0:
		var peak := AudioServer.get_bus_peak_volume_left_db(0, 0)
		print("PROBE frame=", _frames, " playing=", _player.playing, " master_peak_db=", peak)
	if _frames >= 240:
		var final_peak := AudioServer.get_bus_peak_volume_left_db(0, 0)
		print("PROBE FINAL master_peak_db=", final_peak, " => ", "AUDIBLE" if final_peak > -200.0 else "SILENT")
		quit(0)
		return true
	return false
