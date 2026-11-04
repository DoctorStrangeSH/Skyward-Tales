extends PanelContainer
class_name WorldMapPanel

signal travel_requested(region_id: String)

var map_view: WorldMinimap
var quest_label: Label
var travel_row: HFlowContainer
var title_label: Label

func _ready() -> void:
	position = Vector2(94, 7)
	custom_minimum_size = Vector2(452, 345)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.055, 0.075, 0.99)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", UiStyle.panel(false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	add_child(box)
	title_label = _label("КАРТА РЕГИОНА — [M закрыть]", 15, Color(0.99, 0.87, 0.58))
	box.add_child(title_label)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(428, 236)
	box.add_child(canvas)
	map_view = preload("res://scripts/world_minimap.gd").new() as WorldMinimap
	map_view.position = Vector2(42, 3)
	map_view.position = Vector2(62, 2)
	map_view.scale = Vector2(2.2, 2.2)
	canvas.add_child(map_view)
	quest_label = _label("Задание: исследуйте мир.", 10, Color(0.83, 0.89, 0.91))
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(quest_label)
	travel_row = HFlowContainer.new()
	travel_row.add_theme_constant_override("h_separation", 4)
	travel_row.add_theme_constant_override("v_separation", 3)
	box.add_child(travel_row)
	visible = false

## One button per awakened sky stone: "Name · ур. N".
func set_destinations(current: String, destinations: Array[String]) -> void:
	for child in travel_row.get_children():
		travel_row.remove_child(child)
		child.queue_free()
	if destinations.is_empty():
		travel_row.add_child(_label("Пробуждайте небесные камни, чтобы перемещаться между землями.", 9, Color(0.62, 0.7, 0.78)))
		return
	travel_row.add_child(_label("Переместиться:", 9, Color(0.75, 0.88, 1.0)))
	for region_id in destinations:
		var button := Button.new()
		button.text = "%s · ур. %d" % [RegionCatalog.display_name(region_id), RegionCatalog.level(region_id)]
		button.add_theme_font_size_override("font_size", UiFont.px(9))
		button.disabled = region_id == current
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: travel_requested.emit(region_id))
		UiStyle.style_button(button)
		travel_row.add_child(button)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", UiFont.px(font_size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func show_region(region: String, hero: Vector2, landmarks: Dictionary, quest: String) -> void:
	map_view.update_map(region, hero, landmarks)
	title_label.text = "%s · ур. %d" % [RegionCatalog.display_name(region).to_upper(), RegionCatalog.level(region)]
	quest_label.text = "ЗАДАНИЕ: " + quest
	visible = true
