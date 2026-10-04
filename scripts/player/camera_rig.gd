class_name CameraRig
extends Node3D

@export var distance: float = 5.5
@export var height: float = 1.4
@export var sensitivity: float = 0.005
@export var min_pitch: float = -1.2
@export var max_pitch: float = 0.5

var target: Node3D
var yaw: float = 0.0
var pitch: float = -0.35

var _camera: Camera3D


func _ready() -> void:
	top_level = true
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 0.0, distance)
	_camera.fov = 70.0
	add_child(_camera)
	_camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		InputHub.add_look(event.relative)


func _process(delta: float) -> void:
	var look := InputHub.consume_look()
	yaw -= look.x * sensitivity
	pitch = clampf(pitch - look.y * sensitivity, min_pitch, max_pitch)
	if target != null and is_instance_valid(target):
		var goal := target.global_position + Vector3(0.0, height, 0.0)
		global_position = global_position.lerp(goal, 1.0 - exp(-12.0 * delta))
	rotation = Vector3(pitch, yaw, 0.0)