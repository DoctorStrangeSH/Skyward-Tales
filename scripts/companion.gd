extends "res://scripts/npc.gd"
class_name Companion

## A travelling companion: Mira (frost vials and first aid), Toren (arrows),
## Raina (thunder pistol). Owner's list №18–19:
##   • stays close to the hero and fights by tactics (Crew.STANCES):
##     «Защищать» — the hero's target, or whoever attacks the hero or her;
##     «Нападать» — anything near; «В стороне» — never starts a fight;
##   • has health: foes she shoots may turn on her; at 0 she is spent and
##     rests 15 s, then gets back up;
##   • level, gear and her own skills come from Crew (scripts/crew.gd).

const BOLT_SCENE := preload("res://scenes/magic_bolt.tscn")
const FOLLOW_OFFSET := Vector2(-18, 8)
const ATTACK_RANGE := 160.0
const ATTACK_COOLDOWN := 2.4
const HEAL_COOLDOWN := 25.0
## How far from the hero she goes for a target.
const LEASH := 190.0
const DOWN_TIME := 15.0

var hero: PlayerCharacter
var role: String = "mira"
var follow_offset: Vector2 = FOLLOW_OFFSET
var heal_amount: int = 25
var heal_cooldown: float = HEAL_COOLDOWN
var attack_ready_in: float = 1.0
var heal_ready_in: float = 0.0

# From Crew.apply().
var crew_level: int = 1
var damage_bonus: int = 0
var damage_mult: float = 1.0
var crit_chance: float = 0.05
var cooldown_mult: float = 1.0
var max_health: int = 60
var health: int = 60
var armor: int = 0
var regen: int = 0
var ranks: Dictionary = {}
var stance: String = "defend"
## Seconds left resting after being knocked out.
var down_left: float = 0.0

var _last_position: Vector2
var _shots: int = 0
var _special_ready_in: float = 4.0
var _rally_ready_in: float = 0.0
var _breath_ready_in: float = 0.0
var _calm_time: float = 0.0
var _regen_clock: float = 0.0
var _hurt_flash: float = 0.0
var _heal_acc: float = 0.0

func _ready() -> void:
	super._ready()
	is_companion = true
	add_to_group("companions")
	# Not a floating-prompt target: E with nothing else nearby talks to her.
	remove_from_group("interactables")
	_last_position = global_position

func _game() -> Node:
	return get_parent()

