extends Node2D
class_name CrystalTotem

## Summoner (skill "Кристальный тотем"): a floating crystal that zaps the
## nearest foe with the chosen spell's element. Its zaps count as that spell
## for reactions, so the totem and the hero set off combos together.

const RANGE := 150.0
const INTERVAL := 0.9
const SPELL_OF := {"fire": "fireball", "ice": "frostbolt", "lightning": "chain_lightning"}

var game: SkywardGame
var damage: int = 7
var element: String = "fire"
var life: float = 14.0
var _shot_in: float = 0.4
var _clock: float = 0.0
var _beam_to: Vector2 = Vector2.ZERO
var _beam_left: float = 0.0

func _physics_process(delta: float) -> void:
	_clock += delta
	life -= delta
	_beam_left = maxf(0.0, _beam_left - delta)
	if life <= 0.0:
		Vfx.burst(game, global_position + Vector2(0, -16), [Color(1, 1, 1), _color(), Color(_color(), 0)], 14, 60.0, 0.4)
		queue_free()
		return
	_shot_in -= delta
	if _shot_in <= 0.0:
		_shot_in = INTERVAL
		_zap()
	queue_redraw()

func _color() -> Color:
	return ElementalCombos.ELEMENT_COLORS.get(element, Color.WHITE)

func _zap() -> void:
	var best: SlimeEnemy = null
	var best_d := RANGE
	for enemy in game._living_enemies():
		var d := global_position.distance_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	if best == null:
		return
	_beam_to = best.global_position - global_position
	_beam_left = 0.18
	best.take_elemental_damage(damage, element)
	if is_instance_valid(best) and best.health > 0:
		best.react_to_spell(str(SPELL_OF.get(element, "fireball")))
		if element == "fire" and is_instance_valid(best) and best.health > 0:
			best.apply_burning(2, 1.5)
		elif element == "ice" and is_instance_valid(best) and best.health > 0:
			best.apply_slow(0.65, 1.2)

func _draw() -> void:
	var color := _color()
	var bob := sin(_clock * 3.0) * 2.0
	var top := Vector2(0, -22 + bob)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(top, 9.0, Color(color, 0.18))
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, -9), top + Vector2(5, 0), top + Vector2(0, 9), top + Vector2(-5, 0)]), color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, -9), top + Vector2(2, 0), top + Vector2(0, 9), top + Vector2(-5, 0)]), color.lightened(0.3))
	if _beam_left > 0.0:
		draw_line(top, _beam_to, Color(1, 1, 1, 0.9), 2.0)
		draw_line(top, _beam_to, Color(color, 0.7), 4.0)
