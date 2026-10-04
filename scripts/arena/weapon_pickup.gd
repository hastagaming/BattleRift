class_name WeaponPickup
extends Area3D

const RESPAWN_TIME := 12.0

var weapon_id: String = ""

var _active: bool = true
var _spinner: Node3D
var _base: MeshInstance3D
var _label: Label3D
var _time: float = 0.0


static func create(id: String, at: Vector3) -> WeaponPickup:
	var pickup := WeaponPickup.new()
	pickup.weapon_id = id
	pickup.position = at
	return pickup


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, 0.9, 0.0)
	add_child(collider)
	var weapon := WeaponDb.get_weapon(weapon_id)
	var color: Color = weapon.get("color", Color.WHITE)
	_base = ArenaUtil.cylinder(0.7, 0.08, color, true)
	_base.position = Vector3(0.0, 0.04, 0.0)
	add_child(_base)
	_spinner = Node3D.new()
	_spinner.position = Vector3(0.0, 1.4, 0.0)
	_spinner.add_child(WeaponVisuals.build(weapon_id))
	add_child(_spinner)
	_label = Label3D.new()
	_label.text = String(weapon.get("name", weapon_id))
	_label.font_size = 48
	_label.pixel_size = 0.006
	_label.modulate = color
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, 2.2, 0.0)
	add_child(_label)


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_spinner.rotate_y(delta * 1.8)
	_spinner.position.y = 1.4 + sin(_time * 2.0) * 0.08


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	for body in get_overlapping_bodies():
		var player := body as PlayerController
		if player == null or player.state != PlayerController.State.NORMAL:
			continue
		if player.weapons.add_pickup(weapon_id):
			_consume()
			return


func _set_shown(shown: bool) -> void:
	_spinner.visible = shown
	_base.visible = shown
	_label.visible = shown


func _consume() -> void:
	_active = false
	_set_shown(false)
	await get_tree().create_timer(RESPAWN_TIME).timeout
	if is_inside_tree():
		_active = true
		_set_shown(true)