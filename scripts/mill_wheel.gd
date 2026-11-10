extends Node2D
class_name MillWheel

## The turning wheel of the watermill with spray at its foot (art from the
## owner's pack, tools/art/homestead_art.py: 8x6 wheel frames, 4x3 splash).

const WHEEL := "res://assets/world_hd/props/mill_wheel.png"
const SPLASH := "res://assets/world_hd/props/mill_splash.png"

var _wheel: Sprite2D
var _splash: Sprite2D
var _clock: float = 0.0

func _ready() -> void:
	add_to_group("region_actor")
	_wheel = _sheet(WHEEL, 8, 6, Vector2(0, -14))
	_splash = _sheet(SPLASH, 4, 3, Vector2(0, 2))

func _sheet(path: String, columns: int, rows: int, at: Vector2) -> Sprite2D:
	if not ResourceLoader.exists(path):
		return null
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.hframes = columns
	sprite.vframes = rows
	sprite.scale = Vector2.ONE * 0.5
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = at
	add_child(sprite)
	return sprite

func _process(delta: float) -> void:
	_clock += delta
	if _wheel != null:
		_wheel.frame = int(_clock * 12.0) % (_wheel.hframes * _wheel.vframes)
	if _splash != null:
		_splash.frame = int(_clock * 10.0) % (_splash.hframes * _splash.vframes)
