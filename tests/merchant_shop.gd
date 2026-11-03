extends SceneTree

const SHOP_SCRIPT := preload("res://scripts/merchant_shop.gd")

func _initialize() -> void:
	call_deferred("_run")

func _has_offer(offers_list: Array[Dictionary], item_id: String) -> bool:
	for offer in offers_list:
		if str(offer.get("id", "")) == item_id:
			return true
	return false

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("MERCHANT SHOP FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var shop: MerchantShop = SHOP_SCRIPT.new()
	if not _verify(shop.get_price("health_potion", 0) == 18, "base health potion price"):
		return
	if not _verify(shop.get_price("health_potion", 20) == 16, "10 percent village discount"):
		return
	if not _verify(shop.get_price("health_potion", 50) == 15, "15 percent village discount"):
		return
	if not _verify(shop.get_price("health_potion", 80) == 14, "20 percent village discount"):
		return
	if not _verify(shop.get_price("unknown_item", 100) == -1, "unknown items are not sold"):
		return
	if not _verify(not _has_offer(shop.get_offers(0, 19), "mana_amulet"), "Brann stock remains locked below 20 trust"):
		return
	if not _verify(_has_offer(shop.get_offers(0, 20), "mana_amulet"), "mana amulet unlocks at 20 Brann trust"):
		return
	if not _verify(not _has_offer(shop.get_offers(0, 49), "starlight_essence"), "star essence remains locked below 50 trust"):
		return
	if not _verify(_has_offer(shop.get_offers(0, 50), "starlight_essence"), "star essence unlocks at 50 trust"):
		return
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.player.add_gold(100)
	game.relationships.adjust("elder", 20)
	var price: int = shop.get_price("mana_potion", 20)
	var before_gold: int = game.player.gold
	var bought: Dictionary = shop.purchase(game.player, "mana_potion", 20)
	if not _verify(bool(bought.get("success", false)), "valid purchase succeeds"):
		return
	if not _verify(game.player.gold == before_gold - price, "gold is deducted exactly once"):
		return
	if not _verify(int(game.player.inventory.get("mana_potion", 0)) == 1, "purchased item enters inventory"):
		return
	game.player.gold = 0
	var before_inventory: int = int(game.player.inventory.get("health_potion", 0))
	var rejected: Dictionary = shop.purchase(game.player, "health_potion", 20)
	if not _verify(not bool(rejected.get("success", false)), "purchase without enough gold is rejected"):
		return
	if not _verify(int(game.player.inventory.get("health_potion", 0)) == before_inventory, "failed purchase does not add items"):
		return
	game.player.add_gold(100)
	game.relationships.adjust("bran", 50)
	game.player.add_item("mana_potion", 3)
	var barter_before_gold: int = game.player.gold
	var barter: Dictionary = shop.purchase(game.player, "starlight_essence", 0, 50)
	if not _verify(bool(barter.get("success", false)), "barter exchange succeeds at required trust"):
		return
	if not _verify(int(game.player.inventory.get("mana_potion", 0)) == 1, "barter consumes exactly three mana potions"):
		return
	if not _verify(int(game.player.inventory.get("starlight_essence", 0)) == 1 and game.player.gold == barter_before_gold, "barter grants essence without spending gold"):
		return
	var locked_purchase: Dictionary = shop.purchase(game.player, "starlight_essence", 0, 49)
	if not _verify(not bool(locked_purchase.get("success", false)), "barter cannot bypass trust requirement"):
		return
	game.relationships.adjust("bran", -50)
	game._on_merchant_interacted(null)
	if not _verify(game.hud.dialogue_visible and game.hud.dialogue_speaker_label.text.contains("Торговец Бран"), "merchant interaction opens the shop dialogue"):
		return
	if not _verify(game.hud.dialogue_choices_container.get_child_count() == shop.get_offers(20).size() + 1, "shop displays every offer and a close option"):
		return
	var before_health_potions: int = int(game.player.inventory.get("health_potion", 0))
	game._on_dialogue_choice_selected("merchant_buy:health_potion")
	if not _verify(int(game.player.inventory.get("health_potion", 0)) == before_health_potions + 1, "dialogue purchase dispatches to the merchant"):
		return
	if not _verify(game.hud.dialogue_visible, "shop stays open after a purchase"):
		return
	game._on_dialogue_choice_selected("merchant_close")
	if not _verify(not game.hud.dialogue_visible and game.player.is_physics_processing(), "close option resumes player control"):
		return
	print("MERCHANT SHOP OK: catalog, trust discounts, purchases and dialogue flow")
	quit(0)
