extends Node2D
class_name RegionGate

signal travel_requested(target_region: String, arrival_position: Vector2)

@export var target_region: String = "moonlit_grove"
@export var display_name: String = "Тропа в Зачарованный лес"
@export var arrival_position: Vector2 = Vector2(140, 430)

func _ready() -> void:
	add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	travel_requested.emit(target_region, arrival_position)

func _draw() -> void:
	draw_rect(Rect2(-9, -13, 18, 26), Color(0.12, 0.10, 0.18, 0.85))
	draw_rect(Rect2(-6, -10, 12, 20), Color(0.24, 0.42, 0.36))
	draw_rect(Rect2(-3, -8, 6, 16), Color(0.46, 0.78, 0.60))
	draw_rect(Rect2(-1, -6, 2, 12), Color(0.82, 0.92, 0.67))
	draw_rect(Rect2(-12, 10, 24, 3), Color(0.22, 0.17, 0.12))
