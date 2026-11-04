extends Node2D
class_name ContractBoard

## Village contract board: E — take and hand in jobs.

signal used(board: ContractBoard)

var _clock := 0.0

func _ready() -> void:
	add_to_group("interactables")

func interact() -> void:
	used.emit(self)

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	modulate = Color(1.0, 0.86, 0.78)
	WorldArt.draw_prop(self, "world/village_board.png")
	# A red pin with a sword mark so it reads apart from the settlement board.
	var bob := sin(_clock * 3.0) * 1.0
	draw_circle(Vector2(0, -40 + bob), 5.0, Color(0.12, 0.06, 0.05))
	draw_circle(Vector2(0, -40 + bob), 4.0, Color(0.85, 0.22, 0.16))
	draw_line(Vector2(-2, -38 + bob), Vector2(2, -42 + bob), Color(1, 0.95, 0.85), 1.0)
