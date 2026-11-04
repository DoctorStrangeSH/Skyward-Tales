extends PanelContainer
class_name WorldMapPanel

var map_view: WorldMinimap
var quest_label: Label

func _ready() -> void:
	position = Vector2(94, 7)
	custom_minimum_size = Vector2(452, 345)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.055, 0.075, 0.99)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	add_child(box)
	box.add_child(_label("КАРТА РЕГИОНА — [M закрыть]", 15, Color(0.99, 0.87, 0.58)))
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(428, 268)
	box.add_child(canvas)
	map_view = preload("res://scripts/world_minimap.gd").new() as WorldMinimap
	map_view.position = Vector2(42, 3)
	map_view.scale = Vector2(2.4, 2.4)
	canvas.add_child(map_view)
	quest_label = _label("Задание: исследуйте мир.", 10, Color(0.83, 0.89, 0.91))
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(quest_label)
	visible = false

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", UiFont.px(font_size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func show_region(region: String, hero: Vector2, landmarks: Dictionary, quest: String) -> void:
	map_view.update_map(region, hero, landmarks)
	quest_label.text = "ЗАДАНИЕ: " + quest
	visible = true
