extends RefCounted
class_name HeroCombat

## Split out of main.gd (Этап 18, tech debt). Every SkywardGame member is
## reached through `game`; main.gd keeps one-line wrappers with the old names.

var game: SkywardGame

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

func _update_spell_hud() -> void:
	game._update_mouse_slots()
	if game.player.has_bow() and game.hud.spell_label != null:
		var ready := game.cast_cooldown_remaining <= 0.0
		game.hud.spell_label.text = "Лук · ПКМ · удерживать — прицельный" + (" · ГОТОВО" if ready else "")
		game.hud.spell_label.modulate = Color.WHITE
		game.hud.spell_cooldown_bar.value = 1.0 - (game.cast_cooldown_remaining / game.cast_cooldown_total if game.cast_cooldown_total > 0.0 else 0.0)
		return
	if not game.magic_unlocked():
		if game.hud.spell_label != null:
			game.hud.spell_label.text = "Меч · ЛКМ · удерживать — вихрь"
			game.hud.spell_label.modulate = Color.WHITE
			game.hud.spell_cooldown_bar.value = 1.0 - game.attack_cooldown / (SkywardGame.SLASH_COOLDOWN * 2.0)
		return
	var spell: Dictionary = game.spell_definitions.get(game.selected_spell_id, {})
	game.hud.update_spell(str(spell.get("name", game.selected_spell_id)), int(spell.get("mana_cost", 0)), game.player.mana, game.cast_cooldown_remaining, game.cast_cooldown_total)

## ЛКМ / ПКМ squares on the action bar.
func _update_mouse_slots() -> void:
	var weapon := str(game.player.equipment.get("blade", ""))
	var left := {"key": "ЛКМ", "icon": ("icons/%s.png" % weapon) if not weapon.is_empty() and ResourceLoader.exists("res://assets/icons/%s.png" % weapon) else "icons/skill_slash.png",
		"name": str(game.weapon_profile()["name"]), "tooltip": "%s — ЛКМ, удерживать — вихрь" % str(game.weapon_profile()["name"]), "cooldown": clampf(game.attack_cooldown / (SkywardGame.SLASH_COOLDOWN * float(game.weapon_profile()["cooldown"])), 0.0, 1.0)}
	var right := {}
	if game.player.has_bow():
		var bow := str(game.player.equipment.get("weapon", ""))
		right = {"key": "ПКМ", "icon": "icons/%s.png" % bow, "name": "Лук", "tooltip": "Лук — ПКМ, удерживать — прицельный выстрел",
			"cooldown": game.cast_cooldown_remaining / game.cast_cooldown_total if game.cast_cooldown_total > 0.0 else 0.0}
	elif not game.magic_unlocked():
		right = {"key": "ПКМ", "icon": "icons/skill_fireball.png", "name": "Магия", "tooltip": "Магия откроется по сюжету", "locked": "✦"}
	else:
		var spell: Dictionary = game.spell_definitions.get(game.selected_spell_id, {})
		var cost := int(spell.get("mana_cost", 0))
		right = {"key": "ПКМ", "icon": CombatSkills.icon_path(game.selected_spell_id), "name": str(spell.get("name", game.selected_spell_id)),
			"tooltip": "%s — ПКМ · %d MP · колесо мыши — сменить" % [str(spell.get("name", game.selected_spell_id)), cost],
			"cooldown": game.cast_cooldown_remaining / game.cast_cooldown_total if game.cast_cooldown_total > 0.0 else 0.0,
			"note": str(cost), "count": 0 if game.player.mana < cost else -1}
	game.hud.set_mouse_slots(left, right)

## Wheel / Tab-free spell switching: walks the spells the hero can cast.
func cycle_spell(step: int) -> void:
	if not game.magic_unlocked() or game.player.has_bow():
		return
	var known: Array = []
	for spell_id in game.spell_definitions:
		if CombatSkills.definition(str(spell_id)).is_empty() or game.skills.lock_reason(str(spell_id)).is_empty():
			known.append(str(spell_id))
	if known.size() < 2:
		return
	var at := known.find(game.selected_spell_id)
	game.select_spell(str(known[posmod(at + step, known.size())]))

func select_spell(spell_id: String) -> void:
	if not game.spell_definitions.has(spell_id):
		return
	game.selected_spell_id = spell_id
	game.hud.show_message("Магия: " + str(game.spell_definitions[spell_id].get("name", spell_id)), 1.5)
	game._update_spell_hud()

