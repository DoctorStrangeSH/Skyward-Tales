extends PanelContainer
class_name DefeatPanel

signal restart_requested
signal load_requested
signal menu_requested

var hint_label: Label
var load_button: Button

func _ready() -> void:
	position = Vector2(150, 66)
	custom_minimum_size = Vector2(340, 228)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.035, 0.045, 0.99)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	add_child(box)
	var title := _label("ПУТЕШЕСТВИЕ ПРЕРВАНО", 17, Color(1.0, 0.56, 0.48))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var description := _label("Герой пал в бою. Но это ещё не конец истории.", 11, Color(0.91, 0.87, 0.82))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(description)
	hint_label = _label("Выберите, как продолжить.", 10, Color(0.76, 0.82, 0.87))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint_label)
	_button(box, "Начать заново", func() -> void: restart_requested.emit())
	load_button = Button.new()
	load_button.text = "Загрузить сохранение"
	load_button.pressed.connect(func() -> void: load_requested.emit())
	box.add_child(load_button)
	_button(box, "Главное меню", func() -> void: menu_requested.emit())
	visible = false

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(parent: VBoxContainer, value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(callback)
	parent.add_child(button)

func show_defeat(can_load: bool) -> void:
	load_button.disabled = not can_load
	hint_label.text = "Сохранение найдено. Можно вернуться к последней записи." if can_load else "Сохранений пока нет. Начните новое приключение."
	visible = true
