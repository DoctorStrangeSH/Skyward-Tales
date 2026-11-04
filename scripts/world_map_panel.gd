extends PanelContainer
class_name WorldMapPanel

signal travel_requested(region_id: String)

var map_view: WorldMinimap
var quest_label: Label
var travel_row: HFlowContainer
var title_label: Label
var overview: WorldOverview
var region_canvas: Control
var tab_region: Button
var tab_world: Button

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
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	title_label = _label("КАРТА РЕГИОНА — [M закрыть]", 15, Color(0.99, 0.87, 0.58))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	tab_region = _tab("Регион", false)
	tab_world = _tab("Мир", true)
	header.add_child(tab_region)
	header.add_child(tab_world)
	box.add_child(header)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(428, 236)
	box.add_child(canvas)
	region_canvas = canvas
	overview = WorldOverview.new()
	overview.custom_minimum_size = Vector2(428, 236)
	overview.visible = false
	box.add_child(overview)
	box.move_child(overview, canvas.get_index() + 1)
	map_view = preload("res://scripts/world_minimap.gd").new() as WorldMinimap
	map_view.follow = false
	map_view.position = Vector2(0, 0)
	map_view.size = Vector2(428, 236)
	map_view.custom_minimum_size = Vector2(428, 236)
	canvas.add_child(map_view)
	canvas.add_child(_legend())
	quest_label = _label("Задание: исследуйте мир.", 10, Color(0.83, 0.89, 0.91))
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(quest_label)
	travel_row = HFlowContainer.new()
	travel_row.add_theme_constant_override("h_separation", 4)
	travel_row.add_theme_constant_override("v_separation", 3)
	box.add_child(travel_row)
	visible = false

## Small key to the map icons in the corner.
func _legend() -> Control:
	var legend := Label.new()
	legend.text = "! задание   ? сдать   ◆ камень неба   • враг   квадрат — выход"
	legend.add_theme_font_size_override("font_size", UiFont.px(8))
	legend.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	legend.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	legend.add_theme_constant_override("outline_size", 3)
	legend.position = Vector2(4, 222)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return legend

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

func _tab(text: String, world: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", UiFont.px(9))
	UiStyle.style_button(button)
	button.pressed.connect(func() -> void: show_world(world))
	return button

## Switches between this land's map and the whole world.
func show_world(world: bool) -> void:
	overview.visible = world
	region_canvas.visible = not world
	tab_world.disabled = world
	tab_region.disabled = not world

func set_world(current_region: String, visited_regions: Dictionary) -> void:
	overview.set_world(current_region, visited_regions)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", UiFont.px(font_size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func show_region(region: String, hero: Vector2, landmarks: Dictionary, quest: String) -> void:
	map_view.update_map(region, hero, landmarks)
	show_world(false)
	title_label.text = "%s · ур. %d" % [RegionCatalog.display_name(region).to_upper(), RegionCatalog.level(region)]
	quest_label.text = "ЗАДАНИЕ: " + quest
	visible = true
