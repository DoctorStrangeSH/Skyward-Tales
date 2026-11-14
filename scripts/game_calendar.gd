extends Node
class_name GameCalendar

## Этап 24: the calendar of the Sky Isles. Like Stardew Valley: a year is
## four seasons of 28 days (scripts/seasons.gd), weeks of seven days, starting
## with summer; most days are ordinary, a few are marked. On it:
##   • birthdays of the villagers — talk to them that day, wish them well,
##     give a present (each loves something; the favourite pleases most);
##   • festivals — two a season: Новолетье and Ночь светлячков (summer),
##     Праздник урожая and Ночь теней (autumn), Ночь Звездопада and Зимний пир
##     (winter), Праздник Первого Ветра and Канун года (spring; the last day:
##     the elder sums up the year); each host has a gift once a year;
##   • the village fair every Saturday (scripts/village_fair.gd).
## The calendar tab (N) shows the year as a grid, today, and what comes next.

const DAYS_PER_YEAR := Seasons.LENGTH * 4
const SEASON_ORDER := Seasons.ORDER

## Birthdays: npc → day of the year (0..111: season × 28 + date − 1),
## the present they love.
const BIRTHDAYS := {
	"elder": {"day": 4, "loves": "berry_pie"},
	"haven_child": {"day": 11, "loves": "candy_cock"},
	"cartographer": {"day": 18, "loves": "fair_wreath"},
	"blacksmith": {"day": 30, "loves": "star_fragment"},
	"farmer_gavrila": {"day": 36, "loves": "bread"},
	"merchant": {"day": 48, "loves": "fish_stew"},
	"hunter": {"day": 57, "loves": "hearty_stew"},
	"alchemist": {"day": 69, "loves": "sunberry"},
	"herbalist": {"day": 75, "loves": "carrot_pie"},
	"haven_bard": {"day": 87, "loves": "fair_wreath"},
	"haven_baker": {"day": 92, "loves": "sunberry"},
	"haven_warden": {"day": 101, "loves": "berry_pie"},
	"captain_raina": {"day": 107, "loves": "captain_ration"},
}
## Anything of these is a fine present too.
## Villager ids in npc_relationships.json, where they differ.
const RELATIONSHIP_IDS := {"cartographer": "mira", "merchant": "bran", "hunter": "toren"}
## Whose words take feminine endings.
const FEMININE := ["haven_child", "cartographer", "alchemist", "herbalist", "haven_warden", "captain_raina"]
const GIFTS := ["berry_pie", "carrot_pie", "candy_cock", "fair_wreath", "sunberry", "bread", "fish_stew", "hearty_stew"]

