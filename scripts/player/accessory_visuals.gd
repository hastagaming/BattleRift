class_name AccessoryVisuals
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


static func _box(root: Node3D, size: Vector3, color: Color, at: Vector3, emissive: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, emissive)
	instance.position = at
	root.add_child(instance)


static func _cylinder(root: Node3D, radius: float, height: float, color: Color, at: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, false)
	instance.position = at
	root.add_child(instance)


# Returns a node already positioned relative to the CharacterModel origin.
static func build(item_id: String) -> Node3D:
	var root := Node3D.new()
	var color := ItemDb.color_of(item_id)
	match item_id:
		"crown":
			var base_y := CharacterModel.HEAD_Y + 0.17
			_cylinder(root, 0.19, 0.06, color, Vector3(0.0, base_y, 0.0))
			for i in 5:
				var angle := TAU * float(i) / 5.0
				_box(root, Vector3(0.05, 0.12, 0.05), color, Vector3(cos(angle) * 0.17, base_y + 0.08, sin(angle) * 0.17), true)
		"visor":
			_box(root, Vector3(0.32, 0.09, 0.06), color, Vector3(0.0, CharacterModel.HEAD_Y + 0.03, -0.165), true)
		"scarf":
			_box(root, Vector3(0.4, 0.1, 0.36), color, Vector3(0.0, 1.38, 0.0))
			_box(root, Vector3(0.1, 0.4, 0.04), color, Vector3(0.14, 1.2, -0.17))
		"cape":
			_box(root, Vector3(0.46, 0.85, 0.03), color, Vector3(0.0, 1.0, 0.18))
	return root