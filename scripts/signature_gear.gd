extends Node
class_name SignatureGear

## Этап 24: every great foe has an item of its own that changes how you
## fight. It drops the first time the foe falls; a foe beaten before this
## existed (an old save) — Borin forges its trophy from the boss's relic
## (scripts/borin_story.gd, "Трофейная ковка").

## boss kind → item id (data/equipment.json).
const TROPHIES := {
	"crypt_lord": "crypt_lantern",
	"guardian": "heartwood_bark",
	"crab_king": "crab_king_shell",
	"echo": "echo_prism",
	"bog_king": "bog_signet",
	"giant": "giant_fist",
	"tempest": "tempest_eye",
	"vail": "vail_cloak",
	"ash_lord": "ash_brand",
	"forge_titan": "titan_core",
	"pattern_voice": "pattern_tuner",
	"pattern_shade": "shade_shard",
}
const DESCRIPTIONS := {
	"crypt_lantern": "Каждое убийство возвращает 6 маны и 2% здоровья.",
	"heartwood_bark": "Постойте на месте секунду — пустите корни: −25% урона и лечение 1% в секунду.",
	"crab_king_shell": "Блок возвращает атакующему 60% остановленного урона.",
	"echo_prism": "Критический удар отзывается эхом: враги рядом получают половину урона.",
	"bog_signet": "Удары по горящим, отравленным и замедленным врагам лечат 2% здоровья.",
	"giant_fist": "Каждый 5-й удар оглушает врага на секунду и отбрасывает далеко.",
	"tempest_eye": "Перекат оставляет вихрь: 2 секунды бьёт и замедляет врагов вокруг.",
	"vail_cloak": "После убийства — тень Вейла: следующий удар в течение 3 с ×1,8.",
	"ash_brand": "Каждый 3-й удар поджигает; по горящим врагам +20% урона.",
	"titan_core": "Полученный удар копит жар (до 10, +2% урона за заряд); перекат с 5+ зарядами — взрыв.",
	"pattern_tuner": "Чередуйте: удар после заклинания и заклинание после удара — +30%.",
	"shade_shard": "Тень повторяет каждый 3-й удар — 60% урона по другому врагу рядом.",
}

var game: SkywardGame
var _hits: int = 0
var _still: float = 0.0
var rooted: bool = false
var _root_tick: float = 0.0
var _vail_left: float = 0.0
var heat: int = 0
var _bog_cooldown: float = 0.0
## "melee" | "spell" — the last kind of attack (pattern tuner).
var _last_attack: String = ""

func _hero() -> PlayerCharacter:
	return game.player

func wears(item_id: String) -> bool:
	return _hero().wears_base(item_id)

static func effect_text(item_id: String) -> String:
	return str(DESCRIPTIONS.get(item_id, ""))

static func trophy_of(kind: String) -> String:
	return str(TROPHIES.get(kind, ""))

# --- Drops -------------------------------------------------------------------

func owned(item_id: String) -> bool:
	var hero := _hero()
	if int(hero.inventory.get(item_id, 0)) > 0 or hero.wears_base(item_id):
		return true
	for id in hero.inventory:
		if str(hero.get_item_definition(str(id)).get("base_id", "")) == item_id:
			return true
	return false

## A great foe fell for the first time: its trophy drops by the body.
func on_boss_defeated(kind: String, at: Vector2) -> void:
	var item_id := trophy_of(kind)
	if item_id.is_empty() or game.director.has_flag("trophy_" + kind):
		return
	game.director.set_flag("trophy_" + kind)
	game.achievements.add("trophies")
	game._spawn_loot(at + Vector2(0, -18), item_id)
	game.hud.show_message("Трофей: %s! %s" % [_hero().get_item_name(item_id), effect_text(item_id)], 5.0)

## Bosses beaten whose trophy never dropped (saves from before trophies).
func missing() -> Array:
	var result: Array = []
	for kind in TROPHIES:
		if game.director.has_flag(str(kind) + "_defeated") or (kind == "guardian" and game.guardian_defeated):
			if not game.director.has_flag("trophy_" + str(kind)):
				result.append(str(kind))
	return result

# --- Effects -------------------------------------------------------------------

func _process(delta: float) -> void:
	if game == null or game.get_tree().paused or game.player == null:
		return
	_vail_left = maxf(0.0, _vail_left - delta)
	_bog_cooldown = maxf(0.0, _bog_cooldown - delta)
	if not wears("heartwood_bark"):
		rooted = false
		return
	var moving := _hero().velocity.length() > 8.0
	_still = 0.0 if moving else _still + delta
	var was := rooted
	rooted = _still >= 1.0
	if rooted and not was:
		Vfx.burst(game, _hero().global_position + Vector2(0, 6), [Color(0.55, 0.85, 0.4), Color(0.4, 0.3, 0.2, 0)], 10, 30.0, 0.4)
	if rooted:
		_root_tick += delta
		if _root_tick >= 1.0:
			_root_tick = 0.0
			_hero().heal(maxi(1, roundi(_hero().max_health * 0.01)))

