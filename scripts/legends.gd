extends Node
class_name Legends

## Legendary beasts (data/legends.json): one per land, roaming only at
## night. A legend is a huge, glowing version of a local monster with its
## own name; beaten once, it drops a unique trophy. At dawn a living legend
## slips away until the next night.
##
## Legend hunt (Этап 15): Toren the hunter helps track a legend down.
## Stage "tracks": three trail signs in the legend's land (any order); once
## all are read Toren's notes reveal its weakness and the beast waits in its
## lair even by day ("lair"). At half health it flies into a rage: faster,
## harder hitting, with two minions. A hunted legend pays double.

signal legend_defeated(legend_id: String)

const PATH := "res://data/legends.json"

var game: SkywardGame
var data: Dictionary = {}
var defeated: Dictionary = {}
var _current: SlimeEnemy
var _current_id: String = ""
var _announced: Dictionary = {}
## The active hunt: {"id", "stage": "tracks"|"lair", "found": [0..2], "tracks": [[x, y], ...]}.
var hunt: Dictionary = {}
var hunts_done: int = 0
var _enraged: bool = false

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
	if alive and hunted(_current_id) and not _enraged and _current.health * 2 <= _current.max_health:
		_enrage(_current)
	if alive and (not (dark() or hunted(_current_id)) or str(data.get(_current_id, {}).get("region", "")) != game.current_region):
		# Dawn (or the hero left): the legend withdraws.
		if game.day_night.cycles_here():
			game.hud.show_message("%s скрывается до следующей ночи." % str(data[_current_id]["name"]), 3.0)
		_current.queue_free()
		_current = null
		return
	if not alive and (dark() or hunted(legend_for(game.current_region))):
		try_spawn()

## Night on the surface; the Enchanted Grove is always dark.
func dark() -> bool:
	return game.day_night.night_here() or RegionCatalog.style(game.current_region) == "night"

func try_spawn() -> SlimeEnemy:
	if RegionCatalog.is_peaceful(game.current_region):
		return null
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
	_enraged = false
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
	if hunted(legend_id):
		# The hunt pays double: a second tome, more gold and a rare find.
		hunt = {}
		hunts_done += 1
		game._spawn_loot(at + Vector2(0, 16), VillageBuildings.TOME)
		game._spawn_loot(at + Vector2(0, -14), "gold").amount = 60 * maxi(1, RegionCatalog.level(game.current_region))
		game.spawn_generated_loot(at + Vector2(18, -10), "rare", "elite")
		game.achievements.add("legend_hunts")
	game._spawn_loot(at + Vector2(-14, 6), VillageBuildings.TOME)
	# A first win over a legend leaves a Book of Forgetting (the skill reset).
	game._spawn_loot(at + Vector2(0, 22), SkillTree.RESET_TOME)
	var coins := game._spawn_loot(at + Vector2(14, 6), "gold")
	coins.amount = 60 * maxi(1, RegionCatalog.level(game.current_region))
	game.shake(5.0, 0.4)
	game.hud.show_title_card("Легенда повержена!", 3.0)
	game.hud.show_message("%s побеждён. Трофей: %s." % [str(info.get("name", "")), game.player.get_item_name(reward)], 4.0)
	legend_defeated.emit(legend_id)
	game.request_autosave()

func make_snapshot() -> Dictionary:
	return {"defeated": defeated.duplicate(), "hunt": hunt.duplicate(true), "hunts_done": hunts_done}

func restore_snapshot(value: Variant) -> void:
	if value is Dictionary and value.get("defeated", {}) is Dictionary:
		defeated = (value["defeated"] as Dictionary).duplicate()
	hunt = {}
	if value is Dictionary and value.get("hunt", {}) is Dictionary:
		hunt = (value.get("hunt", {}) as Dictionary).duplicate(true)
	if value is Dictionary:
		hunts_done = int(value.get("hunts_done", 0))

# --- Legend hunt ------------------------------------------------------------

func hunted(legend_id: String) -> bool:
	return not legend_id.is_empty() and str(hunt.get("id", "")) == legend_id and str(hunt.get("stage", "")) == "lair"

## The legend Toren can help track: one the hero has not beaten, in a land
## already visited (the current land first).
func huntable() -> String:
	var here := legend_for(game.current_region)
	if not here.is_empty() and not defeated.has(here):
		return here
	for legend_id in data:
		if not defeated.has(legend_id) and game.visited_regions.has(str(data[legend_id].get("region", ""))):
			return str(legend_id)
	return ""

func legend_name(legend_id: String) -> String:
	return str(data.get(legend_id, {}).get("name", legend_id))

func start_hunt(legend_id: String) -> bool:
	if not hunt.is_empty() or not data.has(legend_id) or defeated.has(legend_id):
		return false
	var info: Dictionary = data[legend_id]
	var region := str(info.get("region", ""))
	var lair := Vector2(float(info["position"][0]), float(info["position"][1]))
	hunt = {"id": legend_id, "stage": "tracks", "found": [], "tracks": _track_spots(region, lair)}
	game.hud.show_message("Охота на легенду: %s. Найдите три следа в землях «%s» — они отмечены на карте." % [legend_name(legend_id), RegionCatalog.display_name(region)], 5.0)
	if game.current_region == region:
		spawn_tracks()
	game.request_autosave()
	return true

