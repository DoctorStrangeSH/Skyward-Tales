extends Node2D
class_name SkywardGame

## Root of a running game session. Owns the player, HUD and world actors and
## wires them together. Region layouts live in data/regions.json; NPC talks are
## in NpcDialogues, quest pickups in QuestPickups, save/load in GameSaveState.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BOLT_SCENE := preload("res://scenes/magic_bolt.tscn")
const NPC_SCRIPT := preload("res://scripts/npc.gd")
const COLLECTIBLE_SCRIPT := preload("res://scripts/collectible.gd")
const LOOT_SCRIPT := preload("res://scripts/loot.gd")
const CHEST_SCRIPT := preload("res://scripts/treasure_chest.gd")
const SAVE_SCRIPT := preload("res://scripts/save_system.gd")
const RELATIONSHIP_SCRIPT := preload("res://scripts/npc_relationships.gd")
const MERCHANT_SHOP_SCRIPT := preload("res://scripts/merchant_shop.gd")
const CRAFTING_SERVICE_SCRIPT := preload("res://scripts/crafting_service.gd")
const GATE_SCRIPT := preload("res://scripts/region_gate.gd")
## Story bosses: defeated once (flag "<kind>_defeated"), never respawn.
const STORY_BOSSES := {"echo": "Отголосок", "tempest": "Буревой колосс"}
const ENEMY_SCRIPTS := {
	"slime": preload("res://scripts/enemy.gd"),
	"wolf": preload("res://scripts/forest_wolf.gd"),
	"shaman": preload("res://scripts/forest_shaman.gd"),
	"guardian": preload("res://scripts/grove_guardian.gd"),
	"bat": preload("res://scripts/cave_bat.gd"),
	"echo": preload("res://scripts/echo_warden.gd"),
	"wisp": preload("res://scripts/wind_wisp.gd"),
	"tempest": preload("res://scripts/tempest_colossus.gd"),
	"sentinel": preload("res://scripts/sky_sentinel.gd")
}
const MATERIAL_ITEMS := ["wolf_pelt", "iron_ore"]
const RARITY_LABELS := {"common": "ОБЫЧНАЯ", "uncommon": "НЕОБЫЧНАЯ", "rare": "РЕДКАЯ"}
const CARTOGRAPHER_CACHE_ID := "greenreach_cartographer_cache"

var player: PlayerCharacter
var hud: GameHud
var quests: QuestManager
var relationships: NpcRelationships
var merchant_shop: MerchantShop
var crafting_service: CraftingService
var dialogues: NpcDialogues
var interact_prompt: InteractPrompt
var story: StoryScene
var companion: Companion
var loot_rng := RandomNumberGenerator.new()
var director: StoryDirector
var pickups: QuestPickups
var elder: WorldNpc
var nearby_interactable: Node2D
var spell_definitions: Dictionary = {}
var region_layouts: Dictionary = {}
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
var opened_chests: Dictionary = {}
var gathered_resource_nodes: Dictionary = {}
var latest_cache_narrative: bool = false
var autosave_enabled: bool = true
var _autosave_pending: bool = false
var _session_time: float = 0.0
var _marker_clock: float = 0.0
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0

func _ready() -> void:
	loot_rng.randomize()
	var catalogs: GameCatalogs = GameCatalogs.new()
	spell_definitions = catalogs.spells
	talent_definitions = catalogs.talents
	bestiary_entries = catalogs.bestiary
	region_layouts = catalogs.regions
	world = get_node("World") as Node2D
	# Actors and scenery share one y-sorted space: walk behind trees and ruins.
	y_sort_enabled = true
	quests = QuestManager.new()
	quests.quest_completed.connect(func(quest_id: String) -> void:
		request_autosave()
		if director != null:
			director.on_quest_completed(quest_id))
	relationships = RELATIONSHIP_SCRIPT.new()
	merchant_shop = MERCHANT_SHOP_SCRIPT.new()
	crafting_service = CRAFTING_SERVICE_SCRIPT.new()
	dialogues = NpcDialogues.new(self)
	pickups = QuestPickups.new(self)
	story = StoryScene.new(self)
	director = StoryDirector.new(self)
	player = PLAYER_SCENE.instantiate() as PlayerCharacter
	add_child(player)
	player.global_position = GameSaveState.DEFAULT_PLAYER_POSITION
	player.stats_changed.connect(_refresh_hud)
	player.level_up.connect(_on_level_up)
	player.died.connect(_on_player_died)
	player.hurt.connect(func(amount: int) -> void: shake(clampf(1.5 + amount * 0.15, 1.5, 4.0), 0.18))
	player.second_wind_triggered.connect(func() -> void: hud.show_message("Второе дыхание! Смерть отступила.", 3.0))
	_apply_camera_limits()
	StoryText.reset()

	hud = GameHud.new()
	add_child(hud)
	interact_prompt = InteractPrompt.new()
	add_child(interact_prompt)
	hud.inventory_use_requested.connect(_on_inventory_use)
	hud.inventory_unequip_requested.connect(_on_inventory_unequip)
	hud.pause_save_requested.connect(save_game)
	hud.pause_load_requested.connect(load_game)
	hud.pause_menu_requested.connect(_go_to_title)
	hud.defeat_restart_requested.connect(_restart_run)
	hud.defeat_load_requested.connect(_load_from_defeat)
	hud.defeat_menu_requested.connect(_go_to_title)
	hud.skill_learn_requested.connect(learn_skill)
	hud.dialogue_choice_selected.connect(_on_dialogue_choice_selected)

	_populate_region()

	if get_tree().has_meta("skyward_continue") and bool(get_tree().get_meta("skyward_continue")):
		get_tree().remove_meta("skyward_continue")
		load_game(true)
	elif get_tree().has_meta("skyward_new_hero"):
		var hero: Dictionary = get_tree().get_meta("skyward_new_hero")
		get_tree().remove_meta("skyward_new_hero")
		start_new_story(str(hero.get("name", "")), str(hero.get("gender", "m")))
	else:
		hud.show_message("Добро пожаловать в Skyward Tales! Найдите старейшину.", 5.0)
		hud.show_tip("controls", "Совет: Esc — пауза, там же управление и настройки.", 6.0)
	_refresh_hud()

