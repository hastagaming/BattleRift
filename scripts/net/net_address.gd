class_name NetAddress
extends RefCounted

const DEFAULT_PORT := 7777
const MAX_HOST_LENGTH := 253


static func is_valid_port(port: int) -> bool:
	return port >= 1 and port <= 65535


static func is_ipv4(text: String) -> bool:
	var parts := text.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if part.is_empty() or part.length() > 3 or not part.is_valid_int():
			return false
		var value := part.to_int()
		if value < 0 or value > 255:
			return false
	return true


static func is_loopback(host: String) -> bool:
	var lowered := host.strip_edges().to_lower()
	if lowered == "localhost" or lowered == "::1" or lowered == "0.0.0.0":
		return true
	return lowered.begins_with("127.") and is_ipv4(lowered)


static func is_link_local(host: String) -> bool:
	return host.begins_with("169.254.") and is_ipv4(host)


static func looks_numeric(text: String) -> bool:
	if text.is_empty():
		return false
	for i in text.length():
		var code := text.unicode_at(i)
		if not ((code >= 48 and code <= 57) or code == 46):
			return false
	return true


static func is_valid_hostname(text: String) -> bool:
	if text.is_empty() or text.length() > MAX_HOST_LENGTH:
		return false
	for i in text.length():
		var code := text.unicode_at(i)
		var allowed := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 45 or code == 46
		if not allowed:
			return false
	return not text.begins_with(".") and not text.ends_with(".") and not text.begins_with("-")


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "host": "", "port": DEFAULT_PORT, "error": message}


# Accepts "192.168.1.20", "192.168.1.20:7777" or a host name.
static func parse(text: String) -> Dictionary:
	var cleaned := text.strip_edges()
	if cleaned.is_empty():
		return _fail("Enter the server address, for example 192.168.1.20")
	var host := cleaned
	var port := DEFAULT_PORT
	if cleaned.contains(":"):
		if cleaned.count(":") > 1:
			return _fail("IPv6 addresses are not supported. Use the laptop's IPv4 address.")
		host = cleaned.get_slice(":", 0).strip_edges()
		var port_text := cleaned.get_slice(":", 1).strip_edges()
		if not port_text.is_valid_int():
			return _fail("The port must be a number between 1 and 65535")
		port = port_text.to_int()
	if host.is_empty():
		return _fail("The address is missing")
	if not is_valid_port(port):
		return _fail("The port must be a number between 1 and 65535")
	if looks_numeric(host):
		if not is_ipv4(host):
			return _fail("%s is not a valid IPv4 address" % host)
	elif not is_valid_hostname(host):
		return _fail("%s is not a valid address" % host)
	return {"ok": true, "host": host, "port": port, "error": ""}


static func loopback_hint(host: String, is_android: bool) -> String:
	if is_android and is_loopback(host):
		return "%s is this phone itself. If the server runs on your laptop, open Settings > Match server and enter the laptop's Wi-Fi IPv4 address (for example 192.168.1.20)." % host
	return ""


static func unreachable_message(host: String, port: int, is_android: bool) -> String:
	var message := "Could not reach %s:%d. Check that the server is running, that the phone and the laptop use the same Wi-Fi, that the IP address is correct, and that the laptop firewall allows UDP port %d." % [host, port, port]
	var hint := loopback_hint(host, is_android)
	if not hint.is_empty():
		message += " " + hint
	return message


# The IPv4 addresses of this machine on real networks (used by the server banner and discovery).
static func lan_ipv4_addresses() -> Array[String]:
	var found: Array[String] = []
	for address in IP.get_local_addresses():
		var text := String(address)
		if is_ipv4(text) and not is_loopback(text) and not is_link_local(text) and text not in found:
			found.append(text)
	return found