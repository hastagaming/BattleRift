class_name Arena
extends Node3D

const PLATFORM_COLOR := Color("#20283d")
const ACCENT_COLOR := Color("#2c3552")
const TEAM_SPAWNS := {"A": [0, 1, 4, 8, 9, 6, 12], "B": [2, 3, 5, 10, 11, 7, 13]}

var spawn_points: Array[Vector3] = []
var dynamics: Array[Node3D] = []
var simulate: bool = true
var with_environment: bool = true


func _ready() -> void:
	if with_environment:
		_build_environment()
	_build_center()
	_build_east()
	_build_west()
	_build_north()
	_build_south()
	_build_barrels()
	_build_spawns()
	if not simulate:
		_make_inert(self)


func _dynamic(node: Node3D) -> void:
	add_child(node)
	dynamics.append(node)


func _make_inert(node: Node) -> void:
	node.set_physics_process(false)
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is Area3D:
		(node as Area3D).monitoring = false
		(node as Area3D).monitorable = false
	if node is AnimatableBody3D:
		(node as AnimatableBody3D).sync_to_physics = false
	if node is RigidBody3D:
		var body := node as RigidBody3D
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.freeze = true
	for child in node.get_children():
		_make_inert(child)


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#141a33")
	sky_material.sky_horizon_color = Color("#3d4c86")
	sky_material.ground_horizon_color = Color("#3d4c86")
	sky_material.ground_bottom_color = Color("#080a12")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _solid_cylinder(radius: float, height: float, at: Vector3, color: Color) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = at
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.add_child(ArenaUtil.cylinder(radius, height, color))
	add_child(body)


func _solid_box(size: Vector3, at: Vector3, color: Color) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = at
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.add_child(ArenaUtil.box(size, color))
	add_child(body)


func _build_center() -> void:
	_solid_cylinder(9.0, 1.0, Vector3(0.0, -0.5, 0.0), PLATFORM_COLOR)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 8.2
	ring_mesh.outer_radius = 8.5
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = ArenaUtil.material(UiTheme.ACCENT, true)
	ring.scale = Vector3(1.0, 0.1, 1.0)
	ring.position = Vector3(0.0, 0.02, 0.0)
	add_child(ring)
	_dynamic(SweeperArm.create(14.0, 0.5, 0.5, UiTheme.DANGER, Vector3(0.0, 0.35, 0.0), 1.1))


func _build_east() -> void:
	_dynamic(MovingPlatform.create(Vector3(5.0, 1.0, 5.0), ACCENT_COLOR, Vector3(13.5, -0.5, 0.0), Vector3(9.0, 0.0, 0.0), 7.0))
	_solid_cylinder(5.0, 1.0, Vector3(28.0, -0.5, 0.0), PLATFORM_COLOR)
	add_child(BouncePad.create(1.3, 17.0, Vector3(30.5, 0.0, 0.0), UiTheme.ACCENT))
	_dynamic(WeaponPickup.create("laser", Vector3(26.5, 0.0, 2.5)))


func _build_west() -> void:
	for x in [-12.5, -18.0, -23.5]:
		_dynamic(FallingPlatform.create(Vector3(4.0, 0.6, 4.0), Color("#3a4468"), Vector3(x, -0.3, 0.0)))
	_solid_cylinder(5.0, 1.0, Vector3(-31.0, -0.5, 0.0), PLATFORM_COLOR)
	add_child(BouncePad.create(1.3, 15.0, Vector3(-33.5, 0.0, 0.0), UiTheme.ACCENT))
	_dynamic(WeaponPickup.create("rocket_launcher", Vector3(-30.0, 0.0, 0.0)))


func _build_north() -> void:
	add_child(ConveyorBelt.create(Vector3(4.0, 0.4, 6.0), Color("#3b3f2a"), Vector3(0.0, -0.2, -12.0), Vector3(0.0, 0.0, -3.5)))
	add_child(LavaPool.create(2.8, Vector3(0.0, -0.2, -18.0)))
	_solid_cylinder(4.0, 1.0, Vector3(0.0, -0.5, -26.0), PLATFORM_COLOR)
	_dynamic(WeaponPickup.create("hammer", Vector3(0.0, 0.0, -26.0)))


func _build_south() -> void:
	_solid_box(Vector3(3.0, 1.0, 4.0), Vector3(0.0, -0.5, 10.5), PLATFORM_COLOR)
	_solid_cylinder(5.0, 1.0, Vector3(0.0, -0.5, 17.5), PLATFORM_COLOR)
	add_child(GravityZone.create(Vector3(11.0, 14.0, 11.0), Vector3(0.0, 6.5, 17.5), 0.3))
	add_child(BouncePad.create(1.3, 12.0, Vector3(0.0, 0.0, 17.5), UiTheme.ACCENT))
	_dynamic(WeaponPickup.create("bow", Vector3(3.0, 0.0, 19.5)))


func _build_barrels() -> void:
	for at in [
		Vector3(6.5, 0.6, 0.0),
		Vector3(-6.5, 0.6, 0.0),
		Vector3(3.0, 0.6, 6.5),
		Vector3(-3.0, 0.6, 6.5),
		Vector3(-3.0, 0.6, 15.0),
		Vector3(3.0, 0.6, 15.0),
	]:
		_dynamic(ExplosiveBarrel.create(at))


func _build_spawns() -> void:
	for at in [
		Vector3(5.4, 0.1, 5.4),
		Vector3(-5.4, 0.1, 5.4),
		Vector3(-5.4, 0.1, -5.4),
		Vector3(5.4, 0.1, -5.4),
		Vector3(0.0, 0.1, 7.6),
		Vector3(0.0, 0.1, -7.6),
		Vector3(7.7, 0.1, 0.0),
		Vector3(-7.7, 0.1, 0.0),
		Vector3(2.8, 0.1, 2.8),
		Vector3(-2.8, 0.1, 2.8),
		Vector3(-2.8, 0.1, -2.8),
		Vector3(2.8, 0.1, -2.8),
		Vector3(0.0, 0.1, 4.4),
		Vector3(0.0, 0.1, -4.4),
	]:
		spawn_points.append(at)