extends ScreenFrame

const CHECK_TIMEOUT := 20.0

var _address_text: String = ""
var _address_input: LineEdit
var _server_label: Label
var _network_result: Label
var _test_button: Button
var _find_button: Button
var _found_box: VBoxContainer
var _probing: bool = false
var _finding: bool = false

var _status_label: Label
var _toggle: CheckButton
var _allow_button: Button
var _check_button: Button
var _update_label: Label
var _download_button: Button
var _update_url: String = ""
var _checking: bool = false


func _init() -> void:
	title_text = Loc.t("settings.title")


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 52.0)
	button.pressed.connect(callback)
	return button


func _card(column: VBoxContainer, heading: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	column.add_child(panel)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 10)
	panel.add_child(card)
	card.add_child(_label(heading, 20, UiTheme.MUTED))
	return card


func _build() -> void:
	var scroll := make_list_scroll()
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	body.add_child(scroll)
	_build_language_card(column)
	_build_network_card(column)
	_build_notification_card(column)
	_build_tutorial_card(column)


# ---- Language ----

func _build_language_card(column: VBoxContainer) -> void:
	var card := _card(column, Loc.t("settings.language_card"))
	card.add_child(_label(String(Loc.language_info(Loc.current())["name"]), 24, UiTheme.TEXT))
	card.add_child(_label(Loc.t("settings.language_hint"), 17, UiTheme.MUTED))
	card.add_child(_button(Loc.t("settings.change_language"), _open_language_picker))


func _open_language_picker() -> void:
	Router.language_return = Router.SETTINGS
	Router.go(Router.LANGUAGE)


# ---- Match server ----

func _build_network_card(column: VBoxContainer) -> void:
	var card := _card(column, "MATCH SERVER")
	_server_label = _label("", 22, UiTheme.TEXT)
	card.add_child(_server_label)
	card.add_child(_label("The phones and the laptop must use the same Wi-Fi. Enter the laptop's Wi-Fi IPv4 address, as printed when the server starts.", 17, UiTheme.MUTED))
	var current := NetConfig.current()
	_address_text = "%s:%d" % [String(current["host"]), int(current["port"])]
	_address_input = LineEdit.new()
	_address_input.placeholder_text = "192.168.1.20 or 192.168.1.20:7777"
	_address_input.text = _address_text
	_address_input.custom_minimum_size = Vector2(0.0, 52.0)
	_address_input.text_changed.connect(_on_address_changed)
	card.add_child(_address_input)
	card.add_child(_button("Save Address", _on_save_address))
	_test_button = _button("Test Connection", _on_test)
	card.add_child(_test_button)
	_find_button = _button("Find Server on Wi-Fi", _on_find)
	card.add_child(_find_button)
	_found_box = VBoxContainer.new()
	_found_box.add_theme_constant_override("separation", 8)
	card.add_child(_found_box)
	_network_result = _label("", 18, UiTheme.MUTED)
	card.add_child(_network_result)
	card.add_child(_button("Reset to Default", _on_reset_address))
	_refresh_server_label()


func _refresh_server_label() -> void:
	var current := NetConfig.current()
	var host := String(current["host"])
	_server_label.text = "Server: %s:%d" % [host, int(current["port"])]
	var hint := NetAddress.loopback_hint(host, OS.get_name() == "Android")
	if not hint.is_empty():
		_show_network_result(hint, true)


func _show_network_result(message: String, is_error: bool) -> void:
	_network_result.text = message
	_network_result.add_theme_color_override("font_color", UiTheme.DANGER if is_error else UiTheme.MUTED)


func _on_address_changed(text: String) -> void:
	_address_text = text


func _parsed_address() -> Dictionary:
	var parsed := NetAddress.parse(_address_text)
	if not bool(parsed["ok"]):
		_show_network_result(String(parsed["error"]), true)
	return parsed


func _on_save_address() -> void:
	var parsed := _parsed_address()
	if not bool(parsed["ok"]):
		return
	if NetConfig.save(String(parsed["host"]), int(parsed["port"])):
		_refresh_server_label()
		notify("Server address saved")
	else:
		notify("Could not save the address", true)


func _on_reset_address() -> void:
	NetConfig.clear()
	var current := NetConfig.current()
	_address_text = "%s:%d" % [String(current["host"]), int(current["port"])]
	_address_input.text = _address_text
	_refresh_server_label()
	notify("Server address reset")


func _on_test() -> void:
	if _probing or _finding:
		return
	var parsed := _parsed_address()
	if not bool(parsed["ok"]):
		return
	var host := String(parsed["host"])
	var port := int(parsed["port"])
	_probing = true
	_test_button.disabled = true
	_test_button.text = "Testing..."
	_show_network_result("Contacting %s:%d ..." % [host, port], false)
	var result: Dictionary = await NetProbe.probe(get_tree(), host, port)
	_probing = false
	if not is_inside_tree():
		return
	_test_button.disabled = false
	_test_button.text = "Test Connection"
	if bool(result["ok"]):
		_show_network_result("The server answered at %s:%d (%d ms)." % [host, port, int(result["ms"])], false)
		notify("Server reachable")
		return
	var message := String(result["error"])
	var hint := NetAddress.loopback_hint(host, OS.get_name() == "Android")
	if not hint.is_empty():
		message += " " + hint
	_show_network_result(message, true)


