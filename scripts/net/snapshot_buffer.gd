class_name SnapshotBuffer
extends RefCounted

const MAX_SNAPSHOTS := 40
const INTERP_DELAY := 0.1
const SNAP_DISTANCE := 6.0
const OFFSET_SMOOTHING := 0.05

var _snapshots: Array[Dictionary] = []
var _offset: float = 0.0
var _has_offset: bool = false


func push(snapshot: Dictionary, local_time: float) -> void:
	var t := float(snapshot["t"])
	if not _snapshots.is_empty() and t <= float(_snapshots[_snapshots.size() - 1]["t"]):
		return
	var sample_offset := t - local_time
	if _has_offset:
		_offset = lerpf(_offset, sample_offset, OFFSET_SMOOTHING)
	else:
		_offset = sample_offset
		_has_offset = true
	_snapshots.append(snapshot)
	while _snapshots.size() > MAX_SNAPSHOTS:
		_snapshots.pop_front()


func sample(local_now: float) -> Dictionary:
	if _snapshots.is_empty():
		return {}
	var render_time := local_now + _offset - INTERP_DELAY
	var count := _snapshots.size()
	var index := -1
	for i in count:
		if float(_snapshots[i]["t"]) <= render_time:
			index = i
		else:
			break
	if index == -1:
		return _snapshots[0]
	if index == count - 1:
		return _snapshots[index]
	var a := _snapshots[index]
	var b := _snapshots[index + 1]
	var span := float(b["t"]) - float(a["t"])
	var alpha := 1.0
	if span > 0.0001:
		alpha = clampf((render_time - float(a["t"])) / span, 0.0, 1.0)
	return {
		"t": render_time,
		"c": b["c"],
		"p": _blend_players(a["p"], b["p"], alpha),
		"d": _blend_dynamics(a["d"], b["d"], alpha),
		"j": _blend_projectiles(a["j"], b["j"], alpha),
	}


func _blend_players(a: PackedFloat32Array, b: PackedFloat32Array, alpha: float) -> PackedFloat32Array:
	var out := b.duplicate()
	if a.size() != b.size():
		return out
	var stride := SnapshotCodec.PLAYER_STRIDE
	for i in SnapshotCodec.record_count(b, stride):
		var o := i * stride
		var active_a := (int(a[o + 6]) & SnapshotCodec.FLAG_ACTIVE) != 0
		var active_b := (int(b[o + 6]) & SnapshotCodec.FLAG_ACTIVE) != 0
		if not active_a or not active_b:
			continue
		var from_pos := Vector3(a[o + 1], a[o + 2], a[o + 3])
		var to_pos := Vector3(b[o + 1], b[o + 2], b[o + 3])
		if from_pos.distance_to(to_pos) > SNAP_DISTANCE:
			continue
		for k in [1, 2, 3, 5, 9, 10, 11]:
			out[o + k] = lerpf(a[o + k], b[o + k], alpha)
		out[o + 4] = lerp_angle(a[o + 4], b[o + 4], alpha)
		var ragdoll_a := (int(a[o + 6]) & SnapshotCodec.FLAG_RAGDOLL) != 0
		var ragdoll_b := (int(b[o + 6]) & SnapshotCodec.FLAG_RAGDOLL) != 0
		if ragdoll_a and ragdoll_b:
			var qa := Quaternion(a[o + 12], a[o + 13], a[o + 14], a[o + 15]).normalized()
			var qb := Quaternion(b[o + 12], b[o + 13], b[o + 14], b[o + 15]).normalized()
			var q := qa.slerp(qb, alpha)
			out[o + 12] = q.x
			out[o + 13] = q.y
			out[o + 14] = q.z
			out[o + 15] = q.w
	return out


func _blend_dynamics(a: PackedFloat32Array, b: PackedFloat32Array, alpha: float) -> PackedFloat32Array:
	var out := b.duplicate()
	if a.size() != b.size():
		return out
	var stride := SnapshotCodec.DYNAMIC_STRIDE
	for i in SnapshotCodec.record_count(b, stride):
		var o := i * stride
		if absf(a[o] - b[o]) > 0.5:
			continue
		var from_pos := Vector3(a[o + 1], a[o + 2], a[o + 3])
		var to_pos := Vector3(b[o + 1], b[o + 2], b[o + 3])
		if from_pos.distance_to(to_pos) > SNAP_DISTANCE:
			continue
		for k in [1, 2, 3]:
			out[o + k] = lerpf(a[o + k], b[o + k], alpha)
		var qa := Quaternion(a[o + 4], a[o + 5], a[o + 6], a[o + 7]).normalized()
		var qb := Quaternion(b[o + 4], b[o + 5], b[o + 6], b[o + 7]).normalized()
		var q := qa.slerp(qb, alpha)
		out[o + 4] = q.x
		out[o + 5] = q.y
		out[o + 6] = q.z
		out[o + 7] = q.w
	return out


func _blend_projectiles(a: PackedFloat32Array, b: PackedFloat32Array, alpha: float) -> PackedFloat32Array:
	var out := b.duplicate()
	var stride := SnapshotCodec.PROJECTILE_STRIDE
	var previous := {}
	for i in SnapshotCodec.record_count(a, stride):
		var o := i * stride
		previous[int(a[o])] = Vector3(a[o + 2], a[o + 3], a[o + 4])
	for i in SnapshotCodec.record_count(b, stride):
		var o := i * stride
		var id := int(b[o])
		if not previous.has(id):
			continue
		var from_pos: Vector3 = previous[id]
		var blended := from_pos.lerp(Vector3(b[o + 2], b[o + 3], b[o + 4]), alpha)
		out[o + 2] = blended.x
		out[o + 3] = blended.y
		out[o + 4] = blended.z
	return out