extends Node2D
class_name TreasureChest

signal opened(chest_id: String, gold: int, item_id: String, amount: int)

var chest_id: String = ""
var gold_reward: int = 0
var item_reward: String = ""
var item_amount: int = 0
var is_opened: bool = false

func _ready() -> void:
	add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	if is_opened or is_queued_for_deletion():
		return
	is_opened = true
	opened.emit(chest_id, gold_reward, item_reward, item_amount)
	queue_redraw()
	remove_from_group("interactables")

func _draw() -> void:
	var wood := Color(0.34, 0.22, 0.13) if is_opened else Color(0.44, 0.27, 0.14)
	draw_rect(Rect2(-10, -7, 20, 15), Color(0.15, 0.13, 0.16))
	draw_rect(Rect2(-8, -5, 16, 11), wood)
	draw_rect(Rect2(-8, -5, 16, 3), Color(0.67, 0.44, 0.20))
	draw_rect(Rect2(-2, -2, 4, 5), Color(0.14, 0.14, 0.15) if is_opened else Color(0.98, 0.79, 0.38))
	if is_opened:
		draw_rect(Rect2(-8, -12, 16, 4), Color(0.30, 0.19, 0.11))
