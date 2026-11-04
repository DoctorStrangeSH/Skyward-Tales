extends Node
class_name Achievements

## Achievements (data/achievements.json): counters for kills, bosses,
## legends, fish, treasures, contracts, chests, crafts, lands, level, gold
## and the finale. Reaching a goal shows a banner and pays gold. The journal
## has a page with every achievement and its progress.

signal unlocked(achievement_id: String)

const PATH := "res://data/achievements.json"

var game: SkywardGame
var data: Dictionary = {}
var stats: Dictionary = {}
var done: Dictionary = {}

func _ready() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed.get("achievements", {})

func add(stat: String, amount: int = 1) -> void:
	stats[stat] = int(stats.get(stat, 0)) + amount
	_check()

## For values that only grow (level, lands, gold on hand).
func set_max(stat: String, value: int) -> void:
	if value > int(stats.get(stat, 0)):
		stats[stat] = value
		_check()

func progress(achievement_id: String) -> int:
	var info: Dictionary = data.get(achievement_id, {})
	return mini(int(stats.get(str(info.get("stat", "")), 0)), int(info.get("goal", 1)))

func _check() -> void:
	for achievement_id in data:
		if done.has(achievement_id):
			continue
		var info: Dictionary = data[achievement_id]
		if int(stats.get(str(info.get("stat", "")), 0)) >= int(info.get("goal", 1)):
			done[achievement_id] = true
			var gold := int(info.get("gold", 0))
			if gold > 0 and game != null and game.player != null:
				game.player.add_gold(gold)
			if game != null and game.hud != null:
				game.hud.show_title_card("Достижение: " + str(info.get("title", "")), 2.5)
				game.hud.show_message("%s%s" % [str(info.get("description", "")), ("  +%d золота" % gold) if gold > 0 else ""], 3.5)
				GameAudio.play("level_up", -6.0, 0.0)
			unlocked.emit(str(achievement_id))

## Rows for the journal page.
func entries() -> Array:
	var rows: Array = []
	for achievement_id in data:
		var info: Dictionary = data[achievement_id]
		rows.append({"id": achievement_id, "title": str(info.get("title", "")), "description": str(info.get("description", "")),
			"progress": progress(str(achievement_id)), "goal": int(info.get("goal", 1)), "done": done.has(achievement_id), "gold": int(info.get("gold", 0))})
	return rows

func make_snapshot() -> Dictionary:
	return {"stats": stats.duplicate(), "done": done.duplicate()}

func restore_snapshot(value: Variant) -> void:
	if not value is Dictionary:
		return
	stats = (value.get("stats", {}) as Dictionary).duplicate() if value.get("stats", {}) is Dictionary else {}
	done = (value.get("done", {}) as Dictionary).duplicate() if value.get("done", {}) is Dictionary else {}
