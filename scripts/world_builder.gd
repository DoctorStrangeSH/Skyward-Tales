extends RefCounted
class_name WorldBuilder

## Split out of main.gd (Этап 18, tech debt). Every SkywardGame member is
## reached through `game`; main.gd keeps one-line wrappers with the old names.

var game: SkywardGame

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

func _populate_region() -> void:
	var layout := game._layout()
	for lore_data in layout.get("lore", []):
		game._spawn_lore(lore_data)
	for npc_data in layout.get("npcs", []):
		game._spawn_npc(npc_data)
	for npc_data in game.settlement.npcs_for(game.current_region):
		game._spawn_npc(npc_data)
	game._spawn_settlement()
	for spot in layout.get("contract_boards", []):
		var board := ContractBoard.new()
		game.add_child(board)
		board.global_position = SkywardGame._vec(spot)
		board.used.connect(func(_b: ContractBoard) -> void: game.contracts.open_board())
	game.treasure.spawn_mark()
	game.epilogue.spawn_rift()
	game.village.on_region_ready()
	for node_data in layout.get("resource_nodes", []):
		var node_id := str(node_data.get("id", ""))
		if not bool(game.gathered_resource_nodes.get(node_id, false)):
			game._spawn_herb(SkywardGame._vec(node_data.get("position")), node_id, str(node_data.get("name", node_id)))
	game._spawn_pending_supply_crates(layout)
	game.spawn_story_objects()
	game._spawn_pending_map_fragments(layout)
	for chest_data in layout.get("chests", []):
		game._spawn_chest(str(chest_data.get("id", "")), SkywardGame._vec(chest_data.get("position")), int(chest_data.get("gold", 0)), str(chest_data.get("item", "")), int(chest_data.get("amount", 0)), str(chest_data.get("tier", "wood")))
	for herb_data in layout.get("herbs", []):
		# Quest items only appear once their quest is taken.
		if not game.quests.is_active(game._herb_quest(herb_data)):
			continue
		game._spawn_herb(SkywardGame._vec(herb_data.get("position")), str(herb_data.get("id", "moonleaf")), str(herb_data.get("name", "Лунный лист")), str(herb_data.get("quest", "")))
	for enemy_data in layout.get("enemies", []):
		# "quest": only while that quest is open (unique side bosses).
		var needs := str(enemy_data.get("quest", ""))
		if not needs.is_empty() and not game.quests.is_active(needs):
			continue
		if not game.layout_allows(enemy_data):
			continue
		game._spawn_layout_enemy(enemy_data)
	game._spawn_waystone(layout)
	game._spawn_gathering(layout)
	game._spawn_dynamic_props(layout)
	game._spawn_dungeon(layout)
	var boss: Dictionary = layout.get("boss", {})
	if not boss.is_empty() and game.quests.is_completed(str(boss.get("after_quest", ""))):
		game.spawn_region_boss()
	for gate_data in layout.get("gates", []):
		game._spawn_gate(str(gate_data.get("target", "")), SkywardGame._vec(gate_data.get("position")), SkywardGame._vec(gate_data.get("arrival")), str(gate_data.get("label", "")))
	game.buildings.spawn_mercenary()
	game.lira.populate()
	game.bran.populate()
	game.fair.populate()
	game.trials.populate()
	game.cistern.populate()
	game.hens.populate()
	game.forestry.populate()
	game.adit.populate()
	game.home.populate()
	_apply_camera_limits()
	game.buildings.reveal_chests()
	game.guild.spawn_target()
	if game.current_region == Expeditions.REGION:
		game.expeditions.populate()
	game.legends.on_region_ready()
	game.ship.populate()
	game.fates.populate()
	game.deep_rifts.populate()
	game.party.ensure_follower()
	game.party.apply_mira()

