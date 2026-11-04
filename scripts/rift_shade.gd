extends "res://scripts/forest_shaman.gd"
class_name RiftShade

## Vail's echo on the Shattered Isle: a shadow caster that blinks to a new
## spot near the hero every few seconds. Light hurts it, frost barely does.

const BLINK_INTERVAL := 5.0
const BLINK_DISTANCE := 120.0

var blink_in: float = BLINK_INTERVAL
var home: Vector2

func _ready() -> void:
	sprite_sheet = "res://assets/sprites/enemies/rift_shade_8dir.png"
	sprite_fps = 6.0
	super._ready()
	home = global_position
	max_health = 44
	health = max_health
	xp_reward = 36
	elemental_multipliers = {"fire": 1.0, "ice": 0.75, "lightning": 1.35}
	base_visual_tint = Color(1, 1, 1, 0.92)
	visual.modulate = base_visual_tint
	combat_feedback.set_health(health, max_health)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if health <= 0 or is_queued_for_deletion():
		return
	blink_in -= delta
	if blink_in <= 0.0:
		blink_in = BLINK_INTERVAL * randf_range(0.8, 1.2)
		blink()

## Vanishes and reappears near the hero (but never far from home).
func blink() -> bool:
	var hero := get_tree().get_first_node_in_group("player") as Node2D
	if hero == null or hero.global_position.distance_to(global_position) > detection_radius:
		return false
	var spot := hero.global_position + Vector2.RIGHT.rotated(randf() * TAU) * BLINK_DISTANCE
	spot = home + (spot - home).limit_length(220.0)
	Vfx.burst(get_parent(), global_position, [Color(0.55, 0.4, 0.9), Color(0.2, 0.12, 0.35)], 10, 60.0)
	global_position = spot
	Vfx.burst(get_parent(), global_position, [Color(0.75, 0.6, 1.0), Color(0.3, 0.2, 0.5)], 10, 60.0)
	return true
