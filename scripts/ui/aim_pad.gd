class_name AimPad
extends Control

var _touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and (event.position - (global_position + size * 0.5)).length() <= size.x * 0.5:
				_touch_index = event.index
				queue_redraw()
		elif event.index == _touch_index:
			_touch_index = -1
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		InputHub.add_look(event.relative)


func _draw() -> void:
	var center := size * 0.5
	var radius := size.x * 0.5
	draw_circle(center, radius, Color(UiTheme.TEXT, 0.12 if _touch_index != -1 else 0.05))
	draw_arc(center, radius - 2.0, 0.0, TAU, 48, Color(UiTheme.TEXT, 0.5), 2.0, true)
	var font := ThemeDB.fallback_font
	var font_size := int(clampf(size.x * 0.12, 12.0, 24.0))
	var text_size := font.get_string_size("LOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(center.x - text_size.x * 0.5, center.y + font_size * 0.35), "LOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(UiTheme.TEXT, 0.6))