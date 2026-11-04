extends SceneTree

## Rolled equipment and characteristics: rarity/affix rules, stats from
## level and gear, effects on damage/regen/agility, selling, save/load.

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("RANDOM LOOT TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var player := game.player
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# Rarity decides the number of affixes; definitions are complete.
	var counts := {"common": 1, "uncommon": 2, "rare": 3, "epic": 4}
	for rarity in counts:
		var item := LootGenerator.generate(rng, 3, rarity)
		var lines := str(item["description"]).split(", ")
		if not _verify(lines.size() == counts[rarity] and item["rarity"] == rarity, "%s item has %d affixes" % [rarity, counts[rarity]]):
			return
		if not _verify(not str(item["slot"]).is_empty() and str(item["name"]).contains(" ") and int(item["value"]) > 0, "item has slot, name and value"):
			return
	for i in range(30):
		if not _verify(LootGenerator.roll_rarity(rng, "rare") in ["rare", "epic", "legendary"], "boss drops are at least rare"):
			return

	# Same seed, same item.
	var a := RandomNumberGenerator.new()
	a.seed = 99
	var b := RandomNumberGenerator.new()
	b.seed = 99
	if not _verify(LootGenerator.generate(a, 2) == LootGenerator.generate(b, 2), "generation is deterministic for a seed"):
		return

	# Characteristics grow with level.
	if not _verify(player.get_stat("power") == 0 and is_equal_approx(player.get_spell_power_multiplier(), 1.0), "level 1 starts at zero"):
		return
	player.level = 4
	if not _verify(player.get_stat("power") == 3 and player.get_stat("agility") == 3, "+1 per level"):
		return

	# A rolled weapon with power and agility.
	var weapon := {"slot": "weapon", "rarity": "rare", "name": "Жезл силы", "description": "", "power": 5, "agility": 10, "will": 4, "value": 50, "icon": "apprentice_staff"}
	var item_id := player.register_generated_item(weapon)
	player.add_item(item_id)
	var comparison := player.get_equipment_comparison(item_id)
	var labels: Array = []
	for stat in comparison.get("stats", []):
		labels.append(stat["label"])
	if not _verify("Сила магии" in labels and "Ловкость" in labels, "comparison shows characteristics"):
		return
	var regen_before := player.get_mana_regen()
	if not _verify(player.equip_item(item_id), "rolled weapon equips"):
		return
	if not _verify(player.get_stat("power") == 8 and is_equal_approx(player.get_spell_power_multiplier(), 1.16), "power adds 2% damage per point"):
		return
	if not _verify(player.get_mana_regen() > regen_before and player.get_dodge_cooldown() < player.dodge_cooldown and player.get_move_speed() > player.move_speed, "will and agility take effect"):
		return
	game.hud.toggle_inventory(player)
	if not _verify(game.hud.inventory_view.stats_label.text.contains("Сила магии 8"), "bag shows characteristics"):
		return
	game.hud.toggle_inventory(player)

	# Spare rolled loot can be sold; equipped copy cannot.
	var spare := player.register_generated_item({"slot": "relic", "rarity": "common", "name": "Оберег ветра", "agility": 1, "value": 14})
	player.add_item(spare)
	var offers := game.merchant_shop.get_sell_offers(player)
	var offered: Array = offers.map(func(o: Dictionary) -> String: return o["id"])
	if not _verify(spare in offered and not item_id in offered, "rolled loot is sellable, equipped is not"):
		return
	var gold := player.gold
	if not _verify(bool(game.merchant_shop.sell(player, spare)["success"]) and player.gold == gold + 14, "sells for its value"):
		return

	# Drops from enemies and bosses.
	var drop_id := game.spawn_generated_loot(Vector2(300, 300), "rare")
	if not _verify(drop_id.begins_with("gen_") and player.get_item_definition(drop_id)["rarity"] in ["rare", "epic", "legendary"], "boss-style drop is registered"):
		return
	var on_ground := false
	for node in game.get_children():
		if node is WorldLoot and node.item_id == drop_id:
			on_ground = true
	if not _verify(on_ground, "rolled loot appears on the ground"):
		return

	# Save/load keeps rolled items, equipment and ground loot.
	var snapshot := game.make_save_snapshot()
	var restored: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	if not _verify(restored.restore_save_snapshot(snapshot), "restore works"):
		return
	if not _verify(restored.player.equipment["weapon"] == item_id and restored.player.get_item_name(item_id) == "Жезл силы", "equipped rolled weapon survives save/load"):
		return
	var restored_drop := false
	for node in restored.get_children():
		if node is WorldLoot and node.item_id == drop_id:
			restored_drop = true
	if not _verify(restored_drop and restored.player.get_item_name(drop_id) != drop_id, "ground loot keeps its definition"):
		return
	var next_id := restored.player.register_generated_item({"slot": "relic"})
	if not _verify(not snapshot["player"]["generated_items"].has(next_id), "new ids never collide with saved ones"):
		return
	print("RANDOM LOOT OK: rarities, affixes, characteristics, comparison, selling, drops, save/load")
	quit(0)
