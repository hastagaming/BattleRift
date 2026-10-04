extends Node

signal layout_changed

const SETTING_KEY := "control_layout"
const PRESET_DEFAULT := "default"
const PRESET_CLAW := "claw"
const PRESET_CUSTOM := "custom"
const PRESETS: Array[String] = ["default", "claw", "custom"]
const MIN_OPACITY := 0.1

const ELEMENTS := {
	"move_joystick": {"label": "Movement", "min": 96.0, "max": 320.0},
	"aim_control": {"label": "Camera / Aim", "min": 96.0, "max": 400.0},
	"attack": {"label": "Attack", "min": 56.0, "max": 200.0},
	"weapon_switch": {"label": "Weapon Switch", "min": 48.0, "max": 140.0},
	"jump": {"label": "Jump", "min": 48.0, "max": 160.0},
	"dash": {"label": "Dash", "min": 48.0, "max": 140.0},
	"ability": {"label": "Ability", "min": 48.0, "max": 160.0},
	"pet_ability": {"label": "Pet Ability", "min": 48.0, "max": 140.0},
	"emote": {"label": "Emote", "min": 40.0, "max": 120.0},
	"interact": {"label": "Interact", "min": 48.0, "max": 140.0},
	"minimap": {"label": "Minimap", "min": 96.0, "max": 360.0},
	"spectator_controls": {"label": "Spectator", "min": 80.0, "max": 240.0},
}

const PRESET_LAYOUTS := {
	"default": {
		"move_joystick": {"x": 0.13, "y": 0.70, "size": 180.0, "opacity": 0.7},
		"aim_control": {"x": 0.72, "y": 0.45, "size": 200.0, "opacity": 0.25},
		"attack": {"x": 0.90, "y": 0.72, "size": 110.0, "opacity": 0.85},
		"weapon_switch": {"x": 0.76, "y": 0.76, "size": 68.0, "opacity": 0.8},
		"jump": {"x": 0.82, "y": 0.88, "size": 84.0, "opacity": 0.8},
		"dash": {"x": 0.94, "y": 0.50, "size": 72.0, "opacity": 0.8},
		"ability": {"x": 0.66, "y": 0.88, "size": 76.0, "opacity": 0.8},
		"pet_ability": {"x": 0.57, "y": 0.88, "size": 68.0, "opacity": 0.8},
		"emote": {"x": 0.50, "y": 0.10, "size": 60.0, "opacity": 0.7},
		"interact": {"x": 0.70, "y": 0.66, "size": 68.0, "opacity": 0.8},
		"minimap": {"x": 0.10, "y": 0.20, "size": 140.0, "opacity": 0.8},
		"spectator_controls": {"x": 0.50, "y": 0.90, "size": 120.0, "opacity": 0.8},
	},
	"claw": {
		"move_joystick": {"x": 0.13, "y": 0.72, "size": 180.0, "opacity": 0.7},
		"aim_control": {"x": 0.78, "y": 0.50, "size": 200.0, "opacity": 0.25},
		"attack": {"x": 0.07, "y": 0.36, "size": 100.0, "opacity": 0.85},
		"weapon_switch": {"x": 0.20, "y": 0.30, "size": 64.0, "opacity": 0.8},
		"jump": {"x": 0.91, "y": 0.76, "size": 92.0, "opacity": 0.8},
		"dash": {"x": 0.91, "y": 0.56, "size": 72.0, "opacity": 0.8},
		"ability": {"x": 0.80, "y": 0.88, "size": 76.0, "opacity": 0.8},
		"pet_ability": {"x": 0.70, "y": 0.88, "size": 68.0, "opacity": 0.8},
		"emote": {"x": 0.50, "y": 0.10, "size": 60.0, "opacity": 0.7},
		"interact": {"x": 0.30, "y": 0.62, "size": 68.0, "opacity": 0.8},
		"minimap": {"x": 0.36, "y": 0.18, "size": 130.0, "opacity": 0.8},
		"spectator_controls": {"x": 0.50, "y": 0.90, "size": 120.0, "opacity": 0.8},
	},
}

var _active: String = PRESET_DEFAULT
var _custom: Dictionary = {}


func _ready() -> void:
	_custom = _sanitize({}, PRESET_LAYOUTS[PRESET_DEFAULT])
	PlayerData.signed_in.connect(_on_signed_in)
	PlayerData.signed_out.connect(_on_signed_out)


