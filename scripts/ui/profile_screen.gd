extends ScreenFrame

const CONTEXT_LABELS := {
	"1v1": "1v1",
	"2v2": "2v2",
	"3v3": "3v3",
	"battle_royal": "Battle Royal",
}
const PROVIDER_LABELS := {
	"google": "Google",
	"github": "GitHub",
	"facebook": "Facebook",
	"dev": "Developer (local)",
}

var _preview: CharacterPreview
var _info: VBoxContainer
var _queued: bool = false


func _init() -> void:
	title_text = "Profile"


func _build() -> void:
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	body.add_child(split)
	_preview = CharacterPreview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.size_flags_stretch_ratio = 0.7
	split.add_child(_preview)
	var scroll := make_list_scroll()
	scroll.size_flags_stretch_ratio = 1.3
	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override("separation", 12)
	scroll.add_child(_info)
	split.add_child(scroll)
	PlayerData.data_changed.connect(_queue_render)
	PlayerData.equipment_changed.connect(_on_equipment_changed)
	_render()


func _on_equipment_changed(_slot: String) -> void:
	_preview.refresh()
	_queue_render()


func _queue_render() -> void:
	if _queued:
		return
	_queued = true
	_render.call_deferred()


func _card(heading: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var label := Label.new()
	label.text = heading
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", UiTheme.MUTED)
	column.add_child(label)
	_info.add_child(panel)
	return column


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	return grid


func _pair(grid: GridContainer, key: String, value: String) -> void:
	var key_label := Label.new()
	key_label.text = key
	key_label.add_theme_color_override("font_color", UiTheme.MUTED)
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(key_label)
	var value_label := Label.new()
	value_label.text = value
	grid.add_child(value_label)


func _render() -> void:
	_queued = false
	if not PlayerData.is_signed_in:
		return
	clear_children(_info)
	var data: Dictionary = PlayerData.data
	var profile: Dictionary = data["profile"]
	var level := int(profile["level"])
	var xp := int(profile["xp"])
	var provider := String(data["account"].get("provider", ""))
	var identity := _card("PLAYER")
	var name_label := Label.new()
	name_label.text = String(profile["name"])
	name_label.add_theme_font_size_override("font_size", 30)
	identity.add_child(name_label)
	var sub_label := Label.new()
	sub_label.text = "Level %d  |  %s" % [level, String(PROVIDER_LABELS.get(provider, provider.capitalize()))]
	sub_label.add_theme_color_override("font_color", UiTheme.MUTED)
	identity.add_child(sub_label)
	var xp_bar := ProgressBar.new()
	xp_bar.max_value = float(PlayerData.xp_for_next_level(level))
	xp_bar.value = float(xp)
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0.0, 12.0)
	identity.add_child(xp_bar)
	var xp_label := Label.new()
	xp_label.text = "XP %d / %d" % [xp, PlayerData.xp_for_next_level(level)]
	xp_label.add_theme_font_size_override("font_size", 17)
	xp_label.add_theme_color_override("font_color", UiTheme.MUTED)
	identity.add_child(xp_label)
	var clan_id := String(profile.get("clan_id", ""))
	var clan_label := Label.new()
	clan_label.text = "Clan: %s" % ("No clan" if clan_id.is_empty() else clan_id)
	identity.add_child(clan_label)
	_render_ranks(data)
	_render_stats(data)
	_render_equipped(data)


func _render_ranks(data: Dictionary) -> void:
	var card := _card("RANK")
	var ratings: Dictionary = data["ratings"]
	for context in RankSystem.CONTEXTS:
		var mmr := int(ratings.get(context, RankSystem.DEFAULT_MMR))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var context_label := Label.new()
		context_label.text = String(CONTEXT_LABELS.get(context, context))
		context_label.custom_minimum_size = Vector2(120.0, 0.0)
		row.add_child(context_label)
		var tier_label := Label.new()
		tier_label.text = RankSystem.tier_name_for_mmr(mmr)
		tier_label.custom_minimum_size = Vector2(100.0, 0.0)
		tier_label.add_theme_color_override("font_color", UiTheme.GOLD)
		row.add_child(tier_label)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = RankSystem.tier_progress(mmr)
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(0.0, 10.0)
		row.add_child(bar)
		var mmr_label := Label.new()
		mmr_label.text = "MMR %d" % mmr
		mmr_label.add_theme_font_size_override("font_size", 17)
		mmr_label.add_theme_color_override("font_color", UiTheme.MUTED)
		row.add_child(mmr_label)
		card.add_child(row)


func _render_stats(data: Dictionary) -> void:
	var stats: Dictionary = data["stats"]
	var matches := int(stats.get("matches", 0))
	var wins := int(stats.get("wins", 0))
	var card := _card("STATISTICS")
	var grid := _grid()
	_pair(grid, "Matches", str(matches))
	_pair(grid, "Wins", str(wins))
	_pair(grid, "Losses", str(int(stats.get("losses", 0))))
	_pair(grid, "Draws", str(int(stats.get("draws", 0))))
	_pair(grid, "Eliminations", str(int(stats.get("eliminations", 0))))
	_pair(grid, "Win rate", "-" if matches == 0 else "%d%%" % roundi(100.0 * float(wins) / float(matches)))
	card.add_child(grid)


func _render_equipped(data: Dictionary) -> void:
	var equipped: Dictionary = data["equipped"]
	var card := _card("EQUIPPED")
	var grid := _grid()
	for slot in ItemDb.SLOT_ORDER:
		var item_id := String(equipped.get(slot, ""))
		_pair(grid, String(ItemDb.SLOT_LABELS[slot]), "None" if item_id.is_empty() else ItemDb.display_name(item_id))
	card.add_child(grid)