## Camera shake (off when the "Тряска экрана" setting is disabled).
func shake(strength: float, duration: float) -> void:
	if not GameSettings.get_bool("screen_shake"):
		return
	if strength >= _shake_strength * (_shake_time / maxf(0.01, _shake_duration)):
		_shake_strength = strength
		_shake_duration = duration
		_shake_time = duration

func _update_shake(delta: float) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D if player != null else null
	if camera == null:
		return
	if _shake_time <= 0.0:
		camera.offset = Vector2.ZERO
		return
	_shake_time = maxf(0.0, _shake_time - delta)
	var power := _shake_strength * (_shake_time / maxf(0.01, _shake_duration))
	camera.offset = Vector2(randf_range(-power, power), randf_range(-power, power)).round()

func _process(delta: float) -> void:
	_session_time += delta
	_update_shake(delta)
	cast_cooldown_remaining = maxf(0.0, cast_cooldown_remaining - delta)
	if player == null or hud == null or game_over:
		return
	_update_spell_hud()
	director.update()
	_marker_clock -= delta
	if _marker_clock <= 0.0:
		_marker_clock = 0.25
		update_npc_markers()
	_discover_nearby_enemies()
	_update_minimap()
	hud.update_dodge(player.dodge_cooldown_left, player.dodge_cooldown, player.dodge_time_left > 0.0)
	nearby_interactable = _find_nearest_interactable()
	var busy: bool = hud.dialogue_visible or hud.inventory_open or hud.overlay_visible() or hud.world_map_visible
	if busy or nearby_interactable == null:
		hud.set_prompt("")
		interact_prompt.show_for(null, "")
	else:
		var text := _interaction_prompt(nearby_interactable)
		hud.set_prompt(text)
		interact_prompt.show_for(nearby_interactable, text.trim_prefix("E — "))

func _interaction_prompt(target: Node2D) -> String:
	if target is WorldNpc:
		return "E — поговорить"
	if target is RegionGate:
		return "E — перейти"
	if target is WorldLoot:
		return "E — подобрать"
	if target is TreasureChest:
		return "E — открыть"
	return "E — собрать"

# --- Input ---------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if game_over or (hud != null and (hud.talent_visible or hud.defeat_visible)):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _handle_key(event.keycode):
			get_viewport().set_input_as_handled()
			return
	# _input receives mouse clicks even when a Control overlays the world.
	if event.is_action_pressed("interact"):
		if story.active:
			story.advance()
		elif hud.dialogue_visible:
			hud.close_dialogue()
			player.set_physics_process(true)
		else:
			_try_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cast_spell"):
		if not get_tree().paused and not hud.dialogue_visible and not hud.inventory_open and not hud.overlay_visible():
			_cast_spell()
		get_viewport().set_input_as_handled()

## Returns true when the key was consumed and must not reach other handlers.
func _handle_key(keycode: Key) -> bool:
	var world_blocked: bool = get_tree().paused or hud.dialogue_visible
	match keycode:
		KEY_M when not world_blocked:
			if hud.inventory_open:
				hud.toggle_inventory(player)
			_close_books()
			_update_minimap()
			hud.open_world_map(current_region, player.global_position, discovered_landmarks.get(current_region, {}), quests.get_active_summary())
			return true
		KEY_K when not world_blocked:
			if hud.skills_visible:
				hud.toggle_skill_tree(player)
			if hud.inventory_open:
				hud.toggle_inventory(player)
			if hud.journal_visible:
				hud.toggle_journal(quests)
			hud.toggle_bestiary(bestiary_entries, discovered_enemies)
			return true
		KEY_T when not world_blocked:
			if hud.inventory_open:
				hud.toggle_inventory(player)
			if hud.bestiary_visible:
				hud.toggle_bestiary(bestiary_entries, discovered_enemies)
			if hud.journal_visible:
				hud.toggle_journal(quests)
			hud.toggle_skill_tree(player)
			return true
		KEY_J when not world_blocked:
			if hud.skills_visible:
				hud.toggle_skill_tree(player)
			if hud.inventory_open:
				hud.toggle_inventory(player)
			if hud.bestiary_visible:
				hud.toggle_bestiary(bestiary_entries, discovered_enemies)
			hud.toggle_journal(quests)
			return true
	if hud.overlay_visible():
		return false
	match keycode:
		KEY_F6 when not world_blocked:
			save_game()
			return true
		KEY_F9 when not world_blocked:
			load_game()
			return true
		KEY_SHIFT when not world_blocked and not hud.inventory_open:
			player.start_dodge()
			return true
		KEY_I when not world_blocked:
			hud.toggle_inventory(player)
			return true
	if hud.inventory_open:
		return false
	match keycode:
		KEY_Q:
			_use_consumable("health_potion")
		KEY_R:
			_use_consumable("mana_potion")
		KEY_1:
			select_spell("fireball")
		KEY_2:
			select_spell("frostbolt")
		KEY_3:
			select_spell("chain_lightning")
	return false