func _on_find() -> void:
	if _probing or _finding:
		return
	_finding = true
	_find_button.disabled = true
	_find_button.text = "Searching..."
	clear_children(_found_box)
	_show_network_result("Looking for servers on this Wi-Fi...", false)
	var servers: Array = await LanDiscovery.discover(get_tree())
	_finding = false
	if not is_inside_tree():
		return
	_find_button.disabled = false
	_find_button.text = "Find Server on Wi-Fi"
	if servers.is_empty():
		_show_network_result("No server answered. Check that the server is running on the laptop and that its firewall allows UDP %d and UDP %d. You can also enter the IP address by hand." % [NetAddress.DEFAULT_PORT, NetProtocol.DISCOVERY_PORT], true)
		return
	_show_network_result("Found %d server(s). Tap one to use it." % servers.size(), false)
	for entry in servers:
		var info: Dictionary = entry
		var text := "%s:%d  (%s)" % [String(info["host"]), int(info["port"]), String(info["name"])]
		var usable := bool(info["compatible"])
		if not usable:
			text += "  - different version"
		var button := _button(text, _on_use_server.bind(String(info["host"]), int(info["port"])))
		button.disabled = not usable
		_found_box.add_child(button)


func _on_use_server(host: String, port: int) -> void:
	if NetConfig.save(host, port):
		_address_text = "%s:%d" % [host, port]
		_address_input.text = _address_text
		_refresh_server_label()
		_show_network_result("Using %s:%d" % [host, port], false)
		notify("Server address saved")


# ---- Notifications ----

func _build_notification_card(column: VBoxContainer) -> void:
	var card := _card(column, "NOTIFICATIONS")
	if not AppNotify.is_available():
		card.add_child(empty_note("Notifications are only available in the Android app."))
		return
	card.add_child(_label("Installed version: %s" % AppNotify.installed_version(), 22, UiTheme.TEXT))
	_status_label = _label("", 22, UiTheme.TEXT)
	card.add_child(_status_label)
	_toggle = CheckButton.new()
	_toggle.text = "Notify me about game updates"
	_toggle.toggled.connect(_on_toggle)
	card.add_child(_toggle)
	_allow_button = _button("Allow Notifications", AppNotify.request_permission)
	card.add_child(_allow_button)
	card.add_child(_button("Open System Settings", AppNotify.open_system_settings))
	_check_button = _button("Check for Updates", _on_check)
	card.add_child(_check_button)
	_update_label = _label("", 22, UiTheme.GOLD)
	_update_label.visible = false
	card.add_child(_update_label)
	_download_button = _button("Download Update", _on_download)
	_download_button.visible = false
	card.add_child(_download_button)
	card.add_child(_button("Send Test Notification", _on_test_notification))
	AppNotify.permission_result.connect(_on_permission_result)
	AppNotify.update_check_result.connect(_on_update_result)
	_refresh_notifications()


func _refresh_notifications() -> void:
	var granted := AppNotify.has_permission()
	_status_label.text = "Notifications are allowed" if granted else "Notifications are not allowed"
	_status_label.add_theme_color_override("font_color", UiTheme.TEXT if granted else UiTheme.DANGER)
	_allow_button.visible = not granted
	_toggle.set_pressed_no_signal(AppNotify.is_enabled())


func _on_toggle(pressed: bool) -> void:
	AppNotify.set_enabled(pressed)
	if pressed and not AppNotify.has_permission():
		notify("Allow notifications to receive update alerts", true)
	else:
		notify("Update notifications on" if pressed else "Update notifications off")


func _on_permission_result(status: String) -> void:
	_refresh_notifications()
	match status:
		"granted":
			notify("Notifications allowed")
		"denied":
			notify("Notifications were not allowed", true)
		"blocked":
			notify("Notifications are blocked. Open system settings to allow them.", true)
		_:
			notify("Notifications are not available on this device", true)


func _on_check() -> void:
	if _checking:
		return
	if not AppNotify.check_now():
		notify("Update check is not configured", true)
		return
	_checking = true
	_check_button.disabled = true
	_check_button.text = "Checking..."
	get_tree().create_timer(CHECK_TIMEOUT).timeout.connect(_on_check_timeout)


func _finish_check() -> void:
	_checking = false
	_check_button.disabled = false
	_check_button.text = "Check for Updates"


func _on_check_timeout() -> void:
	if not _checking:
		return
	_finish_check()
	notify("The update check timed out", true)


func _on_update_result(status: String, latest: String, url: String) -> void:
	if not _checking:
		return
	_finish_check()
	match status:
		"newer":
			_update_url = url
			_update_label.text = "Update available: %s" % latest
			_update_label.visible = true
			_download_button.visible = url.begins_with("https://")
			notify("Update available: %s" % latest)
		"current":
			_update_label.text = "You are up to date (%s)" % latest
			_update_label.visible = true
			_download_button.visible = false
			notify("You are up to date")
		_:
			notify("Could not check for updates", true)


func _on_download() -> void:
	if _update_url.begins_with("https://"):
		OS.shell_open(_update_url)


func _on_test_notification() -> void:
	if not AppNotify.has_permission():
		notify("Allow notifications first", true)
		return
	if AppNotify.show_test_notification():
		notify("Test notification sent")
	else:
		notify("Could not show the notification", true)


# ---- Tutorial ----

func _build_tutorial_card(column: VBoxContainer) -> void:
	var card := _card(column, "TUTORIAL")
	card.add_child(_label("Replay the interactive tutorial: the controls in the practice arena, then a tour of rooms, friends, pets, clans and currencies.", 17, UiTheme.MUTED))
	card.add_child(_button("Replay tutorial", _on_replay_tutorial_pressed))


func _on_replay_tutorial_pressed() -> void:
	TutorialStore.restart()
	Router.go(Router.TUTORIAL)