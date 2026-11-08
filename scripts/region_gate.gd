extends Node2D
class_name RegionGate

## Passage to another land. Its look follows where it stands and where it
## leads (see `pick_kind`): a gateway or anchor posts at the head of a rope
## bridge on the island's rim (with planks running to the edge), a cave
## mouth, a cave exit full of daylight, or ruin stairs. The interact prompt
## names the destination and its level.

signal travel_requested(target_region: String, arrival_position: Vector2)

@export var target_region: String = "moonlit_grove"
@export var display_name: String = "Тропа в Зачарованный лес"
@export var arrival_position: Vector2 = Vector2(140, 430)
## Terrain style of the region the gate stands in: day, night or cave.
@export var art_style: String = "day"
## bridge_v, bridge_h, cave_mouth, cave_exit, stairs_down, stairs_up
var kind: String = "bridge_v"
## Direction from the gate to the island edge (bridges), for planks/flip.
var outward := Vector2.DOWN
var edge_distance: float = 0.0
var destination_label: String = ""

func _ready() -> void:
	add_to_group("interactables")
	if destination_label.is_empty():
		destination_label = RegionCatalog.display_name(target_region)
	if kind.begins_with("bridge") and edge_distance > 4.0:
		var planks := Node2D.new()
		planks.z_index = -50
		planks.draw.connect(func() -> void: _draw_planks(planks))
		add_child(planks)
	_add_motes()
	queue_redraw()

## Chooses the look: rim gates become bridges, caves get mouths and exits,
## the ruins get stairs.
static func pick_kind(from_style: String, to_style: String, at: Vector2, map_size: Vector2) -> Dictionary:
	var distances := {"left": at.x, "right": map_size.x - at.x, "top": at.y, "bottom": map_size.y - at.y}
	var side: String = distances.keys()[0]
	for key in distances:
		if float(distances[key]) < float(distances[side]):
			side = key
	var outward: Vector2 = {"left": Vector2.LEFT, "right": Vector2.RIGHT, "top": Vector2.UP, "bottom": Vector2.DOWN}[side]
	var underground := RegionCatalog.UNDERGROUND
	var result := {"outward": outward, "edge_distance": float(distances[side])}
	if from_style == "crypt" or (from_style == "magma" and not to_style in underground):
		result["kind"] = "stairs_up"
	elif to_style == "crypt" or to_style == "magma":
		result["kind"] = "stairs_down"
	elif from_style in underground:
		result["kind"] = "cave_exit" if not to_style in underground else "cave_mouth"
	elif to_style in underground:
		result["kind"] = "cave_mouth"
	elif float(distances[side]) <= 110.0:
		result["kind"] = "bridge_h" if side in ["left", "right"] else "bridge_v"
	else:
		result["kind"] = "bridge_v"
		result["edge_distance"] = 0.0
	return result

func interact() -> void:
	travel_requested.emit(target_region, arrival_position)

func _add_motes() -> void:
	var motes := CPUParticles2D.new()
	motes.amount = 10
	motes.lifetime = 2.6
	motes.preprocess = 2.6
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(16, 6)
	motes.position = Vector2(0, -12)
	motes.direction = Vector2.UP
	motes.spread = 25.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 4.0
	motes.initial_velocity_max = 9.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.0
	var ramp := Gradient.new()
	var tint := Color(0.75, 0.9, 1.0) if kind in ["cave_mouth", "stairs_down"] else Color(1.0, 0.95, 0.75)
	ramp.set_color(0, Color(tint, 0.0))
	ramp.add_point(0.3, Color(tint, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(tint, 0.0))
	motes.color_ramp = ramp
	add_child(motes)

func _draw() -> void:
	var art := "props/gate_%s.png" % kind
	if not ResourceLoader.exists("res://assets/" + art):
		art = "props/gate_%s.png" % art_style
	WorldArt.draw_prop(self, art, kind == "bridge_h" and outward == Vector2.LEFT)

## Planks from the gate to the rim, joining the rope bridge drawn outside.
func _draw_planks(canvas: Node2D) -> void:
	var length := edge_distance + 2.0
	var across := Vector2(-outward.y, outward.x)
	var light := Color(0.78, 0.6, 0.39)
	var dark := Color(0.48, 0.33, 0.21)
	var step := 4.0
	var t := 4.0
	while t < length:
		var center := outward * t
		var a := center - across * 7.0
		var b := center + across * 7.0
		canvas.draw_line(a, b, light if int(t / step) % 2 == 0 else Color(0.66, 0.48, 0.3), 3.0)
		canvas.draw_line(a + outward * 1.5, b + outward * 1.5, dark, 1.0)
		t += step
	canvas.draw_line(across * -9.0, across * -9.0 + outward * length, Color(0.92, 0.86, 0.7), 1.0)
	canvas.draw_line(across * 9.0, across * 9.0 + outward * length, Color(0.92, 0.86, 0.7), 1.0)
