extends ScreenFrame

const QUEUES := [["battle_royal", "Battle Royal"], ["casual", "Casual"], ["ranked", "Ranked"]]
const MODES := [["1v1", "1v1"], ["2v2", "2v2"], ["3v3", "3v3"], ["4v4", "4v4"], ["5v5", "5v5"], ["6v6", "6v6"], ["7v7", "7v7"]]
const DESCRIPTIONS := {
	"battle_royal": "Free for all. The last player standing wins, and your Battle Royal rating changes by placement.",
	"casual": "Team match against players near your rating. Your rating does not change.",
	"ranked": "Team match against players near your rating. Your rating changes after the match.",
}
const POLL_INTERVAL := 2.0
const MAX_MISSED_POLLS := 6

var _queue: String = "casual"
var _mode: String = "1v1"
var _searching: bool = false
var _starting: bool = false
var _polling: bool = false
var _connection_ok: bool = true
var _missed: int = 0
var _search_started_msec: int = 0
var _poll_timer: Timer
var _select_box: VBoxContainer
var _search_box: VBoxContainer
var _mode_holder: VBoxContainer
var _rank_label: Label
var _description: Label
var _find_button: Button
var _labels: Dictionary = {}


func _init() -> void:
	title_text = "Play"


func _build() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_poll)
	add_child(_poll_timer)
	if not PlayerData.remote:
		body.add_child(empty_note("Matchmaking needs a server account. Sign in with Google, GitHub, or Facebook."))
		return
	_select_box = VBoxContainer.new()
	_select_box.add_theme_constant_override("separation", 12)
	body.add_child(_select_box)
	_search_box = VBoxContainer.new()
	_search_box.add_theme_constant_override("separation", 12)
	_search_box.visible = false
	body.add_child(_search_box)
	_build_select()
	_build_search()
	_refresh_select()


func _context() -> String:
	return "battle_royal" if _queue == "battle_royal" else _mode


func _build_select() -> void:
	_select_box.add_child(make_tabs(QUEUES, _queue, _on_queue))
	_mode_holder = VBoxContainer.new()
	_mode_holder.add_child(make_tabs(MODES, _mode, _on_mode))
	_select_box.add_child(_mode_holder)
	_rank_label = Label.new()
	_rank_label.add_theme_font_size_override("font_size", 24)
	_rank_label.add_theme_color_override("font_color", UiTheme.GOLD)
	_select_box.add_child(_rank_label)
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_color_override("font_color", UiTheme.MUTED)
	_select_box.add_child(_description)
	_find_button = Button.new()
	_find_button.text = "Find Match"
	_find_button.custom_minimum_size = Vector2(0.0, 64.0)
	_find_button.pressed.connect(_on_find)
	_select_box.add_child(_find_button)
	var room_button := Button.new()
	room_button.text = "Custom Room"
	room_button.custom_minimum_size = Vector2(0.0, 52.0)
	room_button.pressed.connect(Router.go.bind(Router.ROOM))
	_select_box.add_child(room_button)


func _build_search() -> void:
	var title := Label.new()
	title.text = "SEARCHING FOR PLAYERS"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	_search_box.add_child(title)
	for key in ["mode", "wait", "found", "range", "estimate", "connection"]:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 22)
		_search_box.add_child(label)
		_labels[key] = label
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0.0, 56.0)
	cancel.pressed.connect(_cancel_search)
	_search_box.add_child(cancel)


func _on_queue(queue: String) -> void:
	_queue = queue
	_refresh_select()


func _on_mode(mode: String) -> void:
	_mode = mode
	_refresh_select()


func _refresh_select() -> void:
	_mode_holder.visible = _queue != "battle_royal"
	var context := _context()
	var mmr := int(PlayerData.data["ratings"].get(context, RankSystem.DEFAULT_MMR))
	var context_label := "Battle Royal" if context == "battle_royal" else context
	_rank_label.text = "%s rank: %s  |  MMR %d" % [context_label, RankSystem.tier_name_for_mmr(mmr), mmr]
	_description.text = String(DESCRIPTIONS[_queue])


