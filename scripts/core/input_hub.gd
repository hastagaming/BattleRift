extends Node

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"dash": [KEY_SHIFT],
	"attack": [KEY_F],
	"interact": [KEY_G],
	"ability": [KEY_Q],
	"pet_ability": [KEY_R],
	"weapon_switch": [KEY_TAB],
	"emote": [KEY_E],
}

var look_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for keycode in ACTIONS[action]:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode as Key
			InputMap.action_add_event(action, key_event)


func add_look(relative: Vector2) -> void:
	look_delta += relative


func consume_look() -> Vector2:
	var result := look_delta
	look_delta = Vector2.ZERO
	return result


func set_move(vector: Vector2) -> void:
	_set_axis("move_left", "move_right", vector.x)
	_set_axis("move_forward", "move_back", vector.y)


func _set_axis(negative: String, positive: String, value: float) -> void:
	if value < 0.0:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	elif value > 0.0:
		Input.action_press(positive, value)
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)