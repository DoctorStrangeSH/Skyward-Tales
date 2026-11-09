extends Node
class_name VillageFair

## The village fair (stage 20). Every fourth game day, from morning till
## night, the meadow south of the market in the Green Reaches turns into a
## fairground: garlands, a ribbon pole, a shooting gallery and a prize
## booth, and its own music (tools/audio/orchestra.py → "fair").
##   • Тир (shooting gallery): 30 seconds, straw targets pop up on the range
##     and vanish again — hit them with anything (blade, bow, spells);
##     every two targets give a fair token.
##   • Рыбный день: every fish caught anywhere on a fair day — a token.
##   • Лавка призов: tokens for a sugar cockerel, seeds, a treasure map, a
##     flower wreath, starlight essence.
##   • In the evening the villagers gather at the pole and fireworks go up.
## Tokens are an item ("fair_token"); the best gallery score is saved.

const REGION := "greenreach"
const EVERY := 4
const OFFSET := 2
const OPEN_FROM := 0.27
const CLOSE_AT := 0.84
const FIREWORKS_FROM := 0.72
const TOKEN := "fair_token"
const CENTER := Vector2(760, 800)
const POLE := Vector2(760, 792)
const BOOTH := Vector2(650, 836)
const GALLERY := Vector2(868, 768)
## The range behind the gallery counter where targets pop up.
const RANGE := Rect2(910, 742, 64, 64)
const GALLERY_TIME := 30.0
const TARGET_LIFE := 2.6
const PRIZES := [
	{"id": "candy_cock", "cost": 2, "amount": 1},
	{"id": "seed_sunberry", "cost": 3, "amount": 3},
	{"id": "treasure_map", "cost": 4, "amount": 1},
	{"id": "fair_wreath", "cost": 6, "amount": 1},
	{"id": "starlight_essence", "cost": 8, "amount": 1},
]
const HOST := "Фома-зазывала"

var game: SkywardGame
var best: int = 0
var announced_day: int = -1
## The gallery round in progress.
var playing: bool = false
var score: int = 0
var time_left: float = 0.0
var _spawn_clock: float = 0.0
var _rng := RandomNumberGenerator.new()
var _decor: Array[Node] = []
var _was_open: bool = false
var _firework_clock: float = 0.0

func make_snapshot() -> Dictionary:
	return {"best": best, "announced": announced_day}

func restore_snapshot(data: Variant) -> void:
	if data is Dictionary:
		best = int(data.get("best", 0))
		announced_day = int(data.get("announced", -1))

static func is_fair_day(day: int) -> bool:
	return posmod(day, EVERY) == OFFSET

func days_until() -> int:
	return posmod(OFFSET - game.day_night.day, EVERY)

func open() -> bool:
	var t := game.day_night.time
	return is_fair_day(game.day_night.day) and t >= OPEN_FROM and t < CLOSE_AT

func open_here() -> bool:
	return open() and game.current_region == REGION

func _ready() -> void:
	_rng.seed = 2026
	if game != null and game.fishing != null:
		game.fishing.finished.connect(_on_fish)

func _process(delta: float) -> void:
	if game == null or game.day_night == null or get_tree().paused:
		return
	var now_open := open()
	if now_open and announced_day != game.day_night.day:
		announced_day = game.day_night.day
		if RegionCatalog.style(game.current_region) in DayNight.CYCLING_STYLES or game.current_region == REGION:
			game.hud.show_message("Сегодня в Зелёных Пределах ярмарка! Тир, призы, а вечером — фейерверк.", 4.0)
	if now_open != _was_open:
		_was_open = now_open
		populate()
		game.update_music()
	if playing:
		_tick_gallery(delta)
	if open_here() and game.day_night.time >= FIREWORKS_FROM:
		_firework_clock -= delta
		if _firework_clock <= 0.0:
			_firework_clock = _rng.randf_range(1.4, 3.2)
			launch_firework()

# --- The fairground -----------------------------------------------------------

