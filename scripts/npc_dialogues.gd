extends RefCounted
class_name NpcDialogues

## Conversations, quest hand-ins, trading and crafting for every NPC.
## SkywardGame keeps thin `_on_*_interacted` wrappers so scenes and tests keep working.

var game: SkywardGame

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

# --- Shared helpers ------------------------------------------------------

func _close() -> void:
	game.hud.close_dialogue()
	game.player.set_physics_process(true)

func _say(speaker: String, message: String) -> void:
	game._show_dialogue(speaker, message)

func _ask(speaker: String, message: String, choices: Array[Dictionary]) -> void:
	game._show_dialogue_choices(speaker, message, choices)

func _item_name(item_id: String) -> String:
	return game.player.get_item_name(item_id)

## Grants experience, gold and item rewards; returns a readable item summary.
func _grant_reward(reward: Dictionary) -> String:
	game.player.add_experience(int(reward.get("experience", 0)))
	game.player.add_gold(int(reward.get("gold", 0)))
	var summary := ""
	var items: Variant = (reward.get("items", []) as Array).duplicate() if reward.get("items", []) is Array else []
	# "items_by_flag": gifts that depend on a story flag (the finale choice).
	var by_flag: Variant = reward.get("items_by_flag", {})
	if by_flag is Dictionary:
		for flag in by_flag:
			if game.director.has_flag(str(flag)) and by_flag[flag] is Array:
				items.append_array(by_flag[flag])
	if items is Array:
		for item in items:
			if item is Dictionary:
				var item_id := str(item.get("id", ""))
				var amount := maxi(1, int(item.get("amount", 1)))
				if not item_id.is_empty():
					game.player.add_item(item_id, amount)
					summary += ", %s ×%d" % [_item_name(item_id), amount]
	return summary

# --- Quest markers -------------------------------------------------------

## What floats above an NPC: "quest" (!), "ready" (?), "service" (craft) or "".
## Mirrors the conditions used by the conversations below.
func marker_for(npc_id: String) -> String:
	var quests := game.quests
	if game.givers != null and game.givers.has_giver(npc_id):
		return game.givers.marker_for(npc_id)
	if game.settlement != null and game.settlement.has_settler_npc(npc_id):
		return game.settlement.marker_for(npc_id)
	if game.director != null and game.director.talk_target() == npc_id:
		var definition: Dictionary = quests.definitions.get(quests.active_quest_id, {})
		if not bool(definition.get("talk_requires_progress", false)) or quests.is_ready_to_complete(quests.active_quest_id):
			return "ready"
	var free: bool = quests.active_quest_id.is_empty()
	var village_helped: bool = quests.is_completed("moonleaf_gathering")
	var quest_id: String = {
		"elder": "moonleaf_gathering", "cartographer": "lost_cartographer_notes",
		"grove_warden": "grove_spirits", "hunter": "toren_wolf_hunt", "merchant": "bran_supply_run",
		"miner": "crystal_heart"
	}.get(npc_id, "")
	if not quest_id.is_empty():
		if quests.is_ready_to_complete(quest_id):
			return "ready"
		var started: bool = bool(quests.states.get(quest_id, {}).get("started", false))
		var unlocked: bool = npc_id in ["elder", "grove_warden", "miner"] or village_helped
		var can_take: bool = free or (npc_id in ["grove_warden", "miner"] and quests.active_quest_id == quest_id)
		if not started and not quests.is_completed(quest_id) and unlocked and can_take:
			return "quest"
	if npc_id == "hunter" and quests.is_completed("toren_wolf_hunt") and _can_craft_mantle():
		return "service"
	if npc_id == "blacksmith":
		var story := game.borin.marker()
		if not story.is_empty():
			return story
		for recipe in ["reinforce_wolfskin_mantle", "forge_ironbound_staff"]:
			if bool(game.crafting_service.get_recipe_status(game.player, recipe).get("success", false)):
				return "service"
	return ""

## The marker sprite for an NPC: story quests are gold, side quests blue,
## services green ("quest_main", "ready_main", "quest", "ready", "service").
func marker_style(npc_id: String, marker: String) -> String:
	if not marker in ["quest", "ready"]:
		return marker
	return marker + "_main" if _is_main(_marker_quest(npc_id)) else marker

