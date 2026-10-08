class_name PetNode
extends Node3D

var follow_target: Node3D
var idle_position: Vector3 = Vector3.ZERO

var _pet_id: String = ""
var _visual: Node3D
var _time: float = 0.0
var _pop: float = 0.0
var _initialized: bool = false


func setup(pet_id: String) -> void:
	if pet_id == _pet_id and (_visual != null or pet_id.is_empty()):
		return
	_pet_id = pet_id
	if _visual != null:
		_visual.queue_free()
		_visual = null
	if pet_id.is_empty() or not PetDb.has(pet_id):
		_pet_id = ""
		visible = false
		return
	_visual = PetVisuals.build(pet_id)
	add_child(_visual)
	visible = true
	_initialized = false


func pulse() -> void:
	_pop = 1.0


func _process(delta: float) -> void:
	if _visual == null:
		return
	_time += delta
	_pop = maxf(_pop - delta * 3.0, 0.0)
	var bob := sin(_time * 3.0) * 0.08
	if follow_target != null and is_instance_valid(follow_target):
		var shown := true
		if follow_target is PlayerController:
			shown = (follow_target as PlayerController).is_active
		else:
			shown = follow_target.visible
		visible = shown
		var angle := _time * 0.9
		var goal := follow_target.global_position + Vector3(cos(angle) * 1.1, 1.25 + bob, sin(angle) * 1.1)
		if not _initialized:
			global_position = goal
			_initialized = true
		else:
			global_position = global_position.lerp(goal, 1.0 - exp(-6.0 * delta))
		var look_point := follow_target.global_position + Vector3(0.0, 1.0, 0.0)
		if look_point.distance_to(global_position) > 0.1:
			look_at(look_point, Vector3.UP)
	else:
		position = idle_position + Vector3(0.0, bob, 0.0)
	_visual.scale = Vector3.ONE * (1.0 + 0.45 * _pop)