extends SceneTree

## Этап 24: every great foe drops its own item that changes how you fight;
## Borin forges the trophies of foes beaten before (old saves) and reforges
## one property of a rolled item (the old one can be taken back).

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	push_error("BOSS TROPHIES FAILED: " + reason)
	quit(1)

func _choice_ids() -> Array:
	var ids: Array = []
	for button in game_ref.hud.dialogue_choices_container.get_children():
		if button.has_meta("choice_id"):
			ids.append(str(button.get_meta("choice_id")))
	return ids

var game_ref: SkywardGame

func _run() -> void:
	var game: SkywardGame = load("res://scenes/main.tscn").instantiate()
	game_ref = game
	root.add_child(game)
	await process_frame
	game.autosave_enabled = false
	game.events.enabled = false
	var hero := game.player
	for node in game.get_children():
		if node is SlimeEnemy:
			node.free()
	# Every boss has a trophy, each a real item with an effect text.
	for kind in SkywardGame.STORY_BOSSES:
		var item_id := SignatureGear.trophy_of(kind)
		if item_id.is_empty() or hero.get_item_definition(item_id).is_empty() or SignatureGear.effect_text(item_id).is_empty():
			return _fail("a trophy for " + kind)
		if not ResourceLoader.exists("res://assets/icons/%s.png" % item_id):
			return _fail("an icon for " + item_id)
	if SignatureGear.TROPHIES.size() != SkywardGame.STORY_BOSSES.size() + 1:
		return _fail("12 trophies: story bosses and the grove guardian")
	# The first defeat drops it, the second does not.
	var at := hero.global_position + Vector2(60, 0)
	game._on_story_boss_defeated("crab_king", 900, at)
	var dropped := 0
	for node in game.get_children():
		if node is WorldLoot and node.item_id == "crab_king_shell":
			dropped += 1
	if dropped != 1 or not game.director.has_flag("trophy_crab_king"):
		return _fail("the crab king drops his shell")
	game.signature.on_boss_defeated("crab_king", at)
	if game.signature.missing().size() != 0:
		return _fail("nothing missing yet")
	# An old save: the giant fell but the trophy never dropped → Borin forges it.
	game.director.set_flag("giant_defeated")
	if game.signature.missing() != ["giant"]:
		return _fail("the giant's trophy is missing: %s" % str(game.signature.missing()))
	hero.gold = 1000
	hero.add_item("ancient_relic", 1)
	if not game.reforge.forge_trophy("giant") or int(hero.inventory.get("giant_fist", 0)) != 1 or hero.gold != 750:
		return _fail("Borin forges the giant's fist")
	# Effects: the vail cloak — a kill, then a strike ×1.8.
	var foe := game.spawn_enemy("golem", hero.global_position + Vector2(400, 0))
	foe.set_physics_process(false)
	hero.add_item("vail_cloak", 1)
	hero.equip_item("vail_cloak")
	game.signature.on_kill()
	if absf(game.signature.strike_mult(foe) - 1.8) > 0.001 or absf(game.signature.strike_mult(foe) - 1.0) > 0.001:
		return _fail("the shadow of Vail empowers one strike")
	# The heartwood bark: standing still roots the hero.
	hero.add_item("heartwood_bark", 1)
	hero.equip_item("heartwood_bark")
	var before := hero.get_damage_reduction()
	hero.velocity = Vector2.ZERO
	game.signature._process(1.1)
	if not game.signature.rooted or absf(hero.get_damage_reduction() - before - 0.25) > 0.001:
		return _fail("roots: −25%% damage (%.2f → %.2f)" % [before, hero.get_damage_reduction()])
	# The titan core: heat from hits, a blast on a dodge.
	hero.add_item("titan_core", 1)
	hero.equip_item("titan_core")
	for i in 6:
		game.signature.on_hurt()
	if game.signature.heat != 6 or absf(game.signature.strike_mult(foe) - 1.12) > 0.001:
		return _fail("six heat: +12%%, got %.2f" % game.signature.strike_mult(foe))
	game.signature.on_dodge()
	if game.signature.heat != 0:
		return _fail("a dodge spends the heat")
	# Reforging: a rolled rare item, one property struck off and forged anew.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var definition := LootGenerator.generate(rng, 5, "rare")
	var item_id := hero.register_generated_item(definition)
	hero.add_item(item_id, 1)
	var old_affixes := Reforge.affixes_of(hero.get_item_definition(item_id))
	if old_affixes.size() != 3:
		return _fail("a rare item has three properties")
	# Items rolled before reforging are read from their description.
	var legacy := hero.get_item_definition(item_id).duplicate(true)
	legacy.erase("affixes")
	if Reforge.affixes_of(legacy) != old_affixes:
		return _fail("old items: properties read from the text %s vs %s" % [str(Reforge.affixes_of(legacy)), str(old_affixes)])
	var stats_before := hero.get_item_definition(item_id).duplicate(true)
	hero.add_item("iron_ore", 10)
	var gold_before := hero.gold
	var fresh := game.reforge.reforge(item_id, 1, rng)
	if fresh.is_empty() or hero.gold >= gold_before:
		return _fail("reforging is paid")
	var now := Reforge.affixes_of(hero.get_item_definition(item_id))
	if now[1] != fresh or now[0] != old_affixes[0] or now[2] != old_affixes[2]:
		return _fail("only the chosen property changes")
	for entry in now:
		if str(entry["id"]) == str(old_affixes[1]["id"]) and entry != now[1]:
			return _fail("no duplicate property")
	if not str(hero.get_item_definition(item_id)["description"]).contains(Reforge.line_of(fresh)):
		return _fail("the description shows the new property")
	if not game.reforge.revert():
		return _fail("the old property can be taken back")
	var reverted := hero.get_item_definition(item_id)
	for key in stats_before:
		if key in ["reforged", "affixes", "description"]:
			continue
		if str(reverted.get(key)) != str(stats_before[key]):
			return _fail("revert restores %s: %s vs %s" % [key, str(reverted.get(key)), str(stats_before[key])])
	if int(reverted.get("reforged", 0)) != 1 or game.reforge.cost(item_id)["gold"] <= 0:
		return _fail("the second reforging costs more")
	# Borin's menu offers reforging.
	game.borin.handle_choice("borin_later")
	game.dialogues.on_blacksmith_crafting()
	if not _choice_ids().has("borin_reforge"):
		return _fail("Borin offers reforging: %s" % str(_choice_ids()))
	game.dialogues.handle_choice("borin_reforge")
	if not _choice_ids().has("reforge_item:" + item_id):
		return _fail("the rolled item is in the list: %s" % str(_choice_ids()))
	# Saved with the hero.
	var snapshot := game.make_save_snapshot()
	if not game.restore_save_snapshot(snapshot) or int(game.player.get_item_definition(item_id).get("reforged", 0)) != 1 or not game.director.has_flag("trophy_giant"):
		return _fail("reforging and trophies survive a save")
	print("BOSS TROPHIES OK")
	quit()
