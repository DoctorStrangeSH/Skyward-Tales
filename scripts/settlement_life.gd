extends Node
class_name SettlementLife

## Этап 24: the settlement lives on its own.
##   • Level of the settlement — Хутор → Деревня → Село → Посад → Городок:
##     grows with settlers housed, buildings and requests fulfilled. Every new
##     level is a village celebration with a gift, and fills the treasury more.
##   • Workplaces: a housed settler works — Yarosh's sawmill (wood), Ulf's pier
##     (fish), Martha's kitchen (stew); goods pile up day by day (up to 3 days)
##     and wait at the settlement board with the treasury's gold.
##   • Requests: every day each housed settler asks for something small; bring
##     it — gold, their thanks and the settlement grows.

const LEVELS := [
	[0, "Хутор", "Несколько дворов у тракта."],
	[4, "Деревня", "Казна поселения: 25 золота в день."],
	[9, "Село", "Казна: 40 золота в день; на складе копится на день больше."],
	[15, "Посад", "Казна: 60 золота в день; просьбы жителей платят вдвое."],
	[22, "Городок", "Казна: 90 золота в день. Вас называют основателем."],
]
const TREASURY := [0, 25, 40, 60, 90]
const WORK := {
	"woodcutter": {"name": "Лесопилка Яроша", "items": {"wood": 3}},
	"fisher": {"name": "Причал Ульфа", "items": {"fish": 2}},
	"cook": {"name": "Кухня Марты", "items": {"hearty_stew": 1}},
	"beekeeper": {"name": "Пасека Мирона", "items": {"sunberry": 2}},
	"stonecutter": {"name": "Каменоломня Вилмы", "items": {"stone": 3}},
}
const REQUESTS := {
	"woodcutter": [
		{"items": {"stone": 3}, "text": "Точило совсем стёрлось. Принесёшь три камня?"},
		{"items": {"iron_ore": 1}, "text": "Топор щербатый. Кусок железной руды — и Борин мне его перекуёт."},
		{"items": {"bread": 1}, "text": "С утра в лесу, а хлеба не взял. Выручишь краюхой?"},
	],
	"cook": [
		{"items": {"fish": 2}, "text": "Ухи хочу наварить на всю деревню. Две рыбы найдётся?"},
		{"items": {"healroot": 2}, "text": "Целебного корня бы два — в похлёбку, от простуды."},
		{"items": {"sunberry": 2}, "text": "Пирог задумала! Две солнечные ягоды — и будет праздник."},
	],
	"beekeeper": [
		{"items": {"wood": 2}, "text": "Новый улей сколотить надо. Пару брёвен найдёшь?"},
		{"items": {"bluebell": 2}, "text": "Синецвет — лучший медонос. Принесёшь пару кустиков?"},
		{"items": {"bread": 1}, "text": "Мёд есть, а хлеба к нему нет. Краюху бы!"},
	],
	"stonecutter": [
		{"items": {"iron_ore": 1}, "text": "Зубило затупилось. Кусок железной руды — и Борин сделает новое."},
		{"items": {"fish_stew": 1}, "text": "Целый день в каменоломне — живот к спине прилип. Ухи не найдётся?"},
		{"items": {"copper_ore": 1}, "text": "Медные клинья камень колют ровнее. Медной руды бы кусочек."},
	],
	"fisher": [
		{"items": {"wood": 2}, "text": "Лодка течёт. Две доски-бревна — и залатаю."},
		{"items": {"bluebell": 2}, "text": "Синецвет на наживку — рыба его любит. Принесёшь пару?"},
		{"items": {"copper_ore": 1}, "text": "Крючки из меди — самые уловистые. Кусочек меди найдёшь?"},
	],
}
const MAX_DAYS := 3

var game: SkywardGame
## {settler id: day the goods were last taken}.
var collected: Dictionary = {}
var treasury_day: int = -1
## {settler id: day their request was fulfilled}.
var helped: Dictionary = {}
var requests_done: int = 0
var celebrated_level: int = 1