func _spawn_layout_enemy(enemy_data: Dictionary) -> SlimeEnemy:
	var kind := str(enemy_data.get("kind", "slime"))
	var enemy := game.spawn_enemy(kind, SkywardGame._vec(enemy_data.get("position")), str(enemy_data.get("elite", "?")))
	if kind == "ore_golem" and enemy != null:
		enemy.defeated.connect(func(_xp: int) -> void: game.mine.on_leader_defeated())
	if enemy == null or enemy_data.has("quest") or kind in SkywardGame.STORY_BOSSES or kind in ["guardian", "ore_golem"]:
		return enemy
	var region_id := game.current_region
	enemy.defeated.connect(func(_xp: int) -> void:
		game._respawns.append({"region": region_id, "data": enemy_data, "at": game._play_clock + SkywardGame.ENEMY_RESPAWN}))
	return enemy

func _spawn_pending_supply_crates(layout: Dictionary) -> void:
	var state: Dictionary = game.quests.states.get("bran_supply_run", {})
	if not bool(state.get("started", false)) or game.quests.is_completed("bran_supply_run"):
		return
	var collected: Array = state.get("collected_crates", [])
	var positions: Array = layout.get("supply_crates", [])
	for index in range(positions.size()):
		if not collected.has(index):
			game._spawn_herb(SkywardGame._vec(positions[index]), "supply_crate_%d" % index, "Потерянный ящик с припасами")

func spawn_supply_crates() -> void:
	var positions: Array = game._layout("greenreach").get("supply_crates", [])
	for index in range(positions.size()):
		game._spawn_herb(SkywardGame._vec(positions[index]), "supply_crate_%d" % index, "Потерянный ящик с припасами")

func _spawn_pending_map_fragments(layout: Dictionary) -> void:
	var positions: Array = layout.get("map_fragments", [])
	if positions.is_empty() or game.quests.is_completed("lost_cartographer_notes"):
		return
	var state: Dictionary = game.quests.states.get("lost_cartographer_notes", {})
	var target: int = int(game.quests.definitions.get("lost_cartographer_notes", {}).get("target", 2))
	var remaining: int = target - (int(state.get("progress", 0)) if bool(state.get("started", false)) else 0)
	for index in range(clampi(remaining, 0, positions.size())):
		game._spawn_herb(SkywardGame._vec(positions[index]), "map_fragment", "Обрывок полевого дневника")

func spawn_region_boss() -> void:
	var boss: Dictionary = game._layout().get("boss", {})
	if not boss.is_empty():
		game.spawn_enemy(str(boss.get("kind", "guardian")), SkywardGame._vec(boss.get("position")))

func reveal_secret(region_id: String, marker_id: String) -> void:
	var markers: Dictionary = game.discovered_landmarks.get(region_id, {})
	if markers.has(marker_id):
		return
	var position_data: Variant = game._layout(region_id).get("secrets", {}).get(marker_id)
	if position_data == null:
		push_warning("Неизвестная секретная отметка: " + marker_id)
		return
	var pos := SkywardGame._vec(position_data)
	markers[marker_id] = {"position": [pos.x, pos.y], "kind": "secret"}
	game.discovered_landmarks[region_id] = markers
	if game.current_region == region_id:
		game._update_minimap()

func _clear_region_actors() -> void:
	for node in game.get_children():
		if node is WorldNpc and node.is_companion:
			continue
		if node is WorldNpc or node is WorldCollectible or node is SlimeEnemy or node is WorldLoot or node is TreasureChest or node is RegionGate or node is Waystone or node is SettlementObject or node is GatherNode or node is CraftStation or node is DungeonDoor or node is SpikeTrap or node is FlameVent or node is DungeonLever or node is ContractBoard or node is DigSpot or node is PatternRift or node is Caravan or node is Arrow or node is SnareTrap or node is SpiritAlly or node is CrystalTotem or node is FarmBed or node is FarmPatch or node is MagicBolt or node is EnemyMagicOrb or node.is_in_group("region_actor"):
			game.remove_child(node)
			node.queue_free()
	game.elder = null
	game.nearby_interactable = null
	game._respawns.clear()

