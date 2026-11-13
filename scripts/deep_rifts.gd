extends Node
class_name DeepRifts

## Этап 18: the deep rifts of the Pattern — the endless post-game ladder.
## After the Shadow of the Pattern falls, Soren speaks of a rift that will
## not close: it opens a level deeper each time, somewhere else in the
## lands of the old rifts. Touch it: two waves of echoes, ever stronger (more
## elites, more health and harm); every 5th depth the Devourer of the
## Pattern itself comes out (BossMechanics "devourer"). Each sealed depth
## pays more; the best depth is remembered.

const UNLOCK := "post_shadow"
const BOSS_EVERY := 5

var game: SkywardGame
var depth: int = 1
var best: int = 0
var region: String = ""
var _rift: PatternRift
var _wave: Array = []
var _wave_no: int = 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func unlocked() -> bool:
	return game.quests.is_completed(UNLOCK)

func boss_depth() -> bool:
	return depth % BOSS_EVERY == 0

func _choose_region(exclude: String = "") -> String:
	var lands: Array = game.epilogue.rifts.keys().filter(func(r: Variant) -> bool: return str(r) != exclude)
	if lands.is_empty():
		return "moonlit_grove"
	return str(lands[rng.randi_range(0, lands.size() - 1)])

func ensure_region() -> void:
	if region.is_empty():
		region = _choose_region()

## Spawns the rift when the hero is in its land (called on region populate).
func populate() -> void:
	_rift = null
	_wave.clear()
	_wave_no = 0
	if not unlocked():
		return
	ensure_region()
	if game.current_region != region:
		return
	var pos: Array = game.epilogue.rifts[region]
	var rift := PatternRift.new()
	rift.region_id = region
	rift.add_to_group("region_actor")
	rift.scale = Vector2(1.5, 1.5)
	rift.modulate = Color(1.0, 0.6, 0.75)
	game.add_child(rift)
	# Beside the old (sealed) rift.
	rift.global_position = Vector2(float(pos[0]) + 60.0, float(pos[1]) + 40.0)
	rift.touched.connect(_on_touched)
	_rift = rift

func _on_touched(rift: PatternRift) -> void:
	rift.wake()
	_wave_no = 0
	game.hud.show_title_card("Глубокий разлом · глубина %d" % depth, 2.0)
	_next_wave()

func power() -> float:
	return 1.0 + 0.15 * float(depth - 1)

func _next_wave() -> void:
	_wave_no += 1
	_wave.clear()
	if _rift == null or not is_instance_valid(_rift):
		return
	var at0 := _rift.global_position
	if _wave_no == 2 and boss_depth():
		_spawn_devourer(at0 + Vector2(0, -30))
		return
	var kinds := game.epilogue._local_kinds()
	var gap := maxi(0, game.player.level - RegionCatalog.level(game.current_region))
	var count := 4 + mini(3, depth / 3) + (1 if _wave_no == 2 else 0)
	for i in count:
		var at := at0 + Vector2.RIGHT.rotated(TAU * i / count + 0.3) * 56.0
		var kind := str(kinds[i % kinds.size()])
		var elite := ""
		if EliteModifiers.can_be_elite(kind) and rng.randf() < minf(0.85, 0.2 + 0.05 * depth):
			elite = EliteModifiers.pick(rng)
		game.self_scaled_spawn = true
		var echo := game.spawn_enemy(kind, at, elite)
		game.self_scaled_spawn = false
		if echo == null:
			continue
		echo.set_meta("rift_echo", true)
		echo.max_health = roundi(echo.max_health * (1.6 + 0.12 * gap) * power())
		echo.health = echo.max_health
		echo.attack_damage = roundi(echo.attack_damage * (1.25 + 0.06 * gap) * (1.0 + 0.08 * (depth - 1)))
		echo.xp_reward = roundi(echo.xp_reward * (2.0 + 0.2 * depth))
		echo.base_visual_tint = Color(1.0, 0.62, 0.8)
		echo.visual.modulate = echo.base_visual_tint
		echo.combat_feedback.set_health(echo.health, echo.max_health)
		echo.defeated.connect(func(_xp: int) -> void: _on_down(echo))
		_wave.append(echo)
		Vfx.sparkle(game, at)
	game.shake(3.0, 0.3)
	GameAudio.play("boss_roar", -10.0, 0.0)
	game.hud.show_message("Волна %d из 2!" % _wave_no, 2.0)
	if _wave.is_empty():
		_on_wave_cleared()

