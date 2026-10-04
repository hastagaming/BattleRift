extends Node

signal balance_changed(currency: String, balance: int)
signal purchase_completed(item_id: String)

const CR := "cr"
const BR := "br"
const CURRENCIES: Array[String] = ["cr", "br"]


func balance(currency: String) -> int:
	if not PlayerData.is_signed_in or currency not in CURRENCIES:
		return 0
	return int(PlayerData.data["currencies"][currency])


func can_afford(currency: String, amount: int) -> bool:
	return amount >= 0 and balance(currency) >= amount


func _set_balance(currency: String, value: int) -> void:
	PlayerData.data["currencies"][currency] = value
	PlayerData.save()
	balance_changed.emit(currency, value)


# Local (debug) accounts only. On server accounts CR is credited by the server.
func credit_cr(amount: int, _reason: String) -> bool:
	if not PlayerData.is_signed_in or PlayerData.remote or amount <= 0:
		return false
	_set_balance(CR, balance(CR) + amount)
	return true


# Local (debug) accounts only. On server accounts BR is granted by the server.
func apply_server_br_grant(amount: int, receipt_id: String) -> bool:
	if not PlayerData.is_signed_in or PlayerData.remote or amount <= 0 or receipt_id.is_empty():
		return false
	var receipts: Array = PlayerData.data["economy"]["receipts"]
	if receipt_id in receipts:
		return false
	receipts.append(receipt_id)
	_set_balance(BR, balance(BR) + amount)
	return true


func purchase(item: Dictionary) -> Dictionary:
	if not PlayerData.is_signed_in:
		return {"ok": false, "error": "Not signed in"}
	if PlayerData.remote:
		return await _purchase_remote(String(item.get("id", "")))
	for key in ["id", "category", "currency", "price"]:
		if not item.has(key):
			return {"ok": false, "error": "Invalid item"}
	var item_id := String(item["id"])
	var category := String(item["category"])
	var currency := String(item["currency"])
	var price := int(item["price"])
	if currency not in CURRENCIES or price < 0:
		return {"ok": false, "error": "Invalid price"}
	if not PlayerData.data["inventory"].has(category):
		return {"ok": false, "error": "Invalid category"}
	if PlayerData.owns(category, item_id):
		return {"ok": false, "error": "Already owned"}
	if not can_afford(currency, price):
		return {"ok": false, "error": "Not enough %s" % currency.to_upper()}
	_set_balance(currency, balance(currency) - price)
	PlayerData.grant_item(category, item_id)
	purchase_completed.emit(item_id)
	return {"ok": true, "error": ""}


func _purchase_remote(item_id: String) -> Dictionary:
	if item_id.is_empty():
		return {"ok": false, "error": "Invalid item"}
	var result: Dictionary = await Supabase.rpc("purchase_item", {"p_item_id": item_id})
	if not bool(result["ok"]):
		return {"ok": false, "error": String(result["error"])}
	if not result["body"] is Dictionary:
		return {"ok": false, "error": "Server returned invalid player data"}
	PlayerData.apply_remote_snapshot(result["body"])
	balance_changed.emit(CR, balance(CR))
	balance_changed.emit(BR, balance(BR))
	purchase_completed.emit(item_id)
	return {"ok": true, "error": ""}