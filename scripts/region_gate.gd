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
	# The gate is styled after the region it stands in.
	WorldArt.draw_prop(self, "props/gate_day.png" if target_region == "moonlit_grove" else "props/gate_night.png")
