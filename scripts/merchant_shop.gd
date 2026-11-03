extends RefCounted
class_name MerchantShop

const DATA_PATH := "res://data/merchant_stock.json"

var offers: Dictionary = {}
var discount_tiers: Array = []

func _init() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть каталог торговца: " + DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Каталог торговца должен содержать объект")
		return
	var raw_offers: Variant = parsed.get("offers", {})
	var raw_tiers: Variant = parsed.get("discount_tiers", [])
	if raw_offers is Dictionary:
		offers = raw_offers.duplicate(true)
	if raw_tiers is Array:
		discount_tiers = raw_tiers.duplicate(true)

func get_discount(reputation: int) -> float:
	var discount := 0.0
	for tier in discount_tiers:
		if not tier is Dictionary:
			continue
		if reputation >= int(tier.get("trust", 0)):
			discount = maxf(discount, clampf(float(tier.get("discount", 0.0)), 0.0, 0.5))
	return discount

func get_discount_percent(reputation: int) -> int:
	return roundi(get_discount(reputation) * 100.0)

func get_price(item_id: String, reputation: int = 0) -> int:
	if not offers.has(item_id) or not offers[item_id] is Dictionary:
		return -1
	var base_price := int(offers[item_id].get("base_price", 0))
	if base_price <= 0:
		return -1
	return maxi(1, floori(float(base_price) * (1.0 - get_discount(reputation))))

func get_offers(reputation: int = 0, bran_trust: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in offers:
		var definition: Variant = offers[item_id]
		if not definition is Dictionary:
			continue
		if bran_trust < int(definition.get("required_bran_trust", 0)):
			continue
		var price := get_price(str(item_id), reputation)
		var trade: Variant = definition.get("trade", {})
		if trade is Dictionary and not trade.is_empty():
			result.append({
				"id": str(item_id),
				"name": str(definition.get("name", item_id)),
				"description": str(definition.get("description", "")),
				"trade_currency": str(trade.get("item_id", "")),
				"trade_amount": maxi(1, int(trade.get("amount", 1))),
				"required_bran_trust": int(definition.get("required_bran_trust", 0))
			})
		elif price > 0:
			result.append({
				"id": str(item_id),
				"name": str(definition.get("name", item_id)),
				"description": str(definition.get("description", "")),
				"price": price,
				"required_bran_trust": int(definition.get("required_bran_trust", 0))
			})
	return result

func purchase(player: PlayerCharacter, item_id: String, reputation: int = 0, bran_trust: int = 0) -> Dictionary:
	if player == null:
		return {"success": false, "message": "Покупка сейчас недоступна."}
	if not offers.has(item_id):
		return {"success": false, "message": "Такого товара нет в каталоге."}
	var definition: Dictionary = offers[item_id]
	if bran_trust < int(definition.get("required_bran_trust", 0)):
		return {"success": false, "message": "Бран пока не готов предложить этот товар."}
	var trade: Variant = definition.get("trade", {})
	if trade is Dictionary and not trade.is_empty():
		var currency_id := str(trade.get("item_id", ""))
		var amount := maxi(1, int(trade.get("amount", 1)))
		if currency_id.is_empty():
			return {"success": false, "message": "Условия обмена указаны неверно."}
		var owned := int(player.inventory.get(currency_id, 0))
		if owned < amount:
			return {"success": false, "message": "Для обмена нужно %d ед. ресурса: %s." % [amount, currency_id]}
		player.inventory[currency_id] = owned - amount
		if int(player.inventory[currency_id]) <= 0:
			player.inventory.erase(currency_id)
		player.add_item(item_id, 1)
		return {"success": true, "item_id": item_id, "name": str(definition.get("name", item_id)), "trade_currency": currency_id, "trade_amount": amount}
	var price := get_price(item_id, reputation)
	if price <= 0:
		return {"success": false, "message": "Цена товара указана неверно."}
	if player.gold < price:
		return {"success": false, "message": "Не хватает золота: нужно %d." % price}
	player.add_gold(-price)
	player.add_item(item_id, 1)
	return {"success": true, "item_id": item_id, "name": str(definition.get("name", item_id)), "price": price}
