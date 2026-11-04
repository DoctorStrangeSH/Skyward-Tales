extends Node2D
class_name EnemyCombatFeedback

## Top of the health bar relative to the enemy; tall enemies move it up.
var bar_y: float = -28.0

var max_health: int = 1
var health: int = 1
var damage_amount: int = 0
var damage_timer: float = 0.0
var warning: bool = false
var elite: bool = false
var burning: bool = false
var chilled: bool = false
var reaction_name: String = ""
var reaction_time: float = 0.0
## Ground arrow showing where a lunge will go (empty when length is 0).
var telegraph_direction: Vector2 = Vector2.ZERO
var telegraph_length: float = 0.0
var _telegraph_time: float = 0.0
## Elite modifier name drawn above the health bar.
var elite_name: String = ""
var elite_color: Color = Color(1.0, 0.7, 0.3)

func _ready() -> void:
	z_index = 30
	queue_redraw()

func set_health(current: int, maximum: int) -> void:
	max_health = maxi(1, maximum)
	health = clampi(current, 0, max_health)
	queue_redraw()

func show_damage(amount: int) -> void:
	if not GameSettings.damage_numbers_enabled():
		return
	damage_amount = maxi(0, amount)
	damage_timer = 0.72
	queue_redraw()

func set_warning(enabled: bool) -> void:
	if warning == enabled:
		return
	warning = enabled
	queue_redraw()

func set_statuses(fire: bool, ice: bool) -> void:
	if burning == fire and chilled == ice:
		return
	burning = fire
	chilled = ice
	queue_redraw()

func set_telegraph(direction: Vector2, length: float) -> void:
	telegraph_direction = direction.normalized()
	telegraph_length = length
	_telegraph_time = 0.0
	queue_redraw()

func show_reaction(label: String) -> void:
	reaction_name = label
	reaction_time = 0.8
	queue_redraw()

func _process(delta: float) -> void:
	if telegraph_length > 0.0:
		_telegraph_time += delta
		queue_redraw()
	if reaction_time > 0.0:
		reaction_time = maxf(0.0, reaction_time - delta)
		queue_redraw()
	if damage_timer > 0.0:
		damage_timer = maxf(0.0, damage_timer - delta)
		queue_redraw()

func _draw() -> void:
	if telegraph_length > 0.0:
		var pulse := 0.35 + 0.25 * sin(_telegraph_time * 18.0)
		var tip := telegraph_direction * telegraph_length
		var side := Vector2(-telegraph_direction.y, telegraph_direction.x)
		draw_line(telegraph_direction * 8.0, tip, Color(1.0, 0.25, 0.2, pulse), 4.0)
		draw_colored_polygon(PackedVector2Array([tip + telegraph_direction * 6.0, tip + side * 5.0, tip - side * 5.0]), Color(1.0, 0.3, 0.2, pulse + 0.2))
	if not elite_name.is_empty():
		var font := UiFont.font()
		var width := font.get_string_size(elite_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8)).x
		draw_string_outline(font, Vector2(-width / 2.0, bar_y - 3), elite_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), 3, Color(0.05, 0.04, 0.08))
		draw_string(font, Vector2(-width / 2.0, bar_y - 3), elite_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), elite_color)
	var width: float = 34.0 if elite else 25.0
	var left: float = -width / 2.0
	draw_rect(Rect2(left - 1, bar_y - 1, width + 2, 7), Color(0.06, 0.08, 0.12))
	draw_rect(Rect2(left, bar_y, width, 5), Color(0.29, 0.19, 0.20))
	draw_rect(Rect2(left, bar_y, width * float(health) / float(max_health), 5), Color(0.94, 0.56, 0.24) if elite else Color(0.53, 0.86, 0.53))
	if burning:
		draw_circle(Vector2(-7, -11), 3.5, Color(1.0, 0.38, 0.1, 0.85))
		draw_circle(Vector2(4, -14), 2.5, Color(1.0, 0.8, 0.24, 0.86))
	if chilled:
		draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 20, Color(0.42, 0.85, 1.0, 0.9), 2.0)
	if reaction_time > 0.0:
		draw_string(UiFont.font(), Vector2(-22, bar_y - 15.0 - (0.8 - reaction_time) * 15.0), reaction_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(10), Color(0.92, 0.98, 1.0, reaction_time / 0.8))
	if warning:
		draw_arc(Vector2(0, -1), 13.0 if elite else 10.0, 0.0, TAU, 18, Color(1.0, 0.28, 0.21, 0.9), 2.0)
	if damage_timer > 0.0:
		var drift: float = (0.72 - damage_timer) * 20.0
		draw_string(UiFont.font(), Vector2(-6, bar_y - 6.0 - drift), str(damage_amount), HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(12), Color(1.0, 0.92, 0.73, damage_timer / 0.72))
