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
func setup(map_size: Vector2, region_id: String, gaps: Array = [], outlets: Array = [], outlet_scene: PackedScene = null, varied_depth: bool = false) -> void:
	z_index = -99
	var authored: Node2D
	var mouths: Array = outlets
	if outlet_scene != null:
		authored = outlet_scene.instantiate() as Node2D
		mouths = []
		if authored != null:
			for child in authored.get_children():
				if child is IslandWaterfall and _outlet_clear(child.position.x, child.stream_width, map_size.x, gaps):
					mouths.append({"x": child.position.x, "width": child.stream_width})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region_id + "rim")
	var count := int(ceil((map_size.x + 80.0) / (TILE - 12.0)))
	for i in count:
		var x := -40.0 + i * (TILE - 12.0)
		var tile := _sprite("cliff_high.png" if rng.randf() < 0.75 else "cliff_low.png", Vector2(x, map_size.y - LIP))
		tile.flip_h = rng.randf() < 0.5
		if varied_depth:
			var depth := rng.randf_range(0.78, 1.30)
			tile.scale.y *= depth
			# Anchor the grass lip while the lower silhouette changes depth.
			tile.position.y = map_size.y - LIP * depth
			for outlet in mouths:
				var mouth := float(outlet.get("x", -1000.0))
				var width := float(outlet.get("width", 64.0))
				if mouth + width * 0.5 > x and mouth - width * 0.5 < x + TILE:
					var cut := ShaderMaterial.new()
					cut.shader = load("res://assets/shaders/cliff_outlet.gdshader")
					cut.set_shader_parameter("outlet_x", mouth)
					cut.set_shader_parameter("outlet_width", width)
					cut.set_shader_parameter("rim_y", map_size.y)
					tile.material = cut
	# Greenery over the edge.
	var x := rng.randf_range(10.0, 60.0)
	while x < map_size.x - 30.0:
		var file: String = ["ivy_a.png", "ivy_b.png", "moss.png", "ivy_a.png"][rng.randi() % 4]
		_sprite(file, Vector2(x, map_size.y - 8.0 + rng.randf_range(0.0, 6.0)), 1).flip_h = rng.randf() < 0.5
		x += rng.randf_range(70.0, 170.0)
	# The authored scene is the source of truth when present, never an extra layer.
	if outlet_scene != null:
		if authored != null:
			authored.name = "AuthoredWaterfalls"
			authored.z_index = 2
			add_child(authored)
			for child in authored.get_children():
				if child is IslandWaterfall and not _outlet_clear(child.position.x, child.stream_width, map_size.x, gaps):
					child.queue_free()
			return
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
		fall.setup(float(outlet.get("width", 64.0)), float(outlet.get("drop", 240.0)), rng.randf_range(0.0, 2.0), float(outlet.get("speed", 1.0)))
		add_child(fall)

func _outlet_clear(x: float, width: float, map_width: float, gaps: Array) -> bool:
	if x - width * 0.5 < 0.0 or x + width * 0.5 > map_width:
		return false
	for gap in gaps:
		if absf(float(gap) - x) < maxf(90.0, width * 0.5 + 32.0):
			return false
	return true
