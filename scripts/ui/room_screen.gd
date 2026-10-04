extends Control

const GREEN := Color("#2ecc71")
const GRAY := Color("#4a5068")
const SIZE_LABELS := {2: "1v1", 4: "2v2", 6: "3v3"}
const TIMER_OPTIONS := [["1 min", 60], ["2 min", 120], ["3 min", 180], ["5 min", 300], ["10 min", 600], ["15 min", 900], ["30 min", 1800]]
const STOCK_OPTIONS := [["1", 1], ["2", 2], ["3", 3], ["5", 5], ["9", 9]]

var _client: RoomClient
var _title: Label
var _back_button: Button
var _status: Label
var _body: VBoxContainer
var _signature: String = ""
var _busy: bool = false
var _was_in_room: bool = false
var _capacity: int = 2
var _public_room: bool = false
var _join_input: LineEdit
var _public_list: VBoxContainer


func _ready() -> void:
	UiTheme.ensure(get_tree())
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
	header.add_theme_constant_override("separation", 12)
	_title = _label("Custom Room", 30, UiTheme.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_back_button = _button("Back", _on_back_pressed, 48.0)
	header.add_child(_back_button)
	column.add_child(header)
	_status = _label("", 20, UiTheme.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	column.add_child(scroll)
	_client = RoomClient.new()
	add_child(_client)
	_client.room_updated.connect(_on_room_updated)
	_client.failed.connect(_on_failed)
	if not PlayerData.remote:
		_body.add_child(_label("Rooms need a server account. Sign in with Google, GitHub, or Facebook.", 22, UiTheme.GOLD))
		return
	_enter()


func _label(text: String, font_size: int = 22, color: Color = UiTheme.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _section(text: String) -> Label:
	return _label(text, 18, UiTheme.MUTED)


func _button(text: String, callback: Callable, min_height: float = 52.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, min_height)
	button.pressed.connect(callback)
	return button


func _set_status(text: String, is_error: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UiTheme.DANGER if is_error else UiTheme.MUTED)


func _clear_body() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_public_list = null
	_join_input = null


func _enter() -> void:
	_set_status("Connecting...", false)
	var ok := await _client.refresh()
	if ok:
		_set_status("", false)
	if _signature.is_empty():
		_show_menu()


func _act(function_name: String, args: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	await _client.call_room(function_name, args)
	_busy = false


func _change(changes: Dictionary) -> void:
	_act("update_room", {"p_changes": changes})


func _on_failed(message: String) -> void:
	var text := message.substr(0, 1).to_upper() + message.substr(1)
	_set_status(text, true)


func _on_back_pressed() -> void:
	if _client.room.is_empty():
		Router.go(Router.LOBBY)
	else:
		_act("leave_room")


func _on_room_updated(room: Dictionary) -> void:
	var signature := JSON.stringify(room)
	if signature == _signature:
		return
	_signature = signature
	if room.is_empty():
		_show_menu()
	else:
		_show_room()


func _show_menu() -> void:
	_client.stop_polling()
	_clear_body()
	_title.text = "Custom Room"
	_back_button.text = "Back"
	if _was_in_room:
		_set_status("You are no longer in the room.", false)
		_was_in_room = false
	_body.add_child(_section("CREATE A ROOM"))
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for size_value in [2, 4, 6]:
		var button := Button.new()
		button.text = String(SIZE_LABELS[size_value])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_pressed_no_signal(size_value == _capacity)
		button.pressed.connect(func() -> void: _capacity = size_value)
		sizes.add_child(button)
	_body.add_child(sizes)
	var privacy := CheckButton.new()
	privacy.text = "Public room (listed for everyone)"
	privacy.button_pressed = _public_room
	privacy.toggled.connect(func(enabled: bool) -> void: _public_room = enabled)
	_body.add_child(privacy)
	_body.add_child(_button("Create Room", _on_create_pressed))
	_body.add_child(_section("JOIN WITH CODE"))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	_join_input = LineEdit.new()
	_join_input.placeholder_text = "ROOM CODE"
	_join_input.max_length = 5
	_join_input.custom_minimum_size = Vector2(0.0, 52.0)
	_join_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_input.text_changed.connect(_on_code_changed)
	join_row.add_child(_join_input)
	join_row.add_child(_button("Join", _on_join_pressed))
	_body.add_child(join_row)
	var list_header := HBoxContainer.new()
	var caption := _section("PUBLIC ROOMS")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_header.add_child(caption)
	list_header.add_child(_button("Refresh", _refresh_public, 44.0))
	_body.add_child(list_header)
	_public_list = VBoxContainer.new()
	_public_list.add_theme_constant_override("separation", 8)
	_body.add_child(_public_list)
	_refresh_public()


func _on_create_pressed() -> void:
	_act("create_room", {"p_capacity": _capacity, "p_privacy": "public" if _public_room else "private"})


func _on_code_changed(text: String) -> void:
	var upper := text.to_upper()
	if upper == text:
		return
	var caret := _join_input.caret_column
	_join_input.text = upper
	_join_input.caret_column = caret


func _on_join_pressed() -> void:
	var code := _join_input.text.strip_edges()
	if code.is_empty():
		_set_status("Enter a room code first.", true)
		return
	_act("join_room", {"p_code": code})


func _refresh_public() -> void:
	var list_node := _public_list
	var rooms := await _client.list_public()
	if not is_instance_valid(list_node) or list_node != _public_list:
		return
	for child in list_node.get_children():
		child.queue_free()
	if rooms.is_empty():
		list_node.add_child(_label("No public rooms right now.", 20, UiTheme.MUTED))
		return
	for entry in rooms:
		var info: Dictionary = entry
		var code := String(info["code"])
		var text := "%s   %s   %s   %s   %d/%d" % [
			code,
			String(SIZE_LABELS.get(int(info["capacity"]), "?")),
			String(info["mode"]).capitalize(),
			String(info["host_name"]),
			int(info["filled"]),
			int(info["capacity"]),
		]
		list_node.add_child(_button(text, _act.bind("join_room", {"p_code": code}), 48.0))


func _option(caption: String, items: Array, current: Variant, editable: bool, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _label(caption, 20, UiTheme.MUTED)
	label.custom_minimum_size = Vector2(110.0, 0.0)
	row.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(0.0, 48.0)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected := 0
	for i in items.size():
		picker.add_item(String(items[i][0]))
		if items[i][1] == current:
			selected = i
	picker.select(selected)
	picker.disabled = not editable
	picker.item_selected.connect(func(index: int) -> void: on_change.call(items[index][1]))
	row.add_child(picker)
	_body.add_child(row)


func _show_room() -> void:
	_was_in_room = true
	_clear_body()
	_client.start_polling()
	var room := _client.room
	var started := String(room["status"]) == "started"
	var is_host := _client.is_host()
	var me := _client.my_member()
	var capacity := int(room["capacity"])
	_title.text = "Room %s" % String(room["code"])
	_back_button.text = "Leave"
	_set_status("", false)
	_body.add_child(_label("%s   |   %s   |   %s" % [
		String(SIZE_LABELS.get(capacity, "?")),
		String(room["mode"]).capitalize(),
		String(room["privacy"]).capitalize(),
	], 20, UiTheme.MUTED))
	var editable := is_host and not started
	_option("Privacy", [["Private", "private"], ["Public", "public"]], String(room["privacy"]), editable,
		func(value: Variant) -> void: _change({"privacy": value}))
	_option("Mode", [["Stock", "stock"], ["Unlimited", "unlimited"]], String(room["mode"]), editable,
		func(value: Variant) -> void: _change({"mode": value}))
	var map_items: Array = []
	for map_id in RoomClient.MAPS:
		map_items.append([String(RoomClient.MAPS[map_id]), map_id])
	_option("Map", map_items, String(room["map_id"]), editable,
		func(value: Variant) -> void: _change({"map_id": value}))
	if String(room["mode"]) == "stock":
		_option("Stocks", STOCK_OPTIONS, int(room["stocks"]), editable,
			func(value: Variant) -> void: _change({"stocks": value}))
	else:
		_option("Timer", TIMER_OPTIONS, int(room["time_limit"]), editable,
			func(value: Variant) -> void: _change({"time_limit": value}))
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 12)
	for team in ["A", "B"]:
		teams.add_child(_team_panel(team, room, capacity, started, is_host, me))
	_body.add_child(teams)
	if started:
		_body.add_child(_label("ROOM LOCKED. WAITING FOR THE MATCH SERVER.", 22, UiTheme.GOLD))
		return
	var my_ready := bool(me.get("ready", false))
	_body.add_child(_button("Cancel Ready" if my_ready else "Ready", _act.bind("set_ready", {"p_ready": not my_ready}), 56.0))
	var check := _client.start_check()
	var all_ready := bool(check["ok"])
	if is_host:
		_body.add_child(_label("ALL READY" if all_ready else String(check["error"]).to_upper(), 22, GREEN if all_ready else UiTheme.MUTED))
		var start := _button("START", _act.bind("start_room"), 64.0)
		_style_start(start, all_ready)
		start.disabled = not all_ready
		_body.add_child(start)
	else:
		_body.add_child(_label("ALL READY. WAITING FOR HOST" if all_ready else String(check["error"]).to_upper(), 22, GREEN if all_ready else UiTheme.MUTED))


func _team_panel(team: String, room: Dictionary, capacity: int, started: bool, is_host: bool, me: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var per_team := int(capacity / 2.0)
	var members: Array = []
	for member in room["members"]:
		if String(member["team"]) == team:
			members.append(member)
	var header_color := UiTheme.ACCENT if team == "A" else UiTheme.DANGER
	column.add_child(_label("TEAM %s   %d/%d" % [team, members.size(), per_team], 22, header_color))
	for member in members:
		column.add_child(_member_row(member, room, started, is_host, me))
	for i in range(per_team - members.size()):
		column.add_child(_label("Open slot", 20, UiTheme.MUTED))
	if not started and String(me.get("team", "")) != team and members.size() < per_team:
		column.add_child(_button("Join Team %s" % team, _act.bind("set_team", {"p_team": team}), 48.0))
	return panel


func _member_row(member: Dictionary, room: Dictionary, started: bool, is_host: bool, me: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var user_id := String(member["user_id"])
	var is_me := user_id == String(me.get("user_id", ""))
	var name_label := _label(String(member["name"]), 20, UiTheme.GOLD if is_me else UiTheme.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)
	if user_id == String(room["host_id"]):
		row.add_child(_label("HOST", 16, UiTheme.GOLD))
	var is_ready := bool(member["ready"])
	row.add_child(_label("READY" if is_ready else "WAITING", 16, GREEN if is_ready else UiTheme.MUTED))
	if is_host and not is_me and not started:
		row.add_child(_button("Kick", _act.bind("kick_member", {"p_user": user_id}), 40.0))
	return row


func _style_start(button: Button, enabled: bool) -> void:
	var base := GREEN if enabled else GRAY
	var variants := {
		"normal": base,
		"hover": base.lightened(0.15) if enabled else base,
		"pressed": base.darkened(0.2) if enabled else base,
		"disabled": base,
	}
	for style_name in variants:
		var box := StyleBoxFlat.new()
		box.bg_color = variants[style_name]
		box.set_corner_radius_all(10)
		box.content_margin_left = 18.0
		box.content_margin_right = 18.0
		box.content_margin_top = 10.0
		box.content_margin_bottom = 10.0
		button.add_theme_stylebox_override(style_name, box)
	var text_color := UiTheme.BG if enabled else UiTheme.MUTED
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(color_name, text_color)