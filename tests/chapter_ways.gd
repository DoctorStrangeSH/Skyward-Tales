extends SceneTree

## Story gates (review item 3, reworked in Этап 23): a gate has a key — one
## errand the story needs (Mira's pages, the chant scroll…), handed out and
## taken back by the chapter's giver; other deeds (quests, the Tower, the
## cistern…) forgive missing levels; the journal explains what is left.

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

	# Этап 23: the first gate has a key — Mira's lost pages. Other deeds do
	# not open it.
	var first := _link(game, "main_star_map")
	if director.link_ready(first) or director.key_done(first):
		return _fail("the first gate is closed")
	var lines := "\n".join(director.missing(first))
	if not lines.contains("Без этого никак") or not lines.contains("Страницы, унесённые ветром"):
		return _fail("the giver names the key errand:\n" + lines)
	game.achievements.set_max("scout_runs", 1)
	if director.link_ready(first):
		return _fail("the scout's trail alone does not open the chapter")
	_done(game, "lost_cartographer_notes")
	if not director.link_ready(first) or director.chapter_marker("elder") != "quest":
		return _fail("Mira's pages open the chapter")
	_done(game, "main_star_map")

	# The spires: the key errand is handed out by Orien, brought back to him.
	for link in director.chain:
		if str(link.get("start", "")) == "main_spires":
			break
		if link.has("after") and not game.quests.is_completed(str(link["after"])) and game.quests.states.has(str(link["after"])):
			_done(game, str(link["after"]))
	_done(game, "main_archive")
	var spires := _link(game, "main_spires")
	if director.deeds_needed(spires) != 0 or director.key_quest(spires) != "key_wind_chant":
		return _fail("the spires have a key, deeds are optional")
	hero.level = 10
	if director.link_ready(spires) or director.chapter_marker("archivist") != "quest":
		return _fail("'!' over Orien: he hands out the key errand")
	if not director.try_talk("archivist") or not game.quests.is_active("key_wind_chant"):
		return _fail("talking to Orien starts the chant errand")
	game.story.skip()
	game.hud.close_dialogue()
	if director.chapter_marker("archivist") != "":
		return _fail("no marker while the errand is on")
	game.quests.add_progress("key_wind_chant", 1)
	if director.chapter_marker("archivist") != "ready":
		return _fail("'?' over Orien when the scroll is found")
	# Extra deeds stand in for levels (up to two).
	hero.level = 8
	var text := "\n".join(director.missing(spires))
	if not text.contains("Уровень") or not text.contains("сокращает путь"):
		return _fail("the giver explains the level and the way around it:\n" + text)
	game.achievements.stats.erase("trial_tower")
	game.achievements.stats.erase("cistern")
	game.achievements.stats.erase("scout_runs")
	_done(game, "coast_crabs")
	game.achievements.set_max("cistern", 1)
	if director.level_needed(spires) != 8:
		return _fail("two deeds forgive two levels: needs %d" % director.level_needed(spires))
	game.achievements.set_max("contracts", 5)
	if director.level_needed(spires) != 8:
		return _fail("no more than two levels are forgiven")
	# The journal explains the gate.
	hero.level = 7
	var entries: Array = director.journal_entries()
	if entries.size() != 1 or not bool(entries[0]["gate"]) or not str(entries[0]["title"]).begins_with("Дальше: "):
		return _fail("the journal lists the waiting chapter")
	var page := str(entries[0]["description"])
	if not page.contains("Уровень 8") or not page.contains("начнётся у"):
		return _fail("the journal page explains the gate:\n" + page)
	var tracker := str(director.tracker_entries()[0]["title"])
	if not tracker.contains("ур. 8") or not tracker.contains("журнал"):
		return _fail("the tracker points to the journal: " + tracker)
	# Bringing the scroll back: the errand completes and the chapter opens.
	hero.level = 8
	if not director.try_talk("archivist") or not game.quests.is_completed("key_wind_chant"):
		return _fail("Orien takes the scroll")
	game.story.skip()
	if not bool(game.quests.states["main_spires"]["started"]):
		return _fail("and the chapter begins")
	print("CHAPTER WAYS OK")
	quit(0)
