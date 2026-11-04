extends Node2D
class_name DungeonLever

## A lever: E pulls it for good. Seals elsewhere open when all their levers
## are pulled.

signal used(lever: DungeonLever)

var lever_id: String = ""
var pulled: bool = false

func _ready() -> void:
	if not pulled:
		add_to_group("interactables")
	queue_redraw()

func interact() -> void:
	used.emit(self)

func set_pulled(value: bool) -> void:
	pulled = value
	if pulled:
		remove_from_group("interactables")
	queue_redraw()

func _draw() -> void:
	WorldArt.draw_prop(self, "props/lever_on.png" if pulled else "props/lever_off.png")
