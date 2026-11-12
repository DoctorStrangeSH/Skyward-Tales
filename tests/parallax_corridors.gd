extends SceneTree
const SkyLayer = preload("res://scripts/sky_parallax.gd")
func _initialize() -> void:
	var sky = SkyLayer.new()
	sky._size = Vector2(1920, 1280)
	var sprite := Sprite2D.new()
	var image := Image.create(200, 160, false, Image.FORMAT_RGBA8)
	sprite.texture = ImageTexture.create_from_image(image)
	var checks := 0
	for horizontal in [true, false]:
		for reverse in [false, true]:
			sky.bridge_corridors.clear()
			for coordinate in [100, 250, 400]:
				sky.bridge_corridors.append(Rect2(-480, coordinate, 600, 128) if horizontal else Rect2(coordinate, -480, 128, 600))
			if reverse:
				sky.bridge_corridors.reverse()
			for coordinate in range(-200, 900, 11):
				var base := Vector2(-70, coordinate) if horizontal else Vector2(coordinate, -70)
				var item := {"node": sprite, "base": base, "depth": 0.18, "island": true}
				for view in [Vector2.ZERO, Vector2(960, 640), Vector2(2030, 1428)]:
					var at: Vector2 = sky.projected_position(item, view)
					var half := sprite.texture.get_size() * 0.5 + Vector2.ONE * 14
					var bounds := Rect2(at - half, half * 2)
					for corridor in sky.bridge_corridors:
						if bounds.intersects(corridor, true):
							push_error("island overlaps a bridge")
							quit(1)
							return
					if bounds.intersects(Rect2(Vector2.ZERO, sky._size)):
						push_error("island overlaps terrain")
						quit(1)
						return
					if sky.projected_position(item, view) != at:
						quit(1)
						return
					checks += 1
	sprite.free()
	sky.free()
	print("PARALLAX CORRIDORS OK: ", checks)
	quit(0)
