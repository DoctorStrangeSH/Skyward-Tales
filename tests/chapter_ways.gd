extends SceneTree

## Review item 3: several ways to get ready for a story chapter. A gate
## counts deeds of any kind — help to the people (quests) or other ways
## (the Tower, the cistern, contracts, the scout's trail…); extra deeds stand
## in for missing levels; the journal explains what is left.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("CHAPTER WAYS FAILED: " + reason)
	quit(1)

func _done(game: SkywardGame, quest_id: String) -> void:
	game.quests.states[quest_id]["started"] = true
	game.quests.states[quest_id]["completed"] = true

func _link(game: SkywardGame, start: String) -> Dictionary:
	for link in game.director.chain:
		if str(link.get("start", "")) == start and link.has("giver"):
			return link
	return {}

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var director := game.director
	var hero := game.player
	_done(game, "main_prologue")
	_done(game, "moonleaf_gathering")

	# Every gate with quests also offers other ways, and each way reads a
	# counter that exists.
	var known: Dictionary = {}
	var file: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/achievements.json"))
	for id in file["achievements"]:
		known[str(file["achievements"][id]["stat"])] = true
	for link in director.chain:
		if not link.has("giver") or (link.get("requires", {}).get("quests", []) as Array).is_empty():
			continue
		if director.ways(link).size() < 3:
			return _fail("gate %s offers several other ways" % str(link["start"]))
		for way in director.ways(link):
			if not known.has(str(way["stat"])) or str(way["text"]).is_empty():
				return _fail("way reads a known counter: %s" % str(way))

	# The first gate: no side quest at all — a run with Alaya opens the story.
	var first := _link(game, "main_star_map")
	if director.link_ready(first) or director.deeds(first) != 0:
		return _fail("the first gate is closed")
	var lines := "\n".join(director.missing(first))
	if not lines.contains("Помощь: «") or not lines.contains("тропу разведчицы") or not lines.contains("Башни испытаний"):
		return _fail("the giver lists help and other ways:\n" + lines)
	game.achievements.set_max("scout_runs", 1)
	if not director.link_ready(first) or director.chapter_marker("elder") != "quest":
		return _fail("the scout's trail opens the chapter without a side quest")
	_done(game, "main_star_map")

	# A later gate: three deeds, level 10; mixed ways count together.
	for link in director.chain:
		if str(link.get("start", "")) == "main_spires":
			break
		if link.has("after") and not game.quests.is_completed(str(link["after"])) and game.quests.states.has(str(link["after"])):
			_done(game, str(link["after"]))
	_done(game, "main_archive")
	var spires := _link(game, "main_spires")
	if director.deeds_needed(spires) != 3:
		return _fail("the spires ask for three deeds")
	hero.level = 10
	game.achievements.stats.erase("trial_tower")
	var base := director.deeds(spires)
	_done(game, "coast_crabs")
	game.achievements.set_max("trial_tower", 8)
	game.achievements.set_max("cistern", 1)
	if director.deeds(spires) != base + 3 or (base == 0 and not director.link_ready(spires)):
		return _fail("a quest, the Tower and the cistern are three deeds: %d" % director.deeds(spires))
	if not director.link_ready(spires):
		return _fail("three mixed deeds open the chapter")

	# Extra deeds stand in for levels (up to two).
	hero.level = 8
	if director.link_ready(spires) and director.deeds(spires) < director.deeds_needed(spires) + 2:
		return _fail("two levels short need two extra deeds")
	var text := "\n".join(director.missing(spires))
	if director.deeds(spires) < director.deeds_needed(spires) + 2 and (not text.contains("Уровень") or not text.contains("заменяет уровень")):
		return _fail("the giver explains the level and the way around it:\n" + text)
	game.achievements.set_max("contracts", 5)
	game.achievements.set_max("legends", 1)
	if director.level_needed(spires) != 8 or not director.link_ready(spires):
		return _fail("five deeds forgive two levels: needs %d" % director.level_needed(spires))
	hero.level = 7
	if director.link_ready(spires):
		return _fail("no more than two levels are forgiven")

	# The journal explains the gate.
	var entries: Array = director.journal_entries()
	if entries.size() != 1 or not bool(entries[0]["gate"]) or not str(entries[0]["title"]).begins_with("Дальше: "):
		return _fail("the journal lists the waiting chapter")
	var page := str(entries[0]["description"])
	if not page.contains("Уровень 8") or not page.contains("Уже сделано") or not page.contains("начнётся у"):
		return _fail("the journal page explains the gate:\n" + page)
	game.input_handler.open_tab("journal")
	await process_frame
	await process_frame
	var seen := false
	for button in game.hud.journal_view.entry_list.get_children():
		if button is Button and (button as Button).text.contains("Дальше: "):
			seen = true
	if not seen:
		return _fail("the story tab shows the waiting chapter")
	game.input_handler.toggle_tab("journal")
	var tracker := str(director.tracker_entries()[0]["title"])
	if not tracker.contains("ур. 8") or not tracker.contains("журнал"):
		return _fail("the tracker points to the journal: " + tracker)
	hero.level = 8
	if not str(director.journal_entries()[0]["description"]).contains("открыта"):
		return _fail("an open chapter reads as open")
	print("CHAPTER WAYS OK")
	quit(0)
