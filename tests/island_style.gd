extends SceneTree

## One muted daylight grade; waterfalls are authored outlets, not random
## icicles with a disconnected mist cap. Exercises rebuilds and pause clocks.
func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("ISLAND STYLE FAILED: " + reason)
	quit(1)

func _run() -> void:
	var rim := CliffRim.new()
	root.add_child(rim)
	rim.setup(Vector2(800, 500), "style_test", [300.0], [
		{"x": 100, "width": 24, "drop": 200},
		{"x": 300}, # A bridge mouth must stay clear.
		{"x": -10}, # No stream beyond the island.
	])
	await process_frame
	var falls := rim.find_children("Waterfall_*", "Node2D", false, false)
	if falls.size() != 1:
		return _fail("only an explicitly placed, unobstructed outlet is built")
	var fall := falls[0] as IslandWaterfall
	if fall == null or fall.stream == null or fall.flow_material == null:
		return _fail("the continuous stream has a material")
	if fall.position != Vector2(100, 494) or fall.stream.size != Vector2(24, 200):
		return _fail("the mouth is anchored to the rim, with independent width and drop")
	var before := fall.clock
	await process_frame
	if fall.clock <= before:
		return _fail("the flow advances")
	paused = true
	before = fall.clock
	await process_frame
	await process_frame
	if not is_equal_approx(fall.clock, before):
		return _fail("the flow clock pauses with the game")
	paused = false
	fall.setup(16, 144)
	if fall.stream.size != Vector2(16, 144):
		return _fail("an existing stream can be resized")
	var dry := CliffRim.new()
	root.add_child(dry)
	dry.setup(Vector2(800, 500), "dry_test")
	if not dry.find_children("Waterfall_*", "Node2D", false, false).is_empty():
		return _fail("dry cliffs do not receive random waterfalls")
	var grade := ScreenGrade.new()
	root.add_child(grade)
	if grade.layer != 1 or grade.rect.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return _fail("the world grade remains below the HUD and does not eat clicks")
	GameSettings.set_bool("color_grade", false)
	grade.apply()
	if grade.rect.visible:
		return _fail("the existing colour-grade switch still works")
	GameSettings.set_bool("color_grade", true)
	grade.apply()
	if not grade.rect.visible:
		return _fail("the grade can be restored")
	print("ISLAND STYLE OK")
	quit(0)
