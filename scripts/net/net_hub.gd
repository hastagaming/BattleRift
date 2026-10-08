class_name NetHub
extends Node

# Server side: signals emitted when a client calls an RPC.
signal auth_received(peer_id: int, token: String)
signal weapon_received(peer_id: int, weapon_id: String)
signal input_received(peer_id: int, seq: int, move_x: float, move_y: float, yaw: float, pitch: float, held: bool)
signal action_received(peer_id: int, action: int)
signal emote_received(peer_id: int, emote_id: String)
signal leave_received(peer_id: int)

# Client side: signals emitted when the server calls an RPC.
signal auth_result(ok: bool, error: String)
signal setup_received(data: Dictionary)
signal state_received(data: Dictionary)
signal event_received(data: Dictionary)
signal snapshot_received(data: Dictionary)
signal result_received(data: Dictionary)
signal abort_received(reason: String)


@rpc("any_peer", "call_remote", "reliable")
func srv_auth(token: String) -> void:
	if multiplayer.is_server():
		auth_received.emit(multiplayer.get_remote_sender_id(), token)


@rpc("any_peer", "call_remote", "reliable")
func srv_weapon(weapon_id: String) -> void:
	if multiplayer.is_server():
		weapon_received.emit(multiplayer.get_remote_sender_id(), weapon_id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func srv_input(seq: int, move_x: float, move_y: float, yaw: float, pitch: float, held: bool) -> void:
	if multiplayer.is_server():
		input_received.emit(multiplayer.get_remote_sender_id(), seq, move_x, move_y, yaw, pitch, held)


@rpc("any_peer", "call_remote", "reliable")
func srv_action(action: int) -> void:
	if multiplayer.is_server():
		action_received.emit(multiplayer.get_remote_sender_id(), action)


@rpc("any_peer", "call_remote", "reliable")
func srv_emote(emote_id: String) -> void:
	if multiplayer.is_server():
		emote_received.emit(multiplayer.get_remote_sender_id(), emote_id)


@rpc("any_peer", "call_remote", "reliable")
func srv_leave() -> void:
	if multiplayer.is_server():
		leave_received.emit(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func cl_auth_result(ok: bool, error: String) -> void:
	auth_result.emit(ok, error)


@rpc("authority", "call_remote", "reliable")
func cl_setup(data: Dictionary) -> void:
	setup_received.emit(data)


@rpc("authority", "call_remote", "reliable")
func cl_state(data: Dictionary) -> void:
	state_received.emit(data)


@rpc("authority", "call_remote", "reliable")
func cl_event(data: Dictionary) -> void:
	event_received.emit(data)


@rpc("authority", "call_remote", "unreliable_ordered")
func cl_snapshot(data: Dictionary) -> void:
	snapshot_received.emit(data)


@rpc("authority", "call_remote", "reliable")
func cl_result(data: Dictionary) -> void:
	result_received.emit(data)


@rpc("authority", "call_remote", "reliable")
func cl_abort(reason: String) -> void:
	abort_received.emit(reason)