const FESTIVALS := {
	"new_year": {"day": 0, "name": "Новолетье", "host": "elder",
		"text": "Первый день года. Старейшина раздаёт подарки — загляните к нему.",
		"talk": "Элиан поднял кружку тёплого сидра. «С Новолетьем, {hero}! Пусть ветер этого года дует тебе в спину». Он вложил тебе в ладонь узелок.",
		"gift": {"gold": 120, "items": {"starlight_essence": 1, "berry_pie": 1}}},
	"fireflies": {"day": 23, "name": "Ночь светлячков", "short": "Светлячки", "host": "herbalist",
		"text": "Тёплая летняя ночь: над топью и полями поднимаются тысячи светлячков. Ведана собирает травы, что цветут только этой ночью.",
		"talk": "Ведана протянула тебе связку трав, светящихся в сумерках. «Ночь светлячков, {hero}! Эти травы раскрываются раз в году — держи, пригодятся»",
		"gift": {"gold": 0, "items": {"healroot": 3, "sunberry": 3, "mana_potion": 1}}},
	"harvest": {"day": 43, "name": "Праздник урожая", "short": "Урожай", "host": "farmer_gavrila",
		"text": "Ясный Край собирает урожай. Гаврила угощает всех, кто помогал.",
		"talk": "Гаврила, красный от солнца и от счастья, сунул тебе корзину. «Урожай, {hero}! Бери, бери — в этом году на всех хватит»",
		"gift": {"gold": 40, "items": {"bread": 3, "sunberry": 4, "carrot_pie": 1}}},
	"shadows": {"day": 54, "name": "Ночь теней", "short": "Ночь теней", "host": "alchemist",
		"text": "Осенняя ночь, когда тени длиннее обычного. Лира варит особые зелья и раздаёт смельчакам.",
		"talk": "Лира, в остроконечной шляпе из тыквы, подмигнула. «Ночь теней! Держи — в эту ночь зелья крепче. И не оглядывайся на свою тень»",
		"gift": {"gold": 30, "items": {"power_elixir": 1, "mana_potion": 2}}},
	"starfall": {"day": 63, "name": "Ночь Звездопада", "short": "Звездопад", "host": "cartographer",
		"text": "Ночью над островами падают звёзды. Мира знает, где искать упавшие осколки.",
		"talk": "Мира показала тебе на небо, полное падающих огней. «Ночь Звездопада! Я весь день искала, куда они падают, — смотри». На её ладони мерцали осколки звезды.",
		"gift": {"gold": 0, "items": {"star_fragment": 2, "starlight_essence": 1}}},
	"winter_feast": {"day": 80, "name": "Зимний пир", "short": "Зимний пир", "host": "merchant",
		"text": "Самая длинная ночь зимы. Бран накрывает стол на площади — для всех, кто заглянет.",
		"talk": "Бран, раскрасневшийся у жаровни, сунул тебе миску. «Зимний пир, {hero}! Сегодня торговли нет — сегодня угощаю»",
		"gift": {"gold": 60, "items": {"fish_stew": 2, "hearty_stew": 1}}},
	"first_wind": {"day": 96, "name": "Праздник Первого Ветра", "short": "Первый Ветер", "host": "haven_baker",
		"text": "Весна в Гавани: первый тёплый ветер и сорок пирогов Тимофея.",
		"talk": "Тимофей, весь в муке, торжественно вручил тебе пирог. «С Первым Ветром! Сороковой — твой. Тридцать девять уже съели»",
		"gift": {"gold": 0, "items": {"berry_pie": 2, "carrot_pie": 1}}},
	"year_end": {"day": 111, "name": "Канун года", "host": "elder",
		"text": "Последний день года. Старейшина подводит итоги — что вы успели за год.",
		"talk": "",
		"gift": {"gold": 200, "items": {"health_potion": 3, "mana_potion": 2}}},
}

var game: SkywardGame
## {npc id: year} — birthdays already celebrated.
var greeted: Dictionary = {}
## {festival id: year} — festival gifts already taken.
var celebrated: Dictionary = {}
## What the year started with, for the year's summary.
var year_start: Dictionary = {}
var _last_day: int = -1

# --- Dates ---------------------------------------------------------------------

static func year_of(day: int) -> int:
	return maxi(day, 0) / DAYS_PER_YEAR + 1

static func day_of_year(day: int) -> int:
	return maxi(day, 0) % DAYS_PER_YEAR

static func season_of_year_day(doy: int) -> String:
	return str(SEASON_ORDER[doy / Seasons.LENGTH])

static func date_text(day: int) -> String:
	var doy := day_of_year(day)
	var season := season_of_year_day(doy)
	return "%s, %d-й день · %s · год %d" % [str(Seasons.NAMES[season]), doy % Seasons.LENGTH + 1, str(Seasons.WEEKDAYS[Seasons.weekday_of(day)]), year_of(day)]

## "5 Осени" — a day of the year, short.
static func short_date(doy: int) -> String:
	return "%d-й день, %s" % [doy % Seasons.LENGTH + 1, str(Seasons.NAMES[season_of_year_day(doy)]).to_lower()]

func today() -> int:
	return game.day_night.day

