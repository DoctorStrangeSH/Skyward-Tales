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

func get_offers(reputation: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in offers:
		var definition: Variant = offers[item_id]
		if not definition is Dictionary:
			continue
		var price := get_price(str(item_id), reputation)
		if price <= 0:
			continue
		result.append({"id": str(item_id), "name": str(definition.get("name", item_id)), "description": str(definition.get("description", "")), "price": price})
	return result

func purchase(player: PlayerCharacter, item_id: String, reputation: int = 0) -> Dictionary:
	if player == null:
		return {"success": false, "message": "Покупка сейчас недоступна."}
	if not offers.has(item_id):
		return {"success": false, "message": "Такого товара нет в каталоге."}
	var price := get_price(item_id, reputation)
	if price <= 0:
		return {"success": false, "message": "Цена товара указана неверно."}
	if player.gold < price:
		return {"success": false, "message": "Не хватает золота: нужно %d." % price}
	player.add_gold(-price)
	player.add_item(item_id, 1)
	return {"success": true, "item_id": item_id, "name": str(offers[item_id].get("name", item_id)), "price": price}
