extends Node3D

const HUD_ELEMENTS := ["move_joystick", "aim_control", "attack", "weapon_switch", "jump", "dash", "emote"]
const ACTION_MAP := [["jump", 1], ["dash", 2], ["attack", 4], ["weapon_switch", 8], ["emote", 16]]
const CONNECT_TIMEOUT := 12.0
const INPUT_EVERY := 2

var hub: NetHub
var mirror: MatchState
var arena: Arena
var camera_rig: CameraRig
var touch_hud: TouchHud
var match_hud: MatchHud
var combat_hud: CombatHud
var spectator: Spectator
var my_slot: int = 0

var _layer: CanvasLayer
var _status_root: Control
var _backdrop: ColorRect
var _status_label: Label
var _leave_button: Button
var _buffer := SnapshotBuffer.new()
var _proxies: Dictionary = {}
var _projectiles: Dictionary = {}
var _token: String = ""
var _connected: bool = false
var _setup_done: bool = false
var _ended: bool = false
var _leaving: bool = false
var _editing: bool = false
var _touch_visible: bool = true
var _seq: int = 0
var _frame: int = 0
var _last_weapon_index: int = -2
var _last_damage: int = -1


func _ready() -> void:
	UiTheme.ensure(get_tree())
	if not PlayerData.is_signed_in:
		Router.go(Router.AUTH)
		return
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	_build_status()
	hub = NetHub.new()
	hub.name = "NetHub"
	add_child(hub)
	hub.auth_result.connect(_on_auth_result)
	hub.setup_received.connect(_on_setup)
	hub.state_received.connect(_on_state)
	hub.event_received.connect(_on_event)
	hub.snapshot_received.connect(_on_snapshot)
	hub.result_received.connect(_on_result)
	hub.abort_received.connect(_on_abort)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_connect()


func _build_status() -> void:
	_status_root = Control.new()
	_status_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_status_root)
	_backdrop = ColorRect.new()
	_backdrop.color = UiTheme.BG
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status_root.add_child(_backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(420.0, 0.0)
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status_label)
	_leave_button = Button.new()
	_leave_button.text = "Cancel"
	_leave_button.custom_minimum_size = Vector2(0.0, 52.0)
	_leave_button.pressed.connect(_exit_to_lobby)
	column.add_child(_leave_button)


func _set_status(message: String, is_error: bool) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", UiTheme.DANGER if is_error else UiTheme.TEXT)
	_status_root.visible = true
	_status_root.move_to_front()


func _fail(message: String) -> void:
	_leave_button.text = "Back to Lobby"
	_set_status(message, true)


func _session_token() -> String:
	if NetSession.dev:
		var base_name := String(PlayerData.data["profile"]["name"]).left(16)
		return "dev:%s-%04d" % [base_name, randi() % 10000]
	if not await Supabase.ensure_fresh():
		return ""
	return Supabase.access_token


func _connect() -> void:
	_set_status("Connecting to the match server...", false)
	_token = await _session_token()
	if _token.is_empty():
		_fail("Could not read your session. Sign in again.")
		return
	var address := NetSession.server_address()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(String(address["host"]), int(address["port"]))
	if error != OK:
		_fail("Could not start the connection (error %d)." % error)
		return
	multiplayer.multiplayer_peer = peer
	await get_tree().create_timer(CONNECT_TIMEOUT).timeout
	if not _connected and not _leaving:
		_fail("Could not reach the match server.")


func _on_connected() -> void:
	_connected = true
	_set_status("Signing in to the match...", false)
	hub.rpc_id(1, "srv_auth", _token)
	_token = ""


func _on_connection_failed() -> void:
	_fail("Could not reach the match server.")


func _on_server_disconnected() -> void:
	if _ended or _leaving:
		return
	_fail("Connection to the match server was lost.")


func _on_auth_result(ok: bool, error: String) -> void:
	if not ok:
		_fail(error)
		return
	_set_status("Waiting for the other players...", false)


func _on_abort(reason: String) -> void:
	_ended = true
	_fail(reason)


