extends Node
class_name ElementalCombos

## Combos of blade and elements (Этап 12). Statuses: burning (fire),
## chilled (ice or a stun), shocked (lightning). A second element or the
## sword on top of a status sets off a reaction (enemy.gd):
##   ПАР — ice on burning: a cloud that blinds and slows foes around;
##   ПЕРЕГРУЗКА — fire on shocked: a blast that throws foes back;
##   КРИСТАЛЬНАЯ ЦЕПЬ — lightning on chilled: hits every chilled foe near;
##   ОГНЕННАЯ БУРЯ — lightning on burning: the fire spreads;
##   РАСКОЛ — the sword on a chilled or stunned foe: +60% damage;
##   ПРОВОДНИК — the sword on a shocked foe: the blow arcs to two more.
## "Зачарованный клинок" (skill) puts the chosen spell's element on the
## sword for a while, so a battle mage can combo alone. Found combos are
## listed in the skill tree (tab «Комбинации»).

const REACTIONS := {
	"steam": {"name": "Пар", "recipe": "Лёд по горящему врагу", "text": "Облако пара ослепляет врагов вокруг на 2 с — они не могут атаковать — и замедляет их."},
	"overload": {"name": "Перегрузка", "recipe": "Огонь по наэлектризованному", "text": "Взрыв огня бьёт и отбрасывает всех врагов рядом."},
	"crystal": {"name": "Кристальная цепь", "recipe": "Молния по замедленному", "text": "Лёд проводит молнию: урон всем замедленным врагам вокруг."},
	"firestorm": {"name": "Огненная буря", "recipe": "Молния по горящему", "text": "Пламя перекидывается на врагов рядом."},
	"shatter": {"name": "Раскол", "recipe": "Меч по замедленному или оглушённому", "text": "Удар раскалывает лёд: +60% урона."},
	"conduct": {"name": "Проводник", "recipe": "Меч по наэлектризованному", "text": "Удар перескакивает разрядом ещё на двух врагов."},
}
const ELEMENT_OF := {"fireball": "fire", "frostbolt": "ice", "chain_lightning": "lightning", "fire_wave": "fire", "ice_wall": "ice", "ball_lightning": "lightning"}
const ELEMENT_NAMES := {"fire": "огонь", "ice": "лёд", "lightning": "молния"}
const ELEMENT_COLORS := {"fire": Color(1.0, 0.6, 0.35), "ice": Color(0.6, 0.85, 1.0), "lightning": Color(0.85, 0.75, 1.0)}

var game: SkywardGame
var seen: Dictionary = {}
var imbue_element: String = ""
var imbue_left: float = 0.0

func on_reaction(reaction_id: String, at: Vector2) -> void:
	var info: Dictionary = REACTIONS.get(reaction_id, {})
	Vfx.burst(game, at + Vector2(0, -8), [Color(1, 1, 1), _color(reaction_id), Color(1, 1, 1, 0)], 14, 90.0, 0.35)
	if reaction_id == "steam":
		Vfx.burst(game, at, [Color(0.95, 0.97, 1.0, 0.9), Color(0.8, 0.85, 0.9, 0.7), Color(1, 1, 1, 0)], 34, 60.0, 1.2)
	elif reaction_id == "overload":
		game._ring(at, 52.0, Color(1.0, 0.6, 0.3, 0.9))
		game.shake(2.5, 0.2)
	if info.is_empty() or seen.has(reaction_id):
		return
	seen[reaction_id] = true
	game.hud.show_title_card("Новая комбинация: %s" % str(info["name"]), 2.2)
	game.hud.show_message("%s — %s" % [str(info["recipe"]), str(info["text"])], 4.5)
	game.achievements.set_max("combos", seen.size())
	game.request_autosave()

func _color(reaction_id: String) -> Color:
	match reaction_id:
		"steam", "shatter":
			return Color(0.75, 0.9, 1.0)
		"overload", "firestorm":
			return Color(1.0, 0.6, 0.3)
	return Color(0.85, 0.75, 1.0)

## "Зачарованный клинок": the sword carries the element of the chosen spell.
func start_imbue(duration: float) -> bool:
	var element := str(ELEMENT_OF.get(game.selected_spell_id, "fire"))
	imbue_element = element
	imbue_left = duration
	game.player.add_buff("imbue", 0.0, duration, "Клинок: " + str(ELEMENT_NAMES[element]))
	game.hud.show_message("Клинок зачарован: %s на %d с." % [str(ELEMENT_NAMES[element]), roundi(duration)], 2.0)
	return true

func imbued() -> bool:
	return imbue_left > 0.0 and not imbue_element.is_empty()

func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	if imbue_left > 0.0:
		imbue_left -= delta
		var glow: Color = ELEMENT_COLORS.get(imbue_element, Color.WHITE)
		game.player.visual.self_modulate = Color.WHITE.lerp(glow, 0.35 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
		if imbue_left <= 0.0:
			imbue_element = ""
			game.player.visual.self_modulate = Color.WHITE

## A sword strike landed: combos first, then the blade's element.
func on_strike(enemy: SlimeEnemy, damage: int) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.health <= 0:
		return
	var bonus := enemy.react_to_melee(damage)
	if not imbued() or bonus > 0 or not is_instance_valid(enemy) or enemy.health <= 0:
		return
	match imbue_element:
		"fire":
			enemy.apply_burning(3 + game.player.level / 3, 2.0)
		"ice":
			enemy.apply_slow(0.6, 1.5)
		"lightning":
			enemy.apply_shock(2.5)

func codex() -> Array:
	var result: Array = []
	for reaction_id in REACTIONS:
		var info: Dictionary = REACTIONS[reaction_id]
		result.append({"id": reaction_id, "name": info["name"], "recipe": info["recipe"], "text": info["text"], "seen": seen.has(reaction_id)})
	return result

func make_snapshot() -> Dictionary:
	return {"seen": seen.duplicate()}

func restore_snapshot(data: Variant) -> void:
	if data is Dictionary and data.get("seen", {}) is Dictionary:
		seen = (data["seen"] as Dictionary).duplicate()