func _process(delta: float) -> void:
	super._process(delta)
	if hero == null or not is_instance_valid(hero):
		return
	_follow(delta)
	attack_ready_in = maxf(0.0, attack_ready_in - delta)
	heal_ready_in = maxf(0.0, heal_ready_in - delta)
	_special_ready_in = maxf(0.0, _special_ready_in - delta)
	_rally_ready_in = maxf(0.0, _rally_ready_in - delta)
	_breath_ready_in = maxf(0.0, _breath_ready_in - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	if get_tree().paused:
		return
	if down_left > 0.0:
		down_left -= delta
		if down_left <= 0.0:
			health = max_health / 2
			_say_hud("%s поднимается на ноги." % _short_name())
		queue_redraw()
		return
	_recover(delta)
	var target := pick_target()
	if target != null and attack_ready_in <= 0.0:
		throw_vial(target)
	if role == "mira":
		_mira_support()
	if role == "captain" and ranks.has("rally") and _rally_ready_in <= 0.0 and target != null:
		_rally_ready_in = 30.0
		hero.add_buff("power", 0.15, 6.0, "На абордаж! +15% урона")
		_say_hud("Рейна: «На абордаж!» — +15% к урону на 6 с.")

func _follow(delta: float) -> void:
	var target := hero.global_position + follow_offset
	var distance := global_position.distance_to(target)
	var speed := hero.get_move_speed() * (1.25 if distance > 60.0 else 1.0)
	if down_left > 0.0:
		speed *= 0.5
	if distance > 320.0:
		global_position = target
	elif distance > 14.0:
		global_position = global_position.move_toward(target, speed * delta)
	var moved := global_position - _last_position
	_last_position = global_position
	if visual != null:
		var walking := moved.length_squared() > 0.01
		if walking:
			visual.set_direction_vector(moved)
		visual.set_moving(walking or visual.chibi_id.is_empty())
		visual.modulate = Color(1, 0.55, 0.55) if _hurt_flash > 0.0 else (Color(0.6, 0.6, 0.7, 0.8) if down_left > 0.0 else Color.WHITE)

## Out of a fight she catches her breath; gear may heal too.
func _recover(delta: float) -> void:
	if health >= max_health:
		_calm_time += delta
		return
	_calm_time = 0.0 if _in_fight() else _calm_time + delta
	if _calm_time > 4.0:
		_heal_acc += max_health * 0.05 * delta
		if _heal_acc >= 1.0:
			health = mini(max_health, health + int(_heal_acc))
			_heal_acc -= float(int(_heal_acc))
			queue_redraw()
	if regen > 0:
		_regen_clock += delta
		if _regen_clock >= 5.0:
			_regen_clock = 0.0
			health = mini(max_health, health + regen)

func _in_fight() -> bool:
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		if enemy != null and _is_attacking_us(enemy):
			return true
	return false

# --- Choosing whom to shoot ----------------------------------------------------

## The hero's target, then foes attacking the hero or her; «Нападать» also
## takes anything near. Never a foe too far from the hero.
func pick_target() -> Node2D:
	if stance == "passive":
		return null
	var game := _game()
	var marked: Variant = game.get("hero_target") if game != null else null
	if is_instance_valid(marked) and marked is Node2D and _usable(marked) and game.call("hero_target_fresh"):
		return marked
	var best: Node2D = null
	var best_distance := ATTACK_RANGE
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		if enemy == null or not _usable(enemy):
			continue
		if stance != "attack" and not _is_attacking_us(enemy):
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < best_distance:
			best_distance = d
			best = enemy
	return best

func _usable(enemy: Node2D) -> bool:
	if enemy.is_queued_for_deletion() or ("health" in enemy and int(enemy.get("health")) <= 0):
		return false
	return global_position.distance_to(enemy.global_position) <= ATTACK_RANGE and hero.global_position.distance_to(enemy.global_position) <= LEASH

## A foe that chases the hero (close by) or her.
func _is_attacking_us(enemy: Node2D) -> bool:
	if "taunt" in enemy and enemy.get("taunt") == self:
		return true
	if "brain_state" in enemy and int(enemy.get("brain_state")) == SlimeEnemy.BrainState.CHASE:
		return enemy.global_position.distance_to(hero.global_position) <= 150.0
	return false

# --- Attacks -------------------------------------------------------------------

func _damage(base: int) -> int:
	var amount := roundi(float(base + damage_bonus) * damage_mult)
	if randf() < crit_chance:
		amount *= 2
	return maxi(1, amount)

func _cooldown(base: float) -> float:
	return base * cooldown_mult

func throw_vial(enemy: Node2D) -> void:
	if role == "hunter":
		_shoot_arrow(enemy)
		return
	if role == "captain":
		_fire_pistol(enemy)
		return
	attack_ready_in = _cooldown(ATTACK_COOLDOWN)
	if visual != null:
		visual.set_direction_vector(enemy.global_position - global_position)
		visual.play_named("throw", 0.5)
	var bolt := BOLT_SCENE.instantiate() as MagicBolt
	bolt.speed = 210.0
	bolt.shooter = self
	bolt.setup(enemy.global_position - global_position, _damage(6))
	bolt.configure_effect("frostbolt", 0.6, 1.2 + 0.3 * float(ranks.get("frost_vial", 0)))
	get_parent().add_child(bolt)
	bolt.global_position = global_position
	if ranks.has("frost_cloud") and _special_ready_in <= 0.0:
		_special_ready_in = 12.0
		for candidate in get_tree().get_nodes_in_group("enemies"):
			var other := candidate as Node2D
			if other != null and other.global_position.distance_to(enemy.global_position) <= 60.0 and other.has_method("apply_slow"):
				other.apply_slow(0.45, 3.0)
		Vfx.sparkle(get_parent(), enemy.global_position)

func _shoot_arrow(enemy: Node2D) -> void:
	attack_ready_in = _cooldown(1.8)
	var game := get_parent() as SkywardGame
	if game == null:
		return
	_shots += 1
	var every := 0
	match int(ranks.get("hunter_mark", 0)):
		1:
			every = 3
		2:
			every = 2
	var damage := _damage(9 + hero.level)
	if every > 0 and _shots % every == 0:
		damage *= 2
	var directions: Array[Vector2] = [(enemy.global_position - global_position).normalized()]
	if ranks.has("volley") and _special_ready_in <= 0.0:
		_special_ready_in = 10.0
		directions.append(directions[0].rotated(0.22))
		directions.append(directions[0].rotated(-0.22))
	for direction in directions:
		var arrow := Arrow.new()
		arrow.shooter = self
		arrow.setup(game, direction, damage, 0, false)
		game.add_child(arrow)
		arrow.global_position = global_position + Vector2(0, -8)
	if ranks.has("net") and _shots % 4 == 1 and enemy.has_method("apply_slow"):
		enemy.apply_slow(0.05, 2.5)
		_say_hud("Торен накидывает сеть!")
	if visual != null:
		visual.set_direction_vector(enemy.global_position - global_position)

func _fire_pistol(enemy: Node2D) -> void:
	attack_ready_in = _cooldown(2.6)
	var bolt := BOLT_SCENE.instantiate() as MagicBolt
	bolt.speed = 260.0
	bolt.shooter = self
	bolt.setup(enemy.global_position - global_position, _damage(12 + hero.level))
	bolt.configure_effect("chain_lightning", 1.0, 0.0)
	var chains := int(ranks.get("chain_shot", 0))
	if chains > 0:
		bolt.chain_targets = chains
		bolt.chain_radius = 90.0
	get_parent().add_child(bolt)
	bolt.global_position = global_position + Vector2(0, -8)
	if ranks.has("stun_shot") and _special_ready_in <= 0.0 and enemy.has_method("apply_shock"):
		_special_ready_in = 10.0
		enemy.apply_shock(1.5)
	if visual != null:
		visual.set_direction_vector(enemy.global_position - global_position)
	GameAudio.play("cast_lightning", -12.0, 0.1)

func _mira_support() -> void:
	if hero.health <= 0:
		return
	if ranks.has("second_breath") and _breath_ready_in <= 0.0 and hero.health < hero.max_health * 0.15:
		_breath_ready_in = 90.0
		var amount := roundi(hero.max_health * 0.4)
		hero.health = mini(hero.max_health, hero.health + amount)
		hero.stats_changed.emit()
		Vfx.sparkle(get_parent(), hero.global_position)
		_say_hud("Мира: «Дыши! Слышишь? Дыши!» +%d HP" % amount)
		return
	if heal_ready_in <= 0.0 and hero.health < hero.max_health * 0.35:
		heal_hero()

func heal_hero() -> void:
	heal_ready_in = heal_cooldown
	hero.health = mini(hero.max_health, hero.health + heal_amount)
	hero.stats_changed.emit()
	Vfx.sparkle(get_parent(), hero.global_position)
	_say_hud("Мира перевязывает рану: +%d HP" % heal_amount)

# --- Health ----------------------------------------------------------------------

func take_damage(amount: int, _source: Node = null) -> void:
	if down_left > 0.0:
		return
	health = maxi(0, health - maxi(1, amount - armor))
	_hurt_flash = 0.15
	_calm_time = 0.0
	if health <= 0:
		down_left = DOWN_TIME
		# Foes lose interest in her.
		for candidate in get_tree().get_nodes_in_group("enemies"):
			if "taunt" in candidate and candidate.get("taunt") == self:
				candidate.set("taunt", null)
		_say_hud("%s без сил — отдохнёт %d с." % [_short_name(), int(DOWN_TIME)])
	queue_redraw()

func is_down() -> bool:
	return down_left > 0.0

func _short_name() -> String:
	return display_name.get_slice(",", 0)

func _say_hud(text: String) -> void:
	var game := get_parent()
	if game != null and game.get("hud") != null:
		game.hud.show_message(text, 2.0)

func _draw() -> void:
	super._draw()
	if health >= max_health and down_left <= 0.0:
		return
	var width := 22.0
	var origin := Vector2(-width / 2.0, -34)
	draw_rect(Rect2(origin - Vector2(1, 1), Vector2(width + 2, 4)), Color(0, 0, 0, 0.7))
	var share := float(health) / float(maxi(1, max_health))
	draw_rect(Rect2(origin, Vector2(width * share, 2)), Color(0.45, 0.9, 0.5) if down_left <= 0.0 else Color(0.5, 0.5, 0.55))