# --- Regions -------------------------------------------------------------

func _layout(region_id: String = current_region) -> Dictionary:
	var layout: Variant = region_layouts.get(region_id, {})
	return layout if layout is Dictionary else {}

static func _vec(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return GameSaveState.read_position(value, fallback)

func _populate_region() -> void:
	var layout := _layout()
	for npc_data in layout.get("npcs", []):
		_spawn_npc(npc_data)
	for node_data in layout.get("resource_nodes", []):
		var node_id := str(node_data.get("id", ""))
		if not bool(gathered_resource_nodes.get(node_id, false)):
			_spawn_herb(_vec(node_data.get("position")), node_id, str(node_data.get("name", node_id)))
	_spawn_pending_supply_crates(layout)
	spawn_story_objects()
	_spawn_pending_map_fragments(layout)
	for chest_data in layout.get("chests", []):
		_spawn_chest(str(chest_data.get("id", "")), _vec(chest_data.get("position")), int(chest_data.get("gold", 0)), str(chest_data.get("item", "")), int(chest_data.get("amount", 0)))
	for herb_data in layout.get("herbs", []):
		_spawn_herb(_vec(herb_data.get("position")), str(herb_data.get("id", "moonleaf")), str(herb_data.get("name", "Лунный лист")))
	for enemy_data in layout.get("enemies", []):
		spawn_enemy(str(enemy_data.get("kind", "slime")), _vec(enemy_data.get("position")), str(enemy_data.get("elite", "?")))
	var boss: Dictionary = layout.get("boss", {})
	if not boss.is_empty() and quests.is_completed(str(boss.get("after_quest", ""))):
		spawn_region_boss()
	for gate_data in layout.get("gates", []):
		_spawn_gate(str(gate_data.get("target", "")), _vec(gate_data.get("position")), _vec(gate_data.get("arrival")), str(gate_data.get("label", "")))

func _spawn_pending_supply_crates(layout: Dictionary) -> void:
	var state: Dictionary = quests.states.get("bran_supply_run", {})
	if not bool(state.get("started", false)) or quests.is_completed("bran_supply_run"):
		return
	var collected: Array = state.get("collected_crates", [])
	var positions: Array = layout.get("supply_crates", [])
	for index in range(positions.size()):
		if not collected.has(index):
			_spawn_herb(_vec(positions[index]), "supply_crate_%d" % index, "Потерянный ящик с припасами")

func spawn_supply_crates() -> void:
	var positions: Array = _layout("greenreach").get("supply_crates", [])
	for index in range(positions.size()):
		_spawn_herb(_vec(positions[index]), "supply_crate_%d" % index, "Потерянный ящик с припасами")

func _spawn_pending_map_fragments(layout: Dictionary) -> void:
	var positions: Array = layout.get("map_fragments", [])
	if positions.is_empty() or quests.is_completed("lost_cartographer_notes"):
		return
	var state: Dictionary = quests.states.get("lost_cartographer_notes", {})
	var target: int = int(quests.definitions.get("lost_cartographer_notes", {}).get("target", 2))
	var remaining: int = target - (int(state.get("progress", 0)) if bool(state.get("started", false)) else 0)
	for index in range(clampi(remaining, 0, positions.size())):
		_spawn_herb(_vec(positions[index]), "map_fragment", "Обрывок полевого дневника")

func spawn_region_boss() -> void:
	var boss: Dictionary = _layout().get("boss", {})
	if not boss.is_empty():
		spawn_enemy(str(boss.get("kind", "guardian")), _vec(boss.get("position")))

func reveal_secret(region_id: String, marker_id: String) -> void:
	var markers: Dictionary = discovered_landmarks.get(region_id, {})
	if markers.has(marker_id):
		return
	var position_data: Variant = _layout(region_id).get("secrets", {}).get(marker_id)
	if position_data == null:
		push_warning("Неизвестная секретная отметка: " + marker_id)
		return
	var pos := _vec(position_data)
	markers[marker_id] = {"position": [pos.x, pos.y], "kind": "secret"}
	discovered_landmarks[region_id] = markers
	if current_region == region_id:
		_update_minimap()

func _clear_region_actors() -> void:
	for node in get_children():
		if node is WorldNpc and node.is_companion:
			continue
		if node is WorldNpc or node is WorldCollectible or node is SlimeEnemy or node is WorldLoot or node is TreasureChest or node is RegionGate or node is MagicBolt or node is EnemyMagicOrb:
			remove_child(node)
			node.queue_free()
	elder = null
	nearby_interactable = null

func _set_region(region_id: String, arrival: Vector2, notify: bool = true) -> void:
	current_region = RegionCatalog.resolve(region_id)
	_clear_region_actors()
	if world != null and world.has_method("configure_region"):
		world.configure_region(current_region)
	_populate_region()
	player.global_position = arrival
	_place_companion()
	if notify and hud != null:
		hud.show_message("Локация: " + RegionCatalog.display_name(current_region), 2.5)
	_refresh_hud()

## New adventure: identity from character creation, then the prologue.
func start_new_story(hero_name: String, gender: String) -> void:
	player.set_identity(hero_name, gender)
	quests.start_quest("main_prologue")
	_set_region(current_region, player.global_position, false)
	hud.flash_screen(Color.BLACK, 2.0)
	story.play("prologue", func() -> void:
		hud.show_tip("controls", "Совет: Esc — пауза, там же управление и настройки.", 6.0)
		_refresh_hud())

## Places story objects whose quest is active (skips ones already present).
func spawn_story_objects() -> void:
	for object_data in _layout().get("story_objects", []):
		var object_id := str(object_data.get("id", ""))
		var quest_id := str(object_data.get("quest", ""))
		if not bool(quests.states.get(quest_id, {}).get("started", false)) or quests.is_completed(quest_id):
			continue
		var present := false
		for actor in get_children():
			if actor is WorldCollectible and actor.item_id == object_id and not actor.is_queued_for_deletion():
				present = true
		if not present:
			_spawn_herb(_vec(object_data.get("position")), object_id, str(object_data.get("name", "")))

## Mira joins the party (Act II); safe to call more than once.
func ensure_companion() -> void:
	if companion != null and is_instance_valid(companion):
		return
	for actor in get_children():
		if actor is WorldNpc and not actor.is_companion and actor.npc_id == "cartographer":
			remove_child(actor)
			actor.queue_free()
	companion = Companion.new()
	companion.npc_id = "cartographer"
	companion.display_name = "Мира, картограф"
	companion.hero = player
	add_child(companion)
	companion.global_position = player.global_position + Companion.FOLLOW_OFFSET
	companion.interacted.connect(_on_cartographer_interacted)
	director.set_flag("mira_companion")

func _place_companion() -> void:
	if companion != null and is_instance_valid(companion):
		companion.global_position = player.global_position + Companion.FOLLOW_OFFSET

## Story object data (from regions.json) for an item id in the current region.
func story_object(item_id: String) -> Dictionary:
	for object_data in _layout().get("story_objects", []):
		if str(object_data.get("id", "")) == item_id:
			return object_data
	return {}

func _apply_camera_limits() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null or world == null or not world.has_method("map_size"):
		return
	var size: Vector2 = world.map_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y)

