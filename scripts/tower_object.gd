extends Node2D
class_name TowerObject

## A piece of the Tower of Trials (scripts/trial_tower.gd): the gate, the
## lever, the coffer, the altar, the stairs, a brazier… Art is a prop from
## assets/world_hd/props/tower_*.png; `label` makes it interactable,
## `wall_width` makes it solid, `glow` lights it up.

signal used(object: TowerObject)

var art: String = ""
var label: String = ""
var wall_width: float = 0.0
var glow: Color = Color(0, 0, 0, 0)
var flat: bool = false
## An animated prop: a sheet in assets/world_hd/props with frames.
var sheet: String = ""
var sheet_frames := Vector2i(4, 2)
var sheet_fps: float = 8.0
var _sprite: Sprite2D
var _clock: float = 0.0

func _ready() -> void:
	add_to_group("region_actor")
	if not label.is_empty():
		add_to_group("interactables")
	if flat:
		z_index = -90
	if wall_width > 0.0:
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(wall_width, 12)
		shape.shape = rect
		shape.position = Vector2(0, -6)
		body.add_child(shape)
		add_child(body)
	var sheet_path := "res://assets/world_hd/props/%s.png" % sheet
	if not sheet.is_empty() and ResourceLoader.exists(sheet_path):
		_sprite = Sprite2D.new()
		_sprite.texture = load(sheet_path)
		_sprite.hframes = sheet_frames.x
		_sprite.vframes = sheet_frames.y
		_sprite.scale = Vector2.ONE * 0.5
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_sprite.centered = false
		_sprite.position = -Vector2(_sprite.texture.get_width() / float(sheet_frames.x) * 0.25, _sprite.texture.get_height() / float(sheet_frames.y) * 0.5 - 2.0)
		add_child(_sprite)
	else:
		set_process(false)
	if glow.a > 0.0:
		var light := PointLight2D.new()
		light.texture = _light_texture()
		light.color = glow
		light.energy = 0.9 * glow.a
		light.color = Color(glow.r, glow.g, glow.b)
		light.texture_scale = 1.4
		light.position = Vector2(0, -16)
		add_child(light)
	queue_redraw()

static func _light_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 96
	texture.height = 96
	return texture

func _process(delta: float) -> void:
	_clock += delta
	if _sprite != null:
		_sprite.frame = int(_clock * sheet_fps) % (sheet_frames.x * sheet_frames.y)

func set_art(value: String) -> void:
	art = value
	queue_redraw()

func interact() -> void:
	used.emit(self)

func _draw() -> void:
	if not art.is_empty():
		WorldArt.draw_prop(self, "world/props/%s.png" % art)
