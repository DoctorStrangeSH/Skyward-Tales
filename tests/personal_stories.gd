extends SceneTree

## Stage 20: the personal stories of Lira (a still, runaway potions, the
## Keeper alchemist's notes → a lab with daily potions and brewing) and of
## Bran (a hull, a charter from Bruno → the flying shop «Ласточка» with
## goods from the islands).

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("PERSONAL STORIES FAILED: " + reason)
	quit(1)

func _choices(game: SkywardGame) -> String:
	var text := ""
	for button in game.hud.dialogue_choices_container.get_children():
		text += (button as Button).text + "\n"
	return text

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var q := game.quests
	hero.level = 12
	for id in ["moonleaf_gathering", "lira_slime", "bran_supply_run"]:
		q.states[id]["started"] = true
		q.states[id]["completed"] = true

	# --- Lira -------------------------------------------------------------
	if game.dialogues.marker_for("alchemist") != "quest":
		return _fail("Lira offers her story: " + game.dialogues.marker_for("alchemist"))
	game.givers.talk("alchemist")
	game.story.skip()
	if not _choices(game).contains("Достану руду и слизь"):
		return _fail("Lira asks for ore and slime:\n" + _choices(game))
	game._on_dialogue_choice_selected("lira_accept:still")
	if not q.is_active(LiraStory.STILL):
		return _fail("the still quest starts")
	hero.add_item("iron_ore", 5)
	hero.add_item("slime_gel", 4)
	game._refresh_hud()
	if int(q.states[LiraStory.STILL]["progress"]) != 2 or game.dialogues.marker_for("alchemist") != "ready":
		return _fail("the tracker counts what the hero carries")
	game.givers.talk("alchemist")
	if not game.story.active or not bool(game.story.scenes["_talk"].get("cinematic", false)):
		return _fail("the explosion is a scene on the engine")
	game.story.skip()
	await process_frame
	if not q.is_completed(LiraStory.STILL) or hero.inventory.has("iron_ore") or not q.is_active(LiraStory.BLAST):
		return _fail("the still is built, the potions run away")
	var blobs: Array = []
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("lira_blob"):
			blobs.append(node)
	if blobs.size() != LiraStory.BLOBS:
		return _fail("five living potions: %d" % blobs.size())
	for blob in blobs:
		blob.take_damage(9999)
	await process_frame
	await process_frame
	if not q.is_ready_to_complete(LiraStory.BLAST):
		return _fail("catching them all finishes the hunt: %d" % int(q.states[LiraStory.BLAST]["progress"]))
	game.givers.talk("alchemist")
	game.story.skip()
	game._on_dialogue_choice_selected("lira_accept:recipe")
	if not q.is_completed(LiraStory.BLAST) or not q.is_active(LiraStory.RECIPE):
		return _fail("then the recipe")
	game._set_region(LiraStory.NOTES_REGION, Vector2(600, 420), false)
	await process_frame
	var notes: WorldCollectible = null
	for node in game.get_children():
		if node is WorldCollectible and node.item_id == LiraStory.NOTES_ID:
			notes = node
	if notes == null or notes.art_name() != LiraStory.NOTES_ID:
		return _fail("the notes lie in the Archive")
	game._on_herb_interacted(notes)
	game.story.skip()
	if not q.is_ready_to_complete(LiraStory.RECIPE):
		return _fail("reading the notes")
	game._set_region("greenreach", Vector2(900, 560), false)
	await process_frame
	game.givers.talk("alchemist")
	game.story.skip()
	if not game.lira.lab_grown() or not q.is_completed(LiraStory.RECIPE):
		return _fail("the lab grows")
	var still := false
	for node in game.get_children():
		still = still or node is LiraStory.LabStill
	if not still:
		return _fail("a copper still stands by the lab")
	game.givers.talk("alchemist")
	if not _choices(game).contains("Зелье дня"):
		return _fail("Lira's lab offers the daily potion:\n" + _choices(game))
	var potions := hero.inventory.size()
	game._on_dialogue_choice_selected("lira_gift")
	if game.lira.gift_ready() or hero.inventory.size() < potions:
		return _fail("one potion a day")
	hero.add_item("slime_gel", 3)
	var heal := int(hero.inventory.get("health_potion", 0))
	game._on_dialogue_choice_selected("lira_brew:brew_heal")
	if int(hero.inventory.get("health_potion", 0)) != heal + 2 or hero.inventory.has("slime_gel"):
		return _fail("brewing turns slime into potions")
	game.hud.close_dialogue()

	# --- Bran ---------------------------------------------------------------
	if game.dialogues.marker_for("merchant") != "quest":
		return _fail("Bran offers his story: " + game.dialogues.marker_for("merchant"))
	game.dialogues.on_merchant()
	game.story.skip()
	if not _choices(game).contains("Ласточку") or not _choices(game).contains("лавка"):
		return _fail("Bran asks for a hull, the shop stays near:\n" + _choices(game))
	game._on_dialogue_choice_selected("bran_accept:hull")
	hero.add_item("wood", 10)
	hero.add_item("iron_ore", 6)
	hero.add_item("wind_essence", 2)
	game._refresh_hud()
	game.dialogues.on_merchant()
	game.story.skip()
	game._on_dialogue_choice_selected("bran_accept:charter")
	if not q.is_completed(BranStory.HULL) or not q.is_active(BranStory.CHARTER) or hero.inventory.has("wood"):
		return _fail("the hull is built, the charter is next")
	if game.dialogues.marker_for(BranStory.BRUNO) != "ready":
		return _fail("Bruno waits with the charter")
	hero.gold = 100
	hero.add_item("golden_fish")
	game.givers.talk(BranStory.BRUNO)
	game.story.skip()
	if not _choices(game).contains("золотую рыбку"):
		return _fail("Bruno takes a golden fish:\n" + _choices(game))
	game._on_dialogue_choice_selected("bran_fish")
	game.story.skip()
	if not q.is_ready_to_complete(BranStory.CHARTER) or hero.inventory.has("golden_fish") or hero.gold != 100:
		return _fail("a fish for the charter")
	game.dialogues.on_merchant()
	await process_frame
	if not game.bran.flying():
		return _fail("«Ласточка» flies")
	game.story.skip()
	var ship: Node = null
	for node in game.get_children():
		if node is BranStory.FlyingShop:
			ship = node
	if ship == null:
		return _fail("the flying shop hangs over the market")
	game.dialogues.on_merchant()
	if not _choices(game).contains("Товары с островов"):
		return _fail("goods from the islands:\n" + _choices(game))
	var stock := game.bran.stock()
	if stock.size() != 3 or str(game.bran.stock()[0]["definition"].get("name")) != str(stock[0]["definition"].get("name")):
		return _fail("three pieces a day, the same all day")
	hero.gold = 5000
	game._on_dialogue_choice_selected("bran_isle:0")
	if not game.bran.bought.has(0) or hero.gold >= 5000:
		return _fail("buying from the island goods")
	game._on_dialogue_choice_selected("bran_isle:0")
	if hero.gold != 5000 - int(stock[0]["price"]):
		return _fail("each piece sells once")

	# Saved and restored.
	game.lira.gift_day = 77
	var data := {"lira": game.lira.make_snapshot(), "bran": game.bran.make_snapshot()}
	game.lira.restore_snapshot({})
	game.bran.restore_snapshot({})
	game.lira.restore_snapshot(data["lira"])
	game.bran.restore_snapshot(data["bran"])
	if game.lira.gift_day != 77 or not game.bran.bought.has(0):
		return _fail("the stories are saved")

	print("PERSONAL STORIES OK")
	quit(0)