func _on_region_travel(target_region: String, arrival: Vector2) -> void:
	var gate_data := RegionCatalog.gate(current_region, target_region)
	var required := str(gate_data.get("requires_quest", ""))
	if not required.is_empty() and not quests.is_completed(required):
		hud.show_message(str(gate_data.get("locked_message", "Путь пока закрыт.")), 2.5)
		return
	if bool(gate_data.get("requires_guardian", false)) and not guardian_defeated:
		hud.show_message(str(gate_data.get("locked_message", "Путь пока закрыт.")), 2.5)
		return
	_set_region(target_region, arrival)
	director.on_region_entered(current_region)
	request_autosave()

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
		var kind: String = enemy_kind(enemy)
		if not discovered_enemies.has(kind):
			discovered_enemies[kind] = true
			hud.show_message("Новая запись в бестиарии: %s" % str(bestiary_entries.get(kind, {}).get("name", kind)), 2.5)
			hud.show_tip("bestiary", "Совет: K — бестиарий со слабостями врагов.")

static func enemy_kind(enemy: SlimeEnemy) -> String:
	if enemy is TempestColossus:
		return "tempest"
	if enemy is EchoWarden:
		return "echo"
	if enemy is GroveGuardian:
		return "guardian"
	if enemy is SkySentinel:
		return "sentinel"
	if enemy is ForestShaman:
		return "shaman"
	if enemy is WindWisp:
		return "wisp"
	if enemy is ForestWolf:
		return "wolf"
	if enemy is CaveBat:
		return "bat"
	return "slime"

func _enemy_kind(enemy: SlimeEnemy) -> String:
	return enemy_kind(enemy)

# --- Spawning ------------------------------------------------------------

func _spawn_npc(npc_data: Dictionary) -> void:
	var npc_id := str(npc_data.get("id", ""))
	if npc_id == "cartographer" and companion != null:
		return  # Mira travels with the hero instead of waiting at camp
	var npc := NPC_SCRIPT.new() as WorldNpc
	npc.npc_id = npc_id
	npc.display_name = str(npc_data.get("name", "Путник"))
	var color: Variant = npc_data.get("outfit_color")
	if color is Array and color.size() == 3:
		npc.outfit_color = Color(float(color[0]), float(color[1]), float(color[2]))
	add_child(npc)
	npc.global_position = _vec(npc_data.get("position"))
	var handler := Callable(self, "_on_%s_interacted" % npc_id)
	if handler.is_valid():
		npc.interacted.connect(handler)
	else:
		push_warning("У NPC нет обработчика диалога: " + npc_id)
	if npc_id == "elder":
		elder = npc

