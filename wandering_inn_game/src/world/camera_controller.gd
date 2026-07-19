class_name WICameraController
extends RefCounted

## Issue #194b seam 2: world.gd's camera/clamp block moved VERBATIM. Owns the
## Camera2D positioning math + the one-slot pan tween; world.gd keeps thin
## wrappers (same names — board_renderer calls enter/exit through them) and
## still supplies sim reads (grid_size/player_cell) + the QA-paced duration.
## Tweens are created via the camera node itself (`_camera.create_tween()`),
## so the controller needs no tree presence of its own.

var _camera: Camera2D
var _cell: float
var _view_size: Vector2
var _camera_tween: Tween


func _init(camera: Camera2D, cell_px: float, view_size: Vector2) -> void:
	_camera = camera
	_cell = cell_px
	_view_size = view_size


func update(grid_size: Vector2i, player_cell: Vector2i) -> void:
	kill_tween()
	var content_size := Vector2(grid_size) * _cell
	var focus := Vector2(player_cell) * _cell + Vector2(_cell, _cell) * 0.5
	_camera.position = Vector2(
		axis(content_size.x, _view_size.x, focus.x),
		axis(content_size.y, _view_size.y, focus.y)
	)


static func axis(content: float, view: float, focus: float) -> float:
	if content <= view:
		return content * 0.5
	return clampf(focus, view * 0.5, content - view * 0.5)


func pan_to(grid_size: Vector2i, player_cell: Vector2i, duration: float) -> void:
	if duration <= 0.0:
		update(grid_size, player_cell)
		return
	var content_size := Vector2(grid_size) * _cell
	var focus := Vector2(player_cell) * _cell + Vector2(_cell, _cell) * 0.5
	var target := Vector2(
		axis(content_size.x, _view_size.x, focus.x),
		axis(content_size.y, _view_size.y, focus.y)
	)
	kill_tween()
	_camera_tween = _camera.create_tween()
	_camera_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(_camera, "position", target, duration)


## Mirrors `_kill_player_tween`'s one-slot-not-two idiom
## for the camera pan tween -- a move landing while the previous step's pan is
## still finishing must kill it first, or two tweens fight over
## `_camera.position` for up to ~0.12s.
func kill_tween() -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()


func enter_combat(grid_size: Vector2i) -> void:
	kill_tween()
	var content_size := Vector2(grid_size) * _cell
	_camera.position = Vector2(
		axis(content_size.x, _view_size.x, content_size.x * 0.5),
		axis(content_size.y, _view_size.y, content_size.y * 0.5)
	)