func _is_main(quest_id: String) -> bool:
	return bool(game.quests.definitions.get(quest_id, {}).get("main", false))

## Which quest an NPC's marker is about ("" when unknown).
func _marker_quest(npc_id: String) -> String:
	if game.givers != null and game.givers.has_giver(npc_id):
		return game.givers.current_quest(npc_id)
	if game.director != null and game.director.talk_target() == npc_id:
		return game.quests.active_quest_id
	return {
		"elder": "moonleaf_gathering", "cartographer": "lost_cartographer_notes",
		"grove_warden": "grove_spirits", "hunter": "toren_wolf_hunt", "merchant": "bran_supply_run",
		"miner": "crystal_heart"
	}.get(npc_id, "")

# --- Choice routing ------------------------------------------------------

func handle_choice(choice_id: String) -> void:
	if game.givers != null and game.givers.handle_choice(choice_id):
		return
	if game.borin != null and game.borin.handle_choice(choice_id):
		return
	if game.guild != null and game.guild.handle_choice(choice_id):
		return
	if game.ship != null and game.ship.handle_choice(choice_id):
		return
	if game.factions != null and game.factions.handle_choice(choice_id):
		return
	if game.fates != null and game.fates.handle_choice(choice_id):
		return
	if game.party != null and game.party.handle_choice(choice_id):
		return
	if game.buildings != null and game.buildings.handle_choice(choice_id):
		return
	if game.farm != null and game.farm.handle_choice(choice_id):
		return
	if choice_id.begins_with("toren_buy:"):
		_toren_buy(choice_id.trim_prefix("toren_buy:"))
		return
	if game.settlement != null and game.settlement.handle_choice(choice_id):
		return
	if game.crafting != null and game.crafting.handle_choice(choice_id):
		return
	if game.contracts != null and game.contracts.handle_choice(choice_id):
		return
	if game.events != null and game.events.handle_choice(choice_id):
		return
	if choice_id.begins_with("finale:"):
		_close()
		game.choose_finale(choice_id.trim_prefix("finale:"))
		return
	match choice_id:
		"merchant_quest_start":
			_start_merchant_supply_quest()
		"hunter_quest_start":
			_start_hunter_quest()
		"hunter_craft:mantle":
			_craft_wolfskin_mantle()
		"blacksmith_craft:reinforce_mantle":
			_craft_blacksmith_item("reinforce_wolfskin_mantle")
		"blacksmith_craft:ironbound_staff":
			_craft_blacksmith_item("forge_ironbound_staff")
		"hunter_craft:later", "blacksmith_craft:later", "merchant_close":
			_close()
		_:
			if choice_id.begins_with("hunter_reward:"):
				_complete_hunter_quest(choice_id.trim_prefix("hunter_reward:"))
			elif choice_id.begins_with("merchant_supply:"):
				_complete_merchant_supply_quest(choice_id.trim_prefix("merchant_supply:"))
			elif choice_id.begins_with("miner_reward:"):
				_complete_miner_quest(choice_id.trim_prefix("miner_reward:"))
			elif choice_id.begins_with("merchant_sell:"):
				_sell_to_merchant(choice_id.trim_prefix("merchant_sell:"))
			elif choice_id.begins_with("legend_hunt:"):
				_close()
				game.legends.handle_choice(choice_id)
			elif choice_id.begins_with("merchant_buy:"):
				_purchase_merchant_item(choice_id.trim_prefix("merchant_buy:"))
			elif game.quests.is_ready_to_complete("moonleaf_gathering"):
				_complete_elder_quest_choice(choice_id)
			else:
				_complete_cartographer_quest_choice(choice_id)

# --- Elder Elian ---------------------------------------------------------

