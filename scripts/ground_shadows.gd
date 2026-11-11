extends Node2D
class_name GroundShadows

## Soft shadows on the ground under everything that stands on it (stage 21).
## The sun is fixed: shadows fall to the lower right. Scenery shadows are
## drawn here in one node (above the ground, under every object); moving
## things carry their own blob (`attach`).

const COLOR := Color(0.08, 0.07, 0.22, 0.5)
const SUN := Vector2(0.55, 0.22)

static var _blob: GradientTexture2D

var _spots: Array = []
## [texture, foot, scale, origin] — silhouettes laid on the ground by the sun.
var _casts: Array = []
## How a point `h` above the foot is thrown: right and a little down.
const CAST := Vector2(0.62, 0.2)
const CAST_COLOR := Color(0.02, 0.03, 0.12, 0.36)

static func blob() -> Texture2D:
	if _blob == null:
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.add_point(0.55, Color(1, 1, 1, 0.75))
		ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
		_blob = GradientTexture2D.new()
		_blob.gradient = ramp
		_blob.fill = GradientTexture2D.FILL_RADIAL
		_blob.fill_from = Vector2(0.5, 0.5)
		_blob.fill_to = Vector2(1.0, 0.5)
		_blob.width = 64
		_blob.height = 64
	return _blob

func _ready() -> void:
	z_index = -95
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

## A thing `size` world pixels big standing with its foot at `foot`.
## Trees get a small dark contact patch and the wide shade of the crown.
func add_object(foot: Vector2, size: Vector2, tree: bool = false) -> void:
	if tree:
		_spots.append([foot + Vector2(0, -1), Vector2(size.x * 0.34, size.x * 0.12), 1.0])
		_spots.append([foot + Vector2(size.x * SUN.x * 0.45, size.x * SUN.y * 0.3), Vector2(size.x * 1.15, size.x * 0.5), 0.85])
	else:
		var tall := clampf(size.y / maxf(1.0, size.x), 0.4, 2.0)
		_spots.append([foot + Vector2(size.x * 0.1 * tall, -size.x * 0.02), Vector2(size.x * (0.92 + 0.12 * tall), maxf(5.0, size.x * 0.3)), 1.0])
	queue_redraw()

## The object's own outline as a long shadow (trees, houses, posts).
func add_cast(texture: Texture2D, foot: Vector2, scale: float, origin: Vector2) -> void:
	_casts.append([texture, foot, scale, origin])
	queue_redraw()

func _draw() -> void:
	for cast in _casts:
		var s: float = cast[2]
		# Sprite space → ground: x stays, height leans along the sun.
		draw_set_transform_matrix(Transform2D(Vector2(s, 0), Vector2(-CAST.x * s, -CAST.y * s), cast[1]))
		draw_texture(cast[0], -(cast[3] as Vector2), CAST_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tex := blob()
	for spot in _spots:
		var at: Vector2 = spot[0]
		var size: Vector2 = spot[1]
		draw_set_transform(at, 0.0, size / 64.0)
		draw_texture(tex, Vector2(-32, -32), Color(COLOR.r, COLOR.g, COLOR.b, COLOR.a * float(spot[2])))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A blob under a walking creature.
static func attach(actor: Node2D, width: float = 14.0, lift: float = 0.0) -> Sprite2D:
	var old := actor.get_node_or_null("GroundShadow")
	if old != null:
		old.free()
	var sprite := Sprite2D.new()
	sprite.name = "GroundShadow"
	sprite.texture = blob()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2(width, width * 0.42) / 64.0
	sprite.position = Vector2(width * 0.08, lift)
	sprite.modulate = COLOR
	sprite.z_index = -1
	sprite.show_behind_parent = true
	actor.add_child(sprite)
	actor.move_child(sprite, 0)
	return sprite
