extends Node
class_name WorldEvents

## Random happenings while exploring outdoor lands, every few minutes:
##   starfall  — stars fall nearby; their fragments can be picked up;
##   elite     — a dangerous strong foe appears not far away;
##   thief     — a golden imp with a treasure sack: catch it before it flees;
##   tailwind  — a sky wind: faster running for a minute.
## Events are not saved; the next one comes after a pause.

const INTERVAL := Vector2(150.0, 300.0)
const KINDS := ["starfall", "elite", "thief", "tailwind", "trader", "meteor", "caravan", "caravan"]
const TRADER_TIME := 120.0
const NPC_SCRIPT := preload("res://scripts/npc.gd")
const IMP_SCRIPT := preload("res://scripts/loot_imp.gd")

var game: SkywardGame
var rng := RandomNumberGenerator.new()
var next_in: float = 0.0
var enabled: bool = true
var active: String = ""
var last_event: String = ""

func _ready() -> void:
	rng.randomize()
	next_in = rng.randf_range(INTERVAL.x * 0.6, INTERVAL.y * 0.6)

func _process(delta: float) -> void:
	if not enabled or get_tree().paused or game == null or game.player == null:
		return
	if not can_happen():
		return
	next_in -= delta
	if next_in <= 0.0:
		next_in = rng.randf_range(INTERVAL.x, INTERVAL.y)
		start(KINDS[rng.randi_range(0, KINDS.size() - 1)])

## Only outdoors, out of story scenes and boss fights.
func can_happen() -> bool:
	if RegionCatalog.is_underground(RegionCatalog.style(game.current_region)) or RegionCatalog.is_peaceful(game.current_region):
		return false
	if game.story.active or game.hud.dialogue_visible:
		return false
	for actor in game.get_children():
		if actor is GroveGuardian and actor.health > 0:
			return false
	return true

func start(kind: String) -> bool:
	last_event = kind
	match kind:
		"starfall":
			return _starfall()
		"elite":
			return _elite()
		"thief":
			return _thief()
		"tailwind":
			return _tailwind()
		"trader":
			return _trader()
		"meteor":
			return _meteor()
		"caravan":
			return _caravan()
	return false

## A merchant caravan under attack (see caravan.gd). Not in the village.
func _caravan() -> bool:
	if game.current_region == game.village.region():
		return _starfall()
	var caravan := Caravan.new()
	game.add_child(caravan)
	caravan.global_position = _spot_near(110.0, 180.0)
	caravan.setup(game, game.epilogue._local_kinds(), 4)
	game.hud.show_title_card("Нападение на караван!", 2.5)
	game.hud.show_message("Твари напали на торговый караван. Отбейте его за минуту!", 4.0)
	GameAudio.play("boss_roar", -10.0, 0.0)
	return true

func _spot_near(distance_min: float, distance_max: float) -> Vector2:
	var size: Vector2 = game.world.map_size()
	for attempt in 20:
		var at: Vector2 = game.player.global_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(distance_min, distance_max)
		if at.x > 60 and at.y > 60 and at.x < size.x - 60 and at.y < size.y - 60:
			return at
	return game.player.global_position + Vector2(80, 0)

func _starfall() -> bool:
	game.hud.show_title_card("Звездопад!", 2.5)
	game.hud.show_message("С неба падают звёзды. Подберите их осколки неподалёку.", 4.0)
	GameAudio.play("level_up", -6.0, 0.0)
	for i in rng.randi_range(3, 5):
		var at := _spot_near(60.0, 220.0)
		var delay := 0.4 + i * 0.45
		get_tree().create_timer(delay).timeout.connect(func() -> void: _drop_star(at))
	return true

