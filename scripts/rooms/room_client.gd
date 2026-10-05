class_name RoomClient
extends Node

signal room_updated(room: Dictionary)
signal failed(message: String)

const POLL_INTERVAL := 1.5
const MAPS := {"rift_arena": "Rift Arena"}

var room: Dictionary = {}

var _timer: Timer
var _polling: bool = false


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = POLL_INTERVAL
	_timer.one_shot = false
	_timer.timeout.connect(_poll)
	add_child(_timer)


func start_polling() -> void:
	if _timer.is_stopped():
		_timer.start()


func stop_polling() -> void:
	_timer.stop()


func _poll() -> void:
	if _polling:
		return
	_polling = true
	await refresh()
	_polling = false


func my_user_id() -> String:
	if not PlayerData.is_signed_in:
		return ""
	return String(PlayerData.data["account"].get("account_id", ""))


func is_host() -> bool:
	return not room.is_empty() and String(room["host_id"]) == my_user_id()


func my_member() -> Dictionary:
	for member in room.get("members", []):
		if String(member["user_id"]) == my_user_id():
			return member
	return {}


func start_check() -> Dictionary:
	if room.is_empty():
		return {"ok": false, "error": "Not in a room"}
	var players := {}
	var teams := {}
	for member in room["members"]:
		var id := String(member["user_id"])
		players[id] = {"ready": bool(member["ready"])}
		teams[id] = String(member["team"])
	return GameConfig.can_start_match(players, teams, int(room["capacity"]), String(room["host_id"]))


func refresh() -> bool:
	var result: Dictionary = await Supabase.call_rpc("get_my_room")
	if not bool(result["ok"]):
		failed.emit(String(result["error"]))
		return false
	_apply(result["body"])
	return true


func call_room(function_name: String, args: Dictionary = {}) -> bool:
	var result: Dictionary = await Supabase.call_rpc(function_name, args)
	if not bool(result["ok"]):
		failed.emit(String(result["error"]))
		return false
	_apply(result["body"])
	return true


func list_public() -> Array:
	var result: Dictionary = await Supabase.call_rpc("list_public_rooms")
	if not bool(result["ok"]):
		failed.emit(String(result["error"]))
		return []
	var body: Variant = result["body"]
	return body if body is Array else []


func _apply(body: Variant) -> void:
	room = body if body is Dictionary else {}
	room_updated.emit(room)