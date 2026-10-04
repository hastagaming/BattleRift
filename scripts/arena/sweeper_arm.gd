class_name SweeperArm
extends AnimatableBody3D

const HIT_COOLDOWN := 0.6
const DAMAGE := 7.0
const KNOCKBACK := 12.0
const LIFT := 4.0

var angular_speed: float = 1.1

var _length: float = 10.0
var _thickness: float = 0.5
var _height: float = 0.5
var _color: Color = Color.WHITE
var _hit_area: Area3D
var _cooldowns: Dictionary = {}


static func create(length: float, thickness: float, height: float, color: Color, at: Vector3, speed: float) -> SweeperArm:
	var arm := SweeperArm.new()
	arm._length = length
	arm._thickness = thickness
	arm._height = height
	arm._color = color
	arm.position = at
	arm.angular_speed = speed
	return arm


func _ready() -> void:
	sync_to_physics = true
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(_length, _height, _thickness)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	add_child(ArenaUtil.box(Vector3(_length, _height, _thickness), _color, true))
	add_child(ArenaUtil.cylinder(_thickness, _height + 0.2, Color("#c9d1e6")))
	_hit_area = Area3D.new()
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = PhysicsLayers.PLAYER | PhysicsLayers.PROPS | PhysicsLayers.RAGDOLL
	var hit_shape := BoxShape3D.new()
	hit_shape.size = Vector3(_length, _height + 0.3, _thickness + 0.5)
	var hit_collider := CollisionShape3D.new()
	hit_collider.shape = hit_shape
	_hit_area.add_child(hit_collider)
	add_child(_hit_area)


func _physics_process(delta: float) -> void:
	rotation.y += angular_speed * delta
	for stale in _cooldowns.keys():
		var left := float(_cooldowns[stale]) - delta
		if left <= 0.0:
			_cooldowns.erase(stale)
		else:
			_cooldowns[stale] = left
	for body in _hit_area.get_overlapping_bodies():
		var target := CombatResolver.resolve_target(body)
		if target == null:
			continue
		var id := target.get_instance_id()
		if _cooldowns.has(id):
			continue
		var offset := (body as Node3D).global_position - global_position
		offset.y = 0.0
		var tangent := Vector3.UP.cross(offset)
		if angular_speed < 0.0:
			tangent = -tangent
		_cooldowns[id] = HIT_COOLDOWN
		CombatResolver.deliver(target, ArenaUtil.hazard_hit("sweeper", DAMAGE, KNOCKBACK, LIFT, tangent))