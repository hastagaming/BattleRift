class_name PetVisuals
extends RefCounted


static func _material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.6
	return material


static func _sphere(root: Node3D, radius: float, color: Color, at: Vector3, emissive: bool = false) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, emissive)
	instance.position = at
	root.add_child(instance)


static func _box(root: Node3D, size: Vector3, color: Color, at: Vector3, euler_degrees: Vector3 = Vector3.ZERO, emissive: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, emissive)
	instance.position = at
	instance.rotation_degrees = euler_degrees
	root.add_child(instance)


static func _cone(root: Node3D, radius: float, height: float, color: Color, at: Vector3, euler_degrees: Vector3 = Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, true)
	instance.position = at
	instance.rotation_degrees = euler_degrees
	root.add_child(instance)


# The pet faces -Z. The origin is the center of its body.
static func build(pet_id: String) -> Node3D:
	var root := Node3D.new()
	var pet := PetDb.get_pet(pet_id)
	if pet.is_empty():
		return root
	var color: Color = pet["color"]
	var dark := Color("#10131c")
	_sphere(root, 0.22, color, Vector3.ZERO)
	_sphere(root, 0.045, dark, Vector3(-0.08, 0.05, -0.19))
	_sphere(root, 0.045, dark, Vector3(0.08, 0.05, -0.19))
	match pet_id:
		"pet_volt":
			_box(root, Vector3(0.04, 0.22, 0.04), color, Vector3(-0.09, 0.3, 0.0), Vector3(0.0, 0.0, 20.0), true)
			_box(root, Vector3(0.04, 0.22, 0.04), color, Vector3(0.09, 0.3, 0.0), Vector3(0.0, 0.0, -20.0), true)
			_box(root, Vector3(0.05, 0.2, 0.05), color, Vector3(0.0, 0.0, 0.3), Vector3(60.0, 0.0, 0.0), true)
		"pet_blaze":
			_cone(root, 0.1, 0.3, Color("#ffb347"), Vector3(0.0, 0.34, 0.0))
			_cone(root, 0.06, 0.2, Color("#ff5a1f"), Vector3(0.07, 0.3, 0.02))
		"pet_frost":
			_box(root, Vector3(0.1, 0.3, 0.1), Color("#d6f0ff"), Vector3(0.0, 0.32, 0.0), Vector3(0.0, 45.0, 15.0), true)
		"pet_aero":
			_box(root, Vector3(0.3, 0.03, 0.18), Color("#e8ffd0"), Vector3(-0.27, 0.06, 0.05), Vector3(0.0, 0.0, 25.0))
			_box(root, Vector3(0.3, 0.03, 0.18), Color("#e8ffd0"), Vector3(0.27, 0.06, 0.05), Vector3(0.0, 0.0, -25.0))
		"pet_terra":
			_box(root, Vector3(0.18, 0.1, 0.14), Color("#6e5236"), Vector3(0.0, 0.2, 0.1), Vector3(10.0, 0.0, 0.0))
			_box(root, Vector3(0.14, 0.08, 0.12), Color("#7d5f40"), Vector3(0.1, 0.1, 0.18), Vector3(0.0, 20.0, 0.0))
			_box(root, Vector3(0.14, 0.08, 0.12), Color("#7d5f40"), Vector3(-0.1, 0.1, 0.18), Vector3(0.0, -20.0, 0.0))
		"pet_shadow":
			_cone(root, 0.08, 0.34, color, Vector3(0.0, -0.02, 0.3), Vector3(90.0, 0.0, 0.0))
			_sphere(root, 0.05, Color("#ffffff"), Vector3(-0.08, 0.05, -0.2), true)
			_sphere(root, 0.05, Color("#ffffff"), Vector3(0.08, 0.05, -0.2), true)
		"pet_riftling":
			_box(root, Vector3(0.16, 0.16, 0.16), color, Vector3(0.0, 0.36, 0.0), Vector3(45.0, 0.0, 45.0), true)
		"pet_falcon":
			_box(root, Vector3(0.42, 0.03, 0.2), Color("#c9954a"), Vector3(-0.3, 0.08, 0.05), Vector3(0.0, 0.0, 20.0))
			_box(root, Vector3(0.42, 0.03, 0.2), Color("#c9954a"), Vector3(0.3, 0.08, 0.05), Vector3(0.0, 0.0, -20.0))
			_cone(root, 0.05, 0.14, Color("#ffd166"), Vector3(0.0, -0.01, -0.26), Vector3(-90.0, 0.0, 0.0))
		"pet_catty":
			_cone(root, 0.07, 0.16, color, Vector3(-0.12, 0.26, 0.0))
			_cone(root, 0.07, 0.16, color, Vector3(0.12, 0.26, 0.0))
			_box(root, Vector3(0.05, 0.05, 0.3), color.darkened(0.2), Vector3(0.0, 0.05, 0.3), Vector3(-30.0, 0.0, 0.0))
		"pet_creaton":
			_box(root, Vector3(0.12, 0.12, 0.12), color, Vector3(-0.3, 0.12, 0.0), Vector3(20.0, 30.0, 0.0), true)
			_box(root, Vector3(0.12, 0.12, 0.12), color, Vector3(0.3, 0.12, 0.0), Vector3(-20.0, 30.0, 0.0), true)
			_box(root, Vector3(0.12, 0.12, 0.12), color, Vector3(0.0, 0.36, 0.0), Vector3(45.0, 0.0, 45.0), true)
	return root