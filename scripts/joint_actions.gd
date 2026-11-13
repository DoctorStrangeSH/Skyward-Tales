extends Node
class_name JointActions

## Этап 24: joint actions with companions (G). The hero calls, and every
## companion beside them (not knocked down) adds their own piece:
##   Mira — «Звёздная вспышка»: a flash blinds foes around the target, the
##     hero's next blow is ×1.6;
##   Toren — «Пригвоздить»: an arrow pins the target (slowed almost to a
##     stop for 3 s), the hero's next three blows on it are ×1.4;
##   Raina — «Громовой залп»: a shot in step with the hero — double the hero's
##     blow to the target and foes next to it, knocking them back.
## One cooldown for all; with two companions the action is twice as rich.

const KEY_HINT := "G"
const COOLDOWN := 35.0
const RANGE := 220.0
const ACTIONS := {
	"mira": {"name": "Звёздная вспышка", "text": "Мира ослепляет врагов вокруг цели, ваш следующий удар ×1,6."},
	"hunter": {"name": "Пригвоздить", "text": "Торен пригвождает цель стрелой на 3 с, три ваших удара по ней ×1,4."},
	"captain": {"name": "Громовой залп", "text": "Рейна стреляет вместе с вами: двойной удар по цели и врагам рядом, отбрасывает."},
}

var game: SkywardGame
var ready_in: float = 0.0
var _flash_bonus: bool = false
var _pinned: SlimeEnemy = null
var _pinned_hits: int = 0
var _told_ready: bool = false

## Companions beside the hero who can act now.
func companions() -> Array:
	var result: Array = []
	for companion in [game.companion, game.party.follower() if game.party != null else null]:
		if companion == null or not is_instance_valid(companion) or not companion.is_inside_tree():
			continue
		if float(companion.down_left) > 0.0 or not ACTIONS.has(str(companion.role)):
			continue
		if companion.global_position.distance_to(game.player.global_position) > 260.0:
			continue
		result.append(companion)
	return result

func _process(delta: float) -> void:
	if game == null or game.get_tree().paused:
		return
	if ready_in > 0.0:
		ready_in = maxf(0.0, ready_in - delta)
		if ready_in <= 0.0:
			_told_ready = false
	if not _told_ready and not companions().is_empty() and not game._living_enemies().is_empty():
		_told_ready = true
		game.hud.show_message("%s — совместный приём со спутником готов." % KEY_HINT, 2.5)

func _target() -> SlimeEnemy:
	var best: SlimeEnemy = null
	var best_distance := RANGE
	for enemy in game._living_enemies():
		var distance: float = enemy.global_position.distance_to(game.player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best

## G: true when the action went off.
func trigger() -> bool:
	var helpers := companions()
	if helpers.is_empty():
		game.hud.show_message("Совместный приём — когда спутник рядом и на ногах.", 2.0)
		return false
	if ready_in > 0.0:
		game.hud.show_message("Совместный приём будет готов через %d с." % ceili(ready_in), 1.5)
		return false
	var target := _target()
	if target == null:
		game.hud.show_message("Рядом нет врагов.", 1.5)
		return false
	var names: Array[String] = []
	for companion in helpers:
		var role := str(companion.role)
		names.append(str(ACTIONS[role]["name"]))
		match role:
			"mira":
				_mira(companion, target)
			"hunter":
				_toren(companion, target)
			"captain":
				_raina(companion, target)
	ready_in = COOLDOWN
	game.hud.show_title_card(" + ".join(names), 1.6)
	GameAudio.play("level_up", -10.0, 0.2)
	game.achievements.add("joint_actions")
	return true

func _mira(companion: Node2D, target: SlimeEnemy) -> void:
	for enemy in game._living_enemies():
		if enemy.global_position.distance_to(target.global_position) < 110.0:
			enemy.apply_blind(2.5)
	_flash_bonus = true
	game._ring(target.global_position, 110.0, Color(1.0, 0.95, 0.7))
	game._streak(companion.global_position + Vector2(0, -10), target.global_position + Vector2(0, -8), Color(1.0, 0.95, 0.7), 2.0)

func _toren(companion: Node2D, target: SlimeEnemy) -> void:
	target.apply_slow(0.1, 3.0)
	target.combat_feedback.show_reaction("ПРИГВОЖДЁН!")
	_pinned = target
	_pinned_hits = 3
	game._streak(companion.global_position + Vector2(0, -10), target.global_position + Vector2(0, -8), Color(0.85, 0.75, 0.5), 2.0)

func _raina(companion: Node2D, target: SlimeEnemy) -> void:
	var blow := game.player.get_melee_damage() * 2
	var center := target.global_position
	for enemy in game._living_enemies():
		if enemy == target or enemy.global_position.distance_to(center) < 40.0:
			enemy.apply_knockback((enemy.global_position - game.player.global_position).normalized(), 240.0)
			enemy.take_damage(blow)
	game._streak(companion.global_position + Vector2(0, -10), center + Vector2(0, -8), Color(1.0, 0.85, 0.35), 3.0)
	game._ring(center, 40.0, Color(1.0, 0.8, 0.3))
	game.shake(3.0, 0.2)

## Multiplier of the hero's blow (called from hero_combat._strike).
func strike_mult(enemy: SlimeEnemy) -> float:
	var mult := 1.0
	if _flash_bonus:
		_flash_bonus = false
		mult *= 1.6
	if _pinned_hits > 0 and enemy != null and enemy == _pinned:
		_pinned_hits -= 1
		mult *= 1.4
	return mult

## A line for the skill tree.
func summary() -> String:
	var helpers := companions()
	if helpers.is_empty():
		return ""
	var names: Array[String] = []
	for companion in helpers:
		names.append(str(ACTIONS[str(companion.role)]["name"]))
	return "%s — совместный приём: %s%s" % [KEY_HINT, " + ".join(names), "" if ready_in <= 0.0 else " (через %d с)" % ceili(ready_in)]
