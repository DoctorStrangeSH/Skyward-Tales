extends Node
class_name Fishing

## Fishing minigame at fishing spots (gather kind "fish"):
##   cast → wait for a bite → hook in time (E / LMB) → reel: hold E / LMB to
##   lift the green zone and keep the fish inside until the bar fills.
## Species, difficulty and sizes come from data/fish.json; every catch goes
## into the hero's fishing log (with personal size records).

signal finished(caught: String)

const DATA_PATH := "res://data/fish.json"
const BITE_WINDOW := 1.4
## Early presses forgiven before the fish takes fright.
const EARLY_LIMIT := 3
## Seconds at the start of reeling when the catch bar cannot drop.
const REEL_GRACE := 1.2

var game: SkywardGame
var data: Dictionary = {}
var rng := RandomNumberGenerator.new()
## "", "waiting", "bite", "reel"
var state: String = ""
var timer: float = 0.0
var node: GatherNode
var species: String = ""
var difficulty: float = 0.3
## Reel bar, all 0..1: green zone (bottom edge + width), fish, catch progress.
var zone: float = 0.0
var zone_width: float = 0.3
var zone_speed: float = 0.0
var fish_pos: float = 0.5
var fish_target: float = 0.5
var fish_timer: float = 0.0
var progress: float = 0.0
## Held input; play reads E / LMB, tests set it directly.
var holding: bool = false
var manual_input: bool = false
var _start_health: int = 0
var early_presses: int = 0
var _reel_time: float = 0.0
var _cast_at: Vector2
var _line: Line2D
var _bobber: Node2D

func _ready() -> void:
	rng.randomize()
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed

func active() -> bool:
	return not state.is_empty()

func start(spot: GatherNode) -> bool:
	if active():
		return false
	if not spot.available:
		game.hud.show_message("Здесь пока не клюёт. Рыба вернётся позже.", 2.0)
		return false
	node = spot
	early_presses = 0
	state = "waiting"
	timer = rng.randf_range(1.4, 3.4)
	species = _roll_species()
	difficulty = float(data.get("species", {}).get(species, {}).get("difficulty", 0.3))
	var player := game.player
	_start_health = player.health
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	var direction := (spot.global_position - player.global_position)
	player.visual.set_direction_vector(direction.normalized() if direction.length() > 1.0 else player.facing)
	player.visual.play_named("cast", 0.4)
	_show_tackle()
	GameAudio.play("gust", -10.0, 0.1)
	game.hud.show_fishing(self)
	return true

func _roll_species() -> String:
	var regions: Dictionary = data.get("regions", {})
	var table: Array = regions.get(game.current_region, regions.get("default", [["fish", 1]]))
	var total := 0.0
	for entry in table:
		total += float(entry[1])
	var pick := rng.randf() * total
	for entry in table:
		pick -= float(entry[1])
		if pick <= 0.0:
			return str(entry[0])
	return str(table.back()[0])

## E / LMB pressed.
func press() -> void:
	match state:
		"waiting":
			early_presses += 1
			if early_presses >= EARLY_LIMIT:
				_end("", "Рыба испугалась суеты. Ждите, пока поплавок нырнёт!")
			else:
				# Forgiven: the fish only hesitates a little longer.
				timer += 0.6
				game.hud.show_message("Рано! Ждите, пока поплавок нырнёт (ещё %d)." % (EARLY_LIMIT - early_presses), 1.6)
		"bite":
			_begin_reel()

func cancel() -> void:
	if active():
		_end("", "Вы смотали удочку.")

func _begin_reel() -> void:
	state = "reel"
	zone_width = lerpf(0.42, 0.27, difficulty)
	zone = 0.2
	zone_speed = 0.0
	fish_pos = 0.35
	fish_target = 0.4
	fish_timer = 0.8
	progress = 0.45
	_reel_time = 0.0
	GameAudio.play("hit", -8.0, 0.05)

func _process(delta: float) -> void:
	if not active():
		return
	if not manual_input and DisplayServer.get_name() != "headless":
		holding = Input.is_action_pressed("interact") or Input.is_action_pressed("attack")
	if game.player.health < _start_health:
		_end("", "Вас атакуют — рыбалка прервана!")
		return
	timer -= delta
	match state:
		"waiting":
			if timer <= 0.0:
				state = "bite"
				timer = BITE_WINDOW
				GameAudio.play("pickup", -2.0, 0.0)
				if _bobber != null:
					Vfx.burst(game, _bobber.global_position, [Color(1, 1, 1), Color(0.7, 0.85, 1.0), Color(0.5, 0.7, 1.0, 0)], 8, 40.0, 0.35)
		"bite":
			if timer <= 0.0:
				_end("", "Сорвалась… Подсекайте сразу, как поплавок нырнёт!")
		"reel":
			_update_reel(delta)
	_update_tackle()
	game.hud.update_fishing(self)

