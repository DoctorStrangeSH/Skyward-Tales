extends RefCounted
class_name LoreBook

## The Chronicle: rune stones and plaques around the world (data/lore.json,
## region layouts list them under "lore"). Reading one adds it to the journal
## tab «Летопись». Saved in world.lore.

const DATA_PATH := "res://data/lore.json"

var entries_data: Dictionary = {}
## lore_id -> region id where it was read.
var read: Dictionary = {}

func _init() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			entries_data = parsed.get("entries", {})

func entry(lore_id: String) -> Dictionary:
	return entries_data.get(lore_id, {})

## Returns true the first time a stone is read.
func mark(lore_id: String, region_id: String) -> bool:
	if read.has(lore_id) or not entries_data.has(lore_id):
		return false
	read[lore_id] = region_id
	return true

func total() -> int:
	return entries_data.size()

## Read entries in reading order: [{id, title, text, region}].
func entries() -> Array:
	var result: Array = []
	for lore_id in read:
		var data := entry(str(lore_id))
		result.append({"id": str(lore_id), "title": str(data.get("title", "")), "text": str(data.get("text", "")), "region": str(read[lore_id])})
	return result

func make_snapshot() -> Dictionary:
	return {"read": read.duplicate()}

func restore_snapshot(snapshot: Variant) -> void:
	read = {}
	if snapshot is Dictionary and snapshot.get("read", {}) is Dictionary:
		read = (snapshot["read"] as Dictionary).duplicate()
