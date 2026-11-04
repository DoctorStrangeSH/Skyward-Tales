extends RefCounted
class_name GameCatalogs

var bestiary: Dictionary = {}
var talents: Dictionary = {}
var spells: Dictionary = {}
var regions: Dictionary = {}
var skills: Dictionary = {}

static var _shared: GameCatalogs

## One cached copy for code that only reads catalogs.
static func shared() -> GameCatalogs:
	if _shared == null:
		_shared = GameCatalogs.new()
	return _shared

func _init() -> void:
	regions = _load_dictionary("res://data/regions.json", "Каталог регионов не найден.")
	bestiary = _load_dictionary("res://data/bestiary.json", "Каталог бестиария не найден.")
	talents = _load_dictionary("res://data/talents.json", "Каталог талантов не найден.")
	skills = _load_dictionary("res://data/skills.json", "Каталог навыков не найден.")
	spells = _load_dictionary("res://data/spells.json", "Каталог заклинаний не найден — используются значения по умолчанию.")

func _load_dictionary(path: String, missing_message: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning(missing_message)
		return {}
	var raw: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_warning("Некорректный формат игрового каталога: " + path)
		return {}
	return parsed
