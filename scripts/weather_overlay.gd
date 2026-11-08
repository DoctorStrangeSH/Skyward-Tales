extends Node2D
class_name WeatherOverlay

## Screen weather for the ship-only islands: "storm" (dark sky, slanting
## rain) or "fog" (drifting mist banks). A world node pinned to the screen
## (so the HUD stays above it), drawn in screen pixels.

var mode: String = "storm"
var _drops: Array = []
var _banks: Array = []
var _clock: float = 0.0

func _ready() -> void:
	z_index = 90
	z_as_relative = false
	add_to_group("region_actor")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 90:
		_drops.append(Vector3(rng.randf() * 700.0, rng.randf() * 380.0, rng.randf_range(0.7, 1.3)))
	for i in 7:
		_banks.append(Vector3(rng.randf() * 760.0 - 60.0, rng.randf() * 360.0, rng.randf_range(0.6, 1.4)))

func _process(delta: float) -> void:
	_clock += delta
	for i in _drops.size():
		var d: Vector3 = _drops[i]
		d.x -= 120.0 * delta * d.z
		d.y += 420.0 * delta * d.z
		if d.y > 370.0:
			d.y = -10.0
			d.x = randf() * 720.0
		_drops[i] = d
	for i in _banks.size():
		var b: Vector3 = _banks[i]
		b.x += 9.0 * delta * b.z
		if b.x > 720.0:
			b.x = -140.0
		_banks[i] = b
	# Pin to the screen: undo the camera transform.
	global_transform = get_viewport().get_canvas_transform().affine_inverse()
	queue_redraw()

func _draw() -> void:
	if mode == "bloom":
		draw_rect(Rect2(0, 0, 640, 360), Color(1.0, 0.9, 0.55, 0.07))
		for i in 14:
			var b: Vector3 = _drops[i]
			var p := Vector2(fmod(b.x + _clock * 6.0 * b.z, 660.0), fmod(b.y - _clock * 14.0 * b.z + 400.0, 380.0))
			draw_circle(p, 1.6 * b.z, Color(1.0, 0.92, 0.6, 0.55))
		return
	if mode == "dim":
		draw_rect(Rect2(0, 0, 640, 360), Color(0.12, 0.05, 0.18, 0.26))
		return
	if mode == "storm":
		draw_rect(Rect2(0, 0, 640, 360), Color(0.05, 0.07, 0.2, 0.42))
		for d in _drops:
			var top := Vector2(d.x, d.y)
			draw_line(top, top + Vector2(-3.5, 11.0) * d.z, Color(0.78, 0.85, 1.0, 0.5), 1.0)
	else:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.86, 0.9, 0.98, 0.2 + 0.04 * sin(_clock * 0.5)))
		for b in _banks:
			for k in 3:
				draw_circle(Vector2(b.x + k * 46.0, b.y + sin(_clock * 0.4 + k) * 6.0), 58.0 * b.z, Color(0.94, 0.96, 1.0, 0.12))