func on_elder() -> void:
	var quests := game.quests
	match game.epilogue.ending():
		"restore":
			_say("Старейшина Элиан", "Видишь, как ночами горит небо? Это Узор, {hero}. Острова живы, и дети спрашивают, когда ты вернёшься. Сорен из ордена искал тебя — он ждёт неподалёку.")
			game._refresh_hud()
			return
		"lower":
			_say("Старейшина Элиан", "Земля приняла нас мягко. Ночами падают звёзды, а внизу нас встретили новые соседи. Ты {сделал|сделала} верный выбор, {hero}. Сорен из ордена искал тебя — он ждёт неподалёку.")
			game._refresh_hud()
			return
	if quests.is_completed("moonleaf_gathering"):
		if game.relationships.get_score("elder") >= 20:
			_say("Старейшина Элиан", "Ты {доказал|доказала}, что думаешь не только о себе. Я открыл для тебя старое хранилище у северных руин — там поселение прятало припасы во время войны.")
		else:
			_say("Старейшина Элиан", "%s. Ты {помог|помогла} нашему поселению. На востоке есть тропа в Зачарованный лес. Найди хранительницу Илару — возможно, ей нужна помощь." % game.relationships.get_reaction("elder"))
	elif quests.active_quest_id == "main_prologue":
		_say("Старейшина Элиан", "Сначала взгляни, что упало у северных руин. Это к востоку по тропе.")
	elif quests.active_quest_id.is_empty() and quests.is_completed("main_prologue") and game.story.has_scene("elder_after_shard") and not bool(quests.states["moonleaf_gathering"]["started"]):
		game.story.play("elder_after_shard", func() -> void:
			quests.start_quest("moonleaf_gathering")
			_say("Старейшина Элиан", "Принеси три лунных листа — они очищают воздух. Растут вдоль старой тропы.")
			game._refresh_hud())
	elif quests.active_quest_id.is_empty():
		quests.start_quest("moonleaf_gathering")
		_say("Старейшина Элиан", "{hero}, туман небесной пыли ползёт к домам. Принеси три лунных листа — они очищают воздух. Растут вдоль старой тропы.")
	elif quests.is_ready_to_complete("moonleaf_gathering"):
		_ask("Старейшина Элиан", "Ты {спас|спасла} наши запасы от порчи. Я обещал награду. Но поселению тоже тяжело пережить эту зиму. Как поступим?", [
			{"id": "payment", "label": "Принять полную награду — 25 золота"},
			{"id": "village", "label": "Оставить большую часть награды поселению"}
		])
	else:
		_say("Старейшина Элиан", "Лунные листья растут вдоль старой тропы. Будь осторожен — слизни стали агрессивнее.")
	game._refresh_hud()

func _complete_elder_quest_choice(choice_id: String) -> void:
	const quest_id := "moonleaf_gathering"
	var reward: Dictionary = game.quests.get_choice_reward(quest_id, choice_id)
	if reward.is_empty() or not game.quests.complete_quest(quest_id):
		return
	game.quests.states[quest_id]["choice"] = choice_id
	var gain: int = 20 if choice_id == "village" else 5
	game.relationships.adjust("elder", gain)
	if game.relationships.get_score("elder") >= 20:
		game.reveal_secret("greenreach", "elder_hidden_storehouse")
	_grant_reward(reward)
	_close()
	if game.relationships.get_score("elder") >= 20:
		game.hud.show_message("Элиан благодарен за помощь поселению. Доверие +%d. Тайник отмечен на карте." % gain, 4.0)
	else:
		game._show_relationship_change("elder", gain)
	game._refresh_hud()

# --- Cartographer Mira ---------------------------------------------------

func on_cartographer() -> void:
	const quest_id := "lost_cartographer_notes"
	var quests := game.quests
	if quests.is_completed(quest_id):
		var choice_id: String = str(quests.states[quest_id].get("choice", ""))
		if game.relationships.get_score("mira") >= 20:
			_say("Мира, картограф", "Теперь я знаю, что могу тебе доверять. Я отметила на карте старый тайник с припасами — он находится к югу от лагеря.")
		elif choice_id == "supplies":
			_say("Мира, картограф", "%s. Надеюсь, припасы пригодились. Я уже начала восстанавливать безопасные тропы по копии дневника." % game.relationships.get_reaction("mira"))
		else:
			_say("Мира, картограф", "%s. Благодарю за возвращённый дневник. Монеты — малая плата за такую помощь." % game.relationships.get_reaction("mira"))
	elif not quests.is_completed("moonleaf_gathering"):
		_say("Мира, картограф", "Я ищу страницы своего полевого дневника. Но сначала помоги старейшине Элиану — поселению сейчас нужнее твоя помощь.")
	elif not quests.active_quest_id.is_empty() and quests.active_quest_id != quest_id:
		_say("Мира, картограф", "Понимаю, у тебя уже есть важное дело. Найди меня, когда освободишься.")
	elif not bool(quests.states[quest_id]["started"]):
		quests.start_quest(quest_id)
		_say("Мира, картограф", "Ветер разметал страницы моего полевого дневника возле старого лагеря. Найди два обрывка на поляне и принеси их мне. Там записаны безопасные тропы через лес.")
	elif quests.is_ready_to_complete(quest_id):
		_ask("Мира, картограф", "Ты {нашёл|нашла} обе страницы! Я хочу отблагодарить тебя. Что тебе сейчас нужнее?", [
			{"id": "gold", "label": "Взять 35 золотых монет"},
			{"id": "supplies", "label": "Попросить 2 зелья маны и 10 монет"}
		])
	else:
		_say("Мира, картограф", "Ищи страницы у старого лагеря, чуть восточнее от меня. На них нарисованы отметки безопасных троп.")
	game._refresh_hud()