## Three trail signs, from far to near, at the land's monster spots (they
## are always on open ground).
func _track_spots(region: String, lair: Vector2) -> Array:
	var spots: Array = []
	for enemy_data in game._layout(region).get("enemies", []):
		var at := SkywardGame._vec(enemy_data.get("position"))
		var dist := at.distance_to(lair)
		if dist > 120.0 and dist < 900.0:
			spots.append(at)
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(lair) > b.distance_to(lair))
	var result: Array = []
	if spots.size() >= 3:
		for index in 3:
			var pick: Vector2 = spots[roundi(index * (spots.size() - 1) / 2.0)]
			result.append([pick.x + 14.0, pick.y + 10.0])
	else:
		for index in 3:
			var at := lair + Vector2(140.0 + 90.0 * (2 - index), 0).rotated(0.9 * index)
			result.append([at.x, at.y])
	return result

func spawn_tracks() -> void:
	if hunt.is_empty() or str(hunt.get("stage", "")) != "tracks":
		return
	if game.current_region != str(data[str(hunt["id"])].get("region", "")):
		return
	var found: Array = hunt.get("found", [])
	var tracks: Array = hunt.get("tracks", [])
	for index in tracks.size():
		if index in found:
			continue
		var mark := TrackMark.new()
		mark.index = index
		game.add_child(mark)
		mark.global_position = Vector2(float(tracks[index][0]), float(tracks[index][1]))
		mark.used.connect(_on_track)

func on_region_ready() -> void:
	spawn_tracks()

const TRACK_LINES := [
	"Свежие следы когтей на камне. Зверь проходил здесь недавно.",
	"Клок шерсти и сломанные ветки. Он идёт к логову.",
	"Земля разрыта, пахнет зверем. Логово совсем близко!",
]

func _on_track(mark: TrackMark) -> void:
	if hunt.is_empty():
		return
	var found: Array = hunt.get("found", [])
	if mark.index in found:
		return
	found.append(mark.index)
	hunt["found"] = found
	mark.queue_free()
	GameAudio.play("pickup", -6.0, 0.0)
	var legend_id := str(hunt["id"])
	if found.size() < 3:
		game.hud.show_message("%s (Следы: %d/3)" % [TRACK_LINES[mini(found.size() - 1, 2)], found.size()], 3.5)
	else:
		hunt["stage"] = "lair"
		var kind := str(data[legend_id].get("kind", ""))
		var weakness := _weakness(kind)
		game._show_dialogue("Записи Торена", "Логово найдено! %s ждёт вас — теперь не только ночью. Слабость: %s В ярости зверь зовёт стаю — будьте готовы." % [legend_name(legend_id), weakness])
		try_spawn()
	game.request_autosave()

func _weakness(kind: String) -> String:
	var file := FileAccess.open("res://data/bestiary.json", FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return str(parsed.get(kind, {}).get("weakness", ""))
	return ""

func _enrage(enemy: SlimeEnemy) -> void:
	_enraged = true
	enemy.attack_damage = roundi(enemy.attack_damage * 1.3)
	enemy.move_speed *= 1.25
	enemy.base_visual_tint = enemy.base_visual_tint.lerp(Color(1.0, 0.4, 0.35), 0.5)
	enemy.visual.modulate = enemy.base_visual_tint
	game.shake(4.0, 0.4)
	game.hud.show_message("%s впадает в ярость и зовёт стаю!" % legend_name(_current_id), 3.0)
	GameAudio.play("boss_roar", -4.0, 0.2)
	var kind := str(data[_current_id].get("kind", "wolf"))
	for side in [-1, 1]:
		var minion := game.spawn_enemy(kind, enemy.global_position + Vector2(side * 36, 18))
		if minion != null:
			minion.set_meta("no_respawn", true)

func hunt_targets() -> Array:
	if hunt.is_empty():
		return []
	var legend_id := str(hunt["id"])
	var region := str(data[legend_id].get("region", ""))
	if str(hunt.get("stage", "")) == "lair":
		var pos: Array = data[legend_id]["position"]
		return [{"region": region, "position": Vector2(float(pos[0]), float(pos[1])), "kind": "side", "title": "Логово: " + legend_name(legend_id)}]
	var result: Array = []
	var found: Array = hunt.get("found", [])
	var tracks: Array = hunt.get("tracks", [])
	for index in tracks.size():
		if not index in found:
			result.append({"region": region, "position": Vector2(float(tracks[index][0]), float(tracks[index][1])), "kind": "side", "title": "След легенды"})
	return result

func handle_choice(choice_id: String) -> void:
	if choice_id.begins_with("legend_hunt:"):
		start_hunt(choice_id.trim_prefix("legend_hunt:"))