func _update_reel(delta: float) -> void:
	# Zone: holding lifts it, gravity pulls it down, bounces softly at the ends.
	# Responsive and calm: quick to react, quick to stop.
	_reel_time += delta
	zone_speed += (3.2 if holding else -2.6) * delta
	zone_speed = clampf(zone_speed, -1.1, 1.1)
	zone += zone_speed * delta
	if zone < 0.0:
		zone = 0.0
		zone_speed = absf(zone_speed) * 0.15
	elif zone > 1.0 - zone_width:
		zone = 1.0 - zone_width
		zone_speed = -absf(zone_speed) * 0.15
	# Fish: darts to new spots, faster and more often when it is harder.
	fish_timer -= delta
	if fish_timer <= 0.0:
		fish_timer = rng.randf_range(lerpf(1.6, 0.7, difficulty), lerpf(2.4, 1.2, difficulty))
		# Short darts: the fish moves to a nearby spot, not across the bar.
		var reach := lerpf(0.3, 0.6, difficulty)
		fish_target = clampf(fish_pos + rng.randf_range(-reach, reach), 0.05, 0.95)
	fish_pos = move_toward(fish_pos, fish_target, lerpf(0.2, 0.55, difficulty) * delta)
	if fish_inside():
		progress += 0.45 * delta
	elif _reel_time > REEL_GRACE:
		progress -= lerpf(0.1, 0.2, difficulty) * delta
	if progress >= 1.0:
		_catch()
	elif progress <= 0.0:
		_end("", "Рыба ушла! Держите её в зелёной зоне.")

func fish_inside() -> bool:
	return fish_pos >= zone and fish_pos <= zone + zone_width

func _catch() -> void:
	var player := game.player
	var info: Dictionary = data.get("species", {}).get(species, {})
	var size_range: Array = info.get("size", [20, 30])
	var size := rng.randi_range(int(size_range[0]), int(size_range[1]))
	player.add_item(species)
	var entry: Dictionary = player.fish_log.get(species, {"count": 0, "best": 0})
	var record := size > int(entry.get("best", 0))
	var first := int(entry.get("count", 0)) == 0
	entry["count"] = int(entry.get("count", 0)) + 1
	entry["best"] = maxi(int(entry.get("best", 0)), size)
	player.fish_log[species] = entry
	game.crafting.rest_node(node)
	var name := player.get_item_name(species)
	var text := "Поймано: %s, %d см!" % [name, size]
	if first:
		text += " Новый вид в журнале рыбака!"
	elif record and species != "old_boot":
		text += " Личный рекорд!"
	GameAudio.play("quest" if first else "pickup", -4.0, 0.0)
	Vfx.sparkle(game, player.global_position)
	_end(species, text)

func _end(caught: String, message: String) -> void:
	state = ""
	holding = false
	if game.player != null:
		game.player.set_physics_process(true)
	_hide_tackle()
	game.hud.hide_fishing()
	game.hud.show_message(message, 2.6)
	finished.emit(caught)

# --- Rod line and bobber ---------------------------------------------------------

func _show_tackle() -> void:
	_line = Line2D.new()
	_line.width = 1.0
	_line.default_color = Color(0.95, 0.95, 0.9, 0.8)
	_line.z_index = 20
	game.add_child(_line)
	_bobber = Node2D.new()
	_bobber.z_index = 21
	_bobber.set_script(preload("res://scripts/fishing_bobber.gd"))
	game.add_child(_bobber)
	_cast_at = water_point(node.global_position)
	_bobber.global_position = _cast_at

## A point in the nearest pond, a little way out from the spot.
func water_point(from: Vector2) -> Vector2:
	var best := from + Vector2(0, -14)
	var best_distance := INF
	for pond in game._layout().get("terrain", {}).get("ponds", []):
		var target: Vector2
		var center: Vector2
		if pond.has("circle"):
			var c: Array = pond["circle"]
			center = Vector2(float(c[0]), float(c[1]))
			var radius := float(c[2])
			var direction := (from - center).normalized() if from.distance_to(center) > 1.0 else Vector2.UP
			target = center + direction * maxf(0.0, radius - 16.0)
		elif pond.has("rect"):
			var r: Array = pond["rect"]
			var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow(-12.0)
			center = rect.get_center()
			target = Vector2(clampf(from.x, rect.position.x, rect.end.x), clampf(from.y, rect.position.y, rect.end.y))
		else:
			continue
		var distance := from.distance_to(target)
		if distance < best_distance and distance < 90.0:
			best_distance = distance
			best = target
	return best

func _update_tackle() -> void:
	if _line == null or _bobber == null:
		return
	var dip := 3.0 if state == "bite" else (1.5 * sin(Time.get_ticks_msec() / 220.0) if state == "waiting" else 1.0)
	if state == "reel":
		dip = 2.0 * sin(Time.get_ticks_msec() / 60.0)
	_bobber.position = _cast_at + Vector2(0, dip)
	_bobber.set("alert", state == "bite")
	_bobber.queue_redraw()
	var hand := game.player.global_position + Vector2(5, -14)
	var tip := hand + (_bobber.global_position - hand).normalized() * 16.0 + Vector2(0, -10)
	var points := PackedVector2Array([hand, tip])
	var end := _bobber.global_position
	for i in range(1, 7):
		var t := float(i) / 6.0
		var p := tip.lerp(end, t)
		p.y += sin(t * PI) * (6.0 if state != "reel" else 1.0)
		points.append(p)
	_line.points = points

func _hide_tackle() -> void:
	if _line != null:
		_line.queue_free()
		_line = null
	if _bobber != null:
		_bobber.queue_free()
		_bobber = null
