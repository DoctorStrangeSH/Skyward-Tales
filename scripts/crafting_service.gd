extends RefCounted
class_name CraftingService

const DATA_PATH := "res://data/crafting_recipes.json"

var recipes: Dictionary = {}

func _init() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть каталог рецептов: " + DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("recipes", {}) is Dictionary:
		push_error("Некорректный каталог рецептов: " + DATA_PATH)
		return
	recipes = parsed["recipes"].duplicate(true)

func get_recipe_status(player: PlayerCharacter, recipe_id: String) -> Dictionary:
	if player == null:
		return {"success": false, "message": "Сейчас нельзя изготовить предмет."}
	if not recipes.has(recipe_id) or not recipes[recipe_id] is Dictionary:
		return {"success": false, "message": "Такого рецепта нет."}
	var recipe: Dictionary = recipes[recipe_id]
	var output: Variant = recipe.get("output", {})
	if not output is Dictionary or str(output.get("item_id", "")).is_empty():
		return {"success": false, "message": "Рецепт повреждён."}
	var output_id := str(output.get("item_id", ""))
	if bool(recipe.get("unique_output", false)):
		if int(player.inventory.get(output_id, 0)) > 0 or player.equipment.values().has(output_id):
			return {"success": false, "message": "Этот предмет у тебя уже есть."}
	var gold_cost := maxi(0, int(recipe.get("gold_cost", 0)))
	if player.gold < gold_cost:
		return {"success": false, "message": "Не хватает золота: нужно %d, у тебя %d." % [gold_cost, player.gold]}
	var ingredients: Variant = recipe.get("ingredients", [])
	if not ingredients is Array or ingredients.is_empty():
		return {"success": false, "message": "В рецепте не указаны материалы."}
	for ingredient in ingredients:
		if not ingredient is Dictionary:
			return {"success": false, "message": "Рецепт содержит неверный материал."}
		var item_id := str(ingredient.get("item_id", ""))
		var amount := int(ingredient.get("amount", 0))
		if item_id.is_empty() or amount <= 0:
			return {"success": false, "message": "Рецепт содержит неверное количество материала."}
		var owned := int(player.inventory.get(item_id, 0))
		if owned < amount:
			var item_name := player.get_item_name(item_id)
			return {"success": false, "message": "Не хватает материала «%s»: нужно %d, у тебя %d." % [item_name, amount, owned]}
	return {"success": true, "message": "Все материалы собраны."}

func craft(player: PlayerCharacter, recipe_id: String) -> Dictionary:
	var status := get_recipe_status(player, recipe_id)
	if not bool(status.get("success", false)):
		return status
	var recipe: Dictionary = recipes[recipe_id]
	for ingredient in recipe["ingredients"]:
		if not player.remove_item(str(ingredient["item_id"]), int(ingredient["amount"])):
			return {"success": false, "message": "Не удалось списать материалы. Ничего не изготовлено."}
	var gold_cost := maxi(0, int(recipe.get("gold_cost", 0)))
	if gold_cost > 0:
		player.add_gold(-gold_cost)
	var output: Dictionary = recipe["output"]
	var output_id := str(output["item_id"])
	var output_amount := maxi(1, int(output.get("amount", 1)))
	player.add_item(output_id, output_amount)
	return {
		"success": true,
		"message": "Изготовлено: %s ×%d." % [player.get_item_name(output_id), output_amount],
		"item_id": output_id,
		"amount": output_amount
	}