func _on_find() -> void:
	if _searching or _starting:
		return
	_find_button.disabled = true
	var args := {"p_queue": _queue, "p_context": _context()}
	var result: Dictionary = await Supabase.call_rpc("mm_enqueue", args)
	if not is_inside_tree():
		return
	if not bool(result["ok"]) and String(result["error"]).contains("already in a room"):
		await Supabase.call_rpc("leave_room")
		notify("Left your previous room")
		result = await Supabase.call_rpc("mm_enqueue", args)
		if not is_inside_tree():
			return
	_find_button.disabled = false
	if not bool(result["ok"]):
		notify(friendly_error(String(result["error"])), true)
		return
	var info: Dictionary = result["body"] if result["body"] is Dictionary else {}
	_begin_search(info)


func _begin_search(info: Dictionary) -> void:
	_searching = true
	_missed = 0
	_connection_ok = true
	_search_started_msec = Time.get_ticks_msec()
	_select_box.visible = false
	_search_box.visible = true
	var context_label := "Battle Royal" if _context() == "battle_royal" else "%s %s" % [String(_queue).capitalize(), _context()]
	(_labels["mode"] as Label).text = context_label
	(_labels["mode"] as Label).add_theme_color_override("font_color", UiTheme.GOLD)
	_apply_info(info)
	_poll_timer.start()


func _apply_info(info: Dictionary) -> void:
	if info.has("needed"):
		(_labels["found"] as Label).text = "Players found in range: %d / %d" % [int(info.get("found", 0)), int(info["needed"])]
		(_labels["range"] as Label).text = "Search range: +/- %d MMR (your MMR %d)" % [int(info.get("range", 0)), int(info.get("mmr", 0))]
		var estimate: Variant = info.get("est_wait")
		(_labels["estimate"] as Label).text = "Estimating wait time..." if estimate == null else "Estimated wait: about %s" % _format_seconds(int(estimate))
	_update_connection()


func _update_connection() -> void:
	var connection := _labels["connection"] as Label
	connection.text = "Connection: OK" if _connection_ok else "Connection: reconnecting..."
	connection.add_theme_color_override("font_color", UiTheme.TEXT if _connection_ok else UiTheme.DANGER)


func _format_seconds(total: int) -> String:
	return "%d:%02d" % [int(total / 60.0), total % 60]


func _process(_delta: float) -> void:
	if _searching:
		var elapsed := int((Time.get_ticks_msec() - _search_started_msec) / 1000.0)
		(_labels["wait"] as Label).text = "Time in queue: %s" % _format_seconds(elapsed)


func _poll() -> void:
	if _polling or not _searching:
		return
	_polling = true
	var result: Dictionary = await Supabase.call_rpc("mm_poll")
	_polling = false
	if not _searching or not is_inside_tree():
		return
	if not bool(result["ok"]) or not result["body"] is Dictionary:
		_missed += 1
		_connection_ok = false
		_update_connection()
		if _missed >= MAX_MISSED_POLLS:
			_stop_search_ui()
			notify("Lost connection to matchmaking", true)
		return
	_missed = 0
	_connection_ok = true
	var info: Dictionary = result["body"]
	match String(info.get("status", "")):
		"matched":
			_launch()
		"searching":
			_apply_info(info)
		_:
			_stop_search_ui()
			notify("The search ended")


func _launch() -> void:
	_starting = true
	_searching = false
	_poll_timer.stop()
	(_labels["estimate"] as Label).text = "Match found. Connecting..."
	PartyService.launch_match()


func _stop_search_ui() -> void:
	_searching = false
	_poll_timer.stop()
	_search_box.visible = false
	_select_box.visible = true
	_refresh_select()


func _cancel_search() -> void:
	if not _searching:
		return
	_stop_search_ui()
	await Supabase.call_rpc("mm_cancel")


func _on_back_pressed() -> void:
	if _searching:
		_stop_search_ui()
		await Supabase.call_rpc("mm_cancel")
	Router.go(Router.LOBBY)