func _drop_star(at: Vector2) -> void:
	if game == null or not is_instance_valid(game):
		return
	game._streak(at + Vector2(-70, -180), at, Color(1.0, 0.95, 0.7, 0.95), 3.0)
	Vfx.burst(game, at, [Color(1, 1, 0.9), Color(1.0, 0.85, 0.4), Color(0.6, 0.7, 1.0, 0)], 16, 80.0, 0.5)
	game.shake(1.5, 0.15)
	var loot := game._spawn_loot(at, "star_fragment")
	loot.settle_time = 1.2
	if rng.randf() < 0.18:
		game._spawn_loot(at + Vector2(10, 6), "starlight_essence")

func _elite() -> bool:
	var kinds: Array = []
	for data in game._layout().get("enemies", []):
		var kind := str(data.get("kind", ""))
		if data.has("quest") or kind in SkywardGame.STORY_BOSSES or not EliteModifiers.can_be_elite(kind):
			continue
		kinds.append(kind)
	if kinds.is_empty():
		return false
	var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	var enemy := game.spawn_enemy(kind, _spot_near(180.0, 260.0), EliteModifiers.pick(rng))
	if enemy == null:
		return false
	game.hud.show_title_card("Грозный враг!", 2.5)
	game.hud.show_message("Неподалёку появился сильный противник — на миникарте он оранжевый. Награда втрое больше.", 4.5)
	GameAudio.play("boss_roar", -10.0, 0.1)
	return true

func _thief() -> bool:
	var imp := IMP_SCRIPT.new() as LootImp
	imp.position = _spot_near(90.0, 140.0)
	game.add_child(imp)
	game._scale_to_region(imp)
	imp.defeated.connect(func(xp: int) -> void: _on_imp_caught(xp, imp.global_position))
	imp.escaped.connect(func() -> void: game.hud.show_message("Воришка сбежал с сокровищами…", 3.0))
	game.hud.show_title_card("Золотой воришка!", 2.5)
	game.hud.show_message("Бес с мешком сокровищ! Догоните его, пока не сбежал (26 с).", 4.0)
	return true

func _on_imp_caught(xp: int, at: Vector2) -> void:
	game.player.add_experience(xp)
	var level := RegionCatalog.level(game.current_region)
	for i in 3:
		var coins := game._spawn_loot(at + Vector2(rng.randf_range(-16, 16), rng.randf_range(-10, 10)), "gold")
		coins.amount = rng.randi_range(20, 35) * maxi(1, level)
	game.spawn_generated_loot(at + Vector2(0, 12), "uncommon" if rng.randf() < 0.7 else "rare")
	game.hud.show_message("Воришка пойман! Сокровища ваши.", 3.0)
	GameAudio.play("quest", -4.0, 0.0)

func _tailwind() -> bool:
	game.player.add_buff("speed", 0.25, 60.0, "Попутный ветер")
	game.hud.show_title_card("Попутный ветер", 2.0)
	game.hud.show_message("Небесный ветер подгоняет вас: +25% к скорости на минуту.", 3.5)
	Vfx.burst(game, game.player.global_position, [Color(1, 1, 1), Color(0.8, 0.95, 1.0), Color(0.6, 0.85, 1.0, 0)], 20, 90.0, 0.6)
	GameAudio.play("gust", -4.0, 0.0)
	return true


# --- Wandering trader ----------------------------------------------------------

var trader: WorldNpc
var trader_offers: Array = []

func _trader() -> bool:
	if trader != null and is_instance_valid(trader):
		return false
	trader = NPC_SCRIPT.new() as WorldNpc
	trader.npc_id = "merchant"
	trader.display_name = "Зейн, странствующий торговец"
	trader.outfit_color = Color(0.35, 0.55, 0.9)
	game.add_child(trader)
	trader.global_position = _spot_near(60.0, 110.0)
	trader.interacted.connect(func(_source: Node2D) -> void: open_trader())
	trader_offers = _trader_stock()
	Vfx.sparkle(game, trader.global_position)
	game.hud.show_title_card("Странствующий торговец", 2.5)
	game.hud.show_message("Рядом остановился торговец с редкими товарами. Он уйдёт через две минуты.", 4.0)
	get_tree().create_timer(TRADER_TIME, false).timeout.connect(_trader_leaves)
	return true

