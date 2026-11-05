extends Node2D
class_name SettlementObject

## A village board (interactable), an empty plot or a built house. Houses
## carry their own wall collision; art comes from assets/world/village_*.png.

signal used(object: SettlementObject)

var kind: String = "plot"        # "board", "plot" or "house"
var art: String = "village_plot"
var wall_width: float = 56.0

func _ready() -> void:
	if kind == "board":
		add_to_group("interactables")
	if kind == "house":
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(wall_width, 22)
		shape.shape = rect
		shape.position = Vector2(0, -11)
		body.add_child(shape)
		add_child(body)
		z_index = 0
	elif kind == "plot":
		z_index = -50
	queue_redraw()

func interact() -> void:
	used.emit(self)

func _draw() -> void:
	WorldArt.draw_prop(self, "world/%s.png" % art)
