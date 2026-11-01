extends Area2D
class_name MagicBolt

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")
const FIREBALL_SHEET := "res://assets/sprites/magic/fireball_8dir.png"

@export var speed: float = 255.0
var direction: Vector2 = Vector2.RIGHT
var damage: int = 18
var lifetime: float = 2.0
var spell_id: String = "fireball"
var slow_multiplier: float = 1.0
var slow_duration: float = 0.0
var visual: DirectionalSprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
	visual.name = "DirectionalVisual"
	visual.configure(FIREBALL_SHEET, 4, 8, 1.8, 16.0)
	visual.set_direction_vector(direction)
	visual.set_moving(true)
	if spell_id == "frostbolt":
		visual.modulate = Color(0.38, 0.82, 1.0)
	add_child(visual)

func setup(flight_direction: Vector2, spell_damage: int) -> void:
	direction = flight_direction.normalized()
	damage = spell_damage
	if visual != null:
		visual.set_direction_vector(direction)

func configure_effect(new_spell_id: String, new_slow_multiplier: float, new_slow_duration: float) -> void:
	spell_id = new_spell_id
	slow_multiplier = clampf(new_slow_multiplier, 0.1, 1.0)
	slow_duration = maxf(new_slow_duration, 0.0)
	if visual != null:
		visual.modulate = Color(0.38, 0.82, 1.0) if spell_id == "frostbolt" else Color.WHITE

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if spell_id == "frostbolt" and body.has_method("apply_slow") and slow_duration > 0.0:
			body.apply_slow(slow_multiplier, slow_duration)
		queue_free()
	elif body is StaticBody2D:
		queue_free()
