extends Node2D
class_name SkyParallax

## Far islands and clouds in the sky around a floating land (stage 21,
## art: the owner's sky_harbor/parallax set in assets/world_hd/sky). They
## sit in the band of sky the camera can see past the rim and shift a
## little with the camera — the farther, the less — so the sky has depth;
## clouds also drift with the wind. Placement is fixed per land.

const DIR := "res://assets/world_hd/sky/"
const ISLANDS := ["castle_island", "windmill_island", "linked_islets"]
const CLOUDS := ["cloud_bank", "cloud_tower", "cloud_wisp"]
## Lands whose sky is not a clear day sky get clouds only, tinted.
const TINTS := {"marsh": Color(0.8, 0.82, 0.78), "ash": Color(0.5, 0.42, 0.4), "rift": Color(0.7, 0.6, 0.9), "night": Color(0.75, 0.8, 1.0)}
const NO_ISLANDS := ["marsh", "ash", "rift"]

var items: Array = []
var _size := Vector2.ZERO

func setup(map_size: Vector2, region_id: String, style: String) -> void:
	_size = map_size
	z_index = -109
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("sky:" + region_id)
	var tint: Color = TINTS.get(style, Color.WHITE)
	# Islands: beside and above the land (the cliffs hang below it).
	if style not in NO_ISLANDS:
		# One island per stretch of rim, so every edge of the land has a
		# neighbour in view somewhere.
		var spots: Array = []
		var rows := maxi(1, int(map_size.y / 420.0))
		for r in rows:
			var y := (r + rng.randf_range(0.3, 0.7)) / rows * map_size.y
			spots.append(Vector2(-rng.randf_range(58, 92), y))
			spots.append(Vector2(map_size.x + rng.randf_range(58, 92), (r + rng.randf_range(0.3, 0.7)) / rows * map_size.y))
		var cols := maxi(1, int(map_size.x / 520.0))
		for c in cols:
			spots.append(Vector2((c + rng.randf_range(0.3, 0.7)) / cols * map_size.x, -rng.randf_range(54, 84)))
		for i in spots.size():
			_add(str(ISLANDS[(i + rng.randi()) % ISLANDS.size()]), spots[i], rng.randf_range(0.2, 0.28), rng.randf_range(0.08, 0.18), 0.0, tint.lerp(Color(0.78, 0.88, 1.0), 0.28))
	# Clouds all around, lower ones under the land's foot.
	for i in 12:
		var edge := rng.randi() % 4
		var at := Vector2.ZERO
		match edge:
			0: at = Vector2(-rng.randf_range(30, 130), rng.randf() * map_size.y)
			1: at = Vector2(map_size.x + rng.randf_range(30, 130), rng.randf() * map_size.y)
			2: at = Vector2(rng.randf() * map_size.x, -rng.randf_range(30, 120))
			3: at = Vector2(rng.randf() * map_size.x, map_size.y + rng.randf_range(100, 140))
		_add(str(CLOUDS[rng.randi() % CLOUDS.size()]), at, rng.randf_range(0.22, 0.4), rng.randf_range(0.05, 0.3), rng.randf_range(1.5, 5.0), Color(tint.r, tint.g, tint.b, rng.randf_range(0.7, 0.95)))

func _add(art: String, at: Vector2, size: float, depth: float, drift: float, tint: Color) -> void:
	var path := DIR + art + ".png"
	if not ResourceLoader.exists(path):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.scale = Vector2.ONE * size
	sprite.modulate = tint
	sprite.position = at
	add_child(sprite)
	items.append({"node": sprite, "base": at, "depth": depth, "drift": drift})

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var view := camera.get_screen_center_position()
	for item in items:
		var base: Vector2 = item["base"]
		if float(item["drift"]) > 0.0:
			base.x += float(item["drift"]) * delta
			if base.x > _size.x + 190.0:
				base.x = -190.0
			item["base"] = base
		(item["node"] as Sprite2D).position = base + (view - base) * float(item["depth"])
