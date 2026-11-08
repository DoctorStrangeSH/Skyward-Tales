extends Node2D
class_name TrackMark

## Legend hunt: a trail sign (claw marks, tufts of fur) the hero examines.

signal used(mark: TrackMark)

var index: int = 0
var _clock: float = 0.0

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("region_actor")
	z_index = 3

func interact() -> void:
	used.emit(self)

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.3 + 0.2 * sin(_clock * 3.0)
	draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.85, 0.35, pulse * 0.45))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 28, Color(1.0, 0.9, 0.5, 0.4 + pulse), 1.5)
	for i in 3:
		var x := -5.0 + i * 5.0
		draw_line(Vector2(x - 2, -7), Vector2(x + 2, 6), Color(0.35, 0.2, 0.12, 0.9), 2.0)
	# Paw prints leading away.
	for i in 3:
		var p := Vector2(10 + i * 7, 4 - i * 4)
		draw_circle(p, 2.2, Color(0.3, 0.2, 0.12, 0.75))
		for j in 3:
			draw_circle(p + Vector2(-2 + j * 2, -3), 0.9, Color(0.3, 0.2, 0.12, 0.75))
