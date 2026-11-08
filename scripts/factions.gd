extends RefCounted
class_name Factions

## Этап 17: three factions with their own view of the sky (data/factions.json).
##   Хранители Неба (envoy Liara, Sky Island) — keep the islands up;
##   Союз Свободных Капитанов (Raina, Salt Coast) — the sky belongs to all;
##   Круг Земных Корней (Corina, Enchanted Grove) — let the land come home.
## Reputation −100..100 with ranks. Envoys hand out errands (bring items);
## helping one faction cools its rivals. Friends open a shop, allies get a
## gift once; a soured faction can be won back with an apology in gold.
## The fates of the islands (IslandFates) move reputation the most.

const PATH := "res://data/factions.json"
const FRIENDS := 25
const ALLIES := 60

var game: SkywardGame
var data: Dictionary = {}
var ranks: Array = []
var rep: Dictionary = {}
## Errands done per faction (the next errand rotates through the list).
var errands: Dictionary = {}
var gifts: Dictionary = {}

func _init(owner_game: SkywardGame) -> void:
	game = owner_game
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = (parsed as Dictionary).get("factions", {})
			ranks = (parsed as Dictionary).get("ranks", [])
	for faction_id in data:
		rep[faction_id] = 0

func ids() -> Array:
	return data.keys()

func name_of(faction_id: String) -> String:
	return str(data.get(faction_id, {}).get("name", faction_id))

func value(faction_id: String) -> int:
	return int(rep.get(faction_id, 0))

func rank(faction_id: String) -> String:
	var result := ""
	for entry in ranks:
		if value(faction_id) >= int(entry[0]):
			result = str(entry[1])
	return result

func faction_for_npc(npc_id: String) -> String:
	for faction_id in data:
		if str(data[faction_id].get("npc", "")) == npc_id:
			return str(faction_id)
	return ""

## Changes standing; rivals react when `with_rivals` (errands, choices).
func add_rep(faction_id: String, amount: int, with_rivals: bool = false) -> void:
	if not data.has(faction_id) or amount == 0:
		return
	var before := rank(faction_id)
	rep[faction_id] = clampi(value(faction_id) + amount, -100, 100)
	var after := rank(faction_id)
	game.hud.show_message("%s: %+d · %s" % [name_of(faction_id), amount, after], 3.0)
	if after != before and amount > 0 and value(faction_id) >= FRIENDS:
		game.hud.show_title_card("%s — %s" % [name_of(faction_id), after.to_lower()], 2.5)
	if value(faction_id) >= ALLIES:
		game.achievements.set_max("faction_allies", allies_count())
	if with_rivals:
		var rival: Dictionary = data[faction_id].get("rival", {})
		for other in rival:
			rep[other] = clampi(value(str(other)) + int(rival[other]), -100, 100)

func allies_count() -> int:
	var count := 0
	for faction_id in data:
		if value(str(faction_id)) >= ALLIES:
			count += 1
	return count

func current_errand(faction_id: String) -> Dictionary:
	var tasks: Array = data[faction_id].get("tasks", [])
	if tasks.is_empty():
		return {}
	return tasks[int(errands.get(faction_id, 0)) % tasks.size()]

