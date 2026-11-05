extends RefCounted
class_name BorinStory

## Borin the blacksmith's own story: he dreams of a blade of sky metal.
##   borin_dream  — star iron lies in the Stone Pass mine, overrun by monsters
##                  (taking the quest sets "mine_overrun"; clear it, pick up
##                  the iron, bring the news back);
##   borin_temper — the blade must be tempered in ash: bring 3 obsidian shards.
## The reward is the Skyclaw blade, and the forge itself changes: a second
## forge and weapon racks in the village (flag "borin_forge_2"), and Borin
## sells steel and sky-steel gear.

const DREAM := "borin_dream"
const TEMPER := "borin_temper"
const FLAG := "borin_forge_2"
const MIN_LEVEL := 6
const SHARDS := 3
const SHOP := {"steel_sword": 220, "steel_mail": 240, "skysteel_blade": 620, "skysteel_mail": 640}

var game: SkywardGame

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

func _quests() -> QuestManager:
	return game.quests

func can_offer_dream() -> bool:
	var q := _quests()
	return game.player.level >= MIN_LEVEL and not bool(q.states.get(DREAM, {}).get("started", false)) and not q.is_completed(DREAM)

func can_offer_temper() -> bool:
	var q := _quests()
	return q.is_completed(DREAM) and not bool(q.states.get(TEMPER, {}).get("started", false)) and not q.is_completed(TEMPER)

func shards() -> int:
	return int(game.player.inventory.get("obsidian_shard", 0))

## Keeps the tracker honest: the delivery counts what the hero carries.
func sync_progress() -> void:
	var q := _quests()
	if q.is_active(TEMPER):
		q.states[TEMPER]["progress"] = mini(SHARDS, shards())

func marker() -> String:
	var q := _quests()
	if q.is_ready_to_complete(DREAM) or (q.is_active(TEMPER) and shards() >= SHARDS):
		return "ready"
	if can_offer_dream() or can_offer_temper():
		return "quest"
	return ""

func upgraded() -> bool:
	return game.director.has_flag(FLAG)

## True when Borin's story took the conversation.
func talk() -> bool:
	var q := _quests()
	if q.is_ready_to_complete(DREAM):
		q.complete_quest(DREAM)
		game.npc_reward(DREAM)
		game._show_dialogue_choices("Борин, кузнец", "Звёздное железо… настоящее! Чувствуешь, как звенит? Но сырой металл треснет. Закалить его можно лишь в пепле — принеси мне три обсидиановых осколка из Пепельной пустоши.", [
			{"id": "borin_accept:temper", "label": "Принесу осколки"},
			{"id": "borin_later", "label": "Позже"}])
		return true
	if q.is_active(TEMPER):
		if shards() >= SHARDS:
			game.player.remove_item("obsidian_shard", SHARDS)
			q.states[TEMPER]["progress"] = SHARDS
			q.complete_quest(TEMPER)
			game.npc_reward(TEMPER)
			game.director.set_flag(FLAG)
			game.refresh_world_art()
			game.hud.show_title_card("Кузница Борина", 2.5)
			game._show_dialogue("Борин, кузнец", "Три дня и три ночи у горна — и вот он, «Небесный коготь». Он твой, {hero}. А я теперь умею работать со сталью и небесным металлом: заходи за оружием и бронёй, каких в деревне ещё не видели. Глянь, какую мастерскую отстроил!")
		else:
			game._show_dialogue("Борин, кузнец", "Обсидиановые осколки: %d из %d. Ищи их у пепельных тварей в Пепельной пустоши." % [mini(shards(), SHARDS), SHARDS])
		return true
	if q.is_active(DREAM):
		var where := "Шахта ещё в лапах тварей — одолей их вожака у входа." if game.mine.overrun() else "Шахта свободна — ищи звёздное железо у самого входа."
		game._show_dialogue("Борин, кузнец", "Звёздное железо лежит в шахте на Каменном Перевале. " + where)
		return true
	if can_offer_dream():
		game._show_dialogue_choices("Борин, кузнец", "Знаешь, {hero}, всю жизнь мечтаю выковать клинок из небесного металла. Говорят, в шахту на Каменном Перевале упала звезда — да только шахту захватили твари. Поможешь старику?", [
			{"id": "borin_accept:dream", "label": "Помогу добыть звёздное железо"},
			{"id": "borin_later", "label": "Позже"}])
		return true
	if can_offer_temper():
		game._show_dialogue_choices("Борин, кузнец", "Ну что, найдёшь три обсидиановых осколка для закалки?", [
			{"id": "borin_accept:temper", "label": "Принесу осколки"},
			{"id": "borin_later", "label": "Позже"}])
		return true
	if upgraded():
		var choices: Array[Dictionary] = []
		for item_id in SHOP:
			choices.append({"id": "borin_buy:" + item_id, "label": "%s — %d золота" % [game.player.get_item_name(item_id), int(SHOP[item_id])]})
		choices.append({"id": "borin_craft", "label": "Усилить снаряжение"})
		choices.append({"id": "borin_later", "label": "Уйти"})
		game._show_dialogue_choices("Борин, кузнец", "Новая кузница гудит как улей! Сталь и небесный металл — выбирай.", choices)
		return true
	return false

func handle_choice(choice_id: String) -> bool:
	match choice_id:
		"borin_accept:dream":
			game.quests.start_quest(DREAM)
			# The star iron is in a mine full of monsters.
			game.mine.start_overrun(30.0)
			game.hud.show_message("Задание: Небесный металл. Шахта на Каменном Перевале захвачена!", 3.5)
			_close()
			return true
		"borin_accept:temper":
			game.quests.start_quest(TEMPER)
			sync_progress()
			_close()
			return true
		"borin_later":
			_close()
			return true
		"borin_craft":
			_close()
			game.dialogues.on_blacksmith_crafting()
			return true
	if choice_id.begins_with("borin_buy:"):
		var item_id := choice_id.trim_prefix("borin_buy:")
		var price := int(SHOP.get(item_id, 0))
		if price <= 0:
			return true
		if game.player.gold < price:
			game.hud.show_message("Не хватает золота: нужно %d." % price, 2.5)
		else:
			game.player.add_gold(-price)
			game.player.add_item(item_id, 1)
			game.hud.show_message("Куплено: %s." % game.player.get_item_name(item_id), 2.5)
		talk()
		return true
	return false

func _close() -> void:
	game.hud.close_dialogue()
	game.player.set_physics_process(true)
	game._refresh_hud()
