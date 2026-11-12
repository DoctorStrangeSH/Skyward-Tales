extends RefCounted
class_name RegionCatalog

## Cached read-only access to data/regions.json. Every region-specific rule
## (name, map colour, gate requirements, which quest its herbs advance) lives
## in the data, so adding a region needs no code changes.

const PATH := "res://data/regions.json"
const DEFAULT_REGION := "greenreach"

static var _regions: Dictionary = {}

static func all() -> Dictionary:
	if _regions.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_regions = parsed
		if _regions.is_empty():
			push_warning("Каталог регионов не найден: " + PATH)
	return _regions

## Lands on the world map. Hidden lands (the Pattern Vault, reached only by
## expedition) are left out; all_ids() lists them too.
static func ids() -> Array:
	return all().keys().filter(func(region_id: Variant) -> bool: return not is_hidden(str(region_id)))

static func all_ids() -> Array:
	return all().keys()

static func is_hidden(region_id: String) -> bool:
	return bool(get_region(str(region_id)).get("hidden", false))

static func has(region_id: String) -> bool:
	return all().has(region_id)

static func get_region(region_id: String) -> Dictionary:
	var region: Variant = all().get(region_id, {})
	return region if region is Dictionary else {}

## The portrait of an NPC (assets/sprites/portraits/<id>.png): its own, or
## the one of the character whose look it wears; "" when there is none.
## Found by id or by the name shown in dialogue ("Сеня, молодой рудокоп").
static var _portraits: Dictionary = {}

static func portrait_id(npc_id_or_name: String) -> String:
	if _portraits.is_empty():
		for region_id in all_ids():
			for npc in get_region(str(region_id)).get("npcs", []):
				var id := str(npc.get("id", ""))
				var face := str(npc.get("look", id))
				for candidate in [id, face]:
					if ResourceLoader.exists("res://assets/sprites/portraits/%s.png" % candidate):
						_portraits[id] = candidate
						_portraits[str(npc.get("name", id))] = candidate
						break
	if _portraits.has(npc_id_or_name):
		return str(_portraits[npc_id_or_name])
	for key in _portraits:
		if str(key).length() > 3 and npc_id_or_name.begins_with(str(key)):
			return str(_portraits[key])
	return ""

## The name an NPC is shown with ("" when unknown).
static func npc_name(npc_id: String) -> String:
	for region_id in all_ids():
		for npc in get_region(str(region_id)).get("npcs", []):
			if str(npc.get("id", "")) == npc_id:
				return str(npc.get("name", npc_id))
	return ""

static func resolve(region_id: String) -> String:
	return region_id if has(region_id) else DEFAULT_REGION

static func display_name(region_id: String) -> String:
	return str(get_region(region_id).get("name", region_id))

static func terrain(region_id: String) -> Dictionary:
	var value: Variant = get_region(region_id).get("terrain", {})
	return value if value is Dictionary else {}

static func style(region_id: String) -> String:
	return str(terrain(region_id).get("style", "day"))

const UNDERGROUND := ["cave", "crypt", "magma"]
const DUNGEONS := ["crypt", "magma"]

## Caves and dungeons: no sky, no weather events.
## Peaceful lands (the Haven): no monsters, no raids.
static func is_peaceful(region_id: String) -> bool:
	return bool(get_region(region_id).get("peaceful", false))

static func is_underground(style_id: String) -> bool:
	return style_id in UNDERGROUND

static func is_dungeon(style_id: String) -> bool:
	return style_id in DUNGEONS

static func map_color(region_id: String) -> Color:
	var value: Variant = get_region(region_id).get("map_color", [0.18, 0.32, 0.19])
	if value is Array and value.size() == 3:
		return Color(float(value[0]), float(value[1]), float(value[2]))
	return Color(0.18, 0.32, 0.19)

## Quest advanced by collecting this region's herbs (e.g. moonleaf → elder).
## Recommended hero level (shown on the map and when entering).
static func level(region_id: String) -> int:
	return int(get_region(region_id).get("level", 1))

## Multiplier for enemy health, damage and experience in this region.
static func enemy_power(region_id: String) -> float:
	return float(get_region(region_id).get("enemy_power", 1.0))

static func waystone(region_id: String) -> Variant:
	return get_region(region_id).get("waystone", null)

static func herb_quest(region_id: String) -> String:
	return str(get_region(region_id).get("herb_quest", ""))

## The gate leading from `from_region` to `target`, or {} if none.
static func gate(from_region: String, target: String) -> Dictionary:
	for gate_data in get_region(from_region).get("gates", []):
		if gate_data is Dictionary and str(gate_data.get("target", "")) == target:
			return gate_data
	return {}
