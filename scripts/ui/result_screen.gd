class_name ResultScreen
extends Control

var result: Dictionary = {}
var local_peer: int = 0
var on_back: Callable = Callable()

var _preview: CharacterPreview


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.BG, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	_preview = CharacterPreview.new()
	row.add_child(_preview)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(460.0, 0.0)
	column.add_theme_constant_override("separation", 10)
	row.add_child(column)
	var title := Label.new()
	title.text = _title_text()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", _title_color())
	column.add_child(title)
	var summary := Label.new()
	summary.text = "%s  |  %s" % [_reason_text(), _duration_text()]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_color_override("font_color", UiTheme.MUTED)
	column.add_child(summary)
	var battle_royal := String(result.get("queue_type", "")) == "battle_royal"
	var place := int(_local_row().get("placement", 0))
	if battle_royal and place > 0:
		var place_label := Label.new()
		place_label.text = "Placement #%d of %d" % [place, (result.get("participants", {}) as Dictionary).size()]
		place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		place_label.add_theme_font_size_override("font_size", 26)
		column.add_child(place_label)
	var scores: Dictionary = result.get("scores", {})
	var show_scores := String(result.get("mode", "")) != MatchState.MODE_PRACTICE and not battle_royal and not scores.is_empty()
	if show_scores:
		var parts: Array[String] = []
		for team in scores:
			parts.append("%s %d" % [String(team), int(scores[team])])
		var score_label := Label.new()
		score_label.text = "   ".join(parts)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.add_theme_font_size_override("font_size", 28)
		column.add_child(score_label)
	column.add_child(_build_table())
	var rewards: Dictionary = result.get("rewards", {})
	if not rewards.is_empty():
		column.add_child(_build_rewards(rewards))
	var note := String(result.get("note", ""))
	if not note.is_empty():
		var note_label := Label.new()
		note_label.text = note
		note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note_label.add_theme_color_override("font_color", UiTheme.MUTED)
		column.add_child(note_label)
	var emote_button := Button.new()
	emote_button.text = "Play Emote"
	emote_button.custom_minimum_size = Vector2(0.0, 48.0)
	emote_button.pressed.connect(_on_emote_pressed)
	column.add_child(emote_button)
	var back := Button.new()
	back.text = "Back to Lobby"
	back.custom_minimum_size = Vector2(0.0, 56.0)
	back.pressed.connect(_on_back_pressed)
	column.add_child(back)
	if _title_text() == "VICTORY":
		get_tree().create_timer(0.8).timeout.connect(_on_emote_pressed)


func _on_emote_pressed() -> void:
	if is_instance_valid(_preview):
		_preview.play_emote()


func _on_back_pressed() -> void:
	if on_back.is_valid():
		on_back.call()
	else:
		Router.go(Router.LOBBY)


func _local_row() -> Dictionary:
	var rows: Dictionary = result.get("participants", {})
	return rows.get(local_peer, {})


func _title_text() -> String:
	if String(result.get("mode", "")) == MatchState.MODE_PRACTICE:
		return "PRACTICE ENDED"
	if bool(result.get("draw", false)):
		return "DRAW"
	var won := String(_local_row().get("team", "")) == String(result.get("winner_team", ""))
	return "VICTORY" if won else "DEFEAT"


func _title_color() -> Color:
	var title := _title_text()
	if title == "VICTORY":
		return UiTheme.ACCENT
	if title == "DEFEAT":
		return UiTheme.DANGER
	return UiTheme.GOLD


func _reason_text() -> String:
	match String(result.get("reason", "")):
		"time":
			return "Time is up"
		"last_team":
			return "Last team standing"
		"quit":
			return "Match left"
	return ""


func _duration_text() -> String:
	var total := int(float(result.get("duration", 0.0)))
	return "%d:%02d" % [int(total / 60.0), total % 60]


func _cell(text: String, color: Color = UiTheme.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _placement_less(a: Variant, b: Variant) -> bool:
	var rows: Dictionary = result.get("participants", {})
	return int(rows[a]["placement"]) < int(rows[b]["placement"])


func _build_table() -> GridContainer:
	var rows: Dictionary = result.get("participants", {})
	var battle_royal := String(result.get("queue_type", "")) == "battle_royal"
	var headers: Array[String] = ["Player", "Team", "Kills", "Deaths", "Stocks"]
	if battle_royal:
		headers = ["Place", "Player", "Kills", "Deaths"]
	var grid := GridContainer.new()
	grid.columns = headers.size()
	grid.add_theme_constant_override("h_separation", 16)
	for header in headers:
		grid.add_child(_cell(header, UiTheme.MUTED))
	var order: Array = rows.keys()
	if battle_royal:
		order.sort_custom(_placement_less)
	for peer_id in order:
		var row: Dictionary = rows[peer_id]
		var color := UiTheme.GOLD if int(peer_id) == local_peer else UiTheme.TEXT
		if battle_royal:
			grid.add_child(_cell("#%d" % int(row["placement"]), color))
			grid.add_child(_cell(String(row["name"]), color))
		else:
			grid.add_child(_cell(String(row["name"]), color))
			grid.add_child(_cell(String(row["team"]), color))
		grid.add_child(_cell(str(int(row["kills"])), color))
		grid.add_child(_cell(str(int(row["deaths"])), color))
		if not battle_royal:
			grid.add_child(_cell(str(int(row["stocks"])), color))
	return grid


func _build_rewards(rewards: Dictionary) -> Label:
	var parts: Array[String] = []
	if rewards.has("cr"):
		parts.append("CR +%d" % int(rewards["cr"]))
	if rewards.has("xp"):
		parts.append("XP +%d" % int(rewards["xp"]))
	if rewards.has("rank_delta"):
		parts.append("Rank %+d" % int(rewards["rank_delta"]))
	if rewards.has("rank_tier"):
		parts.append(String(rewards["rank_tier"]))
	var label := Label.new()
	label.text = "   ".join(parts)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiTheme.GOLD)
	return label