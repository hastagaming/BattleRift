class_name PetVisuals
extends RefCounted

# Every pet is built from rounded shapes with its own silhouette. Parts tagged "wing" flap and
# parts tagged "spin" turn, see PetNode. The pet faces -Z and the origin is the center of its body.

const DARK := Color("#10131c")


static func _eyes(root: Node3D, x: float, y: float, z: float, size: float, color: Color = DARK) -> void:
	for side in [-1.0, 1.0]:
		SmoothMesh.ellipsoid(root, Vector3(size, size * 1.15, size * 0.8), color, Vector3(x * side, y, z))
		SmoothMesh.sphere(root, size * 0.35, Color.WHITE, Vector3(x * side + size * 0.25, y + size * 0.35, z - size * 0.55))


static func _paws(root: Node3D, color: Color, front_z: float, back_z: float, x: float, y: float, size: float) -> void:
	for side in [-1.0, 1.0]:
		SmoothMesh.ellipsoid(root, Vector3(size, size * 0.7, size * 1.2), color, Vector3(x * side, y, front_z))
		SmoothMesh.ellipsoid(root, Vector3(size, size * 0.7, size * 1.2), color, Vector3(x * side, y, back_z))


static func _wing(root: Node3D, side: float, at: Vector3, length: float, depth: float, color: Color, tip_color: Color) -> void:
	var wing := SmoothMesh.pivot(root, at, "wing", side)
	SmoothMesh.ellipsoid(wing, Vector3(length, 0.04, depth), color, Vector3(side * length * 0.95, 0.03, 0.02), false, Vector3(0.0, 0.0, side * 12.0))
	SmoothMesh.ellipsoid(wing, Vector3(length * 0.72, 0.035, depth * 0.8), tip_color, Vector3(side * length * 1.25, 0.08, 0.07), false, Vector3(0.0, side * 12.0, side * 16.0))


static func _volt(root: Node3D, c: Color) -> void:
	var spark := Color("#fffbd0")
	SmoothMesh.ellipsoid(root, Vector3(0.17, 0.15, 0.3), c, Vector3(0.0, -0.02, 0.06))
	SmoothMesh.ellipsoid(root, Vector3(0.14, 0.12, 0.15), c, Vector3(0.0, 0.1, -0.22))
	SmoothMesh.ellipsoid(root, Vector3(0.06, 0.045, 0.06), spark, Vector3(0.0, 0.05, -0.34))
	SmoothMesh.sphere(root, 0.02, DARK, Vector3(0.0, 0.07, -0.395))
	for side in [-1.0, 1.0]:
		SmoothMesh.ellipsoid(root, Vector3(0.055, 0.06, 0.03), c.darkened(0.1), Vector3(0.1 * side, 0.2, -0.18))
	_eyes(root, 0.06, 0.13, -0.33, 0.03)
	var crest: Array[Vector3] = [Vector3(0.0, 0.25, -0.2), Vector3(0.05, 0.31, -0.2), Vector3(-0.01, 0.36, -0.2), Vector3(0.05, 0.43, -0.2)]
	for i in crest.size():
		SmoothMesh.ellipsoid(root, Vector3(0.045, 0.06, 0.03), spark, crest[i], true, Vector3(0.0, 0.0, 35.0 * (1.0 if i % 2 == 0 else -1.0)))
	var tail: Array[Vector3] = [Vector3(0.0, 0.0, 0.3), Vector3(0.03, 0.06, 0.37), Vector3(-0.025, 0.13, 0.43), Vector3(0.035, 0.2, 0.48), Vector3(-0.025, 0.28, 0.52), Vector3(0.03, 0.36, 0.55)]
	for i in tail.size():
		var shrink := 1.0 - 0.1 * float(i)
		SmoothMesh.ellipsoid(root, Vector3(0.075 * shrink, 0.075 * shrink, 0.11), c if i < tail.size() - 1 else spark, tail[i], i >= tail.size() - 2)
	_paws(root, c.darkened(0.15), -0.12, 0.2, 0.1, -0.15, 0.05)


