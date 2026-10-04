class_name WeaponDb
extends RefCounted

const KIND_MELEE := "melee"
const KIND_PROJECTILE := "projectile"
const KIND_HITSCAN := "hitscan"

const ORDER: Array[String] = ["sword", "hammer", "spear", "shield", "bow", "blaster", "rocket_launcher", "laser"]

const WEAPONS := {
	"sword": {
		"name": "Sword", "kind": "melee", "color": Color("#9fe8ff"),
		"damage": 8.0, "attack_interval": 0.45, "windup": 0.12, "cooldown": 0.1,
		"range": 2.3, "arc": 110.0, "knockback": 7.0, "lift": 2.5, "auto": false,
	},
	"hammer": {
		"name": "Hammer", "kind": "melee", "color": Color("#ffc857"),
		"damage": 18.0, "attack_interval": 1.1, "windup": 0.35, "cooldown": 0.3,
		"range": 2.6, "arc": 140.0, "knockback": 15.0, "lift": 5.0, "auto": false,
	},
	"spear": {
		"name": "Spear", "kind": "melee", "color": Color("#c9f27a"),
		"damage": 7.0, "attack_interval": 0.55, "windup": 0.15, "cooldown": 0.1,
		"range": 3.6, "arc": 40.0, "knockback": 8.0, "lift": 1.5, "auto": false,
	},
	"shield": {
		"name": "Shield", "kind": "melee", "color": Color("#7aa7ff"),
		"damage": 4.0, "attack_interval": 0.8, "windup": 0.1, "cooldown": 0.15,
		"range": 1.9, "arc": 150.0, "knockback": 11.0, "lift": 1.5, "auto": false,
		"guard_time": 0.7,
	},
	"bow": {
		"name": "Bow", "kind": "projectile", "color": Color("#d9a273"),
		"damage": 9.0, "attack_interval": 0.8, "windup": 0.25, "cooldown": 0.0,
		"knockback": 6.0, "lift": 1.0, "auto": false, "spread": 0.0,
		"projectile_speed": 30.0, "gravity": 1.0, "projectile_mass": 0.2,
		"projectile_radius": 0.08, "lifetime": 4.0, "explosion_radius": 0.0,
		"projectile_shape": "arrow",
	},
	"blaster": {
		"name": "Blaster", "kind": "projectile", "color": Color("#38e8c6"),
		"damage": 3.0, "attack_interval": 0.18, "windup": 0.0, "cooldown": 0.0,
		"knockback": 3.5, "lift": 0.6, "auto": true, "spread": 1.5,
		"projectile_speed": 40.0, "gravity": 0.05, "projectile_mass": 0.05,
		"projectile_radius": 0.1, "lifetime": 2.5, "explosion_radius": 0.0,
		"projectile_shape": "bolt",
	},
	"rocket_launcher": {
		"name": "Rocket Launcher", "kind": "projectile", "color": Color("#ff5a5f"),
		"damage": 14.0, "attack_interval": 1.6, "windup": 0.2, "cooldown": 0.4,
		"knockback": 16.0, "lift": 6.0, "auto": false, "spread": 0.0,
		"projectile_speed": 18.0, "gravity": 0.0, "projectile_mass": 1.0,
		"projectile_radius": 0.15, "lifetime": 5.0, "explosion_radius": 4.0,
		"projectile_shape": "rocket",
	},
	"laser": {
		"name": "Laser", "kind": "hitscan", "color": Color("#ff4fd8"),
		"damage": 1.5, "attack_interval": 0.1, "windup": 0.0, "cooldown": 0.0,
		"range": 30.0, "knockback": 1.4, "lift": 0.2, "auto": true,
	},
}


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(ORDER)
	return result


static func has(weapon_id: String) -> bool:
	return WEAPONS.has(weapon_id)


static func get_weapon(weapon_id: String) -> Dictionary:
	return WEAPONS.get(weapon_id, {})