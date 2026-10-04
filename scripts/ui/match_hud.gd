class_name MatchHud
extends Control

signal leave_requested

var state: MatchState
var local_peer: int = 0

var _top_panel: PanelContainer
var _timer_label: Label
var _score_label: Label
var _stocks_label: Label
var _banner: Label
var _feed: VBoxContainer
var _leave_button: Button
var _banner_token: int = 0
var _status_active: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_panel = PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_top_panel.add_child(column)
	_timer_label = _make_label(30, UiTheme.TEXT)
	column.add_child(_timer_label)
	_score_label = _make_label(20, UiTheme.MUTED)
	column.add_child(_score_label)
	_stocks_label = _make_label(18, UiTheme.GOLD)
	column.add_child(_stocks_label)
	add_child(_top_panel)
	_leave_button = Button.new()
	_leave_button.text = "Leave"
	_leave_button.pressed.connect(func() -> void: leave_requested.emit())
	add_child(_leave_button)
	_feed = VBoxContainer.new()
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)
	_banner = _make_label(64, UiTheme.TEXT)
	_banner.visible = false
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", UiTheme.BG)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.3
	_banner.anchor_bottom = 0.3
	_banner.offset_left = 0.0
	_banner.offset_right = 0.0
	_banner.offset_top = -48.0
	_banner.offset_bottom = 48.0
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_banner)
	state.clock_changed.connect(_on_clock)
	state.scores_changed.connect(func(_scores: Dictionary) -> void: _refresh_scores())
	state.participant_changed.connect(func(_peer_id: int) -> void: _refresh_stocks())
	state.player_knocked_out.connect(_on_knockout)
	get_viewport().size_changed.connect(_layout)
	_on_clock(state.clock)
	_refresh_scores()
	_refresh_stocks()
	_layout.call_deferred()


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _layout() -> void:
	var area := ControlLayout.get_safe_area_rect(get_viewport())
	var panel_size := _top_panel.get_combined_minimum_size()
	_top_panel.size = panel_size
	_top_panel.position = Vector2(area.position.x + (area.size.x - panel_size.x) * 0.5, area.position.y + 8.0)
	_leave_button.size = _leave_button.get_combined_minimum_size()
	_leave_button.position = area.position + Vector2(12.0, 8.0)
	_feed.position = area.position + Vector2(12.0, 64.0)


func show_banner(text: String, seconds: float = 0.0) -> void:
	_banner_token += 1
	var token := _banner_token
	_banner.text = text
	_banner.visible = true
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
		if token == _banner_token and not _status_active:
			_banner.visible = false


func hide_banner() -> void:
	_banner_token += 1
	_banner.visible = false


func _process(_delta: float) -> void:
	if state.phase != MatchState.Phase.ACTIVE:
		return
	var mine := state.participant(local_peer)
	var current := String(mine.get("state", ""))
	if current == MatchState.STATE_RESPAWNING:
		_status_active = true
		_banner.text = "RESPAWN IN %.1f" % float(mine["respawn_in"])
		_banner.visible = true
	elif current == MatchState.STATE_OUT:
		_status_active = true
		_banner.text = "ELIMINATED"
		_banner.visible = true
	elif _status_active:
		_status_active = false
		_banner.visible = false


func _on_clock(seconds: float) -> void:
	var total := int(maxf(seconds, 0.0))
	_timer_label.text = "%d:%02d" % [int(total / 60.0), total % 60]
	_layout.call_deferred()


func _refresh_scores() -> void:
	if state.mode == MatchState.MODE_PRACTICE:
		_score_label.text = "PRACTICE"
	else:
		var parts: Array[String] = []
		for team in state.scores:
			parts.append("%s %d" % [String(team), int(state.scores[team])])
		_score_label.text = "   ".join(parts)
	_layout.call_deferred()


func _refresh_stocks() -> void:
	_stocks_label.visible = state.mode == MatchState.MODE_STOCK
	if _stocks_label.visible:
		_stocks_label.text = "STOCKS x%d" % int(state.participant(local_peer).get("stocks", 0))
	_layout.call_deferred()


func _on_knockout(victim_id: int, killer_id: int) -> void:
	var victim_name := String(state.participant(victim_id).get("name", "?"))
	var text := "%s fell" % victim_name
	if killer_id >= 0:
		text = "%s knocked out %s" % [String(state.participant(killer_id).get("name", "?")), victim_name]
	var line := Label.new()
	line.text = text
	line.add_theme_color_override("font_color", UiTheme.TEXT)
	_feed.add_child(line)
	if _feed.get_child_count() > 4:
		_feed.get_child(0).queue_free()
	get_tree().create_timer(4.0).timeout.connect(line.queue_free)