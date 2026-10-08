class_name CharacterDb
extends RefCounted

const KIND_BLINK := "blink"
const KIND_GUARD := "guard"
const KIND_HASTE := "haste"
const KIND_LEAP := "leap"
const KIND_AREA := "area"
const KIND_SLOW := "slow"

const ORDER: Array[String] = ["rifter", "vanguard", "striker", "sprite", "titan", "oracle"]
const MIN_COOLDOWN := 8.0
const MAX_DAMAGE := 6.0
const MAX_KNOCKBACK := 12.0

const CHARACTERS := {
	"rifter": {
		"name": "Rifter", "role": "All-rounder", "color": Color("#38e8c6"),
		"desc": "A balanced runner who slips through gaps in the Rift.",
		"skill": {"name": "Rift Blink", "kind": "blink", "cooldown": 10.0, "distance": 6.0, "desc": "Blink forward a short distance."},
		"passive_name": "Steady Footing", "passive_desc": "Recover from hits a little faster.",
		"passive": {"hitstun": 0.9},
	},
	"vanguard": {
		"name": "Vanguard", "role": "Tank", "color": Color("#ff5a5f"),
		"desc": "Red-armored front liner who holds the line.",
		"skill": {"name": "Bulwark", "kind": "guard", "cooldown": 14.0, "duration": 1.6, "desc": "Brace yourself and shrug off most knockback."},
		"passive_name": "Heavy Frame", "passive_desc": "Take less knockback, but walk a bit slower.",
		"passive": {"knockback_taken": 0.92, "walk_speed": 0.96},
	},
	"striker": {
		"name": "Striker", "role": "Attacker", "color": Color("#ffc857"),
		"desc": "A fast hitter who lives on momentum.",
		"skill": {"name": "Overdrive", "kind": "haste", "cooldown": 16.0, "factor": 0.7, "duration": 4.0, "desc": "Attack much faster for a few seconds."},
		"passive_name": "Reckless", "passive_desc": "Attack slightly faster, but take a bit more knockback.",
		"passive": {"attack_interval": 0.95, "knockback_taken": 1.06},
	},
	"sprite": {
		"name": "Sprite", "role": "Mobility", "color": Color("#7a5cff"),
		"desc": "A light climber who loves the air.",
		"skill": {"name": "Sky Leap", "kind": "leap", "cooldown": 8.0, "up": 11.0, "forward": 5.0, "desc": "Leap high and forward."},
		"passive_name": "Featherweight", "passive_desc": "Float and jump better, but take more knockback.",
		"passive": {"gravity": 0.9, "jump": 1.05, "knockback_taken": 1.08},
	},
	"titan": {
		"name": "Titan", "role": "Bruiser", "color": Color("#b08a5a"),
		"desc": "A slow giant that is hard to move.",
		"skill": {"name": "Ground Slam", "kind": "area", "cooldown": 15.0, "radius": 3.8, "damage": 6.0, "knockback": 9.0, "lift": 4.0, "mode": "outward", "desc": "Slam the ground and throw nearby players away."},
		"passive_name": "Immovable", "passive_desc": "Take much less knockback, but move and jump less.",
		"passive": {"knockback_taken": 0.88, "walk_speed": 0.94, "jump": 0.95},
	},
	"oracle": {
		"name": "Oracle", "role": "Control", "color": Color("#8fd3ff"),
		"desc": "A seer who bends time around the fight.",
		"skill": {"name": "Time Snare", "kind": "slow", "cooldown": 15.0, "radius": 5.5, "slow_factor": 0.55, "duration": 2.5, "desc": "Slow nearby players."},
		"passive_name": "Foresight", "passive_desc": "Get back on your feet faster after a fall.",
		"passive": {"ragdoll_time": 0.8, "hitstun": 0.9},
	},
}


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(ORDER)
	return result


static func has(character_id: String) -> bool:
	return CHARACTERS.has(character_id)


static func get_character(character_id: String) -> Dictionary:
	return CHARACTERS.get(character_id, {})


static func get_skill(character_id: String) -> Dictionary:
	return get_character(character_id).get("skill", {})


static func get_passive(character_id: String) -> Dictionary:
	return get_character(character_id).get("passive", {})


static func color_of(character_id: String) -> Color:
	return get_character(character_id).get("color", Color("#38e8c6"))


static func effect_radius(skill: Dictionary) -> float:
	match String(skill.get("kind", "")):
		KIND_AREA, KIND_SLOW:
			return float(skill.get("radius", 3.0))
	return 1.4


static func is_balanced(character_id: String) -> bool:
	var character := get_character(character_id)
	if character.is_empty():
		return false
	if not PassiveLimits.is_valid(character.get("passive", {})):
		return false
	var skill: Dictionary = character.get("skill", {})
	if float(skill.get("cooldown", 0.0)) < MIN_COOLDOWN:
		return false
	if float(skill.get("damage", 0.0)) > MAX_DAMAGE or float(skill.get("knockback", 0.0)) > MAX_KNOCKBACK:
		return false
	if String(skill.get("kind", "")) == KIND_HASTE and float(skill.get("factor", 1.0)) < 0.6:
		return false
	if String(skill.get("kind", "")) == KIND_GUARD and float(skill.get("duration", 0.0)) > 2.5:
		return false
	return true