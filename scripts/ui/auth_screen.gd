extends Control

const PROVIDER_LABELS := {"google": "Google", "github": "GitHub", "facebook": "Facebook"}
const PROVIDER_COLORS := {"google": Color("#4a90ff"), "github": Color("#c9d1e6"), "facebook": Color("#2f7bff")}

var _buttons: Array[Button] = []
var _status: Label
var _cancel_button: Button


func _ready() -> void:
	UiTheme.ensure(get_tree())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Loc.apply_to(self)
	var background := ColorRect.new()
	background.color = UiTheme.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var hero_texture := LoginArt.hero_texture(get_viewport_rect().size)
	if hero_texture != null:
		var hero := TextureRect.new()
		hero.texture = hero_texture
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hero)
	var shade := ColorRect.new()
	shade.color = Color(UiTheme.BG, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	center.add_child(card)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(440, 0)
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.svg")
	logo.custom_minimum_size = Vector2(96, 96)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(logo)
	var title := Label.new()
	title.text = "BATTLERIFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	title.add_theme_color_override("font_outline_color", UiTheme.BG)
	title.add_theme_constant_override("outline_size", 10)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = Loc.t("login.subtitle")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", UiTheme.MUTED)
	column.add_child(subtitle)
	for provider in PlayerData.PROVIDERS:
		var button := Button.new()
		button.text = Loc.t("login.continue_with", {"provider": PROVIDER_LABELS[provider]})
		button.custom_minimum_size = Vector2(0, 58)
		UiTheme.tint_button(button, PROVIDER_COLORS.get(provider, UiTheme.ACCENT))
		button.pressed.connect(_on_provider_pressed.bind(provider))
		column.add_child(button)
		_buttons.append(button)
	if OS.is_debug_build():
		var dev_button := Button.new()
		dev_button.text = Loc.t("login.dev_account")
		dev_button.custom_minimum_size = Vector2(0, 54)
		UiTheme.tint_button(dev_button, UiTheme.GOLD)
		dev_button.pressed.connect(_on_dev_pressed)
		column.add_child(dev_button)
		_buttons.append(dev_button)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", UiTheme.MUTED)
	column.add_child(_status)
	_cancel_button = Button.new()
	_cancel_button.text = Loc.t("common.cancel")
	_cancel_button.custom_minimum_size = Vector2(0, 48)
	_cancel_button.visible = false
	_cancel_button.pressed.connect(AuthService.cancel)
	column.add_child(_cancel_button)
	AuthService.state_changed.connect(_on_state_changed)
	if not AuthService.is_backend_configured():
		_set_status(Loc.t("login.backend_missing"), false)
	card.modulate.a = 0.0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.5)


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
		LanguageSync.apply_account()
		Router.go(TutorialStore.landing_scene())


func _on_dev_pressed() -> void:
	var result := AuthService.sign_in_dev()
	if bool(result["ok"]):
		Router.go(Router.LOBBY)
	else:
		_set_status(String(result["error"]), true)