## Builds or clears the fairground (called when the land is built, and when
## the fair opens or closes).
func populate() -> void:
	for node in _decor:
		if is_instance_valid(node):
			node.queue_free()
	_decor.clear()
	if not open_here():
		if playing:
			_end_gallery()
		return
	_add(FairProp.new("fair_maypole", POLE, Vector2(10, 6)))
	var booth := FairStand.new("fair_booth", BOOTH, "лавка призов")
	booth.used.connect(open_booth)
	_add(booth)
	var stand := FairStand.new("fair_gallery", GALLERY, "тир")
	stand.used.connect(open_gallery)
	_add(stand)
	var ribbons := Ribbons.new()
	ribbons.position = POLE + Vector2(0, -74)
	_add(ribbons)
	# Flag strings from the top of the pole to short poles around the square.
	for corner in [Vector2(-120, -40), Vector2(120, -40), Vector2(-140, 44), Vector2(140, 44), Vector2(-60, 86), Vector2(60, 86)]:
		var garland := Garland.new()
		garland.points_list = [POLE + Vector2(0, -74), POLE + corner + Vector2(0, -40)]
		_add(garland)

func _add(node: Node2D) -> void:
	game.add_child(node)
	if node.position == Vector2.ZERO and node.has_method("anchor"):
		node.global_position = node.anchor()
	_decor.append(node)

## Where the villagers stand in the evening of a fair day: around the pole.
func evening_spot(slot: int) -> Vector2:
	var angle := -PI * 0.15 + slot * 0.9
	return POLE + Vector2(cos(angle) * 44.0, 18.0 + sin(angle) * 16.0)

func launch_firework() -> void:
	# Over the square, inside the view (the camera looks down at the hero).
	var near := game.player.global_position if game.player.global_position.distance_to(CENTER) < 260.0 else CENTER
	var at := near + Vector2(_rng.randf_range(-150, 150), _rng.randf_range(-105, -55))
	var palettes := [
		[Color(1, 1, 0.9), Color(1.0, 0.45, 0.4), Color(0.9, 0.2, 0.3, 0.0)],
		[Color(1, 1, 1), Color(0.5, 0.8, 1.0), Color(0.3, 0.4, 1.0, 0.0)],
		[Color(1, 1, 0.8), Color(1.0, 0.85, 0.3), Color(1.0, 0.5, 0.1, 0.0)],
		[Color(1, 0.95, 1), Color(0.85, 0.5, 1.0), Color(0.5, 0.2, 0.8, 0.0)],
		[Color(0.95, 1, 0.95), Color(0.5, 1.0, 0.6), Color(0.2, 0.7, 0.4, 0.0)],
	]
	var colors: Array = palettes[_rng.randi() % palettes.size()]
	for ring in 2:
		var burst := Vfx.burst(game, at, colors, 60 if ring == 0 else 30, 130.0 if ring == 0 else 60.0, 1.6)
		if burst != null:
			burst.gravity = Vector2(0, 30)
			burst.damping_min = 25.0
			burst.damping_max = 45.0
			burst.scale_amount_min = 2.0
			burst.scale_amount_max = 3.5
			burst.z_index = 60
	# A bright flash at the heart of the burst.
	var flash := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 12:
		points.append(Vector2.RIGHT.rotated(TAU * i / 12.0) * 7.0)
	flash.polygon = points
	flash.color = (colors[1] as Color).lightened(0.5)
	flash.z_index = 61
	game.add_child(flash)
	flash.global_position = at
	var tween := flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2.5, 2.5), 0.25)
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(flash.queue_free)
	GameAudio.play("firework", -8.0, 0.1)

# --- Shooting gallery ---------------------------------------------------------

func open_gallery() -> void:
	if playing:
		return
	var tokens := "Рекорд: %d мишеней." % best if best > 0 else "Рекорда ещё нет — будь первой!"
	game._show_dialogue_choices(HOST, "Тир! Тридцать секунд, соломенные мишени выскакивают и прячутся. Бей чем хочешь — мечом, стрелой, огнём. Каждые две мишени — жетон! %s" % tokens, [
		{"id": "fair_gallery_start", "label": "Начать (бесплатно)"},
		{"id": "fair_later", "label": "Потом"},
	])

func start_gallery() -> void:
	game.dialogues._close()
	playing = true
	score = 0
	time_left = GALLERY_TIME
	_spawn_clock = 0.3
	game.hud.show_title_card("Тир!", 1.5)
	GameAudio.play("quest", -8.0)

