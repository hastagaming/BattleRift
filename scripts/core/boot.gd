extends Control

var _status: Label
var _bar: ProgressBar


func _ready() -> void:
	UiTheme.ensure(get_tree())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiTheme.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.svg")
	logo.custom_minimum_size = Vector2(112, 112)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(logo)
	var title := Label.new()
	title.text = "BATTLERIFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(title)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(340, 12)
	column.add_child(_bar)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", UiTheme.MUTED)
	column.add_child(_status)
	_run()


func _scenes_exist() -> bool:
	for path in [Router.AUTH, Router.LOBBY]:
		if not ResourceLoader.exists(path):
			return false
	return true


func _run() -> void:
	var checks: Array[Dictionary] = [
		{"label": "Validating game rules", "ok": not GameConfig.ALLOW_BOTS, "error": "Bots are not allowed in BattleRift"},
		{"label": "Checking scenes", "ok": _scenes_exist(), "error": "Required scenes are missing"},
		{"label": "Preparing input", "ok": InputMap.has_action("move_left") and InputMap.has_action("jump"), "error": "Input map was not registered"},
	]
	var done := 0
	for check in checks:
		_status.text = String(check["label"])
		await get_tree().process_frame
		if not bool(check["ok"]):
			_status.text = String(check["error"])
			_status.add_theme_color_override("font_color", UiTheme.DANGER)
			return
		done += 1
		_bar.value = float(done) / float(checks.size())
		await get_tree().process_frame
	_status.text = "Restoring session"
	var restored: bool = await AuthService.restore_session()
	if restored:
		Router.go(Router.LOBBY)
	else:
		Router.go(Router.AUTH)