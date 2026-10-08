class_name PetController
extends Node

signal triggered(pet_id: String, center: Vector3)
signal barrier_created(position: Vector3, yaw: float, duration: float, width: float, height: float, color: Color)

const START_DELAY := 3.0

var owner_body: PlayerController
var pet_id: String = ""

var _cooldown: float = 0.0


func _ready() -> void:
	if owner_body.remote_input == null:
		_equip_from_data()
		PlayerData.equipment_changed.connect(_on_equipment_changed)


func _equip_from_data() -> void:
	var wanted := ""
	if PlayerData.is_signed_in:
		wanted = String(PlayerData.data["equipped"].get("pet", ""))
	set_pet(wanted)


func _on_equipment_changed(slot: String) -> void:
	if slot == "pet":
		_equip_from_data()


func set_pet(id: String) -> void:
	pet_id = id if PetDb.has(id) else ""
	_cooldown = START_DELAY if has_active_ability() else 0.0


func has_active_ability() -> bool:
	if pet_id.is_empty():
		return false
	return not PetDb.is_passive(PetDb.get_pet(pet_id))


# Passive pets never use a button. Their multipliers are read by the player controller.
func passive() -> Dictionary:
	var pet := PetDb.get_pet(pet_id)
	if PetDb.is_passive(pet):
		return pet.get("passive", {})
	return {}


func cooldown_remaining() -> float:
	return _cooldown


func is_ready() -> bool:
	return has_active_ability() and _cooldown <= 0.0


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if owner_body == null:
		return
	if owner_body.state != PlayerController.State.NORMAL or not owner_body.controllable:
		return
	var pressed := owner_body.frame_input().take(PlayerInput.PET)
	if pressed and is_ready():
		trigger()


func trigger() -> bool:
	var pet := PetDb.get_pet(pet_id)
	if pet.is_empty() or not is_ready():
		return false
	_cooldown = float(pet["cooldown"])
	var center := owner_body.global_position + Vector3(0.0, 1.0, 0.0)
	var color: Color = pet["color"]
	match String(pet["kind"]):
		PetDb.KIND_AREA:
			AbilityKit.area_hit(owner_body, pet_id, pet, center)
		PetDb.KIND_SLOW:
			AbilityKit.area_slow(owner_body, pet, center)
		PetDb.KIND_GUARD:
			owner_body.guard_remaining = maxf(owner_body.guard_remaining, float(pet["duration"]))
		PetDb.KIND_DASH:
			owner_body.dash_burst(AbilityKit.flat_aim(owner_body), float(pet["speed"]), float(pet["duration"]), float(pet["immune"]))
		PetDb.KIND_BARRIER:
			_barrier(pet, color)
	if not NetBus.headless and String(pet["kind"]) != PetDb.KIND_BARRIER:
		NetEffects.blast(owner_body.get_parent(), center, PetDb.effect_radius(pet), color)
	triggered.emit(pet_id, center)
	return true


func _barrier(pet: Dictionary, color: Color) -> void:
	var aim := AbilityKit.flat_aim(owner_body)
	var at := owner_body.global_position + aim * float(pet["distance"])
	var yaw := atan2(-aim.x, -aim.z)
	Barrier.spawn(owner_body.get_parent(), at, yaw, float(pet["duration"]), float(pet["width"]), float(pet["height"]), true, color)
	barrier_created.emit(at, yaw, float(pet["duration"]), float(pet["width"]), float(pet["height"]), color)