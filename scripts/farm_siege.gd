extends Node
class_name FarmSiege

## Этап 24: a defence errand. Gavrila's barn is besieged: three waves come
## from the fields and go for the barn, not the hero (they are "taunted" by
## it, like by a companion's war cry). The barn has health; if it falls, the
## errand waits for another try. Leaving the land calls the siege off.

const NPC := "farmer_gavrila"
const QUEST := "defense_farm"
const REGION := "greenreach"
const BARN := Vector2(1190, 836)
## (a granary of crates and sheaves next to Gavrila, drawn by SiegeBarn)
const BARN_HEALTH := 260
const WAVES := [
	["slime", "slime", "slime", "slime"],
	["wolf", "wolf", "slime", "slime", "wolf"],
	["wolf", "wolf", "wolf", "shaman", "wolf@"],
]
## Directions the waves come from (the fields, the forest, the road).
const FROM := [Vector2(-1, -0.3), Vector2(0.2, 1), Vector2(1, -0.6)]
const LEVEL := 4

var game: SkywardGame
var active: bool = false
var wave: int = 0
var barn: SiegeBarn
var _foes: Array = []
var _pause: float = 0.0

func available() -> bool:
	return game.quests.is_completed("moonleaf_gathering") and game.player.level >= LEVEL and not game.quests.is_completed(QUEST)

func marker(npc_id: String) -> String:
	if npc_id != NPC or active:
		return ""
	if available() and not bool(game.quests.states.get(QUEST, {}).get("started", false)):
		return "quest"
	return ""

func talk(npc_id: String) -> bool:
	if npc_id != NPC or active or not available():
		return false
	# Gavrila's own errands come first.
	if game.givers != null and game.givers.has_giver(NPC) and not game.givers.marker_for(NPC).is_empty():
		return false
	var started := bool(game.quests.states.get(QUEST, {}).get("started", false))
	var text := "Гаврила мял шапку. «Ночами из полей лезет всякая нечисть — слизни, волки, а позавчера и шаман приходил. Целят в амбар: там зерно на всю зиму. Постоишь со мной, {hero}? Три волны — и они поймут, что тут им не рады»." if not started else "«Амбар подлатал, {hero}. Попробуем ещё раз?»"
	game._show_dialogue_choices("Фермер Гаврила", StoryText.format(text), [
		{"id": "siege_start", "label": "Я готов%s — пусть идут" % ("а" if StoryText.hero_gender == "f" else "")},
		{"id": "siege_later", "label": "Чуть позже"}])
	return true

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("siege_"):
		return false
	game.dialogues._close()
	if choice_id == "siege_start":
		start()
	return true

func start() -> void:
	if not bool(game.quests.states.get(QUEST, {}).get("started", false)):
		game.quests.start_quest(QUEST)
	active = true
	wave = 0
	_spawn_barn()
	game.hud.show_title_card("Осада амбара", 2.4)
	game.hud.show_message("Враги идут к амбару, а не к вам. Не дайте им его разбить: 3 волны.", 4.0)
	_pause = 3.0

func _spawn_barn() -> void:
	if barn != null and is_instance_valid(barn):
		barn.queue_free()
	barn = SiegeBarn.new()
	barn.max_health = BARN_HEALTH
	barn.health = BARN_HEALTH
	barn.add_to_group("region_actor")
	game.add_child(barn)
	barn.global_position = BARN

func _process(delta: float) -> void:
	if not active or game.get_tree().paused:
		return
	if game.current_region != REGION:
		_fail("Вы ушли — осада снята, амбар держался сам. Поговорите с Гаврилой, чтобы попробовать снова.")
		return
	if barn == null or not is_instance_valid(barn) or barn.is_down():
		_fail("Амбар разбит! Гаврила латает стены. Поговорите с ним — попробуем ещё раз.")
		return
	_foes = _foes.filter(func(foe: Variant) -> bool: return is_instance_valid(foe) and not (foe as Node).is_queued_for_deletion() and (foe as SlimeEnemy).health > 0)
	for foe in _foes:
		# They keep going for the barn.
		foe.taunt = barn
		foe.taunt_left = 5.0
	if not _foes.is_empty():
		return
	_pause -= delta
	if _pause > 0.0:
		return
	if wave >= WAVES.size():
		_win()
		return
	_spawn_wave(wave)
	wave += 1
	_pause = 4.0

func _spawn_wave(index: int) -> void:
	var map := game.world.get_world_2d().navigation_map
	var kinds: Array = WAVES[index]
	var from: Vector2 = FROM[index % FROM.size()].normalized()
	game.hud.show_message("Волна %d из %d!" % [index + 1, WAVES.size()], 2.5)
	for i in kinds.size():
		var kind := str(kinds[i])
		var elite := ""
		if kind.ends_with("@"):
			kind = kind.trim_suffix("@")
			elite = EliteModifiers.pick(game.loot_rng)
		var spot := BARN + from.rotated(randf_range(-0.4, 0.4)) * randf_range(230.0, 290.0)
		spot = NavigationServer2D.map_get_closest_point(map, spot) if NavigationServer2D.map_get_iteration_id(map) > 0 else spot
		var foe := game.spawn_enemy(kind, spot, elite)
		if foe == null:
			continue
		foe.set_meta("siege", true)
		foe.taunt = barn
		foe.taunt_left = 5.0
		foe.detection_radius = 999.0
		foe.give_up_radius = 2000.0
		_foes.append(foe)

func _win() -> void:
	active = false
	var quest_target := int(game.quests.definitions[QUEST].get("target", 1))
	game.quests.add_progress(QUEST, quest_target)
	game.quests.complete_quest(QUEST)
	var share := int(round(barn.health * 100.0 / float(barn.max_health)))
	var bonus := 60 if share >= 75 else 0
	game.player.add_gold(160 + bonus)
	game.player.add_experience(220)
	game.player.add_item("health_potion", 2)
	game.director.set_flag("farm_defended")
	game.hud.show_title_card("Амбар устоял", 2.6)
	game._show_dialogue("Фермер Гаврила", StoryText.format("«Устоял! Ни одного зёрнышка не взяли!» Гаврила обнял тебя, пахнущего дымом и волчьей шерстью. «Держи — и приходи на ужин. Пока я жив, у тебя тут всегда будет хлеб». Амбар цел на %d%%%s." % [share, " — ещё 60 золота за то, что почти не задели" if bonus > 0 else ""]))
	if barn != null and is_instance_valid(barn):
		barn.queue_free()
	game.achievements.add("sieges")
	game.request_autosave()

func _fail(text: String) -> void:
	active = false
	for foe in _foes:
		if is_instance_valid(foe):
			(foe as Node).queue_free()
	_foes.clear()
	if barn != null and is_instance_valid(barn):
		barn.queue_free()
	barn = null
	game.hud.show_message(text, 5.0)

## On every region rebuild: the barn and foes were cleared with the land.
func populate() -> void:
	if active and game.current_region != REGION:
		_fail("Вы ушли — осада снята. Поговорите с Гаврилой, чтобы попробовать снова.")