func damage_reduction() -> float:
	return 0.25 if rooted and wears("heartwood_bark") else 0.0

## Damage multiplier of a sword blow before it lands.
func strike_mult(enemy: SlimeEnemy) -> float:
	var mult := 1.0
	if wears("vail_cloak") and _vail_left > 0.0:
		_vail_left = 0.0
		mult *= 1.8
		if enemy != null:
			enemy.combat_feedback.show_reaction("ТЕНЬ!")
	if wears("ash_brand") and enemy != null and enemy.burn_time_left > 0.0:
		mult *= 1.2
	if wears("titan_core"):
		mult *= 1.0 + 0.02 * float(heat)
	if wears("pattern_tuner") and _last_attack == "spell":
		mult *= 1.3
	return mult

func on_strike(enemy: SlimeEnemy, damage: int, crit: bool) -> void:
	_last_attack = "melee"
	if enemy == null or not is_instance_valid(enemy):
		return
	_hits += 1
	var alive := enemy.health > 0
	if wears("echo_prism") and crit:
		for other in game._living_enemies():
			if other != enemy and other.global_position.distance_to(enemy.global_position) < 70.0:
				other.take_damage(maxi(1, damage / 2))
		game._ring(enemy.global_position, 70.0, Color(0.7, 0.85, 1.0, 0.8))
	if wears("bog_signet") and _bog_cooldown <= 0.0 and (enemy.burn_time_left > 0.0 or enemy.slow_time_left > 0.0):
		_bog_cooldown = 0.5
		_hero().heal(maxi(1, roundi(_hero().max_health * 0.02)))
	if wears("giant_fist") and alive and _hits % 5 == 0:
		enemy.apply_slow(0.05, 1.0)
		enemy.apply_knockback((enemy.global_position - _hero().global_position).normalized(), 320.0)
		enemy.combat_feedback.show_reaction("ОГЛУШЁН!")
		game.shake(3.0, 0.15)
	if wears("ash_brand") and alive and is_instance_valid(enemy) and _hits % 3 == 0:
		enemy.apply_burning(3 + _hero().level / 2, 3.0)
	if wears("shade_shard") and _hits % 3 == 0:
		var target: SlimeEnemy = null
		var best := 120.0
		for other in game._living_enemies():
			var d: float = other.global_position.distance_to(_hero().global_position)
			if other != enemy and d < best:
				best = d
				target = other
		if target == null and is_instance_valid(enemy) and enemy.health > 0:
			target = enemy
		if target != null:
			target.take_damage(maxi(1, roundi(damage * 0.6)))
			game._streak(_hero().global_position + Vector2(0, -8), target.global_position + Vector2(0, -8), Color(0.45, 0.3, 0.7), 2.0)

## Damage of a spell before it flies (pattern tuner).
func spell_damage(damage: int) -> int:
	var mult := 1.3 if wears("pattern_tuner") and _last_attack == "melee" else 1.0
	_last_attack = "spell"
	return roundi(float(damage) * mult)

func on_kill() -> void:
	if wears("crypt_lantern"):
		var hero := _hero()
		hero.mana = mini(hero.max_mana, hero.mana + 6)
		hero.stats_changed.emit()
		hero.heal(maxi(1, roundi(hero.max_health * 0.02)))
	if wears("vail_cloak"):
		_vail_left = 3.0

func on_blocked(stopped: int) -> void:
	var source := _hero().last_attacker
	if wears("crab_king_shell") and stopped > 0 and source != null and is_instance_valid(source) and source != _hero() and source.has_method("take_damage"):
		source.call_deferred("take_damage", maxi(1, roundi(float(stopped) * 0.6)))

func on_hurt() -> void:
	if wears("titan_core"):
		heat = mini(10, heat + 1)

func on_dodge() -> void:
	if wears("titan_core") and heat >= 5:
		var blast := 6 + _hero().level + heat * 2
		for other in game._living_enemies():
			if other.global_position.distance_to(_hero().global_position) < 60.0:
				other.take_elemental_damage(blast, "fire")
		game._ring(_hero().global_position, 60.0, Color(1.0, 0.55, 0.2))
		game.shake(3.0, 0.2)
		heat = 0
	if wears("tempest_eye"):
		_whirl(_hero().global_position, 4)

func _whirl(at: Vector2, pulses: int) -> void:
	if pulses <= 0 or not is_inside_tree():
		return
	var hit := 4 + _hero().level / 2
	for other in game._living_enemies():
		if other.global_position.distance_to(at) < 48.0:
			other.take_damage(hit)
			if is_instance_valid(other) and other.health > 0:
				other.apply_slow(0.6, 0.6)
	game._ring(at, 48.0, Color(0.75, 0.9, 1.0, 0.7))
	get_tree().create_timer(0.5).timeout.connect(func() -> void: _whirl(at, pulses - 1))
