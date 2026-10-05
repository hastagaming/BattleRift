class_name ScreenFrame
extends Control

var title_text: String = ""
var body: VBoxContainer

var _cr_label: Label
var _br_label: Label
var _snack_panel: PanelContainer
var _snack_label: Label
var _snack_tween: Tween


func _ready() -> void:
	UiTheme.ensure(get_tree())
	if not PlayerData.is_signed_in:
		Router.go(Router.AUTH)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiTheme.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var area := ControlLayout.get_safe_area_rect(get_viewport())
	var full := get_viewport().get_visible_rect().size
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(area.position.x) + 16)
	margin.add_theme_constant_override("margin_right", int(full.x - area.end.x) + 16)
	margin.add_theme_constant_override("margin_top", int(area.position.y) + 12)
	margin.add_theme_constant_override("margin_bottom", int(full.y - area.end.y) + 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	header.add_child(title)
	_cr_label = Label.new()
	_cr_label.add_theme_color_override("font_color", UiTheme.GOLD)
	header.add_child(_cr_label)
	_br_label = Label.new()
	_br_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	header.add_child(_br_label)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0.0, 48.0)
	back.pressed.connect(_on_back_pressed)
	header.add_child(back)
	column.add_child(header)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	_build_snackbar(int(full.y - area.end.y))
	Economy.balance_changed.connect(_on_balance_changed)
	PlayerData.data_changed.connect(_refresh_balances)
	_refresh_balances()
	_build()


# Subclasses build their content into `body` here.
func _build() -> void:
	push_error("%s must override _build()" % get_class())


func _on_back_pressed() -> void:
	Router.go(Router.LOBBY)


func _on_balance_changed(_currency: String, _balance: int) -> void:
	_refresh_balances()


func _refresh_balances() -> void:
	if not PlayerData.is_signed_in or _cr_label == null:
		return
	_cr_label.text = "CR %d" % Economy.balance(Economy.CR)
	_br_label.text = "BR %d" % Economy.balance(Economy.BR)


func _build_snackbar(bottom_inset: int) -> void:
	var holder := VBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var row := CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	_snack_panel = PanelContainer.new()
	_snack_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snack_panel.modulate.a = 0.0
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.SURFACE_HOVER
	box.set_corner_radius_all(10)
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	_snack_panel.add_theme_stylebox_override("panel", box)
	row.add_child(_snack_panel)
	_snack_label = Label.new()
	_snack_panel.add_child(_snack_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, float(bottom_inset) + 28.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(spacer)


func notify(message: String, is_error: bool = false) -> void:
	if _snack_label == null:
		return
	_snack_label.text = message
	_snack_label.add_theme_color_override("font_color", UiTheme.DANGER if is_error else UiTheme.TEXT)
	if _snack_tween != null and _snack_tween.is_valid():
		_snack_tween.kill()
	_snack_panel.modulate.a = 1.0
	_snack_tween = create_tween()
	_snack_tween.tween_interval(2.4)
	_snack_tween.tween_property(_snack_panel, "modulate:a", 0.0, 0.35)


func friendly_error(message: String) -> String:
	if message.is_empty():
		return "Something went wrong"
	return (message.substr(0, 1).to_upper() + message.substr(1)).replace(" cr", " CR").replace(" br", " BR")


func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func make_tabs(entries: Array, selected_id: String, on_select: Callable) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, 58.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)
	var group := ButtonGroup.new()
	for entry in entries:
		var button := Button.new()
		button.text = String(entry[1])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0.0, 48.0)
		button.set_pressed_no_signal(String(entry[0]) == selected_id)
		button.pressed.connect(on_select.bind(String(entry[0])))
		row.add_child(button)
	return scroll


func make_list_scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll


func build_row(title: String, subtitle: String, color: Color, action: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(10.0, 52.0)
	row.add_child(swatch)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 24)
	text.add_child(title_label)
	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.add_theme_font_size_override("font_size", 17)
	subtitle_label.add_theme_color_override("font_color", UiTheme.MUTED)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(subtitle_label)
	row.add_child(text)
	if action != null:
		row.add_child(action)
	return panel


func empty_note(message: String, action_text: String = "", action_scene: String = "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", UiTheme.MUTED)
	box.add_child(label)
	if not action_text.is_empty() and not action_scene.is_empty():
		var button := Button.new()
		button.text = action_text
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.pressed.connect(Router.go.bind(action_scene))
		box.add_child(button)
	return box