## Spawns an enemy of the given kind and returns it, or null if it must not
## appear (unknown kind, defeated or already present boss).
## elite: "" ordinary, a modifier id, or "?" to roll (story mode only).
func spawn_enemy(kind: String, spawn_position: Vector2, elite: String = "") -> SlimeEnemy:
	if not ENEMY_SCRIPTS.has(kind):
		push_warning("Неизвестный тип противника: " + kind)
		return null
	if kind == "guardian":
		if guardian_defeated:
			return null
		for actor in get_children():
			if actor is GroveGuardian and not actor is EchoWarden and not actor.is_queued_for_deletion():
				return null
	if kind in STORY_BOSSES:
		if director.has_flag(kind + "_defeated"):
			return null
		for actor in get_children():
			if actor is SlimeEnemy and enemy_kind(actor) == kind and not actor.is_queued_for_deletion():
				return null
	var enemy := (ENEMY_SCRIPTS[kind] as GDScript).new() as SlimeEnemy
	enemy.position = spawn_position
	if elite == "?":
		elite = EliteModifiers.roll(loot_rng) if director.story_mode() and EliteModifiers.can_be_elite(kind) else ""
	if not elite.is_empty():
		EliteModifiers.apply(enemy, elite)
	add_child(enemy)
	EliteModifiers.finish(enemy)
	match kind:
		"guardian":
			enemy.defeated.connect(func(xp: int) -> void: _on_guardian_defeated(xp, enemy.global_position))
		"echo", "tempest":
			enemy.defeated.connect(func(xp: int) -> void: _on_story_boss_defeated(kind, xp, enemy.global_position))
		"wolf":
			enemy.defeated.connect(func(xp: int) -> void:
				_on_wolf_defeated(xp, enemy.global_position)
				_on_elite_defeated(enemy))
		_:
			enemy.defeated.connect(func(xp: int) -> void:
				_on_enemy_defeated(xp, enemy.global_position)
				_on_elite_defeated(enemy))
	return enemy

func _spawn_guardian(spawn_position: Vector2) -> void:
	spawn_enemy("guardian", spawn_position)

func _spawn_herb(spawn_position: Vector2, item_id: String = "moonleaf", label: String = "Лунный лист") -> void:
	var herb := COLLECTIBLE_SCRIPT.new() as WorldCollectible
	herb.item_id = item_id
	herb.display_name = label
	add_child(herb)
	herb.global_position = spawn_position
	herb.interacted.connect(_on_herb_interacted)

func _spawn_chest(id: String, at_position: Vector2, gold: int, item: String, amount: int) -> void:
	var chest := CHEST_SCRIPT.new() as TreasureChest
	chest.chest_id = id
	chest.gold_reward = gold
	chest.item_reward = item
	chest.item_amount = amount
	chest.is_opened = bool(opened_chests.get(id, false))
	chest.position = at_position
	add_child(chest)
	if chest.is_opened:
		chest.remove_from_group("interactables")
	chest.opened.connect(_on_chest_opened)
	chest.bonus_found.connect(_on_chest_bonus)

func _spawn_gate(target_region: String, gate_position: Vector2, arrival: Vector2, label: String) -> void:
	var gate := GATE_SCRIPT.new() as RegionGate
	gate.target_region = target_region
	gate.arrival_position = arrival
	gate.display_name = label
	gate.art_style = RegionCatalog.style(current_region)
	add_child(gate)
	gate.global_position = gate_position
	gate.travel_requested.connect(_on_region_travel)

func _spawn_loot(drop_position: Vector2, item_id: String) -> WorldLoot:
	var loot := LOOT_SCRIPT.new() as WorldLoot
	loot.item_id = item_id
	loot.item_name = player.get_item_name(item_id)
	loot.position = drop_position
	add_child(loot)
	loot.collected.connect(_on_loot_collected)
	return loot

# --- NPCs and dialogue (logic lives in NpcDialogues) ---------------------

func _on_elder_interacted(_source: Node2D) -> void:
	if not director.try_talk("elder"):
		dialogues.on_elder()

func _on_cartographer_interacted(_source: Node2D) -> void:
	if not director.try_talk("cartographer"):
		dialogues.on_cartographer()

func _on_grove_warden_interacted(_source: Node2D) -> void:
	if not director.try_talk("grove_warden"):
		dialogues.on_grove_warden()

func _on_merchant_interacted(_source: Node2D) -> void:
	if not director.try_talk("merchant"):
		dialogues.on_merchant()

func _on_hunter_interacted(_source: Node2D) -> void:
	if not director.try_talk("hunter"):
		dialogues.on_hunter()

func _on_blacksmith_interacted(_source: Node2D) -> void:
	if not director.try_talk("blacksmith"):
		dialogues.on_blacksmith()

func _on_archivist_interacted(_source: Node2D) -> void:
	if not director.try_talk("archivist"):
		dialogues.on_archivist()

func _on_miner_interacted(_source: Node2D) -> void:
	if not director.try_talk("miner"):
		dialogues.on_miner()

