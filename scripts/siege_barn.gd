extends Node2D
class_name SiegeBarn

## The thing besieged in a defence errand: foes are taunted by it, hit it
## like a hero, and its health bar hangs over it.

var max_health: int = 200
var health: int = 200
var _flash: float = 0.0

func _ready() -> void:
	z_index = 2
	# The granary itself: sheaves, crates and a barrel by Gavrila's field.
	for piece in [["farm_sheaf", Vector2(-18, -4)], ["farm_sheaf", Vector2(18, -4)], ["supply_crate", Vector2(0, 2)], ["farm_barrel", Vector2(14, 10)], ["supply_crate", Vector2(-12, 10)]]:
		var prop := TowerObject.new()
		prop.art = str(piece[0])
		prop.position = piece[1]
		prop.z_index = -1
		add_child(prop)

func take_damage(amount: int, _source: Node = null) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	_flash = 0.15
	queue_redraw()

func is_down() -> bool:
	return health <= 0

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()

func _draw() -> void:
	if _flash > 0.0:
		draw_circle(Vector2(0, -8), 18.0, Color(1, 0.3, 0.2, 0.25))
	# A shield sign over the granary and its health bar.
	var width := 48.0
	var top := Vector2(-width / 2.0, -40.0)
	draw_rect(Rect2(top - Vector2(1, 1), Vector2(width + 2, 6)), Color(0, 0, 0, 0.75))
	var share := float(health) / float(maxi(1, max_health))
	var color := Color(0.45, 0.85, 0.4) if share > 0.5 else (Color(0.95, 0.75, 0.3) if share > 0.25 else Color(0.95, 0.3, 0.25))
	draw_rect(Rect2(top, Vector2(width * share, 4)), color.lightened(0.5) if _flash > 0.0 else color)
	draw_circle(Vector2(0, -50), 6.0, Color(0.15, 0.12, 0.08, 0.85))
	draw_arc(Vector2(0, -50), 6.0, 0, TAU, 16, Color(1.0, 0.85, 0.45), 1.5)
	draw_line(Vector2(0, -54), Vector2(0, -46), Color(1.0, 0.85, 0.45), 1.5)
