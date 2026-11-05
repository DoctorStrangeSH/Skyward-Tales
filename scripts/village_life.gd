extends Node
class_name VillageLife

## Daily life in the village (data/routines.json):
##   morning — villagers leave their homes and go to work;
##   day     — at work (their spots from regions.json);
##   evening — they gather on the square and swap rumors in speech bubbles;
##   night   — indoors asleep ("z z" over the door, still answer a knock);
##             a guard walks the lamps instead.
## Villagers greet the hero passing by. Rumors follow the world: a rescued
## caravan, a legend roaming somewhere, open rifts.

const PATH := "res://data/routines.json"
const NPC_SCRIPT := preload("res://scripts/npc.gd")

var game: SkywardGame
var data: Dictionary = {}
var phase: String = ""
var guard: WorldNpc
var rng := RandomNumberGenerator.new()
var _chatter_clock: float = 3.0
var _greeted: Dictionary = {}
var _patrol_index: int = 0
var _clock: float = 0.0
var _last_greet: float = -999.0

func _ready() -> void:
	rng.randomize()
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed

func region() -> String:
	return str(data.get("region", "greenreach"))

static func phase_at(t: float) -> String:
	if t >= 0.84 or t < 0.25:
		return "night"
	if t < 0.34:
		return "morning"
	if t < 0.72:
		return "day"
	return "evening"

func phase_now() -> String:
	return phase_at(game.day_night.time)

func villagers() -> Array:
	var result: Array = []
	var routines: Dictionary = data.get("npcs", {})
	for node in game.get_children():
		if node is WorldNpc and not node.is_companion and not node.is_queued_for_deletion() and routines.has(node.npc_id):
			result.append(node)
	return result

func work_spot(npc_id: String) -> Vector2:
	for npc in RegionCatalog.get_region(region()).get("npcs", []):
		if str(npc.get("id", "")) == npc_id:
			return SkywardGame._vec(npc.get("position"))
	return Vector2.ZERO

func spot(npc_id: String, for_phase: String) -> Vector2:
	var routine: Dictionary = data.get("npcs", {}).get(npc_id, {})
	match for_phase:
		"evening":
			# With a tavern, evenings move to its door.
			if game.settlement.building_level(VillageBuildings.TAVERN) >= 1:
				var door := SkywardGame._vec(game.settlement.building_info(VillageBuildings.TAVERN).get("position")) + Vector2(0, 34)
				var keys: Array = data.get("npcs", {}).keys()
				var slot := keys.find(npc_id)
				return door + Vector2(-56 + slot * 26, 6 + (slot % 2) * 10)
			return SkywardGame._vec(routine.get("evening", [0, 0]))
		"night":
			return SkywardGame._vec(routine.get("home", [0, 0]))
	return work_spot(npc_id)

## Along the village lane, so nobody cuts through a house.
func route(from: Vector2, to: Vector2) -> Array:
	var lane := float(data.get("lane_y", 630))
	if absf(from.y - to.y) < 20.0:
		return [to]
	return [Vector2(from.x, lane), Vector2(to.x, lane), to]

## Called when the village is (re)built: everyone is where they should be.
func on_region_ready() -> void:
	phase = ""
	_greeted.clear()
	guard = null
	if game.current_region != region():
		return
	phase = phase_now()
	_place_all(false)

func _process(delta: float) -> void:
	if game == null or game.day_night == null or game.current_region != region() or get_tree().paused:
		return
	_clock += delta
	var now := phase_now()
	if now != phase:
		phase = now
		_place_all(true)
	_update_guard()
	_chatter(delta)
	_greet()

func _place_all(walk: bool) -> void:
	for npc in villagers():
		var target := spot(npc.npc_id, phase)
		if target == Vector2.ZERO:
			continue
		var sleep := phase == "night"
		if walk:
			npc.walk_path(route(npc.global_position, target), sleep)
		else:
			npc.stop_walking()
			npc.global_position = target
			npc.set_asleep(sleep)
	_update_guard()