func weapon_profile() -> Dictionary:
	return SkywardGame.WEAPON_PROFILES.get(game.player.weapon_kind(), SkywardGame.WEAPON_PROFILES["sword"])

func _aim_direction() -> Vector2:
	# Headless runs (tests) have no mouse: strike where the hero faces.
	if DisplayServer.get_name() == "headless":
		return game.player.facing.normalized()
	var direction := (game.get_global_mouse_position() - game.player.global_position)
	return direction.normalized() if direction.length_squared() > 1.0 else game.player.facing

func _attack_pressed() -> void:
	game._attack_holding = true
	game._attack_held = 0.0
	game.sword_slash()

func _attack_released() -> void:
	game._attack_holding = false
	if game._charging:
		game._charging = false
		game.sword_spin()

func _update_sword(delta: float) -> void:
	game.attack_cooldown = maxf(0.0, game.attack_cooldown - delta)
	game._combo_timer = maxf(0.0, game._combo_timer - delta)
	if game._combo_timer <= 0.0:
		game._combo_step = 0
	if game._attack_holding and not game._charging:
		game._attack_held += delta
		if game._attack_held >= SkywardGame.CHARGE_TIME - 0.15 * float(game.player.talents.get("whirl_master", 0)) and game.player.health > 0:
			game._charging = true
			game.player.visual.play_named("charge", 30.0)
			Vfx.sparkle(game, game.player.global_position + Vector2(0, -8))

## Two-hit combo in front of the hero (towards the mouse).
func sword_slash() -> bool:
	if game.attack_cooldown > 0.0 or game.player.health <= 0 or game.player.dodge_time_left > 0.0:
		return false
	var direction := game._aim_direction()
	game.player.facing = direction
	game.player.visual.set_direction_vector(direction)
	var finisher := game._combo_step == 2
	var anim := "spin" if finisher else ("slash1" if game._combo_step == 0 else "slash2")
	game.player.visual.play_named(anim, 0.36 if finisher else 0.28)
	var damage := game.player.get_melee_damage() + (2 if game._combo_step == 1 else 0)
	var hits := 0
	if finisher:
		# Blade Dance: the third swing is a full circle at double damage.
		hits = game._melee_hit(game.player.global_position, direction, SkywardGame.SPIN_REACH, 360.0, damage * 2, 150.0)
		game._ring(game.player.global_position, SkywardGame.SPIN_REACH, Color(1.0, 0.85, 0.5, 0.8))
	else:
		var profile := game.weapon_profile()
		hits = game._melee_hit(game.player.global_position, direction, SkywardGame.SLASH_REACH * float(profile["reach"]), float(profile["arc"]), damage, float(profile["push"]))
		if game.player.weapon_kind() == "spear":
			game._streak(game.player.global_position + direction * 8.0, game.player.global_position + direction * SkywardGame.SLASH_REACH * float(profile["reach"]), Color(1, 1, 1, 0.7), 2.0)
		elif game.player.weapon_kind() == "hammer":
			if hits > 0:
				game.shake(2.0, 0.12)
				for enemy in game.last_hit_enemies:
					if is_instance_valid(enemy) and enemy.health > 0 and game.crit_rng.randf() < 0.3:
						enemy.apply_slow(0.05, 0.6)
						enemy.combat_feedback.show_reaction("ОГЛУШЁН!")
	GameAudio.play("dash" if hits == 0 else "hit", -4.0, 0.1)
	game._combo_step = (game._combo_step + 1) % (3 if game.player.has_skill("blade_dance") else 2)
	game._combo_timer = SkywardGame.COMBO_WINDOW
	game.attack_cooldown = SkywardGame.SLASH_COOLDOWN * float(game.weapon_profile()["cooldown"])
	return true

## Held attack: a full circle at 1.8x damage.
func sword_spin() -> bool:
	if game.player.health <= 0:
		return false
	game.player.visual.play_named("spin", 0.42)
	var hits := game._melee_hit(game.player.global_position, Vector2.RIGHT, SkywardGame.SPIN_REACH, 360.0, int(round(game.player.get_melee_damage() * (1.8 + 0.45 * float(game.player.talents.get("whirl_master", 0))))), 170.0)
	GameAudio.play("gust", -4.0, 0.05)
	Vfx.burst(game, game.player.global_position, [Color(1, 1, 1), Color(0.8, 0.9, 1.0)], 14, 90.0)
	if hits > 0:
		game.shake(2.5, 0.2)
	game.attack_cooldown = SkywardGame.SLASH_COOLDOWN * 2.0
	return true

