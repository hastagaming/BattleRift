class_name ArenaUtil
extends RefCounted


static func material(color: Color, emissive: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color, alpha)
	result.roughness = 0.75
	if alpha < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 1.6
	return result


static func box(size: Vector3, color: Color, emissive: bool = false, alpha: float = 1.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color, emissive, alpha)
	return instance


static func cylinder(radius: float, height: float, color: Color, emissive: bool = false, alpha: float = 1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 40
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color, emissive, alpha)
	return instance


static func hazard_hit(hazard_id: String, damage: float, knockback: float, lift: float, direction: Vector3) -> Dictionary:
	return CombatResolver.make_hit({"damage": damage, "knockback": knockback, "lift": lift}, hazard_id, direction, null)


static func launch_body(body: Node, velocity: Vector3) -> void:
	if body is PlayerController:
		(body as PlayerController).launch(velocity)
	elif body is RigidBody3D:
		var rigid := body as RigidBody3D
		rigid.apply_central_impulse.call_deferred((velocity - rigid.linear_velocity) * rigid.mass)