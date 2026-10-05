extends ScreenFrame

var _slot: String = "skin"
var _preview: CharacterPreview
var _list: VBoxContainer
var _queued: bool = false


func _init() -> void:
	title_text = "Customize"


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
		entries.append([slot, String(ItemDb.SLOT_LABELS[slot])])
	right.add_child(make_tabs(entries, _slot, _on_slot))
	var scroll := make_list_scroll()
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	right.add_child(scroll)
	var emote_button := Button.new()
	emote_button.text = "Play Emote"
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
	var choices: Array[String] = []
	for entry in PlayerData.data["inventory"].get(category, []):
		if ItemDb.slot_of(category, String(entry)) == _slot:
			choices.append(String(entry))
	if choices.is_empty():
		_list.add_child(empty_note("Nothing to equip in this slot yet.", "Open Shop", Router.SHOP))
		return
	if _slot not in PlayerData.REQUIRED_SLOTS:
		_list.add_child(_make_choice("", equipped_id.is_empty()))
	for item_id in choices:
		_list.add_child(_make_choice(item_id, item_id == equipped_id))


func _make_choice(item_id: String, selected: bool) -> PanelContainer:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150.0, 52.0)
	button.text = "Selected" if selected else "Select"
	button.disabled = selected
	button.pressed.connect(_on_pick.bind(item_id))
	if item_id.is_empty():
		return build_row("None", "Leave this slot empty", UiTheme.MUTED, button)
	var desc := String(ItemDb.info(item_id).get("desc", ""))
	return build_row(ItemDb.display_name(item_id), desc, ItemDb.color_of(item_id), button)


func _on_pick(item_id: String) -> void:
	if item_id.is_empty():
		if PlayerData.unequip(_slot):
			notify("Slot cleared")
		else:
			notify("This slot cannot be empty", true)
		return
	if PlayerData.equip(_slot, item_id):
		notify("Equipped %s" % ItemDb.display_name(item_id))
	else:
		notify("Could not equip this item", true)