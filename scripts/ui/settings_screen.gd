extends ScreenFrame

const CHECK_TIMEOUT := 20.0

var _status_label: Label
var _toggle: CheckButton
var _allow_button: Button
var _check_button: Button
var _update_label: Label
var _download_button: Button
var _update_url: String = ""
var _checking: bool = false


func _init() -> void:
	title_text = "Settings"


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


func _build() -> void:
	var scroll := make_list_scroll()
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	body.add_child(scroll)
	var panel := PanelContainer.new()
	column.add_child(panel)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 10)
	panel.add_child(card)
	card.add_child(_label("NOTIFICATIONS", 20, UiTheme.MUTED))
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
	card.add_child(_button("Send Test Notification", _on_test))
	AppNotify.permission_result.connect(_on_permission_result)
	AppNotify.update_check_result.connect(_on_update_result)
	_refresh()


func _refresh() -> void:
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
	_refresh()
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


func _on_test() -> void:
	if not AppNotify.has_permission():
		notify("Allow notifications first", true)
		return
	if AppNotify.show_test_notification():
		notify("Test notification sent")
	else:
		notify("Could not show the notification", true)