func _on_setup(data: Dictionary) -> void:
	if _setup_done:
		return
	_setup_done = true
	my_slot = int(data["slot"])
	mirror = MatchState.new()
	add_child(mirror)
	mirror.set_process(false)
	mirror.mode = String(data["mode"])
	mirror.stocks_per_player = int(data["stocks"])
	mirror.time_limit = float(data["time_limit"])
	arena = Arena.new()
	arena.simulate = false
	add_child(arena)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.global_position = Vector3(0.0, camera_rig.height, 8.0)
	for entry in data["participants"]:
		var info: Dictionary = entry
		var slot := int(info["slot"])
		var team := String(info["team"])
		mirror.participants[slot] = {
			"name": String(info["name"]),
			"team": team,
			"state": MatchState.STATE_ALIVE,
			"stocks": mirror.stocks_per_player if mirror.mode == MatchState.MODE_STOCK else 0,
			"kills": 0,
			"deaths": 0,
			"respawn_in": 0.0,
			"forfeited": false,
		}
		if not mirror.scores.has(team):
			mirror.scores[team] = 0
		var proxy := RemotePlayer.new()
		add_child(proxy)
				proxy.setup(slot, String(info["name"]), team, String(info["skin"]), String(info["character"]), info.get("accessories", {}))
		proxy.visible = false
		_proxies[slot] = proxy
	camera_rig.target = _proxies[my_slot]
	_build_ui()
	_status_root.visible = false
	var select := WeaponSelect.new()
	select.confirmed.connect(_on_weapon_confirmed)
	_layer.add_child(select)
	touch_hud.visible = false


func _build_ui() -> void:
	touch_hud = TouchHud.new()
	touch_hud.elements = HUD_ELEMENTS
	_layer.add_child(touch_hud)
	_touch_visible = touch_hud.visible
	match_hud = MatchHud.new()
	match_hud.state = mirror
	match_hud.local_peer = my_slot
	match_hud.leave_requested.connect(_exit_to_lobby)
	_layer.add_child(match_hud)
	combat_hud = CombatHud.new()
	combat_hud.touch_hud = touch_hud
	combat_hud.editor_toggled.connect(func(open: bool) -> void: _editing = open)
	_layer.add_child(combat_hud)
	spectator = Spectator.new()
	spectator.state = mirror
	spectator.local_peer = my_slot
	spectator.camera_rig = camera_rig
	spectator.bodies = _proxies
	add_child(spectator)
	var spectator_hud := SpectatorHud.new()
	spectator_hud.spectator = spectator
	_layer.add_child(spectator_hud)
	mirror.participant_changed.connect(_on_participant_changed)
	mirror.phase_changed.connect(_on_phase_changed)
	_status_root.move_to_front()


func _on_weapon_confirmed(weapon_id: String) -> void:
	PlayerData.equip("weapon", weapon_id)
	hub.rpc_id(1, "srv_weapon", weapon_id)
	touch_hud.visible = _touch_visible
	match_hud.show_banner("WAITING FOR PLAYERS", 0.0)


func _on_phase_changed(phase: int) -> void:
	if phase == MatchState.Phase.ACTIVE:
		match_hud.show_banner("GO!", 0.9)


func _on_participant_changed(peer_id: int) -> void:
	if peer_id != my_slot:
		return
	if String(mirror.participant(my_slot).get("state", "")) == MatchState.STATE_OUT:
		spectator.start()
	else:
		spectator.stop()


func _on_state(data: Dictionary) -> void:
	if mirror != null:
		mirror.apply_remote_state(data)


func _on_event(data: Dictionary) -> void:
	if not _setup_done:
		return
	match String(data.get("type", "")):
		"countdown":
			var seconds_left := int(data["n"])
			if seconds_left > 0:
				match_hud.show_banner(str(seconds_left), 0.9)
		"attack":
			var attacker: RemotePlayer = _proxies.get(int(data["slot"]))
			if attacker != null:
				attacker.play_attack(float(data["duration"]))
		"emote":
			var actor: RemotePlayer = _proxies.get(int(data["slot"]))
			if actor != null:
				actor.play_emote(String(data["id"]))
		"knockout":
			mirror.player_knocked_out.emit(int(data["victim"]), int(data["killer"]))
		"blast":
			NetEffects.blast(self, data["pos"], float(data["radius"]), data["color"])
		"beam":
			NetEffects.beam(self, data["from"], data["to"], data["color"])
		"weapon_rejected":
			match_hud.show_banner("WEAPON NOT AVAILABLE. USING YOUR DEFAULT.", 2.5)


func _on_snapshot(data: Dictionary) -> void:
	if not _setup_done:
		return
	_buffer.push(data, Time.get_ticks_msec() / 1000.0)
	mirror.set_clock(float(data["c"]))


