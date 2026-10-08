class_name PetDb
extends RefCounted

const KIND_AREA := "area"
const KIND_SLOW := "slow"
const KIND_GUARD := "guard"
const KIND_DASH := "dash"
const KIND_BARRIER := "barrier"
const KIND_PASSIVE := "passive"

const ORDER: Array[String] = [
	"pet_volt", "pet_blaze", "pet_frost", "pet_aero", "pet_terra", "pet_shadow", "pet_riftling",
	"pet_falcon", "pet_catty", "pet_creaton",
]
const MAX_DAMAGE := 6.0
const MAX_KNOCKBACK := 12.0
const MIN_COOLDOWN := 8.0
const MAX_BARRIER_SECONDS := 8.0

const PETS := {
	"pet_volt": {
		"name": "Volt", "ability_name": "Static Burst", "color": Color("#ffe14d"),
		"desc": "Shocks nearby players with an electric burst.",
		"kind": "area", "cooldown": 12.0, "radius": 3.2, "damage": 3.0, "knockback": 4.0, "lift": 2.5, "mode": "outward",
	},
	"pet_blaze": {
		"name": "Blaze", "ability_name": "Fire Pulse", "color": Color("#ff7a4d"),
		"desc": "A hot pulse that throws nearby players back.",
		"kind": "area", "cooldown": 14.0, "radius": 3.5, "damage": 5.0, "knockback": 11.0, "lift": 3.0, "mode": "outward",
	},
	"pet_frost": {
		"name": "Frost", "ability_name": "Chill Wave", "color": Color("#8fd3ff"),
		"desc": "Slows nearby players for a few seconds.",
		"kind": "slow", "cooldown": 14.0, "radius": 5.0, "slow_factor": 0.5, "duration": 3.0,
	},
	"pet_aero": {
		"name": "Aero", "ability_name": "Gust", "color": Color("#c9f27a"),
		"desc": "A wide gust that pushes players away without hurting them.",
		"kind": "area", "cooldown": 12.0, "radius": 6.0, "damage": 0.0, "knockback": 9.0, "lift": 2.0, "mode": "outward",
	},
	"pet_terra": {
		"name": "Terra", "ability_name": "Earth Shell", "color": Color("#b08a5a"),
		"desc": "Protects you from most knockback for a moment.",
		"kind": "guard", "cooldown": 18.0, "duration": 1.8,
	},
	"pet_shadow": {
		"name": "Shadow", "ability_name": "Shadow Step", "color": Color("#7a5cff"),
		"desc": "A quick dash that lets you slip past hits.",
		"kind": "dash", "cooldown": 10.0, "speed": 22.0, "duration": 0.22, "immune": 0.45,
	},
	"pet_riftling": {
		"name": "Riftling", "ability_name": "Rift Pull", "color": Color("#38e8c6"),
		"desc": "Pulls nearby players toward you.",
		"kind": "area", "cooldown": 16.0, "radius": 7.0, "damage": 2.0, "knockback": 8.0, "lift": 1.5, "mode": "inward",
	},
	"pet_falcon": {
		"name": "Falcon", "ability_name": "Wind Rider", "color": Color("#e0b36a"),
		"desc": "Passive. Better air control and slower falling, so you recover from knockback more easily.",
		"kind": "passive", "passive": {"air_accel": 1.6, "fall_gravity": 0.82},
	},
	"pet_catty": {
		"name": "Catty", "ability_name": "Cat Reflex", "color": Color("#ffb3d9"),
		"desc": "Passive. You get back on your feet faster after being knocked down.",
		"kind": "passive", "passive": {"ragdoll_time": 0.6, "hitstun": 0.75},
	},
	"pet_creaton": {
		"name": "Creaton", "ability_name": "Barrier", "color": Color("#6ee7b7"),
		"desc": "Raises a solid wall in front of you for a few seconds.",
		"kind": "barrier", "cooldown": 20.0, "duration": 6.0, "width": 4.0, "height": 2.4, "distance": 2.2,
	},
}


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(ORDER)
	return result


static func has(pet_id: String) -> bool:
	return PETS.has(pet_id)


static func get_pet(pet_id: String) -> Dictionary:
	return PETS.get(pet_id, {})


static func is_passive(pet: Dictionary) -> bool:
	return String(pet.get("kind", "")) == KIND_PASSIVE


static func effect_radius(pet: Dictionary) -> float:
	match String(pet.get("kind", "")):
		KIND_AREA, KIND_SLOW:
			return float(pet.get("radius", 3.0))
	return 1.6


# Pets are sidegrades: slow, rare and never a raw stat boost.
static func is_balanced(pet: Dictionary) -> bool:
	if pet.is_empty():
		return false
	if is_passive(pet):
		return PassiveLimits.is_valid(pet.get("passive", {}))
	if float(pet.get("cooldown", 0.0)) < MIN_COOLDOWN:
		return false
	if float(pet.get("damage", 0.0)) > MAX_DAMAGE:
		return false
	if float(pet.get("knockback", 0.0)) > MAX_KNOCKBACK:
		return false
	if String(pet.get("kind", "")) == KIND_BARRIER:
		return float(pet.get("duration", 0.0)) <= MAX_BARRIER_SECONDS and float(pet.get("width", 0.0)) <= 5.0
	return true