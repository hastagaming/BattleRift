extends Node

signal state_changed(busy: bool, message: String, is_error: bool)

const LOOPBACK_HOST := "127.0.0.1"
const LOOPBACK_PORT := 53682
const CALLBACK_PATH := "/callback"
const LOGIN_TIMEOUT := 180.0

var busy: bool = false

var _cancel_requested: bool = false


func _ready() -> void:
	PlayerData.signed_out.connect(_on_signed_out)


func _on_signed_out() -> void:
	Supabase.sign_out()


func is_backend_configured() -> bool:
	return Supabase.is_configured()


func cancel() -> void:
	_cancel_requested = true


func restore_session() -> bool:
	if not Supabase.is_configured() or not Supabase.has_saved_session():
		return false
	if not await Supabase.refresh():
		return false
	var result: Dictionary = await PlayerData.sign_in_remote("")
	return bool(result["ok"])


func sign_in_dev(display_name: String = "Rifter") -> Dictionary:
	if not OS.is_debug_build():
		return {"ok": false, "error": "Developer account is only available in debug builds"}
	if not PlayerData.sign_in("dev", "dev-local", display_name):
		return {"ok": false, "error": "Could not open developer account"}
	for weapon_id in WeaponDb.ids():
		PlayerData.grant_item("weapon", weapon_id)
		if Economy.balance(Economy.CR) < 1000:
		Economy.credit_cr(5000, "developer account")
	if Economy.balance(Economy.BR) < 100:
		Economy.apply_server_br_grant(500, "dev-%d" % Time.get_ticks_msec())
	return {"ok": true, "error": ""}


func sign_in_with(provider: String) -> Dictionary:
	if busy:
		return {"ok": false, "error": "Sign in already in progress"}
	if provider not in PlayerData.PROVIDERS:
		return {"ok": false, "error": "Unknown provider"}
	if not Supabase.is_configured():
		var message := "Supabase is not configured (supabase_url and supabase_anon_key)"
		state_changed.emit(false, message, true)
		return {"ok": false, "error": message}
	var server := TCPServer.new()
	if server.listen(LOOPBACK_PORT, LOOPBACK_HOST) != OK:
		return _fail("Port %d is busy. Close other sign in attempts and retry" % LOOPBACK_PORT)
	busy = true
	_cancel_requested = false
	var verifier := _make_verifier()
	var redirect := "http://%s:%d%s" % [LOOPBACK_HOST, LOOPBACK_PORT, CALLBACK_PATH]
	var login_url := "%s/auth/v1/authorize?provider=%s&redirect_to=%s&code_challenge=%s&code_challenge_method=s256" % [
		Supabase.base_url(),
		provider,
		redirect.uri_encode(),
		_make_challenge(verifier),
	]
	state_changed.emit(true, "Finish signing in with your browser, then return to the game...", false)
	OS.shell_open(login_url)
	var outcome: Dictionary = await _wait_for_code(server)
	server.stop()
	if String(outcome["code"]).is_empty():
		return _fail(String(outcome["error"]))
	state_changed.emit(true, "Signing in...", false)
	var exchange: Dictionary = await Supabase.exchange_pkce(String(outcome["code"]), verifier)
	if not bool(exchange["ok"]):
		return _fail(String(exchange["error"]))
	var loaded: Dictionary = await PlayerData.sign_in_remote("")
	if not bool(loaded["ok"]):
		Supabase.clear_session()
		return _fail(String(loaded["error"]))
	busy = false
	state_changed.emit(false, "", false)
	return {"ok": true, "error": ""}


func _fail(message: String) -> Dictionary:
	busy = false
	state_changed.emit(false, message, true)
	return {"ok": false, "error": message}


func _base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


func _make_verifier() -> String:
	return _base64url(Crypto.new().generate_random_bytes(48))


func _make_challenge(verifier: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(verifier.to_ascii_buffer())
	return _base64url(context.finish())


func _wait_for_code(server: TCPServer) -> Dictionary:
	var waited := 0.0
	while waited < LOGIN_TIMEOUT:
		if _cancel_requested:
			return {"done": true, "code": "", "error": "Sign in cancelled"}
		if server.is_connection_available():
			var outcome: Dictionary = await _handle_connection(server.take_connection())
			if bool(outcome["done"]):
				return outcome
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	return {"done": true, "code": "", "error": "Sign in timed out"}


func _handle_connection(peer: StreamPeerTCP) -> Dictionary:
	var request_text := ""
	var tries := 0
	while tries < 25 and not request_text.contains("\r\n"):
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		var available := peer.get_available_bytes()
		if available > 0:
			request_text += peer.get_utf8_string(available)
		else:
			await get_tree().create_timer(0.08).timeout
			tries += 1
	var parts := request_text.get_slice("\r\n", 0).split(" ")
	if parts.size() < 2 or parts[0] != "GET" or not parts[1].begins_with(CALLBACK_PATH):
		_respond(peer, 404, "Not found.")
		return {"done": false, "code": "", "error": ""}
	var target := parts[1]
	var query_string := target.get_slice("?", 1) if target.contains("?") else ""
	var query := {}
	for pair in query_string.split("&", false):
		var key := pair.get_slice("=", 0).uri_decode()
		var value := pair.get_slice("=", 1).replace("+", " ").uri_decode() if pair.contains("=") else ""
		query[key] = value
	if query.has("code"):
		_respond(peer, 200, "Login berhasil. Kembali ke game BattleRift.")
		return {"done": true, "code": String(query["code"]), "error": ""}
	if query.has("error"):
		var reason := String(query.get("error_description", query["error"]))
		_respond(peer, 200, "Login gagal. Kembali ke game dan coba lagi.")
		return {"done": true, "code": "", "error": reason}
	_respond(peer, 400, "Permintaan tidak valid.")
	return {"done": false, "code": "", "error": ""}


func _respond(peer: StreamPeerTCP, status: int, message: String) -> void:
	var reason: String = {200: "OK", 400: "Bad Request"}.get(status, "Not Found")
	var html := "<!doctype html><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>BattleRift</title><body style='font-family:sans-serif;background:#10131c;color:#e8ecf6;text-align:center;padding:48px 16px'><h2>BattleRift</h2><p>%s</p></body>" % message
	var body := html.to_utf8_buffer()
	var header := "HTTP/1.1 %d %s\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status, reason, body.size()]
	peer.put_data(header.to_utf8_buffer())
	peer.put_data(body)
	peer.poll()
	peer.disconnect_from_host()