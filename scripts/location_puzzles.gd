extends Node
class_name LocationPuzzles

## Этап 24: secrets of the lands — puzzles that stand in the world and wait.
## "lights": rune stones, each touch flips the stone and its neighbours;
##   all lit — solved. (It starts from a solved state scrambled by known
##   touches, so it can always be solved.)
## "order": bells named by the sides of the world; an inscription tells the
##   order in a riddle; a wrong bell silences them all — start again.
## Solved once: a cache appears (gold, a rare find, sometimes a Book of
## Forgetting — another way to get one), flag puzzle_<id>.

const PUZZLES := {
	"pass_runes": {
		"region": "stone_pass", "kind": "lights", "title": "Руны перевала",
		"center": [738, 748], "radius": 40.0,
		"names": ["Руна Камня", "Руна Ветра", "Руна Огня", "Руна Воды", "Руна Корня"],
		# Each stone flips itself and the two next to it in the ring.
		"scramble": [0, 2],
		"hint": "На плите выбито: «Пять рун уснули. Тронь одну — проснутся и соседи. Разбуди всех разом — и камень откроет то, что хранит».",
		"reward": {"gold": 220, "rarity": "epic"},
	},
	"spire_bells": {
		"region": "wind_spires", "kind": "order", "title": "Колокола Шпилей",
		"center": [320, 590], "radius": 56.0,
		"names": ["Поющий кристалл Севера", "Поющий кристалл Востока", "Поющий кристалл Юга", "Поющий кристалл Запада"],
		"order": [1, 2, 3, 0],
		"hint": "Под колоколами надпись: «Солнце встаёт, солнце стоит высоко, солнце уходит — а ночью звёзды глядят в полночь. Звони так, как ходит свет».",
		"reward": {"gold": 260, "rarity": "rare", "items": {"tome_of_forgetting": 1}},
	},
}

var game: SkywardGame
## {puzzle id: {"lit": [bool…]} or {"step": int}} — progress of unsolved ones.
var state: Dictionary = {}

func solved(id: String) -> bool:
	return game.director.has_flag("puzzle_" + id)

func _state(id: String) -> Dictionary:
	if not state.has(id):
		var info: Dictionary = PUZZLES[id]
		var count: int = (info["names"] as Array).size()
		if str(info["kind"]) == "lights":
			var lit: Array = []
			for i in count:
				lit.append(true)
			for touch in info.get("scramble", []):
				_flip(lit, int(touch))
			state[id] = {"lit": lit}
		else:
			state[id] = {"step": 0}
	return state[id]

static func _flip(lit: Array, index: int) -> void:
	var count := lit.size()
	for i in [index - 1, index, index + 1]:
		var at := posmod(int(i), count)
		lit[at] = not bool(lit[at])

## Touches a piece; true when that solved the puzzle.
func touch(id: String, index: int) -> bool:
	if solved(id) or not PUZZLES.has(id):
		return false
	var info: Dictionary = PUZZLES[id]
	var current := _state(id)
	if str(info["kind"]) == "lights":
		_flip(current["lit"], index)
		GameAudio.play("ui", -4.0, 0.2)
		if not (current["lit"] as Array).has(false):
			_solve(id)
			return true
	else:
		var order: Array = info["order"]
		var step := int(current["step"])
		if int(order[step]) == index:
			current["step"] = step + 1
			GameAudio.play("quest", -8.0, 0.1 + 0.05 * step)
			if int(current["step"]) >= order.size():
				_solve(id)
				return true
		else:
			current["step"] = 0
			GameAudio.play("hit", -6.0, 0.1)
			game.hud.show_message("Колокола смолкли. Начните сначала.", 2.0)
	_refresh(id)
	return false

