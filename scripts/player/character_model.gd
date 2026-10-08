class_name CharacterModel
extends Node3D

const TORSO_SIZE := Vector3(0.5, 0.7, 0.3)
const ARM_SIZE := Vector3(0.14, 0.6, 0.14)
const LEG_SIZE := Vector3(0.18, 0.7, 0.18)
const HEAD_RADIUS := 0.18
const TORSO_Y := 1.05
const SHOULDER_Y := 1.35
const SHOULDER_X := 0.36
const HIP_Y := 0.7
const HIP_X := 0.12
const HEAD_Y := 1.6

const SKIN_COLORS := {
	"default": Color("#d9a273"),
	"frost": Color("#8fd3ff"),
	"ember": Color("#ff7a4d"),
	"shadow": Color("#5b5472"),
}
const EMOTES: Array[String] = ["wave", "spin", "cheer"]
const HOLD_ANGLE := 1.1
const ACCESSORY_SLOTS: Array[String] = ["head", "face", "body", "back"]

var skin_color: Color = Color("#d9a273")
var accent_color: Color = Color("#38e8c6")

var _skin_material := StandardMaterial3D.new()
var _accent_material := StandardMaterial3D.new()
var _pants_material := StandardMaterial3D.new()
var _eye_material := StandardMaterial3D.new()
var _arm_left: Node3D
var _arm_right: Node3D
var _leg_left: Node3D
var _leg_right: Node3D
var _weapon_holder: Node3D
var _extras: Node3D
var _accessory_nodes: Dictionary = {}
var _appearance_locked: bool = false
var _phase: float = 0.0
var _hold_offset: float = 0.0
var _emoting: bool = false
var _attacking: bool = false
var _emote_tween: Tween
var _attack_tween: Tween


