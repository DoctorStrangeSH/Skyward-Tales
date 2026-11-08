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
const SHOP := {"steel_sword": 220, "steel_mail": 240, "skysteel_blade": 620, "skysteel_mail": 640,
	"scout_knife": 140, "guard_spear": 140, "smith_hammer": 150}
## Sold once the forge is expanded (level 3).
const SHOP_3 := {"shadow_dagger": 380, "coral_pike": 380, "mountain_maul": 400, "warden_plate": 820, "keeper_hourglass": 900}
## Forge level 3: gold and materials.
const FORGE_3 := "borin_forge_3"
const EXPAND_COST := {"gold": 900, "materials": {"iron_ore": 12, "obsidian_shard": 4, "wind_essence": 2}}

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
		choices.append({"id": "borin_forge", "label": "⚒ Заточка снаряжения (до +%d)" % forge_level()})
		choices.append({"id": "borin_shop", "label": "Купить оружие и броню"})
		if forge_level() < 3:
			choices.append({"id": "borin_expand", "label": "Расширить кузницу — %s" % cost_text(EXPAND_COST)})
		choices.append({"id": "borin_craft", "label": "Усилить снаряжение"})
		choices.append({"id": "borin_later", "label": "Уйти"})
		var line := "Кузница гудит как улей! Заточу что угодно, а легендарное — пробужу." if forge_level() >= 3 else "Новая кузница гудит как улей! Сталь и небесный металл — выбирай."
		game._show_dialogue_choices("Борин, кузнец", line, choices)
		return true
	return false

# --- Forge (Этап 14): sharpening, awakening, the third forge -----------------

## 1 — the old smithy, 2 — after "Небесный коготь", 3 — expanded.
func forge_level() -> int:
	if game.director.has_flag(FORGE_3):
		return 3
	return 2 if upgraded() else 1

## Highest forging level for an item at this forge (+5 — awakened legendary).
func max_upgrade(item_id: String) -> int:
	var rarity := str(game.player.get_item_definition(item_id).get("rarity", ""))
	if forge_level() >= 3 and rarity == "legendary":
		return 5
	return forge_level()

func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = ["%d золота" % int(cost.get("gold", 0))]
	var materials: Dictionary = cost.get("materials", {})
	for material in materials:
		parts.append("%s ×%d" % [game.player.get_item_name(str(material)), int(materials[material])])
	return ", ".join(parts)

## Gear that can be forged now: worn first, then the bag.
func forgeable() -> Array:
	var result: Array = []
	var player := game.player
	for slot in player.equipment:
		var item_id := str(player.equipment[slot])
		if not item_id.is_empty() and player.upgrade_level(item_id) < max_upgrade(item_id):
			result.append(item_id)
	for item_id in player.inventory:
		var id := str(item_id)
		if not result.has(id) and not str(player.get_item_definition(id).get("slot", "")).is_empty() and player.upgrade_level(id) < max_upgrade(id):
			result.append(id)
	return result

func open_forge() -> void:
	var player := game.player
	var choices: Array[Dictionary] = []
	for item_id in forgeable().slice(0, 7):
		var level := player.upgrade_level(item_id)
		var cost := player.upgrade_cost(item_id)
		var mark := "" if player.can_pay(cost) else "✗ "
		var verb := "пробудить" if level + 1 >= 4 else "+%d" % (level + 1)
		choices.append({"id": "borin_up:" + str(item_id), "label": "%s%s → %s — %s" % [mark, player.get_item_name(item_id), verb, cost_text(cost)]})
	choices.append({"id": "borin_later", "label": "Хватит"})
	var line := "Каждая заточка — +15%% к характеристикам вещи. Сейчас моя кузница точит до +%d." % forge_level()
	if forge_level() >= 3:
		line += " Легендарное оружие могу пробудить до +5 — нужен звёздный металл."
	if choices.size() == 1:
		line = "Нечего точить: всё твоё снаряжение уже заточено до предела моей кузницы."
	game._show_dialogue_choices("Борин, кузнец", line, choices)

func open_shop() -> void:
	var choices: Array[Dictionary] = []
	var stock := SHOP.duplicate() if forge_level() >= 2 else {"scout_knife": 140, "guard_spear": 140, "smith_hammer": 150}
	if forge_level() >= 3:
		stock.merge(SHOP_3)
	for item_id in stock:
		choices.append({"id": "borin_buy:" + str(item_id), "label": "%s — %d золота" % [game.player.get_item_name(str(item_id)), int(stock[item_id])]})
	choices.append({"id": "borin_later", "label": "Хватит"})
	game._show_dialogue_choices("Борин, кузнец", "Кинжалы — для быстрых, копья — для осторожных, молоты — для упрямых. Выбирай.", choices)

func expand_forge() -> bool:
	if forge_level() != 2 or not game.player.can_pay(EXPAND_COST):
		return false
	game.player.add_gold(-int(EXPAND_COST["gold"]))
	var materials: Dictionary = EXPAND_COST["materials"]
	for material in materials:
		game.player.remove_item(str(material), int(materials[material]))
	game.director.set_flag(FORGE_3)
	game.refresh_world_art()
	game.achievements.add("forge")
	game.hud.show_title_card("Кузница · ур. 3", 2.5)
	return true

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
		"borin_forge":
			open_forge()
			return true
		"borin_shop":
			open_shop()
			return true
		"borin_expand":
			if expand_forge():
				game._show_dialogue("Борин, кузнец", "Третий горн, мехи из шкуры горного быка и наковальня из метеорита! Теперь я точу до +3, а легендарное — пробуждаю. И в лавке прибавилось товара.")
			else:
				game.hud.show_message("Нужно: %s." % cost_text(EXPAND_COST), 3.0)
				talk()
			return true
	if choice_id.begins_with("borin_up:"):
		var item_id := choice_id.trim_prefix("borin_up:")
		var cost := game.player.upgrade_cost(item_id)
		if game.player.upgrade_level(item_id) >= max_upgrade(item_id):
			return true
		if not game.player.can_pay(cost):
			game.hud.show_message("Нужно: %s." % cost_text(cost), 3.0)
		else:
			var forged := game.player.upgrade_item(item_id)
			if not forged.is_empty():
				GameAudio.play("hit", -2.0, 0.2)
				game.shake(2.0, 0.15)
				game.achievements.add("forged")
				game.hud.show_message("Заточено: %s!" % game.player.get_item_name(forged), 3.0)
				if game.player.upgrade_level(forged) == 4:
					game.hud.show_title_card("Пробуждение!", 2.0)
		open_forge()
		return true
	if choice_id.begins_with("borin_buy:"):
		var item_id := choice_id.trim_prefix("borin_buy:")
		var price := int(SHOP.get(item_id, SHOP_3.get(item_id, 0)))
		if forge_level() < 2 and not item_id in ["scout_knife", "guard_spear", "smith_hammer"] or forge_level() < 3 and SHOP_3.has(item_id):
			return true
		if price <= 0:
			return true
		if game.player.gold < price:
			game.hud.show_message("Не хватает золота: нужно %d." % price, 2.5)
		else:
			game.player.add_gold(-price)
			game.player.add_item(item_id, 1)
			game.hud.show_message("Куплено: %s." % game.player.get_item_name(item_id), 2.5)
		open_shop()
		return true
	return false

func _close() -> void:
	game.hud.close_dialogue()
	game.player.set_physics_process(true)
	game._refresh_hud()
