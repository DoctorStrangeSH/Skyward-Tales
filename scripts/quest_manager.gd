extends RefCounted
class_name QuestManager

var definitions: Dictionary = {}
var states: Dictionary = {}
var active_quest_id: String = ""

signal quest_completed(quest_id: String)

func _init() -> void:
	var file := FileAccess.open("res://data/quests.json", FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть data/quests.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		push_error("data/quests.json должен содержать массив заданий")
		return
	for definition in parsed:
		var quest_id: String = str(definition.get("id", ""))
		if quest_id.is_empty():
			continue
		definitions[quest_id] = definition
		states[quest_id] = {"started": false, "completed": false, "progress": 0}

func start_quest(quest_id: String) -> bool:
	if not definitions.has(quest_id) or states[quest_id]["completed"]:
		return false
	states[quest_id]["started"] = true
	active_quest_id = quest_id
	return true

func add_progress(quest_id: String, amount: int = 1) -> void:
	if not states.has(quest_id):
		return
	if not states[quest_id]["started"] or states[quest_id]["completed"]:
		return
	var target: int = int(definitions[quest_id].get("target", 1))
	states[quest_id]["progress"] = mini(target, int(states[quest_id]["progress"]) + amount)

func is_ready_to_complete(quest_id: String) -> bool:
	if not states.has(quest_id):
		return false
	return states[quest_id]["started"] and not states[quest_id]["completed"] and int(states[quest_id]["progress"]) >= int(definitions[quest_id].get("target", 1))

func is_completed(quest_id: String) -> bool:
	return states.has(quest_id) and bool(states[quest_id]["completed"])

func complete_quest(quest_id: String) -> bool:
	if not is_ready_to_complete(quest_id):
		return false
	states[quest_id]["completed"] = true
	if active_quest_id == quest_id:
		active_quest_id = ""
	quest_completed.emit(quest_id)
	return true

func get_active_summary() -> String:
	if active_quest_id.is_empty() or not definitions.has(active_quest_id):
		return "Поговорите со старейшиной, чтобы узнать о задании."
	var definition: Dictionary = definitions[active_quest_id]
	var state: Dictionary = states[active_quest_id]
	return "%s  [%d/%d]" % [
		str(definition.get("title", "Задание")),
		int(state["progress"]),
		int(definition.get("target", 1))
	]

func get_reward(quest_id: String) -> Dictionary:
	if not definitions.has(quest_id):
		return {}
	var reward: Variant = definitions[quest_id].get("reward", {})
	return reward if reward is Dictionary else {}

func get_choice_reward(quest_id: String, choice_id: String) -> Dictionary:
	if not definitions.has(quest_id):
		return {}
	var choices: Variant = definitions[quest_id].get("choices", {})
	if not choices is Dictionary or not choices.has(choice_id):
		return {}
	var choice: Variant = choices[choice_id]
	if not choice is Dictionary:
		return {}
	var reward: Variant = choice.get("reward", {})
	return reward.duplicate(true) if reward is Dictionary else {}
