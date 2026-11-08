extends Node2D
class_name RunePlate

## A floor rune of the Pattern Vault puzzle (Expeditions): stepping on it
## emits `stepped`. Lit plates glow in their element's colour.

signal stepped(plate: RunePlate)

var rune: int = 0
var color: Color = Color.WHITE
var lit: bool = false
var _inside: bool = false
var _clock: float = 0.0

func _ready() -> void:
	add_to_group("region_actor")
	z_index = -40

func _process(delta: float) -> void:
	_clock += delta
	var game := get_parent() as SkywardGame
	if game != null and game.player != null:
		var now := game.player.global_position.distance_to(global_position) < 15.0
		if now and not _inside:
			stepped.emit(self)
		_inside = now
	queue_redraw()

func _draw() -> void:
	var glow := 0.9 if lit else 0.25 + 0.12 * sin(_clock * 2.5 + rune)
	draw_circle(Vector2.ZERO, 13.0, Color(0.12, 0.13, 0.18, 0.9))
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 32, Color(0.45, 0.47, 0.55), 2.0)
	draw_circle(Vector2.ZERO, 10.0, Color(color, glow * 0.35))
	var points := PackedVector2Array()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.75, 0.75))
	match rune:
		0: # fire: a flame triangle
			points = PackedVector2Array([Vector2(0, -9), Vector2(7, 6), Vector2(-7, 6), Vector2(0, -9)])
		1: # ice: a diamond
			points = PackedVector2Array([Vector2(0, -9), Vector2(7, 0), Vector2(0, 9), Vector2(-7, 0), Vector2(0, -9)])
		2: # storm: a bolt
			points = PackedVector2Array([Vector2(3, -9), Vector2(-4, 1), Vector2(3, 1), Vector2(-3, 9)])
		_: # earth: a square
			points = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6), Vector2(-6, -6)])
	draw_polyline(points, Color(color, 0.45 + glow * 0.55), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if lit:
		draw_circle(Vector2.ZERO, 17.0, Color(color, 0.12))
