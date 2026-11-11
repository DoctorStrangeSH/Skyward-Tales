extends Node2D
class_name CliffRim

## The southern rim of a floating land (stage 21, step 12): painted cliffs
## with a grassy lip, ivy and moss hanging over the edge, waterfalls with
## mist. Art: assets/world_hd/cliffs (tools/art/cliff_art.py). Built by
## world.gd for lands with an apron; gates (bridges) are left clear.

const DIR := "res://assets/world_hd/cliffs/"
const TILE := 240.0
## The grassy lip of the tile lies this many world pixels below its top.
const LIP := 14.0

var _animated: Array = []
var _clock: float = 0.0

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

func _sheet(file: String, at: Vector2, fps: float, z: int) -> Sprite2D:
	var sprite := _sprite(file, at, z)
	sprite.hframes = 6
	sprite.vframes = 4
	_animated.append([sprite, fps, randf() * 24.0])
	return sprite

## `gaps` — x positions of bridges on the southern edge.
func setup(map_size: Vector2, region_id: String, gaps: Array = []) -> void:
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
	# Waterfalls.
	var falls := maxi(2, int(map_size.x / 420.0))
	for i in falls:
		var fx := (i + rng.randf_range(0.25, 0.75)) / falls * map_size.x
		var clear := true
		for gap in gaps:
			clear = clear and absf(float(gap) - fx) > 90.0
		if not clear:
			continue
		_sheet("waterfall.png", Vector2(fx - 13.0, map_size.y - 6.0), 12.0, 2)
		_sheet("mist.png", Vector2(fx - 22.0, map_size.y + 74.0), 8.0, 3).modulate.a = 0.85

func _process(delta: float) -> void:
	_clock += delta
	for entry in _animated:
		var sprite: Sprite2D = entry[0]
		sprite.frame = int(_clock * float(entry[1]) + float(entry[2])) % 24
