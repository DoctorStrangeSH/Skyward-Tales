extends Node2D
class_name FarmPatch

## The garden's fence; at level 3 a scarecrow and a sprinkler join it.

var farm: Farm
var _clock: float = 0.0

func _ready() -> void:
	z_index = -35

func _process(delta: float) -> void:
	_clock += delta
	if farm.level() >= 3:
		queue_redraw()

func _draw() -> void:
	var rows := 1 if farm.level() <= 1 else 2
	var half := Vector2(70, 22 if rows == 1 else 44)
	var top := -half.y - 8.0
	var bottom := (half.y - 22.0) if rows == 1 else half.y
	var wood := Color(0.55, 0.38, 0.22)
	var dark := Color(0.32, 0.2, 0.12)
	# Rails and posts around the beds (open at the bottom middle).
	for y in [top, bottom + 14.0]:
		var segments: Array = [[-half.x, -12.0], [12.0, half.x]] if y > 0.0 else [[-half.x, half.x]]
		for segment in segments:
			draw_line(Vector2(segment[0], y - 4), Vector2(segment[1], y - 4), wood, 2.0)
			draw_line(Vector2(segment[0], y), Vector2(segment[1], y), wood, 2.0)
	for x in [-half.x, half.x]:
		draw_line(Vector2(x, top - 4), Vector2(x, bottom + 14.0), wood, 2.0)
	var post_x := -half.x
	while post_x <= half.x:
		for y in [top, bottom + 14.0]:
			if y > 0.0 and absf(post_x) < 14.0:
				continue
			draw_rect(Rect2(post_x - 1.5, y - 8, 3, 9), dark)
		post_x += 20.0
	if farm.level() >= 3:
		# Scarecrow.
		var s := Vector2(half.x + 16, top + 18)
		draw_line(s, s + Vector2(0, -26), dark, 2.0)
		draw_line(s + Vector2(-9, -18), s + Vector2(9, -18), dark, 2.0)
		draw_rect(Rect2(s + Vector2(-6, -20), Vector2(12, 10)), Color(0.75, 0.3, 0.25))
		draw_circle(s + Vector2(0, -26), 4.0, Color(0.9, 0.8, 0.5))
		draw_colored_polygon(PackedVector2Array([s + Vector2(-6, -28), s + Vector2(6, -28), s + Vector2(0, -35)]), Color(0.5, 0.35, 0.2))
		# Sprinkler: a little spray arc.
		var w := Vector2(-half.x - 14, top + 22)
		draw_rect(Rect2(w + Vector2(-2, -10), Vector2(4, 10)), Color(0.5, 0.52, 0.58))
		for i in 5:
			var a := -PI * 0.5 + sin(_clock * 2.0) * 0.8 + (i - 2) * 0.25
			draw_circle(w + Vector2(0, -12) + Vector2(cos(a), sin(a)) * (6.0 + fmod(_clock * 20.0 + i * 3, 10.0)), 0.9, Color(0.6, 0.85, 1.0, 0.8))
