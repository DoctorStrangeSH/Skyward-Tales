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

## Felled trees and worked veins change their look instead of fading:
## "ready", "cut" (a stump), "young" (a sapling). Art:
## assets/world_hd/props/tree_<oak|birch>_<stage>.png, vein_<ready|cut>.png.
var stage: String = "ready"

func staged_art() -> String:
	if kind == "wood":
		return "props/tree_%s_%s" % ["oak" if absi(hash(key)) % 2 == 0 else "birch", stage]
	if kind == "iron":
		return "props/vein_%s" % ("ready" if stage == "ready" else "cut")
	return ""

func _has_stages() -> bool:
	var file := staged_art()
	return not file.is_empty() and ResourceLoader.exists("res://assets/world_hd/%s.png" % file)

func set_stage(value: String) -> void:
	if stage != value:
		stage = value
		queue_redraw()

func set_ready(value: bool) -> void:
	available = value
	if _has_stages():
		modulate = Color.WHITE
		if available:
			stage = "ready"
		elif stage == "ready":
			stage = "cut"
	else:
		modulate = Color.WHITE if available else Color(1, 1, 1, 0.35)
	queue_redraw()

func _draw() -> void:
	if _has_stages():
		WorldArt.draw_prop(self, "world/%s.png" % staged_art())
		return
	WorldArt.draw_prop(self, "world/%s.png" % art)