func _spawn_devourer(at: Vector2) -> void:
	game.self_scaled_spawn = true
	var boss := game.spawn_enemy("shade", at)
	game.self_scaled_spawn = false
	if boss == null:
		_on_wave_cleared()
		return
	boss.set_meta("rift_echo", true)
	boss.set_meta("devourer", true)
	boss.max_health = roundi(boss.max_health * 9.0 * power())
	boss.health = boss.max_health
	boss.attack_damage = roundi(boss.attack_damage * 1.6 * (1.0 + 0.08 * (depth - 1)))
	boss.xp_reward = roundi(boss.xp_reward * 10.0)
	boss.knockback_resist = maxf(boss.knockback_resist, 0.9)
	boss.visual.scale *= 2.0
	boss.combat_feedback.elite = true
	boss.combat_feedback.elite_name = "♦ Пожиратель Узора"
	boss.combat_feedback.elite_color = Color(1.0, 0.55, 0.85)
	boss.combat_feedback.bar_y *= 2.0
	boss.base_visual_tint = Color(1.0, 0.55, 0.85)
	boss.visual.modulate = boss.base_visual_tint
	boss.combat_feedback.set_health(boss.health, boss.max_health)
	BossMechanics.attach(boss, game, "devourer")
	boss.defeated.connect(func(_xp: int) -> void:
		game.achievements.add("devourer")
		_on_down(boss))
	_wave.append(boss)
	game.hud.show_title_card("Пожиратель Узора", 2.5)
	GameAudio.play("boss_roar", -2.0, 0.0)

func _on_down(echo: SlimeEnemy) -> void:
	_wave.erase(echo)
	var alive := _wave.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as SlimeEnemy).is_queued_for_deletion() and (e as SlimeEnemy).health > 0)
	if alive.is_empty():
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	if _wave_no < 2:
		_next_wave.call_deferred()
		return
	seal()

func seal() -> void:
	var at := _rift.global_position if _rift != null and is_instance_valid(_rift) else game.player.global_position
	if _rift != null and is_instance_valid(_rift):
		_rift.queue_free()
	_rift = null
	var sealed := depth
	Vfx.burst(game, at, [Color(1, 0.8, 0.9), Color(0.9, 0.5, 1.0), Color(0.4, 0.2, 0.7, 0)], 30, 110.0, 0.7)
	game._spawn_loot(at, "pattern_shard").amount = 1 + sealed / 3
	game._spawn_loot(at + Vector2(14, 6), "gold").amount = roundi(80.0 * sealed * game.epilogue.gold_mult())
	if rng.randf() < minf(0.9, 0.3 + 0.05 * sealed):
		game.spawn_generated_loot(at + Vector2(-14, 8), "epic")
	if sealed % BOSS_EVERY == 0:
		game.spawn_generated_loot(at + Vector2(0, 18), "legendary")
		game._spawn_loot(at + Vector2(0, -16), "starlight_essence").amount = 1
	best = maxi(best, sealed)
	depth = sealed + 1
	game.achievements.set_max("deep_rift", best)
	region = _choose_region(game.current_region)
	game.hud.show_message("Глубина %d запечатана! Разлом ушёл глубже — теперь он в землях «%s» (глубина %d)." % [sealed, RegionCatalog.display_name(region), depth], 4.5)
	GameAudio.play("quest", -2.0, 0.0)
	game.request_autosave()

func minimap_marker() -> Array:
	if _rift != null and is_instance_valid(_rift) and not _rift.awake:
		return [{"kind": "rift", "position": _rift.global_position}]
	return []

func targets() -> Array:
	if not unlocked():
		return []
	ensure_region()
	var pos: Array = game.epilogue.rifts.get(region, [0, 0])
	return [{"region": region, "position": Vector2(float(pos[0]) + 60.0, float(pos[1]) + 40.0), "kind": "side", "title": "Глубокий разлом · %d" % depth}]

## Soren's words once the deep rifts open.
func herald_line() -> String:
	ensure_region()
	return "Тень повержена, но один разлом не закрывается — он уходит глубже. Сейчас он в землях «%s», глубина %d. Лучшая глубина: %d. Каждые пять уровней из него лезет Пожиратель Узора." % [RegionCatalog.display_name(region), depth, best]

func make_snapshot() -> Dictionary:
	return {"depth": depth, "best": best, "region": region}

func restore_snapshot(value: Variant) -> void:
	depth = 1
	best = 0
	region = ""
	if value is Dictionary:
		depth = maxi(1, int(value.get("depth", 1)))
		best = int(value.get("best", 0))
		region = str(value.get("region", ""))
