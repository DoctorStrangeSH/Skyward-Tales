extends Control
class_name SaveIndicator

## Bottom-right corner badge shown after every autosave: a turning crystal
## and "Сохранено", fading out after a moment.

var _time: float = 0.0
var _left: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(548, 300)
	size = Vector2(88, 18)
	process_mode = Node.PROCESS_MODE_ALWAYS
	modulate.a = 0.0

func play() -> void:
	_left = 2.2
	_time = 0.0

func _process(delta: float) -> void:
	if _left <= 0.0:
		modulate.a = 0.0
		return
	_left -= delta
	_time += delta
	modulate.a = clampf(minf(_time / 0.25, _left / 0.5), 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var font := UiFont.font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.06, 0.05, 0.75))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.45, 0.27, 0.9), false, 1.0)
	var c := Vector2(10, 9)
	var turn := absf(cos(_time * 5.0)) if _time < 0.9 else 1.0
	var w := 4.5 * maxf(0.2, turn)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(w, 0), c + Vector2(0, 6), c + Vector2(-w, 0)]), Color(0.5, 0.95, 1.0))
	var text := "Сохранение…" if _time < 0.9 else "Сохранено"
	draw_string(font, Vector2(20, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), Color(0.92, 0.95, 1.0))
