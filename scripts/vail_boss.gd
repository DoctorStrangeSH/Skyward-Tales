extends "res://scripts/grove_guardian.gd"
class_name VailBoss

## Act II finale: Vail himself. Volleys of shadow orbs and blinks around the
## hero; at half health he calls two shades and fires rings of orbs.

const SHADE_SCRIPT := preload("res://scripts/rift_shade.gd")
const BLINK_INTERVAL := 4.5
const RING_INTERVAL := 6.0

var blink_in: float = BLINK_INTERVAL
var ring_in: float = RING_INTERVAL
var home: Vector2

func _ready() -> void:
	sprite_sheet = "res://assets/sprites/enemies/vail_8dir.png"
	sprite_scale = 1.5
	sprite_offset = Vector2(0.0, -14.0)
	super._ready()
	# GroveGuardian picks its own sheet in _ready; swap in Vail afterwards.
	sprite_sheet = "res://assets/sprites/enemies/vail_8dir.png"
	sprite_offset = Vector2(0.0, -14.0)
	visual.configure(sprite_sheet, 4, 8, sprite_scale, 6.0)
	visual.offset = sprite_offset
	home = global_position
	elemental_multipliers = {"fire": 1.0, "ice": 1.0, "lightning": 1.0}
	max_health = 420
	health = max_health
	xp_reward = 320
	move_speed = 34.0
	combat_feedback.bar_y = -40.0
	combat_feedback.set_health(health, max_health)

func take_damage(amount: int) -> void:
	var was_enraged := enraged
	super.take_damage(amount)
	if enraged and not was_enraged and health > 0:
		base_visual_tint = Color(1.0, 0.85, 1.25)
		visual.modulate = base_visual_tint
		_summon_shades()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if health <= 0 or is_queued_for_deletion():
		return
	blink_in -= delta * (1.5 if enraged else 1.0)
	if blink_in <= 0.0:
		blink_in = BLINK_INTERVAL
		blink()
	if enraged:
		ring_in -= delta
		if ring_in <= 0.0:
			ring_in = RING_INTERVAL
			ring()

func blink() -> bool:
	var hero := get_tree().get_first_node_in_group("player") as Node2D
	if hero == null:
		return false
	var spot := hero.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 150.0
	spot = home + (spot - home).limit_length(240.0)
	Vfx.burst(get_parent(), global_position, [Color(0.75, 0.55, 1.0), Color(0.25, 0.15, 0.4)], 16, 90.0)
	global_position = spot
	Vfx.burst(get_parent(), global_position, [Color(0.9, 0.8, 1.0), Color(0.4, 0.25, 0.6)], 16, 90.0)
	return true

## Eight orbs in every direction.
func ring() -> void:
	GameAudio.play("cast_lightning", -4.0, 0.0)
	for i in range(8):
		var orb := ORB_SCRIPT.new() as EnemyMagicOrb
		orb.setup(Vector2.RIGHT.rotated(TAU * i / 8.0), 11)
		orb.global_position = global_position
		get_parent().add_child(orb)

func _summon_shades() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if parent.has_method("shake"):
		parent.shake(4.0, 0.4)
	for offset in [Vector2(-60, 10), Vector2(60, 10)]:
		var shade := SHADE_SCRIPT.new() as SlimeEnemy
		shade.position = global_position + offset
		parent.add_child(shade)
		if parent.has_method("_on_enemy_defeated"):
			shade.defeated.connect(func(xp: int) -> void: parent._on_enemy_defeated(xp, shade.global_position))
		Vfx.sparkle(parent, shade.global_position)
