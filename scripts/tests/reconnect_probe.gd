extends SceneTree

# End-to-end reconnect probe. Run through scripts/tests/run_reconnect_probe.sh, which starts a
# real headless server and two probe clients (alice and bob) over ENet loopback.

var role: String = "alice"
var port: int = 47921
var hub: NetHub
var failures: int = 0
var auth_results: Array = []
var setups: Array = []
var states: Array = []
var events: Array = []
var results: Array = []
var snapshots: int = 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.substr(7)
		elif arg.begins_with("--port="):
			port = int(arg.substr(7))
	var game := Node.new()
	game.name = "Game"
	root.add_child(game)
	hub = NetHub.new()
	hub.name = "NetHub"
	game.add_child(hub)
	hub.auth_result.connect(func(ok: bool, error: String) -> void: auth_results.append({"ok": ok, "error": error}))
	hub.setup_received.connect(func(data: Dictionary) -> void: setups.append(data))
	hub.state_received.connect(func(data: Dictionary) -> void: states.append(data))
	hub.event_received.connect(func(data: Dictionary) -> void: events.append(data))
	hub.result_received.connect(func(data: Dictionary) -> void: results.append(data))
	hub.snapshot_received.connect(func(_data: Dictionary) -> void: snapshots += 1)
	if role == "alice":
		await _run_alice()
	else:
		await _run_bob()
	print("[%s] finished with %d failure(s)" % [role, failures])
	quit(failures)


func _check(condition: bool, message: String) -> void:
	print("%s  [%s] %s" % ["PASS" if condition else "FAIL", role, message])
	if not condition:
		failures += 1


func _wait_until(predicate: Callable, seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < seconds:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _sleep(seconds: float) -> void:
	await create_timer(seconds).timeout


func _connect_and_auth() -> bool:
	auth_results.clear()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client("127.0.0.1", port) != OK:
		return false
	get_multiplayer().multiplayer_peer = peer
	var connected := await _wait_until(func() -> bool: return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, 6.0)
	if not connected:
		return false
	hub.rpc_id(1, "srv_auth", "dev:%s" % role, NetProtocol.VERSION)
	return await _wait_until(func() -> bool: return not auth_results.is_empty(), 6.0)


func _drop() -> void:
	var peer := get_multiplayer().multiplayer_peer
	if peer != null:
		peer.close()
	get_multiplayer().multiplayer_peer = null


func _slot_of(prefix: String) -> int:
	for entry in (setups[0] as Dictionary)["participants"]:
		if String(entry["name"]).begins_with(prefix):
			return int(entry["slot"])
	return 0


func _last_state_row(slot: int) -> Dictionary:
	if states.is_empty():
		return {}
	var latest: Dictionary = states[states.size() - 1]
	return (latest["participants"] as Dictionary).get(slot, {})


func _join_and_start() -> void:
	var joined := await _connect_and_auth()
	_check(joined and bool(auth_results[0]["ok"]), "signs in to the server")
	await _wait_until(func() -> bool: return not setups.is_empty(), 20.0)
	_check(not setups.is_empty() and not bool(setups[0].get("rejoin", true)), "first setup is not marked as a rejoin")
	hub.rpc_id(1, "srv_weapon", "sword")
	var active := await _wait_until(func() -> bool:
		return not states.is_empty() and int((states[states.size() - 1] as Dictionary)["phase"]) == MatchState.Phase.ACTIVE, 25.0)
	_check(active, "the match becomes active")


func _run_alice() -> void:
	await _join_and_start()
	var my_slot := _slot_of("alice")
	await _wait_until(func() -> bool: return snapshots > 0, 5.0)
	_check(snapshots > 0, "snapshots arrive during the match")
	# First drop: reconnect inside the grace window.
	_drop()
	await _sleep(1.5)
	setups.clear()
	states.clear()
	snapshots = 0
	var back := await _connect_and_auth()
	_check(back and bool(auth_results[0]["ok"]), "reconnects with the same account inside the grace window")
	await _wait_until(func() -> bool: return not setups.is_empty() and not states.is_empty(), 5.0)
	_check(not setups.is_empty() and bool(setups[0].get("rejoin", false)) and int(setups[0]["slot"]) == my_slot, "server sends the same slot marked as a rejoin")
	var row := _last_state_row(my_slot)
	_check(not row.is_empty() and bool(row["connected"]) and not bool(row["forfeited"]), "the slot is connected and not forfeited after the rejoin")
	await _wait_until(func() -> bool: return snapshots > 0, 5.0)
	_check(snapshots > 0, "snapshots resume after the rejoin")
	await _sleep(1.0)
	# Second drop: stay away longer than the grace window.
	_drop()
	await _sleep(6.0)
	var late := await _connect_and_auth()
	_check(late and not bool(auth_results[0]["ok"]), "a late rejoin is refused")
	_check(late and String(auth_results[0]["error"]).contains("already left"), "the refusal says the player already left")


func _run_bob() -> void:
	await _join_and_start()
	var alice_slot := _slot_of("alice")
	_check(alice_slot != 0, "bob knows alice's slot")
	var saw_lost := await _wait_until(func() -> bool: return _has_link(alice_slot, false), 20.0)
	_check(saw_lost, "bob is told that alice lost her connection")
	var row := _last_state_row(alice_slot)
	var saw_back := await _wait_until(func() -> bool: return _has_link(alice_slot, true), 10.0)
	_check(saw_back, "bob is told that alice reconnected")
	_check(not row.is_empty() or saw_back, "bob keeps receiving state while alice is away")
	var forfeited := await _wait_until(func() -> bool:
		var latest := _last_state_row(alice_slot)
		return not latest.is_empty() and bool(latest["forfeited"]), 25.0)
	_check(forfeited, "alice forfeits after not returning in time")
	var got_result := await _wait_until(func() -> bool: return not results.is_empty(), 10.0)
	_check(got_result and not bool(results[0].get("draw", true)), "bob receives a decisive result")
	# Stay connected on the result screen so the match is still open when alice tries to return late.
	await _sleep(5.0)


func _has_link(slot: int, connected: bool) -> bool:
	for event in events:
		var data: Dictionary = event
		if String(data.get("type", "")) == "link" and int(data["slot"]) == slot and bool(data["connected"]) == connected:
			return true
	return false