func _set_region(region_id: String, arrival: Vector2, notify: bool = true) -> void:
	game.current_region = RegionCatalog.resolve(region_id)
	game.visited_regions[game.current_region] = true
	if game.achievements != null:
		game.achievements.set_max("regions", game.visited_regions.size())
	game._clear_region_actors()
	if game.world != null and game.world.has_method("configure_region"):
		game.world.set("allows", game.layout_allows)
		game.world.configure_region(game.current_region)
	game._populate_region()
	game.update_music.call_deferred()
	game.player.global_position = arrival
	game._place_companion()
	if notify and game.hud != null:
		game.hud.show_message("Локация: " + RegionCatalog.display_name(game.current_region), 2.5)
	game._refresh_hud()

## Places story objects whose quest is active (skips ones already present).
func spawn_story_objects() -> void:
	for object_data in game._layout().get("story_objects", []):
		if not game.layout_allows(object_data):
			continue
		var object_id := str(object_data.get("id", ""))
		var quest_id := str(object_data.get("quest", ""))
		if not bool(game.quests.states.get(quest_id, {}).get("started", false)) or game.quests.is_completed(quest_id):
			continue
		var present := false
		for actor in game.get_children():
			if actor is WorldCollectible and actor.item_id == object_id and not actor.is_queued_for_deletion():
				present = true
		if not present:
			game._spawn_herb(SkywardGame._vec(object_data.get("position")), object_id, str(object_data.get("name", "")))

func _apply_camera_limits() -> void:
	var camera := game.player.get_node_or_null("Camera2D") as Camera2D
	if camera == null or game.world == null or not game.world.has_method("map_size"):
		return
	# The art is drawn at twice the world scale: at zoom 0.75 a 1080p screen
	# shows it almost pixel for pixel (crisp, and far more of the world in
	# view). Rooms and dungeons stay closer.
	var zoom := game.camera_zoom()
	camera.zoom = Vector2(zoom, zoom)
	var size: Vector2 = game.world.map_size()
	# On floating islands the camera may look past the rim into the sky.
	var view := 110 if game.world.has_method("has_apron") and game.world.has_apron() else 0
	var left := -float(view)
	var top := -float(view)
	var right := size.x + view
	# Leave room to see authored water above the HUD, within the painted sky.
	var south_view := mini(view, 78) if game.world.get_node_or_null("CliffRim") != null else view
	if view > 0:
		south_view = int(clampf(float(RegionCatalog.terrain(game.current_region).get("camera_bottom_margin", south_view)), 0.0, 160.0))
	var bottom := size.y + south_view
	# A land smaller than the screen sits in the middle of it.
	var seen := Vector2(640, 360) / zoom
	if right - left < seen.x:
		var pad := (seen.x - (right - left)) * 0.5
		left -= pad
		right += pad
	if bottom - top < seen.y:
		var pad := (seen.y - (bottom - top)) * 0.5
		top -= pad
		bottom += pad
	camera.limit_left = int(floor(left))
	camera.limit_top = int(floor(top))
	camera.limit_right = int(ceil(right))
	camera.limit_bottom = int(ceil(bottom))

func _spawn_waystone(layout: Dictionary) -> void:
	var spot: Variant = layout.get("waystone", null)
	if not spot is Array:
		return
	var stone := SkywardGame.WAYSTONE_SCRIPT.new() as Waystone
	stone.region_id = game.current_region
	game.add_child(stone)
	stone.global_position = SkywardGame._vec(spot)
	stone.set_awake(game.waystone_awake(game.current_region))
	stone.used.connect(game._on_waystone_used)

