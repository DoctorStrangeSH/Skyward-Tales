extends RefCounted
class_name GoalPin

## One goal pinned to the screen: a recipe (the crafting window's "Закрепить"
## button) or a settlement building / house (pinned by itself when materials
## run short at the board). The quest tracker lists what is still needed —
## have / need — and where to get it.

var game: SkywardGame
## "" (nothing), "recipe", "building", "house".
var kind: String = ""
var id: String = ""

func _init(owner_game: SkywardGame) -> void:
	game = owner_game

func pin(pin_kind: String, pin_id: String) -> void:
	kind = pin_kind
	id = pin_id

func clear() -> void:
	kind = ""
	id = ""

func is_pinned(pin_kind: String, pin_id: String) -> bool:
	return kind == pin_kind and id == pin_id

func title() -> String:
	match kind:
		"recipe":
			var recipe: Dictionary = game.crafting_service.recipes.get(id, {})
			return game.player.get_item_name(str(recipe.get("output", {}).get("item_id", id)))
		"building":
			return str(game.settlement.building_info(id).get("name", id))
		"house":
			return "Дом: %s" % str(game.settlement.settler(id).get("name", id)).get_slice(",", 0)
	return ""

## item_id → amount needed ("gold" for coins).
func needs() -> Dictionary:
	var result := {}
	match kind:
		"recipe":
			var recipe: Dictionary = game.crafting_service.recipes.get(id, {})
			for ingredient in recipe.get("ingredients", []):
				result[str(ingredient.get("item_id", ""))] = int(ingredient.get("amount", 1))
			if int(recipe.get("gold_cost", 0)) > 0:
				result["gold"] = int(recipe.get("gold_cost", 0))
		"building":
			result = game.settlement.upgrade_materials(id).duplicate()
			if game.settlement.upgrade_cost(id) > 0:
				result["gold"] = game.settlement.upgrade_cost(id)
		"house":
			result = game.settlement.house_materials(id).duplicate()
			result["gold"] = game.settlement.house_cost(id)
	return result

func _have(item_id: String) -> int:
	return game.player.gold if item_id == "gold" else int(game.player.inventory.get(item_id, 0))

## The goal no longer makes sense (built, housed, recipe gone).
func _stale() -> bool:
	match kind:
		"recipe": return not game.crafting_service.recipes.has(id)
		"building": return game.settlement.next_level(id).is_empty()
		"house": return not game.settlement.home_of(id).is_empty()
	return true

## Rows for the quest tracker: what is still missing (or "ready").
func tracker_entries() -> Array:
	if kind.is_empty():
		return []
	if _stale():
		clear()
		return []
	var result: Array = []
	var need := needs()
	for item_id in need:
		var have := _have(str(item_id))
		if have >= int(need[item_id]):
			continue
		var name := "золото" if str(item_id) == "gold" else game.player.get_item_name(str(item_id)).to_lower()
		result.append({"title": "%s: %s" % [title(), name], "progress": have, "target": int(need[item_id]), "main": false, "contract": true, "pin": true})
	if result.is_empty():
		result.append({"title": "%s: всё собрано!" % title(), "progress": 1, "target": 1, "main": false, "contract": true, "pin": true})
	return result.slice(0, 3)

func make_snapshot() -> Dictionary:
	return {"kind": kind, "id": id}

func restore_snapshot(value: Variant) -> void:
	var data: Dictionary = value if value is Dictionary else {}
	kind = str(data.get("kind", ""))
	id = str(data.get("id", ""))