func _on_signed_in(_account: Dictionary) -> void:
	var stored: Variant = PlayerData.get_setting(SETTING_KEY, {})
	var stored_dict: Dictionary = stored if stored is Dictionary else {}
	_custom = _sanitize(stored_dict.get("custom", {}), PRESET_LAYOUTS[PRESET_DEFAULT])
	var preset := String(stored_dict.get("preset", PRESET_DEFAULT))
	_active = preset if preset in PRESETS else PRESET_DEFAULT
	layout_changed.emit()


func _on_signed_out() -> void:
	_active = PRESET_DEFAULT
	_custom = _sanitize({}, PRESET_LAYOUTS[PRESET_DEFAULT])
	layout_changed.emit()


func _sanitize(layout: Variant, fallback: Dictionary) -> Dictionary:
	var source: Dictionary = layout if layout is Dictionary else {}
	var result := {}
	for id in ELEMENTS:
		var limits: Dictionary = ELEMENTS[id]
		var fb: Dictionary = fallback[id]
		var src: Dictionary = source.get(id, {}) if source.get(id, {}) is Dictionary else {}
		result[id] = {
			"x": clampf(float(src.get("x", fb["x"])), 0.02, 0.98),
			"y": clampf(float(src.get("y", fb["y"])), 0.02, 0.98),
			"size": clampf(float(src.get("size", fb["size"])), float(limits["min"]), float(limits["max"])),
			"opacity": clampf(float(src.get("opacity", fb["opacity"])), MIN_OPACITY, 1.0),
		}
	return result


func _layout_for(preset: String) -> Dictionary:
	if preset == PRESET_CUSTOM:
		return _custom
	return PRESET_LAYOUTS[preset]


func _persist() -> void:
	PlayerData.set_setting(SETTING_KEY, {"preset": _active, "custom": _custom})
	layout_changed.emit()


func get_active_preset() -> String:
	return _active


func set_active_preset(preset: String) -> bool:
	if preset not in PRESETS:
		return false
	_active = preset
	_persist()
	return true


func begin_edit() -> void:
	if _active != PRESET_CUSTOM:
		_custom = _layout_for(_active).duplicate(true)
		_active = PRESET_CUSTOM
		_persist()


func reset_custom(from_preset: String = PRESET_DEFAULT) -> bool:
	if from_preset not in [PRESET_DEFAULT, PRESET_CLAW]:
		return false
	_custom = _sanitize(PRESET_LAYOUTS[from_preset], PRESET_LAYOUTS[PRESET_DEFAULT])
	_active = PRESET_CUSTOM
	_persist()
	return true


func get_element(element_id: String) -> Dictionary:
	if not ELEMENTS.has(element_id):
		return {}
	return (_layout_for(_active)[element_id] as Dictionary).duplicate()


func set_element(element_id: String, x: float, y: float, size: float, opacity: float) -> bool:
	if not ELEMENTS.has(element_id):
		return false
	begin_edit()
	var limits: Dictionary = ELEMENTS[element_id]
	_custom[element_id] = {
		"x": clampf(x, 0.02, 0.98),
		"y": clampf(y, 0.02, 0.98),
		"size": clampf(size, float(limits["min"]), float(limits["max"])),
		"opacity": clampf(opacity, MIN_OPACITY, 1.0),
	}
	_persist()
	return true


func get_safe_area_rect(viewport: Viewport) -> Rect2:
	var visible_size: Vector2 = viewport.get_visible_rect().size
	var full := Rect2(Vector2.ZERO, visible_size)
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return full
	var safe := DisplayServer.get_display_safe_area()
	var factor := visible_size / window_size
	var rect := Rect2(Vector2(safe.position) * factor, Vector2(safe.size) * factor)
	var clipped := full.intersection(rect)
	if clipped.size.x < visible_size.x * 0.5 or clipped.size.y < visible_size.y * 0.5:
		return full
	return clipped


func apply_to_control(control: Control, element_id: String, area: Rect2) -> bool:
	var element := get_element(element_id)
	if element.is_empty():
		return false
	var size_px := float(element["size"])
	control.size = Vector2(size_px, size_px)
	control.position = area.position + Vector2(float(element["x"]) * area.size.x, float(element["y"]) * area.size.y) - control.size * 0.5
	control.modulate.a = float(element["opacity"])
	return true