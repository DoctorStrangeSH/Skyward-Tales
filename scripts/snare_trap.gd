extends Node2D
class_name SnareTrap

## Ranger's trap: snaps shut on the first foe that steps in — damage and
## 2.5 s rooted (a rooted foe counts as chilled for "Раскол").

const LIFETIME := 45.0

var game: SkywardGame
var damage: int = 12
var _life: float = LIFETIME
var _snapped: bool = false
var _snap_anim: float = 0.0

func _physics_process(delta: float) -> void:
	_life -= delta
	if _snapped:
		_snap_anim += delta
		if _snap_anim > 0.8:
			queue_free()
		queue_redraw()
		return
	if _life <= 0.0:
		queue_free()
		return
	for enemy in game._living_enemies():
		if enemy.global_position.distance_to(global_position) <= 14.0:
			_snap(enemy)
			return

func _snap(enemy: SlimeEnemy) -> void:
	_snapped = true
	enemy.take_damage(damage)
	if is_instance_valid(enemy) and enemy.health > 0:
		enemy.apply_slow(0.05, 2.5)
		enemy.combat_feedback.show_reaction("КАПКАН!")
	GameAudio.play("hit", -2.0, 0.2)
	Vfx.burst(game, global_position, [Color(0.9, 0.9, 0.95), Color(0.6, 0.5, 0.4), Color(0.5, 0.4, 0.3, 0)], 10, 60.0, 0.3)
	queue_redraw()

func _draw() -> void:
	var closed := _snapped
	var metal := Color(0.75, 0.78, 0.84)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 18, Color(0.35, 0.3, 0.26), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var gap := 1.0 if closed else 4.0
	for side in [-1.0, 1.0]:
		var base := Vector2(0, side * gap)
		draw_line(base + Vector2(-8, 0), base + Vector2(8, 0), metal, 1.5)
		for x in range(-7, 8, 3):
			draw_line(base + Vector2(x, 0), base + Vector2(x + 1, -side * 2.5), metal, 1.0)
	draw_circle(Vector2.ZERO, 1.5, Color(0.55, 0.42, 0.28))
