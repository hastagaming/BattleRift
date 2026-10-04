class_name WeaponSelect
extends Control

signal confirmed(weapon_id: String)

var _selected: String = ""
var _info: Label
var _confirm: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.BG, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Select Weapon"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	var group := ButtonGroup.new()
	var equipped := String(PlayerData.data["equipped"].get("weapon", ""))
	var first_owned := ""
	for weapon_id in WeaponDb.ORDER:
		if not PlayerData.owns("weapon", weapon_id):
			continue
		if first_owned.is_empty():
			first_owned = weapon_id
		var button := Button.new()
		button.text = String(WeaponDb.get_weapon(weapon_id)["name"])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(200.0, 60.0)
		button.pressed.connect(_select.bind(weapon_id))
		grid.add_child(button)
		if weapon_id == equipped:
			button.set_pressed_no_signal(true)
			_selected = weapon_id
	_info = Label.new()
	_info.custom_minimum_size = Vector2(420.0, 0.0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", UiTheme.MUTED)
	column.add_child(_info)
	_confirm = Button.new()
	_confirm.text = "Confirm"
	_confirm.custom_minimum_size = Vector2(0.0, 56.0)
	_confirm.pressed.connect(_on_confirm)
	column.add_child(_confirm)
	if _selected.is_empty():
		_selected = first_owned
		for child in grid.get_children():
			if (child as Button).text == String(WeaponDb.get_weapon(_selected).get("name", "")):
				(child as Button).set_pressed_no_signal(true)
	_refresh()


func _select(weapon_id: String) -> void:
	_selected = weapon_id
	_refresh()


func _refresh() -> void:
	_confirm.disabled = _selected.is_empty()
	if _selected.is_empty():
		_info.text = "You do not own any weapon."
		return
	var weapon := WeaponDb.get_weapon(_selected)
	var kind := String(weapon["kind"]).capitalize()
	_info.text = "%s\nDamage %.1f   Speed %.1f/s   Knockback %.1f" % [kind, float(weapon["damage"]), 1.0 / float(weapon["attack_interval"]), float(weapon["knockback"])]


func _on_confirm() -> void:
	if _selected.is_empty():
		return
	confirmed.emit(_selected)
	queue_free()