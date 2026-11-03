extends Area2D
class_name EnemyMagicOrb

var direction: Vector2 = Vector2.RIGHT
var speed: float = 150.0
var damage: int = 9
var lifetime: float = 3.0
var consumed: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 5 # player 1, world 4; never hit another enemy
	monitoring = true
	body_entered.connect(_on_body_entered)
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(0.46, 0.86, 0.62))
	draw_circle(Vector2(-1, -1), 2.0, Color(0.87, 1.0, 0.79))

func setup(travel_direction: Vector2, orb_damage: int = 9) -> void:
	direction = travel_direction.normalized() if travel_direction.length_squared() > 0.0001 else Vector2.RIGHT
	damage = orb_damage

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if consumed:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		consumed = true
		body.take_damage(damage)
		queue_free()
	elif body is StaticBody2D:
		consumed = true
		queue_free()