func _living_enemies() -> Array:
	var result: Array = []
	for candidate in game.get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as SlimeEnemy
		if enemy != null and not enemy.is_queued_for_deletion() and enemy.health > 0:
			result.append(enemy)
	return result

## One sword blow: crit roll, lifesteal, knockback.
func _strike(enemy: SlimeEnemy, damage: int, push_direction: Vector2, push: float) -> void:
	var crit := game.crit_rng.randf() < game.player.get_crit_chance()
	if crit:
		damage *= 2
		Vfx.sparkle(game, enemy.global_position)
		game.gear.on_crit(enemy)
	var shaped := game.gear.modify_strike(damage)
	damage = int(shaped["damage"])
	if bool(shaped["riposte"]):
		enemy.combat_feedback.show_reaction("КОНТРАТАКА!")
		Vfx.sparkle(game, enemy.global_position)
		game.shake(3.0, 0.15)
	enemy.take_damage(damage)
	enemy.apply_knockback(push_direction, push)
	game.last_hit_enemies.append(enemy)
	game.combos.on_strike(enemy, damage)
	game.gear.on_strike(enemy, damage)
	var heal := game.player.get_melee_lifesteal()
	if heal > 0 and game.player.health < game.player.max_health:
		game.player.health = mini(game.player.max_health, game.player.health + heal)
		game.player.stats_changed.emit()

## Damages enemies within reach and the arc (degrees); returns how many.
func _melee_hit(origin: Vector2, direction: Vector2, reach: float, arc: float, damage: int, push: float) -> int:
	game.last_hit_enemies.clear()
	for enemy in game._living_enemies():
		var offset: Vector2 = enemy.global_position - origin
		if offset.length() > reach + 8.0:
			continue
		if arc < 360.0 and offset.length() > 4.0 and rad_to_deg(absf(direction.angle_to(offset))) > arc * 0.5:
			continue
		game._strike(enemy, damage, offset.normalized() if offset.length() > 0.1 else direction, push)
	return game.last_hit_enemies.size()

## Damages enemies in a strip in front of origin (lunge, blade wave).
func _line_hit(origin: Vector2, direction: Vector2, length: float, width: float, damage: int, push: float) -> int:
	game.last_hit_enemies.clear()
	for enemy in game._living_enemies():
		var offset: Vector2 = enemy.global_position - origin
		var along := offset.dot(direction)
		if along < -6.0 or along > length:
			continue
		if absf(offset.cross(direction)) > width * 0.5 + 8.0:
			continue
		game._strike(enemy, damage, direction, push)
	return game.last_hit_enemies.size()

## Short-lived white streak (lunge path, blade wave).
func _streak(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = width
	line.default_color = color
	line.z_index = 30
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	game.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)

## Expanding ring (shockwave, war cry, blade dance).
func _ring(at: Vector2, radius: float, color: Color) -> void:
	var line := Line2D.new()
	var points := PackedVector2Array()
	for index in 25:
		points.append(Vector2.RIGHT.rotated(TAU * index / 24.0) * radius)
	line.points = points
	line.width = 2.0
	line.default_color = color
	line.z_index = 30
	line.position = at
	line.scale = Vector2(0.3, 0.3 * 0.6)
	game.add_child(line)
	var tween := line.create_tween()
	tween.set_parallel(true)
	tween.tween_property(line, "scale", Vector2(1.0, 0.6), 0.25)
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(line.queue_free)

## Puts a newly awakened spell into an empty or still-locked hotbar slot.
func _place_spell_on_hotbar(spell_id: String) -> void:
	if game.player.skill_slots.has(spell_id):
		return
	for index in game.player.skill_slots.size():
		var current := str(game.player.skill_slots[index])
		if current.is_empty() or not game.skills.lock_reason(current).is_empty():
			game.player.assign_skill(index, spell_id)
			return
	game.player.assign_skill(PlayerCharacter.SKILL_SLOT_COUNT - 1, spell_id)

## Story mode: the heroine starts with the sword; Ilara awakens her magic
## once the grove guardian falls. Free play (tests) has magic from the start.
func magic_unlocked() -> bool:
	return not game.director.story_mode() or game.director.has_flag("magic_unlocked")

