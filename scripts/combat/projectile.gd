class_name Projectile
extends RigidBody3D

static var _next_id: int = 1

var weapon_id: String = ""
var weapon: Dictionary = {}
var shooter: Node3D
var net_id: int = 0

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
	projectile.net_id = _next_id
	_next_id = _next_id % 1000000 + 1
	parent.add_child(projectile)
	projectile.global_position = origin
	projectile.linear_velocity = direction.normalized() * float(projectile.weapon["projectile_speed"])
	return projectile


func _ready() -> void:
	add_to_group("projectiles")
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
	_pivot = ProjectileVisual.build(weapon_id)
	add_child(_pivot)
	set_process(not NetBus.headless)
	body_entered.connect(_on_body_entered)


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
	var color: Color = weapon["color"]
	NetBus.emit_blast(self, _impact_point, radius, color)
	if not NetBus.headless:
		NetEffects.blast(parent, _impact_point, radius, color)