extends Node2D
class_name IslandCrystal

## Этап 17: an island's support crystal. Its look follows the island's fate:
## "" — dim and flickering, "restore" — bright gold-blue, "take" — cracked and
## dark, "harmony" — teal, slowly singing (notes float up).

signal used

var state: String = ""
var prompt: String = "коснуться кристалла"
var _clock: float = 0.0

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("region_actor")
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 12)
	shape.shape = rect
	shape.position = Vector2(0, -4)
	body.add_child(shape)
	add_child(body)

func interact() -> void:
	used.emit()

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _color() -> Color:
	match state:
		"restore":
			return Color(1.0, 0.86, 0.45)
		"take":
			return Color(0.42, 0.3, 0.5)
		"harmony":
			return Color(0.45, 1.0, 0.85)
	return Color(0.6, 0.75, 1.0)

func _draw() -> void:
	var color := _color()
	var pulse := 0.5 + 0.5 * sin(_clock * (1.2 if state != "" else 7.0))
	if state == "":
		pulse *= 0.6 + 0.4 * float(int(_clock * 5.0) % 3 != 0)  # flickering
	# Glow on the ground.
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 34.0, Color(color, 0.12 + 0.12 * pulse))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Stone pedestal.
	draw_colored_polygon(PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(13, -10), Vector2(-13, -10)]), Color(0.42, 0.42, 0.48))
	draw_polyline(PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(13, -10), Vector2(-13, -10), Vector2(-18, 0)]), Color(0.18, 0.17, 0.22), 1.5)
	draw_line(Vector2(-13, -6), Vector2(13, -6), Color(0.55, 0.55, 0.62), 1.0)
	# The crystal, floating.
	var bob := sin(_clock * 1.6) * 2.0
	var c := Vector2(0, -34 + bob)
	var body := PackedVector2Array([c + Vector2(0, -20), c + Vector2(9, -4), c + Vector2(5, 16), c + Vector2(-5, 16), c + Vector2(-9, -4)])
	draw_circle(c, 22.0, Color(color, 0.1 + 0.15 * pulse))
	draw_colored_polygon(body, color.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(9, -4), c + Vector2(1, 4), c + Vector2(-2, -6)]), color.lightened(0.35))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.15, 0.12, 0.2), 1.5)
	if state == "take":
		draw_line(c + Vector2(-4, -10), c + Vector2(3, 2), Color(0.1, 0.05, 0.12), 1.5)
		draw_line(c + Vector2(3, 2), c + Vector2(-2, 12), Color(0.1, 0.05, 0.12), 1.5)
	if state == "harmony":
		for i in 3:
			var t := fmod(_clock * 0.4 + i / 3.0, 1.0)
			var p := c + Vector2(sin(t * 6.0 + i) * 14.0, -10.0 - t * 40.0)
			draw_circle(p, 2.2, Color(0.8, 1.0, 0.95, 1.0 - t))
			draw_line(p + Vector2(2, 0), p + Vector2(2, -6), Color(0.8, 1.0, 0.95, 1.0 - t), 1.0)
