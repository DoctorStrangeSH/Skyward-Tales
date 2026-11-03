extends RefCounted
class_name NpcRelationships

const DATA_PATH := "res://data/npc_relationships.json"
const MIN_SCORE := -100
const MAX_SCORE := 100

var definitions: Dictionary = {}
var scores: Dictionary = {}

func _init() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть data/npc_relationships.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("data/npc_relationships.json должен содержать объект")
		return
	var entries: Variant = parsed.get("npcs", {})
	if not entries is Dictionary:
		push_error("Список NPC в npc_relationships.json должен быть объектом")
		return
	definitions = entries.duplicate(true)
	for npc_id in definitions:
		var definition: Variant = definitions[npc_id]
		if definition is Dictionary:
			scores[str(npc_id)] = clampi(int(definition.get("starting_score", 0)), MIN_SCORE, MAX_SCORE)

func has_npc(npc_id: String) -> bool:
	return definitions.has(npc_id) and scores.has(npc_id)

func adjust(npc_id: String, amount: int) -> int:
	if not has_npc(npc_id):
		return 0
	var previous := int(scores[npc_id])
	scores[npc_id] = clampi(previous + amount, MIN_SCORE, MAX_SCORE)
	return int(scores[npc_id]) - previous

func get_score(npc_id: String) -> int:
	return int(scores.get(npc_id, 0))

func get_name(npc_id: String) -> String:
	if not has_npc(npc_id):
		return npc_id
	return str(definitions[npc_id].get("name", npc_id))

func get_rank(npc_id: String) -> String:
	var score := get_score(npc_id)
	if score <= -50:
		return "Враждебность"
	if score <= -20:
		return "Недоверие"
	if score >= 80:
		return "Доверенное лицо"
	if score >= 50:
		return "Друг"
	if score >= 20:
		return "Знакомый"
	return "Незнакомец"

func get_reaction(npc_id: String) -> String:
	var rank := get_rank(npc_id)
	match rank:
		"Враждебность":
			return "Я помню твои поступки и не желаю тебе доверять"
		"Недоверие":
			return "Мне ещё трудно тебе доверять"
		"Знакомый":
			return "Мы уже немного узнали друг друга"
		"Друг":
			return "Я рад видеть тебя, друг"
		"Доверенное лицо":
			return "Тебе я могу доверить даже самые важные тайны"
		_:
			return "Пока мы едва знакомы"

func make_snapshot() -> Dictionary:
	return scores.duplicate(true)

func restore_snapshot(snapshot: Variant) -> void:
	# Unknown NPC IDs and malformed values are ignored; old saves use defaults.
	if not snapshot is Dictionary:
		return
	for npc_id in definitions:
		if snapshot.has(npc_id):
			var value: Variant = snapshot[npc_id]
			if value is int or value is float:
				scores[npc_id] = clampi(int(value), MIN_SCORE, MAX_SCORE)
