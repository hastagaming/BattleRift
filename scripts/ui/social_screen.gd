extends ScreenFrame

const FRIEND_POLL := 5.0
const AVATAR_SIZE := 56.0

var _tab: String = "party"
var _content: VBoxContainer
var _tab_buttons: Dictionary = {}
var _friends: Dictionary = {}
var _friends_loaded: bool = false
var _friends_error: String = ""
var _busy: bool = false
var _signature: String = ""
var _typed_code: String = ""
var _timer: Timer


func _init() -> void:
	title_text = "Social"


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.pressed.connect(callback)
	return button


func _actions() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	return row


func _chip(text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 1.0
	chip.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UiTheme.BG)
	chip.add_child(label)
	return chip


func _tag_color(tag: String) -> Color:
	match tag:
		"LEADER":
			return UiTheme.GOLD
		"YOU", "READY":
			return UiTheme.ACCENT
	return UiTheme.MUTED


func _dot(online: bool) -> PanelContainer:
	var dot := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.ACCENT if online else UiTheme.MUTED
	box.set_corner_radius_all(7)
	dot.add_theme_stylebox_override("panel", box)
	dot.custom_minimum_size = Vector2(14.0, 14.0)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return dot


func _avatar(display_name: String, color: Color) -> PanelContainer:
	var avatar := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.SURFACE_HOVER
	box.set_corner_radius_all(int(AVATAR_SIZE / 2.0))
	box.border_color = color
	box.set_border_width_all(3)
	avatar.add_theme_stylebox_override("panel", box)
	avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = SocialLogic.initial(display_name)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	avatar.add_child(label)
	return avatar


func _person_card(display_name: String, subtitle: String, online: bool, color: Color, tags: Array, actions: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	row.add_child(_avatar(display_name, color))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 4)
	var title_row := HFlowContainer.new()
	title_row.add_theme_constant_override("h_separation", 8)
	title_row.add_theme_constant_override("v_separation", 4)
	var title := Label.new()
	title.text = display_name
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", color)
	title_row.add_child(title)
	for tag in tags:
		title_row.add_child(_chip(String(tag), _tag_color(String(tag))))
	text.add_child(title_row)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	status_row.add_child(_dot(online))
	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.add_theme_font_size_override("font_size", 17)
	subtitle_label.add_theme_color_override("font_color", UiTheme.MUTED)
	status_row.add_child(subtitle_label)
	text.add_child(status_row)
	row.add_child(text)
	if actions != null:
		row.add_child(actions)
	return panel


