extends RefCounted
class_name StoryDirector

## Drives the main story from data/dialogues.json "chain":
## - after a quest completes, start the next main quest and queue its scene;
## - "talk" objectives: talking to an NPC plays a scene and completes the quest;
## - region "on_enter" scenes (once, remembered in story flags);
## - boss defeats that finish a chapter.
## Story mode is on only for adventures started from the title menu
## (main_prologue started), so older saves and tests keep the classic flow.

var game: SkywardGame
var chain: Array = []
var on_enter: Array = []
var bosses: Dictionary = {}
var flags: Dictionary = {}
var _queue: Array[Dictionary] = []

func _init(owner_game: SkywardGame) -> void:
	game = owner_game
	var file := FileAccess.open(StoryScene.DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		chain = parsed.get("chain", [])
		on_enter = parsed.get("on_enter", [])
		bosses = parsed.get("bosses", {})

func story_mode() -> bool:
	return bool(game.quests.states.get("main_prologue", {}).get("started", false))

func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))

func set_flag(flag: String) -> void:
	flags[flag] = true

## Scenes wait until no dialogue is open, then play one by one.
func queue_scene(scene_id: String, on_finished: Callable = Callable()) -> void:
	_queue.append({"scene": scene_id, "done": on_finished})

func has_pending() -> bool:
	return not _queue.is_empty()

func update() -> void:
	if _queue.is_empty() or game.story.active or game.hud.dialogue_visible or game.get_tree().paused:
		return
	var next: Dictionary = _queue.pop_front()
	game.story.play(str(next["scene"]), next["done"])

# --- Chapter gates (owner's list №7) -------------------------------------------
# A chain link with "giver" does not start by itself: the next chapter is
# taken from that NPC, and only once "requires" is met — {"level": N,
# "quests": [...], "count": K, "why": "…"}. Until then the giver says what is
# missing and where to get it; the tracker shows the same hint.

## Tests of the story beats (and a debug switch) run the chain without gates:
## every chapter starts right after the previous one, as before the gates.
var auto_chapters: bool = false

## Links whose chapter waits for its giver right now.
func pending_links() -> Array:
	var result: Array = []
	if not story_mode() or auto_chapters:
		return result
	for link in chain:
		if not link.has("giver"):
			continue
		var start := str(link.get("start", ""))
		if game.quests.is_completed(str(link.get("after", ""))) and not bool(game.quests.states.get(start, {}).get("started", false)) and not game.quests.is_completed(start):
			result.append(link)
	return result

func _done_count(link: Dictionary) -> int:
	var done := 0
	for quest_id in link.get("requires", {}).get("quests", []):
		if game.quests.is_completed(str(quest_id)):
			done += 1
	return done

# Several ways to get ready (the review of 11 November): besides helping the
# people ("quests"), a gate lists "ways" — {"stat", "min", "text"} checked
# against the achievement counters (the Tower's floor, contracts, legends,
# the cistern…). Every finished quest and every finished way is one deed;
# the gate asks for "count" deeds of any kind. Deeds above the count stand
# in for missing levels (LEVEL_PER_DEED each, at most MAX_LEVEL_RELIEF).
const MAX_LEVEL_RELIEF := 2

func _stat(way: Dictionary) -> int:
	return int(game.achievements.stats.get(str(way.get("stat", "")), 0)) if game.achievements != null else 0

func way_done(way: Dictionary) -> bool:
	return _stat(way) >= int(way.get("min", 1))

func ways(link: Dictionary) -> Array:
	return link.get("requires", {}).get("ways", [])

func _ways_done(link: Dictionary) -> int:
	var done := 0
	for way in ways(link):
		if way_done(way):
			done += 1
	return done

## Deeds done for this gate: quests helped plus other ways.
func deeds(link: Dictionary) -> int:
	return _done_count(link) + _ways_done(link)

