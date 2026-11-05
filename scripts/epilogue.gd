extends Node
class_name Epilogue

## The world after the finale. The hero's choice stays visible:
## "restore" (Живое небо) — aurora of the lit Pattern at night, golden
##   threads drifting up by day, +10% experience;
## "lower" (Звёзды над землёй) — shooting stars every night, +15% gold.
## Post-game quests from Soren the herald: close six Pattern rifts
## (data/epilogue.json), then face the Shadow of the Pattern.

const PATH := "res://data/epilogue.json"
const RIFT_QUEST := "post_rifts"
const ECHO_COUNT := 4

var game: SkywardGame
var rifts: Dictionary = {}
var closed: Dictionary = {}
var sky: EpilogueSky
var motes: CPUParticles2D
var rng := RandomNumberGenerator.new()
var _wave: Array = []
var _rift: PatternRift
var _region: String = ""

func _ready() -> void:
	rng.randomize()
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			rifts = parsed.get("rifts", {})
	sky = EpilogueSky.new()
	sky.name = "EpilogueSky"
	game.add_child(sky)

## "restore", "lower" or "" before the finale.
func ending() -> String:
	if game.director.has_flag("ending_restore"):
		return "restore"
	if game.director.has_flag("ending_lower"):
		return "lower"
	return ""

func xp_mult() -> float:
	return 1.1 if ending() == "restore" else 1.0

func gold_mult() -> float:
	return 1.15 if ending() == "lower" else 1.0

func blessing_text() -> String:
	match ending():
		"restore":
			return "Благословение Узора: +10% опыта. Ночами в небе горит сияние."
		"lower":
			return "Щедрость земли: +15% золота. Ночами падают звёзды."
	return ""

func _process(_delta: float) -> void:
	if game == null or game.day_night == null:
		return
	var current := ending()
	var surface := game.day_night.cycles_here()
	sky.ending = current
	var target := 0.0
	if surface and not current.is_empty():
		target = clampf((1.0 - game.day_night.canvas.color.g) / 0.6, 0.0, 1.0)
	sky.night = target
	var want_motes := current == "restore" and surface
	if _region != game.current_region or (motes != null) != want_motes:
		_region = game.current_region
		_rebuild_motes(want_motes)

## Golden threads of the lit Pattern drift up from the ground.
func _rebuild_motes(enabled: bool) -> void:
	if motes != null and is_instance_valid(motes):
		motes.queue_free()
	motes = null
	if not enabled or game.world == null or not game.world.has_method("map_size"):
		return
	var size: Vector2 = game.world.map_size()
	motes = CPUParticles2D.new()
	motes.name = "PatternMotes"
	motes.amount = int(clampf(size.x * size.y / 14000.0, 40, 160))
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = size * 0.5
	motes.position = size * 0.5
	motes.direction = Vector2.UP
	motes.spread = 12.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 4.0
	motes.initial_velocity_max = 9.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.5, 0.0))
	ramp.add_point(0.5, Color(0.7, 0.95, 1.0, 0.7))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.85, 0.5, 0.0))
	motes.color_ramp = ramp
	motes.z_index = 54
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	motes.material = additive
	game.add_child(motes)

# --- Rifts -------------------------------------------------------------------

func rift_open(region_id: String) -> bool:
	return rifts.has(region_id) and not closed.has(region_id) and game.quests.is_active(RIFT_QUEST)

## Called when a region is populated.
func spawn_rift() -> void:
	_wave.clear()
	_rift = null
	if not rift_open(game.current_region):
		return
	var pos: Array = rifts[game.current_region]
	var rift := PatternRift.new()
	rift.region_id = game.current_region
	game.add_child(rift)
	rift.global_position = Vector2(float(pos[0]), float(pos[1]))
	rift.touched.connect(_on_touched)
	_rift = rift

func _local_kinds() -> Array:
	var kinds: Array = []
	for entry in RegionCatalog.get_region(game.current_region).get("enemies", []):
		var kind := str(entry.get("kind", ""))
		if entry.has("quest") or kind in SkywardGame.STORY_BOSSES or kind == "guardian" or kinds.has(kind):
			continue
		kinds.append(kind)
	return kinds if not kinds.is_empty() else ["shade"]

