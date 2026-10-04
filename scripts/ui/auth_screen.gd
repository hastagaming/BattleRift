extends Control

const PROVIDER_LABELS := {"google": "Google", "github": "GitHub", "facebook": "Facebook"}

var _buttons: Array[Button] = []
var _status: Label
var _cancel_button: Button


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
	column.custom_minimum_size = Vector2(420, 0)
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.svg")
	logo.custom_minimum_size = Vector2(88, 88)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(logo)
	var title := Label.new()
	title.text = "BATTLERIFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Sign in to enter the Rift"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", UiTheme.MUTED)
	column.add_child(subtitle)
	for provider in PlayerData.PROVIDERS:
		var button := Button.new()
		button.text = "Continue with %s" % PROVIDER_LABELS[provider]
		button.custom_minimum_size = Vector2(0, 54)
		button.pressed.connect(_on_provider_pressed.bind(provider))
		column.add_child(button)
		_buttons.append(button)
	if OS.is_debug_build():
		var dev_button := Button.new()
		dev_button.text = "Developer Local Account (debug only)"
		dev_button.custom_minimum_size = Vector2(0, 54)
		dev_button.add_theme_color_override("font_color", UiTheme.GOLD)
		dev_button.pressed.connect(_on_dev_pressed)
		column.add_child(dev_button)
		_buttons.append(dev_button)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", UiTheme.MUTED)
	column.add_child(_status)
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(0, 48)
	_cancel_button.visible = false
	_cancel_button.pressed.connect(AuthService.cancel)
	column.add_child(_cancel_button)
	AuthService.state_changed.connect(_on_state_changed)
	if not AuthService.is_backend_configured():
		_set_status("Supabase is not configured. Set supabase_url and supabase_anon_key in project.godot.", false)


func _set_status(message: String, is_error: bool) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", UiTheme.DANGER if is_error else UiTheme.MUTED)


func _on_state_changed(busy: bool, message: String, is_error: bool) -> void:
	for button in _buttons:
		button.disabled = busy
	_cancel_button.visible = busy
	_set_status(message, is_error)


func _on_provider_pressed(provider: String) -> void:
	var result: Dictionary = await AuthService.sign_in_with(provider)
	if bool(result["ok"]):
		Router.go(Router.LOBBY)


func _on_dev_pressed() -> void:
	var result := AuthService.sign_in_dev()
	if bool(result["ok"]):
		Router.go(Router.LOBBY)
	else:
		_set_status(String(result["error"]), true)