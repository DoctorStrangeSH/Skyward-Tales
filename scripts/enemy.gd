extends CharacterBody2D
class_name SlimeEnemy

signal defeated(xp_reward: int)

@export var max_health: int = 32
@export var move_speed: float = 38.0
@export var xp_reward: int = 14

var health: int
var attack_cooldown: float = 0.0

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
	queue_redraw()

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	# Pause enemy AI while the player is reading a dialogue.
	if not player.is_physics_processing():
		velocity = Vector2.ZERO
		return
	var offset := player.global_position - global_position
	if offset.length() > 18.0:
		velocity = offset.normalized() * move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		if attack_cooldown <= 0.0 and player.has_method("take_damage"):
			player.take_damage(7)
			attack_cooldown = 1.1
	queue_redraw()

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		defeated.emit(xp_reward)
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-8, -4, 16, 11), Color(0.10, 0.18, 0.18, 0.35))
	draw_rect(Rect2(-7, -5, 14, 10), Color(0.30, 0.67, 0.48))
	draw_rect(Rect2(-5, -8, 10, 5), Color(0.40, 0.80, 0.56))
	draw_rect(Rect2(-4, -3, 2, 3), Color(0.08, 0.12, 0.11))
	draw_rect(Rect2(2, -3, 2, 3), Color(0.08, 0.12, 0.11))
	draw_rect(Rect2(-2, 1, 4, 1), Color(0.13, 0.23, 0.17))
