extends ScreenFrame

const FRIEND_POLL := 5.0

var _tab: String = "party"
var _content: VBoxContainer
var _tab_buttons: Dictionary = {}
var _friends: Dictionary = {}
var _friends_loaded: bool = false
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
		return JSON.stringify(PartyService.state)
	return JSON.stringify(_friends)


func _on_party_state(_state: Dictionary) -> void:
	if _tab == "party" and _current_signature() != _signature:
		_render()


func _on_timer() -> void:
	if _tab == "friends":
		_load_friends()


func _render() -> void:
	_signature = _current_signature()
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
	var heading := Label.new()
	heading.text = "PARTY  %d / %d" % [members.size(), int(party["max"])]
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	_content.add_child(heading)
	for entry in members:
		var member: Dictionary = entry
		var user_id := String(member["user_id"])
		var is_leader := user_id == leader_id
		var is_me := user_id == PartyService.my_id()
		var name_text := String(member["name"])
		if is_leader:
			name_text += "  (Leader)"
		var status: Array[String] = ["Lv %d" % int(member["level"])]
		status.append("Online" if bool(member["online"]) else "Offline")
		if not is_leader:
			status.append("Ready" if bool(member["ready"]) else "Not ready")
		var actions := _actions()
		if am_leader and not is_me:
			actions.add_child(_button("Promote", _run.bind(PartyService.transfer.bind(user_id), "Leader changed")))
			actions.add_child(_button("Kick", _run.bind(PartyService.kick.bind(user_id), "Player removed")))
		var color := UiTheme.GOLD if is_me else UiTheme.TEXT
		_content.add_child(build_row(name_text, "  |  ".join(status), color, actions if actions.get_child_count() > 0 else null))
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
		if members.size() > 1:
			var hint := Label.new()
			hint.text = "Members must be ready before you start matchmaking."
			hint.add_theme_color_override("font_color", UiTheme.MUTED)
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
	await _friend_rpc("friends_state")
	if is_inside_tree() and _tab == "friends" and _current_signature() != _signature:
		_render()


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
		var loading := Label.new()
		loading.text = "Loading friends..."
		loading.add_theme_color_override("font_color", UiTheme.MUTED)
		_content.add_child(loading)
		return
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
	if friends.is_empty():
		_content.add_child(empty_note("No friends yet. Share your code or add a friend by theirs."))
	for entry in friends:
		var friend: Dictionary = entry
		var user_id := String(friend["user_id"])
		var online := bool(friend["online"])
		var status := "Online" if online else "Offline"
		if bool(friend["in_party"]):
			status += "  |  In a party"
		var actions := _actions()
		var invite_button := _button("Invite", _run.bind(_invite_friend.bind(user_id), "Invite sent"))
		invite_button.disabled = not online or bool(friend["in_party"])
		actions.add_child(invite_button)
		actions.add_child(_button("Remove", _run.bind(_friend_rpc.bind("friend_remove", {"p_user": user_id}), "Friend removed")))
		_content.add_child(build_row(String(friend["name"]), "Lv %d  |  %s" % [int(friend["level"]), status], UiTheme.ACCENT if online else UiTheme.MUTED, actions))
	var outgoing: Array = _friends.get("outgoing", [])
	if not outgoing.is_empty():
		var names: Array[String] = []
		for entry in outgoing:
			names.append(String((entry as Dictionary)["name"]))
		var pending := Label.new()
		pending.text = "Waiting for: %s" % ", ".join(names)
		pending.add_theme_color_override("font_color", UiTheme.MUTED)
		_content.add_child(pending)