## Everything on a day of the year: [{"kind", "id", "title", "text"}].
func events_on(doy: int) -> Array:
	var result: Array = []
	for id in FESTIVALS:
		var info: Dictionary = FESTIVALS[id]
		if int(info["day"]) == doy:
			result.append({"kind": "festival", "id": str(id), "title": str(info["name"]), "short": str(info.get("short", info["name"])), "text": str(info["text"])})
	if game.tavern_party != null and game.tavern_party.tavern_built() and TavernParty.is_party_day(doy):
		result.append({"kind": "party", "id": "party", "title": "Вечер в таверне", "short": "Таверна", "text": "Пятничный вечер у Греты: кости с Яром, песни барда, угощение на всех."})
	if VillageFair.is_fair_day(doy):
		result.append({"kind": "fair", "id": "fair", "title": "Ярмарка", "short": "Ярмарка", "text": "Субботняя ярмарка в Ясном Краю: тир, лавка призов, вечером — фейерверк."})
	for npc in BIRTHDAYS:
		var info: Dictionary = BIRTHDAYS[npc]
		if int(info["day"]) == doy:
			result.append({"kind": "birthday", "id": str(npc), "title": "День рождения: %s" % short_name(str(npc)), "short": short_name(str(npc)),
				"text": "%s празднует. Любит: %s." % [RegionCatalog.npc_name(str(npc)), _lower_first(game.player.get_item_name(str(info["loves"])))]})
	return result

static func _lower_first(text: String) -> String:
	return text.left(1).to_lower() + text.substr(1)

static func short_name(npc_id: String) -> String:
	var full := RegionCatalog.npc_name(npc_id)
	var cut := full.get_slice(",", 0)
	for title in ["Старейшина ", "Торговец ", "Кузнец ", "Фермер ", "Пекарь ", "Бард ", "Рыбак "]:
		cut = cut.trim_prefix(title)
	return cut.get_slice(" ", 0)

## The next events from today: [{"in": days, "day": absolute day, …event}].
func upcoming(count: int = 6) -> Array:
	var result: Array = []
	var day := today()
	var listed_weekly: Dictionary = {}
	for offset in range(0, DAYS_PER_YEAR + 1):
		for event in events_on(day_of_year(day + offset)):
			# The fair is weekly: only the next one is worth listing.
			if str(event["kind"]) in ["fair", "party"]:
				if listed_weekly.has(str(event["kind"])):
					continue
				listed_weekly[str(event["kind"])] = true
			var entry: Dictionary = (event as Dictionary).duplicate()
			entry["in"] = offset
			entry["day"] = day + offset
			result.append(entry)
			if result.size() >= count:
				return result
	return result

static func in_text(days: int) -> String:
	if days == 0:
		return "сегодня"
	if days == 1:
		return "завтра"
	var tail := "дней"
	if days % 10 == 1 and days % 100 != 11:
		tail = "день"
	elif days % 10 in [2, 3, 4] and not (days % 100 in [12, 13, 14]):
		tail = "дня"
	return "через %d %s" % [days, tail]

# --- The day -----------------------------------------------------------------------

func _process(_delta: float) -> void:
	if game == null or game.day_night == null or game.player == null:
		return
	var day := today()
	if day == _last_day:
		return
	var first := _last_day < 0
	_last_day = day
	if year_start.is_empty() or day_of_year(day) == 0 and int(year_start.get("year", 0)) != year_of(day):
		_start_year()
	if first:
		return
	var titles: Array[String] = []
	for event in events_on(day_of_year(day)):
		titles.append(str(event["title"]))
	game.hud.show_message("%s.%s" % [date_text(day), (" Сегодня: " + ", ".join(titles) + " (N — календарь).") if not titles.is_empty() else ""], 5.0)

func _start_year() -> void:
	year_start = {"year": year_of(today()), "kills": int(game.achievements.stats.get("kills", 0)), "quests": _quests_done(), "level": game.player.level, "gold": int(game.achievements.stats.get("gold_earned", 0))}

