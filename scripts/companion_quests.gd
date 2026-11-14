extends Node
class_name CompanionQuests

## Этап 24: personal quests of the companions (data/companion_quests.json).
## Toren — «Последний след» (his lost partner Yan in the Moonlit Grove),
## Raina — «Колокол «Ласточки»» (her wrecked sloop on the Salt Coast).
## Offered in the companion's talk when they trust the hero enough (their
## level) and the hero is ready; every step needs the companion beside you:
##   spot  — a place to look at (E) in a land;
##   talk  — a villager to ask;
##   fight — foes rise when you come near; the step is done when they fall;
## then a choice that ends the story — each way gives its own item and is
## remembered (a flag).

const PATH := "res://data/companion_quests.json"
const NEAR := 130.0

var game: SkywardGame
var data: Dictionary = {}
## {quest id: step index} — quests under way.
var steps: Dictionary = {}
## {quest id: option id} — finished stories.
var endings: Dictionary = {}
var _foes: Array = []
var _fight_quest: String = ""

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else {}
	data = parsed.get("quests", {}) if parsed is Dictionary else {}

func info(id: String) -> Dictionary:
	return data.get(id, {})

func quest_for(companion: String) -> String:
	for id in data:
		if str(data[id].get("companion", "")) == companion:
			return str(id)
	return ""

## The companion is in the party and beside the hero.
func with_hero(companion: String) -> bool:
	if game.party == null or game.party.extra != companion:
		return false
	var node: Node2D = game.party.follower()
	return node != null and is_instance_valid(node) and node.global_position.distance_to(game.player.global_position) < 300.0

func available(id: String) -> bool:
	var entry := info(id)
	if entry.is_empty() or steps.has(id) or endings.has(id):
		return false
	var companion := str(entry["companion"])
	return game.player.level >= int(entry.get("level", 1)) and int(game.crew.state(companion).get("level", 1)) >= int(entry.get("crew_level", 1))

func current(id: String) -> Dictionary:
	if not steps.has(id):
		return {}
	var list: Array = info(id).get("steps", [])
	var index := int(steps[id])
	return list[index] if index < list.size() else {}

# --- Start, steps, the end --------------------------------------------------------

## A line for the companion's talk.
func offer_choice(companion: String) -> Dictionary:
	var id := quest_for(companion)
	if id.is_empty():
		return {}
	if available(id):
		return {"id": "cq_start:" + id, "label": str(info(id).get("offer", "Поговорим о личном?"))}
	if steps.has(id):
		if current(id).is_empty():
			return {"id": "cq_status:" + id, "label": "Решить, что делать: %s" % str(info(id).get("title", ""))}
		return {"id": "cq_status:" + id, "label": "О нашем деле: %s" % str(info(id).get("title", ""))}
	return {}

func start(id: String) -> bool:
	if not available(id):
		return false
	steps[id] = 0
	game.quests.start_quest(str(info(id)["quest"]))
	game.hud.show_title_card(str(info(id).get("title", "")), 2.4)
	populate()
	game.update_npc_markers()
	game.request_autosave()
	return true

## Next step; `said` — the text of the step just done (it opens the ending).
func _advance(id: String, said: String = "") -> void:
	steps[id] = int(steps[id]) + 1
	game.quests.add_progress(str(info(id)["quest"]), 1)
	if current(id).is_empty():
		_offer_ending(id, said)
	else:
		populate()
	game.update_npc_markers()
	game.request_autosave()

func _offer_ending(id: String, said: String = "") -> void:
	var choice: Dictionary = info(id).get("choice", {})
	var options: Array[Dictionary] = []
	for option in choice.get("options", []):
		options.append({"id": "cq_end:%s:%s" % [id, str(option["id"])], "label": str(option["label"])})
	var companion := str(info(id)["companion"])
	game._show_dialogue_choices(str(game.crew.info(companion).get("name", companion)), ((said + "\n\n") if not said.is_empty() else "") + StoryText.format(str(choice.get("text", ""))), options)