static func _blaze(root: Node3D, c: Color) -> void:
	var cream := Color("#ffd9a8")
	SmoothMesh.ellipsoid(root, Vector3(0.19, 0.17, 0.26), c, Vector3(0.0, -0.02, 0.05))
	SmoothMesh.ellipsoid(root, Vector3(0.15, 0.13, 0.14), c, Vector3(0.0, 0.1, -0.2))
	SmoothMesh.ellipsoid(root, Vector3(0.07, 0.05, 0.09), cream, Vector3(0.0, 0.06, -0.32))
	SmoothMesh.sphere(root, 0.02, DARK, Vector3(0.0, 0.075, -0.405))
	for side in [-1.0, 1.0]:
		SmoothMesh.cone(root, 0.055, 0.14, c.darkened(0.1), Vector3(0.09 * side, 0.23, -0.18), false, Vector3(0.0, 0.0, -12.0 * side))
	_eyes(root, 0.065, 0.14, -0.318, 0.03)
	SmoothMesh.ellipsoid(root, Vector3(0.055, 0.15, 0.055), Color("#ffb347"), Vector3(0.0, 0.31, -0.17), true)
	SmoothMesh.ellipsoid(root, Vector3(0.04, 0.1, 0.04), Color("#ff5a1f"), Vector3(0.07, 0.27, -0.15), true, Vector3(0.0, 0.0, -18.0))
	SmoothMesh.ellipsoid(root, Vector3(0.04, 0.1, 0.04), Color("#ff5a1f"), Vector3(-0.07, 0.27, -0.15), true, Vector3(0.0, 0.0, 18.0))
	var tail: Array[Vector3] = [Vector3(0.0, 0.0, 0.3), Vector3(0.0, 0.05, 0.4), Vector3(0.0, 0.11, 0.48), Vector3(0.0, 0.18, 0.55)]
	for i in tail.size():
		SmoothMesh.ellipsoid(root, Vector3(0.08 - 0.01 * float(i), 0.065, 0.11), c, tail[i])
	SmoothMesh.ellipsoid(root, Vector3(0.075, 0.16, 0.075), Color("#ffb347"), Vector3(0.0, 0.3, 0.58), true)
	SmoothMesh.ellipsoid(root, Vector3(0.045, 0.1, 0.045), Color("#ff5a1f"), Vector3(0.0, 0.27, 0.58), true)
	_paws(root, c.darkened(0.25), -0.1, 0.2, 0.1, -0.17, 0.05)


static func _frost(root: Node3D, c: Color) -> void:
	var ice := Color("#d6f0ff")
	SmoothMesh.ellipsoid(root, Vector3(0.21, 0.2, 0.22), c, Vector3(0.0, -0.02, 0.03))
	SmoothMesh.ellipsoid(root, Vector3(0.15, 0.14, 0.14), c, Vector3(0.0, 0.15, -0.14))
	for side in [-1.0, 1.0]:
		SmoothMesh.ellipsoid(root, Vector3(0.045, 0.17, 0.03), c, Vector3(0.1 * side, 0.3, -0.1), false, Vector3(0.0, 0.0, -28.0 * side))
		SmoothMesh.ellipsoid(root, Vector3(0.025, 0.12, 0.015), Color("#ffd1e6"), Vector3(0.1 * side, 0.3, -0.115), false, Vector3(0.0, 0.0, -28.0 * side))
		SmoothMesh.sphere(root, 0.05, Color.WHITE, Vector3(0.12 * side, 0.1, -0.2))
		SmoothMesh.ellipsoid(root, Vector3(0.025, 0.08, 0.025), ice, Vector3(0.07 * side, 0.34, -0.2), true, Vector3(0.0, 0.0, -30.0 * side))
	SmoothMesh.ellipsoid(root, Vector3(0.03, 0.13, 0.03), ice, Vector3(0.0, 0.36, -0.2), true)
	_eyes(root, 0.06, 0.17, -0.265, 0.03)
	SmoothMesh.sphere(root, 0.075, Color.WHITE, Vector3(0.0, 0.0, 0.25))
	_paws(root, c.lightened(0.2), -0.12, 0.14, 0.1, -0.18, 0.055)


