extends CharacterBody2D
class_name PlayerCharacter

signal stats_changed
signal level_up(new_level: int)

@export var move_speed: float = 92.0
@export var max_health: int = 100
@export var max_mana: int = 60

var health: int = 100
var mana: int = 60
var level: int = 1
var experience: int = 0
var experience_to_next: int = 40
var gold: int = 0
var facing: Vector2 = Vector2.DOWN

func _ready() -> void:
	add_to_group("player")
	health = max_health
	mana = max_mana
	queue_redraw()

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length_squared() > 0.01:
		facing = direction.normalized()
	velocity = direction * move_speed
	move_and_slide()
	queue_redraw()

func take_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	stats_changed.emit()

func spend_mana(amount: int) -> bool:
	if mana < amount:
		return false
	mana -= amount
	stats_changed.emit()
	return true

func add_experience(amount: int) -> void:
	experience += amount
	while experience >= experience_to_next:
		experience -= experience_to_next
		level += 1
		experience_to_next = int(round(float(experience_to_next) * 1.35))
		max_health += 10
		max_mana += 5
		health = max_health
		mana = max_mana
		level_up.emit(level)
	stats_changed.emit()

func add_gold(amount: int) -> void:
	gold += amount
	stats_changed.emit()

func _draw() -> void:
	# Tiny hand-drawn pixel adventurer; all dimensions are integer multiples.
	draw_rect(Rect2(-6, 5, 12, 5), Color(0.10, 0.12, 0.16, 0.45))
	draw_rect(Rect2(-5, -2, 10, 11), Color(0.20, 0.27, 0.57))
	draw_rect(Rect2(-4, 0, 8, 8), Color(0.34, 0.43, 0.78))
	draw_rect(Rect2(-4, -9, 8, 8), Color(0.91, 0.70, 0.50))
	draw_rect(Rect2(-5, -10, 10, 4), Color(0.22, 0.15, 0.12))
	draw_rect(Rect2(-3, -4, 2, 2), Color(0.12, 0.10, 0.12))
	draw_rect(Rect2(2, -4, 2, 2), Color(0.12, 0.10, 0.12))
	draw_rect(Rect2(-5, 7, 4, 3), Color(0.26, 0.18, 0.16))
	draw_rect(Rect2(1, 7, 4, 3), Color(0.26, 0.18, 0.16))
	# A small colored pixel marks the direction the character is facing.
	var mark := facing * 7.0
	draw_rect(Rect2(mark.x - 1.0, mark.y - 1.0, 3, 3), Color(0.45, 0.88, 1.0))
