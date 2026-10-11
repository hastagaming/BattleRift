class_name NetProbe
extends RefCounted


# Opens a real ENet connection to the server, then drops it. It does not sign in.
static func probe(tree: SceneTree, host: String, port: int, timeout_msec: int = 4000) -> Dictionary:
	var connection := ENetConnection.new()
	var created := connection.create_host(1)
	if created != OK:
		return {"ok": false, "error": "Could not open a network socket (error %d)." % created, "ms": 0}
	var peer := connection.connect_to_host(host, port)
	if peer == null:
		connection.destroy()
		return {"ok": false, "error": "Could not start the connection. Check the address.", "ms": 0}
	var started := Time.get_ticks_msec()
	var outcome := {
		"ok": false,
		"error": "No answer from %s:%d. Check the IP address, that the server is running, that the laptop firewall allows UDP port %d, and that both devices use the same Wi-Fi." % [host, port, port],
		"ms": 0,
	}
	while Time.get_ticks_msec() - started < timeout_msec:
		var event: Array = connection.service(0)
		var kind: int = event[0]
		if kind == ENetConnection.EVENT_CONNECT:
			outcome = {"ok": true, "error": "", "ms": Time.get_ticks_msec() - started}
			break
		if kind == ENetConnection.EVENT_DISCONNECT:
			outcome = {"ok": false, "error": "The server refused the connection.", "ms": 0}
			break
		await tree.process_frame
	peer.peer_disconnect_now()
	connection.flush()
	connection.destroy()
	return outcome