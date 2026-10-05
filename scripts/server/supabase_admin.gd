class_name SupabaseAdmin
extends Node

var base_url: String = ""
var anon_key: String = ""
var service_key: String = ""


func has_service_key() -> bool:
	return not service_key.is_empty()


# Runs an RPC as the player who owns the token. Identity comes from the JWT, never from the client.
func user_rpc(token: String, function_name: String, args: Dictionary = {}) -> Dictionary:
	var headers := PackedStringArray([
		"apikey: %s" % anon_key,
		"Authorization: Bearer %s" % token,
		"Content-Type: application/json",
		"Accept: application/json",
	])
	return await _send("/rest/v1/rpc/%s" % function_name, args, headers)


# Runs an RPC with the service key. Only used for functions that clients cannot call.
func service_rpc(function_name: String, args: Dictionary = {}) -> Dictionary:
	if not has_service_key():
		return {"ok": false, "status": 0, "body": null, "error": "Service key is not configured"}
	var headers := PackedStringArray([
		"apikey: %s" % service_key,
		"Content-Type: application/json",
		"Accept: application/json",
	])
	if not service_key.begins_with("sb_secret_"):
		headers.append("Authorization: Bearer %s" % service_key)
	return await _send("/rest/v1/rpc/%s" % function_name, args, headers)


func _send(path: String, payload: Dictionary, headers: PackedStringArray) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var error := http.request(base_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "body": null, "error": "Could not reach Supabase"}
	var response: Array = await http.request_completed
	http.queue_free()
	var result_code: int = response[0]
	var status: int = response[1]
	var text := (response[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var ok := result_code == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300
	var message := ""
	if not ok:
		message = "Network error"
		if result_code == HTTPRequest.RESULT_SUCCESS:
			message = "Server error (%d)" % status
			if parsed is Dictionary and not String(parsed.get("message", "")).is_empty():
				message = String(parsed["message"])
	return {"ok": ok, "status": status, "body": parsed, "error": message}