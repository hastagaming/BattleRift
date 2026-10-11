class_name NetSession
extends RefCounted

static var dev: bool = false


static func server_address() -> Dictionary:
	return NetConfig.current()