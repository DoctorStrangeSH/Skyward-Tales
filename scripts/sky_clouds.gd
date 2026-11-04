extends Node2D

## Loose clouds drifting slowly beneath the island (drawn under the ground,
## so they only show over the sky around it).

var area := Rect2()
var night := false
var clouds: Array = []
var textures: Array = []

func _ready() -> void:
	for variant in 3:
		var texture := WorldArt.texture("world/cloud_puff_%s_%d.png" % ["night" if night else "day", variant])
		if texture != null:
			textures.append(texture)
	if textures.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(area.size.x * 7 + area.size.y)
	for index in 14:
		clouds.append({
			"pos": Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y)),
			"speed": rng.randf_range(4.0, 11.0),
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
	for cloud in clouds:
		var texture: Texture2D = cloud["texture"]
		draw_texture(texture, cloud["pos"] - texture.get_size() * 0.5, Color(1, 1, 1, float(cloud["alpha"])))
