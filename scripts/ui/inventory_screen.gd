extends ScreenFrame

var _category: String = "skin"
var _list: VBoxContainer
var _queued: bool = false


func _init() -> void:
	title_text = "Inventory"


func _build() -> void:
	var entries: Array = []
	for category in ItemDb.CATEGORY_ORDER:
		entries.append([category, String(ItemDb.CATEGORY_LABELS[category])])
	body.add_child(make_tabs(entries, _category, _on_category))
	var scroll := make_list_scroll()
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	body.add_child(scroll)
	PlayerData.inventory_changed.connect(_queue_render)
	PlayerData.equipment_changed.connect(_on_equipment_changed)
	_render()


func _on_category(category: String) -> void:
	_category = category
	_render()


func _on_equipment_changed(_slot: String) -> void:
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
	var owned: Array = PlayerData.data["inventory"].get(_category, [])
	if owned.is_empty():
		var label := String(ItemDb.CATEGORY_LABELS[_category]).to_lower()
		_list.add_child(empty_note("You do not own any %s yet." % label, "Open Shop", Router.SHOP))
		return
	for entry in owned:
		var item_id := String(entry)
		var slot := ItemDb.slot_of(_category, item_id)
		if slot.is_empty():
			continue
		_list.add_child(_make_row(item_id, slot))


func _make_row(item_id: String, slot: String) -> PanelContainer:
	var equipped := String(PlayerData.data["equipped"].get(slot, "")) == item_id
	var button := Button.new()
	button.custom_minimum_size = Vector2(150.0, 52.0)
	if equipped:
		if slot in PlayerData.REQUIRED_SLOTS:
			button.text = "Equipped"
			button.disabled = true
		else:
			button.text = "Unequip"
			button.pressed.connect(_on_unequip.bind(slot))
	else:
		button.text = "Equip"
		button.pressed.connect(_on_equip.bind(slot, item_id))
	var subtitle := String(ItemDb.SLOT_LABELS.get(slot, slot))
	if equipped:
		subtitle += "  |  Equipped"
	return build_row(ItemDb.display_name(item_id), subtitle, ItemDb.color_of(item_id), button)


func _on_equip(slot: String, item_id: String) -> void:
	if PlayerData.equip(slot, item_id):
		notify("Equipped %s" % ItemDb.display_name(item_id))
	else:
		notify("Could not equip this item", true)


func _on_unequip(slot: String) -> void:
	if PlayerData.unequip(slot):
		notify("Removed from %s slot" % String(ItemDb.SLOT_LABELS.get(slot, slot)).to_lower())
	else:
		notify("This slot cannot be empty", true)