extends RefCounted
class_name IslandFates

## Этап 17 «Судьба островов». The support crystals of Небесный остров,
## Ветреные шпили и Расколотый остров are fading (after Vail's truth). At each
## the hero decides, for good:
##   restore — the island blooms (gentler foes, a healing light), the Keepers
##             cheer, the Roots grumble;
##   take    — the power is yours (gold, starlight, a fine item), the island
##             dims and its foes grow fierce; the Captains approve;
##   harmony — the third way: sing the last line of the Song of the Pattern
##             (from Vesta in Haven) — the crystal learns to hold itself;
##             everyone respects it a little.
## The quest "fate_islands" counts the decisions.

const QUEST := "fate_islands"
const REQUIRES := "main_vail"
const SONG := "haven_songs"
const ISLANDS := ["sky_island", "wind_spires", "sky_rift"]

var game: SkywardGame
var fates: Dictionary = {}
var _crystal: IslandCrystal
var _overlay: WeatherOverlay
var _aura_clock: float = 0.0

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

func unlocked() -> bool:
	return game.quests.is_completed(REQUIRES)

func fate(region_id: String) -> String:
	return str(fates.get(region_id, ""))

func power_mult(region_id: String) -> float:
	match fate(region_id):
		"restore":
			return 0.85
		"take":
			return 1.2
	return 1.0

func decided() -> int:
	return fates.size()

func populate() -> void:
	_crystal = null
	_overlay = null
	var spot: Variant = RegionCatalog.get_region(game.current_region).get("fate_crystal", null)
	if not spot is Array:
		return
	_crystal = IslandCrystal.new()
	_crystal.state = fate(game.current_region)
	game.add_child(_crystal)
	_crystal.global_position = Vector2(float(spot[0]), float(spot[1]))
	_crystal.used.connect(_on_crystal)
	match fate(game.current_region):
		"restore":
			_overlay = WeatherOverlay.new()
			_overlay.mode = "bloom"
		"take":
			_overlay = WeatherOverlay.new()
			_overlay.mode = "dim"
	if _overlay != null:
		game.add_child(_overlay)

## A healing (restore) or mana (harmony) light around a decided crystal.
func tick(delta: float) -> void:
	if _crystal == null or not is_instance_valid(_crystal):
		return
	_aura_clock -= delta
	if _aura_clock > 0.0:
		return
	_aura_clock = 2.0
	if game.player.global_position.distance_to(_crystal.global_position) > 90.0:
		return
	match _crystal.state:
		"restore":
			if game.player.health < game.player.max_health:
				game.player.health = mini(game.player.max_health, game.player.health + maxi(3, game.player.max_health / 20))
				game.player.stats_changed.emit()
		"harmony":
			game.player.mana = mini(game.player.max_mana, game.player.mana + maxi(3, game.player.max_mana / 12))
			game.player.stats_changed.emit()

func _on_crystal() -> void:
	var region := game.current_region
	if not fate(region).is_empty():
		game._show_dialogue("Кристалл острова", {
			"restore": "Кристалл горит ровно и тепло. Остров дышит — Хранители не зря тебе доверились.",
			"take": "Кристалл треснул и потемнел. Остров держится — пока. Сила теперь у тебя.",
			"harmony": "Кристалл тихо поёт Песню Узора — сам себе. Он больше никому не принадлежит.",
		}[fate(region)])
		return
	if not unlocked():
		game._show_dialogue("Кристалл острова", "Кристалл мерцает и гаснет. Ты чувствуешь: он держит остров из последних сил. Что с этим делать, ты поймёшь, когда узнаешь правду об опорах неба.")
		return
	if not game.quests.is_active(QUEST) and not game.quests.is_completed(QUEST):
		game.quests.start_quest(QUEST)
		game.quests.states[QUEST]["progress"] = decided()
	var choices: Array[Dictionary] = [
		{"id": "fate_restore", "label": "Восстановить кристалл (Хранители +, Корни −)"},
		{"id": "fate_take", "label": "Забрать силу кристалла (Капитаны +, Хранители −)"},
	]
	if game.quests.is_completed(SONG):
		choices.append({"id": "fate_harmony", "label": "Третий путь: спеть Песню Узора (все +)"})
	else:
		choices.append({"id": "fate_later", "label": "Третий путь… (нужна Песня Узора от сказительницы Весты)"})
	choices.append({"id": "fate_later", "label": "Подумать ещё"})
	game._show_dialogue_choices("Кристалл острова", "Кристалл-опора гаснет. Вейл говорил: каждая опора — это Хранитель, державший небо собой. Решение будет навсегда.", choices)

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("fate_"):
		return false
	if choice_id == "fate_later":
		game.hud.close_dialogue()
		game.player.set_physics_process(true)
		return true
	decide(game.current_region, choice_id.trim_prefix("fate_"))
	return true

