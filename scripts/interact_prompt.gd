extends Node2D
class_name InteractPrompt

## Floating "E" keycap with a short verb next to the nearest interactable.

var target: Node2D
var verb: String = ""
var _time: float = 0.0

func _ready() -> void:
	z_index = 55
	top_level = true

func show_for(new_target: Node2D, new_verb: String) -> void:
	target = new_target
	verb = new_verb
	visible = target != null
	queue_redraw()

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		visible = false
		return
	_time += delta
	var lift := -40.0 if target is WorldNpc else -22.0
	var side := 12.0 if target is WorldNpc else 0.0
	global_position = (target.global_position + Vector2(side, lift + roundf(sin(_time * 5.0)))).round()
	queue_redraw()

func _draw() -> void:
	if target == null:
		return
	WorldArt.draw_prop(self, "props/key_e.png")
	if verb.is_empty():
		return
	var font := UiFont.font()
	var at := Vector2(8, -2)
	draw_string_outline(font, at, verb, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), 3, Color(0.05, 0.04, 0.08))
	draw_string(font, at, verb, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.px(8), Color(1.0, 0.96, 0.85))
