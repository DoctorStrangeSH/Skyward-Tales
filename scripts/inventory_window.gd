extends PanelContainer
class_name InventoryWindow

signal filter_selected(index: int)
signal sort_selected(index: int)

var equipment_list: VBoxContainer
var item_list: VBoxContainer
var filter_button: OptionButton
var sort_button: OptionButton

func _ready() -> void:
	position = Vector2(8, 30)
	custom_minimum_size = Vector2(286, 300)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.06, 0.09, 0.97)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var contents := VBoxContainer.new()
	add_child(contents)
	contents.add_child(_label("СУМКА  [I — закрыть]", 13, Color(1.0, 0.88, 0.56)))
	contents.add_child(_label("Экипировка (клик — снять)", 10, Color(0.91, 0.90, 0.75)))
	equipment_list = VBoxContainer.new()
	contents.add_child(equipment_list)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 4)
	contents.add_child(controls)
	filter_button = OptionButton.new()
	filter_button.custom_minimum_size = Vector2(118, 26)
	filter_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_button.add_item("Все предметы", 0)
	filter_button.add_item("Экипировка", 1)
	filter_button.add_item("Расходники", 2)
	filter_button.tooltip_text = "Фильтр содержимого сумки"
	filter_button.item_selected.connect(func(index: int) -> void: filter_selected.emit(index))
	controls.add_child(filter_button)
	sort_button = OptionButton.new()
	sort_button.custom_minimum_size = Vector2(118, 26)
	sort_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_button.add_item("Порядок", 0)
	sort_button.add_item("По названию", 1)
	sort_button.add_item("По редкости", 2)
	sort_button.tooltip_text = "Порядок отображения предметов"
	sort_button.item_selected.connect(func(index: int) -> void: sort_selected.emit(index))
	controls.add_child(sort_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 90)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.add_child(scroll)
	item_list = VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(item_list)
	visible = false

func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
