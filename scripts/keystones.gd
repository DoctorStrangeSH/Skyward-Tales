extends Node
class_name Keystones

## Этап 23: key talents ("ключевые таланты"). At levels 5, 10 and 15 the
## hero picks one of three — each changes how a fight is played, not just a
## number. The pick is kept on the hero (PlayerCharacter.keystones, saved),
## shown in the skill tree, and given back by the skill reset.

const TIERS := {
	5: {"title": "Путь клинка", "ids": ["berserk", "duelist", "spellblade"]},
	10: {"title": "Путь крови", "ids": ["vampire", "guardian", "headhunter"]},
	15: {"title": "Путь легенды", "ids": ["bladestorm", "unstoppable", "fortune"]},
}
const INFO := {
	"berserk": ["Берсерк", "Чем меньше здоровья, тем сильнее удар: до +50% урона клинком у самой черты."],
	"duelist": ["Дуэлянт", "После переката следующий удар — всегда критический. Танцуйте вокруг врага."],
	"spellblade": ["Клинок-чародей", "Удар клинком возвращает 2 маны; попавшее заклинание делает следующий удар на 60% сильнее."],
	"vampire": ["Вампир", "Каждый удар клинком лечит 5% нанесённого урона. Но зелья здоровья лечат вдвое слабее."],
	"guardian": ["Страж", "Окно парирования шире; парирование бьёт волной вокруг героя и оглушает всех рядом."],
	"headhunter": ["Охотник за головами", "+30% урона по элите и боссам; поверженная элита роняет ещё одну вещь."],
	"bladestorm": ["Буря клинков", "Каждый 5-й удар выпускает вперёд волну стали: она режет всех на линии."],
	"unstoppable": ["Неудержимый", "Победа лечит 6% здоровья; пока серия ударов 10 и больше — входящий урон −25%."],
	"fortune": ["Баловень судьбы", "+35% золота и +15% опыта за врагов; клады и сундуки щедрее."],
}

var game: SkywardGame
var _sure_crit: bool = false
var _empowered: bool = false
var _strikes: int = 0
var _offer_clock: float = 1.0

func _player() -> PlayerCharacter:
	return game.player

func has(id: String) -> bool:
	return game != null and game.player != null and game.player.has_keystone(id)

static func name_of(id: String) -> String:
	return str(INFO.get(id, [id, ""])[0])

static func text_of(id: String) -> String:
	return str(INFO.get(id, ["", ""])[1])

## Tiers reached and not chosen yet, lowest first.
func pending() -> Array:
	var result: Array = []
	var tiers := TIERS.keys()
	tiers.sort()
	for tier in tiers:
		if _player().level >= int(tier) and not _player().keystones.has(str(tier)):
			result.append(int(tier))
	return result

func choose(tier: int, id: String) -> bool:
	if not TIERS.has(tier) or not id in TIERS[tier]["ids"] or _player().keystones.has(str(tier)) or _player().level < tier:
		return false
	_player().keystones[str(tier)] = id
	_player().stats_changed.emit()
	game.hud.show_title_card("Ключевой талант: %s" % name_of(id), 2.6)
	game.hud.show_message(text_of(id), 5.0)
	GameAudio.play("level_up", -4.0, 0.2)
	Vfx.level_up(game, _player().global_position)
	game.achievements.set_max("keystones", _player().keystones.size())
	game.request_autosave()
	return true

## The choice: three cards in the dialogue box.
func offer(tier: int) -> void:
	var info: Dictionary = TIERS[tier]
	var choices: Array[Dictionary] = []
	for id in info["ids"]:
		choices.append({"id": "keystone:%d:%s" % [tier, id], "label": "%s — %s" % [name_of(str(id)), text_of(str(id))]})
	choices.append({"id": "keystone_later", "label": "Подумать позже (T — дерево навыков)"})
	game._show_dialogue_choices("Уровень %d · %s" % [tier, str(info["title"])], "Ключевой талант меняет то, как вы сражаетесь. Выбор один из трёх; сменить его можно сбросом навыков у дерева (T).", choices)

func handle_choice(choice_id: String) -> bool:
	if choice_id == "keystone_later":
		game.dialogues._close()
		return true
	if not choice_id.begins_with("keystone:"):
		return false
	var parts := choice_id.split(":")
	game.dialogues._close()
	choose(int(parts[1]), parts[2])
	return true

