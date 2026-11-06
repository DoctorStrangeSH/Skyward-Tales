extends Node2D
class_name LoreStone

## A rune stone with a piece of the world's history (see LoreBook).
## Glows softly until it has been read.

signal interacted(source: Node2D)

var lore_id: String = ""
var fresh: bool = true
var _clock := 0.0

func _ready() -> void:
	add_to_group("interactables")
	z_index = 0

func interact() -> void:
	interacted.emit(self)

func _process(delta: float) -> void:
	if fresh:
		_clock += delta
		queue_redraw()

func _draw() -> void:
	WorldArt.draw_prop(self, "props/lore_stone.png")
	if fresh:
		var pulse := 0.35 + 0.25 * sin(_clock * 3.0)
		draw_circle(Vector2(0, -14), 9.0, Color(0.55, 1.0, 0.95, pulse * 0.35))
