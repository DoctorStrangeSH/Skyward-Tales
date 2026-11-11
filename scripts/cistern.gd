extends Node
class_name Cistern

## Stage 21, step 6: the Flooded Cistern under the village well (region
## "flooded_cistern", tools/cistern_layout.py).
##
## The channels between its halls stand under water. Each hall has a drain
## plate: press it and the next channel runs dry — crabs crawl out of the
## silt, a chest shows on the bottom, the way on opens. Past the third
## channel waits the Keeper of the Cistern. When the season changes
## (scripts/seasons.gd) the rains fill the cistern again: the water, the
## chests and the Keeper return.

const REGION := "flooded_cistern"
const POOLS := [Rect2(480, 352, 64, 128), Rect2(752, 576, 112, 64), Rect2(656, 224, 112, 64)]
const PLATES := [Vector2(690, 690), Vector2(410, 300), Vector2(1000, 560)]
const BOSS_AT := Vector2(912, 230)
const WATER := "res://assets/world_hd/props/cistern_water.png"

## A channel: water that blocks the way until it is drained.
class Pool extends Node2D:
	var rect: Rect2
	var flooded: bool = true
	var _water: Sprite2D
	var _body: StaticBody2D
	var _clock: float = 0.0

	func _ready() -> void:
		add_to_group("region_actor")
		z_index = -80
		position = rect.position
		_water = Sprite2D.new()
		if ResourceLoader.exists(Cistern.WATER):
			_water.texture = load(Cistern.WATER)
		_water.centered = false
		_water.region_enabled = true
		_water.region_rect = Rect2(Vector2.ZERO, rect.size * 2.0)
		_water.scale = Vector2.ONE * 0.5
		_water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_water.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_water.visible = flooded
		add_child(_water)
		_body = StaticBody2D.new()
		_body.collision_layer = 4
		_body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.size * 0.5
		shape.disabled = not flooded
		_body.add_child(shape)
		add_child(_body)
		queue_redraw()

	func _process(delta: float) -> void:
		_clock += delta
		if _water.visible:
			_water.region_rect.position = Vector2(_clock * 10.0, sin(_clock * 0.7) * 6.0)

	func drain() -> void:
		if not flooded:
			return
		flooded = false
		(_body.get_child(0) as CollisionShape2D).set_deferred("disabled", true)
		var tween := create_tween()
		tween.tween_property(_water, "modulate:a", 0.0, 1.2)
		tween.tween_callback(func() -> void: _water.visible = false)
		queue_redraw()

	func _draw() -> void:
		# The wet bottom of a drained channel; a pale rim on a full one.
		if flooded:
			draw_rect(Rect2(Vector2(-1, -1), rect.size + Vector2(2, 2)), Color(0.75, 0.9, 0.85, 0.35), false, 1.0)
		else:
			draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.0, 0.08, 0.1, 0.32))

var game: SkywardGame
## How many channels are drained (0..3).
var level: int = 0
var cleared: bool = false
var flood_season: String = ""
var runs: int = 0
var times_cleared: int = 0
var _pools: Array = []
var _plates: Array = []
var _boss: SlimeEnemy

func _object(at: Vector2, art: String, label: String = "", wall: float = 0.0, glow: Color = Color(0, 0, 0, 0), flat: bool = false) -> TowerObject:
	var object := TowerObject.new()
	object.art = art
	object.label = label
	object.wall_width = wall
	object.glow = glow
	object.flat = flat
	game.add_child(object)
	object.global_position = at
	return object

func _season() -> String:
	return game.seasons.current() if game.seasons != null else "summer"

## Called when a region is built.
func populate() -> void:
	_pools.clear()
	_plates.clear()
	_boss = null
	if game.current_region != REGION:
		return
	if cleared and _season() != flood_season:
		# A new season: the rains have filled the cistern again.
		cleared = false
		level = 0
		runs += 1
		game.hud.show_message("С новым сезоном дожди снова затопили цистерну. Хозяин вернулся.", 5.0)
	for i in POOLS.size():
		var pool := Pool.new()
		pool.rect = POOLS[i]
		pool.flooded = i >= level
		game.add_child(pool)
		_pools.append(pool)
		if i < level:
			_pool_chest(i)
	for i in PLATES.size():
		var plate := _object(PLATES[i], "cistern_plate", "E — нажать плиту водостока" if i >= level else "", 0.0, Color(0, 0, 0, 0), true)
		var index := i
		plate.used.connect(func(_o: TowerObject) -> void: press(index))
		_plates.append(plate)
		_object(PLATES[i] + Vector2(26, -6), "cistern_lantern", "", 8.0, Color(1.0, 0.75, 0.4, 1.0))
	# The halls: columns, pots, grates in the walls, a tomb by the Keeper.
	for at in [Vector2(120, 620), Vector2(310, 620), Vector2(480, 520), Vector2(720, 520), Vector2(800, 140), Vector2(1020, 140), Vector2(800, 350), Vector2(1020, 350)]:
		_object(at, "cistern_column", "", 14.0)
	for at in [Vector2(150, 710), Vector2(560, 720), Vector2(620, 210), Vector2(900, 720), Vector2(1030, 500)]:
		_object(at, "cistern_pots")
	for at in [Vector2(270, 600), Vector2(470, 330), Vector2(880, 500), Vector2(1000, 330)]:
		_object(at, "cistern_rubble")
	for at in [Vector2(216, 588), Vector2(600, 492), Vector2(504, 188), Vector2(960, 492), Vector2(912, 108)]:
		_object(at, "cistern_grate").z_index = -85
	_object(Vector2(912, 150), "cistern_sarcophagus", "", 30.0)
	if not cleared:
		_spawn_boss()
	else:
		_boss_chest()

