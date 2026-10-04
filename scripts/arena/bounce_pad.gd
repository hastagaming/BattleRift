class_name BouncePad
extends Area3D

var power: float = 16.0

var _radius: float = 1.3
var _color: Color = Color.WHITE
var _visual: MeshInstance3D


static func create(radius: float, launch_power: float, at: Vector3, color: Color) -> BouncePad:
	var pad := BouncePad.new()
	pad._radius = radius
	pad.power = launch_power
	pad._color = color
	pad.position = at
	return pad


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER | PhysicsLayers.PROPS | PhysicsLayers.RAGDOLL
	var shape := CylinderShape3D.new()
	shape.radius = _radius
	shape.height = 0.5
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, 0.25, 0.0)
	add_child(collider)
	_visual = ArenaUtil.cylinder(_radius, 0.1, _color, true)
	_visual.position = Vector3(0.0, 0.05, 0.0)
	add_child(_visual)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	ArenaUtil.launch_body(body, Vector3(0.0, power, 0.0))
	var tween := _visual.create_tween()
	tween.tween_property(_visual, "scale", Vector3(1.15, 1.0, 1.15), 0.08)
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.12)