func _update_guard() -> void:
	var on_duty := phase == "night"
	var alive := guard != null and is_instance_valid(guard) and not guard.is_queued_for_deletion()
	if on_duty and not alive:
		var info: Dictionary = data.get("guard", {})
		var patrol: Array = info.get("patrol", [])
		if patrol.is_empty():
			return
		guard = NPC_SCRIPT.new() as WorldNpc
		guard.npc_id = str(info.get("id", "guard"))
		guard.display_name = str(info.get("name", "Стражник"))
		guard.outfit_color = Color(0.4, 0.45, 0.6)
		guard.walk_speed = 26.0
		game.add_child(guard)
		guard.global_position = SkywardGame._vec(patrol[0])
		guard.interacted.connect(func(_source: Node2D) -> void: _guard_talk())
		_patrol_index = 0
	elif not on_duty and alive:
		guard.queue_free()
		guard = null
		return
	if on_duty and guard != null and not guard.is_walking():
		var patrol: Array = data.get("guard", {}).get("patrol", [])
		_patrol_index = (_patrol_index + 1) % patrol.size()
		guard.walk_path([SkywardGame._vec(patrol[_patrol_index])])

func _guard_talk() -> void:
	var lines: Array = data.get("guard_lines", ["Всё спокойно."])
	var line := str(lines[rng.randi_range(0, lines.size() - 1)])
	if rng.randf() < 0.5:
		line = rumor()
	game._show_dialogue(guard.display_name if guard != null else "Стражник", line)

## Rumors that follow the world, mixed with the everyday ones.
func rumor() -> String:
	var lines: Array = (data.get("rumors", []) as Array).duplicate()
	var live: Array = []
	if game.world_state.has("trade_route"):
		live.append("Караван дошёл целым! У Брана теперь заморские товары, да ещё со скидкой.")
	if game.world_state.has("caravan_lost"):
		live.append("Слыхали? Караван разграбили по дороге. Бран поднял цены…")
	for legend_id in game.legends.data:
		if not game.legends.defeated.has(legend_id):
			var info: Dictionary = game.legends.data[legend_id]
			live.append("Говорят, по ночам в землях «%s» бродит %s. Огромный, светится!" % [RegionCatalog.display_name(str(info.get("region", ""))), str(info.get("name", ""))])
			break
	var mine_news := game.mine.rumor()
	if not mine_news.is_empty():
		live.append(mine_news)
	if game.borin.upgraded():
		live.append("Видал новую кузницу Борина? Говорят, он теперь куёт из небесного металла!")
	if not game.epilogue.open_rift_regions().is_empty():
		live.append("Над землями снова трещит небо — разломы Узора. Сорен места себе не находит.")
	# Fresh news comes up more often.
	if not live.is_empty() and rng.randf() < 0.6:
		return StoryText.format(str(live[rng.randi_range(0, live.size() - 1)]))
	return StoryText.format(str(lines[rng.randi_range(0, lines.size() - 1)])) if not lines.is_empty() else ""

func _chatter(delta: float) -> void:
	if phase != "evening":
		return
	_chatter_clock -= delta
	if _chatter_clock > 0.0:
		return
	_chatter_clock = rng.randf_range(4.5, 8.0)
	var idle := villagers().filter(func(n: WorldNpc) -> bool: return not n.is_walking() and n.bubble_text.is_empty())
	if idle.is_empty():
		return
	var speaker: WorldNpc = idle[rng.randi_range(0, idle.size() - 1)]
	speaker.say(rumor(), 5.0)

func _greet() -> void:
	var hero := game.player.global_position
	var lines: Array = data.get("greetings", {}).get(phase, [])
	# One greeting at a time, not a chorus.
	if lines.is_empty() or _clock - _last_greet < 6.0:
		return
	for npc in villagers():
		if npc.asleep or npc.is_walking() or not npc.bubble_text.is_empty():
			continue
		if npc.global_position.distance_to(hero) > 46.0:
			continue
		var last := float(_greeted.get(npc.npc_id, -999.0))
		var now := _clock
		if now - last < 90.0:
			continue
		_greeted[npc.npc_id] = now
		_last_greet = now
		npc.say(StoryText.format(str(lines[rng.randi_range(0, lines.size() - 1)])), 3.0)
		return
