extends Node2D
class_name WorldNpc

signal interacted(source: Node2D)

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")

@export var display_name: String = "Путник"
@export var outfit_color: Color = Color(0.53, 0.36, 0.66)
## Selects assets/sprites/npcs/<npc_id>.png; unknown ids fall back to a drawn figure.
@export var npc_id: String = ""

var visual: DirectionalSprite

func _ready() -> void:
	add_to_group("interactables")
	var sheet := "res://assets/sprites/npcs/%s.png" % npc_id
	if not npc_id.is_empty() and ResourceLoader.exists(sheet):
		visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
		visual.configure(sheet, 4, 8, 1.0, 2.5)
		visual.offset = Vector2(0.0, -14.0)
		visual.set_direction_vector(Vector2.DOWN)
		visual.set_moving(true)  # gentle idle breathing
		add_child(visual)
	queue_redraw()

func interact() -> void:
	interacted.emit(self)

func _draw() -> void:
	if visual != null:
		return
	draw_rect(Rect2(-7, 5, 14, 4), Color(0.10, 0.12, 0.15, 0.4))
	draw_rect(Rect2(-5, -2, 10, 10), outfit_color)
	draw_rect(Rect2(-4, -9, 8, 8), Color(0.84, 0.65, 0.48))
	draw_rect(Rect2(-5, -11, 10, 4), Color(0.77, 0.78, 0.80))
