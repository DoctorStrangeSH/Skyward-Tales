extends Node2D
class_name WorldCollectible

signal interacted(source: Node2D)

@export var item_id: String = "moonleaf"
@export var display_name: String = "Лунный лист"

func _ready() -> void:
	add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	interacted.emit(self)

func _draw() -> void:
	draw_rect(Rect2(-2, -1, 4, 11), Color(0.20, 0.34, 0.17))
	draw_rect(Rect2(-8, -7, 7, 7), Color(0.47, 0.78, 0.46))
	draw_rect(Rect2(1, -10, 7, 7), Color(0.60, 0.88, 0.55))
	draw_rect(Rect2(-5, -5, 4, 3), Color(0.76, 0.93, 0.63))
	draw_rect(Rect2(3, -8, 3, 3), Color(0.82, 0.96, 0.67))
