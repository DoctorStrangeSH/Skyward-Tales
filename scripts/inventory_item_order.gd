extends RefCounted
class_name InventoryItemOrder

# Inventory category and sorting rules. UI construction remains in GameHud.
static func category(player: PlayerCharacter, item_id: String, consumable_ids: Array) -> String:
	if not str(player.get_item_definition(item_id).get("slot", "")).is_empty():
		return "equipment"
	if consumable_ids.has(item_id) or player.get_item_definition(item_id).has("use"):
		return "consumable"
	return "other"

static func display_name(player: PlayerCharacter, item_id: String, fallback_names: Dictionary) -> String:
	return str(fallback_names.get(item_id, player.get_item_name(item_id)))

static func rarity_rank(player: PlayerCharacter, item_id: String) -> int:
	match str(player.get_item_definition(item_id).get("rarity", "")):
		"legendary":
			return 5
		"epic":
			return 4
		"rare":
			return 3
		"uncommon":
			return 2
		"common":
			return 1
		_:
			return 0

static func sort_items(player: PlayerCharacter, item_ids: Array[String], sort_index: int, fallback_names: Dictionary) -> void:
	if sort_index == 1:
		item_ids.sort_custom(func(a: String, b: String) -> bool:
			return display_name(player, a, fallback_names).to_lower() < display_name(player, b, fallback_names).to_lower()
		)
	elif sort_index == 2:
		item_ids.sort_custom(func(a: String, b: String) -> bool:
			var rank_a: int = rarity_rank(player, a)
			var rank_b: int = rarity_rank(player, b)
			if rank_a != rank_b:
				return rank_a > rank_b
			return display_name(player, a, fallback_names).to_lower() < display_name(player, b, fallback_names).to_lower()
		)
