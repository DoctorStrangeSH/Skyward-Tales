extends RefCounted
class_name QuestPickups

## Handles world collectibles: quest herbs, Bran's supply crates,
## Mira's journal pages and iron ore veins.

const SUPPLY_QUEST := "bran_supply_run"
const NOTES_QUEST := "lost_cartographer_notes"

var game: SkywardGame

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

func _collect(herb: WorldCollectible) -> void:
	Vfx.sparkle(game, herb.global_position)
	herb.queue_free()

func handle(herb: WorldCollectible) -> void:
	if herb == null:
		return
	if herb.item_id.begins_with("supply_crate_"):
		_collect_supply_crate(herb)
	elif herb.item_id.begins_with("iron_ore_node_"):
		_mine_ore(herb)
	elif herb.item_id == "meteor_iron":
		_collect_meteor(herb)
	elif not game.story_object(herb.item_id).is_empty():
		_inspect_story_object(herb)
		return
	elif herb.item_id == "map_fragment":
		_collect_map_fragment(herb)
	else:
		_collect_quest_herb(herb)
	game._refresh_hud()

## Borin's star iron: progress, not an instant completion.
func _collect_meteor(herb: WorldCollectible) -> void:
	if game.quests.is_active(BorinStory.DREAM):
		game.quests.add_progress(BorinStory.DREAM, 1)
		game.hud.show_title_card("Звёздное железо!", 2.0)
		game.hud.show_message("Тяжёлое, звенящее железо со звезды. Отнесите его Борину.", 3.5)
		GameAudio.play("level_up", -6.0, 0.0)
	_collect(herb)

## Plays the object's scene, then completes its main-story quest.
func _inspect_story_object(herb: WorldCollectible) -> void:
	var data := game.story_object(herb.item_id)
	var quest_id := str(data.get("quest", ""))
	if game.story.active:
		return
	var spawns: Dictionary = data.get("spawns", {})
	game.story.play(str(data.get("scene", "")), func() -> void:
		if not spawns.is_empty():
			# The scene unleashes a boss; the quest completes when it falls.
			var pos: Array = spawns.get("position", [0, 0])
			game.spawn_enemy(str(spawns.get("kind", "")), Vector2(float(pos[0]), float(pos[1])))
			if is_instance_valid(herb):
				_collect(herb)
			return
		if game.quests.states.has(quest_id) and not game.quests.is_completed(quest_id):
			game.quests.add_progress(quest_id, 1)
			if game.quests.complete_quest(quest_id):
				game._grant_quest_reward(quest_id)
				game.hud.show_message("Задание выполнено: " + str(game.quests.definitions[quest_id].get("title", "")), 3.0)
		if is_instance_valid(herb):
			_collect(herb)
		game._refresh_hud())

func _collect_supply_crate(herb: WorldCollectible) -> void:
	var quests := game.quests
	if quests.active_quest_id != SUPPLY_QUEST or quests.is_completed(SUPPLY_QUEST):
		game.hud.show_message("Потерянный ящик с припасами. Бран наверняка знает, кому он принадлежит.", 2.5)
		return
	var crate_index := int(herb.item_id.trim_prefix("supply_crate_"))
	var collected: Array = quests.states[SUPPLY_QUEST].get("collected_crates", [])
	if crate_index < 0 or crate_index >= 3 or collected.has(crate_index):
		return
	collected.append(crate_index)
	quests.states[SUPPLY_QUEST]["collected_crates"] = collected
	quests.add_progress(SUPPLY_QUEST, 1)
	_collect(herb)
	game.hud.show_message("Возвращён ящик с припасами: %d/3." % int(quests.states[SUPPLY_QUEST].get("progress", 0)), 2.0)
	if quests.is_ready_to_complete(SUPPLY_QUEST):
		game.hud.show_message("Все три ящика найдены! Вернитесь к Брану.", 3.0)

func _mine_ore(herb: WorldCollectible) -> void:
	_collect(herb)
	if bool(game.gathered_resource_nodes.get(herb.item_id, false)):
		return
	game.gathered_resource_nodes[herb.item_id] = true
	game.player.add_item("iron_ore", 1)
	game.hud.show_message("Железная руда собрана. Всего: %d." % int(game.player.inventory.get("iron_ore", 0)), 2.0)

func _collect_map_fragment(herb: WorldCollectible) -> void:
	var quests := game.quests
	if quests.active_quest_id != NOTES_QUEST or quests.is_completed(NOTES_QUEST):
		game.hud.show_message("Обрывок полевого дневника. Возможно, Мира знает, кому он принадлежит.", 2.5)
		return
	quests.add_progress(NOTES_QUEST, 1)
	_collect(herb)
	game.hud.show_message("Найден обрывок полевого дневника.", 2.0)
	if quests.is_ready_to_complete(NOTES_QUEST):
		game.hud.show_message("Обе страницы найдены! Вернитесь к Мире.", 3.0)

func _collect_quest_herb(herb: WorldCollectible) -> void:
	var quests := game.quests
	var required_quest: String = herb.quest_id if not herb.quest_id.is_empty() else RegionCatalog.herb_quest(game.current_region)
	if not quests.is_active(required_quest):
		game.hud.show_message(herb.display_name + ". Поговорите с местным хранителем, чтобы узнать, зачем он нужен.", 2.5)
		return
	quests.add_progress(required_quest, 1)
	_collect(herb)
	game.hud.show_message(herb.display_name + " собран.", 1.5)
	if quests.is_ready_to_complete(required_quest):
		game.hud.show_message("Все предметы собраны! Вернитесь к хранителю.", 3.0)
