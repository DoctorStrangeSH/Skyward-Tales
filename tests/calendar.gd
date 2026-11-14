extends SceneTree

## Этап 24: the calendar — dates, birthdays with presents, festivals with a
## gift once a year, the year's summary, the N tab.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("CALENDAR FAILED: " + reason)
	quit(1)

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var cal := game.calendar
	# Dates.
	if GameCalendar.date_text(0) != "Лето, 1-й день · понедельник · год 1" or GameCalendar.date_text(112 + 28 + 4) != "Осень, 5-й день · пятница · год 2":
		return _fail("dates: %s / %s" % [GameCalendar.date_text(0), GameCalendar.date_text(112 + 28 + 4)])
	if GameCalendar.DAYS_PER_YEAR != 112:
		return _fail("four seasons of 28 days")
	# Every day of the year shows; the fair every fourth day; every birthday is someone real.
	var fairs := 0
	var birthdays := 0
	for doy in GameCalendar.DAYS_PER_YEAR:
		for event in cal.events_on(doy):
			if event["kind"] == "fair":
				fairs += 1
			elif event["kind"] == "birthday":
				birthdays += 1
				if RegionCatalog.npc_name(str(event["id"])) == str(event["id"]) or hero.get_item_definition(str(GameCalendar.BIRTHDAYS[event["id"]]["loves"])).is_empty():
					return _fail("a real villager with a real favourite: " + str(event["id"]))
	if fairs != 16 or birthdays != GameCalendar.BIRTHDAYS.size():
		return _fail("a fair every Saturday and every birthday in a year (%d, %d)" % [fairs, birthdays])
	# Like Stardew: most days are ordinary, festivals two a season, never on a birthday.
	var empty := 0
	for doy in GameCalendar.DAYS_PER_YEAR:
		if cal.events_on(doy).is_empty():
			empty += 1
		var festivals := cal.events_on(doy).filter(func(e: Dictionary) -> bool: return e["kind"] == "festival").size()
		var birthday := cal.events_on(doy).filter(func(e: Dictionary) -> bool: return e["kind"] == "birthday").size()
		if festivals > 0 and birthday > 0:
			return _fail("a festival and a birthday on one day: %d" % doy)
	if empty < 70:
		return _fail("most days are empty: %d" % empty)
	for s in 4:
		var count := 0
		for id in GameCalendar.FESTIVALS:
			if int(GameCalendar.FESTIVALS[id]["day"]) / Seasons.LENGTH == s:
				count += 1
		if count != 2:
			return _fail("two festivals a season")
	var listed := cal.upcoming(6).filter(func(e: Dictionary) -> bool: return e["kind"] == "fair").size()
	if listed != 1:
		return _fail("only the next fair is listed in «soon»")
	if cal.upcoming(5).size() != 5 or GameCalendar.in_text(3) != "через 3 дня" or GameCalendar.in_text(5) != "через 5 дней":
		return _fail("what comes next")
	if cal.marker("elder") != "":
		return _fail("no celebrations before the prologue is over")
	game.quests.states["main_prologue"] = {"started": true, "completed": true, "progress": 1}
	# Borin's birthday: a marker, the favourite present pleases most.
	game.day_night.day = GameCalendar.DAYS_PER_YEAR + int(GameCalendar.BIRTHDAYS["blacksmith"]["day"])
	if cal.marker("blacksmith") != "service" or cal.marker("elder") != "":
		return _fail("the birthday marker")
	hero.add_item("star_fragment", 1)
	var gold := hero.gold
	if not cal.talk("blacksmith"):
		return _fail("the birthday takes the talk")
	game.dialogues.handle_choice("bday:blacksmith:star_fragment")
	if hero.inventory.has("star_fragment") and int(hero.inventory["star_fragment"]) > 0:
		return _fail("the present is given")
	if hero.gold != gold + 80:
		return _fail("the favourite: gold back and warmth")
	if cal.talk("blacksmith") or cal.marker("blacksmith") != "":
		return _fail("once a year")
	# Toren: a plain present still warms (relationships know him as "toren").
	game.day_night.day = int(GameCalendar.BIRTHDAYS["hunter"]["day"])
	hero.add_item("bread", 1)
	var warmth := game.relationships.get_score("toren")
	cal.talk("hunter")
	game.dialogues.handle_choice("bday:hunter:bread")
	if game.relationships.get_score("toren") != warmth + 8:
		return _fail("a present warms Toren")
	game.day_night.day = GameCalendar.DAYS_PER_YEAR + int(GameCalendar.BIRTHDAYS["blacksmith"]["day"])
	# Next year — again.
	game.day_night.day += GameCalendar.DAYS_PER_YEAR
	if not cal.birthday_today("blacksmith"):
		return _fail("a birthday every year")
	# Festivals: the harvest gift once a year.
	game.day_night.day = int(GameCalendar.FESTIVALS["harvest"]["day"])
	var bread := int(hero.inventory.get("bread", 0))
	if not cal.talk("farmer_gavrila") or int(hero.inventory.get("bread", 0)) != bread + 3:
		return _fail("the harvest basket")
	game.hud.close_dialogue()
	if cal.festival_today("farmer_gavrila") != "" or cal.talk("farmer_gavrila"):
		return _fail("the festival gift once a year")
	# The year's eve: the elder sums it up.
	cal._process(0.0)
	game.achievements.add("kills")
	game.achievements.add("kills")
	game.day_night.day = int(GameCalendar.FESTIVALS["year_end"]["day"])
	cal._start_year()
	game.achievements.add("kills")
	if not cal.year_summary().contains("одолел") or not cal.year_summary().contains("— 1"):
		return _fail("the year's summary counts this year: " + cal.year_summary())
	# The tab.
	game.input_handler.open_tab("calendar")
	await process_frame
	if not game.hud.calendar_visible or game.input_handler.current_tab() != "calendar":
		return _fail("N opens the calendar")
	var view := game.hud.calendar_view
	if view.grid.get_child_count() != 7 + 28:
		return _fail("weekdays and four weeks of a season")
	if not view.title.text.contains("Весна") or view.season_label.text != "Весна":
		return _fail("opens on today's season: " + view.title.text)
	view.turn(1)
	if view.season_label.text != "Лето" or view.grid.get_child_count() != 7 + 28:
		return _fail("◀ ▶ turn the seasons")
	game.input_handler.close_tabs()
	if game.hud.calendar_visible:
		return _fail("closes")
	# Saved.
	var snapshot := game.make_save_snapshot()
	cal.greeted.clear()
	if not game.restore_save_snapshot(snapshot) or int(game.calendar.greeted.get("blacksmith", 0)) != 2:
		return _fail("greetings survive a save")
	print("CALENDAR OK")
	quit()
