extends ScreenFrame

var _slot: String = "skin"
var _preview: CharacterPreview
var _list: VBoxContainer
var _queued: bool = false


func _init() -> void:
	title_text = Loc.t("customize.title")


func _build() -> void:
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	body.add_child(split)
	_preview = CharacterPreview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.size_flags_stretch_ratio = 0.8
	split.add_child(_preview)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.2
	right.add_theme_constant_override("separation", 10)
	split.add_child(right)
	var entries: Array = []
	for slot in ItemDb.SLOT_ORDER:
		entries.append([slot, ItemDb.slot_label(slot)])
	right.add_child(make_tabs(entries, _slot, _on_slot))
	var scroll := make_list_scroll()
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	right.add_child(scroll)
	var emote_button := Button.new()
	emote_button.text = Loc.t("customize.play_emote")
	emote_button.custom_minimum_size = Vector2(0.0, 52.0)
	emote_button.pressed.connect(_preview.play_emote)
	right.add_child(emote_button)
	PlayerData.inventory_changed.connect(_queue_render)
	PlayerData.equipment_changed.connect(_on_equipment_changed)
	_render()


func _on_slot(slot: String) -> void:
	_slot = slot
	_render()


func _on_equipment_changed(_changed_slot: String) -> void:
	_preview.refresh()
	_queue_render()


func _queue_render() -> void:
	if _queued:
		return
	_queued = true
	_render.call_deferred()


func _render() -> void:
	_queued = false
	if not PlayerData.is_signed_in:
		return
	clear_children(_list)
	var category := String(PlayerData.SLOT_CATEGORY[_slot])
	var equipped_id := String(PlayerData.data["equipped"].get(_slot, ""))
	var owned: Array = PlayerData.data["inventory"].get(category, [])
	if _slot == "pet":
		_render_pets(owned, equipped_id)
		return
	var choices: Array[String] = []
	for entry in owned:
		if ItemDb.slot_of(category, String(entry)) == _slot:
			choices.append(String(entry))
	if category == "emote":
		# The communication emotes belong to everyone, even if the inventory has not listed them.
		choices.clear()
		for emote_id in CharacterModel.EMOTES:
			if emote_id in owned or emote_id in CharacterModel.STARTER_EMOTES:
				choices.append(emote_id)
	if choices.is_empty():
		_list.add_child(empty_note(Loc.t("customize.nothing"), Loc.t("customize.open_shop"), Router.SHOP))
		return
	if _slot not in PlayerData.REQUIRED_SLOTS:
		_list.add_child(_make_choice("", equipped_id.is_empty()))
	for item_id in choices:
		_list.add_child(_make_choice(item_id, item_id == equipped_id))


func _render_pets(owned: Array, equipped_id: String) -> void:
	var progress := PetLogic.collection_progress(owned)
	var heading := Label.new()
	heading.text = Loc.t("customize.pets_collected", {"owned": int(progress["owned"]), "total": int(progress["total"])})
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	_list.add_child(heading)
	var bar := ProgressBar.new()
	bar.max_value = float(progress["total"])
	bar.value = float(progress["owned"])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 12.0)
	_list.add_child(bar)
	if _slot not in PlayerData.REQUIRED_SLOTS:
		_list.add_child(_make_choice("", equipped_id.is_empty()))
	for pet_id in PetLogic.collection_order(owned):
		_list.add_child(_pet_card(pet_id, pet_id in owned, pet_id == equipped_id))


func _pet_card(pet_id: String, is_owned: bool, is_equipped: bool) -> PanelContainer:
	var pet := PetDb.get_pet(pet_id)
	var color: Color = pet["color"] if is_owned else UiTheme.MUTED
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	row.add_child(UiTheme.orb(String(pet["name"]).substr(0, 1), color))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	var title_row := HFlowContainer.new()
	title_row.add_theme_constant_override("h_separation", 8)
	var title := Label.new()
	title.text = String(pet["name"])
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", color)
	title_row.add_child(title)
	title_row.add_child(UiTheme.chip(PetLogic.kind_label(pet), color))
	if is_equipped:
		title_row.add_child(UiTheme.chip(Loc.t("customize.equipped_tag"), UiTheme.ACCENT))
	if not is_owned:
		title_row.add_child(UiTheme.chip(Loc.t("customize.locked"), UiTheme.DANGER))
	text.add_child(title_row)
	var ability := Label.new()
	ability.text = "%s: %s" % [PetLogic.ability_name(pet_id), PetLogic.description(pet_id)]
	ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability.add_theme_font_size_override("font_size", 17)
	ability.add_theme_color_override("font_color", UiTheme.MUTED)
	text.add_child(ability)
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 6)
	stats.add_theme_constant_override("v_separation", 4)
	for fact in PetLogic.stat_chips(pet):
		stats.add_child(UiTheme.chip(fact, UiTheme.SURFACE_HOVER, UiTheme.TEXT))
	text.add_child(stats)
	row.add_child(text)
	var button := Button.new()
	button.custom_minimum_size = Vector2(150.0, 52.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_owned:
		button.text = Loc.t("customize.selected") if is_equipped else Loc.t("customize.select")
		button.disabled = is_equipped
		button.pressed.connect(_on_pick.bind(pet_id))
	else:
		button.text = Loc.t("customize.get_in_shop")
		button.pressed.connect(Router.go.bind(Router.SHOP))
	row.add_child(button)
	if not is_owned:
		panel.modulate = Color(1.0, 1.0, 1.0, 0.7)
	return panel


func _make_choice(item_id: String, selected: bool) -> PanelContainer:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150.0, 52.0)
	button.text = Loc.t("customize.selected") if selected else Loc.t("customize.select")
	button.disabled = selected
	button.pressed.connect(_on_pick.bind(item_id))
	if item_id.is_empty():
		return build_row(Loc.t("customize.none"), Loc.t("customize.none_desc"), UiTheme.MUTED, button)
	var desc := ItemDb.description(item_id)
	return build_row(ItemDb.display_name(item_id), desc, ItemDb.color_of(item_id), button)


func _on_pick(item_id: String) -> void:
	if item_id.is_empty():
		if PlayerData.unequip(_slot):
			notify(Loc.t("customize.slot_cleared"))
		else:
			notify(Loc.t("customize.slot_required"), true)
		return
	if PlayerData.equip(_slot, item_id):
		notify(Loc.t("customize.equipped", {"item": ItemDb.display_name(item_id)}))
	else:
		notify(Loc.t("customize.equip_failed"), true)