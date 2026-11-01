extends CharacterBody2D
class_name SlimeEnemy

signal defeated(xp_reward: int)

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")
const SLIME_SHEET := "user://SkywardTales/sprites/forest_slime_8dir.png"

@export var max_health: int = 32
@export var move_speed: float = 38.0
@export var xp_reward: int = 14

var health: int
var attack_cooldown: float = 0.0
var visual: DirectionalSprite

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	health = max_health
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	shape_node.shape = shape
	add_child(shape_node)
	visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
	visual.name = "DirectionalVisual"
	visual.configure(SLIME_SHEET, 4, 8, 1.5, 5.5)
	visual.offset = Vector2(0.0, -14.0)
	visual.set_direction_vector(Vector2.DOWN)
	add_child(visual)

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if not player.is_physics_processing():
		velocity = Vector2.ZERO
		visual.set_moving(false)
		return
	var offset := player.global_position - global_position
	var moving := offset.length() > 18.0
	if moving:
		var direction := offset.normalized()
		velocity = direction * move_speed
		visual.set_direction_vector(direction)
		visual.set_moving(true)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		visual.set_moving(false)
		if attack_cooldown <= 0.0 and player.has_method("take_damage"):
			player.take_damage(7)
			attack_cooldown = 1.1

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		defeated.emit(xp_reward)
		queue_free()
