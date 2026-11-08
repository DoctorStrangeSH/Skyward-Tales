extends Node2D
class_name BossMechanics

## Этап 18: the mechanics of the two endgame bosses, attached as a child of
## an ordinary enemy body (scaled, tinted and renamed).
##   "devourer" — «Пожиратель Узора» (every 5th depth of the deep rifts):
##       at 66% and 33% health it hides behind a shield fed by three Pattern
##       anchors (kill them to break it); every few seconds a ring of falling
##       crystals erupts around it.
##   "abyss" — «Хранитель Бездны» (legendary expeditions): lightning strikes
##       in a cross around the hero; at half health it splits off two
##       illusions and grows furious.

const ANCHOR_SHARE := 0.08

var style: String = "devourer"
var boss: SlimeEnemy
var game: SkywardGame
var shielded: bool = false
var anchors: Array = []
var _thresholds: Array = [0.66, 0.33]
var _attack_clock: float = 4.0
var _split: bool = false
var _clock: float = 0.0

static func attach(target: SlimeEnemy, owner_game: SkywardGame, kind: String) -> BossMechanics:
	var mech := BossMechanics.new()
	mech.style = kind
	mech.boss = target
	mech.game = owner_game
	target.add_child(mech)
	return mech

func _process(delta: float) -> void:
	if boss == null or not is_instance_valid(boss) or boss.is_queued_for_deletion() or boss.health <= 0:
		_cleanup()
		return
	if game == null or game.get_tree().paused:
		return
	_clock += delta
	queue_redraw()
	if style == "devourer":
		_devourer(delta)
	else:
		_abyss(delta)

func _devourer(delta: float) -> void:
	if shielded:
		anchors = anchors.filter(func(a: Variant) -> bool: return is_instance_valid(a) and not (a as SlimeEnemy).is_queued_for_deletion() and (a as SlimeEnemy).health > 0)
		if anchors.is_empty():
			shielded = false
			boss.invulnerable = false
			game.hud.show_message("Щит Пожирателя рухнул!", 2.0)
			game.shake(4.0, 0.3)
	elif not _thresholds.is_empty() and boss.health <= roundi(boss.max_health * float(_thresholds[0])):
		_thresholds.pop_front()
		_raise_shield()
	_attack_clock -= delta
	if _attack_clock <= 0.0:
		_attack_clock = 6.0
		for i in 8:
			var strike := CrystalStrike.new()
			strike.damage = maxi(6, roundi(game.player.max_health * 0.12))
			game.add_child(strike)
			strike.global_position = boss.global_position + Vector2.RIGHT.rotated(TAU * i / 8.0 + _clock) * 70.0

func _raise_shield() -> void:
	shielded = true
	boss.invulnerable = true
	anchors.clear()
	for i in 3:
		var at := boss.global_position + Vector2.RIGHT.rotated(TAU * i / 3.0) * 90.0
		var anchor := game.spawn_enemy("wisp", at)
		if anchor == null:
			continue
		anchor.set_meta("rift_echo", true)
		anchor.max_health = maxi(20, roundi(boss.max_health * ANCHOR_SHARE))
		anchor.health = anchor.max_health
		anchor.attack_damage = roundi(anchor.attack_damage * 1.5)
		anchor.combat_feedback.elite = true
		anchor.combat_feedback.elite_name = "Якорь Узора"
		anchor.combat_feedback.elite_color = Color(0.85, 0.6, 1.0)
		anchor.base_visual_tint = Color(0.85, 0.6, 1.0)
		anchor.visual.modulate = anchor.base_visual_tint
		anchor.combat_feedback.set_health(anchor.health, anchor.max_health)
		anchors.append(anchor)
	game.hud.show_message("Пожиратель закрылся щитом! Разбейте три якоря Узора.", 3.0)
	GameAudio.play("boss_roar", -6.0, 0.3)

func _abyss(delta: float) -> void:
	_attack_clock -= delta
	if _attack_clock <= 0.0:
		_attack_clock = 5.0 if not _split else 3.8
		var hero := game.player.global_position
		for offset in [Vector2.ZERO, Vector2(40, 0), Vector2(-40, 0), Vector2(0, 32), Vector2(0, -32)]:
			var strike := CrystalStrike.new()
			strike.lightning = true
			strike.damage = maxi(6, roundi(game.player.max_health * 0.1))
			game.add_child(strike)
			strike.global_position = hero + offset
	if not _split and boss.health * 2 <= boss.max_health:
		_split = true
		boss.attack_damage = roundi(boss.attack_damage * 1.3)
		boss.move_speed *= 1.2
		for side in [-1, 1]:
			var kind := SkywardGame.enemy_kind(boss)
			var copy := game.spawn_enemy(kind, boss.global_position + Vector2(side * 50, 10))
			if copy == null:
				continue
			copy.set_meta("vault", true)
			copy.max_health = maxi(30, boss.max_health / 5)
			copy.health = copy.max_health
			copy.attack_damage = roundi(boss.attack_damage * 0.5)
			copy.base_visual_tint = Color(0.5, 0.6, 1.0, 0.55)
			copy.visual.modulate = copy.base_visual_tint
			copy.combat_feedback.set_health(copy.health, copy.max_health)
			copy.combat_feedback.elite = true
			copy.combat_feedback.elite_name = "Иллюзия"
		game.hud.show_message("Хранитель Бездны раскалывается на отражения!", 2.5)
		game.shake(4.0, 0.3)

func _draw() -> void:
	if style == "devourer" and shielded:
		var pulse := 0.5 + 0.5 * sin(_clock * 5.0)
		draw_circle(Vector2(0, -16), 30.0, Color(0.7, 0.45, 1.0, 0.12 + 0.08 * pulse))
		draw_arc(Vector2(0, -16), 30.0, 0.0, TAU, 32, Color(0.9, 0.7, 1.0, 0.7), 2.0)
		for a in anchors:
			if is_instance_valid(a):
				draw_line(Vector2(0, -16), to_local((a as Node2D).global_position), Color(0.85, 0.6, 1.0, 0.35 + 0.3 * pulse), 1.5)

func _cleanup() -> void:
	for a in anchors:
		if is_instance_valid(a):
			(a as Node).queue_free()
	anchors.clear()
	set_process(false)
