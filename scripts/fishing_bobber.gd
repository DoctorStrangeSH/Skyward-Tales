extends Node2D

## Red-and-white float; an exclamation mark pops up on a bite.

var alert: bool = false

func _draw() -> void:
	draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 5.0, Color(0.8, 0.95, 1.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0, 0), 2.6, Color(0.95, 0.95, 0.95))
	draw_circle(Vector2(0, -1), 2.2, Color(0.9, 0.2, 0.2))
	draw_line(Vector2(0, -3), Vector2(0, -6), Color(0.2, 0.15, 0.15), 1.0)
	if alert:
		var font := UiFont.font()
		draw_string_outline(font, Vector2(-3, -10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(14), 3, Color(0, 0, 0))
		draw_string(font, Vector2(-3, -10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(14), Color(1.0, 0.9, 0.3))
