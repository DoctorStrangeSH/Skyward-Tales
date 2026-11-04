extends Node2D
class_name DungeonDoor

## A locked grate: E with the right key opens it for good.

signal used(door: DungeonDoor)

var door_id: String = ""
var key_item: String = ""
var is_open: bool = false
var _body: StaticBody2D

func _ready() -> void:
	add_to_group("interactables")
	_body = StaticBody2D.new()
	_body.collision_layer = 4
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 16)
	shape.shape = rect
	shape.position = Vector2(0, -8)
	_body.add_child(shape)
	add_child(_body)
	set_open(is_open)

func interact() -> void:
	used.emit(self)

func set_open(value: bool) -> void:
	is_open = value
	if _body != null:
		_body.process_mode = Node.PROCESS_MODE_DISABLED if is_open else Node.PROCESS_MODE_INHERIT
		_body.collision_layer = 0 if is_open else 4
	if is_open:
		remove_from_group("interactables")
	queue_redraw()

func _draw() -> void:
	WorldArt.draw_prop(self, "world/crypt_door_open.png" if is_open else "world/crypt_door.png")
