class_name Spectator
extends Node

signal target_changed(peer_id: int)
signal active_changed(active: bool)

var state: MatchState
var local_peer: int = 0
var camera_rig: CameraRig
var bodies: Dictionary = {}
var active: bool = false
var target_peer: int = -1

var _anchor: Node3D
var _home_target: Node3D


func _ready() -> void:
	_anchor = Node3D.new()
	add_child(_anchor)
	state.participant_changed.connect(_on_participant_changed)


func _process(_delta: float) -> void:
	if not active:
		return
	if Input.is_action_just_pressed("spectate_next"):
		cycle(1)
	elif Input.is_action_just_pressed("spectate_prev"):
		cycle(-1)


func target_name() -> String:
	if target_peer < 0:
		return ""
	return String(state.participant(target_peer).get("name", ""))


func start() -> void:
	if active:
		return
	_home_target = camera_rig.target
	active = true
	active_changed.emit(true)
	_pick(SpectatorLogic.next(_candidates(), -1, 1))


func stop() -> void:
	if not active:
		return
	active = false
	target_peer = -1
	if is_instance_valid(_home_target):
		camera_rig.target = _home_target
	active_changed.emit(false)


func cycle(direction: int) -> void:
	if not active:
		return
	_pick(SpectatorLogic.next(_candidates(), target_peer, direction))


func _available_peers() -> Array:
	var peers: Array = []
	for peer_id in bodies:
		if is_instance_valid(bodies[peer_id]):
			peers.append(int(peer_id))
	return peers


func _candidates() -> Array[int]:
	return SpectatorLogic.candidates(state.participants, local_peer, _available_peers())


func _pick(peer_id: int) -> void:
	var body: Variant = bodies.get(peer_id)
	if peer_id >= 0 and is_instance_valid(body) and body is Node3D:
		target_peer = peer_id
		camera_rig.target = body as Node3D
	else:
		target_peer = -1
		_anchor.global_position = Vector3(0.0, 1.0, 0.0)
		camera_rig.target = _anchor
	target_changed.emit(target_peer)


func _on_participant_changed(_peer_id: int) -> void:
	if not active:
		return
	var list := _candidates()
	if target_peer in list:
		return
	if list.is_empty() and target_peer == -1:
		return
	_pick(SpectatorLogic.next(list, target_peer, 1))