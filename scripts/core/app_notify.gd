extends Node

signal permission_result(status: String)
signal update_check_result(status: String, latest: String, url: String)

const PLUGIN_NAME := "BattleRiftNotify"
const CONFIG_PATH := "user://device.cfg"
const CHECK_INTERVAL_MINUTES := 360

var _plugin: Object = null
var _enabled: bool = true
var _asked: bool = false


func _ready() -> void:
	_load_config()
	if OS.get_name() == "Android" and Engine.has_singleton(PLUGIN_NAME):
		_plugin = Engine.get_singleton(PLUGIN_NAME)
		_plugin.connect("permission_result", _on_permission_result)
		_plugin.connect("update_check_result", _on_update_check_result)
		apply_schedule()


func is_available() -> bool:
	return _plugin != null


func update_url() -> String:
	return String(ProjectSettings.get_setting("battlerift/update_check_url", "")).strip_edges()


func installed_version() -> String:
	if _plugin == null:
		return ""
	return String(_plugin.call("getInstalledVersion"))


func needs_permission() -> bool:
	return _plugin != null and bool(_plugin.call("needsPermission"))


func has_permission() -> bool:
	return _plugin != null and bool(_plugin.call("hasPermission"))


func is_enabled() -> bool:
	return _enabled


func set_enabled(value: bool) -> void:
	_enabled = value
	_save_config()
	apply_schedule()


func request_permission() -> void:
	if _plugin == null:
		permission_result.emit("unavailable")
		return
	_plugin.call("requestPermission")


func open_system_settings() -> void:
	if _plugin != null:
		_plugin.call("openNotificationSettings")


# Schedules the background update check, or cancels it when it should not run.
func apply_schedule() -> void:
	if _plugin == null:
		return
	var url := update_url()
	if _enabled and has_permission() and not url.is_empty():
		_plugin.call("scheduleUpdateChecks", url, CHECK_INTERVAL_MINUTES)
	else:
		_plugin.call("cancelUpdateChecks")


func check_now() -> bool:
	if _plugin == null or update_url().is_empty():
		return false
	return bool(_plugin.call("checkForUpdateNow", update_url()))


func show_test_notification() -> bool:
	if _plugin == null:
		return false
	return bool(_plugin.call("showNotification", "BattleRift", "Notifications are working."))


# Asks for the notification permission the first time the lobby opens.
func ask_once() -> void:
	if _plugin == null or _asked:
		return
	_asked = true
	_save_config()
	if needs_permission() and not has_permission():
		request_permission()


func _on_permission_result(status: String) -> void:
	if status == "granted":
		apply_schedule()
	permission_result.emit(status)


func _on_update_check_result(status: String, latest: String, url: String) -> void:
	update_check_result.emit(status, latest, url)


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	_enabled = bool(cfg.get_value("notify", "enabled", true))
	_asked = bool(cfg.get_value("notify", "asked", false))


func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("notify", "enabled", _enabled)
	cfg.set_value("notify", "asked", _asked)
	cfg.save(CONFIG_PATH)