# Этап 23, the owner: "smart side quests that open the way, not just any
# deeds". A gate may name a key ("requires.key"): one particular errand
# whose outcome the story needs (a key, a chant, a compass). {"quest": id}
# — a quest; {"flag": id} — a world flag; "start": true — the giver hands
# the errand out himself; "intro" — his lines when he does; "hint" — where
# to look. Other deeds then only forgive levels (each one, up to 2).
func key(link: Dictionary) -> Dictionary:
	return link.get("requires", {}).get("key", {})

func key_done(link: Dictionary) -> bool:
	var k := key(link)
	if k.is_empty():
		return true
	if k.has("flag"):
		return has_flag(str(k["flag"]))
	return game.quests.is_completed(str(k.get("quest", "")))

func key_quest(link: Dictionary) -> String:
	return str(key(link).get("quest", ""))

func deeds_needed(link: Dictionary) -> int:
	if not key(link).is_empty():
		return 0
	var req: Dictionary = link.get("requires", {})
	var quests: Array = req.get("quests", [])
	if quests.is_empty() and ways(link).is_empty():
		return 0
	return int(req.get("count", quests.size()))

## The level the gate asks for now: every deed above the count forgives one
## level (up to MAX_LEVEL_RELIEF).
func level_needed(link: Dictionary) -> int:
	var level := int(link.get("requires", {}).get("level", 0))
	if not key(link).is_empty():
		return level - clampi(deeds(link), 0, MAX_LEVEL_RELIEF)
	if level <= 0 or deeds_needed(link) <= 0:
		return level
	return level - clampi(deeds(link) - deeds_needed(link), 0, MAX_LEVEL_RELIEF)

func link_ready(link: Dictionary) -> bool:
	if game.player.level < level_needed(link) or not key_done(link):
		return false
	return deeds(link) >= deeds_needed(link)

