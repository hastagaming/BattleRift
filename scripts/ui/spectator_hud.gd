class_name SpectatorHud
extends Control

var spectator: Spectator

var _pad: Control
var _prev: Button
var _next: Button
var _label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_outline_color", UiTheme.BG)
	add_child(_label)
	_pad = Control.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)
	_prev = Button.new()
	_prev.text = "<"
	_prev.pressed.connect(func() -> void: spectator.cycle(-1))
	_pad.add_child(_prev)
	_next = Button.new()
	_next.text = ">"
	_next.pressed.connect(func() -> void: spectator.cycle(1))
	_pad.add_child(_next)
	spectator.active_changed.connect(_on_active_changed)
	spectator.target_changed.connect(func(_peer_id: int) -> void: _refresh())
	ControlLayout.layout_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()


func _on_active_changed(active: bool) -> void:
	visible = active
	_refresh()


func _refresh() -> void:
	if spectator.target_peer >= 0:
		_label.text = "SPECTATING  %s" % spectator.target_name()
	else:
		_label.text = "NO ONE TO SPECTATE"
	_layout.call_deferred()


func _layout() -> void:
	var area := ControlLayout.get_safe_area_rect(get_viewport())
	ControlLayout.apply_to_control(_pad, "spectator_controls", area)
	var width := _pad.size.x
	var height := width * 0.42
	_pad.position.y += (_pad.size.y - height) * 0.5
	_pad.size = Vector2(width, height)
	var half := width * 0.5 - 4.0
	_prev.position = Vector2.ZERO
	_prev.size = Vector2(half, height)
	_next.position = Vector2(width * 0.5 + 4.0, 0.0)
	_next.size = Vector2(half, height)
	var label_size := _label.get_combined_minimum_size()
	_label.size = label_size
	_label.position = Vector2(area.position.x + (area.size.x - label_size.x) * 0.5, area.position.y + 120.0)