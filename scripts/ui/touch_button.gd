class_name TouchButton
extends Control

var action: StringName = &""
var label: String = ""

var _touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _exit_tree() -> void:
	if _touch_index != -1:
		Input.action_release(action)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event is not InputEventScreenTouch:
		return
	if event.pressed:
		if _touch_index == -1 and (event.position - (global_position + size * 0.5)).length() <= size.x * 0.5:
			_touch_index = event.index
			Input.action_press(action)
			queue_redraw()
	elif event.index == _touch_index:
		_touch_index = -1
		Input.action_release(action)
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := size.x * 0.5
	draw_circle(center, radius, Color(UiTheme.ACCENT, 0.4 if _touch_index != -1 else 0.16))
	draw_arc(center, radius - 2.0, 0.0, TAU, 48, UiTheme.ACCENT, 3.0, true)
	var font := ThemeDB.fallback_font
	var font_size := int(clampf(size.x * 0.22, 11.0, 28.0))
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(center.x - text_size.x * 0.5, center.y + font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiTheme.TEXT)