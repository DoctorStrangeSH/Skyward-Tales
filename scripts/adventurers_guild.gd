extends RefCounted
class_name AdventurersGuild

## The Adventurers' Guild (village building, Ragna). Bounties: a named
## monster lurks in a land the hero has visited; take the job, find it
## (marked on the minimap and the world map), beat it, come back for the pay.
## Ranks grow with finished bounties and raise every reward by 10%.
## Level 2: "Гроза земель" bounties — twice as tough, epic loot.

const BUILDING := "guild"
## A mighty bounty also pays with one of these (each once).
const TROPHIES := ["viper_fang", "storm_spear", "titan_breaker", "blossom_bow"]
const RANKS := [["Новичок", 0], ["Медь", 2], ["Бронза", 5], ["Серебро", 9], ["Золото", 14], ["Небесный", 20]]
const NICKNAMES := ["Клык", "Шрам", "Гроза троп", "Седая Грива", "Пепел", "Тихоступ", "Железный Зуб", "Одноглаз", "Бешеный Рык", "Ночная Тень", "Костолом", "Хромая Беда"]

var game: SkywardGame
var rng := RandomNumberGenerator.new()
var offers: Array = []
## The taken bounty: {name, kind, region, position, elite, mighty, gold, xp, done}.
var active: Dictionary = {}
var finished: int = 0
var _serial: int = 0

func _init(owner_game: SkywardGame) -> void:
	game = owner_game
	rng.randomize()

func level() -> int:
	return game.settlement.building_level(BUILDING)

func rank() -> int:
	var result := 0
	for index in RANKS.size():
		if finished >= int(RANKS[index][1]):
			result = index
	return result

func rank_name() -> String:
	return str(RANKS[rank()][0])

func reward_mult() -> float:
	return 1.0 + 0.1 * rank()

func _targets() -> Array:
	var result: Array = []
	for region_id in game.visited_regions:
		if RegionCatalog.is_underground(RegionCatalog.style(str(region_id))) or str(region_id) == game.settlement.village_region():
			continue
		var kinds := {}
		for entry in RegionCatalog.get_region(str(region_id)).get("enemies", []):
			var kind := str(entry.get("kind", ""))
			if entry.has("quest") or entry.has("requires_state") or kind in SkywardGame.STORY_BOSSES or kind in ["guardian", "ore_golem"] or not EliteModifiers.can_be_elite(kind):
				continue
			kinds[kind] = true
		for kind in kinds:
			result.append([str(region_id), kind])
	return result

func make_offer(mighty: bool = false) -> Dictionary:
	var targets := _targets()
	if targets.is_empty():
		return {}
	var pick: Array = targets[rng.randi_range(0, targets.size() - 1)]
	var region_id := str(pick[0])
	var kind := str(pick[1])
	var kind_name := str(game.bestiary_entries.get(kind, {}).get("name", kind))
	var region_level := maxi(1, RegionCatalog.level(region_id))
	_serial += 1
	return {
		"id": "b%d" % _serial,
		"name": "%s «%s»" % [kind_name, NICKNAMES[rng.randi_range(0, NICKNAMES.size() - 1)]],
		"kind": kind, "region": region_id, "mighty": mighty,
		"elite": EliteModifiers.pick(rng),
		"gold": (90 + 35 * region_level) * (2 if mighty else 1),
		"xp": (70 + 45 * region_level) * (2 if mighty else 1),
		"position": [], "done": false,
	}

func fill_offers() -> void:
	var tries := 0
	while offers.size() < 3 and tries < 20:
		tries += 1
		var offer := make_offer(level() >= 2 and offers.size() == 2)
		if offer.is_empty():
			return
		if offers.any(func(o: Dictionary) -> bool: return o["region"] == offer["region"] and o["kind"] == offer["kind"]):
			continue
		offers.append(offer)

func talk() -> void:
	var lines := "Ранг: %s · охот завершено: %d · награды +%d%%." % [rank_name(), finished, roundi((reward_mult() - 1.0) * 100.0)]
	var choices: Array[Dictionary] = []
	if not active.is_empty():
		if bool(active.get("done", false)):
			choices.append({"id": "guild_turnin", "label": "Сдать охоту: %s → %d золота, %d опыта" % [active["name"], roundi(active["gold"] * reward_mult()), roundi(active["xp"] * reward_mult())]})
		else:
			lines += "\nТекущая охота: %s (%s)." % [active["name"], RegionCatalog.display_name(str(active["region"]))]
			choices.append({"id": "guild_drop", "label": "Отказаться от охоты"})
	else:
		fill_offers()
		if offers.is_empty():
			lines += "\nПобывайте в других землях — там найдётся работа."
		for index in offers.size():
			var offer: Dictionary = offers[index]
			choices.append({"id": "guild_take:%d" % index, "label": "%s%s — %s · %d золота" % ["☠ ГРОЗА: " if bool(offer["mighty"]) else "", offer["name"], RegionCatalog.display_name(str(offer["region"])), roundi(offer["gold"] * reward_mult())]})
	if game.expeditions != null:
		lines += "\nЭкспедиций в хранилище Узора: %d." % game.expeditions.completed
		choices.append({"id": "guild_expedition", "label": "Экспедиция в хранилище Узора (тайная тропа, ур. %d)" % maxi(1, game.player.level)})
	choices.append({"id": "guild_close", "label": "Уйти"})
	game._show_dialogue_choices("Рагна, глава гильдии", lines, choices)

