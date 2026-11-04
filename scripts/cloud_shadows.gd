extends Node2D

## Soft shadows of clouds passing over the island: a quiet reminder that
## the sky is all around.

var area := Rect2()
var shadows: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(area.size.x + area.size.y * 3)
	var count := int(area.get_area() / 260000.0) + 3
	for index in count:
		var blobs: Array = []
		for i in rng.randi_range(4, 7):
			blobs.append([Vector2(rng.randf_range(-50, 50), rng.randf_range(-16, 16)), rng.randf_range(22, 40)])
		shadows.append({"pos": Vector2(rng.randf_range(0, area.size.x), rng.randf_range(0, area.size.y)), "speed": rng.randf_range(6.0, 12.0), "blobs": blobs})

func _process(delta: float) -> void:
	for shadow in shadows:
		shadow["pos"] += Vector2(1.0, 0.25) * float(shadow["speed"]) * delta
		if shadow["pos"].x > area.end.x + 120.0:
			shadow["pos"] = Vector2(area.position.x - 120.0, fmod(shadow["pos"].y, area.size.y))
		if shadow["pos"].y > area.end.y + 60.0:
			shadow["pos"].y = area.position.y - 60.0
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	for shadow in shadows:
		for blob in shadow["blobs"]:
			var at: Vector2 = shadow["pos"] + blob[0]
			draw_circle(Vector2(at.x, at.y / 0.6), float(blob[1]), Color(0.05, 0.1, 0.2, 0.07))
