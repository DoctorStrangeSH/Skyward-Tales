extends Node
class_name EscortErrand

## Этап 24: an escort errand. Vedana the herbalist goes across the marsh to
## the old sanctuary for mist-grass; the hero walks beside her. She waits if
## the hero falls behind, stops when attacked (twice on the way foes come
## for her, not for the hero) and goes on once they are gone. If she falls,
## she is carried back home and the errand waits for another try; leaving
## the land calls it off.

const NPC := "herbalist"
const QUEST := "escort_vedana"
const REGION := "misty_marsh"
const FROM := Vector2(420, 250)
const TO := Vector2(894, 640)
const HEALTH := 140
const SPEED := 36.0
## How far the hero may fall behind before she waits.
const LEASH := 150.0
## Ambushes: where on the way (share of the path) and who comes.
const AMBUSHES := [[0.35, ["toad", "toad", "wolf"]], [0.75, ["wolf", "wolf", "toad", "toad@"]]]
const LEVEL := 9

var game: SkywardGame
var active: bool = false
var walker: EscortWalker
var _route: Array = []
var _length: float = 0.0
var _next_ambush: int = 0
var _foes: Array = []
var _waiting: bool = false

func available() -> bool:
	return game.player.level >= LEVEL and game.quests.is_completed("marsh_lanterns") and not game.quests.is_completed(QUEST)

func marker(npc_id: String) -> String:
	if npc_id != NPC or active:
		return ""
	return "quest" if available() and not bool(game.quests.states.get(QUEST, {}).get("started", false)) else ""

func talk(npc_id: String) -> bool:
	if npc_id != NPC or active or not available():
		return false
	if game.givers != null and game.givers.has_giver(NPC) and not game.givers.marker_for(NPC).is_empty():
		return false
	var started := bool(game.quests.states.get(QUEST, {}).get("started", false))
	var text := "Ведана повязала платок потуже. «В старом святилище на юге растёт туманник — без него зимой половина Ясного Края закашляет. Одна я не дойду: жабы нынче злые, волки наглые. Проводишь, {hero}? Я иду медленно, ты не убегай вперёд»." if not started else "«Отлежалась, {hero}. Попробуем ещё раз? Только теперь держись ближе»."
	game._show_dialogue_choices("Ведана, травница", StoryText.format(text), [
		{"id": "escort_start", "label": "Пойдём вместе"},
		{"id": "escort_later", "label": "Чуть позже"}])
	return true

func handle_choice(choice_id: String) -> bool:
	if not choice_id.begins_with("escort_"):
		return false
	game.dialogues._close()
	if choice_id == "escort_start":
		start()
	return true

func _region_npc() -> WorldNpc:
	for node in game.get_children():
		if node is WorldNpc and not node is EscortWalker and (node as WorldNpc).npc_id == NPC:
			return node
	return null

func start() -> void:
	if not bool(game.quests.states.get(QUEST, {}).get("started", false)):
		game.quests.start_quest(QUEST)
	var home := _region_npc()
	if home != null:
		home.visible = false
		home.remove_from_group("interactables")
	walker = EscortWalker.new()
	# Her own figure sits behind the herb stall; on the road — a walking one.
	walker.npc_id = "vedana_walking"
	walker.look_id = "librarian"
	walker.display_name = "Ведана"
	walker.max_health = HEALTH
	walker.health = HEALTH
	walker.walk_speed = SPEED
	walker.add_to_group("region_actor")
	game.add_child(walker)
	walker.remove_from_group("interactables")
	walker.global_position = home.global_position if home != null else FROM
	var map := game.world.get_world_2d().navigation_map
	var path := NavigationServer2D.map_get_path(map, walker.global_position, TO, true) if NavigationServer2D.map_get_iteration_id(map) > 0 else PackedVector2Array()
	_route = Array(path) if path.size() >= 2 else [walker.global_position, TO]
	_length = 0.0
	for i in range(1, _route.size()):
		_length += (_route[i] as Vector2).distance_to(_route[i - 1])
	_next_ambush = 0
	_foes.clear()
	_waiting = false
	active = true
	walker.walk_path(_route.slice(1))
	walker.say("Ну, пошли. Тихо и не спеша.", 3.0)
	game.hud.show_title_card("Проводить Ведану", 2.4)
	game.hud.show_message("Держитесь рядом с Веданой — она ждёт, если вы отстанете. Враги будут целить в неё.", 4.0)

