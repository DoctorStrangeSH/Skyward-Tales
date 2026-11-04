extends Node2D
class_name FlameVent

## Fire vent in the Forge Depths: smoulders, glows as a warning, then
## erupts in a column of flame. Standing in it burns; rolling through is safe.

const IDLE_TIME := 2.2
const WARN_TIME := 0.6
const FIRE_TIME := 1.0
const DAMAGE := 14
const RADIUS := 13.0

var clock: float = 0.0
var state: String = "idle"
var _hit_cooldown: float = 0.0
var _flames: CPUParticles2D

func _ready() -> void:
	z_index = -40
	clock = fmod(global_position.x * 0.017 + global_position.y * 0.011, IDLE_TIME + WARN_TIME + FIRE_TIME)
	_flames = CPUParticles2D.new()
	_flames.emitting = false
	_flames.amount = 26
	_flames.lifetime = 0.5
	_flames.direction = Vector2.UP
	_flames.spread = 14.0
	_flames.gravity = Vector2(0, -60)
	_flames.initial_velocity_min = 30.0
	_flames.initial_velocity_max = 60.0
	_flames.scale_amount_min = 2.0
	_flames.scale_amount_max = 3.5
	_flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.6))
	ramp.add_point(0.4, Color(1.0, 0.55, 0.15))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.5, 0.1, 0.05, 0.0))
	_flames.color_ramp = ramp
	_flames.z_index = 60
	_flames.z_as_relative = false
	add_child(_flames)
	queue_redraw()

func _process(delta: float) -> void:
	var cycle := IDLE_TIME + WARN_TIME + FIRE_TIME
	clock = fmod(clock + delta, cycle)
	var now := "idle" if clock < IDLE_TIME else ("warn" if clock < IDLE_TIME + WARN_TIME else "fire")
	if now != state:
		state = now
		_flames.emitting = state == "fire"
		queue_redraw()
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if state == "fire" and _hit_cooldown <= 0.0:
		var hero := get_tree().get_first_node_in_group("player") as PlayerCharacter
		if hero != null and hero.global_position.distance_to(global_position) < RADIUS:
			hero.take_damage(DAMAGE)
			_hit_cooldown = 0.7

func is_dangerous() -> bool:
	return state == "fire"

func _draw() -> void:
	WorldArt.draw_prop(self, "props/vent_active.png" if state != "idle" else "props/vent_idle.png")
	if state == "warn":
		draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.5, 0.15, 0.18))
	elif state == "fire":
		draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.6, 0.2, 0.3))