func _complete_cartographer_quest_choice(choice_id: String) -> void:
	const quest_id := "lost_cartographer_notes"
	if not game.quests.is_ready_to_complete(quest_id):
		return
	var reward: Dictionary = game.quests.get_choice_reward(quest_id, choice_id)
	if reward.is_empty() or not game.quests.complete_quest(quest_id):
		return
	game.quests.states[quest_id]["choice"] = choice_id
	var gain: int = 20 if choice_id == "supplies" else 8
	game.relationships.adjust("mira", gain)
	if game.relationships.get_score("mira") >= 20:
		game.reveal_secret("greenreach", "secret_cartographer_cache")
	_grant_reward(reward)
	_close()
	if game.relationships.get_score("mira") >= 20:
		game.hud.show_message("Доверие с Мирой: +%d — %s. Тайник отмечен на карте." % [gain, game.relationships.get_rank("mira")], 4.0)
	else:
		game._show_relationship_change("mira", gain)
	game._refresh_hud()

# --- Warden Ilara --------------------------------------------------------

func on_grove_warden() -> void:
	var quests := game.quests
	if quests.is_completed("grove_spirits"):
		if game.relationships.get_score("ilara") >= 20:
			_say("Хранительница Илара", "Лес доверяет тебе. Я отметила на карте древний тайник у камней — там хранятся припасы для тех, кто защищает рощу.")
		else:
			_say("Хранительница Илара", "%s. Лес запомнит твою доброту." % game.relationships.get_reaction("ilara"))
	elif quests.active_quest_id.is_empty() or quests.active_quest_id == "grove_spirits":
		if not quests.states["grove_spirits"]["started"]:
			quests.start_quest("grove_spirits")
			_say("Хранительница Илара", "Лес теряет свой свет. Собери три духовных цветка у старых камней и принеси их мне.")
		elif quests.is_ready_to_complete("grove_spirits"):
			if quests.complete_quest("grove_spirits"):
				game._grant_quest_reward("grove_spirits")
				game.relationships.adjust("ilara", 20)
				game.reveal_secret("moonlit_grove", "ilara_ancient_cache")
				game._show_relationship_change("ilara", 20)
			game.spawn_region_boss()
			_say("Хранительница Илара", "Ты {вернул|вернула} лесу его сияние. Прими эту награду.")
		else:
			_say("Хранительница Илара", "Ищи духовные цветы вдоль древней тропы. Их свет виден даже в сумерках.")
	else:
		_say("Хранительница Илара", "Заверши начатое дело, прежде чем браться за новое.")
	game._refresh_hud()

# --- Hunter Toren --------------------------------------------------------

func _can_craft_mantle() -> bool:
	var player := game.player
	return int(player.inventory.get("wolf_pelt", 0)) >= 3 \
		and int(player.inventory.get("wolfskin_mantle", 0)) == 0 \
		and str(player.equipment.get("armor", "")) != "wolfskin_mantle"

## Toren's bows: the way of the ranger.
const TOREN_BOWS := {"hunting_bow": [120, 1], "elm_longbow": [380, 8]}

func _toren_bow_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for item_id in TOREN_BOWS:
		var price := int(TOREN_BOWS[item_id][0])
		var level := int(TOREN_BOWS[item_id][1])
		if game.player.level >= level:
			choices.append({"id": "toren_buy:" + item_id, "label": "%s — %d золота" % [game.player.get_item_name(item_id), price]})
	return choices

