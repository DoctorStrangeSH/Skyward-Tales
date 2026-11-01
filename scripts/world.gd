extends Node2D

const TILE_SIZE := 16
const MAP_WIDTH := 80
const MAP_HEIGHT := 54
const COLLISION_WORLD := 4

const GREENREACH_TREES: Array[Vector2] = [
	Vector2(70, 90), Vector2(125, 85), Vector2(330, 80), Vector2(380, 95),
	Vector2(610, 90), Vector2(680, 115), Vector2(840, 90), Vector2(1080, 105),
	Vector2(110, 390), Vector2(200, 460), Vector2(350, 420), Vector2(600, 420),
	Vector2(690, 500), Vector2(980, 390), Vector2(1080, 460), Vector2(470, 590)
]
const GROVE_TREES: Array[Vector2] = [
	Vector2(75, 100), Vector2(165, 120), Vector2(285, 90), Vector2(420, 105),
	Vector2(560, 90), Vector2(690, 120), Vector2(830, 95), Vector2(1010, 110),
	Vector2(1170, 95), Vector2(90, 300), Vector2(260, 320), Vector2(420, 290),
	Vector2(610, 310), Vector2(790, 290), Vector2(980, 330), Vector2(1160, 300),
	Vector2(160, 650), Vector2(360, 690), Vector2(600, 660), Vector2(850, 690),
	Vector2(1080, 650)
]
var region_id: String = "greenreach"

func configure_region(new_region_id: String) -> void:
	region_id = "moonlit_grove" if new_region_id == "moonlit_grove" else "greenreach"
	for child in get_children():
		if child is StaticBody2D:
			remove_child(child)
			child.queue_free()
	queue_redraw()
	_create_world_collisions()

func _active_tree_positions() -> Array[Vector2]:
	return GROVE_TREES if region_id == "moonlit_grove" else GREENREACH_TREES

func _ready() -> void:
	z_index = -10
	queue_redraw()
	_create_world_collisions()

func _draw() -> void:
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var variation: int = absi(x * 928371 + y * 1237 + x * y * 17) % 7
			var base := Color(0.20, 0.39, 0.24) if region_id == "greenreach" else Color(0.13, 0.29, 0.25)
			if variation == 0:
				base = Color(0.22, 0.42, 0.25) if region_id == "greenreach" else Color(0.16, 0.34, 0.28)
			elif variation == 1:
				base = Color(0.18, 0.36, 0.22) if region_id == "greenreach" else Color(0.10, 0.25, 0.23)
			draw_rect(Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE), base)
			if variation == 2:
				draw_rect(Rect2(x * TILE_SIZE + 4, y * TILE_SIZE + 5, 2, 2), Color(0.36, 0.53, 0.28) if region_id == "greenreach" else Color(0.35, 0.55, 0.38))
			elif variation == 5:
				draw_rect(Rect2(x * TILE_SIZE + 11, y * TILE_SIZE + 10, 2, 2), Color(0.43, 0.55, 0.30) if region_id == "greenreach" else Color(0.46, 0.63, 0.46))

	if region_id == "moonlit_grove":
		_draw_grove()
		return
	# Winding dirt trail through the first playable region.
	var trail := PackedVector2Array([
		Vector2(60, 205), Vector2(170, 205), Vector2(225, 250),
		Vector2(340, 250), Vector2(405, 195), Vector2(545, 195),
		Vector2(625, 255), Vector2(790, 255), Vector2(900, 205),
		Vector2(1120, 205)
	])
	for i in range(trail.size() - 1):
		draw_line(trail[i], trail[i + 1], Color(0.34, 0.27, 0.18), 19.0, false)
		draw_line(trail[i], trail[i + 1], Color(0.47, 0.37, 0.23), 13.0, false)

	# A pond and a small ruin make the first area readable even with placeholder art.
	draw_rect(Rect2(760, 470, 145, 88), Color(0.12, 0.30, 0.39))
	draw_rect(Rect2(770, 480, 125, 68), Color(0.17, 0.40, 0.48))
	draw_rect(Rect2(770, 480, 125, 3), Color(0.34, 0.59, 0.61))
	draw_rect(Rect2(920, 90, 92, 58), Color(0.34, 0.32, 0.28))
	draw_rect(Rect2(930, 100, 72, 38), Color(0.24, 0.25, 0.24))
	draw_rect(Rect2(940, 84, 10, 14), Color(0.48, 0.46, 0.39))
	draw_rect(Rect2(984, 84, 10, 14), Color(0.48, 0.46, 0.39))

	for tree_position in _active_tree_positions():
		_draw_tree(tree_position)

func _draw_tree(pos: Vector2) -> void:
	draw_rect(Rect2(pos.x - 3, pos.y + 2, 6, 12), Color(0.27, 0.17, 0.12))
	draw_rect(Rect2(pos.x - 10, pos.y - 11, 20, 17), Color(0.10, 0.25, 0.17))
	draw_rect(Rect2(pos.x - 8, pos.y - 14, 16, 15), Color(0.19, 0.39, 0.22))
	draw_rect(Rect2(pos.x - 5, pos.y - 12, 5, 4), Color(0.30, 0.49, 0.27))

## A separate world collision layer prevents actors walking through scenery.
## Geometry is intentionally simple: gameplay first, art polish later.
func _create_world_collisions() -> void:
	var width: float = MAP_WIDTH * TILE_SIZE
	var height: float = MAP_HEIGHT * TILE_SIZE
	# Thin perimeter walls are centered just outside the playable area.
	_add_wall(Vector2(width * 0.5, -8.0), Vector2(width + 32.0, 16.0))
	_add_wall(Vector2(width * 0.5, height + 8.0), Vector2(width + 32.0, 16.0))
	_add_wall(Vector2(-8.0, height * 0.5), Vector2(16.0, height + 32.0))
	_add_wall(Vector2(width + 8.0, height * 0.5), Vector2(16.0, height + 32.0))
	for tree_position in _active_tree_positions():
		_add_wall(tree_position + Vector2(0.0, 5.0), Vector2(10.0, 11.0))
	if region_id == "moonlit_grove":
		return
	# Keep pond and ruined walls impassable, while the dirt trail stays open.
	_add_wall(Vector2(832.5, 514.0), Vector2(145.0, 88.0))
	_add_wall(Vector2(966.0, 119.0), Vector2(92.0, 58.0))

func _add_wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = COLLISION_WORLD
	body.collision_mask = 0
	body.position = center
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _draw_grove() -> void:
	var trail := PackedVector2Array([
		Vector2(40, 430), Vector2(210, 430), Vector2(330, 360),
		Vector2(510, 360), Vector2(650, 445), Vector2(820, 445),
		Vector2(960, 365), Vector2(1220, 365)
	])
	for i in range(trail.size() - 1):
		draw_line(trail[i], trail[i + 1], Color(0.19, 0.22, 0.17), 24.0, false)
		draw_line(trail[i], trail[i + 1], Color(0.31, 0.34, 0.24), 15.0, false)
	# Moonlit pools and ancient standing stones are decorative landmarks for now.
	draw_circle(Vector2(570, 190), 58.0, Color(0.10, 0.25, 0.31))
	draw_circle(Vector2(570, 190), 45.0, Color(0.14, 0.34, 0.39))
	draw_rect(Rect2(930, 600, 110, 12), Color(0.28, 0.30, 0.27))
	draw_rect(Rect2(950, 575, 12, 62), Color(0.34, 0.37, 0.31))
	draw_rect(Rect2(1008, 575, 12, 62), Color(0.34, 0.37, 0.31))
	for tree_position in _active_tree_positions():
		_draw_tree(tree_position)
