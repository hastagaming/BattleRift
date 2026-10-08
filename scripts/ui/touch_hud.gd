class_name TouchHud
extends Control

const BUTTONS := {
	"attack": {"action": "attack", "label": "ATK"},
	"weapon_switch": {"action": "weapon_switch", "label": "SWAP"},
	"jump": {"action": "jump", "label": "JUMP"},
	"dash": {"action": "dash", "label": "DASH"},
	"ability": {"action": "ability", "label": "SKILL"},
	"pet_ability": {"action": "pet_ability", "label": "PET"},
	"emote": {"action": "emote", "label": "EMOTE"},
	"interact": {"action": "interact", "label": "USE"},
}

var elements: Array = []

var _widgets: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for element_id in elements:
		var widget := _create_widget(String(element_id))
		if widget == null:
			continue
		widget.name = String(element_id)
		add_child(widget)
		_widgets[String(element_id)] = widget
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.is_debug_build()
	ControlLayout.layout_changed.connect(_relayout)
	get_viewport().size_changed.connect(_relayout)
	_relayout.call_deferred()


func _create_widget(element_id: String) -> Control:
	match element_id:
		"move_joystick":
			return VirtualJoystick.new()
		"aim_control":
			return AimPad.new()
	if BUTTONS.has(element_id):
		var button := TouchButton.new()
		button.action = StringName(BUTTONS[element_id]["action"])
		button.label = String(BUTTONS[element_id]["label"])
		return button
	return null


func _relayout() -> void:
	var area := ControlLayout.get_safe_area_rect(get_viewport())
	for element_id in _widgets:
		var widget: Control = _widgets[element_id]
		ControlLayout.apply_to_control(widget, element_id, area)
		widget.queue_redraw()


func set_cooldown(element_id: String, ratio: float) -> void:
	var widget: Variant = _widgets.get(element_id)
	if widget is TouchButton:
		(widget as TouchButton).set_cooldown(ratio)