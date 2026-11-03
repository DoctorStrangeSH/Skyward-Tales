extends PanelContainer
class_name PauseMenuPanel

## Pause menu with three pages: main actions, controls and settings.

signal resume_requested
signal save_requested
signal load_requested
signal menu_requested

const CONTROLS := [
	["WASD / стрелки", "движение"],
	["ЛКМ", "заклинание в сторону курсора"],
	["1 / 2 / 3", "огонь / лёд / молния"],
	["Shift", "рывок (неуязвимость)"],
	["E", "говорить, подбирать, открывать"],
	["Q / R", "зелье здоровья / маны"],
	["I", "сумка и экипировка"],
	["J", "журнал заданий"],
	["K", "бестиарий"],
	["M", "карта региона"],
	["F6 / F9", "быстрое сохранение / загрузка"],
	["Esc", "пауза"],
]

var main_page: VBoxContainer
var controls_page: VBoxContainer
var settings_page: VBoxContainer
var hints_toggle: CheckButton
var damage_toggle: CheckButton

func _ready() -> void:
	position = Vector2(190, 40)
	custom_minimum_size = Vector2(260, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.11, 0.97)
	style.border_color = Color(0.93, 0.78, 0.47, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	# Main page stays the first child (tests and HUD rely on it).
	main_page = _page("ПАУЗА")
	_button(main_page, "Продолжить", func() -> void: resume_requested.emit())
	_button(main_page, "Сохранить", func() -> void: save_requested.emit())
	_button(main_page, "Загрузить", func() -> void: load_requested.emit())
	_button(main_page, "Главное меню", func() -> void: menu_requested.emit())
	_button(main_page, "Управление", func() -> void: show_page(controls_page))
	_button(main_page, "Настройки", func() -> void: show_page(settings_page))

	controls_page = _page("УПРАВЛЕНИЕ")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 1)
	for row in CONTROLS:
		grid.add_child(_label(row[0], 9, Color(1.0, 0.85, 0.5)))
		grid.add_child(_label(row[1], 9, Color(0.92, 0.92, 0.88)))
	controls_page.add_child(grid)
	_button(controls_page, "Назад", func() -> void: show_page(main_page))

	settings_page = _page("НАСТРОЙКИ")
	hints_toggle = _toggle(settings_page, "Обучающие советы", "hints")
	damage_toggle = _toggle(settings_page, "Числа урона над врагами", "damage_numbers")
	_button(settings_page, "Показать советы заново", func() -> void: GameSettings.reset_tips())
	_button(settings_page, "Назад", func() -> void: show_page(main_page))
	show_page(main_page)
	visible = false

func show_page(page: VBoxContainer) -> void:
	for child in get_children():
		child.visible = child == page
	reset_size()

func _page(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.add_child(_label(title, 14, Color(0.96, 0.87, 0.65)))
	add_child(box)
	return box

func _toggle(parent: VBoxContainer, title: String, key: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.add_theme_font_size_override("font_size", 10)
	toggle.button_pressed = GameSettings.get_bool(key)
	toggle.toggled.connect(func(on: bool) -> void: GameSettings.set_bool(key, on))
	parent.add_child(toggle)
	return toggle

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(parent: VBoxContainer, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.add_theme_font_size_override("font_size", 10)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(callback)
	parent.add_child(button)
