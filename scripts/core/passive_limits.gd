class_name PassiveLimits
extends RefCounted

# Allowed range for each passive multiplier. Passives are small sidegrades,
# and stacked values from a character and a pet are clamped to these ranges.
const RANGES := {
	"air_accel": [0.8, 2.0],
	"fall_gravity": [0.7, 1.2],
	"ragdoll_time": [0.5, 1.3],
	"hitstun": [0.6, 1.3],
	"walk_speed": [0.9, 1.1],
	"jump": [0.9, 1.1],
	"gravity": [0.85, 1.15],
	"knockback_taken": [0.85, 1.15],
	"attack_interval": [0.6, 1.2],
}


static func clamp_value(key: String, value: float) -> float:
	if not RANGES.has(key):
		return value
	var limits: Array = RANGES[key]
	return clampf(value, float(limits[0]), float(limits[1]))


static func is_valid(passive: Dictionary) -> bool:
	for key in passive:
		if not RANGES.has(key):
			return false
		var limits: Array = RANGES[key]
		var value := float(passive[key])
		if value < float(limits[0]) or value > float(limits[1]):
			return false
	return true