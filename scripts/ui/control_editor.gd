class_name ControlEditor
extends Control

signal closed

const SHORT_LABELS := {
	"move_joystick": "MOVE",
	"aim_control": "LOOK",
	"attack": "ATK",
	"weapon_switch": "SWAP",
	"jump": "JUMP",
	"dash": "DASH",
	"ability": "SKILL",
	"pet_ability": "PET",
	"emote": "EMOTE",
	"interact": "USE",
	"minimap": "MAP",
	"spectator_controls": "SPEC",
}

var _handles: Dictionary = {}
var _preset_buttons: Dictionary = {}
var _selected: String = ""
var _area: Rect2 = Rect2()
var _dock_top: bool = true
var _panel: PanelContainer
var _title: Label
var _size_slider: HSlider
var _opacity_slider: HSlider


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.BG, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	for id in ControlLayout.ELEMENTS:
		var handle := ControlEditHandle.new()
		handle.element_id = id
		handle.label_text = String(SHORT_LABELS.get(id, "?"))
		handle.rectangular = id == "minimap"
		handle.selected.connect(_select)
		handle.moved.connect(_on_moved)
		handle.released.connect(_commit)
		add_child(handle)
		_handles[id] = handle
	_build_panel()
	ControlLayout.layout_changed.connect(_sync_handles)
	get_viewport().size_changed.connect(_sync_handles)
	_sync_handles()
	_select("move_joystick")
	_layout_panel()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	_title = Label.new()
	column.add_child(_title)
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for preset in ControlLayout.PRESETS:
		var button := Button.new()
		button.text = String(preset).capitalize()
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_preset_pressed.bind(preset))
		presets.add_child(button)
		_preset_buttons[preset] = button
	column.add_child(presets)
	_size_slider = _make_slider(column, "Size", 1.0)
	_size_slider.value_changed.connect(_on_size_changed)
	_opacity_slider = _make_slider(column, "Opacity", 0.01)
	_opacity_slider.min_value = ControlLayout.MIN_OPACITY
	_opacity_slider.max_value = 1.0
	_opacity_slider.value_changed.connect(_on_opacity_changed)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.add_child(_make_action("Reset", _on_reset_pressed))
	actions.add_child(_make_action("Move Panel", _on_dock_pressed))
	actions.add_child(_make_action("Done", _close))
	column.add_child(actions)
	add_child(_panel)


func _make_slider(parent: Control, caption: String, step: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(96.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0.0, 36.0)
	slider.drag_ended.connect(_on_slider_released)
	row.add_child(slider)
	parent.add_child(row)
	return slider


func _make_action(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _layout_panel() -> void:
	var width := minf(520.0, _area.size.x - 24.0)
	_panel.custom_minimum_size = Vector2(width, 0.0)
	_panel.reset_size()
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	var x := _area.position.x + (_area.size.x - panel_size.x) * 0.5
	var y := _area.position.y + 8.0 if _dock_top else _area.end.y - panel_size.y - 8.0
	_panel.position = Vector2(x, y)


func _sync_handles() -> void:
	_area = ControlLayout.get_safe_area_rect(get_viewport())
	for id in _handles:
		var handle: ControlEditHandle = _handles[id]
		ControlLayout.apply_to_control(handle, id, _area)
		handle.opacity = handle.modulate.a
		handle.modulate.a = 1.0
		handle.queue_redraw()
	var active := ControlLayout.get_active_preset()
	if _preset_buttons.has(active):
		(_preset_buttons[active] as Button).set_pressed_no_signal(true)
	if _selected != "":
		var current: ControlEditHandle = _handles[_selected]
		_size_slider.set_value_no_signal(current.size.x)
		_opacity_slider.set_value_no_signal(current.opacity)
	if _panel != null:
		_layout_panel()


func _select(id: String) -> void:
	_selected = id
	for key in _handles:
		var handle: ControlEditHandle = _handles[key]
		handle.is_selected = key == id
		handle.queue_redraw()
	var limits: Dictionary = ControlLayout.ELEMENTS[id]
	_size_slider.min_value = float(limits["min"])
	_size_slider.max_value = float(limits["max"])
	var current: ControlEditHandle = _handles[id]
	_size_slider.set_value_no_signal(current.size.x)
	_opacity_slider.set_value_no_signal(current.opacity)
	_title.text = "Editing: %s" % String(limits["label"])
	current.move_to_front()
	_panel.move_to_front()


func _on_moved(id: String, center: Vector2) -> void:
	var handle: ControlEditHandle = _handles[id]
	var clamped := Vector2(
		clampf(center.x, _area.position.x, _area.end.x),
		clampf(center.y, _area.position.y, _area.end.y)
	)
	handle.position = clamped - handle.size * 0.5


func _on_size_changed(value: float) -> void:
	if _selected == "":
		return
	var handle: ControlEditHandle = _handles[_selected]
	var center := handle.position + handle.size * 0.5
	handle.size = Vector2(value, value)
	handle.position = center - handle.size * 0.5
	handle.queue_redraw()


func _on_opacity_changed(value: float) -> void:
	if _selected == "":
		return
	var handle: ControlEditHandle = _handles[_selected]
	handle.opacity = value
	handle.queue_redraw()


func _on_slider_released(_value_changed: bool) -> void:
	if _selected != "":
		_commit(_selected)


func _commit(id: String) -> void:
	var handle: ControlEditHandle = _handles[id]
	var center := handle.position + handle.size * 0.5
	ControlLayout.set_element(
		id,
		(center.x - _area.position.x) / _area.size.x,
		(center.y - _area.position.y) / _area.size.y,
		handle.size.x,
		handle.opacity
	)


func _on_preset_pressed(preset: String) -> void:
	ControlLayout.set_active_preset(preset)


func _on_reset_pressed() -> void:
	ControlLayout.reset_custom(ControlLayout.PRESET_DEFAULT)


func _on_dock_pressed() -> void:
	_dock_top = not _dock_top
	_layout_panel()


func _close() -> void:
	closed.emit()
	queue_free()