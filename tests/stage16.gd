extends SceneTree

## Этап 16: the sky ship «Ветрокрыл» — Sol's story, the wreck, Yar's repair,
## docks and flights, sky weather, upgrades, the storm and mirage islands.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("STAGE 16 TEST FAILED: " + reason)
	quit(1)

func _views(game: SkywardGame) -> Array:
	return game.get_children().filter(func(n: Node) -> bool: return n is SkyShipView and not n.is_queued_for_deletion())

func _slot_with(ship: SkyShip, wanted: String) -> int:
	for slot in range(0, 200):
		if ship.weather(slot) == wanted:
			return slot
	return -1

func _set_slot(game: SkywardGame, slot: int) -> void:
	game.day_night.day = slot / 2
	game.day_night.time = 0.6 if slot % 2 == 1 else 0.3

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var ship := game.ship
	var q := game.quests
	var hero := game.player

	if "storm_isle" in RegionCatalog.ids() or "mirage_isle" in RegionCatalog.ids():
		return _fail("ship islands are hidden from the world map")
	if ship.can_offer():
		return _fail("no ship before the first act ends")
	q.states["main_echo"]["completed"] = true

	# Sol tells of the wreck.
	game._travel("haven", Vector2(860, 960))
	await process_frame
	if ship.marker(SkyShip.SOL) != "quest":
		return _fail("Sol has a quest marker")
	game.givers.talk(SkyShip.SOL)
	if not game.hud.dialogue_visible:
		return _fail("Sol talks about the ship")
	game.dialogues.handle_choice("ship_accept")
	if not q.is_active(SkyShip.WRECK):
		return _fail("the wreck quest starts")
	if ship.targets().size() != 1:
		return _fail("the wreck is pinned on the map")

	# The wreck on the Salt Coast.
	game._travel("salt_coast", Vector2(900, 600))
	await process_frame
	var views := _views(game)
	if views.size() != 1 or not views[0].wrecked:
		return _fail("the wreck lies on the Salt Coast")
	views[0].interact()
	if not q.is_ready_to_complete(SkyShip.WRECK):
		return _fail("examining the wreck finishes the search")
	if game._interaction_prompt(views[0]) != "E — осмотреть обломки":
		return _fail("wreck prompt")
	game.hud.close_dialogue()

	# Back to Sol, then Yar.
	game._travel("haven", Vector2(860, 960))
	await process_frame
	if ship.marker(SkyShip.SOL) != "ready":
		return _fail("Sol waits for the news")
	game.givers.talk(SkyShip.SOL)
	if not q.is_completed(SkyShip.WRECK) or not q.is_active(SkyShip.REPAIR):
		return _fail("the repair quest follows")
	game.hud.close_dialogue()
	game.givers.talk(SkyShip.YAR)
	if ship.is_ready():
		return _fail("no repair without materials")
	game.hud.close_dialogue()
	for item_id in SkyShip.REPAIR_MATERIALS:
		hero.add_item(item_id, int(SkyShip.REPAIR_MATERIALS[item_id]) + 1)
	if ship.marker(SkyShip.YAR) != "ready":
		return _fail("Yar is ready to build")
	game.givers.talk(SkyShip.YAR)
	if not ship.is_ready() or not q.is_completed(SkyShip.REPAIR):
		return _fail("the ship is repaired")
	if int(hero.inventory.get("wood", 0)) != 1:
		return _fail("the materials are spent")
	game.hud.close_dialogue()

	# The ship waits at every dock.
	game._travel("haven", Vector2(860, 960))
	await process_frame
	views = _views(game)
	if views.size() != 1 or views[0].wrecked:
		return _fail("the ship is at Haven's dock")
	views[0].interact()
	if not game.hud.dialogue_visible:
		return _fail("the ship menu opens")
	game.hud.close_dialogue()
	game.givers.talk(SkyShip.YAR)
	if not game.hud.dialogue_visible:
		return _fail("Yar offers ship upgrades")
	game.hud.close_dialogue()
	if ship.blocked("sky_island") != "путь ещё не известен":
		return _fail("unknown islands are closed")
	game.visited_regions["sky_island"] = true
	if not ship.fly_now("sky_island") or game.current_region != "sky_island":
		return _fail("flight to the sky island")
	await process_frame
	views = _views(game)
	if views.size() != 1:
		return _fail("the ship docks at the island")
	var island_ship: SkyShipView = views[0]
	var ship_sprite := island_ship.get_child(0) as Sprite2D
	var airship_texture := ship_sprite.texture
	var ladder_offset := ship_sprite.position + WorldArt.origin(SkyShipView.SHIP) * ship_sprite.scale
	if ship_sprite.texture.resource_path != "res://assets/" + SkyShipView.SHIP \
			or not is_zero_approx(ladder_offset.x) or absf(ladder_offset.y) > 2.5:
		return _fail("the new airship is anchored by its boarding ladder")
	var harbor_props: Dictionary = {}
	for node in game.world.get_children():
		var sprite := node as Sprite2D
		if sprite != null and sprite.texture != null and sprite.texture.resource_path.contains("/decor_harbor_"):
			harbor_props[sprite.texture.resource_path.get_file()] = sprite
	if harbor_props.size() != 6 or not harbor_props.has("decor_harbor_mooring_beacon.png"):
		return _fail("all six harbor props are loaded on the island")
	if not get_nodes_in_group("night_lights").any(func(node: Node) -> bool:
		return node is PointLight2D and node.position == Vector2(463, 696)):
		return _fail("the beacon provides a light for the night cycle")
	if game.player.global_position != island_ship.global_position + Vector2(0, 26) \
			or game.player.test_move(game.player.global_transform, Vector2(0, -12)):
		return _fail("the arrival and path to the ladder remain open")
	if game._find_nearest_interactable() != island_ship:
		return _fail("the ladder is the nearest interactable from the arrival spot")
	game._try_interact()
	if not game.hud.dialogue_visible:
		return _fail("boarding at the island opens the travel menu")
	ship.handle_choice("ship_later")
	var scenic_clouds := game.world.get_node("SkyClouds") as Node2D
	var landmarks := game.world.get_children().filter(func(node: Node) -> bool:
		return node is Sprite2D and node.texture != null \
			and node.texture.resource_path.contains("/sky_scenery/"))
	if landmarks.size() != 3 or not landmarks.all(func(node: Node) -> bool:
		return node.z_index < scenic_clouds.z_index and node.z_index > -110):
		return _fail("the three distant landmarks render behind the clouds")
	var cloud_textures: Array = scenic_clouds.get("textures")
	if cloud_textures.size() != 3 or not cloud_textures.all(func(texture: Texture2D) -> bool:
		return texture.resource_path.contains("/sky_scenery/")):
		return _fail("the island uses the three new cloud sprites")

	# Weather and the storm engine.
	var storm_slot := _slot_with(ship, "storm")
	var fog_slot := _slot_with(ship, "fog")
	if storm_slot < 0 or fog_slot < 0 or ship.weather(storm_slot) != ship.weather(storm_slot):
		return _fail("the sky has storms and fog")
	_set_slot(game, storm_slot)
	if ship.weather() != "storm" or not ship.forecast_text().contains("Гроза"):
		return _fail("the forecast follows the slot")
	if ship.blocked("storm_isle") != "нужен двигатель бурь":
		return _fail("the storm island needs the engine")
	hero.add_gold(5000)
	hero.add_item("iron_ore", 10)
	hero.add_item("wind_essence", 5)
	if not ship.upgrade("engine") or not ship.has_upgrade(SkyShip.ENGINE):
		return _fail("engine upgrade")
	_set_slot(game, _slot_with(ship, "clear"))
	if ship.blocked("storm_isle") != "ждите грозы":
		return _fail("the storm island needs a thunderstorm")
	_set_slot(game, storm_slot)
	if not ship.fly_now("storm_isle"):
		return _fail("flight into the storm")
	await process_frame
	var storm_clouds: Array = game.world.get_node("SkyClouds").get("textures")
	if storm_clouds.is_empty() or not storm_clouds.all(func(texture: Texture2D) -> bool:
		return texture.resource_path.get_file().begins_with("cloud_puff_")):
		return _fail("other islands keep their usual clouds")
	if game.get_children().filter(func(n: Node) -> bool: return n is WeatherOverlay).is_empty():
		return _fail("rain over the storm island")
	var warden: SlimeEnemy = null
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("storm_warden"):
			warden = node
	if warden == null:
		return _fail("the storm warden waits")
	warden.set_physics_process(false)
	ship._storm_clock = 0.0
	await process_frame
	await process_frame
	var bolts := game.get_children().filter(func(n: Node) -> bool: return n is CrystalStrike and n.lightning)
	if bolts.is_empty():
		return _fail("lightning strikes on the storm island")
	ship._on_warden_down(warden.global_position)
	if not game.director.has_flag(SkyShip.WARDEN_FLAG):
		return _fail("storm warden flag")
	var crown := game.get_children().filter(func(n: Node) -> bool: return n is WorldLoot and n.item_id == "storm_crown")
	if crown.is_empty():
		return _fail("the storm crown drops")
	if not game.achievements.done.has("storm_rider"):
		return _fail("storm achievement")

	# The radar and the mirage island.
	hero.add_item("gear_cog", 4)
	hero.add_item("shadow_essence", 3)
	if not ship.upgrade("radar"):
		return _fail("radar upgrade")
	_set_slot(game, storm_slot)
	if ship.blocked("mirage_isle") != "виден лишь в тумане":
		return _fail("the mirage hides outside fog")
	_set_slot(game, fog_slot)
	if not ship.fly_now("mirage_isle"):
		return _fail("flight to the mirage")
	await process_frame
	if not game.achievements.done.has("mirage_finder"):
		return _fail("mirage achievement")
	var keeper := game.get_children().filter(func(n: Node) -> bool: return n is WorldNpc and n.npc_id == "mirage_keeper")
	if keeper.is_empty():
		return _fail("Veira waits on the mirage")
	if game.get_children().filter(func(n: Node) -> bool: return n is WeatherOverlay and n.mode == "fog").is_empty():
		return _fail("fog over the mirage")

	# A real flight with the transition.
	game.visited_regions["haven"] = true
	if not ship.fly("haven"):
		return _fail("flight starts")
	var transitions := game.get_children().filter(func(node: Node) -> bool: return node is FlightTransition)
	if transitions.size() != 1 or (transitions[0] as FlightTransition)._ship != airship_texture:
		return _fail("the flight transition uses the same airship")
	var waited := 0.0
	while game.current_region != "haven" and waited < 5.0:
		await process_frame
		waited += 1.0 / 60.0
	if game.current_region != "haven":
		return _fail("the flight lands in Haven")
	for i in 400:
		if not ship._flying:
			break
		await process_frame
	if ship._flying:
		return _fail("the flight finishes")
	if game.get_children().filter(func(n: Node) -> bool: return n is WeatherOverlay).size() > 0:
		return _fail("weather stays on its island")

	# Save.
	var snap := ship.make_snapshot()
	ship.flights = 0
	ship.restore_snapshot(snap)
	if ship.flights != 4:
		return _fail("flights saved (%d)" % ship.flights)
	if not game.achievements.done.has("sky_captain"):
		return _fail("captain achievement")
	print("STAGE 16 TEST PASSED")
	quit(0)
