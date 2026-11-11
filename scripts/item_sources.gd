extends RefCounted
class_name ItemSources

## "Where do I get it?" — a short answer for any item, gathered from the
## game's own data: resource nodes (and the lands they stand in), the garden,
## the merchant, recipes, monster drops, fishing. Shown in the crafting
## window under a missing ingredient and for pinned goals.

const EXTRA := {
	"egg": "куры у огорода, по утрам",
	"trial_seal": "Башня испытаний: рекорды и чемпионы",
	"sapling": "Орвин в доме лесничих; падает с деревьев",
	"resin": "рубка деревьев (ранг «Лесничий»)",
	"wolf_pelt": "добыча: волки",
	"star_fragment": "событие «Звездопад» — упавшие звёзды",
	"traveler_sword": "меч, с которым герой начинает путь",
	"wolfskin_mantle": "шьёт кузнец из волчьих шкур",
}
static var _CACHE: Dictionary = {}

static func _json(path: String) -> Dictionary:
	if _CACHE.has(path):
		return _CACHE[path]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	_CACHE[path] = parsed if parsed is Dictionary else {}
	return _CACHE[path]

## All known sources of the item, the handiest first.
static func list(game: SkywardGame, item_id: String) -> Array[String]:
	var result: Array[String] = []
	if EXTRA.has(item_id):
		result.append(str(EXTRA[item_id]))
	# Resource nodes and their lands.
	var kinds: Dictionary = game.crafting.data.get("kinds", {})
	for kind_id in kinds:
		if str(kinds[kind_id].get("item", "")) != item_id:
			continue
		var lands: Array[String] = []
		for region_id in RegionCatalog.all_ids():
			for entry in RegionCatalog.get_region(str(region_id)).get("gather", []):
				if str(entry.get("kind", "")) == str(kind_id) and not lands.has(RegionCatalog.display_name(str(region_id))):
					lands.append(RegionCatalog.display_name(str(region_id)))
		var where := (" — " + ", ".join(lands.slice(0, 3))) if not lands.is_empty() else ""
		result.append("%s%s" % [str(kinds[kind_id].get("name", kind_id)).to_lower(), where])
	# The garden.
	for seed in Farm.SEEDS:
		if str(Farm.SEEDS[seed][0]) == item_id:
			result.append("огород: %s" % game.player.get_item_name(str(seed)).to_lower())
	# Recipes.
	for recipe_id in game.crafting_service.recipes:
		var recipe: Dictionary = game.crafting_service.recipes[recipe_id]
		if str(recipe.get("output", {}).get("item_id", "")) == item_id:
			var station := str(game.crafting.station(str(recipe.get("station", ""))).get("name", "ремесло"))
			var line := "ремесло: %s" % station.to_lower()
			if not result.has(line):
				result.append(line)
	# The merchant.
	if game.merchant_shop.offers.has(item_id):
		result.append("торговец Бран")
	# Monster drops.
	var bestiary := _json("res://data/bestiary.json")
	var monsters: Dictionary = _json("res://data/drops.json").get("monsters", {})
	var droppers: Array[String] = []
	for kind in monsters:
		for drop in monsters[kind].get("items", []):
			if str(drop.get("item", "")) == item_id:
				droppers.append(str(bestiary.get(kind, {}).get("name", kind)).to_lower())
	if not droppers.is_empty():
		result.append("добыча: %s" % ", ".join(droppers.slice(0, 3)))
	# Fishing.
	var fish := _json("res://data/fish.json")
	for group in fish:
		var entries: Variant = fish[group]
		if entries is Dictionary and entries.has(item_id):
			result.append("рыбалка")
			break
	return result

## One line for the interface ("" when nothing is known).
static func describe(game: SkywardGame, item_id: String, limit: int = 2) -> String:
	var sources := list(game, item_id)
	return "; ".join(sources.slice(0, limit))
