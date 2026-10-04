class_name CombatHud
extends Control

var player: PlayerController
var touch_hud: Control

var _panel: PanelContainer
var _weapon_label: Label
var _damage_label: Label
var _editor: ControlEditor
var _hud_was_visible: bool = false
var _player_was_controllable: bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_panel.add_child(row)
	_weapon_label = Label.new()
	row.add_child(_weapon_label)
	_damage_label = Label.new()
	row.add_child(_damage_label)
	var controls_button := Button.new()
	controls_button.text = "Controls"
	controls_button.pressed.connect(_open_editor)
	row.add_child(controls_button)
	add_child(_panel)
	player.weapons.weapon_changed.connect(_on_weapon_changed)
	player.damage_changed.connect(_on_damage_changed)
	get_viewport().size_changed.connect(_layout)
	_on_weapon_changed(player.weapons.current_id)
	_on_damage_changed(player.damage_percent)


func _layout() -> void:
	var area := ControlLayout.get_safe_area_rect(get_viewport())
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	_panel.position = Vector2(area.end.x - panel_size.x - 12.0, area.position.y + 68.0)


func _on_weapon_changed(weapon_id: String) -> void:
	_weapon_label.text = String(WeaponDb.get_weapon(weapon_id).get("name", "Unarmed"))
	_layout.call_deferred()


func _on_damage_changed(percent: float) -> void:
	_damage_label.text = "DMG %d%%" % roundi(percent)
	_damage_label.add_theme_color_override("font_color", UiTheme.TEXT.lerp(UiTheme.DANGER, clampf(percent / 150.0, 0.0, 1.0)))
	_layout.call_deferred()


func _open_editor() -> void:
	if _editor != null:
		return
	_hud_was_visible = touch_hud.visible
	touch_hud.visible = false
	_player_was_controllable = player.controllable
	player.controllable = false
	_editor = ControlEditor.new()
	_editor.closed.connect(_on_editor_closed)
	get_parent().add_child(_editor)


func _on_editor_closed() -> void:
	_editor = null
	touch_hud.visible = _hud_was_visible
	player.controllable = true