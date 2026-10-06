extends Node3D

const ARENA_RADIUS := 14.0
const HUD_ELEMENTS := ["move_joystick", "aim_control", "attack", "weapon_switch", "jump", "dash", "emote"]

var _player: PlayerController
var _camera_rig: CameraRig
var _top_bar: PanelContainer
var _name_label: Label
var _rank_label: Label
var _cr_label: Label
var _br_label: Label
var _menu_bar: PanelContainer


func _ready() -> void:
	UiTheme.ensure(get_tree())
	if not PlayerData.is_signed_in:
		Router.go(Router.AUTH)
		return
	_build_environment()
	_build_floor()
	_build_pillars()
	_build_emblem()
	_build_pad(Vector3(-6.0, 0.0, 0.0), UiTheme.ACCENT, "launch")
	_build_pad(Vector3(6.0, 0.0, 0.0), UiTheme.DANGER, "shock")
	_spawn_player()
	_build_ui()
	PlayerData.data_changed.connect(_refresh_ui)
	PlayerData.signed_out.connect(_on_signed_out)
	Economy.balance_changed.connect(_on_balance_changed)
	get_viewport().size_changed.connect(_layout_ui)
	_refresh_ui()
	_layout_ui()
	AppNotify.ask_once()


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#1a2342")
	sky_material.sky_horizon_color = Color("#4b5f9e")
	sky_material.ground_horizon_color = Color("#4b5f9e")
	sky_material.ground_bottom_color = Color("#0b0e17")
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
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)


func _static_body(shape: Shape3D, mesh: Mesh, color: Color, body_position: Vector3, emissive: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Ragdoll.LAYER_WORLD
	body.collision_mask = 0
	body.position = body_position
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.5
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
	return body


func _build_floor() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = ARENA_RADIUS
	shape.height = 1.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = ARENA_RADIUS
	mesh.bottom_radius = ARENA_RADIUS
	mesh.height = 1.0
	mesh.radial_segments = 48
	_static_body(shape, mesh, Color("#20283d"), Vector3(0.0, -0.5, 0.0))


func _build_pillars() -> void:
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 4.0, 1.0)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.0, 4.0, 1.0)
		var color := UiTheme.ACCENT if i % 2 == 0 else Color("#2c3552")
		_static_body(shape, mesh, color, Vector3(cos(angle) * 12.0, 2.0, sin(angle) * 12.0), i % 2 == 0)


func _build_emblem() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 3.2
	mesh.outer_radius = 3.6
	var material := StandardMaterial3D.new()
	material.albedo_color = UiTheme.ACCENT
	material.emission_enabled = true
	material.emission = UiTheme.ACCENT
	material.emission_energy_multiplier = 1.5
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.scale = Vector3(1.0, 0.15, 1.0)
	visual.position = Vector3(0.0, 0.02, 0.0)
	add_child(visual)


func _build_pad(pad_position: Vector3, color: Color, kind: String) -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = Ragdoll.LAYER_PLAYER
	area.position = pad_position + Vector3(0.0, 0.3, 0.0)
	var shape := CylinderShape3D.new()
	shape.radius = 1.4
	shape.height = 0.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	area.add_child(collider)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.4
	mesh.bottom_radius = 1.4
	mesh.height = 0.08
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.8
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = Vector3(0.0, -0.26, 0.0)
	area.add_child(visual)
	add_child(area)
	area.body_entered.connect(_on_pad_entered.bind(area, kind))


func _on_pad_entered(body: Node3D, pad: Area3D, kind: String) -> void:
	var player := body as PlayerController
	if player == null:
		return
	if kind == "launch":
		player.launch(Vector3(0.0, 12.0, 0.0))
		return
	var away := player.global_position - pad.global_position
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3.BACK
	player.apply_knockback(away.normalized() * 11.0 + Vector3(0.0, 7.0, 0.0))


