class_name LanBeacon
extends Node

var game_port: int = 7777
var server_name: String = "BattleRift Server"

var _socket := PacketPeerUDP.new()
var _active: bool = false


func start() -> bool:
	var error := _socket.bind(NetProtocol.DISCOVERY_PORT, "0.0.0.0")
	if error != OK:
		push_warning("LAN discovery is off: could not listen on UDP port %d (error %d)." % [NetProtocol.DISCOVERY_PORT, error])
		return false
	_active = true
	return true


func _process(_delta: float) -> void:
	if not _active:
		return
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		var sender_ip := _socket.get_packet_ip()
		var sender_port := _socket.get_packet_port()
		if packet.get_string_from_utf8() != NetProtocol.DISCOVERY_QUERY:
			continue
		_socket.set_dest_address(sender_ip, sender_port)
		var reply := "%s|%d|%d|%s" % [NetProtocol.DISCOVERY_PREFIX, NetProtocol.VERSION, game_port, server_name]
		_socket.put_packet(reply.to_utf8_buffer())