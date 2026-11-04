extends SceneTree

## Passages look like part of the world: bridges on the rim, cave mouths,
## daylight exits and ruin stairs; the prompt names the destination.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("REGION GATES TEST FAILED: " + reason)
	quit(1)

func _gate_kinds(game: SkywardGame) -> Dictionary:
	var kinds := {}
	for node in game.get_children():
		if node is RegionGate:
			kinds[node.target_region] = node.kind
	return kinds

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var expected := {
		"greenreach": {"salt_coast": "bridge_h", "moonlit_grove": "bridge_h", "ruins_depths": "stairs_down"},
		"moonlit_grove": {"crystal_caves": "cave_mouth", "misty_marsh": "bridge_v"},
		"crystal_caves": {"sky_island": "cave_exit", "moonlit_grove": "cave_exit"},
		"ruins_depths": {"greenreach": "stairs_up"},
		"sky_island": {"crystal_caves": "cave_mouth", "wind_spires": "bridge_h"},
	}
	for region in expected:
		game._set_region(region, Vector2(400, 400), false)
		await process_frame
		var kinds := _gate_kinds(game)
		for target in expected[region]:
			if kinds.get(target, "") != expected[region][target]:
				return _fail("%s → %s should be %s, got %s" % [region, target, expected[region][target], kinds.get(target, "")])
	game._set_region("greenreach", Vector2(400, 400), false)
	await process_frame
	for node in game.get_children():
		if node is RegionGate and node.target_region == "ruins_depths":
			var text := game._interaction_prompt(node)
			if not text.contains("спуститься") or not text.contains(RegionCatalog.display_name("ruins_depths")):
				return _fail("the prompt names the way and the destination: " + text)
	print("REGION GATES OK: bridges, cave mouths, exits, stairs, prompts")
	quit(0)
