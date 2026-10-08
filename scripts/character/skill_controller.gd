class_name SkillController
extends Node

signal triggered(character_id: String, center: Vector3)

const START_DELAY := 2.0

var owner_body: PlayerController
var character_id: String = "rifter"

var _cooldown: float = 0.0


func _ready() -> void:
	if owner_body.remote_input == null:
		_equip_from_data()
		PlayerData.equipment_changed.connect(_on_equipment_changed)


func _equip_from_data() -> void:
	var wanted := "rifter"
	if PlayerData.is_signed_in:
		wanted = String(PlayerData.data["equipped"].get("character", "rifter"))
	set_character(wanted)


func _on_equipment_changed(slot: String) -> void:
	if slot == "character":
		_equip_from_data()


func set_character(id: String) -> void:
	character_id = id if CharacterDb.has(id) else "rifter"
	_cooldown = START_DELAY


func passive() -> Dictionary:
	return CharacterDb.get_passive(character_id)


func skill() -> Dictionary:
	return CharacterDb.get_skill(character_id)


func cooldown_remaining() -> float:
	return _cooldown


func is_ready() -> bool:
	return _cooldown <= 0.0


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if owner_body == null:
		return
	if owner_body.state != PlayerController.State.NORMAL or not owner_body.controllable:
		return
	var pressed := owner_body.frame_input().take(PlayerInput.ABILITY)
	if pressed and is_ready():
		trigger()


func trigger() -> bool:
	var data := skill()
	if data.is_empty() or not is_ready():
		return false
	_cooldown = float(data["cooldown"])
	var center := owner_body.global_position + Vector3(0.0, 1.0, 0.0)
	match String(data["kind"]):
		CharacterDb.KIND_BLINK:
			_blink(data)
		CharacterDb.KIND_GUARD:
			owner_body.guard_remaining = maxf(owner_body.guard_remaining, float(data["duration"]))
		CharacterDb.KIND_HASTE:
			owner_body.apply_haste(float(data["factor"]), float(data["duration"]))
		CharacterDb.KIND_LEAP:
			var forward := AbilityKit.flat_aim(owner_body)
			owner_body.launch(Vector3(forward.x * float(data["forward"]), float(data["up"]), forward.z * float(data["forward"])))
		CharacterDb.KIND_AREA:
			AbilityKit.area_hit(owner_body, character_id, data, center)
		CharacterDb.KIND_SLOW:
			AbilityKit.area_slow(owner_body, data, center)
	if not NetBus.headless:
		NetEffects.blast(owner_body.get_parent(), center, CharacterDb.effect_radius(data), CharacterDb.color_of(character_id))
	triggered.emit(character_id, center)
	return true


func _blink(data: Dictionary) -> void:
	var direction := AbilityKit.flat_aim(owner_body)
	var distance := float(data["distance"])
	var from := owner_body.global_position + Vector3(0.0, 1.0, 0.0)
	var excluded: Array[RID] = [owner_body.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * distance, PhysicsLayers.WORLD, excluded)
	var hit := owner_body.get_world_3d().direct_space_state.intersect_ray(query)
	var travel := distance
	if not hit.is_empty():
		travel = maxf(from.distance_to(hit["position"]) - 0.6, 0.0)
	owner_body.global_position += direction * travel
	owner_body.face(direction)