## Lines saying what is still missing, with hints where to get it.
func missing(link: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var req: Dictionary = link.get("requires", {})
	var need := deeds_needed(link)
	var have := deeds(link)
	var level := level_needed(link)
	var k := key(link)
	if not k.is_empty() and not key_done(link):
		var quest_id := key_quest(link)
		var state := ""
		if not quest_id.is_empty() and game.quests.is_ready_to_complete(quest_id):
			state = " — готово, поговорите: %s" % _giver_name(link)
		elif not quest_id.is_empty() and game.quests.is_active(quest_id):
			state = " — в пути (%d из %d)" % [int(game.quests.states[quest_id].get("progress", 0)), int(game.quests.definitions[quest_id].get("target", 1))]
		var title := str(game.quests.definitions.get(quest_id, {}).get("title", "")) if not quest_id.is_empty() else ""
		lines.append("• Без этого никак: %s%s%s" % [("«%s» — " % title) if not title.is_empty() else "", str(k.get("hint", "")), state])
	if game.player.level < level:
		var relief := ""
		if not k.is_empty() and deeds(link) < MAX_LEVEL_RELIEF:
			relief = " Каждое доброе дело ниже сокращает путь на уровень (до %d)." % MAX_LEVEL_RELIEF
		if need > 0 and int(req.get("level", 0)) - level < MAX_LEVEL_RELIEF:
			relief = " Или сделайте ещё дело сверх нужного: каждое заменяет уровень (до %d)." % MAX_LEVEL_RELIEF
		lines.append("• Уровень %d (сейчас %d) — сражайтесь, выполняйте поручения.%s" % [level, game.player.level, relief])
	var quests: Array = req.get("quests", [])
	if need > 0 and have < need:
		lines.append("• %s — любые дела на выбор (%d из %d):" % [str(req.get("why", "Подготовьтесь")), have, need])
	if (need > 0 and (have < need or game.player.level < level)) or (not k.is_empty() and game.player.level < level):
		var shown := 0
		for quest_id in quests:
			if game.quests.is_completed(str(quest_id)) or shown >= 3:
				continue
			shown += 1
			var title := str(game.quests.definitions.get(quest_id, {}).get("title", quest_id))
			var source := quest_source(str(quest_id))
			var state := " — уже взято" if game.quests.is_active(str(quest_id)) else ""
			lines.append("   – Помощь: «%s» (%s)%s" % [title, source, state])
		shown = 0
		for way in ways(link):
			if way_done(way) or shown >= 4:
				continue
			shown += 1
			var goal := int(way.get("min", 1))
			var count := " (%d из %d)" % [_stat(way), goal] if goal > 1 else ""
			lines.append("   – %s%s" % [str(way.get("text", "")), count])
	return lines

## The whole gate for the journal: the chapter, its giver, what is done and
## what is left.
func gate_text(link: Dictionary) -> String:
	var title := str(game.quests.definitions.get(str(link.get("start", "")), {}).get("title", "Следующая глава"))
	if link_ready(link):
		return "Глава «%s» открыта. Поговорите: %s." % [title, _giver_name(link)]
	var text := "Глава «%s» начнётся у: %s. Сначала нужно подготовиться — путь выбираете вы.\n" % [title, _giver_name(link)]
	text += "\n".join(missing(link))
	var finished: Array[String] = []
	for way in ways(link):
		if way_done(way):
			finished.append(str(way.get("text", "")))
	for quest_id in link.get("requires", {}).get("quests", []):
		if game.quests.is_completed(str(quest_id)):
			finished.append("Помощь: «%s»" % str(game.quests.definitions.get(quest_id, {}).get("title", quest_id)))
	if not finished.is_empty():
		text += "\nУже сделано: " + "; ".join(finished) + "."
	return text

## Pseudo-entries of the journal's story tab for chapters that wait.
func journal_entries() -> Array:
	var result: Array = []
	for link in pending_links():
		var title := str(game.quests.definitions.get(str(link.get("start", "")), {}).get("title", "Следующая глава"))
		var need := maxi(1, deeds_needed(link))
		result.append({"id": "@gate:" + str(link.get("start", "")), "title": "Дальше: " + title, "description": gate_text(link),
			"progress": mini(deeds(link), need), "target": need,
			"decision": "", "main": true, "tracked": true, "gate": true, "ready": link_ready(link)})
	return result

## Who gives a quest and where: "Мира, Зелёные Пределы".
func quest_source(quest_id: String) -> String:
	const HANDMADE := {"lost_cartographer_notes": "cartographer", "toren_wolf_hunt": "hunter", "bran_supply_run": "merchant", "borin_dream": "blacksmith", "borin_temper": "blacksmith", "ship_wreck": "haven_anchor"}
	var npc_id := str(HANDMADE.get(quest_id, ""))
	if npc_id.is_empty() and game.givers != null:
		for giver_id in game.givers.givers:
			if quest_id in game.givers.givers[giver_id].get("quests", []):
				npc_id = str(giver_id)
	for region_id in RegionCatalog.all_ids():
		for npc in RegionCatalog.get_region(str(region_id)).get("npcs", []):
			if str(npc.get("id", "")) == npc_id:
				return "%s, %s" % [str(npc.get("name", npc_id)), RegionCatalog.display_name(str(region_id))]
	return "спросите у жителей"

func _giver_name(link: Dictionary) -> String:
	var npc_id := str(link.get("giver", ""))
	if npc_id == "cartographer":
		return "Мира"
	for region_id in RegionCatalog.all_ids():
		for npc in RegionCatalog.get_region(str(region_id)).get("npcs", []):
			if str(npc.get("id", "")) == npc_id:
				return str(npc.get("name", npc_id))
	return npc_id

## "quest" over a giver whose chapter is open; "" otherwise.
func chapter_marker(npc_id: String) -> String:
	for link in pending_links():
		if str(link.get("giver", "")) == npc_id:
			if link_ready(link):
				return "quest"
			# A key errand to hand out or to take back shows over the giver.
			var quest_id := key_quest(link)
			if not quest_id.is_empty() and game.quests.is_ready_to_complete(quest_id):
				return "ready"
			if not quest_id.is_empty() and bool(key(link).get("start", false)) and not bool(game.quests.states.get(quest_id, {}).get("started", false)):
				return "quest"
			return ""
	return ""

func chapter_quest(npc_id: String) -> String:
	for link in pending_links():
		if str(link.get("giver", "")) == npc_id:
			return str(link.get("start", ""))
	return ""

## The tracker's line about the next chapter.
func tracker_entries() -> Array:
	var result: Array = []
	for link in pending_links():
		var title := str(game.quests.definitions.get(str(link.get("start", "")), {}).get("title", "Следующая глава"))
		if link_ready(link):
			result.append({"title": "Глава «%s»: поговорите — %s" % [title, _giver_name(link)], "main": true, "progress": 0, "target": 1})
		else:
			var parts: Array[String] = []
			if not key_done(link):
				var key_title := str(game.quests.definitions.get(key_quest(link), {}).get("title", ""))
				parts.append("«%s»" % key_title if not key_title.is_empty() else str(key(link).get("short", "ключ к главе")))
			if game.player.level < level_needed(link):
				parts.append("ур. %d" % level_needed(link))
			if deeds(link) < deeds_needed(link):
				parts.append("дела %d/%d" % [deeds(link), deeds_needed(link)])
			result.append({"title": "Сюжет закрыт: нужно %s (журнал — J)" % ", ".join(parts), "main": true, "progress": 0, "target": 1})
	return result

## The giver's answer: open the chapter, or say what is missing.
func _offer_chapter(link: Dictionary) -> bool:
	if link_ready(link):
		if bool(link.get("npc_starts", false)):
			return false
		_begin_link(link)
		return true
	var k := key(link)
	var quest_id := key_quest(link)
	if not quest_id.is_empty() and game.quests.is_ready_to_complete(quest_id):
		# The errand is done: the giver takes what was brought.
		_complete(quest_id)
		if link_ready(link):
			if bool(link.get("npc_starts", false)):
				_begin_link(link)
			else:
				_begin_link(link)
			return true
	elif not quest_id.is_empty() and bool(k.get("start", false)) and not bool(game.quests.states.get(quest_id, {}).get("started", false)) and not game.quests.is_completed(quest_id):
		game.quests.start_quest(quest_id)
		var intro: Array = k.get("intro", [])
		if not intro.is_empty():
			game.talk_line(str(link.get("giver", "")), _giver_name(link), intro)
		else:
			game._show_dialogue(_giver_name(link), str(game.quests.definitions[quest_id].get("description", "")))
		game.hud.show_message("Ключ к главе: " + str(game.quests.definitions[quest_id].get("title", "")), 3.5)
		game.update_npc_markers()
		return true
	var lines := missing(link)
	var text := str(link.get("locked", "Ещё рано, {hero}. Сначала —")) + "\n" + "\n".join(lines)
	game._show_dialogue(_giver_name(link), text)
	return true

func _begin_link(link: Dictionary) -> void:
	var next_quest := str(link.get("start", ""))
	var scene := str(link.get("scene", ""))
	var title := str(link.get("title", ""))
	var begin := func() -> void:
		if not title.is_empty():
			game.hud.show_title_card(title, 4.0)
		if not next_quest.is_empty() and game.quests.start_quest(next_quest):
			game.hud.show_message("Новая глава: " + str(game.quests.definitions[next_quest].get("title", "")), 3.0)
			game.spawn_story_objects()
		game.update_npc_markers()
		game._refresh_hud()
	if scene.is_empty() or not game.story.has_scene(scene):
		begin.call()
	else:
		game.story.play(scene, begin)

func on_quest_completed(quest_id: String) -> void:
	if not story_mode():
		return
	for link in chain:
		if str(link.get("after", "")) != quest_id:
			continue
		if link.has("giver") and not auto_chapters:
			# The next chapter waits for its giver.
			var who := _giver_name(link)
			if link_ready(link):
				game.hud.show_message("Следующая глава: поговорите — %s." % who, 4.0)
			else:
				game.hud.show_message("Сюжет пока закрыт. %s подскажет, что нужно сделать." % who, 4.5)
			game.update_npc_markers.call_deferred()
			continue
		var next_quest := str(link.get("start", ""))
		var scene := str(link.get("scene", ""))
		var title := str(link.get("title", ""))
		var begin := func() -> void:
			if not title.is_empty():
				game.hud.show_title_card(title, 4.0)
			if not next_quest.is_empty() and game.quests.start_quest(next_quest):
				game.hud.show_message("Новая глава: " + str(game.quests.definitions[next_quest].get("title", "")), 3.0)
				game.spawn_story_objects()
			game._refresh_hud()
		# The next chapter starts at once: with its scene, or right away.
		if scene.is_empty() or not game.story.has_scene(scene):
			begin.call_deferred()
		else:
			queue_scene(scene, begin)

## Returns true if talking to this NPC advanced the main story.
func try_talk(npc_id: String) -> bool:
	if not story_mode() or game.story.active:
		return false
	for link in pending_links():
		if str(link.get("giver", "")) == npc_id:
			return _offer_chapter(link)
	var quest_id := game.quests.active_quest_id
	var definition: Dictionary = game.quests.definitions.get(quest_id, {})
	if str(definition.get("talk_to", "")) != npc_id:
		return false
	if bool(definition.get("talk_requires_progress", false)) and not game.quests.is_ready_to_complete(quest_id):
		return false
	game.story.play(str(definition.get("talk_scene", "")), func() -> void: _complete(quest_id))
	return true

## The NPC the current main objective asks to talk to (for markers).
func talk_target() -> String:
	if not story_mode():
		return ""
	return str(game.quests.definitions.get(game.quests.active_quest_id, {}).get("talk_to", ""))

func on_region_entered(region_id: String) -> void:
	if not story_mode():
		return
	for trigger in on_enter:
		var flag := str(trigger.get("flag", ""))
		if str(trigger.get("region", "")) == region_id and not has_flag(flag):
			set_flag(flag)
			var completes := str(trigger.get("completes", ""))
			queue_scene(str(trigger.get("scene", "")), func() -> void:
				if not completes.is_empty() and game.quests.active_quest_id == completes:
					_complete(completes))

func on_boss_defeated(kind: String) -> void:
	if not story_mode() or not bosses.has(kind):
		return
	var data: Dictionary = bosses[kind]
	var quest_id := str(data.get("completes", ""))
	queue_scene(str(data.get("scene", "")), func() -> void:
		_complete(quest_id)
		var item := str(data.get("grants_item", ""))
		if not item.is_empty():
			game.player.add_item(item)
			game.hud.show_message("Получено: " + game.player.get_item_name(item), 3.0)
		if data.has("title"):
			game.hud.show_title_card(str(data["title"]), 4.0)
		if bool(data.get("finale", false)):
			game.offer_finale())

func _complete(quest_id: String) -> void:
	var quests := game.quests
	if quest_id.is_empty() or not quests.states.has(quest_id) or quests.is_completed(quest_id):
		return
	if not bool(quests.states[quest_id].get("started", false)):
		quests.start_quest(quest_id)
	var target := int(quests.definitions[quest_id].get("target", 1))
	quests.add_progress(quest_id, target)
	if quests.complete_quest(quest_id):
		game._grant_quest_reward(quest_id)
		game.hud.show_message("Глава завершена: " + str(quests.definitions[quest_id].get("title", "")), 3.0)
	game._refresh_hud()

func make_snapshot() -> Dictionary:
	return flags.duplicate(true)

func restore_snapshot(data: Variant) -> void:
	flags = data.duplicate(true) if data is Dictionary else {}
	_queue.clear()
