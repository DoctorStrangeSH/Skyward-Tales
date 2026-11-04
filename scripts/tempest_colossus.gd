extends "res://scripts/echo_warden.gd"
class_name TempestColossus

## Act II boss of the Wind Spires. Storm orbs like the Echo Warden; every few
## seconds a gust pushes the hero back. Enraged, it calls wind wisps.

const WISP_SCRIPT := preload("res://scripts/wind_wisp.gd")
const GUST_INTERVAL := 6.0
const GUST_RADIUS := 130.0
const GUST_PUSH := 56.0

var gust_in: float = GUST_INTERVAL

func _ready() -> void:
	super._ready()
	sprite_sheet = "res://assets/sprites/enemies/tempest_colossus_8dir.png"
	sprite_scale = 1.4
	visual.configure(sprite_sheet, 4, 8, sprite_scale, 5.0)
	visual.offset = Vector2(0.0, -20.0)
	combat_feedback.bar_y = -62.0
	elemental_multipliers = {"fire": 1.0, "ice": 1.3, "lightning": 0.6}
	max_health = 300
	health = max_health
	xp_reward = 220
	combat_feedback.set_health(health, max_health)

func take_damage(amount: int) -> void:
	var was_enraged := enraged
	super.take_damage(amount)
	if enraged and not was_enraged:
		# Storm-blue rage instead of the guardian's red.
		base_visual_tint = Color(0.92, 1.0, 1.15)
		visual.modulate = base_visual_tint

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	gust_in -= delta * (1.5 if enraged else 1.0)
	if gust_in <= 0.0:
		gust_in = GUST_INTERVAL
		gust()

## Pushes the hero away if close; returns true when the gust hit.
func gust() -> bool:
	var hero := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if hero == null or health <= 0:
		return false
	GameAudio.play("gust", -3.0, 0.05)
	Vfx.burst(get_parent(), global_position, [Color(1, 1, 1), Color(0.75, 0.92, 1.0)], 16, 120.0)
	var offset := hero.global_position - global_position
	if offset.length() > GUST_RADIUS:
		return false
	hero.move_and_collide((offset.normalized() if offset.length() > 1.0 else Vector2.DOWN) * GUST_PUSH)
	if get_parent().has_method("shake"):
		get_parent().shake(2.5, 0.25)
	return true

func _summon_bats() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if parent.has_method("shake"):
		parent.shake(4.0, 0.4)
	for offset in [Vector2(-44, -6), Vector2(44, -6)]:
		var wisp := WISP_SCRIPT.new() as SlimeEnemy
		wisp.position = global_position + offset
		parent.add_child(wisp)
		if parent.has_method("_on_enemy_defeated"):
			wisp.defeated.connect(func(xp: int) -> void: parent._on_enemy_defeated(xp, wisp.global_position))
		Vfx.sparkle(parent, wisp.global_position)
