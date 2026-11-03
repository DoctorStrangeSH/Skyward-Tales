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
	elif herb.item_id == "map_fragment":
		_collect_map_fragment(herb)
	else:
		_collect_quest_herb(herb)
	game._refresh_hud()

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
	var required_quest: String = "grove_spirits" if game.current_region == "moonlit_grove" else "moonleaf_gathering"
	if quests.active_quest_id != required_quest or quests.is_completed(required_quest):
		game.hud.show_message(herb.display_name + ". Поговорите с местным хранителем, чтобы узнать, зачем он нужен.", 2.5)
		return
	quests.add_progress(required_quest, 1)
	_collect(herb)
	game.hud.show_message(herb.display_name + " собран.", 1.5)
	if quests.is_ready_to_complete(required_quest):
		game.hud.show_message("Все предметы собраны! Вернитесь к хранителю.", 3.0)
