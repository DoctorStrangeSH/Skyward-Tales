extends RefCounted
class_name QuestGivers

## Data-driven side-quest NPCs (data/quest_givers.json). Each giver offers its
## quests in order: offer → progress → done, then idle. Rewards may include
## items. Adding a new side-quest chain needs only data, no code.

const DATA_PATH := "res://data/quest_givers.json"

var game: SkywardGame
var givers: Dictionary = {}

func _init(owner_game: SkywardGame) -> void:
	game = owner_game
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		givers = parsed

func has_giver(npc_id: String) -> bool:
	return givers.has(npc_id)

func _speaker(npc_id: String) -> String:
	return str(givers[npc_id].get("speaker", npc_id))

func _line(npc_id: String, quest_id: String, key: String) -> String:
	return StoryText.format(str(givers[npc_id].get("lines", {}).get(quest_id, {}).get(key, "")))

## The quest this giver is about right now, or "" when everything is done.
func current_quest(npc_id: String) -> String:
	for quest_id in givers[npc_id].get("quests", []):
		if not game.quests.is_completed(str(quest_id)):
			return str(quest_id)
	return ""

func _unlocked(quest_id: String) -> bool:
	var needs := str(game.quests.definitions.get(quest_id, {}).get("requires_quest", ""))
	return needs.is_empty() or game.quests.is_completed(needs)

## "quest" (!) when an offer is waiting, "ready" (?) when a reward is due.
func marker_for(npc_id: String) -> String:
	var quest_id := current_quest(npc_id)
	if quest_id.is_empty():
		return ""
	if game.quests.is_ready_to_complete(quest_id):
		return "ready"
	if not bool(game.quests.states[quest_id]["started"]) and _unlocked(quest_id):
		return "quest"
	return ""

func talk(npc_id: String) -> void:
	var quests := game.quests
	var speaker := _speaker(npc_id)
	var quest_id := current_quest(npc_id)
	if quest_id.is_empty():
		game._show_dialogue(speaker, StoryText.format(str(givers[npc_id].get("idle", "Спасибо тебе за всё."))))
		return
	if quests.is_ready_to_complete(quest_id):
		quests.complete_quest(quest_id)
		var summary := game.dialogues._grant_reward(quests.get_reward(quest_id))
		var reward: Dictionary = quests.get_reward(quest_id)
		game._show_dialogue(speaker, _line(npc_id, quest_id, "done"))
		game.hud.show_message("Задание выполнено: %s · +%d опыта, +%d золота%s" % [quests.definitions[quest_id].get("title", ""), int(reward.get("experience", 0)), int(reward.get("gold", 0)), summary], 3.5)
		game._refresh_hud()
		game.update_npc_markers()
		return
	if bool(quests.states[quest_id]["started"]):
		game._show_dialogue(speaker, _line(npc_id, quest_id, "progress"))
		return
	if not _unlocked(quest_id):
		game._show_dialogue(speaker, StoryText.format(str(givers[npc_id].get("busy", "Приходи позже — сейчас мне нечем тебя занять."))))
		return
	var choices: Array[Dictionary] = [
		{"id": "giver_accept:" + quest_id, "label": "Взяться за дело"},
		{"id": "giver_later", "label": "Не сейчас"},
	]
	game._show_dialogue_choices(speaker, _line(npc_id, quest_id, "offer"), choices)

func handle_choice(choice_id: String) -> bool:
	if choice_id == "giver_later":
		game.dialogues._close()
		return true
	if not choice_id.begins_with("giver_accept:"):
		return false
	var quest_id := choice_id.trim_prefix("giver_accept:")
	game.dialogues._close()
	if game.quests.start_quest(quest_id):
		game.hud.show_message("Новое задание: " + str(game.quests.definitions[quest_id].get("title", "")), 3.0)
		game._refresh_hud()
		game.update_npc_markers()
		# Unique side bosses appear once their quest is open.
		game.spawn_quest_enemies(quest_id)
	return true