func _tick_gallery(delta: float) -> void:
	time_left -= delta
	_spawn_clock -= delta
	if _spawn_clock <= 0.0 and time_left > 1.0:
		# Faster and two at a time near the end.
		_spawn_clock = lerpf(1.6, 0.8, 1.0 - time_left / GALLERY_TIME)
		spawn_target()
		if time_left < GALLERY_TIME * 0.4:
			spawn_target()
	game.hud.show_message("Тир: %d мишеней · %d с" % [score, ceili(maxf(0.0, time_left))], 0.4)
	if time_left <= 0.0:
		_end_gallery()

func spawn_target() -> SlimeEnemy:
	var target := (SkywardGame.ENEMY_SCRIPTS["slime"] as GDScript).new() as SlimeEnemy
	target.set_meta("event_foe", true)
	target.set_meta("fair_target", true)
	target.max_health = 1
	target.xp_reward = 0
	game.add_child(target)
	target.global_position = RANGE.position + Vector2(_rng.randf() * RANGE.size.x, _rng.randf() * RANGE.size.y)
	target.health = 1
	target.set_physics_process(false)
	if target.visual != null:
		target.visual.visible = false
	if target.combat_feedback != null:
		target.combat_feedback.visible = false
	var look := Sprite2D.new()
	look.texture = load("res://assets/world_hd/props/fair_target.png")
	look.scale = Vector2(0.5, 0.5)
	look.offset = Vector2(0, -26)
	look.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	target.add_child(look)
	look.scale = Vector2(0.5, 0.05)
	look.create_tween().tween_property(look, "scale", Vector2(0.5, 0.5), 0.12)
	target.defeated.connect(func(_xp: int) -> void: _on_target_hit())
	get_tree().create_timer(TARGET_LIFE).timeout.connect(func() -> void:
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			target.queue_free())
	return target

func _on_target_hit() -> void:
	if not playing:
		return
	score += 1
	GameAudio.play("pickup", -10.0, 0.1)

func _end_gallery() -> void:
	playing = false
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("fair_target"):
			node.queue_free()
	var tokens := ceili(score / 2.0)
	var record := score > best
	best = maxi(best, score)
	if tokens > 0:
		game.player.add_item(TOKEN, tokens)
	game.achievements.set_max("fair_gallery", score)
	var line := "Время! %d мишеней — %d %s." % [score, tokens, _token_word(tokens)]
	if record and score > 0:
		line += " Новый рекорд ярмарки!"
		GameAudio.play("level_up", -8.0)
	game.hud.show_message(line, 4.0)
	game._refresh_hud()

static func _token_word(n: int) -> String:
	if n % 10 == 1 and n % 100 != 11:
		return "жетон"
	if n % 10 in [2, 3, 4] and not n % 100 in [12, 13, 14]:
		return "жетона"
	return "жетонов"

# --- Prizes and fish -------------------------------------------------------------

func tokens() -> int:
	return int(game.player.inventory.get(TOKEN, 0))

func open_booth() -> void:
	var choices: Array[Dictionary] = []
	for i in PRIZES.size():
		var prize: Dictionary = PRIZES[i]
		var name := game.player.get_item_name(str(prize["id"]))
		if int(prize["amount"]) > 1:
			name += " ×%d" % int(prize["amount"])
		choices.append({"id": "fair_prize:%d" % i, "label": "%s — %d %s" % [name, int(prize["cost"]), _token_word(int(prize["cost"]))]})
	choices.append({"id": "fair_later", "label": "Уйти"})
	game._show_dialogue_choices(HOST, "Призы, призы! У тебя %d %s. Жетоны дают в тире, а сегодня ещё и за каждую пойманную рыбу." % [tokens(), _token_word(tokens())], choices)

func _on_fish(caught: String) -> void:
	if caught.is_empty() or caught == "old_boot" or not open():
		return
	game.player.add_item(TOKEN, 1)
	game.hud.show_message("Рыбный день на ярмарке: +1 жетон", 2.0)

