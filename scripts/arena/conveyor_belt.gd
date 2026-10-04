class_name ConveyorBelt
extends StaticBody3D

const STRIPE_COUNT := 6

var belt_velocity: Vector3 = Vector3.ZERO

var _size: Vector3 = Vector3.ONE
var _color: Color = Color.WHITE
var _stripes: Array[MeshInstance3D] = []
var _axis: Vector3 = Vector3.FORWARD
var _length: float = 1.0
var _scroll: float = 0.0


static func create(size: Vector3, color: Color, at: Vector3, velocity: Vector3) -> ConveyorBelt:
	var belt := ConveyorBelt.new()
	belt._size = size
	belt._color = color
	belt.position = at
	belt.belt_velocity = velocity
	return belt


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	constant_linear_velocity = belt_velocity
	var shape := BoxShape3D.new()
	shape.size = _size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	add_child(ArenaUtil.box(_size, _color))
	var flat := Vector3(belt_velocity.x, 0.0, belt_velocity.z)
	_axis = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	_length = absf(_axis.x) * _size.x + absf(_axis.z) * _size.z
	var across := absf(_axis.z) * _size.x + absf(_axis.x) * _size.z
	var stripe_size := Vector3(0.3, 0.03, across * 0.9) if absf(_axis.x) > absf(_axis.z) else Vector3(across * 0.9, 0.03, 0.3)
	for i in STRIPE_COUNT:
		var stripe := ArenaUtil.box(stripe_size, _color.lightened(0.45), true, 0.9)
		add_child(stripe)
		_stripes.append(stripe)


func _process(delta: float) -> void:
	var spacing := _length / float(STRIPE_COUNT)
	_scroll = fposmod(_scroll + belt_velocity.length() * delta, spacing)
	for i in _stripes.size():
		var along := fposmod(_scroll + float(i) * spacing, _length) - _length * 0.5
		_stripes[i].position = _axis * along + Vector3(0.0, _size.y * 0.5 + 0.02, 0.0)