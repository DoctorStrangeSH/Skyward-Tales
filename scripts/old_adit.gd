extends Node
class_name OldAdit

## Stage 21, step 9: the Old Adit — a mine in the north of Greenreach
## (region "old_adit", tools/adit_layout.py).
##
## Copper veins lie in its halls; a minecart runs the rails between the
## entry cave and the copper hall (E — a quick ride either way). Two
## branches are buried under cave-ins: they yield only to a pickaxe. Behind
## one — rich veins, behind the other — an amethyst geode and its Guardian.
## Tools are made at the foresters' bench and work from the bag:
## the copper pickaxe gives +1 from every vein and rock and clears rubble,
## the copper axe gives +1 log from every tree.

const HOME := "greenreach"
const REGION := "old_adit"
const ENTRANCE := Vector2(1270, 205)
const INSIDE := Vector2(110, 500)
const CART_STOPS := [Vector2(210, 450), Vector2(770, 450)]
const RUBBLE := [Vector2(984, 448), Vector2(816, 250)]
const GUARDIAN_AT := Vector2(816, 128)
const PICKAXE := "copper_pickaxe"
const AXE := "copper_axe"

## The cart: E rides it to the other end of the line.
class Cart extends Node2D:
	signal arrived
	var stops: Array = []
	var at_stop: int = 0
	var rider: Node2D
	var riding: bool = false
	var _clock: float = 0.0

	func _ready() -> void:
		add_to_group("region_actor")
		add_to_group("interactables")
		GroundShadows.attach(self, 22.0)

	func interact() -> void:
		get_meta("adit").call("ride")

	func _process(delta: float) -> void:
		if not riding:
			return
		_clock += delta
		var target: Vector2 = stops[at_stop]
		var step := target - global_position
		var move := 300.0 * delta
		if step.length() <= move:
			global_position = target
			riding = false
			arrived.emit()
		else:
			global_position += step.normalized() * move
		if is_instance_valid(rider):
			rider.global_position = global_position + Vector2(0, -8)
		queue_redraw()

	func _draw() -> void:
		WorldArt.draw_prop(self, "world/props/mine_cart.png", false, Vector2(0, sin(_clock * 40.0) * 0.6 if riding else 0.0))

var game: SkywardGame
var cleared: Array = [false, false]
var guardian_down: bool = false
var rides: int = 0
var _cart: Cart
var _rubble: Array = [[], []]

func has_pickaxe() -> bool:
	return int(game.player.inventory.get(PICKAXE, 0)) > 0

## Extra items from a gather node thanks to tools in the bag.
func tool_bonus(node: GatherNode) -> int:
	if node.kind in ["iron", "copper", "stone", "amethyst"] and has_pickaxe():
		return 1
	if node.kind == "wood" and int(game.player.inventory.get(AXE, 0)) > 0:
		return 1
	return 0

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

## Called when a region is built.
func populate() -> void:
	_cart = null
	_rubble = [[], []]
	if game.current_region == HOME:
		_object(ENTRANCE, "mine_timber", "", 0.0, Color(1.0, 0.75, 0.4, 0.5))
		var way := _object(ENTRANCE + Vector2(0, -4), "", "E — спуститься в штольню")
		way.map_label = "Старая штольня"
		way.used.connect(func(_o: TowerObject) -> void: enter())
		_object(ENTRANCE + Vector2(0, 14), "mine_track", "", 0.0, Color(0, 0, 0, 0), true).rotation = PI / 2.0
		_object(ENTRANCE + Vector2(44, 10), "vein_cut")
		return
	if game.current_region != REGION:
		return
	# The way out and the rails.
	_object(INSIDE + Vector2(0, 36), "mine_timber", "", 0.0, Color(1.0, 0.75, 0.4, 0.4))
	var way_out := _object(INSIDE + Vector2(0, 30), "", "E — выйти наружу")
	way_out.map_label = "Выход"
	way_out.used.connect(func(_o: TowerObject) -> void: leave())
	var from: Vector2 = CART_STOPS[0]
	var to: Vector2 = CART_STOPS[1]
	var x := from.x - 20.0
	while x <= to.x + 20.0:
		_object(Vector2(x, from.y + 4), "mine_track", "", 0.0, Color(0, 0, 0, 0), true)
		x += 64.0
	for tx in [340.0, 500.0, 660.0]:
		_object(Vector2(tx, 482), "mine_timber", "", 0.0, Color(1.0, 0.75, 0.4, 0.35)).z_index = 30
	_object(Vector2(984, 482), "mine_timber").z_index = 30
	_cart = Cart.new()
	_cart.stops = CART_STOPS
	_cart.set_meta("adit", self)
	game.add_child(_cart)
	_cart.global_position = CART_STOPS[0]
	_cart.arrived.connect(_on_arrived)
	# Cave-ins.
	for i in RUBBLE.size():
		if not bool(cleared[i]):
			_build_rubble(i)
	# The geode hall.
	if not guardian_down:
		_spawn_guardian()
	else:
		_geode_chest()

