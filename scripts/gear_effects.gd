extends Node
class_name GearEffects

## The warrior's rhythm and gear that changes how you fight (Этап 12).
## Hit streak: blows without being hurt build "В ударе!" (+15% at 10,
## +30% at 20); a hit taken or a pause ends it.
## Parry (F at the right moment): the attacker staggers, the next blow is a
## riposte (critical ×2.5).
## Special effects of epic and legendary gear:
##   skyclaw_blade — every 4th sword hit calls a star bolt (lightning + shock);
##   dusk_fang     — a kill in the dark heals 6% health;
##   toad_crown    — whoever hits the hero is poisoned;
##   crab_aegis    — a longer parry window; a parry heals 5%;
##   golem_heart   — below 30% health, +30% damage reduction (player.gd);
##   spark_collar  — after a dodge the next two hits shock;
##   jelly_staff   — spells stick: hit foes are slowed.

const STREAK_WINDOW := 2.5
const RIPOSTE_WINDOW := 1.5
const DESCRIPTIONS := {
	"skyclaw_blade": "Каждый 4-й удар мечом зовёт звёздную молнию.",
	"dusk_fang": "Убийство в темноте лечит 6% здоровья.",
	"toad_crown": "Ударившие героиню враги отравлены.",
	"crab_aegis": "Окно парирования длиннее; парирование лечит 5%.",
	"golem_heart": "При здоровье ниже 30% — +30% к снижению урона.",
	"spark_collar": "После переката два удара электризуют врагов.",
	"jelly_staff": "Заклинания липнут: поражённые враги замедлены.",
	"viper_fang": "Критические удары отравляют врага.",
	"storm_spear": "Выпад с шансом 30% перескакивает молнией на соседнего врага.",
	"titan_breaker": "Каждый третий удар — ударная волна вокруг героини.",
	"phoenix_feather": "Раз в 3 минуты смертельный удар оставляет 40% здоровья.",
	"keeper_hourglass": "Умения перезаряжаются на 20% быстрее.",
}

var game: SkywardGame
var streak: int = 0
var streak_left: float = 0.0
var best_streak: int = 0
var riposte_left: float = 0.0
var _strikes: int = 0
var _spark_charges: int = 0

func _player() -> PlayerCharacter:
	return game.player

func wears(item_id: String) -> bool:
	return _player().wears_base(item_id)

static func effect_text(item_id: String) -> String:
	return str(DESCRIPTIONS.get(item_id, ""))

var _set_check := 0.0

func _process(delta: float) -> void:
	if game == null or game.get_tree().paused:
		return
	_set_check -= delta
	if _set_check <= 0.0:
		_set_check = 1.0
		for count in _player().worn_sets().values():
			if int(count) >= 3:
				game.achievements.set_max("full_set", 1)
	riposte_left = maxf(0.0, riposte_left - delta)
	if streak > 0:
		streak_left -= delta
		if streak_left <= 0.0:
			streak = 0
		game.hud.set_streak(streak, streak_left / STREAK_WINDOW)

func streak_mult() -> float:
	if streak >= 20:
		return 1.3
	if streak >= 10:
		return 1.15
	return 1.0

## Damage of a sword blow before it lands: streak and riposte.
func modify_strike(damage: int) -> Dictionary:
	var riposte := riposte_left > 0.0
	if riposte:
		riposte_left = 0.0
		damage = roundi(damage * 2.5)
	return {"damage": roundi(damage * streak_mult()), "riposte": riposte}

