class_name ExplosiveBarrel
extends RigidBody3D

const MAX_HEALTH := 12.0
const RESPAWN_TIME := 8.0
const BLAST_RADIUS := 4.5
const BLAST_DAMAGE := 16.0
const BLAST_KNOCKBACK := 15.0
const BLAST_LIFT := 6.5
const KILL_Y := -25.0

var _health: float = MAX_HEALTH
var _exploding: bool = false
var _home: Transform3D = Transform3D.IDENTITY
var _last_attacker: Node
var _collider: CollisionShape3D


static func create(at: Vector3) -> ExplosiveBarrel:
	var barrel := ExplosiveBarrel.new()
	barrel.position = at
	return barrel


func _ready() -> void:
	mass = 4.0
	collision_layer = PhysicsLayers.PROPS
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PROPS | PhysicsLayers.PLAYER | PhysicsLayers.RAGDOLL
	var shape := CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 1.1
	_collider = CollisionShape3D.new()
	_collider.shape = shape
	add_child(_collider)
	add_child(ArenaUtil.cylinder(0.4, 1.1, Color("#c0392b")))
	add_child(ArenaUtil.cylinder(0.41, 0.14, Color("#ffd166"), true))
	_home = global_transform


func apply_hit(hit: Dictionary) -> void:
	if _exploding:
		return
	apply_central_impulse(CombatResolver.raw_impulse(hit) * mass)
	var attacker: Variant = hit.get("attacker")
	if attacker is Node and is_instance_valid(attacker):
		_last_attacker = attacker as Node
	_health -= float(hit["damage"])
	if _health <= 0.0:
		_explode()


func _physics_process(_delta: float) -> void:
	if global_position.y < KILL_Y and not _exploding:
		_reset()


func _explode() -> void:
	_exploding = true
	var template := {
		"weapon": "explosion",
		"damage": BLAST_DAMAGE,
		"knockback": BLAST_KNOCKBACK,
		"lift": BLAST_LIFT,
		"color": Color("#ffb347"),
	}
	var excluded: Array[RID] = [get_rid()]
	var attacker: Node = _last_attacker if is_instance_valid(_last_attacker) else null
	Explosion.detonate(self, global_position + Vector3(0.0, 0.4, 0.0), BLAST_RADIUS, template, attacker, excluded)
	visible = false
	_collider.set_deferred("disabled", true)
	set_deferred("freeze", true)
	await get_tree().create_timer(RESPAWN_TIME).timeout
	if is_inside_tree():
		_reset()


func _reset() -> void:
	_health = MAX_HEALTH
	_exploding = false
	_last_attacker = null
	global_transform = _home
	var body := get_rid()
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, _home)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	freeze = false
	visible = true
	_collider.disabled = false


func net_flag() -> float:
	return 0.0 if _exploding else 1.0


func net_apply(flag: float, _extra: float) -> void:
	visible = flag > 0.5