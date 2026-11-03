extends Node2D
class_name WorldLoot

signal collected(item_id: String, amount: int)

var item_id: String = "health_potion"
var item_name: String = "Зелье здоровья"
var amount: int = 1

func _ready() -> void:
	add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	collected.emit(item_id, amount)
	queue_free()

func _draw() -> void:
	var art := "pouch"
	if item_id in ["health_potion", "mana_potion", "wolf_pelt"]:
		art = item_id
	elif item_id == "ancient_relic":
		art = "relic"
	WorldArt.draw_prop(self, "props/%s.png" % art)