func finish(id: String, option_id: String) -> bool:
	if not steps.has(id) or not current(id).is_empty():
		return false
	var option: Dictionary = {}
	for entry in info(id).get("choice", {}).get("options", []):
		if str(entry["id"]) == option_id:
			option = entry
	if option.is_empty():
		return false
	steps.erase(id)
	endings[id] = option_id
	game.director.set_flag(str(option.get("flag", id + "_" + option_id)))
	game.player.add_item(str(option.get("item", "")), 1)
	var quest := str(info(id)["quest"])
	var target := int(game.quests.definitions[quest].get("target", 1))
	game.quests.states[quest]["progress"] = target
	game.quests.complete_quest(quest)
	var summary := str(game.dialogues._grant_reward(game.quests.get_reward(quest)))
	var companion := str(info(id)["companion"])
	game.hud.show_title_card("%s — история завершена" % str(game.crew.info(companion).get("name", companion)), 2.6)
	game._show_dialogue(str(game.crew.info(companion).get("name", companion)), StoryText.format(str(option.get("text", ""))) + ("\n\n" + summary if not summary.is_empty() else ""))
	game.achievements.add("companion_stories")
	game.update_npc_markers()
	game.request_autosave()
	return true

# --- In the world ------------------------------------------------------------------

func populate() -> void:
	for node in get_tree().get_nodes_in_group("cq_spot"):
		node.queue_free()
	for id in steps:
		var step := current(str(id))
		if step.is_empty() or str(step.get("region", "")) != game.current_region or str(step.get("kind", "")) != "spot":
			continue
		var spot := TowerObject.new()
		spot.art = str(step.get("art", "pouch"))
		spot.label = "E — %s" % str(step.get("name", "осмотреть"))
		spot.glow = Color(0.6, 0.9, 1.0, 0.55)
		spot.add_to_group("cq_spot")
		spot.add_to_group("region_actor")
		game.add_child(spot)
		spot.global_position = SkywardGame._vec(step.get("position"))
		var quest_id := str(id)
		spot.used.connect(func(_object: TowerObject) -> void: look(quest_id))

## E on a spot of the current step.
func look(id: String) -> bool:
	var step := current(id)
	if step.is_empty() or str(step.get("kind", "")) != "spot":
		return false
	var companion := str(info(id)["companion"])
	if not with_hero(companion):
		game.hud.show_message("Торен должен быть рядом — это его история." if companion == "hunter" else "Рейна должна быть рядом — это её история.", 3.0)
		return false
	var said := StoryText.format(str(step.get("text", "")))
	var last := int(steps[id]) + 1 >= (info(id).get("steps", []) as Array).size()
	if not last:
		game._show_dialogue(str(step.get("name", "")), said)
	_advance(id, said if last else "")
	return true

## A villager's talk on a "talk" step; true when it took the conversation.
func talk(npc_id: String) -> bool:
	for id in steps:
		var step := current(str(id))
		if str(step.get("kind", "")) != "talk" or str(step.get("npc", "")) != npc_id:
			continue
		if not with_hero(str(info(str(id))["companion"])):
			return false
		game._show_dialogue(str(step.get("speaker", "")), StoryText.format(str(step.get("text", ""))))
		_advance(str(id))
		return true
	return false

func marker(npc_id: String) -> String:
	for id in steps:
		var step := current(str(id))
		if str(step.get("kind", "")) == "talk" and str(step.get("npc", "")) == npc_id:
			return "quest"
	return ""

func _process(_delta: float) -> void:
	if game == null or game.get_tree().paused or game.player == null:
		return
	if not _fight_quest.is_empty():
		_foes = _foes.filter(func(foe: Variant) -> bool: return is_instance_valid(foe) and not (foe as Node).is_queued_for_deletion() and (foe as SlimeEnemy).health > 0)
		if _foes.is_empty():
			var id := _fight_quest
			_fight_quest = ""
			if steps.has(id) and str(current(id).get("kind", "")) == "fight":
				game.hud.show_message("Тихо. Можно идти дальше.", 2.5)
				_advance(id)
		elif not steps.has(_fight_quest) or str(current(_fight_quest).get("region", "")) != game.current_region:
			_fight_quest = ""
			_foes.clear()
		return
	for id in steps:
		var step := current(str(id))
		if str(step.get("kind", "")) != "fight" or str(step.get("region", "")) != game.current_region:
			continue
		var at := SkywardGame._vec(step.get("position"))
		if game.player.global_position.distance_to(at) > NEAR or not with_hero(str(info(str(id))["companion"])):
			continue
		_start_fight(str(id), step, at)
		return

