class_name LavaPool
extends Area3D

const DAMAGE_PER_PULSE := 8.0
const PULSE_INTERVAL := 0.45
const PULSE_KNOCKBACK := 4.0
const PULSE_LIFT := 13.0

var _radius: float = 3.0
var _cooldowns: Dictionary = {}


static func create(radius: float, at: Vector3) -> LavaPool:
	var pool := LavaPool.new()
	pool._radius = radius
	pool.position = at
	return pool


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER | PhysicsLayers.PROPS | PhysicsLayers.RAGDOLL
	var shape := CylinderShape3D.new()
	shape.radius = _radius
	shape.height = 1.4
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, 0.2, 0.0)
	add_child(collider)
	var surface := ArenaUtil.cylinder(_radius, 0.1, Color("#ff5a1f"), true)
	surface.position = Vector3(0.0, 0.15, 0.0)
	add_child(surface)
	var glow := OmniLight3D.new()
	glow.light_color = Color("#ff7a3d")
	glow.light_energy = 2.0
	glow.omni_range = 9.0
	glow.position = Vector3(0.0, 1.5, 0.0)
	add_child(glow)


func _physics_process(delta: float) -> void:
	var seen := {}
	for body in get_overlapping_bodies():
		var target := CombatResolver.resolve_target(body)
		if target == null:
			continue
		var id := target.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		var left := float(_cooldowns.get(id, 0.0)) - delta
		if left <= 0.0:
			left = PULSE_INTERVAL
			var offset := (body as Node3D).global_position - global_position
			offset.y = 0.0
			CombatResolver.deliver(target, ArenaUtil.hazard_hit("lava", DAMAGE_PER_PULSE, PULSE_KNOCKBACK, PULSE_LIFT, offset))
		_cooldowns[id] = left
	for stale in _cooldowns.keys():
		if not seen.has(stale):
			_cooldowns.erase(stale)