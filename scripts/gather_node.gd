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
	set_process(false)
	queue_redraw()

func interact() -> void:
	used.emit(self)

## Felled trees and worked veins change their look instead of fading:
## "ready", "cut" (a stump), "young" (a sapling). Art:
## assets/world_hd/props/tree_<oak|birch>_<stage>.png, vein_<ready|cut>.png.
var stage: String = "ready"

func staged_art() -> String:
	if kind == "wood":
		return "props/tree_%s_%s" % ["oak" if absi(hash(key)) % 2 == 0 else "birch", stage]
	if kind in ["stone", "iron", "copper"]:
		return "props/vein_%s" % ("ready" if stage == "ready" else "cut")
	if kind == "echo_crystal":
		return "props/tower_crystal" if stage == "ready" else "props/vein_cut"
	if kind == "memory_crystal":
		return "props/tower_amethyst" if stage == "ready" else "props/vein_cut"
	if kind == "amethyst":
		return "props/tower_amethyst" if stage == "ready" else "props/vein_cut"
	return ""

func _has_stages() -> bool:
	var file := staged_art()
	return not file.is_empty() and ResourceLoader.exists("res://assets/world_hd/%s.png" % file)

func set_stage(value: String) -> void:
	if stage != value:
		var before := stage
		stage = value
		_start_growth(before)
		queue_redraw()

func set_ready(value: bool) -> void:
	available = value
	if _has_stages():
		modulate = Color.WHITE
		if available:
			set_stage("ready")
		elif stage == "ready":
			set_stage("cut")
	else:
		modulate = Color.WHITE if available else Color(1, 1, 1, 0.35)
	queue_redraw()

const GROWTH_FRAMES := 12
const GROWTH_FPS := 10.0
var growth_clock: float = 0.0
var growth_sheet: Texture2D
var growth_origin := Vector2.ZERO

func _start_growth(before: String) -> void:
	growth_sheet = null
	set_process(false)
	if not is_node_ready():
		return
	var file := ""
	if kind == "wood" and stage in ["young", "ready"]:
		var species := "oak" if absi(hash(key)) % 2 == 0 else "birch"
		file = "tree_%s_%s" % [species, "sprout" if stage == "young" else "growth"]
	elif kind in ["stone", "iron", "copper"] and stage == "ready" and before != "ready":
		file = "vein_growth"
	if file.is_empty():
		return
	var path := "world_hd/props/%s.png" % file
	if not ResourceLoader.exists("res://assets/" + path):
		return
	growth_sheet = WorldArt.texture(path)
	growth_origin = WorldArt.origin(path)
	growth_clock = 0.0
	set_process(true)

func _process(delta: float) -> void:
	growth_clock += delta
	if growth_clock >= GROWTH_FRAMES / GROWTH_FPS:
		growth_sheet = null
		set_process(false)
	queue_redraw()

func _draw() -> void:
	if growth_sheet != null:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var size := Vector2(growth_sheet.get_width() / float(GROWTH_FRAMES), growth_sheet.get_height())
		var frame := mini(int(growth_clock * GROWTH_FPS), GROWTH_FRAMES - 1)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * 0.5)
		draw_texture_rect_region(growth_sheet, Rect2(-growth_origin, size), Rect2(Vector2(size.x * frame, 0), size))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if _has_stages():
		WorldArt.draw_prop(self, "world/%s.png" % staged_art())
		return
	WorldArt.draw_prop(self, "world/%s.png" % art)

