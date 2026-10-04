class_name CombatResolver
extends RefCounted

const DAMAGE_SCALE := 80.0
const GUARD_REDUCTION := 0.35


static func make_hit(weapon: Dictionary, weapon_id: String, direction: Vector3, attacker: Node) -> Dictionary:
	var flat := Vector3(direction.x, 0.0, direction.z)
	flat = flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD
	return {
		"weapon": weapon_id,
		"damage": float(weapon["damage"]),
		"knockback": float(weapon["knockback"]),
		"lift": float(weapon["lift"]),
		"direction": flat,
		"attacker": attacker,
	}


static func raw_impulse(hit: Dictionary) -> Vector3:
	var direction: Vector3 = hit["direction"]
	return direction * float(hit["knockback"]) + Vector3.UP * float(hit["lift"])


static func victim_impulse(hit: Dictionary, damage_percent: float, guarding: bool) -> Vector3:
	var scale := 1.0 + damage_percent / DAMAGE_SCALE
	if guarding:
		scale *= GUARD_REDUCTION
	return raw_impulse(hit) * scale


static func victim_damage(hit: Dictionary, guarding: bool) -> float:
	var amount := float(hit["damage"])
	return amount * GUARD_REDUCTION if guarding else amount


static func resolve_target(collider: Node) -> Node:
	if collider == null:
		return null
	if collider.has_method("apply_hit"):
		return collider
	var parent := collider.get_parent()
	if parent != null and parent.has_method("apply_hit"):
		return parent
	return null


static func deliver(target: Node, hit: Dictionary) -> void:
	if target != null and target.has_method("apply_hit"):
		target.apply_hit(hit)