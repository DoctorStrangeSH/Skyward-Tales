extends Node2D

## Loose clouds drifting slowly beneath the island (drawn under the ground,
## so they only show over the sky around it).

var area := Rect2()
var night := false
var count := 14
var speed_scale := 1.0
var clouds: Array = []
var textures: Array = []
var _hd := false

func _ready() -> void:
	for variant in 3:
		var path := "world/cloud_puff_%s_%d.png" % ["night" if night else "day", variant]
		var hd := WorldArt.hd_path(path)
		_hd = _hd or not hd.is_empty()
		var texture := WorldArt.texture(hd if not hd.is_empty() else path)
		if texture != null:
			textures.append(texture)
	if textures.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(area.size.x * 7 + area.size.y)
	for index in count:
		clouds.append({
			"pos": Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y)),
			"speed": rng.randf_range(4.0, 11.0) * speed_scale,
			"texture": textures[index % textures.size()],
			"alpha": rng.randf_range(0.55, 0.9),
		})

func _process(delta: float) -> void:
	for cloud in clouds:
		cloud["pos"].x += float(cloud["speed"]) * delta
		if cloud["pos"].x > area.end.x + 60.0:
			cloud["pos"].x = area.position.x - 60.0
	queue_redraw()

func _draw() -> void:
	if _hd:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.5, 0.5))
	for cloud in clouds:
		var texture: Texture2D = cloud["texture"]
		var at: Vector2 = cloud["pos"] * (2.0 if _hd else 1.0)
		draw_texture(texture, at - texture.get_size() * 0.5, Color(1, 1, 1, float(cloud["alpha"])))