func _on_dialogue_choice_selected(choice_id: String) -> void:
	dialogues.handle_choice(choice_id)

func _on_herb_interacted(source: Node2D) -> void:
	pickups.handle(source as WorldCollectible)

func update_npc_markers() -> void:
	for actor in get_children():
		if actor is WorldNpc and not actor.is_queued_for_deletion():
			var marker := dialogues.marker_for(actor.npc_id)
			# The companion is always at hand: mark her only when she advances the story.
			if actor.is_companion and marker != "ready":
				marker = ""
			actor.set_marker(marker)

func _show_dialogue(speaker: String, message: String) -> void:
	player.set_physics_process(false)
	hud.show_dialogue(speaker, StoryText.format(message))

func _show_dialogue_choices(speaker: String, message: String, choices: Array[Dictionary]) -> void:
	player.set_physics_process(false)
	var formatted: Array[Dictionary] = []
	for choice in choices:
		var copy: Dictionary = choice.duplicate()
		copy["label"] = StoryText.format(str(choice.get("label", "")))
		formatted.append(copy)
	hud.show_dialogue_choices(speaker, StoryText.format(message), formatted)

func _show_relationship_change(npc_id: String, amount: int) -> void:
	hud.show_message("Отношение: %s (%+d) — %s" % [relationships.get_name(npc_id), amount, relationships.get_rank(npc_id)], 3.0)

func _grant_quest_reward(quest_id: String) -> void:
	var reward: Dictionary = quests.get_reward(quest_id)
	player.add_experience(int(reward.get("experience", 0)))
	player.add_gold(int(reward.get("gold", 0)))

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
	if target == null and companion != null and is_instance_valid(companion):
		companion.interact()
		return
	if target == null:
		hud.show_message("Здесь пока нечего исследовать.", 1.5)
		return
	if target.has_method("interact"):
		target.interact()

# --- Rewards, loot and combat outcomes -----------------------------------

func _on_chest_opened(id: String, gold: int, item: String, amount: int) -> void:
	if opened_chests.has(id):
		return
	opened_chests[id] = true
	latest_cache_narrative = id == CARTOGRAPHER_CACHE_ID
	player.add_gold(gold)
	var has_item := not item.is_empty() and amount > 0
	if has_item:
		player.add_item(item, amount)
	if latest_cache_narrative:
		hud.show_message("Тайник картографа: найдены записи о тропах и припасы. +%d золота, %s ×%d" % [gold, player.get_item_name(item), amount], 4.0)
	elif has_item:
		hud.show_message("Тайник открыт! +%d золота, %s ×%d" % [gold, player.get_item_name(item), amount], 3.0)
	else:
		hud.show_message("Тайник открыт! +%d золота" % gold, 3.0)

func _on_chest_bonus(item_id: String, rarity: String) -> void:
	player.add_item(item_id)
	var find := "%s НАХОДКА: %s!" % [str(RARITY_LABELS.get(rarity, rarity)), player.get_item_name(item_id)]
	if latest_cache_narrative:
		hud.show_message("Записи картографа найдены! " + find, 4.0)
		latest_cache_narrative = false
	else:
		hud.show_message(find, 3.0)

func _on_guardian_defeated(xp: int, death_position: Vector2) -> void:
	if guardian_defeated:
		return
	guardian_defeated = true
	player.add_experience(xp)
	player.add_gold(100)
	_spawn_loot(death_position, "ancient_relic")
	spawn_generated_loot(death_position + Vector2(14, 6), "rare")
	shake(5.0, 0.5)
	hud.show_message("Хранитель побеждён! +100 золота. Древний артефакт ждёт!", 3.5)
	_grant_sky_seal()
	director.on_boss_defeated("guardian")
	request_autosave()

func _on_story_boss_defeated(kind: String, xp: int, death_position: Vector2) -> void:
	if director.has_flag(kind + "_defeated"):
		return
	director.set_flag(kind + "_defeated")
	player.add_experience(xp)
	_spawn_loot(death_position, "ancient_relic")
	spawn_generated_loot(death_position + Vector2(14, 6), "rare")
	shake(6.0, 0.6)
	hud.show_message("%s повержен!" % STORY_BOSSES[kind], 3.0)
	_grant_sky_seal()
	director.on_boss_defeated(kind)
	request_autosave()

func _on_wolf_defeated(xp_reward: int, death_position: Vector2) -> void:
	if quests.active_quest_id == "toren_wolf_hunt" and not quests.is_completed("toren_wolf_hunt"):
		quests.add_progress("toren_wolf_hunt", 1)
		var progress: int = int(quests.states["toren_wolf_hunt"].get("progress", 0))
		hud.show_message("Волк побеждён! Охота: %d/3." % progress, 2.0)
		if quests.is_ready_to_complete("toren_wolf_hunt"):
			hud.show_message("Стая отступила. Вернись к Торену за наградой.", 3.0)
	_refresh_hud()
	_spawn_loot(death_position, "wolf_pelt")
	_on_enemy_defeated(xp_reward, death_position)

