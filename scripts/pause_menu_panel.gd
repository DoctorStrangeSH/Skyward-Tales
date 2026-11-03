extends PanelContainer
class_name PauseMenuPanel

signal resume_requested
signal save_requested
signal load_requested
signal menu_requested

func _ready() -> void:
	position = Vector2(200, 65)
	custom_minimum_size = Vector2(240, 210)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.98)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "ПАУЗА"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.96, 0.87, 0.65))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	_button(box, "Продолжить", func() -> void: resume_requested.emit())
	_button(box, "Сохранить", func() -> void: save_requested.emit())
	_button(box, "Загрузить", func() -> void: load_requested.emit())
	_button(box, "Главное меню", func() -> void: menu_requested.emit())
	visible = false

func _button(parent: VBoxContainer, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(callback)
	parent.add_child(button)
