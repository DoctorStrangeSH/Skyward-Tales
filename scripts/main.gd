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
## Foes whose touch is magic (the hero's resist counts, not armour).
const MAGIC_FOES := ["wisp", "shade", "echo", "tempest", "vail", "pattern_voice", "pattern_shade"]
const STORY_BOSSES := {"echo": "Отголосок", "tempest": "Буревой колосс", "vail": "Вейл", "bog_king": "Болотный король", "crab_king": "Краб-король", "giant": "Горный великан", "crypt_lord": "Повелитель склепа", "ash_lord": "Владыка Пепла", "forge_titan": "Титан Горнила", "pattern_voice": "Голос Узора", "pattern_shade": "Тень Узора"}
const ENEMY_SCRIPTS := {
	"slime": preload("res://scripts/enemy.gd"),
	"wolf": preload("res://scripts/forest_wolf.gd"),
	"windtail": preload("res://scripts/windtail.gd"),
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
var lira: LiraStory
var fair: VillageFair
var grade: ScreenGrade
var bran: BranStory
var combos: ElementalCombos
var gear: GearEffects
var farm: Farm
var seasons: Seasons
var trials: TrialTower
var cistern: Cistern
var hens: VillageHens
var scout: ScoutTrail
var forestry: ForestGuild
var adit: OldAdit
var buildings: VillageBuildings
var guild: AdventurersGuild
var expeditions: Expeditions
var ship: SkyShip
## Modules split out of this file (tech debt): hero combat, input, region building.
var combat: HeroCombat = HeroCombat.new(self)
var builder: WorldBuilder = WorldBuilder.new(self)
var maps: MapTracker = MapTracker.new(self)
var input_handler: GameInput = GameInput.new(self)
var factions: Factions
var fates: IslandFates
var party: Party
## Skill trainers (owner's list №29–30).
var trainers: Trainers
## Companions' levels, skills, gear, tactics and talk (owner's list №18–21).
var crew: Crew
var deep_rifts: DeepRifts
var achievements: Achievements
var lore: LoreBook = LoreBook.new()
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
		_clear_quest_items(quest_id)
		if quest_id == "main_guardian" and director != null and director.story_mode() and not director.has_flag("magic_unlocked"):
			director.set_flag("magic_unlocked")
			# Awakened magic knows one spell; the others are taught.
			player.learn_skill("fireball")
			_place_spell_on_hotbar("fireball")
			hud.show_message("Илара пробудила в вас магию неба! Огненный шар — на панели навыков, ПКМ — заклинание. C — навыки.", 5.0)
			_update_spell_hud()
		request_autosave()
		if quest_id.begins_with("haven_") and achievements != null:
			achievements.add("haven")
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
	grade = ScreenGrade.new()
	grade.name = "ScreenGrade"
	add_child(grade)
	fair = VillageFair.new()
	fair.name = "VillageFair"
	fair.game = self
	add_child(fair)
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
	lira = LiraStory.new(self)
	bran = BranStory.new(self)
	factions = Factions.new(self)
	fates = IslandFates.new(self)
	party = Party.new(self)
	trainers = Trainers.new(self)
	crew = Crew.new(self)
	buildings = VillageBuildings.new(self)
	guild = AdventurersGuild.new(self)
	expeditions = Expeditions.new()
	expeditions.name = "Expeditions"
	expeditions.game = self
	add_child(expeditions)
	ship = SkyShip.new()
	ship.name = "SkyShip"
	ship.game = self
	add_child(ship)
	deep_rifts = DeepRifts.new()
	deep_rifts.name = "DeepRifts"
	deep_rifts.game = self
	add_child(deep_rifts)
	farm = Farm.new()
	farm.name = "Farm"
	farm.game = self
	add_child(farm)
	seasons = Seasons.new()
	seasons.name = "Seasons"
	seasons.game = self
	add_child(seasons)
	trials = TrialTower.new()
	trials.name = "TrialTower"
	trials.game = self
	add_child(trials)
	cistern = Cistern.new()
	cistern.name = "Cistern"
	cistern.game = self
	add_child(cistern)
	hens = VillageHens.new()
	hens.name = "VillageHens"
	hens.game = self
	add_child(hens)
	scout = ScoutTrail.new()
	scout.name = "ScoutTrail"
	scout.game = self
	add_child(scout)
	forestry = ForestGuild.new()
	forestry.name = "ForestGuild"
	forestry.game = self
	add_child(forestry)
	adit = OldAdit.new()
	adit.name = "OldAdit"
	adit.game = self
	add_child(adit)
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
	player.experience_gained.connect(func(amount: int) -> void: crew.on_hero_experience(amount))
	player.level_up.connect(_on_level_up)
	player.died.connect(_on_player_died)
	player.charge_cancelled.connect(func() -> void: combat.cancel_charge())
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
	player.phoenix_triggered.connect(func() -> void:
		hud.show_title_card("Перо феникса!", 2.0)
		Vfx.burst(self, player.global_position, [Color(1, 0.9, 0.5), Color(1, 0.5, 0.2), Color(1, 0.3, 0.1, 0)], 30, 120.0, 0.6))
	_apply_camera_limits()
	StoryText.reset()

	hud = GameHud.new()
	add_child(hud)
	interact_prompt = InteractPrompt.new()
	add_child(interact_prompt)
	hud.inventory_use_requested.connect(_on_inventory_use)
	hud.inventory_equip_to_requested.connect(equip_from_bag)
	hud.inventory_view.set_skills(skills)
	hud.journal_view.achievements = achievements
	hud.journal_view.lore_book = lore
	hud.journal_view.factions_ref = factions
	hud.journal_view.tracking_changed.connect(func() -> void:
		quest_nav.refresh()
		_refresh_hud())
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
	hud.menu_key_requested.connect(func(keycode: int) -> void: _handle_key(keycode as Key))
	hud.menu_tab_requested.connect(func(tab_id: String) -> void: input_handler.open_tab(tab_id))
	hud.tab_provider = input_handler.current_tab
	hud.skills_view.combos = combos
	hud.dialogue_choice_selected.connect(_on_dialogue_choice_selected)
	hud.world_map_view.travel_requested.connect(fast_travel)

	_populate_region()
	update_music.call_deferred()

	# Owner's list №35: the save slot chosen in the title menu.
	if get_tree().has_meta("skyward_slot"):
		save_path = SaveSystem.slot_path(int(get_tree().get_meta("skyward_slot")))
	if get_tree().has_meta("skyward_continue") and bool(get_tree().get_meta("skyward_continue")):
		get_tree().remove_meta("skyward_continue")
		load_game(true)
	elif get_tree().has_meta("skyward_ng_plus"):
		var seed: Dictionary = get_tree().get_meta("skyward_ng_plus")
		get_tree().remove_meta("skyward_ng_plus")
		start_ng_plus(seed)
	elif get_tree().has_meta("skyward_new_hero"):
		var hero: Dictionary = get_tree().get_meta("skyward_new_hero")
		get_tree().remove_meta("skyward_new_hero")
		start_new_story(str(hero.get("name", "")), str(hero.get("gender", "m")))
		# Only the weapon at first: skills are learned from trainers.
		player.skills_need_learning = true
		player.learned_skills = {}
		player.skill_slots = ["", "", "", ""]
		# A new adventure starts with a sword and a plank shield; magic comes later.
		player.add_item("traveler_sword")
		player.equip_item("traveler_sword")
		player.add_item("wooden_shield")
		player.equip_item("wooden_shield")
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

## Region music by art style (stage 20: an orchestral track per kind of land,
## tools/audio/orchestra.py); bosses override it while alive.
const MUSIC_BY_STYLE := {"night": "night", "cave": "caves", "sky": "sky", "spires": "sky", "rift": "rift", "marsh": "marsh",
	"coast": "coast", "mountain": "caves", "crypt": "caves", "ash": "ash", "magma": "ash"}

func update_music() -> void:
	for actor in get_children():
		if actor is GroveGuardian and not actor.is_queued_for_deletion() and actor.health > 0:
			GameAudio.music("boss")
			return
	var style := RegionCatalog.style(current_region)
	update_ambience()
	if fair != null and fair.open_here():
		GameAudio.music("fair")
		return
	GameAudio.music(MUSIC_BY_STYLE.get(style, "meadow"))

## The background bed of the land: wind on the islands, waves on the coast,
## birds by day and crickets by night, drips in caves, crackling in ash.
func ambience_for(region_id: String, night: bool) -> String:
	match RegionCatalog.style(region_id):
		"cave", "crypt":
			return "cave"
		"ash", "magma":
			return "fire"
		"coast":
			return "waves"
		"sky", "spires", "rift", "mountain":
			return "wind"
	return "night" if night else "birds"

var _ambience_clock: float = 0.0

func update_ambience() -> void:
	var night := day_night != null and day_night.night_here()
	GameAudio.ambience(ambience_for(current_region, night))

func shake(strength: float, duration: float) -> void:
	if not GameSettings.get_bool("screen_shake"):
		return
	if strength >= _shake_strength * (_shake_time / maxf(0.01, _shake_duration)):
		_shake_strength = strength
		_shake_duration = duration
		_shake_time = duration

## Where a story scene points the camera (stage 20), relative to the hero.
var cinema_offset := Vector2.ZERO

func hero_camera() -> Camera2D:
	return player.get_node_or_null("Camera2D") as Camera2D if player != null else null

func _update_shake(delta: float) -> void:
	var camera := hero_camera()
	if camera == null:
		return
	if _shake_time <= 0.0:
		camera.offset = cinema_offset.round()
		return
	_shake_time = maxf(0.0, _shake_time - delta)
	var power := _shake_strength * (_shake_time / maxf(0.01, _shake_duration))
	camera.offset = (cinema_offset + Vector2(randf_range(-power, power), randf_range(-power, power))).round()

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
	_ambience_clock -= delta
	if _ambience_clock <= 0.0:
		_ambience_clock = 2.0
		update_ambience()
	if fates != null:
		fates.tick(delta)
	_tick_autosave(delta)
	_update_spell_hud()
	hud.update_hotbar(skills.hotbar_entries())
	hud.quest_tracker.extra = director.tracker_entries() + contracts.tracker_entries()
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
	return input_handler._interaction_prompt(target)

# --- Input ---------------------------------------------------------------

func _input(event: InputEvent) -> void:
	input_handler._input(event)

## Returns true when the key was consumed and must not reach other handlers.
func _handle_key(keycode: Key) -> bool:
	return input_handler._handle_key(keycode)

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
	builder._populate_region()

## Ordinary monsters come back a while after they fall (bosses, quest foes,
## legends and event foes do not).
const ENEMY_RESPAWN := 40.0
var _respawns: Array = []
var _play_clock: float = 0.0

func _spawn_layout_enemy(enemy_data: Dictionary) -> SlimeEnemy:
	return builder._spawn_layout_enemy(enemy_data)

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
	builder._spawn_pending_supply_crates(layout)

func spawn_supply_crates() -> void:
	builder.spawn_supply_crates()

func _spawn_pending_map_fragments(layout: Dictionary) -> void:
	builder._spawn_pending_map_fragments(layout)

func spawn_region_boss() -> void:
	builder.spawn_region_boss()

func reveal_secret(region_id: String, marker_id: String) -> void:
	builder.reveal_secret(region_id, marker_id)

func _clear_region_actors() -> void:
	builder._clear_region_actors()

func _set_region(region_id: String, arrival: Vector2, notify: bool = true) -> void:
	builder._set_region(region_id, arrival, notify)

## New adventure: identity from character creation, then the prologue.
## Этап 18: «Новая игра+» — the story starts over, the hero keeps level,
## skills, gear, gold and achievements; enemies are tougher (and catch up
## with the hero's level), experience is richer.
var ng_plus: int = 0

func start_ng_plus(seed: Dictionary) -> void:
	var character: Dictionary = seed.get("player", {})
	if character.is_empty() or not character.has("inventory") or not character.has("equipment"):
		start_new_story("", "m")
		return
	ng_plus = int(seed.get("ng", 0)) + 1
	start_new_story(str(character.get("hero_name", "")), str(character.get("hero_gender", "m")))
	GameSaveState._apply_player(player, character)
	player.health = player.max_health
	player.mana = player.max_mana
	achievements.restore_snapshot(seed.get("achievements", {}))
	lore.restore_snapshot(seed.get("lore", {}))
	var known: Variant = seed.get("discovered", {})
	if known is Dictionary:
		discovered_enemies = (known as Dictionary).duplicate(true)
	achievements.set_max("ng_plus", ng_plus)
	hud.show_message("Новая игра+ · круг %d: враги сильнее, опыта больше на %d%%." % [ng_plus, roundi(ng_mult_xp() * 100.0) - 100], 6.0)
	_refresh_hud()

func ng_mult_xp() -> float:
	return 1.0 + 0.25 * ng_plus

## Enemy toughness in New Game+: grows with the round and with how far the
## hero outlevels the land.
func ng_power(region_id: String) -> float:
	if ng_plus <= 0 or player == null:
		return 1.0
	return 1.0 + 0.4 * ng_plus + 0.05 * maxi(0, player.level - RegionCatalog.level(region_id))

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
	builder.spawn_story_objects()

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
	crew.apply("cartographer")

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
	builder._apply_camera_limits()

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
	if fates != null:
		power *= fates.power_mult(current_region)
	power *= ng_power(current_region)
	if ng_plus > 0:
		enemy.xp_reward = int(round(enemy.xp_reward * ng_mult_xp()))
	if not is_equal_approx(power, 1.0) and not enemy is GroveGuardian:
		enemy.max_health = int(round(enemy.max_health * power))
		enemy.attack_damage = int(round(enemy.attack_damage * power))
		enemy.xp_reward = int(round(enemy.xp_reward * power))
	_apply_toughness(enemy)
	enemy.health = enemy.max_health
	enemy.combat_feedback.set_health(enemy.health, enemy.max_health)

## Balance (owner's list №27): every foe is tougher than before, bosses much
## tougher, and a land above the hero's level hits hard — level up first.
## Farming lands far below the hero gives little experience.
const TOUGH_HEALTH := 1.35
const TOUGH_DAMAGE := 1.15
const BOSS_HEALTH := 1.6
const GAP_HEALTH := 0.15
const GAP_DAMAGE := 0.1

func level_gap(region_id: String = current_region) -> int:
	return RegionCatalog.level(region_id) - (player.level if player != null else 1)

static func gap_xp_mult(gap: int) -> float:
	var over := -gap - 3
	return 1.0 if over <= 0 else maxf(0.2, 1.0 - 0.15 * over)

## Tests of the older mechanics switch the balance pass off to check base stats.
var classic_balance: bool = false

func _apply_toughness(enemy: SlimeEnemy) -> void:
	if classic_balance:
		return
	var health := TOUGH_HEALTH
	var damage := TOUGH_DAMAGE
	if enemy is GroveGuardian or enemy_kind(enemy) in STORY_BOSSES:
		health *= BOSS_HEALTH
	var gap := clampi(level_gap(), 0, 8)
	health *= 1.0 + GAP_HEALTH * gap
	damage *= 1.0 + GAP_DAMAGE * gap
	enemy.max_health = int(round(enemy.max_health * health))
	enemy.attack_damage = int(round(enemy.attack_damage * damage))
	enemy.xp_reward = maxi(1, int(round(enemy.xp_reward * gap_xp_mult(level_gap()))))

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

## A finished quest takes its leftovers off the ground (owner's list №16):
## spare herbs, pages, crates and other pickups that belong to it.
const QUEST_PICKUP_IDS := {"lost_cartographer_notes": "map_fragment", "bran_supply_run": "supply_crate_"}

func _clear_quest_items(quest_id: String) -> void:
	for node in get_children():
		if not node is WorldCollectible or node.is_queued_for_deletion():
			continue
		var belongs: bool = node.quest_id == quest_id
		if node.quest_id.is_empty() and RegionCatalog.herb_quest(current_region) == quest_id and not node.item_id.begins_with("iron_ore_node_") and node.item_id != "meteor_iron":
			belongs = true
		var prefix := str(QUEST_PICKUP_IDS.get(quest_id, ""))
		if not prefix.is_empty() and node.item_id.begins_with(prefix):
			belongs = true
		if belongs and story_object(node.item_id).is_empty():
			Vfx.sparkle(self, node.global_position)
			node.queue_free()

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
	builder._spawn_waystone(layout)

# --- Dungeons: locked doors and spike traps ----------------------------------

func _spawn_dungeon(layout: Dictionary) -> void:
	builder._spawn_dungeon(layout)

## Pulling a lever; seals open once all their levers are down.
func _on_lever_used(lever: DungeonLever) -> void:
	builder._on_lever_used(lever)

func _on_door_used(door: DungeonDoor) -> void:
	builder._on_door_used(door)

## Landmarks that change with quests (the lighthouse lights up).
func _spawn_dynamic_props(layout: Dictionary) -> void:
	builder._spawn_dynamic_props(layout)

func _refresh_dynamic_props() -> void:
	builder._refresh_dynamic_props()

# --- Gathering and crafting stations -----------------------------------------

func _spawn_gathering(layout: Dictionary) -> void:
	builder._spawn_gathering(layout)

## only_state: spawn just the entries that need this world state (they appear
## mid-visit, e.g. the rich veins of a freed mine).
func _spawn_gathering_entries(entries: Array, only_state: String = "") -> void:
	builder._spawn_gathering_entries(entries, only_state)

func _spawn_craft_stations() -> void:
	builder._spawn_craft_stations()

# --- Settlement: board, plots and houses in the village ----------------------

func _spawn_settlement() -> void:
	builder._spawn_settlement()

func _spawn_settlement_object(kind: String, art: String, at: Vector2) -> void:
	builder._spawn_settlement_object(kind, art, at)

## A village building grew a level (settlement.upgrade).
func on_building_upgraded(building_id: String) -> void:
	if building_id == Farm.BUILDING:
		farm.refresh()
	elif current_region == settlement.village_region():
		refresh_settlement()

## Rebuilds the village objects and settlers after a house goes up.
func refresh_settlement() -> void:
	for node in get_children():
		if node is SettlementObject or node is FarmBed or node is FarmPatch or node is MillWheel or (node is WorldNpc and node.npc_id.begins_with("settler_")):
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
	maps.open_map(world_tab)

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
	maps._update_minimap()

func _discover_landmarks() -> void:
	maps._discover_landmarks()

func _draw_minimap() -> void:
	maps._draw_minimap()

## Kind of a saved landmark for a world object ("" if it is not one).
func _landmark_kind(actor: Node) -> String:
	return maps._landmark_kind(actor)

## Icons that reflect the present: quest givers, unopened chests, exits,
## quest items and enemies near the hero.
func minimap_markers() -> Array:
	return maps.minimap_markers()

func _discover_nearby_enemies() -> void:
	maps._discover_nearby_enemies()

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
	if enemy is Windtail:
		return "windtail"
	if enemy is ForestWolf:
		return "wolf"
	if enemy is CaveBat:
		return "bat"
	return "slime"

func _enemy_kind(enemy: SlimeEnemy) -> String:
	return enemy_kind(enemy)

# --- Spawning ------------------------------------------------------------

func _spawn_npc(npc_data: Dictionary) -> void:
	builder._spawn_npc(npc_data)

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
	enemy.magic_attacks = kind in MAGIC_FOES
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
	builder._spawn_herb(spawn_position, item_id, label, quest_id)

func _spawn_lore(lore_data: Dictionary) -> void:
	builder._spawn_lore(lore_data)

## Reads a rune stone: its text in the dialogue box, the first time also an
## entry in the Chronicle and a little experience.
func read_lore(stone: LoreStone) -> void:
	var data := lore.entry(stone.lore_id)
	_show_dialogue(str(data.get("title", "Руны")), str(data.get("text", "")))
	if lore.mark(stone.lore_id, current_region):
		stone.fresh = false
		stone.queue_redraw()
		player.add_experience(15)
		hud.show_message("Новая запись в Летописи (%d из %d) · +15 опыта" % [lore.read.size(), lore.total()], 3.0)
		GameAudio.play("pickup", -6.0, 0.05)
		if achievements != null:
			achievements.add("lore")

func _spawn_chest(id: String, at_position: Vector2, gold: int, item: String, amount: int, tier: String = "wood") -> void:
	builder._spawn_chest(id, at_position, gold, item, amount, tier)

func _spawn_gate(target_region: String, gate_position: Vector2, arrival: Vector2, label: String) -> void:
	builder._spawn_gate(target_region, gate_position, arrival, label)

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
	if director.try_talk("cartographer") or party.talk("cartographer"):
		return
	# Mira on the road: quest business first, otherwise her own menu
	# (owner's list №21).
	if companion != null and is_instance_valid(companion) and dialogues.marker_for("cartographer").is_empty():
		crew.talk("cartographer")
		return
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
	if choice_id == "knock_wait":
		hud.close_dialogue()
		player.set_physics_process(true)
		wait_until_morning()
		return
	if choice_id == "knock_leave":
		hud.close_dialogue()
		player.set_physics_process(true)
		return
	if choice_id.begins_with("train_") and trainers.handle_choice(choice_id):
		return
	if choice_id.begins_with("crew_") and crew.handle_choice(choice_id):
		return
	dialogues.handle_choice(choice_id)

## Sleeping villagers do not talk (owner's list №8): a knock gets a sleepy
## mumble, and the hero may wait for the morning.
const KNOCK_LINES := [
	"Из-за двери доносится сонное бормотание: «Утром… всё утром…» — и снова тишина.",
	"Ты стучишь. Где-то внутри скрипит кровать, кто-то вздыхает — и поворачивается на другой бок.",
	"За дверью темно и тихо. Только мерно, спокойно, кто-то похрапывает.",
]

func knock_on_door(npc: WorldNpc) -> void:
	player.set_physics_process(false)
	_show_dialogue_choices(npc.display_name + " (спит)", str(KNOCK_LINES[randi() % KNOCK_LINES.size()]), [
		{"id": "knock_wait", "label": "Подождать до утра"},
		{"id": "knock_leave", "label": "Не будить"}])

## Skips the night: the sky fades and it is morning.
func wait_until_morning() -> void:
	hud.flash_screen(Color(0.02, 0.02, 0.06, 1.0), 1.2)
	if day_night.time >= 0.25:
		day_night.day += 1
	day_night.time = 0.28
	hud.show_message("Ты дожидаешься утра. Деревня просыпается.", 3.0)

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

## Book-style talk (8 ноября 2026): `line` is a String (one window), an
## Array of Strings (one of them, at random — everyday variety) or an Array of
## steps (a small scene with a narrator; speaker "self" is this NPC). With
## `choices`, the answers come after the last window, asking `prompt`.
func talk_line(npc_id: String, speaker: String, line: Variant, choices: Array[Dictionary] = [], prompt: String = "") -> void:
	if line is Array and not (line as Array).is_empty() and (line as Array)[0] is Dictionary:
		var steps: Array = line
		if choices.is_empty():
			story.play_steps(steps, npc_id, speaker)
			return
		var ask := prompt
		if ask.is_empty():
			# The last speech becomes the question.
			ask = str(steps[-1].get("text", "")) if steps[-1] is Dictionary else str(steps[-1])
			steps = steps.slice(0, steps.size() - 1)
		story.play_steps(steps, npc_id, speaker, func() -> void: _show_dialogue_choices(speaker, ask, choices))
		return
	if line is Array:
		# Everyday variety: one variant (itself a line or a small scene).
		var variants: Array = line
		if variants.is_empty():
			return
		talk_line(npc_id, speaker, variants[randi() % variants.size()], choices, prompt)
		return
	var text := str(line)
	if choices.is_empty():
		_show_dialogue(speaker, text)
	else:
		_show_dialogue_choices(speaker, text if prompt.is_empty() else prompt, choices)

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
	spawn_generated_loot(death_position + Vector2(14, 6), "rare", "boss")
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
	spawn_generated_loot(death_position + Vector2(14, 6), "rare", "boss")
	shake(6.0, 0.6)
	hit_stop(0.2)
	update_music.call_deferred()
	hud.show_message("%s повержен!" % STORY_BOSSES[kind], 3.0)
	_grant_sky_seal()
	director.on_boss_defeated(kind)
	request_autosave()

func _on_wolf_defeated(xp_reward: int, death_position: Vector2, elite: bool = false) -> void:
	if quests.is_active("toren_wolf_hunt"):
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
	if crafting.is_open():
		crafting.close()
		return
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
	# The Keepers' regalia lie scattered over the high sky islands.
	if RegionCatalog.style(current_region) in ["sky", "spires", "rift"] and loot_rng.randf() < (0.08 if elite else 0.025):
		var missing := KEEPER_SET.filter(func(id: String) -> bool: return not player.inventory.has(id) and not player.wears_base(id))
		if not missing.is_empty():
			var piece: String = missing[loot_rng.randi_range(0, missing.size() - 1)]
			_spawn_loot(_scatter(at), piece)
			dropped.append(piece)
	if not RegionCatalog.is_underground(RegionCatalog.style(current_region)) and loot_rng.randf() < 0.015:
		_spawn_loot(_scatter(at), TreasureHunt.MAP_ITEM)
		dropped.append(TreasureHunt.MAP_ITEM)
	return dropped

## Balance: monster drops and experience (lower = slower, rarer).
const LOOT_RATE := 0.6
const KEEPER_SET := ["keeper_staff", "keeper_robe", "keeper_sigil"]
const GEAR_RATE := 0.45
const XP_RATE := 0.6

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
	spawn_generated_loot(enemy.global_position + Vector2(-10, 6), "uncommon", "elite")
	shake(2.5, 0.25)

## Drops a rolled piece of equipment (bosses pass a minimum rarity).
## source: "" ordinary, "elite" mini-boss, "boss" — only the last two give
## legendaries with a real chance.
func spawn_generated_loot(at: Vector2, minimum_rarity: String = "common", source: String = "") -> String:
	var rarity := minimum_rarity if minimum_rarity == "legendary" else LootGenerator.roll_rarity(loot_rng, minimum_rarity, source)
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
		equip_from_bag(item_id)
		return
	_use_consumable(item_id)

## Puts a piece on (into `slot` when given — a ring's second slot, say) and
## says what came off: a shield for a two-handed weapon and back.
func equip_from_bag(item_id: String, slot: String = "") -> void:
	var target := player.target_slot(item_id, slot)
	var pushed: Array[String] = []
	for other in player.displaced_by(item_id, target):
		pushed.append(player.get_item_name(str(player.equipment.get(other, ""))))
	if player.equip_item(item_id, slot):
		var line := "Надето: %s." % player.get_item_name(item_id)
		if not pushed.is_empty():
			line += " Снято: %s — %s." % [", ".join(pushed), "двуручному оружию нужны обе руки" if target == "blade" else "щит не держат с двуручным оружием"]
		hud.show_message(line, 2.5)
		_update_spell_hud()
	else:
		hud.show_message("Невозможно экипировать.", 1.5)
	hud.refresh_inventory(player)

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
	combat._update_spell_hud()

## ЛКМ / ПКМ squares on the action bar.
func _update_mouse_slots() -> void:
	combat._update_mouse_slots()

## Wheel / Tab-free spell switching: walks the spells the hero can cast.
func cycle_spell(step: int) -> void:
	combat.cycle_spell(step)

func select_spell(spell_id: String) -> void:
	combat.select_spell(spell_id)

# --- Sword -------------------------------------------------------------------

const SLASH_COOLDOWN := 0.3
const COMBO_WINDOW := 0.65
const CHARGE_TIME := 0.5
const SLASH_REACH := 30.0
const SPIN_REACH := 40.0

## How each kind of blade swings: cooldown, reach and arc multipliers, push.
const WEAPON_PROFILES := {
	"sword": {"cooldown": 1.0, "reach": 1.0, "arc": 75.0, "push": 110.0, "name": "Меч"},
	"dagger": {"cooldown": 0.62, "reach": 0.85, "arc": 70.0, "push": 60.0, "name": "Кинжал"},
	"spear": {"cooldown": 1.15, "reach": 1.65, "arc": 34.0, "push": 150.0, "name": "Копьё"},
	"hammer": {"cooldown": 1.5, "reach": 1.05, "arc": 120.0, "push": 210.0, "name": "Молот"},
	"staff": {"cooldown": 1.25, "reach": 1.1, "arc": 90.0, "push": 130.0, "name": "Посох"},
	"bow": {"cooldown": 1.0, "reach": 0.8, "arc": 70.0, "push": 80.0, "name": "Лук"},
}

func weapon_profile() -> Dictionary:
	return combat.weapon_profile()

var attack_cooldown: float = 0.0
var _combo_step: int = 0
var _combo_timer: float = 0.0
var _attack_holding: bool = false
var _attack_held: float = 0.0
var _charging: bool = false

func _aim_direction() -> Vector2:
	return combat._aim_direction()

func _attack_pressed() -> void:
	combat._attack_pressed()

func _attack_released() -> void:
	combat._attack_released()

func _update_sword(delta: float) -> void:
	combat._update_sword(delta)

## Two-hit combo in front of the hero (towards the mouse).
func sword_slash() -> bool:
	return combat.sword_slash()

## Held attack: a full circle at 1.8x damage.
func sword_spin() -> bool:
	return combat.sword_spin()

## Enemies struck by the latest sword hit (skills add effects to them).
var last_hit_enemies: Array = []
## Rolls for crits in tests; seeded randomly in play.
var crit_rng := RandomNumberGenerator.new()

func _living_enemies() -> Array:
	return combat._living_enemies()

## One sword blow: crit roll, lifesteal, knockback.
func _strike(enemy: SlimeEnemy, damage: int, push_direction: Vector2, push: float) -> void:
	note_hero_target(enemy)
	combat._strike(enemy, damage, push_direction, push)

## The foe the hero fights: companions on «Защищать» help with it.
var hero_target: Node2D = null
var _hero_target_until: int = 0

func note_hero_target(enemy: Node) -> void:
	if enemy is Node2D:
		hero_target = enemy
		_hero_target_until = Time.get_ticks_msec() + 6000

func hero_target_fresh() -> bool:
	return is_instance_valid(hero_target) and Time.get_ticks_msec() < _hero_target_until

## A companion's arrow: plain damage and a push, no hero bonuses.
func crew_strike(enemy: SlimeEnemy, damage: int, push_direction: Vector2, shooter: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	enemy.apply_knockback(push_direction, 60.0)
	enemy.take_damage(damage)
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		enemy.provoke(shooter)

## Damages enemies within reach and the arc (degrees); returns how many.
func _melee_hit(origin: Vector2, direction: Vector2, reach: float, arc: float, damage: int, push: float) -> int:
	return combat._melee_hit(origin, direction, reach, arc, damage, push)

## Damages enemies in a strip in front of origin (lunge, blade wave).
func _line_hit(origin: Vector2, direction: Vector2, length: float, width: float, damage: int, push: float) -> int:
	return combat._line_hit(origin, direction, length, width, damage, push)

## Short-lived white streak (lunge path, blade wave).
func _streak(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	combat._streak(from, to, color, width)

## Expanding ring (shockwave, war cry, blade dance).
func _ring(at: Vector2, radius: float, color: Color) -> void:
	combat._ring(at, radius, color)

## Puts a newly awakened spell into an empty or still-locked hotbar slot.
func _place_spell_on_hotbar(spell_id: String) -> void:
	combat._place_spell_on_hotbar(spell_id)

# --- Magic -------------------------------------------------------------------

## Story mode: the heroine starts with the sword; Ilara awakens her magic
## once the grove guardian falls. Free play (tests) has magic from the start.
func magic_unlocked() -> bool:
	return combat.magic_unlocked()

# --- Bow (ranger) ----------------------------------------------------------

const BOW_COOLDOWN := 0.45
const AIM_TIME := 0.55
var _bow_holding: bool = false
var _bow_held: float = 0.0

func _bow_press() -> void:
	combat._bow_press()

func _update_bow(delta: float) -> void:
	combat._update_bow(delta)

func _bow_release() -> void:
	combat._bow_release()

func shoot_arrow(direction: Vector2, damage: int, aimed: bool, pierce: int = 0) -> Arrow:
	return combat.shoot_arrow(direction, damage, aimed, pierce)

func _cast_spell() -> void:
	combat._cast_spell()

func _refresh_hud() -> void:
	if borin != null:
		borin.sync_progress()
	if lira != null:
		lira.sync_progress()
	if bran != null:
		bran.sync_progress()
	if ship != null:
		ship.sync_progress()
	if hud != null and player != null and quests != null:
		hud.update_status(player, quests)

# --- Defeat, save and load -----------------------------------------------

func _on_player_died() -> void:
	if game_over:
		return
	if trials != null and trials.on_fall():
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
