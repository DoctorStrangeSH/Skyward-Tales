extends Node
class_name DayNight

## Day and night on the surface: a full day takes 12 minutes. Dawn and dusk
## tint the world warm, night turns it blue and lights fireflies. At night
## enemies hit harder and have more health, but give more experience and
## gold. Lands that are always night (the grove) and the underground keep
## their own light.

const CYCLE := 720.0
const KEYS := [
	[0.0, Color(0.42, 0.48, 0.78)],
	[0.18, Color(0.46, 0.52, 0.8)],
	[0.25, Color(1.0, 0.8, 0.7)],
	[0.32, Color(1, 1, 1)],
	[0.68, Color(1, 1, 1)],
	[0.75, Color(1.0, 0.76, 0.6)],
	[0.82, Color(0.5, 0.52, 0.8)],
	[1.0, Color(0.42, 0.48, 0.78)],
]
const CYCLING_STYLES := ["day", "coast", "mountain", "sky", "spires", "marsh", "ash"]

var game: SkywardGame
## 0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk.
var time: float = 0.36
var paused: bool = false
var canvas: CanvasModulate
var fireflies: CPUParticles2D
var _was_night: bool = false
var _region: String = ""

func _ready() -> void:
	canvas = CanvasModulate.new()
	canvas.name = "DayNightTint"
	game.add_child(canvas)
	_was_night = is_night()

func _process(delta: float) -> void:
	if game == null or game.get_tree().paused:
		return
	if not paused:
		time = fmod(time + delta / CYCLE, 1.0)
	if _region != game.current_region:
		_region = game.current_region
		_rebuild_fireflies()
	var applies := cycles_here()
	canvas.color = tint() if applies else Color.WHITE
	if fireflies != null:
		fireflies.emitting = applies and is_night()
	var night := applies and is_night()
	# Village lamps light up from dusk to dawn.
	var glow := 0.0
	if applies:
		glow = clampf(1.0 - canvas.color.g, 0.0, 0.6) * 1.8
	for light in game.get_tree().get_nodes_in_group("night_lights"):
		(light as PointLight2D).energy = glow
	if night != _was_night:
		_was_night = night
		if night:
			game.hud.show_message("Наступает ночь: враги сильнее, но опыт и золото щедрее.", 3.5)
		elif applies:
			game.hud.show_message("Рассвет. Небо светлеет.", 2.5)

func cycles_here() -> bool:
	return RegionCatalog.style(game.current_region) in CYCLING_STYLES

func is_night() -> bool:
	return time >= 0.8 or time < 0.22

## Night counts only where the sky is seen.
func night_here() -> bool:
	return cycles_here() and is_night()

func phase_name() -> String:
	if time < 0.22 or time >= 0.8:
		return "Ночь"
	if time < 0.32:
		return "Рассвет"
	if time < 0.7:
		return "День"
	return "Закат"

func tint() -> Color:
	for index in range(KEYS.size() - 1):
		var a: Array = KEYS[index]
		var b: Array = KEYS[index + 1]
		if time >= float(a[0]) and time <= float(b[0]):
			var t := (time - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			return (a[1] as Color).lerp(b[1] as Color, t)
	return Color.WHITE

func _rebuild_fireflies() -> void:
	if fireflies != null and is_instance_valid(fireflies):
		fireflies.queue_free()
	fireflies = null
	if game.world == null or not game.world.has_method("map_size"):
		return
	var size: Vector2 = game.world.map_size()
	fireflies = CPUParticles2D.new()
	fireflies.name = "NightFireflies"
	fireflies.amount = int(clampf(size.x * size.y / 9000.0, 60, 260))
	fireflies.lifetime = 6.0
	fireflies.preprocess = 6.0
	fireflies.emitting = false
	fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fireflies.emission_rect_extents = size * 0.5
	fireflies.position = size * 0.5
	fireflies.direction = Vector2.UP
	fireflies.spread = 180.0
	fireflies.gravity = Vector2.ZERO
	fireflies.initial_velocity_min = 2.0
	fireflies.initial_velocity_max = 7.0
	fireflies.scale_amount_min = 1.0
	fireflies.scale_amount_max = 2.0
	var glow := Gradient.new()
	glow.set_color(0, Color(1.0, 0.95, 0.5, 0.0))
	glow.add_point(0.5, Color(1.0, 0.95, 0.55, 1.0))
	glow.set_color(glow.get_point_count() - 1, Color(1.0, 0.9, 0.4, 0.0))
	fireflies.color_ramp = glow
	fireflies.z_index = 55
	# Fireflies glow through the night tint.
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fireflies.material = material
	game.add_child(fireflies)

func make_snapshot() -> Dictionary:
	return {"time": time}

func restore_snapshot(data: Variant) -> void:
	if data is Dictionary:
		time = clampf(float(data.get("time", time)), 0.0, 1.0)
