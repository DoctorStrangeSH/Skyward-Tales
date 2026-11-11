extends "res://scripts/forest_wolf.gd"
class_name CoastCrab

## Salt Coast crab: scuttles close, then snaps forward (the wolf's lunge).
## An ambusher: it waits buried — only a little mound shows — and bursts out
## when the hero steps within EMERGE_RANGE (or when anything hits the mound).
## Watch the ground, strike the mound first or lure it out and step back.

const EMERGE_RANGE := 54.0
var buried: bool = true

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/coast_crab_8dir.png"
	visual.configure(sprite_sheet, 4, 8, 1.0, 8.0)
	visual.offset = Vector2(0.0, -10.0)
	max_health = 34
	health = max_health
	move_speed = 44.0
	xp_reward = 20
	attack_damage = 8
	attack_lunge_speed = 240.0
	elemental_multipliers = {"fire": 0.8, "ice": 1.0, "lightning": 1.3}
	combat_feedback.set_health(health, max_health)
	_set_buried(buried)

func _set_buried(value: bool) -> void:
	buried = value
	visual.visible = not value
	combat_feedback.visible = not value
	queue_redraw()

## Out of the sand, straight into a snap.
func emerge() -> void:
	if not buried:
		return
	_set_buried(false)
	_pose("lunge")
	combat_feedback.show_reaction("ЗАСАДА!")
	GameAudio.play("dash", -4.0, 0.2)
	Vfx.burst(get_parent(), global_position, [Color(0.95, 0.88, 0.65), Color(0.8, 0.7, 0.5), Color(0.7, 0.6, 0.4, 0)], 10, 60.0, 0.4)
	attack_cooldown = 0.0

func _physics_process(delta: float) -> void:
	if buried:
		velocity = Vector2.ZERO
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(global_position) <= EMERGE_RANGE:
			emerge()
		return
	super._physics_process(delta)

func take_damage(amount: int) -> void:
	if buried:
		emerge()
	super.take_damage(amount)

func _shape_chase(direction: Vector2, _delta: float) -> Vector2:
	# Crabs do not hunt in packs.
	return direction

func _draw() -> void:
	super._draw()
	if buried:
		# A mound of sand with two eye-stalks.
		draw_circle(Vector2(0, -2), 7.0, Color(0.78, 0.68, 0.48, 0.9))
		draw_circle(Vector2(-1, -4), 5.0, Color(0.88, 0.8, 0.6, 0.9))
		draw_line(Vector2(-3, -6), Vector2(-3, -10), Color(0.75, 0.35, 0.25), 1.0)
		draw_line(Vector2(3, -6), Vector2(3, -10), Color(0.75, 0.35, 0.25), 1.0)
		draw_circle(Vector2(-3, -10), 1.0, Color(0.1, 0.1, 0.1))
		draw_circle(Vector2(3, -10), 1.0, Color(0.1, 0.1, 0.1))