func handle_choice(choice_id: String) -> bool:
	if choice_id == "fair_later":
		game.dialogues._close()
		return true
	if choice_id == "fair_gallery_start":
		start_gallery()
		return true
	if choice_id.begins_with("fair_prize:"):
		var index := int(choice_id.trim_prefix("fair_prize:"))
		if index < 0 or index >= PRIZES.size():
			return true
		var prize: Dictionary = PRIZES[index]
		if tokens() < int(prize["cost"]):
			game.hud.show_message("Не хватает жетонов.", 1.8)
		else:
			game.player.remove_item(TOKEN, int(prize["cost"]))
			game.player.add_item(str(prize["id"]), int(prize["amount"]))
			GameAudio.play("chest", -8.0)
			game.hud.show_message("Приз: %s!" % game.player.get_item_name(str(prize["id"])), 2.5)
		open_booth()
		return true
	return false

# --- Fairground pieces ---------------------------------------------------------------

## A drawn prop of the fair (y-sorted with the hero by its foot).
class FairProp extends Node2D:
	var art: String
	var spot: Vector2
	var block: Vector2

	func _init(art_name: String, at: Vector2, block_size: Vector2 = Vector2.ZERO) -> void:
		art = art_name
		spot = at
		block = block_size

	func anchor() -> Vector2:
		return spot

	func _ready() -> void:
		add_to_group("region_actor")
		var sprite := Sprite2D.new()
		var texture := load("res://assets/world_hd/props/%s.png" % art) as Texture2D
		sprite.texture = texture
		sprite.scale = Vector2(0.5, 0.5)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if texture != null:
			sprite.offset = Vector2(0, -texture.get_height() * 0.5 + 4)
		add_child(sprite)
		if block != Vector2.ZERO:
			var body := StaticBody2D.new()
			body.collision_layer = 4
			body.collision_mask = 0
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = block
			shape.shape = rect
			shape.position = Vector2(0, -block.y * 0.5)
			body.add_child(shape)
			add_child(body)

## A stall the hero talks to (E).
class FairStand extends FairProp:
	signal used
	var prompt: String

	func _init(art_name: String, at: Vector2, verb: String) -> void:
		super(art_name, at, Vector2(44, 12))
		prompt = verb

	func _ready() -> void:
		super()
		add_to_group("interactables")

	func interact() -> void:
		used.emit()

## Ribbons fluttering from the top of the pole.
class Ribbons extends Node2D:
	var _clock := 0.0
	const COLORS := [Color(0.95, 0.35, 0.35), Color(1.0, 0.85, 0.3), Color(0.45, 0.7, 1.0), Color(0.6, 0.9, 0.5), Color(0.9, 0.55, 0.95)]

	func _ready() -> void:
		add_to_group("region_actor")
		z_index = 3

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		for i in COLORS.size():
			var base := TAU * i / COLORS.size() + _clock * 0.8
			var points := PackedVector2Array()
			for k in 9:
				var t := k / 8.0
				var sway := sin(_clock * 3.0 + t * 4.0 + i) * 3.0 * t
				points.append(Vector2(cos(base) * (4.0 + 26.0 * t) + sway, sin(base) * 6.0 * t + 40.0 * t * t + 2.0))
			draw_polyline(points, COLORS[i], 1.5)

## A string of little flags between poles.
class Garland extends Node2D:
	var points_list: Array = []
	var _clock := 0.0
	const FLAGS := [Color(0.9, 0.3, 0.3), Color(1.0, 0.85, 0.35), Color(0.4, 0.65, 0.95), Color(0.55, 0.85, 0.45), Color(0.95, 0.95, 0.9)]

	func _ready() -> void:
		add_to_group("region_actor")
		z_index = 25

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		var flag := 0
		for s in points_list.size() - 1:
			var a: Vector2 = points_list[s]
			var b: Vector2 = points_list[s + 1]
			var line := PackedVector2Array()
			var steps := 16
			for k in steps + 1:
				var t := float(k) / steps
				var p := a.lerp(b, t) + Vector2(0, sin(t * PI) * 10.0)
				line.append(p)
			draw_polyline(line, Color(0.35, 0.25, 0.2, 0.9), 1.0)
			for k in range(1, steps, 2):
				var p := line[k]
				var flutter := sin(_clock * 4.0 + k + s) * 1.2
				draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(3, 0), p + Vector2(flutter, 7)]), FLAGS[flag % FLAGS.size()])
				flag += 1
		# A short post under the outer end.
		var end: Vector2 = points_list[points_list.size() - 1]
		draw_line(end, end + Vector2(0, 40), Color(0.45, 0.3, 0.2), 2.0)
		draw_circle(end, 1.8, Color(0.95, 0.8, 0.3))
