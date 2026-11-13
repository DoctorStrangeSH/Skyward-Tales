extends Node
class_name Mysteries

## Этап 24: investigations (data/mysteries.json). A villager asks who did
## it; clues are people's words (talk to them while the case is open) and
## places to look at (E); with enough clues the giver hears the accusation —
## the right one is rewarded and remembered (flag mystery_<id>_right), a
## wrong one leaves its mark too (mystery_<id>_wrong).

const PATH := "res://data/mysteries.json"

var game: SkywardGame
var data: Dictionary = {}
## {mystery id: {"clues": {clue id: true}, "verdict": suspect id}}
var cases: Dictionary = {}

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else {}
	data = parsed.get("mysteries", {}) if parsed is Dictionary else {}

func info(id: String) -> Dictionary:
	return data.get(id, {})

func quest_of(id: String) -> String:
	return str(info(id).get("quest", ""))

func is_open(id: String) -> bool:
	return game.quests.is_active(quest_of(id)) and not _case(id).has("verdict")

func found(id: String) -> int:
	return (_case(id).get("clues", {}) as Dictionary).size()

func _case(id: String) -> Dictionary:
	if not cases.has(id):
		cases[id] = {"clues": {}}
	return cases[id]

func available(id: String) -> bool:
	var entry := info(id)
	var quest_id := quest_of(id)
	if entry.is_empty() or bool(game.quests.states.get(quest_id, {}).get("started", false)):
		return false
	var after := str(entry.get("after", ""))
	return (after.is_empty() or game.quests.is_completed(after)) and game.player.level >= int(entry.get("level", 1))

func ready_to_accuse(id: String) -> bool:
	return is_open(id) and found(id) >= int(info(id).get("need", 1))

## Marker over a villager: "quest" — a case to take, "ready" — the case is
## solved enough to name the culprit, "clue" — they have something to say.
func marker(npc_id: String) -> String:
	for id in data:
		var entry: Dictionary = data[id]
		if str(entry.get("giver", "")) == npc_id:
			if ready_to_accuse(str(id)):
				return "ready"
			if available(str(id)):
				return "quest"
	return ""

## Handles a talk; true when the case took the conversation.
func talk(npc_id: String) -> bool:
	for id in data:
		var entry: Dictionary = data[id]
		var case_id := str(id)
		if str(entry.get("giver", "")) == npc_id:
			if available(case_id):
				game._show_dialogue_choices(str(entry.get("title", "")), StoryText.format(str(entry.get("intro", ""))), [
					{"id": "mystery_take:%s" % case_id, "label": "Взяться за расследование"},
					{"id": "mystery_later", "label": "Не сейчас"}])
				return true
			if ready_to_accuse(case_id):
				_accuse_dialog(case_id)
				return true
		if is_open(case_id):
			for clue in entry.get("clues", []):
				if str(clue.get("kind", "")) == "talk" and str(clue.get("npc", "")) == npc_id and not (_case(case_id)["clues"] as Dictionary).has(str(clue["id"])):
					_find(case_id, clue)
					game._show_dialogue(str(clue.get("speaker", "")), StoryText.format(str(clue.get("text", ""))))
					return true
	return false

func _accuse_dialog(id: String) -> void:
	var entry := info(id)
	var choices: Array[Dictionary] = []
	for suspect in entry.get("suspects", []):
		choices.append({"id": "mystery_accuse:%s:%s" % [id, str(suspect["id"])], "label": str(suspect["label"])})
	choices.append({"id": "mystery_later", "label": "Мне нужно ещё подумать"})
	var notes := ""
	for clue in entry.get("clues", []):
		if (_case(id)["clues"] as Dictionary).has(str(clue["id"])):
			notes += "\n• " + StoryText.format(str(clue.get("text", ""))).left(110) + ("…" if str(clue.get("text", "")).length() > 110 else "")
	game._show_dialogue_choices("%s — кто виноват?" % str(entry.get("title", "")), "Ваши улики:" + notes, choices)

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("mystery_"):
		return false
	game.dialogues._close()
	if choice_id.begins_with("mystery_take:"):
		var id := choice_id.trim_prefix("mystery_take:")
		game.quests.start_quest(quest_of(id))
		game.hud.show_title_card("Расследование: %s" % str(info(id).get("title", "")), 2.4)
		game.hud.show_message("Улики — в разговорах и на месте (E). Нужно %d." % int(info(id).get("need", 1)), 4.0)
		populate()
		game.update_npc_markers()
	elif choice_id.begins_with("mystery_accuse:"):
		var parts := choice_id.split(":")
		accuse(parts[1], parts[2])
	return true

