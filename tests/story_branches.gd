extends SceneTree

## Story scenes: flags, branches and the hero's answers (tech debt from
## Этап 2), and the first real choice — how the hero takes Vail's fall,
## remembered by Elian in Act III.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("STORY BRANCHES TEST FAILED: " + reason)
	quit(1)

func _texts(story: StoryScene) -> Array:
	return story._steps.map(func(s: Dictionary) -> String: return str(s.get("text", "")))

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	var story := game.story
	story.scenes["test_branch"] = {"steps": [
		{"set_flag": "test_seen"},
		{"if_flag": "test_seen", "then": [{"text": "да"}], "else": [{"text": "нет"}]},
		{"if_quest_done": "main_echo", "then": [{"text": "эхо"}], "else": [{"text": "без эха"}]},
		{"speaker": "hero", "text": "Выбор?", "choice": [
			{"label": "А", "flag": "test_a", "steps": [{"text": "ветка А"}]},
			{"label": "Б", "flag": "test_b", "steps": [{"text": "ветка Б"}]}]},
		{"text": "конец"}]}
	var finished := [false]
	story.play("test_branch", func() -> void: finished[0] = true)
	if not game.director.has_flag("test_seen"):
		return _fail("set_flag")
	if not _texts(story).has("да") or _texts(story).has("нет"):
		return _fail("if_flag picks the right branch")
	story.advance()
	if not _texts(story).has("без эха"):
		return _fail("if_quest_done")
	story.advance()
	if story._choices.size() != 2 or not game.hud.dialogue_visible:
		return _fail("a choice line waits for an answer")
	game.dialogues.handle_choice("scene_choice:1")
	if not game.director.has_flag("test_b") or game.director.has_flag("test_a") or not _texts(story).has("ветка Б"):
		return _fail("the answer plays its branch and sets its flag")
	story.skip()
	if story.active or not finished[0]:
		return _fail("the scene ends")
	# E on a choice line takes the first answer (skipping never hangs).
	story.play("test_branch")
	story.skip()
	if story.active or not game.director.has_flag("test_a"):
		return _fail("skip answers with the first choice")

	# Vail's fall: the hero's feeling is remembered by Elian.
	story.play("vail_falls")
	while story.active and story._choices.is_empty():
		story.advance()
	if story._choices.size() != 3:
		return _fail("three answers to Vail's fall")
	game.dialogues.handle_choice("scene_choice:2")
	story.skip()
	if not game.director.has_flag("vail_pity"):
		return _fail("pity remembered")
	story.play("elder_truth")
	story.advance()
	if not _texts(story).any(func(t: String) -> bool: return t.contains("пожалел")):
		return _fail("Elian remembers the hero's pity")
	story.skip()
	print("STORY BRANCHES TEST PASSED")
	quit(0)
