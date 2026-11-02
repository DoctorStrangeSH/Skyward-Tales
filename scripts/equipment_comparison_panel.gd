extends PanelContainer
class_name EquipmentComparisonPanel

var title_label: Label
var subtitle_label: Label
var stats_grid: GridContainer
var description_label: Label

func _ready() -> void:
	position = Vector2(300, 30)
	custom_minimum_size = Vector2(330, 300)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.085, 0.98)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	add_child(box)
	title_label = _label("СРАВНЕНИЕ ЭКИПИРОВКИ", 12, Color(1.0, 0.87, 0.57))
	box.add_child(title_label)
	subtitle_label = _label("Наведите курсор на предмет слева.", 10, Color(0.82, 0.87, 0.9))
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle_label)
	stats_grid = GridContainer.new()
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 8)
	stats_grid.add_theme_constant_override("v_separation", 5)
	box.add_child(stats_grid)
	description_label = _label("", 10, Color(0.78, 0.85, 0.9))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description_label)
	box.add_child(_label("Зелёный — улучшение   Красный — ухудшение", 9, Color(0.69, 0.75, 0.8)))
	visible = false

func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _stat_label(value: String, color: Color, font_size: int = 9) -> Label:
	var result := _label(value, font_size, color)
	result.custom_minimum_size.x = 82
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func show_item(comparison: Dictionary, item_id: String) -> void:
	if comparison.is_empty():
		visible = false
		return
	visible = true
	title_label.text = "СРАВНЕНИЕ: " + str(comparison.get("candidate_name", item_id))
	var slot_names: Dictionary = {"weapon": "Оружие", "armor": "Броня", "amulet": "Амулет", "relic": "Реликвия"}
	var current_item_id: String = str(comparison.get("current_item_id", ""))
	var current_name: String = str(comparison.get("current_name", "Пусто"))
	subtitle_label.text = "%s  •  Сейчас: %s  →  Новый предмет: %s" % [
		str(slot_names.get(str(comparison.get("slot", "")), "Экипировка")),
		current_name,
		str(comparison.get("candidate_name", item_id))
	]
	for child in stats_grid.get_children():
		stats_grid.remove_child(child)
		child.queue_free()
	stats_grid.add_child(_stat_label("Характеристика", Color(0.82, 0.86, 0.9), 8))
	stats_grid.add_child(_stat_label("Сейчас", Color(0.82, 0.86, 0.9), 8))
	stats_grid.add_child(_stat_label("Будет", Color(0.82, 0.86, 0.9), 8))
	var stats: Array = comparison.get("stats", [])
	for stat in stats:
		var label: String = str(stat.get("label", ""))
		var unit: String = str(stat.get("unit", ""))
		var before: float = float(stat.get("before", 0.0))
		var after: float = float(stat.get("after", 0.0))
		var delta: float = float(stat.get("delta", 0.0))
		var delta_color: Color = Color(0.52, 0.91, 0.62) if delta > 0.0 else Color(1.0, 0.55, 0.49)
		stats_grid.add_child(_stat_label(label, Color(0.88, 0.89, 0.86)))
		stats_grid.add_child(_stat_label(InventoryComparisonFormatter.value_text(before, unit), Color(0.82, 0.85, 0.88)))
		stats_grid.add_child(_stat_label("%s (%s)" % [InventoryComparisonFormatter.value_text(after, unit), InventoryComparisonFormatter.delta_text(delta, unit)], delta_color))
	if stats.is_empty():
		stats_grid.add_child(_stat_label("Изменения", Color(0.82, 0.86, 0.9)))
		stats_grid.add_child(_stat_label("—", Color(0.82, 0.85, 0.88)))
		stats_grid.add_child(_stat_label("Без изменений", Color(0.82, 0.85, 0.88)))
	description_label.text = "Этот предмет уже надет." if current_item_id == item_id else str(comparison.get("description", ""))
