extends "res://scripts/enemy.gd"
class_name Skeleton

## Ruins skeleton, a shield-bearer: it walks behind a rusty shield, and a
## blade does little to it (GUARD of the damage). It opens up for OPEN_TIME
## right after its own swing — bait the blow, step aside, punish — and while
## frozen, shocked or blinded. Spells go around the shield.

const GUARD := 0.25
const OPEN_BONUS := 1.25
const OPEN_TIME := 1.0

var open_left: float = 0.0

func _ready() -> void:
	sprite_fps = 8.0
	super._ready()
	visual.configure_chibi("skeleton", 8.0, sprite_scale)
	max_health = 40
	health = max_health
	move_speed = 40.0
	xp_reward = 24
	attack_damage = 9
	elemental_multipliers = {"fire": 1.15, "ice": 0.8, "lightning": 1.3}
	combat_feedback.set_health(health, max_health)

## The shield is up: blades glance off.
func guarding() -> bool:
	return open_left <= 0.0 and slow_time_left <= 0.0 and shock_time_left <= 0.0 and blind_time_left <= 0.0

func _physics_process(delta: float) -> void:
	var was := guarding()
	open_left = maxf(0.0, open_left - delta)
	var before := attack_cooldown
	super._physics_process(delta)
	if attack_cooldown > before + 0.2:
		# It has just swung: the shield arm is down.
		open_left = OPEN_TIME
		combat_feedback.show_reaction("ОТКРЫТ!")
	if guarding() != was:
		queue_redraw()

func take_damage(amount: int) -> void:
	if melee_hit and health > 0:
		if guarding():
			amount = maxi(1, roundi(amount * GUARD))
			combat_feedback.show_reaction("БЛОК")
			GameAudio.play("ui_tick", -2.0, -0.3)
		elif open_left > 0.0:
			amount = roundi(amount * OPEN_BONUS)
	super.take_damage(amount)

func _draw() -> void:
	super._draw()
	if guarding():
		# The shield: a pale arc in front.
		draw_arc(Vector2(0, -8), 11.0, PI * 0.15, PI * 0.85, 12, Color(0.8, 0.85, 0.95, 0.9), 2.5)
