extends Node

const DEFAULT_PORT := 7777
const MAX_PEERS := 48
const AUTH_TIMEOUT := 10.0
const MAX_TOKEN_LENGTH := 4096

var hub: NetHub
var admin: SupabaseAdmin
var port: int = DEFAULT_PORT
var max_matches: int = 4
var dev_accounts: bool = false
var dev_capacity: int = 2
var dev_mode: String = "stock"

var _peers: Dictionary = {}
var _matches: Dictionary = {}
var _clock: float = 0.0


func _ready() -> void:
	Engine.max_fps = 60
	_read_options()
	admin = SupabaseAdmin.new()
	admin.base_url = _setting("BATTLERIFT_SUPABASE_URL", "supabase_url").rstrip("/")
	admin.anon_key = _setting("BATTLERIFT_SUPABASE_ANON_KEY", "supabase_anon_key")
	admin.service_key = OS.get_environment("SUPABASE_SERVICE_KEY").strip_edges()
	add_child(admin)
	if admin.base_url.is_empty() or admin.anon_key.is_empty():
		push_warning("Supabase is not configured. Only --dev-accounts connections can work.")
	if not admin.has_service_key():
		push_warning("SUPABASE_SERVICE_KEY is not set. Match results will not be saved.")
	if dev_accounts:
		push_warning("DEV ACCOUNTS ENABLED. Never run a public server with --dev-accounts.")
	hub = NetHub.new()
	hub.name = "NetHub"
	add_child(hub)
	hub.auth_received.connect(_on_auth)
	hub.weapon_received.connect(_on_weapon)
	hub.input_received.connect(_on_input)
	hub.action_received.connect(_on_action)
	hub.leave_received.connect(_on_leave)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PEERS)
	if error != OK:
		push_error("Could not listen on UDP port %d (error %d)" % [port, error])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	(multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	NetBus.blast_hook = _route_blast
	NetBus.beam_hook = _route_beam
	print("BattleRift server listening on UDP %d (max matches: %d)" % [port, max_matches])


func _setting(env_name: String, project_key: String) -> String:
	var from_env := OS.get_environment(env_name).strip_edges()
	if not from_env.is_empty():
		return from_env
	return String(ProjectSettings.get_setting("battlerift/%s" % project_key, "")).strip_edges()


func _read_options() -> void:
	var options := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		options[body.get_slice("=", 0)] = body.get_slice("=", 1) if body.contains("=") else "true"
	var env_port := OS.get_environment("BATTLERIFT_PORT")
	port = int(options.get("port", env_port if not env_port.is_empty() else str(DEFAULT_PORT)))
	max_matches = clampi(int(options.get("max-matches", "4")), 1, 32)
	dev_accounts = options.has("dev-accounts")
	var capacity := int(options.get("dev-capacity", "2"))
	dev_capacity = capacity if GameConfig.is_valid_custom_room_size(capacity) else 2
	var mode := String(options.get("dev-mode", "stock"))
	dev_mode = mode if mode in ["stock", "unlimited"] else "stock"


func _process(delta: float) -> void:
	_clock += delta
	for peer_id in _peers.keys():
		var info: Dictionary = _peers[peer_id]
		if String(info["state"]) == "connected" and _clock - float(info["since"]) > AUTH_TIMEOUT:
			_disconnect_peer(peer_id)


func _disconnect_peer(peer_id: int) -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer != null:
		peer.disconnect_peer(peer_id)


func _on_peer_connected(peer_id: int) -> void:
	_peers[peer_id] = {"state": "connected", "since": _clock, "match": null}


func _on_peer_disconnected(peer_id: int) -> void:
	var instance := _match_of(peer_id)
	if instance != null:
		instance.remove_peer(peer_id)
	_peers.erase(peer_id)


func _match_of(peer_id: int) -> ServerMatch:
	var info: Dictionary = _peers.get(peer_id, {})
	var value: Variant = info.get("match")
	if value != null and is_instance_valid(value):
		return value as ServerMatch
	return null


func _reject(peer_id: int, message: String) -> void:
	if not _peers.has(peer_id):
		return
	hub.rpc_id(peer_id, "cl_auth_result", false, message)
	await get_tree().create_timer(0.3).timeout
	if _peers.has(peer_id):
		_disconnect_peer(peer_id)


func _on_auth(peer_id: int, token: String) -> void:
	var info: Dictionary = _peers.get(peer_id, {})
	if info.is_empty() or String(info["state"]) != "connected":
		return
	if token.is_empty() or token.length() > MAX_TOKEN_LENGTH:
		_reject(peer_id, "Invalid token")
		return
	info["state"] = "authenticating"
	var identity := await _identify(token)
	if not _peers.has(peer_id):
		return
	if not bool(identity["ok"]):
		_reject(peer_id, String(identity["error"]))
		return
	var match_key := String(identity["key"])
	var instance: ServerMatch = _matches.get(match_key)
	if instance == null:
		if _matches.size() >= max_matches:
			_reject(peer_id, "The server is full. Try again soon.")
			return
		instance = _create_match(match_key, identity)
	var joined := instance.add_peer(peer_id, identity)
	if not bool(joined["ok"]):
		_reject(peer_id, String(joined["error"]))
		return
	info["state"] = "ready"
	info["match"] = instance


func _identify(token: String) -> Dictionary:
	if token.begins_with("dev:"):
		if not dev_accounts:
			return {"ok": false, "error": "Developer accounts are disabled on this server"}
		var display_name := token.substr(4).strip_edges().left(24)
		if display_name.is_empty():
			return {"ok": false, "error": "Invalid developer account"}
		return {
			"ok": true,
			"error": "",
			"key": "dev",
			"user_id": "dev-%s" % display_name,
			"name": display_name,
			"skin": "default",
			"character": "rifter",
			"emote": "wave",
			"accessories": {},
			"ratings": RankSystem.new_ratings(),
			"owned": WeaponDb.ids(),
			"equipped_weapon": "sword",
			"room": {"id": "dev", "capacity": dev_capacity, "mode": dev_mode, "stocks": 3, "time_limit": 180},
			"persist": false,
			"open_roster": true,
		}
	if admin.base_url.is_empty():
		return {"ok": false, "error": "The server is not configured"}
	var player: Dictionary = await admin.user_rpc(token, "get_player")
	if not bool(player["ok"]) or not player["body"] is Dictionary:
		return {"ok": false, "error": "Invalid session. Sign in again."}
	var room_result: Dictionary = await admin.user_rpc(token, "get_my_room")
	if not bool(room_result["ok"]) or not room_result["body"] is Dictionary:
		return {"ok": false, "error": "You are not in a room"}
	var data: Dictionary = player["body"]
	var room: Dictionary = room_result["body"]
	if String(room.get("status", "")) != "started":
		return {"ok": false, "error": "The room has not started yet"}
	var equipped: Dictionary = data["equipped"]
	var inventory: Dictionary = data["inventory"]
	return {
		"ok": true,
		"error": "",
		"key": String(room["id"]),
		"user_id": String(data["account"]["account_id"]),
		"name": String(data["profile"]["name"]),
		"skin": String(equipped.get("skin", "default")),
		"character": String(equipped.get("character", "rifter")),
		"emote": String(equipped.get("emote", "")),
		"accessories": {
			"head": String(equipped.get("head", "")),
			"face": String(equipped.get("face", "")),
			"body": String(equipped.get("body", "")),
			"back": String(equipped.get("back", "")),
		},
		"ratings": data["ratings"],
		"owned": inventory.get("weapon", []),
		"equipped_weapon": String(equipped.get("weapon", "")),
		"room": room,
		"persist": true,
		"open_roster": false,
	}


func _create_match(match_key: String, identity: Dictionary) -> ServerMatch:
	var instance := ServerMatch.new()
	instance.hub = hub
	instance.admin = admin
	instance.key = match_key
	instance.room = identity["room"]
	instance.persist = bool(identity["persist"]) and admin.has_service_key()
	instance.open_roster = bool(identity["open_roster"])
	instance.finished.connect(_on_match_finished.bind(match_key))
	add_child(instance)
	_matches[match_key] = instance
	print("Match %s created (%d players)" % [match_key, int(identity["room"].get("capacity", 2))])
	return instance


func _on_match_finished(match_key: String) -> void:
	var instance: ServerMatch = _matches.get(match_key)
	if instance == null:
		return
	_matches.erase(match_key)
	for peer_id in instance.connected_peers():
		var info: Dictionary = _peers.get(peer_id, {})
		if not info.is_empty():
			info["match"] = null
		_disconnect_peer(peer_id)
	instance.queue_free()
	print("Match %s closed" % match_key)


func _on_weapon(peer_id: int, weapon_id: String) -> void:
	var instance := _match_of(peer_id)
	if instance != null:
		instance.on_weapon(peer_id, weapon_id)


func _on_input(peer_id: int, seq: int, move_x: float, move_y: float, yaw: float, pitch: float, held: bool) -> void:
	var instance := _match_of(peer_id)
	if instance != null:
		instance.on_input(peer_id, seq, move_x, move_y, yaw, pitch, held)


func _on_action(peer_id: int, action: int) -> void:
	var instance := _match_of(peer_id)
	if instance != null:
		instance.on_action(peer_id, action)


func _on_leave(peer_id: int) -> void:
	var instance := _match_of(peer_id)
	if instance != null:
		instance.remove_peer(peer_id)


func _match_from_node(node: Node) -> ServerMatch:
	var viewport := node.get_viewport()
	if viewport == null or not viewport.has_meta("server_match"):
		return null
	return viewport.get_meta("server_match") as ServerMatch


func _route_blast(context: Node, center: Vector3, radius: float, color: Color) -> void:
	var instance := _match_from_node(context)
	if instance != null:
		instance.broadcast_event({"type": "blast", "pos": center, "radius": radius, "color": color})


func _route_beam(context: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var instance := _match_from_node(context)
	if instance != null:
		instance.broadcast_event({"type": "beam", "from": from, "to": to, "color": color})