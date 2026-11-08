extends Node2D
class_name RuneTablet

## The rune tablet of the Pattern Vault: reading it tells the rune order.

signal used

var prompt: String = "прочитать скрижаль"

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("region_actor")
	z_index = 0

func interact() -> void:
	used.emit()

func _draw() -> void:
	draw_rect(Rect2(-12, -26, 24, 26), Color(0.32, 0.33, 0.4))
	draw_rect(Rect2(-12, -26, 24, 26), Color(0.18, 0.18, 0.24), false, 2.0)
	draw_rect(Rect2(-14, -2, 28, 4), Color(0.22, 0.22, 0.28))
	var colors := [Color(1.0, 0.5, 0.2), Color(0.5, 0.85, 1.0), Color(0.75, 0.55, 1.0), Color(0.55, 0.9, 0.4)]
	for i in 4:
		draw_circle(Vector2(-6 + (i % 2) * 12, -19 + (i / 2) * 10), 3.0, colors[i])
