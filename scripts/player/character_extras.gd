class_name CharacterExtras
extends RefCounted


static func _material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.5
	return material


static func _box(root: Node3D, size: Vector3, color: Color, at: Vector3, euler_degrees: Vector3 = Vector3.ZERO, emissive: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, emissive)
	instance.position = at
	instance.rotation_degrees = euler_degrees
	root.add_child(instance)


static func _sphere(root: Node3D, radius: float, color: Color, at: Vector3, emissive: bool = false) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, emissive)
	instance.position = at
	root.add_child(instance)


static func _ring(root: Node3D, inner: float, outer: float, color: Color, at: Vector3, emissive: bool) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, emissive)
	instance.position = at
	instance.scale = Vector3(1.0, 0.5, 1.0)
	root.add_child(instance)


# Small shapes that make each character recognizable.
static func build(character_id: String) -> Node3D:
	var root := Node3D.new()
	var color := CharacterDb.color_of(character_id)
	match character_id:
		"rifter":
			_box(root, Vector3(0.13, 0.13, 0.04), color, Vector3(0.0, CharacterModel.TORSO_Y + 0.08, -0.17), Vector3(0.0, 0.0, 45.0), true)
		"vanguard":
			_box(root, Vector3(0.44, 0.4, 0.04), color.darkened(0.35), Vector3(0.0, CharacterModel.TORSO_Y, -0.17))
		"striker":
			_ring(root, 0.17, 0.2, color, Vector3(0.0, CharacterModel.HEAD_Y + 0.06, 0.0), false)
		"sprite":
			_box(root, Vector3(0.02, 0.2, 0.02), color, Vector3(-0.1, CharacterModel.HEAD_Y + 0.26, 0.0))
			_box(root, Vector3(0.02, 0.2, 0.02), color, Vector3(0.1, CharacterModel.HEAD_Y + 0.26, 0.0))
			_sphere(root, 0.05, color, Vector3(-0.1, CharacterModel.HEAD_Y + 0.38, 0.0), true)
			_sphere(root, 0.05, color, Vector3(0.1, CharacterModel.HEAD_Y + 0.38, 0.0), true)
		"titan":
			_box(root, Vector3(0.24, 0.14, 0.28), color, Vector3(-0.42, CharacterModel.SHOULDER_Y + 0.05, 0.0))
			_box(root, Vector3(0.24, 0.14, 0.28), color, Vector3(0.42, CharacterModel.SHOULDER_Y + 0.05, 0.0))
		"oracle":
			_ring(root, 0.14, 0.18, color, Vector3(0.0, CharacterModel.HEAD_Y + 0.36, 0.0), true)
	return root