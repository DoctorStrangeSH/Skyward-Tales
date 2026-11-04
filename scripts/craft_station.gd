extends Node2D
class_name CraftStation

## Kitchen cauldron, alchemy table, forge: E opens the recipe list for this
## station (data/crafting_recipes.json, "station").

signal used(station: CraftStation)

var station_id: String = "kitchen"
var display_name: String = "Котёл"
var art: String = ""

func _ready() -> void:
	add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	used.emit(self)

func _draw() -> void:
	if not art.is_empty():
		WorldArt.draw_prop(self, "world/%s.png" % art)
