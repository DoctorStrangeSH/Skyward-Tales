extends CanvasLayer
class_name SkyBattleView

## The backdrop of an air battle (scripts/sky_battle.gd): the sky above the
## clouds, the «Ветрокрыл» on the left, the pirate ship (darkened, under a
## black sail) on the right; volleys flash and the hit ship shakes. It sits
## under the HUD so the battle's dialogue stays on top.

var _canvas: Control
var _ship: Texture2D
var _clouds: Array = []
var _clock: float = 0.0
var _flash: Dictionary = {"ours": 0.0, "theirs": 0.0}
var _shake: Dictionary = {"ours": 0.0, "theirs": 0.0}

func _ready() -> void:
	layer = 1
	_ship = WorldArt.texture(SkyShipView.SHIP)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = Vector2(640, 360)
	_canvas.draw.connect(_draw_sky)
	add_child(_canvas)
	for i in 16:
		_clouds.append(Vector3(randf() * 800.0, randf() * 260.0, randf_range(0.5, 1.4)))

## A volley: `side` — who fires ("ours" / "theirs").
func volley(side: String) -> void:
	_flash[side] = 0.35
	_shake["theirs" if side == "ours" else "ours"] = 0.4

func _process(delta: float) -> void:
	_clock += delta
	for key in _flash:
		_flash[key] = maxf(0.0, float(_flash[key]) - delta)
		_shake[key] = maxf(0.0, float(_shake[key]) - delta)
	_canvas.queue_redraw()

func _draw_ship(at: Vector2, side: String, tint: Color, flip: bool) -> void:
	if _ship == null:
		return
	var tex := _ship.get_size()
	var size := tex * minf(200.0 / tex.x, 120.0 / tex.y)
	var wobble := Vector2(randf_range(-3, 3), randf_range(-2, 2)) if float(_shake[side]) > 0.0 else Vector2.ZERO
	var pos := at + wobble + Vector2(0, sin(_clock * 2.2 + (1.0 if flip else 0.0)) * 5.0)
	var rect := Rect2(pos, size)
	if flip:
		rect = Rect2(pos + Vector2(size.x, 0), Vector2(-size.x, size.y))
	_canvas.draw_texture_rect(_ship, rect, false, tint)
	if float(_flash[side]) > 0.0:
		var muzzle := pos + Vector2(size.x if not flip else 0.0, size.y * 0.55)
		_canvas.draw_circle(muzzle, 10.0 + 30.0 * float(_flash[side]), Color(1.0, 0.85, 0.4, float(_flash[side]) * 2.0))

func _draw_sky() -> void:
	var top := Color(0.3, 0.48, 0.82)
	var bottom := Color(0.8, 0.88, 0.98)
	for i in 12:
		_canvas.draw_rect(Rect2(0, i * 30.0, 640, 31), top.lerp(bottom, i / 11.0))
	for c in _clouds:
		var x := fmod(c.x - _clock * 40.0 * c.z + 1600.0, 800.0) - 80.0
		for k in 3:
			_canvas.draw_circle(Vector2(x + k * 22.0 * c.z, c.y + (k % 2) * 6.0), 20.0 * c.z, Color(1, 1, 1, 0.7))
	_draw_ship(Vector2(20, 60), "ours", Color.WHITE, false)
	_draw_ship(Vector2(272, 96), "theirs", Color(0.45, 0.38, 0.42), true)