func _settlement() -> Settlement:
	return game.settlement

func today() -> int:
	return game.day_night.day

# --- Level -----------------------------------------------------------------------

func points() -> int:
	var total := _settlement().homes.size() * 2 + requests_done / 2
	for plot_id in _settlement().homes:
		total += _settlement().home_level(str(_settlement().homes[plot_id])) - 1
	for id in _settlement().buildings:
		total += int(_settlement().buildings[id])
	return total

func level() -> int:
	var result := 1
	for i in LEVELS.size():
		if points() >= int(LEVELS[i][0]):
			result = i + 1
	return result

func level_name() -> String:
	return str(LEVELS[level() - 1][1])

func status_line() -> String:
	var lvl := level()
	var next := "" if lvl >= LEVELS.size() else " · до «%s»: %d/%d" % [str(LEVELS[lvl][1]), points(), int(LEVELS[lvl][0])]
	return "Поселение: %s (ур. %d)%s" % [level_name(), lvl, next]

## A new level: the village celebrates.
func check_growth() -> void:
	var lvl := level()
	if lvl <= celebrated_level:
		return
	celebrated_level = lvl
	var gift := 100 * lvl
	game.player.add_gold(gift)
	game.player.add_item("berry_pie", 1)
	game.hud.show_title_card("Поселение выросло: %s!" % level_name(), 3.0)
	game.hud.show_message("Жители празднуют: на площади пироги и музыка, вам — %d золота. %s" % [gift, str(LEVELS[lvl - 1][2])], 6.0)
	GameAudio.play("level_up", -4.0, 0.0)
	game.achievements.set_max("settlement_level", lvl)
	game.request_autosave()

# --- Workplaces and the treasury -----------------------------------------------------

func working() -> Array:
	var result: Array = []
	for id in WORK:
		if not _settlement().home_of(str(id)).is_empty():
			result.append(str(id))
	return result

func max_days() -> int:
	return MAX_DAYS + (1 if level() >= 3 else 0)

func _days(since: int) -> int:
	return clampi(today() - since, 0, max_days())

## Days of work waiting at the store for a settler.
func waiting_days(id: String) -> int:
	if not collected.has(id):
		collected[id] = today() - 1
	return _days(int(collected[id]))

func treasury_waiting() -> int:
	if TREASURY[level() - 1] <= 0:
		return 0
	if treasury_day < 0:
		treasury_day = today() - 1
	return _days(treasury_day) * int(TREASURY[level() - 1])

## {item: amount} on the store plus "gold".
func store() -> Dictionary:
	var result: Dictionary = {}
	for id in working():
		var days := waiting_days(id)
		if days <= 0:
			continue
		var items: Dictionary = WORK[id]["items"]
		for item in items:
			result[item] = int(result.get(item, 0)) + int(items[item]) * days * maxi(1, _settlement().home_level(id))
	var gold := treasury_waiting()
	if gold > 0:
		result["gold"] = gold
	return result

func store_text() -> String:
	var parts: Array[String] = []
	var goods := store()
	for item in goods:
		parts.append(("%d золота" % int(goods[item])) if item == "gold" else "%s ×%d" % [game.player.get_item_name(str(item)), int(goods[item])])
	return ", ".join(parts)

func collect() -> bool:
	var goods := store()
	if goods.is_empty():
		return false
	for item in goods:
		if item == "gold":
			game.player.add_gold(int(goods[item]))
		else:
			game.player.add_item(str(item), int(goods[item]))
	for id in working():
		collected[id] = today()
	treasury_day = today()
	game.hud.show_message("Со склада поселения: %s." % ", ".join(goods.keys().map(func(item: String) -> String: return ("%d золота" % int(goods[item])) if item == "gold" else "%s ×%d" % [game.player.get_item_name(item), int(goods[item])])), 4.0)
	GameAudio.play("chest", -4.0, 0.0)
	game.request_autosave()
	return true

# --- Requests ----------------------------------------------------------------------

