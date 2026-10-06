extends ScreenFrame

const KIND_TEXT := {
	"matches": "Play %d matches",
	"wins": "Win %d matches",
	"eliminations": "Get %d eliminations",
}

var _list: VBoxContainer
var _busy: bool = false
var _loaded: bool = false
var _loaded_msec: int = 0
var _daily_resets: int = 0
var _weekly_resets: int = 0
var _missions: Array = []
var _reset_labels: Dictionary = {}


func _init() -> void:
	title_text = "Missions"


func _build() -> void:
	if not PlayerData.remote:
		body.add_child(empty_note("Missions need a server account. Sign in with Google, GitHub, or Facebook."))
		return
	var scroll := make_list_scroll()
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	body.add_child(scroll)
	_load()


func _load() -> void:
	var result: Dictionary = await Supabase.call_rpc("get_missions")
	if not is_inside_tree():
		return
	if not bool(result["ok"]) or not result["body"] is Dictionary:
		_show_error(friendly_error(String(result["error"])))
		return
	var data: Dictionary = result["body"]
	_missions = data.get("missions", [])
	_daily_resets = int(data.get("daily_resets_in", 0))
	_weekly_resets = int(data.get("weekly_resets_in", 0))
	_loaded_msec = Time.get_ticks_msec()
	_loaded = true
	_render()


func _show_error(message: String) -> void:
	clear_children(_list)
	var label := Label.new()
	label.text = "Could not load missions. %s" % message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", UiTheme.DANGER)
	_list.add_child(label)
	var retry := Button.new()
	retry.text = "Retry"
	retry.custom_minimum_size = Vector2(0.0, 52.0)
	retry.pressed.connect(_load)
	_list.add_child(retry)


func _format_reset(seconds: int) -> String:
	if seconds >= 86400:
		return "%dd %dh" % [int(seconds / 86400.0), int((seconds % 86400) / 3600.0)]
	if seconds >= 3600:
		return "%dh %02dm" % [int(seconds / 3600.0), int((seconds % 3600) / 60.0)]
	return "%dm %02ds" % [int(seconds / 60.0), seconds % 60]


func _remaining(period: String) -> int:
	var elapsed := int((Time.get_ticks_msec() - _loaded_msec) / 1000.0)
	var total := _daily_resets if period == "daily" else _weekly_resets
	return maxi(total - elapsed, 0)


func _process(_delta: float) -> void:
	if not _loaded:
		return
	for period in _reset_labels:
		(_reset_labels[period] as Label).text = "Resets in %s" % _format_reset(_remaining(period))
	if _remaining("daily") <= 0 and not _busy:
		_loaded = false
		_load()


func _render() -> void:
	clear_children(_list)
	_reset_labels.clear()
	for period in ["daily", "weekly"]:
		var heading := HBoxContainer.new()
		var title := Label.new()
		title.text = "DAILY" if period == "daily" else "WEEKLY"
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 22)
		title.add_theme_color_override("font_color", UiTheme.ACCENT)
		heading.add_child(title)
		var reset := Label.new()
		reset.add_theme_color_override("font_color", UiTheme.MUTED)
		heading.add_child(reset)
		_reset_labels[period] = reset
		_list.add_child(heading)
		for entry in _missions:
			var mission: Dictionary = entry
			if String(mission["period"]) == period:
				_list.add_child(_make_mission_row(mission))


func _make_mission_row(mission: Dictionary) -> PanelContainer:
	var target := int(mission["target"])
	var progress := int(mission["progress"])
	var claimed := bool(mission["claimed"])
	var done := progress >= target
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = String(KIND_TEXT.get(String(mission["kind"]), "Mission")) % target
	title.add_theme_font_size_override("font_size", 24)
	text.add_child(title)
	var bar := ProgressBar.new()
	bar.max_value = float(target)
	bar.value = float(progress)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 10.0)
	text.add_child(bar)
	var rewards: Array[String] = []
	if int(mission["reward_cr"]) > 0:
		rewards.append("%d CR" % int(mission["reward_cr"]))
	if int(mission["reward_xp"]) > 0:
		rewards.append("%d XP" % int(mission["reward_xp"]))
	var detail := Label.new()
	detail.text = "%d / %d   |   Reward: %s" % [progress, target, ", ".join(rewards)]
	detail.add_theme_font_size_override("font_size", 17)
	detail.add_theme_color_override("font_color", UiTheme.MUTED)
	text.add_child(detail)
	row.add_child(text)
	var button := Button.new()
	button.custom_minimum_size = Vector2(150.0, 52.0)
	if claimed:
		button.text = "Claimed"
		button.disabled = true
	elif done:
		button.text = "Claim"
		button.disabled = _busy
		button.pressed.connect(_on_claim.bind(String(mission["id"])))
	else:
		button.text = "In progress"
		button.disabled = true
	row.add_child(button)
	return panel


func _on_claim(mission_id: String) -> void:
	if _busy:
		return
	_busy = true
	var result: Dictionary = await Supabase.call_rpc("claim_mission", {"p_mission_id": mission_id})
	_busy = false
	if not is_inside_tree():
		return
	if bool(result["ok"]) and result["body"] is Dictionary:
		PlayerData.apply_remote_snapshot(result["body"])
		notify("Reward claimed")
		_load()
	else:
		notify(friendly_error(String(result["error"])), true)
		_render()