extends Control

# Guide part of the tutorial: welcome / resume card and the feature cards. Gameplay steps run in
# the practice arena (TutorialDirector) and come back here when they are finished.

var _flow: TutorialFlow
var _column: VBoxContainer
var _step_label: Label
var _title_label: Label
var _body_label: Label
var _back_button: Button
var _continue_button: Button
var _skip_button: Button
var _resume_mode: bool = false


func _ready() -> void:
	UiTheme.ensure(get_tree())
	if not PlayerData.is_signed_in:
		Router.go(Router.AUTH)
		return
	_build_ui()
	var saved := TutorialProgress.saved_index(PlayerData.data)
	var active := TutorialProgress.status(PlayerData.data) == TutorialProgress.STATUS_ACTIVE
	var from_arena := TutorialStore.from_arena
	TutorialStore.from_arena = false
	_flow = TutorialFlow.new(saved if active else 0)
	_resume_mode = active and saved > 0 and not from_arena
	_show_current()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiTheme.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var area := ControlLayout.get_safe_area_rect(get_viewport())
	var full := get_viewport().get_visible_rect().size
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(area.position.x) + 20)
	margin.add_theme_constant_override("margin_top", int(area.position.y) + 16)
	margin.add_theme_constant_override("margin_right", int(full.x - area.end.x) + 20)
	margin.add_theme_constant_override("margin_bottom", int(full.y - area.end.y) + 16)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	_column = VBoxContainer.new()
	_column.custom_minimum_size = Vector2(minf(area.size.x - 40.0, 640.0), 0.0)
	_column.add_theme_constant_override("separation", 12)
	center.add_child(_column)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.svg")
	logo.custom_minimum_size = Vector2(72.0, 72.0)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(logo)
	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.add_theme_color_override("font_color", UiTheme.MUTED)
	_column.add_child(_step_label)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	_column.add_child(_title_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, minf(area.size.y * 0.38, 260.0))
	_column.add_child(scroll)
	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_font_size_override("font_size", 21)
	scroll.add_child(_body_label)
	_continue_button = _make_button("Continue", _on_continue_pressed)
	_column.add_child(_continue_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_column.add_child(row)
	_back_button = _make_button("Back", _on_back_pressed)
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_back_button)
	_skip_button = _make_button("Skip tutorial", _on_skip_pressed)
	_skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_skip_button)


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 54.0)
	button.pressed.connect(callback)
	return button


func _show_current() -> void:
	var step := _flow.current()
	if _resume_mode:
		_step_label.text = "Tutorial in progress"
		_title_label.text = "Welcome back"
		_body_label.text = "You stopped at \"%s\" (%s). Pick up where you left off, or start the tutorial again." % [String(step["title"]), _flow.progress_text().to_lower()]
		_continue_button.text = "Resume"
		_back_button.text = "Start over"
		_back_button.disabled = false
		return
	_step_label.text = _flow.progress_text()
	_title_label.text = String(step["title"])
	_body_label.text = String(step["body"])
	_back_button.text = "Back"
	_back_button.disabled = not _flow.can_go_back()
	if _flow.index == 0:
		_continue_button.text = "Start"
	elif _flow.is_last():
		_continue_button.text = "Finish"
	else:
		_continue_button.text = "Continue"


func _on_continue_pressed() -> void:
	if _resume_mode:
		_resume_mode = false
		if _flow.where() == TutorialFlow.WHERE_MATCH:
			_launch_practice()
			return
		_show_current()
		return
	var result := _flow.advance()
	if not bool(result["ok"]):
		return
	if bool(result["finished"]):
		await TutorialStore.complete()
		Router.go(Router.LOBBY)
		return
	TutorialStore.save_step(_flow.index)
	if _flow.where() == TutorialFlow.WHERE_MATCH:
		_launch_practice()
		return
	_show_current()


func _on_back_pressed() -> void:
	if _resume_mode:
		TutorialStore.restart()
		_flow = TutorialFlow.new(0)
		_resume_mode = false
		_show_current()
		return
	if _flow.back():
		TutorialStore.save_step(_flow.index)
		_show_current()


func _on_skip_pressed() -> void:
	await TutorialStore.skip()
	Router.go(Router.LOBBY)


func _launch_practice() -> void:
	MatchSession.config = MatchSession.practice()
	MatchSession.tutorial = true
	Router.go(Router.MATCH)