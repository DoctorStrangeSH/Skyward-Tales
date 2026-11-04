extends Node
class_name WorldEvents

## Random happenings while exploring outdoor lands, every few minutes:
##   starfall  — stars fall nearby; their fragments can be picked up;
##   elite     — a dangerous strong foe appears not far away;
##   thief     — a golden imp with a treasure sack: catch it before it flees;
##   tailwind  — a sky wind: faster running for a minute.
## Events are not saved; the next one comes after a pause.

const INTERVAL := Vector2(150.0, 300.0)
const KINDS := ["starfall", "elite", "thief", "tailwind"]
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
	if RegionCatalog.style(game.current_region) in ["cave", "crypt"]:
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
	return false

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