## A sword blow landed.
func on_strike(enemy: SlimeEnemy, _damage: int) -> void:
	streak += 1
	streak_left = STREAK_WINDOW
	if streak > best_streak:
		best_streak = streak
	game.achievements.set_max("streak", streak)
	game.hud.set_streak(streak, 1.0)
	if streak == 10 or streak == 20:
		game.hud.show_message("В ударе! Урон +%d%%" % (15 if streak == 10 else 30), 1.6)
	if enemy == null or not is_instance_valid(enemy) or enemy.health <= 0:
		return
	_strikes += 1
	if wears("skyclaw_blade") and _strikes % 4 == 0:
		var bolt := 8 + _player().level
		enemy.take_elemental_damage(bolt, "lightning")
		if is_instance_valid(enemy) and enemy.health > 0:
			enemy.apply_shock(2.0)
		Vfx.burst(game, enemy.global_position + Vector2(0, -20), [Color(1, 1, 1), Color(0.6, 0.9, 1.0), Color(0.4, 0.6, 1.0, 0)], 16, 70.0, 0.3)
		game._ring(enemy.global_position, 18.0, Color(0.7, 0.9, 1.0))
	if wears("storm_spear") and is_instance_valid(enemy) and game.crit_rng.randf() < 0.3:
		var next: SlimeEnemy = null
		var best := 90.0
		for other in game._living_enemies():
			var d: float = other.global_position.distance_to(enemy.global_position)
			if other != enemy and d < best:
				best = d
				next = other
		if next != null:
			next.take_elemental_damage(6 + _player().level, "lightning")
			if is_instance_valid(next) and next.health > 0:
				next.apply_shock(2.0)
			game._streak(enemy.global_position + Vector2(0, -8), next.global_position + Vector2(0, -8), Color(0.7, 0.9, 1.0), 2.0)
	if wears("titan_breaker") and _strikes % 3 == 0:
		var wave := roundi(_damage * 0.6)
		for other in game._living_enemies():
			if other.global_position.distance_to(_player().global_position) < 56.0:
				other.take_damage(wave)
				if is_instance_valid(other) and other.health > 0:
					other.apply_knockback((other.global_position - _player().global_position).normalized(), 180.0)
		game._ring(_player().global_position, 56.0, Color(1.0, 0.85, 0.5, 0.9))
		game.shake(3.0, 0.18)
	if _spark_charges > 0 and is_instance_valid(enemy) and enemy.health > 0:
		_spark_charges -= 1
		enemy.apply_shock(2.5)

## A critical blow landed.
func on_crit(enemy: SlimeEnemy) -> void:
	if wears("viper_fang") and is_instance_valid(enemy) and enemy.health > 0:
		enemy.apply_burning(3 + _player().level / 2, 3.0)
		enemy.combat_feedback.show_reaction("ЯД!")

func on_dodge() -> void:
	if wears("spark_collar"):
		_spark_charges = 2

func on_kill() -> void:
	if wears("dusk_fang") and (game.legends.dark() if game.legends != null else false):
		_player().heal(maxi(1, roundi(_player().max_health * 0.06)))

func on_spell_hit(enemy: Node) -> void:
	if wears("jelly_staff") and is_instance_valid(enemy) and enemy.has_method("apply_slow"):
		enemy.apply_slow(0.7, 1.2)

## The hero was hurt (not blocked or parried).
func on_hurt(_amount: int, source: Node) -> void:
	if _player().blocking:
		return
	if streak >= 3:
		game.hud.show_message("Серия прервана (×%d)." % streak, 1.2)
	streak = 0
	game.hud.set_streak(0, 0.0)
	if wears("toad_crown") and source != null and is_instance_valid(source) and source.has_method("apply_burning"):
		source.apply_burning(4 + _player().level / 2, 3.0)

func on_parry(source: Node) -> void:
	riposte_left = RIPOSTE_WINDOW
	game.achievements.add("parries")
	if source != null and is_instance_valid(source):
		if source.has_method("apply_slow"):
			source.apply_slow(0.05, 1.2)
		if source.has_method("apply_knockback"):
			source.apply_knockback((source.global_position - _player().global_position).normalized(), 160.0)
		var feedback: Variant = source.get("combat_feedback")
		if feedback != null:
			feedback.show_reaction("ПАРИРОВАНО!")
	if wears("crab_aegis"):
		_player().heal(maxi(1, roundi(_player().max_health * 0.05)))
	Vfx.burst(game, _player().global_position + _player().facing * 14.0 + Vector2(0, -8), [Color(1, 1, 1), Color(1.0, 0.9, 0.5), Color(1, 0.8, 0.3, 0)], 16, 90.0, 0.3)
	GameAudio.play("hit", 0.0, 0.3)
	game.shake(3.0, 0.15)
	game.hud.show_message("Парирование! Следующий удар — контратака.", 1.5)