func _quests_done() -> int:
	var done := 0
	for id in game.quests.states:
		if bool(game.quests.states[id].get("completed", false)):
			done += 1
	return done

# --- Talks: birthdays and festival hosts ----------------------------------------------

## Celebrations begin once the hero has settled in (after the prologue).
func open() -> bool:
	return game.quests.is_completed("main_prologue")

func birthday_today(npc_id: String) -> bool:
	return open() and BIRTHDAYS.has(npc_id) and int(BIRTHDAYS[npc_id]["day"]) == day_of_year(today()) and int(greeted.get(npc_id, 0)) != year_of(today())

func festival_today(npc_id: String) -> String:
	if not open():
		return ""
	for id in FESTIVALS:
		var info: Dictionary = FESTIVALS[id]
		if str(info["host"]) == npc_id and int(info["day"]) == day_of_year(today()) and int(celebrated.get(id, 0)) != year_of(today()):
			return str(id)
	return ""

## A marker over a villager: their birthday or a festival gift waits.
func marker(npc_id: String) -> String:
	return "service" if birthday_today(npc_id) or not festival_today(npc_id).is_empty() else ""

## Takes the conversation on a birthday or a festival; true when it did.
func talk(npc_id: String) -> bool:
	# Quest business first: a villager with a task speaks of it.
	if game.dialogues != null and not (game.dialogues._base_marker(npc_id) in ["", "service"]):
		return false
	var festival := festival_today(npc_id)
	if not festival.is_empty():
		_celebrate(festival)
		return true
	if birthday_today(npc_id):
		_birthday(npc_id)
		return true
	return false

func _birthday(npc_id: String) -> void:
	var name := RegionCatalog.npc_name(npc_id).get_slice(",", 0)
	var loves := str(BIRTHDAYS[npc_id]["loves"])
	var hero := game.player
	var choices: Array[Dictionary] = []
	if int(hero.inventory.get(loves, 0)) > 0:
		choices.append({"id": "bday:%s:%s" % [npc_id, loves], "label": "Подарить: %s ★" % hero.get_item_name(loves)})
	for gift in GIFTS:
		if gift != loves and int(hero.inventory.get(gift, 0)) > 0:
			choices.append({"id": "bday:%s:%s" % [npc_id, gift], "label": "Подарить: %s" % hero.get_item_name(gift)})
			break
	choices.append({"id": "bday:%s:" % npc_id, "label": "Просто поздравить"})
	game._show_dialogue_choices(name, StoryText.format("«Ой, {hero}! А ты знаешь, какой сегодня день?» — %s улыбается во весь рот. — «Мой день рождения! Ещё никто не поздравил…»" % name), choices)

func _celebrate(festival: String) -> void:
	var info: Dictionary = FESTIVALS[festival]
	celebrated[festival] = year_of(today())
	var gift: Dictionary = info["gift"]
	var hero := game.player
	hero.add_gold(int(gift.get("gold", 0)))
	var items: Dictionary = gift.get("items", {})
	var got: Array[String] = []
	for item in items:
		hero.add_item(str(item), int(items[item]))
		got.append("%s ×%d" % [hero.get_item_name(str(item)), int(items[item])])
	var text := str(info["talk"])
	if festival == "year_end":
		text = year_summary()
	game.hud.show_title_card(str(info["name"]), 2.4)
	game._show_dialogue(RegionCatalog.npc_name(str(info["host"])).get_slice(",", 0), StoryText.format(text) + "\n\nПолучено: %s%s." % [("%d золота, " % int(gift.get("gold", 0))) if int(gift.get("gold", 0)) > 0 else "", ", ".join(got)])
	GameAudio.play("quest", -4.0, 0.0)
	game.achievements.add("festivals")
	game.update_npc_markers()
	game.request_autosave()

