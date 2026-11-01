extends Node2D
class_name WorldNpc

signal interacted(source: Node2D)

@export var display_name: String = "Путник"

func _ready() -> void:
	add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	interacted.emit(self)

func _draw() -> void:
	draw_rect(Rect2(-7, 5, 14, 4), Color(0.10, 0.12, 0.15, 0.4))
	draw_rect(Rect2(-5, -2, 10, 10), Color(0.53, 0.36, 0.66))
	draw_rect(Rect2(-4, -9, 8, 8), Color(0.84, 0.65, 0.48))
	draw_rect(Rect2(-5, -11, 10, 4), Color(0.77, 0.78, 0.80))
	draw_rect(Rect2(-6, -7, 3, 5), Color(0.77, 0.78, 0.80))
	draw_rect(Rect2(3, -7, 3, 5), Color(0.77, 0.78, 0.80))
	draw_rect(Rect2(-3, -4, 2, 2), Color(0.15, 0.12, 0.14))
	draw_rect(Rect2(2, -4, 2, 2), Color(0.15, 0.12, 0.14))
	draw_rect(Rect2(8, -16, 7, 7), Color(0.96, 0.77, 0.25))
	draw_rect(Rect2(10, -14, 3, 3), Color(0.98, 0.91, 0.62))