func _start_fight(id: String, step: Dictionary, at: Vector2) -> void:
	_fight_quest = id
	_foes.clear()
	game._show_dialogue(str(step.get("name", "")), StoryText.format(str(step.get("text", ""))))
	var kinds: Array = step.get("foes", [])
	var map := game.world.get_world_2d().navigation_map
	for i in kinds.size():
		var kind := str(kinds[i])
		var elite := ""
		if kind.ends_with("@"):
			kind = kind.trim_suffix("@")
			elite = EliteModifiers.pick(game.loot_rng)
		var spot := at + Vector2.RIGHT.rotated(TAU * float(i) / float(kinds.size())) * 90.0
		spot = NavigationServer2D.map_get_closest_point(map, spot) if NavigationServer2D.map_get_iteration_id(map) > 0 else spot
		var foe := game.spawn_enemy(kind, spot, elite)
		if foe == null:
			continue
		foe.detection_radius = 999.0
		foe.give_up_radius = 2000.0
		_foes.append(foe)

## Map pins: where the current step is.
func targets() -> Array:
	var result: Array = []
	for id in steps:
		var step := current(str(id))
		if step.is_empty():
			continue
		var position: Variant = step.get("position", null)
		if position == null and str(step.get("kind", "")) == "talk":
			for npc in RegionCatalog.get_region(str(step.get("region", ""))).get("npcs", []):
				if str(npc.get("id", "")) == str(step.get("npc", "")):
					position = npc.get("position")
		if position != null:
			result.append({"region": str(step.get("region", "")), "position": SkywardGame._vec(position), "kind": "side", "title": str(info(str(id)).get("title", ""))})
	return result

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("cq_"):
		return false
	var parts := choice_id.split(":")
	if choice_id.begins_with("cq_start:"):
		var id := parts[1]
		var companion := str(info(id).get("companion", ""))
		game._show_dialogue_choices(str(game.crew.info(companion).get("name", companion)), StoryText.format(str(info(id).get("intro", ""))), [
			{"id": "cq_accept:" + id, "label": "Пойдём вместе"},
			{"id": "cq_later", "label": "Не сейчас"}])
		return true
	if choice_id.begins_with("cq_accept:"):
		game.dialogues._close()
		start(parts[1])
		return true
	if choice_id.begins_with("cq_status:"):
		var id := parts[1]
		var step := current(id)
		if step.is_empty():
			_offer_ending(id)
			return true
		var where := RegionCatalog.display_name(str(step.get("region", ""))) if step.has("region") else ""
		game._show_dialogue(str(info(id).get("title", "")), "Дальше: %s%s." % [str(step.get("name", step.get("speaker", "…"))), (" — " + where) if not where.is_empty() else ""])
		return true
	if choice_id.begins_with("cq_end:"):
		game.dialogues._close()
		finish(parts[1], parts[2])
		return true
	if choice_id == "cq_later":
		game.dialogues._close()
		return true
	return false

func make_snapshot() -> Dictionary:
	return {"steps": steps.duplicate(), "endings": endings.duplicate()}

func restore_snapshot(value: Variant) -> void:
	var saved: Dictionary = value if value is Dictionary else {}
	steps = (saved.get("steps", {}) as Dictionary).duplicate() if saved.get("steps", {}) is Dictionary else {}
	endings = (saved.get("endings", {}) as Dictionary).duplicate() if saved.get("endings", {}) is Dictionary else {}
	_fight_quest = ""
	_foes.clear()