func _trader_stock() -> Array:
	var level := maxi(1, game.player.level)
	var stock: Array = []
	for rarity in ["rare", "epic"]:
		var item_id := game.player.register_generated_item(LootGenerator.generate(rng, level, rarity))
		stock.append({"item": item_id, "price": (90 if rarity == "rare" else 220) + level * (12 if rarity == "rare" else 25)})
	stock.append({"item": TreasureHunt.MAP_ITEM, "price": 60 + level * 6})
	stock.append({"item": "starlight_essence", "price": 260 + level * 10})
	return stock

func open_trader() -> void:
	if trader == null or not is_instance_valid(trader):
		return
	var choices: Array[Dictionary] = []
	for index in trader_offers.size():
		var offer: Dictionary = trader_offers[index]
		var definition := game.player.get_item_definition(str(offer["item"]))
		var rarity := str(definition.get("rarity", ""))
		var label := "%s%s — %d золота" % [game.player.get_item_name(str(offer["item"])), (" (" + str(game.hud.INVENTORY_RARITY_NAMES.get(rarity, rarity)).to_lower() + ")") if not rarity.is_empty() else "", int(offer["price"])]
		choices.append({"id": "trader_buy:%d" % index, "label": label})
	choices.append({"id": "trader_close", "label": "Не сейчас"})
	game._show_dialogue_choices(trader.display_name, "Редкости со всех островов! Золото у вас есть: %d." % game.player.gold, choices)

func handle_choice(choice_id: String) -> bool:
	if choice_id == "trader_close":
		game.hud.close_dialogue()
		game.player.set_physics_process(true)
		return true
	if not choice_id.begins_with("trader_buy:"):
		return false
	var index := int(choice_id.trim_prefix("trader_buy:"))
	if index >= 0 and index < trader_offers.size():
		var offer: Dictionary = trader_offers[index]
		if game.player.gold >= int(offer["price"]):
			game.player.add_gold(-int(offer["price"]))
			game.player.add_item(str(offer["item"]))
			trader_offers.remove_at(index)
			GameAudio.play("pickup", -4.0, 0.0)
			game.hud.show_message("Куплено: " + game.player.get_item_name(str(offer["item"])), 2.5)
		else:
			game.hud.show_message("Не хватает золота.", 2.0)
	open_trader()
	return true

func _trader_leaves() -> void:
	if trader != null and is_instance_valid(trader):
		Vfx.sparkle(game, trader.global_position)
		trader.queue_free()
		game.hud.show_message("Странствующий торговец отправился дальше.", 2.5)
	trader = null

# --- Meteor ----------------------------------------------------------------------

func _meteor() -> bool:
	var at := _spot_near(140.0, 220.0)
	game.hud.show_title_card("Падает метеорит!", 2.5)
	game.hud.show_message("Небесный камень рухнул неподалёку. Его охраняет звёздный страж.", 4.0)
	game._streak(at + Vector2(-140, -260), at, Color(1.0, 0.8, 0.5, 1.0), 6.0)
	get_tree().create_timer(0.35, false).timeout.connect(func() -> void: _meteor_lands(at))
	return true

func _meteor_lands(at: Vector2) -> void:
	if game == null or not is_instance_valid(game):
		return
	Vfx.burst(game, at, [Color(1, 1, 0.85), Color(1.0, 0.6, 0.25), Color(0.4, 0.2, 0.1, 0)], 30, 140.0, 0.7)
	game.shake(5.0, 0.4)
	GameAudio.play("boss_roar", -8.0, 0.0)
	for i in 4:
		var loot := game._spawn_loot(at + Vector2.RIGHT.rotated(TAU * i / 4.0) * 18.0, "star_fragment")
		loot.settle_time = 2.0
	if rng.randf() < 0.4:
		game._spawn_loot(at, "starlight_essence").settle_time = 2.0
	var guard := game.spawn_enemy("sentinel", at + Vector2(0, -24), EliteModifiers.pick(rng))
	if guard == null:
		return