func _on_touched(rift: PatternRift) -> void:
	rift.wake()
	_wave.clear()
	var kinds := _local_kinds()
	var gap := maxi(0, game.player.level - RegionCatalog.level(game.current_region))
	for i in ECHO_COUNT:
		var at := rift.global_position + Vector2.RIGHT.rotated(TAU * i / ECHO_COUNT + 0.4) * 46.0
		var kind := str(kinds[i % kinds.size()])
		var elite := EliteModifiers.pick(rng) if i == 0 and EliteModifiers.can_be_elite(kind) else ""
		var echo := game.spawn_enemy(kind, at, elite)
		if echo == null:
			continue
		echo.set_meta("rift_echo", true)
		# Echoes keep up with a hero who outgrew the land.
		echo.max_health = roundi(echo.max_health * (1.6 + 0.12 * gap))
		echo.health = echo.max_health
		echo.attack_damage = roundi(echo.attack_damage * (1.25 + 0.06 * gap))
		echo.xp_reward = roundi(echo.xp_reward * 2.0)
		echo.base_visual_tint = Color(0.9, 0.74, 1.0)
		echo.visual.modulate = echo.base_visual_tint
		echo.combat_feedback.set_health(echo.health, echo.max_health)
		echo.defeated.connect(func(_xp: int) -> void: _on_echo_down(echo))
		_wave.append(echo)
		Vfx.sparkle(game, at)
	game.shake(3.0, 0.3)
	GameAudio.play("boss_roar", -10.0, 0.0)
	game.hud.show_message("Из разлома лезут отголоски! Одолейте всех.", 3.0)
	if _wave.is_empty():
		seal(rift)

func _on_echo_down(echo: SlimeEnemy) -> void:
	_wave.erase(echo)
	var alive := _wave.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as SlimeEnemy).is_queued_for_deletion() and (e as SlimeEnemy).health > 0)
	if alive.is_empty() and _rift != null and is_instance_valid(_rift):
		seal(_rift)

func seal(rift: PatternRift) -> void:
	var region_id := rift.region_id
	if closed.has(region_id):
		return
	closed[region_id] = true
	var at := rift.global_position
	rift.queue_free()
	_rift = null
	Vfx.burst(game, at, [Color(1, 0.95, 0.7), Color(0.8, 0.6, 1.0), Color(0.4, 0.2, 0.7, 0)], 26, 90.0, 0.6)
	game.shake(4.0, 0.3)
	GameAudio.play("quest", -2.0, 0.0)
	game._spawn_loot(at, "pattern_shard").amount = 2
	var coins := game._spawn_loot(at + Vector2(14, 6), "gold")
	coins.amount = 40 * maxi(1, RegionCatalog.level(region_id))
	if rng.randf() < 0.4:
		game.spawn_generated_loot(at + Vector2(-14, 8), "epic")
	game.achievements.add("rifts")
	if game.quests.is_active(RIFT_QUEST):
		game.quests.add_progress(RIFT_QUEST, 1)
	var done := int(game.quests.states.get(RIFT_QUEST, {}).get("progress", closed.size()))
	game.hud.show_message("Разлом закрыт! (%d/%d)%s" % [mini(done, rifts.size()), rifts.size(), " Вернитесь к Сорену." if done >= rifts.size() else ""], 3.5)
	game._refresh_hud()
	game.request_autosave()

func minimap_marker() -> Array:
	if rift_open(game.current_region):
		var pos: Array = rifts[game.current_region]
		return [{"kind": "rift", "position": Vector2(float(pos[0]), float(pos[1]))}]
	return []

## Lands with an open rift (for the world map and tests).
func open_rift_regions() -> Array:
	return rifts.keys().filter(func(id: Variant) -> bool: return rift_open(str(id)))

func make_snapshot() -> Dictionary:
	return {"closed": closed.duplicate()}

func restore_snapshot(data: Variant) -> void:
	if data is Dictionary and data.get("closed", {}) is Dictionary:
		closed = (data["closed"] as Dictionary).duplicate()