func request_of(id: String) -> Dictionary:
	if not REQUESTS.has(id) or _settlement().home_of(id).is_empty() or int(helped.get(id, -99)) == today():
		return {}
	var list: Array = REQUESTS[id]
	return list[posmod(today() + id.length(), list.size())]

func can_fulfil(id: String) -> bool:
	var request := request_of(id)
	if request.is_empty():
		return false
	var items: Dictionary = request["items"]
	for item in items:
		if int(game.player.inventory.get(item, 0)) < int(items[item]):
			return false
	return true

func reward() -> int:
	return 40 * (2 if level() >= 4 else 1)

func fulfil(id: String) -> bool:
	if not can_fulfil(id):
		return false
	var items: Dictionary = request_of(id)["items"]
	for item in items:
		game.player.remove_item(str(item), int(items[item]))
	helped[id] = today()
	requests_done += 1
	game.player.add_gold(reward())
	game.player.add_experience(40 + 8 * game.player.level)
	game.achievements.add("settler_requests")
	check_growth()
	game.update_npc_markers()
	game.request_autosave()
	return true

## A settler's talk: today's request first. True when it took the talk.
func talk(id: String) -> bool:
	var request := request_of(id)
	if request.is_empty():
		return false
	var name := str(_settlement().settler(id).get("name", id)).get_slice(",", 0)
	var items: Dictionary = request["items"]
	var need: Array[String] = []
	for item in items:
		need.append("%s %d/%d" % [game.player.get_item_name(str(item)), int(game.player.inventory.get(item, 0)), int(items[item])])
	var choices: Array[Dictionary] = []
	if can_fulfil(id):
		choices.append({"id": "life_give:" + id, "label": "Отдать: %s (+%d золота)" % [", ".join(need), reward()]})
	choices.append({"id": "life_later", "label": "Позже" if can_fulfil(id) else "Поищу (%s)" % ", ".join(need)})
	game._show_dialogue_choices(name, StoryText.format(str(request["text"])), choices)
	return true

func marker(npc_id: String) -> String:
	var id := npc_id.trim_prefix("settler_")
	return "ready" if can_fulfil(id) else ""

func handle_choice(choice_id: String) -> bool:
	if choice_id == "life_later":
		game.dialogues._close()
		return true
	if choice_id == "life_collect":
		game.dialogues._close()
		collect()
		return true
	if choice_id.begins_with("life_give:"):
		game.dialogues._close()
		var id := choice_id.trim_prefix("life_give:")
		if fulfil(id):
			var name := str(_settlement().settler(id).get("name", id)).get_slice(",", 0)
			game._show_dialogue(name, "Вот спасибо! Держи %d золота — и заходи ещё." % reward())
		return true
	return false

## Lines and a choice for the settlement board.
func board_lines() -> String:
	var lines := status_line()
	var asks: Array[String] = []
	for id in REQUESTS:
		if not request_of(str(id)).is_empty():
			asks.append(str(_settlement().settler(str(id)).get("name", id)).get_slice(",", 0))
	if not asks.is_empty():
		lines += "\nПросят о помощи: " + ", ".join(asks)
	var goods := store_text()
	if not goods.is_empty():
		lines += "\nНа складе: " + goods
	return lines

func board_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if not store().is_empty():
		choices.append({"id": "life_collect", "label": "Забрать со склада: " + store_text()})
	return choices

func make_snapshot() -> Dictionary:
	return {"collected": collected.duplicate(), "treasury_day": treasury_day, "helped": helped.duplicate(), "requests_done": requests_done, "celebrated_level": celebrated_level}

func restore_snapshot(value: Variant) -> void:
	var saved: Dictionary = value if value is Dictionary else {}
	collected = (saved.get("collected", {}) as Dictionary).duplicate() if saved.get("collected", {}) is Dictionary else {}
	treasury_day = int(saved.get("treasury_day", -1))
	helped = (saved.get("helped", {}) as Dictionary).duplicate() if saved.get("helped", {}) is Dictionary else {}
	requests_done = int(saved.get("requests_done", 0))
	celebrated_level = int(saved.get("celebrated_level", 1))
