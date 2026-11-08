extends Node2D
class_name CrystalStrike

## «Хрустальный шторм»: a glowing circle warns, then a crystal falls.
## Standing inside when it lands hurts; rolling out is enough.

const WARN := 1.1
const RADIUS := 18.0

var damage: int = 8
## A lightning bolt instead of a falling crystal (Грозовой остров).
var lightning: bool = false
var _clock: float = 0.0
var _landed: bool = false

func _ready() -> void:
	add_to_group("region_actor")
	z_index = 2

func _process(delta: float) -> void:
	_clock += delta
	if not _landed and _clock >= WARN:
		_landed = true
		var game := get_parent() as SkywardGame
		if game != null and game.player.global_position.distance_to(global_position) < RADIUS:
			game.player.take_damage(damage, self)
		GameAudio.play("hit", -10.0, 0.3)
	if _clock > WARN + 0.5:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if lightning:
		_draw_lightning()
		return
	if not _landed:
		var t := _clock / WARN
		draw_circle(Vector2.ZERO, RADIUS, Color(0.55, 0.85, 1.0, 0.22 + 0.25 * t))
		draw_arc(Vector2.ZERO, RADIUS * t, 0.0, TAU, 24, Color(0.85, 0.97, 1.0, 0.95), 2.0)
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color(0.85, 0.97, 1.0, 0.7), 1.0)
		# The crystal falling from above.
		var y := -90.0 * (1.0 - t)
		_draw_crystal(Vector2(0, y - 6), 0.7 + 0.3 * t)
	else:
		var fade := 1.0 - (_clock - WARN) / 0.5
		for i in 6:
			var angle := TAU * i / 6.0
			var dist := 6.0 + 18.0 * (1.0 - fade)
			_draw_crystal(Vector2(cos(angle), sin(angle)) * dist, fade * 0.6)

func _draw_crystal(at: Vector2, alpha: float) -> void:
	var shape := PackedVector2Array([at + Vector2(0, -9), at + Vector2(4, 0), at + Vector2(0, 6), at + Vector2(-4, 0)])
	draw_colored_polygon(shape, Color(0.65, 0.9, 1.0, alpha))
	draw_polyline(shape + PackedVector2Array([shape[0]]), Color(1, 1, 1, alpha), 1.0)

func _draw_lightning() -> void:
	if not _landed:
		var t := _clock / WARN
		draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.95, 0.5, 0.15 + 0.25 * t))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color(1.0, 0.95, 0.6, 0.5 + 0.4 * t), 1.5)
		draw_arc(Vector2.ZERO, RADIUS * (1.0 - t), 0.0, TAU, 24, Color(1.0, 1.0, 0.8, 0.9), 1.5)
		return
	var fade := 1.0 - (_clock - WARN) / 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 13.0 + global_position.y)
	var points := PackedVector2Array([Vector2(0, -160)])
	for i in 7:
		points.append(Vector2(rng.randf_range(-10, 10), -160.0 + 160.0 * (i + 1) / 7.0))
	points.append(Vector2.ZERO)
	draw_polyline(points, Color(0.8, 0.85, 1.0, fade * 0.5), 5.0)
	draw_polyline(points, Color(1, 1, 1, fade), 2.0)
	draw_circle(Vector2.ZERO, RADIUS * 0.8, Color(1.0, 0.95, 0.7, fade * 0.45))
