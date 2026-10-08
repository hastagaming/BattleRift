extends Node3D

const HUD_ELEMENTS := ["move_joystick", "aim_control", "attack", "weapon_switch", "jump", "dash", "emote", "pet_ability", "ability"]

var state: MatchState
var arena: Arena
var player: PlayerController
var camera_rig: CameraRig
var touch_hud: TouchHud
var match_hud: MatchHud
var spectator: Spectator
var local_peer: int = 0

var _layer: CanvasLayer
var _players: Dictionary = {}
var _next_spawn: int = 0
var _weapon_confirmed: bool = false
var _touch_visible: bool = true


func _ready() -> void:
	UiTheme.ensure(get_tree())
	if not PlayerData.is_signed_in:
		Router.go(Router.AUTH)
		return
	var config: Dictionary = MatchSession.config
	if config.is_empty():
		config = MatchSession.practice()
	state = MatchState.new()
	add_child(state)
	var configured := state.configure(config)
	if not bool(configured["ok"]):
		push_error(String(configured["error"]))
		Router.go(Router.LOBBY)
		return
	arena = Arena.new()
	add_child(arena)
	var roster: Array = config.get("participants", [])
	for entry in roster:
		var info: Dictionary = entry
		var peer_id := int(info["peer_id"])
		state.add_participant(peer_id, String(info["name"]), String(info["team"]))
		if bool(info.get("local", false)):
			local_peer = peer_id
	if local_peer == 0:
		push_error("Match has no local participant")
		Router.go(Router.LOBBY)
		return
	_spawn_local_player()
	_build_ui()
	state.phase_changed.connect(_on_phase_changed)
	state.countdown_changed.connect(_on_countdown_changed)
	state.respawn_requested.connect(_respawn_player)
	state.match_ended.connect(_on_match_ended)
	state.roster_changed.connect(_try_begin)
	state.participant_changed.connect(_on_participant_changed)
	var select := WeaponSelect.new()
	select.confirmed.connect(_on_weapon_confirmed)
	_layer.add_child(select)
	touch_hud.visible = false


func _take_spawn() -> Vector3:
	var point: Vector3 = arena.spawn_points[_next_spawn % arena.spawn_points.size()]
	_next_spawn += 1
	return point


func _spawn_local_player() -> void:
	player = PlayerController.new()
	player.auto_respawn = false
	player.spawn_point = _take_spawn()
	player.position = player.spawn_point
	add_child(player)
	player.controllable = false
	player.fell_out.connect(_on_player_fell_out)
	_players[local_peer] = player
	camera_rig = CameraRig.new()
	camera_rig.target = player
	add_child(camera_rig)
	camera_rig.global_position = player.position + Vector3(0.0, camera_rig.height, 0.0)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	touch_hud = TouchHud.new()
	touch_hud.elements = HUD_ELEMENTS
	_layer.add_child(touch_hud)
	_touch_visible = touch_hud.visible
	match_hud = MatchHud.new()
	match_hud.state = state
	match_hud.local_peer = local_peer
	match_hud.leave_requested.connect(_on_leave_requested)
	_layer.add_child(match_hud)
	var combat_hud := CombatHud.new()
	combat_hud.player = player
	combat_hud.touch_hud = touch_hud
	combat_hud.emote_picked.connect(_on_emote_picked)
	_layer.add_child(combat_hud)
	spectator = Spectator.new()
	spectator.state = state
	spectator.local_peer = local_peer
	spectator.camera_rig = camera_rig
	spectator.bodies = _players
	add_child(spectator)
	var spectator_hud := SpectatorHud.new()
	spectator_hud.spectator = spectator
	_layer.add_child(spectator_hud)


func _on_emote_picked(emote_id: String) -> void:
	player.model.play_emote(emote_id)


func _on_weapon_confirmed(weapon_id: String) -> void:
	PlayerData.equip("weapon", weapon_id)
	var ids: Array[String] = [weapon_id]
	player.weapons.set_available(ids)
	touch_hud.visible = _touch_visible
	_weapon_confirmed = true
	_try_begin()


func _try_begin() -> void:
	if not _weapon_confirmed or state.phase != MatchState.Phase.WAITING:
		return
	var check := state.can_begin()
	if bool(check["ok"]):
		match_hud.hide_banner()
		state.begin()
	else:
		match_hud.show_banner(String(check["error"]).to_upper(), 0.0)


func _on_countdown_changed(seconds_left: int) -> void:
	if seconds_left > 0:
		match_hud.show_banner(str(seconds_left), 0.9)


func _on_phase_changed(phase: int) -> void:
	if phase == MatchState.Phase.ACTIVE:
		player.controllable = true
		match_hud.show_banner("GO!", 0.9)
	elif phase == MatchState.Phase.ENDED:
		player.controllable = false


func _on_player_fell_out(attacker: Node) -> void:
	if state.phase != MatchState.Phase.ACTIVE:
		_respawn_player(local_peer)
		return
	var attacker_peer := -1
	if attacker != null:
		for peer_id in _players:
			if _players[peer_id] == attacker:
				attacker_peer = int(peer_id)
	if not state.report_knockout(local_peer, attacker_peer):
		_respawn_player(local_peer)


func _respawn_player(peer_id: int) -> void:
	var target: PlayerController = _players.get(peer_id)
	if target == null:
		return
	target.spawn_point = _take_spawn()
	target.respawn()
	target.controllable = state.phase == MatchState.Phase.ACTIVE


func _on_leave_requested() -> void:
	match state.phase:
		MatchState.Phase.WAITING:
			Router.go(Router.LOBBY)
		MatchState.Phase.COUNTDOWN, MatchState.Phase.ACTIVE:
			state.forfeit(local_peer)
			if state.phase != MatchState.Phase.ENDED:
				Router.go(Router.LOBBY)


func _on_participant_changed(peer_id: int) -> void:
	if peer_id != local_peer:
		return
	if String(state.participant(local_peer).get("state", "")) == MatchState.STATE_OUT:
		spectator.start()
	else:
		spectator.stop()


func _on_match_ended(final_result: Dictionary) -> void:
	spectator.stop()
	touch_hud.visible = false
	await get_tree().create_timer(1.2).timeout
	var screen := ResultScreen.new()
	screen.result = final_result
	screen.local_peer = local_peer
	_layer.add_child(screen)