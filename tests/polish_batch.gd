extends SceneTree

## Polish batch: Esc closes the top window first, story quests follow each
## other automatically, NPCs vary repeated lines, quest marker colors, sprint.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("POLISH TEST FAILED: " + reason)
	quit(1)

func _esc() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	return event

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hud := game.hud

	# Esc: inventory closes first, then the pause menu opens.
	hud.toggle_inventory(game.player)
	hud._unhandled_input(_esc())
	if hud.inventory_open or paused:
		return _fail("Esc closes the inventory without pausing")
	hud.toggle_journal(game.quests, game.player)
	hud._unhandled_input(_esc())
	if hud.journal_visible:
		return _fail("Esc closes the journal")
	hud._unhandled_input(_esc())
	if not paused or not hud.pause_panel.visible:
		return _fail("Esc with nothing open opens the menu")
	hud._unhandled_input(_esc())
	if paused:
		return _fail("Esc again resumes")

	# Story quests start by themselves one after another.
	var quests := game.quests
	quests.states["main_prologue"]["started"] = true
	quests.start_quest("main_star_map")
	quests.states["main_star_map"]["progress"] = int(quests.definitions["main_star_map"].get("target", 1))
	quests.complete_quest("main_star_map")
	await process_frame
	await process_frame
	if not bool(quests.states["grove_spirits"]["started"]):
		return _fail("the next story quest starts automatically")

	# Repeated lines turn into small talk.
	var lines := {}
	for i in 6:
		lines[game._vary_line("Мира, картограф", "Привет.")] = true
	if lines.size() < 3:
		return _fail("NPCs don't repeat the same line: %d" % lines.size())

	# Marker colors.
	if game.dialogues.marker_style("hunter", "quest") != "quest" or game.dialogues.marker_style("elder", "quest") != "quest_main":
		return _fail("story markers are gold, side markers blue")

	# Sprint is faster than walking.
	if SkywardGame.XP_RATE >= 1.0 or PlayerCharacter.SPRINT_MULT <= 1.2:
		return _fail("sprint and slower leveling")
	if not InputMap.has_action("sprint") or not InputMap.has_action("dodge"):
		return _fail("sprint and dodge keys")
	print("POLISH OK: esc, story chain, varied lines, marker colors, sprint")
	quit(0)
