extends Node
class_name Legends

## Legendary beasts (data/legends.json): one per land, roaming only at
## night. A legend is a huge, glowing version of a local monster with its
## own name; beaten once, it drops a unique trophy. At dawn a living legend
## slips away until the next night.

signal legend_defeated(legend_id: String)

const PATH := "res://data/legends.json"

var game: SkywardGame
var data: Dictionary = {}
var defeated: Dictionary = {}
var _current: SlimeEnemy
var _current_id: String = ""
var _announced: Dictionary = {}

func _ready() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed.get("legends", {})

func legend_for(region_id: String) -> String:
	for legend_id in data:
		if str(data[legend_id].get("region", "")) == region_id:
			return str(legend_id)
	return ""

func _process(_delta: float) -> void:
	if game == null or game.day_night == null:
		return
	var alive := _current != null and is_instance_valid(_current) and not _current.is_queued_for_deletion()
	if alive and (not dark() or str(data.get(_current_id, {}).get("region", "")) != game.current_region):
		# Dawn (or the hero left): the legend withdraws.
		if game.day_night.cycles_here():
			game.hud.show_message("%s скрывается до следующей ночи." % str(data[_current_id]["name"]), 3.0)
		_current.queue_free()
		_current = null
		return
	if not alive and dark():
		try_spawn()

## Night on the surface; the Enchanted Grove is always dark.
func dark() -> bool:
	return game.day_night.night_here() or RegionCatalog.style(game.current_region) == "night"

func try_spawn() -> SlimeEnemy:
	var legend_id := legend_for(game.current_region)
	if legend_id.is_empty() or defeated.has(legend_id):
		return null
	if _current != null and is_instance_valid(_current):
		return _current
	var info: Dictionary = data[legend_id]
	var pos: Array = info.get("position", [400, 400])
	var enemy := game.spawn_enemy(str(info["kind"]), Vector2(float(pos[0]), float(pos[1])))
	if enemy == null:
		return null
	enemy.set_meta("legend", legend_id)
	enemy.max_health = roundi(enemy.max_health * float(info.get("health_mult", 4.0)))
	enemy.health = enemy.max_health
	enemy.attack_damage = roundi(enemy.attack_damage * float(info.get("damage_mult", 1.5)))
	enemy.xp_reward *= 4
	enemy.knockback_resist = maxf(enemy.knockback_resist, 0.7)
	var scale_value := float(info.get("scale", 1.5))
	enemy.visual.scale *= scale_value
	var rgb: Array = info.get("color", [1, 0.8, 0.4])
	var color := Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
	enemy.base_visual_tint = Color.WHITE.lerp(color, 0.45)
	enemy.visual.modulate = enemy.base_visual_tint
	enemy.combat_feedback.elite = true
	enemy.combat_feedback.elite_name = "★ " + str(info["name"])
	enemy.combat_feedback.elite_color = color
	enemy.combat_feedback.bar_y = enemy.combat_feedback.bar_y * scale_value
	enemy.combat_feedback.set_health(enemy.health, enemy.max_health)
	enemy.defeated.connect(func(_xp: int) -> void: _on_defeated(legend_id, enemy.global_position))
	_current = enemy
	_current_id = legend_id
	if not _announced.has(legend_id):
		_announced[legend_id] = true
		game.hud.show_title_card("Легенда ночи", 2.5)
		game.hud.show_message("В этих землях бродит %s. На миникарте — фиолетовая метка." % str(info["name"]), 4.5)
		GameAudio.play("boss_roar", -8.0, 0.0)
	return enemy

func _on_defeated(legend_id: String, at: Vector2) -> void:
	if defeated.has(legend_id):
		return
	defeated[legend_id] = true
	_current = null
	var info: Dictionary = data.get(legend_id, {})
	var reward := str(info.get("reward", ""))
	if not reward.is_empty():
		game._spawn_loot(at, reward).settle_time = 1.0
	var coins := game._spawn_loot(at + Vector2(14, 6), "gold")
	coins.amount = 60 * maxi(1, RegionCatalog.level(game.current_region))
	game.shake(5.0, 0.4)
	game.hud.show_title_card("Легенда повержена!", 3.0)
	game.hud.show_message("%s побеждён. Трофей: %s." % [str(info.get("name", "")), game.player.get_item_name(reward)], 4.0)
	legend_defeated.emit(legend_id)
	game.request_autosave()

func make_snapshot() -> Dictionary:
	return {"defeated": defeated.duplicate()}

func restore_snapshot(value: Variant) -> void:
	if value is Dictionary and value.get("defeated", {}) is Dictionary:
		defeated = (value["defeated"] as Dictionary).duplicate()
