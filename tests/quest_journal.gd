extends SceneTree

## Quest journal: J toggles it, active quests show progress, completed quests
## show the player's decision, and it blocks casting while open.

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("QUEST JOURNAL TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _press(game: SkywardGame, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	game._input(event)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false

	var entries := QuestJournalPanel.build_entries(game.quests)
	if not _verify(entries["active"].is_empty() and entries["completed"].is_empty(), "journal starts empty"):
		return

	game.quests.start_quest("moonleaf_gathering")
	game.quests.add_progress("moonleaf_gathering", 2)
	entries = QuestJournalPanel.build_entries(game.quests)
	if not _verify(entries["active"].size() == 1 and entries["active"][0]["title"] == "Три лунных листа", "active quest is listed"):
		return
	if not _verify(entries["active"][0]["progress"] == 2 and entries["active"][0]["target"] == 3, "active quest shows progress"):
		return

	game.quests.add_progress("moonleaf_gathering", 1)
	game._on_dialogue_choice_selected("village")
	entries = QuestJournalPanel.build_entries(game.quests)
	if not _verify(entries["active"].is_empty() and entries["completed"].size() == 1, "completed quest moves to the completed list"):
		return
	if not _verify(entries["completed"][0]["decision"] == "Оставить большую часть награды поселению", "decision is shown"):
		return

	# The quest reward levels the hero up; dismiss the talent choice first.
	game.pending_level_choices.clear()
	game.hud.hide_talent_choices()
	paused = false
	_press(game, KEY_J)
	if not _verify(game.hud.journal_visible and game.hud.journal_view.visible, "J opens the journal"):
		return
	if not _verify(game.hud.journal_view.entry_list.get_child_count() > 0, "journal has rows"):
		return
	var mana_before: int = game.player.mana
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game._input(click)
	if not _verify(game.player.mana == mana_before, "casting is blocked while the journal is open"):
		return
	_press(game, KEY_K)
	if not _verify(game.hud.bestiary_visible and not game.hud.journal_visible, "K switches from journal to bestiary"):
		return
	_press(game, KEY_J)
	if not _verify(game.hud.journal_visible and not game.hud.bestiary_visible, "J switches back to journal"):
		return
	_press(game, KEY_J)
	if not _verify(not game.hud.journal_visible, "J closes the journal"):
		return

	print("QUEST JOURNAL OK: active progress, decisions, toggling, input blocking")
	quit(0)
