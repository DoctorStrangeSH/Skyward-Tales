extends CanvasLayer
class_name FlightTransition

## The flight between docks: the sky fades in, clouds race past and the ship
## crosses the screen; at the midpoint the region changes underneath.

signal midpoint
signal finished

const DURATION := 2.4

var title: String = ""
var storm: bool = false
var _clock: float = 0.0
var _mid_sent: bool = false
var _canvas: Control
var _ship: Texture2D
var _clouds: Array = []

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ship = load(SkyShipView.SHIP)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = Vector2(640, 360)
	_canvas.draw.connect(_draw_flight)
	add_child(_canvas)
	for i in 14:
		_clouds.append(Vector3(randf() * 800.0, randf() * 360.0, randf_range(0.5, 1.4)))
	GameAudio.play("travel", -2.0, 0.0)

func _process(delta: float) -> void:
	_clock += delta
	if not _mid_sent and _clock >= DURATION * 0.5:
		_mid_sent = true
		midpoint.emit()
	if _clock >= DURATION:
		finished.emit()
		queue_free()
		return
	_canvas.queue_redraw()

func _alpha() -> float:
	var t := _clock / DURATION
	if t < 0.25:
		return t / 0.25
	if t > 0.75:
		return (1.0 - t) / 0.25
	return 1.0

func _draw_flight() -> void:
	var a := _alpha()
	var top := Color(0.36, 0.55, 0.85) if not storm else Color(0.16, 0.18, 0.32)
	var bottom := Color(0.78, 0.88, 0.98) if not storm else Color(0.36, 0.38, 0.52)
	for i in 12:
		var y := i * 30.0
		_canvas.draw_rect(Rect2(0, y, 640, 31), Color(top.lerp(bottom, i / 11.0), a))
	var t := _clock / DURATION
	for c in _clouds:
		var x := fmod(c.x - t * 900.0 * c.z + 1600.0, 800.0) - 80.0
		var col := Color(1, 1, 1, 0.75 * a) if not storm else Color(0.55, 0.58, 0.7, 0.8 * a)
		for k in 3:
			_canvas.draw_circle(Vector2(x + k * 22.0 * c.z, c.y + (k % 2) * 6.0), 20.0 * c.z, col)
	if _ship != null:
		var size := Vector2(170, 150)
		var pos := Vector2(lerpf(-120.0, 560.0, t), 110.0 + sin(_clock * 3.0) * 6.0)
		_canvas.draw_texture_rect(_ship, Rect2(pos, size), false, Color(1, 1, 1, a))
	if not title.is_empty():
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_canvas.draw_string_outline(font, Vector2(320 - width * 0.5, 320), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.7 * a))
		_canvas.draw_string(font, Vector2(320 - width * 0.5, 320), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.8, a))
