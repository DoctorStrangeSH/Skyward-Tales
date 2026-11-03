extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("QUEST REWARD FAILED: " + reason)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var quests: QuestManager = game.quests
	if not _verify(quests.get_reward("moonleaf_gathering").get("gold") == 25 and quests.get_reward("grove_spirits").get("experience") == 90, "quest catalog rewards"):
		return
	if not _verify(quests.get_reward("no_such_quest").is_empty(), "unknown quests should have no reward"):
		return
	quests.definitions["test_reward"] = {"target": 1, "title": "Награда", "reward": {"experience": 17, "gold": 13}}
	quests.states["test_reward"] = {"started": false, "completed": false, "progress": 0}
	if not _verify(quests.start_quest("test_reward"), "quest start failed"):
		return
	quests.add_progress("test_reward")
	if not _verify(quests.complete_quest("test_reward"), "quest completion failed"):
		return
	var before_gold: int = game.player.gold
	var before_xp: int = game.player.experience
	game._grant_quest_reward("test_reward")
	if not _verify(game.player.gold == before_gold + 13 and game.player.experience == before_xp + 17, "reward not taken from quest definition"):
		return
	print("QUEST REWARD OK: data-driven XP/gold")
	quit(0)
