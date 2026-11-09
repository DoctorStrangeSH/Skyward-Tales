extends "res://scripts/enemy.gd"
class_name Windtail

const DASH_TEXTURE := preload("res://assets/sprites/magic/windtail_dash_vfx.png")
const DASH_ANIMATION := &"dash"
static var _dash_frames: SpriteFrames
var dash_visual: AnimatedSprite2D

func _ready() -> void:
	max_health = 66
	move_speed = 64.0
	xp_reward = 32
	detection_radius = 160.0
	give_up_radius = 240.0
	attack_damage = 14
	attack_range = 82.0
	attack_cooldown_duration = 2.2
	attack_windup_duration = 0.55
	attack_lunge_duration = 0.27
	attack_lunge_speed = 315.0
	attack_hit_radius = 19.0
	elemental_multipliers = {"ice": 1.25, "lightning": 0.8}
	sprite_sheet = "res://assets/sprites/enemies/windtail_8dir.png"
	sprite_offset = Vector2(0, -18)
	sprite_fps = 10.0
	super._ready()

	if _dash_frames == null:
		_dash_frames = SpriteFrames.new()
		_dash_frames.add_animation(DASH_ANIMATION)
		_dash_frames.set_animation_speed(DASH_ANIMATION, 15.0)
		_dash_frames.set_animation_loop(DASH_ANIMATION, false)
		for index in range(6):
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = DASH_TEXTURE
			frame_texture.region = Rect2(index * 96, 0, 96, 96)
			_dash_frames.add_frame(DASH_ANIMATION, frame_texture)
	dash_visual = AnimatedSprite2D.new()
	dash_visual.name = "DashVisual"
	dash_visual.sprite_frames = _dash_frames
	dash_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dash_visual.scale = Vector2.ONE * 0.7
	dash_visual.hide()
	dash_visual.animation_finished.connect(dash_visual.hide)
	add_child(dash_visual)
	move_child(dash_visual, visual.get_index())

func _start_special_attack(direction: Vector2) -> void:
	visual.set_direction_vector(direction)
	super._start_special_attack(direction)

func _pose(kind: String, duration: float = 0.12) -> void:
	super._pose(kind, duration)
	if kind == "lunge":
		dash_visual.position = -attack_direction * 13.0 + Vector2(0, -9)
		dash_visual.rotation = attack_direction.angle()
		dash_visual.stop()
		dash_visual.show()
		dash_visual.play(DASH_ANIMATION)

func _cancel_special_attack() -> void:
	super._cancel_special_attack()
	if dash_visual != null and dash_visual.visible:
		dash_visual.stop()
		dash_visual.hide()

func _can_hit_lunge_target(player: Node2D) -> bool:
	return super._can_hit_lunge_target(player) and not _line_blocked(player.global_position)
