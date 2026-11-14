extends Node
class_name Seasons

## The year (stage 21, step 4; этап 24 — like Stardew Valley: 28 days a
## season, weeks of 7 days): four seasons of LENGTH days each, starting
## in summer. In the homelands (styles "day" and "haven") the trees change
## (art: assets/world_hd/season_*), the ground gets a seasonal veil and
## details, leaves / snow / petals drift in the air. The garden feels it too
## (scripts/farm.gd): spring grows faster, autumn gives a richer harvest,
## in winter outdoor beds sleep — only the greenhouse works.

const LENGTH := 28
const WEEK := 7
const WEEKDAYS := ["понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье"]
const WEEKDAYS_SHORT := ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
const ORDER := ["summer", "autumn", "winter", "spring"]
const NAMES := {"summer": "Лето", "autumn": "Осень", "winter": "Зима", "spring": "Весна"}
const ANNOUNCE := {
	"summer": "Лето: долгие тёплые дни.",
	"autumn": "Осень: урожай на грядках щедрее (+1).",
	"winter": "Зима: грядки под снегом спят — растёт только в теплице.",
	"spring": "Весна: на грядках всё растёт на четверть быстрее.",
}
const SEASONAL_STYLES := ["day", "haven"]
const VEIL := {"autumn": Color(0.9, 0.5, 0.1, 0.2), "winter": Color(0.93, 0.96, 1.0, 0.6), "spring": Color(0.7, 1.0, 0.6, 0.05)}
const DRIFT := {
	"autumn": [Color(0.95, 0.55, 0.15), Color(0.85, 0.3, 0.12), 26, 2.2],
	"winter": [Color(1, 1, 1), Color(0.85, 0.92, 1.0), 70, 1.4],
	"spring": [Color(1.0, 0.75, 0.85), Color(1.0, 0.95, 0.98), 22, 1.8],
}
const HD := "res://assets/world_hd/"

var game: SkywardGame
var _shown: String = ""
var _region: String = ""
var _layer: Node2D
var _drift: CPUParticles2D

static func weekday_of(day: int) -> int:
	return posmod(day, WEEK)

static func season_of(day: int) -> String:
	return ORDER[(maxi(day, 0) / LENGTH) % ORDER.size()]

func current() -> String:
	return season_of(game.day_night.day)

func current_name() -> String:
	return str(NAMES[current()])

## Days until the next season.
func days_left() -> int:
	return LENGTH - maxi(game.day_night.day, 0) % LENGTH

## True in lands that live by the calendar.
func here() -> bool:
	return RegionCatalog.style(game.current_region) in SEASONAL_STYLES

func _process(_delta: float) -> void:
	if game == null or game.world == null:
		return
	var season := current()
	if season != _shown or _region != game.current_region or not is_instance_valid(_layer):
		var announce := not _shown.is_empty() and season != _shown
		_shown = season
		_region = game.current_region
		apply()
		if announce:
			game.hud.show_title_card(str(NAMES[season]), 2.4)
			game.hud.show_message(str(ANNOUNCE[season]), 4.5)
	if is_instance_valid(_drift):
		var camera := get_viewport().get_camera_2d()
		if camera != null:
			_drift.global_position = camera.get_screen_center_position() + Vector2(40, -60)

## The tree art for this season ("" — the land's own tree).
static func tree_file(season: String, style: String, variant: int, at: Vector2) -> String:
	var roll := absi(int(at.x) * 31 + int(at.y) * 17) % 10
	match season:
		"autumn":
			return "" if roll == 0 else "season_autumn_tree_%d.png" % (variant % 2)
		"winter":
			return "season_winter_tree_%d.png" % (variant % 2)
		"spring":
			return "season_spring_tree_%d.png" % (variant % 2) if style == "day" and roll < 4 else ""
	return ""

## Dresses the current land for the season (safe to call again).
func apply() -> void:
	var world := game.world
	if is_instance_valid(_layer):
		_layer.free()
	_layer = Node2D.new()
	_layer.name = "SeasonLayer"
	world.add_child(_layer)
	_drift = null
	var season := current() if here() else "summer"
	var manifest: Dictionary = world.get("art_manifest")
	var style := RegionCatalog.style(game.current_region)
	for node in world.get_children():
		if not (node is Sprite2D) or not node.has_meta("season_tree"):
			continue
		var info: Array = node.get_meta("season_tree")
		var file := tree_file(season, style, int(info[1]), info[2])
		if file.is_empty() or not ResourceLoader.exists(HD + file):
			file = str(info[0])
		var sprite := node as Sprite2D
		var texture: Texture2D = load(HD + file)
		if texture == null or sprite.texture == texture:
			continue
		sprite.texture = texture
		var origin: Variant = manifest.get("world_hd/" + file, {}).get("origin", [texture.get_width() / 2, texture.get_height()])
		sprite.offset = -Vector2(float(origin[0]), float(origin[1]))
	if season == "summer":
		return
	var size: Vector2 = world.call("map_size")
	var veil := ColorRect.new()
	veil.color = VEIL[season]
	veil.size = size
	veil.z_index = -99
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(veil)
	# Fallen leaves, snow heaps, first flowers.
	var detail := HD + "props/season_%s_detail.png" % season
	if ResourceLoader.exists(detail):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(game.current_region + season)
		var texture: Texture2D = load(detail)
		for i in int(size.x * size.y / 26000.0):
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.scale = Vector2.ONE * 0.5 * rng.randf_range(0.8, 1.2)
			sprite.flip_h = rng.randf() < 0.5
			sprite.position = Vector2(rng.randf_range(20, size.x - 20), rng.randf_range(20, size.y - 20))
			sprite.z_index = -97
			_layer.add_child(sprite)
	var spec: Array = DRIFT[season]
	_drift = CPUParticles2D.new()
	_drift.amount = int(spec[2])
	_drift.lifetime = 9.0
	_drift.preprocess = 9.0
	_drift.local_coords = false
	_drift.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_drift.emission_rect_extents = Vector2(400, 230)
	_drift.direction = Vector2(-0.5, 1.0)
	_drift.spread = 18.0
	_drift.gravity = Vector2.ZERO
	_drift.initial_velocity_min = 14.0
	_drift.initial_velocity_max = 30.0
	_drift.scale_amount_min = float(spec[3]) * 0.6
	_drift.scale_amount_max = float(spec[3])
	_drift.angular_velocity_min = -90.0
	_drift.angular_velocity_max = 90.0
	var ramp := Gradient.new()
	ramp.set_color(0, spec[0])
	ramp.set_color(1, spec[1])
	_drift.color_initial_ramp = ramp
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 0.9))
	fade.add_point(0.85, Color(1, 1, 1, 0.9))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	_drift.color_ramp = fade
	_drift.z_index = 70
	_layer.add_child(_drift)
