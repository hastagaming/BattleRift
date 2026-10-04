class_name MovingPlatform
extends AnimatableBody3D

var travel: Vector3 = Vector3.ZERO
var period: float = 8.0
var phase_offset: float = 0.0

var _size: Vector3 = Vector3.ONE
var _color: Color = Color.WHITE
var _home: Vector3 = Vector3.ZERO
var _time: float = 0.0


static func create(size: Vector3, color: Color, home: Vector3, move_travel: Vector3, move_period: float, shift: float = 0.0) -> MovingPlatform:
	var platform := MovingPlatform.new()
	platform._size = size
	platform._color = color
	platform.position = home
	platform.travel = move_travel
	platform.period = maxf(move_period, 0.5)
	platform.phase_offset = shift
	return platform


func _ready() -> void:
	sync_to_physics = true
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = _size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	add_child(ArenaUtil.box(_size, _color))
	_home = position


func _physics_process(delta: float) -> void:
	_time += delta
	var t := 0.5 - 0.5 * cos(TAU * (_time / period + phase_offset))
	position = _home + travel * t