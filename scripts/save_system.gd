extends RefCounted
class_name SaveSystem

const VERSION: int = 1
const SAVE_PATH: String = "user://skyward_tales_save.json"

static func save_snapshot(snapshot: Dictionary, path: String = SAVE_PATH) -> bool:
	var data: Dictionary = snapshot.duplicate(true)
	data["version"] = VERSION
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать сохранение: " + path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	return true

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
	if not data.has("player") or not data.has("world") or not data.has("quest"):
		push_warning("Неполное сохранение")
		return {}
	return data
