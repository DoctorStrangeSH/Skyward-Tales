extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BOLT_SCENE := preload("res://scenes/magic_bolt.tscn")
const NPC_SCRIPT := preload("res://scripts/npc.gd")
const COLLECTIBLE_SCRIPT := preload("res://scripts/collectible.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const LOOT_SCRIPT := preload("res://scripts/loot.gd")
const SAVE_SCRIPT := preload("res://scripts/save_system.gd")

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

func _ready() -> void:
	_load_spell_definitions()
	quests = QuestManager.new()
	player = PLAYER_SCENE.instantiate() as PlayerCharacter
	add_child(player)
	player.global_position = Vector2(130, 210)
	player.stats_changed.connect(_refresh_hud)
	player.level_up.connect(_on_level_up)

	hud = GameHud.new()
	add_child(hud)
	hud.inventory_use_requested.connect(_on_inventory_use)
	hud.inventory_unequip_requested.connect(_on_inventory_unequip)

	_spawn_elder()
	_spawn_herb(Vector2(370, 155))
	_spawn_herb(Vector2(515, 310))
	_spawn_herb(Vector2(700, 190))
	_spawn_slime(Vector2(475, 350))
	_spawn_slime(Vector2(790, 300))
	_spawn_slime(Vector2(990, 250))

	hud.show_message("Добро пожаловать в Skyward Tales! Найдите старейшину.", 5.0)
	_refresh_hud()

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
	if player == null or hud == null:
		return
	_update_spell_hud()
	nearby_interactable = _find_nearest_interactable()
	if hud.dialogue_visible or hud.inventory_open:
		hud.set_prompt("")
	elif nearby_interactable != null:
		var prompt := "E — поговорить" if nearby_interactable is WorldNpc else ("E — подобрать" if nearby_interactable is WorldLoot else "E — собрать")
		hud.set_prompt(prompt)
	else:
		hud.set_prompt("WASD — ходьба   1/2/3 — магия   ЛКМ — каст   E — подбор   Q/R — зелья   F6/F9 — сейв/загрузка")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F6 and not get_tree().paused and not hud.dialogue_visible:
			save_game()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F9 and not get_tree().paused and not hud.dialogue_visible:
			load_game()
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
		if not get_tree().paused and not hud.dialogue_visible and not hud.inventory_open:
			_cast_spell()
		get_viewport().set_input_as_handled()

func _spawn_elder() -> void:
	elder = NPC_SCRIPT.new() as WorldNpc
	elder.display_name = "Старейшина Элиан"
	add_child(elder)
	elder.global_position = Vector2(250, 205)
	elder.interacted.connect(_on_elder_interacted)

func _spawn_herb(spawn_position: Vector2) -> void:
	var herb := COLLECTIBLE_SCRIPT.new() as WorldCollectible
	add_child(herb)
	herb.global_position = spawn_position
	herb.interacted.connect(_on_herb_interacted)

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
		_show_dialogue("Старейшина Элиан", "Ты помог нашему поселению. Но лес хранит куда больше тайн, чем кажется...")
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
	if quests.active_quest_id == "moonleaf_gathering" and not quests.is_completed("moonleaf_gathering"):
		quests.add_progress("moonleaf_gathering", 1)
		source.queue_free()
		hud.show_message("Лунный лист собран.", 1.5)
		if quests.is_ready_to_complete("moonleaf_gathering"):
			hud.show_message("Собраны все листья! Вернитесь к старейшине.", 3.0)
	else:
		hud.show_message("Лунный лист. Поговорите со старейшиной, чтобы узнать, зачем он нужен.", 2.5)
	_refresh_hud()

func _on_enemy_defeated(xp_reward: int, death_position: Vector2) -> void:
	player.add_experience(xp_reward)
	defeated_enemies += 1
	var drops: Array[String] = ["apprentice_staff", "leather_armor", "mana_amulet"]
	_spawn_loot(death_position, drops[(defeated_enemies - 1) % 3] if defeated_enemies <= 3 else ("health_potion" if defeated_enemies % 2 == 1 else "mana_potion"))
	hud.show_message("Слизень побеждён! +%d опыта" % xp_reward, 1.5)

func _spawn_loot(drop_position: Vector2, item_id: String) -> void:
	var loot := LOOT_SCRIPT.new() as WorldLoot
	loot.item_id = item_id
	loot.item_name = item_id
	loot.position = drop_position
	add_child(loot)
	loot.collected.connect(_on_loot_collected)

func _on_loot_collected(item_id: String, amount: int) -> void:
	player.add_item(item_id, amount)
	var names: Dictionary = {"health_potion": "Зелье здоровья", "mana_potion": "Зелье маны", "apprentice_staff": "Посох ученика", "leather_armor": "Кожаная броня", "mana_amulet": "Амулет маны"}
	hud.show_message("Получено: %s ×%d" % [names.get(item_id, item_id), amount], 2.0)

func _on_inventory_unequip(slot: String) -> void:
	if hud.dialogue_visible or get_tree().paused:
		return
	if player.unequip_slot(slot):
		hud.show_message("Экипировка снята.", 1.5)

func _on_inventory_use(item_id: String) -> void:
	if item_id in ["apprentice_staff", "leather_armor", "mana_amulet"]:
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
	hud.show_message("НОВЫЙ УРОВЕНЬ: %d! Здоровье и мана восстановлены." % new_level, 3.0)

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
	var spell_damage := int(spell.get("damage", 18)) + player.get_spell_bonus()
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
	bolt.chain_targets = int(spell.get("chain_targets", 0))
	bolt.chain_radius = float(spell.get("chain_radius", 0.0))
	bolt.chain_damage_factor = float(spell.get("chain_damage_factor", 0.65))
	add_child(bolt)
	bolt.global_position = player.global_position + direction * 12.0
	cast_cooldown_total = float(spell.get("cooldown", 0.25))
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

func make_save_snapshot() -> Dictionary:
	var alive_enemies: Array = []
	var herbs: Array = []
	var loot_items: Array = []
	for node in get_children():
		if node.is_queued_for_deletion():
			continue
		if node is SlimeEnemy:
			alive_enemies.append({"position": _position_array(node.global_position), "hp": node.health, "home": _position_array(node.home_position)})
		elif node is WorldCollectible:
			herbs.append(_position_array(node.global_position))
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
			"equipment": player.equipment.duplicate(true)
		},
		"quest": {"states": quests.states.duplicate(true), "active": quests.active_quest_id},
		"world": {"enemies": alive_enemies, "herbs": herbs, "loot": loot_items, "defeated": defeated_enemies},
		"magic": selected_spell_id
	}