func _process(delta: float) -> void:
	if game == null or game.player == null or game.get_tree().paused:
		return
	_offer_clock -= delta
	if _offer_clock > 0.0:
		return
	_offer_clock = 1.0
	# Offered once per tier, in a quiet moment (not in a fight or a talk).
	var waiting := pending()
	if waiting.is_empty() or game.hud.dialogue_visible or game.story.active or game.in_danger():
		return
	var tier := int(waiting[0])
	if _player().keystone_offered.has(str(tier)):
		return
	_player().keystone_offered[str(tier)] = true
	offer(tier)

# --- Effects (hooks from HeroCombat, GearEffects, SkywardGame) ----------------

## Multiplier of a sword blow against this enemy.
func strike_mult(enemy: SlimeEnemy) -> float:
	var mult := 1.0
	var hero := _player()
	if has("berserk"):
		mult *= 1.0 + 0.5 * clampf(1.0 - float(hero.health) / float(maxi(1, hero.max_health)), 0.0, 1.0)
	if has("spellblade") and _empowered:
		_empowered = false
		mult *= 1.6
	if has("headhunter") and enemy != null and (enemy.combat_feedback.elite or SkywardGame.STORY_BOSSES.has(SkywardGame.enemy_kind(enemy))):
		mult *= 1.3
	return mult

## Duelist: the blow after a roll is a sure critical.
func take_sure_crit() -> bool:
	if has("duelist") and _sure_crit:
		_sure_crit = false
		return true
	return false

func on_dodge() -> void:
	if has("duelist"):
		_sure_crit = true

func on_spell_hit() -> void:
	if has("spellblade"):
		_empowered = true

func on_strike(enemy: SlimeEnemy, damage: int) -> void:
	var hero := _player()
	_strikes += 1
	if has("spellblade") and hero.mana < hero.max_mana:
		hero.mana = mini(hero.max_mana, hero.mana + 2)
		hero.stats_changed.emit()
	if has("vampire"):
		hero.heal(maxi(1, roundi(float(damage) * 0.05)))
	if has("bladestorm") and _strikes % 5 == 0:
		_blade_wave(roundi(float(damage) * 0.8))

func _blade_wave(damage: int) -> void:
	var hero := _player()
	var origin := hero.global_position + Vector2(0, -8)
	var direction := hero.facing.normalized()
	var reach := 130.0
	for other in game._living_enemies():
		var offset: Vector2 = other.global_position + Vector2(0, -8) - origin
		var along := offset.dot(direction)
		if along < 0.0 or along > reach:
			continue
		if absf(offset.cross(direction)) > 22.0 or game.combat.wall_between(origin, other.global_position):
			continue
		other.take_damage(damage)
		if is_instance_valid(other) and other.health > 0:
			other.apply_knockback(direction, 120.0)
	game._streak(origin, origin + direction * reach, Color(0.85, 0.95, 1.0, 0.9), 4.0)
	GameAudio.play("dash", -6.0, 0.4)

func on_parry() -> void:
	if not has("guardian"):
		return
	var hero := _player()
	for other in game._living_enemies():
		if other.global_position.distance_to(hero.global_position) < 72.0:
			other.take_damage(maxi(4, roundi(hero.get_melee_damage() * 0.7)))
			if is_instance_valid(other) and other.health > 0:
				other.apply_slow(0.05, 1.2)
				other.combat_feedback.show_reaction("ОГЛУШЁН!")
	game._ring(hero.global_position, 72.0, Color(1.0, 0.9, 0.55))

func on_kill(elite: bool, at: Vector2) -> void:
	var hero := _player()
	if has("unstoppable"):
		hero.heal(maxi(1, roundi(hero.max_health * 0.06)))
	if has("headhunter") and elite:
		game.spawn_generated_loot(at + Vector2(10, 6), "rare")

## Incoming damage share kept off (Unstoppable on a streak).
func damage_reduction() -> float:
	return 0.25 if has("unstoppable") and game.gear != null and game.gear.streak >= 10 else 0.0

func xp_mult() -> float:
	return 1.15 if has("fortune") else 1.0

func gold_mult() -> float:
	return 1.35 if has("fortune") else 1.0
