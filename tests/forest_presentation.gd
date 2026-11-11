extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("FOREST PRESENTATION FAILED: " + message)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var terrain := RegionCatalog.terrain("greenreach")
	var trees: Array = terrain["trees"]
	var variants: Array = terrain.get("tree_variants", [])
	if variants.size() != trees.size() or trees.size() < 100:
		return _fail("authored trees and species stay in sync")
	var sky := game.world.get_node("SkyParallax") as SkyParallax
	if sky.bridge_corridors.size() != 3:
		return _fail("three outer bridge mouths, no corridors for dungeon entrances")
	# Exercise camera corners and interior, including the full parallax excursion.
	for x in [-110, 0, 960, 1920, 2030]:
		for y in [-110, 0, 640, 1280, 1428]:
			for item in sky.items:
				if not bool(item.get("island", false)):
					continue
				var sprite := item["node"] as Sprite2D
				var at := sky.projected_position(item, Vector2(x, y))
				var size := sprite.texture.get_size() * sprite.scale
				var bounds := Rect2(at - size * 0.5, size)
				if bounds.intersects(Rect2(Vector2.ZERO, Vector2(1920, 1280))):
					return _fail("a far island slides onto the foreground land")
				for corridor in sky.bridge_corridors:
					if bounds.intersects(corridor):
						return _fail("a far island crosses a near bridge")
	for kind in ["wood", "stone", "iron", "copper"]:
		var resource := GatherNode.new()
		resource.kind = kind
		resource.key = "presentation:" + kind
		game.add_child(resource)
		resource.position = Vector2(1100, 800)
		resource.set_ready(false)
		if kind == "wood":
			resource.set_stage("young")
			if resource.growth_sheet == null:
				return _fail("the planted sapling animates")
		resource.set_ready(true)
		if resource.growth_sheet == null:
			return _fail("regrowth animation is missing: " + kind)
		var anchor := resource.position
		await process_frame
		paused = true
		var clock := resource.growth_clock
		await process_frame
		await process_frame
		if resource.growth_clock != clock:
			return _fail("growth ignores pause")
		paused = false
		resource._process(2.0)
		if resource.growth_sheet != null or resource.position != anchor or resource.scale != Vector2.ONE or resource.stage != "ready":
			return _fail("growth must finish on the original rooted drawing")
		resource.queue_free()
	print("FOREST PRESENTATION OK")
	quit(0)
