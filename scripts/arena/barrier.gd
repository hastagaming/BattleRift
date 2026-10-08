class_name Barrier
extends StaticBody3D

const THICKNESS := 0.5

var _width: float = 4.0
var _height: float = 2.4
var _duration: float = 6.0
var _solid: bool = true
var _color: Color = Color.WHITE


# A solid barrier blocks movement, projectiles and beams. A non-solid one is only a visual.
static func spawn(parent: Node, at: Vector3, yaw: float, duration: float, width: float, height: float, solid: bool, color: Color) -> Barrier:
	var barrier := Barrier.new()
	barrier._width = width
	barrier._height = height
	barrier._duration = duration
	barrier._solid = solid
	barrier._color = color
	barrier.position = at + Vector3(0.0, height * 0.5, 0.0)
	barrier.rotation.y = yaw
	parent.add_child(barrier)
	return barrier


func _ready() -> void:
	if _solid:
		collision_layer = PhysicsLayers.WORLD
		collision_mask = 0
		add_to_group("barrier")
		var shape := BoxShape3D.new()
		shape.size = Vector3(_width, _height, THICKNESS)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		add_child(collider)
	else:
		collision_layer = 0
		collision_mask = 0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(_width, _height, THICKNESS)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(_color, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = _color
	material.emission_energy_multiplier = 0.9
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.scale = Vector3(1.0, 0.1, 1.0)
	add_child(visual)
	var rise := visual.create_tween()
	rise.tween_property(visual, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_interval(maxf(_duration - 0.5, 0.1))
	rise.tween_property(material, "albedo_color:a", 0.0, 0.3)
	rise.tween_callback(queue_free)