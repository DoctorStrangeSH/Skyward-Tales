extends Node
class_name CombatSkills

## Hotbar skills (keys 1–4) from data/skills.json: sword techniques unlock by
## level, spells once magic awakens. Cooldowns live here; the hit logic
## reuses the sword helpers in main.gd (crits, lifesteal, knockback).

var game: SkywardGame
var cooldowns: Dictionary = {}
var totals: Dictionary = {}

static func actives() -> Dictionary:
	return GameCatalogs.shared().skills.get("active", {})

static func passives() -> Dictionary:
	return GameCatalogs.shared().skills.get("passive", {})

static func definition(skill_id: String) -> Dictionary:
	return actives().get(skill_id, {})

static func is_spell(skill_id: String) -> bool:
	return bool(definition(skill_id).get("spell", false))

static func icon_path(skill_id: String) -> String:
	return "icons/skill_%s.png" % skill_id

## Why the skill can't be used yet ("" when it can).
func lock_reason(skill_id: String) -> String:
	var data := definition(skill_id)
	if data.is_empty():
		return "Пусто"
	if is_spell(skill_id):
		return "" if game.magic_unlocked() else "Магия спит"
	var needed := int(data.get("level", 1))
	return "" if game.player.level >= needed else "Ур. %d" % needed

func cooldown_left(skill_id: String) -> float:
	if is_spell(skill_id):
		return game.cast_cooldown_remaining if game.selected_spell_id == skill_id else 0.0
	return float(cooldowns.get(skill_id, 0.0))

## 0 = ready, 1 = just used.
func cooldown_ratio(skill_id: String) -> float:
	var total := float(totals.get(skill_id, 0.0))
	if is_spell(skill_id):
		total = game.cast_cooldown_total
	return 0.0 if total <= 0.0 else clampf(cooldown_left(skill_id) / total, 0.0, 1.0)

func _process(delta: float) -> void:
	for skill_id in cooldowns.keys():
		cooldowns[skill_id] = maxf(0.0, float(cooldowns[skill_id]) - delta)

func use_slot(index: int) -> bool:
	var slots: Array = game.player.skill_slots
	if index < 0 or index >= slots.size():
		return false
	return use(str(slots[index]))

func use(skill_id: String) -> bool:
	var player := game.player
	if skill_id.is_empty() or player.health <= 0:
		return false
	var reason := lock_reason(skill_id)
	if not reason.is_empty():
		game.hud.show_message("%s: %s" % [str(definition(skill_id).get("name", skill_id)), "откроется на уровне %s" % reason.trim_prefix("Ур. ") if reason.begins_with("Ур.") else reason.to_lower()], 1.8)
		return false
	if is_spell(skill_id):
		game.selected_spell_id = skill_id
		var mana := player.mana
		game._cast_spell()
		return player.mana < mana
	if cooldown_left(skill_id) > 0.0:
		return false
	var data := definition(skill_id)
	var ok := false
	match skill_id:
		"lunge":
			ok = _lunge(data)
		"shockwave":
			ok = _shockwave(data)
		"war_cry":
			ok = _war_cry(data)
		"blade_wave":
			ok = _blade_wave(data)
	if ok:
		var total := float(data.get("cooldown", 5.0)) * player.get_skill_cooldown_multiplier()
		cooldowns[skill_id] = total
		totals[skill_id] = total
	return ok

func _damage(data: Dictionary) -> int:
	return int(round(game.player.get_melee_damage() * float(data.get("damage_mult", 1.0))))

func _lunge(data: Dictionary) -> bool:
	var player := game.player
	var direction := game._aim_direction()
	var start := player.global_position
	player.facing = direction
	player.visual.set_direction_vector(direction)
	player.visual.play_named("slash2", 0.3)
	var reach := float(data.get("reach", 72))
	for _step in 8:
		if player.move_and_collide(direction * reach / 8.0) != null:
			break
	var travelled := player.global_position - start
	game._line_hit(start, direction, maxf(travelled.length(), 24.0) + 14.0, 16.0, _damage(data), 120.0)
	Vfx.burst(game, start.lerp(player.global_position, 0.5), [Color(1, 1, 1), Color(1.0, 0.9, 0.7), Color(1, 1, 1, 0)], 10, 50.0, 0.3)
	game._streak(start, player.global_position, Color(1, 1, 1, 0.85), 5.0)
	GameAudio.play("dash", -3.0, 0.08)
	return true

