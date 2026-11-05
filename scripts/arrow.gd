extends Node2D
class_name Arrow

## A bow shot (ranger). Flies straight and lands a "strike" on the first foe
## it touches (main._strike: crits, ripostes, combos, the imbued element and
## the hit streak all work for arrows too). Aimed shots pierce.

var game: SkywardGame
var direction: Vector2 = Vector2.RIGHT
var speed: float = 330.0
var damage: int = 8
var pierce_left: int = 0
var lifetime: float = 0.9
var aimed: bool = false
var _hit: Array = []

func setup(owner_game: SkywardGame, flight: Vector2, arrow_damage: int, pierces: int = 0, is_aimed: bool = false) -> void:
	game = owner_game
	direction = flight.normalized()
	damage = arrow_damage
	pierce_left = pierces
	aimed = is_aimed
	rotation = direction.angle()
	z_index = 20

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	for enemy in game._living_enemies():
		if _hit.has(enemy):
			continue
		if enemy.global_position.distance_to(global_position) <= 11.0 + (6.0 if aimed else 0.0):
			_hit.append(enemy)
			game._strike(enemy, damage, direction, 60.0 if not aimed else 120.0)
			Vfx.sparkle(game, global_position)
			if pierce_left <= 0:
				queue_free()
				return
			pierce_left -= 1

func _draw() -> void:
	var color := Color(1.0, 0.9, 0.6) if not aimed else Color(1.0, 0.95, 0.75)
	var element: String = game.combos.imbue_element if game != null and game.combos.imbued() else ""
	if not element.is_empty():
		color = ElementalCombos.ELEMENT_COLORS.get(element, color)
		draw_line(Vector2(-14, -8), Vector2(4, -8), Color(color, 0.35), 4.0)
	draw_line(Vector2(-10, -8), Vector2(5, -8), Color(0.55, 0.38, 0.22), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -8), Vector2(4, -10), Vector2(4, -6)]), Color(0.85, 0.88, 0.92))
	draw_line(Vector2(-12, -10), Vector2(-9, -8), color, 1.0)
	draw_line(Vector2(-12, -6), Vector2(-9, -8), color, 1.0)
	if aimed:
		draw_line(Vector2(-22, -8), Vector2(-10, -8), Color(1, 1, 1, 0.35), 2.0)

func _process(_delta: float) -> void:
	queue_redraw()
