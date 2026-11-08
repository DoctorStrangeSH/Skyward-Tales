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
## "mira" — frost vials and first aid; "hunter" (Toren) — arrows that hit
## hard; "captain" (Raina) — thunder pistol shots (Этап 17).
var role: String = "mira"
var follow_offset: Vector2 = FOLLOW_OFFSET
## Mira patches up more (and sooner) after her mother's logbook is found.
var heal_amount: int = 25
var heal_cooldown: float = HEAL_COOLDOWN
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
	var target := hero.global_position + follow_offset
	var distance := global_position.distance_to(target)
	if distance > 320.0:
		global_position = target
	elif distance > 14.0:
		var speed := hero.get_move_speed() * (1.25 if distance > 60.0 else 1.0)
		global_position = global_position.move_toward(target, speed * delta)
	var moved := global_position - _last_position
	_last_position = global_position
	if visual != null:
		var walking := moved.length_squared() > 0.01
		if walking:
			visual.set_direction_vector(moved)
		visual.set_moving(walking or visual.chibi_id.is_empty())
	attack_ready_in = maxf(0.0, attack_ready_in - delta)
	heal_ready_in = maxf(0.0, heal_ready_in - delta)
	if get_tree().paused:
		return
	if attack_ready_in <= 0.0:
		var enemy := _nearest_enemy()
		if enemy != null:
			throw_vial(enemy)
	if role == "mira" and heal_ready_in <= 0.0 and hero.health > 0 and hero.health < hero.max_health * 0.35:
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
	if role == "hunter":
		_shoot_arrow(enemy)
		return
	if role == "captain":
		_fire_pistol(enemy)
		return
	attack_ready_in = ATTACK_COOLDOWN
	if visual != null:
		visual.set_direction_vector(enemy.global_position - global_position)
		visual.play_named("throw", 0.5)
	var bolt := BOLT_SCENE.instantiate() as MagicBolt
	bolt.speed = 210.0
	bolt.setup(enemy.global_position - global_position, 6)
	bolt.configure_effect("frostbolt", 0.6, 1.2)
	get_parent().add_child(bolt)
	bolt.global_position = global_position

func _shoot_arrow(enemy: Node2D) -> void:
	attack_ready_in = 1.8
	var game := get_parent() as SkywardGame
	if game == null:
		return
	var arrow := Arrow.new()
	arrow.setup(game, (enemy.global_position - global_position).normalized(), 9 + hero.level, 0, false)
	game.add_child(arrow)
	arrow.global_position = global_position + Vector2(0, -8)
	if visual != null:
		visual.set_direction_vector(enemy.global_position - global_position)

func _fire_pistol(enemy: Node2D) -> void:
	attack_ready_in = 2.6
	var bolt := BOLT_SCENE.instantiate() as MagicBolt
	bolt.speed = 260.0
	bolt.setup(enemy.global_position - global_position, 12 + hero.level)
	bolt.configure_effect("chain_lightning", 1.0, 0.0)
	get_parent().add_child(bolt)
	bolt.global_position = global_position + Vector2(0, -8)
	if visual != null:
		visual.set_direction_vector(enemy.global_position - global_position)
	GameAudio.play("cast_lightning", -12.0, 0.1)

func heal_hero() -> void:
	heal_ready_in = heal_cooldown
	hero.health = mini(hero.max_health, hero.health + heal_amount)
	hero.stats_changed.emit()
	Vfx.sparkle(get_parent(), hero.global_position)
	var game := get_parent()
	if game != null and game.get("hud") != null:
		game.hud.show_message("Мира перевязывает рану: +%d HP" % heal_amount, 2.0)
