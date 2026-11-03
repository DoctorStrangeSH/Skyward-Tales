extends RefCounted
class_name StoryScene

## Plays short story scenes from data/dialogues.json: a sequence of steps
## shown in the dialogue box (E advances). Steps:
##   {"speaker": "elder"|"hero"|"" (narrator), "text": "…"}
##   {"effect": "meteor", "to": [x, y]} / {"effect": "flash"}
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
	_index += 1
	while _index < _steps.size():
		var step: Dictionary = _steps[_index]
		if step.has("effect"):
			_run_effect(step)
			_index += 1
			continue
		var speaker_id := str(step.get("speaker", ""))
		game.hud.show_scene_line(_speaker_name(speaker_id), StoryText.format(str(step.get("text", ""))), _portrait(speaker_id))
		return
	_finish()

func skip() -> void:
	while active:
		advance()

func _finish() -> void:
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