func _solve(id: String) -> void:
	var info: Dictionary = PUZZLES[id]
	state.erase(id)
	game.director.set_flag("puzzle_" + id)
	game.achievements.add("puzzles")
	var reward: Dictionary = info.get("reward", {})
	var center := SkywardGame._vec(info["center"])
	game.player.add_gold(int(reward.get("gold", 0)))
	game.player.add_experience(180 + 12 * game.player.level)
	var items: Dictionary = reward.get("items", {})
	for item in items:
		game.player.add_item(str(item), int(items[item]))
	game.spawn_generated_loot(center + Vector2(0, 8), str(reward.get("rarity", "rare")), "puzzle")
	game.hud.show_title_card("Тайна раскрыта: %s" % str(info["title"]), 2.6)
	game.hud.show_message("Камень в середине отошёл: +%d золота%s." % [int(reward.get("gold", 0)), " и Книга Забвения" if items.has("tome_of_forgetting") else ""], 4.5)
	GameAudio.play("level_up", -4.0, 0.0)
	game._ring(center, 90.0, Color(1.0, 0.9, 0.5))
	populate()
	game.request_autosave()

# --- In the world --------------------------------------------------------------

func _piece_position(info: Dictionary, index: int) -> Vector2:
	var count: int = (info["names"] as Array).size()
	var angle := -PI / 2.0 + TAU * float(index) / float(count)
	if str(info["kind"]) == "order":
		# Bells by the sides of the world: north, east, south, west.
		angle = [-PI / 2.0, 0.0, PI / 2.0, PI][index]
	return SkywardGame._vec(info["center"]) + Vector2.RIGHT.rotated(angle) * float(info["radius"])

func populate() -> void:
	for node in get_tree().get_nodes_in_group("puzzle_piece"):
		node.queue_free()
	for id in PUZZLES:
		var info: Dictionary = PUZZLES[id]
		if str(info["region"]) != game.current_region:
			continue
		var center := SkywardGame._vec(info["center"])
		var plate := TowerObject.new()
		plate.art = "tower_crystal"
		plate.label = "" if solved(id) else "E — прочитать надпись"
		plate.add_to_group("puzzle_piece")
		game.add_child(plate)
		plate.global_position = center
		var the_id := str(id)
		plate.used.connect(func(_object: TowerObject) -> void:
			game._show_dialogue(str(PUZZLES[the_id]["title"]), str(PUZZLES[the_id]["hint"])))
		if solved(id):
			continue
		for i in (info["names"] as Array).size():
			var piece := TowerObject.new()
			piece.label = "E — %s" % str(info["names"][i])
			piece.glow = Color(0.6, 0.8, 1.0, 0.5)
			piece.set_meta("puzzle", the_id)
			piece.set_meta("index", i)
			piece.add_to_group("puzzle_piece")
			game.add_child(piece)
			piece.global_position = _piece_position(info, i)
			var index := i
			piece.used.connect(func(_object: TowerObject) -> void: touch(the_id, index))
		_refresh(the_id)

## Lit stones glow; bells already rung in the right order glow.
func _refresh(id: String) -> void:
	if solved(id):
		return
	var info: Dictionary = PUZZLES[id]
	var current := _state(id)
	for node in get_tree().get_nodes_in_group("puzzle_piece"):
		if not node.has_meta("puzzle") or str(node.get_meta("puzzle")) != id or node.is_queued_for_deletion():
			continue
		var index := int(node.get_meta("index"))
		var on := false
		if str(info["kind"]) == "lights":
			on = bool(current["lit"][index])
		else:
			on = (info["order"] as Array).slice(0, int(current["step"])).has(index)
		if str(info["kind"]) == "lights":
			(node as TowerObject).set_art("lore_stone")
			(node as TowerObject).modulate = Color(1.35, 1.25, 0.8) if on else Color(0.55, 0.6, 0.7)
		else:
			(node as TowerObject).set_art("memory_crystal" if on else "echo_crystal")
			(node as TowerObject).modulate = Color(1.2, 1.1, 1.2) if on else Color(0.8, 0.85, 0.95)

func make_snapshot() -> Dictionary:
	return {"state": state.duplicate(true)}

func restore_snapshot(value: Variant) -> void:
	var saved: Dictionary = value if value is Dictionary else {}
	state = (saved.get("state", {}) as Dictionary).duplicate(true) if saved.get("state", {}) is Dictionary else {}
