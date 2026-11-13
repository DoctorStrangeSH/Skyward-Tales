extends SceneTree

## Owner's list, package A (bugs): sleeping NPCs, loot pickup, Mira's pages
## during the story, the way back from the grove, leftovers of finished
## quests, the rooted charge, foliage stops in the pause menu.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("OWNER BATCH A FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player

	# №8: a sleeping villager answers a knock, not a conversation.
	var elder: WorldNpc = null
	for node in game.get_children():
		if node is WorldNpc and node.npc_id == "elder":
			elder = node
	elder.set_asleep(true)
	elder.interact()
	if not game.hud.dialogue_speaker_label.text.contains("спит") or game.hud.dialogue_choices_container.get_child_count() != 2:
		return _fail("a sleeping elder only answers a knock")
	game.day_night.time = 0.9
	game._on_dialogue_choice_selected("knock_wait")
	if absf(game.day_night.time - 0.28) > 0.01:
		return _fail("waiting until the morning")
	elder.set_asleep(false)

	# №10 (revised in Этап 24 by the owner): gear waits on the ground for E;
	# coins, materials and potions fly into the bag.
	var ore := game._spawn_loot(hero.global_position + Vector2(10, 4), "iron_ore")
	var ore_before := int(hero.inventory.get("iron_ore", 0))
	var sword := game._spawn_loot(hero.global_position + Vector2(10, 0), "iron_sword")
	var coins := game._spawn_loot(hero.global_position + Vector2(-10, 0), "gold")
	coins.amount = 7
	var gold := hero.gold
	for i in 40:
		await process_frame
	if not is_instance_valid(sword) or sword.is_queued_for_deletion():
		return _fail("loot is not picked up by itself")
	if hero.gold != gold + 7:
		return _fail("coins are still picked up by walking")
	if int(hero.inventory.get("iron_ore", 0)) != ore_before + 1 or (is_instance_valid(ore) and not ore.is_queued_for_deletion()):
		return _fail("materials fly into the bag")
	if not game._interaction_prompt(sword).contains("подобрать"):
		return _fail("the prompt names the item")
	sword.interact()

	# №12: Mira's pages count while a story quest is tracked.
	game.quests.states["moonleaf_gathering"]["completed"] = true
	game.quests.start_quest("lost_cartographer_notes")
	game.quests.start_quest("main_guardian")
	if game.quests.active_quest_id != "main_guardian" or not game.quests.is_side("lost_cartographer_notes"):
		return _fail("Mira's pages are a side quest next to the story")
	var page := WorldCollectible.new()
	page.item_id = "map_fragment"
	game.add_child(page)
	game.pickups.handle(page)
	if int(game.quests.states["lost_cartographer_notes"]["progress"]) != 1:
		return _fail("a page counts during the story")

	# №16: a finished quest takes its leftovers off the ground.
	var spare := WorldCollectible.new()
	spare.item_id = "map_fragment"
	game.add_child(spare)
	game.quests.add_progress("lost_cartographer_notes", 1)
	game.quests.complete_quest("lost_cartographer_notes")
	await process_frame
	if is_instance_valid(spare) and not spare.is_queued_for_deletion():
		return _fail("leftover pages vanish after the quest")

	# №15: the way back from the grove is the western path.
	var back: Dictionary = {}
	for gate in RegionCatalog.get_region("moonlit_grove").get("gates", []):
		if gate["target"] == "greenreach":
			back = gate
	if int(back["position"][0]) > 80:
		return _fail("the grove's way back is at the western edge")

	# №20: a charged attack roots the hero; a roll cancels it.
	game._charging = true
	hero.charge_rooted = true
	Input.action_press("move_right")
	var start := hero.global_position
	for i in 10:
		await physics_frame
	if hero.global_position.distance_to(start) > 1.0:
		Input.action_release("move_right")
		return _fail("the charged hero stands still")
	Input.action_press("sprint")
	await physics_frame
	await physics_frame
	Input.action_release("sprint")
	Input.action_release("move_right")
	if game._charging or hero.charge_rooted:
		return _fail("sprint cancels the charge")

	# №6: the pause menu freezes the foliage.
	var material: ShaderMaterial = (game.world.get_script() as GDScript).call("sway_material", 5.0)
	await process_frame
	var before: float = material.get_shader_parameter("clock")
	game.hud._set_paused(true)
	for i in 10:
		await process_frame
	var during: float = material.get_shader_parameter("clock")
	game.hud._set_paused(false)
	if not is_equal_approx(before, during):
		return _fail("the trees freeze in the pause menu")
	print("OWNER BATCH A PASSED")
	quit(0)