func _section_heading(text: String, detail: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	row.add_child(heading)
	if not detail.is_empty():
		row.add_child(_chip(detail, UiTheme.SURFACE_HOVER))
		(row.get_child(1).get_child(0) as Label).add_theme_color_override("font_color", UiTheme.TEXT)
	return row


func _loading_note(message: String) -> Label:
	var label := Label.new()
	label.text = message
	label.add_theme_color_override("font_color", UiTheme.MUTED)
	return label


func _error_block(message: String, retry: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", UiTheme.DANGER)
	box.add_child(label)
	box.add_child(_button("Retry", retry))
	return box


func _update_tab_badges() -> void:
	if _tab_buttons.is_empty():
		return
	var incoming: Array = _friends.get("incoming", [])
	(_tab_buttons["party"] as Button).text = SocialLogic.badge_text("Party", PartyService.invites().size())
	(_tab_buttons["friends"] as Button).text = SocialLogic.badge_text("Friends", incoming.size())


func _build() -> void:
	if not PlayerData.remote:
		body.add_child(empty_note("Party and friends need a server account. Sign in with Google, GitHub, or Facebook."))
		return
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for entry in [["party", "Party"], ["friends", "Friends"]]:
		var button := Button.new()
		button.text = String(entry[1])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0.0, 48.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_pressed_no_signal(String(entry[0]) == _tab)
		button.pressed.connect(_switch_tab.bind(String(entry[0])))
		tabs.add_child(button)
		_tab_buttons[String(entry[0])] = button
	body.add_child(tabs)
	var scroll := make_list_scroll()
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)
	body.add_child(scroll)
	PartyService.state_changed.connect(_on_party_state)
	_timer = Timer.new()
	_timer.wait_time = FRIEND_POLL
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	_timer.start()
	_render()
	PartyService.refresh()
	_load_friends()


func _switch_tab(tab: String) -> void:
	_tab = tab
	(_tab_buttons[tab] as Button).set_pressed_no_signal(true)
	_signature = ""
	_render()
	if tab == "friends":
		_load_friends()


func _current_signature() -> String:
	if _tab == "party":
		return JSON.stringify([PartyService.state, PartyService.loaded, PartyService.last_error])
	return JSON.stringify([_friends, _friends_loaded, _friends_error])


func _on_party_state(_state: Dictionary) -> void:
	_update_tab_badges()
	if _tab == "party" and _current_signature() != _signature:
		_render()


func _on_timer() -> void:
	if _tab == "friends":
		_load_friends()


func _render() -> void:
	_signature = _current_signature()
	_update_tab_badges()
	clear_children(_content)
	if _tab == "party":
		_render_party()
	else:
		_render_friends()


func _run(task: Callable, success_message: String = "") -> void:
	if _busy:
		return
	_busy = true
	var result: Dictionary = await task.call()
	_busy = false
	if not is_inside_tree():
		return
	if bool(result["ok"]):
		if not success_message.is_empty():
			notify(success_message)
	else:
		notify(friendly_error(String(result["error"])), true)
	_render()


func _member_of(user_id: String) -> Dictionary:
	for entry in PartyService.party().get("members", []):
		if String((entry as Dictionary)["user_id"]) == user_id:
			return entry
	return {}


func _render_party() -> void:
	if not PartyService.loaded:
		if PartyService.last_error.is_empty():
			_content.add_child(_loading_note("Loading party..."))
		else:
			_content.add_child(_error_block("Could not load your party. %s" % friendly_error(PartyService.last_error), PartyService.refresh))
		return
	if not PartyService.last_error.is_empty():
		var warning := _loading_note("Connection problem. Showing the last known party.")
		warning.add_theme_color_override("font_color", UiTheme.GOLD)
		_content.add_child(warning)
	for entry in PartyService.invites():
		var invite: Dictionary = entry
		var party_id := String(invite["party_id"])
		var actions := _actions()
		actions.add_child(_button("Accept", _run.bind(PartyService.accept.bind(party_id), "Joined the party")))
		actions.add_child(_button("Decline", _run.bind(PartyService.decline.bind(party_id), "")))
		_content.add_child(build_row("%s invited you" % String(invite["from_name"]), "Party invite", UiTheme.GOLD, actions))
	var party := PartyService.party()
	if party.is_empty():
		_content.add_child(empty_note("You are not in a party. Create one and invite your friends to queue together."))
		_content.add_child(_button("Create Party", _run.bind(PartyService.create, "Party created")))
		return
	var members: Array = party["members"]
	var leader_id := String(party["leader_id"])
	var am_leader := PartyService.is_leader()
	_content.add_child(_section_heading("PARTY", "%d / %d" % [members.size(), int(party["max"])]))
	var progress := SocialLogic.ready_progress(members, leader_id)
	if int(progress["total"]) > 0:
		var ready_label := Label.new()
		ready_label.text = "Ready  %d / %d" % [int(progress["ready"]), int(progress["total"])]
		ready_label.add_theme_font_size_override("font_size", 17)
		ready_label.add_theme_color_override("font_color", UiTheme.MUTED)
		_content.add_child(ready_label)
		var bar := ProgressBar.new()
		bar.max_value = float(progress["total"])
		bar.value = float(progress["ready"])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0.0, 14.0)
		_content.add_child(bar)
	for entry in SocialLogic.sort_members(members, leader_id):
		var member: Dictionary = entry
		var user_id := String(member["user_id"])
		var is_leader := user_id == leader_id
		var is_me := user_id == PartyService.my_id()
		var actions := _actions()
		if am_leader and not is_me:
			actions.add_child(_button("Promote", _run.bind(PartyService.transfer.bind(user_id), "Leader changed")))
			actions.add_child(_button("Kick", _run.bind(PartyService.kick.bind(user_id), "Player removed")))
		var color := UiTheme.GOLD if is_me else UiTheme.TEXT
		_content.add_child(_person_card(String(member["name"]), SocialLogic.member_subtitle(member), bool(member["online"]), color, SocialLogic.member_tags(member, is_leader, is_me), actions if actions.get_child_count() > 0 else null))
	var invited: Array = party.get("invited", [])
	if not invited.is_empty():
		var names: Array[String] = []
		for entry in invited:
			names.append(String((entry as Dictionary)["name"]))
		var invited_label := Label.new()
		invited_label.text = "Waiting for: %s" % ", ".join(names)
		invited_label.add_theme_color_override("font_color", UiTheme.MUTED)
		_content.add_child(invited_label)
	if not am_leader:
		var me := _member_of(PartyService.my_id())
		var is_ready := bool(me.get("ready", false))
		_content.add_child(_button("Not Ready" if is_ready else "Ready", _run.bind(PartyService.set_ready.bind(not is_ready), "")))
	else:
		_content.add_child(_button("Invite Friends", _switch_tab.bind("friends")))
		var hint_text := SocialLogic.ready_hint(members, leader_id)
		if not hint_text.is_empty():
			var hint := Label.new()
			hint.text = hint_text
			hint.add_theme_color_override("font_color", UiTheme.ACCENT if SocialLogic.all_ready(members, leader_id) else UiTheme.MUTED)
			_content.add_child(hint)
	_content.add_child(_button("Find Match", Router.go.bind(Router.PLAY)))
	_content.add_child(_button("Leave Party", _run.bind(PartyService.leave, "Left the party")))


