extends Node

signal state_changed(state: Dictionary)

const POLL_INTERVAL := 3.0

var state: Dictionary = {}

var _timer: Timer
var _polling: bool = false
var _launching: bool = false
var _suppress_until_msec: int = 0


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = POLL_INTERVAL
	_timer.one_shot = false
	_timer.timeout.connect(refresh)
	add_child(_timer)
	PlayerData.signed_in.connect(_on_signed_in)
	PlayerData.signed_out.connect(_on_signed_out)
	if PlayerData.is_signed_in and PlayerData.remote:
		_timer.start()


func _on_signed_in(_account: Dictionary) -> void:
	if PlayerData.remote:
		_timer.start()
		refresh()


func _on_signed_out() -> void:
	_timer.stop()
	state = {}
	_launching = false
	state_changed.emit(state)


func my_id() -> String:
	if not PlayerData.is_signed_in:
		return ""
	return String(PlayerData.data["account"].get("account_id", ""))


func party() -> Dictionary:
	var value: Variant = state.get("party")
	if value is Dictionary:
		return value
	return {}


func invites() -> Array:
	var value: Variant = state.get("invites")
	if value is Array:
		return value
	return []


func in_party() -> bool:
	return not party().is_empty()


func is_leader() -> bool:
	return in_party() and String(party()["leader_id"]) == my_id()


func member_count() -> int:
	if not in_party():
		return 0
	return (party()["members"] as Array).size()


func refresh() -> void:
	if _polling or not PlayerData.is_signed_in or not PlayerData.remote:
		return
	_polling = true
	var result: Dictionary = await Supabase.call_rpc("party_state")
	_polling = false
	if not PlayerData.is_signed_in:
		return
	if bool(result["ok"]) and result["body"] is Dictionary:
		_apply(result["body"])


func _apply(body: Dictionary) -> void:
	state = body
	state_changed.emit(state)
	if bool(state.get("matched", false)):
		launch_match()


func _call(function_name: String, args: Dictionary = {}) -> Dictionary:
	var result: Dictionary = await Supabase.call_rpc(function_name, args)
	if bool(result["ok"]) and result["body"] is Dictionary:
		_apply(result["body"])
	return {"ok": bool(result["ok"]), "error": String(result["error"])}


func create() -> Dictionary:
	return await _call("party_create")


func invite(user_id: String) -> Dictionary:
	return await _call("party_invite", {"p_user": user_id})


func accept(party_id: String) -> Dictionary:
	return await _call("party_accept", {"p_party": party_id})


func decline(party_id: String) -> Dictionary:
	return await _call("party_decline", {"p_party": party_id})


func leave() -> Dictionary:
	return await _call("party_leave")


func kick(user_id: String) -> Dictionary:
	return await _call("party_kick", {"p_user": user_id})


func set_ready(ready_state: bool) -> Dictionary:
	return await _call("party_set_ready", {"p_ready": ready_state})


func transfer(user_id: String) -> Dictionary:
	return await _call("party_transfer", {"p_user": user_id})


# Called when a matchmade room has started. Safe to call more than once.
func launch_match() -> void:
	if _launching or Time.get_ticks_msec() < _suppress_until_msec:
		return
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == Router.ONLINE_MATCH:
		return
	_launching = true
	NetSession.dev = false
	Router.go(Router.ONLINE_MATCH)
	await get_tree().create_timer(6.0).timeout
	_launching = false


# The online match scene calls this while leaving so a stale poll cannot pull the player back in.
func suppress_launch(seconds: float) -> void:
	_suppress_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	_launching = false