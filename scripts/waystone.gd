extends Node2D
class_name Waystone

## Sky stone: touch it once to awaken, then travel between awakened stones
## from the world map (M).

signal used(stone: Waystone)

var region_id: String = ""
var awake: bool = false

func _ready() -> void:
	add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	used.emit(self)

func set_awake(value: bool) -> void:
	awake = value
	queue_redraw()

func _draw() -> void:
	WorldArt.draw_prop(self, "props/waystone_on.png" if awake else "props/waystone_off.png")
