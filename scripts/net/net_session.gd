class_name NetSession
extends RefCounted

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 7777

static var dev: bool = false


static func server_address() -> Dictionary:
	var host := String(ProjectSettings.get_setting("battlerift/game_server_host", DEFAULT_HOST)).strip_edges()
	var port := int(ProjectSettings.get_setting("battlerift/game_server_port", DEFAULT_PORT))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			var value := arg.substr(9)
			host = value.get_slice(":", 0)
			if value.contains(":"):
				port = int(value.get_slice(":", 1))
	if host.is_empty():
		host = DEFAULT_HOST
	return {"host": host, "port": port}