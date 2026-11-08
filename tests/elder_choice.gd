extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _verify(ok: bool, detail: String) -> bool:
	if not ok:
		push_error("ELDER CHOICE FAILED: " + detail)
		quit(1)
		return false
	return true

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.quests.start_quest("moonleaf_gathering")
	game.quests.add_progress("moonleaf_gathering", 3)
	game._on_elder_interacted(null)
	game.story.skip()
	if not _verify(game.hud.dialogue_visible, "elder offers a dialogue choice after collecting leaves"):
		return
	if not _verify(game.hud.dialogue_label.text.contains("поселению"), "elder explains the village dilemma"):
		return
	var before_gold: int = game.player.gold
	var before_level: int = game.player.level
	game.player.experience = game.player.experience_to_next - 20
	var before_xp: int = game.player.experience
	var xp_to_next: int = game.player.experience_to_next
	game._on_dialogue_choice_selected("village")
	if not _verify(game.quests.is_completed("moonleaf_gathering"), "village choice completes the quest"):
		return
	if not _verify(game.quests.states["moonleaf_gathering"].get("choice", "") == "village", "choice is saved in quest state"):
		return
	if not _verify(game.player.gold == before_gold + 10 and game.player.level == before_level + 1 and game.player.experience == before_xp + 50 - xp_to_next, "village choice grants its data-driven reward and applies level-up XP"):
		return
	if not _verify(game.relationships.get_score("elder") == 20, "donating reward grants twenty trust"):
		return
	if not _verify(game.discovered_landmarks.get("greenreach", {}).has("elder_hidden_storehouse"), "trust reveals the elder's hidden storehouse on the map"):
		return
	var snapshot: Dictionary = game.make_save_snapshot()
	if not _verify(snapshot["world"]["landmarks"]["greenreach"].has("elder_hidden_storehouse"), "secret landmark is included in the save snapshot"):
		return
	game._on_elder_interacted(null)
	if not _verify(game.hud.dialogue_label.text.contains("хранилище"), "trusted follow-up dialogue reveals the storehouse"):
		return
	if not _verify(game.relationships.get_score("elder") == 20, "repeated conversation does not grant trust again"):
		return
	print("ELDER CHOICE OK: reward branch, trust, secret landmark and persistence")
	quit(0)