static func _aero(root: Node3D, c: Color) -> void:
	var beak := Color("#ffb347")
	SmoothMesh.sphere(root, 0.18, c, Vector3.ZERO)
	for side in [-1.0, 1.0]:
		SmoothMesh.sphere(root, 0.13, c, Vector3(0.16 * side, -0.03, 0.03))
	SmoothMesh.sphere(root, 0.12, c, Vector3(0.0, 0.06, 0.15))
	SmoothMesh.sphere(root, 0.1, c, Vector3(0.0, 0.14, -0.18))
	SmoothMesh.cone(root, 0.04, 0.11, beak, Vector3(0.0, 0.12, -0.31), false, Vector3(-90.0, 0.0, 0.0))
	_eyes(root, 0.05, 0.17, -0.265, 0.025)
	for side in [-1.0, 1.0]:
		_wing(root, side, Vector3(0.14 * side, 0.05, 0.0), 0.26, 0.1, Color("#e8ffd0"), Color("#ffffff"))
	for yaw in [-22.0, 0.0, 22.0]:
		SmoothMesh.ellipsoid(root, Vector3(0.04, 0.02, 0.14), Color("#e8ffd0"), Vector3(sin(deg_to_rad(yaw)) * 0.12, 0.03, 0.3), false, Vector3(0.0, -yaw, 0.0))


static func _terra(root: Node3D, c: Color) -> void:
	var shell := Color("#6e5236")
	SmoothMesh.ellipsoid(root, Vector3(0.2, 0.12, 0.24), Color("#c9a97a"), Vector3(0.0, -0.08, 0.0))
	SmoothMesh.ellipsoid(root, Vector3(0.26, 0.2, 0.3), shell, Vector3(0.0, 0.04, 0.05))
	var plates: Array[Vector3] = [Vector3(0.0, 0.235, 0.05), Vector3(0.12, 0.2, 0.0), Vector3(-0.12, 0.2, 0.0), Vector3(0.1, 0.19, 0.16), Vector3(-0.1, 0.19, 0.16)]
	for plate in plates:
		SmoothMesh.ellipsoid(root, Vector3(0.075, 0.035, 0.075), Color("#8a6a46"), plate)
	SmoothMesh.ellipsoid(root, Vector3(0.11, 0.1, 0.12), c, Vector3(0.0, 0.0, -0.28))
	SmoothMesh.ellipsoid(root, Vector3(0.06, 0.045, 0.05), c.lightened(0.15), Vector3(0.0, -0.03, -0.37))
	_eyes(root, 0.06, 0.05, -0.37, 0.025)
	SmoothMesh.ellipsoid(root, Vector3(0.03, 0.09, 0.02), Color("#6ac26a"), Vector3(0.02, 0.33, 0.08), false, Vector3(0.0, 0.0, 22.0))
	SmoothMesh.ellipsoid(root, Vector3(0.025, 0.07, 0.02), Color("#58b058"), Vector3(-0.03, 0.31, 0.1), false, Vector3(0.0, 0.0, -28.0))
	_paws(root, c.darkened(0.2), -0.14, 0.2, 0.18, -0.17, 0.06)


static func _shadow(root: Node3D, c: Color) -> void:
	var wisp := Color("#b8a6ff")
	SmoothMesh.ellipsoid(root, Vector3(0.16, 0.14, 0.28), c, Vector3(0.0, -0.02, 0.05))
	SmoothMesh.ellipsoid(root, Vector3(0.14, 0.12, 0.13), c, Vector3(0.0, 0.1, -0.2))
	for side in [-1.0, 1.0]:
		SmoothMesh.cone(root, 0.06, 0.2, c.darkened(0.15), Vector3(0.09 * side, 0.3, -0.18), false, Vector3(0.0, 0.0, -12.0 * side))
		SmoothMesh.ellipsoid(root, Vector3(0.045, 0.02, 0.02), Color.WHITE, Vector3(0.07 * side, 0.12, -0.315), true, Vector3(0.0, 0.0, 14.0 * side))
	for i in 8:
		var t := float(i) / 7.0
		var shrink := 1.0 - 0.6 * t
		SmoothMesh.ellipsoid(root, Vector3(0.055 * shrink, 0.05 * shrink, 0.09), c, Vector3(sin(t * 3.5) * 0.14, 0.02 + t * 0.22, 0.28 + t * 0.4), i == 7)
	var wisps: Array[Vector3] = [Vector3(0.22, 0.2, 0.1), Vector3(-0.22, 0.14, 0.0), Vector3(0.0, 0.4, 0.2)]
	for position in wisps:
		SmoothMesh.sphere(root, 0.03, wisp, position, true)
	_paws(root, c.darkened(0.2), -0.1, 0.22, 0.1, -0.15, 0.045)


