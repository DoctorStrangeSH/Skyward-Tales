extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BOLT_SCENE := preload("res://scenes/magic_bolt.tscn")
const SPRITE_ARCHIVE := preload("res://scripts/sprite_archive.gd")
const NPC_SCRIPT := preload("res://scripts/npc.gd")
const COLLECTIBLE_SCRIPT := preload("res://scripts/collectible.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")

var player: PlayerCharacter
var hud: GameHud
var quests: QuestManager
var elder: WorldNpc
var nearby_interactable: Node2D
var spell_definitions: Dictionary = {}
var cast_cooldown_remaining: float = 0.0

func _ready() -> void:
	SPRITE_ARCHIVE.extract_if_needed()
	_load_spell_definitions()
	quests = QuestManager.new()
	player = PLAYER_SCENE.instantiate() as PlayerCharacter
	add_child(player)
	player.global_position = Vector2(130, 210)
	player.stats_changed.connect(_refresh_hud)
	player.level_up.connect(_on_level_up)

	hud = GameHud.new()
	add_child(hud)

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
	nearby_interactable = _find_nearest_interactable()
	if hud.dialogue_visible:
		hud.set_prompt("")
	elif nearby_interactable != null:
		var prompt := "E — поговорить" if nearby_interactable is WorldNpc else "E — собрать"
		hud.set_prompt(prompt)
	else:
		hud.set_prompt("WASD — движение   ЛКМ — магия   E — взаимодействие   Esc — пауза")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if hud.dialogue_visible:
			hud.close_dialogue()
			player.set_physics_process(true)
		else:
			_try_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cast_spell"):
		if not hud.dialogue_visible:
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
	add_child(slime)
	slime.global_position = spawn_position
	slime.defeated.connect(_on_enemy_defeated)

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

func _on_enemy_defeated(xp_reward: int) -> void:
	player.add_experience(xp_reward)
	hud.show_message("Слизень побеждён! +%d опыта" % xp_reward, 1.5)

func _on_level_up(new_level: int) -> void:
	hud.show_message("НОВЫЙ УРОВЕНЬ: %d! Здоровье и мана восстановлены." % new_level, 3.0)

func _cast_spell() -> void:
	if cast_cooldown_remaining > 0.0:
		return
	var spell: Dictionary = spell_definitions.get("fireball", {})
	var mana_cost := int(spell.get("mana_cost", 8))
	var spell_damage := int(spell.get("damage", 18))
	if not player.spend_mana(mana_cost):
		hud.show_message("Недостаточно маны.", 1.2)
		return
	var direction := (get_global_mouse_position() - player.global_position).normalized()
	if direction.length_squared() < 0.01:
		direction = player.facing
	var bolt := BOLT_SCENE.instantiate() as MagicBolt
	bolt.speed = float(spell.get("projectile_speed", 255))
	bolt.setup(direction, spell_damage)
	add_child(bolt)
	bolt.global_position = player.global_position + direction * 12.0
	cast_cooldown_remaining = float(spell.get("cooldown", 0.25))

func _refresh_hud() -> void:
	if hud != null and player != null and quests != null:
		hud.update_status(player, quests)