## The elder's words on the year's eve.
func year_summary() -> String:
	var kills := int(game.achievements.stats.get("kills", 0)) - int(year_start.get("kills", 0))
	var quests := _quests_done() - int(year_start.get("quests", 0))
	var levels := game.player.level - int(year_start.get("level", game.player.level))
	var greet := 0
	for npc in greeted:
		if int(greeted[npc]) == year_of(today()):
			greet += 1
	return "Элиан долго смотрел на закат. «Вот и год прошёл, {hero}. Давай вспомним. Дел ты переделал%s — %d. Тварей одолел%s — %d. Вырос%s на %d %s. Поздравил%s с днём рождения %d %s. Неплохой год. Пусть следующий будет не хуже»." % [
		"" if StoryText.hero_gender != "f" else "а", maxi(quests, 0),
		"" if StoryText.hero_gender != "f" else "а", maxi(kills, 0),
		"" if StoryText.hero_gender != "f" else "ла", maxi(levels, 0), _plural(maxi(levels, 0), "уровень", "уровня", "уровней"),
		"" if StoryText.hero_gender != "f" else "а", greet, _plural(greet, "друга", "друзей", "друзей")]

static func _plural(n: int, one: String, few: String, many: String) -> String:
	if n % 10 == 1 and n % 100 != 11:
		return one
	if n % 10 in [2, 3, 4] and not (n % 100 in [12, 13, 14]):
		return few
	return many

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("bday:"):
		return false
	game.dialogues._close()
	var parts := choice_id.split(":")
	var npc_id := parts[1]
	var gift := parts[2] if parts.size() > 2 else ""
	if not birthday_today(npc_id):
		return true
	greeted[npc_id] = year_of(today())
	var hero := game.player
	var name := RegionCatalog.npc_name(npc_id).get_slice(",", 0)
	var loves := str(BIRTHDAYS[npc_id]["loves"])
	var text := ""
	var warmth := 3
	if not gift.is_empty() and hero.remove_item(gift, 1):
		if gift == loves:
			warmth = 15
			hero.add_gold(80)
			hero.add_item("health_potion", 2)
			text = "%s ахнул%s: «Это же моё любимое! Откуда ты знал%s?!» В ответ — крепкие объятия, кошель с 80 золотыми и два зелья «на всякий случай»." % [name, "а" if npc_id in FEMININE else "", "а" if StoryText.hero_gender == "f" else ""]
			game.achievements.add("favourite_gifts")
		else:
			warmth = 8
			hero.add_gold(30)
			text = "%s благодарит от души и суёт тебе 30 золотых: «Ну что ты, не стоило!»" % name
	else:
		text = "%s светится: «Спасибо, что вспомнил%s! Это лучше любого подарка»." % [name, "а" if StoryText.hero_gender == "f" else ""]
	var bond := str(RELATIONSHIP_IDS.get(npc_id, npc_id))
	if game.relationships.has_npc(bond):
		game.relationships.adjust(bond, warmth)
	game.achievements.add("birthdays")
	game._show_dialogue(name, StoryText.format(text))
	GameAudio.play("quest", -6.0, 0.1)
	game.update_npc_markers()
	game.request_autosave()
	return true

func make_snapshot() -> Dictionary:
	return {"greeted": greeted.duplicate(), "celebrated": celebrated.duplicate(), "year_start": year_start.duplicate()}

func restore_snapshot(value: Variant) -> void:
	var saved: Dictionary = value if value is Dictionary else {}
	greeted = (saved.get("greeted", {}) as Dictionary).duplicate() if saved.get("greeted", {}) is Dictionary else {}
	celebrated = (saved.get("celebrated", {}) as Dictionary).duplicate() if saved.get("celebrated", {}) is Dictionary else {}
	year_start = (saved.get("year_start", {}) as Dictionary).duplicate() if saved.get("year_start", {}) is Dictionary else {}
	_last_day = -1
