extends SceneTree

## Autosave after quests, region travel and boss kills; atomic writes;
## "newest save" selection for Continue and the defeat screen.

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("AUTOSAVE TEST FAILED: " + reason)
		quit(1)
		return false
	return true

func _cleanup(game: SkywardGame) -> void:
	for path in [game.save_path, game.autosave_path()]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save_path = "user://autosave_test.json"
	_cleanup(game)
	if not _verify(game.autosave_path() == "user://autosave_test_autosave.json", "autosave lives next to the manual save"):
		return

	# Completing a quest autosaves at the end of the frame, including its reward.
	var gold_before: int = game.player.gold
	game.quests.start_quest("moonleaf_gathering")
	game.quests.add_progress("moonleaf_gathering", 3)
	game._on_dialogue_choice_selected("payment")
	if not _verify(game.quests.is_completed("moonleaf_gathering"), "elder quest completed"):
		return
	await process_frame
	var auto: Dictionary = SaveSystem.load_snapshot(game.autosave_path())
	if not _verify(not auto.is_empty(), "quest completion writes an autosave"):
		return
	if not _verify(bool(auto["quest"]["states"]["moonleaf_gathering"]["completed"]), "autosave contains the completed quest"):
		return
	if not _verify(int(auto["player"]["gold"]) > gold_before, "autosave contains the quest reward"):
		return
	if not _verify(not FileAccess.file_exists(game.autosave_path() + ".tmp"), "atomic write leaves no temp file"):
		return
	if not _verify(not FileAccess.file_exists(game.save_path), "autosave never touches the manual save"):
		return

	# Region travel autosaves the new region.
	game._on_region_travel("moonlit_grove", Vector2(140, 430))
	await process_frame
	auto = SaveSystem.load_snapshot(game.autosave_path())
	if not _verify(str(auto["world"]["region"]) == "moonlit_grove", "region travel autosaves"):
		return

	# Death without a manual save can still recover from the autosave.
	var gold_at_autosave: int = int(auto["player"]["gold"])
	game.player.add_gold(500)
	game.player.take_damage(9999)
	if not _verify(game.game_over and not game.hud.defeat_load_button.disabled, "defeat screen offers the autosave"):
		return
	if not _verify(not game.autosave(), "no autosave after defeat"):
		return
	game._load_from_defeat()
	if not _verify(not game.game_over and not paused, "loading the autosave resumes play"):
		return
	if not _verify(game.player.gold == gold_at_autosave and game.current_region == "moonlit_grove", "autosave state restored"):
		return

	# A newer manual save wins for "load newest"; F9 always prefers the manual save.
	game.player.gold = 777
	if not _verify(game.save_game(), "manual save works"):
		return
	game.player.gold = 1
	if not _verify(game.load_game(true) and game.player.gold == 777, "newest save (manual) is loaded"):
		return
	game.player.gold = 5
	if not _verify(game.autosave(), "direct autosave works"):
		return
	game.player.gold = 1
	if not _verify(game.load_game(true) and game.player.gold == 5, "newest save (autosave) is loaded"):
		return
	if not _verify(game.load_game() and game.player.gold == 777, "F9 loads the manual save"):
		return

	_cleanup(game)
	print("AUTOSAVE OK: quest/travel triggers, atomic write, defeat recovery, newest-save selection")
	quit(0)