func cart_prompt() -> String:
	return "E — прокатиться в вагонетке"

func _build_rubble(index: int) -> void:
	var at: Vector2 = RUBBLE[index]
	var along := Vector2(0, 1) if index == 0 else Vector2(1, 0)
	var parts: Array = []
	for k in [-1, 0, 1]:
		var rock := _object(at + along * 20.0 * k + Vector2(0, 8), "vein_cut")
		parts.append(rock)
	var wall := _object(at + Vector2(0, 10), "", "E — разобрать завал")
	wall.used.connect(func(_o: TowerObject) -> void: clear_rubble(index))
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(20, 72) if index == 0 else Vector2(72, 20)
	shape.shape = box
	shape.position = Vector2(0, -10)
	body.add_child(shape)
	wall.add_child(body)
	parts.append(wall)
	_rubble[index] = parts

## Breaks a cave-in apart (needs the pickaxe).
func clear_rubble(index: int) -> bool:
	if index < 0 or index >= cleared.size() or bool(cleared[index]):
		return false
	if not has_pickaxe():
		game.hud.show_message("Завал не разобрать голыми руками. Нужна кирка — её делают на верстаке лесничих из досок и меди.", 4.5)
		return false
	cleared[index] = true
	for part in _rubble[index]:
		if is_instance_valid(part):
			part.queue_free()
	_rubble[index] = []
	var at: Vector2 = RUBBLE[index]
	game.shake(4.0, 0.4)
	GameAudio.play("boss_roar", -14.0, 0.2)
	Vfx.burst(game, at, [Color(0.8, 0.75, 0.7), Color(0.5, 0.45, 0.4), Color(0.3, 0.28, 0.26, 0)], 26, 110.0, 0.6)
	game.player.add_item("stone", 3)
	game.hud.show_message("Завал разобран! +3 камня. Путь %s открыт." % ("к богатым жилам" if index == 0 else "к аметистовой жеоде"), 4.0)
	game.request_autosave()
	return true

func enter() -> void:
	game._travel(REGION, INSIDE)

func leave() -> void:
	game._travel(HOME, ENTRANCE + Vector2(0, 30))

## A ride to the other end of the line.
func ride() -> void:
	if _cart == null or _cart.riding:
		return
	var hero := game.player
	_cart.at_stop = 1 - _cart.at_stop
	_cart.rider = hero
	_cart.riding = true
	hero.set_physics_process(false)
	hero.velocity = Vector2.ZERO
	rides += 1
	GameAudio.play("travel", -8.0, 0.3)

func _on_arrived() -> void:
	var hero := game.player
	hero.set_physics_process(true)
	hero.global_position = _cart.global_position + Vector2(0, 22)
	_cart.rider = null
	GameAudio.play("ui_tick", -6.0, -0.3)

func _spawn_guardian() -> void:
	var foe := game.spawn_enemy("golem", GUARDIAN_AT)
	if foe == null:
		return
	foe.set_meta("adit_guardian", true)
	foe.set_meta("special_encounter", true)
	foe.max_health = roundi(foe.max_health * 5.0)
	foe.health = foe.max_health
	foe.attack_damage = roundi(foe.attack_damage * 1.2)
	foe.xp_reward = roundi(foe.xp_reward * 3.0)
	foe.combat_feedback.elite = true
	foe.combat_feedback.elite_name = "♦ Страж жеоды"
	foe.combat_feedback.elite_color = Color(0.8, 0.55, 1.0)
	foe.base_visual_tint = Color(0.85, 0.7, 1.0)
	foe.visual.modulate = foe.base_visual_tint
	foe.combat_feedback.set_health(foe.health, foe.max_health)
	foe.defeated.connect(func(_xp: int) -> void: _on_guardian_down())

func _on_guardian_down() -> void:
	if guardian_down:
		return
	guardian_down = true
	_geode_chest.call_deferred()
	game.achievements.set_max("adit_guardian", 1)
	game.hud.show_title_card("Страж жеоды повержен", 2.4)
	game.request_autosave()

func _geode_chest() -> void:
	game._spawn_chest("adit_geode", GUARDIAN_AT + Vector2(0, -34), 180, "amethyst", 4, "gold")

func make_snapshot() -> Dictionary:
	return {"cleared": cleared.duplicate(), "guardian": guardian_down, "rides": rides}

func restore_snapshot(value: Variant) -> void:
	var data: Dictionary = value if value is Dictionary else {}
	var saved: Array = data.get("cleared", [])
	cleared = [saved.size() > 0 and bool(saved[0]), saved.size() > 1 and bool(saved[1])]
	guardian_down = bool(data.get("guardian", false))
	rides = int(data.get("rides", 0))