func _toren_buy(item_id: String) -> void:
	if not TOREN_BOWS.has(item_id):
		return
	var price := int(TOREN_BOWS[item_id][0])
	if game.player.gold < price:
		_say("Торен, охотник", "Хороший лук стоит хороших денег. Нужно %d золота." % price)
		return
	game.player.add_gold(-price)
	game.player.add_item(item_id, 1)
	_say("Торен, охотник", "Держи. Наденешь лук — правая рука забудет заклинания, зато стрела летит дальше любого огня. Удерживай выстрел — и бей наверняка. А капканы ставь там, где зверь пойдёт.")
	game._refresh_hud()

func on_hunter() -> void:
	const quest_id := "toren_wolf_hunt"
	var quests := game.quests
	if quests.is_completed(quest_id) and _can_craft_mantle():
		_ask("Торен, охотник", "Три волчьи шкуры — отличный материал. Я могу сшить тебе прочную волчью накидку: она защитит от ударов. Отдашь шкуры?", [
			{"id": "hunter_craft:mantle", "label": "Сшить волчью накидку — 3 шкуры"},
			{"id": "hunter_craft:later", "label": "Пока оставить шкуры"}
		])
	elif quests.is_completed(quest_id):
		var choices := _toren_bow_choices()
		var prey := game.legends.huntable()
		var hunt: Dictionary = game.legends.hunt
		if hunt.is_empty() and not prey.is_empty():
			choices.push_front({"id": "legend_hunt:" + prey, "label": "Выследить легенду: " + game.legends.legend_name(prey)})
		elif not hunt.is_empty():
			choices.push_front({"id": "hunter_craft:later", "label": "Как идёт охота? (%s)" % game.legends.legend_name(str(hunt["id"]))})
		if game.party.can_recruit("hunter"):
			choices.push_front({"id": "party_join:hunter", "label": "Пойдём со мной, Торен"})
		choices.append({"id": "hunter_craft:later", "label": "Просто поболтать"})
		_ask("Торен, охотник", "Шкуры уже высушены, а тропы снова безопасны. %s. Хочешь лук? Делаю сам." % game.relationships.get_reaction("toren"), choices)
	elif quests.is_ready_to_complete(quest_id):
		_ask("Торен, охотник", "Три волка больше не угрожают дороге. Какую награду предпочитаешь?", [
			{"id": "hunter_reward:gold", "label": "35 золота и 40 опыта"},
			{"id": "hunter_reward:supplies", "label": "20 золота, 2 зелья здоровья и 60 опыта"}
		])
	elif bool(quests.states[quest_id].get("started", false)):
		_say("Торен, охотник", "В Зачарованном лесу ещё рыщут волки. Победи трёх и возвращайся. Сейчас: %d/3." % int(quests.states[quest_id].get("progress", 0)))
	elif not quests.is_completed("moonleaf_gathering"):
		_say("Торен, охотник", "Сначала помоги старейшине Элиану. После этого поговорим о волках.")
	elif not quests.active_quest_id.is_empty():
		_say("Торен, охотник", "Закончи текущее поручение, и я расскажу об охоте.")
	else:
		_ask("Торен, охотник", "Я Торен. Волки спустились из леса и нападают на путников. Поможешь проредить стаю?", [
			{"id": "hunter_quest_start", "label": "Взяться за охоту"}
		])
	game._refresh_hud()

func _start_hunter_quest() -> void:
	if not game.quests.is_completed("moonleaf_gathering") or not game.quests.active_quest_id.is_empty():
		return
	if game.quests.start_quest("toren_wolf_hunt"):
		_say("Торен, охотник", "Найди трёх волков в Зачарованном лесу. Победи их и возвращайся за наградой.")
		game._refresh_hud()

