class_name Explosion
extends RefCounted


static func detonate(context: Node3D, center: Vector3, radius: float, template: Dictionary, attacker: Node, excluded: Array[RID] = []) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = PhysicsLayers.HITTABLE
	params.exclude = excluded
	var done := {}
	for result in context.get_world_3d().direct_space_state.intersect_shape(params, 48):
		var collider := result["collider"] as Node3D
		if collider == null:
			continue
		var target := CombatResolver.resolve_target(collider)
		if target == null or done.has(target.get_instance_id()):
			continue
		done[target.get_instance_id()] = true
		var anchor := collider.global_position
		if target is PlayerController:
			anchor += Vector3(0.0, 0.9, 0.0)
		var offset := anchor - center
		var falloff := lerpf(1.0, 0.2, clampf(offset.length() / radius, 0.0, 1.0))
		var hit := CombatResolver.make_hit(template, String(template["weapon"]), offset, attacker)
		for key in ["damage", "knockback", "lift"]:
			hit[key] = float(hit[key]) * falloff
		CombatResolver.deliver(target, hit)
	var blast_color: Color = template.get("color", Color("#ffb347"))
	NetBus.emit_blast(context, center, radius, blast_color)
	if not NetBus.headless:
		NetEffects.blast(context.get_parent(), center, radius, blast_color)