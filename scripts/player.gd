extends CharacterBody2D
class_name PlayerCharacter

signal stats_changed
signal level_up(new_level: int)

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")
const HERO_SHEET := "user://SkywardTales/sprites/hero_8dir_walk.png"

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
var visual: DirectionalSprite

func _ready() -> void:
	add_to_group("player")
	health = max_health
	mana = max_mana
	visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
	visual.name = "DirectionalVisual"
	visual.configure(HERO_SHEET, 4, 8, 1.8, 8.0)
	visual.offset = Vector2(0.0, -14.0)
	visual.set_direction_vector(facing)
	add_child(visual)

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var moving := direction.length_squared() > 0.01
	if moving:
		facing = direction.normalized()
	velocity = direction * move_speed
	move_and_slide()
	visual.set_direction_vector(facing)
	visual.set_moving(moving)

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