func _shockwave(data: Dictionary) -> bool:
	var player := game.player
	player.visual.play_named("spin", 0.4)
	var stun := float(data.get("stun", 1.2)) + (1.0 if player.has_skill("unbreakable") else 0.0)
	var hit := game._melee_hit(player.global_position, Vector2.RIGHT, float(data.get("radius", 56)), 360.0, _damage(data), 140.0)
	for enemy in game.last_hit_enemies:
		if is_instance_valid(enemy) and enemy.health > 0:
			enemy.apply_slow(0.05, stun)
	Vfx.burst(game, player.global_position + Vector2(0, 6), [Color(0.95, 0.85, 0.6), Color(0.7, 0.55, 0.35), Color(0.5, 0.4, 0.3, 0)], 22, 110.0, 0.45)
	game._ring(player.global_position, float(data.get("radius", 56)), Color(1.0, 0.9, 0.6, 0.8))
	game.shake(3.0 if hit > 0 else 1.5, 0.25)
	GameAudio.play("hit", -2.0, 0.05)
	return true

func _war_cry(data: Dictionary) -> bool:
	var player := game.player
	player.add_buff("power", float(data.get("power", 0.3)), float(data.get("duration", 8.0)), "Клич")
	player.visual.play_named("charge", 0.5)
	game._ring(player.global_position, 34.0, Color(1.0, 0.45, 0.3, 0.8))
	Vfx.burst(game, player.global_position + Vector2(0, -8), [Color(1, 0.95, 0.7), Color(1.0, 0.5, 0.3), Color(0.8, 0.2, 0.2, 0)], 16, 70.0, 0.5)
	GameAudio.play("level_up", -8.0, 0.1)
	game.hud.show_message("Боевой клич! +%d%% урона." % roundi(float(data.get("power", 0.3)) * 100.0), 1.8)
	return true

func _blade_wave(data: Dictionary) -> bool:
	var player := game.player
	var direction := game._aim_direction()
	player.facing = direction
	player.visual.set_direction_vector(direction)
	player.visual.play_named("slash1", 0.28)
	var reach := float(data.get("reach", 130))
	game._line_hit(player.global_position, direction, reach, float(data.get("width", 20)), _damage(data), 90.0)
	game._streak(player.global_position + direction * 10.0, player.global_position + direction * reach, Color(0.8, 0.95, 1.0, 0.9), 8.0)
	GameAudio.play("gust", -4.0, 0.08)
	return true

## Entries for the HUD hotbar: four skills, then dodge and the potions.
func hotbar_entries() -> Array:
	var player := game.player
	var entries: Array = []
	for index in PlayerCharacter.SKILL_SLOT_COUNT:
		var skill_id := str(player.skill_slots[index]) if index < player.skill_slots.size() else ""
		var data := definition(skill_id)
		entries.append({
			"key": str(index + 1), "icon": icon_path(skill_id) if not skill_id.is_empty() else "",
			"name": str(data.get("name", "Пусто")), "cooldown": cooldown_ratio(skill_id) if not skill_id.is_empty() else 0.0,
			"locked": lock_reason(skill_id) if not skill_id.is_empty() else "", "count": -1,
		})
	var dodge_total := maxf(0.01, player.get_dodge_cooldown()) if player.has_method("get_dodge_cooldown") else 1.0
	entries.append({"key": "Sh", "icon": "icons/skill_dodge.png", "name": "Перекат", "cooldown": clampf(player.dodge_cooldown_left / dodge_total, 0.0, 1.0), "locked": "", "count": -1})
	entries.append({"key": "Q", "icon": "icons/health_potion.png", "name": "Зелье здоровья", "cooldown": 0.0, "locked": "", "count": int(player.inventory.get("health_potion", 0))})
	entries.append({"key": "R", "icon": "icons/mana_potion.png", "name": "Зелье маны", "cooldown": 0.0, "locked": "", "count": int(player.inventory.get("mana_potion", 0))})
	return entries
