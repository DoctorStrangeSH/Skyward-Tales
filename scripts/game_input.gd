extends RefCounted
class_name GameInput

## Split out of main.gd (Этап 18, tech debt). Every SkywardGame member is
## reached through `game`; main.gd keeps one-line wrappers with the old names.

var game: SkywardGame

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

func _interaction_prompt(target: Node2D) -> String:
	if target is GatherNode:
		return "E — " + target.verb if target.available else "E — пусто"
	if target is CraftStation:
		return "E — " + ("готовить" if target.station_id == "kitchen" else "мастерить")
	if target is DungeonDoor:
		return "E — печать" if not target.levers.is_empty() else "E — открыть"
	if target is ContractBoard:
		return "E — доска заказов"
	if target is DigSpot:
		return "E — копать"
	if target is PatternRift:
		return "E — закрыть разлом"
	if target is FarmBed:
		return game.farm.prompt(target.index)
	if target is SettlementObject and target.kind == "door":
		return target.label
	if target is DungeonLever:
		return "E — опустить рычаг"
	if target is SettlementObject:
		return "E — доска поселения"
	if target is WorldNpc:
		return "E — постучать" if target.asleep else "E — поговорить"
	if target is RegionGate:
		var verb: String = {"cave_mouth": "войти в пещеру", "cave_exit": "выйти", "stairs_down": "спуститься", "stairs_up": "подняться"}.get(target.kind, "по мосту")
		return "E — %s: %s · ур. %d" % [verb, RegionCatalog.display_name(target.target_region), RegionCatalog.level(target.target_region)]
	if target is WorldLoot:
		return "E — подобрать"
	if target is LoreStone:
		return "E — прочитать руны"
	if target is TreasureChest:
		return "E — открыть"
	if "prompt" in target:
		return "E — " + str(target.get("prompt"))
	return "E — собрать"

func _input(event: InputEvent) -> void:
	if game.game_over or (game.hud != null and (game.hud.talent_visible or game.hud.defeat_visible)):
		return
	if game.fishing != null and game.fishing.active():
		# While fishing only E / LMB (hook and reel) and cancel keys matter.
		if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
			game.fishing.press()
			game.get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			game.fishing.cancel()
			game.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.pressed and event.keycode == KEY_F:
		game.player.end_guard()
	if event is InputEventKey and event.pressed and not event.echo:
		if game._handle_key(event.keycode):
			game.get_viewport().set_input_as_handled()
			return
	# Mouse wheel: the next / previous spell.
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if game.get_viewport().gui_get_hovered_control() == null and not game.get_tree().paused and not game.hud.dialogue_visible and not game.hud.inventory_open and not game.hud.overlay_visible() and not game.hud.crafting_visible:
			game.cycle_spell(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		return
	# _input receives mouse clicks even when a Control overlays the world.
	if event.is_action_pressed("interact"):
		if game.story.active:
			game.story.advance()
		elif game.hud.dialogue_visible:
			game.hud.close_dialogue()
			game.player.set_physics_process(true)
		else:
			game._try_interact()
		game.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack") or event.is_action_released("attack"):
		if game.get_viewport().gui_get_hovered_control() != null:
			return
		if not game.get_tree().paused and not game.hud.dialogue_visible and not game.hud.inventory_open and not game.hud.overlay_visible():
			if event.is_pressed():
				game._attack_pressed()
			else:
				game._attack_released()
			game.get_viewport().set_input_as_handled()
	elif event.is_action_released("cast_spell") and game._bow_holding:
		game._bow_release()
		game.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cast_spell"):
		# Clicks on buttons (dialogue choices, menus) must reach the GUI, so the
		# click is consumed only when it really casts a spell.
		if game.get_viewport().gui_get_hovered_control() != null:
			return
		if not game.get_tree().paused and not game.hud.dialogue_visible and not game.hud.inventory_open and not game.hud.overlay_visible():
			if game.player.has_bow():
				game._bow_press()
			else:
				game._cast_spell()
			game.get_viewport().set_input_as_handled()

## Returns true when the key was consumed and must not reach other handlers.
func _handle_key(keycode: Key) -> bool:
	var world_blocked: bool = game.get_tree().paused or game.hud.dialogue_visible
	if game.hud.crafting_visible and keycode != KEY_B:
		if keycode == KEY_E:
			game.crafting.close()
			return true
		return keycode in [KEY_SPACE, KEY_F, KEY_1, KEY_2, KEY_3, KEY_4, KEY_Q, KEY_R, KEY_I, KEY_C, KEY_J, KEY_M, KEY_T, KEY_K]
	match keycode:
		KEY_M when not world_blocked:
			if game.hud.inventory_open:
				game.hud.toggle_inventory(game.player)
			game._close_books()
			game._update_minimap()
			game.open_map()
			return true
		KEY_K when not world_blocked:
			if game.hud.skills_visible:
				game.hud.toggle_skill_tree(game.player)
			if game.hud.inventory_open:
				game.hud.toggle_inventory(game.player)
			if game.hud.journal_visible:
				game.hud.toggle_journal(game.quests, game.player)
			game.hud.toggle_bestiary(game.bestiary_entries, game.discovered_enemies)
			return true
		KEY_C when not world_blocked:
			if not game.hud.inventory_open:
				game._close_books()
			game.hud.toggle_hero_panel(game.player, game.skills)
			return true
		KEY_T when not world_blocked:
			if game.hud.inventory_open:
				game.hud.toggle_inventory(game.player)
			if game.hud.bestiary_visible:
				game.hud.toggle_bestiary(game.bestiary_entries, game.discovered_enemies)
			if game.hud.journal_visible:
				game.hud.toggle_journal(game.quests, game.player)
			game.hud.toggle_skill_tree(game.player)
			return true
		KEY_J when not world_blocked:
			if game.hud.skills_visible:
				game.hud.toggle_skill_tree(game.player)
			if game.hud.inventory_open:
				game.hud.toggle_inventory(game.player)
			if game.hud.bestiary_visible:
				game.hud.toggle_bestiary(game.bestiary_entries, game.discovered_enemies)
			game.hud.toggle_journal(game.quests, game.player)
			return true
	if game.hud.overlay_visible():
		return false
	match keycode:
		KEY_F6 when not world_blocked:
			game.save_game()
			return true
		KEY_F9 when not world_blocked:
			game.load_game()
			return true
		KEY_SPACE when not world_blocked and not game.hud.inventory_open:
			if game.player.start_dodge():
				GameAudio.play("dash", -6.0)
				game.gear.on_dodge()
			return true
		KEY_F when not world_blocked and not game.hud.inventory_open:
			if game.player.start_guard():
				game.player.visual.play_named("charge", 0.3)
			return true
		KEY_I, KEY_TAB when not world_blocked:
			game.hud.toggle_inventory(game.player)
			return true
		KEY_B when not world_blocked:
			game.open_handcraft()
			return true
	if game.hud.inventory_open:
		return false
	match keycode:
		KEY_Q:
			game._use_consumable("health_potion")
		KEY_R:
			game._use_consumable("mana_potion")
		KEY_1, KEY_2, KEY_3, KEY_4:
			if not world_blocked:
				game.skills.use_slot(keycode - KEY_1)
				game.hud.update_hotbar(game.skills.hotbar_entries())
			return true
	return false
