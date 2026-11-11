extends Node2D
class_name CliffRim

## The southern rim of a floating land (stage 21, step 12): painted cliffs
## with a grassy lip, ivy and moss hanging over the edge, waterfalls with
## clouds. Art: assets/world_hd/cliffs (tools/art/cliff_art.py). Built by
## world.gd for lands with an apron; gates (bridges) are left clear.

const DIR := "res://assets/world_hd/cliffs/"
const TILE := 240.0
## The grassy lip of the tile lies this many world pixels below its top.
const LIP := 14.0

static func available() -> bool:
	return ResourceLoader.exists(DIR + "cliff_high.png")

func _sprite(file: String, at: Vector2, z: int = 0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(DIR + file)
	sprite.centered = false
	sprite.scale = Vector2.ONE * 0.5
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = at
	sprite.z_index = z
	add_child(sprite)
	return sprite

## `gaps` — x positions of bridges on the southern edge.
## Outlets are authored in terrain.waterfalls. No random streams from dry grass.
func setup(map_size: Vector2, region_id: String, gaps: Array = [], outlets: Array = []) -> void:
	z_index = -99
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region_id + "rim")
	var count := int(ceil((map_size.x + 80.0) / (TILE - 12.0)))
	for i in count:
		var x := -40.0 + i * (TILE - 12.0)
		var tile := _sprite("cliff_high.png" if rng.randf() < 0.75 else "cliff_low.png", Vector2(x, map_size.y - LIP))
		tile.flip_h = rng.randf() < 0.5
	# Greenery over the edge.
	var x := rng.randf_range(10.0, 60.0)
	while x < map_size.x - 30.0:
		var file: String = ["ivy_a.png", "ivy_b.png", "moss.png", "ivy_a.png"][rng.randi() % 4]
		_sprite(file, Vector2(x, map_size.y - 8.0 + rng.randf_range(0.0, 6.0)), 1).flip_h = rng.randf() < 0.5
		x += rng.randf_range(70.0, 170.0)
	# Explicit springs in the cliff face; the stream disappears into the clouds.
	for outlet in outlets:
		var fx := float(outlet.get("x", map_size.x * 0.5))
		if fx < 32.0 or fx > map_size.x - 32.0:
			continue
		var clear := true
		for gap in gaps:
			clear = clear and absf(float(gap) - fx) > 90.0
		if not clear:
			continue
		var fall := IslandWaterfall.new()
		fall.name = "Waterfall_%d" % get_child_count()
		fall.position = Vector2(fx, map_size.y - 6.0)
		fall.z_index = 2
		fall.setup(float(outlet.get("width", 20.0)), float(outlet.get("drop", 180.0)), rng.randf_range(0.0, 2.0))
		add_child(fall)