func _spawn_dungeon(layout: Dictionary) -> void:
	for entry in layout.get("doors", []):
		var door := SkywardGame.DUNGEON_DOOR_SCRIPT.new() as DungeonDoor
		door.door_id = str(entry.get("id", ""))
		door.key_item = str(entry.get("key", ""))
		for lever_id in entry.get("levers", []):
			door.levers.append(str(lever_id))
		door.is_open = bool(game.opened_doors.get(door.door_id, false))
		game.add_child(door)
		door.global_position = SkywardGame._vec(entry.get("position"))
		door.used.connect(game._on_door_used)
	for spot in layout.get("traps", []):
		var trap: Node2D
		if spot is Dictionary and str(spot.get("kind", "")) == "vent":
			trap = FlameVent.new()
			spot = spot.get("position")
		else:
			trap = SkywardGame.SPIKE_TRAP_SCRIPT.new() as SpikeTrap
		game.add_child(trap)
		trap.global_position = SkywardGame._vec(spot)
	for entry in layout.get("levers", []):
		var lever := DungeonLever.new()
		lever.lever_id = str(entry.get("id", ""))
		lever.pulled = bool(game.opened_doors.get(lever.lever_id, false))
		game.add_child(lever)
		lever.global_position = SkywardGame._vec(entry.get("position"))
		lever.used.connect(game._on_lever_used)

## Pulling a lever; seals open once all their levers are down.
func _on_lever_used(lever: DungeonLever) -> void:
	if lever.pulled:
		return
	game.opened_doors[lever.lever_id] = true
	lever.set_pulled(true)
	GameAudio.play("chest", -4.0, 0.1)
	game.shake(1.5, 0.15)
	for node in game.get_children():
		if node is DungeonDoor and not node.is_open and not node.levers.is_empty():
			var done: int = node.levers.filter(func(id: String) -> bool: return bool(game.opened_doors.get(id, false))).size()
			if done >= node.levers.size():
				game.opened_doors[node.door_id] = true
				node.set_open(true)
				game.shake(3.0, 0.3)
				game.hud.show_message("Где-то с грохотом открылась печать!", 3.0)
			else:
				game.hud.show_message("Рычаг опущен. Печать: %d из %d." % [done, node.levers.size()], 2.5)
	game.request_autosave()

func _on_door_used(door: DungeonDoor) -> void:
	if door.is_open:
		return
	if not door.levers.is_empty():
		var done: int = door.levers.filter(func(id: String) -> bool: return bool(game.opened_doors.get(id, false))).size()
		game.hud.show_message("Печать держат рычаги: опущено %d из %d. Найдите остальные." % [done, door.levers.size()], 3.0)
		return
	if not game.player.remove_item(door.key_item, 1):
		game.hud.show_message("Заперто. Нужен ключ: %s." % game.player.get_item_name(door.key_item), 2.5)
		return
	game.opened_doors[door.door_id] = true
	door.set_open(true)
	GameAudio.play("chest", -2.0, 0.0)
	game.shake(2.0, 0.2)
	game.hud.show_message("Решётка поднимается!", 2.0)
	game.request_autosave()

## Landmarks that change with quests (the lighthouse lights up).
func _spawn_dynamic_props(layout: Dictionary) -> void:
	for entry in layout.get("dynamic_props", []):
		var lit := game.quests.is_completed(str(entry.get("lit_quest", "")))
		var object := SkywardGame.SETTLEMENT_OBJECT_SCRIPT.new() as SettlementObject
		object.kind = "house"
		object.art = str(entry.get("lit_art", "")) if lit else str(entry.get("art", ""))
		object.set_meta("dynamic", true)
		game.add_child(object)
		object.global_position = SkywardGame._vec(entry.get("position"))

func _refresh_dynamic_props() -> void:
	for node in game.get_children():
		if node is SettlementObject and node.has_meta("dynamic"):
			game.remove_child(node)
			node.queue_free()
	game._spawn_dynamic_props(game._layout())

func _spawn_gathering(layout: Dictionary) -> void:
	game._spawn_gathering_entries(layout.get("gather", []))
	game._spawn_craft_stations()

