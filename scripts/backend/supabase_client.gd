extends Node

signal session_changed(signed_in: bool)
signal _refresh_finished(ok: bool)

const SESSION_FILE := "user://session.cfg"
const REFRESH_MARGIN := 60.0

var access_token: String = ""
var refresh_token: String = ""
var user_id: String = ""
var user_display_name: String = ""

var _expires_at: float = 0.0
var _refreshing: bool = false


func _ready() -> void:
	_load_refresh_token()


func base_url() -> String:
	return String(ProjectSettings.get_setting("battlerift/supabase_url", "")).strip_edges().rstrip("/")


func anon_key() -> String:
	return String(ProjectSettings.get_setting("battlerift/supabase_anon_key", "")).strip_edges()


func is_configured() -> bool:
	return base_url().begins_with("https://") and not anon_key().is_empty()


func has_session() -> bool:
	return not access_token.is_empty()


func has_saved_session() -> bool:
	return not refresh_token.is_empty()


func _session_key() -> String:
	return OS.get_unique_id() + "battlerift-session"


func _load_refresh_token() -> void:
	if not FileAccess.file_exists(SESSION_FILE):
		return
	var cfg := ConfigFile.new()
	if cfg.load_encrypted_pass(SESSION_FILE, _session_key()) != OK:
		return
	refresh_token = String(cfg.get_value("session", "refresh_token", ""))


func _save_refresh_token() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("session", "refresh_token", refresh_token)
	cfg.save_encrypted_pass(SESSION_FILE, _session_key())


func _apply_session(body: Variant) -> bool:
	if not body is Dictionary:
		return false
	var new_access := String(body.get("access_token", ""))
	var new_refresh := String(body.get("refresh_token", ""))
	if new_access.is_empty() or new_refresh.is_empty():
		return false
	access_token = new_access
	refresh_token = new_refresh
	_expires_at = Time.get_unix_time_from_system() + float(body.get("expires_in", 3600))
	var user: Variant = body.get("user", {})
	if user is Dictionary:
		user_id = String(user.get("id", user_id))
		var meta: Variant = user.get("user_metadata", {})
		if meta is Dictionary:
			for key in ["full_name", "name", "user_name", "preferred_username"]:
				var value := String(meta.get(key, "")).strip_edges()
				if not value.is_empty():
					user_display_name = value
					break
	_save_refresh_token()
	session_changed.emit(true)
	return true


func clear_session() -> void:
	access_token = ""
	refresh_token = ""
	user_id = ""
	user_display_name = ""
	_expires_at = 0.0
	if FileAccess.file_exists(SESSION_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_FILE))
	session_changed.emit(false)


func sign_out() -> void:
	var token := access_token
	clear_session()
	if token.is_empty() or not is_configured():
		return
	await _raw_request(HTTPClient.METHOD_POST, "/auth/v1/logout", null, token)


func exchange_pkce(auth_code: String, verifier: String) -> Dictionary:
	var result := await _raw_request(
		HTTPClient.METHOD_POST,
		"/auth/v1/token?grant_type=pkce",
		{"auth_code": auth_code, "code_verifier": verifier},
		""
	)
	if bool(result["ok"]) and not _apply_session(result["body"]):
		result["ok"] = false
		result["error"] = "Server returned an invalid session"
	return result


func refresh() -> bool:
	if refresh_token.is_empty():
		return false
	if _refreshing:
		return await _refresh_finished
	_refreshing = true
	var result := await _raw_request(
		HTTPClient.METHOD_POST,
		"/auth/v1/token?grant_type=refresh_token",
		{"refresh_token": refresh_token},
		""
	)
	var ok: bool = bool(result["ok"]) and _apply_session(result["body"])
	if not ok and int(result["status"]) in [400, 401, 403]:
		clear_session()
	_refreshing = false
	_refresh_finished.emit(ok)
	return ok


func ensure_fresh() -> bool:
	if access_token.is_empty() and refresh_token.is_empty():
		return false
	if not access_token.is_empty() and Time.get_unix_time_from_system() < _expires_at - REFRESH_MARGIN:
		return true
	return await refresh()


func request(method: int, path: String, payload: Variant = null) -> Dictionary:
	if not is_configured():
		return {"ok": false, "status": 0, "body": null, "error": "Supabase is not configured"}
	if not await ensure_fresh():
		return {"ok": false, "status": 401, "body": null, "error": "Not signed in"}
	var result := await _raw_request(method, path, payload, access_token)
	if int(result["status"]) == 401 and await refresh():
		result = await _raw_request(method, path, payload, access_token)
	return result


func rpc(function_name: String, args: Dictionary = {}) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/rest/v1/rpc/%s" % function_name, args)


func _raw_request(method: int, path: String, payload: Variant, bearer: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var headers := PackedStringArray([
		"apikey: %s" % anon_key(),
		"Content-Type: application/json",
		"Accept: application/json",
	])
	if not bearer.is_empty():
		headers.append("Authorization: Bearer %s" % bearer)
	var body := "" if payload == null else JSON.stringify(payload)
	var error := http.request(base_url() + path, headers, method, body)
	if error != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "body": null, "error": "Could not reach the server"}
	var response: Array = await http.request_completed
	http.queue_free()
	var result_code: int = response[0]
	var status: int = response[1]
	var text := (response[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var ok := result_code == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300
	var message := ""
	if not ok:
		message = "Network error" if result_code != HTTPRequest.RESULT_SUCCESS else _error_message(parsed, status)
	return {"ok": ok, "status": status, "body": parsed, "error": message}


func _error_message(parsed: Variant, status: int) -> String:
	if parsed is Dictionary:
		for key in ["message", "msg", "error_description", "error"]:
			var value := String(parsed.get(key, ""))
			if not value.is_empty():
				return value
	return "Server error (%d)" % status