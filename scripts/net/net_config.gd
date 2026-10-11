class_name NetConfig
extends RefCounted

const CONFIG_PATH := "user://device.cfg"
const SECTION := "network"


static func project_default() -> Dictionary:
	var host := String(ProjectSettings.get_setting("battlerift/game_server_host", "127.0.0.1")).strip_edges()
	var port := int(ProjectSettings.get_setting("battlerift/game_server_port", NetAddress.DEFAULT_PORT))
	if host.is_empty():
		host = "127.0.0.1"
	if not NetAddress.is_valid_port(port):
		port = NetAddress.DEFAULT_PORT
	return {"host": host, "port": port}


static func saved() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return {}
	var host := String(cfg.get_value(SECTION, "host", "")).strip_edges()
	var port := int(cfg.get_value(SECTION, "port", NetAddress.DEFAULT_PORT))
	if host.is_empty() or not NetAddress.is_valid_port(port):
		return {}
	return {"host": host, "port": port}


static func save(host: String, port: int) -> bool:
	var cleaned := host.strip_edges()
	if cleaned.is_empty() or not NetAddress.is_valid_port(port):
		return false
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value(SECTION, "host", cleaned)
	cfg.set_value(SECTION, "port", port)
	return cfg.save(CONFIG_PATH) == OK


static func clear() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	if cfg.has_section(SECTION):
		cfg.erase_section(SECTION)
	cfg.save(CONFIG_PATH)


# Order of precedence: --server=host:port on the command line, the address saved on
# this device (Settings), then the project setting.
static func current() -> Dictionary:
	var result := project_default()
	var stored := saved()
	if not stored.is_empty():
		result = stored
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			var parsed := NetAddress.parse(arg.substr(9))
			if bool(parsed["ok"]):
				result = {"host": parsed["host"], "port": parsed["port"]}
	return result