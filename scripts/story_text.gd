extends RefCounted
class_name StoryText

## Hero identity used by every line of text.
## "{hero}" → the hero's name; "{нашёл|нашла}" → form for the hero's gender.

const DEFAULT_NAMES := {"m": "Арен", "f": "Арина"}

static var hero_name: String = "Арен"
static var hero_gender: String = "m"

static var _choice := RegEx.create_from_string("\\{([^{}|]*)\\|([^{}|]*)\\}")

static func set_hero(name: String, gender: String) -> void:
	hero_gender = "f" if gender == "f" else "m"
	var clean := name.strip_edges()
	hero_name = clean if not clean.is_empty() else DEFAULT_NAMES[hero_gender]

static func reset() -> void:
	set_hero("", "m")

static func format(text: String) -> String:
	var result := text.replace("{hero}", hero_name)
	var pick := 2 if hero_gender == "f" else 1
	for match in _choice.search_all(result):
		result = result.replace(match.get_string(0), match.get_string(pick))
	return result
