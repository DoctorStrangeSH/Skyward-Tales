extends Node2D
class_name SkywardGame

## Root of a running game session. Owns the player, HUD and world actors and
## wires them together. Region layouts live in data/regions.json; NPC talks are
## in NpcDialogues, quest pickups in QuestPickups, save/load in GameSaveState.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BOLT_SCENE := preload("res://scenes/magic_bolt.tscn")
const NPC_SCRIPT := preload("res://scripts/npc.gd")
const COLLECTIBLE_SCRIPT := preload("res://scripts/collectible.gd")
const WAYSTONE_SCRIPT := preload("res://scripts/waystone.gd")
const SETTLEMENT_OBJECT_SCRIPT := preload("res://scripts/settlement_object.gd")
const GATHER_NODE_SCRIPT := preload("res://scripts/gather_node.gd")
const CRAFT_STATION_SCRIPT := preload("res://scripts/craft_station.gd")
const DUNGEON_DOOR_SCRIPT := preload("res://scripts/dungeon_door.gd")
const SPIKE_TRAP_SCRIPT := preload("res://scripts/spike_trap.gd")
const LOOT_SCRIPT := preload("res://scripts/loot.gd")
const CHEST_SCRIPT := preload("res://scripts/treasure_chest.gd")
const SAVE_SCRIPT := preload("res://scripts/save_system.gd")
const RELATIONSHIP_SCRIPT := preload("res://scripts/npc_relationships.gd")
const MERCHANT_SHOP_SCRIPT := preload("res://scripts/merchant_shop.gd")
const CRAFTING_SERVICE_SCRIPT := preload("res://scripts/crafting_service.gd")
const GATE_SCRIPT := preload("res://scripts/region_gate.gd")
## Story bosses: defeated once (flag "<kind>_defeated"), never respawn.
const STORY_BOSSES := {"echo": "Отголосок", "tempest": "Буревой колосс", "vail": "Вейл", "bog_king": "Болотный король", "crab_king": "Краб-король", "giant": "Горный великан", "crypt_lord": "Повелитель склепа", "ash_lord": "Владыка Пепла", "forge_titan": "Титан Горнила", "pattern_voice": "Голос Узора", "pattern_shade": "Тень Узора"}
const ENEMY_SCRIPTS := {
	"slime": preload("res://scripts/enemy.gd"),
	"wolf": preload("res://scripts/forest_wolf.gd"),
	"shaman": preload("res://scripts/forest_shaman.gd"),
	"guardian": preload("res://scripts/grove_guardian.gd"),
	"bat": preload("res://scripts/cave_bat.gd"),
	"echo": preload("res://scripts/echo_warden.gd"),
	"wisp": preload("res://scripts/wind_wisp.gd"),
	"tempest": preload("res://scripts/tempest_colossus.gd"),
	"shade": preload("res://scripts/rift_shade.gd"),
	"vail": preload("res://scripts/vail_boss.gd"),
	"toad": preload("res://scripts/marsh_toad.gd"),
	"bog_king": preload("res://scripts/bog_king.gd"),
	"crab": preload("res://scripts/coast_crab.gd"),
	"crab_king": preload("res://scripts/crab_king.gd"),
	"golem": preload("res://scripts/stone_golem.gd"),
	"ore_golem": preload("res://scripts/ore_golem.gd"),
	"giant": preload("res://scripts/mountain_giant.gd"),
	"skeleton": preload("res://scripts/skeleton.gd"),
	"crypt_lord": preload("res://scripts/crypt_lord.gd"),
	"sentinel": preload("res://scripts/sky_sentinel.gd"),
	"ember_hound": preload("res://scripts/ember_hound.gd"),
	"magma_golem": preload("res://scripts/magma_golem.gd"),
	"ash_cultist": preload("res://scripts/ash_cultist.gd"),
	"ash_lord": preload("res://scripts/ash_lord.gd"),
	"forge_titan": preload("res://scripts/forge_titan.gd"),
	"pattern_voice": preload("res://scripts/pattern_voice.gd"),
	"pattern_shade": preload("res://scripts/pattern_shade.gd")
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
var givers: QuestGivers
var settlement: Settlement
var crafting: CraftingMenu
var elder: WorldNpc
var nearby_interactable: Node2D
var spell_definitions: Dictionary = {}
var region_layouts: Dictionary = {}
var cast_cooldown_remaining: float = 0.0
var selected_spell_id: String = "fireball"
var skills: CombatSkills
var fishing: Fishing
var events: WorldEvents
var day_night: DayNight
var treasure: TreasureHunt
var contracts: Contracts
var legends: Legends
var epilogue: Epilogue
var quest_nav: QuestNav
var world_state: WorldState
var village: VillageLife
var mine: PassMine
var borin: BorinStory
var combos: ElementalCombos
var gear: GearEffects
var farm: Farm
var buildings: VillageBuildings
var guild: AdventurersGuild
var achievements: Achievements
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
## Regions the hero has set foot in (world map shows the rest as unknown).
var visited_regions: Dictionary = {}
## Dungeon doors opened with keys.
var opened_doors: Dictionary = {}
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
	crit_rng.randomize()
	var catalogs: GameCatalogs = GameCatalogs.new()
	spell_definitions = catalogs.spells
	talent_definitions = catalogs.talents
	bestiary_entries = catalogs.bestiary
	region_layouts = catalogs.regions
	world = get_node("World") as Node2D
	# Actors and scenery share one y-sorted space: walk behind trees and ruins.
	y_sort_enabled = true
	quests = QuestManager.new()
	quests.quest_started.connect(_on_quest_started)
	quests.quest_completed.connect(func(quest_id: String) -> void:
		GameAudio.play("quest", -2.0, 0.0)
		_refresh_dynamic_props.call_deferred()
		if quest_id == "main_guardian" and director != null and director.story_mode() and not director.has_flag("magic_unlocked"):
			director.set_flag("magic_unlocked")
			_place_spell_on_hotbar("fireball")
			hud.show_message("Илара пробудила в вас магию неба! Огненный шар — на панели навыков, ПКМ — заклинание. C — навыки.", 5.0)
			_update_spell_hud()
		request_autosave()
		if director != null:
			director.on_quest_completed(quest_id))
	relationships = RELATIONSHIP_SCRIPT.new()
	merchant_shop = MERCHANT_SHOP_SCRIPT.new()
	crafting_service = CRAFTING_SERVICE_SCRIPT.new()
	dialogues = NpcDialogues.new(self)
	pickups = QuestPickups.new(self)
	givers = QuestGivers.new(self)
	settlement = Settlement.new(self)
	crafting = CraftingMenu.new(self)
	story = StoryScene.new(self)
	director = StoryDirector.new(self)
	skills = CombatSkills.new()
	skills.name = "CombatSkills"
	skills.game = self
	add_child(skills)
	fishing = Fishing.new()
	fishing.name = "Fishing"
	fishing.game = self
	add_child(fishing)
	events = WorldEvents.new()
	events.name = "WorldEvents"
	events.game = self
	add_child(events)
	day_night = DayNight.new()
	day_night.name = "DayNight"
	day_night.game = self
	add_child(day_night)
	treasure = TreasureHunt.new()
	treasure.name = "TreasureHunt"
	treasure.game = self
	add_child(treasure)
	achievements = Achievements.new()
	achievements.name = "Achievements"
	achievements.game = self
	add_child(achievements)
	world_state = WorldState.new()
	world_state.name = "WorldState"
	world_state.game = self
	add_child(world_state)
	borin = BorinStory.new(self)
	buildings = VillageBuildings.new(self)
	guild = AdventurersGuild.new(self)
	farm = Farm.new()
	farm.name = "Farm"
	farm.game = self
	add_child(farm)
	gear = GearEffects.new()
	gear.name = "GearEffects"
	gear.game = self
	add_child(gear)
	combos = ElementalCombos.new()
	combos.name = "ElementalCombos"
	combos.game = self
	add_child(combos)
	mine = PassMine.new()
	mine.name = "PassMine"
	mine.game = self
	add_child(mine)
	village = VillageLife.new()
	village.name = "VillageLife"
	village.game = self
	add_child(village)
	legends = Legends.new()
	legends.name = "Legends"
	legends.game = self
	add_child(legends)
	legends.legend_defeated.connect(func(_id: String) -> void: achievements.add("legends"))
	quest_nav = QuestNav.new(self)
	epilogue = Epilogue.new()
	epilogue.name = "Epilogue"
	epilogue.game = self
	add_child(epilogue)
	fishing.finished.connect(func(caught: String) -> void:
		if not caught.is_empty():
			achievements.add("fish"))
	contracts = Contracts.new()
	contracts.name = "Contracts"
	contracts.game = self
	add_child(contracts)
	player = PLAYER_SCENE.instantiate() as PlayerCharacter
	add_child(player)
	player.global_position = GameSaveState.DEFAULT_PLAYER_POSITION
	player.stats_changed.connect(_refresh_hud)
	player.level_up.connect(_on_level_up)
	player.died.connect(_on_player_died)
	player.recipe_learned.connect(func(recipe_item: String) -> void:
		hud.show_message("Выучен рецепт: " + player.get_item_name(recipe_item).trim_prefix("Рецепт: "), 3.0)
		GameAudio.play("quest", -4.0, 0.0))
	player.parried.connect(func(source: Node) -> void: gear.on_parry(source))
	player.blocked.connect(func(_amount: int) -> void:
		GameAudio.play("hit", -8.0, 0.4)
		Vfx.sparkle(self, player.global_position + player.facing * 12.0))
	player.hurt.connect(func(amount: int) -> void:
		gear.on_hurt(amount, player.last_attacker)
		GameAudio.play("hurt", -3.0)
		shake(clampf(1.5 + amount * 0.15, 1.5, 4.0), 0.18))
	player.second_wind_triggered.connect(func() -> void: hud.show_message("Второе дыхание! Смерть отступила.", 3.0))
	_apply_camera_limits()
	StoryText.reset()

	hud = GameHud.new()
	add_child(hud)
	interact_prompt = InteractPrompt.new()
	add_child(interact_prompt)
	hud.inventory_use_requested.connect(_on_inventory_use)
	hud.inventory_view.set_skills(skills)
	hud.journal_view.achievements = achievements
	hud.inventory_unequip_requested.connect(_on_inventory_unequip)
	hud.handcraft_requested.connect(open_handcraft)
	hud.hero_unequip_requested.connect(func(slot: String) -> void:
		_on_inventory_unequip(slot)
		hud.refresh_hero_panel(player, skills))
	hud.hero_assign_requested.connect(func(index: int, skill_id: String) -> void:
		if player.assign_skill(index, skill_id):
			hud.update_hotbar(skills.hotbar_entries())
		hud.refresh_hero_panel(player, skills))
	hud.pause_save_requested.connect(save_game)
	hud.pause_load_requested.connect(func() -> void: load_game(true))
	hud.pause_menu_requested.connect(_go_to_title)
	hud.defeat_restart_requested.connect(_restart_run)
	hud.defeat_load_requested.connect(_load_from_defeat)
	hud.defeat_menu_requested.connect(_go_to_title)
	hud.skill_learn_requested.connect(learn_skill)
	hud.skills_reset_requested.connect(reset_skills)
	hud.dialogue_dismissed.connect(func() -> void: player.set_physics_process(true))
	hud.can_dismiss_dialogue = func() -> bool: return not story.active
	hud.skills_view.combos = combos
	hud.dialogue_choice_selected.connect(_on_dialogue_choice_selected)
	hud.world_map_view.travel_requested.connect(fast_travel)

	_populate_region()
	update_music.call_deferred()

	if get_tree().has_meta("skyward_continue") and bool(get_tree().get_meta("skyward_continue")):
		get_tree().remove_meta("skyward_continue")
		load_game(true)
	elif get_tree().has_meta("skyward_new_hero"):
		var hero: Dictionary = get_tree().get_meta("skyward_new_hero")
		get_tree().remove_meta("skyward_new_hero")
		start_new_story(str(hero.get("name", "")), str(hero.get("gender", "m")))
		# A new adventure starts with a sword in hand; magic comes later.
		player.add_item("traveler_sword")
		player.equip_item("traveler_sword")
	else:
		hud.show_message("Добро пожаловать в Skyward Tales! Найдите старейшину.", 5.0)
		hud.show_tip("controls", "Совет: Esc — пауза, там же управление и настройки.", 6.0)
	_refresh_hud()

## Camera shake (off when the "Тряска экрана" setting is disabled).
## Quests with "kill_kind" count defeats of that enemy kind; a main quest
## completes itself (and continues the story chain) when the count is reached.
func _track_kill_quests(enemy: SlimeEnemy, kind: String) -> void:
	for quest_id in quests.definitions:
		if str(quests.definitions[quest_id].get("kill_kind", "")) != kind:
			continue
		enemy.defeated.connect(func(_xp: int) -> void: _on_kill_quest_progress(quest_id))

func _on_kill_quest_progress(quest_id: String) -> void:
	if not bool(quests.states[quest_id].get("started", false)) or quests.is_completed(quest_id):
		return
	quests.add_progress(quest_id, 1)
	var target := int(quests.definitions[quest_id].get("target", 1))
	var progress := int(quests.states[quest_id].get("progress", 0))
	hud.show_message("%s: %d/%d" % [quests.definitions[quest_id].get("title", ""), mini(progress, target), target], 2.0)
	if quests.is_ready_to_complete(quest_id) and bool(quests.definitions[quest_id].get("main", false)):
		director._complete(quest_id)
	_refresh_hud()

## Hit-stop: a few frames of near-frozen time make heavy blows land.
## Skipped headless so tests keep a steady clock.
func hit_stop(duration: float) -> void:
	if duration <= 0.0 or DisplayServer.get_name() == "headless" or Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

## Region music by art style; bosses override it while alive.
func update_music() -> void:
	for actor in get_children():
		if actor is GroveGuardian and not actor.is_queued_for_deletion() and actor.health > 0:
			GameAudio.music("boss")
			return
	var style := RegionCatalog.style(current_region)
	GameAudio.music({"night": "night", "cave": "caves", "sky": "sky", "spires": "sky", "rift": "night", "marsh": "night", "coast": "sky", "mountain": "caves", "crypt": "caves", "ash": "night", "magma": "boss"}.get(style, "meadow"))

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
	_update_bow(delta)
	if player != null:
		_update_sword(delta)
	if player == null or hud == null or game_over:
		return
	_process_respawns(delta)
	_tick_autosave(delta)
	_update_spell_hud()
	hud.update_hotbar(skills.hotbar_entries())
	hud.quest_tracker.extra = contracts.tracker_entries()
	director.update()
	# The finale choice comes back until the hero makes it.
	if quests.is_completed("main_heart") and not director.has_flag("ending_restore") and not director.has_flag("ending_lower"):
		if not hud.dialogue_visible and not story.active and not director.has_pending():
			offer_finale()
	if not get_tree().paused:
		crafting.tick(delta)
	_marker_clock -= delta
	if _marker_clock <= 0.0:
		_marker_clock = 0.25
		update_npc_markers()
		crafting.refresh_nodes()
		if not player.buffs.is_empty():
			_refresh_hud()
	_discover_nearby_enemies()
	# The minimap redraws every frame (smooth); discovery and quest targets
	# are refreshed a few times a second.
	_minimap_clock -= delta
	if _minimap_clock <= 0.0:
		_minimap_clock = 0.3
		_discover_landmarks()
		quest_nav.refresh()
	_draw_minimap()
	hud.update_dodge(player.dodge_cooldown_left, player.dodge_cooldown, player.dodge_time_left > 0.0)
	nearby_interactable = _find_nearest_interactable()
	var busy: bool = hud.dialogue_visible or hud.inventory_open or hud.overlay_visible() or hud.world_map_visible or fishing.active()
	if busy or nearby_interactable == null:
		hud.set_prompt("")
		interact_prompt.show_for(null, "")
	else:
		var text := _interaction_prompt(nearby_interactable)
		hud.set_prompt(text)
		interact_prompt.show_for(nearby_interactable, text.trim_prefix("E — "))

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
		return farm.prompt(target.index)
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
	if target is TreasureChest:
		return "E — открыть"
	return "E — собрать"

# --- Input ---------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if game_over or (hud != null and (hud.talent_visible or hud.defeat_visible)):
		return
	if fishing != null and fishing.active():
		# While fishing only E / LMB (hook and reel) and cancel keys matter.
		if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
			fishing.press()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			fishing.cancel()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.pressed and event.keycode == KEY_F:
		player.end_guard()
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
	elif event.is_action_pressed("attack") or event.is_action_released("attack"):
		if get_viewport().gui_get_hovered_control() != null:
			return
		if not get_tree().paused and not hud.dialogue_visible and not hud.inventory_open and not hud.overlay_visible():
			if event.is_pressed():
				_attack_pressed()
			else:
				_attack_released()
			get_viewport().set_input_as_handled()
	elif event.is_action_released("cast_spell") and _bow_holding:
		_bow_release()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cast_spell"):
		# Clicks on buttons (dialogue choices, menus) must reach the GUI, so the
		# click is consumed only when it really casts a spell.
		if get_viewport().gui_get_hovered_control() != null:
			return
		if not get_tree().paused and not hud.dialogue_visible and not hud.inventory_open and not hud.overlay_visible():
			if player.has_bow():
				_bow_press()
			else:
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
			open_map()
			return true
		KEY_K when not world_blocked:
			if hud.skills_visible:
				hud.toggle_skill_tree(player)
			if hud.inventory_open:
				hud.toggle_inventory(player)
			if hud.journal_visible:
				hud.toggle_journal(quests, player)
			hud.toggle_bestiary(bestiary_entries, discovered_enemies)
			return true
		KEY_C when not world_blocked:
			if not hud.inventory_open:
				_close_books()
			hud.toggle_hero_panel(player, skills)
			return true
		KEY_T when not world_blocked:
			if hud.inventory_open:
				hud.toggle_inventory(player)
			if hud.bestiary_visible:
				hud.toggle_bestiary(bestiary_entries, discovered_enemies)
			if hud.journal_visible:
				hud.toggle_journal(quests, player)
			hud.toggle_skill_tree(player)
			return true
		KEY_J when not world_blocked:
			if hud.skills_visible:
				hud.toggle_skill_tree(player)
			if hud.inventory_open:
				hud.toggle_inventory(player)
			if hud.bestiary_visible:
				hud.toggle_bestiary(bestiary_entries, discovered_enemies)
			hud.toggle_journal(quests, player)
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
		KEY_SPACE when not world_blocked and not hud.inventory_open:
			if player.start_dodge():
				GameAudio.play("dash", -6.0)
				gear.on_dodge()
			return true
		KEY_F when not world_blocked and not hud.inventory_open:
			if player.start_guard():
				player.visual.play_named("charge", 0.3)
			return true
		KEY_I when not world_blocked:
			hud.toggle_inventory(player)
			return true
		KEY_B when not world_blocked:
			open_handcraft()
			return true
	if hud.inventory_open:
		return false
	match keycode:
		KEY_Q:
			_use_consumable("health_potion")
		KEY_R:
			_use_consumable("mana_potion")
		KEY_1, KEY_2, KEY_3, KEY_4:
			if not world_blocked:
				skills.use_slot(keycode - KEY_1)
				hud.update_hotbar(skills.hotbar_entries())
			return true
	return false

# --- Regions -------------------------------------------------------------

func _layout(region_id: String = current_region) -> Dictionary:
	var layout: Variant = region_layouts.get(region_id, {})
	return layout if layout is Dictionary else {}

static func _vec(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return GameSaveState.read_position(value, fallback)

## Region entries may depend on the world: "requires_state" / "unless_state"
## name a world state (world_state.gd) or a story flag.
func layout_allows(entry: Variant) -> bool:
	if not entry is Dictionary:
		return true
	var need := str(entry.get("requires_state", ""))
	if not need.is_empty() and not state_on(need):
		return false
	var block := str(entry.get("unless_state", ""))
	return block.is_empty() or not state_on(block)

func state_on(state_id: String) -> bool:
	return (world_state != null and world_state.has(state_id)) or director.has_flag(state_id)

func _populate_region() -> void:
	var layout := _layout()
	for npc_data in layout.get("npcs", []):
		_spawn_npc(npc_data)
	for npc_data in settlement.npcs_for(current_region):
		_spawn_npc(npc_data)
	_spawn_settlement()
	for spot in layout.get("contract_boards", []):
		var board := ContractBoard.new()
		add_child(board)
		board.global_position = _vec(spot)
		board.used.connect(func(_b: ContractBoard) -> void: contracts.open_board())
	treasure.spawn_mark()
	epilogue.spawn_rift()
	village.on_region_ready()
	for node_data in layout.get("resource_nodes", []):
		var node_id := str(node_data.get("id", ""))
		if not bool(gathered_resource_nodes.get(node_id, false)):
			_spawn_herb(_vec(node_data.get("position")), node_id, str(node_data.get("name", node_id)))
	_spawn_pending_supply_crates(layout)
	spawn_story_objects()
	_spawn_pending_map_fragments(layout)
	for chest_data in layout.get("chests", []):
		_spawn_chest(str(chest_data.get("id", "")), _vec(chest_data.get("position")), int(chest_data.get("gold", 0)), str(chest_data.get("item", "")), int(chest_data.get("amount", 0)), str(chest_data.get("tier", "wood")))
	for herb_data in layout.get("herbs", []):
		# Quest items only appear once their quest is taken.
		if not quests.is_active(_herb_quest(herb_data)):
			continue
		_spawn_herb(_vec(herb_data.get("position")), str(herb_data.get("id", "moonleaf")), str(herb_data.get("name", "Лунный лист")), str(herb_data.get("quest", "")))
	for enemy_data in layout.get("enemies", []):
		# "quest": only while that quest is open (unique side bosses).
		var needs := str(enemy_data.get("quest", ""))
		if not needs.is_empty() and not quests.is_active(needs):
			continue
		if not layout_allows(enemy_data):
			continue
		_spawn_layout_enemy(enemy_data)
	_spawn_waystone(layout)
	_spawn_gathering(layout)
	_spawn_dynamic_props(layout)
	_spawn_dungeon(layout)
	var boss: Dictionary = layout.get("boss", {})
	if not boss.is_empty() and quests.is_completed(str(boss.get("after_quest", ""))):
		spawn_region_boss()
	for gate_data in layout.get("gates", []):
		_spawn_gate(str(gate_data.get("target", "")), _vec(gate_data.get("position")), _vec(gate_data.get("arrival")), str(gate_data.get("label", "")))
	buildings.spawn_mercenary()
	buildings.reveal_chests()
	guild.spawn_target()

## Ordinary monsters come back a while after they fall (bosses, quest foes,
## legends and event foes do not).
const ENEMY_RESPAWN := 40.0
var _respawns: Array = []
var _play_clock: float = 0.0

func _spawn_layout_enemy(enemy_data: Dictionary) -> SlimeEnemy:
	var kind := str(enemy_data.get("kind", "slime"))
	var enemy := spawn_enemy(kind, _vec(enemy_data.get("position")), str(enemy_data.get("elite", "?")))
	if kind == "ore_golem" and enemy != null:
		enemy.defeated.connect(func(_xp: int) -> void: mine.on_leader_defeated())
	if enemy == null or enemy_data.has("quest") or kind in STORY_BOSSES or kind in ["guardian", "ore_golem"]:
		return enemy
	var region_id := current_region
	enemy.defeated.connect(func(_xp: int) -> void:
		_respawns.append({"region": region_id, "data": enemy_data, "at": _play_clock + ENEMY_RESPAWN}))
	return enemy

func _process_respawns(delta: float) -> void:
	_play_clock += delta
	if _respawns.is_empty():
		return
	for entry in _respawns.duplicate():
		if float(entry["at"]) > _play_clock:
			continue
		if str(entry["region"]) != current_region:
			_respawns.erase(entry)
			continue
		var at := _vec(entry["data"].get("position"))
		# Never pop up in plain sight: wait until the hero walks away.
		if player.global_position.distance_to(at) < 200.0:
			entry["at"] = _play_clock + 3.0
			continue
		_respawns.erase(entry)
		if not layout_allows(entry["data"]):
			continue
		var enemy := _spawn_layout_enemy(entry["data"])
		if enemy != null:
			enemy.modulate.a = 0.0
			enemy.create_tween().tween_property(enemy, "modulate:a", 1.0, 0.8)

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
		if node is WorldNpc or node is WorldCollectible or node is SlimeEnemy or node is WorldLoot or node is TreasureChest or node is RegionGate or node is Waystone or node is SettlementObject or node is GatherNode or node is CraftStation or node is DungeonDoor or node is SpikeTrap or node is FlameVent or node is DungeonLever or node is ContractBoard or node is DigSpot or node is PatternRift or node is Caravan or node is Arrow or node is SnareTrap or node is SpiritAlly or node is CrystalTotem or node is FarmBed or node is FarmPatch or node is MagicBolt or node is EnemyMagicOrb:
			remove_child(node)
			node.queue_free()
	elder = null
	nearby_interactable = null
	_respawns.clear()

func _set_region(region_id: String, arrival: Vector2, notify: bool = true) -> void:
	current_region = RegionCatalog.resolve(region_id)
	visited_regions[current_region] = true
	if achievements != null:
		achievements.set_max("regions", visited_regions.size())
	_clear_region_actors()
	if world != null and world.has_method("configure_region"):
		world.set("allows", layout_allows)
		world.configure_region(current_region)
	_populate_region()
	update_music.call_deferred()
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
		if not layout_allows(object_data):
			continue
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

## Finale of Act III: after the Voice of the Pattern falls, the hero decides.
func offer_finale() -> void:
	if director.has_flag("ending_restore") or director.has_flag("ending_lower"):
		return
	_show_dialogue_choices("Небесная печать", "Печать горит в ладони. Узор ждёт решения.", [
		{"id": "finale:restore", "label": "Зажечь Узор — острова останутся в небе"},
		{"id": "finale:lower", "label": "Отпустить Узор — острова мягко опустятся на землю"},
	])

func choose_finale(ending: String) -> void:
	if ending != "restore" and ending != "lower":
		return
	player.set_physics_process(true)
	director.set_flag("ending_" + ending)
	achievements.add("ending")
	director.queue_scene("ending_" + ending, func() -> void:
		hud.show_title_card("Конец · %s" % ("Живое небо" if ending == "restore" else "Звёзды над землёй"), 6.0)
		hud.show_message("Спасибо за игру! %s Вестник Сорен ждёт в Зелёных Пределах." % epilogue.blessing_text(), 8.0)
		if current_region == "greenreach":
			for npc_data in _layout().get("npcs", []):
				if str(npc_data.get("id", "")) == "herald":
					_spawn_npc(npc_data)
			update_npc_markers()
		request_autosave())

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
	# On floating islands the camera may look past the rim into the sky.
	var view := 110 if world.has_method("has_apron") and world.has_apron() else 0
	camera.limit_left = -view
	camera.limit_top = -view
	camera.limit_right = int(size.x) + view
	camera.limit_bottom = int(size.y) + view

func _on_region_travel(target_region: String, arrival: Vector2) -> void:
	var gate_data := RegionCatalog.gate(current_region, target_region)
	var required := str(gate_data.get("requires_quest", ""))
	if not required.is_empty() and not quests.is_completed(required):
		hud.show_message(str(gate_data.get("locked_message", "Путь пока закрыт.")), 2.5)
		return
	if bool(gate_data.get("requires_guardian", false)) and not guardian_defeated:
		hud.show_message(str(gate_data.get("locked_message", "Путь пока закрыт.")), 2.5)
		return
	_travel(target_region, arrival)

func _travel(target_region: String, arrival: Vector2) -> void:
	GameAudio.play("travel", -4.0, 0.0)
	_set_region(target_region, arrival)
	director.on_region_entered(current_region)
	var recommended := RegionCatalog.level(current_region)
	if recommended > player.level + 2:
		hud.show_message("Опасные земли! Рекомендуемый уровень: %d" % recommended, 3.5)
	request_autosave()

# --- Open world: region levels, waystones, fast travel ----------------------

func _scale_to_region(enemy: SlimeEnemy) -> void:
	if day_night != null and day_night.night_here() and not enemy is GroveGuardian:
		# Night: tougher foes, richer rewards.
		enemy.max_health = int(round(enemy.max_health * 1.2))
		enemy.attack_damage = int(round(enemy.attack_damage * 1.15))
		enemy.xp_reward = int(round(enemy.xp_reward * 1.3))
		enemy.health = enemy.max_health
		enemy.combat_feedback.set_health(enemy.health, enemy.max_health)
	enemy.xp_reward = maxi(1, int(round(enemy.xp_reward * XP_RATE)))
	if epilogue != null:
		enemy.xp_reward = int(round(enemy.xp_reward * epilogue.xp_mult()))
	var power := RegionCatalog.enemy_power(current_region)
	if is_equal_approx(power, 1.0) or enemy is GroveGuardian:
		return
	enemy.max_health = int(round(enemy.max_health * power))
	enemy.health = enemy.max_health
	enemy.attack_damage = int(round(enemy.attack_damage * power))
	enemy.xp_reward = int(round(enemy.xp_reward * power))
	enemy.combat_feedback.set_health(enemy.health, enemy.max_health)

## The camera shows the world at 2x (320x180 world pixels on screen): enemies
## notice and shoot from about two-thirds of their old ranges, so nothing
## attacks from off-screen.
const VIEW_RANGE := 0.68

func _fit_to_view(enemy: SlimeEnemy) -> void:
	enemy.detection_radius *= VIEW_RANGE
	enemy.give_up_radius *= VIEW_RANGE
	if enemy is ForestShaman:
		enemy.shooting_distance *= VIEW_RANGE
		enemy.preferred_distance *= VIEW_RANGE
		enemy.retreat_distance *= VIEW_RANGE

func _collectible_at(spot: Vector2) -> bool:
	for node in get_children():
		if node is WorldCollectible and not node.is_queued_for_deletion() and node.global_position.distance_to(spot) < 1.0:
			return true
	return false

func _herb_quest(herb_data: Dictionary) -> String:
	var own := str(herb_data.get("quest", ""))
	return own if not own.is_empty() else RegionCatalog.herb_quest(current_region)

## A quest just started: its herbs and enemies in this region appear now.
func _on_quest_started(quest_id: String) -> void:
	request_autosave()
	if world != null:
		spawn_story_objects()
	if world == null:
		return
	for herb_data in _layout().get("herbs", []):
		if _herb_quest(herb_data) == quest_id and not _collectible_at(_vec(herb_data.get("position"))):
			_spawn_herb(_vec(herb_data.get("position")), str(herb_data.get("id", "moonleaf")), str(herb_data.get("name", "Лунный лист")), str(herb_data.get("quest", "")))
	spawn_quest_enemies(quest_id)

## Enemies tied to a quest ("quest" in the region layout) appear when it opens.
func spawn_quest_enemies(quest_id: String) -> void:
	for enemy_data in _layout().get("enemies", []):
		if str(enemy_data.get("quest", "")) == quest_id:
			spawn_enemy(str(enemy_data.get("kind", "slime")), _vec(enemy_data.get("position")), str(enemy_data.get("elite", "")))

func _spawn_waystone(layout: Dictionary) -> void:
	var spot: Variant = layout.get("waystone", null)
	if not spot is Array:
		return
	var stone := WAYSTONE_SCRIPT.new() as Waystone
	stone.region_id = current_region
	add_child(stone)
	stone.global_position = _vec(spot)
	stone.set_awake(waystone_awake(current_region))
	stone.used.connect(_on_waystone_used)

# --- Dungeons: locked doors and spike traps ----------------------------------

func _spawn_dungeon(layout: Dictionary) -> void:
	for entry in layout.get("doors", []):
		var door := DUNGEON_DOOR_SCRIPT.new() as DungeonDoor
		door.door_id = str(entry.get("id", ""))
		door.key_item = str(entry.get("key", ""))
		for lever_id in entry.get("levers", []):
			door.levers.append(str(lever_id))
		door.is_open = bool(opened_doors.get(door.door_id, false))
		add_child(door)
		door.global_position = _vec(entry.get("position"))
		door.used.connect(_on_door_used)
	for spot in layout.get("traps", []):
		var trap: Node2D
		if spot is Dictionary and str(spot.get("kind", "")) == "vent":
			trap = FlameVent.new()
			spot = spot.get("position")
		else:
			trap = SPIKE_TRAP_SCRIPT.new() as SpikeTrap
		add_child(trap)
		trap.global_position = _vec(spot)
	for entry in layout.get("levers", []):
		var lever := DungeonLever.new()
		lever.lever_id = str(entry.get("id", ""))
		lever.pulled = bool(opened_doors.get(lever.lever_id, false))
		add_child(lever)
		lever.global_position = _vec(entry.get("position"))
		lever.used.connect(_on_lever_used)

## Pulling a lever; seals open once all their levers are down.
func _on_lever_used(lever: DungeonLever) -> void:
	if lever.pulled:
		return
	opened_doors[lever.lever_id] = true
	lever.set_pulled(true)
	GameAudio.play("chest", -4.0, 0.1)
	shake(1.5, 0.15)
	for node in get_children():
		if node is DungeonDoor and not node.is_open and not node.levers.is_empty():
			var done: int = node.levers.filter(func(id: String) -> bool: return bool(opened_doors.get(id, false))).size()
			if done >= node.levers.size():
				opened_doors[node.door_id] = true
				node.set_open(true)
				shake(3.0, 0.3)
				hud.show_message("Где-то с грохотом открылась печать!", 3.0)
			else:
				hud.show_message("Рычаг опущен. Печать: %d из %d." % [done, node.levers.size()], 2.5)
	request_autosave()

func _on_door_used(door: DungeonDoor) -> void:
	if door.is_open:
		return
	if not door.levers.is_empty():
		var done: int = door.levers.filter(func(id: String) -> bool: return bool(opened_doors.get(id, false))).size()
		hud.show_message("Печать держат рычаги: опущено %d из %d. Найдите остальные." % [done, door.levers.size()], 3.0)
		return
	if not player.remove_item(door.key_item, 1):
		hud.show_message("Заперто. Нужен ключ: %s." % player.get_item_name(door.key_item), 2.5)
		return
	opened_doors[door.door_id] = true
	door.set_open(true)
	GameAudio.play("chest", -2.0, 0.0)
	shake(2.0, 0.2)
	hud.show_message("Решётка поднимается!", 2.0)
	request_autosave()

## Landmarks that change with quests (the lighthouse lights up).
func _spawn_dynamic_props(layout: Dictionary) -> void:
	for entry in layout.get("dynamic_props", []):
		var lit := quests.is_completed(str(entry.get("lit_quest", "")))
		var object := SETTLEMENT_OBJECT_SCRIPT.new() as SettlementObject
		object.kind = "house"
		object.art = str(entry.get("lit_art", "")) if lit else str(entry.get("art", ""))
		object.set_meta("dynamic", true)
		add_child(object)
		object.global_position = _vec(entry.get("position"))

func _refresh_dynamic_props() -> void:
	for node in get_children():
		if node is SettlementObject and node.has_meta("dynamic"):
			remove_child(node)
			node.queue_free()
	_spawn_dynamic_props(_layout())

# --- Gathering and crafting stations -----------------------------------------

func _spawn_gathering(layout: Dictionary) -> void:
	_spawn_gathering_entries(layout.get("gather", []))
	_spawn_craft_stations()

## only_state: spawn just the entries that need this world state (they appear
## mid-visit, e.g. the rich veins of a freed mine).
func _spawn_gathering_entries(entries: Array, only_state: String = "") -> void:
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		if not layout_allows(entry):
			continue
		if not only_state.is_empty() and str(entry.get("requires_state", "")) != only_state:
			continue
		var info := crafting.kind(str(entry.get("kind", "")))
		if info.is_empty():
			continue
		var node := GATHER_NODE_SCRIPT.new() as GatherNode
		node.key = "%s:%d" % [current_region, index]
		node.kind = str(entry.get("kind", ""))
		node.display_name = str(info.get("name", node.kind))
		node.art = str(info.get("art", "gather_wood"))
		node.verb = str(info.get("verb", "собрать"))
		add_child(node)
		node.global_position = _vec(entry.get("position"))
		node.set_ready(crafting.is_ready(node.key))
		node.used.connect(crafting.gather)

func _spawn_craft_stations() -> void:
	var stations: Dictionary = crafting.data.get("placements", {}).get(current_region, {})
	for station_id in stations:
		var info := crafting.station(str(station_id))
		var station := CRAFT_STATION_SCRIPT.new() as CraftStation
		station.station_id = str(station_id)
		station.display_name = str(info.get("name", station_id))
		station.art = str(info.get("art", ""))
		add_child(station)
		station.global_position = _vec(stations[station_id])
		station.used.connect(func(s: CraftStation) -> void: crafting.open(s.station_id))

# --- Settlement: board, plots and houses in the village ----------------------

func _spawn_settlement() -> void:
	if current_region != settlement.village_region():
		return
	var board_pos: Array = settlement.data.get("board", {}).get("position", [0, 0])
	_spawn_settlement_object("board", "village_board", Vector2(float(board_pos[0]), float(board_pos[1])))
	for entry in settlement.data.get("plots", []):
		var p: Array = entry.get("position", [0, 0])
		var plot_id := str(entry.get("id", ""))
		var art := "village_plot"
		var kind := "plot"
		if settlement.homes.has(plot_id):
			art = str(settlement.settler(str(settlement.homes[plot_id])).get("house", "village_house_small"))
			kind = "house"
		_spawn_settlement_object(kind, art, Vector2(float(p[0]), float(p[1])))
	farm.spawn()
	buildings.spawn()

func _spawn_settlement_object(kind: String, art: String, at: Vector2) -> void:
	var object := SETTLEMENT_OBJECT_SCRIPT.new() as SettlementObject
	object.kind = kind
	object.art = art
	add_child(object)
	object.global_position = at
	if kind == "board":
		object.used.connect(func(_o: SettlementObject) -> void: settlement.open_board())

## A village building grew a level (settlement.upgrade).
func on_building_upgraded(building_id: String) -> void:
	if building_id == Farm.BUILDING:
		farm.refresh()
	elif current_region == settlement.village_region():
		refresh_settlement()

## Rebuilds the village objects and settlers after a house goes up.
func refresh_settlement() -> void:
	for node in get_children():
		if node is SettlementObject or node is FarmBed or node is FarmPatch or (node is WorldNpc and node.npc_id.begins_with("settler_")):
			remove_child(node)
			node.queue_free()
	_spawn_settlement()
	for npc_data in settlement.npcs_for(current_region):
		_spawn_npc(npc_data)
	update_npc_markers()

func waystone_awake(region_id: String) -> bool:
	return director.has_flag("waystone_" + region_id)

## Regions with an awakened stone, in world order.
func travel_destinations() -> Array[String]:
	var result: Array[String] = []
	for region_id in RegionCatalog.all():
		if RegionCatalog.waystone(region_id) is Array and waystone_awake(region_id):
			result.append(str(region_id))
	return result

func _on_waystone_used(stone: Waystone) -> void:
	if not stone.awake:
		director.set_flag("waystone_" + stone.region_id)
		stone.set_awake(true)
		Vfx.sparkle(self, stone.global_position)
		GameAudio.play("quest", -4.0, 0.0)
		hud.show_message("Небесный камень пробуждён. Перемещение — на карте (M).", 3.5)
		request_autosave()
		return
	open_map(true)

## The map (M). From a sky stone it opens on the world tab, ready to travel.
func open_map(world_tab: bool = false) -> void:
	quest_nav.refresh()
	hud.open_world_map(current_region, player.global_position, discovered_landmarks.get(current_region, {}), quests.get_active_summary())
	var live := minimap_markers()
	live.append_array(treasure.minimap_marker())
	live.append_array(epilogue.minimap_marker())
	live.append_array(quest_nav.minimap_markers())
	hud.world_map.set_live(live, player.facing)
	var destinations := travel_destinations()
	hud.world_map_view.set_destinations(current_region, destinations)
	var goal := quest_nav.main_region()
	hud.world_map_view.set_world(current_region, visited_regions, destinations, quest_nav.region_badges(), QuestNav.route(current_region, goal) if not goal.is_empty() else [])
	if world_tab:
		hud.world_map_view.show_world(true)

## Fast travel to an awakened stone. Refused during a boss fight.
func fast_travel(region_id: String) -> bool:
	if region_id == current_region or not waystone_awake(region_id):
		return false
	for actor in get_children():
		if actor is GroveGuardian and not actor.is_queued_for_deletion() and actor.health > 0:
			hud.show_message("Нельзя переместиться посреди битвы.", 2.5)
			return false
	hud.close_world_map()
	_travel(region_id, _vec(RegionCatalog.waystone(region_id)) + Vector2(0, 26))
	return true

const MINIMAP_DISCOVER := 160.0
var _minimap_clock: float = 0.0

func _update_minimap() -> void:
	_discover_landmarks()
	quest_nav.refresh()
	_draw_minimap()

func _discover_landmarks() -> void:
	var region_markers: Dictionary = discovered_landmarks.get(current_region, {})
	for actor in get_children():
		var kind := _landmark_kind(actor)
		if kind.is_empty():
			continue
		if player.global_position.distance_squared_to(actor.global_position) > MINIMAP_DISCOVER * MINIMAP_DISCOVER:
			continue
		var marker_id: String = "%s_%d_%d" % [kind, int(actor.global_position.x), int(actor.global_position.y)]
		if not region_markers.has(marker_id):
			region_markers[marker_id] = {"position": [actor.global_position.x, actor.global_position.y], "kind": kind}
	discovered_landmarks[current_region] = region_markers

func _draw_minimap() -> void:
	hud.minimap.update_map(current_region, player.global_position, discovered_landmarks.get(current_region, {}))
	var live := minimap_markers()
	live.append_array(treasure.minimap_marker())
	live.append_array(epilogue.minimap_marker())
	live.append_array(quest_nav.minimap_markers())
	hud.minimap.day_time = day_night.time if day_night.cycles_here() else -1.0
	hud.minimap.set_live(live, player.facing)
	if hud.world_map_visible:
		hud.world_map.set_live(live, player.facing)

## Kind of a saved landmark for a world object ("" if it is not one).
func _landmark_kind(actor: Node) -> String:
	if actor is WorldNpc:
		return "npc"
	if actor is RegionGate:
		return "gate"
	if actor is TreasureChest:
		return "chest"
	if actor is Waystone:
		return "waystone"
	if actor is CraftStation:
		return "station"
	if actor is GatherNode and actor.kind == "fish":
		return "fish"
	return ""

## Icons that reflect the present: quest givers, unopened chests, exits,
## quest items and enemies near the hero.
func minimap_markers() -> Array:
	var known: Dictionary = discovered_landmarks.get(current_region, {})
	var result: Array = []
	for actor in get_children():
		if not actor is Node2D or actor.is_queued_for_deletion():
			continue
		var at: Vector2 = actor.global_position
		var id := "%s_%d_%d" % [_landmark_kind(actor), int(at.x), int(at.y)]
		if actor is RegionGate:
			result.append({"kind": "gate", "position": at, "label": RegionCatalog.display_name(actor.target_region)})
		elif actor is WorldNpc and known.has(id):
			var marker := str(actor.marker)
			result.append({"kind": marker if marker in ["quest", "ready", "service"] else "npc", "position": at})
		elif actor is TreasureChest and known.has(id) and not actor.is_opened:
			result.append({"kind": "chest", "position": at})
		elif actor is WorldCollectible and not str(actor.quest_id).is_empty() and quests.is_active(str(actor.quest_id)):
			if player.global_position.distance_squared_to(at) < 400.0 * 400.0:
				result.append({"kind": "item", "position": at})
		elif actor is SlimeEnemy and actor.health > 0 and player.global_position.distance_squared_to(at) < 260.0 * 260.0:
			var kind := "enemy"
			if enemy_kind(actor) in STORY_BOSSES:
				kind = "boss"
			elif actor.has_meta("legend"):
				kind = "boss"
			elif not actor.elite_id.is_empty() or actor is LootImp:
				kind = "elite"
			result.append({"kind": kind, "position": at})
	return result

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
	if enemy is LootImp:
		return "loot_imp"
	if enemy is PatternShade:
		return "pattern_shade"
	if enemy is PatternVoice:
		return "pattern_voice"
	if enemy is ForgeTitan:
		return "forge_titan"
	if enemy is AshLord:
		return "ash_lord"
	if enemy is EmberHound:
		return "ember_hound"
	if enemy is MagmaGolem:
		return "magma_golem"
	if enemy is AshCultist:
		return "ash_cultist"
	if enemy is CryptLord:
		return "crypt_lord"
	if enemy is VailBoss:
		return "vail"
	if enemy is BogKing:
		return "bog_king"
	if enemy is CrabKing:
		return "crab_king"
	if enemy is MountainGiant:
		return "giant"
	if enemy is TempestColossus:
		return "tempest"
	if enemy is EchoWarden:
		return "echo"
	if enemy is GroveGuardian:
		return "guardian"
	if enemy is RiftShade:
		return "shade"
	if enemy is SkySentinel:
		return "sentinel"
	if enemy is ForestShaman:
		return "shaman"
	if enemy is WindWisp:
		return "wisp"
	if enemy is MarshToad:
		return "toad"
	if enemy is CoastCrab:
		return "crab"
	if enemy is OreGolem:
		return "ore_golem"
	if enemy is StoneGolem:
		return "golem"
	if enemy is Skeleton:
		return "skeleton"
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
	# "requires_flag": "ending" — only after the finale choice.
	var needs_flag := str(npc_data.get("requires_flag", ""))
	if needs_flag == "ending" and epilogue.ending().is_empty():
		return
	if not layout_allows(npc_data):
		return
	if not needs_flag.is_empty() and needs_flag != "ending" and not director.has_flag(needs_flag):
		return
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
	elif settlement.has_settler_npc(npc_id):
		npc.interacted.connect(func(_source: Node2D) -> void: settlement.talk(npc_id))
	elif givers.has_giver(npc_id):
		npc.interacted.connect(func(_source: Node2D) -> void: givers.talk(npc_id))
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
	_scale_to_region(enemy)
	_fit_to_view(enemy)
	_track_kill_quests(enemy, kind)
	if enemy is GroveGuardian:
		GameAudio.play("boss_roar", -2.0, 0.0)
		update_music.call_deferred()
	match kind:
		"guardian":
			enemy.defeated.connect(func(xp: int) -> void: _on_guardian_defeated(xp, enemy.global_position))
		"echo", "tempest", "vail", "bog_king", "crab_king", "giant", "crypt_lord", "ash_lord", "forge_titan", "pattern_voice", "pattern_shade":
			enemy.defeated.connect(func(xp: int) -> void: _on_story_boss_defeated(kind, xp, enemy.global_position))
		"wolf":
			enemy.defeated.connect(func(xp: int) -> void:
				_on_wolf_defeated(xp, enemy.global_position, not enemy.elite_id.is_empty())
				_on_elite_defeated(enemy))
		_:
			enemy.defeated.connect(func(xp: int) -> void:
				_on_enemy_defeated(xp, enemy.global_position, kind, not enemy.elite_id.is_empty())
				_on_elite_defeated(enemy))
	return enemy

func _spawn_guardian(spawn_position: Vector2) -> void:
	spawn_enemy("guardian", spawn_position)

func _spawn_herb(spawn_position: Vector2, item_id: String = "moonleaf", label: String = "Лунный лист", quest_id: String = "") -> void:
	var herb := COLLECTIBLE_SCRIPT.new() as WorldCollectible
	herb.item_id = item_id
	herb.quest_id = quest_id
	herb.display_name = label
	add_child(herb)
	herb.global_position = spawn_position
	herb.interacted.connect(_on_herb_interacted)

func _spawn_chest(id: String, at_position: Vector2, gold: int, item: String, amount: int, tier: String = "wood") -> void:
	var chest := CHEST_SCRIPT.new() as TreasureChest
	chest.tier = tier
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
	chest.opened.connect(func(_id: String, _gold: int, _item: String, _amount: int) -> void: chest_tier_reward(chest.tier, chest.global_position))
	chest.bonus_found.connect(_on_chest_bonus)

func _spawn_gate(target_region: String, gate_position: Vector2, arrival: Vector2, label: String) -> void:
	var gate := GATE_SCRIPT.new() as RegionGate
	gate.target_region = target_region
	gate.arrival_position = arrival
	gate.display_name = label
	gate.art_style = RegionCatalog.style(current_region)
	var size: Vector2 = world.map_size() if world != null and world.has_method("map_size") else Vector2(1280, 864)
	var look := RegionGate.pick_kind(gate.art_style, RegionCatalog.style(target_region), gate_position, size)
	gate.kind = str(look["kind"])
	gate.outward = look["outward"]
	gate.edge_distance = float(look["edge_distance"])
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

## Magic bolts report hits (gear effects such as the jelly staff).
func on_spell_hit(enemy: Node) -> void:
	if gear != null:
		gear.on_spell_hit(enemy)

## Enemies report elemental combos here (enemy.gd → _announce_reaction).
func on_reaction(reaction_id: String, at: Vector2) -> void:
	if combos != null:
		combos.on_reaction(reaction_id, at)

func _on_tavern_keeper_interacted(_source: Node2D) -> void:
	buildings.talk_tavern()

func _on_guild_master_interacted(_source: Node2D) -> void:
	guild.talk()

func _on_librarian_interacted(_source: Node2D) -> void:
	buildings.talk_library()

func _on_pass_miner_interacted(_source: Node2D) -> void:
	mine.talk_miner()

## Rewards for quests handed out in code (Borin's story).
func npc_reward(quest_id: String) -> void:
	var summary := dialogues._grant_reward(quests.get_reward(quest_id))
	hud.show_message("Задание выполнено: %s%s" % [str(quests.definitions.get(quest_id, {}).get("title", quest_id)), (" · " + summary) if not summary.is_empty() else ""], 3.5)

## Rebuilds the land's art after the world changed (new buildings).
func refresh_world_art() -> void:
	if world != null and world.has_method("configure_region"):
		world.set("allows", layout_allows)
		world.configure_region(current_region)

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
			actor.set_marker(dialogues.marker_style(actor.npc_id, marker))

func _show_dialogue(speaker: String, message: String) -> void:
	player.set_physics_process(false)
	hud.show_dialogue(speaker, StoryText.format(_vary_line(speaker, message)))

## The same NPC doesn't repeat the same line: on a repeat they make small talk
## from data/chatter.json (rotating), and every third time remind the task.
var _chatter: Dictionary = {}
var _last_said: Dictionary = {}
var _repeat_count: Dictionary = {}

func _vary_line(speaker: String, message: String) -> String:
	if _chatter.is_empty():
		var file := FileAccess.open("res://data/chatter.json", FileAccess.READ)
		_chatter = JSON.parse_string(file.get_as_text()) if file != null else {"speakers": {}}
	if str(_last_said.get(speaker, "")) != message:
		_last_said[speaker] = message
		_repeat_count[speaker] = 0
		return message
	var count: int = int(_repeat_count.get(speaker, 0)) + 1
	_repeat_count[speaker] = count
	if count % 3 == 0:
		return message
	var pool: Array = (_chatter.get("speakers", {}) as Dictionary).get(speaker, []).duplicate()
	if pool.size() < 3:
		pool.append_array(_chatter.get("_any", []))
	if pool.is_empty():
		return message
	var key := speaker + "#chat"
	var line := str(pool[randi() % pool.size()])
	if pool.size() > 1:
		while line == str(_last_said.get(key, "")):
			line = str(pool[randi() % pool.size()])
	_last_said[key] = line
	return line

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
	achievements.add("chests")
	GameAudio.play("chest", -2.0, 0.0)
	latest_cache_narrative = id == CARTOGRAPHER_CACHE_ID
	gold = roundi(float(gold) * player.get_gold_multiplier())
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
	update_music.call_deferred()
	if guardian_defeated:
		return
	guardian_defeated = true
	achievements.add("bosses")
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
	achievements.add("bosses")
	# Every great foe guards a page of the Keepers' lore.
	_spawn_loot(death_position + Vector2(-16, 8), VillageBuildings.TOME)
	if kind == "pattern_shade":
		achievements.add("shade")
	player.add_experience(xp)
	_spawn_loot(death_position, "ancient_relic")
	spawn_generated_loot(death_position + Vector2(14, 6), "rare")
	shake(6.0, 0.6)
	hit_stop(0.2)
	update_music.call_deferred()
	hud.show_message("%s повержен!" % STORY_BOSSES[kind], 3.0)
	_grant_sky_seal()
	director.on_boss_defeated(kind)
	request_autosave()

func _on_wolf_defeated(xp_reward: int, death_position: Vector2, elite: bool = false) -> void:
	if quests.active_quest_id == "toren_wolf_hunt" and not quests.is_completed("toren_wolf_hunt"):
		quests.add_progress("toren_wolf_hunt", 1)
		var progress: int = int(quests.states["toren_wolf_hunt"].get("progress", 0))
		hud.show_message("Волк побеждён! Охота: %d/3." % progress, 2.0)
		if quests.is_ready_to_complete("toren_wolf_hunt"):
			hud.show_message("Стая отступила. Вернись к Торену за наградой.", 3.0)
	_refresh_hud()
	_spawn_loot(death_position, "wolf_pelt")
	_on_enemy_defeated(xp_reward, death_position, "wolf", elite)

func _on_enemy_defeated(xp_reward: int, death_position: Vector2, kind: String = "", elite: bool = false) -> void:
	player.add_experience(xp_reward)
	gear.on_kill()
	defeated_enemies += 1
	contracts.on_kill(kind)
	achievements.add("kills")
	achievements.set_max("gold", player.gold)
	var starter: Array[String] = ["apprentice_staff", "leather_armor", "mana_amulet"]
	if defeated_enemies <= starter.size():
		_spawn_loot(death_position, starter[defeated_enemies - 1])
	roll_drops(kind, death_position, elite)
	hud.show_message("Противник побеждён! +%d опыта" % xp_reward, 1.5)

## Field crafting from the bag (B): potions, whetstones and gear from
## monster materials, no station needed.
func open_handcraft() -> void:
	if hud.inventory_open:
		hud.toggle_inventory(player)
	crafting.open("hand")

## Iron chests hold uncommon+ equipment, golden ones rare+ and extra loot.
func chest_tier_reward(tier: String, at: Vector2) -> String:
	match tier:
		"iron":
			return spawn_generated_loot(at + Vector2(0, 14), "uncommon")
		"gold":
			_spawn_loot(at + Vector2(-12, 12), "gold").amount = 40 + 10 * player.level
			if loot_rng.randf() < 0.35:
				_spawn_loot(at + Vector2(12, -6), TreasureHunt.MAP_ITEM)
			if loot_rng.randf() < 0.2:
				_spawn_loot(at + Vector2(-14, -4), VillageBuildings.TOME)
			return spawn_generated_loot(at + Vector2(10, 14), "rare")
	return ""

## Drop tables (data/drops.json): coins, monster materials, potions and a
## chance of rolled equipment, each scattered around the body.
func roll_drops(kind: String, at: Vector2, elite: bool = false) -> Array:
	var tables := drop_tables()
	var table: Dictionary = (tables.get("defaults", {}) as Dictionary).duplicate()
	table.merge(tables.get("monsters", {}).get(kind, {}), true)
	var dropped: Array = []
	var gold_range: Array = table.get("gold", [0, 0])
	if loot_rng.randf() < float(table.get("gold_chance", 0.7)) or elite:
		var coins := loot_rng.randi_range(int(gold_range[0]), int(gold_range[1])) + maxi(0, enemy_power_bonus())
		if elite:
			coins *= int(tables.get("elite", {}).get("gold_mult", 3))
		coins = roundi(float(coins) * player.get_gold_multiplier() * (1.3 if day_night != null and day_night.night_here() else 1.0) * (epilogue.gold_mult() if epilogue != null else 1.0))
		if coins > 0:
			_spawn_loot(_scatter(at), "gold").amount = coins
			dropped.append("gold")
	for entry in table.get("items", []):
		if loot_rng.randf() < float(entry.get("chance", 0.0)) * LOOT_RATE:
			_spawn_loot(_scatter(at), str(entry.get("item", "")))
			dropped.append(str(entry.get("item", "")))
	if loot_rng.randf() < float(table.get("potion", 0.2)) * LOOT_RATE:
		var potion := "health_potion" if loot_rng.randf() < 0.6 else "mana_potion"
		_spawn_loot(_scatter(at), potion)
		dropped.append(potion)
	if not elite and loot_rng.randf() < float(table.get("gear", LootGenerator.drop_chance())) * GEAR_RATE:
		dropped.append(spawn_generated_loot(_scatter(at)))
	if not RegionCatalog.is_underground(RegionCatalog.style(current_region)) and loot_rng.randf() < 0.015:
		_spawn_loot(_scatter(at), TreasureHunt.MAP_ITEM)
		dropped.append(TreasureHunt.MAP_ITEM)
	return dropped

## Balance: monster drops and experience (lower = slower, rarer).
const LOOT_RATE := 0.6
const GEAR_RATE := 0.45
const XP_RATE := 0.7

var _drop_tables: Dictionary = {}

func drop_tables() -> Dictionary:
	if _drop_tables.is_empty():
		var file := FileAccess.open("res://data/drops.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_drop_tables = parsed
	return _drop_tables

## Stronger lands pay a little more per kill.
func enemy_power_bonus() -> int:
	return int(_layout().get("level", 1)) - 1

func _scatter(at: Vector2) -> Vector2:
	return at + Vector2(loot_rng.randf_range(-14.0, 14.0), loot_rng.randf_range(-8.0, 10.0))

## Elites always leave equipment (uncommon or better).
func _on_elite_defeated(enemy: SlimeEnemy) -> void:
	if enemy.elite_id.is_empty():
		return
	achievements.add("elites")
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
	if item_id == "gold":
		player.add_gold(amount)
		GameAudio.play("pickup", -8.0, 0.15)
		hud.show_message("+%d золота" % amount, 1.2)
		return
	player.add_item(item_id, amount)
	GameAudio.play("pickup", -4.0, 0.02)
	hud.show_message("Получено: %s ×%d" % [player.get_item_name(item_id), amount], 2.0)

# --- Inventory -----------------------------------------------------------

func _on_inventory_unequip(slot: String) -> void:
	if hud.dialogue_visible or get_tree().paused:
		return
	if player.unequip_slot(slot):
		hud.show_message("Экипировка снята.", 1.5)
		hud.refresh_inventory(player)

func _on_inventory_use(item_id: String) -> void:
	if item_id == TreasureHunt.MAP_ITEM:
		treasure.read_map()
		hud.refresh_inventory(player)
		return
	if item_id in MATERIAL_ITEMS or bool(player.get_item_definition(item_id).get("material", false)):
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
	GameAudio.play("level_up", -2.0, 0.0)
	achievements.set_max("level", new_level)
	request_autosave()
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

## A new build: all skill points (and sky seals) come back for gold.
func reset_skills() -> bool:
	if SkillTree.spent_points(player) <= 0:
		hud.show_message("Навыки ещё не изучены.", 2.0)
		return false
	if not SkillTree.reset(player):
		hud.show_message("Сброс стоит %d золота." % SkillTree.reset_cost(player), 2.5)
		return false
	hud.show_message("Навыки сброшены: очков — %d. Соберите новый билд!" % SkillTree.available_points(player), 3.0)
	hud.refresh_skill_tree(player)
	_refresh_hud()
	request_autosave()
	return true

## Bosses grant a Sky Seal that unlocks one tier-3 skill.
func _grant_sky_seal() -> void:
	player.add_item(SkillTree.SEAL_ITEM)
	hud.show_message("Получена Печать Неба! Она открывает высший навык ветки (T).", 4.0)

# --- Magic ---------------------------------------------------------------

func _update_spell_hud() -> void:
	if player.has_bow() and hud.spell_label != null:
		var ready := cast_cooldown_remaining <= 0.0
		hud.spell_label.text = "Лук · ПКМ · удерживать — прицельный" + (" · ГОТОВО" if ready else "")
		hud.spell_label.modulate = Color.WHITE
		hud.spell_cooldown_bar.value = 1.0 - (cast_cooldown_remaining / cast_cooldown_total if cast_cooldown_total > 0.0 else 0.0)
		return
	if not magic_unlocked():
		if hud.spell_label != null:
			hud.spell_label.text = "Меч · ЛКМ · удерживать — вихрь"
			hud.spell_label.modulate = Color.WHITE
			hud.spell_cooldown_bar.value = 1.0 - attack_cooldown / (SLASH_COOLDOWN * 2.0)
		return
	var spell: Dictionary = spell_definitions.get(selected_spell_id, {})
	hud.update_spell(str(spell.get("name", selected_spell_id)), int(spell.get("mana_cost", 0)), player.mana, cast_cooldown_remaining, cast_cooldown_total)

func select_spell(spell_id: String) -> void:
	if not spell_definitions.has(spell_id):
		return
	selected_spell_id = spell_id
	hud.show_message("Магия: " + str(spell_definitions[spell_id].get("name", spell_id)), 1.5)
	_update_spell_hud()

# --- Sword -------------------------------------------------------------------

const SLASH_COOLDOWN := 0.3
const COMBO_WINDOW := 0.65
const CHARGE_TIME := 0.5
const SLASH_REACH := 30.0
const SPIN_REACH := 40.0

var attack_cooldown: float = 0.0
var _combo_step: int = 0
var _combo_timer: float = 0.0
var _attack_holding: bool = false
var _attack_held: float = 0.0
var _charging: bool = false

func _aim_direction() -> Vector2:
	# Headless runs (tests) have no mouse: strike where the hero faces.
	if DisplayServer.get_name() == "headless":
		return player.facing.normalized()
	var direction := (get_global_mouse_position() - player.global_position)
	return direction.normalized() if direction.length_squared() > 1.0 else player.facing

func _attack_pressed() -> void:
	_attack_holding = true
	_attack_held = 0.0
	sword_slash()

func _attack_released() -> void:
	_attack_holding = false
	if _charging:
		_charging = false
		sword_spin()

func _update_sword(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if _combo_timer <= 0.0:
		_combo_step = 0
	if _attack_holding and not _charging:
		_attack_held += delta
		if _attack_held >= CHARGE_TIME - 0.15 * float(player.talents.get("whirl_master", 0)) and player.health > 0:
			_charging = true
			player.visual.play_named("charge", 30.0)
			Vfx.sparkle(self, player.global_position + Vector2(0, -8))

## Two-hit combo in front of the hero (towards the mouse).
func sword_slash() -> bool:
	if attack_cooldown > 0.0 or player.health <= 0 or player.dodge_time_left > 0.0:
		return false
	var direction := _aim_direction()
	player.facing = direction
	player.visual.set_direction_vector(direction)
	var finisher := _combo_step == 2
	var anim := "spin" if finisher else ("slash1" if _combo_step == 0 else "slash2")
	player.visual.play_named(anim, 0.36 if finisher else 0.28)
	var damage := player.get_melee_damage() + (2 if _combo_step == 1 else 0)
	var hits := 0
	if finisher:
		# Blade Dance: the third swing is a full circle at double damage.
		hits = _melee_hit(player.global_position, direction, SPIN_REACH, 360.0, damage * 2, 150.0)
		_ring(player.global_position, SPIN_REACH, Color(1.0, 0.85, 0.5, 0.8))
	else:
		hits = _melee_hit(player.global_position, direction, SLASH_REACH, 75.0, damage, 110.0)
	GameAudio.play("dash" if hits == 0 else "hit", -4.0, 0.1)
	_combo_step = (_combo_step + 1) % (3 if player.has_skill("blade_dance") else 2)
	_combo_timer = COMBO_WINDOW
	attack_cooldown = SLASH_COOLDOWN
	return true

## Held attack: a full circle at 1.8x damage.
func sword_spin() -> bool:
	if player.health <= 0:
		return false
	player.visual.play_named("spin", 0.42)
	var hits := _melee_hit(player.global_position, Vector2.RIGHT, SPIN_REACH, 360.0, int(round(player.get_melee_damage() * (1.8 + 0.45 * float(player.talents.get("whirl_master", 0))))), 170.0)
	GameAudio.play("gust", -4.0, 0.05)
	Vfx.burst(self, player.global_position, [Color(1, 1, 1), Color(0.8, 0.9, 1.0)], 14, 90.0)
	if hits > 0:
		shake(2.5, 0.2)
	attack_cooldown = SLASH_COOLDOWN * 2.0
	return true

## Enemies struck by the latest sword hit (skills add effects to them).
var last_hit_enemies: Array = []
## Rolls for crits in tests; seeded randomly in play.
var crit_rng := RandomNumberGenerator.new()

func _living_enemies() -> Array:
	var result: Array = []
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as SlimeEnemy
		if enemy != null and not enemy.is_queued_for_deletion() and enemy.health > 0:
			result.append(enemy)
	return result

## One sword blow: crit roll, lifesteal, knockback.
func _strike(enemy: SlimeEnemy, damage: int, push_direction: Vector2, push: float) -> void:
	var crit := crit_rng.randf() < player.get_crit_chance()
	if crit:
		damage *= 2
		Vfx.sparkle(self, enemy.global_position)
	var shaped := gear.modify_strike(damage)
	damage = int(shaped["damage"])
	if bool(shaped["riposte"]):
		enemy.combat_feedback.show_reaction("КОНТРАТАКА!")
		Vfx.sparkle(self, enemy.global_position)
		shake(3.0, 0.15)
	enemy.take_damage(damage)
	enemy.apply_knockback(push_direction, push)
	last_hit_enemies.append(enemy)
	combos.on_strike(enemy, damage)
	gear.on_strike(enemy, damage)
	var heal := player.get_melee_lifesteal()
	if heal > 0 and player.health < player.max_health:
		player.health = mini(player.max_health, player.health + heal)
		player.stats_changed.emit()

## Damages enemies within reach and the arc (degrees); returns how many.
func _melee_hit(origin: Vector2, direction: Vector2, reach: float, arc: float, damage: int, push: float) -> int:
	last_hit_enemies.clear()
	for enemy in _living_enemies():
		var offset: Vector2 = enemy.global_position - origin
		if offset.length() > reach + 8.0:
			continue
		if arc < 360.0 and offset.length() > 4.0 and rad_to_deg(absf(direction.angle_to(offset))) > arc * 0.5:
			continue
		_strike(enemy, damage, offset.normalized() if offset.length() > 0.1 else direction, push)
	return last_hit_enemies.size()

## Damages enemies in a strip in front of origin (lunge, blade wave).
func _line_hit(origin: Vector2, direction: Vector2, length: float, width: float, damage: int, push: float) -> int:
	last_hit_enemies.clear()
	for enemy in _living_enemies():
		var offset: Vector2 = enemy.global_position - origin
		var along := offset.dot(direction)
		if along < -6.0 or along > length:
			continue
		if absf(offset.cross(direction)) > width * 0.5 + 8.0:
			continue
		_strike(enemy, damage, direction, push)
	return last_hit_enemies.size()

## Short-lived white streak (lunge path, blade wave).
func _streak(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = width
	line.default_color = color
	line.z_index = 30
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)

## Expanding ring (shockwave, war cry, blade dance).
func _ring(at: Vector2, radius: float, color: Color) -> void:
	var line := Line2D.new()
	var points := PackedVector2Array()
	for index in 25:
		points.append(Vector2.RIGHT.rotated(TAU * index / 24.0) * radius)
	line.points = points
	line.width = 2.0
	line.default_color = color
	line.z_index = 30
	line.position = at
	line.scale = Vector2(0.3, 0.3 * 0.6)
	add_child(line)
	var tween := line.create_tween()
	tween.set_parallel(true)
	tween.tween_property(line, "scale", Vector2(1.0, 0.6), 0.25)
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(line.queue_free)

## Puts a newly awakened spell into an empty or still-locked hotbar slot.
func _place_spell_on_hotbar(spell_id: String) -> void:
	if player.skill_slots.has(spell_id):
		return
	for index in player.skill_slots.size():
		var current := str(player.skill_slots[index])
		if current.is_empty() or not skills.lock_reason(current).is_empty():
			player.assign_skill(index, spell_id)
			return
	player.assign_skill(PlayerCharacter.SKILL_SLOT_COUNT - 1, spell_id)

# --- Magic -------------------------------------------------------------------

## Story mode: the heroine starts with the sword; Ilara awakens her magic
## once the grove guardian falls. Free play (tests) has magic from the start.
func magic_unlocked() -> bool:
	return not director.story_mode() or director.has_flag("magic_unlocked")

# --- Bow (ranger) ----------------------------------------------------------

const BOW_COOLDOWN := 0.45
const AIM_TIME := 0.55
var _bow_holding: bool = false
var _bow_held: float = 0.0

func _bow_press() -> void:
	if cast_cooldown_remaining > 0.0 or player.health <= 0:
		return
	_bow_holding = true
	_bow_held = 0.0
	player.visual.play_named("charge", 30.0)

func _update_bow(delta: float) -> void:
	if not _bow_holding:
		return
	var before := _bow_held
	_bow_held += delta
	if before < AIM_TIME and _bow_held >= AIM_TIME:
		Vfx.sparkle(self, player.global_position + Vector2(0, -10))

func _bow_release() -> void:
	if not _bow_holding:
		return
	_bow_holding = false
	var aimed := _bow_held >= AIM_TIME
	var damage := player.get_ranged_damage() * (2 if aimed else 1)
	var pierce := (99 if player.equipment.get("weapon", "") == "wind_bow" else 2) if aimed else 0
	shoot_arrow(_aim_direction(), damage, aimed, pierce)
	player.play_cast(_aim_direction())
	GameAudio.play("dash", -6.0 if not aimed else -2.0, 0.2)
	cast_cooldown_total = BOW_COOLDOWN * (1.6 if aimed else 1.0)
	cast_cooldown_remaining = cast_cooldown_total
	_update_spell_hud()

func shoot_arrow(direction: Vector2, damage: int, aimed: bool, pierce: int = 0) -> Arrow:
	var arrow := Arrow.new()
	arrow.setup(self, direction, damage, pierce, aimed)
	add_child(arrow)
	arrow.global_position = player.global_position + direction.normalized() * 10.0
	return arrow

func _cast_spell() -> void:
	if not magic_unlocked():
		hud.show_message("Магия ещё спит. Пока — меч: ЛКМ, удерживать — круговой удар.", 2.5)
		return
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
	GameAudio.play({"fireball": "cast_fire", "frostbolt": "cast_ice", "chain_lightning": "cast_lightning"}.get(selected_spell_id, "cast_fire"), -5.0)
	cast_cooldown_total = float(spell.get("cooldown", 0.25)) * player.get_cooldown_multiplier()
	cast_cooldown_remaining = cast_cooldown_total
	_update_spell_hud()

func _refresh_hud() -> void:
	if borin != null:
		borin.sync_progress()
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

## Besides saving on every important event, the game saves itself every two
## minutes of play (not in the middle of a conversation or a cutscene).
const AUTOSAVE_INTERVAL := 120.0
var _autosave_clock: float = 0.0

func _tick_autosave(delta: float) -> void:
	_autosave_clock += delta
	if _autosave_clock < AUTOSAVE_INTERVAL:
		return
	if hud.dialogue_visible or story.active or fishing.active():
		return
	_autosave_clock = 0.0
	request_autosave()

func autosave() -> bool:
	_autosave_pending = false
	if not autosave_enabled or game_over or player == null or not is_inside_tree():
		return false
	var success: bool = SAVE_SCRIPT.save_snapshot(make_save_snapshot(), autosave_path())
	if success:
		_autosave_clock = 0.0
		if hud != null:
			hud.show_save_indicator()
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
		hud.toggle_journal(quests, player)

func _go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_menu.tscn")
