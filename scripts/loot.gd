extends Node2D
class_name WorldLoot

signal collected(item_id: String, amount: int)

var item_id: String = "health_potion"
var item_name: String = "Зелье здоровья"
var amount: int = 1

func _ready() -> void:
	add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	collected.emit(item_id, amount)
	queue_free()

func _draw() -> void:
	var color: Color = Color(0.9, 0.25, 0.3) if item_id == "health_potion" else Color(0.27, 0.6, 0.95)
	draw_rect(Rect2(-4, -4, 8, 9), Color(0.17, 0.15, 0.22))
	draw_rect(Rect2(-3, -3, 6, 7), color)
	draw_rect(Rect2(-2, -6, 4, 3), Color(0.87, 0.73, 0.44))
