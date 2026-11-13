extends Node
class_name CraftOrders

## Этап 24: crafting orders. Every day Borin and Lira want something made —
## whetstones, oils, rivets; potions, tea, elixirs. The first talk of the day
## tells the order; bring the goods and get paid. Every third order of a
## master also brings a recipe scroll you do not know yet (theirs to share).
## The crafting window lists today's orders.

const MASTERS := {
	"blacksmith": {"name": "Борин", "orders": [["whetstone", 2, 60], ["copper_rivets", 1, 90], ["venom_oil", 2, 70], ["facet_edge", 1, 110], ["planks", 4, 60]],
		"scrolls": ["recipe_steel_mail", "recipe_skysteel"]},
	"alchemist": {"name": "Лира", "orders": [["health_potion", 3, 55], ["mana_potion", 3, 60], ["herb_tea", 2, 50], ["power_elixir", 1, 100], ["swift_tonic", 1, 90]],
		"scrolls": ["recipe_power_elixir", "recipe_swift_tonic", "recipe_hearty_stew"]},
}

var game: SkywardGame
## {master: day the order was shown}.
var seen: Dictionary = {}
## {master: day the order was delivered}.
var delivered: Dictionary = {}
## {master: orders done}.
var done: Dictionary = {}

func today() -> int:
	return game.day_night.day

## Today's order of a master: {"item", "amount", "gold"} ({} — done today).
## Orders begin once the hero has settled in.
func open() -> bool:
	return game.quests.is_completed("main_prologue") and game.player.level >= 3

func order(master: String) -> Dictionary:
	if not open() or not MASTERS.has(master) or int(delivered.get(master, -99)) == today():
		return {}
	var list: Array = MASTERS[master]["orders"]
	var pick: Array = list[posmod(today() * 3 + master.length(), list.size())]
	return {"item": str(pick[0]), "amount": int(pick[1]), "gold": int(pick[2]) + 4 * game.player.level}

func ready(master: String) -> bool:
	var entry := order(master)
	return not entry.is_empty() and int(game.player.inventory.get(entry["item"], 0)) >= int(entry["amount"])

func order_text(master: String) -> String:
	var entry := order(master)
	if entry.is_empty():
		return ""
	return "%s ×%d (%d/%d) — %d золота" % [game.player.get_item_name(str(entry["item"])), int(entry["amount"]), mini(int(game.player.inventory.get(entry["item"], 0)), int(entry["amount"])), int(entry["amount"]), int(entry["gold"])]

## A line for the crafting window.
func summary() -> String:
	var parts: Array[String] = []
	for master in MASTERS:
		if not order(str(master)).is_empty():
			parts.append("%s — %s" % [str(MASTERS[master]["name"]), order_text(str(master))])
	return ("Заказы дня: " + "; ".join(parts)) if not parts.is_empty() else ""

func marker(npc_id: String) -> String:
	return "ready" if ready(npc_id) else ""

## The master's talk: the day's order (once) or its delivery. True — taken.
func talk(npc_id: String) -> bool:
	if not MASTERS.has(npc_id) or order(npc_id).is_empty():
		return false
	# Quest business first.
	if game.dialogues != null and not (game.dialogues._base_marker(npc_id) in ["", "service"]):
		return false
	var name := str(MASTERS[npc_id]["name"])
	if ready(npc_id):
		game._show_dialogue_choices(name, "«Ну-ка, что принёс%s? %s — то, что нужно!»" % ["ла" if StoryText.hero_gender == "f" else "", order_text(npc_id).get_slice(" (", 0)], [
			{"id": "order_give:" + npc_id, "label": "Отдать заказ (+%d золота)" % int(order(npc_id)["gold"])},
			{"id": "order_later", "label": "Потом"}])
		return true
	if int(seen.get(npc_id, -99)) == today():
		return false
	seen[npc_id] = today()
	var entry := order(npc_id)
	var line := "«Заказ на сегодня, если возьмёшься: %s. Сделаешь — плачу %d золотых». (Рецепт — в окне ремесла, B; книга рецептов подскажет, где готовить.)" % [order_text(npc_id).get_slice(" (", 0), int(entry["gold"])]
	game._show_dialogue(name, line)
	return true

func deliver(master: String) -> bool:
	if not ready(master):
		return false
	var entry := order(master)
	game.player.remove_item(str(entry["item"]), int(entry["amount"]))
	delivered[master] = today()
	done[master] = int(done.get(master, 0)) + 1
	game.player.add_gold(int(entry["gold"]))
	game.player.add_experience(30 + 6 * game.player.level)
	game.achievements.add("craft_orders")
	var scroll := ""
	if int(done[master]) % 3 == 0:
		for candidate in MASTERS[master]["scrolls"]:
			if not game.player.learned_recipes.has(str(candidate)) and int(game.player.inventory.get(candidate, 0)) == 0:
				scroll = str(candidate)
				break
	if not scroll.is_empty():
		game.player.add_item(scroll, 1)
	var name := str(MASTERS[master]["name"])
	game._show_dialogue(name, "«Добрая работа!» — +%d золота%s." % [int(entry["gold"]), (" и в придачу свиток: %s" % game.player.get_item_name(scroll)) if not scroll.is_empty() else ""])
	GameAudio.play("quest", -6.0, 0.1)
	game.update_npc_markers()
	game.request_autosave()
	return true

func handle_choice(choice_id: String) -> bool:
	if choice_id == "order_later":
		game.dialogues._close()
		return true
	if choice_id.begins_with("order_give:"):
		game.dialogues._close()
		deliver(choice_id.trim_prefix("order_give:"))
		return true
	return false

func make_snapshot() -> Dictionary:
	return {"seen": seen.duplicate(), "delivered": delivered.duplicate(), "done": done.duplicate()}

func restore_snapshot(value: Variant) -> void:
	var saved: Dictionary = value if value is Dictionary else {}
	seen = (saved.get("seen", {}) as Dictionary).duplicate() if saved.get("seen", {}) is Dictionary else {}
	delivered = (saved.get("delivered", {}) as Dictionary).duplicate() if saved.get("delivered", {}) is Dictionary else {}
	done = (saved.get("done", {}) as Dictionary).duplicate() if saved.get("done", {}) is Dictionary else {}