func _on_enemy_defeated(xp_reward: int, death_position: Vector2) -> void:
	player.add_experience(xp_reward)
	defeated_enemies += 1
	var drops: Array[String] = ["apprentice_staff", "leather_armor", "mana_amulet"]
	var drop: String
	if defeated_enemies <= drops.size():
		drop = drops[defeated_enemies - 1]
	else:
		drop = "health_potion" if defeated_enemies % 2 == 1 else "mana_potion"
	_spawn_loot(death_position, drop)
	if loot_rng.randf() < LootGenerator.drop_chance():
		spawn_generated_loot(death_position + Vector2(10, 4))
	hud.show_message("Противник побеждён! +%d опыта" % xp_reward, 1.5)

## Elites always leave equipment (uncommon or better).
func _on_elite_defeated(enemy: SlimeEnemy) -> void:
	if enemy.elite_id.is_empty():
		return
	spawn_generated_loot(enemy.global_position + Vector2(-10, 6), "uncommon")
	shake(2.5, 0.25)

## Drops a rolled piece of equipment (bosses pass a minimum rarity).
func spawn_generated_loot(at: Vector2, minimum_rarity: String = "common") -> String:
	var rarity := LootGenerator.roll_rarity(loot_rng, minimum_rarity)
	var definition := LootGenerator.generate(loot_rng, player.level, rarity)
	if definition.is_empty():
		return ""
	var item_id := player.register_generated_item(definition)
	_spawn_loot(at, item_id)
	return item_id

func _on_loot_collected(item_id: String, amount: int) -> void:
	player.add_item(item_id, amount)
	hud.show_message("Получено: %s ×%d" % [player.get_item_name(item_id), amount], 2.0)

# --- Inventory -----------------------------------------------------------

func _on_inventory_unequip(slot: String) -> void:
	if hud.dialogue_visible or get_tree().paused:
		return
	if player.unequip_slot(slot):
		hud.show_message("Экипировка снята.", 1.5)
		hud.refresh_inventory(player)

func _on_inventory_use(item_id: String) -> void:
	if item_id in MATERIAL_ITEMS:
		hud.show_message("%s — %s" % [player.get_item_name(item_id), player.get_item_description(item_id)], 3.0)
		return
	var definition: Dictionary = player.get_item_definition(item_id)
	if not str(definition.get("slot", "")).is_empty():
		hud.show_message("Предмет экипирован!" if player.equip_item(item_id) else "Невозможно экипировать.", 1.5)
		hud.refresh_inventory(player)
		return
	_use_consumable(item_id)

func _use_consumable(item_id: String, label: String = "") -> void:
	if hud == null or hud.dialogue_visible or get_tree().paused:
		return
	if player.use_item(item_id):
		hud.show_message("Использовано: " + (label if not label.is_empty() else player.get_item_name(item_id)), 1.5)
		hud.refresh_inventory(player)
	elif int(player.inventory.get(item_id, 0)) <= 0:
		hud.show_message("Нет предмета: %s." % player.get_item_name(item_id), 1.5)
	else:
		hud.show_message("Восстановление не требуется.", 1.5)

# --- Levels and talents --------------------------------------------------

func _on_level_up(new_level: int) -> void:
	# No pause: each level gives a skill point to spend in the tree (T).
	Vfx.level_up(self, player.global_position)
	if hud != null and not game_over:
		hud.show_message("НОВЫЙ УРОВЕНЬ: %d! +1 очко навыков." % new_level, 3.0)
		hud.show_tip("skill_tree", "Совет: T — дерево навыков. Там тратятся очки и Печати Неба.", 6.0)
		_refresh_hud()

## Learns a skill from the tree window; returns false with a message if blocked.
func learn_skill(skill_id: String) -> bool:
	var reason := SkillTree.block_reason(player, skill_id)
	if not reason.is_empty():
		hud.show_message(reason, 2.5)
		return false
	SkillTree.learn(player, skill_id)
	hud.show_message("Изучено: " + str(SkillTree.definitions()[skill_id].get("name", skill_id)), 2.5)
	hud.refresh_skill_tree(player)
	_refresh_hud()
	return true

## Bosses grant a Sky Seal that unlocks one tier-3 skill.
func _grant_sky_seal() -> void:
	player.add_item(SkillTree.SEAL_ITEM)
	hud.show_message("Получена Печать Неба! Она открывает высший навык ветки (T).", 4.0)

# --- Magic ---------------------------------------------------------------

func _update_spell_hud() -> void:
	var spell: Dictionary = spell_definitions.get(selected_spell_id, {})
	hud.update_spell(str(spell.get("name", selected_spell_id)), int(spell.get("mana_cost", 0)), player.mana, cast_cooldown_remaining, cast_cooldown_total)

func select_spell(spell_id: String) -> void:
	if not spell_definitions.has(spell_id):
		return
	selected_spell_id = spell_id
	hud.show_message("Магия: " + str(spell_definitions[spell_id].get("name", spell_id)), 1.5)
	_update_spell_hud()

