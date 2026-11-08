extends SceneTree

## Bran buys materials and spare gear, never equipped items, and pays more
## to trusted friends.

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("MERCHANT SELLING TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var shop := game.merchant_shop
	var player := game.player
	if not _verify(shop.get_sell_offers(player).is_empty(), "nothing to sell at the start"):
		return
	player.add_item("wolf_pelt", 2)
	player.add_item("leather_armor")
	player.equip_item("leather_armor")
	var offers := shop.get_sell_offers(player)
	if not _verify(offers.size() == 1 and offers[0]["id"] == "wolf_pelt" and offers[0]["count"] == 2, "only unequipped items are offered"):
		return
	var gold := player.gold
	var result := shop.sell(player, "wolf_pelt")
	if not _verify(bool(result["success"]) and player.gold == gold + 8 and int(player.inventory.get("wolf_pelt", 0)) == 1, "selling a pelt pays 8 gold"):
		return
	if not _verify(not bool(shop.sell(player, "leather_armor")["success"]), "equipped armour cannot be sold"):
		return
	if not _verify(not bool(shop.sell(player, "crystal_lens")["success"]), "unknown items are refused"):
		return
	if not _verify(shop.get_sell_price("wolf_pelt", 20) == 9, "trusted friends get 10% more"):
		return

	# Through the dialogue.
	game._on_merchant_interacted(null)
	var has_sell := false
	for button in game.hud.dialogue_choices_container.get_children():
		if button.text.contains("Продать вещи"):
			has_sell = true
	if not _verify(has_sell, "merchant menu offers selling"):
		return
	game._on_dialogue_choice_selected("merchant_sell:menu")
	await process_frame
	gold = player.gold
	game._on_dialogue_choice_selected("merchant_sell:wolf_pelt")
	if not _verify(player.gold == gold + 8 and not player.inventory.has("wolf_pelt"), "selling via dialogue works"):
		return
	game._on_dialogue_choice_selected("merchant_sell:back")
	if not _verify(game.hud.dialogue_visible and game.hud.dialogue_label.text.contains("лавку Брана"), "back returns to the shop"):
		return
	print("MERCHANT SELLING OK: offers, prices, equipped protection, trust bonus, dialogue")
	quit(0)