func _complete_hunter_quest(choice_id: String) -> void:
	const quest_id := "toren_wolf_hunt"
	var reward: Dictionary = game.quests.get_choice_reward(quest_id, choice_id)
	if reward.is_empty() or not game.quests.is_ready_to_complete(quest_id):
		return
	if not game.quests.complete_quest(quest_id):
		return
	game.quests.states[quest_id]["choice"] = choice_id
	var item_summary := _grant_reward(reward)
	var trust_gain := int(reward.get("toren_trust", 0))
	game.relationships.adjust("toren", trust_gain)
	_close()
	game.hud.show_message("Охота завершена! +%d золота, +%d опыта%s. Доверие Торена +%d." % [int(reward.get("gold", 0)), int(reward.get("experience", 0)), item_summary, trust_gain], 4.0)
	game._refresh_hud()

func _craft_wolfskin_mantle() -> void:
	if not _can_craft_mantle():
		game.hud.show_message("Нужно три волчьи шкуры, а накидка уже может быть только одна.", 3.0)
		return
	game.player.remove_item("wolf_pelt", 3)
	game.player.add_item("wolfskin_mantle")
	_close()
	game.hud.show_message("Торен сшил волчью накидку! Она ждёт в инвентаре.", 3.0)
	game._refresh_hud()

# --- Blacksmith Borin ----------------------------------------------------

func on_blacksmith() -> void:
	if game.borin.talk():
		return
	on_blacksmith_crafting()

func on_blacksmith_crafting() -> void:
	var crafting := game.crafting_service
	var choices: Array[Dictionary] = []
	var mantle_status: Dictionary = crafting.get_recipe_status(game.player, "reinforce_wolfskin_mantle")
	var staff_status: Dictionary = crafting.get_recipe_status(game.player, "forge_ironbound_staff")
	if bool(mantle_status.get("success", false)):
		choices.append({"id": "blacksmith_craft:reinforce_mantle", "label": "Укрепить волчью накидку — 2 шкуры, 30 золота"})
	if bool(staff_status.get("success", false)):
		choices.append({"id": "blacksmith_craft:ironbound_staff", "label": "Усилить посох железом — 3 руды, 50 золота"})
	if not game.borin.upgraded():
		choices.push_front({"id": "borin_forge", "label": "⚒ Заточка снаряжения (до +1)"})
		choices.push_back({"id": "borin_shop", "label": "Купить оружие"})
	if not choices.is_empty():
		choices.append({"id": "blacksmith_craft:later", "label": "В другой раз"})
		_ask("Борин, кузнец", "Приноси материалы — и я превращу обычное снаряжение в надёжное оружие и броню. Выбирай работу:", choices)
	else:
		var requirements := "Для усиления накидки: волчья накидка, 2 волчьи шкуры и 30 золота. "
		requirements += "Для железного посоха: посох ученика, 3 железной руды и 50 золота."
		var missing := str(mantle_status.get("message", "")) + " " + str(staff_status.get("message", ""))
		_say("Борин, кузнец", "Я работаю с тем, что принесли. " + requirements + "\n" + missing)

func _craft_blacksmith_item(recipe_id: String) -> void:
	var result: Dictionary = game.crafting_service.craft(game.player, recipe_id)
	_close()
	game.hud.show_message(str(result.get("message", "Кузнец не смог выполнить заказ.")), 3.0)
	game._refresh_hud()

# --- Miner Dorn ------------------------------------------------------------

func on_archivist() -> void:
	var quests := game.quests
	if quests.is_completed("main_archive"):
		_say("Ориэн, архивариус", "Ветреные шпили ждут. Ветер там помнит голоса Хранителей.")
	elif bool(quests.states.get("main_archive", {}).get("started", false)):
		_say("Ориэн, архивариус", "Кристаллы памяти разбросаны по руинам. Найдено: %d из 3." % int(quests.states["main_archive"].get("progress", 0)))
	else:
		_say("Ориэн, архивариус", "Тише… Архив спит. Только печать Хранителя может его разбудить.")

