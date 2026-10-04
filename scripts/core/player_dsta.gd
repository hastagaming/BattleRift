extends Node

signal signed_in(account: Dictionary)
signal signed_out
signal inventory_changed
signal equipment_changed(slot: String)
signal data_changed

const PROVIDERS: Array[String] = ["google", "github", "facebook"]
const SAVE_DIR := "user://accounts"
const SETTINGS_SYNC_DELAY := 1.5
const SLOT_CATEGORY := {
	"character": "character",
	"skin": "skin",
	"head": "accessory",
	"face": "accessory",
	"body": "accessory",
	"back": "accessory",
	"weapon": "weapon",
	"effect": "effect",
	"pet": "pet",
	"emote": "emote",
}
const REQUIRED_SLOTS: Array[String] = ["character", "skin"]

var data: Dictionary = {}
var is_signed_in: bool = false
var remote: bool = false

var _save_path: String = ""
var _flush_timer: Timer
var _pending_settings: Dictionary = {}
var _signing_out: bool = false


func _ready() -> void:
	_flush_timer = Timer.new()
	_flush_timer.one_shot = true
	_flush_timer.wait_time = SETTINGS_SYNC_DELAY
	_flush_timer.timeout.connect(_flush_settings)
	add_child(_flush_timer)


func _default_data(provider: String, account_id: String, display_name: String) -> Dictionary:
	return {
		"version": GameConfig.SAVE_VERSION,
		"account": {"provider": provider, "account_id": account_id},
		"profile": {"name": display_name, "level": 1, "xp": 0, "clan_id": ""},
		"currencies": {"cr": 0, "br": 0},
		"economy": {"receipts": []},
		"ratings": RankSystem.new_ratings(),
		"stats": {"matches": 0, "wins": 0, "losses": 0, "draws": 0, "eliminations": 0},
		"inventory": {
			"character": ["rifter"],
			"skin": ["default"],
			"accessory": [],
			"weapon": ["sword"],
			"effect": [],
			"pet": [],
			"emote": ["wave"],
		},
		"equipped": {
			"character": "rifter",
			"skin": "default",
			"head": "",
			"face": "",
			"body": "",
			"back": "",
			"weapon": "sword",
			"effect": "",
			"pet": "",
			"emote": "wave",
		},
		"settings": {},
	}


