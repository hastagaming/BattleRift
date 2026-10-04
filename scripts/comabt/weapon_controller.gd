class_name WeaponController
extends Node

signal weapon_changed(weapon_id: String)
signal attacked(weapon_id: String)

const AIM_DISTANCE := 60.0

var owner_body: PlayerController
var enabled: bool = true
var current_id: String = ""

var _available: Array[String] = []
var _cooldown: float = 0.0


func _ready() -> void:
	var equipped := "sword"
	if PlayerData.is_signed_in:
		var stored := String(PlayerData.data["equipped"].get("weapon", ""))
		if WeaponDb.has(stored):
			equipped = stored
	set_available([equipped])


func set_available(ids: Array[String]) -> void:
	_available = []
	for id in ids:
		if WeaponDb.has(id) and id not in _available:
			_available.append(id)
	if _available.is_empty():
		current_id = ""
		owner_body.model.set_weapon("")
		weapon_changed.emit("")
	elif current_id not in _available:
		select(_available[0])


func select(weapon_id: String) -> void:
	if weapon_id not in _available:
		return
	current_id = weapon_id
	owner_body.model.set_weapon(weapon_id)
	weapon_changed.emit(weapon_id)


func cycle() -> void:
	if _available.size() < 2:
		return
	var index := _available.find(current_id)
	select(_available[(index + 1) % _available.size()])


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not enabled or owner_body == null or current_id.is_empty():
		return
	if owner_body.state != PlayerController.State.NORMAL or not owner_body.controllable:
		return
	if Input.is_action_just_pressed("weapon_switch"):
		cycle()
		return
	var weapon := WeaponDb.get_weapon(current_id)
	var wants_attack := Input.is_action_pressed("attack") if bool(weapon["auto"]) else Input.is_action_just_pressed("attack")
	if wants_attack and _cooldown <= 0.0:
		_attack(weapon)


func _attack(weapon: Dictionary) -> void:
	var weapon_id := current_id
	var windup := float(weapon["windup"])
	_cooldown = maxf(float(weapon["attack_interval"]), windup + float(weapon["cooldown"]))
	owner_body.face(owner_body.aim_direction())
	owner_body.model.play_attack(maxf(windup + 0.2, 0.15))
	if weapon.has("guard_time"):
		owner_body.guard_remaining = float(weapon["guard_time"])
	attacked.emit(weapon_id)
	if windup > 0.0:
		await get_tree().create_timer(windup).timeout
		if owner_body.state != PlayerController.State.NORMAL or current_id != weapon_id:
			return
	match String(weapon["kind"]):
		WeaponDb.KIND_MELEE:
			_melee(weapon, weapon_id)
		WeaponDb.KIND_PROJECTILE:
			_fire_projectile(weapon, weapon_id)
		WeaponDb.KIND_HITSCAN:
			_fire_hitscan(weapon, weapon_id)


func _exclude() -> Array[RID]:
	var rids: Array[RID] = [owner_body.get_rid()]
	return rids


func _muzzle_origin() -> Vector3:
	return owner_body.global_position + Vector3(0.0, 1.25, 0.0)


func _aim_direction(origin: Vector3) -> Vector3:
	var camera := owner_body.get_viewport().get_camera_3d()
	if camera == null:
		return -owner_body.model.global_transform.basis.z
	var from := camera.global_position
	var forward := -camera.global_transform.basis.z
	var to := from + forward * AIM_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD | PhysicsLayers.HITTABLE, _exclude())
	var hit := owner_body.get_world_3d().direct_space_state.intersect_ray(query)
	var point := to
	if not hit.is_empty():
		point = hit["position"]
	var direction := point - origin
	if direction.length() < 0.5:
		return forward
	return direction.normalized()


func _apply_spread(direction: Vector3, spread: float) -> Vector3:
	var axis := direction.cross(Vector3.UP)
	if axis.length() < 0.01:
		axis = Vector3.RIGHT
	var tilted := direction.rotated(axis.normalized(), randf() * spread)
	return tilted.rotated(direction, randf() * TAU)


func _melee(weapon: Dictionary, weapon_id: String) -> void:
	var forward := owner_body.aim_direction()
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length() < 0.01:
		flat = -owner_body.model.global_transform.basis.z
		flat.y = 0.0
	flat = flat.normalized()
	var shape := SphereShape3D.new()
	shape.radius = float(weapon["range"])
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, owner_body.global_position + Vector3(0.0, 1.0, 0.0))
	params.collision_mask = PhysicsLayers.HITTABLE
	params.exclude = _exclude()
	var half_arc := deg_to_rad(float(weapon["arc"])) * 0.5
	var done := {}
	for result in owner_body.get_world_3d().direct_space_state.intersect_shape(params, 32):
		var collider := result["collider"] as Node3D
		if collider == null:
			continue
		var target := CombatResolver.resolve_target(collider)
		if target == null or target == owner_body or done.has(target.get_instance_id()):
			continue
		var to_target := collider.global_position - owner_body.global_position
		to_target.y = 0.0
		var to_target_dir := to_target.normalized() if to_target.length() > 0.05 else flat
		if flat.angle_to(to_target_dir) > half_arc:
			continue
		done[target.get_instance_id()] = true
		var direction := (flat * 0.65 + to_target_dir * 0.35).normalized()
		CombatResolver.deliver(target, CombatResolver.make_hit(weapon, weapon_id, direction, owner_body))


func _fire_projectile(weapon: Dictionary, weapon_id: String) -> void:
	var origin := _muzzle_origin()
	var direction := _aim_direction(origin)
	var spread := deg_to_rad(float(weapon.get("spread", 0.0)))
	if spread > 0.0:
		direction = _apply_spread(direction, spread)
	Projectile.launch(owner_body.get_parent(), owner_body, weapon_id, origin + direction * 0.7, direction)


func _fire_hitscan(weapon: Dictionary, weapon_id: String) -> void:
	var origin := _muzzle_origin()
	var direction := _aim_direction(origin)
	var end := origin + direction * float(weapon["range"])
	var query := PhysicsRayQueryParameters3D.create(origin, end, PhysicsLayers.WORLD | PhysicsLayers.HITTABLE, _exclude())
	var result := owner_body.get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		end = result["position"]
		var target := CombatResolver.resolve_target(result["collider"] as Node)
		if target != null and target != owner_body:
			CombatResolver.deliver(target, CombatResolver.make_hit(weapon, weapon_id, direction, owner_body))
	_spawn_beam(origin + direction * 0.6, end, weapon["color"])


func _spawn_beam(from: Vector3, to: Vector3, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var pivot := Node3D.new()
	owner_body.get_parent().add_child(pivot)
	var axis := (to - from).normalized()
	var up := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	pivot.look_at_from_position(from, to, up)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.03
	mesh.bottom_radius = 0.03
	mesh.height = length
	var beam := MeshInstance3D.new()
	beam.mesh = mesh
	beam.material_override = material
	beam.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	beam.position = Vector3(0.0, 0.0, -length * 0.5)
	pivot.add_child(beam)
	var tween := pivot.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.12)
	tween.tween_callback(pivot.queue_free)