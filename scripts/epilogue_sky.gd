extends Node2D
class_name EpilogueSky

## The sky after the finale, drawn over the visible part of the world.
## "restore" (Живое небо): aurora ribbons of the lit Pattern at night.
## "lower" (Звёзды над землёй): shooting stars streak across the night.

var ending: String = ""
## 0..1, how dark it is (set by Epilogue every frame).
var night: float = 0.0
var _clock := 0.0
var _stars: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 60
	_rng.randomize()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

func _view() -> Rect2:
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var size := get_viewport().get_visible_rect().size
	return Rect2(inverse * Vector2.ZERO, inverse.basis_xform(size))

func _process(delta: float) -> void:
	_clock += delta
	if ending == "lower" and night > 0.3:
		if _rng.randf() < delta * 0.9:
			_stars.append({"t": 0.0, "x": _rng.randf(), "y": _rng.randf_range(0.0, 0.45), "len": _rng.randf_range(0.18, 0.32)})
	for star in _stars:
		star["t"] = float(star["t"]) + delta / 0.9
	_stars = _stars.filter(func(s: Dictionary) -> bool: return float(s["t"]) < 1.0)
	queue_redraw()

func _draw() -> void:
	if night <= 0.01:
		return
	var view := _view()
	if ending == "restore":
		_draw_aurora(view)
	elif ending == "lower":
		_draw_stars(view)

func _draw_aurora(view: Rect2) -> void:
	var colors := [Color(0.3, 1.0, 0.7), Color(0.45, 0.78, 1.0), Color(0.8, 0.55, 1.0)]
	var steps := 48
	for band in 3:
		var color: Color = colors[band]
		var base_y := view.position.y + view.size.y * (0.06 + band * 0.07)
		var prev_top := Vector2.ZERO
		var prev_bottom := Vector2.ZERO
		var prev_alpha := 0.0
		for i in steps + 1:
			var t := float(i) / steps
			var x := view.position.x + t * view.size.x
			var wave := sin(t * 6.0 + _clock * (0.35 + band * 0.12) + band * 1.7) * view.size.y * 0.035
			var height := view.size.y * (0.1 + 0.05 * sin(t * 9.0 - _clock * 0.6 + band))
			var top := Vector2(x, base_y + wave)
			var bottom := top + Vector2(0, height)
			var alpha := sin(t * PI) * night * (0.75 + 0.25 * sin(t * 13.0 + _clock + band))
			if i > 0:
				# A curtain: bright along the top edge, fading downwards.
				draw_polygon(PackedVector2Array([prev_top, top, bottom, prev_bottom]),
					PackedColorArray([Color(color, prev_alpha), Color(color, alpha), Color(color, 0.0), Color(color, 0.0)]))
				draw_line(prev_top, top, Color(color.lightened(0.4), minf(1.0, alpha * 1.2)), 1.0)
			prev_top = top
			prev_bottom = bottom
			prev_alpha = alpha

func _draw_stars(view: Rect2) -> void:
	# A faint field of extra stars, then the streaks.
	for i in 40:
		var px := fmod(float(i) * 0.6180339 * 7.0, 1.0)
		var py := fmod(float(i) * 0.4142135 * 5.0, 1.0) * 0.5
		var twinkle := 0.5 + 0.5 * sin(_clock * 2.0 + i)
		draw_rect(Rect2(view.position + Vector2(px, py) * view.size, Vector2(1, 1)), Color(1, 1, 0.9, 0.35 * night * twinkle))
	for star in _stars:
		var t := float(star["t"])
		var head := view.position + Vector2(float(star["x"]) * view.size.x - t * view.size.x * 0.35, (float(star["y"]) + t * 0.2) * view.size.y)
		var tail := head + Vector2(1.0, -0.45).normalized() * view.size.x * float(star["len"]) * (1.0 - absf(t - 0.5))
		var alpha := sin(t * PI) * night
		draw_line(tail, head, Color(1.0, 0.95, 0.7, alpha * 0.5), 1.5)
		draw_line(tail.lerp(head, 0.6), head, Color(1, 1, 1, alpha), 1.0)
		draw_circle(head, 1.2, Color(1, 1, 1, alpha))