## The share of the way already behind her.
func progress() -> float:
	if walker == null or _length <= 0.0:
		return 0.0
	var left := 0.0
	var at := walker.global_position
	for point in walker._path:
		left += at.distance_to(point)
		at = point
	return clampf(1.0 - left / _length, 0.0, 1.0)

func _process(_delta: float) -> void:
	if not active or game.get_tree().paused:
		return
	if game.current_region != REGION:
		_fail("Вы ушли — Ведана вернулась домой. Поговорите с ней, чтобы попробовать снова.")
		return
	if walker == null or not is_instance_valid(walker) or walker.is_down():
		_fail("Ведану ранили! Её унесли домой отлежаться. Поговорите с ней — попробуем ещё раз.")
		return
	_foes = _foes.filter(func(foe: Variant) -> bool: return is_instance_valid(foe) and not (foe as Node).is_queued_for_deletion() and (foe as SlimeEnemy).health > 0)
	for foe in _foes:
		foe.taunt = walker
		foe.taunt_left = 5.0
	if _next_ambush < AMBUSHES.size() and progress() >= float(AMBUSHES[_next_ambush][0]):
		_ambush(AMBUSHES[_next_ambush][1])
		_next_ambush += 1
	var far := walker.global_position.distance_to(game.player.global_position) > LEASH
	var hold := far or not _foes.is_empty()
	if hold != _waiting:
		_waiting = hold
		walker.walk_speed = 0.0 if hold else SPEED
		if walker.visual != null:
			walker.visual.set_moving(not hold)
		if far and _foes.is_empty():
			walker.say(StoryText.format("Подожди меня, {hero}!"), 2.5)
	if not walker.is_walking() and _foes.is_empty():
		_win()

func _ambush(kinds: Array) -> void:
	game.hud.show_message("Засада! Защитите Ведану.", 2.5)
	walker.say("Ой! Они идут на меня!", 2.5)
	var map := game.world.get_world_2d().navigation_map
	for i in kinds.size():
		var kind := str(kinds[i])
		var elite := ""
		if kind.ends_with("@"):
			kind = kind.trim_suffix("@")
			elite = EliteModifiers.pick(game.loot_rng)
		var spot := walker.global_position + Vector2.RIGHT.rotated(TAU * float(i) / float(kinds.size()) + randf() * 0.6) * randf_range(170.0, 220.0)
		spot = NavigationServer2D.map_get_closest_point(map, spot) if NavigationServer2D.map_get_iteration_id(map) > 0 else spot
		var foe := game.spawn_enemy(kind, spot, elite)
		if foe == null:
			continue
		foe.set_meta("escort", true)
		foe.taunt = walker
		foe.taunt_left = 5.0
		foe.detection_radius = 999.0
		foe.give_up_radius = 2000.0
		_foes.append(foe)

func _win() -> void:
	active = false
	var target := int(game.quests.definitions[QUEST].get("target", 1))
	game.quests.add_progress(QUEST, target)
	game.quests.complete_quest(QUEST)
	var share := int(round(walker.health * 100.0 / float(walker.max_health)))
	var bonus := 50 if share >= 70 else 0
	game.player.add_gold(140 + bonus)
	game.player.add_experience(320)
	game.player.add_item("mana_potion", 2)
	game.player.add_item("health_potion", 2)
	game.director.set_flag("vedana_escorted")
	game.achievements.add("escorts")
	game.hud.show_title_card("Ведана дошла", 2.6)
	game._show_dialogue("Ведана, травница", StoryText.format("Ведана опустилась на колени у старого камня и бережно, как котёнка, подняла пучок серебристой травы. «Туманник! Целая поляна!» Она сунула тебе флаконы. «Держи. И знай: пока у меня есть травы, у тебя будет и лечение — бесплатно»%s." % (" — и ещё 50 золота за то, что меня почти не задели" if bonus > 0 else "")))
	walker.queue_free()
	walker = null
	var home := _region_npc()
	if home != null:
		home.visible = true
		home.add_to_group("interactables")
	game.request_autosave()

func _fail(text: String) -> void:
	active = false
	for foe in _foes:
		if is_instance_valid(foe):
			(foe as Node).queue_free()
	_foes.clear()
	if walker != null and is_instance_valid(walker):
		walker.queue_free()
	walker = null
	var home := _region_npc()
	if home != null:
		home.visible = true
		home.add_to_group("interactables")
	game.hud.show_message(text, 5.0)

func populate() -> void:
	if active and game.current_region != REGION:
		_fail("Вы ушли — Ведана вернулась домой. Поговорите с ней, чтобы попробовать снова.")
