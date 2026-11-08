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
var _base_texture: Texture2D
var _action_time_left: float = 0.0
var _action_duration: float = 0.0
var _action_frames: int = 0
var _base_frames: int = 4

## Chibi characters (assets/sprites/chibi, built by tools/art/chibi.py): named
## animations with their own frame counts, an idle loop when standing still.
const CHIBI_DIR := "res://assets/sprites/chibi/"
static var _chibi_manifest: Dictionary = {}
var chibi_id: String = ""
var chibi_anims: Dictionary = {}
var _walk_fps: float = 8.0
var _idle_fps: float = 6.0
var _showing_idle: bool = false

static func chibi_entry(id: String) -> Dictionary:
	if _chibi_manifest.is_empty():
		var file := FileAccess.open(CHIBI_DIR + "manifest.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_chibi_manifest = parsed
	var entry: Variant = _chibi_manifest.get(id, {})
	return entry if entry is Dictionary else {}

static func has_chibi(id: String) -> bool:
	return not chibi_entry(id).is_empty()

func _chibi_path(anim: String) -> String:
	return CHIBI_DIR + chibi_id + "/" + anim + ".png"

## Switches this sprite to a chibi character; false when there is none.
## The sprite is offset so the character's feet stand on the node origin.
func configure_chibi(id: String, fps: float = 10.0, visual_scale: float = 1.0) -> bool:
	var entry := chibi_entry(id)
	if entry.is_empty():
		return false
	chibi_id = id
	chibi_anims = entry.get("anims", {})
	_walk_fps = fps
	var start := "walk" if chibi_anims.has("walk") else "idle"
	configure(_chibi_path(start), int(chibi_anims[start]), 8, visual_scale, fps)
	var cell: Array = entry.get("cell", [64, 64])
	offset = Vector2(0.0, float(cell[1]) * 0.5 - float(entry.get("feet", cell[1])))
	_showing_idle = start == "idle"
	_show_idle(true)
	return true

func has_anim(anim: String) -> bool:
	return chibi_anims.has(anim)

## Plays a named chibi animation once; false when the character lacks it.
func play_named(anim: String, duration: float) -> bool:
	if not chibi_anims.has(anim):
		return false
	play_action(_chibi_path(anim), duration, int(chibi_anims[anim]))
	return true

func _show_idle(idle: bool) -> void:
	if chibi_id.is_empty() or _action_time_left > 0.0:
		return
	var anim := "idle" if idle and chibi_anims.has("idle") else ("walk" if chibi_anims.has("walk") else "idle")
	var want_idle := anim == "idle"
	if want_idle == _showing_idle and texture != null:
		return
	_showing_idle = want_idle
	texture = _get_texture(_chibi_path(anim))
	frames_per_direction = int(chibi_anims[anim])
	hframes = frames_per_direction
	animation_fps = _idle_fps if want_idle else _walk_fps
	animation_frame = 0
	_apply_frame()

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
	_base_frames = frames_per_direction
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
	if not chibi_id.is_empty():
		_show_idle(not is_moving)
		return
	if not is_moving:
		animation_frame = 0
		_apply_frame()

## Plays a one-shot action sheet over the walk cycle. frames < 0 means the
## same frame count as the current sheet.
func play_action(texture_path: String, duration: float, frames: int = -1) -> void:
	var action := _get_texture(texture_path)
	if action == null:
		return
	if _action_time_left <= 0.0:
		_base_texture = texture
		_base_frames = hframes
	_action_frames = frames if frames > 0 else _base_frames
	hframes = _action_frames
	texture = action
	_action_duration = maxf(0.01, duration)
	_action_time_left = _action_duration
	_apply_frame()

## Cuts a running action (e.g. a cancelled charge) back to the base pose.
func stop_action() -> void:
	if _action_time_left <= 0.0:
		return
	_action_time_left = 0.0
	texture = _base_texture
	hframes = _base_frames
	_apply_frame()

func is_playing_action() -> bool:
	return _action_time_left > 0.0

func _process(delta: float) -> void:
	if _action_time_left > 0.0:
		_action_time_left -= delta
		if _action_time_left <= 0.0:
			texture = _base_texture
			hframes = _base_frames
		_apply_frame()
		return
	var animating := is_moving or _showing_idle
	if not animating or frames_per_direction <= 1:
		return
	_animation_clock += delta
	var frame_duration := 1.0 / animation_fps
	while _animation_clock >= frame_duration:
		_animation_clock -= frame_duration
		animation_frame = (animation_frame + 1) % frames_per_direction
		_apply_frame()

func _apply_frame() -> void:
	if _action_time_left > 0.0:
		var progress := 1.0 - _action_time_left / _action_duration
		frame = direction_index * _action_frames + mini(_action_frames - 1, int(progress * _action_frames))
		return
	frame = direction_index * frames_per_direction + animation_frame
