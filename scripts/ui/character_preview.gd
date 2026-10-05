class_name CharacterPreview
extends SubViewportContainer

var model: CharacterModel
var spin_speed: float = 0.6

var _viewport: SubViewport
var _pivot: Node3D
var _dragging: bool = false


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(260.0, 320.0)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9aa7d6")
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	_viewport.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 32.0
	_viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.15, 4.2), Vector3(0.0, 0.95, 0.0))
	_pivot = Node3D.new()
	_pivot.rotation.y = PI
	_viewport.add_child(_pivot)
	model = CharacterModel.new()
	_pivot.add_child(model)
	refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotate_y(event.relative.x * 0.012)
		accept_event()


func _process(delta: float) -> void:
	if _pivot == null:
		return
	if not _dragging:
		_pivot.rotate_y(spin_speed * delta)
	model.animate(0.0, true, delta)


func refresh() -> void:
	model.apply_equipped()
	var weapon_id := ""
	if PlayerData.is_signed_in:
		weapon_id = String(PlayerData.data["equipped"].get("weapon", ""))
	model.set_weapon(weapon_id if WeaponDb.has(weapon_id) else "")


func play_emote() -> void:
	if not PlayerData.is_signed_in:
		return
	var emote_id := String(PlayerData.data["equipped"].get("emote", ""))
	if not emote_id.is_empty():
		model.play_emote(emote_id)