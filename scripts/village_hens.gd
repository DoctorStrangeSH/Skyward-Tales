extends Node
class_name VillageHens

## Stage 21, step 7: hens of the homestead. With a garden (settlement
## building "farm") hens walk about it: peck, wander, scurry away from the
## hero. Every morning each hen lays an egg near the garden (up to MAX_EGGS
## wait to be picked up). Eggs go into omelettes on the kitchen.

const HOME := "greenreach"
const YARD := Rect2(700, 892, 140, 44)
const MAX_EGGS := 6

## One hen.
class Hen extends Node2D:
	var visual: DirectionalSprite
	var yard: Rect2
	var rng := RandomNumberGenerator.new()
	var hero: Node2D
	var _target: Vector2
	var _wait: float = 0.0
	var _pecking: float = 0.0
	var _cluck: float = 0.0

	func _ready() -> void:
		add_to_group("region_actor")
		rng.randomize()
		visual = DirectionalSprite.new()
		visual.configure_chibi("hen", 8.0)
		visual.set_direction_vector(Vector2.DOWN)
		visual.set_moving(false)
		add_child(visual)
		GroundShadows.attach(self, 8.0)
		_target = global_position
		_wait = rng.randf_range(0.5, 3.0)

	func _process(delta: float) -> void:
		_cluck = maxf(0.0, _cluck - delta)
		var speed := 22.0
		if is_instance_valid(hero) and hero.global_position.distance_to(global_position) < 26.0:
			# Shoo! Run from the hero, but stay near the yard.
			var away := (global_position - hero.global_position).normalized()
			_target = (global_position + away * 46.0).clamp(yard.position - Vector2(30, 20), yard.end + Vector2(30, 20))
			_wait = 0.0
			_pecking = 0.0
			speed = 70.0
			if _cluck <= 0.0:
				_cluck = 2.5
				GameAudio.play("ui_tick", -14.0, 0.2)
		if _pecking > 0.0:
			_pecking -= delta
			return
		if _wait > 0.0:
			_wait -= delta
			visual.set_moving(false)
			if _wait <= 0.0 and rng.randf() < 0.5:
				_pecking = 0.9
				visual.set_direction_vector(Vector2.DOWN)
				visual.play_named("peck", 0.9)
			return
		var step := _target - global_position
		if step.length() < 2.0:
			_wait = rng.randf_range(1.0, 4.0)
			_target = Vector2(rng.randf_range(yard.position.x, yard.end.x), rng.randf_range(yard.position.y, yard.end.y))
			return
		visual.set_direction_vector(step)
		visual.set_moving(true)
		global_position += step.normalized() * minf(step.length(), speed * delta)

var game: SkywardGame
var eggs_waiting: int = 0
var eggs_found: int = 0
var _day: int = -1
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func count() -> int:
	var level := game.settlement.building_level(Farm.BUILDING)
	return 0 if level <= 0 else 1 + level

func _process(_delta: float) -> void:
	if game == null or game.day_night == null:
		return
	var day := game.day_night.day
	if _day < 0:
		_day = day
	elif day != _day:
		# Morning: every hen has laid an egg.
		var laid := mini(count() * (day - _day), MAX_EGGS - eggs_waiting) if day > _day else 0
		_day = day
		if laid > 0:
			eggs_waiting += laid
			if game.current_region == HOME:
				_lay(laid)
				game.hud.show_message("Куры снеслись: у огорода %d свеж. яиц." % eggs_waiting, 3.5)

func _lay(amount: int) -> void:
	for i in amount:
		var at := Vector2(rng.randf_range(YARD.position.x, YARD.end.x), rng.randf_range(YARD.position.y, YARD.end.y))
		var loot := game._spawn_loot(at, "egg")
		loot.amount = 1
		loot.set_meta("hen_egg", true)
		loot.collected.connect(_on_egg_found)

func _on_egg_found(_item: String, _amount: int) -> void:
	eggs_waiting = maxi(0, eggs_waiting - 1)
	eggs_found += 1

## Called when a region is built.
func populate() -> void:
	if game.current_region != HOME:
		return
	for i in count():
		var hen := Hen.new()
		hen.yard = YARD
		hen.hero = game.player
		hen.position = Vector2(rng.randf_range(YARD.position.x, YARD.end.x), rng.randf_range(YARD.position.y, YARD.end.y))
		game.add_child(hen)
	if count() > 0 and eggs_waiting > 0:
		_lay(eggs_waiting)

func make_snapshot() -> Dictionary:
	return {"eggs": eggs_waiting, "found": eggs_found, "day": _day}

func restore_snapshot(value: Variant) -> void:
	var data: Dictionary = value if value is Dictionary else {}
	eggs_waiting = clampi(int(data.get("eggs", 0)), 0, MAX_EGGS)
	eggs_found = int(data.get("found", 0))
	_day = int(data.get("day", -1))
