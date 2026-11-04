extends Node
class_name TreasureHunt

## Treasure maps: monsters and chests sometimes drop a "Карта сокровищ".
## Reading it marks a spot in some land on the minimap and the world map;
## there a dig mark appears — E digs up a chest of gold and good gear.

const MAP_ITEM := "treasure_map"
const DIG_SCRIPT := preload("res://scripts/dig_spot.gd")

var game: SkywardGame
var rng := RandomNumberGenerator.new()
## {"region": id, "position": [x, y]} while a map is being followed.
var active: Dictionary = {}
var found: int = 0

func _ready() -> void:
	rng.randomize()

func has_active() -> bool:
	return not active.is_empty()

## Lands a map can point to: outdoor lands the hero has seen.
func candidate_regions() -> Array:
	var result: Array = []
	for region_id in RegionCatalog.ids():
		var style := RegionCatalog.style(region_id)
		if RegionCatalog.is_underground(style):
			continue
		if region_id == game.current_region or game.visited_regions.has(region_id):
			result.append(region_id)
	if result.is_empty():
		result.append(game.current_region)
	return result

func read_map() -> bool:
	if has_active():
		game.hud.show_message("Сначала найдите клад по прошлой карте: %s." % RegionCatalog.display_name(str(active["region"])), 3.0)
		return false
	if not game.player.remove_item(MAP_ITEM, 1):
		return false
	var regions := candidate_regions()
	var region_id: String = regions[rng.randi_range(0, regions.size() - 1)]
	active = {"region": region_id, "position": _spot(region_id)}
	game.hud.show_title_card("Карта сокровищ", 2.0)
	game.hud.show_message("Крестик на карте: %s. Ищите отметку X на миникарте." % RegionCatalog.display_name(region_id), 4.5)
	GameAudio.play("quest", -6.0, 0.0)
	spawn_mark()
	return true

## A dig spot beside a trail, inside the island and away from water.
func _spot(region_id: String) -> Array:
	var terrain := RegionCatalog.terrain(region_id)
	var size: Array = terrain.get("size", [1280, 864])
	var margin := float(terrain.get("edge_margin", 0)) + 80.0
	var trails: Array = terrain.get("trails", [])
	for attempt in 60:
		var point := Vector2(rng.randf_range(margin, float(size[0]) - margin), rng.randf_range(margin, float(size[1]) - margin))
		if not trails.is_empty():
			var trail: Array = trails[rng.randi_range(0, trails.size() - 1)]
			var a: Array = trail[rng.randi_range(0, trail.size() - 1)]
			point = Vector2(float(a[0]), float(a[1])) + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(50.0, 120.0)
		point.x = clampf(point.x, margin, float(size[0]) - margin)
		point.y = clampf(point.y, margin, float(size[1]) - margin)
		if _clear(terrain, point):
			return [roundi(point.x), roundi(point.y)]
	return [roundi(float(size[0]) * 0.5), roundi(float(size[1]) * 0.5)]

func _clear(terrain: Dictionary, point: Vector2) -> bool:
	for pond in terrain.get("ponds", []):
		if pond.has("circle"):
			var c: Array = pond["circle"]
			if point.distance_to(Vector2(float(c[0]), float(c[1]))) < float(c[2]) + 30.0:
				return false
		elif pond.has("rect"):
			var r: Array = pond["rect"]
			if Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow(30.0).has_point(point):
				return false
	for blocker in terrain.get("blockers", []):
		var c: Array = blocker.get("center", [0, 0])
		var s: Array = blocker.get("size", [0, 0])
		if Rect2(float(c[0]) - float(s[0]) * 0.5, float(c[1]) - float(s[1]) * 0.5, float(s[0]), float(s[1])).grow(16.0).has_point(point):
			return false
	for tree in terrain.get("trees", []):
		if point.distance_to(Vector2(float(tree[0]), float(tree[1]))) < 26.0:
			return false
	return true

## Puts the X on the ground when the hero is in the map's land.
func spawn_mark() -> void:
	if not has_active() or str(active["region"]) != game.current_region:
		return
	for node in game.get_children():
		if node is DigSpot:
			return
	var mark := DIG_SCRIPT.new() as DigSpot
	var pos: Array = active["position"]
	add_mark(mark, Vector2(float(pos[0]), float(pos[1])))

func add_mark(mark: DigSpot, at: Vector2) -> void:
	game.add_child(mark)
	mark.global_position = at
	mark.dug.connect(_on_dug)

func _on_dug(mark: DigSpot) -> void:
	var at := mark.global_position
	mark.queue_free()
	active = {}
	found += 1
	var level := RegionCatalog.level(game.current_region)
	Vfx.burst(game, at, [Color(0.8, 0.65, 0.4), Color(0.55, 0.4, 0.25), Color(0.3, 0.2, 0.1, 0)], 18, 70.0, 0.5)
	GameAudio.play("chest", -2.0, 0.0)
	game.shake(2.0, 0.2)
	for i in 3:
		var coins := game._spawn_loot(at + Vector2(rng.randf_range(-16, 16), rng.randf_range(-6, 12)), "gold")
		coins.amount = rng.randi_range(15, 30) * maxi(1, level)
	game.spawn_generated_loot(at + Vector2(0, 14), "rare" if rng.randf() < 0.75 else "epic")
	if rng.randf() < 0.35:
		game._spawn_loot(at + Vector2(14, -4), "starlight_essence")
	game.hud.show_message("Клад найден! (%d)" % found, 3.0)

func minimap_marker() -> Array:
	if has_active() and str(active["region"]) == game.current_region:
		var pos: Array = active["position"]
		return [{"kind": "treasure", "position": Vector2(float(pos[0]), float(pos[1]))}]
	return []

func make_snapshot() -> Dictionary:
	return {"active": active.duplicate(true), "found": found}

func restore_snapshot(data: Variant) -> void:
	if data is Dictionary:
		active = (data.get("active", {}) as Dictionary).duplicate(true) if data.get("active", {}) is Dictionary else {}
		found = int(data.get("found", 0))