func _items_text(items: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id in items:
		parts.append("%s ×%d (есть %d)" % [game.player.get_item_name(str(item_id)), int(items[item_id]), int(game.player.inventory.get(str(item_id), 0))])
	return ", ".join(parts)

func can_finish(faction_id: String) -> bool:
	var errand := current_errand(faction_id)
	var items: Dictionary = errand.get("items", {})
	for item_id in items:
		if int(game.player.inventory.get(str(item_id), 0)) < int(items[item_id]):
			return false
	return not errand.is_empty()

func finish_errand(faction_id: String) -> bool:
	if not can_finish(faction_id):
		return false
	var errand := current_errand(faction_id)
	var items: Dictionary = errand.get("items", {})
	for item_id in items:
		game.player.remove_item(str(item_id), int(items[item_id]))
	game.player.add_gold(int(errand.get("gold", 0)))
	errands[faction_id] = int(errands.get(faction_id, 0)) + 1
	add_rep(faction_id, int(errand.get("rep", 0)), true)
	game.achievements.add("faction_errands")
	game._refresh_hud()
	game.request_autosave()
	return true

func apology_cost(faction_id: String) -> int:
	return 150 + 6 * absi(value(faction_id))

func marker(npc_id: String) -> String:
	var faction_id := faction_for_npc(npc_id)
	if faction_id.is_empty():
		return ""
	if can_finish(faction_id) or (value(faction_id) >= ALLIES and not gifts.has(faction_id)):
		return "ready"
	return ""

## The envoy's conversation; true when this NPC is an envoy.
func talk(npc_id: String) -> bool:
	var faction_id := faction_for_npc(npc_id)
	if faction_id.is_empty():
		return false
	var info: Dictionary = data[faction_id]
	var errand := current_errand(faction_id)
	var choices: Array[Dictionary] = []
	if game.party != null and game.party.can_recruit(npc_id):
		choices.append({"id": "party_join:" + npc_id, "label": "Полетишь с нами, Рейна?"})
	if not errand.is_empty():
		var reward := "+%d реп., %d золота" % [int(errand.get("rep", 0)), int(errand.get("gold", 0))]
		var label := "Поручение: %s — %s (%s)" % [str(errand.get("text", "")), _items_text(errand.get("items", {})), reward]
		choices.append({"id": "fac_errand:" + faction_id, "label": ("✓ " if can_finish(faction_id) else "") + label})
	if value(faction_id) >= FRIENDS:
		choices.append({"id": "fac_shop:" + faction_id, "label": "Лавка фракции"})
	else:
		choices.append({"id": "fac_later", "label": "Лавка — с ранга «Друзья» (%d/%d)" % [value(faction_id), FRIENDS]})
	if value(faction_id) >= ALLIES and not gifts.has(faction_id):
		choices.append({"id": "fac_gift:" + faction_id, "label": "★ Принять дар союзникам"})
	if value(faction_id) < 0:
		choices.append({"id": "fac_apology:" + faction_id, "label": "Загладить вину — %d золота" % apology_cost(faction_id)})
	choices.append({"id": "fac_later", "label": "Уйти"})
	var line := "%s\n%s: %s (%d)." % [StoryText.format(str(info.get("pitch", ""))), name_of(faction_id), rank(faction_id), value(faction_id)]
	if value(faction_id) < -30:
		line = "Нам не о чем говорить, пока ты на стороне тех, кто против нас.\n%s: %s (%d)." % [name_of(faction_id), rank(faction_id), value(faction_id)]
	game._show_dialogue_choices(str(info.get("speaker", "")), line, choices)
	return true

func open_shop(faction_id: String) -> void:
	var stock: Dictionary = data[faction_id].get("shop", {})
	var choices: Array[Dictionary] = []
	for item_id in stock:
		choices.append({"id": "fac_buy:%s:%s" % [faction_id, item_id], "label": "%s — %d золота" % [game.player.get_item_name(str(item_id)), int(stock[item_id])]})
	choices.append({"id": "fac_later", "label": "Хватит"})
	game._show_dialogue_choices(str(data[faction_id].get("speaker", "")), "Для своих — лучшее, что у нас есть.", choices)

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("fac_"):
		return false
	var parts := choice_id.split(":")
	var faction_id := parts[1] if parts.size() > 1 else ""
	var speaker := str(data.get(faction_id, {}).get("speaker", ""))
	match parts[0]:
		"fac_later":
			_close()
		"fac_errand":
			if finish_errand(faction_id):
				game._show_dialogue(speaker, "Спасибо, {hero}. Такое не забывается.")
			else:
				game._show_dialogue(speaker, "Пока не хватает: %s." % _items_text(current_errand(faction_id).get("items", {})))
		"fac_shop":
			open_shop(faction_id)
		"fac_buy":
			var item_id := parts[2] if parts.size() > 2 else ""
			var price := int(data[faction_id].get("shop", {}).get(item_id, 0))
			if price <= 0 or value(faction_id) < FRIENDS:
				_close()
			elif game.player.gold < price:
				game._show_dialogue(speaker, "Не хватает золота: нужно %d." % price)
			else:
				game.player.add_gold(-price)
				game.player.add_item(item_id, 1)
				game._refresh_hud()
				game._show_dialogue(speaker, "%s — твоё. Носи с честью." % game.player.get_item_name(item_id))
		"fac_gift":
			if value(faction_id) >= ALLIES and not gifts.has(faction_id):
				gifts[faction_id] = true
				var gift := str(data[faction_id].get("gift", ""))
				game.player.add_item(gift, 1)
				game.hud.show_title_card("Дар: %s" % game.player.get_item_name(gift), 2.5)
				game._show_dialogue(speaker, StoryText.format(str(data[faction_id].get("gift_line", ""))))
				game.request_autosave()
			else:
				_close()
		"fac_apology":
			var cost := apology_cost(faction_id)
			if value(faction_id) >= 0:
				_close()
			elif game.player.gold < cost:
				game._show_dialogue(speaker, "Слова — это мало. Приходи, когда сможешь подкрепить их делом (%d золота)." % cost)
			else:
				game.player.add_gold(-cost)
				rep[faction_id] = mini(5, value(faction_id) + 40)
				game._refresh_hud()
				game._show_dialogue(speaker, "Ладно. Начнём сначала — но второй раз я так не скажу.")
		_:
			return false
	return true

func _close() -> void:
	game.hud.close_dialogue()
	game.player.set_physics_process(true)
	game._refresh_hud()

## One line per faction for the journal / status.
func summary() -> Array[String]:
	var lines: Array[String] = []
	for faction_id in data:
		lines.append("%s — %s (%d)" % [name_of(str(faction_id)), rank(str(faction_id)), value(str(faction_id))])
	return lines

func make_snapshot() -> Dictionary:
	return {"rep": rep.duplicate(), "errands": errands.duplicate(), "gifts": gifts.duplicate()}

func restore_snapshot(value_data: Variant) -> void:
	if not value_data is Dictionary:
		return
	var snap: Dictionary = value_data
	for faction_id in data:
		rep[faction_id] = int(snap.get("rep", {}).get(faction_id, 0))
	errands = (snap.get("errands", {}) as Dictionary).duplicate() if snap.get("errands", {}) is Dictionary else {}
	gifts = (snap.get("gifts", {}) as Dictionary).duplicate() if snap.get("gifts", {}) is Dictionary else {}
