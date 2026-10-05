class_name Ragdoll
extends Node3D

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_RAGDOLL := 4
const LAYER_PROPS := 8

var _torso: RigidBody3D
var _bodies: Array[RigidBody3D] = []


static func spawn(parent: Node, source: Node3D, initial_velocity: Vector3, skin: Color, accent: Color) -> Ragdoll:
	var ragdoll := Ragdoll.new()
	parent.add_child(ragdoll)
	ragdoll._build(source.global_transform, initial_velocity, skin, accent)
	return ragdoll


func torso_position() -> Vector3:
	return _torso.global_position


func torso_transform() -> Transform3D:
	return _torso.global_transform


func is_settled() -> bool:
	return _torso.linear_velocity.length() < 0.5 and _torso.angular_velocity.length() < 1.0


func _build(origin: Transform3D, velocity: Vector3, skin: Color, accent: Color) -> void:
	var torso_box := BoxShape3D.new()
	torso_box.size = CharacterModel.TORSO_SIZE
	_torso = _create_body("Torso", torso_box, _box_mesh(CharacterModel.TORSO_SIZE), Vector3(0.0, CharacterModel.TORSO_Y, 0.0), origin, accent, 3.0, velocity)
	var head_shape := SphereShape3D.new()
	head_shape.radius = CharacterModel.HEAD_RADIUS
	var head_mesh := SphereMesh.new()
	head_mesh.radius = CharacterModel.HEAD_RADIUS
	head_mesh.height = CharacterModel.HEAD_RADIUS * 2.0
	var head := _create_body("Head", head_shape, head_mesh, Vector3(0.0, CharacterModel.HEAD_Y, 0.0), origin, skin, 1.0, velocity)
	_join(_torso, head, origin, Vector3(0.0, 1.42, 0.0), 40.0, 40.0)
	var arm_y := CharacterModel.SHOULDER_Y - CharacterModel.ARM_SIZE.y * 0.5
	var leg_y := CharacterModel.HIP_Y - CharacterModel.LEG_SIZE.y * 0.5
	for side in [-1.0, 1.0]:
		var arm_shape := BoxShape3D.new()
		arm_shape.size = CharacterModel.ARM_SIZE
		var arm := _create_body("Arm%d" % int(side), arm_shape, _box_mesh(CharacterModel.ARM_SIZE), Vector3(CharacterModel.SHOULDER_X * side, arm_y, 0.0), origin, skin, 0.8, velocity)
		_join(_torso, arm, origin, Vector3(CharacterModel.SHOULDER_X * side, CharacterModel.SHOULDER_Y, 0.0), 80.0, 40.0)
		var leg_shape := BoxShape3D.new()
		leg_shape.size = CharacterModel.LEG_SIZE
		var leg := _create_body("Leg%d" % int(side), leg_shape, _box_mesh(CharacterModel.LEG_SIZE), Vector3(CharacterModel.HIP_X * side, leg_y, 0.0), origin, accent.darkened(0.55), 1.2, velocity)
		_join(_torso, leg, origin, Vector3(CharacterModel.HIP_X * side, CharacterModel.HIP_Y, 0.0), 50.0, 20.0)
	for i in _bodies.size():
		for j in range(i + 1, _bodies.size()):
			_bodies[i].add_collision_exception_with(_bodies[j])
	_torso.angular_velocity = Vector3(velocity.z, 0.0, -velocity.x) * 0.4


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _create_body(part_name: String, shape: Shape3D, mesh: Mesh, local_position: Vector3, origin: Transform3D, color: Color, mass: float, velocity: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = part_name
	body.mass = mass
	body.collision_layer = LAYER_RAGDOLL
	body.collision_mask = LAYER_WORLD | LAYER_RAGDOLL | LAYER_PROPS
	body.linear_damp = 0.2
	body.angular_damp = 1.2
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
	body.global_transform = Transform3D(origin.basis, origin * local_position)
	body.linear_velocity = velocity
	_bodies.append(body)
	return body


func _join(body_a: RigidBody3D, body_b: RigidBody3D, origin: Transform3D, local_position: Vector3, swing_degrees: float, twist_degrees: float) -> void:
	var joint := ConeTwistJoint3D.new()
	add_child(joint)
	joint.global_transform = Transform3D(origin.basis * Basis(Vector3.BACK, PI / 2.0), origin * local_position)
	joint.node_a = body_a.get_path()
	joint.node_b = body_b.get_path()
	joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(swing_degrees))
	joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(twist_degrees))


func apply_hit(hit: Dictionary) -> void:
	_torso.apply_central_impulse(CombatResolver.raw_impulse(hit) * _torso.mass)