func take(index: int) -> bool:
	if not active.is_empty() or index < 0 or index >= offers.size():
		return false
	active = offers[index]
	offers.remove_at(index)
	var spot: Array = game.treasure._spot(str(active["region"]))
	active["position"] = spot
	game.hud.show_message("Охота взята: %s в землях «%s». Цель отмечена на карте." % [active["name"], RegionCatalog.display_name(str(active["region"]))], 4.0)
	if game.current_region == str(active["region"]):
		spawn_target()
	game.request_autosave()
	return true

## The named monster waits in its land while the bounty is open.
func spawn_target() -> void:
	if active.is_empty() or bool(active.get("done", false)) or game.current_region != str(active["region"]):
		return
	for node in game.get_children():
		if node is SlimeEnemy and node.has_meta("bounty"):
			return
	var pos: Array = active["position"]
	var at := Vector2(float(pos[0]), float(pos[1]))
	var enemy := game.spawn_enemy(str(active["kind"]), at, str(active.get("elite", "")))
	if enemy == null:
		return
	enemy.set_meta("bounty", str(active["id"]))
	var gap := maxi(0, game.player.level - RegionCatalog.level(game.current_region))
	var might := (2.0 if bool(active["mighty"]) else 1.0) * (2.2 + 0.15 * gap)
	enemy.max_health = roundi(enemy.max_health * might)
	enemy.health = enemy.max_health
	enemy.attack_damage = roundi(enemy.attack_damage * (1.3 + 0.06 * gap) * (1.3 if bool(active["mighty"]) else 1.0))
	enemy.xp_reward *= 3
	enemy.visual.scale *= 1.3
	enemy.combat_feedback.elite = true
	enemy.combat_feedback.elite_name = "☠ " + str(active["name"])
	enemy.combat_feedback.elite_color = Color(1.0, 0.4, 0.3)
	enemy.combat_feedback.set_health(enemy.health, enemy.max_health)
	enemy.defeated.connect(func(_xp: int) -> void: _on_target_down(enemy.global_position))

func _on_target_down(at: Vector2) -> void:
	if active.is_empty():
		return
	active["done"] = true
	game.hud.show_title_card("Охота выполнена!", 2.2)
	game.hud.show_message("%s повержен. Вернитесь к Рагне за наградой." % str(active["name"]), 3.5)
	if bool(active["mighty"]):
		game.spawn_generated_loot(at + Vector2(0, 14), "epic")
	GameAudio.play("quest", -4.0, 0.0)
	game.request_autosave()

func turn_in() -> bool:
	if active.is_empty() or not bool(active.get("done", false)):
		return false
	var before := rank()
	var trophy := ""
	if bool(active.get("mighty", false)):
		var left: Array = TROPHIES.filter(func(id: String) -> bool: return not game.player.inventory.has(id) and not game.player.wears_base(id))
		if not left.is_empty():
			trophy = str(left[randi() % left.size()])
			game.player.add_item(trophy, 1)
	game.player.add_gold(roundi(active["gold"] * reward_mult()))
	game.player.add_experience(roundi(active["xp"] * reward_mult()))
	finished += 1
	active = {}
	game.achievements.add("bounties")
	game.achievements.set_max("guild_rank", rank())
	if rank() >= 4 and before < 4:
		game.player.add_item("phoenix_feather", 1)
		game.hud.show_message("Рагна: «Золотой ранг — держи Перо феникса. Оно спасало меня трижды».", 4.0)
	if not trophy.is_empty():
		game.hud.show_message("Трофей «Грозы»: %s!" % game.player.get_item_name(trophy), 4.0)
	if rank() > before:
		game.hud.show_title_card("Ранг гильдии: %s" % rank_name(), 2.5)
	else:
		game.hud.show_message("Награда получена. Охот завершено: %d." % finished, 3.0)
	GameAudio.play("chest", -3.0, 0.0)
	game.request_autosave()
	return true

func handle_choice(choice_id: String) -> bool:
	if choice_id == "guild_close":
		game.dialogues._close()
		return true
	if choice_id.begins_with("guild_take:"):
		game.dialogues._close()
		take(int(choice_id.trim_prefix("guild_take:")))
		return true
	if choice_id == "guild_expedition":
		game.dialogues._close()
		game.expeditions.start()
		return true
	if choice_id == "guild_turnin":
		game.dialogues._close()
		turn_in()
		return true
	if choice_id == "guild_drop":
		active = {}
		game.dialogues._close()
		for node in game.get_children():
			if node is SlimeEnemy and node.has_meta("bounty"):
				node.queue_free()
		return true
	return false

## Targets for the quest navigator.
func targets() -> Array:
	if active.is_empty():
		return []
	if bool(active.get("done", false)):
		var at := SkywardGame._vec(game.settlement.building_info(BUILDING).get("position")) + Vector2(30, 16)
		return [{"region": game.settlement.village_region(), "position": at, "kind": "turnin", "title": "Гильдия"}]
	var pos: Array = active["position"]
	return [{"region": str(active["region"]), "position": Vector2(float(pos[0]), float(pos[1])), "kind": "side", "title": str(active["name"])}]

func make_snapshot() -> Dictionary:
	return {"offers": offers.duplicate(true), "active": active.duplicate(true), "finished": finished, "serial": _serial}

func restore_snapshot(data: Variant) -> void:
	if not data is Dictionary:
		return
	offers = (data.get("offers", []) as Array).duplicate(true) if data.get("offers", []) is Array else []
	active = (data.get("active", {}) as Dictionary).duplicate(true) if data.get("active", {}) is Dictionary else {}
	finished = int(data.get("finished", 0))
	_serial = int(data.get("serial", 0))
