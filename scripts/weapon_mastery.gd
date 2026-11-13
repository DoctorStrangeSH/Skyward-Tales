extends Node
class_name WeaponMastery

## Этап 24: weapon mastery. Every kind of weapon grows with use — a foe
## defeated with it in hand gives points (an elite 3, a boss 10) — and each
## of three ranks teaches it something of its own. A reason to try them all.

const RANKS := [25, 100, 300]
const KINDS := {
	"sword": {"name": "Меч", "perks": [
		"+5% урона мечом.",
		"Вихрь: каждый 4-й удар подряд задевает всех вокруг (половина урона).",
		"Крит мечом сильнее на 25%."]},
	"dagger": {"name": "Кинжал", "perks": [
		"+6% шанса крита.",
		"Подлый удар: по замедленным, горящим и ослеплённым врагам ×1,4.",
		"Тень: после переката два следующих удара ×1,3."]},
	"spear": {"name": "Копьё", "perks": [
		"+6% урона копьём.",
		"Удар копьём замедляет врага на секунду.",
		"Первый удар по нетронутому врагу ×1,6."]},
	"hammer": {"name": "Молот", "perks": [
		"+8% урона молотом.",
		"Удар молотом замедляет и элиту, и боссов.",
		"Добивание: обычный враг ниже 20% здоровья падает от удара."]},
	"bow": {"name": "Лук", "perks": [
		"+6% урона стрелами.",
		"Прицельный выстрел +20% и пробивает ещё одного врага.",
		"Обычный выстрел тоже пробивает врага."]},
	"staff": {"name": "Посох", "perks": [
		"+5% урона заклинаниями.",
		"Заклинания на 10% дешевле.",
		"Каждое 5-е заклинание — бесплатно."]},
}

var game: SkywardGame
var _combo: int = 0
var _shadow: int = 0
var _casts: int = 0

func _hero() -> PlayerCharacter:
	return game.player

func points(kind: String) -> int:
	return int(_hero().mastery.get(kind, 0))

func rank(kind: String) -> int:
	var have := points(kind)
	var result := 0
	for need in RANKS:
		if have >= int(need):
			result += 1
	return result

func has(kind: String, at_rank: int) -> bool:
	return _hero().weapon_kind() == kind and rank(kind) >= at_rank

## Points for a foe defeated with the weapon in hand.
func on_kill(elite: bool, boss: bool) -> void:
	var kind := _hero().weapon_kind()
	if not KINDS.has(kind):
		return
	var before := rank(kind)
	_hero().mastery[kind] = points(kind) + (10 if boss else (3 if elite else 1))
	var after := rank(kind)
	if after > before:
		var info: Dictionary = KINDS[kind]
		game.hud.show_title_card("Мастерство: %s — ступень %s" % [str(info["name"]), ["I", "II", "III"][after - 1]], 2.6)
		game.hud.show_message(str(info["perks"][after - 1]), 5.0)
		GameAudio.play("level_up", -6.0, 0.3)
		game.achievements.set_max("mastery", after)

## A line for the skill tree: the weapon in hand, its rank, the next perk.
func summary() -> String:
	var kind := _hero().weapon_kind()
	if not KINDS.has(kind):
		return ""
	var info: Dictionary = KINDS[kind]
	var level := rank(kind)
	var stars := "★".repeat(level) + "☆".repeat(3 - level)
	var next := "" if level >= 3 else " · %d/%d → %s" % [points(kind), int(RANKS[level]), str(info["perks"][level])]
	return "Мастерство «%s» %s%s" % [str(info["name"]), stars, next]

# --- Effects -------------------------------------------------------------------

func strike_mult(enemy: SlimeEnemy, crit: bool) -> float:
	var kind := _hero().weapon_kind()
	var mult := 1.0
	match kind:
		"sword":
			if has("sword", 1):
				mult *= 1.05
			if crit and has("sword", 3):
				mult *= 1.25
		"dagger":
			if has("dagger", 2) and enemy != null and (enemy.slow_time_left > 0.0 or enemy.burn_time_left > 0.0 or enemy.blind_time_left > 0.0):
				mult *= 1.4
			if has("dagger", 3) and _shadow > 0:
				_shadow -= 1
				mult *= 1.3
		"spear":
			if has("spear", 1):
				mult *= 1.06
			if has("spear", 3) and enemy != null and enemy.health >= enemy.max_health:
				mult *= 1.6
		"hammer":
			if has("hammer", 1):
				mult *= 1.08
	return mult

func crit_bonus() -> float:
	return 0.06 if has("dagger", 1) else 0.0

func on_strike(enemy: SlimeEnemy, damage: int) -> void:
	var kind := _hero().weapon_kind()
	if not is_instance_valid(enemy):
		return
	match kind:
		"sword":
			_combo += 1
			if has("sword", 2) and _combo % 4 == 0:
				for other in game._living_enemies():
					if other != enemy and other.global_position.distance_to(_hero().global_position) < 40.0:
						other.take_damage(maxi(1, damage / 2))
				game._ring(_hero().global_position, 40.0, Color(0.85, 0.9, 1.0))
		"spear":
			if has("spear", 2) and enemy.health > 0:
				enemy.apply_slow(0.5, 1.0)
		"hammer":
			if has("hammer", 2) and enemy.health > 0:
				enemy.apply_slow(0.55, 0.8)
			if has("hammer", 3) and enemy.health > 0 and enemy.health < enemy.max_health * 0.2 and not SkywardGame.STORY_BOSSES.has(SkywardGame.enemy_kind(enemy)):
				enemy.combat_feedback.show_reaction("ДОБИТ!")
				enemy.take_damage(enemy.health + 1)

func on_dodge() -> void:
	if has("dagger", 3):
		_shadow = 2

func bow_damage(damage: int, aimed: bool) -> int:
	var mult := 1.0
	if has("bow", 1):
		mult *= 1.06
	if aimed and has("bow", 2):
		mult *= 1.2
	return roundi(float(damage) * mult)

func bow_pierce(pierce: int, aimed: bool) -> int:
	if aimed and has("bow", 2):
		return pierce + 1
	if not aimed and has("bow", 3):
		return maxi(pierce, 1)
	return pierce

func spell_damage(damage: int) -> int:
	return roundi(float(damage) * (1.05 if has("staff", 1) else 1.0))

func mana_cost(cost: int) -> int:
	if has("staff", 3):
		_casts += 1
		if _casts % 5 == 0:
			return 0
	return roundi(float(cost) * (0.9 if has("staff", 2) else 1.0))
