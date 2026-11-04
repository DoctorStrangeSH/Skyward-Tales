extends Node2D
class_name GatherNode

## A resource point (log, rock, fishing spot, herb): E gathers a few items,
## then it rests for a while (play time) and fades until it grows back.

signal used(node: GatherNode)

var key: String = ""            # "<region>:<index>", saved cooldown key
var kind: String = "wood"
var display_name: String = ""
var art: String = "gather_wood"
var verb: String = "собрать"
var available: bool = true

func _ready() -> void:
	add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	used.emit(self)

func set_ready(value: bool) -> void:
	available = value
	modulate = Color.WHITE if available else Color(1, 1, 1, 0.35)
	queue_redraw()

func _draw() -> void:
	WorldArt.draw_prop(self, "world/%s.png" % art)