func decide(region_id: String, choice: String) -> bool:
	if not region_id in ISLANDS or not fate(region_id).is_empty() or not choice in ["restore", "take", "harmony"]:
		return false
	if choice == "harmony" and not game.quests.is_completed(SONG):
		return false
	fates[region_id] = choice
	var f := game.factions
	var at := _crystal.global_position + Vector2(0, 20) if _crystal != null and is_instance_valid(_crystal) else game.player.global_position
	var line := ""
	match choice:
		"restore":
			f.add_rep("keepers", 20)
			f.add_rep("roots", -10)
			line = "Ты кладёшь ладонь на кристалл — печать отзывается светом. Нити Узора натягиваются, и остров вздыхает с облегчением."
		"take":
			f.add_rep("captains", 20)
			f.add_rep("keepers", -15)
			game._spawn_loot(at, "gold").amount = 500
			game._spawn_loot(at + Vector2(-16, 6), "starlight_essence").amount = 2
			game.spawn_generated_loot(at + Vector2(16, 6), "epic")
			line = "Сила кристалла течёт в твои руки. Он трескается, свет уходит… Остров дрожит, но держится. Пока."
		"harmony":
			f.add_rep("keepers", 8)
			f.add_rep("captains", 8)
			f.add_rep("roots", 12)
			game._spawn_loot(at, VillageBuildings.TOME)
			line = "«…и небо держит тех, кто держит друг друга». Кристалл подхватывает песню — и больше не гаснет. Ему не нужен Хранитель: он держит себя сам."
	game.achievements.add("island_fates")
	if game.quests.is_active(QUEST):
		game.quests.states[QUEST]["progress"] = decided()
		if decided() >= ISLANDS.size():
			game.quests.complete_quest(QUEST)
			game.npc_reward(QUEST)
	game._show_dialogue("Судьба острова", line)
	game.hud.show_title_card("Судьба острова: %s" % {"restore": "восстановлен", "take": "сила забрана", "harmony": "третий путь"}[choice], 2.5)
	# Rebuild the island's look.
	if region_id == game.current_region and _crystal != null and is_instance_valid(_crystal):
		_crystal.state = choice
		if _overlay != null and is_instance_valid(_overlay):
			_overlay.queue_free()
		_overlay = null
		if choice != "harmony":
			_overlay = WeatherOverlay.new()
			_overlay.mode = "bloom" if choice == "restore" else "dim"
			game.add_child(_overlay)
	game.request_autosave()
	return true

func targets() -> Array:
	if not unlocked() or decided() >= ISLANDS.size() or not game.quests.is_active(QUEST):
		return []
	var result: Array = []
	for region_id in ISLANDS:
		if fate(region_id).is_empty():
			var spot: Array = RegionCatalog.get_region(region_id).get("fate_crystal", [0, 0])
			result.append({"region": region_id, "position": Vector2(float(spot[0]), float(spot[1])), "kind": "side", "title": "Кристалл-опора"})
	return result

func make_snapshot() -> Dictionary:
	return {"fates": fates.duplicate()}

func restore_snapshot(value: Variant) -> void:
	fates = {}
	if value is Dictionary and value.get("fates", {}) is Dictionary:
		fates = (value.get("fates", {}) as Dictionary).duplicate()
