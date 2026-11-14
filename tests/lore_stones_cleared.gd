extends SceneTree

## Этап 24 (the bot found it): rune stones belong to their land — changing
## lands takes them away; a stone of Greenreach must not wait in the Spires.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("LORE STONES FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	for region in ["haven", "wind_spires", "greenreach"]:
		game._set_region(region, Vector2(600, 500), false)
		for i in 4:
			await process_frame
		var expected: Array = RegionCatalog.get_region(region).get("lore", []).map(func(l: Dictionary) -> String: return str(l["id"]))
		for node in game.get_children():
			if node is LoreStone and not node.is_queued_for_deletion() and not expected.has(node.lore_id):
				return _fail("a stone of another land in %s: %s" % [region, node.lore_id])
	print("LORE STONES OK")
	quit()
