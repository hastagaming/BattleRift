class_name EmotePicker
extends Control

signal picked(emote_id: String)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.BG, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Emotes"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	var owned: Array = PlayerData.data["inventory"].get("emote", [])
	for emote_id in CharacterModel.EMOTES:
		if emote_id not in owned and emote_id not in CharacterModel.STARTER_EMOTES:
			continue
		var button := Button.new()
		button.text = ItemDb.display_name(emote_id)
		button.custom_minimum_size = Vector2(150.0, 64.0)
		button.add_theme_color_override("font_color", ItemDb.color_of(emote_id))
		button.pressed.connect(_on_pick.bind(emote_id))
		grid.add_child(button)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0.0, 48.0)
	close.pressed.connect(queue_free)
	column.add_child(close)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()


func _on_pick(emote_id: String) -> void:
	PlayerData.equip("emote", emote_id)
	picked.emit(emote_id)
	queue_free()