func _bow_press() -> void:
	if game.cast_cooldown_remaining > 0.0 or game.player.health <= 0:
		return
	game._bow_holding = true
	game._bow_held = 0.0
	game.player.visual.play_named("charge", 30.0)

func _update_bow(delta: float) -> void:
	if not game._bow_holding:
		return
	var before := game._bow_held
	game._bow_held += delta
	if before < SkywardGame.AIM_TIME and game._bow_held >= SkywardGame.AIM_TIME:
		Vfx.sparkle(game, game.player.global_position + Vector2(0, -10))

func _bow_release() -> void:
	if not game._bow_holding:
		return
	game._bow_holding = false
	var aimed := game._bow_held >= SkywardGame.AIM_TIME
	var damage := game.player.get_ranged_damage() * (2 if aimed else 1)
	var pierce := (99 if game.player.wears_base("wind_bow") else 2) if aimed else 0
	game.shoot_arrow(game._aim_direction(), damage, aimed, pierce)
	game.player.play_cast(game._aim_direction())
	GameAudio.play("dash", -6.0 if not aimed else -2.0, 0.2)
	game.cast_cooldown_total = SkywardGame.BOW_COOLDOWN * (1.6 if aimed else 1.0)
	game.cast_cooldown_remaining = game.cast_cooldown_total
	game._update_spell_hud()

func shoot_arrow(direction: Vector2, damage: int, aimed: bool, pierce: int = 0) -> Arrow:
	var arrow := Arrow.new()
	arrow.setup(game, direction, damage, pierce, aimed)
	game.add_child(arrow)
	arrow.global_position = game.player.global_position + direction.normalized() * 10.0
	return arrow

func _cast_spell() -> void:
	if not game.magic_unlocked():
		game.hud.show_message("Магия ещё спит. Пока — меч: ЛКМ, удерживать — круговой удар.", 2.5)
		return
	if game.cast_cooldown_remaining > 0.0:
		return
	var spell: Dictionary = game.spell_definitions.get(game.selected_spell_id, {})
	var mana_cost := int(spell.get("mana_cost", 8))
	var spell_damage := roundi((int(spell.get("damage", 18)) + game.player.get_spell_bonus(game.selected_spell_id)) * game.player.get_spell_power_multiplier())
	if not game.player.spend_mana(mana_cost):
		game.hud.show_message("Недостаточно маны.", 1.2)
		return
	var direction := (game.get_global_mouse_position() - game.player.global_position).normalized()
	if direction.length_squared() < 0.01:
		direction = game.player.facing
	var bolt := SkywardGame.BOLT_SCENE.instantiate() as MagicBolt
	if bolt == null:
		push_error("Не удалось создать снаряд заклинания")
		return
	bolt.speed = float(spell.get("projectile_speed", 255))
	bolt.setup(direction, spell_damage)
	bolt.configure_effect(game.selected_spell_id, float(spell.get("slow_multiplier", 1.0)), float(spell.get("slow_duration", 0.0)) + game.player.get_slow_duration_bonus())
	bolt.configure_burning(int(spell.get("burn_damage", 0)) + game.player.get_burn_damage_bonus(), float(spell.get("burn_duration", 0.0)))
	bolt.chain_targets = int(spell.get("chain_targets", 0)) + game.player.get_chain_targets_bonus()
	bolt.chain_radius = float(spell.get("chain_radius", 0.0))
	bolt.chain_damage_factor = float(spell.get("chain_damage_factor", 0.65))
	if game.selected_spell_id == "fireball" and game.player.has_skill("fire_ultimate"):
		bolt.explode_radius = 48.0
	if game.selected_spell_id == "frostbolt" and game.player.has_skill("ice_ultimate"):
		bolt.pierce_left = 2
		bolt.freeze_on_hit = true
	if game.selected_spell_id == "chain_lightning" and game.player.has_skill("storm_ultimate"):
		bolt.chain_damage_factor = 1.0
	game.add_child(bolt)
	bolt.global_position = game.player.global_position + direction * 12.0
	game.player.play_cast(direction)
	GameAudio.play({"fireball": "cast_fire", "frostbolt": "cast_ice", "chain_lightning": "cast_lightning"}.get(game.selected_spell_id, "cast_fire"), -5.0)
	game.cast_cooldown_total = float(spell.get("cooldown", 0.25)) * game.player.get_cooldown_multiplier()
	game.cast_cooldown_remaining = game.cast_cooldown_total
	game._update_spell_hud()
