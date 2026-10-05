class_name FallingPlatform
extends AnimatableBody3D

enum Phase { IDLE, SHAKING, FALLING, GONE }

const SHAKE_TIME := 0.8
const FALL_ACCEL := 22.0
const FALL_TIME := 2.2
const RESPAWN_TIME := 5.0
const WARNING_COLOR := Color("#ff9f43")

var _size: Vector3 = Vector3.ONE
var _color: Color = Color.WHITE
var _home: Vector3 = Vector3.ZERO
var _phase: Phase = Phase.IDLE
var _timer: float = 0.0
var _speed: float = 0.0
var _visual: MeshInstance3D
var _collider: CollisionShape3D
var _trigger: Area3D


static func create(size: Vector3, color: Color, home: Vector3) -> FallingPlatform:
	var platform := FallingPlatform.new()
	platform._size = size
	platform._color = color
	platform.position = home
	return platform


func _ready() -> void:
	sync_to_physics = true
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = _size
	_collider = CollisionShape3D.new()
	_collider.shape = shape
	add_child(_collider)
	_visual = ArenaUtil.box(_size, _color)
	add_child(_visual)
	_trigger = Area3D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = PhysicsLayers.PLAYER | PhysicsLayers.PROPS | PhysicsLayers.RAGDOLL
	var trigger_shape := BoxShape3D.new()
	trigger_shape.size = Vector3(_size.x * 0.9, 0.4, _size.z * 0.9)
	var trigger_collider := CollisionShape3D.new()
	trigger_collider.shape = trigger_shape
	trigger_collider.position = Vector3(0.0, _size.y * 0.5 + 0.2, 0.0)
	_trigger.add_child(trigger_collider)
	add_child(_trigger)
	_trigger.body_entered.connect(_on_body_entered)
	_home = position


func _set_tint(color: Color) -> void:
	(_visual.material_override as StandardMaterial3D).albedo_color = color


func _on_body_entered(_body: Node3D) -> void:
	if _phase != Phase.IDLE:
		return
	_phase = Phase.SHAKING
	_timer = SHAKE_TIME
	_set_tint(WARNING_COLOR)


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.SHAKING:
			_timer -= delta
			position = _home + Vector3(randf_range(-0.05, 0.05), 0.0, randf_range(-0.05, 0.05))
			if _timer <= 0.0:
				position = _home
				_phase = Phase.FALLING
				_timer = FALL_TIME
				_speed = 0.0
		Phase.FALLING:
			_speed += FALL_ACCEL * delta
			position.y -= _speed * delta
			_timer -= delta
			if _timer <= 0.0:
				_vanish()
		Phase.GONE:
			_timer -= delta
			if _timer <= 0.0:
				_restore()


func _vanish() -> void:
	_phase = Phase.GONE
	_timer = RESPAWN_TIME
	visible = false
	_collider.set_deferred("disabled", true)
	_trigger.set_deferred("monitoring", false)


func _restore() -> void:
	position = _home
	visible = true
	_collider.set_deferred("disabled", false)
	_trigger.set_deferred("monitoring", true)
	_set_tint(_color)
	_phase = Phase.IDLE


func net_flag() -> float:
	return 0.0 if _phase == Phase.GONE else 1.0


func net_extra() -> float:
	return 1.0 if _phase == Phase.SHAKING else 0.0


func net_apply(flag: float, extra: float) -> void:
	visible = flag > 0.5
	_set_tint(WARNING_COLOR if extra > 0.5 else _color)