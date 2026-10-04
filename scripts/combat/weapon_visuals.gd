class_name WeaponVisuals
extends RefCounted


static func _material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.4
	return material


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


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


static func _part(root: Node3D, mesh: Mesh, color: Color, offset: Vector3, euler_degrees: Vector3 = Vector3.ZERO, emissive: bool = false) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, emissive)
	instance.position = offset
	instance.rotation_degrees = euler_degrees
	root.add_child(instance)


# Weapons extend along -Y from the hand.
static func build(weapon_id: String) -> Node3D:
	var root := Node3D.new()
	var weapon := WeaponDb.get_weapon(weapon_id)
	if weapon.is_empty():
		return root
	var color: Color = weapon["color"]
	var metal := Color("#c9d1e6")
	var dark := Color("#2a3048")
	match weapon_id:
		"sword":
			_part(root, _box(Vector3(0.07, 0.95, 0.025)), color, Vector3(0.0, -0.62, 0.0))
			_part(root, _box(Vector3(0.34, 0.06, 0.07)), dark, Vector3(0.0, -0.12, 0.0))
			_part(root, _cylinder(0.03, 0.2), dark, Vector3(0.0, -0.02, 0.0))
		"hammer":
			_part(root, _cylinder(0.03, 1.1), dark, Vector3(0.0, -0.55, 0.0))
			_part(root, _box(Vector3(0.4, 0.26, 0.26)), color, Vector3(0.0, -1.12, 0.0))
		"spear":
			_part(root, _cylinder(0.025, 1.9), dark, Vector3(0.0, -0.8, 0.0))
			_part(root, _cone(0.07, 0.3), metal, Vector3(0.0, -1.9, 0.0), Vector3(180.0, 0.0, 0.0))
		"shield":
			_part(root, _cylinder(0.4, 0.07), color, Vector3(0.0, -0.2, -0.12), Vector3(90.0, 0.0, 0.0))
			_part(root, _sphere(0.1), metal, Vector3(0.0, -0.2, -0.17), Vector3.ZERO, true)
		"bow":
			_part(root, _box(Vector3(0.05, 0.2, 0.05)), dark, Vector3(0.0, -0.1, 0.0))
			_part(root, _box(Vector3(0.03, 0.03, 0.55)), color, Vector3(0.0, -0.2, 0.28), Vector3(20.0, 0.0, 0.0))
			_part(root, _box(Vector3(0.03, 0.03, 0.55)), color, Vector3(0.0, -0.2, -0.28), Vector3(-20.0, 0.0, 0.0))
			_part(root, _box(Vector3(0.008, 0.008, 1.0)), metal, Vector3(0.0, -0.32, 0.0))
		"blaster":
			_part(root, _box(Vector3(0.1, 0.4, 0.16)), dark, Vector3(0.0, -0.18, 0.0))
			_part(root, _cylinder(0.035, 0.3), color, Vector3(0.0, -0.5, 0.0), Vector3.ZERO, true)
		"rocket_launcher":
			_part(root, _cylinder(0.1, 0.95), color, Vector3(0.0, -0.35, 0.0))
			_part(root, _sphere(0.09), Color("#ffb347"), Vector3(0.0, -0.85, 0.0), Vector3.ZERO, true)
			_part(root, _box(Vector3(0.07, 0.2, 0.08)), dark, Vector3(0.0, -0.1, 0.12))
		"laser":
			_part(root, _cylinder(0.05, 0.6), metal, Vector3(0.0, -0.3, 0.0))
			_part(root, _sphere(0.06), color, Vector3(0.0, -0.62, 0.0), Vector3.ZERO, true)
	return root