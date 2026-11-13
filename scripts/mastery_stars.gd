extends Node
class_name MasteryStars

## Этап 24: growth does not end at level 20. Every level past it gives a
## mastery star, spent on one of five small, lasting bonuses (each up to 20
## ranks): the hero keeps getting stronger, a little at a time.

const FROM_LEVEL := 20
const MAX_RANK := 20
const TRACKS := {
	"might": {"name": "Сила", "text": "+1% урона оружием и стрелами"},
	"arcana": {"name": "Чародейство", "text": "+1% урона заклинаниями"},
	"guard": {"name": "Стойкость", "text": "+1% к снижению урона"},
	"vigor": {"name": "Жизнь", "text": "+8 к здоровью"},
	"fortune": {"name": "Удача", "text": "+2% золота"},
}
const ORDER := ["might", "arcana", "guard", "vigor", "fortune"]

var game: SkywardGame

func _hero() -> PlayerCharacter:
	return game.player

func rank(track: String) -> int:
	return int(_hero().stars.get(track, 0))

func earned() -> int:
	return maxi(0, _hero().level - FROM_LEVEL)

func spent() -> int:
	var total := 0
	for track in _hero().stars:
		total += int(_hero().stars[track])
	return total

func available() -> int:
	return maxi(0, earned() - spent())

func spend(track: String) -> bool:
	if available() <= 0 or not TRACKS.has(track) or rank(track) >= MAX_RANK:
		return false
	_hero().stars[track] = rank(track) + 1
	if track == "vigor":
		_hero().max_health += 8
		_hero().heal(8)
	_hero().stats_changed.emit()
	game.achievements.set_max("stars", spent())
	return true

# --- Effects ---------------------------------------------------------------------

func melee_mult() -> float:
	return 1.0 + 0.01 * float(rank("might"))

func spell_mult() -> float:
	return 1.0 + 0.01 * float(rank("arcana"))

func damage_reduction() -> float:
	return 0.01 * float(rank("guard"))

func gold_mult() -> float:
	return 1.0 + 0.02 * float(rank("fortune"))

## A line for the skill tree.
func summary() -> String:
	if earned() <= 0:
		return "Звёзды мастерства — с %d-го уровня: каждый уровень даёт звезду." % (FROM_LEVEL + 1)
	var parts: Array[String] = []
	for track in ORDER:
		if rank(track) > 0:
			parts.append("%s %d" % [str(TRACKS[track]["name"]), rank(track)])
	return "Звёзды мастерства: %d свободно%s" % [available(), (" · " + ", ".join(parts)) if not parts.is_empty() else ""]

# --- Dialogue --------------------------------------------------------------------

func offer() -> void:
	if available() <= 0:
		return
	var choices: Array[Dictionary] = []
	for track in ORDER:
		var info: Dictionary = TRACKS[track]
		if rank(track) < MAX_RANK:
			choices.append({"id": "star:" + track, "label": "★ %s — %s (сейчас %d/%d)" % [str(info["name"]), str(info["text"]), rank(track), MAX_RANK]})
	choices.append({"id": "star_later", "label": "Позже (T — дерево навыков)"})
	game._show_dialogue_choices("Звезда мастерства", "Свободных звёзд: %d. Каждая — маленький, но вечный шаг вперёд." % available(), choices)

func handle_choice(choice_id: String) -> bool:
	if choice_id == "star_later":
		game.dialogues._close()
		return true
	if not choice_id.begins_with("star:"):
		return false
	var track := choice_id.trim_prefix("star:")
	if spend(track):
		GameAudio.play("quest", -6.0, 0.2)
		game.hud.show_message("★ %s: %d" % [str(TRACKS[track]["name"]), rank(track)], 2.0)
	if available() > 0:
		offer()
	else:
		game.dialogues._close()
	return true