func accuse(id: String, suspect: String) -> bool:
	if not ready_to_accuse(id):
		return false
	var entry := info(id)
	var right := suspect == str(entry.get("culprit", ""))
	_case(id)["verdict"] = suspect
	var outcome: Dictionary = entry.get("right" if right else "wrong", {})
	game.director.set_flag("mystery_%s_%s" % [id, "right" if right else "wrong"])
	var hero := game.player
	hero.add_experience(int(outcome.get("experience", 0)))
	hero.add_gold(int(outcome.get("gold", 0)))
	var items: Dictionary = outcome.get("items", {})
	for item in items:
		hero.add_item(str(item), int(items[item]))
	var quest_id := quest_of(id)
	var target := int(game.quests.definitions[quest_id].get("target", 1))
	game.quests.add_progress(quest_id, target)
	game.quests.complete_quest(quest_id)
	game._show_dialogue(str(outcome.get("speaker", "")), StoryText.format(str(outcome.get("text", ""))))
	game.hud.show_title_card("Дело раскрыто" if right else "Дело закрыто", 2.4)
	game.achievements.add("mysteries" if right else "mysteries_closed")
	game.update_npc_markers()
	game.request_autosave()
	return right

func _find(id: String, clue: Dictionary) -> void:
	(_case(id)["clues"] as Dictionary)[str(clue["id"])] = true
	var quest_id := quest_of(id)
	if found(id) <= int(game.quests.definitions[quest_id].get("target", 1)):
		game.quests.add_progress(quest_id, 1)
	game.hud.show_message("Улика %d из %d%s" % [found(id), int(info(id).get("need", 1)), " — можно назвать виновного (%s)." % RegionCatalog.npc_name(str(info(id).get("giver", ""))).get_slice(",", 0) if ready_to_accuse(id) else "."], 3.5)
	GameAudio.play("quest", -8.0, 0.2)
	game.update_npc_markers()

## Places to look at, while the case is open.
func populate() -> void:
	for node in get_tree().get_nodes_in_group("mystery_spot"):
		node.queue_free()
	for id in data:
		var entry: Dictionary = data[id]
		var case_id := str(id)
		if str(entry.get("region", "")) != game.current_region or not is_open(case_id):
			continue
		for clue in entry.get("clues", []):
			if str(clue.get("kind", "")) != "spot" or (_case(case_id)["clues"] as Dictionary).has(str(clue["id"])):
				continue
			var spot := TowerObject.new()
			spot.art = str(clue.get("art", "pouch"))
			spot.label = "E — осмотреть: %s" % str(clue.get("name", ""))
			spot.glow = Color(1.0, 0.85, 0.4, 0.5)
			spot.add_to_group("mystery_spot")
			spot.add_to_group("region_actor")
			game.add_child(spot)
			spot.global_position = SkywardGame._vec(clue.get("position"))
			var the_clue: Dictionary = clue
			spot.used.connect(func(object: TowerObject) -> void:
				if (_case(case_id)["clues"] as Dictionary).has(str(the_clue["id"])):
					return
				_find(case_id, the_clue)
				game._show_dialogue(str(the_clue.get("name", "")), StoryText.format(str(the_clue.get("text", ""))))
				object.queue_free())

## Clues found, as the journal shows them.
func journal_text(quest_id: String) -> String:
	for id in data:
		if quest_of(str(id)) == quest_id:
			var lines: Array[String] = []
			for clue in data[id].get("clues", []):
				if (_case(str(id))["clues"] as Dictionary).has(str(clue["id"])):
					lines.append("• " + StoryText.format(str(clue.get("text", ""))))
			return "" if lines.is_empty() else "Улики:\n" + "\n".join(lines)
	return ""

func make_snapshot() -> Dictionary:
	return {"cases": cases.duplicate(true)}

func restore_snapshot(value: Variant) -> void:
	var saved: Dictionary = value if value is Dictionary else {}
	cases = (saved.get("cases", {}) as Dictionary).duplicate(true) if saved.get("cases", {}) is Dictionary else {}
