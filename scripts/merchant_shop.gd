extends RefCounted
class_name MerchantShop

const DATA_PATH := "res://data/merchant_stock.json"

var offers: Dictionary = {}
var discount_tiers: Array = []
var sell_prices: Dictionary = {}
var sell_trust_bonus: Dictionary = {}

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
	var raw_sell: Variant = parsed.get("sell_prices", {})
	if raw_sell is Dictionary:
		sell_prices = raw_sell.duplicate(true)
	var raw_bonus: Variant = parsed.get("sell_trust_bonus", {})
	if raw_bonus is Dictionary:
		sell_trust_bonus = raw_bonus.duplicate(true)

# --- Selling ---------------------------------------------------------------

## How much Bran pays for one item, or -1 if he does not buy it.
func get_sell_price(item_id: String, bran_trust: int = 0, player: PlayerCharacter = null) -> int:
	var price: float
	if sell_prices.has(item_id):
		price = float(sell_prices[item_id])
	elif player != null and player.get_item_definition(item_id).has("value"):
		price = float(player.get_item_definition(item_id)["value"])  # rolled loot
	else:
		return -1
	if bran_trust >= int(sell_trust_bonus.get("trust", 999)):
		price *= 1.0 + float(sell_trust_bonus.get("bonus", 0.0))
	return maxi(1, roundi(price))

## Copies the player can sell: equipped items keep one copy on the hero.
func sellable_count(player: PlayerCharacter, item_id: String) -> int:
	var count := int(player.inventory.get(item_id, 0))
	if item_id in player.equipment.values():
		count -= 1
	return maxi(0, count)

func get_sell_offers(player: PlayerCharacter, bran_trust: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = sell_prices.keys()
	for item_id in player.inventory:
		if not ids.has(item_id) and player.get_item_definition(str(item_id)).has("value"):
			ids.append(item_id)
	for item_id in ids:
		var count := sellable_count(player, str(item_id))
		if count <= 0:
			continue
		result.append({"id": str(item_id), "name": player.get_item_name(str(item_id)), "price": get_sell_price(str(item_id), bran_trust, player), "count": count})
	return result

func sell(player: PlayerCharacter, item_id: String, bran_trust: int = 0) -> Dictionary:
	var price := get_sell_price(item_id, bran_trust, player)
	if price < 0:
		return {"success": false, "message": "Бран такое не покупает."}
	if sellable_count(player, item_id) <= 0 or not player.remove_item(item_id, 1):
		return {"success": false, "message": "Нечего продать: надетые вещи не продаются."}
	player.add_gold(price)
	return {"success": true, "price": price, "name": player.get_item_name(item_id)}

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
