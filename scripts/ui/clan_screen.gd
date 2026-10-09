extends ScreenFrame

const STATE_POLL := 8.0
const CHAT_POLL := 3.0
const MAX_LOCAL_MESSAGES := 100

var _tab: String = "find"
var _structure: String = ""
var _signature: String = ""
var _busy: bool = false
var _tab_bar: HBoxContainer
var _content: VBoxContainer
var _results: Array = []
var _query: String = ""
var _searched: bool = false
var _searching: bool = false
var _messages: Array = []
var _last_message_id: int = 0
var _chat_box: VBoxContainer
var _chat_scroll: ScrollContainer
var _chat_input: LineEdit
var _chat_polling: bool = false
var _confirm_disband: bool = false
var _manage_loaded: bool = false
var _create_form: Dictionary = {
	"name": "", "tag": "", "description": "", "rules": "",
	"min_rank": "", "min_br": 0, "min_level": 0, "approval": false,
}
var _manage_form: Dictionary = {
	"description": "", "rules": "",
	"min_rank": "", "min_br": 0, "min_level": 0, "approval": false,
}


func _init() -> void:
	title_text = "Clan"


func _label(text: String, font_size: int = 20, color: Color = UiTheme.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.pressed.connect(callback)
	return button


func _build() -> void:
	if not PlayerData.remote:
		body.add_child(empty_note("Clans need a server account. Sign in with Google, GitHub, or Facebook."))
		return
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 8)
	body.add_child(_tab_bar)
	var scroll := make_list_scroll()
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)
	body.add_child(scroll)
	var state_timer := Timer.new()
	state_timer.wait_time = STATE_POLL
	state_timer.timeout.connect(_on_state_timer)
	add_child(state_timer)
	state_timer.start()
	var chat_timer := Timer.new()
	chat_timer.wait_time = CHAT_POLL
	chat_timer.timeout.connect(_poll_chat)
	add_child(chat_timer)
	chat_timer.start()
	ClanService.state_changed.connect(_on_state_changed)
	_rebuild()
	ClanService.refresh()


func _on_state_timer() -> void:
	ClanService.refresh()


func _structure_key() -> String:
	return "%s|%s" % [String(ClanService.clan().get("id", "")), ClanService.my_role()]


func _valid_tabs() -> Array:
	if not ClanService.in_clan():
		return [["find", "Find Clan"], ["create", "Create Clan"]]
	var tabs: Array = [["overview", "Overview"], ["members", "Members"], ["chat", "Chat"]]
	if ClanService.can_manage():
		tabs.append(["manage", "Manage"])
	return tabs


func _rebuild() -> void:
	var tabs := _valid_tabs()
	var known := false
	for entry in tabs:
		if String(entry[0]) == _tab:
			known = true
	if not known:
		_tab = String(tabs[0][0])
	_structure = _structure_key()
	_signature = ClanService.signature()
	_render_tabs(tabs)
	clear_children(_content)
	_chat_box = null
	_chat_scroll = null
	_chat_input = null
	match _tab:
		"find":
			_render_find()
		"create":
			_render_create()
		"overview":
			_render_overview()
		"members":
			_render_members()
		"chat":
			_render_chat()
		"manage":
			_render_manage()


func _render_tabs(tabs: Array) -> void:
	clear_children(_tab_bar)
	var group := ButtonGroup.new()
	for entry in tabs:
		var button := Button.new()
		button.text = String(entry[1])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0.0, 48.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_pressed_no_signal(String(entry[0]) == _tab)
		button.pressed.connect(_switch_tab.bind(String(entry[0])))
		_tab_bar.add_child(button)


func _switch_tab(tab: String) -> void:
	_tab = tab
	_confirm_disband = false
	_rebuild()


func _on_state_changed(_state: Dictionary) -> void:
	if _content == null:
		return
	if _structure_key() != _structure:
		_messages.clear()
		_last_message_id = 0
		_manage_loaded = false
		_rebuild()
		return
	if _tab != "chat" and ClanService.signature() != _signature and not _busy:
		_rebuild()


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
	_rebuild()
	if _tab == "find":
		_run_search()


# ---- Form helpers ----