## only_state: spawn just the entries that need this world state (they appear
## mid-visit, e.g. the rich veins of a freed mine).
func _spawn_gathering_entries(entries: Array, only_state: String = "") -> void:
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		if not game.layout_allows(entry):
			continue
		if not only_state.is_empty() and str(entry.get("requires_state", "")) != only_state:
			continue
		var info := game.crafting.kind(str(entry.get("kind", "")))
		if info.is_empty():
			continue
		var node := SkywardGame.GATHER_NODE_SCRIPT.new() as GatherNode
		node.key = "%s:%d" % [game.current_region, index]
		node.kind = str(entry.get("kind", ""))
		node.display_name = str(info.get("name", node.kind))
		node.art = str(info.get("art", "gather_wood"))
		node.verb = str(info.get("verb", "собрать"))
		game.add_child(node)
		node.global_position = SkywardGame._vec(entry.get("position"))
		node.set_ready(game.crafting.is_ready(node.key))
		node.used.connect(game.crafting.gather)

func _spawn_craft_stations() -> void:
	var stations: Dictionary = game.crafting.data.get("placements", {}).get(game.current_region, {})
	for station_id in stations:
		var info := game.crafting.station(str(station_id))
		var station := SkywardGame.CRAFT_STATION_SCRIPT.new() as CraftStation
		station.station_id = str(station_id)
		station.display_name = str(info.get("name", station_id))
		station.art = str(info.get("art", ""))
		game.add_child(station)
		station.global_position = SkywardGame._vec(stations[station_id])
		station.used.connect(func(s: CraftStation) -> void: game.crafting.open(s.station_id))

func _spawn_settlement() -> void:
	if game.current_region != game.settlement.village_region():
		return
	var board_pos: Array = game.settlement.data.get("board", {}).get("position", [0, 0])
	game._spawn_settlement_object("board", "village_board", Vector2(float(board_pos[0]), float(board_pos[1])))
	for entry in game.settlement.data.get("plots", []):
		var p: Array = entry.get("position", [0, 0])
		var plot_id := str(entry.get("id", ""))
		var art := "village_plot"
		var kind := "plot"
		if game.settlement.homes.has(plot_id):
			art = str(game.settlement.settler(str(game.settlement.homes[plot_id])).get("house", "village_house_small"))
			kind = "house"
		game._spawn_settlement_object(kind, art, Vector2(float(p[0]), float(p[1])))
	game.farm.spawn()
	game.buildings.spawn()

func _spawn_settlement_object(kind: String, art: String, at: Vector2) -> void:
	var object := SkywardGame.SETTLEMENT_OBJECT_SCRIPT.new() as SettlementObject
	object.kind = kind
	object.art = art
	game.add_child(object)
	object.global_position = at
	if kind == "board":
		object.used.connect(func(_o: SettlementObject) -> void: game.settlement.open_board())

func _spawn_npc(npc_data: Dictionary) -> void:
	var npc_id := str(npc_data.get("id", ""))
	# "requires_flag": "ending" — only after the finale choice.
	var needs_flag := str(npc_data.get("requires_flag", ""))
	if needs_flag == "ending" and game.epilogue.ending().is_empty():
		return
	if not game.layout_allows(npc_data):
		return
	if not needs_flag.is_empty() and needs_flag != "ending" and not game.director.has_flag(needs_flag):
		return
	if npc_id == "cartographer" and game.companion != null:
		return  # Mira travels with the hero instead of waiting at camp
	if game.party != null and game.party.extra == npc_id:
		return  # this one travels with the hero too
	var npc := SkywardGame.NPC_SCRIPT.new() as WorldNpc
	npc.npc_id = npc_id
	npc.look_id = str(npc_data.get("look", ""))
	npc.display_name = str(npc_data.get("name", "Путник"))
	var color: Variant = npc_data.get("outfit_color")
	if color is Array and color.size() == 3:
		npc.outfit_color = Color(float(color[0]), float(color[1]), float(color[2]))
	game.add_child(npc)
	npc.global_position = SkywardGame._vec(npc_data.get("position"))
	var handler := Callable(game, "_on_%s_interacted" % npc_id)
	if handler.is_valid() and game.trainers.has_trainer(npc_id):
		# A trainer first asks: talk or learn (owner's list №29).
		npc.interacted.connect(func(source: Node2D) -> void: game.trainers.greet(npc_id, func(_s: Variant) -> void: handler.call(source)))
	elif handler.is_valid():
		npc.interacted.connect(handler)
	elif game.settlement.has_settler_npc(npc_id):
		npc.interacted.connect(func(_source: Node2D) -> void: game.settlement.talk(npc_id))
	elif game.givers.has_giver(npc_id) or game.givers.is_special(npc_id):
		npc.interacted.connect(func(_source: Node2D) -> void: game.givers.talk(npc_id))
	else:
		push_warning("У NPC нет обработчика диалога: " + npc_id)
	var wander: Variant = npc_data.get("wander", [])
	if wander is Array and not (wander as Array).is_empty():
		var walker := NpcWander.new()
		walker.setup(game, npc, wander)
		npc.add_child(walker)
	if npc_id == "elder":
		game.elder = npc

