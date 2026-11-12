extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("WATERFALL SCENE FAILED: " + reason)
	quit(1)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/props/island_waterfall.tscn")
	var fall := scene.instantiate() as IslandWaterfall
	root.add_child(fall)
	await process_frame
	if fall.stream == null or fall.stream_width < 48.0:
		return _fail("the editable scene starts with a broad visible stream")
	if fall.approach.visible:
		return _fail("cliff springs have no surface approach by default")
	for field in ["stream_width", "drop_length", "flow_speed", "approach_length", "water_tint", "cloud_fade", "show_lip", "animate_in_editor"]:
		var exposed := false
		for property in fall.get_property_list():
			if property.name == field and int(property.usage) & PROPERTY_USAGE_EDITOR:
				exposed = true
		if not exposed:
			return _fail("inspector control missing: " + field)
	fall.stream_width = 128.0
	fall.drop_length = 420.0
	fall.flow_speed = 1.5
	fall.approach_length = 38.0
	await process_frame
	await process_frame
	if fall.left_cap == null or fall.right_cap == null or fall.left_cap.position.x != -67.0 or fall.right_cap.position.x != 67.0:
		return _fail("the bank stones follow live width changes")
	if fall.stream.size != Vector2(128, 420) or fall.stream.position != Vector2(-64, 0):
		return _fail("inspector edits update the existing stream without moving its mouth")
	if not fall.approach.visible or fall.approach.position != Vector2(-64, -38) or fall.approach.size != Vector2(128, 41):
		return _fail("surface current follows width and overlaps the falling water")
	if not is_equal_approx(float(fall.flow_material.get_shader_parameter("stream_width")), 128.0):
		return _fail("grain density follows width instead of stretching the old column")
	fall.set_process(false)
	var before := fall.clock
	fall._process(0.5)
	if not is_equal_approx(fall.clock - before, 0.75):
		return _fail("the speed control affects animation")
	if not is_equal_approx(float(fall.approach_material.get_shader_parameter("clock")), fall.clock):
		return _fail("surface and falling flow share the same animation clock")
	fall.flow_speed = 0.0
	await process_frame
	before = fall.clock
	fall._process(1.0)
	if not is_equal_approx(fall.clock, before):
		return _fail("zero speed freezes the preview")
	var group: PackedScene = load("res://scenes/regions/greenreach_waterfalls.tscn")
	var rim := CliffRim.new()
	root.add_child(rim)
	rim.setup(Vector2(1920, 1280), "greenreach", [], [{"x": 700}], group)
	await process_frame
	var authored := rim.get_node_or_null("AuthoredWaterfalls")
	if authored == null or authored.get_child_count() != 1:
		return _fail("the first island uses the authored scene without duplicate data outlets")
	var source := authored.get_node("EastLakeSource") as IslandWaterfall
	if source.approach_length != 38.0:
		return _fail("the lake feeds an animated surface current")
	if source == null or source.position != Vector2(1556, 1274) or source.stream_width != 64.0 or source.drop_length != 160.0:
		return _fail("the game and editor use the same authored source")
	print("WATERFALL SCENE OK")
	quit(0)
