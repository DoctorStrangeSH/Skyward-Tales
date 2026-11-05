extends Node2D
class_name Mercenary

## Kai, a sellsword hired at the tavern (level 2) for one in-game day. He
## follows the hero across lands and cuts down the nearest foe. He cannot be
## hurt; he leaves when the contract runs out.

const SPEED := 120.0
const SWING_RANGE := 20.0
const SEEK_RANGE := 180.0
const SWING_COOLDOWN := 0.9

var game: SkywardGame
var visual: DirectionalSprite
var _swing_in: float = 0.5

func _ready() -> void:
	visual = preload("res://scripts/directional_sprite.gd").new() as DirectionalSprite
	visual.configure_chibi("mercenary", 8.0, 1.0)
	visual.offset = Vector2(0, -14)
	add_child(visual)

func damage() -> int:
	return 6 + game.player.level * 2

func _nearest() -> SlimeEnemy:
	var best: SlimeEnemy = null
	var best_d := SEEK_RANGE
	for enemy in game._living_enemies():
		if enemy.global_position.distance_to(game.player.global_position) > SEEK_RANGE + 40.0:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best

func _physics_process(delta: float) -> void:
	if not game.world_state.has("mercenary"):
		game.hud.show_message("Наёмник Кай: «Контракт окончен. Удачи!»", 3.0)
		queue_free()
		return
	_swing_in = maxf(0.0, _swing_in - delta)
	var target := _nearest()
	var goal := target.global_position if target != null else game.player.global_position + Vector2(-24, 12)
	var to := goal - global_position
	var stop := SWING_RANGE * 0.8 if target != null else 16.0
	if to.length() > 260.0 and target == null:
		global_position = goal
	elif to.length() > stop:
		global_position += to.normalized() * minf(SPEED * delta, to.length() - stop)
		visual.set_direction_vector(to)
		visual.set_moving(true)
	else:
		visual.set_moving(false)
	if target != null and to.length() <= SWING_RANGE and _swing_in <= 0.0:
		_swing_in = SWING_COOLDOWN
		visual.play_named("slash1", 0.3)
		target.take_damage(damage())
		if is_instance_valid(target):
			target.apply_knockback(to.normalized(), 70.0)