static func _riftling(root: Node3D, c: Color) -> void:
	SmoothMesh.sphere(root, 0.17, c, Vector3.ZERO, true)
	SmoothMesh.sphere(root, 0.09, Color.WHITE, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		SmoothMesh.ellipsoid(root, Vector3(0.03, 0.04, 0.02), DARK, Vector3(0.06 * side, 0.03, -0.165))
	var ring_a := SmoothMesh.pivot(root, Vector3.ZERO, "spin", 1.4)
	SmoothMesh.ring(ring_a, 0.25, 0.29, c, Vector3.ZERO, true)
	var ring_b := SmoothMesh.pivot(root, Vector3.ZERO, "spin", -1.0)
	SmoothMesh.ring(ring_b, 0.3, 0.33, c.lightened(0.3), Vector3.ZERO, true, Vector3(90.0, 0.0, 0.0))
	var orbit := SmoothMesh.pivot(root, Vector3.ZERO, "spin", 2.2)
	for i in 4:
		var angle := TAU * float(i) / 4.0
		SmoothMesh.ellipsoid(orbit, Vector3(0.035, 0.08, 0.035), Color("#c8fff4"), Vector3(cos(angle) * 0.4, 0.0, sin(angle) * 0.4), true, Vector3(0.0, 0.0, 20.0))


static func _falcon(root: Node3D, c: Color) -> void:
	var gold := Color("#c9954a")
	SmoothMesh.ellipsoid(root, Vector3(0.14, 0.14, 0.28), c, Vector3(0.0, 0.0, 0.04), false, Vector3(-10.0, 0.0, 0.0))
	SmoothMesh.ellipsoid(root, Vector3(0.11, 0.1, 0.18), Color("#fff1d0"), Vector3(0.0, -0.04, -0.08), false, Vector3(-10.0, 0.0, 0.0))
	SmoothMesh.sphere(root, 0.11, gold, Vector3(0.0, 0.1, -0.26))
	SmoothMesh.cone(root, 0.042, 0.12, Color("#ffd166"), Vector3(0.0, 0.07, -0.39), false, Vector3(-90.0, 0.0, 0.0))
	SmoothMesh.cone(root, 0.026, 0.07, Color("#e0a93a"), Vector3(0.0, 0.03, -0.43), false, Vector3(-120.0, 0.0, 0.0))
	SmoothMesh.ellipsoid(root, Vector3(0.1, 0.025, 0.05), gold.darkened(0.3), Vector3(0.0, 0.17, -0.3))
	_eyes(root, 0.055, 0.12, -0.345, 0.024, Color("#3b2a10"))
	for side in [-1.0, 1.0]:
		_wing(root, side, Vector3(0.12 * side, 0.06, 0.0), 0.36, 0.13, gold, Color("#8a6428"))
	for yaw in [-20.0, 0.0, 20.0]:
		SmoothMesh.ellipsoid(root, Vector3(0.05, 0.02, 0.2), gold, Vector3(sin(deg_to_rad(yaw)) * 0.14, 0.0, 0.4), false, Vector3(0.0, -yaw, 0.0))
	for side in [-1.0, 1.0]:
		SmoothMesh.cone(root, 0.018, 0.07, Color("#2b2012"), Vector3(0.06 * side, -0.16, -0.02), false, Vector3(180.0, 0.0, 0.0))


static func _catty(root: Node3D, c: Color) -> void:
	var inner := c.darkened(0.2)
	SmoothMesh.ellipsoid(root, Vector3(0.19, 0.18, 0.24), c, Vector3(0.0, -0.02, 0.05))
	SmoothMesh.ellipsoid(root, Vector3(0.16, 0.14, 0.14), c, Vector3(0.0, 0.12, -0.15))
	for side in [-1.0, 1.0]:
		SmoothMesh.cone(root, 0.07, 0.16, c, Vector3(0.11 * side, 0.27, -0.14), false, Vector3(0.0, 0.0, -10.0 * side))
		SmoothMesh.cone(root, 0.04, 0.09, inner, Vector3(0.11 * side, 0.265, -0.165), false, Vector3(0.0, 0.0, -10.0 * side))
		for i in 3:
			SmoothMesh.ellipsoid(root, Vector3(0.1, 0.004, 0.004), Color.WHITE, Vector3(0.2 * side, 0.08 + 0.02 * float(i), -0.27), false, Vector3(0.0, side * (15.0 * float(i - 1)), 0.0))
	SmoothMesh.ellipsoid(root, Vector3(0.06, 0.045, 0.04), Color.WHITE, Vector3(0.0, 0.07, -0.27))
	SmoothMesh.sphere(root, 0.018, inner, Vector3(0.0, 0.095, -0.305))
	_eyes(root, 0.065, 0.17, -0.265, 0.03)
	for i in 10:
		var t := float(i) / 9.0
		SmoothMesh.ellipsoid(root, Vector3(0.05, 0.05, 0.075), c if i < 9 else c.lightened(0.25), Vector3(0.06 * sin(t * 5.0), 0.02 + t * 0.36, 0.27 + 0.1 * t), false, Vector3(-40.0 * t, 0.0, 0.0))
	SmoothMesh.ring(root, 0.11, 0.15, Color("#ff5a5f"), Vector3(0.0, 0.03, -0.1), false, Vector3(70.0, 0.0, 0.0))
	SmoothMesh.sphere(root, 0.03, Color("#ffc857"), Vector3(0.0, -0.03, -0.2), true)
	_paws(root, c.lightened(0.25), -0.1, 0.18, 0.1, -0.17, 0.05)


static func _creaton(root: Node3D, c: Color) -> void:
	SmoothMesh.ellipsoid(root, Vector3(0.2, 0.17, 0.2), c, Vector3.ZERO)
	SmoothMesh.sphere(root, 0.1, c.lightened(0.5), Vector3.ZERO, true)
	var crown: Array[Vector3] = [Vector3(0.0, 0.25, 0.0), Vector3(0.09, 0.22, 0.02), Vector3(-0.09, 0.22, 0.02)]
	for i in crown.size():
		var lean := 0.0 if i == 0 else (-18.0 if i == 1 else 18.0)
		SmoothMesh.ellipsoid(root, Vector3(0.04, 0.12, 0.04), Color("#c8fff0"), crown[i], true, Vector3(0.0, 0.0, lean))
	SmoothMesh.ellipsoid(root, Vector3(0.14, 0.12, 0.03), Color("#e8fff6"), Vector3(0.0, -0.01, -0.19), true)
	_eyes(root, 0.055, 0.04, -0.215, 0.022)
	for i in 3:
		SmoothMesh.ellipsoid(root, Vector3(0.04, 0.075, 0.04), c, Vector3(float(i - 1) * 0.09, -0.2, 0.02 * float(i % 2)))
	var orbit := SmoothMesh.pivot(root, Vector3.ZERO, "spin", 1.6)
	for side in [-1.0, 1.0]:
		SmoothMesh.sphere(orbit, 0.06, Color("#c8fff0"), Vector3(0.3 * side, 0.02, 0.0), true)


static func build(pet_id: String) -> Node3D:
	var root := Node3D.new()
	var pet := PetDb.get_pet(pet_id)
	if pet.is_empty():
		return root
	var color: Color = pet["color"]
	match pet_id:
		"pet_volt":
			_volt(root, color)
		"pet_blaze":
			_blaze(root, color)
		"pet_frost":
			_frost(root, color)
		"pet_aero":
			_aero(root, color)
		"pet_terra":
			_terra(root, color)
		"pet_shadow":
			_shadow(root, color)
		"pet_riftling":
			_riftling(root, color)
		"pet_falcon":
			_falcon(root, color)
		"pet_catty":
			_catty(root, color)
		"pet_creaton":
			_creaton(root, color)
		_:
			SmoothMesh.sphere(root, 0.22, color, Vector3.ZERO)
			_eyes(root, 0.08, 0.05, -0.19, 0.04)
	return root