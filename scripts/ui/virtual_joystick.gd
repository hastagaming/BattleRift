class_name VirtualJoystick
extends Control

const DEADZONE := 0.15

var _touch_index: int = -1
var _vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _exit_tree() -> void:
	if _touch_index != -1:
		InputHub.set_move(Vector2.ZERO)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and _contains(event.position):
				_touch_index = event.index
				_update(event.position)
		elif event.index == _touch_index:
			_touch_index = -1
			_vector = Vector2.ZERO
			InputHub.set_move(Vector2.ZERO)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update(event.position)


func _contains(point: Vector2) -> bool:
	return (point - (global_position + size * 0.5)).length() <= size.x * 0.5


func _update(point: Vector2) -> void:
	var offset := (point - (global_position + size * 0.5)) / (size.x * 0.5)
	if offset.length() > 1.0:
		offset = offset.normalized()
	_vector = offset
	InputHub.set_move(offset if offset.length() >= DEADZONE else Vector2.ZERO)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := size.x * 0.5
	var knob_radius := radius * 0.38
	draw_circle(center, radius, Color(UiTheme.ACCENT, 0.12))
	draw_arc(center, radius - 2.0, 0.0, TAU, 48, UiTheme.ACCENT, 3.0, true)
	draw_circle(center + _vector * (radius - knob_radius), knob_radius, Color(UiTheme.ACCENT, 0.55))