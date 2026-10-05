class_name ProjectileVisual
extends RefCounted


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh


static func _cone(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


static func _add(pivot: Node3D, mesh: Mesh, color: Color, offset_z: float, emissive: bool, tip_forward: bool = false) -> void:
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
	pivot.add_child(instance)


# The returned node points along -Z once oriented with look_at.
static func build(weapon_id: String) -> Node3D:
	var pivot := Node3D.new()
	var weapon := WeaponDb.get_weapon(weapon_id)
	if weapon.is_empty():
		return pivot
	var color: Color = weapon["color"]
	match String(weapon.get("projectile_shape", "")):
		"arrow":
			_add(pivot, _cylinder(0.015, 0.7), Color("#d9c9a8"), 0.0, false)
			_add(pivot, _cone(0.04, 0.12), color, -0.38, true, true)
		"bolt":
			_add(pivot, _sphere(0.1), color, 0.0, true)
		"rocket":
			_add(pivot, _cylinder(0.09, 0.5), color, 0.0, false)
			_add(pivot, _sphere(0.1), Color("#ffb347"), 0.3, true)
	return pivot