func _pool_chest(index: int) -> void:
	if index == 0:
		return
	var at: Vector2 = POOLS[index].get_center()
	game._spawn_chest("cistern_%d_pool%d" % [runs, index], at, 40 + 30 * index, "health_potion", 1 + index, "wood" if index == 1 else "silver")

func _boss_chest() -> void:
	game._spawn_chest("cistern_%d_keeper" % runs, BOSS_AT + Vector2(0, -40), 220, "starlight_essence", 1, "gold")

## Presses drain plate `index`: the next channel runs dry.
func press(index: int) -> void:
	if game.current_region != REGION or index != level or index >= POOLS.size():
		return
	level += 1
	if index < _plates.size() and is_instance_valid(_plates[index]):
		var plate: TowerObject = _plates[index]
		plate.label = ""
		plate.remove_from_group("interactables")
	if index < _pools.size() and is_instance_valid(_pools[index]):
		(_pools[index] as Pool).drain()
	var rect: Rect2 = POOLS[index]
	game.shake(4.0, 0.5)
	GameAudio.play("boss_roar", -12.0, 0.0)
	Vfx.burst(game, rect.get_center(), [Color(0.7, 1.0, 0.95), Color(0.3, 0.7, 0.7), Color(0.1, 0.4, 0.4, 0)], 26, 90.0, 0.8)
	# Crabs crawl out of the silt.
	for i in 2:
		var at := rect.get_center() + (Vector2(0, -22 + 44 * i) if rect.size.y > rect.size.x else Vector2(-26 + 52 * i, 0))
		var crab := game.spawn_enemy("crab", at)
		if crab != null:
			crab.set_meta("cistern_crab", true)
			Vfx.sparkle(game, at)
	_pool_chest(index)
	var where: String = ["к западному залу", "к восточному залу", "к залу Хозяина"][index]
	game.hud.show_message("Вода уходит! Открыт путь %s." % where, 4.0)
	game.request_autosave()

func _spawn_boss() -> void:
	var boss := game.spawn_enemy("toad", BOSS_AT)
	if boss == null:
		return
	boss.set_meta("cistern_keeper", true)
	boss.set_meta("special_encounter", true)
	boss.max_health = roundi(boss.max_health * 14.0)
	boss.health = boss.max_health
	boss.attack_damage = roundi(boss.attack_damage * 1.8)
	boss.xp_reward = roundi(boss.xp_reward * 8.0)
	boss.knockback_resist = maxf(boss.knockback_resist, 0.85)
	boss.visual.scale *= 1.9
	boss.combat_feedback.elite = true
	boss.combat_feedback.elite_name = "♦ Хозяин цистерны"
	boss.combat_feedback.elite_color = Color(0.5, 1.0, 0.9)
	boss.combat_feedback.bar_y *= 1.8
	boss.base_visual_tint = Color(0.65, 1.0, 0.95)
	boss.visual.modulate = boss.base_visual_tint
	boss.combat_feedback.set_health(boss.health, boss.max_health)
	boss.defeated.connect(func(_xp: int) -> void: _on_keeper_down())
	_boss = boss

func _on_keeper_down() -> void:
	if cleared:
		return
	cleared = true
	times_cleared += 1
	flood_season = _season()
	game.achievements.set_max("cistern", times_cleared)
	_boss_chest.call_deferred()
	game.spawn_generated_loot.call_deferred(BOSS_AT + Vector2(20, 10), "epic" if times_cleared > 1 else "rare")
	game.hud.show_title_card("Хозяин цистерны повержен", 2.6)
	game.hud.show_message("Цистерна чиста — до новых дождей. Со сменой сезона вода и Хозяин вернутся.", 5.0)
	GameAudio.play("quest", -2.0, 0.0)
	game.request_autosave()

func make_snapshot() -> Dictionary:
	return {"level": level, "cleared": cleared, "flood_season": flood_season, "runs": runs, "times_cleared": times_cleared}

func restore_snapshot(value: Variant) -> void:
	var data: Dictionary = value if value is Dictionary else {}
	level = clampi(int(data.get("level", 0)), 0, POOLS.size())
	cleared = bool(data.get("cleared", false))
	flood_season = str(data.get("flood_season", ""))
	runs = int(data.get("runs", 0))
	times_cleared = int(data.get("times_cleared", 0))
