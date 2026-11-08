extends RefCounted
class_name StoryScene

## Plays short story scenes from data/dialogues.json: a sequence of steps
## shown in the dialogue box (E advances). Steps:
##   {"speaker": "elder"|"hero"|"" (narrator), "text": "…"}
##   {"effect": "meteor", "to": [x, y]} / {"effect": "flash"}
##   {"set_flag": "id"} — remembers a story flag;
##   {"if_flag": "id", "then": [steps], "else": [steps]} — branches (also
##     "if_quest_done": "quest_id");
##   {"speaker", "text", "choice": [{"label", "flag"?, "steps": [...]}]} — the
##     hero answers; the chosen branch plays next (E picks the first answer).
## A scene may have a "title" shown as a title card when it starts.

const DATA_PATH := "res://data/dialogues.json"
const NARRATOR := "—"

var game: SkywardGame
var speakers: Dictionary = {}
var scenes: Dictionary = {}
var active: bool = false
var scene_id: String = ""
var _steps: Array = []
var _index: int = -1
var _on_finished: Callable
## The answers of the line on screen ([] when it is a plain line).
var _choices: Array = []

func _init(owner_game: SkywardGame) -> void:
	game = owner_game
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("Нет файла сцен: " + DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		speakers = parsed.get("speakers", {})
		scenes = parsed.get("scenes", {})

func has_scene(id: String) -> bool:
	return scenes.has(id)

## A conversation with an NPC told like a scene (several windows, a
## narrator): steps may name the speaker "self" — the NPC being talked to.
func play_steps(steps: Array, self_id: String, self_name: String, on_finished: Callable = Callable()) -> bool:
	var resolved: Array = []
	for step in steps:
		if step is String:
			resolved.append({"speaker": self_id, "text": step})
			continue
		var copy: Dictionary = (step as Dictionary).duplicate(true)
		if str(copy.get("speaker", "")) == "self":
			copy["speaker"] = self_id
		resolved.append(copy)
	if not self_id.is_empty() and not speakers.has(self_id):
		speakers[self_id] = self_name
	scenes["_talk"] = {"steps": resolved}
	return play("_talk", on_finished)

func play(id: String, on_finished: Callable = Callable()) -> bool:
	if not scenes.has(id):
		push_warning("Неизвестная сцена: " + id)
		if on_finished.is_valid():
			on_finished.call()
		return false
	var scene: Dictionary = scenes[id]
	scene_id = id
	_steps = scene.get("steps", [])
	_index = -1
	_on_finished = on_finished
	active = true
	game.player.set_physics_process(false)
	if scene.has("title"):
		game.hud.show_title_card(str(scene["title"]))
	advance()
	return true

## Shows the next line (running effects on the way); ends the scene after the last.
func advance() -> void:
	if not active:
		return
	if not _choices.is_empty():
		choose(0)
		return
	_index += 1
	while _index < _steps.size():
		var step: Dictionary = _steps[_index]
		if step.has("effect"):
			_run_effect(step)
			_index += 1
			continue
		if step.has("set_flag"):
			game.director.set_flag(str(step["set_flag"]))
			_index += 1
			continue
		if step.has("if_flag") or step.has("if_quest_done"):
			var passed := game.director.has_flag(str(step["if_flag"])) if step.has("if_flag") else game.quests.is_completed(str(step["if_quest_done"]))
			var branch: Array = step.get("then" if passed else "else", [])
			_steps = _steps.slice(0, _index + 1) + branch + _steps.slice(_index + 1)
			_index += 1
			continue
		var speaker_id := str(step.get("speaker", ""))
		if step.get("choice", []) is Array and not (step.get("choice", []) as Array).is_empty():
			_choices = step["choice"]
			var options: Array[Dictionary] = []
			for i in _choices.size():
				options.append({"id": "scene_choice:%d" % i, "label": StoryText.format(str(_choices[i].get("label", "…")))})
			game.hud.show_dialogue_choices(_speaker_name(speaker_id), StoryText.format(str(step.get("text", ""))), options)
			return
		game.hud.show_scene_line(_speaker_name(speaker_id), StoryText.format(str(step.get("text", ""))), _portrait(speaker_id))
		return
	_finish()

## The hero's answer to a choice line: its branch plays next.
func choose(index: int) -> void:
	if _choices.is_empty():
		return
	var picked: Dictionary = _choices[clampi(index, 0, _choices.size() - 1)]
	_choices = []
	if picked.has("flag"):
		game.director.set_flag(str(picked["flag"]))
	var branch: Array = picked.get("steps", [])
	_steps = _steps.slice(0, _index + 1) + branch + _steps.slice(_index + 1)
	advance()

func handle_choice(choice_id: String) -> bool:
	if not active or not choice_id.begins_with("scene_choice:"):
		return false
	choose(int(choice_id.trim_prefix("scene_choice:")))
	return true

func skip() -> void:
	while active:
		advance()

func _finish() -> void:
	_choices = []
	active = false
	scene_id = ""
	game.hud.close_dialogue()
	game.player.set_physics_process(true)
	var callback := _on_finished
	_on_finished = Callable()
	if callback.is_valid():
		callback.call()

func _speaker_name(speaker_id: String) -> String:
	if speaker_id == "hero":
		return StoryText.hero_name
	if speaker_id.is_empty():
		return NARRATOR
	return str(speakers.get(speaker_id, speaker_id))

func _portrait(speaker_id: String) -> String:
	var face_id := ("hero_f" if StoryText.hero_gender == "f" else "hero_m") if speaker_id == "hero" else speaker_id
	if not face_id.is_empty() and ResourceLoader.exists("res://assets/sprites/portraits/%s.png" % face_id):
		return "sprites/portraits/%s.png" % face_id
	if speaker_id == "hero":
		return "sprites/characters/%s.png" % ("hero_f_8dir_walk" if StoryText.hero_gender == "f" else "hero_8dir_walk")
	if speaker_id.is_empty():
		return ""
	return "sprites/npcs/%s.png" % speaker_id

func _run_effect(step: Dictionary) -> void:
	match str(step.get("effect", "")):
		"meteor":
			var to: Array = step.get("to", [0, 0])
			Vfx.meteor(game, Vector2(float(to[0]), float(to[1])))
		"flash":
			game.hud.flash_screen(Color(0.8, 1.0, 1.0, 0.7), 0.5)
		"companion_join":
			game.ensure_companion()
		"title":
			game.hud.show_title_card(StoryText.format(str(step.get("text", ""))), 4.0)