func _on_result(data: Dictionary) -> void:
	if not _setup_done:
		return
	_ended = true
	spectator.stop()
	touch_hud.visible = false
	await get_tree().create_timer(1.2).timeout
	if _leaving:
		return
	var screen := ResultScreen.new()
	screen.result = data
	screen.local_peer = my_slot
	screen.on_back = _exit_to_lobby
	_layer.add_child(screen)
	_status_root.move_to_front()


func _exit_to_lobby() -> void:
	if _leaving:
		return
	_leaving = true
	_leave_button.disabled = true
	_set_status("Leaving...", false)
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null
	if PlayerData.remote:
		await Supabase.call_rpc("leave_room")
		await PlayerData.refresh_remote()
	Router.go(Router.LOBBY)


func _process(delta: float) -> void:
	if not _setup_done:
		return
	for slot in mirror.participants:
		var entry: Dictionary = mirror.participants[slot]
		if String(entry["state"]) == MatchState.STATE_RESPAWNING:
			entry["respawn_in"] = maxf(float(entry["respawn_in"]) - delta, 0.0)
	var sample := _buffer.sample(Time.get_ticks_msec() / 1000.0)
	if sample.is_empty():
		return
	_apply_players(sample["p"], delta)
	_apply_dynamics(sample["d"])
	_apply_projectiles(sample["j"])


func _apply_players(data: PackedFloat32Array, delta: float) -> void:
	for i in SnapshotCodec.record_count(data, SnapshotCodec.PLAYER_STRIDE):
		var record := SnapshotCodec.read_player(data, i)
		var slot := int(record["slot"])
		var proxy: RemotePlayer = _proxies.get(slot)
		if proxy == null:
			continue
		proxy.apply_state(record, delta)
		if slot == my_slot:
			_update_local_hud(record)


func _update_local_hud(record: Dictionary) -> void:
	var weapon_index := int(record["weapon"])
	if weapon_index != _last_weapon_index:
		_last_weapon_index = weapon_index
		var weapon_id := ""
		if weapon_index >= 0 and weapon_index < WeaponDb.ORDER.size():
			weapon_id = WeaponDb.ORDER[weapon_index]
		combat_hud.show_weapon(weapon_id)
	var damage := roundi(float(record["damage"]))
	if damage != _last_damage:
		_last_damage = damage
		combat_hud.set_damage(float(damage))


func _apply_dynamics(data: PackedFloat32Array) -> void:
	var count := mini(SnapshotCodec.record_count(data, SnapshotCodec.DYNAMIC_STRIDE), arena.dynamics.size())
	for i in count:
		var record := SnapshotCodec.read_dynamic(data, i)
		var node := arena.dynamics[i]
		node.global_transform = record["xform"]
		if node.has_method("net_apply"):
			node.call("net_apply", float(record["flag"]), float(record["extra"]))


func _apply_projectiles(data: PackedFloat32Array) -> void:
	var seen := {}
	for i in SnapshotCodec.record_count(data, SnapshotCodec.PROJECTILE_STRIDE):
		var record := SnapshotCodec.read_projectile(data, i)
		var id := int(record["id"])
		seen[id] = true
		var node: Node3D = _projectiles.get(id)
		if node == null:
			var kind := clampi(int(record["kind"]), 0, WeaponDb.ORDER.size() - 1)
			node = ProjectileVisual.build(WeaponDb.ORDER[kind])
			add_child(node)
			_projectiles[id] = node
		var position: Vector3 = record["pos"]
		var velocity: Vector3 = record["vel"]
		node.global_position = position
		if velocity.length() > 0.5:
			var direction := velocity.normalized()
			var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
			node.look_at(position + direction, up)
	for id in _projectiles.keys():
		if not seen.has(id):
			(_projectiles[id] as Node3D).queue_free()
			_projectiles.erase(id)


func _physics_process(_delta: float) -> void:
	if not _setup_done or _leaving or camera_rig == null:
		return
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var alive := String(mirror.participant(my_slot).get("state", "")) == MatchState.STATE_ALIVE
	var active := mirror.phase == MatchState.Phase.ACTIVE and alive and not _editing
	if active:
		for entry in ACTION_MAP:
			if Input.is_action_just_pressed(String(entry[0])):
				hub.rpc_id(1, "srv_action", int(entry[1]))
	_frame += 1
	if _frame % INPUT_EVERY != 0:
		return
	var move := Vector2.ZERO
	var held := false
	if active:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		held = Input.is_action_pressed("attack")
	hub.rpc_id(1, "srv_input", _seq, move.x, move.y, camera_rig.yaw, camera_rig.pitch, held)
	_seq += 1