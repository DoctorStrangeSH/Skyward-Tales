extends Node2D
class_name TreasureChest

signal opened(chest_id: String, gold: int, item_id: String, amount: int)
signal bonus_found(item_id: String, rarity: String)

var chest_id: String = ""
var gold_reward: int = 0
var item_reward: String = ""
var item_amount: int = 0
var is_opened: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	if is_opened or is_queued_for_deletion():
		return
	is_opened = true
	opened.emit(chest_id, gold_reward, item_reward, item_amount)
	var drop: Dictionary = roll_bonus(rng.randf())
	bonus_found.emit(str(drop["item"]), str(drop["rarity"]))
	queue_redraw()
	remove_from_group("interactables")

static func roll_bonus(chance: float) -> Dictionary:
	# 65% common, 28% uncommon, 7% rare; rare tier is split between four finds.
	var value: float = clampf(chance, 0.0, 0.999999)
	if value < 0.65:
		return {"item": "health_potion", "rarity": "common"}
	if value < 0.93:
		return {"item": "mana_amulet", "rarity": "uncommon"}
	var rare_roll: float = (value - 0.93) / 0.07
	if rare_roll < 0.25:
		return {"item": "starlight_essence", "rarity": "rare"}
	if rare_roll < 0.50:
		return {"item": "pyromancer_core", "rarity": "rare"}
	if rare_roll < 0.75:
		return {"item": "frost_heart", "rarity": "rare"}
	return {"item": "storm_eye", "rarity": "rare"}

func _draw() -> void:
	WorldArt.draw_prop(self, "props/chest_open.png" if is_opened else "props/chest_closed.png")
