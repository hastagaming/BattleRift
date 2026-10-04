class_name Projectile
extends RigidBody3D

var weapon_id: String = ""
var weapon: Dictionary = {}
var shooter: Node3D

var _pivot: Node3D
var _age: float = 0.0
var _spent: bool = false
var _impact_body: Node
var _impact_point: Vector3 = Vector3.ZERO
var _impact_velocity: Vector3 = Vector3.ZERO


static func launch(parent: Node, shooter_body: Node3D, id: String, origin: Vector3, direction: Vector3) -> Projectile:
	var projectile := Projectile.new()
	projectile.weapon_id = id
	projectile.weapon = WeaponDb.get_weapon(id)
	projectile.shooter = shooter_body
	parent.add_child(projectile)
	projectile.global_position = origin
	projectile.linear_velocity = direction.normalized() * float(projectile.weapon["projectile_speed"])
	return projectile


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.HITTABLE
	mass = float(weapon["projectile_mass"])
	gravity_scale = float(weapon["gravity"])
	continuous_cd = true
	lock_rotation = true
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 4
	var shape := SphereShape3D.new()
	shape.radius = float(weapon["projectile_radius"])
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	if shooter is PhysicsBody3D:
		add_collision_exception_with(shooter)
	_pivot = Node3D.new()
	add_child(_pivot)
	_build_visual()
	body_entered.connect(_on_body_entered)


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh


func _cone(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _add_mesh(mesh: Mesh, color: Color, offset_z: float, emissive: bool, tip_forward: bool = false) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(0.0, 0.0, offset_z)
	instance.rotation_degrees = Vector3(-90.0 if tip_forward else 90.0, 0.0, 0.0)
	_pivot.add_child(instance)


func _build_visual() -> void:
	var color: Color = weapon["color"]
	match String(weapon["projectile_shape"]):
		"arrow":
			_add_mesh(_cylinder(0.015, 0.7), Color("#d9c9a8"), 0.0, false)
			_add_mesh(_cone(0.04, 0.12), color, -0.38, true, true)
		"bolt":
			_add_mesh(_sphere(0.1), color, 0.0, true)
		"rocket":
			_add_mesh(_cylinder(0.09, 0.5), color, 0.0, false)
			_add_mesh(_sphere(0.1), Color("#ffb347"), 0.3, true)


func _process(_delta: float) -> void:
	if _spent:
		return
	var speed := linear_velocity.length()
	if speed < 0.5:
		return
	var direction := linear_velocity / speed
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	_pivot.look_at(_pivot.global_position + direction, up)


func _physics_process(delta: float) -> void:
	if _spent:
		_resolve_impact()
		return
	_age += delta
	if _age >= float(weapon["lifetime"]):
		_spent = true
		_impact_point = global_position
		_impact_body = null
		_impact_velocity = linear_velocity


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	_spent = true
	_impact_body = body
	_impact_point = global_position
	_impact_velocity = linear_velocity


func _resolve_impact() -> void:
	var parent := get_parent()
	if float(weapon["explosion_radius"]) > 0.0:
		_explode(parent)
	elif is_instance_valid(_impact_body):
		var target := CombatResolver.resolve_target(_impact_body)
		if target != null and target != shooter:
			var direction := _impact_velocity.normalized() if _impact_velocity.length() > 0.01 else Vector3.FORWARD
			CombatResolver.deliver(target, CombatResolver.make_hit(weapon, weapon_id, direction, shooter))
	queue_free()


func _explode(parent: Node) -> void:
	var radius := float(weapon["explosion_radius"])
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, _impact_point)
	params.collision_mask = PhysicsLayers.HITTABLE
	var done := {}
	for result in get_world_3d().direct_space_state.intersect_shape(params, 32):
		var collider := result["collider"] as Node3D
		if collider == null:
			continue
		var target := CombatResolver.resolve_target(collider)
		if target == null or done.has(target.get_instance_id()):
			continue
		done[target.get_instance_id()] = true
		var center := collider.global_position
		if target is PlayerController:
			center += Vector3(0.0, 0.9, 0.0)
		var offset := center - _impact_point
		var falloff := lerpf(1.0, 0.2, clampf(offset.length() / radius, 0.0, 1.0))
		var hit := CombatResolver.make_hit(weapon, weapon_id, offset, shooter)
		for key in ["damage", "knockback", "lift"]:
			hit[key] = float(hit[key]) * falloff
		if target == shooter:
			hit["damage"] = 0.0
			hit["knockback"] = float(hit["knockback"]) * 0.6
			hit["lift"] = float(hit["lift"]) * 0.6
		CombatResolver.deliver(target, hit)
	_spawn_blast(parent, radius)


func _spawn_blast(parent: Node, radius: float) -> void:
	if parent == null:
		return
	var color: Color = weapon["color"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var blast := MeshInstance3D.new()
	blast.mesh = mesh
	blast.material_override = material
	blast.scale = Vector3.ONE * 0.2
	parent.add_child(blast)
	blast.global_position = _impact_point
	var tween := blast.create_tween()
	tween.set_parallel(true)
	tween.tween_property(blast, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(blast.queue_free)