func _friend_rpc(function_name: String, args: Dictionary = {}) -> Dictionary:
	var result: Dictionary = await Supabase.call_rpc(function_name, args)
	if bool(result["ok"]) and result["body"] is Dictionary:
		_friends = result["body"]
		_friends_loaded = true
	return {"ok": bool(result["ok"]), "error": String(result["error"])}


func _load_friends() -> void:
	var result: Dictionary = await _friend_rpc("friends_state")
	if not is_inside_tree():
		return
	_friends_error = "" if bool(result["ok"]) else friendly_error(String(result["error"]))
	_update_tab_badges()
	if _tab == "friends" and _current_signature() != _signature:
		_render()


func _retry_friends() -> void:
	_friends_error = ""
	_signature = ""
	_render()
	_load_friends()


func _invite_friend(user_id: String) -> Dictionary:
	if not PartyService.in_party():
		var created: Dictionary = await PartyService.create()
		if not bool(created["ok"]):
			return created
	return await PartyService.invite(user_id)


func _on_typed(text: String) -> void:
	_typed_code = text.to_upper()


func _on_add_pressed() -> void:
	var code := _typed_code.strip_edges()
	if code.is_empty():
		notify("Enter a friend code first", true)
		return
	_typed_code = ""
	_run(_friend_rpc.bind("friend_add", {"p_code": code}), "Friend request sent")


func _on_copy_pressed(code: String) -> void:
	DisplayServer.clipboard_set(code)
	notify("Friend code copied")


func _render_friends() -> void:
	if not _friends_loaded:
		if _friends_error.is_empty():
			_content.add_child(_loading_note("Loading friends..."))
		else:
			_content.add_child(_error_block("Could not load your friends. %s" % _friends_error, _retry_friends))
		return
	if not _friends_error.is_empty():
		var warning := _loading_note("Connection problem. Showing the last known friends list.")
		warning.add_theme_color_override("font_color", UiTheme.GOLD)
		_content.add_child(warning)
	var code := String(_friends.get("code", ""))
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 12)
	var code_label := Label.new()
	code_label.text = "Your friend code: %s" % code
	code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_label.add_theme_font_size_override("font_size", 24)
	code_label.add_theme_color_override("font_color", UiTheme.GOLD)
	code_row.add_child(code_label)
	code_row.add_child(_button("Copy", _on_copy_pressed.bind(code)))
	_content.add_child(code_row)
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	var input := LineEdit.new()
	input.placeholder_text = "FRIEND CODE"
	input.max_length = 8
	input.text = _typed_code
	input.custom_minimum_size = Vector2(0.0, 48.0)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_changed.connect(_on_typed)
	add_row.add_child(input)
	add_row.add_child(_button("Add Friend", _on_add_pressed))
	_content.add_child(add_row)
	var incoming: Array = _friends.get("incoming", [])
	for entry in incoming:
		var request: Dictionary = entry
		var user_id := String(request["user_id"])
		var actions := _actions()
		actions.add_child(_button("Accept", _run.bind(_friend_rpc.bind("friend_respond", {"p_user": user_id, "p_accept": true}), "Friend added")))
		actions.add_child(_button("Decline", _run.bind(_friend_rpc.bind("friend_respond", {"p_user": user_id, "p_accept": false}), "")))
		_content.add_child(build_row(String(request["name"]), "Friend request", UiTheme.GOLD, actions))
	var friends: Array = _friends.get("friends", [])
	_content.add_child(_section_heading("FRIENDS", "%d  |  %d online" % [friends.size(), SocialLogic.online_count(friends)]))
	if friends.is_empty():
		_content.add_child(empty_note("No friends yet. Share your code or add a friend by theirs."))
	for entry in SocialLogic.sort_friends(friends):
		var friend: Dictionary = entry
		var user_id := String(friend["user_id"])
		var online := bool(friend["online"])
		var actions := _actions()
		var invite_button := _button("Invite", _run.bind(_invite_friend.bind(user_id), "Invite sent"))
		invite_button.disabled = not SocialLogic.can_invite(friend)
		actions.add_child(invite_button)
		actions.add_child(_button("Remove", _run.bind(_friend_rpc.bind("friend_remove", {"p_user": user_id}), "Friend removed")))
		_content.add_child(_person_card(String(friend["name"]), SocialLogic.friend_subtitle(friend), online, UiTheme.TEXT if online else UiTheme.MUTED, [], actions))
	var outgoing: Array = _friends.get("outgoing", [])
	if not outgoing.is_empty():
		var names: Array[String] = []
		for entry in outgoing:
			names.append(String((entry as Dictionary)["name"]))
		var pending := Label.new()
		pending.text = "Waiting for: %s" % ", ".join(names)
		pending.add_theme_color_override("font_color", UiTheme.MUTED)
		_content.add_child(pending)