extends RefCounted
class_name Difficulty

## Этап 24: difficulty levels. Each save keeps its own (SkywardGame.difficulty);
## the settings keep the one new adventures start with. Foes are made
## tougher or softer, and — the pacing fix from the full-game bot — they grow
## with a hero who outlevels the land (except in «Сказка»): «slack» is how
## many levels above the land the hero may be before foes catch up.

const LEVELS := [
	{"id": "story", "name": "Сказка", "health": 0.7, "damage": 0.6, "slack": 99, "elite": 0.5, "reward": 1.0,
		"text": "Для истории: враги слабее, не растут вместе с героем."},
	{"id": "normal", "name": "Обычная", "health": 1.0, "damage": 1.0, "slack": 3, "elite": 1.0, "reward": 1.0,
		"text": "Как задумано. Если герой обгонит землю больше чем на 3 уровня, враги подтянутся."},
	{"id": "heroic", "name": "Героическая", "health": 1.3, "damage": 1.25, "slack": 0, "elite": 1.6, "reward": 1.2,
		"text": "Враги сильнее и всегда не ниже уровня героя, элиты чаще; опыта и золота +20%."},
	{"id": "legendary", "name": "Легендарная", "health": 1.6, "damage": 1.5, "slack": -1, "elite": 2.2, "reward": 1.4,
		"text": "Враги на уровень выше героя и бьют больно, элит вдвое больше; опыта и золота +40%. Без поблажек."},
]
const DEFAULT := 1
const HEROIC := 2

static func clamp_level(level: int) -> int:
	return clampi(level, 0, LEVELS.size() - 1)

static func info(level: int) -> Dictionary:
	return LEVELS[clamp_level(level)]

static func names() -> Array:
	return LEVELS.map(func(entry: Dictionary) -> String: return str(entry["name"]))

## Levels by which foes are lifted above their land for this hero.
static func catch_up(level: int, hero_level: int, land_level: int) -> int:
	return maxi(0, hero_level - land_level - int(info(level)["slack"]))

## Health and damage of a foe lifted by `levels` (≈ what the next lands add).
static func lift_health(levels: int) -> float:
	return 1.0 + 0.09 * float(levels)

static func lift_damage(levels: int) -> float:
	return 1.0 + 0.07 * float(levels)

static func lift_xp(levels: int) -> float:
	return 1.0 + 0.06 * float(levels)

## Settings: the difficulty new adventures start with.
static func default_level() -> int:
	return clamp_level(int(GameSettings.get_float("difficulty")))
