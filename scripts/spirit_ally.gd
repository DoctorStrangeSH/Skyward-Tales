extends Node2D
class_name SpiritAlly

## Summoner (skill "Дух-волк"): a spectral wolf that fights beside the hero
## for a while. It runs to the nearest foe and bites; each bite carries the
## element of the chosen spell (fire burns, ice chills, lightning shocks),
## so spirits set up combos for the hero. Spirits cannot be hurt.

const DIRECTIONAL_SPRITE_SCRIPT := preload("res://scripts/directional_sprite.gd")
const SHEET := "res://assets/sprites/enemies/forest_wolf_8dir.png"
const SPEED := 150.0
const BITE_RANGE := 18.0
const SEEK_RANGE := 220.0
const BITE_COOLDOWN := 0.8

var game: SkywardGame
var damage: int = 8
var element: String = "fire"
var life: float = 20.0
var visual: DirectionalSprite
var _bite_in: float = 0.3
var _clock: float = 0.0

func _ready() -> void:
	visual = DIRECTIONAL_SPRITE_SCRIPT.new() as DirectionalSprite
	visual.configure(SHEET, 4, 8, 1.0, 10.0)
	visual.offset = Vector2(0, -14)
	visual.set_direction_vector(Vector2.DOWN)
	var tint: Color = ElementalCombos.ELEMENT_COLORS.get(element, Color(0.7, 0.85, 1.0))
	# Spectral glow: brighter than life, slightly see-through.
	visual.modulate = Color(0.6 + tint.r * 1.2, 0.6 + tint.g * 1.2, 0.6 + tint.b * 1.2, 0.85)
	add_child(visual)
	z_index = 2
	Vfx.burst(game, global_position, [Color(1, 1, 1), tint, Color(tint, 0)], 16, 70.0, 0.4)

func _nearest() -> SlimeEnemy:
	var best: SlimeEnemy = null
	var best_d := SEEK_RANGE
	for enemy in game._living_enemies():
		var d := global_position.distance_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best

func _physics_process(delta: float) -> void:
	_clock += delta
	life -= delta
	if life <= 0.0:
		Vfx.burst(game, global_position, [Color(1, 1, 1, 0.8), Color(0.7, 0.85, 1.0, 0)], 10, 50.0, 0.3)
		queue_free()
		return
	_bite_in = maxf(0.0, _bite_in - delta)
	var target := _nearest()
	var goal: Vector2
	if target != null:
		goal = target.global_position
	else:
		# No foes: trot beside the hero.
		goal = game.player.global_position + Vector2(-22, 10)
	var to := goal - global_position
	var stop := BITE_RANGE * 0.8 if target != null else 14.0
	if to.length() > stop:
		global_position += to.normalized() * minf(SPEED * delta, to.length() - stop)
		visual.set_direction_vector(to)
		visual.set_moving(true)
	else:
		visual.set_moving(false)
	if target != null and to.length() <= BITE_RANGE and _bite_in <= 0.0:
		_bite(target)
	# A spectral shimmer.
	visual.self_modulate.a = 0.75 + 0.2 * sin(_clock * 6.0)
	queue_redraw()

func _draw() -> void:
	var tint: Color = ElementalCombos.ELEMENT_COLORS.get(element, Color(0.7, 0.85, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 12.0 + sin(_clock * 5.0), Color(tint, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 3:
		var a := _clock * 2.5 + i * 2.1
		draw_circle(Vector2(cos(a) * 10.0, -10.0 + sin(a) * 6.0), 1.2, Color(1, 1, 1, 0.8))

func _bite(enemy: SlimeEnemy) -> void:
	_bite_in = BITE_COOLDOWN
	enemy.take_elemental_damage(damage, element)
	if not is_instance_valid(enemy) or enemy.health <= 0:
		return
	match element:
		"fire":
			enemy.apply_burning(2 + game.player.level / 4, 1.5)
		"ice":
			enemy.apply_slow(0.6, 1.2)
		"lightning":
			enemy.apply_shock(2.0)
	Vfx.sparkle(game, enemy.global_position)
