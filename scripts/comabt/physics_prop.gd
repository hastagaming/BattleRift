class_name PhysicsProp
extends RigidBody3D

const KILL_Y := -25.0

var _home: Transform3D = Transform3D.IDENTITY


static func create(kind: String, size: float, color: Color, spawn_position: Vector3) -> PhysicsProp:
	var prop := PhysicsProp.new()
	prop.position = spawn_position
	prop.mass = 3.0 * size * size * size
	prop.collision_layer = PhysicsLayers.PROPS
	prop.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PROPS | PhysicsLayers.PLAYER | PhysicsLayers.RAGDOLL
	var shape: Shape3D
	var mesh: Mesh
	if kind == "ball":
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = size * 0.5
		shape = sphere_shape
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = size * 0.5
		sphere_mesh.height = size
		mesh = sphere_mesh
	else:
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3.ONE * size
		shape = box_shape
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3.ONE * size
		mesh = box_mesh
	var collider := CollisionShape3D.new()
	collider.shape = shape
	prop.add_child(collider)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	prop.add_child(visual)
	return prop


func _ready() -> void:
	_home = global_transform


func apply_hit(hit: Dictionary) -> void:
	apply_central_impulse(CombatResolver.raw_impulse(hit) * mass)
	apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * mass)


func _physics_process(_delta: float) -> void:
	if global_position.y >= KILL_Y:
		return
	var body := get_rid()
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, _home)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)