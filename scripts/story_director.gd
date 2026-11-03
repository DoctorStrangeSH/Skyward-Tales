extends RefCounted
class_name StoryDirector

## Drives the main story from data/dialogues.json "chain":
## - after a quest completes, start the next main quest and queue its scene;
## - "talk" objectives: talking to an NPC plays a scene and completes the quest;
## - region "on_enter" scenes (once, remembered in story flags);
## - boss defeats that finish a chapter.
## Story mode is on only for adventures started from the title menu
## (main_prologue started), so older saves and tests keep the classic flow.

var game: SkywardGame
var chain: Array = []
var on_enter: Array = []
var bosses: Dictionary = {}
var flags: Dictionary = {}
var _queue: Array[Dictionary] = []

func _init(owner_game: SkywardGame) -> void:
	game = owner_game
	var file := FileAccess.open(StoryScene.DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		chain = parsed.get("chain", [])
		on_enter = parsed.get("on_enter", [])
		bosses = parsed.get("bosses", {})

func story_mode() -> bool:
	return bool(game.quests.states.get("main_prologue", {}).get("started", false))

func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))

func set_flag(flag: String) -> void:
	flags[flag] = true

## Scenes wait until no dialogue is open, then play one by one.
func queue_scene(scene_id: String, on_finished: Callable = Callable()) -> void:
	_queue.append({"scene": scene_id, "done": on_finished})

func has_pending() -> bool:
	return not _queue.is_empty()

func update() -> void:
	if _queue.is_empty() or game.story.active or game.hud.dialogue_visible or game.get_tree().paused:
		return
	var next: Dictionary = _queue.pop_front()
	game.story.play(str(next["scene"]), next["done"])

func on_quest_completed(quest_id: String) -> void:
	if not story_mode():
		return
	for link in chain:
		if str(link.get("after", "")) != quest_id:
			continue
		var next_quest := str(link.get("start", ""))
		var scene := str(link.get("scene", ""))
		queue_scene(scene, func() -> void:
			if not next_quest.is_empty() and game.quests.start_quest(next_quest):
				game.hud.show_message("Новая глава: " + str(game.quests.definitions[next_quest].get("title", "")), 3.0)
				game.spawn_story_objects()
			game._refresh_hud())

## Returns true if talking to this NPC advanced the main story.
func try_talk(npc_id: String) -> bool:
	if not story_mode() or game.story.active:
		return false
	var quest_id := game.quests.active_quest_id
	var definition: Dictionary = game.quests.definitions.get(quest_id, {})
	if str(definition.get("talk_to", "")) != npc_id:
		return false
	game.story.play(str(definition.get("talk_scene", "")), func() -> void: _complete(quest_id))
	return true

## The NPC the current main objective asks to talk to (for markers).
func talk_target() -> String:
	if not story_mode():
		return ""
	return str(game.quests.definitions.get(game.quests.active_quest_id, {}).get("talk_to", ""))

func on_region_entered(region_id: String) -> void:
	if not story_mode():
		return
	for trigger in on_enter:
		var flag := str(trigger.get("flag", ""))
		if str(trigger.get("region", "")) == region_id and not has_flag(flag):
			set_flag(flag)
			queue_scene(str(trigger.get("scene", "")))

func on_boss_defeated(kind: String) -> void:
	if not story_mode() or not bosses.has(kind):
		return
	var data: Dictionary = bosses[kind]
	var quest_id := str(data.get("completes", ""))
	queue_scene(str(data.get("scene", "")), func() -> void:
		_complete(quest_id)
		var item := str(data.get("grants_item", ""))
		if not item.is_empty():
			game.player.add_item(item)
			game.hud.show_message("Получено: " + game.player.get_item_name(item), 3.0)
		if data.has("title"):
			game.hud.show_title_card(str(data["title"]), 4.0))

func _complete(quest_id: String) -> void:
	var quests := game.quests
	if quest_id.is_empty() or not quests.states.has(quest_id) or quests.is_completed(quest_id):
		return
	if not bool(quests.states[quest_id].get("started", false)):
		quests.start_quest(quest_id)
	var target := int(quests.definitions[quest_id].get("target", 1))
	quests.add_progress(quest_id, target)
	if quests.complete_quest(quest_id):
		game._grant_quest_reward(quest_id)
		game.hud.show_message("Глава завершена: " + str(quests.definitions[quest_id].get("title", "")), 3.0)
	game._refresh_hud()

func make_snapshot() -> Dictionary:
	return flags.duplicate(true)

func restore_snapshot(data: Variant) -> void:
	flags = data.duplicate(true) if data is Dictionary else {}
	_queue.clear()
