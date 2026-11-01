extends Area2D
class_name MagicBolt

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")
const FIREBALL_SHEET := "user://SkywardTales/sprites/fireball_8dir.png"

@export var speed: float = 255.0
var direction: Vector2 = Vector2.RIGHT
var damage: int = 18
var lifetime: float = 2.0
var visual: DirectionalSprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
	visual.name = "DirectionalVisual"
	visual.configure(FIREBALL_SHEET, 4, 8, 1.5, 16.0)
	visual.set_direction_vector(direction)
	visual.set_moving(true)
	add_child(visual)

func setup(flight_direction: Vector2, spell_damage: int) -> void:
	direction = flight_direction.normalized()
	damage = spell_damage
	if visual != null:
		visual.set_direction_vector(direction)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
