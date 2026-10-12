class_name Scoreboard
extends Control

var state: MatchState
var local_peer: int = 0

var _panel: PanelContainer
var _flow: HFlowContainer
var _scroll: ScrollContainer
var _dirty: bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "SCOREBOARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_flow = HFlowContainer.new()
	_flow.add_theme_constant_override("h_separation", 14)
	_flow.add_theme_constant_override("v_separation", 14)
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_flow)
	add_child(_panel)
	state.scores_changed.connect(_mark_dirty)
	state.participant_changed.connect(_mark_dirty)
	state.roster_changed.connect(_mark_dirty)
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()


func _mark_dirty(_value: Variant = null) -> void:
	_dirty = true


func toggle() -> void:
	set_open(not visible)


func set_open(open: bool) -> void:
	visible = open
	if open:
		_dirty = true
		_layout()


func _layout() -> void:
	if _panel == null:
		return
	var area := ControlLayout.get_safe_area_rect(get_viewport())
	var width := minf(area.size.x - 32.0, 920.0)
	var height := minf(area.size.y - 96.0, 520.0)
	_panel.custom_minimum_size = Vector2(width, 0.0)
	_scroll.custom_minimum_size = Vector2(0.0, height - 48.0)
	_panel.size = Vector2(width, height)
	_panel.position = Vector2(area.position.x + (area.size.x - width) * 0.5, area.position.y + 72.0)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_focus_next"):
		set_open(true)
	elif Input.is_action_just_released("ui_focus_next"):
		set_open(false)
	if visible and _dirty:
		_dirty = false
		_rebuild()


func _rebuild() -> void:
	for child in _flow.get_children():
		_flow.remove_child(child)
		child.queue_free()
	var show_stocks := state.mode == MatchState.MODE_STOCK
	for group in ScoreboardLogic.grouped(state.participants, local_peer, state.scores):
		_flow.add_child(_team_block(group, show_stocks))


func _team_block(group: Dictionary, show_stocks: bool) -> PanelContainer:
	var block := PanelContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.custom_minimum_size = Vector2(380.0, 0.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	block.add_child(box)
	var header := Label.new()
	header.text = "TEAM %s   %d" % [String(group["team"]), int(group["score"])]
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(header)
	var columns := 5 if show_stocks else 4
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	var heads: Array = ["PLAYER", "K", "D", "K/D"]
	if show_stocks:
		heads.append("STOCKS")
	for head in heads:
		grid.add_child(_cell(String(head), UiTheme.MUTED, 16, head != "PLAYER"))
	for row in group["rows"]:
		var info: Dictionary = row
		var color := UiTheme.GOLD if bool(info["is_local"]) else UiTheme.TEXT
		if bool(info["out"]):
			color = UiTheme.MUTED
		var label := String(info["name"])
		if bool(info["forfeited"]):
			label += " (left)"
		elif bool(info["out"]):
			label += " (out)"
		elif not bool(info["connected"]):
			label += " (reconnecting)"
		elif String(info["state"]) == MatchState.STATE_RESPAWNING:
			label += " (respawning)"
		var name_cell := _cell(label, color, 20, false)
		name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_cell.clip_text = true
		grid.add_child(name_cell)
		grid.add_child(_cell(str(int(info["kills"])), color, 20, true))
		grid.add_child(_cell(str(int(info["deaths"])), color, 20, true))
		grid.add_child(_cell(ScoreboardLogic.kd_text(int(info["kills"]), int(info["deaths"])), color, 20, true))
		if show_stocks:
			grid.add_child(_cell(str(int(info["stocks"])), color, 20, true))
	return block


func _cell(text: String, color: Color, font_size: int, centered: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(52.0, 0.0)
	return label