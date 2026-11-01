extends Area2D
class_name MagicBolt

@export var speed: float = 255.0
var direction: Vector2 = Vector2.RIGHT
var damage: int = 18
var lifetime: float = 2.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func setup(flight_direction: Vector2, spell_damage: int) -> void:
	direction = flight_direction.normalized()
	damage = spell_damage

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

func _draw() -> void:
	draw_rect(Rect2(-5, -3, 10, 6), Color(0.20, 0.67, 1.0))
	draw_rect(Rect2(-2, -5, 5, 10), Color(0.42, 0.87, 1.0))
	draw_rect(Rect2(-1, -2, 3, 3), Color(0.92, 0.98, 1.0))
