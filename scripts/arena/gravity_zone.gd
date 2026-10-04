class_name GravityZone
extends Area3D

var gravity_factor: float = 0.3

var _size: Vector3 = Vector3.ONE * 4.0


static func create(size: Vector3, at: Vector3, factor: float) -> GravityZone:
	var zone := GravityZone.new()
	zone._size = size
	zone.position = at
	zone.gravity_factor = factor
	return zone


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER | PhysicsLayers.PROPS | PhysicsLayers.RAGDOLL
	gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * gravity_factor
	var shape := BoxShape3D.new()
	shape.size = _size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	add_child(ArenaUtil.box(_size, Color("#7aa7ff"), false, 0.08))
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		(body as PlayerController).set_gravity_source(get_instance_id(), gravity_factor)


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		(body as PlayerController).clear_gravity_source(get_instance_id())