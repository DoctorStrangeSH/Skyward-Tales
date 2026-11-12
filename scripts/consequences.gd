extends Node
class_name Consequences

## Этап 23: decisions in errands come back later (data/consequences.json).
## When the chapter named in "after" is finished, every consequence whose
## quest was finished with that choice arrives: a few words from the one who
## remembers it, and what they give. Each comes once (saved).

const PATH := "res://data/consequences.json"

var game: SkywardGame
var entries: Array = []
var delivered: Dictionary = {}

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else {}
	entries = parsed.get("consequences", []) if parsed is Dictionary else []

func due() -> Array:
	var result: Array = []
	for entry in entries:
		var id := str(entry.get("id", ""))
		if delivered.has(id) or not game.quests.is_completed(str(entry.get("after", ""))):
			continue
		var state: Dictionary = game.quests.states.get(str(entry.get("quest", "")), {})
		if bool(state.get("completed", false)) and str(state.get("choice", "")) == str(entry.get("choice", "")):
			result.append(entry)
	return result

## Called a moment after a quest completes (and after loading).
func check() -> void:
	for entry in due():
		deliver(entry)

func deliver(entry: Dictionary) -> void:
	var id := str(entry.get("id", ""))
	if delivered.has(id):
		return
	delivered[id] = true
	var hero := game.player
	var items: Dictionary = entry.get("items", {})
	for item in items:
		hero.add_item(str(item), int(items[item]))
	if int(entry.get("gold", 0)) > 0:
		hero.add_gold(int(entry["gold"]))
	if int(entry.get("xp", 0)) > 0:
		hero.add_experience(int(entry["xp"]))
	var skill := str(entry.get("learn", ""))
	if not skill.is_empty() and not hero.knows(skill):
		hero.learn_skill(skill)
	game.hud.show_title_card("Отголосок вашего решения", 2.6)
	game.hud.show_message("%s" % StoryText.format(str(entry.get("text", ""))), 7.0)
	GameAudio.play("quest", -6.0, 0.1)
	game.request_autosave()

func make_snapshot() -> Dictionary:
	return {"delivered": delivered.keys()}

func restore_snapshot(value: Variant) -> void:
	delivered.clear()
	var data: Dictionary = value if value is Dictionary else {}
	for id in data.get("delivered", []):
		delivered[str(id)] = true
