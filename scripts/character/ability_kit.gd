class_name AbilityKit
extends RefCounted


static func is_ally(caster: PlayerController, target: Node) -> bool:
	if not target is PlayerController:
		return false
	var other := target as PlayerController
	return not caster.team.is_empty() and other.team == caster.team


static func flat_aim(caster: PlayerController) -> Vector3:
	var aim := caster.aim_direction()
	aim.y = 0.0
	if aim.length() < 0.05:
		aim = -caster.model.global_transform.basis.z
		aim.y = 0.0
	return aim.normalized()


# Everything hittable inside the radius, without the caster and without teammates.
static func targets(caster: PlayerController, center: Vector3, radius: float) -> Array[Dictionary]:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var excluded: Array[RID] = [caster.get_rid()]
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = PhysicsLayers.HITTABLE
	params.exclude = excluded
	var found: Array[Dictionary] = []
	var done := {}
	for result in caster.get_world_3d().direct_space_state.intersect_shape(params, 32):
		var collider := result["collider"] as Node3D
		if collider == null:
			continue
		var target := CombatResolver.resolve_target(collider)
		if target == null or target == caster or done.has(target.get_instance_id()):
			continue
		if is_ally(caster, target):
			continue
		done[target.get_instance_id()] = true
		found.append({"target": target, "collider": collider})
	return found


static func area_hit(caster: PlayerController, source_id: String, params: Dictionary, center: Vector3) -> void:
	var radius := float(params["radius"])
	var inward := String(params.get("mode", "outward")) == "inward"
	for entry in targets(caster, center, radius):
		var target: Node = entry["target"]
		var collider: Node3D = entry["collider"]
		var offset := collider.global_position - caster.global_position
		offset.y = 0.0
		var direction := offset.normalized() if offset.length() > 0.05 else Vector3.BACK
		if inward:
			direction = -direction
		var falloff := lerpf(1.0, 0.4, clampf(offset.length() / radius, 0.0, 1.0))
		var template := {
			"damage": float(params.get("damage", 0.0)) * falloff,
			"knockback": float(params.get("knockback", 0.0)) * falloff,
			"lift": float(params.get("lift", 0.0)) * falloff,
		}
		CombatResolver.deliver(target, CombatResolver.make_hit(template, source_id, direction, caster))


static func area_slow(caster: PlayerController, params: Dictionary, center: Vector3) -> void:
	for entry in targets(caster, center, float(params["radius"])):
		var target: Node = entry["target"]
		if target is PlayerController:
			(target as PlayerController).apply_slow(float(params["slow_factor"]), float(params["duration"]))