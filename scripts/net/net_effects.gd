class_name NetEffects
extends RefCounted


static func blast(parent: Node, center: Vector3, radius: float, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.scale = Vector3.ONE * 0.2
	parent.add_child(visual)
	visual.global_position = center
	var tween := visual.create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(visual.queue_free)


static func beam(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var pivot := Node3D.new()
	parent.add_child(pivot)
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
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	visual.position = Vector3(0.0, 0.0, -length * 0.5)
	pivot.add_child(visual)
	var tween := pivot.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.12)
	tween.tween_callback(pivot.queue_free)