func _spawn_herb(spawn_position: Vector2, item_id: String = "moonleaf", label: String = "Лунный лист", quest_id: String = "") -> void:
	var herb := SkywardGame.COLLECTIBLE_SCRIPT.new() as WorldCollectible
	herb.item_id = item_id
	herb.quest_id = quest_id
	herb.display_name = label
	game.add_child(herb)
	herb.global_position = spawn_position
	herb.interacted.connect(game._on_herb_interacted)

func _spawn_lore(lore_data: Dictionary) -> void:
	var lore_id := str(lore_data.get("id", ""))
	if game.lore.entry(lore_id).is_empty():
		return
	var stone := LoreStone.new()
	stone.lore_id = lore_id
	stone.fresh = not game.lore.read.has(lore_id)
	game.add_child(stone)
	stone.global_position = SkywardGame._vec(lore_data.get("position"))
	stone.interacted.connect(func(_source: Node2D) -> void: game.read_lore(stone))

func _spawn_chest(id: String, at_position: Vector2, gold: int, item: String, amount: int, tier: String = "wood") -> void:
	var chest := SkywardGame.CHEST_SCRIPT.new() as TreasureChest
	chest.tier = tier
	chest.chest_id = id
	chest.gold_reward = gold
	chest.item_reward = item
	chest.item_amount = amount
	chest.is_opened = bool(game.opened_chests.get(id, false))
	chest.position = at_position
	game.add_child(chest)
	if chest.is_opened:
		chest.remove_from_group("interactables")
	chest.opened.connect(game._on_chest_opened)
	chest.opened.connect(func(_id: String, _gold: int, _item: String, _amount: int) -> void: game.chest_tier_reward(chest.tier, chest.global_position))
	chest.bonus_found.connect(game._on_chest_bonus)

func _spawn_gate(target_region: String, gate_position: Vector2, arrival: Vector2, label: String) -> void:
	var gate := SkywardGame.GATE_SCRIPT.new() as RegionGate
	gate.target_region = target_region
	gate.arrival_position = arrival
	gate.display_name = label
	gate.art_style = RegionCatalog.style(game.current_region)
	var size: Vector2 = game.world.map_size() if game.world != null and game.world.has_method("map_size") else Vector2(1280, 864)
	var look := RegionGate.pick_kind(gate.art_style, RegionCatalog.style(target_region), gate_position, size)
	gate.kind = str(look["kind"])
	gate.outward = look["outward"]
	gate.edge_distance = float(look["edge_distance"])
	# HD ground has the walkway to the rim painted in.
	if ResourceLoader.exists("res://assets/world_hd/%s_ground.webp" % game.current_region):
		gate.edge_distance = 0.0
	game.add_child(gate)
	gate.global_position = gate_position
	gate.travel_requested.connect(game._on_region_travel)