func _merge_defaults(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	var result: Dictionary = loaded.duplicate(true)
	for key in defaults:
		if not result.has(key):
			result[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]
		elif defaults[key] is Dictionary and result[key] is Dictionary:
			result[key] = _merge_defaults(defaults[key], result[key])
	return result


func _is_valid_provider(provider: String) -> bool:
	return provider in PROVIDERS or (provider == "dev" and OS.is_debug_build())


# Local account (debug developer account only).
func sign_in(provider: String, account_id: String, display_name: String) -> bool:
	if not _is_valid_provider(provider) or account_id.strip_edges().is_empty():
		return false
	if is_signed_in:
		sign_out()
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_save_path = "%s/%s_%s.cfg" % [SAVE_DIR, provider, account_id.md5_text()]
	var defaults := _default_data(provider, account_id, display_name.strip_edges())
	var cfg := ConfigFile.new()
	if cfg.load(_save_path) == OK:
		var loaded: Variant = cfg.get_value("player", "data", {})
		data = _merge_defaults(defaults, loaded if loaded is Dictionary else {})
	else:
		data = defaults
	remote = false
	is_signed_in = true
	save()
	signed_in.emit(data["account"])
	return true


# Server account (Supabase). The server is the source of truth.
func sign_in_remote(display_name: String) -> Dictionary:
	if not Supabase.has_session():
		return {"ok": false, "error": "No session"}
	var player_name := display_name.strip_edges()
	if player_name.is_empty():
		player_name = Supabase.user_display_name
	var result: Dictionary = await Supabase.rpc("ensure_player", {"p_name": player_name})
	if not bool(result["ok"]):
		return {"ok": false, "error": String(result["error"])}
	if not result["body"] is Dictionary:
		return {"ok": false, "error": "Server returned invalid player data"}
	if is_signed_in:
		data = {}
		is_signed_in = false
	apply_remote_snapshot(result["body"])
	remote = true
	is_signed_in = true
	signed_in.emit(data["account"])
	return {"ok": true, "error": ""}


func apply_remote_snapshot(body: Dictionary) -> void:
	var account: Dictionary = body["account"] if body.get("account") is Dictionary else {}
	var defaults := _default_data(String(account.get("provider", "unknown")), String(account.get("account_id", "")), "Rifter")
	data = _merge_defaults(defaults, body)
	if is_signed_in:
		inventory_changed.emit()
		for slot in SLOT_CATEGORY:
			equipment_changed.emit(slot)
		data_changed.emit()


func refresh_remote() -> bool:
	if not is_signed_in or not remote:
		return false
	var result: Dictionary = await Supabase.rpc("get_player")
	if not bool(result["ok"]) or not result["body"] is Dictionary:
		return false
	apply_remote_snapshot(result["body"])
	return true


func sign_out() -> void:
	if not is_signed_in or _signing_out:
		return
	_signing_out = true
	if remote:
		await _flush_settings()
	else:
		save()
	data = {}
	is_signed_in = false
	remote = false
	_save_path = ""
	_signing_out = false
	signed_out.emit()


func save() -> bool:
	if not is_signed_in:
		return false
	if remote:
		return true
	var cfg := ConfigFile.new()
	cfg.set_value("player", "data", data)
	return cfg.save(_save_path) == OK


func _sync(function_name: String, args: Dictionary) -> void:
	var result: Dictionary = await Supabase.rpc(function_name, args)
	if bool(result["ok"]):
		return
	push_warning("Server rejected %s: %s" % [function_name, result["error"]])
	await refresh_remote()


func _flush_settings() -> void:
	_flush_timer.stop()
	var pending := _pending_settings
	_pending_settings = {}
	for key in pending:
		var result: Dictionary = await Supabase.rpc("set_setting", {"p_key": key, "p_value": pending[key]})
		if not bool(result["ok"]):
			push_warning("Could not sync setting %s: %s" % [key, result["error"]])


func get_setting(key: String, default_value: Variant = null) -> Variant:
	if not is_signed_in:
		return default_value
	return data["settings"].get(key, default_value)


func set_setting(key: String, value: Variant) -> void:
	if not is_signed_in:
		return
	data["settings"][key] = value
	if remote:
		_pending_settings[key] = value
		_flush_timer.start()
	else:
		save()
	data_changed.emit()


func owns(category: String, item_id: String) -> bool:
	if not is_signed_in or not data["inventory"].has(category):
		return false
	return item_id in data["inventory"][category]


func grant_item(category: String, item_id: String) -> bool:
	if not is_signed_in or remote or item_id.is_empty() or not data["inventory"].has(category):
		return false
	if owns(category, item_id):
		return false
	data["inventory"][category].append(item_id)
	save()
	inventory_changed.emit()
	return true


func equip(slot: String, item_id: String) -> bool:
	if not is_signed_in or not SLOT_CATEGORY.has(slot):
		return false
	if not owns(SLOT_CATEGORY[slot], item_id):
		return false
	data["equipped"][slot] = item_id
	if remote:
		_sync("equip_item", {"p_slot": slot, "p_item": item_id})
	else:
		save()
	equipment_changed.emit(slot)
	return true


func unequip(slot: String) -> bool:
	if not is_signed_in or not SLOT_CATEGORY.has(slot) or slot in REQUIRED_SLOTS:
		return false
	data["equipped"][slot] = ""
	if remote:
		_sync("unequip_slot", {"p_slot": slot})
	else:
		save()
	equipment_changed.emit(slot)
	return true


func xp_for_next_level(level: int) -> int:
	return 100 + level * 50


func add_xp(amount: int) -> void:
	if not is_signed_in or remote or amount <= 0:
		return
	var profile: Dictionary = data["profile"]
	profile["xp"] = int(profile["xp"]) + amount
	while int(profile["xp"]) >= xp_for_next_level(int(profile["level"])):
		profile["xp"] = int(profile["xp"]) - xp_for_next_level(int(profile["level"]))
		profile["level"] = int(profile["level"]) + 1
	save()
	data_changed.emit()


func record_match(outcome: String, eliminations: int) -> bool:
	if not is_signed_in or remote or outcome not in ["win", "loss", "draw"]:
		return false
	var stats: Dictionary = data["stats"]
	stats["matches"] = int(stats["matches"]) + 1
	stats["eliminations"] = int(stats["eliminations"]) + maxi(eliminations, 0)
	match outcome:
		"win":
			stats["wins"] = int(stats["wins"]) + 1
		"loss":
			stats["losses"] = int(stats["losses"]) + 1
		"draw":
			stats["draws"] = int(stats["draws"]) + 1
	save()
	data_changed.emit()
	return true