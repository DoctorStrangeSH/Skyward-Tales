extends RefCounted
class_name Trainers

## Owner's list №29–30: skills and passives are learned. Trainers
## (data/trainers.json) teach for gold once the hero has the level:
##   Борин — the blade, Торен — the hunt and the bow, Илара — magic,
##   Ориэн — the old formulas, Бран — a trader's luck.
## In a story game talking to a trainer first asks: talk or learn.

var game: SkywardGame
var _handlers: Dictionary = {}

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

static func catalog() -> Dictionary:
	var file := FileAccess.open("res://data/trainers.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static var _cache: Dictionary = {}

static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = catalog()
	return _cache

func has_trainer(npc_id: String) -> bool:
	return data().has(npc_id)

## Who teaches a skill: "Борин, кузнец (Зелёные Пределы)".
static func teacher_of(skill_id: String) -> String:
	for npc_id in data():
		if (data()[npc_id].get("skills", {}) as Dictionary).has(skill_id):
			return str(data()[npc_id].get("teacher", npc_id))
	return ""

static func price_of(skill_id: String) -> int:
	for npc_id in data():
		var skills: Dictionary = data()[npc_id].get("skills", {})
		if skills.has(skill_id):
			return int(skills[skill_id])
	return 0

static func skill_data(skill_id: String) -> Dictionary:
	var catalog := PlayerCharacter.skill_catalog()
	if catalog.get("active", {}).has(skill_id):
		return catalog["active"][skill_id]
	return catalog.get("passive", {}).get(skill_id, {})

## Wraps an NPC's talk: a trainer first offers lessons.
func greet(npc_id: String, talk: Callable) -> void:
	_handlers[npc_id] = talk
	if not game.player.skills_need_learning or not has_trainer(npc_id):
		talk.call(null)
		return
	var news := not game.dialogues.marker_for(npc_id).is_empty()
	var info: Dictionary = data()[npc_id]
	var ready := _ready_lessons(npc_id)
	var choices: Array[Dictionary] = [
		{"id": "train_talk:" + npc_id, "label": "Поговорить" + ("  ❗" if news else "")},
		{"id": "train_list:" + npc_id, "label": "%s%s" % [str(info.get("title", "Учиться")), ("  (%d)" % ready) if ready > 0 else ""]},
		{"id": "train_bye", "label": "Уйти"},
	]
	game._show_dialogue_choices(_speaker(npc_id), str(info.get("greeting", "Чего тебе?")), choices)

## Lessons the hero can take right now.
func _ready_lessons(npc_id: String) -> int:
	var count := 0
	for skill_id in data()[npc_id].get("skills", {}):
		if game.player.knows(str(skill_id)) and game.player.skills_need_learning:
			continue
		if lock_reason(str(skill_id)).is_empty():
			count += 1
	return count

## Why a lesson can't be taken ("" when it can).
func lock_reason(skill_id: String) -> String:
	var info := skill_data(skill_id)
	if game.player.level < int(info.get("level", 1)):
		return "нужен ур. %d" % int(info.get("level", 1))
	if (bool(info.get("magic", false)) or bool(info.get("spell", false))) and not game.magic_unlocked():
		return "магия ещё спит"
	if game.player.gold < price_of(skill_id):
		return "не хватает золота"
	return ""

func show_lessons(npc_id: String, line: String = "") -> void:
	var info: Dictionary = data().get(npc_id, {})
	var choices: Array[Dictionary] = []
	for skill_id in info.get("skills", {}):
		var id := str(skill_id)
		var skill := skill_data(id)
		var kind := "пассивка" if PlayerCharacter.skill_catalog().get("passive", {}).has(id) else ("заклинание" if bool(skill.get("spell", false)) else "навык")
		if game.player.knows(id):
			choices.append({"id": "train_known:" + npc_id, "label": "✓ %s — изучено" % str(skill.get("name", id))})
			continue
		var reason := lock_reason(id)
		var label := "%s (%s) — %d золота" % [str(skill.get("name", id)), kind, int(info["skills"][skill_id])]
		if not reason.is_empty():
			label = "🔒 " + label + " · " + reason
		choices.append({"id": "train_learn:%s:%s" % [npc_id, id], "label": label})
	choices.append({"id": "train_talk:" + npc_id, "label": "Поговорить"})
	choices.append({"id": "train_bye", "label": "Хватит"})
	game._show_dialogue_choices(_speaker(npc_id), line if not line.is_empty() else str(info.get("line", "")), choices)

func learn(npc_id: String, skill_id: String) -> bool:
	var reason := lock_reason(skill_id)
	if game.player.knows(skill_id) or not reason.is_empty():
		show_lessons(npc_id, "Рано, %s: %s." % ["{hero}", reason] if not reason.is_empty() else "Это ты уже знаешь.")
		return false
	game.player.gold -= price_of(skill_id)
	game.player.learn_skill(skill_id)
	var skill := skill_data(skill_id)
	game.hud.show_message("Изучено: %s. %s" % [str(skill.get("name", skill_id)), "Навык на панели (1–4)." if game.player.skill_slots.has(skill_id) else ""], 3.5)
	GameAudio.play("level_up", -10.0, 0.0)
	game._refresh_hud()
	game.request_autosave()
	show_lessons(npc_id, "Запомни, как держать руку. Ещё раз — медленно. Вот так. Теперь это твоё.")
	return true

func handle_choice(choice_id: String) -> bool:
	if choice_id == "train_bye":
		_close()
		return true
	if choice_id.begins_with("train_talk:"):
		var npc_id := choice_id.trim_prefix("train_talk:")
		game.hud.close_dialogue()
		var talk: Callable = _handlers.get(npc_id, Callable())
		if talk.is_valid():
			talk.call(null)
		return true
	if choice_id.begins_with("train_list:") or choice_id.begins_with("train_known:"):
		show_lessons(choice_id.get_slice(":", 1))
		return true
	if choice_id.begins_with("train_learn:"):
		learn(choice_id.get_slice(":", 1), choice_id.get_slice(":", 2))
		return true
	return false

func _speaker(npc_id: String) -> String:
	return str(data().get(npc_id, {}).get("speaker", npc_id))

func _close() -> void:
	game.hud.close_dialogue()
	game.player.set_physics_process(true)
	game._refresh_hud()
