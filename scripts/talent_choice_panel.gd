extends PanelContainer
class_name TalentChoicePanel

signal talent_chosen(talent_id: String)

var choice_list: VBoxContainer

func _ready() -> void:
	position = Vector2(128, 35)
	custom_minimum_size = Vector2(384, 290)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.085, 0.99)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := _label("НОВЫЙ УРОВЕНЬ — ВЫБЕРИТЕ ТАЛАНТ", 14, Color(1.0, 0.87, 0.58))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := _label("Выбор изменит ваш стиль игры. Каждый талант можно усилить до III ранга.", 10, Color(0.77, 0.83, 0.88))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	choice_list = VBoxContainer.new()
	choice_list.add_theme_constant_override("separation", 7)
	box.add_child(choice_list)
	visible = false

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", UiFont.px(font_size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func populate(choices: Array[Dictionary]) -> void:
	for child in choice_list.get_children():
		choice_list.remove_child(child)
		child.queue_free()
	for choice in choices:
		var talent_id: String = str(choice.get("id", ""))
		var rank: int = int(choice.get("rank", 0))
		var entry := VBoxContainer.new()
		var button := Button.new()
		button.text = "%s   РАНГ %d → %d" % [str(choice.get("name", talent_id)), rank, rank + 1]
		button.custom_minimum_size = Vector2(340, 34)
		button.tooltip_text = str(choice.get("description", ""))
		button.pressed.connect(func() -> void: talent_chosen.emit(talent_id))
		entry.add_child(button)
		var description := _label(str(choice.get("description", "")), 9, Color(0.78, 0.84, 0.89))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_child(description)
		choice_list.add_child(entry)
