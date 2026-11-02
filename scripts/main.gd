extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BOLT_SCENE := preload("res://scenes/magic_bolt.tscn")
const NPC_SCRIPT := preload("res://scripts/npc.gd")
const COLLECTIBLE_SCRIPT := preload("res://scripts/collectible.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const LOOT_SCRIPT := preload("res://scripts/loot.gd")
const SAVE_SCRIPT := preload("res://scripts/save_system.gd")
const GATE_SCRIPT := preload("res://scripts/region_gate.gd")
const WOLF_SCRIPT := preload("res://scripts/forest_wolf.gd")
const SHAMAN_SCRIPT := preload("res://scripts/forest_shaman.gd")
const GUARDIAN_SCRIPT := preload("res://scripts/grove_guardian.gd")

var player: PlayerCharacter
var hud: GameHud
var quests: QuestManager
var elder: WorldNpc
var nearby_interactable: Node2D
var spell_definitions: Dictionary = {}
var cast_cooldown_remaining: float = 0.0
var selected_spell_id: String = "fireball"
var cast_cooldown_total: float = 0.0
var defeated_enemies: int = 0
var save_path: String = SAVE_SCRIPT.SAVE_PATH
var world: Node2D
var current_region: String = "greenreach"
var guardian_defeated: bool = false
var game_over: bool = false
var talent_definitions: Dictionary = {}
var pending_level_choices: Array[int] = []
var bestiary_entries: Dictionary = {}
var discovered_enemies: Dictionary = {}
var discovered_landmarks: Dictionary = {}

func _ready() -> void:
	_load_spell_definitions()
	_load_talent_definitions()
	_load_bestiary_entries()
	world = get_node("World") as Node2D
	quests = QuestManager.new()
	player = PLAYER_SCENE.instantiate() as PlayerCharacter
	add_child(player)
	player.global_position = Vector2(130, 210)
	player.stats_changed.connect(_refresh_hud)
	player.level_up.connect(_on_level_up)
	player.died.connect(_on_player_died)

	hud = GameHud.new()
	add_child(hud)
	hud.inventory_use_requested.connect(_on_inventory_use)
	hud.inventory_unequip_requested.connect(_on_inventory_unequip)
	hud.pause_save_requested.connect(save_game)
	hud.pause_load_requested.connect(load_game)
	hud.pause_menu_requested.connect(_go_to_title)
	hud.defeat_restart_requested.connect(_restart_run)
	hud.defeat_load_requested.connect(_load_from_defeat)
	hud.defeat_menu_requested.connect(_go_to_title)
	hud.talent_selected.connect(_on_talent_selected)

	_populate_region()

	if get_tree().has_meta("skyward_continue") and bool(get_tree().get_meta("skyward_continue")):
		get_tree().remove_meta("skyward_continue")
		load_game()
	else:
		hud.show_message("Добро пожаловать в Skyward Tales! Найдите старейшину.", 5.0)
	_refresh_hud()

func _load_bestiary_entries() -> void:
	var file := FileAccess.open("res://data/bestiary.json", FileAccess.READ)
	if file == null:
		push_warning("Каталог бестиария не найден.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		bestiary_entries = parsed

func _load_talent_definitions() -> void:
	var file := FileAccess.open("res://data/talents.json", FileAccess.READ)
	if file == null:
		push_warning("Каталог талантов не найден.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		talent_definitions = parsed

func _load_spell_definitions() -> void:
	var file := FileAccess.open("res://data/spells.json", FileAccess.READ)
	if file == null:
		push_warning("Каталог заклинаний не найден — используются значения по умолчанию.")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		spell_definitions = parsed

func _process(delta: float) -> void:
	cast_cooldown_remaining = maxf(0.0, cast_cooldown_remaining - delta)
	if player == null or hud == null or game_over:
		return
	_update_spell_hud()
	_discover_nearby_enemies()
	_update_minimap()
	hud.update_dodge(player.dodge_cooldown_left, player.dodge_cooldown, player.dodge_time_left > 0.0)
	nearby_interactable = _find_nearest_interactable()
	if hud.dialogue_visible or hud.inventory_open or hud.bestiary_visible or hud.world_map_visible:
		hud.set_prompt("")
	elif nearby_interactable != null:
		var prompt := "E — поговорить" if nearby_interactable is WorldNpc else ("E — перейти" if nearby_interactable is RegionGate else ("E — подобрать" if nearby_interactable is WorldLoot else "E — собрать"))
		hud.set_prompt(prompt)
	else:
		hud.set_prompt("WASD — ходьба   Shift — рывок   1/2/3 — магия   ЛКМ — каст   E — подбор   Q/R — зелья   K — бестиарий   M — карта   F6/F9 — сейв/загрузка")

func _update_minimap() -> void:
	var region_markers: Dictionary = discovered_landmarks.get(current_region, {})
	for actor in get_children():
		if not (actor is WorldNpc or actor is RegionGate):
			continue
		if player.global_position.distance_squared_to(actor.global_position) > 150.0 * 150.0:
			continue
		var kind: String = "gate" if actor is RegionGate else "npc"
		var marker_id: String = "%s_%d_%d" % [kind, int(actor.global_position.x), int(actor.global_position.y)]
		if not region_markers.has(marker_id):
			region_markers[marker_id] = {"position": [actor.global_position.x, actor.global_position.y], "kind": kind}
	discovered_landmarks[current_region] = region_markers
	hud.minimap.update_map(current_region, player.global_position, region_markers)

func _discover_nearby_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is SlimeEnemy or enemy.is_queued_for_deletion():
			continue
		if player.global_position.distance_squared_to(enemy.global_position) > 180.0 * 180.0:
			continue
		var kind: String = _enemy_kind(enemy)
		if not discovered_enemies.has(kind):
			discovered_enemies[kind] = true
			hud.show_message("Бестиарий: %s! Откройте книгу клавишей K." % str(bestiary_entries.get(kind, {}).get("name", kind)), 2.5)

func _enemy_kind(enemy: SlimeEnemy) -> String:
	if enemy is GroveGuardian:
		return "guardian"
	if enemy is ForestShaman:
		return "shaman"
	if enemy is ForestWolf:
		return "wolf"
	return "slime"

func _input(event: InputEvent) -> void:
	if game_over or (hud != null and (hud.talent_visible or hud.defeat_visible)):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M and not get_tree().paused and not hud.dialogue_visible:
			if hud.inventory_open:
				hud.toggle_inventory(player)
			if hud.bestiary_visible:
				hud.toggle_bestiary(bestiary_entries, discovered_enemies)
			_update_minimap()
			hud.open_world_map(current_region, player.global_position, discovered_landmarks.get(current_region, {}), quests.get_active_summary())
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_K and not get_tree().paused and not hud.dialogue_visible:
			if hud.inventory_open:
				hud.toggle_inventory(player)
			hud.toggle_bestiary(bestiary_entries, discovered_enemies)
			get_viewport().set_input_as_handled()
			return
		if hud.bestiary_visible:
			return
		if event.keycode == KEY_F6 and not get_tree().paused and not hud.dialogue_visible:
			save_game()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F9 and not get_tree().paused and not hud.dialogue_visible:
			load_game()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_SHIFT and not get_tree().paused and not hud.dialogue_visible and not hud.inventory_open:
			player.start_dodge()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_I and not get_tree().paused and not hud.dialogue_visible:
			hud.toggle_inventory(player)
			get_viewport().set_input_as_handled()
			return
		if hud.inventory_open:
			return
		if event.keycode == KEY_Q:
			_use_consumable("health_potion", "Зелье здоровья")
		elif event.keycode == KEY_R:
			_use_consumable("mana_potion", "Зелье маны")
		elif event.keycode == KEY_1:
			select_spell("fireball")
		elif event.keycode == KEY_2:
			select_spell("frostbolt")
		elif event.keycode == KEY_3:
			select_spell("chain_lightning")
	# _input receives mouse clicks even when a Control overlays the world.
	if event.is_action_pressed("interact"):
		if hud.dialogue_visible:
			hud.close_dialogue()
			player.set_physics_process(true)
		else:
			_try_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cast_spell"):
		if not get_tree().paused and not hud.dialogue_visible and not hud.inventory_open and not hud.bestiary_visible:
			_cast_spell()
		get_viewport().set_input_as_handled()

func _populate_region() -> void:
	if current_region == "moonlit_grove":
		_spawn_grove_warden()
		_spawn_herb(Vector2(330, 315), "spirit_blossom", "Духовный цветок")
		_spawn_herb(Vector2(680, 505), "spirit_blossom", "Духовный цветок")
		_spawn_herb(Vector2(1080, 390), "spirit_blossom", "Духовный цветок")
		_spawn_wolf(Vector2(470, 430))
		_spawn_wolf(Vector2(900, 290))
		_spawn_shaman(Vector2(730, 360))
		if quests.is_completed("grove_spirits") and not guardian_defeated:
			_spawn_guardian(Vector2(1020, 580))
		_spawn_gate("greenreach", Vector2(1120, 205), Vector2(1080, 205), "Возврат к Зелёным Пределам")
	else:
		_spawn_elder()
		_spawn_herb(Vector2(370, 155))
		_spawn_herb(Vector2(515, 310))
		_spawn_herb(Vector2(700, 190))
		_spawn_slime(Vector2(475, 350))
		_spawn_slime(Vector2(790, 300))
		_spawn_slime(Vector2(990, 250))
		_spawn_gate("moonlit_grove", Vector2(1120, 205), Vector2(140, 430), "Тропа в Зачарованный лес")

func _clear_region_actors() -> void:
	for node in get_children():
		if node is WorldNpc or node is WorldCollectible or node is SlimeEnemy or node is WorldLoot or node is RegionGate or node is MagicBolt or node is EnemyMagicOrb:
			remove_child(node)
			node.queue_free()
	elder = null
	nearby_interactable = null

func _set_region(region_id: String, arrival: Vector2, notify: bool = true) -> void:
	current_region = "moonlit_grove" if region_id == "moonlit_grove" else "greenreach"
	_clear_region_actors()
	if world != null and world.has_method("configure_region"):
		world.configure_region(current_region)
	_populate_region()
	player.global_position = arrival
	if notify and hud != null:
		hud.show_message("Локация: " + ("Зачарованный лес" if current_region == "moonlit_grove" else "Зелёные Пределы"), 2.5)
	_refresh_hud()

func _spawn_gate(target_region: String, gate_position: Vector2, arrival: Vector2, label: String) -> void:
	var gate := GATE_SCRIPT.new() as RegionGate
	gate.target_region = target_region
	gate.arrival_position = arrival
	gate.display_name = label
	add_child(gate)
	gate.global_position = gate_position
	gate.travel_requested.connect(_on_region_travel)

func _on_region_travel(target_region: String, arrival: Vector2) -> void:
	if target_region == "moonlit_grove" and not quests.is_completed("moonleaf_gathering"):
		hud.show_message("Сначала помогите старейшине с лунными листьями.", 2.5)
		return
	_set_region(target_region, arrival)

func _spawn_grove_warden() -> void:
	var warden := NPC_SCRIPT.new() as WorldNpc
	warden.display_name = "Хранительница Илара"
	add_child(warden)
	warden.global_position = Vector2(250, 420)
	warden.interacted.connect(_on_grove_warden_interacted)

func _on_grove_warden_interacted(_source: Node2D) -> void:
	if quests.is_completed("grove_spirits"):
		_show_dialogue("Хранительница Илара", "Духи снова поют. Лес запомнит твою доброту.")
	elif quests.active_quest_id.is_empty() or quests.active_quest_id == "grove_spirits":
		if not quests.states["grove_spirits"]["started"]:
			quests.start_quest("grove_spirits")
			_show_dialogue("Хранительница Илара", "Лес теряет свой свет. Собери три духовных цветка у старых камней и принеси их мне.")
		elif quests.is_ready_to_complete("grove_spirits"):
			quests.complete_quest("grove_spirits")
			player.add_experience(90)
			player.add_gold(50)
			_spawn_guardian(Vector2(1020, 580))
			_show_dialogue("Хранительница Илара", "Ты вернул лесу его сияние. Прими эту награду.")
		else:
			_show_dialogue("Хранительница Илара", "Ищи духовные цветы вдоль древней тропы. Их свет виден даже в сумерках.")
	else:
		_show_dialogue("Хранительница Илара", "Заверши начатое дело, прежде чем браться за новое.")
	_refresh_hud()

func _spawn_elder() -> void:
	elder = NPC_SCRIPT.new() as WorldNpc
	elder.display_name = "Старейшина Элиан"
	add_child(elder)
	elder.global_position = Vector2(250, 205)
	elder.interacted.connect(_on_elder_interacted)

func _spawn_herb(spawn_position: Vector2, item_id: String = "moonleaf", label: String = "Лунный лист") -> void:
	var herb := COLLECTIBLE_SCRIPT.new() as WorldCollectible
	herb.item_id = item_id
	herb.display_name = label
	add_child(herb)
	herb.global_position = spawn_position
	herb.interacted.connect(_on_herb_interacted)

func _spawn_guardian(spawn_position: Vector2) -> void:
	if guardian_defeated:
		return
	for actor in get_children():
		if actor is GroveGuardian and not actor.is_queued_for_deletion():
			return
	var boss := GUARDIAN_SCRIPT.new() as GroveGuardian
	boss.position = spawn_position
	add_child(boss)
	boss.defeated.connect(func(xp: int) -> void: _on_guardian_defeated(xp, boss.global_position))

func _on_guardian_defeated(xp: int, death_position: Vector2) -> void:
	if guardian_defeated:
		return
	guardian_defeated = true
	player.add_experience(xp)
	player.add_gold(100)
	_spawn_loot(death_position, "ancient_relic")
	hud.show_message("Хранитель побеждён! +100 золота. Древний артефакт ждёт!", 3.5)

func _spawn_shaman(spawn_position: Vector2) -> void:
	var shaman := SHAMAN_SCRIPT.new() as ForestShaman
	shaman.position = spawn_position
	add_child(shaman)
	shaman.defeated.connect(func(xp: int) -> void: _on_enemy_defeated(xp, shaman.global_position))

func _spawn_wolf(spawn_position: Vector2) -> void:
	var wolf := WOLF_SCRIPT.new() as ForestWolf
	wolf.position = spawn_position
	add_child(wolf)
	wolf.defeated.connect(func(xp: int) -> void: _on_enemy_defeated(xp, wolf.global_position))

func _spawn_slime(spawn_position: Vector2) -> void:
	var slime := ENEMY_SCRIPT.new() as SlimeEnemy
	slime.position = spawn_position
	add_child(slime)
	slime.defeated.connect(func(xp: int) -> void: _on_enemy_defeated(xp, spawn_position))

func _find_nearest_interactable() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := 28.0
	for candidate in get_tree().get_nodes_in_group("interactables"):
		var candidate_2d := candidate as Node2D
		if candidate_2d == null or not is_instance_valid(candidate_2d):
			continue
		var distance := player.global_position.distance_to(candidate_2d.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate_2d
	return nearest

func _try_interact() -> void:
	var target := _find_nearest_interactable()
	if target == null:
		hud.show_message("Здесь пока нечего исследовать.", 1.5)
		return
	if target.has_method("interact"):
		target.interact()

func _show_dialogue(speaker: String, message: String) -> void:
	player.set_physics_process(false)
	hud.show_dialogue(speaker, message)

func _on_elder_interacted(_source: Node2D) -> void:
	if quests.is_completed("moonleaf_gathering"):
		_show_dialogue("Старейшина Элиан", "Ты помог нашему поселению. На востоке есть тропа в Зачарованный лес. Найди хранительницу Илару — возможно, ей нужна помощь.")
	elif quests.active_quest_id.is_empty():
		quests.start_quest("moonleaf_gathering")
		_show_dialogue("Старейшина Элиан", "Юный странник, ночной туман отравляет наш лес. Принеси мне три лунных листа — они растут вдоль старой тропы. Я щедро тебя отблагодарю.")
	elif quests.is_ready_to_complete("moonleaf_gathering"):
		quests.complete_quest("moonleaf_gathering")
		player.add_experience(50)
		player.add_gold(25)
		_show_dialogue("Старейшина Элиан", "Ты принёс все три! Пусть древние звёзды хранят тебя. Прими эти монеты и знания.")
	else:
		_show_dialogue("Старейшина Элиан", "Лунные листья растут вдоль старой тропы. Будь осторожен — слизни стали агрессивнее.")
	_refresh_hud()

func _on_herb_interacted(source: Node2D) -> void:
	var herb := source as WorldCollectible
	var required_quest: String = "grove_spirits" if current_region == "moonlit_grove" else "moonleaf_gathering"
	if herb == null:
		return
	if quests.active_quest_id == required_quest and not quests.is_completed(required_quest):
		quests.add_progress(required_quest, 1)
		source.queue_free()
		hud.show_message(herb.display_name + " собран.", 1.5)
		if quests.is_ready_to_complete(required_quest):
			hud.show_message("Все предметы собраны! Вернитесь к хранителю.", 3.0)
	else:
		hud.show_message(herb.display_name + ". Поговорите с местным хранителем, чтобы узнать, зачем он нужен.", 2.5)
	_refresh_hud()

func _on_enemy_defeated(xp_reward: int, death_position: Vector2) -> void:
	player.add_experience(xp_reward)
	defeated_enemies += 1
	var drops: Array[String] = ["apprentice_staff", "leather_armor", "mana_amulet"]
	_spawn_loot(death_position, drops[(defeated_enemies - 1) % 3] if defeated_enemies <= 3 else ("health_potion" if defeated_enemies % 2 == 1 else "mana_potion"))
	hud.show_message("Противник побеждён! +%d опыта" % xp_reward, 1.5)

func _spawn_loot(drop_position: Vector2, item_id: String) -> void:
	var loot := LOOT_SCRIPT.new() as WorldLoot
	loot.item_id = item_id
	loot.item_name = item_id
	loot.position = drop_position
	add_child(loot)
	loot.collected.connect(_on_loot_collected)

func _on_loot_collected(item_id: String, amount: int) -> void:
	player.add_item(item_id, amount)
	var names: Dictionary = {"health_potion": "Зелье здоровья", "mana_potion": "Зелье маны", "apprentice_staff": "Посох ученика", "leather_armor": "Кожаная броня", "mana_amulet": "Амулет маны", "ancient_relic": "Древний артефакт"}
	hud.show_message("Получено: %s ×%d" % [names.get(item_id, item_id), amount], 2.0)

func _on_inventory_unequip(slot: String) -> void:
	if hud.dialogue_visible or get_tree().paused:
		return
	if player.unequip_slot(slot):
		hud.show_message("Экипировка снята.", 1.5)

func _on_inventory_use(item_id: String) -> void:
	if item_id in ["apprentice_staff", "leather_armor", "mana_amulet"] :
		if player.equip_item(item_id):
			hud.show_message("Предмет экипирован!", 1.5)
		else:
			hud.show_message("Невозможно экипировать.", 1.5)
		return
	var label: String = "Зелье здоровья" if item_id == "health_potion" else "Зелье маны"
	_use_consumable(item_id, label)

func _use_consumable(item_id: String, label: String) -> void:
	if hud == null or hud.dialogue_visible or get_tree().paused:
		return
	if player.use_item(item_id):
		hud.show_message("Использовано: " + label, 1.5)
	else:
		hud.show_message("Нет зелья или восстановление не требуется.", 1.5)

func _on_level_up(new_level: int) -> void:
	pending_level_choices.append(new_level)
	if hud != null and not game_over:
		hud.show_message("НОВЫЙ УРОВЕНЬ: %d! Здоровье и мана восстановлены." % new_level, 2.5)
		_present_next_level_choice()

func _present_next_level_choice() -> void:
	if pending_level_choices.is_empty() or game_over or hud == null or hud.talent_visible:
		return
	var available: Array[Dictionary] = []
	for talent_id in talent_definitions:
		var definition: Dictionary = talent_definitions[talent_id]
		var rank: int = int(player.talents.get(talent_id, 0))
		var maximum: int = int(definition.get("max_rank", 3))
		if rank < maximum:
			available.append({
				"id": str(talent_id),
				"name": str(definition.get("name", talent_id)),
				"description": str(definition.get("description", "")),
				"rank": rank,
				"max_rank": maximum
			})
	if available.is_empty():
		pending_level_choices.clear()
		hud.show_message("Все таланты изучены. Следующий уровень принесёт новые возможности.", 3.0)
		return
	available.shuffle()
	var choices: Array[Dictionary] = []
	for index in range(mini(3, available.size())):
		choices.append(available[index])
	hud.show_talent_choices(choices)
	get_tree().paused = true

func _on_talent_selected(talent_id: String) -> void:
	if not hud.talent_visible or not player.apply_talent(talent_id):
		return
	if not pending_level_choices.is_empty():
		pending_level_choices.pop_front()
	hud.hide_talent_choices()
	if pending_level_choices.is_empty():
		get_tree().paused = false
		hud.show_message("Талант изучен: " + str(talent_definitions.get(talent_id, {}).get("name", talent_id)), 2.5)
	else:
		_present_next_level_choice()
	_refresh_hud()

func _update_spell_hud() -> void:
	var spell: Dictionary = spell_definitions.get(selected_spell_id, {})
	hud.update_spell(str(spell.get("name", selected_spell_id)), int(spell.get("mana_cost", 0)), player.mana, cast_cooldown_remaining, cast_cooldown_total)

func select_spell(spell_id: String) -> void:
	if not spell_definitions.has(spell_id):
		return
	selected_spell_id = spell_id
	var data: Dictionary = spell_definitions[spell_id]
	hud.show_message("Магия: " + str(data.get("name", spell_id)), 1.5)
	_update_spell_hud()

func _cast_spell() -> void:
	if cast_cooldown_remaining > 0.0:
		return
	var spell: Dictionary = spell_definitions.get(selected_spell_id, {})
	var mana_cost := int(spell.get("mana_cost", 8))
	var spell_damage := int(spell.get("damage", 18)) + player.get_spell_bonus(selected_spell_id)
	if not player.spend_mana(mana_cost):
		hud.show_message("Недостаточно маны.", 1.2)
		return
	var direction := (get_global_mouse_position() - player.global_position).normalized()
	if direction.length_squared() < 0.01:
		direction = player.facing
	var bolt := BOLT_SCENE.instantiate() as MagicBolt
	if bolt == null:
		push_error("Не удалось создать огненный шар")
		return
	bolt.speed = float(spell.get("projectile_speed", 255))
	bolt.setup(direction, spell_damage)
	bolt.configure_effect(selected_spell_id, float(spell.get("slow_multiplier", 1.0)), float(spell.get("slow_duration", 0.0)))
	bolt.configure_burning(int(spell.get("burn_damage", 0)), float(spell.get("burn_duration", 0.0)))
	bolt.chain_targets = int(spell.get("chain_targets", 0))
	bolt.chain_radius = float(spell.get("chain_radius", 0.0))
	bolt.chain_damage_factor = float(spell.get("chain_damage_factor", 0.65))
	add_child(bolt)
	bolt.global_position = player.global_position + direction * 12.0
	cast_cooldown_total = float(spell.get("cooldown", 0.25)) * player.get_cooldown_multiplier()
	cast_cooldown_remaining = cast_cooldown_total
	_update_spell_hud()

func _refresh_hud() -> void:
	if hud != null and player != null and quests != null:
		hud.update_status(player, quests)

func _position_array(pos: Vector2) -> Array[float]:
	return [pos.x, pos.y]

func _read_position(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	pending_level_choices.clear()
	if hud != null:
		hud.hide_talent_choices()
		hud.show_defeat(not SAVE_SCRIPT.load_snapshot(save_path).is_empty())
	get_tree().paused = true

func _restart_run() -> void:
	get_tree().paused = false
	game_over = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _load_from_defeat() -> void:
	load_game()

func make_save_snapshot() -> Dictionary:
	var alive_enemies: Array = []
	var herbs: Array = []
	var loot_items: Array = []
	for node in get_children():
		if node.is_queued_for_deletion():
			continue
		if node is SlimeEnemy:
			var kind: String = "guardian" if node is GroveGuardian else ("shaman" if node is ForestShaman else ("wolf" if node is ForestWolf else "slime"))
			alive_enemies.append({"position": _position_array(node.global_position), "hp": node.health, "home": _position_array(node.home_position), "kind": kind, "burn_remaining": node.burn_time_left, "burn_tick": node.burn_tick_timer, "burn_damage": node.burn_damage})
		elif node is WorldCollectible:
			herbs.append({"position": _position_array(node.global_position), "id": node.item_id, "name": node.display_name})
		elif node is WorldLoot:
			loot_items.append({"position": _position_array(node.global_position), "id": node.item_id, "amount": node.amount})
	return {
		"player": {
			"position": _position_array(player.global_position),
			"health": player.health, "max_health": player.max_health,
			"mana": player.mana, "max_mana": player.max_mana,
			"level": player.level, "experience": player.experience,
			"experience_to_next": player.experience_to_next,
			"gold": player.gold,
			"inventory": player.inventory.duplicate(true),
			"equipment": player.equipment.duplicate(true),
			"talents": player.talents.duplicate(true)
		},
		"quest": {"states": quests.states.duplicate(true), "active": quests.active_quest_id},
		"world": {"region": current_region, "enemies": alive_enemies, "herbs": herbs, "loot": loot_items, "defeated": defeated_enemies, "guardian_defeated": guardian_defeated, "discovered": discovered_enemies.duplicate(true), "landmarks": discovered_landmarks.duplicate(true)},
		"magic": selected_spell_id
	}

func save_game() -> bool:
	if game_over:
		if hud != null:
			hud.set_defeat_message("После поражения нельзя перезаписать сохранение. Загрузите прежний прогресс или начните заново.")
		return false
	var success: bool = SAVE_SCRIPT.save_snapshot(make_save_snapshot(), save_path)
	if hud != null:
		hud.show_message("Игра сохранена (F9 — загрузить)" if success else "Ошибка сохранения!", 2.0)
	return success

func load_game() -> bool:
	var data: Dictionary = SAVE_SCRIPT.load_snapshot(save_path)
	if data.is_empty():
		if game_over and hud != null:
			hud.set_defeat_message("Сохранение не найдено или повреждено. Можно начать новое приключение.")
		elif hud != null:
			hud.show_message("Сохранение не найдено или повреждено.", 2.0)
		return false
	var recovering_from_defeat: bool = game_over
	if recovering_from_defeat:
		get_tree().paused = false
		game_over = false
	var restored: bool = restore_save_snapshot(data)
	if restored:
		if hud != null:
			hud.hide_defeat()
	elif recovering_from_defeat:
		game_over = true
		get_tree().paused = true
		if hud != null:
			hud.set_defeat_message("Не удалось восстановить сохранение. Попробуйте начать заново.")
	return restored

func restore_save_snapshot(data: Dictionary) -> bool:
	if not data.get("player") is Dictionary or not data.get("quest") is Dictionary or not data.get("world") is Dictionary:
		return false
	var character: Dictionary = data["player"]
	var quest_data: Dictionary = data["quest"]
	var world_data: Dictionary = data["world"]
	# Validate structure before changing existing game state.
	if not character.get("inventory") is Dictionary or not character.get("equipment") is Dictionary or (character.has("talents") and not character.get("talents") is Dictionary):
		return false
	if not quest_data.get("states") is Dictionary:
		return false
	if not world_data.get("enemies") is Array or not world_data.get("herbs") is Array or not world_data.get("loot") is Array:
		return false
	guardian_defeated = bool(world_data.get("guardian_defeated", false))
	discovered_enemies = world_data.get("discovered", {}).duplicate(true)
	discovered_landmarks = world_data.get("landmarks", {}).duplicate(true)
	var saved_region: String = str(world_data.get("region", "greenreach"))
	_set_region(saved_region, _read_position(character.get("position"), Vector2(130, 210)), false)
	for quest_id in quest_data["states"]:
		if quests.states.has(quest_id) and quest_data["states"][quest_id] is Dictionary:
			quests.states[quest_id] = quest_data["states"][quest_id].duplicate(true)
	quests.active_quest_id = str(quest_data.get("active", ""))
	player.level = maxi(1, int(character.get("level", 1)))
	player.experience = maxi(0, int(character.get("experience", 0)))
	player.experience_to_next = maxi(1, int(character.get("experience_to_next", 40)))
	player.gold = maxi(0, int(character.get("gold", 0)))
	player.max_health = maxi(1, int(character.get("max_health", 100)))
	player.max_mana = maxi(1, int(character.get("max_mana", 60)))
	player.health = clampi(int(character.get("health", player.max_health)), 1, player.max_health)
	player.mana = clampi(int(character.get("mana", player.max_mana)), 0, player.max_mana)
	player.inventory = character["inventory"].duplicate(true)
	player.equipment = character["equipment"].duplicate(true)
	player.talents = character.get("talents", {}).duplicate(true)
	pending_level_choices.clear()
	if hud.talent_visible:
		hud.hide_talent_choices()
	player.global_position = _read_position(character.get("position"), Vector2(130, 210))
	# Recreate dynamic world state; queued old nodes must be removed from scene tree immediately.
	for node in get_children():
		if node is SlimeEnemy or node is WorldCollectible or node is WorldLoot or node is MagicBolt or node is EnemyMagicOrb:
			remove_child(node)
			node.queue_free()
	for herb_data in world_data["herbs"]:
		if herb_data is Dictionary:
			_spawn_herb(_read_position(herb_data.get("position"), Vector2.ZERO), str(herb_data.get("id", "moonleaf")), str(herb_data.get("name", "Лунный лист")))
		else:
			_spawn_herb(_read_position(herb_data, Vector2.ZERO))
	for enemy_data in world_data["enemies"]:
		if not enemy_data is Dictionary:
			continue
		var enemy_kind: String = str(enemy_data.get("kind", "wolf" if current_region == "moonlit_grove" else "slime"))
		if enemy_kind == "guardian":
			_spawn_guardian(_read_position(enemy_data.get("position"), Vector2(1020, 580)))
		elif enemy_kind == "shaman":
			_spawn_shaman(_read_position(enemy_data.get("position"), Vector2(730, 360)))
		elif enemy_kind == "wolf":
			_spawn_wolf(_read_position(enemy_data.get("position"), Vector2(475, 430)))
		else:
			_spawn_slime(_read_position(enemy_data.get("position"), Vector2(475, 350)))
		var enemy: SlimeEnemy = get_child(get_child_count() - 1) as SlimeEnemy
		if enemy != null:
			enemy.health = clampi(int(enemy_data.get("hp", enemy.max_health)), 1, enemy.max_health)
			if enemy is GroveGuardian and enemy.health <= enemy.max_health / 2:
				(enemy as GroveGuardian).enraged = true
				enemy.move_speed = 44.0
				enemy.attack_cooldown_duration = 1.2
			enemy.home_position = _read_position(enemy_data.get("home"), enemy.global_position)
			enemy.burn_time_left = maxf(0.0, float(enemy_data.get("burn_remaining", 0.0)))
			enemy.burn_damage = maxi(0, int(enemy_data.get("burn_damage", 0)))
			enemy.burn_tick_timer = clampf(float(enemy_data.get("burn_tick", 0.5)), 0.001, enemy.burn_tick_interval)
	for loot_data in world_data["loot"]:
		if not loot_data is Dictionary:
			continue
		_spawn_loot(_read_position(loot_data.get("position"), Vector2.ZERO), str(loot_data.get("id", "health_potion")))
		var drop: WorldLoot = get_child(get_child_count() - 1) as WorldLoot
		if drop != null:
			drop.amount = maxi(1, int(loot_data.get("amount", 1)))
	defeated_enemies = maxi(0, int(world_data.get("defeated", 0)))
	var spell_id: String = str(data.get("magic", "fireball"))
	if spell_definitions.has(spell_id):
		selected_spell_id = spell_id
	cast_cooldown_remaining = 0.0
	cast_cooldown_total = 0.0
	if hud.inventory_open:
		hud.toggle_inventory(player)
	if hud.bestiary_visible:
		hud.toggle_bestiary(bestiary_entries, discovered_enemies)
	player.stats_changed.emit()
	_update_minimap()
	_refresh_hud()
	hud.show_message("Прогресс загружен!", 2.0)
	return true

func _go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_menu.tscn")
