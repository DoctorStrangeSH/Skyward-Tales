extends CanvasLayer
class_name ScreenGrade

## The colour pass over the world (stage 21): cool shadows, warm lights,
## a soft vignette — assets/shaders/screen_grade.gdshader. Sits between the
## world and the interface (the HUD is layer 2). Off in the settings →
## `GameSettings` key "color_grade".

var rect: ColorRect

func _ready() -> void:
	layer = 1
	add_to_group("screen_grade")
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/screen_grade.gdshader")
	rect.material = material
	add_child(rect)
	apply()

func apply() -> void:
	rect.visible = GameSettings.get_bool("color_grade")
