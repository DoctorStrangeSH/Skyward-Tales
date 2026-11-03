extends Sprite2D
class_name DirectionalSprite

## Shared 8-way sprite-sheet controller.
## Atlas layout: one row per direction, frames left-to-right.
## Direction order: down, down-right, right, up-right, up,
##                  up-left, left, down-left.

@export var frames_per_direction: int = 4
@export var direction_count: int = 8
@export var animation_fps: float = 8.0

var direction_index: int = 0
var animation_frame: int = 0
var is_moving: bool = false
var _animation_clock: float = 0.0

## Atlas textures are shared between all sprites that use the same file.
static var _texture_cache: Dictionary = {}

static func _get_texture(texture_path: String) -> Texture2D:
	if _texture_cache.has(texture_path):
		return _texture_cache[texture_path]
	# Imported resource: works in the editor and in exported builds.
	var loaded := load(texture_path) as Texture2D
	if loaded == null:
		# Fallback for a project that has not been imported yet.
		var image := Image.new()
		if image.load(texture_path) == OK:
			loaded = ImageTexture.create_from_image(image)
	if loaded != null:
		_texture_cache[texture_path] = loaded
	return loaded

func configure(texture_path: String, frames: int = 4, directions: int = 8, visual_scale: float = 1.0, fps: float = 8.0) -> void:
	texture = _get_texture(texture_path)
	frames_per_direction = maxi(1, frames)
	direction_count = maxi(1, directions)
	animation_fps = maxf(1.0, fps)
	hframes = frames_per_direction
	vframes = direction_count
	scale = Vector2.ONE * visual_scale
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true
	direction_index = 0
	animation_frame = 0
	_apply_frame()

func set_direction_vector(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	var octant: int = posmod(int(round(direction.angle() / (PI / 4.0))), 8)
	# atan2 uses screen coordinates: right, down-right, down, ...
	var row_for_octant := [2, 1, 0, 7, 6, 5, 4, 3]
	var next_direction := int(row_for_octant[octant])
	if next_direction != direction_index:
		direction_index = next_direction
		animation_frame = 0
		_animation_clock = 0.0
		_apply_frame()

func set_moving(value: bool) -> void:
	if is_moving == value:
		return
	is_moving = value
	_animation_clock = 0.0
	if not is_moving:
		animation_frame = 0
		_apply_frame()

func _process(delta: float) -> void:
	if not is_moving or frames_per_direction <= 1:
		return
	_animation_clock += delta
	var frame_duration := 1.0 / animation_fps
	while _animation_clock >= frame_duration:
		_animation_clock -= frame_duration
		animation_frame = (animation_frame + 1) % frames_per_direction
		_apply_frame()

func _apply_frame() -> void:
	frame = direction_index * frames_per_direction + animation_frame