func _cast_spell() -> void:
	if cast_cooldown_remaining > 0.0:
		return
	var spell: Dictionary = spell_definitions.get(selected_spell_id, {})
	var mana_cost := int(spell.get("mana_cost", 8))
	var spell_damage := roundi((int(spell.get("damage", 18)) + player.get_spell_bonus(selected_spell_id)) * player.get_spell_power_multiplier())
	if not player.spend_mana(mana_cost):
		hud.show_message("Недостаточно маны.", 1.2)
		return
	var direction := (get_global_mouse_position() - player.global_position).normalized()
	if direction.length_squared() < 0.01:
		direction = player.facing
	var bolt := BOLT_SCENE.instantiate() as MagicBolt
	if bolt == null:
		push_error("Не удалось создать снаряд заклинания")
		return
	bolt.speed = float(spell.get("projectile_speed", 255))
	bolt.setup(direction, spell_damage)
	bolt.configure_effect(selected_spell_id, float(spell.get("slow_multiplier", 1.0)), float(spell.get("slow_duration", 0.0)) + player.get_slow_duration_bonus())
	bolt.configure_burning(int(spell.get("burn_damage", 0)) + player.get_burn_damage_bonus(), float(spell.get("burn_duration", 0.0)))
	bolt.chain_targets = int(spell.get("chain_targets", 0)) + player.get_chain_targets_bonus()
	bolt.chain_radius = float(spell.get("chain_radius", 0.0))
	bolt.chain_damage_factor = float(spell.get("chain_damage_factor", 0.65))
	if selected_spell_id == "fireball" and player.has_skill("fire_ultimate"):
		bolt.explode_radius = 48.0
	if selected_spell_id == "frostbolt" and player.has_skill("ice_ultimate"):
		bolt.pierce_left = 2
		bolt.freeze_on_hit = true
	if selected_spell_id == "chain_lightning" and player.has_skill("storm_ultimate"):
		bolt.chain_damage_factor = 1.0
	add_child(bolt)
	bolt.global_position = player.global_position + direction * 12.0
	player.play_cast(direction)
	cast_cooldown_total = float(spell.get("cooldown", 0.25)) * player.get_cooldown_multiplier()
	cast_cooldown_remaining = cast_cooldown_total
	_update_spell_hud()

func _refresh_hud() -> void:
	if hud != null and player != null and quests != null:
		hud.update_status(player, quests)

# --- Defeat, save and load -----------------------------------------------

func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	pending_level_choices.clear()
	if hud != null:
		hud.hide_talent_choices()
		hud.show_defeat(not SAVE_SCRIPT.load_latest(save_path).is_empty())
	get_tree().paused = true

func _restart_run() -> void:
	get_tree().paused = false
	game_over = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _load_from_defeat() -> void:
	load_game(true)

func make_save_snapshot() -> Dictionary:
	return GameSaveState.capture(self)

func autosave_path() -> String:
	return SAVE_SCRIPT.autosave_path_for(save_path)

## Autosave runs at the end of the frame, so rewards granted right after a
## quest completes are included in the snapshot.
func request_autosave() -> void:
	if autosave_enabled and not _autosave_pending:
		_autosave_pending = true
		autosave.call_deferred()

func autosave() -> bool:
	_autosave_pending = false
	if not autosave_enabled or game_over or player == null or not is_inside_tree():
		return false
	var success: bool = SAVE_SCRIPT.save_snapshot(make_save_snapshot(), autosave_path())
	if success and hud != null and hud.message_time <= 0.0:
		hud.show_message("Автосохранение", 1.2)
	return success

func save_game() -> bool:
	if game_over:
		if hud != null:
			hud.set_defeat_message("После поражения нельзя перезаписать сохранение. Загрузите прежний прогресс или начните заново.")
		return false
	var success: bool = SAVE_SCRIPT.save_snapshot(make_save_snapshot(), save_path)
	if hud != null:
		hud.show_message("Игра сохранена" if success else "Ошибка сохранения!", 2.0)
		if success:
			hud.show_tip("quickload", "Совет: F9 — быстрая загрузка.")
	return success

## F9 / pause menu load the manual save (falling back to the autosave);
## "Continue" and the defeat screen load whichever save is newest.
func load_game(newest: bool = false) -> bool:
	var data: Dictionary
	if newest:
		data = SAVE_SCRIPT.load_latest(save_path)
	else:
		data = SAVE_SCRIPT.load_snapshot(save_path)
		if data.is_empty():
			data = SAVE_SCRIPT.load_snapshot(autosave_path())
			if not data.is_empty():
				data["_source_path"] = autosave_path()
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
			if str(data.get("_source_path", "")) == autosave_path():
				hud.show_message("Загружено автосохранение.", 2.0)
	elif recovering_from_defeat:
		game_over = true
		get_tree().paused = true
		if hud != null:
			hud.set_defeat_message("Не удалось восстановить сохранение. Попробуйте начать заново.")
	return restored

func restore_save_snapshot(data: Dictionary) -> bool:
	if not GameSaveState.apply(self, data):
		return false
	if hud.inventory_open:
		hud.toggle_inventory(player)
	_close_books()
	player.stats_changed.emit()
	_update_minimap()
	_refresh_hud()
	hud.show_message("Прогресс загружен!", 2.0)
	return true

func _close_books() -> void:
	if hud.skills_visible:
		hud.toggle_skill_tree(player)
	if hud.bestiary_visible:
		hud.toggle_bestiary(bestiary_entries, discovered_enemies)
	if hud.journal_visible:
		hud.toggle_journal(quests)

func _go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_menu.tscn")
