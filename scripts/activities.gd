extends RefCounted
class_name Activities

## Owner's list №33: everything there is to do in the world on one page —
## what it is, where it waits, whether it is open yet and how far the hero
## got. Built fresh from the game systems every time the tab opens.
## Each row: {id, title, group, open, progress, where, how}.

static func entries(game: SkywardGame) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var stat := func(id: String) -> int: return int(game.achievements.stats.get(id, 0))
	var q := game.quests
	# Story.
	var chapter := ""
	for quest_id in q.states:
		if q.is_active(str(quest_id)) and bool(q.definitions.get(str(quest_id), {}).get("main", false)):
			chapter = str(q.definitions.get(str(quest_id), {}).get("title", ""))
	var gate := game.director.tracker_entries()
	rows.append(_row("story", "Главная история", "Сюжет", true,
		("Глава: «%s»" % chapter) if not chapter.is_empty() else (str(gate[0].get("progress", "")) if not gate.is_empty() else "—"),
		"Журнал (J), золотые ◆ на карте", "Следующие главы открываются уровнем и добрыми делами."))
	var side_done := 0
	var side_active := 0
	for quest_id in q.states:
		if q.is_side(str(quest_id)):
			if q.is_completed(str(quest_id)):
				side_done += 1
			elif q.is_active(str(quest_id)):
				side_active += 1
	rows.append(_row("side", "Поручения жителей", "Сюжет", true, "выполнено %d, в работе %d" % [side_done, side_active], "Жители с «!» над головой", "Опыт, золото — и ключ к следующим главам."))
	# Hunts and fights.
	var legend_total := (game.legends.data.get("legends", {}) as Dictionary).size()
	rows.append(_row("legends", "Легендарные звери", "Охота", true, "повержено %d из %d" % [game.legends.defeated.size(), legend_total], "Ночью в каждой земле", "Огромные светящиеся звери с трофеями. Торен поможет выследить."))
	var guild_open := game.guild.level() >= 1
	rows.append(_row("guild", "Гильдия искателей", "Охота", guild_open, ("ранг «%s», заказов %d" % [game.guild.rank_name(), game.guild.finished]) if guild_open else "", "Деревня, здание гильдии", "Постройте гильдию на доске поселения." if not guild_open else "Именные чудовища за награду."))
	rows.append(_row("contracts", "Доска заказов", "Охота", true, "выполнено %d" % game.contracts.completed, "Деревня, доска у дороги", "Охота и доставка материалов за золото."))
	rows.append(_row("expeditions", "Экспедиции в Хранилище Узора", "Подземелья", guild_open,
		("походов %d · героических %d · легендарных %d" % [game.expeditions.completed, game.expeditions.heroic_done, game.expeditions.legendary_done]) if guild_open else "",
		"Рагна в гильдии", "Залы с ловушками, рунная загадка и Страж." if guild_open else "Откроется вместе с гильдией."))
	rows.append(_row("trials", "Башня испытаний", "Подземелья", true, ("рекорд: этаж %d" % game.trials.best) if game.trials.best > 0 else "", "Зелёные Пределы, к северо-востоку от деревни", "Этаж за этажом: правила, благословения, чемпионы. Падение не смертельно."))
	rows.append(_row("cistern", "Затопленная цистерна", "Подземелья", true, ("очищена %d раз" % game.cistern.times_cleared) if game.cistern.times_cleared > 0 else "", "Деревня, решётка у колодца", "Спускайте воду плитами водостока, дойдите до Хозяина. С каждым сезоном затапливается заново."))
	rows.append(_row("scout", "Тропа разведчицы", "Мирное", true, ("побед: %d" % game.scout.runs_won) if game.scout.runs_won > 0 else "", "Алая, к северу от деревни", "Забег по пяти флажкам на время; тропа меняется каждый день. Золотое время — плата вдвое."))
	rows.append(_row("forestry", "Лесная гильдия", "Мирное", true, "ранг: %s" % game.forestry.rank_name(), "Дом лесничих в лесу к востоку от деревни", "Рубите деревья и сажайте саженцы на пни — растёт ранг лесничего. В доме: верстак, очаг, постель."))
	rows.append(_row("rifts", "Глубокие разломы", "Подземелья", game.deep_rifts.unlocked(), ("лучшая глубина %d" % game.deep_rifts.best) if game.deep_rifts.unlocked() else "", "Земли старых разломов", "Бесконечная лестница волн и Пожиратель Узора." if game.deep_rifts.unlocked() else "После победы над Тенью Узора."))
	rows.append(_row("mine", "Рудник на перевале", "Подземелья", game.visited_regions.has("stone_pass"), "захвачен чудовищами!" if game.mine.overrun() else ("свободен" if game.mine.cleared() else "спокойно"), "Каменный перевал", "Иногда рудник захватывают — выбейте Рудного вожака."))
	# The sky.
	rows.append(_row("ship", "Корабль «Ветрокрыл»", "Небо", game.ship.is_ready(), "летает" if game.ship.is_ready() else "", "Причалы островов", "Полёты между островами, Грозовой остров и Остров-мираж." if game.ship.is_ready() else "Откроется после Акта II: обломки на Солёном берегу."))
	rows.append(_row("fates", "Судьба островов", "Небо", game.fates.unlocked(), "решено %d из 3" % game.fates.decided(), "Кристаллы трёх островов", "Спасти остров или забрать силу — навсегда." if game.fates.unlocked() else "После правды Вейла."))
	var faction_line: Array[String] = []
	for faction_id in game.factions.ids():
		faction_line.append("%s: %s" % [game.factions.name_of(str(faction_id)).get_slice(" ", 0), game.factions.rank(str(faction_id))])
	rows.append(_row("factions", "Фракции", "Небо", game.director.has_flag("ship_ready") or game.factions.value("keepers") != 0, ", ".join(faction_line), "Послы на острове, берегу и в роще", "Поручения, лавки для друзей, награды союзникам."))
	# Peaceful.
	rows.append(_row("fishing", "Рыбалка", "Мирное", true, "поймано %d" % stat.call("fish"), "Места с рябью на воде", "Подсечь вовремя и удержать рыбу в зелёной зоне."))
	rows.append(_row("treasure", "Карты сокровищ", "Мирное", true, "найдено кладов %d%s" % [game.treasure.found, " · карта в работе" if game.treasure.has_active() else ""], "Карты падают с врагов и из сундуков", "Прочитайте карту — на миникарте появится место раскопок."))
	rows.append(_row("farm", "Огород", "Мирное", game.farm.level() >= 1, ("уровень %d, урожаев %d" % [game.farm.level(), stat.call("harvests")]) if game.farm.level() >= 1 else "", "Деревня", "Сажайте семена, поливайте, собирайте." if game.farm.level() >= 1 else "Постройте огород на доске поселения."))
	var fair_when := "сегодня!" if VillageFair.is_fair_day(game.day_night.day) else "через %d дн." % game.fair.days_until()
	rows.append(_row("fair", "Ярмарка", "Мирное", true, "%s · рекорд тира %d" % [fair_when, game.fair.best], "Луг у рынка в Зелёных Пределах, каждые 4 дня", "Тир, рыбный день, лавка призов за жетоны, вечером фейерверк."))
	rows.append(_row("forge", "Кузня Борина", "Мирное", true, "уровень %d, заточек %d" % [game.borin.forge_level(), stat.call("forged")], "Борин в Пределах", "Заточка вещей, полки с оружием, щитами и украшениями."))
	rows.append(_row("trainers", "Наставники", "Мирное", true, "изучено %d" % game.player.learned_skills.size(), "Борин, Торен, Илара, Ориэн, Бран", "Навыки, заклинания и пассивки за золото."))
	rows.append(_row("crafts", "Ремесло", "Мирное", true, "создано %d" % stat.call("crafts"), "Клавиша B, верстаки и котлы", "Зелья, снаряжение, еда."))
	rows.append(_row("lore", "Летопись мира", "Знание", true, "прочитано %d из %d" % [game.lore.read.size(), game.lore.total()], "Рунные камни и таблички", "Журнал → «Летопись»."))
	var achievement_rows := game.achievements.entries()
	var done := achievement_rows.filter(func(a: Dictionary) -> bool: return bool(a["done"])).size()
	rows.append(_row("achievements", "Достижения", "Знание", true, "%d из %d" % [done, achievement_rows.size()], "Журнал → «Достижения»", "Каждое платит золотом."))
	rows.append(_row("events", "События в пути", "Знание", true, "", "Открытые земли", "Звездопад, золотой воришка, караван, странствующий торговец, попутный ветер — случаются сами."))
	return rows

static func _row(id: String, title: String, group: String, open: bool, progress: String, where: String, how: String) -> Dictionary:
	return {"id": id, "title": title, "group": group, "open": open, "progress": progress, "where": where, "how": how}
