class_name LanDiscovery
extends RefCounted

const RESEND_MSEC := 600


static func broadcast_targets() -> Array[String]:
	var targets: Array[String] = ["255.255.255.255"]
	for address in NetAddress.lan_ipv4_addresses():
		var parts := address.split(".")
		var target := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if target not in targets:
			targets.append(target)
	return targets


static func parse_reply(text: String, ip: String) -> Dictionary:
	var parts := text.split("|")
	if parts.size() < 4 or parts[0] != NetProtocol.DISCOVERY_PREFIX:
		return {}
	if not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return {}
	var port := parts[2].to_int()
	if not NetAddress.is_valid_port(port) or not NetAddress.is_ipv4(ip):
		return {}
	return {
		"host": ip,
		"port": port,
		"name": parts[3].left(40),
		"compatible": parts[1].to_int() == NetProtocol.VERSION,
	}


static func _open_socket() -> PacketPeerUDP:
	var first := PacketPeerUDP.new()
	if first.bind(0, "0.0.0.0") == OK:
		return first
	for candidate in range(47000, 47020):
		var retry := PacketPeerUDP.new()
		if retry.bind(candidate, "0.0.0.0") == OK:
			return retry
	return null


static func discover(tree: SceneTree, timeout_msec: int = 2500, extra_targets: Array[String] = []) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var socket := _open_socket()
	if socket == null:
		return found
	socket.set_broadcast_enabled(true)
	var targets := broadcast_targets()
	targets.append_array(extra_targets)
	var seen := {}
	var started := Time.get_ticks_msec()
	var next_send := 0
	while Time.get_ticks_msec() - started < timeout_msec:
		var elapsed := Time.get_ticks_msec() - started
		if elapsed >= next_send:
			next_send = elapsed + RESEND_MSEC
			for target in targets:
				socket.set_dest_address(target, NetProtocol.DISCOVERY_PORT)
				socket.put_packet(NetProtocol.DISCOVERY_QUERY.to_utf8_buffer())
		while socket.get_available_packet_count() > 0:
			var text := socket.get_packet().get_string_from_utf8()
			var sender := socket.get_packet_ip()
			var entry := parse_reply(text, sender)
			if entry.is_empty():
				continue
			var key := "%s:%d" % [sender, int(entry["port"])]
			if not seen.has(key):
				seen[key] = true
				found.append(entry)
		await tree.process_frame
	socket.close()
	return found