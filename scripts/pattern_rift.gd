extends Node2D
class_name PatternRift

## A tear in the Pattern (post-game, data/epilogue.json). E — touch it:
## echoes of local monsters pour out; when the last one falls the rift seals.

signal touched(rift: PatternRift)

var region_id: String = ""
## true while its echoes are alive (no more interaction).
var awake: bool = false
var _clock := 0.0

func _ready() -> void:
	add_to_group("interactables")
	z_index = -40

func interact() -> void:
	if awake:
		return
	touched.emit(self)

func wake() -> void:
	awake = true
	remove_from_group("interactables")

func _process(delta: float) -> void:
	_clock += delta * (2.4 if awake else 1.0)
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 26.0 + pulse * 3.0, Color(0.45, 0.2, 0.75, 0.22))
	draw_circle(Vector2.ZERO, 17.0, Color(0.12, 0.04, 0.22, 0.85))
	# Swirling arms of light around the dark core.
	for arm in 3:
		var points := PackedVector2Array()
		for step in 12:
			var t := float(step) / 11.0
			var angle := _clock * 1.6 + arm * TAU / 3.0 + t * 3.2
			points.append(Vector2.RIGHT.rotated(angle) * lerpf(5.0, 24.0, t))
		draw_polyline(points, Color(0.85, 0.6, 1.0, 0.85), 1.6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A crack of light standing up from the ground.
	var glow := Color(1.0, 0.86, 0.55, 0.6 + 0.4 * pulse)
	draw_polyline(PackedVector2Array([Vector2(0, 2), Vector2(-3, -10), Vector2(2, -20), Vector2(-2, -30), Vector2(1, -38)]), glow, 2.0)
	draw_polyline(PackedVector2Array([Vector2(0, 2), Vector2(-3, -10), Vector2(2, -20), Vector2(-2, -30), Vector2(1, -38)]), Color(1, 1, 1, 0.8), 0.8)
