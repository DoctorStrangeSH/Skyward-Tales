extends CharacterBody2D
class_name PlayerCharacter

signal stats_changed
signal level_up(new_level: int)

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")
const HERO_SHEET := "res://assets/sprites/characters/hero_8dir_walk.png"

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
var mana_regen_accumulator: float = 0.0
var inventory: Dictionary = {}
var equipment: Dictionary = {"weapon": "", "armor": "", "amulet": ""}

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
	# Recover mana slowly so casting remains testable during exploration.
	if mana < max_mana:
		mana_regen_accumulator += _delta * 4.0
		if mana_regen_accumulator >= 1.0:
			var recovered: int = mini(int(mana_regen_accumulator), max_mana - mana)
			mana += recovered
			mana_regen_accumulator -= float(recovered)
			stats_changed.emit()
	else:
		mana_regen_accumulator = 0.0
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var moving := direction.length_squared() > 0.01
	if moving:
		facing = direction.normalized()
	velocity = direction * move_speed
	move_and_slide()
	visual.set_direction_vector(facing)
	visual.set_moving(moving)

func take_damage(amount: int) -> void:
	health = maxi(0, health - maxi(1, amount - get_armor()))
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

func get_armor() -> int:
	return 4 if equipment.get("armor", "") == "leather_armor" else 0

func get_spell_bonus() -> int:
	return 5 if equipment.get("weapon", "") == "apprentice_staff" else 0

func equip_item(item_id: String) -> bool:
	var slot: String = ""
	var old_max_mana: int = max_mana
	match item_id:
		"apprentice_staff":
			slot = "weapon"
		"leather_armor":
			slot = "armor"
		"mana_amulet":
			slot = "amulet"
		_:
			return false
	if int(inventory.get(item_id, 0)) < 1 or equipment.get(slot, "") == item_id:
		return false
	var previous: String = str(equipment.get(slot, ""))
	inventory[item_id] = int(inventory[item_id]) - 1
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	if not previous.is_empty():
		add_item(previous)
	equipment[slot] = item_id
	if slot == "amulet":
		max_mana += 20
		mana = mini(max_mana, mana + 20)
	stats_changed.emit()
	return true

func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	stats_changed.emit()

func use_item(item_id: String) -> bool:
	if int(inventory.get(item_id, 0)) <= 0:
		return false
	match item_id:
		"health_potion":
			if health >= max_health:
				return false
			health = mini(max_health, health + 35)
		"mana_potion":
			if mana >= max_mana:
				return false
			mana = mini(max_mana, mana + 25)
		_:
			return false
	inventory[item_id] = int(inventory[item_id]) - 1
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	stats_changed.emit()
	return true
