extends PanelContainer
class_name BestiaryPanel

var entry_list: VBoxContainer

func _ready() -> void:
	position = Vector2(110, 22)
	custom_minimum_size = Vector2(420, 310)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.06, 0.08, 0.98)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(_label("БЕСТИАРИЙ  [K — закрыть]", 15, Color(1.0, 0.87, 0.57)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 265)
	box.add_child(scroll)
	entry_list = VBoxContainer.new()
	entry_list.custom_minimum_size = Vector2(382, 0)
	scroll.add_child(entry_list)
	visible = false

func populate(entries: Dictionary, discovered: Dictionary) -> void:
	for child in entry_list.get_children():
		entry_list.remove_child(child)
		child.queue_free()
	for id in entries:
		var entry: Dictionary = entries[id]
		var seen: bool = bool(discovered.get(id, false))
		entry_list.add_child(_label(str(entry.get("name", id)) if seen else "??? — Не обнаружен", 12, Color(1.0, 0.88, 0.65)))
		if seen:
			var detail := _label("Место: %s\nАтака: %s\nСлабость: %s\nЗащита: %s" % [str(entry.get("habitat", "")), str(entry.get("attack", "")), str(entry.get("weakness", "")), str(entry.get("resistance", ""))], 9, Color(0.81, 0.88, 0.9))
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.custom_minimum_size = Vector2(365, 70)
			entry_list.add_child(detail)

func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", UiFont.px(font_size))
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
