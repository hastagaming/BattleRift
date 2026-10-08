class_name SnapshotCodec
extends RefCounted

const PLAYER_STRIDE := 18
const DYNAMIC_STRIDE := 9
const PROJECTILE_STRIDE := 8

const FLAG_GROUNDED := 1
const FLAG_RAGDOLL := 2
const FLAG_GUARD := 4
const FLAG_ACTIVE := 8


@warning_ignore("integer_division")
static func record_count(data: PackedFloat32Array, stride: int) -> int:
	return data.size() / stride


static func append_player(out: PackedFloat32Array, slot: int, pos: Vector3, yaw: float, speed: float, flags: int, damage: float, weapon_index: int, torso: Transform3D, pet_cooldown: float = 0.0, skill_cooldown: float = 0.0) -> void:
	var q := torso.basis.get_rotation_quaternion()
	out.append_array(PackedFloat32Array([
		float(slot), pos.x, pos.y, pos.z, yaw, speed, float(flags), damage, float(weapon_index),
		torso.origin.x, torso.origin.y, torso.origin.z, q.x, q.y, q.z, q.w, pet_cooldown, skill_cooldown,
	]))


static func read_player(data: PackedFloat32Array, index: int) -> Dictionary:
	var b := index * PLAYER_STRIDE
	var q := Quaternion(data[b + 12], data[b + 13], data[b + 14], data[b + 15]).normalized()
	return {
		"slot": int(data[b]),
		"pos": Vector3(data[b + 1], data[b + 2], data[b + 3]),
		"yaw": data[b + 4],
		"speed": data[b + 5],
		"flags": int(data[b + 6]),
		"damage": data[b + 7],
		"weapon": int(data[b + 8]),
		"torso": Transform3D(Basis(q), Vector3(data[b + 9], data[b + 10], data[b + 11])),
		"pet_cd": data[b + 16],
		"skill_cd": data[b + 17],
	}


static func append_dynamic(out: PackedFloat32Array, flag: float, xform: Transform3D, extra: float) -> void:
	var q := xform.basis.get_rotation_quaternion()
	out.append_array(PackedFloat32Array([
		flag, xform.origin.x, xform.origin.y, xform.origin.z, q.x, q.y, q.z, q.w, extra,
	]))


static func read_dynamic(data: PackedFloat32Array, index: int) -> Dictionary:
	var b := index * DYNAMIC_STRIDE
	var q := Quaternion(data[b + 4], data[b + 5], data[b + 6], data[b + 7]).normalized()
	var origin := Vector3(data[b + 1], data[b + 2], data[b + 3])
	return {
		"flag": data[b],
		"pos": origin,
		"xform": Transform3D(Basis(q), origin),
		"extra": data[b + 8],
	}


static func append_projectile(out: PackedFloat32Array, id: int, kind: int, pos: Vector3, velocity: Vector3) -> void:
	out.append_array(PackedFloat32Array([
		float(id), float(kind), pos.x, pos.y, pos.z, velocity.x, velocity.y, velocity.z,
	]))


static func read_projectile(data: PackedFloat32Array, index: int) -> Dictionary:
	var b := index * PROJECTILE_STRIDE
	return {
		"id": int(data[b]),
		"kind": int(data[b + 1]),
		"pos": Vector3(data[b + 2], data[b + 3], data[b + 4]),
		"vel": Vector3(data[b + 5], data[b + 6], data[b + 7]),
	}