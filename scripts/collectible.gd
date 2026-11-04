extends Node2D
class_name WorldCollectible

signal interacted(source: Node2D)

@export var item_id: String = "moonleaf"
@export var display_name: String = "Лунный лист"

func _ready() -> void:
	add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	interacted.emit(self)

func _draw() -> void:
	WorldArt.draw_prop(self, "props/%s.png" % art_name())

func art_name() -> String:
	if item_id.begins_with("iron_ore_node_"):
		return "ore_node"
	if item_id.begins_with("supply_crate_"):
		return "supply_crate"
	if item_id in ["map_fragment", "spirit_blossom", "echo_crystal", "sky_shard", "altar_heart", "memory_crystal", "wind_rune", "storm_heart"]:
		return item_id
	return "moonleaf"