func _on_field_changed(text: String, form: Dictionary, key: String) -> void:
	form[key] = text


func _on_spin_changed(value: float, form: Dictionary, key: String) -> void:
	form[key] = int(value)


func _on_rank_selected(index: int, form: Dictionary) -> void:
	form["min_rank"] = "" if index == 0 else ClanRules.TIER_IDS[index - 1]


func _on_approval_toggled(pressed: bool, form: Dictionary) -> void:
	form["approval"] = pressed


func _add_field(parent: Control, caption: String, form: Dictionary, key: String, max_length: int, placeholder: String) -> void:
	parent.add_child(_label(caption, 18, UiTheme.MUTED))
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.max_length = max_length
	input.text = String(form[key])
	input.custom_minimum_size = Vector2(0.0, 48.0)
	input.text_changed.connect(_on_field_changed.bind(form, key))
	parent.add_child(input)


func _add_spin(parent: Control, caption: String, form: Dictionary, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _label(caption, 18, UiTheme.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 100000
	spin.step = 1
	spin.value = int(form[key])
	spin.custom_minimum_size = Vector2(160.0, 48.0)
	spin.value_changed.connect(_on_spin_changed.bind(form, key))
	row.add_child(spin)
	parent.add_child(row)


func _add_requirements_form(parent: Control, form: Dictionary) -> void:
	parent.add_child(_label("JOIN REQUIREMENTS", 18, UiTheme.MUTED))
	var rank_row := HBoxContainer.new()
	rank_row.add_theme_constant_override("separation", 12)
	var rank_label := _label("Minimum rank", 18, UiTheme.MUTED)
	rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_row.add_child(rank_label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(160.0, 48.0)
	picker.add_item("Any rank")
	var selected := 0
	for i in ClanRules.TIER_IDS.size():
		picker.add_item(ClanRules.tier_name(ClanRules.TIER_IDS[i]))
		if ClanRules.TIER_IDS[i] == String(form["min_rank"]):
			selected = i + 1
	picker.select(selected)
	picker.item_selected.connect(_on_rank_selected.bind(form))
	rank_row.add_child(picker)
	parent.add_child(rank_row)
	_add_spin(parent, "Minimum BR (balance, not spent)", form, "min_br")
	_add_spin(parent, "Minimum level", form, "min_level")
	var approval := CheckButton.new()
	approval.text = "Require approval to join"
	approval.button_pressed = bool(form["approval"])
	approval.toggled.connect(_on_approval_toggled.bind(form))
	parent.add_child(approval)


func _requirements_from(form: Dictionary) -> Dictionary:
	return ClanRules.build_requirements(String(form["min_rank"]), int(form["min_br"]), int(form["min_level"]), bool(form["approval"]))


# ---- Find ----

func _on_query_changed(text: String) -> void:
	_query = text


func _on_query_submitted(text: String) -> void:
	_query = text
	_run_search()


func _run_search() -> void:
	if _searching:
		return
	_searching = true
	var result: Dictionary = await ClanService.search(_query.strip_edges())
	_searching = false
	if not is_inside_tree():
		return
	_searched = true
	if bool(result["ok"]):
		_results = result["results"]
	else:
		notify(friendly_error(String(result["error"])), true)
	if _tab == "find":
		_rebuild()


func _make_clan_row(info: Dictionary) -> PanelContainer:
	var clan_id := String(info["id"])
	var requested := bool(info.get("requested", false)) or clan_id in ClanService.my_requests()
	var reason: Variant = info.get("reason")
	var requirements: Dictionary = info.get("requirements", {})
	var button := Button.new()
	button.custom_minimum_size = Vector2(160.0, 52.0)
	if requested:
		button.text = "Cancel Request"
		button.pressed.connect(_run.bind(ClanService.cancel_request.bind(clan_id), "Request cancelled"))
	elif reason != null:
		button.text = "Locked"
		button.disabled = true
	elif ClanRules.needs_approval(requirements):
		button.text = "Request"
		button.pressed.connect(_run.bind(ClanService.join.bind(clan_id), "Request sent"))
	else:
		button.text = "Join"
		button.pressed.connect(_run.bind(ClanService.join.bind(clan_id), "Joined the clan"))
	var subtitle := "Lv %d  |  %d / %d members  |  %s" % [
		int(info["level"]), int(info["members"]), int(info["capacity"]), ClanRules.requirements_text(requirements),
	]
	var description := String(info.get("description", ""))
	if not description.is_empty():
		subtitle += "\n%s" % description
	if reason != null:
		subtitle += "\n%s" % friendly_error(String(reason))
	var title := "[%s] %s" % [String(info["tag"]), String(info["name"])]
	return build_row(title, subtitle, UiTheme.ACCENT if reason == null else UiTheme.MUTED, button)


func _render_find() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var input := LineEdit.new()
	input.placeholder_text = "Search by name or tag"
	input.text = _query
	input.custom_minimum_size = Vector2(0.0, 48.0)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_changed.connect(_on_query_changed)
	input.text_submitted.connect(_on_query_submitted)
	row.add_child(input)
	row.add_child(_button("Search", _run_search))
	_content.add_child(row)
	if not _searched:
		_run_search()
	var pending := ClanService.my_requests().size()
	if pending > 0:
		_content.add_child(_label("Pending requests: %d" % pending, 18, UiTheme.MUTED))
	if _searched and _results.is_empty():
		_content.add_child(empty_note("No clans found. Try another search or create your own."))
	for entry in _results:
		_content.add_child(_make_clan_row(entry))


# ---- Create ----

func _render_create() -> void:
	_content.add_child(_label("CREATE A CLAN", 20, UiTheme.MUTED))
	_add_field(_content, "Clan name", _create_form, "name", 20, "3 to 20 letters, numbers, spaces, - or _")
	_add_field(_content, "Tag", _create_form, "tag", 5, "2 to 5 letters or numbers")
	_add_field(_content, "Description", _create_form, "description", ClanRules.MAX_DESCRIPTION, "What is your clan about?")
	_add_field(_content, "Rules", _create_form, "rules", ClanRules.MAX_RULES, "Rules for your members")
	_add_requirements_form(_content, _create_form)
	_content.add_child(_button("Create Clan", _on_create_pressed))


func _on_create_pressed() -> void:
	var clan_name := String(_create_form["name"]).strip_edges()
	var tag := String(_create_form["tag"]).strip_edges()
	if not ClanRules.valid_name(clan_name):
		notify("Clan name must be 3 to 20 letters, numbers, spaces, - or _", true)
		return
	if not ClanRules.valid_tag(tag):
		notify("Tag must be 2 to 5 letters or numbers", true)
		return
	var description := String(_create_form["description"]).strip_edges()
	var rules := String(_create_form["rules"]).strip_edges()
	_run(ClanService.create.bind(clan_name, tag, description, rules, _requirements_from(_create_form)), "Clan created")


# ---- Overview ----

func _render_overview() -> void:
	var clan := ClanService.clan()
	var members: Array = clan.get("members", [])
	var level := int(clan["level"])
	_content.add_child(_label("[%s] %s" % [String(clan["tag"]), String(clan["name"])], 30, UiTheme.ACCENT))
	var level_text := "Level %d" % level
	if level >= ClanRules.MAX_LEVEL:
		level_text += "  (max)"
	_content.add_child(_label(level_text, 22, UiTheme.GOLD))
	var bar := ProgressBar.new()
	bar.max_value = float(clan["xp_needed"])
	bar.value = float(clan["xp"])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 12.0)
	_content.add_child(bar)
	_content.add_child(_label("Clan XP %d / %d" % [int(clan["xp"]), int(clan["xp_needed"])], 17, UiTheme.MUTED))
	_content.add_child(_label("Members: %d / %d" % [members.size(), int(clan["capacity"])], 20))
	var leader_name := ""
	for entry in members:
		if String((entry as Dictionary)["role"]) == "leader":
			leader_name = String((entry as Dictionary)["name"])
	_content.add_child(_label("Leader: %s" % leader_name, 20))
	var description := String(clan.get("description", ""))
	if not description.is_empty():
		_content.add_child(_label(description, 20, UiTheme.MUTED))
	var rules := String(clan.get("rules", ""))
	if not rules.is_empty():
		_content.add_child(_label("Rules: %s" % rules, 18, UiTheme.MUTED))
	_content.add_child(_label("Join requirements: %s" % ClanRules.requirements_text(clan.get("requirements", {})), 18, UiTheme.MUTED))
	var ranked := members.duplicate()
	ranked.sort_custom(_by_contribution)
	_content.add_child(_label("TOP CONTRIBUTORS", 18, UiTheme.MUTED))
	for i in mini(3, ranked.size()):
		var member: Dictionary = ranked[i]
		_content.add_child(_label("%d. %s  |  %d XP" % [i + 1, String(member["name"]), int(member["contribution"])], 20))
	_content.add_child(_button("Leave Clan", _run.bind(ClanService.leave, "You left the clan")))


func _by_contribution(a: Variant, b: Variant) -> bool:
	return int((a as Dictionary)["contribution"]) > int((b as Dictionary)["contribution"])


# ---- Members ----

func _render_members() -> void:
	var clan := ClanService.clan()
	var members: Array = clan.get("members", [])
	_content.add_child(_label("MEMBERS  %d / %d" % [members.size(), int(clan["capacity"])], 22, UiTheme.ACCENT))
	var my_role := ClanService.my_role()
	var my_id := ClanService.my_id()
	for entry in members:
		var member: Dictionary = entry
		var user_id := String(member["user_id"])
		var role := String(member["role"])
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		if user_id != my_id:
			if my_role == "leader":
				if role == "member":
					actions.add_child(_button("Promote", _run.bind(ClanService.set_role.bind(user_id, "officer"), "Promoted to officer")))
				elif role == "officer":
					actions.add_child(_button("Demote", _run.bind(ClanService.set_role.bind(user_id, "member"), "Demoted to member")))
				actions.add_child(_button("Make Leader", _run.bind(ClanService.transfer.bind(user_id), "Leadership handed over")))
				actions.add_child(_button("Kick", _run.bind(ClanService.kick.bind(user_id), "Member removed")))
			elif my_role == "officer" and role == "member":
				actions.add_child(_button("Kick", _run.bind(ClanService.kick.bind(user_id), "Member removed")))
		var name_text := String(member["name"])
		var color := UiTheme.TEXT
		if role == "leader":
			name_text += "  (Leader)"
			color = UiTheme.GOLD
		elif role == "officer":
			name_text += "  (Officer)"
			color = UiTheme.ACCENT
		var status := "Lv %d  |  %s  |  %d XP" % [int(member["level"]), "Online" if bool(member["online"]) else "Offline", int(member["contribution"])]
		var row_action: Control = null
		if actions.get_child_count() > 0:
			row_action = actions
		_content.add_child(build_row(name_text, status, color, row_action))


# ---- Chat ----

func _add_chat_line(message: Dictionary) -> void:
	if _chat_box == null:
		return
	var mine := String(message["user_id"]) == ClanService.my_id()
	var line := _label("%s: %s" % [String(message["name"]), String(message["body"])], 19, UiTheme.GOLD if mine else UiTheme.TEXT)
	_chat_box.add_child(line)
	while _chat_box.get_child_count() > MAX_LOCAL_MESSAGES:
		var oldest := _chat_box.get_child(0)
		_chat_box.remove_child(oldest)
		oldest.queue_free()


func _scroll_chat_to_end() -> void:
	await get_tree().process_frame
	if is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


func _render_chat() -> void:
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.custom_minimum_size = Vector2(0.0, 260.0)
	_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_box = VBoxContainer.new()
	_chat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_box.add_theme_constant_override("separation", 4)
	_chat_scroll.add_child(_chat_box)
	_content.add_child(_chat_scroll)
	for message in _messages:
		_add_chat_line(message)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Message your clan"
	_chat_input.max_length = ClanRules.MAX_MESSAGE
	_chat_input.custom_minimum_size = Vector2(0.0, 48.0)
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.text_submitted.connect(_on_chat_submitted)
	row.add_child(_chat_input)
	row.add_child(_button("Send", _send_chat))
	_content.add_child(row)
	_scroll_chat_to_end()
	_poll_chat()


func _poll_chat() -> void:
	if _tab != "chat" or _chat_polling or not ClanService.in_clan() or _chat_box == null:
		return
	_chat_polling = true
	var result: Dictionary = await ClanService.messages(_last_message_id)
	_chat_polling = false
	if not is_inside_tree() or _chat_box == null or not bool(result["ok"]):
		return
	var fresh: Array = result["messages"]
	if fresh.is_empty():
		return
	for entry in fresh:
		var message: Dictionary = entry
		_last_message_id = maxi(_last_message_id, int(message["id"]))
		_messages.append(message)
		_add_chat_line(message)
	while _messages.size() > MAX_LOCAL_MESSAGES:
		_messages.pop_front()
	_scroll_chat_to_end()


func _on_chat_submitted(_text: String) -> void:
	_send_chat()


func _send_chat() -> void:
	if _busy or not is_instance_valid(_chat_input):
		return
	var text := _chat_input.text.strip_edges()
	if text.is_empty():
		return
	_chat_input.text = ""
	_busy = true
	var result: Dictionary = await ClanService.send_message(text)
	_busy = false
	if not is_inside_tree():
		return
	if bool(result["ok"]):
		_poll_chat()
	else:
		notify(friendly_error(String(result["error"])), true)
		if is_instance_valid(_chat_input):
			_chat_input.text = text


# ---- Manage ----

func _load_manage_form() -> void:
	var clan := ClanService.clan()
	var requirements: Dictionary = clan.get("requirements", {})
	_manage_form["description"] = String(clan.get("description", ""))
	_manage_form["rules"] = String(clan.get("rules", ""))
	_manage_form["min_rank"] = String(requirements.get("min_rank", ""))
	_manage_form["min_br"] = int(requirements.get("min_br", 0))
	_manage_form["min_level"] = int(requirements.get("min_level", 0))
	_manage_form["approval"] = bool(requirements.get("approval", false))
	_manage_loaded = true


func _render_manage() -> void:
	if not _manage_loaded:
		_load_manage_form()
	_content.add_child(_label("CLAN SETTINGS", 20, UiTheme.MUTED))
	_add_field(_content, "Description", _manage_form, "description", ClanRules.MAX_DESCRIPTION, "What is your clan about?")
	_add_field(_content, "Rules", _manage_form, "rules", ClanRules.MAX_RULES, "Rules for your members")
	_add_requirements_form(_content, _manage_form)
	_content.add_child(_button("Save Settings", _on_save_pressed))
	var requests: Array = ClanService.clan().get("requests", [])
	_content.add_child(_label("JOIN REQUESTS  %d" % requests.size(), 20, UiTheme.MUTED))
	if requests.is_empty():
		_content.add_child(_label("No pending requests.", 18, UiTheme.MUTED))
	for entry in requests:
		var request: Dictionary = entry
		var user_id := String(request["user_id"])
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		actions.add_child(_button("Accept", _run.bind(ClanService.respond.bind(user_id, true), "Player accepted")))
		actions.add_child(_button("Decline", _run.bind(ClanService.respond.bind(user_id, false), "Request declined")))
		var subtitle := "Lv %d  |  %s" % [int(request["level"]), RankSystem.tier_name_for_mmr(int(request["mmr"]))]
		_content.add_child(build_row(String(request["name"]), subtitle, UiTheme.GOLD, actions))
	if ClanService.my_role() == "leader":
		var label := "Tap again to confirm" if _confirm_disband else "Disband Clan"
		var disband := _button(label, _on_disband_pressed)
		disband.add_theme_color_override("font_color", UiTheme.DANGER)
		_content.add_child(disband)


func _on_save_pressed() -> void:
	var description := String(_manage_form["description"]).strip_edges()
	var rules := String(_manage_form["rules"]).strip_edges()
	_run(ClanService.update.bind(description, rules, _requirements_from(_manage_form)), "Settings saved")


func _on_disband_pressed() -> void:
	if not _confirm_disband:
		_confirm_disband = true
		notify("Tap again to disband the clan", true)
		_rebuild()
		await get_tree().create_timer(4.0).timeout
		if _confirm_disband and is_inside_tree():
			_confirm_disband = false
			if _tab == "manage":
				_rebuild()
		return
	_confirm_disband = false
	_run(ClanService.disband, "The clan was disbanded")