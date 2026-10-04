class_name ControlEditHandle
extends Control

signal selected(id: String)
signal moved(id: String, center: Vector2)
signal released(id: String)

var element_id: String = ""
var label_text: String = ""
var is_selected: bool = false
var opacity: float = 1.0
var rectangular: bool = false

var _dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_grab_offset = global_position + size * 0.5 - event.global_position
			selected.emit(element_id)
		elif _dragging:
			_dragging = false
			released.emit(element_id)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		moved.emit(element_id, event.global_position + _grab_offset)
		accept_event()


func _draw() -> void:
	var center := size * 0.5
	var fill := Color(UiTheme.ACCENT, 0.12 + 0.5 * opacity)
	var outline := UiTheme.GOLD if is_selected else Color(UiTheme.TEXT, 0.85)
	var line_width := 3.0 if is_selected else 2.0
	if rectangular:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, fill, true)
		draw_rect(rect, outline, false, line_width)
	else:
		var radius := size.x * 0.5
		draw_circle(center, radius, fill)
		draw_arc(center, radius - 2.0, 0.0, TAU, 48, outline, line_width, true)
	var font := ThemeDB.fallback_font
	var font_size := int(clampf(size.x * 0.16, 11.0, 24.0))
	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(center.x - text_size.x * 0.5, center.y + font_size * 0.35), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiTheme.TEXT)