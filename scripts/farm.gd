extends Node
class_name Farm

## The village garden (Этап 13), built and upgraded at the settlement board
## (settlement.json → buildings.farm). Beds: E on an empty bed — plant seeds
## from the bag; E on a growing bed — water it (grows twice as fast); E on a
## ripe bed — harvest. Crops grow in game time (a day is 12 minutes) and keep
## growing while the hero is away. Level 2: six beds, faster; level 3:
## scarecrow and sprinkler (beds water themselves, +1 crop, faster still).

const BUILDING := "farm"
const CENTER := Vector2(700, 812)
const BED_SPOTS := [Vector2(660, 792), Vector2(700, 792), Vector2(740, 792), Vector2(660, 834), Vector2(700, 834), Vector2(740, 834)]
## seed -> [crop, growth in days, min, max]
const SEEDS := {
	"seed_healroot": ["healroot", 0.25, 3, 4],
	"seed_bluebell": ["bluebell", 0.25, 3, 4],
	"seed_wheat": ["wheat", 0.35, 4, 5],
	"seed_sunberry": ["sunberry", 0.5, 2, 3],
}
const CROP_COLORS := {"healroot": Color(0.85, 0.35, 0.3), "bluebell": Color(0.45, 0.55, 1.0), "wheat": Color(0.95, 0.8, 0.35), "sunberry": Color(1.0, 0.6, 0.15)}

var game: SkywardGame
## Bed index -> {"seed", "planted" (absolute day), "watered"}.
var beds: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func level() -> int:
	return game.settlement.building_level(BUILDING)

func bed_count() -> int:
	return 0 if level() <= 0 else (3 if level() == 1 else 6)

func _now() -> float:
	return game.day_night.now()

func growth_days(index: int) -> float:
	var bed: Dictionary = beds.get(index, {})
	var days := float(SEEDS.get(str(bed.get("seed", "")), ["", 0.3])[1])
	days *= [1.0, 1.0, 0.75, 0.5][clampi(level(), 0, 3)]
	if bool(bed.get("watered", false)) or level() >= 3:
		days *= 0.5
	return days

## 0..1 for a planted bed, -1 for an empty one.
func growth(index: int) -> float:
	if not beds.has(index):
		return -1.0
	var days := growth_days(index)
	return clampf((_now() - float(beds[index].get("planted", 0.0))) / maxf(0.001, days), 0.0, 1.0)

func ripe(index: int) -> bool:
	return growth(index) >= 1.0

func crop_of(index: int) -> String:
	return str(SEEDS.get(str(beds.get(index, {}).get("seed", "")), [""])[0])

func seeds_in_bag() -> Array:
	return SEEDS.keys().filter(func(id: String) -> bool: return int(game.player.inventory.get(id, 0)) > 0)

func prompt(index: int) -> String:
	if not beds.has(index):
		return "E — посадить" if not seeds_in_bag().is_empty() else "Грядка пуста — семена у Брана"
	if ripe(index):
		return "E — собрать урожай"
	if not bool(beds[index].get("watered", false)) and level() < 3:
		return "E — полить (%d%%)" % roundi(growth(index) * 100.0)
	return "Растёт: %d%%" % roundi(growth(index) * 100.0)

func use_bed(index: int) -> void:
	if not beds.has(index):
		var seeds := seeds_in_bag()
		if seeds.is_empty():
			game.hud.show_message("Нужны семена. Бран продаёт их в лавке.", 2.5)
			return
		var choices: Array[Dictionary] = []
		for seed_id in seeds:
			choices.append({"id": "farm_plant:%d:%s" % [index, seed_id], "label": "Посадить: %s (×%d)" % [game.player.get_item_name(seed_id), int(game.player.inventory.get(seed_id, 0))]})
		choices.append({"id": "farm_close", "label": "Позже"})
		game._show_dialogue_choices("Огород", "Что посадим?", choices)
		return
	if ripe(index):
		harvest(index)
		return
	if not bool(beds[index].get("watered", false)) and level() < 3:
		beds[index]["watered"] = true
		Vfx.burst(game, BED_SPOTS[index], [Color(0.6, 0.85, 1.0), Color(0.4, 0.6, 1.0, 0)], 10, 40.0, 0.35)
		GameAudio.play("pickup", -10.0, 0.4)
		game.hud.show_message("Полито — растёт вдвое быстрее.", 1.8)
		return
	game.hud.show_message("Растёт: %d%%. Загляните позже." % roundi(growth(index) * 100.0), 2.0)

func plant(index: int, seed_id: String) -> bool:
	if beds.has(index) or index >= bed_count() or not SEEDS.has(seed_id) or not game.player.remove_item(seed_id, 1):
		return false
	beds[index] = {"seed": seed_id, "planted": _now(), "watered": false}
	GameAudio.play("pickup", -8.0, 0.0)
	game.hud.show_message("Посажено: %s." % game.player.get_item_name(seed_id), 2.0)
	game.request_autosave()
	return true

func harvest(index: int) -> bool:
	if not ripe(index):
		return false
	var info: Array = SEEDS[str(beds[index]["seed"])]
	var amount := rng.randi_range(int(info[2]), int(info[3])) + (1 if level() >= 3 else 0)
	var crop := str(info[0])
	game.player.add_item(crop, amount)
	game.player.add_experience(6 + amount * 2)
	beds.erase(index)
	game.achievements.add("harvests")
	Vfx.burst(game, BED_SPOTS[index], [Color(1, 1, 0.8), CROP_COLORS.get(crop, Color.WHITE), Color(1, 1, 1, 0)], 14, 50.0, 0.4)
	GameAudio.play("pickup", -4.0, 0.0)
	game.hud.show_message("Урожай: %s ×%d." % [game.player.get_item_name(crop), amount], 2.5)
	game.request_autosave()
	return true

func handle_choice(choice_id: String) -> bool:
	if choice_id == "farm_close":
		game.dialogues._close()
		return true
	if choice_id.begins_with("farm_plant:"):
		var parts := choice_id.split(":")
		game.dialogues._close()
		plant(int(parts[1]), parts[2])
		return true
	return false

## World objects: the fenced garden and its beds (in the village only).
func spawn() -> void:
	if game.current_region != game.settlement.village_region() or level() <= 0:
		return
	var patch := FarmPatch.new()
	patch.farm = self
	game.add_child(patch)
	patch.global_position = CENTER
	for index in bed_count():
		var bed := FarmBed.new()
		bed.farm = self
		bed.index = index
		game.add_child(bed)
		bed.global_position = BED_SPOTS[index]

func refresh() -> void:
	for node in game.get_children():
		if node is FarmBed or node is FarmPatch:
			node.queue_free()
	spawn()

func make_snapshot() -> Dictionary:
	var saved := {}
	for index in beds:
		saved[str(index)] = beds[index].duplicate()
	return {"beds": saved}

func restore_snapshot(data: Variant) -> void:
	beds = {}
	if data is Dictionary and data.get("beds", {}) is Dictionary:
		for key in data["beds"]:
			beds[int(key)] = (data["beds"][key] as Dictionary).duplicate()
