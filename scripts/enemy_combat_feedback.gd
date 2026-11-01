extends Node2D
class_name EnemyCombatFeedback

var max_health: int = 1
var health: int = 1
var damage_amount: int = 0
var damage_timer: float = 0.0
var warning: bool = false
var elite: bool = false

func _ready() -> void:
	z_index = 30
	queue_redraw()

func set_health(current: int, maximum: int) -> void:
	max_health = maxi(1, maximum)
	health = clampi(current, 0, max_health)
	queue_redraw()

func show_damage(amount: int) -> void:
	damage_amount = maxi(0, amount)
	damage_timer = 0.72
	queue_redraw()

func set_warning(enabled: bool) -> void:
	if warning == enabled:
		return
	warning = enabled
	queue_redraw()

func _process(delta: float) -> void:
	if damage_timer > 0.0:
		damage_timer = maxf(0.0, damage_timer - delta)
		queue_redraw()

func _draw() -> void:
	var width: float = 34.0 if elite else 25.0
	var left: float = -width / 2.0
	draw_rect(Rect2(left - 1, -29, width + 2, 7), Color(0.06, 0.08, 0.12))
	draw_rect(Rect2(left, -28, width, 5), Color(0.29, 0.19, 0.20))
	draw_rect(Rect2(left, -28, width * float(health) / float(max_health), 5), Color(0.94, 0.56, 0.24) if elite else Color(0.53, 0.86, 0.53))
	if warning:
		draw_arc(Vector2(0, -1), 13.0 if elite else 10.0, 0.0, TAU, 18, Color(1.0, 0.28, 0.21, 0.9), 2.0)
	if damage_timer > 0.0:
		var drift: float = (0.72 - damage_timer) * 20.0
		draw_string(ThemeDB.fallback_font, Vector2(-6, -34 - drift), str(damage_amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.92, 0.73, damage_timer / 0.72))
