extends Node

signal state_changed(state: Dictionary)

var state: Dictionary = {}


func _ready() -> void:
	PlayerData.signed_in.connect(_on_signed_in)
	PlayerData.signed_out.connect(_on_signed_out)
	if PlayerData.is_signed_in and PlayerData.remote:
		refresh()


func _on_signed_in(_account: Dictionary) -> void:
	if PlayerData.remote:
		refresh()


func _on_signed_out() -> void:
	state = {}
	state_changed.emit(state)


func my_id() -> String:
	if not PlayerData.is_signed_in:
		return ""
	return String(PlayerData.data["account"].get("account_id", ""))


func clan() -> Dictionary:
	var value: Variant = state.get("clan")
	if value is Dictionary:
		return value
	return {}


func in_clan() -> bool:
	return not clan().is_empty()


func my_role() -> String:
	return String(clan().get("my_role", ""))


func can_manage() -> bool:
	return my_role() in ["leader", "officer"]


func my_requests() -> Array:
	var value: Variant = state.get("my_requests")
	if value is Array:
		return value
	return []


func tag_prefix() -> String:
	if not in_clan():
		return ""
	return "[%s] " % String(clan()["tag"])


func display_text() -> String:
	if not in_clan():
		return "No clan"
	return "[%s] %s" % [String(clan()["tag"]), String(clan()["name"])]


func signature() -> String:
	return JSON.stringify(state)


func _call(function_name: String, args: Dictionary = {}) -> Dictionary:
	if not PlayerData.is_signed_in or not PlayerData.remote:
		return {"ok": false, "error": "Clans need a server account"}
	var result: Dictionary = await Supabase.call_rpc(function_name, args)
	if bool(result["ok"]) and result["body"] is Dictionary:
		state = result["body"]
		state_changed.emit(state)
	return {"ok": bool(result["ok"]), "error": String(result["error"])}


func refresh() -> Dictionary:
	return await _call("clan_state")


func create(clan_name: String, tag: String, description: String, rules: String, requirements: Dictionary) -> Dictionary:
	return await _call("clan_create", {
		"p_name": clan_name,
		"p_tag": tag,
		"p_description": description,
		"p_rules": rules,
		"p_requirements": requirements,
	})


func join(clan_id: String) -> Dictionary:
	return await _call("clan_join", {"p_clan": clan_id})


func cancel_request(clan_id: String) -> Dictionary:
	return await _call("clan_cancel_request", {"p_clan": clan_id})


func respond(user_id: String, accept: bool) -> Dictionary:
	return await _call("clan_respond", {"p_user": user_id, "p_accept": accept})


func leave() -> Dictionary:
	return await _call("clan_leave")


func kick(user_id: String) -> Dictionary:
	return await _call("clan_kick", {"p_user": user_id})


func set_role(user_id: String, role: String) -> Dictionary:
	return await _call("clan_set_role", {"p_user": user_id, "p_role": role})


func transfer(user_id: String) -> Dictionary:
	return await _call("clan_transfer", {"p_user": user_id})


func update(description: String, rules: String, requirements: Dictionary) -> Dictionary:
	return await _call("clan_update", {
		"p_description": description,
		"p_rules": rules,
		"p_requirements": requirements,
	})


func disband() -> Dictionary:
	return await _call("clan_disband")


func search(query: String) -> Dictionary:
	var result: Dictionary = await Supabase.call_rpc("clan_search", {"p_query": query})
	var rows: Array = []
	if bool(result["ok"]) and result["body"] is Array:
		rows = result["body"]
	return {"ok": bool(result["ok"]), "error": String(result["error"]), "results": rows}


func messages(after_id: int) -> Dictionary:
	var result: Dictionary = await Supabase.call_rpc("clan_messages", {"p_after": after_id})
	var rows: Array = []
	if bool(result["ok"]) and result["body"] is Array:
		rows = result["body"]
	return {"ok": bool(result["ok"]), "error": String(result["error"]), "messages": rows}


func send_message(text: String) -> Dictionary:
	var result: Dictionary = await Supabase.call_rpc("clan_send_message", {"p_body": text})
	return {"ok": bool(result["ok"]), "error": String(result["error"])}