func save_game() -> bool:
	var success: bool = SAVE_SCRIPT.save_snapshot(make_save_snapshot(), save_path)
	if hud != null:
		hud.show_message("Игра сохранена (F9 — загрузить)" if success else "Ошибка сохранения!", 2.0)
	return success

func load_game() -> bool:
	var data: Dictionary = SAVE_SCRIPT.load_snapshot(save_path)
	if data.is_empty():
		if hud != null:
			hud.show_message("Сохранение не найдено или повреждено.", 2.0)
		return false
	return restore_save_snapshot(data)

func restore_save_snapshot(data: Dictionary) -> bool:
	if not data.get("player") is Dictionary or not data.get("quest") is Dictionary or not data.get("world") is Dictionary:
		return false
	var character: Dictionary = data["player"]
	var quest_data: Dictionary = data["quest"]
	var world_data: Dictionary = data["world"]
	# Validate structure before changing existing game state.
	if not character.get("inventory") is Dictionary or not character.get("equipment") is Dictionary:
		return false
	if not quest_data.get("states") is Dictionary:
		return false
	if not world_data.get("enemies") is Array or not world_data.get("herbs") is Array or not world_data.get("loot") is Array:
		return false
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
	player.health = clampi(int(character.get("health", player.max_health)), 0, player.max_health)
	player.mana = clampi(int(character.get("mana", player.max_mana)), 0, player.max_mana)
	player.inventory = character["inventory"].duplicate(true)
	player.equipment = character["equipment"].duplicate(true)
	player.global_position = _read_position(character.get("position"), Vector2(130, 210))
	# Recreate dynamic world state; queued old nodes must be removed from scene tree immediately.
	for node in get_children():
		if node is SlimeEnemy or node is WorldCollectible or node is WorldLoot or node is MagicBolt:
			remove_child(node)
			node.queue_free()
	for herb_pos in world_data["herbs"]:
		_spawn_herb(_read_position(herb_pos, Vector2.ZERO))
	for enemy_data in world_data["enemies"]:
		if not enemy_data is Dictionary:
			continue
		_spawn_slime(_read_position(enemy_data.get("position"), Vector2(475, 350)))
		var enemy: SlimeEnemy = get_child(get_child_count() - 1) as SlimeEnemy
		if enemy != null:
			enemy.health = clampi(int(enemy_data.get("hp", enemy.max_health)), 1, enemy.max_health)
			enemy.home_position = _read_position(enemy_data.get("home"), enemy.global_position)
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
	player.stats_changed.emit()
	_refresh_hud()
	hud.show_message("Прогресс загружен!", 2.0)
	return true
