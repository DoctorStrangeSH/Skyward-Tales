extends RefCounted
class_name SaveSystem

const VERSION: int = 1
const SAVE_PATH: String = "user://skyward_tales_save.json"

## Owner's list №35: three save slots. Slot 1 is the old single save file,
## so saves from before keep working.
const SLOTS := 3

static func slot_path(slot: int) -> String:
	return SAVE_PATH if slot <= 1 else "user://skyward_tales_save_%d.json" % slot

## What the slot holds, for the title menu: {} when empty, else
## {slot, name, level, region, saved_at, ng, ending}.
static func slot_summary(slot: int) -> Dictionary:
	var data := load_latest(slot_path(slot))
	if data.is_empty():
		return {}
	var player: Dictionary = data.get("player", {}) if data.get("player", {}) is Dictionary else {}
	var world: Dictionary = data.get("world", {}) if data.get("world", {}) is Dictionary else {}
	var flags: Variant = world.get("story_flags", {})
	return {"slot": slot, "name": str(player.get("hero_name", "Герой")), "level": int(player.get("level", 1)),
		"region": str(world.get("region", "greenreach")), "saved_at": float(data.get("saved_at", 0.0)), "ng": int(world.get("ng_plus", 0)),
		"ending": flags is Dictionary and ((flags as Dictionary).has("ending_restore") or (flags as Dictionary).has("ending_lower"))}

## The slot played last (0 when there are no saves).
static func latest_slot() -> int:
	var best := 0
	var best_time := -1.0
	for slot in range(1, SLOTS + 1):
		var summary := slot_summary(slot)
		if not summary.is_empty() and float(summary["saved_at"]) > best_time:
			best_time = float(summary["saved_at"])
			best = slot
	return best

static func delete_slot(slot: int) -> void:
	var path := slot_path(slot)
	for file in [path, autosave_path_for(path)]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))

## Autosaves live next to the manual save: foo.json -> foo_autosave.json.
static func autosave_path_for(path: String = SAVE_PATH) -> String:
	return path.get_basename() + "_autosave." + path.get_extension()

## Writes atomically: a crash mid-write leaves the previous save intact.
static func save_snapshot(snapshot: Dictionary, path: String = SAVE_PATH) -> bool:
	var data: Dictionary = snapshot.duplicate(true)
	data["version"] = VERSION
	data["saved_at"] = Time.get_unix_time_from_system()
	var temp_path := path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать сохранение: " + path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	if write_error != OK:
		DirAccess.remove_absolute(absolute_temp)
		push_error("Ошибка записи сохранения: " + path)
		return false
	var absolute_path := ProjectSettings.globalize_path(path)
	if DirAccess.rename_absolute(absolute_temp, absolute_path) != OK:
		# Some platforms refuse to rename over an existing file.
		DirAccess.remove_absolute(absolute_path)
		if DirAccess.rename_absolute(absolute_temp, absolute_path) != OK:
			push_error("Не удалось заменить файл сохранения: " + path)
			return false
	return true

## Returns the newest valid snapshot among the manual save and the autosave.
## The chosen file path is stored under the "_source_path" key.
static func load_latest(path: String = SAVE_PATH) -> Dictionary:
	var best: Dictionary = {}
	for candidate_path in [path, autosave_path_for(path)]:
		if not FileAccess.file_exists(candidate_path):
			continue
		var data := load_snapshot(candidate_path)
		if data.is_empty():
			continue
		if best.is_empty() or float(data.get("saved_at", 0.0)) > float(best.get("saved_at", 0.0)):
			data["_source_path"] = candidate_path
			best = data
	return best

static func load_snapshot(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Не удалось открыть сохранение")
		return {}
	var raw: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_warning("Файл сохранения повреждён")
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", -1)) != VERSION:
		push_warning("Несовместимая версия сохранения")
		return {}
	if not validate_snapshot(data):
		push_warning("Неполное или повреждённое сохранение")
		return {}
	return data

static func validate_snapshot(data: Dictionary) -> bool:
	var character: Variant = data.get("player")
	var quest_data: Variant = data.get("quest")
	var world_data: Variant = data.get("world")
	if not character is Dictionary or not quest_data is Dictionary or not world_data is Dictionary:
		return false
	var player_data: Dictionary = character
	var quest_dictionary: Dictionary = quest_data
	var world_dictionary: Dictionary = world_data
	if not player_data.get("inventory") is Dictionary or not player_data.get("equipment") is Dictionary:
		return false
	if player_data.has("talents") and not player_data.get("talents") is Dictionary:
		return false
	if not quest_dictionary.get("states") is Dictionary:
		return false
	if not world_dictionary.get("enemies") is Array or not world_dictionary.get("herbs") is Array or not world_dictionary.get("loot") is Array:
		return false
	return true
