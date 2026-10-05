extends ScreenFrame

const CATALOG_PATH := "/rest/v1/shop_items?select=id,category,currency,price&active=eq.true&order=price.asc"

var _catalog: Array = []
var _category: String = "skin"
var _list: VBoxContainer
var _status: Label
var _busy: bool = false
var _loaded: bool = false


func _init() -> void:
	title_text = "Shop"


func _build() -> void:
	var entries: Array = []
	for category in ItemDb.CATEGORY_ORDER:
		entries.append([category, String(ItemDb.CATEGORY_LABELS[category])])
	body.add_child(make_tabs(entries, _category, _on_category))
	_status = Label.new()
	_status.add_theme_color_override("font_color", UiTheme.MUTED)
	body.add_child(_status)
	var scroll := make_list_scroll()
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	body.add_child(scroll)
	PlayerData.inventory_changed.connect(_render)
	_load_catalog()


func _load_catalog() -> void:
	_status.text = "Loading shop..."
	clear_children(_list)
	if PlayerData.remote:
		var result: Dictionary = await Supabase.request(HTTPClient.METHOD_GET, CATALOG_PATH)
		if not is_inside_tree():
			return
		if not bool(result["ok"]) or not result["body"] is Array:
			_status.text = ""
			_show_load_error(friendly_error(String(result["error"])))
			return
		_catalog = result["body"]
	else:
		_catalog = ItemDb.local_catalog()
	_loaded = true
	_status.text = ""
	_render()


func _show_load_error(message: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = "Could not load the shop. %s" % message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", UiTheme.DANGER)
	box.add_child(label)
	var retry := Button.new()
	retry.text = "Retry"
	retry.custom_minimum_size = Vector2(0.0, 52.0)
	retry.pressed.connect(_load_catalog)
	box.add_child(retry)
	_list.add_child(box)


func _on_category(category: String) -> void:
	_category = category
	_render()


func _sort_rows(a: Dictionary, b: Dictionary) -> bool:
	var owned_a := PlayerData.owns(String(a["category"]), String(a["id"]))
	var owned_b := PlayerData.owns(String(b["category"]), String(b["id"]))
	if owned_a != owned_b:
		return not owned_a
	return int(a["price"]) < int(b["price"])


func _render() -> void:
	if not _loaded:
		return
	clear_children(_list)
	var rows: Array = []
	for entry in _catalog:
		var item: Dictionary = entry
		if String(item["category"]) == _category:
			rows.append(item)
	rows.sort_custom(_sort_rows)
	if rows.is_empty():
		_list.add_child(empty_note("Nothing for sale in this category yet."))
		return
	for item in rows:
		_list.add_child(_make_item_row(item))


func _make_item_row(item: Dictionary) -> PanelContainer:
	var item_id := String(item["id"])
	var category := String(item["category"])
	var currency := String(item["currency"])
	var price := int(item["price"])
	var owned := PlayerData.owns(category, item_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(150.0, 52.0)
	if owned:
		button.text = "Owned"
		button.disabled = true
	else:
		button.text = "%d %s" % [price, currency.to_upper()]
		button.disabled = _busy or not Economy.can_afford(currency, price)
		button.add_theme_color_override("font_color", UiTheme.GOLD if currency == "cr" else UiTheme.ACCENT)
		button.pressed.connect(_on_buy.bind(item))
	var desc := String(ItemDb.info(item_id).get("desc", ""))
	var subtitle := desc if currency == "cr" else "%s  |  Premium" % desc
	return build_row(ItemDb.display_name(item_id), subtitle, ItemDb.color_of(item_id), button)


func _on_buy(item: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	_render()
	var result: Dictionary = await Economy.purchase(item)
	_busy = false
	if not is_inside_tree():
		return
	if bool(result["ok"]):
		notify("Purchased %s" % ItemDb.display_name(String(item["id"])))
	else:
		notify(friendly_error(String(result["error"])), true)
	_render()