extends Node2D
class_name DigSpot

## The X from a treasure map, drawn on the ground. E — dig.

signal dug(spot: DigSpot)

var _clock := 0.0

func _ready() -> void:
	add_to_group("interactables")
	z_index = -45

func interact() -> void:
	dug.emit(self)

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.6 + 0.4 * sin(_clock * 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, 12.0, Color(0.35, 0.22, 0.12, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var red := Color(0.85, 0.15, 0.12, pulse)
	draw_line(Vector2(-6, -4), Vector2(6, 4), red, 2.5)
	draw_line(Vector2(-6, 4), Vector2(6, -4), red, 2.5)
