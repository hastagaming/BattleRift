class_name PlayerInput
extends RefCounted

const JUMP := 1
const DASH := 2
const ATTACK := 4
const SWITCH := 8
const EMOTE := 16
const PET := 32
const ABILITY := 64
const ALL_ACTIONS := 127
const MAX_PITCH := 1.4

var move: Vector2 = Vector2.ZERO
var yaw: float = 0.0
var pitch: float = -0.35
var attack_held: bool = false

var _edges: int = 0
var _captured_frame: int = -1


static func is_single_action(action: int) -> bool:
	return action > 0 and action <= ALL_ACTIONS and (action & (action - 1)) == 0


func press(action: int) -> void:
	_edges |= (action & ALL_ACTIONS)


func take(action: int) -> bool:
	var had := (_edges & action) != 0
	_edges &= ~action
	return had


func clear_edges() -> void:
	_edges = 0


func aim_basis() -> Basis:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0))


func aim_forward() -> Vector3:
	return aim_basis() * Vector3.FORWARD


func apply_state(new_move: Vector2, new_yaw: float, new_pitch: float, held: bool) -> bool:
	if not (is_finite(new_move.x) and is_finite(new_move.y) and is_finite(new_yaw) and is_finite(new_pitch)):
		return false
	move = new_move.limit_length(1.0)
	yaw = wrapf(new_yaw, -PI, PI)
	pitch = clampf(new_pitch, -MAX_PITCH, MAX_PITCH)
	attack_held = held
	return true


func capture_local(camera_yaw: float, camera_pitch: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _captured_frame:
		return
	_captured_frame = frame
	move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	yaw = camera_yaw
	pitch = camera_pitch
	attack_held = Input.is_action_pressed("attack")
	_edges = 0
	if Input.is_action_just_pressed("jump"):
		_edges |= JUMP
	if Input.is_action_just_pressed("dash"):
		_edges |= DASH
	if Input.is_action_just_pressed("attack"):
		_edges |= ATTACK
	if Input.is_action_just_pressed("weapon_switch"):
		_edges |= SWITCH
	if Input.is_action_just_pressed("emote"):
		_edges |= EMOTE
	if Input.is_action_just_pressed("pet_ability"):
		_edges |= PET
	if Input.is_action_just_pressed("ability"):
		_edges |= ABILITY