func _ready() -> void:
	_eye_material.albedo_color = Color("#10131c")
	var torso := _mesh_instance(_box_mesh(TORSO_SIZE), _accent_material)
	torso.position = Vector3(0.0, TORSO_Y, 0.0)
	add_child(torso)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = HEAD_RADIUS
	head_mesh.height = HEAD_RADIUS * 2.0
	var head := _mesh_instance(head_mesh, _skin_material)
	head.position = Vector3(0.0, HEAD_Y, 0.0)
	add_child(head)
	for side in [-1.0, 1.0]:
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.07
		var eye := _mesh_instance(eye_mesh, _eye_material)
		eye.position = Vector3(0.07 * side, 0.03, -0.16)
		head.add_child(eye)
	_arm_left = _limb(Vector3(-SHOULDER_X, SHOULDER_Y, 0.0), ARM_SIZE, _skin_material)
	_arm_right = _limb(Vector3(SHOULDER_X, SHOULDER_Y, 0.0), ARM_SIZE, _skin_material)
	_leg_left = _limb(Vector3(-HIP_X, HIP_Y, 0.0), LEG_SIZE, _pants_material)
	_leg_right = _limb(Vector3(HIP_X, HIP_Y, 0.0), LEG_SIZE, _pants_material)
	_weapon_holder = Node3D.new()
	_weapon_holder.position = Vector3(0.0, -ARM_SIZE.y, 0.0)
	_arm_right.add_child(_weapon_holder)
	apply_equipped()


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _mesh_instance(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance


func _limb(pivot_position: Vector3, size: Vector3, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_position
	var visual := _mesh_instance(_box_mesh(size), material)
	visual.position = Vector3(0.0, -size.y * 0.5, 0.0)
	pivot.add_child(visual)
	add_child(pivot)
	return pivot


func apply_equipped() -> void:
	if _appearance_locked:
		return
	var skin_id := "default"
	var character_id := "rifter"
	var accessories := {}
	if PlayerData.is_signed_in:
		var equipped: Dictionary = PlayerData.data["equipped"]
		skin_id = String(equipped.get("skin", "default"))
		character_id = String(equipped.get("character", "rifter"))
		for slot in ACCESSORY_SLOTS:
			accessories[slot] = String(equipped.get(slot, ""))
	_paint(skin_id, character_id)
	_set_accessories(accessories)


func apply_appearance(skin_id: String, character_id: String, accessories: Dictionary = {}) -> void:
	_appearance_locked = true
	_paint(skin_id, character_id)
	_set_accessories(accessories)


func _paint(skin_id: String, character_id: String) -> void:
	var character := character_id if CharacterDb.has(character_id) else "rifter"
	skin_color = SKIN_COLORS.get(skin_id, SKIN_COLORS["default"])
	accent_color = CharacterDb.color_of(character)
	_skin_material.albedo_color = skin_color
	_accent_material.albedo_color = accent_color
	_pants_material.albedo_color = accent_color.darkened(0.55)
	if _extras != null:
		_extras.queue_free()
	_extras = CharacterExtras.build(character)
	add_child(_extras)


func _set_accessories(items: Dictionary) -> void:
	for slot in ACCESSORY_SLOTS:
		var wanted := String(items.get(slot, ""))
		var current: Node3D = _accessory_nodes.get(slot)
		if current != null and String(current.get_meta("item_id", "")) == wanted:
			continue
		if current != null:
			current.queue_free()
			_accessory_nodes.erase(slot)
		if wanted.is_empty():
			continue
		var node := AccessoryVisuals.build(wanted)
		node.set_meta("item_id", wanted)
		add_child(node)
		_accessory_nodes[slot] = node


func is_emoting() -> bool:
	return _emoting


func set_weapon(weapon_id: String) -> void:
	for child in _weapon_holder.get_children():
		child.queue_free()
	if weapon_id.is_empty():
		_hold_offset = 0.0
		return
	_weapon_holder.add_child(WeaponVisuals.build(weapon_id))
	_hold_offset = HOLD_ANGLE


func play_attack(duration: float) -> void:
	if _emoting:
		stop_emote()
	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()
	var total := maxf(duration, 0.12)
	_attacking = true
	_attack_tween = create_tween()
	_attack_tween.tween_property(_arm_right, "rotation:x", 2.7, total * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(_arm_right, "rotation:x", 1.2, total * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_attack_tween.tween_property(_arm_right, "rotation:x", _hold_offset, total * 0.25)
	_attack_tween.finished.connect(func() -> void: _attacking = false)


func animate(speed: float, grounded: bool, delta: float) -> void:
	if _emoting or _attacking:
		return
	var amount := clampf(speed / 5.5, 0.0, 1.0)
	_phase += speed * delta * 1.6
	var swing := sin(_phase) * 0.9 * amount
	var arm_l := swing
	var arm_r := -swing + _hold_offset
	var leg_l := -swing
	var leg_r := swing
	if not grounded:
		arm_l = 2.4
		arm_r = 2.4
		leg_l = 0.35
		leg_r = -0.35
	var weight := clampf(14.0 * delta, 0.0, 1.0)
	_arm_left.rotation.x = lerpf(_arm_left.rotation.x, arm_l, weight)
	_arm_right.rotation.x = lerpf(_arm_right.rotation.x, arm_r, weight)
	_leg_left.rotation.x = lerpf(_leg_left.rotation.x, leg_l, weight)
	_leg_right.rotation.x = lerpf(_leg_right.rotation.x, leg_r, weight)


func play_emote(emote_id: String) -> bool:
	if emote_id not in EMOTES:
		return false
	stop_emote()
	_emoting = true
	_emote_tween = create_tween()
	match emote_id:
		"wave":
			_emote_tween.tween_property(_arm_right, "rotation:x", 2.9, 0.2)
			for i in 3:
				_emote_tween.tween_property(_arm_right, "rotation:z", -0.5, 0.15)
				_emote_tween.tween_property(_arm_right, "rotation:z", 0.5, 0.15)
			_emote_tween.tween_property(_arm_right, "rotation", Vector3.ZERO, 0.2)
		"spin":
			_emote_tween.tween_property(self, "rotation:y", rotation.y + TAU, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		"cheer":
			_emote_tween.tween_property(_arm_left, "rotation:x", 2.8, 0.2)
			_emote_tween.parallel().tween_property(_arm_right, "rotation:x", 2.8, 0.2)
			for i in 3:
				_emote_tween.tween_property(_arm_left, "rotation:z", 0.4, 0.15)
				_emote_tween.parallel().tween_property(_arm_right, "rotation:z", -0.4, 0.15)
				_emote_tween.tween_property(_arm_left, "rotation:z", -0.4, 0.15)
				_emote_tween.parallel().tween_property(_arm_right, "rotation:z", 0.4, 0.15)
			_emote_tween.tween_property(_arm_left, "rotation", Vector3.ZERO, 0.2)
			_emote_tween.parallel().tween_property(_arm_right, "rotation", Vector3.ZERO, 0.2)
	_emote_tween.finished.connect(func() -> void: _emoting = false)
	return true


func stop_emote() -> void:
	if _emote_tween != null and _emote_tween.is_valid():
		_emote_tween.kill()
	_emote_tween = null
	_emoting = false
	_arm_left.rotation = Vector3.ZERO
	_arm_right.rotation = Vector3.ZERO