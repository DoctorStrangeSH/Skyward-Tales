extends SceneTree

## Этап 24: Friday evening at Greta's — dice with Yar, a bard's song for
## good spirits (+10% gold), a round for the house; on the calendar.

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("TAVERN PARTY FAILED: " + reason)
	quit(1)

func _ids(game: SkywardGame) -> Array:
	var ids: Array = []
	for button in game.hud.dialogue_choices_container.get_children():
		if button.has_meta("choice_id") and not button.is_queued_for_deletion():
			ids.append(str(button.get_meta("choice_id")))
	return ids

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	var party := game.tavern_party
	game.day_night.day = 4
	game.day_night.time = 0.8
	if party.tonight():
		return _fail("no party without a tavern")
	game.settlement.buildings[VillageBuildings.TAVERN] = 1
	if not party.tonight() or not TavernParty.is_party_day(11) or TavernParty.is_party_day(5):
		return _fail("Friday evenings")
	if game.calendar.events_on(4).filter(func(e: Dictionary) -> bool: return e["kind"] == "party").size() != 1:
		return _fail("the calendar marks Fridays")
	game.buildings.talk_tavern()
	await process_frame
	var ids := _ids(game)
	if not ids.has("tparty_dice") or not ids.has("tparty_song") or not ids.has("tparty_round"):
		return _fail("Greta's party menu: %s" % str(ids))
	# Dice: wins pay, three a night at most.
	hero.gold = 1000
	party.rng.seed = 7
	var won := 0
	for i in 40:
		var roll := party.roll_dice()
		if roll.is_empty():
			break
		if roll["result"] == "win":
			won += 1
	if won != TavernParty.MAX_WINS or not party.roll_dice().is_empty():
		return _fail("three wins a night (%d)" % won)
	# The song: good spirits, +10% gold.
	var mult := hero.get_gold_multiplier()
	game.dialogues.handle_choice("tparty_song")
	if not party.cheer() or absf(hero.get_gold_multiplier() - mult * 1.1) > 0.001:
		return _fail("the song: +10% gold")
	# A round for the house warms the villagers.
	var warmth := game.relationships.get_score("bran")
	game.dialogues.handle_choice("tparty_round")
	if game.relationships.get_score("bran") != warmth + 2 or party.choices().any(func(c: Dictionary) -> bool: return c["id"] == "tparty_round"):
		return _fail("one round a night, Bran warms")
	# Not on a Saturday.
	game.day_night.day = 5
	if party.tonight() or not party.choices().is_empty():
		return _fail("only on Fridays")
	print("TAVERN PARTY OK")
	quit()