func on_miner() -> void:
	const quest_id := "crystal_heart"
	const speaker := "Дорн, рудокоп"
	var quests := game.quests
	if quests.is_completed(quest_id):
		_say(speaker, "%s. Пещера снова поёт ровно — кристаллы больше не трескаются. Заходи, если найдёшь ещё руду." % game.relationships.get_reaction("dorn"))
	elif quests.is_ready_to_complete(quest_id):
		_ask(speaker, "Четыре эхо-кристалла! Слышишь, как звенят? Гильдия хорошо заплатит… или я огранщу один для тебя.", [
			{"id": "miner_reward:guild", "label": "Сдать кристаллы гильдии — 80 золота"},
			{"id": "miner_reward:lens", "label": "Огранить хрустальную линзу (+30 маны, молния сильнее)"}
		])
	elif bool(quests.states[quest_id].get("started", false)):
		_say(speaker, "Эхо-кристаллы светятся вдоль тоннелей. Нашёл %d из 4. Осторожнее с летучими мышами — молния их пугает." % int(quests.states[quest_id].get("progress", 0)))
	elif not quests.active_quest_id.is_empty():
		_say(speaker, "Вижу, у тебя свои заботы. Закончи их — тогда поговорим о кристаллах.")
	else:
		quests.start_quest(quest_id)
		_say(speaker, "Ну и ну, кто-то прошёл мимо хранителя! Я Дорн. Пещера гудит — её эхо-кристаллы перегружены. Собери четыре, пока они не взорвались, и принеси мне.")
	game._refresh_hud()

func _complete_miner_quest(choice_id: String) -> void:
	const quest_id := "crystal_heart"
	var reward: Dictionary = game.quests.get_choice_reward(quest_id, choice_id)
	if reward.is_empty() or not game.quests.complete_quest(quest_id):
		return
	game.quests.states[quest_id]["choice"] = choice_id
	var item_summary := _grant_reward(reward)
	var gain := int(reward.get("dorn_trust", 0))
	game.relationships.adjust("dorn", gain)
	_close()
	game.hud.show_message("Сердце пещеры успокоено! +%d золота, +%d опыта%s. Доверие Дорна +%d." % [int(reward.get("gold", 0)), int(reward.get("experience", 0)), item_summary, gain], 4.0)
	game._refresh_hud()

# --- Merchant Bran -------------------------------------------------------

func on_merchant() -> void:
	const quest_id := "bran_supply_run"
	var quests := game.quests
	var reputation: int = game.relationships.get_score("elder")
	var bran_trust: int = game.relationships.get_score("bran")
	var discount_percent: int = game.merchant_shop.get_discount_percent(reputation)
	var choices: Array[Dictionary] = []
	var message := "Добро пожаловать! Чем могу помочь?"
	# The road decides the market.
	var route_open: bool = game.world_state.has("trade_route")
	var plundered: bool = game.world_state.has("caravan_lost")
	game.merchant_shop.caravan_open = route_open
	game.merchant_shop.price_mult = 0.9 if route_open else (1.15 if plundered else 1.0)
	game.merchant_shop.sell_mult = {"iron_ore": game.mine.iron_price_mult()}
	if quests.is_completed(quest_id):
		message = "Благодаря тебе лавка снова получает товары. %s." % game.relationships.get_reaction("bran")
	elif quests.is_ready_to_complete(quest_id):
		message = "Ты {вернул|вернула} все три ящика! Теперь решим, как распределить припасы."
		choices.append({"id": "merchant_supply:fair", "label": "Продать припасы — 40 золота"})
		choices.append({"id": "merchant_supply:clinic", "label": "Передать часть лечебнице — 15 золота"})
	elif bool(quests.states[quest_id].get("started", false)):
		message = "Осталось найти ящики с припасами: %d из 3." % int(quests.states[quest_id].get("progress", 0))
	elif quests.is_completed("moonleaf_gathering") and quests.active_quest_id.is_empty():
		choices.append({"id": "merchant_quest_start", "label": "Помочь вернуть потерянные поставки"})
	if route_open:
		message += "\nКараван дошёл — заморские товары и скидка 10%% ещё %d дн.!" % game.world_state.days_left("trade_route")
	elif plundered:
		message += "\nКараван разграбили… Пока цены выше обычного."
	if discount_percent > 0:
		message += "\nЗа помощь поселению действует скидка %d%%." % discount_percent
	else:
		message += "\nПомоги поселению — и я предложу лучшие цены."
	for offer in game.merchant_shop.get_offers(reputation, bran_trust):
		var offer_label: String
		if offer.has("trade_currency"):
			offer_label = "Обменять %d × %s на %s" % [int(offer["trade_amount"]), _item_name(str(offer["trade_currency"])), str(offer["name"])]
		else:
			offer_label = "Купить %s — %d золота" % [str(offer.get("name", "Товар")), int(offer.get("price", 0))]
		choices.append({"id": "merchant_buy:" + str(offer.get("id", "")), "label": offer_label})
	if not game.merchant_shop.get_sell_offers(game.player, bran_trust).is_empty():
		choices.append({"id": "merchant_sell:menu", "label": "Продать вещи"})
	choices.append({"id": "merchant_close", "label": "Завершить торговлю"})
	_ask("Торговец Бран", message, choices)

