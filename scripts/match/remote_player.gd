class_name RemotePlayer
extends Node3D

var slot: int = 0
var model: CharacterModel
var display_name: String = ""
var team: String = "A"

var _label: Label3D
var _pet: PetNode
var _weapon_index: int = -2
var _damage_shown: int = -1
var _was_ragdoll: bool = false


func setup(slot_id: int, player_name: String, player_team: String, skin_id: String, character_id: String, accessories: Dictionary = {}, pet_id: String = "") -> void:
	slot = slot_id
	display_name = player_name
	team = player_team
	model = CharacterModel.new()
	add_child(model)
	model.apply_appearance(skin_id, character_id, accessories)
	_label = Label3D.new()
	_label.font_size = 40
	_label.pixel_size = 0.006
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = UiTheme.ACCENT if team == "A" else UiTheme.DANGER
	_label.position = Vector3(0.0, 2.15, 0.0)
	add_child(_label)
	_pet = PetNode.new()
	_pet.top_level = true
	_pet.follow_target = self
	add_child(_pet)
	_pet.setup(pet_id)
	_refresh_label(0)


func _refresh_label(damage: int) -> void:
	_damage_shown = damage
	_label.text = "%s  %d%%" % [display_name, damage]


func play_attack(duration: float) -> void:
	model.play_attack(duration)


func play_emote(emote_id: String) -> void:
	model.play_emote(emote_id)


func pulse_pet() -> void:
	_pet.pulse()


func apply_state(record: Dictionary, delta: float) -> void:
	var flags := int(record["flags"])
	var active := (flags & SnapshotCodec.FLAG_ACTIVE) != 0
	visible = active
	if not active:
		return
	var weapon_index := int(record["weapon"])
	if weapon_index != _weapon_index:
		_weapon_index = weapon_index
		var weapon_id := ""
		if weapon_index >= 0 and weapon_index < WeaponDb.ORDER.size():
			weapon_id = WeaponDb.ORDER[weapon_index]
		model.set_weapon(weapon_id)
	var damage := roundi(float(record["damage"]))
	if damage != _damage_shown:
		_refresh_label(damage)
	global_position = record["pos"]
	if (flags & SnapshotCodec.FLAG_RAGDOLL) != 0:
		model.stop_emote()
		var torso: Transform3D = record["torso"]
		model.global_transform = torso * Transform3D(Basis.IDENTITY, Vector3(0.0, -CharacterModel.TORSO_Y, 0.0))
		_was_ragdoll = true
		return
	_was_ragdoll = false
	model.position = Vector3.ZERO
	if not model.is_emoting():
		model.rotation = Vector3(0.0, float(record["yaw"]), 0.0)
	model.animate(float(record["speed"]), (flags & SnapshotCodec.FLAG_GROUNDED) != 0, delta)