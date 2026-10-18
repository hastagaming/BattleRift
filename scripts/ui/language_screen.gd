extends Control

# Language picker. It opens on the first launch and from Settings. Router.language_return says
# where Continue goes. Choosing a language changes the screen at once, so the player can see it.

var _selected: String = ""
var _first_launch: bool = false


func _ready() -> void:
	UiTheme.ensure(get_tree())
	_first_launch = Loc.needs_first_choice()
	_selected = Loc.current()
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
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
	shade.color = Color(UiTheme.BG, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var area := ControlLayout.get_safe_area_rect(get_viewport())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(area.position.x) + 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", int(area.position.y) + 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var card := PanelContainer.new()
	center.add_child(card)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(480, 0)
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var title := Label.new()
	title.text = Loc.t("language.choose")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(title)
	var suggested := Loc.suggested_language()
	if _first_launch and not suggested.is_empty():
		var hint := Label.new()
		hint.text = "%s: %s" % [Loc.t("language.suggested"), String(Loc.language_info(suggested)["name"])]
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", UiTheme.MUTED)
		column.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var languages := Loc.available()
	var selected_button: Button = null
	for info in languages:
		var code := String(info["code"])
		var button := Button.new()
		button.text = String(info["name"]) if info["name"] == info["name_en"] else "%s  |  %s" % [String(info["name"]), String(info["name_en"])]
		button.custom_minimum_size = Vector2(0, 56)
		if code == _selected:
			UiTheme.tint_button(button, UiTheme.ACCENT)
			selected_button = button
		button.pressed.connect(_on_pick.bind(code))
		list.add_child(button)
	if selected_button != null:
		scroll.ensure_control_visible.call_deferred(selected_button)
	var count := Label.new()
	count.text = Loc.n("language.available_count", languages.size())
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_color_override("font_color", UiTheme.MUTED)
	column.add_child(count)
	var go := Button.new()
	go.text = Loc.t("common.continue")
	go.custom_minimum_size = Vector2(0, 58)
	UiTheme.tint_button(go, UiTheme.GOLD)
	go.pressed.connect(_on_continue)
	column.add_child(go)


func _on_pick(code: String) -> void:
	_selected = code
	Loc.set_language(code, false)
	_build()


func _on_continue() -> void:
	Loc.set_language(_selected, true)
	LanguageSync.push_to_account()
	var target := Router.language_return
	Router.language_return = Router.BOOT
	Router.go(target)