func _show_sell_menu() -> void:
	var bran_trust: int = game.relationships.get_score("bran")
	var choices: Array[Dictionary] = []
	for offer in game.merchant_shop.get_sell_offers(game.player, bran_trust):
		choices.append({"id": "merchant_sell:" + str(offer["id"]), "label": "Продать %s (×%d) — %d золота" % [offer["name"], offer["count"], offer["price"]]})
	choices.append({"id": "merchant_sell:back", "label": "Назад к товарам"})
	var message := "Что продашь? Надетые вещи я не возьму." if choices.size() > 1 else "Продавать больше нечего."
	if bran_trust >= int(game.merchant_shop.sell_trust_bonus.get("trust", 999)):
		message += "\nДругу поселения плачу на 10% больше."
	_ask("Торговец Бран", message, choices)

func _sell_to_merchant(item_id: String) -> void:
	if item_id == "menu":
		_show_sell_menu()
		return
	if item_id == "back":
		on_merchant()
		return
	var result: Dictionary = game.merchant_shop.sell(game.player, item_id, game.relationships.get_score("bran"))
	if bool(result.get("success", false)):
		game.hud.show_message("Продано: %s за %d золота." % [str(result["name"]), int(result["price"])], 2.5)
	else:
		game.hud.show_message(str(result.get("message", "Продажа не удалась.")), 2.5)
	_show_sell_menu()
	game._refresh_hud()

func _start_merchant_supply_quest() -> void:
	const quest_id := "bran_supply_run"
	if not game.quests.is_completed("moonleaf_gathering") or not game.quests.active_quest_id.is_empty():
		_say("Торговец Бран", "Сначала помоги старейшине и закончи текущее поручение. Тогда поговорим о поставках.")
		return
	if game.quests.start_quest(quest_id):
		game.spawn_supply_crates()
		_say("Торговец Бран", "Три ящика с лечебными травами и инструментами пропали на дороге к поселению. Найди их в Зелёных Пределах. Без этих поставок лечебница скоро останется без лекарств.")
		game._refresh_hud()

func _complete_merchant_supply_quest(choice_id: String) -> void:
	const quest_id := "bran_supply_run"
	var reward: Dictionary = game.quests.get_choice_reward(quest_id, choice_id)
	if reward.is_empty() or not game.quests.is_ready_to_complete(quest_id) or not game.quests.complete_quest(quest_id):
		return
	game.quests.states[quest_id]["choice"] = choice_id
	_grant_reward(reward)
	var bran_gain: int = int(reward.get("bran_trust", 0))
	var elder_gain: int = int(reward.get("elder_trust", 0))
	game.relationships.adjust("bran", bran_gain)
	if elder_gain > 0:
		game.relationships.adjust("elder", elder_gain)
	_close()
	if choice_id == "clinic":
		game.hud.show_message("Припасы переданы лечебнице. Доверие Брана +%d, доверие поселения +%d." % [bran_gain, elder_gain], 4.0)
	else:
		game.hud.show_message("Бран выплатил награду за возвращённые поставки. Доверие +%d." % bran_gain, 3.5)
	game._refresh_hud()

func _purchase_merchant_item(item_id: String) -> void:
	var result: Dictionary = game.merchant_shop.purchase(game.player, item_id, game.relationships.get_score("elder"), game.relationships.get_score("bran"))
	if bool(result.get("success", false)):
		if result.has("trade_currency"):
			game.hud.show_message("Обмен завершён: получено %s." % str(result.get("name", item_id)), 2.5)
		else:
			game.hud.show_message("Куплено: %s за %d золота." % [str(result.get("name", item_id)), int(result.get("price", 0))], 2.5)
	else:
		game.hud.show_message(str(result.get("message", "Покупка не удалась.")), 2.5)
	on_merchant()