func _spawn_player() -> void:
	_player = PlayerController.new()
	_player.spawn_point = Vector3(0.0, 0.1, 6.5)
	_player.position = _player.spawn_point
	add_child(_player)
	_player.weapons.set_available(WeaponDb.ids())
	  var training_range := LobbyRange.new()
	  add_child(training_range)
	_camera_rig = CameraRig.new()
	_camera_rig.target = _player
	add_child(_camera_rig)
	_camera_rig.global_position = _player.position + Vector3(0.0, _camera_rig.height, 0.0)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var hud := TouchHud.new()
	hud.elements = HUD_ELEMENTS
	layer.add_child(hud)
	_top_bar = PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_top_bar.add_child(row)
	_name_label = Label.new()
	row.add_child(_name_label)
	_rank_label = Label.new()
	_rank_label.add_theme_color_override("font_color", UiTheme.MUTED)
	row.add_child(_rank_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_cr_label = Label.new()
	_cr_label.add_theme_color_override("font_color", UiTheme.GOLD)
	row.add_child(_cr_label)
	_br_label = Label.new()
	_br_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	row.add_child(_br_label)
	var arena_button := Button.new()
	arena_button.text = "Practice Arena"
	arena_button.pressed.connect(_on_practice_pressed)
	row.add_child(arena_button)
	var room_button := Button.new()
	room_button.text = "Custom Room"
	room_button.pressed.connect(_on_room_pressed)
	row.add_child(room_button)
	if OS.is_debug_build():
		var dev_match_button := Button.new()
		dev_match_button.text = "Dev Match"
		dev_match_button.pressed.connect(_on_dev_match_pressed)
		row.add_child(dev_match_button)
	var sign_out_button := Button.new()
	sign_out_button.text = "Sign Out"
	sign_out_button.pressed.connect(PlayerData.sign_out)
	row.add_child(sign_out_button)
	layer.add_child(_top_bar)
		_menu_bar = PanelContainer.new()
	var menu_row := HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 10)
	_menu_bar.add_child(menu_row)
        for entry in [["Play", Router.PLAY], ["Missions", Router.MISSIONS], ["Shop", Router.SHOP], ["Inventory", Router.INVENTORY], ["Customize", Router.CUSTOMIZE], ["Profile", Router.PROFILE], ["Settings", Router.SETTINGS]]:
		var menu_button := Button.new()
		menu_button.text = String(entry[0])
		menu_button.custom_minimum_size = Vector2(120.0, 52.0)
		menu_button.pressed.connect(Router.go.bind(String(entry[1])))
		menu_row.add_child(menu_button)
	layer.add_child(_menu_bar)
	var combat_hud := CombatHud.new()
	  combat_hud.player = _player
	  combat_hud.touch_hud = hud
	  layer.add_child(combat_hud)


func _layout_ui() -> void:
	if _top_bar == null:
		return
	var area := ControlLayout.get_safe_area_rect(get_viewport())
	_top_bar.position = area.position + Vector2(12.0, 8.0)
	_top_bar.size = Vector2(area.size.x - 24.0, 0.0)
	if _menu_bar != null:
		var menu_size := _menu_bar.get_combined_minimum_size()
		_menu_bar.size = menu_size
		_menu_bar.position = Vector2(area.position.x + (area.size.x - menu_size.x) * 0.5, area.end.y - menu_size.y - 12.0)


func _best_rank_text() -> String:
	var ratings: Dictionary = PlayerData.data["ratings"]
	var best_context := "1v1"
	var best_mmr := -1
	for context in RankSystem.CONTEXTS:
		var mmr := int(ratings.get(context, RankSystem.DEFAULT_MMR))
		if mmr > best_mmr:
			best_mmr = mmr
			best_context = context
	var context_label := "BR" if best_context == "battle_royal" else best_context
	return "%s %s" % [context_label, RankSystem.tier_name_for_mmr(best_mmr)]


func _refresh_ui() -> void:
	if not PlayerData.is_signed_in or _name_label == null:
		return
	var profile: Dictionary = PlayerData.data["profile"]
	_name_label.text = "%s  Lv %d" % [String(profile["name"]), int(profile["level"])]
	_rank_label.text = _best_rank_text()
	_cr_label.text = "CR %d" % Economy.balance(Economy.CR)
	_br_label.text = "BR %d" % Economy.balance(Economy.BR)


func _on_balance_changed(_currency: String, _balance: int) -> void:
	_refresh_ui()


func _on_signed_out() -> void:
	Router.go(Router.AUTH)


func _on_practice_pressed() -> void:
	MatchSession.config = MatchSession.practice()
	Router.go(Router.MATCH)


func _on_room_pressed() -> void:
	Router.go(Router.ROOM)


func _on_dev_match_pressed() -> void:
	NetSession.dev = true
	Router.go(Router.ONLINE_MATCH)