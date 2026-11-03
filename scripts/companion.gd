extends "res://scripts/npc.gd"
class_name Companion

## Mira as a travelling companion (Act II). Follows the hero, throws frost
## vials at nearby enemies, patches the hero up when health runs low, and can
## still be talked to (same handler as the camp NPC). Survives region changes.

const BOLT_SCENE := preload("res://scenes/magic_bolt.tscn")
const FOLLOW_OFFSET := Vector2(-18, 8)
const ATTACK_RANGE := 160.0
const ATTACK_COOLDOWN := 2.4
const HEAL_COOLDOWN := 25.0

var hero: PlayerCharacter
var attack_ready_in: float = 1.0
var heal_ready_in: float = 0.0
var _last_position: Vector2

func _ready() -> void:
	super._ready()
	is_companion = true
	# Not a floating-prompt target: E with nothing else nearby talks to Mira.
	remove_from_group("interactables")
	_last_position = global_position

func _process(delta: float) -> void:
	super._process(delta)
	if hero == null or not is_instance_valid(hero):
		return
	var target := hero.global_position + FOLLOW_OFFSET
	var distance := global_position.distance_to(target)
	if distance > 320.0:
		global_position = target
	elif distance > 14.0:
		var speed := hero.get_move_speed() * (1.25 if distance > 60.0 else 1.0)
		global_position = global_position.move_toward(target, speed * delta)
	var moved := global_position - _last_position
	_last_position = global_position
	if visual != null:
		if moved.length_squared() > 0.01:
			visual.set_direction_vector(moved)
		visual.set_moving(true)
	attack_ready_in = maxf(0.0, attack_ready_in - delta)
	heal_ready_in = maxf(0.0, heal_ready_in - delta)
	if get_tree().paused:
		return
	if attack_ready_in <= 0.0:
		var enemy := _nearest_enemy()
		if enemy != null:
			throw_vial(enemy)
	if heal_ready_in <= 0.0 and hero.health > 0 and hero.health < hero.max_health * 0.35:
		heal_hero()

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := ATTACK_RANGE
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < best_distance:
			best_distance = d
			best = enemy
	return best

func throw_vial(enemy: Node2D) -> void:
	attack_ready_in = ATTACK_COOLDOWN
	var bolt := BOLT_SCENE.instantiate() as MagicBolt
	bolt.speed = 210.0
	bolt.setup(enemy.global_position - global_position, 6)
	bolt.configure_effect("frostbolt", 0.6, 1.2)
	get_parent().add_child(bolt)
	bolt.global_position = global_position

func heal_hero() -> void:
	heal_ready_in = HEAL_COOLDOWN
	hero.health = mini(hero.max_health, hero.health + 25)
	hero.stats_changed.emit()
	Vfx.sparkle(get_parent(), hero.global_position)
	var game := get_parent()
	if game != null and game.get("hud") != null:
		game.hud.show_message("Мира перевязывает рану: +25 HP", 2.0)
